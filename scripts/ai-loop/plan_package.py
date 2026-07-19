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


# evidence 判定マーカー（契約 §1 正規定義 / #887 F-1・F-2・F-5）。
# 行頭アンカー + verdict + evidence 作成時点の plan.md sha256。自然文の
# 「判定:」表記からの substring 抽出は行わない（後置追記による判定反転を
# 構造的に排除）。ファイル内にちょうど 1 回でなければ fail-closed。
_C1_MARKER_RE = re.compile(r"^C1-VERDICT: (\S+) plan=(sha256:[0-9a-f]{64})$", re.MULTILINE)
_C2_MARKER_RE = re.compile(r"^C2-VERDICT: (\S+) plan=(sha256:[0-9a-f]{64})$", re.MULTILINE)
# プレフィックス行（`C1-VERDICT:` で始まるが完全文法に一致しない行も含む）を
# 数える。完全マッチ数とプレフィックス行数が一致しなければ、文法外の
# VERDICT 行が混入している（末尾空白・不正 hash 等の追記）ため fail-closed
# にする（#887 レビュー / Codex minor 指摘反映）。
_C1_PREFIX_RE = re.compile(r"^C1-VERDICT:", re.MULTILINE)
_C2_PREFIX_RE = re.compile(r"^C2-VERDICT:", re.MULTILINE)

# 契約 §2: decision の 3 値 allowlist（#887 レビュー / 両 Codex major 指摘反映）。
VALID_DECISIONS = ("AUTO_APPROVED", "HUMAN_ESCALATED", "BLOCKED")
VALID_VERDICTS = ("approve", "reject")


def _read_evidence_marker(path, marker_re, prefix_re):
    """マーカーを読み (verdict, plan_hash, error) を返す。

    完全マッチがちょうど 1 回、かつプレフィックス行数と一致する場合のみ受理。
    それ以外（0 回 / 2 回以上 / プレフィックスのみ一致する文法外行の混入）は
    すべて fail-closed。
    """
    text = path.read_text(encoding="utf-8", errors="replace")
    matches = marker_re.findall(text)
    prefix_count = len(prefix_re.findall(text))
    if len(matches) != 1 or prefix_count != 1:
        return None, None, (
            f"evidence: {path.name} の VERDICT マーカーが不正"
            f"（完全一致 {len(matches)} 回 / プレフィックス行 {prefix_count} 行。"
            "契約 §1: 完全文法でちょうど 1 回のみ・fail-closed）")
    verdict, plan_hash = matches[0]
    return verdict, plan_hash, None


def check_evidence(task_dir):
    """契約 §1: C-1/C-2 evidence のマーカー判定・stale 検証（AC-3 / R-002 / #887）。

    受理は C-1=PASS / C-2=approve のみ。stale はマーカー内 plan hash と現
    plan.md の sha256 照合のみで判定する（mtime 不使用・決定論 / F-2）。
    """
    task_dir = pathlib.Path(task_dir)
    errors = []
    plan = task_dir / "plan.md"
    current_plan_hash = _sha256_of(plan) if plan.is_file() else None

    for name, marker_re, prefix_re, accepted in (
        (C1_EVIDENCE, _C1_MARKER_RE, _C1_PREFIX_RE, ("PASS",)),
        (C2_EVIDENCE, _C2_MARKER_RE, _C2_PREFIX_RE, ("approve",)),
    ):
        path = task_dir / name
        if not path.is_file():
            errors.append(f"evidence: {name} が存在しない")
            continue
        verdict, marker_hash, err = _read_evidence_marker(path, marker_re, prefix_re)
        if err:
            errors.append(err)
            continue
        if verdict not in accepted:
            errors.append(f"evidence: {name} の判定が受理対象外 ({verdict})")
        if current_plan_hash is not None and marker_hash != current_plan_hash:
            errors.append(
                f"evidence: {name} が stale（マーカーの plan hash が現 plan.md と不一致。"
                "再 C-1/C-2 が必要）")
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
    if not re.fullmatch(r"[0-9a-f]{7,40}", source_sha or ""):
        errors.append(f"source_sha が commit SHA 形式でない: {source_sha!r}")
    # decision の 3 値 allowlist（契約 §2 / #887 レビュー・両 Codex major）。
    if decision not in VALID_DECISIONS:
        errors.append(
            f"decision が契約の 3 値以外: {decision!r}（許容: {VALID_DECISIONS}）")
    for m in ("model_a", "model_b"):
        if m not in (verdicts or {}):
            errors.append(f"verdicts.{m} が欠落（reviewer snapshot を組めない）")
        elif (verdicts or {}).get(m) not in VALID_VERDICTS:
            errors.append(
                f"verdicts.{m} が approve/reject 以外: {(verdicts or {}).get(m)!r}")
        if m not in (reviewer_evidence or {}):
            errors.append(f"reviewer_evidence.{m} が欠落")
    # decision↔verdicts 整合（契約 §2 / #887 F-3）: AUTO_APPROVED は両 reviewer
    # approve のときのみ。reject を含む AUTO_APPROVED record は生成拒否。
    if decision == "AUTO_APPROVED" and any(
        (verdicts or {}).get(m) != "approve" for m in ("model_a", "model_b")
    ):
        errors.append(
            "decision=AUTO_APPROVED だが reviewer verdict に approve 以外を含む"
            "（decision↔verdicts 不整合 / F-3）")
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
    # evidence_ref 表示値の再読。check_evidence は build 冒頭で通過済みだが、
    # compute_hashes 後の TOCTOU 改変で再読が失敗しうる（#887 レビュー / Codex
    # 新規バグ指摘）。再読エラーは #None を含む record を返さず fail-closed。
    c1_mark, _, c1_err = _read_evidence_marker(task_dir / C1_EVIDENCE, _C1_MARKER_RE, _C1_PREFIX_RE)
    c2_mark, _, c2_err = _read_evidence_marker(task_dir / C2_EVIDENCE, _C2_MARKER_RE, _C2_PREFIX_RE)
    if c1_err or c2_err:
        raise PlanPackageError([e for e in (c1_err, c2_err) if e])

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
