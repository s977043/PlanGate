#!/usr/bin/env python3
"""Realistic spaced-path bypass + per-invocation timing (old vs new)."""
import json, subprocess, os, time
S = os.path.dirname(os.path.abspath(__file__))
OLD, NEW = os.path.join(S, "before.sh"), os.path.join(S, "after.sh")
GT, Q, DQ = chr(62), chr(39), chr(34)
TOK = "c3" + ".json"

def probe(script, cmd):
    return subprocess.run(["sh", script], input=json.dumps({
        "hook_event_name": "PreToolUse", "tool_name": "Bash",
        "tool_input": {"command": cmd}, "session_id": "p"}),
        capture_output=True, text=True).returncode

cases = [
    ("abs path with a space (sq)",
     "echo x %s %s/Users/u/My Drive/pg/docs/working/TASK-0001/approvals/%s%s" % (GT, Q, TOK, Q)),
    ("abs path with a space (dq)",
     "echo x %s %s/Users/u/My Drive/pg/docs/working/TASK-0001/approvals/%s%s" % (GT, DQ, TOK, DQ)),
    ("dir with parentheses",
     "echo x %s %s/repo (2)/docs/working/TASK-0001/approvals/%s%s" % (GT, Q, TOK, Q)),
    ("dir with a hash",
     "echo x %s %sdocs/PR#1/approvals/%s%s" % (GT, Q, TOK, Q)),
    ("tee to spaced path (copy-like lane, control)",
     "echo x | tee %s/a b/approvals/%s%s" % (Q, TOK, Q)),
]
print("=== realistic spaced/metachar path bypass ===")
for d, c in cases:
    print("%-46s OLD rc=%s  NEW rc=%s" % (d, probe(OLD, c), probe(NEW, c)))

print("\n=== per-invocation timing (200 iterations each) ===")
bench = [
    ("no-token read", "ls -la /tmp"),
    ("token read", "cat docs/working/TASK-0001/approvals/%s" % TOK),
    ("token + redirect", "git commit -m %sdocs %s%s %s /tmp/log.txt" % (Q, TOK, Q, GT)),
    ("many redirects (20)", " ; ".join("echo a %s /tmp/f%d" % (GT, i) for i in range(20)) + " # " + TOK),
]
for label, cmd in bench:
    for name, sc in (("OLD", OLD), ("NEW", NEW)):
        t0 = time.time()
        for _ in range(200):
            probe(sc, cmd)
        dt = (time.time() - t0) / 200 * 1000
        print("%-22s %s %7.2f ms/call" % (label, name, dt))
