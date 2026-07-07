#!/bin/sh
# check-stop-diff-status.sh — Hook (proposed EH-11 候補): Stop 軽量 verify
#
# セッション停止時に `git status --short` + `git diff --check` のみを実行し、
# 未コミット差分の一覧と whitespace error / conflict marker の有無を
# 情報提示する。テスト・lint 等の重い処理は一切実行しない（issue #760 スコープ、
# 重い検証は bin/plangate verify / CI に委ねる）。
#
# 【重要】本 hook は常に non-blocking（exit 0 固定）とする。理由:
#   1. Claude Code の Stop hook は `decision:"block"`（または exit code 2）を
#      返すと「Claude の停止を阻止し会話を継続させる」（PostToolUse の
#      block=ツール実行後の警告のみ、とは挙動が異なる）。ドキュメント上
#      ループガード（回数上限等）が明記されておらず、条件判定を誤ると
#      Stop hook が繰り返し発火し続けるリスクがある。
#   2. 完了担保は既に doctor タスクロック（working-context.md 「settings
#      タスクロック」節、Workflow-owned）と V-1/handoff プロセスが担っている。
#      Stop hook で重複して block すると、責務 4 分類（Workflow-owned の
#      完了ゲート）と二重化し、かつ (1) のループリスクを追加で背負うだけで
#      増分の安全性が乏しい。
#   → 本 hook は「情報提示のみ・exit 0 固定」を推奨とし、PLANGATE_HOOK_STRICT
#     によるブロックモードは意図的に提供しない（他の EH hook との非対称は
#     上記 2 点の理由による意図的な設計判断）。
#
# 入力: なし（対象は常にリポジトリ全体の working tree）
#
# 出力: stdout に `git status --short` と `git diff --check` の結果を提示。
#        差分・警告が無い場合も PASS として明示する。
#
# 非 git 環境（.git 不在）では静かに exit 0（no-op）。
#
# 監査: docs/working/_audit/hook-events.log
#
# Issue #760（HO 制約により本ファイルは提示のみ。適用は Human-owned）

set -eu

REPO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
WORKING_DIR="$REPO_ROOT/docs/working"
AUDIT_LOG="$WORKING_DIR/_audit/hook-events.log"

log_event() {
  level=$1
  msg=$2
  mkdir -p "$(dirname "$AUDIT_LOG")" 2>/dev/null || return 0
  ts=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
  printf '%s\t%s\tcheck-stop-diff-status\t-\t%s\n' "$ts" "$level" "$msg" >>"$AUDIT_LOG" 2>/dev/null || true
}

# bypass（他 hook との一貫性のため用意するが、本 hook は non-blocking 固定
# なので実質的には audit ログを出すか出さないかの差のみ）
if [ "${PLANGATE_BYPASS_HOOK:-0}" = "1" ]; then
  log_event "BYPASS" "PLANGATE_BYPASS_HOOK=1 set"
  printf '[Hook check-stop-diff-status] BYPASS\n'
  exit 0
fi

# 非 git 環境では no-op
if ! git -C "$REPO_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  exit 0
fi

status_output=$(git -C "$REPO_ROOT" status --short 2>/dev/null || true)
diff_output=$(git -C "$REPO_ROOT" diff --check 2>/dev/null || true)

printf '[Hook check-stop-diff-status] session stop — lightweight repo status\n'

if [ -z "$status_output" ]; then
  printf '  git status --short: (clean, no uncommitted changes)\n'
else
  printf '  git status --short:\n'
  printf '%s\n' "$status_output" | sed 's/^/    /'
fi

if [ -z "$diff_output" ]; then
  printf '  git diff --check  : PASS (no whitespace error / conflict marker)\n'
  log_event "PASS" "clean status, no diff --check issues"
else
  printf '  git diff --check  : WARNING (whitespace error / conflict marker detected)\n'
  printf '%s\n' "$diff_output" | sed 's/^/    /'
  log_event "WARNING" "diff --check flagged issue(s): $(printf '%s' "$diff_output" | awk 'NR>1{printf " | "} {printf "%s", $0}')"
fi

# non-blocking 固定（設計上の意図的判断。上記コメント参照）
exit 0
