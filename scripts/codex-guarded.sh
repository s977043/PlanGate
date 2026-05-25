#!/bin/sh
# codex-guarded.sh — Codex CLI guarded entrypoint for PlanGate parity (Gap 4 / #336)
#
# Purpose:
#   Codex CLI lacks Claude Code's PreToolUse:Write/Edit hooks. This wrapper
#   gives Codex sessions equivalent protection by running EH-3 (plan_hash) /
#   EH-8 (metrics privacy) / EH-6 (forbidden_files) checks **before and after**
#   the Codex run.
#
# Usage:
#   scripts/codex-guarded.sh --task TASK-XXXX [codex args...]
#   PLANGATE_GUARDED_TASK=TASK-XXXX scripts/codex-guarded.sh [codex args...]
#
# Behavior:
#   1. Resolve TASK ID (from --task / env / cwd)
#   2. Pre-flight (fail-closed):
#      - bin/plangate validate $TASK     (plan_hash integrity)
#      - bin/plangate doctor --check-settings (settings task-lock)
#      - EH-8 metrics privacy on staged files (if any)
#   3. Run codex via scripts/codex-local.sh
#   4. Post-flight (warning):
#      - bin/plangate validate $TASK     (detect drift during session)
#      - Append to docs/working/_audit/codex-guarded.log
#
# Limitations:
#   - This is NOT a physical pre-write hook. Codex can still Write/Edit
#     freely during the session. Post-flight detects drift only.
#   - For physical pre-write enforcement, see Issue #336 long-term plan
#     (Codex CLI plugin/extension once public API is confirmed).
#
# Exit codes:
#   0  success
#   1  pre-flight failed (codex not started)
#   2  post-flight detected drift (codex completed but plan_hash mismatch)

set -eu

REPO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
AUDIT_LOG="$REPO_ROOT/docs/working/_audit/codex-guarded.log"

log_event() {
  level=$1
  msg=$2
  mkdir -p "$(dirname "$AUDIT_LOG")"
  ts=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
  printf '%s\t%s\t%s\t%s\n' "$ts" "$level" "${TASK_ID:--}" "$msg" >> "$AUDIT_LOG"
}

# ── 1. Resolve TASK ID ──
TASK_ID=""
codex_args=""
while [ $# -gt 0 ]; do
  case "$1" in
    --task)
      TASK_ID="${2:-}"
      shift 2
      ;;
    --task=*)
      TASK_ID="${1#--task=}"
      shift
      ;;
    --help|-h)
      sed -n '2,32p' "$0"
      exit 0
      ;;
    *)
      codex_args="$codex_args \"$1\""
      shift
      ;;
  esac
done

if [ -z "$TASK_ID" ]; then
  TASK_ID="${PLANGATE_GUARDED_TASK:-}"
fi

if [ -z "$TASK_ID" ]; then
  # Try cwd detection
  cwd=$(pwd)
  case "$cwd" in
    */docs/working/TASK-*)
      TASK_ID=$(echo "$cwd" | sed -E 's|.*/docs/working/(TASK-[0-9]+).*|\1|')
      ;;
  esac
fi

if [ -z "$TASK_ID" ]; then
  printf 'error: TASK ID not specified.\n' >&2
  printf '  Use --task TASK-XXXX, set PLANGATE_GUARDED_TASK, or run from docs/working/TASK-*/\n' >&2
  exit 1
fi

case "$TASK_ID" in
  TASK-*) ;;
  *)
    printf 'error: invalid TASK ID: %s\n' "$TASK_ID" >&2
    exit 1
    ;;
esac

cd "$REPO_ROOT"

# ── 2. Pre-flight (fail-closed) ──
printf '[codex-guarded] Pre-flight for %s\n' "$TASK_ID"
log_event "PREFLIGHT_START" "task=$TASK_ID"

# 2.1 plan_hash integrity
printf '  - bin/plangate validate %s (plan_hash + artifacts)\n' "$TASK_ID"
if ! bin/plangate validate "$TASK_ID" >/dev/null 2>&1; then
  printf '[codex-guarded] PREFLIGHT FAIL: bin/plangate validate %s\n' "$TASK_ID" >&2
  printf '  Run manually: bin/plangate validate %s\n' "$TASK_ID" >&2
  log_event "PREFLIGHT_FAIL" "validate failed"
  exit 1
