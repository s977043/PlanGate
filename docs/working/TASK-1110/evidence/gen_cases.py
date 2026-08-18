import base64, sys

TOK = "approvals/" + "c3" + ".json"
MAINT = "maintenance" + ".json"

cases = [
    # A: token literal in commit message + unrelated redirect -> expect rc=0
    "git commit -m 'docs: %s' > /tmp/log.txt" % TOK,
    # B: token literal in commit message, no redirect -> expect rc=0
    "git commit -m 'docs: %s handling'" % TOK,
    # C: no token literal + redirect -> expect rc=0
    "git commit -m 'docs: approval token' > /tmp/log.txt",
    # D: true positive -> expect rc=2
    "echo x > %s" % TOK,
    # E: read only -> expect rc=0
    "cat %s" % TOK,
    # F: append to token path -> expect rc=2
    "echo x >> %s" % TOK,
    # G: token path redirect with ./ prefix -> expect rc=2
    "echo x > ./%s" % TOK,
    # H: token in message + write to different real file -> expect rc=0
    "echo '%s' > /tmp/note.txt" % TOK,
    # I: quoted token target -> expect rc=2
    'echo x > "%s"' % TOK,
    # J: maintenance json target -> expect rc=2
    "echo x > docs/working/_maintenance/%s" % MAINT,
    # K: redirect to /dev/null with token literal in message -> expect rc=0
    "git commit -m 'docs: %s' > /dev/null" % TOK,
    # L: cp into token path -> expect rc=2 (copy-like rule, not redirect)
    "cp /tmp/x %s" % TOK,
    # M: two commands; second writes token -> expect rc=2
    "echo hi > /tmp/a.txt; echo x > %s" % TOK,
    # N: token path via variable-ish/normalized path -> expect rc=2
    "echo x > docs/working/TASK-0001/../TASK-0001/approvals/" + "c3" + ".json",
    # O: heredoc writing token path -> expect rc=2
    "cat > %s <<EOF\n{}\nEOF" % TOK,
    # P: fd dup with token literal in message -> expect rc=0
    "git commit -m 'docs: %s' 2>&1" % TOK,
    # Q: tab/space before target -> expect rc=2
    "echo x >   %s" % TOK,
    # R: redirect target unresolvable (command substitution) with token literal -> expect rc=2 (fail-closed)
    "echo x > $(cat /tmp/p) # %s" % TOK,
]

with open(sys.argv[1], "w") as f:
    for c in cases:
        f.write(base64.b64encode(c.encode()).decode() + "\n")
print("wrote %d cases" % len(cases))
