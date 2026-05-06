#!/bin/sh
# check-metrics-privacy.sh — Hook EH-8: Metrics Privacy 違反 block
#
# Usage:
#   sh scripts/hooks/check-metrics-privacy.sh                 (auto-detect staged files via git)
#   sh scripts/hooks/check-metrics-privacy.sh <file.json>...  (explicit files)
#   PLANGATE_HOOK_FILES="a.json b.ndjson" sh scripts/hooks/check-metrics-privacy.sh
#
# 検査:
#   1. docs/working/_metrics/events.ndjson が staging に含まれていないこと
#      （metrics-privacy.md §8: public repo に commit させない）
#   2. NDJSON / JSON ファイル内に metrics-privacy.md §4 Forbidden カテゴリの
#      フィールド（file_path, stack_trace, command_output, raw_response,
#      user_prompt, system_prompt 等）が含まれていないこと
#
# Modes:
#   default                       warning（exit 0）
#   PLANGATE_HOOK_STRICT=1        違反時 exit 1（commit / push block）
#   PLANGATE_BYPASS_HOOK=1        常時 exit 0
#
# 適用対象:
#   - PreToolUse hook（Edit / Write / Bash on git add）として登録可
#   - pre-commit として local hook に流用可
#   - CI で `git diff --cached --name-only` の出力に対して実行
#
# 監査: docs/working/_audit/hook-events.log
#
# Issue #195 (Metrics v1) / v8.6.0 改善

set -eu

REPO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
AUDIT_LOG="$REPO_ROOT/docs/working/_audit/hook-events.log"

# metrics-privacy.md §4 Forbidden categories のキー名
# regex 互換: word boundary を考慮、JSON key としての出現のみ検出
FORBIDDEN_KEYS='"file_path"|"file_paths"|"stack_trace"|"stacktrace"|"command_output"|"stdout"|"stderr"|"raw_response"|"raw_request"|"api_key"|"user_prompt"|"system_prompt"|"prompt_text"|"absolute_path"'
EVENTS_LOG_REL="docs/working/_metrics/events.ndjson"

log_event() {
  level=$1
  msg=$2
  mkdir -p "$(dirname "$AUDIT_LOG")"
  ts=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
  printf '%s\t%s\tcheck-metrics-privacy\t-\t%s\n' "$ts" "$level" "$msg" >>"$AUDIT_LOG"
}

if [ "${PLANGATE_BYPASS_HOOK:-0}" = "1" ]; then
  log_event "BYPASS" "PLANGATE_BYPASS_HOOK=1 set"
  printf '[Hook EH-8] BYPASS\n'
  exit 0
fi

# ---- ファイル一覧の決定 ----
# 優先順: 明示引数 > PLANGATE_HOOK_FILES > git staged
files=""
if [ "$#" -gt 0 ]; then
  files="$*"
elif [ -n "${PLANGATE_HOOK_FILES:-}" ]; then
  files="$PLANGATE_HOOK_FILES"
elif [ -d "$REPO_ROOT/.git" ] || [ -f "$REPO_ROOT/.git" ]; then
  files=$(git -C "$REPO_ROOT" diff --cached --name-only --diff-filter=ACM 2>/dev/null || true)
fi

# ---- Check 1: events.ndjson が staging に含まれていないか ----
violations=""
events_ndjson_staged=0

if [ -n "$files" ]; then
  # newline / space 両対応で含有検査
  case " $(echo "$files" | tr '\n' ' ') " in
    *" $EVENTS_LOG_REL "*)
      events_ndjson_staged=1
      ;;
  esac
fi

if [ "$events_ndjson_staged" = "1" ]; then
  violations="${violations}events.ndjson is staged for commit (privacy §8 violation); "
fi

# ---- Check 2: 各 JSON / NDJSON ファイルに Forbidden フィールドが無いか ----
forbidden_hits=""
if [ -n "$files" ]; then
  for f in $files; do
    case "$f" in
      *.json|*.ndjson) ;;
      *) continue ;;
    esac
    case "$f" in
      /*) abs="$f" ;;
      *)  abs="$REPO_ROOT/$f" ;;
    esac
    [ -f "$abs" ] || continue
    # grep -E で Forbidden パターン検出（false positive を避けるため "key": の形式で検出）
    if grep -E "($FORBIDDEN_KEYS)[[:space:]]*:" "$abs" >/dev/null 2>&1; then
      hit=$(grep -oE "($FORBIDDEN_KEYS)" "$abs" | sort -u | tr '\n' ',' | sed 's/,$//')
      forbidden_hits="${forbidden_hits}$f:[$hit]; "
    fi
  done
fi

if [ -n "$forbidden_hits" ]; then
  violations="${violations}forbidden fields detected: $forbidden_hits"
fi

if [ -z "$violations" ]; then
  if [ -z "$files" ]; then
    log_event "PASS" "no staged files to check"
    printf '[Hook EH-8 PASS] no staged files to check\n'
  else
    file_count=$(echo "$files" | tr ' ' '\n' | grep -c -E '\.(json|ndjson)$' || true)
    log_event "PASS" "checked ${file_count} JSON/NDJSON files, no privacy violations"
    printf '[Hook EH-8 PASS] %s JSON/NDJSON files checked, privacy §3/§4 OK\n' "$file_count"
  fi
  exit 0
fi

reason="metrics privacy violation: $violations"
log_event "VIOLATION" "$reason"

if [ "${PLANGATE_HOOK_STRICT:-0}" = "1" ]; then
  printf '[Hook EH-8 BLOCK] %s\n' "$reason" >&2
  printf '  Action 1: events.ndjson は .gitignore 対象です。git restore --staged %s を実行してください。\n' "$EVENTS_LOG_REL" >&2
  printf '  Action 2: Forbidden field を含む JSON は metrics-privacy.md §4 違反です。フィールドを削除してください。\n' >&2
  printf '  Reference: docs/ai/metrics-privacy.md\n' >&2
  exit 1
fi

printf '[Hook EH-8 WARNING] %s\n' "$reason" >&2
exit 0
