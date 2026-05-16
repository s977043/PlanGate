#!/bin/sh
# check-settings-wiring.sh — settings wiring 契約 構造検証（TASK-0080 S1b / V-3 CR-2）
#
# 正本: docs/ai/settings-wiring-contract.md
# grep ではなく JSON 構造（.hooks.PreToolUse[].matcher / hooks[].command）を
# python で検証する（_comment_ 誤検出・別 matcher・無効 JSON を排除）。
#
#   sh scripts/check-settings-wiring.sh [--target user|example]
# exit 0=準拠 / 1=逸脱(不足列挙) / 2=対象不在・無効JSON
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
target=user
case "${1:-}" in --target) target=${2:-user} ;; --target=*) target=${1#--target=} ;; esac
case "$target" in
  user)    F="$ROOT/.claude/settings.json" ;;
  example) F="$ROOT/.claude/settings.example.json" ;;
  *) printf 'error: --target must be user|example\n' >&2; exit 2 ;;
esac
python3 - "$F" "$target" <<'PY'
import json, sys
F, target = sys.argv[1], sys.argv[2]
try:
    with open(F) as fh:
        doc = json.load(fh)
except FileNotFoundError:
    if target == "user":
        print(f"[check-settings] FAIL: {F} 不在（settings 未適用）", file=sys.stderr)
        print("  → sh scripts/apply-claude-settings.sh を実行してください", file=sys.stderr)
        sys.exit(1)
    print(f"[check-settings] FAIL: {F} 不在", file=sys.stderr); sys.exit(2)
except (json.JSONDecodeError, OSError) as e:
    print(f"[check-settings] FAIL: {F} 無効 JSON: {e}", file=sys.stderr); sys.exit(2)

pre = ((doc or {}).get("hooks", {}) or {}).get("PreToolUse", [])
# PreToolUse 内 hooks[].command（_comment_ は無視）を matcher 別に収集
cmds = []
for blk in pre if isinstance(pre, list) else []:
    if not isinstance(blk, dict):
        continue
    matcher = blk.get("matcher", "")
    for h in blk.get("hooks", []) or []:
        if isinstance(h, dict) and h.get("type") == "command":
            cmds.append((matcher, h.get("command", "")))

def has(substr, matcher_re=None):
    import re
    for m, c in cmds:
        if substr in c and (matcher_re is None or re.search(matcher_re, m)):
            return True
    return False

miss = []
checks = [
    ("check-plan-exists.sh", "Edit|Write", "EH-1 plan-exists"),
    ("check-c3-approval.sh", "Edit|Write", "EH-2 c3-approval"),
    ("check-forbidden-files.sh", "Edit|Write", "EH-6 forbidden-files"),
    ("check-plan-hash.sh", "Edit|Write", "EH-3 plan-hash"),
    ("${PLANGATE_HOOK_FILE:-}", "Edit|Write", "EH-3 の PLANGATE_HOOK_FILE 引数(P4(d)/AC-8)"),
    ("check-delegation-commit-boundary.sh", "Bash", "EH-9 delegation-commit-boundary(TASK-0073)"),
]
for sub, mre, label in checks:
    if not has(sub, mre):
        miss.append(label)

if miss:
    for m in miss:
        print(f"[check-settings] 不足: {m}", file=sys.stderr)
    print(f"[check-settings] FAIL: settings wiring 契約 逸脱(target={target})", file=sys.stderr)
    print("  契約: docs/ai/settings-wiring-contract.md / 適用: scripts/apply-claude-settings.sh", file=sys.stderr)
    sys.exit(1)
print(f"[check-settings] PASS: settings wiring 契約準拠(target={target})")
sys.exit(0)
PY
