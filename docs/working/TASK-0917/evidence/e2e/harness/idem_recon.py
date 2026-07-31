#!/usr/bin/env python3
"""T-35 Step 4b（冪等）+ Step 5（Reconciler）+ push_pr_head 事前検査の負検証。"""
import json
import pathlib
import sys

SP = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(SP / "impl"))

import gh_exec       # noqa: E402
import delivery      # noqa: E402
import executor      # noqa: E402
import reconciler    # noqa: E402

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
    proc = _orig_spawn(argv, cwd=cwd, timeout=timeout)
    LEDGER.append({"seq": len(LEDGER) + 1, "argv": list(argv),
                   "returncode": proc.returncode,
                   "stdout": (proc.stdout or "")[:800],
                   "stderr": (proc.stderr or "")[:800]})
    return proc


gh_exec._spawn = spy


def dump(path, obj):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(obj, indent=2, sort_keys=True, ensure_ascii=False)
                    + "\n", encoding="utf-8")
    print(f"[dump] {path}")


action = delivery._action("repair_ci", {
    "pr_number": PR, "head_sha": HEAD_AT_APPROVAL, "round": 1,
    "taxonomy": "code", "failed_checks": ["Markdown lint"]})

ctx = executor.ExecContext(repo=REPO, branch=BRANCH, task_dir=TASK_DIR, now=NOW,
                           gh=gh_exec, cwd=str(WT), repair_commit_sha=REPAIR_COMMIT)

# --- Step 4b: 同一 action の再実行（receipt 済み = 外部作用ゼロで即返す） ---
before = len(LEDGER)
report = executor.execute_actions([action], ctx)
after = len(LEDGER)
idem = {
    "outcomes": [vars(o) | {"escalation_flags": list(o.escalation_flags)}
                 for o in report.outcomes],
    "spawn_calls_during_rerun": after - before,
    "record_lines_after": len(
        delivery.load_entries(delivery.record_path(TASK_DIR))),
}
print("[idempotency]", json.dumps(idem, ensure_ascii=False))
dump(EVID / "idempotency-rerun.json", idem)

# --- Step 5: Reconciler（intent ↔ receipt の突合） ---
entries = delivery.load_entries(delivery.record_path(TASK_DIR))
state = reconciler.reconcile(TASK_DIR, pr_number=PR, entries=entries)
recon = {
    "intent_action_ids": sorted(state.intents),
    "receipt_action_ids": sorted(state.receipts),
    "pending": list(state.pending),
    "orphan_receipts": [e.get("action_id") for e in state.orphan_receipts],
    "dispositions": state.dispositions,
    "conflict_resolution": state.conflict_resolution,
    "escalation_flags": list(reconciler.escalation_flags(state)),
    "filter_unexecuted_of_same_action": [
        a["action_id"] for a in reconciler.filter_unexecuted([action], entries)],
    "is_applied": reconciler.is_applied(action["action_id"], entries),
}
print("[reconcile]", json.dumps(recon, indent=2, ensure_ascii=False))
dump(EVID / "reconcile.json", recon)

# --- push_pr_head 事前検査の負検証（いずれも push に到達しない） -------------
probes = []


def probe(name, **kw):
    n0 = len(LEDGER)
    try:
        res = gh_exec.push_pr_head(**kw)
        probes.append({"probe": name, "outcome": "NOT_DENIED",
                       "pushed": res.pushed, "argv": list(res.argv),
                       "spawns": len(LEDGER) - n0})
    except gh_exec.Denied as exc:
        probes.append({"probe": name, "outcome": "Denied",
                       "reason": exc.reason, "message": str(exc),
                       "spawns_during_probe": len(LEDGER) - n0,
                       "push_argv_spawned": any(
                           e["argv"][:2] == ["git", "push"]
                           for e in LEDGER[n0:])})


probe("check1/2: branch=main（PR の headRefName と一致しない）",
      repo=REPO, branch="main", expected_parent_sha=REPAIR_COMMIT, cwd=str(WT))
probe("check4: fast-forward でない expected_parent_sha",
      repo=REPO, branch=BRANCH,
      expected_parent_sha="3c1242f0000000000000000000000000000000ff", cwd=str(WT))
probe("入力検査: SHA 形式でない expected_parent_sha",
      repo=REPO, branch=BRANCH, expected_parent_sha="HEAD~1", cwd=str(WT))
probe("入力検査: branch 名に '..' を含む",
      repo=REPO, branch="../evil", expected_parent_sha=REPAIR_COMMIT, cwd=str(WT))

# check3（origin URL 一致）は純関数を実測 origin URL で直接評価する
origin = gh_exec.run_git(["ls-remote", "--get-url", "origin"], cwd=str(WT))
probes.append({
    "probe": "check3: origin URL 一致（純関数 _origin_matches を実測値で評価）",
    "measured_origin_url": origin.stdout.strip(),
    "matches_target_repo": gh_exec._origin_matches(origin.stdout, REPO),
    "matches_other_repo": gh_exec._origin_matches(origin.stdout, "s977043/other"),
})

print("[precheck-probes]", json.dumps(probes, indent=2, ensure_ascii=False))
dump(EVID / "precheck-probes.json", probes)
dump(EVID / "raw" / "spawn-ledger-idem-recon.json", LEDGER)
