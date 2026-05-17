#!/usr/bin/env python3
"""context-engine.py — Dynamic Context Engine v1 (#199 / PBI-HI-005).

phase / mode / profile に応じて context を解決する。**契約コンテキスト**
（PBI / 承認済 plan / test-cases / c3.json）は固定し承認境界・監査可能性を
保つ。**作業コンテキスト**（git status/diff/recent/test failure 等）は
記述子として列挙（実取得は呼び出し側・budget 内）。

opt-in（既存 workflow 非破壊）。Vector DB / embedding は使わない（Non-goal）。
C-3/C-4 は緩和しない。stale plan/c3 は EH-3 plan_hash と矛盾しない判定を行う。

正本: docs/ai/context-engine.md / schema: schemas/context-manifest.schema.json

Usage:
  python3 scripts/context-engine.py <TASK-XXXX> --phase execute \\
      --mode standard [--profile gpt-5_5] [--no-write]
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
WORKING = REPO / "docs" / "working"

# mode → context budget（model-profiles の max_context_policy と整合）
_BUDGET = {
    "ultra_light": ("compact", 3),
    "light": ("compact", 5),
    "standard": ("standard", 10),
    "high_risk": ("expanded", 16),
    "critical": ("expanded", 24),
}
_POLICY_RANK = {"compact": 0, "standard": 1, "expanded": 2}
_RANK_POLICY = {0: "compact", 1: "standard", 2: "expanded"}


def _profile_policy(profile: str | None) -> str | None:
    """model-profiles.yaml の指定 profile の max_context_policy を返す。

    PyYAML 不在や未定義時は None（mode 由来のみ採用）。v1 は両者の
    **保守側（compact<standard<expanded の小さい方）** を採用し profile の
    方針と矛盾させない（#199 V-3 MJ-1）。
    """
    if not profile:
        return None
    try:
        import yaml

        y = yaml.safe_load(
            (REPO / "docs" / "ai" / "model-profiles.yaml").read_text()
        )
        m = (y or {}).get("models", {}).get(profile)
        return m.get("max_context_policy") if m else None
    except Exception:
        return None

_DYNAMIC = [
    ("git_status", "git status --porcelain", "always"),
    ("git_diff", "git diff --stat", "on_demand"),
    ("recent_files", "git log --name-only -n 5", "on_demand"),
    ("test_failure", "last test run output", "on_failure"),
    ("repo_structure", "tree -L 2 (or git ls-files)", "on_demand"),
    ("coding_rules", "CLAUDE.md / .claude/rules/", "on_demand"),
    ("past_handoff", "docs/working/TASK-*/handoff.md", "on_demand"),
    ("related_pbi", "docs/working/ cross-reference", "on_demand"),
]


def _contract(task_id: str) -> tuple[list, dict]:
    d = WORKING / task_id
    items = []
    plan_hash_match = None
    note = ""
    spec = [
        ("pbi_input", d / "pbi-input.md"),
        ("approved_plan", d / "plan.md"),
        ("test_cases", d / "test-cases.md"),
        ("c3_approval", d / "approvals" / "c3.json"),
    ]
    c3 = d / "approvals" / "c3.json"
    plan = d / "plan.md"
    rec_hash = None
    if c3.is_file():
        m = re.search(r'"plan_hash"\s*:\s*"sha256:([0-9a-f]+)"', c3.read_text())
        rec_hash = m.group(1) if m else None
    for kind, fp in spec:
        if not fp.is_file():
            items.append({"kind": kind, "path": str(fp.relative_to(REPO)),
                          "status": "missing"})
            continue
        entry = {"kind": kind, "path": str(fp.relative_to(REPO)),
                 "status": "present"}
        if kind == "approved_plan":
            if rec_hash:
                cur = hashlib.sha256(fp.read_bytes()).hexdigest()
                entry["plan_hash"] = f"sha256:{cur}"
                if cur != rec_hash:
                    # EH-3 と矛盾しない: plan_hash 不一致 = stale。契約 invalidate
                    entry["status"] = "stale"
                    entry["invalidated"] = True
                    plan_hash_match = False
                    note = "plan.md changed after C-3 (EH-3 plan_hash mismatch)"
                else:
                    plan_hash_match = True
            elif c3.is_file():
                # c3 はあるが plan_hash 抽出不可 → 未照合の承認 plan を
                # contract として使わせない（承認境界を弱めない / V-3 MJ-2）
                entry["status"] = "stale"
                entry["invalidated"] = True
                plan_hash_match = False
                note = "plan_hash missing/unverified in c3.json — contract not usable"
        items.append(entry)
    return items, {"plan_hash_match": plan_hash_match,
                   "note": note or ("plan_hash consistent" if plan_hash_match else "no c3/plan to verify")}


def build(task_id: str, phase: str, mode: str, profile: str | None) -> dict:
    pol, dmax = _BUDGET.get(mode, ("standard", 10))
    ppol = _profile_policy(profile)
    if ppol in _POLICY_RANK:
        # mode 由来と profile 由来の保守側（小さい rank）を採用
        pol = _RANK_POLICY[min(_POLICY_RANK[pol], _POLICY_RANK[ppol])]
    contract, guard = _contract(task_id)
    dyn = [{"kind": k, "source": s, "when": w} for k, s, w in _DYNAMIC][:dmax]
    return {
        "task_id": task_id,
        "schema": "context-manifest/v1",
        "phase": phase,
        "mode": mode,
        **({"profile": profile} if profile else {}),
        "contract_context": contract,
        "dynamic_context": dyn,
        "budget": {"max_context_policy": pol, "dynamic_max_items": dmax},
        "stale_guard": guard,
        "note": "opt-in resolved context; contract fixed (approval boundary). "
                "Not a gate; C-3/C-4 unchanged (#199 Non-goal).",
    }


def render_md(m: dict) -> str:
    g = m.get("stale_guard", {})
    lines = [
        f"# Context Manifest: {m['task_id']}",
        "",
        f"> phase={m['phase']} mode={m['mode']} "
        f"profile={m.get('profile', '-')} (opt-in / advisory)",
        "",
        "## Contract context（固定・承認境界）",
        "",
    ]
    for c in m["contract_context"]:
        flag = " ⚠️invalidated" if c.get("invalidated") else ""
        lines.append(f"- `{c['kind']}` {c['path']} — **{c['status']}**{flag}")
    lines += ["", "## Dynamic context（記述子・budget 内）", ""]
    for dctx in m["dynamic_context"]:
        lines.append(f"- `{dctx['kind']}` ({dctx['when']}): {dctx['source']}")
    lines += [
        "",
        f"## Budget: {m['budget']['max_context_policy']} / "
        f"dynamic_max_items={m['budget']['dynamic_max_items']}",
        "",
        f"## Stale guard: plan_hash_match={g.get('plan_hash_match')} "
        f"— {g.get('note', '')}",
        "",
        "## 関連",
        "",
        "- [`docs/ai/context-engine.md`](../../ai/context-engine.md)",
        "- [`schemas/context-manifest.schema.json`]"
        "(../../../schemas/context-manifest.schema.json)",
        "",
    ]
    return "\n".join(lines)


def main() -> int:
    ap = argparse.ArgumentParser(description="PlanGate Dynamic Context Engine v1 (#199)")
    ap.add_argument("task_id")
    ap.add_argument("--phase", required=True,
                    choices=["classify", "plan", "approve-wait", "execute",
                             "review", "verify", "handoff"])
    ap.add_argument("--mode", default="standard",
                    choices=["ultra_light", "light", "standard",
                             "high_risk", "critical"])
    ap.add_argument("--profile")
    ap.add_argument("--no-write", action="store_true")
    a = ap.parse_args()
    if not re.match(r"^TASK-[0-9A-Za-z]+$", a.task_id):
        print(f"error: invalid task_id: {a.task_id}", file=sys.stderr)
        return 2
    m = build(a.task_id, a.phase, a.mode, a.profile)
    js = json.dumps(m, indent=2, ensure_ascii=False)
    md = render_md(m)
    if a.no_write:
        print("=== context-manifest.md ===")
        print(md)
        print("=== context-manifest.json ===")
        print(js)
    else:
        d = WORKING / a.task_id
        d.mkdir(parents=True, exist_ok=True)
        (d / "context-manifest.json").write_text(js + "\n")
        (d / "context-manifest.md").write_text(md + "\n")
        print(f"Written: docs/working/{a.task_id}/context-manifest.{{md,json}}")
    # stale（EH-3 矛盾防止）: invalidated 契約があれば exit 1（advisory 警告）
    if any(c.get("invalidated") for c in m["contract_context"]):
        print("WARNING: contract context invalidated (stale plan_hash)",
              file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
