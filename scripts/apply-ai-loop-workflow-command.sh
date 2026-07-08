#!/bin/sh
# apply-ai-loop-workflow-command.sh -- /ai-loop-workflow コマンド新設
#
# .claude/commands/ は Hardening Override (HO) 対象（self-mod guard）。
# AI は --dry-run のみ実行可。--apply の実行は Human-owned
# （.claude/rules/responsibility-classes.md）。
#
# 背景: /ai-dev-workflow（PlanGate 本番フロー入口）と対をなす ai-loop の
# 明示起動入口。skill `ai-loop-cycle`（1 サイクル実行単位・モデル起動）は
# 改名せず、コマンド層で対称性を取る（Human 設計決定 2026-07-08）。
# 適用後は scripts/sync-plugin-plangate.sh で plugin/plangate/commands/ へ同期
# され、導入先では /plangate:ai-loop-workflow として起動できる。
#
# Usage:
#   sh scripts/apply-ai-loop-workflow-command.sh --dry-run
#   sh scripts/apply-ai-loop-workflow-command.sh --apply   # Human 実行のみ
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
DST="$ROOT/.claude/commands/ai-loop-workflow.md"
SRC="$ROOT/docs/working/_prompts/ai-loop-workflow-command.md"
[ $# -eq 1 ] || { echo "usage: $0 --dry-run|--apply" >&2; exit 1; }
[ "$1" = "--dry-run" ] || [ "$1" = "--apply" ] || { echo "usage: $0 --dry-run|--apply" >&2; exit 1; }
[ -f "$SRC" ] || { echo "error: source not found: $SRC" >&2; exit 2; }
if [ -f "$DST" ] && cmp -s "$SRC" "$DST"; then
  echo "[apply] SKIP: 適用済み（差分なし）"; exit 0
fi
if [ "$1" = "--dry-run" ]; then
  echo "[dry-run] COPY 予定: $SRC -> $DST"
  if [ -f "$DST" ]; then
    diff -u "$DST" "$SRC" | head -40 || true
  else
    echo "[dry-run] 新規作成"
  fi
  exit 0
elif [ "$1" = "--apply" ]; then
  [ -d "$(dirname "$DST")" ] || { echo "error: .claude/commands/ 不在" >&2; exit 2; }
  cp "$SRC" "$DST"
  echo "[apply] 作成: $DST"
  echo "[apply] 次に: sh scripts/sync-plugin-plangate.sh で plugin へ同期"
  exit 0
fi
echo "usage: $0 --dry-run|--apply" >&2; exit 1