fi

# 2.2 settings task-lock
printf '  - bin/plangate doctor --check-settings (Shadow Config prevention)\n'
if ! bin/plangate doctor --check-settings >/dev/null 2>&1; then
  printf '[codex-guarded] PREFLIGHT FAIL: settings task-lock not satisfied\n' >&2
  printf '  Human action required: sh scripts/apply-claude-settings.sh\n' >&2
  log_event "PREFLIGHT_FAIL" "settings task-lock failed"
  exit 1
fi

# 2.3 EH-8 metrics privacy (on staged files if any)
if [ -f "$REPO_ROOT/scripts/hooks/check-metrics-privacy.sh" ]; then
  if git diff --cached --name-only 2>/dev/null | grep -q .; then
    printf '  - EH-8 metrics privacy on staged files\n'
    if ! PLANGATE_HOOK_STRICT=1 sh "$REPO_ROOT/scripts/hooks/check-metrics-privacy.sh" >/dev/null 2>&1; then
      printf '[codex-guarded] PREFLIGHT FAIL: EH-8 privacy violation in staged files\n' >&2
      log_event "PREFLIGHT_FAIL" "EH-8 metrics privacy violation"
      exit 1
    fi
  fi
fi

# Snapshot plan.md hash for post-flight comparison
plan_file="$REPO_ROOT/docs/working/$TASK_ID/plan.md"
pre_hash=""
if [ -f "$plan_file" ]; then
  if command -v sha256sum >/dev/null 2>&1; then
    pre_hash=$(sha256sum "$plan_file" | awk '{print $1}')
  else
    pre_hash=$(shasum -a 256 "$plan_file" | awk '{print $1}')
  fi
fi

log_event "PREFLIGHT_PASS" "task=$TASK_ID pre_hash=$pre_hash"
printf '[codex-guarded] Pre-flight PASS\n'

# ── 3. Run codex via codex-local.sh ──
printf '[codex-guarded] Launching codex for %s\n' "$TASK_ID"
log_event "CODEX_START" "task=$TASK_ID"

set +e
eval "sh \"$REPO_ROOT/scripts/codex-local.sh\" $codex_args"
codex_exit=$?
set -e

log_event "CODEX_END" "exit=$codex_exit"

# ── 4. Post-flight (warning, not fail-closed) ──
printf '\n[codex-guarded] Post-flight for %s\n' "$TASK_ID"

post_hash=""
if [ -f "$plan_file" ]; then
  if command -v sha256sum >/dev/null 2>&1; then
    post_hash=$(sha256sum "$plan_file" | awk '{print $1}')
  else
    post_hash=$(shasum -a 256 "$plan_file" | awk '{print $1}')
  fi
fi

if [ -n "$pre_hash" ] && [ -n "$post_hash" ] && [ "$pre_hash" != "$post_hash" ]; then
  printf '[codex-guarded] WARNING: plan.md changed during codex session\n' >&2
  printf '  Pre  : sha256:%s\n' "$pre_hash" >&2
  printf '  Post : sha256:%s\n' "$post_hash" >&2
  printf '  Action: re-run bin/plangate validate %s and verify c3.json plan_hash\n' "$TASK_ID" >&2
  log_event "DRIFT_DETECTED" "pre=$pre_hash post=$post_hash"
  if [ "$codex_exit" -eq 0 ]; then
    exit 2
  fi
fi

if ! bin/plangate validate "$TASK_ID" >/dev/null 2>&1; then
  printf '[codex-guarded] WARNING: bin/plangate validate %s FAIL after session\n' "$TASK_ID" >&2
  printf '  Run: bin/plangate validate %s for details\n' "$TASK_ID" >&2
  log_event "POSTFLIGHT_VALIDATE_FAIL" "task=$TASK_ID"
fi

log_event "POSTFLIGHT_END" "task=$TASK_ID codex_exit=$codex_exit"
printf '[codex-guarded] Done (codex exit=%d)\n' "$codex_exit"
exit "$codex_exit"
