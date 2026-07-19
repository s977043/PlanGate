#!/usr/bin/env python3
"""plan_package.py — Plan Package の presence/integrity 検証・hash 固定・LoopSpec 決定論的派生・
c3-prime record 組み立て（TASK-0872 / issue #872）。

PlanGate 本番フロー（bin/plangate・scripts/hooks/）からは一切呼ばれない隔離 PoC。
ai-loop（Phase 1）の C-3' を Plan Package の hash と evidence へ束縛する層を提供する。
契約正本: docs/workflows/ai-loop/c3-prime-contract.md

設計原則（arbiter.py / #873 delivery.py と同型）:
- 決定論: 同一入力 → 同一出力（timestamp は issued_at として注入・now() を直接参照しない）
- fail-closed: 判定不能・欠落・不一致はすべてエラー側に倒す
- 冪等: 同一 Plan Package からの派生・組み立ては byte 同一
"""

from __future__ import annotations

import argparse
import hashlib
import json
import pathlib
import re
import sys

TASK_ID_RE = re.compile(r"^TASK-[0-9]{4}$")

# 契約 §1: Plan Package 6 要素（key 順は artifact_hashes の表示順にも使う）
ARTIFACTS = (
    "pbi-input.md",
    "plan.md",
    "todo.md",
    "test-cases.md",
    "review-self.md",
    "review-external.md",
)

C1_EVIDENCE = "review-self.md"
C2_EVIDENCE = "review-external.md"


class PlanPackageError(Exception):
    """fail-closed 用例外。errors に機械追跡可能なエラー文字列リストを保持する。"""

    def __init__(self, errors):
        self.errors = list(errors)
        super().__init__("; ".join(self.errors))


def validate_task_id(task_id):
    """TC-01 層 2: task_id 形式検証。エラーリストを返す（空 = OK）。"""
    if not isinstance(task_id, str) or not TASK_ID_RE.match(task_id or ""):
        return [f"task_id が TASK-XXXX 形式でない: {task_id!r}"]
    return []


def check_presence(task_dir):
    """契約 §1: 6 要素の存在 + 非空（EC-1）。エラーリストを返す。"""
    task_dir = pathlib.Path(task_dir)
    errors = []
    for name in ARTIFACTS:
        path = task_dir / name
        if not path.is_file():
            errors.append(f"presence: {name} が存在しない ({path})")
        elif path.stat().st_size == 0:
            errors.append(f"integrity: {name} が 0 byte ({path})")
    return errors


def _extract_verdict_line(text, patterns):
    """判定行を後方から探す（最後の判定が正）。見つからなければ None。"""
    for line in reversed(text.splitlines()):
        for pat in patterns:
            if pat in line:
                return line
    return None


# 判定「値」の抽出（行全体の部分一致は「FAIL 0 件」等の注記に誤反応するため使わない）
_C1_VERDICT_RE = re.compile(r"判定:\s*\**([A-Z]+)\**")
_C2_VERDICT_RE = re.compile(r"総合判定:\s*\**([a-z]+)\**")


def check_evidence(task_dir):
    """契約 §1: C-1/C-2 evidence の判定・stale 検証（AC-3 / R-002）。

    受理は C-1=PASS / C-2=approve のみ（それ以外・抽出不能はすべて fail-closed）。
    stale は evidence の mtime < plan.md の mtime の暫定実装
    （#810 の evidence キー契約確定後に hash 照合へ強化する。plan.md Unknowns 参照）。
    """
    task_dir = pathlib.Path(task_dir)
    errors = []
    plan = task_dir / "plan.md"
    plan_mtime = plan.stat().st_mtime if plan.is_file() else None

    for name, patterns, verdict_re, accepted in (
        (C1_EVIDENCE, ("判定:",), _C1_VERDICT_RE, ("PASS",)),
        (C2_EVIDENCE, ("総合判定:",), _C2_VERDICT_RE, ("approve",)),
    ):
        path = task_dir / name
        if not path.is_file():
            errors.append(f"evidence: {name} が存在しない")
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        line = _extract_verdict_line(text, patterns)
        match = verdict_re.search(line) if line else None
        if line is None or match is None:
            errors.append(f"evidence: {name} に判定行が見つからない（fail-closed）")
        elif match.group(1) not in accepted:
            errors.append(
                f"evidence: {name} の判定が受理対象外 ({match.group(1)}): {line.strip()}")
        if plan_mtime is not None and path.stat().st_mtime < plan_mtime:
            errors.append(
                f"evidence: {name} が stale（plan.md より古い。再 C-1/C-2 が必要）")
    return errors


