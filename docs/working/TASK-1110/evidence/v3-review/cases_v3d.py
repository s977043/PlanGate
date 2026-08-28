#!/usr/bin/env python3
"""Lane asymmetry: Write lane vs Bash lane for the same spaced token path."""
import json, subprocess, os
S = os.path.dirname(os.path.abspath(__file__))
NEW = os.path.join(S, "after.sh")
GT, Q = chr(62), chr(39)
P = "/Users/u/My Drive/pg/docs/working/TASK-0001/approvals/" + "c3" + ".json"

def run(payload):
    p = subprocess.run(["sh", NEW], input=json.dumps(payload), capture_output=True, text=True)
    return p.returncode

print("Write tool, file_path = spaced token path      -> rc=%s" % run(
    {"hook_event_name": "PreToolUse", "tool_name": "Write",
     "tool_input": {"file_path": P, "content": "{}"}}))
print("Bash tool, redirect to the same spaced path    -> rc=%s" % run(
    {"hook_event_name": "PreToolUse", "tool_name": "Bash",
     "tool_input": {"command": "echo x %s %s%s%s" % (GT, Q, P, Q)}}))
print("Bash tool, tee to the same spaced path (ctrl)  -> rc=%s" % run(
    {"hook_event_name": "PreToolUse", "tool_name": "Bash",
     "tool_input": {"command": "echo x | tee %s%s%s" % (Q, P, Q)}}))
