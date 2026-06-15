#!/bin/sh
# apply-task-0130-working-context.sh
# TASK-0130 (#544 Phase1): working-context.md の plan.md 必須要素に AEE 条項を追記する。
#
# working-context.md は Hardening Override 対象（.claude/rules/*.md）。
# AI はこのスクリプトを生成するのみ・実行は人間（[[HO適用スクリプトAI実行禁止]]）。
#
# Usage:
#   sh scripts/apply-task-0130-working-context.sh            # dry-run（差分プレビューのみ）
#   sh scripts/apply-task-0130-working-context.sh --apply    # 実適用（人間が実行）
set -eu

REPO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TARGET="$REPO_ROOT/.claude/rules/working-context.md"
APPLY=0
[ "${1:-}" = "--apply" ] && APPLY=1

ANCHOR="- Testing Strategy（Unit / Integration / E2E / Verification Automation）"
# 既適用チェック（冪等）
if grep -q "Stop Condition / Resume Condition / Replan Triggers" "$TARGET"; then
  echo "[skip] already applied (AEE 条項が既に存在)"
  exit 0
fi

python3 - "$TARGET" "$APPLY" <<'PY'
import sys
target, apply = sys.argv[1], sys.argv[2]=="1"
s=open(target).read()
anchor="- Testing Strategy（Unit / Integration / E2E / Verification Automation）"
addition=anchor+"\n- Stop Condition / Resume Condition / Replan Triggers（機械値）/ Revert Policy / Loop Scope（承認済み実行境界 AEE 条項。#544 Phase1=明文化・強制は Phase2/#543）\n- Loop Attempts（exec 中の最小試行ログ欄。#544 Phase1）"
if anchor not in s:
    print("[error] anchor 行が見つかりません:", anchor); sys.exit(2)
new=s.replace(anchor, addition, 1)
if apply:
    open(target,"w").write(new)
    print("[applied] working-context.md に AEE 条項を追記しました")
else:
    print("=== DRY-RUN 差分プレビュー ===")
    print("  " + anchor)
    print("+ - Stop Condition / Resume Condition / Replan Triggers（機械値）/ Revert Policy / Loop Scope（...AEE 条項...）")
    print("+ - Loop Attempts（exec 中の最小試行ログ欄。#544 Phase1）")
    print("=== --apply で実適用（人間が実行）===")
PY
