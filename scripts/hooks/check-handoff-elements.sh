#!/bin/sh
# check-handoff-elements.sh — Hook EHS-2: handoff.md 必須 6 要素チェック
#
# Usage:
#   sh scripts/hooks/check-handoff-elements.sh <handoff.md path>
#   sh scripts/hooks/check-handoff-elements.sh TASK-XXXX
#
# Modes:
#   default                       warning + exit 0
#   PLANGATE_HOOK_STRICT=1        違反時 exit 1（block）
#   PLANGATE_BYPASS_HOOK=1        常時 exit 0
#
# 必須 6 要素: Markdown 内に "## 1." 〜 "## 6." の見出しが揃っていること。
# (.claude/rules/working-context.md Rule 5 / docs/working/templates/handoff.md)
#
# Issue #157 / TASK-0048

set -eu

REPO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
WORKING_DIR="$REPO_ROOT/docs/working"
AUDIT_LOG="$WORKING_DIR/_audit/hook-events.log"

if [ $# -eq 0 ]; then
  printf 'Usage: %s <handoff.md path | TASK-XXXX>\n' "$0" >&2
  exit 2
fi

target=$1

case "$target" in
  TASK-*)
    handoff_path="$WORKING_DIR/$target/handoff.md"
    ;;
  *)
    handoff_path=$target
    ;;
esac

log_event() {
  level=$1
  msg=$2
  mkdir -p "$(dirname "$AUDIT_LOG")"
  ts=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
  printf '%s\t%s\tcheck-handoff-elements\t%s\t%s\n' "$ts" "$level" "$target" "$msg" >>"$AUDIT_LOG"
}

if [ "${PLANGATE_BYPASS_HOOK:-0}" = "1" ]; then
  log_event "BYPASS" "PLANGATE_BYPASS_HOOK=1 set"
  printf '[Hook EHS-2] BYPASS\n'
  exit 0
fi

if [ ! -f "$handoff_path" ]; then
  reason="handoff.md not found: $handoff_path"
  log_event "VIOLATION" "$reason"
  printf '[Hook EHS-2 %s] %s\n' "$([ "${PLANGATE_HOOK_STRICT:-0}" = "1" ] && echo BLOCK || echo WARN)" "$reason" >&2
  if [ "${PLANGATE_HOOK_STRICT:-0}" = "1" ]; then
    exit 1
  fi
  exit 0
fi

count=$(grep -cE "^## [1-6]\." "$handoff_path" || echo 0)

if [ "$count" -lt 6 ]; then
  reason="handoff.md has only $count of 6 required sections"
  log_event "VIOLATION" "$reason"
  if [ "${PLANGATE_HOOK_STRICT:-0}" = "1" ]; then
    printf '[Hook EHS-2 BLOCK] %s\n' "$reason" >&2
    printf 'Required sections: ## 1.〜## 6. (要件適合確認 / 既知課題 / V2 候補 / 妥協点 / 引き継ぎ文書 / テスト結果)\n' >&2
    exit 1
  fi
  printf '[Hook EHS-2 WARNING] %s\n' "$reason" >&2
  exit 0
fi

log_event "PASS" "6/6 sections present"
printf '[Hook EHS-2 PASS] handoff.md has all 6 required sections\n'
exit 0
