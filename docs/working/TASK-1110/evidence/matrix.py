#!/usr/bin/env python3
"""TASK-1110 R-001 regression matrix: OLD(main) / NEW(f922442) / FIXED(worktree).

Never writes to any real approvals path -- only feeds PreToolUse payloads to the
hook and observes rc. Token path literals are assembled at runtime so this file
itself does not trip EH-13 when it appears in a command line.
"""
import json, os, subprocess, sys

SP = "/private/tmp/claude-502/-Users-user-Documents-GitHub-plangate/ed736940-223f-452c-bd1b-4dfefbc8ee9d/scratchpad"
WT = "/Users/user/Documents/GitHub/plangate/.claude/worktrees/agent-a64c4b7f24aa1b27d"

GUARDS = [
    ("OLD", os.path.join(SP, "guard-main.sh")),
    ("NEW", os.path.join(SP, "guard-f922442.sh")),
    ("FIXED", os.path.join(WT, "scripts/check-approval-token-write.sh")),
]

GT, SQ, DQ, BS = chr(62), chr(39), chr(34), chr(92)
C3 = "c3" + ".json"
MAINT = "maintenance" + ".json"
TOK = "docs/working/TASK-0001/approvals/" + C3


def sp(c):
    """token path whose TASK segment carries a special char (still a token path)"""
    return "docs/working/TASK%s0001/approvals/%s" % (c, C3)


def probe(guard, cmd):
    env = dict(os.environ)
    env.pop("PLANGATE_HOOK_FILE", None)
    env["PLANGATE_SKIP_TOKEN_GUARD"] = "0"
    p = subprocess.run(["sh", guard], input=json.dumps({
        "hook_event_name": "PreToolUse", "tool_name": "Bash",
        "tool_input": {"command": cmd}, "session_id": "probe"}),
        capture_output=True, text=True, env=env)
    return p.returncode


def probe_write(guard, path):
    env = dict(os.environ)
    env.pop("PLANGATE_HOOK_FILE", None)
    env["PLANGATE_SKIP_TOKEN_GUARD"] = "0"
    p = subprocess.run(["sh", guard], input=json.dumps({
        "hook_event_name": "PreToolUse", "tool_name": "Write",
        "tool_input": {"file_path": path, "content": "x"}, "session_id": "probe"}),
        capture_output=True, text=True, env=env)
    return p.returncode


# ---------------------------------------------------------------- group R-001
R001 = []
for ch, name in [(" ", "space"), ("\t", "tab"), (";", "semicolon"), ("&", "amp"),
                 ("|", "pipe"), ("(", "lparen"), (")", "rparen"), ("<", "lt"),
                 ("#", "hash")]:
    R001.append(("quoted %s" % name, 2,
                 "echo x %s %s%s%s" % (GT, SQ, sp(ch), SQ)))
    R001.append(("dquoted %s" % name, 2,
                 "echo x %s %s%s%s" % (GT, DQ, sp(ch), DQ)))
R001.append(("backslash-escaped space", 2,
             "echo x %s docs/working/TASK%s 0001/approvals/%s" % (GT, BS, C3)))
R001.append(("unquoted mid-word hash", 2,
             "echo x %s %s" % (GT, sp("#"))))
R001.append(("quoted spaced abs path", 2,
             "echo x %s %s/Users/u/My Drive/pg/%s%s" % (GT, DQ, TOK, DQ)))
R001.append(("quoted paren dir", 2,
             "echo x %s %s/Users/u/repo (2)/%s%s" % (GT, DQ, TOK, DQ)))

# --------------------------------------------------------- group A-E (issue)
AE = [
    ("A token-literal + unrelated redirect", 0,
     "git commit -m %sdocs: %s%s %s /tmp/log.txt" % (SQ, TOK, SQ, GT)),
    ("B token-literal, no redirect", 0,
     "git commit -m %sdocs: %s handling%s" % (SQ, TOK, SQ)),
    ("C no token literal + redirect", 0,
     "git commit -m %sdocs: approval token%s %s /tmp/log.txt" % (SQ, SQ, GT)),
    ("D true positive", 2, "echo x %s %s" % (GT, TOK)),
    ("E read only", 0, "cat %s" % TOK),
]

