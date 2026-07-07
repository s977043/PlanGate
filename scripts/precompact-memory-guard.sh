#!/bin/sh
# precompact-memory-guard.sh -- PreCompact hook: current-state.md staleness check
# TASK issue #742
#
# staged in scripts/ root (non-HO). Actual wiring (install into scripts/hooks/
# + .claude/settings.json PreCompact registration) is Human-applied via
# scripts/apply-precompact-guard.sh.
#
# spec: docs/ai/precompact-memory-guard.md
#
# Usage:
#   PLANGATE_HOOK_TASK=TASK-XXXX sh scripts/precompact-memory-guard.sh
#
# Env:
#   PLANGATE_HOOK_TASK               task id to inspect (unset -> silent exit 0)
#   PLANGATE_PRECOMPACT_MAX_AGE_MIN  staleness threshold minutes (default 120)
#   PLANGATE_PRECOMPACT_BLOCK        1 to opt in to block (default warn only)
#   PLANGATE_TEST_MODE               1 to allow test time injection
#   PLANGATE_TEST_NOW                epoch seconds "now" when TEST_MODE=1

set -eu

REPO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
WORKING_DIR="$REPO_ROOT/docs/working"

_log_prefix='[Hook PreCompact-MG]'

# read stdin (PreCompact hook JSON) but discard; guard against no-stdin/tty
if [ ! -t 0 ]; then
  _stdin=$(cat 2>/dev/null || true)
fi

task_id="${PLANGATE_HOOK_TASK:-}"

# no TASK context -> silent (zero false-positive design core)
if [ -z "$task_id" ]; then
  exit 0
fi

# task_id format validation (check-forbidden-files.sh pattern + traversal guard):
#   - must match TASK-* (silent SKIP otherwise, same as existing hooks)
#   - must not contain path separators or ".." (path traversal guard --
#     PLANGATE_HOOK_TASK is interpolated into a filesystem path below)
case "$task_id" in
  */*|*..*) exit 0 ;;
  TASK-*) ;;
  *) exit 0 ;;
esac

max_age_min="${PLANGATE_PRECOMPACT_MAX_AGE_MIN:-120}"
block_mode="${PLANGATE_PRECOMPACT_BLOCK:-0}"

_now() {
  if [ "${PLANGATE_TEST_MODE:-0}" = "1" ] && [ -n "${PLANGATE_TEST_NOW:-}" ]; then
    printf '%s' "$PLANGATE_TEST_NOW"
  else
    date -u '+%s'
  fi
}

_mtime_epoch() {
  # BSD (macOS) / GNU both
  if stat -f '%m' "$1" >/dev/null 2>&1; then
    stat -f '%m' "$1"
  else
    stat -c '%Y' "$1"
  fi
}

target="$WORKING_DIR/$task_id/current-state.md"
warnings=""

_add_warning() {
  warnings="${warnings}${warnings:+; }$1"
  printf '%s WARN: %s\n' "$_log_prefix" "$1" >&2
}

if [ ! -f "$target" ]; then
  _add_warning "current-state.md not found (task=$task_id, path=docs/working/$task_id/current-state.md)"
else
  _now_epoch=$(_now)
  _mtime=$(_mtime_epoch "$target" 2>/dev/null || echo "$_now_epoch")
  _age_min=$(( (_now_epoch - _mtime) / 60 ))
  if [ "$_age_min" -ge "$max_age_min" ]; then
    _add_warning "current-state.md last updated ${_age_min} min ago (threshold ${max_age_min} min) (task=$task_id)"
  fi

  if grep -q 'PENDING-VERIFY' "$target" 2>/dev/null; then
    _add_warning "current-state.md still has PENDING-VERIFY entries. Finalize before compact or record as explicit carryover (task=$task_id)"
  fi
fi

if [ -n "$warnings" ]; then
  if [ "$block_mode" = "1" ]; then
    printf '%s BLOCK (PLANGATE_PRECOMPACT_BLOCK=1): %s\n' "$_log_prefix" "$warnings" >&2
    exit 2
  fi
  printf '%s review working-context freshness before compact.\n' "$_log_prefix" >&2
  exit 0
fi

exit 0
