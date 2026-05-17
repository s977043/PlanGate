#!/usr/bin/env python3
"""keep-rate.py — Keep Rate v1 (#198 / PBI-HI-004).

AI が作成・変更した成果物の残存率を **決定論・軽量**に算出する。
GitHub 全履歴の完全解析・LLM judge・外部分析基盤は行わない（Non-goal）。
算出不能は 0 ではなく "unknown"。release blocker としては使わない（助言）。

正本: docs/ai/keep-rate.md / schema: schemas/keep-rate-result.schema.json

Usage:
  python3 scripts/keep-rate.py <TASK-XXXX> [--no-write]
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
WORKING = REPO / "docs" / "working"
AC_LINE = re.compile(r"^\|\s*AC[0-9A-Za-z_-]*\s*\|.*\|\s*(PASS|FAIL|WARN)\s*\|", re.I)

UNKNOWN = "unknown"
REFERENCED = "referenced"


def _unknown(reason: str) -> dict:
    return {"value": UNKNOWN, "reason": reason}


def _ratio(num: int, denom: int, **extra) -> dict:
    return {"value": round(100.0 * num / denom, 2), **extra}


def _read_c3_plan_hash(c3_path: Path) -> str | None:
    """c3.json を JSON として読み plan_hash の sha256 部を返す。

    正規表現でなく json.load で読む（偽プロパティ注入耐性。EH-3 と同意味）。
    欠落/不正/不可は None。
    """
    try:
        ph = json.loads(c3_path.read_text()).get("plan_hash", "")
    except (OSError, ValueError):
        return None
    if isinstance(ph, str) and ph.startswith("sha256:"):
        return ph[len("sha256:"):]
    return None


def _git(*args: str) -> str | None:
    try:
        out = subprocess.run(
            ["git", *args], cwd=REPO, capture_output=True, text=True, timeout=30
        )
        return out.stdout if out.returncode == 0 else None
    except (OSError, subprocess.SubprocessError):
        return None


_CODE_EXT = (".py", ".sh", ".js", ".ts", ".tsx", ".jsx", ".rb", ".go",
             ".rs", ".java", ".php", ".sql")
_CODE_PATH_PREFIX = ("scripts/", "src/", "lib/", "app/", "tests/")


def _is_code(path: str) -> bool:
    """コードファイル allowlist（#198 V-3 MJ-1）。

    Code Keep Rate は *コード* の残存率。docs/*.md・schemas/*.json・
    docs/working/ 等の成果物/設定は対象外（成果物残存率と混同しない）。
    """
    if path == "bin/plangate":
        return True
    if path.startswith("docs/"):
        return False
    if path.startswith(_CODE_PATH_PREFIX) and path.endswith(_CODE_EXT):
        return True
    if path.endswith(_CODE_EXT):
        return True
    return False


def code_keep_rate(task_id: str) -> dict:
    """TASK の commit が触れた *コードファイル* のうち HEAD で残存する割合。

    全履歴 blame 解析はしない（Non-goal）。ファイル存続率の軽量近似。
    """
    log = _git("log", "--all", "-E", "--format=%H",
               f"--grep=(^|[^0-9A-Za-z-]){re.escape(task_id)}([^0-9A-Za-z-]|$)")
    if not log or not log.strip():
        return _unknown(f"no commit referencing {task_id}")
    shas = log.split()
    # 全 SHA を 1 回の git show に渡す（N fork 回避）
    files = _git("show", "--name-only", "--format=", *shas) or ""
    changed = {
        f.strip() for f in files.splitlines()
        if f.strip() and _is_code(f.strip())
    }
    if not changed:
        return _unknown("no code files in TASK commits")
    survived = sum(1 for f in changed if (REPO / f).is_file())
    return _ratio(survived, len(changed), survived=survived,
                  total=len(changed))


def plan_keep_rate(task_id: str) -> dict:
    """C-3 承認 plan の todo がどれだけ完了維持されたか（todo.md done 比率）。

    plan_hash を **実検証**し、C-3 後に plan.md 改変があれば unknown。
    """
    d = WORKING / task_id
    todo = d / "todo.md"
    c3 = d / "approvals" / "c3.json"
    handoff = d / "handoff.md"
    plan_md = d / "plan.md"
    if not todo.is_file() or not c3.is_file() or not handoff.is_file():
        return _unknown("todo.md / c3.json / handoff.md missing")
    if plan_md.is_file():
        rec = _read_c3_plan_hash(c3)
        try:
            cur = hashlib.sha256(plan_md.read_bytes()).hexdigest()
        except OSError:
            # plan.md 読込不可は stale 検証不能 = unknown（算出不能は unknown 原則）
            return _unknown("plan.md unreadable — plan_hash unverifiable")
        if rec and rec != cur:
            return _unknown("plan.md changed after C-3 (plan_hash mismatch)")
    txt = todo.read_text()
    done = len(re.findall(r"^\s*- \[x\]", txt, re.M | re.I))
    total = len(re.findall(r"^\s*- \[[ xX]\]", txt, re.M))
    if total == 0:
        return _unknown("no todo checklist items")
    return _ratio(done, total, done=done, total=total)


def acceptance_keep_rate(task_id: str) -> dict:
    """test-cases の AC が handoff まで PASS で維持された割合（handoff §1 AC 表）。"""
    d = WORKING / task_id
    tc = d / "test-cases.md"
    handoff = d / "handoff.md"
    if not tc.is_file() or not handoff.is_file():
        return _unknown("test-cases.md / handoff.md missing")
    tc_ids = set(re.findall(r"\bAC[0-9][0-9A-Za-z_-]*", tc.read_text()))
    p = f = w = 0
    for ln in handoff.read_text().splitlines():
        m = AC_LINE.match(ln)
        if m:
            v = m.group(1).upper()
            p += v == "PASS"
            f += v == "FAIL"
            w += v == "WARN"
    tot = p + f + w
    if tot == 0:
        return _unknown("no AC verdict rows in handoff")
    out = {"value": round(100.0 * p / tot, 2), "pass": p, "fail": f, "warn": w}
    if tc_ids and tot < len(tc_ids):
        out["reason"] = (
            f"partial: handoff AC rows {tot} < test-cases AC ids "
            f"{len(tc_ids)} (coverage 不足の可能性)"
        )
    return out


def handoff_keep_rate(task_id: str) -> dict:
    """handoff の既知課題/V2/妥協点が後続 PBI で参照された割合（粗い近似）。

    定義と算出方針は docs/ai/keep-rate.md。完全な履歴解析はしない（Non-goal）。
    近似: 他 TASK の plan/handoff/pbi-input が本 task_id を参照していれば
    「参照あり」とし referenced_by 件数を返す。0 件 or 未算出は unknown。
    """
    d = WORKING / task_id
    if not (d / "handoff.md").is_file():
        return _unknown("handoff.md missing")
    refs = 0
    for other in sorted(WORKING.glob("TASK-*")):
        if other.name == task_id or not other.is_dir():
            continue
        for fn in ("plan.md", "handoff.md", "pbi-input.md"):
            fp = other / fn
            if fp.is_file() and task_id in fp.read_text():
                refs += 1
                break
    if refs == 0:
        return _unknown("no downstream reference yet (定義: keep-rate.md §Handoff)")
    return {"value": REFERENCED, "referenced_by": refs}


def build(task_id: str) -> dict:
    return {
        "task_id": task_id,
        "schema": "keep-rate-result/v1",
        "code_keep_rate": code_keep_rate(task_id),
        "plan_keep_rate": plan_keep_rate(task_id),
        "acceptance_keep_rate": acceptance_keep_rate(task_id),
        "handoff_keep_rate": handoff_keep_rate(task_id),
        "note": "advisory only — not a release blocker (#198 Non-goal)",
    }


def render_md(r: dict) -> str:
    def fmt(m: dict) -> str:
        v = m["value"]
        if v == UNKNOWN:
            return f"unknown ({m.get('reason', '')})"
        if v == REFERENCED:
            return f"referenced (by {m.get('referenced_by')} TASK)"
        return f"{v}%"

    return "\n".join(
        [
            f"# Keep Rate v1: {r['task_id']}",
            "",
            "> advisory only — release blocker としては使わない（#198）",
            "",
            f"- Code Keep Rate: **{fmt(r['code_keep_rate'])}**",
            f"- Plan Keep Rate: **{fmt(r['plan_keep_rate'])}**",
            f"- Acceptance Keep Rate: **{fmt(r['acceptance_keep_rate'])}**",
            f"- Handoff Keep Rate: **{fmt(r['handoff_keep_rate'])}**",
            "",
            "## 関連",
            "",
            "- [`docs/ai/keep-rate.md`](../../ai/keep-rate.md)",
            "- [`schemas/keep-rate-result.schema.json`]"
            "(../../../schemas/keep-rate-result.schema.json)",
            "",
        ]
    )


def main() -> int:
    ap = argparse.ArgumentParser(description="PlanGate Keep Rate v1 (#198)")
    ap.add_argument("task_id")
    ap.add_argument("--no-write", action="store_true")
    a = ap.parse_args()
    if not re.match(r"^TASK-[0-9A-Za-z]+$", a.task_id):
        print(f"error: invalid task_id: {a.task_id}", file=sys.stderr)
        return 2
    r = build(a.task_id)
    md = render_md(r)
    js = json.dumps(r, indent=2, ensure_ascii=False)
    if a.no_write:
        print("=== keep-rate-result.md ===")
        print(md)
        print("=== keep-rate-result.json ===")
        print(js)
    else:
        d = WORKING / a.task_id
        d.mkdir(parents=True, exist_ok=True)
        (d / "keep-rate-result.md").write_text(md + "\n")
        (d / "keep-rate-result.json").write_text(js + "\n")
        print(f"Written: docs/working/{a.task_id}/keep-rate-result.{{md,json}}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
