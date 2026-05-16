#!/bin/sh
# check-plan-hash.sh — Hook EH-3: plan_hash 改竄検知
#
# approvals/c3.json の plan_hash と現 plan.md の SHA-256 を突合。
# 不一致なら C-3 承認後に plan が改変されたことを示す → 違反。
#
# Usage:
#   sh scripts/hooks/check-plan-hash.sh <TASK-XXXX>
#   PLANGATE_HOOK_TASK=TASK-XXXX sh scripts/hooks/check-plan-hash.sh
#
# Modes:
#   default                       warning（exit 0）
#   PLANGATE_HOOK_STRICT=1        違反時 exit 1（block）
#   PLANGATE_BYPASS_HOOK=1        常時 exit 0
#
# 監査: docs/working/_audit/hook-events.log
#
# Issue #169 / TASK-0056

set -eu

REPO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
WORKING_DIR="$REPO_ROOT/docs/working"
AUDIT_LOG="$WORKING_DIR/_audit/hook-events.log"

log_event() {
  level=$1
  msg=$2
  mkdir -p "$(dirname "$AUDIT_LOG")"
  ts=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
  printf '%s\t%s\tcheck-plan-hash\t%s\t%s\n' "$ts" "$level" "${task_id:-${PLANGATE_HOOK_TASK:--}}" "$msg" >>"$AUDIT_LOG"
}

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

# bypass
if [ "${PLANGATE_BYPASS_HOOK:-0}" = "1" ]; then
  log_event "BYPASS" "PLANGATE_BYPASS_HOOK=1 set"
  printf '[Hook EH-3] BYPASS\n'
  exit 0
fi

# TASK / 対象ファイル resolution
# codebase 慣行（check-forbidden-files.sh）に合わせ env → 位置引数の順。
task_id=${PLANGATE_HOOK_TASK:-${1:-}}
target_file=${PLANGATE_HOOK_FILE:-${2:-}}

# PreToolUse hook では Claude Code が stdin に JSON（tool_input.file_path）を
# 渡す。env / 引数で未指定なら stdin JSON から対象パスを補完する（最終手段）。
if [ -z "$target_file" ] && [ ! -t 0 ]; then
  _stdin=$(cat 2>/dev/null || true)
  if [ -n "$_stdin" ]; then
    # V-3/Gemini 指摘: sed の貪欲マッチは「最後の "file_path"」を拾い、
    # 偽プロパティ注入で plan.md 判定を回避され得る。jq で正規パス
    # (.tool_input.file_path) を優先抽出し、無ければ「最初に出現する」
    # file_path を grep -o（非貪欲・出現順）で取得する。
    if command -v jq >/dev/null 2>&1; then
      target_file=$(printf '%s' "$_stdin" \
        | jq -r '.tool_input.file_path // .file_path // empty' 2>/dev/null \
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

# P4(d) ファイルパス感応型ガード（TASK-0070 / C-3 F1-b 採用 / Gemini レビュー）:
#   - TASK 文脈なし & 対象が plan.md → BLOCK（C-3 承認後の plan 改変を
#     TASK 文脈を消して通す攻撃を阻止。Gemini 相談 Case 1）
#   - TASK 文脈なし & plan.md 以外 → SKIP（汎用 Edit/Write を許可。
#     check-forbidden-files.sh と同じ「no task→skip」慣行。Case 2）
#   - PLANGATE_HOOK_STRICT=1 は従来どおり no-task を一律 block（後方互換）
if [ -z "$task_id" ]; then
  # 正規化（V-3/Gemini 指摘）: 末尾空白除去 + 小文字化で plan.md 判定回避を防ぐ
  #   - macOS は既定で大文字小文字非区別 → PLAN.md で OS 上は plan.md 改変可能
  #   - "plan.md "（末尾空白）等の表記揺れも plan.md として扱う
  _tf_lc=$(printf '%s' "$target_file" | sed 's/[[:space:]]*$//' | tr 'A-Z' 'a-z')
  case "$_tf_lc" in
    */plan.md|plan.md)
      reason="plan.md edited without TASK context (EH-3 bypass guard): $target_file"
      log_event "VIOLATION" "$reason"
      printf '[Hook EH-3] BLOCK: plan.md edited without TASK context.\n' >&2
      printf '  target: %s\n' "$target_file" >&2
      printf '  Set PLANGATE_HOOK_TASK=TASK-XXXX to allow plan.md edits.\n' >&2
      exit 2
      ;;
  esac
  if [ "${PLANGATE_HOOK_STRICT:-0}" = "1" ]; then
    printf 'Usage: %s <TASK-XXXX>  (or set PLANGATE_HOOK_TASK)\n' "$0" >&2
    exit 2
  fi
  reason="no task_id; non-plan target (${target_file:-unknown}) — skipped"
  log_event "SKIP" "$reason"
  printf '[Hook EH-3 SKIP] %s\n' "$reason"
  exit 0
fi

case "$task_id" in
  TASK-*) ;;
  *)
    printf 'error: invalid task_id: %s\n' "$task_id" >&2
    exit 2
    ;;
esac

plan_file="$WORKING_DIR/$task_id/plan.md"
c3_file="$WORKING_DIR/$task_id/approvals/c3.json"

if [ ! -f "$plan_file" ]; then
  reason="plan.md not found: $plan_file"
  log_event "SKIP" "$reason"
  printf '[Hook EH-3 SKIP] %s\n' "$reason"
  exit 0
fi

if [ ! -f "$c3_file" ]; then
  reason="c3.json not found: $c3_file (no approval to compare against)"
  log_event "SKIP" "$reason"
  printf '[Hook EH-3 SKIP] %s\n' "$reason"
  exit 0
fi

# c3.json から plan_hash を抽出
recorded_hash=$(grep '"plan_hash"' "$c3_file" 2>/dev/null \
  | sed 's/.*"plan_hash"[[:space:]]*:[[:space:]]*"sha256:\([0-9a-f]*\)".*/\1/' || echo "")

if [ -z "$recorded_hash" ]; then
  reason="plan_hash not found in c3.json"
  log_event "SKIP" "$reason"
  printf '[Hook EH-3 SKIP] %s\n' "$reason"
  exit 0
fi

current_hash=$(sha256_of "$plan_file")

if [ "$recorded_hash" = "$current_hash" ]; then
  log_event "PASS" "plan_hash matches"
  printf '[Hook EH-3 PASS] plan_hash matches current plan.md\n'
  exit 0
fi

reason="plan_hash mismatch: recorded=$recorded_hash, current=$current_hash"
log_event "VIOLATION" "$reason"

if [ "${PLANGATE_HOOK_STRICT:-0}" = "1" ]; then
  printf '[Hook EH-3 BLOCK] plan.md was modified after C-3 approval.\n' >&2
  printf '  Recorded: sha256:%s\n' "$recorded_hash" >&2
  printf '  Current : sha256:%s\n' "$current_hash" >&2
  printf '  Action  : Re-approval required (update c3.json plan_hash) or revert plan.md.\n' >&2
  exit 1
fi

printf '[Hook EH-3 WARNING] plan_hash mismatch (plan.md modified post-C-3)\n' >&2
printf '  Recorded: sha256:%s\n' "$recorded_hash" >&2
printf '  Current : sha256:%s\n' "$current_hash" >&2
exit 0
