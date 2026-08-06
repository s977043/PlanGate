#!/usr/bin/env python3
"""#928 self-approve guard テストハーネス（sandbox 実行専用）。

usage: python3 run-approve-guard-tests.py <repo-root>
hook を PreToolUse 相当の stdin JSON で直接叩き、exit code を判定する。
exit 2 = block（Claude Code の blocking error）、exit 0 = allow。
"""
import json
import os
import subprocess
import sys

ROOT = sys.argv[1]
HOOK = os.path.join(ROOT, "scripts", "check-approval-token-write.sh")

# (label, command, expect_block)
POSITIVE = [
    ("P01 long form",              'gh pr review --approve 123', True),
    ("P02 short -a",               'gh pr review -a 123', True),
    ("P03 flag interleave",        'gh pr review --repo s977043/plangate --approve', True),
    ("P04 positional+body",        'gh pr review 123 --approve --body "lgtm"', True),
    ("P05 multi space + tab",      'gh  pr   review\t--approve', True),
    ("P06 --approve=true",         'gh pr review --approve=true', True),
    ("P07 env prefix",             'GH_TOKEN=xxx gh pr review --approve 1', True),
    ("P08 command builtin",        'command gh pr review --approve', True),
    ("P09 absolute path",          '/opt/homebrew/bin/gh pr review --approve', True),
    ("P10 sh -c nesting",          'sh -c "gh pr review --approve 1"', True),
    ("P11 eval",                   'eval "gh pr review --approve"', True),
    ("P12 && chain",               'echo hi && gh pr review --approve 1', True),
    ("P13 ; chain",                'echo hi ; gh pr review -a', True),
    ("P14 command substitution",   '$(which gh) pr review --approve', True),
    ("P15 var indirection",        'X=--approve; gh pr review $X', True),
    ("P16 bundled shorthand -ab",  'gh pr review -ab "text"', True),
    ("P17 REST direct",            "gh api repos/o/r/pulls/1/reviews -X POST -f event=APPROVE", True),
    ("P18 GraphQL direct",         "gh api graphql -f query='mutation{addPullRequestReview(input:{event:APPROVE}){clientMutationId}}'", True),
    ("P19 newline separated",      'cd /tmp\ngh pr review --approve', True),
    ("P20 bare (fail-closed)",     'gh pr review 123', True),
    ("P21 quoted tokens",          'gh "pr" "review" "--approve"', True),
    ("P22 xargs",                  'echo 123 | xargs gh pr review --approve', True),
    ("P23 backticks",              'gh pr review `echo --approve`', True),
]

NEGATIVE = [
    ("N01 --comment",              'gh pr review --comment --body "nit"', False),
    ("N02 -c -b",                  'gh pr review -c -b "nit"', False),
    ("N03 --request-changes",      'gh pr review --request-changes --body "fix"', False),
    ("N04 -r -b",                  'gh pr review -r -b "fix"', False),
    ("N05 pr view",                'gh pr view 123', False),
    ("N06 pr list",                'gh pr list --state open', False),
    ("N07 pr create",              'gh pr create --title x --body y', False),
    ("N08 pr diff",                'gh pr diff 123', False),
    ("N09 review --help",          'gh pr review --help', False),
    ("N10 git commit",             'git commit -m "add approve guard"', False),
    ("N11 api read reviews",       'gh api repos/o/r/pulls/1/reviews', False),
    ("N12 pr comment",             'gh pr comment 123 --body "will approve later"', False),
    ("N13 repo flag + comment",    'gh pr review --repo o/r --comment --body "x"', False),
    ("N14 pr checks",              'gh pr checks 123', False),
    ("N15 grep for approve",       'grep -rn "pr review" scripts/', False),
    ("N16 body mentions -a",       'gh pr review --comment --body "-a is banned"', False),
]

REGRESSION = [
    ("R01 token write blocked",    'echo "{}" > docs/working/TASK-0900/approvals/c3.json', True),
    ("R02 token read allowed",     'cat docs/working/TASK-0900/approvals/c3.json', False),
]


def run(cmd):
    payload = json.dumps({"tool_name": "Bash", "tool_input": {"command": cmd}})
    env = {k: v for k, v in os.environ.items()
           if not k.startswith("PLANGATE_")}
    p = subprocess.run(["sh", HOOK], input=payload, capture_output=True,
                       text=True, env=env)
    return p.returncode, p.stderr.strip()


def main():
    fails = 0
    for group, cases in (("POSITIVE (must block)", POSITIVE),
                         ("NEGATIVE (must pass)", NEGATIVE),
                         ("REGRESSION (token write)", REGRESSION)):
        print("=" * 72)
        print(group)
        print("=" * 72)
        for label, cmd, expect_block in cases:
            rc, err = run(cmd)
            blocked = (rc == 2)
            ok = (blocked == expect_block)
            if not ok:
                fails += 1
            print(f"{'PASS' if ok else 'FAIL':4}  {label:28} rc={rc} "
                  f"blocked={blocked} expect={expect_block}")
            if not ok and err:
                print(f"        stderr: {err.splitlines()[0] if err else ''}")
    print()
    print(f"TOTAL FAILURES: {fails}")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
