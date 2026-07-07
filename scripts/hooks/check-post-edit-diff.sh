#!/bin/sh
# check-post-edit-diff.sh — Hook (proposed EH-10 候補): PostToolUse 軽量品質チェック
#
# Edit / Write / MultiEdit 直後に `git diff --check` のみを実行し、
# whitespace error（trailing whitespace 等）/ leftover conflict marker
# (<<<<<<< / ======= / >>>>>>>) を検出する。lint やテストは実行しない
# （重い処理は Stop / CI に委ねる。issue #760 スコープ）。
#
# Claude Code PostToolUse hook 仕様の注意点（重要）:
#   - PostToolUse は「ツール実行後」に発火するため、この hook 自体は
#     直前の Edit/Write を取り消せない（exit 2 でも "tool already ran"）。
#     本 hook の役割は「次のターンで Claude が気づいて直せるように
#     stderr へフィードバックする」ことに限定される。
#   - stdin には Claude Code から JSON（tool_name / tool_input.file_path 等）
#     が渡される想定（check-plan-hash.sh / check-forbidden-files.sh と同じ
#     env-first・stdin-fallback の流儀を踏襲）。
#
# 入力（優先順）:
#   PLANGATE_HOOK_FILE   編集対象ファイルの相対 path（明示があれば最優先）
#   stdin JSON           tool_input.file_path（jq があれば優先、無ければ grep）
#   (未解決)             リポジトリ全体の working tree 差分を対象にする
#
# Modes:
#   default                       warning（exit 0、stdout に警告のみ）
#   PLANGATE_HOOK_STRICT=1        違反検出時 exit 2（stderr で Claude にフィードバック。
#                                 ツール実行そのものは取り消せない点に注意）
#   PLANGATE_BYPASS_HOOK=1        常時 exit 0
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
  printf '%s\t%s\tcheck-post-edit-diff\t-\t%s\n' "$ts" "$level" "$msg" >>"$AUDIT_LOG" 2>/dev/null || true
}

# bypass
if [ "${PLANGATE_BYPASS_HOOK:-0}" = "1" ]; then
  log_event "BYPASS" "PLANGATE_BYPASS_HOOK=1 set"
  printf '[Hook check-post-edit-diff] BYPASS\n'
  exit 0
fi

# 非 git 環境では no-op（false-positive 防止。plangate 以外のプロジェクトへ
# コピーされた場合や、git 未初期化のワークスペースでも安全に動く）
if ! git -C "$REPO_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  exit 0
fi

# ---- 対象ファイルの解決（env → stdin JSON → 未解決） ----
target_file=${PLANGATE_HOOK_FILE:-}

if [ -z "$target_file" ] && [ ! -t 0 ]; then
  _stdin=$(cat 2>/dev/null || true)
  if [ -n "$_stdin" ]; then
    if command -v jq >/dev/null 2>&1; then
      target_file=$(printf '%s' "$_stdin" \
        | jq -r '.tool_input.file_path // empty' 2>/dev/null \
        | head -1)
    fi
    if [ -z "$target_file" ]; then
      target_file=$(printf '%s' "$_stdin" \
        | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' \
        | head -1 \
        | sed 's/.*"\([^"]*\)"$/\1/')
    fi
  fi
fi

# ---- git diff --check 実行（scope: target_file があればそれのみ、無ければ全体）----
diff_output=""
diff_rc=0
if [ -n "$target_file" ]; then
  # リポジトリルート相対 / 絶対どちらの表記でも受け付ける
  case "$target_file" in
    /*) rel_target=${target_file#"$REPO_ROOT"/} ;;
    *)  rel_target=$target_file ;;
  esac
  diff_output=$(git -C "$REPO_ROOT" diff --check -- "$rel_target" 2>/dev/null) || diff_rc=$?
else
  diff_output=$(git -C "$REPO_ROOT" diff --check 2>/dev/null) || diff_rc=$?
fi

# git diff --check は問題を検出すると非 0 を返す（"trailing whitespace" /
# "leftover conflict marker" 等）。diff 対象が無い場合も非 0 だが出力は空。
if [ "$diff_rc" -eq 0 ] || [ -z "$diff_output" ]; then
  log_event "PASS" "no whitespace error / conflict marker (target=${target_file:-<worktree>})"
  printf '[Hook check-post-edit-diff PASS] no whitespace error / conflict marker detected\n'
  exit 0
fi

reason="git diff --check flagged issue(s) in ${target_file:-<worktree>}: $(printf '%s' "$diff_output" | tr '\n' ' | ')"
log_event "VIOLATION" "$reason"

if [ "${PLANGATE_HOOK_STRICT:-0}" = "1" ]; then
  printf '[Hook check-post-edit-diff BLOCK] whitespace error / conflict marker detected (tool already ran; fix before continuing)\n' >&2
  printf '%s\n' "$diff_output" >&2
  exit 2
fi

printf '[Hook check-post-edit-diff WARNING] whitespace error / conflict marker detected\n' >&2
printf '%s\n' "$diff_output" >&2
exit 0
