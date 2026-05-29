#!/bin/sh
# check-git-add-scope.sh — git pre-commit hook for scope 外ファイル混入検知
#
# TASK-0119 (#362)
#
# 検知対象:
#   1. docs/working/_audit/skip-decision-log.jsonl に acknowledged_by:null エントリがある状態で staged
#   2. staged ファイルに <claude-mem-context> を含む
#      (TASK-0113 check-ai-memory-pollution.sh が未インストールの場合の補完)
#   3. 現在の TASK (PLANGATE_HOOK_TASK 環境変数) と異なる TASK-XXXX の eval-result.* が staged
#
# 責務分界 (T-01 調査):
#   - <claude-mem-context> 検知: TASK-0113 check-ai-memory-pollution.sh が主担当
#     本スクリプトは TASK-0113 未インストール時の補完として重複検知を許容
#   - skip-decision-log 未追認 / 他 TASK eval-result: 本スクリプト専担
#
# 使用例:
#   .git/hooks/pre-commit 経由で自動起動 (install: sh scripts/install-pre-commit.sh)
#   PLANGATE_SKIP_SCOPE_CHECK=1 git commit  # 全スキップ

set -eu

# === Allowlist: 環境変数による全スキップ ===
if [ "${PLANGATE_SKIP_SCOPE_CHECK:-0}" = "1" ]; then
  exit 0
fi

REPO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACMR 2>/dev/null || true)

if [ -z "$STAGED_FILES" ]; then
  exit 0
fi

VIOLATIONS=""

# =========================================================
# 検知 1: skip-decision-log.jsonl に未追認エントリがある状態で staged
# =========================================================
SKIP_LOG_PATH="docs/working/_audit/skip-decision-log.jsonl"
if printf '%s\n' "$STAGED_FILES" | grep -qF "$SKIP_LOG_PATH"; then
  # staged content を取得して未追認エントリを検索
  staged_content=$(git show ":$SKIP_LOG_PATH" 2>/dev/null || true)
  if [ -n "$staged_content" ]; then
    if printf '%s' "$staged_content" | grep -qF '"acknowledged_by":null'; then
      VIOLATIONS="${VIOLATIONS}[scope-guard:skip-log-unack] ${SKIP_LOG_PATH}: acknowledged_by:null エントリが未追認のまま staged|"
    fi
  fi
fi

# =========================================================
# 検知 2: staged ファイルに <claude-mem-context> を含む
# (TASK-0113 check-ai-memory-pollution.sh 未インストール時の補完)
# =========================================================
for file in $STAGED_FILES; do
  # バイナリ / 大容量ファイルはスキップ
  if [ -f "$REPO_ROOT/$file" ]; then
    size=$(wc -c < "$REPO_ROOT/$file" 2>/dev/null || echo 0)
    if [ "$size" -gt 1048576 ]; then
      continue
    fi
    if head -c 512 "$REPO_ROOT/$file" 2>/dev/null | LC_ALL=C grep -q $'\0' 2>/dev/null; then
      continue
    fi
  fi

  staged_content=$(git show ":$file" 2>/dev/null || true)
  if printf '%s' "$staged_content" | grep -qF '<claude-mem-context>'; then
    VIOLATIONS="${VIOLATIONS}[scope-guard:claude-mem] ${file}: <claude-mem-context> を含む (TASK-0113 インストール推奨)|"
  fi
done

# =========================================================
# 検知 3: 現在の TASK と異なる TASK-XXXX の eval-result.* が staged
# =========================================================
CURRENT_TASK="${PLANGATE_HOOK_TASK:-}"
for file in $STAGED_FILES; do
  # eval-result.* ファイルか確認
  case "$file" in
    docs/working/TASK-*/eval-result.*)
      # ファイルパスから TASK 番号を抽出
      file_task=$(printf '%s' "$file" | sed 's|docs/working/\(TASK-[0-9]*\)/.*|\1|')
      if [ -n "$CURRENT_TASK" ] && [ "$file_task" != "$CURRENT_TASK" ]; then
        VIOLATIONS="${VIOLATIONS}[scope-guard:eval-result] ${file}: 現在の TASK (${CURRENT_TASK}) と異なる ${file_task} の eval-result が staged|"
      elif [ -z "$CURRENT_TASK" ]; then
        # PLANGATE_HOOK_TASK 未設定時は警告のみ（任意 staged の可能性あるため exit 1 しない）
        printf '[scope-guard] INFO: PLANGATE_HOOK_TASK 未設定。eval-result scope チェックをスキップ: %s\n' "$file" >&2
      fi
      ;;
  esac
done

# =========================================================
# 結果出力
# =========================================================
if [ -z "$VIOLATIONS" ]; then
  exit 0
fi

printf '\n[scope-guard] scope 外ファイル混入を検知しました:\n\n' >&2
printf '%s' "$VIOLATIONS" | tr '|' '\n' | while read -r v; do
  [ -z "$v" ] && continue
  printf '  %s\n' "$v" >&2
done

printf '\n[scope-guard] 対処:\n' >&2
printf '  1. 対象ファイルを unstage:\n' >&2
printf '     git restore --staged <file>\n' >&2
printf '  2. 全スキップ (allowlist):\n' >&2
printf '     PLANGATE_SKIP_SCOPE_CHECK=1 git commit\n' >&2
printf '  3. skip-decision-log 未追認エントリ解消:\n' >&2
printf '     bin/plangate skip-acknowledge\n' >&2
printf '\n  詳細: docs/ai/git-add-scope-guard.md\n' >&2

exit 1
