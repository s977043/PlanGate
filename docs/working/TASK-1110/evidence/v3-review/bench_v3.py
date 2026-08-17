#!/usr/bin/env python3
"""Interleaved median timing, old vs new, to cancel machine noise."""
import json, subprocess, os, time, statistics
S = os.path.dirname(os.path.abspath(__file__))
OLD, NEW = os.path.join(S, "before.sh"), os.path.join(S, "after.sh")
GT, Q = chr(62), chr(39)
TOK = "c3" + ".json"

def one(script, payload):
    t0 = time.perf_counter()
    subprocess.run(["sh", script], input=payload, capture_output=True, text=True)
    return (time.perf_counter() - t0) * 1000

bench = [
    ("no-token (common path)", "ls -la /tmp"),
    ("token read only", "cat docs/working/TASK-0001/approvals/%s" % TOK),
    ("token + 1 redirect", "git commit -m %sdocs %s%s %s /tmp/log.txt" % (Q, TOK, Q, GT)),
    ("token + 20 redirects", " ; ".join("echo a %s /tmp/f%d" % (GT, i) for i in range(20)) + " # " + TOK),
    ("token + 200 redirects", " ; ".join("echo a %s /tmp/f%d" % (GT, i) for i in range(200)) + " # " + TOK),
]
N = 60
print("%-24s %10s %10s %8s" % ("case", "OLD med", "NEW med", "delta"))
for label, cmd in bench:
    p = json.dumps({"hook_event_name": "PreToolUse", "tool_name": "Bash",
                    "tool_input": {"command": cmd}, "session_id": "p"})
    o, n = [], []
    for _ in range(N):
        o.append(one(OLD, p))
        n.append(one(NEW, p))
    mo, mn = statistics.median(o), statistics.median(n)
    print("%-24s %9.2fms %9.2fms %+7.2fms" % (label, mo, mn, mn - mo))