def _sha256_of(path):
    return "sha256:" + hashlib.sha256(pathlib.Path(path).read_bytes()).hexdigest()


def compute_hashes(task_dir):
    """契約 §2: artifact_hashes / plan_hash / plan_package_hash を算出する。"""
    task_dir = pathlib.Path(task_dir)
    presence = check_presence(task_dir)
    if presence:
        raise PlanPackageError(presence)
    artifact_hashes = {name: _sha256_of(task_dir / name) for name in ARTIFACTS}
    canon = json.dumps(artifact_hashes, sort_keys=True,
                       separators=(",", ":")).encode("utf-8")
    return {
        "artifact_hashes": artifact_hashes,
        "plan_hash": artifact_hashes["plan.md"],
        "plan_package_hash": "sha256:" + hashlib.sha256(canon).hexdigest(),
    }


def _extract_section(text, heading):
    """`## heading` から次の `## ` までの本文を返す（無ければ None）。"""
    lines = text.splitlines()
    start = None
    for i, line in enumerate(lines):
        if line.strip().startswith("## ") and heading in line:
            start = i + 1
            break
    if start is None:
        return None
    body = []
    for line in lines[start:]:
        if line.startswith("## "):
            break
        body.append(line)
    return "\n".join(body).strip()


_PATH_RE = re.compile(r"`([^`\s]+/[^`\s]+)`")


def derive_loopspec(task_dir, task_id, maker, checker):
    """契約 §6: LoopSpec 必須フィールド全数の決定論的派生（AC-10 / R-012）。

    導出不能フィールドが 1 つでもあれば PlanPackageError（I-4 fail-closed）。
    """
    errors = validate_task_id(task_id)
    if errors:
        raise PlanPackageError(errors)
    if not maker or not checker:
        raise PlanPackageError(["actors: maker / checker は必須"])
    if maker == checker:
        raise PlanPackageError(["actors: maker と checker が同一（I-2 違反）"])
    task_dir = pathlib.Path(task_dir)
    presence = check_presence(task_dir)
    if presence:
        raise PlanPackageError(presence)

    plan_text = (task_dir / "plan.md").read_text(encoding="utf-8", errors="replace")

    goal = _extract_section(plan_text, "Goal")
    if not goal:
        raise PlanPackageError(["derive: plan.md に `## Goal` 節がない"])

    files_section = _extract_section(plan_text, "Files / Components to Touch")
    allowed_paths = _PATH_RE.findall(files_section or "")
    if not allowed_paths:
        raise PlanPackageError(
            ["derive: `## Files / Components to Touch` からパスを抽出できない"])

    cmd_match = re.search(r"Verification Automation:\s*`([^`]+)`", plan_text)
    if not cmd_match:
        raise PlanPackageError(["derive: `Verification Automation:` 行が抽出できない"])
    deterministic = [
        {"cmd": cmd.strip(), "expect_exit": 0}
        for cmd in cmd_match.group(1).split("&&")
        if cmd.strip()
    ]
    if not deterministic:
        raise PlanPackageError(["derive: Verification Automation のコマンドが空"])

    return {
        "loop": {
            "name": "plan-first-" + task_id.lower(),
            "trigger": {"type": "manual"},
            "goal": {
                "description": goal,
                "exit_criteria_ref": f"docs/working/{task_id}/test-cases.md",
            },
            "context": {
                "include": ["plan_package", "diff", "test_results"],
                "exclude": ["stale_tool_outputs"],
                "external_sources": [],
            },
            "scope": {"allowed_paths": allowed_paths},
            "actors": {"maker": maker, "checker": checker},
            "verification": {
                "deterministic": deterministic,
                "review": ["requirements_fit", "architecture_consistency"],
            },
            "stopping_rule": {
                "terminal_state_ref": "decision-table.md",
                "round_limit_ref": "execution-runbook.md §2-(7)",
            },
            "memory": {
                "write": ["decision_record"],
                "ref": "execution-runbook.md §2-(4)",
            },
            "escalation": {
                "touches_ho": "unconditional",
                "budget_ref": "arbiter-policy.md §7",
            },
        }
    }


