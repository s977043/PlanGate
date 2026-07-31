#!/usr/bin/env python3
"""T-35 Step 3: Executor の実走（通知コメント → pre-check → repair push → receipt）。

`gh_exec._spawn`（実装が「テストが差し替えられる唯一の口」と明記している seam）を
**素通しの記録ラッパ**で包み、実際に起動された argv / rc / stdout / stderr を
時系列で残す。挙動は一切変えない（delegate のみ）。
"""
import json
import pathlib
import sys
import time

SP = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(SP / "impl"))

import gh_exec       # noqa: E402
import delivery      # noqa: E402
import executor      # noqa: E402

WT = pathlib.Path("/Users/user/Documents/GitHub/plangate-wt-0917")
EVID = WT / "docs/working/TASK-0917/evidence/e2e"
TASK_DIR = EVID / "run"
REPO = "s977043/PlanGate"
BRANCH = "chore/task-0917-e2e-probe"
PR = 940
HEAD_AT_APPROVAL = "fe0abc66d426ce13b18c58d407ecfa6f68808450"
REPAIR_COMMIT = "7b229223b21a40708d1262fa86ff287977621ee4"
NOW = "2026-07-31T00:00:00Z"

LEDGER = []
_orig_spawn = gh_exec._spawn


def spy(argv, *, cwd=None, timeout=120):
    t0 = time.time()
    proc = _orig_spawn(argv, cwd=cwd, timeout=timeout)
    LEDGER.append({
        "seq": len(LEDGER) + 1,
        "argv": list(argv),
        "returncode": proc.returncode,
        "stdout": (proc.stdout or "")[:2000],
        "stderr": (proc.stderr or "")[:2000],
        "elapsed_ms": int((time.time() - t0) * 1000),
    })
    return proc


gh_exec._spawn = spy


def dump(path, obj):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(obj, indent=2, sort_keys=True, ensure_ascii=False)
                    + "\n", encoding="utf-8")
    print(f"[dump] {path}")


def main():
    # --- ① repair_ci intent を用意する ---------------------------------------
    # `delivery.assess()` は今回の実 PR で CHECKS_FAILED に到達しない（CI 全 green）
    # ため、repair_ci intent は `delivery._action()`（実物のコンストラクタ）で
    # 組み立て、`assess()` が書く intent entry と**同一形状**で record へ追記する。
    action = delivery._action("repair_ci", {
        "pr_number": PR,
        "head_sha": HEAD_AT_APPROVAL,
        "round": 1,
        "taxonomy": "code",
        "failed_checks": ["Markdown lint"],
    })
    intent = {"kind": "intent", "action_id": action["action_id"],
              "action_kind": action["action_kind"],
              "payload": {k: v for k, v in action.items()
                          if k not in ("action_id", "action_kind")}}
    n = delivery.append_entries(delivery.record_path(TASK_DIR), [intent], NOW)
    print(f"[intent] appended={n} action_id={action['action_id']}")
    dump(EVID / "action-repair-ci.json", action)

    # `verify_action_id()` が受理する導出であることを事前確認（外部作用の前）
    print("[verify_action_id]", executor.verify_action_id(action))

    ctx = executor.ExecContext(
        repo=REPO, branch=BRANCH, task_dir=TASK_DIR, now=NOW,
        gh=gh_exec, cwd=str(WT), repair_commit_sha=REPAIR_COMMIT)

    report = executor.execute_actions([action], ctx)
    out = {
        "outcomes": [vars(o) | {"escalation_flags": list(o.escalation_flags)}
                     for o in report.outcomes],
        "escalation_flags": list(report.escalation_flags),
    }
    dump(EVID / "execution-report.json", out)
    dump(EVID / "raw" / "spawn-ledger-exec.json", LEDGER)
    print(json.dumps(out, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