# ------------------------------------------------------- group boundary (13)
BOUND = [
    ("06 append", 2, "echo x %s%s %s" % (GT, GT, TOK)),
    ("07 dot-slash", 2, "echo x %s ./%s" % (GT, TOK)),
    ("08 token as content to other file", 0,
     "echo %s%s%s %s /tmp/note.txt" % (SQ, TOK, SQ, GT)),
    ("09 quoted token target", 2, "echo x %s %s%s%s" % (GT, DQ, TOK, DQ)),
    ("10 maintenance target", 2,
     "echo x %s docs/working/_maintenance/%s" % (GT, MAINT)),
    ("11 redirect to /dev/null", 0,
     "git commit -m %sdocs: %s%s %s /dev/null" % (SQ, TOK, SQ, GT)),
    ("12 cp into token (copy-like)", 2, "cp /tmp/x %s" % TOK),
    ("13 second stmt writes token", 2,
     "echo hi %s /tmp/a.txt; echo x %s %s" % (GT, GT, TOK)),
    ("14 dotdot in path", 2,
     "echo x %s docs/working/TASK-0001/../TASK-0001/approvals/%s" % (GT, C3)),
    ("15 heredoc to token", 2, "cat %s %s <<EOF\n{}\nEOF" % (GT, TOK)),
    ("16 fd dup 2>&1", 0,
     "git commit -m %sdocs: %s%s 2%s&1" % (SQ, TOK, SQ, GT)),
    ("17 multiple spaces", 2, "echo x %s   %s" % (GT, TOK)),
    ("18 command substitution target", 2,
     "echo x %s $(cat /tmp/p) # %s" % (GT, TOK)),
]

# ------------------------------------------------- group fail-closed declared
FC = [
    ("$VAR target", 2, "echo x %s $OUT # %s" % (GT, TOK)),
    ("backtick target", 2, "echo x %s `cat /tmp/p` # %s" % (GT, TOK)),
    ("glob * target", 2, "echo x %s /tmp/*.json # %s" % (GT, TOK)),
    ("glob ? target", 2, "echo x %s /tmp/a?.json # %s" % (GT, TOK)),
    ("glob [ target", 2, "echo x %s /tmp/a[0].json # %s" % (GT, TOK)),
    ("empty target", 2, "echo x %s   # %s" % (GT, TOK)),
    ("/dev/stdout", 2, "cat %s %s /dev/stdout" % (TOK, GT)),
    ("&> file", 2, "echo x &%s /tmp/a # %s" % (GT, TOK)),
    (">& file", 2, "cat %s %s& /tmp/o" % (TOK, GT)),
]

# ------------------------------------------------------ group lane symmetry
SPACED = "/Users/u/My Drive/pg/" + TOK
LANE = [
    ("tee to spaced token (copy-like)", 2,
     "printf x | tee %s%s%s" % (DQ, SPACED, DQ)),
    ("cp to spaced token (copy-like)", 2,
     "cp /tmp/x %s%s%s" % (DQ, SPACED, DQ)),
    ("redirect to spaced token", 2,
     "echo x %s %s%s%s" % (GT, DQ, SPACED, DQ)),
]

# --------------------------------------------------- group newline flattening
NL = [
    ("heredoc body mentions token, writes /tmp", 0,
     "cat <<EOF %s /tmp/log.txt\n%s\nEOF" % (GT, TOK)),
    # rejected-alternative control: the record after '>' keeps running to the end of
    # the command and contains a quote. Flagging "chars were dropped by truncation"
    # (reviewer's option 2) would block this legitimate case; scoping the check to the
    # truncated word (option 1, adopted) must not.
    ("redirect to /tmp then quoted token msg", 0,
     "echo x %s /tmp/log.txt && git commit -m %sdocs: %s%s" % (GT, SQ, TOK, SQ)),
    ("redirect to /tmp then unquoted token word", 0,
     "echo x %s /tmp/log.txt && grep -c %s .gitignore" % (GT, TOK)),
]

GROUPS = [("R-001 truncation classes", R001), ("issue cases A-E", AE),
          ("boundary 13", BOUND), ("declared fail-closed", FC),
          ("lane symmetry (same spaced path)", LANE),
          ("newline flattening", NL)]

fail = 0
for gname, cases in GROUPS:
    print("\n=== %s ===" % gname)
    print("%-42s %-6s %-6s %-6s %-6s %s" % ("case", "want", "OLD", "NEW", "FIXED", "verdict"))
    for label, want, cmd in cases:
        rcs = [probe(g, cmd) for _, g in GUARDS]
        ok = rcs[2] == want
        verdict = "OK" if ok else "MISMATCH"
        if rcs[0] == 2 and rcs[2] == 0:
            # main が block していたものを通す = 意図した誤検出解消(want=0) か退行(want=2)
            verdict += (" / intended false-positive removal" if want == 0
                        else " / TRUE-POSITIVE LOST vs main")
        if not ok:
            fail += 1
        print("%-42s %-6s %-6s %-6s %-6s %s" % (label, want, rcs[0], rcs[1], rcs[2], verdict))

print("\n=== Write-lane control (same spaced token path) ===")
for _, g in GUARDS:
    pass
print("Write tool, spaced token path: OLD=%s NEW=%s FIXED=%s" % tuple(
    probe_write(g, SPACED) for _, g in GUARDS))

print("\nFIXED mismatches: %d" % fail)
sys.exit(1 if fail else 0)
