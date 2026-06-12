#!/bin/sh
# apply-task-0128-token-guard-wiring.sh — TASK-0128 R-002
# check-approval-token-write.sh を .claude/settings.json と settings.example.json の
# PreToolUse に Edit|Write + Bash の2 matcher で配線する。
#
# settings*.json は self-mod ガード対象（AI 改変不可）。本スクリプトを AI が用意し、
# Human が dry-run 確認のうえ適用する（責務4分類: settings 適用は Human-owned）。
#
# 使い方:
#   sh scripts/apply-task-0128-token-guard-wiring.sh --dry-run
#   sh scripts/apply-task-0128-token-guard-wiring.sh
#
# 冪等: 既に check-approval-token-write が配線済みなら何もしない。
set -eu

REPO_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
DRY_RUN=0
if [ $# -gt 0 ]; then
  if [ "$1" = "--dry-run" ] && [ $# -eq 1 ]; then DRY_RUN=1
  else echo "ERROR: Usage: $0 [--dry-run]" >&2; exit 1; fi
fi
command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 が必要です"; exit 1; }

for f in .claude/settings.json .claude/settings.example.json; do
  [ -f "$REPO_ROOT/$f" ] || { echo "ERROR: $f が見つかりません"; exit 1; }
done

python3 - "$REPO_ROOT" "$DRY_RUN" <<'PY'
import json, sys, difflib, os

repo, dry = sys.argv[1], sys.argv[2] == "1"
CMD = "sh ${CLAUDE_PROJECT_DIR}/scripts/check-approval-token-write.sh"
ENTRIES = [
    {"matcher": "Edit|Write", "hooks": [{"type": "command", "command": CMD}]},
    {"matcher": "Bash",       "hooks": [{"type": "command", "command": CMD}]},
]

changed_any = False
for rel in (".claude/settings.json", ".claude/settings.example.json"):
    path = os.path.join(repo, rel)
    orig = open(path).read()
    d = json.loads(orig)
    pre = d.setdefault("hooks", {}).setdefault("PreToolUse", [])
    already = any(
        "check-approval-token-write.sh" in h.get("command", "")
        for e in pre for h in e.get("hooks", [])
    )
    if already:
        sys.stderr.write(f"SKIP: {rel} は既に配線済み\n")
        continue
    pre.extend(ENTRIES)
    new = json.dumps(d, ensure_ascii=False, indent=2) + "\n"
    changed_any = True
    if dry:
        diff = difflib.unified_diff(orig.splitlines(True), new.splitlines(True),
                                    fromfile=rel, tofile=rel + " (after)")
        sys.stdout.write("".join(diff))
    else:
        open(path, "w").write(new)
        sys.stderr.write(f"[applied] {rel} に token-guard を配線しました\n")

if not changed_any and not dry:
    sys.stderr.write("nothing to do (既に配線済み)\n")
PY
