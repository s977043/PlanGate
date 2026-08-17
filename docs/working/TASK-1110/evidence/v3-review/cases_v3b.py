#!/usr/bin/env python3
"""Characterize the truncation-char class of the #1110 regression."""
import json, subprocess, os
S = os.path.dirname(os.path.abspath(__file__))
OLD, NEW = os.path.join(S, "before.sh"), os.path.join(S, "after.sh")
GT, Q, DQ = chr(62), chr(39), chr(34)
TOK = "c3" + ".json"

def probe(script, cmd):
    p = subprocess.run(["sh", script], input=json.dumps({
        "hook_event_name": "PreToolUse", "tool_name": "Bash",
        "tool_input": {"command": cmd}, "session_id": "probe"}),
        capture_output=True, text=True)
    return p.returncode, p.stderr.strip().replace("\n", " ")[:90]

# every char the extractor truncates on, embedded in a *quoted* (hence legal) path
CHARS = [(" ", "space"), ("\t", "tab"), (";", "semicolon"), ("&", "amp"),
         ("|", "pipe"), ("(", "lparen"), (")", "rparen"), ("<", "lt"), ("#", "hash")]
print("%-12s %-6s %-6s %s" % ("TRUNC-CHAR", "OLD", "NEW", "verdict"))
lost = []
for c, name in CHARS:
    path = "docs/working/TASK%s0001/approvals/%s" % (c, TOK)
    cmd = "echo x %s %s%s%s" % (GT, Q, path, Q)
    ro, _ = probe(OLD, cmd)
    rn, msg = probe(NEW, cmd)
    v = "TRUE-POSITIVE LOST" if (ro == 2 and rn == 0) else "ok"
    if v != "ok":
        lost.append(name)
    print("%-12s rc=%-3s rc=%-3s %s" % (name, ro, rn, v))
print("\nlost:", lost)

print("\n--- control: same chars, unquoted (not a single shell word) ---")
for c, name in [(" ", "space"), ("#", "hash")]:
    path = "docs/working/TASK%s0001/approvals/%s" % (c, TOK)
    cmd = "echo x %s %s" % (GT, path)
    ro, _ = probe(OLD, cmd)
    rn, _ = probe(NEW, cmd)
    print("%-12s rc=%-3s rc=%-3s" % (name, ro, rn))

print("\n--- does the declared fail-closed set really fire? ---")
for label, cmd in [
    ("$VAR",        "echo x %s $OUT # %s" % (GT, TOK)),
    ("$(...)",      "echo x %s $(cat /tmp/p) # %s" % (GT, TOK)),
    ("backtick",    "echo x %s `cat /tmp/p` # %s" % (GT, TOK)),
    ("glob *",      "echo x %s /tmp/*.json # %s" % (GT, TOK)),
    ("glob ?",      "echo x %s /tmp/a?.json # %s" % (GT, TOK)),
    ("glob [",      "echo x %s /tmp/a[0].json # %s" % (GT, TOK)),
    ("empty",       "echo x %s   # %s" % (GT, TOK)),
    ("/dev/stdout", "cat docs/working/TASK-0001/approvals/%s %s /dev/stdout" % (TOK, GT)),
    ("&%s"%GT,      "echo x &%s /tmp/a # %s" % (GT, TOK)),
    ("glob TOKEN*", "echo x %s docs/working/TASK-0001/approvals/c3.jso*" % GT),
    ("quoted+space","echo x %s %sa b/approvals/x.json%s" % (GT, Q, Q)),
]:
    ro, _ = probe(OLD, cmd)
    rn, msg = probe(NEW, cmd)
    print("%-14s OLD rc=%-3s NEW rc=%-3s %s" % (label, ro, rn, msg[:70]))
