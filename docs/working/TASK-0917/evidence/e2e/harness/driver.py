#!/usr/bin/env python3
"""TASK-0917 T-35 実 PR 1 周の実走ドライバ（証跡採取用ハーネス）。

実装コード（scripts/ai-loop/*.py）は feat/task-0917-delivery から
`git show` で**バイト等価**に取り出したものを import する（改変ゼロ）。
"""
import json
import os
import pathlib
import sys

IMPL = pathlib.Path(__file__).resolve().parent / "impl"
sys.path.insert(0, str(IMPL))

import gh_exec       # noqa: E402
import collector     # noqa: E402
import delivery      # noqa: E402
import executor      # noqa: E402
import reconciler    # noqa: E402

WT = pathlib.Path("/Users/user/Documents/GitHub/plangate-wt-0917")
EVID = WT / "docs/working/TASK-0917/evidence/e2e"
RAW = EVID / "raw"
TASK_DIR = EVID / "run"
REPO = "s977043/PlanGate"
PR = 940
SOURCE_SHA = "d64e36f6c275a15506b4d3956a9bd6c6c7d3f41d"
NOW = "2026-07-31T00:00:00Z"


class Recorder:
    """gh_exec への全呼び出しを記録する透過プロキシ（実装は差し替えない）。"""

    Denied = gh_exec.Denied

    def __init__(self):
        self.calls = []

    def _rec(self, fn, argv, proc):
        self.calls.append({
            "fn": fn, "argv": argv,
            "returncode": getattr(proc, "returncode", None),
            "stdout_len": len(getattr(proc, "stdout", "") or ""),
            "stderr": (getattr(proc, "stderr", "") or "")[:400],
        })

    def run_gh(self, args, *, repo, cwd=None, **kw):
        proc = gh_exec.run_gh(args, repo=repo, cwd=cwd, **kw)
        self._rec("run_gh", list(args), proc)
        self.calls[-1]["stdout"] = proc.stdout
        return proc

    def run_git(self, args, *, cwd=None, **kw):
        proc = gh_exec.run_git(args, cwd=cwd, **kw)
        self._rec("run_git", list(args), proc)
        self.calls[-1]["stdout"] = proc.stdout
        return proc

    def comment_pr(self, **kw):
        proc = gh_exec.comment_pr(**kw)
        self._rec("comment_pr", ["<pr comment>", str(kw.get("pr_number"))], proc)
        self.calls[-1]["stdout"] = proc.stdout
        return proc

    def push_pr_head(self, **kw):
        res = gh_exec.push_pr_head(**kw)
        self.calls.append({
            "fn": "push_pr_head", "argv": list(res.argv),
            "pushed": res.pushed,
            "returncode": getattr(res.result, "returncode", None),
            "stdout": getattr(res.result, "stdout", ""),
            "stderr": getattr(res.result, "stderr", ""),
        })
        return res


def dump(path, obj):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(obj, indent=2, sort_keys=True, ensure_ascii=False)
                    + "\n", encoding="utf-8")
    print(f"[dump] {path} ({len(path.read_text(encoding='utf-8').splitlines())} lines)")


def do_collect(tag):
    rec = Recorder()
    plan_text = (WT / "docs/working/TASK-0917/plan.md").read_text(encoding="utf-8")
    entries = []
    try:
        entries = delivery.load_entries(delivery.record_path(TASK_DIR))
    except delivery.RecordError as exc:
        print("record load error:", exc)
    snap = collector.collect(
        task_id="TASK-0917", repo=REPO, pr_number=PR, source_sha=SOURCE_SHA,
        plan_text=plan_text, findings=[], record_entries=entries,
        gh=rec, cwd=str(WT))
    dump(EVID / f"snapshot-{tag}.json", snap)
    dump(RAW / f"gh-calls-{tag}.json", rec.calls)
    return snap, entries


def do_assess(snap, entries, tag):
    try:
        result = delivery.assess(snap, entries, plan_hash=None)
    except delivery.SnapshotError as exc:
        result = {"error": f"SnapshotError: {exc}"}
    dump(EVID / f"assess-{tag}.json", result)
    return result


if __name__ == "__main__":
    step = sys.argv[1]
    if step == "collect1":
        snap, entries = do_collect("1")
        res = do_assess(snap, entries, "1")
        print("STATE-1:", res.get("state"))
        print("REASONS-1:", json.dumps(res.get("reasons"), ensure_ascii=False))
        print("FLAGS-1:", json.dumps(snap.get("escalation_flags"), ensure_ascii=False))
        print("HEAD-1:", snap.get("head_sha"))
    else:
        tag = step.replace("collect", "")
        snap, entries = do_collect(tag)
        res = do_assess(snap, entries, tag)
        print(f"STATE-{tag}:", res.get("state"))
        print(f"REASONS-{tag}:", json.dumps(res.get("reasons"), ensure_ascii=False))
        print(f"FLAGS-{tag}:",
              json.dumps(snap.get("escalation_flags"), ensure_ascii=False))
        print(f"HEAD-{tag}:", snap.get("head_sha"))
        print(f"CHECKS-{tag}:", json.dumps(
            [(c["name"], c["conclusion"]) for c in snap["checks"]],
            ensure_ascii=False))