def build_c3_prime(task_dir, task_id, source_sha, target_sha, verdicts,
                   reviewer_evidence, decision, policy_ref, issued_at, issued_by):
    """契約 §2/§3: c3-prime record を組み立てる（TC-08a）。

    presence / evidence / task_id / source_sha 整合のいずれかが不成立なら
    PlanPackageError（AUTO_APPROVED record を組ませない = AC-2/AC-3 の生成側防御）。
    """
    errors = validate_task_id(task_id)
    task_dir = pathlib.Path(task_dir)
    errors += check_presence(task_dir)
    if not errors:
        errors += check_evidence(task_dir)
    if source_sha != target_sha:
        errors.append(
            f"source_sha ({source_sha}) と target_sha ({target_sha}) が不一致（R-011）")
    if not re.match(r"^[0-9a-f]{7,40}$", source_sha or ""):
        errors.append(f"source_sha が commit SHA 形式でない: {source_sha!r}")
    for m in ("model_a", "model_b"):
        if m not in (verdicts or {}):
            errors.append(f"verdicts.{m} が欠落（reviewer snapshot を組めない）")
        if m not in (reviewer_evidence or {}):
            errors.append(f"reviewer_evidence.{m} が欠落")
    if errors:
        raise PlanPackageError(errors)

    hashes = compute_hashes(task_dir)
    reviewers = {
        m: {
            "verdict": verdicts[m],
            "plan_hash": hashes["plan_hash"],
            "source_sha": source_sha,
            "plan_package_hash": hashes["plan_package_hash"],
            "evidence_ref": reviewer_evidence[m],
        }
        for m in ("model_a", "model_b")
    }
    c1_line = _extract_verdict_line(
        (task_dir / C1_EVIDENCE).read_text(encoding="utf-8", errors="replace"),
        ("判定:",)) or ""
    c2_line = _extract_verdict_line(
        (task_dir / C2_EVIDENCE).read_text(encoding="utf-8", errors="replace"),
        ("総合判定:",)) or ""
    c1_mark = "PASS" if "PASS" in c1_line else "UNKNOWN"
    c2_mark = "approve" if "approve" in c2_line else "UNKNOWN"

    return {
        "task_id": task_id,
        "approval_kind": "c3-prime",
        "phase": "C-3'",
        "decision": decision,
        "source_sha": source_sha,
        "plan_hash": hashes["plan_hash"],
        "plan_package_hash": hashes["plan_package_hash"],
        "artifact_hashes": hashes["artifact_hashes"],
        "c1_evidence_ref": f"{C1_EVIDENCE}#{c1_mark}",
        "c2_evidence_ref": f"{C2_EVIDENCE}#{c2_mark}",
        "reviewers": reviewers,
        "policy_ref": policy_ref,
        "issued_at": issued_at,
        "issued_by": issued_by,
    }


def serialize_c3_prime(record):
    """契約 §5: 決定論 serialization（indent=2 / sort_keys / c3_status 禁止）。"""
    if "c3_status" in record:
        raise PlanPackageError(["serialization: c3-prime に c3_status を含めてはならない（§5）"])
    return json.dumps(record, ensure_ascii=False, indent=2, sort_keys=True) + "\n"


def main(argv=None):
    parser = argparse.ArgumentParser(
        description="Plan Package の presence/evidence/hash 検証（read-only）")
    parser.add_argument("--task-dir", required=True, help="docs/working/TASK-XXXX のパス")
    parser.add_argument("--task-id", required=True, help="TASK-XXXX")
    args = parser.parse_args(argv)

    errors = validate_task_id(args.task_id)
    errors += check_presence(args.task_dir)
    if not errors:
        errors += check_evidence(args.task_dir)
    if errors:
        for e in errors:
            print(f"[plan-package] FAIL: {e}", file=sys.stderr)
        return 3
    hashes = compute_hashes(args.task_dir)
    print(json.dumps(hashes, ensure_ascii=False, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
