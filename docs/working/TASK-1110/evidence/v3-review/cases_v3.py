#!/usr/bin/env python3
"""V-3 review probe: run attack cases against old (main) and new (PR) EH-13 guard."""
import json, subprocess, sys, os

S = os.path.dirname(os.path.abspath(__file__))
OLD = os.path.join(S, "before.sh")
NEW = os.path.join(S, "after.sh")

T = "docs/working/TASK-0001/approvals/" + "c3" + ".json"
M = "docs/working/_maintenance/" + "maintenance" + ".json"
GT = chr(62)   # >
Q = chr(39)    # '
DQ = chr(34)   # "

CASES = [
    # id, description, command, expectation(the reviewer's view)
    ("N1",  "quoted path containing a space",        "echo x %s %smy dir/%s%s" % (GT, Q, T, Q), "block"),
    ("N1b", "dquoted path containing a space",       "echo x %s %smy dir/%s%s" % (GT, DQ, T, DQ), "block"),
    ("N2",  "exec %s TOKEN" % GT,                    "exec %s %s" % (GT, T), "block"),
    ("N3",  "exec 3%s TOKEN" % GT,                   "exec 3%s %s" % (GT, T), "block"),
    ("N4",  "heredoc: cat <<EOF %s TOKEN" % GT,      "cat <<EOF %s %s\n{}\nEOF" % (GT, T), "block"),
    ("N5",  "dd of=TOKEN",                           "dd if=/dev/zero of=%s" % T, "block"),
    ("N6",  "python open(...,'w')",                  "python3 -c %sopen(%s%s%s,%sw%s).write(%s{}%s)%s" % (DQ, Q, T, Q, Q, Q, Q, Q, DQ), "block"),
    ("N7",  "double slash in path",                  "echo x %s docs/working/TASK-0001/approvals//%s" % (GT, "c3" + ".json"), "block"),
    ("N8",  "tab between %s and target" % GT,        "echo x %s\t%s" % (GT, T), "block"),
    ("N9",  "backslash-escaped space in path",       "echo x %s my\\ dir/%s" % (GT, T), "block"),
    ("N10", "&%s TOKEN (all-output)" % GT,           "echo x &%s %s" % (GT, T), "block"),
    ("N11", "&%s%s TOKEN" % (GT, GT),                "echo x &%s%s %s" % (GT, GT, T), "block"),
    ("N12", "%s| TOKEN (noclobber override)" % GT,   "echo x %s| %s" % (GT, T), "block"),
    ("N13", "newline-separated second stmt",         "echo hi\necho x %s %s" % (GT, T), "block"),
    ("N14", "target then ; (semicolon)",             "echo x %s %s; echo done" % (GT, T), "block"),
    ("N15", "uppercase C3.JSON",                     "echo x %s docs/working/TASK-0001/approvals/%s" % (GT, "C3" + ".JSON"), "?"),
    ("N16", "tilde home prefix",                     "echo x %s ~/%s" % (GT, T), "block"),
    ("N17", "truncate -s 0 TOKEN",                   "truncate -s 0 %s" % T, "block"),
    ("N18", "install -m 644 -> TOKEN",               "install -m 644 /tmp/a %s" % T, "block"),
    ("N19", "sed -i on TOKEN",                       "sed -i %s%s s/a/b/ %s" % (Q, Q, T), "block"),
    ("N20", "dquoted target + && tail",              "echo x %s %s%s%s && echo ok" % (GT, DQ, T, DQ), "block"),
    ("N21", "maintenance.json redirect",             "echo x %s %s" % (GT, M), "block"),
    ("N22", "IFS tampering then redirect",           "IFS=/; echo x %s %s" % (GT, T), "block"),
    ("N23", "target followed by ) subshell",         "(echo x %s %s)" % (GT, T), "block"),
    ("N24", "target inside backtick-free func",      "f(){ echo x %s %s; }; f" % (GT, T), "block"),
    ("N25", "2%s/dev/null then real write" % GT,     "ls 2%s/dev/null; echo x %s %s" % (GT, GT, T), "block"),
    ("N26", "%s TOKEN with trailing spaces" % GT,    "echo x %s %s   " % (GT, T), "block"),
    ("N27", "unrelated redirect first, token 2nd",   "echo hi %s /tmp/a.txt; printf x %s %s" % (GT, GT, T), "block"),
    ("N28", "token target then unrelated redirect",  "echo x %s %s; echo hi %s /tmp/a.txt" % (GT, T, GT), "block"),
    ("N29", "FP: commit msg + unrelated redirect",   "git commit -m %sdocs: %s%s %s /tmp/log.txt" % (Q, T, Q, GT), "pass"),
    ("N30", "FP: read + unrelated write",            "cat %s && echo hi %s /tmp/other.txt" % (T, GT), "pass"),
    ("N31", "FP: heredoc body mentions token",       "cat <<EOF %s /tmp/note.txt\n%s\nEOF" % (GT, T), "pass"),
    ("N32", "FP: -m msg with '%s' in text" % GT,     "git commit -m %sa %s b, see %s%s" % (Q, GT, T, Q), "pass"),
    ("N33", "process substitution target",           "echo x %s %s(cat) # %s" % (GT, GT, T), "block?"),
    ("N34", "brace expansion target",                "echo x %s docs/working/TASK-0001/approvals/{a,%s}" % (GT, "c3" + ".json"), "block"),
    ("N35", "target = symlink-ish ./a/../TOKEN",     "echo x %s ./a/../%s" % (GT, T), "block"),
]


def probe(script, cmd):
    payload = json.dumps({
        "hook_event_name": "PreToolUse", "tool_name": "Bash",
        "tool_input": {"command": cmd}, "session_id": "probe"})
    p = subprocess.run(["sh", script], input=payload, capture_output=True, text=True)
    return p.returncode


print("%-5s %-40s %-6s %-6s %s" % ("ID", "DESC", "OLD", "NEW", "EXPECT"))
regress = []
for cid, desc, cmd, exp in CASES:
    ro = probe(OLD, cmd)
    rn = probe(NEW, cmd)
    flag = ""
    if ro == 2 and rn == 0:
        flag = "  <== LOOSENED"
    if exp == "block" and rn != 2:
        flag += "  <== NOT BLOCKED"
        regress.append(cid)
    print("%-5s %-40s rc=%-3s rc=%-3s %s%s" % (cid, desc[:40], ro, rn, exp, flag))
print()
print("cases where NEW fails to block an expected-true-positive:", regress)
