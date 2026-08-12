# tests/extras/_extra-contract.sh
# Shared standalone/harness execution contract for tests/extras/ta-*.sh
# (TASK-0921 / #921). This is the ONLY shared file the extras convention
# permits (exit-contract helper exception — see tests/extras/README.md).
#
# rc layer (standalone execution):
#   0 = all checks passed          1 = internal test failure (fail > 0)
#   2 = invocation error (harness-only run directly / invalid declaration)
#   3 = prerequisite absent — nothing was inspected (never rc=0)
# On the harness (source) path this helper NEVER exits and NEVER returns
# non-zero (tests/run-tests.sh runs under `set -eu`).
#
# Rules baked in (plan.md TASK-0921):
#   - POSIX sh only; no non-POSIX function-scoped variables (R-033-1);
#     state lives in _PG_EXTRA_* globals
#   - mode is resolved on every pg_extra_contract_init call (R-033-2)
#   - probe env is captured and unset at init so it never reaches children
#     spawned by the test body (R-015b); harness mode never reads it
#   - NEVER source this file from an interactive shell (R-033-3): the
#     standalone finalize path calls `exit` and would kill your shell.

# _pg_extra_resolve_mode: harness predicate.
# 正本: docs/working/TASK-0921/plan.md「### Mode resolution」(3 条件 AND / HR-4 = (b))
_pg_extra_resolve_mode() {
  if [ "${PG_HARNESS_SOURCED:-0}" = "1" ] && [ -n "${FIXTURES_DIR:-}" ] && [ -n "${EXTRAS_DIR:-}" ]; then
    _PG_EXTRA_STANDALONE=0
  else
    _PG_EXTRA_STANDALONE=1
  fi
}

# pg_extra_contract_is_standalone: rc 0 when the current file runs standalone.
pg_extra_contract_is_standalone() {
  [ "${_PG_EXTRA_STANDALONE:-1}" = "1" ]
}

# pg_extra_contract_init <test-id> <standalone-capable|harness-only>
pg_extra_contract_init() {
  _PG_EXTRA_ID="${1:-}"
  _PG_EXTRA_CAPABILITY="${2:-}"
  _pg_extra_resolve_mode
  # fail-closed validation (TC-08): id must yield TA-<NN>, capability must be known
  _PG_EXTRA_NN=$(printf '%s\n' "$_PG_EXTRA_ID" | sed -nE 's/^ta-([0-9]+).*/\1/p')
  _PG_EXTRA_VALID=1
  [ -n "$_PG_EXTRA_NN" ] || _PG_EXTRA_VALID=0
  case "$_PG_EXTRA_CAPABILITY" in
    standalone-capable|harness-only) : ;;
    *) _PG_EXTRA_VALID=0 ;;
  esac
  if [ "$_PG_EXTRA_VALID" = "0" ]; then
    printf '  [FAIL] extras contract: invalid test-id/capability (id=%s capability=%s)\n' \
      "$_PG_EXTRA_ID" "$_PG_EXTRA_CAPABILITY" >&2
    if [ "$_PG_EXTRA_STANDALONE" = "0" ]; then
      # harness: mark red, never exit / never return non-zero (R-024)
      fail=$((fail + 1))
      return 0
    fi
    exit 2
  fi
  if [ "$_PG_EXTRA_STANDALONE" = "0" ]; then
    # harness mode: non-invasive. Counters, cleanup registry and traps are the
    # runner's; the probe env is not read (internal-only, 裁定 ①).
    return 0
  fi
  if [ "$_PG_EXTRA_CAPABILITY" = "harness-only" ]; then
    printf '[ERROR] %s is harness-only; run: sh tests/run-tests.sh\n' "$_PG_EXTRA_ID" >&2
    exit 2
  fi
  # standalone-capable, standalone execution.
  # Neutralize external env contamination — superset of the runner's guarded
  # set (tests/run-tests.sh unset line; ta-26 TC-33 compatibility).
  unset PLANGATE_SKIP_REASON PLANGATE_HOOK_TASK PLANGATE_HOOK_FILE PLANGATE_BYPASS_HOOK PLANGATE_HOOK_STRICT PG_HARNESS_SOURCED PLANGATE_ALLOW_MASS_DELETE 2>/dev/null || true
  pass=0
  fail=0
  _PG_EXTRA_PREREQ_MISSING=0
  _PG_EXTRA_SKIP_REASON=''
  _PG_EXTRA_CLEANUP_PATHS=''
  # test-only contract probe seam: capture then unset so the body's child
  # processes never inherit it (R-015b recursion guard).
  _PG_EXTRA_PROBE="${PG_EXTRA_CONTRACT_PROBE:-}"
  _PG_EXTRA_PROBE_TARGET="${PG_EXTRA_CONTRACT_TARGET:-}"
  unset PG_EXTRA_CONTRACT_PROBE PG_EXTRA_CONTRACT_TARGET 2>/dev/null || true
  # standalone fallback cleanup registry — defined only when the harness has
  # not provided one (R-019b: never redefine unconditionally).
  if ! command -v register_cleanup >/dev/null 2>&1; then
    register_cleanup() {
      for _pg_extra_cp in "$@"; do
        [ -n "$_pg_extra_cp" ] || continue
        _PG_EXTRA_CLEANUP_PATHS="${_PG_EXTRA_CLEANUP_PATHS}${_pg_extra_cp}
"
      done
    }
  fi
  return 0
}

# pg_extra_contract_skip <reason>
# The ONLY channel for declaring "prerequisite absent". Standalone: finalizes
# immediately (rc=3, or rc=1 when failures were already recorded — the
# Finalize precedence). Harness: prints the diagnostic and returns 0; the
# caller then leaves the sourced file with a plain top-level `return 0`.
pg_extra_contract_skip() {
  _PG_EXTRA_SKIP_REASON="${1:-prerequisite absent}"
  printf '  [SKIP] PG_EXTRA_CONTRACT_SKIP:%s: %s\n' "${_PG_EXTRA_ID:-unknown}" "$_PG_EXTRA_SKIP_REASON"
  _PG_EXTRA_PREREQ_MISSING=1
  if [ "${_PG_EXTRA_STANDALONE:-1}" = "0" ]; then
    return 0
  fi
  pg_extra_contract_finalize
}

# pg_extra_contract_finalize
# Must be the last line of every migrated file, with no command in between
# (HJ-4 = (b): the original rc is captured from $? on entry).
pg_extra_contract_finalize() {
  _PG_EXTRA_ORIGINAL_RC=$?
  if [ "${_PG_EXTRA_STANDALONE:-0}" = "0" ]; then
    # harness mode: the runner aggregates and decides the final rc.
    # Explicit return 0 — never end on a test command (R-024).
    return 0
  fi
  # 1. drain the standalone cleanup registry (registered paths only)
  if [ -n "${_PG_EXTRA_CLEANUP_PATHS:-}" ]; then
    printf '%s' "$_PG_EXTRA_CLEANUP_PATHS" | while IFS= read -r _pg_extra_cp; do
      [ -n "$_pg_extra_cp" ] || continue
      rm -rf "$_pg_extra_cp" 2>/dev/null || true
    done
    _PG_EXTRA_CLEANUP_PATHS=''
  fi
  # 2. contract probe (test-only; fail-safe — it can only add failures)
  if [ -n "${_PG_EXTRA_PROBE:-}" ]; then
    if [ -z "${_PG_EXTRA_PROBE_TARGET:-}" ]; then
      # fail-closed (裁定 ②): a probe without a target is a mis-wired test
      printf '  [FAIL] PG_EXTRA_CONTRACT_PROBE is set but PG_EXTRA_CONTRACT_TARGET is unset (fail-closed)\n' >&2
      exit 4
    fi
    if [ "$_PG_EXTRA_PROBE" = "force-fail" ] && [ "$_PG_EXTRA_PROBE_TARGET" = "${_PG_EXTRA_ID:-}" ] && [ "${_PG_EXTRA_PREREQ_MISSING:-0}" = "0" ]; then
      fail=$((fail + 1))
      printf '  [FAIL] PG_EXTRA_CONTRACT_PROBE_FIRED:%s (test-only force-fail probe)\n' "$_PG_EXTRA_ID"
    fi
  fi
  # 3. recursion guard: never propagate probe env further (belt and braces)
  unset PG_EXTRA_CONTRACT_PROBE PG_EXTRA_CONTRACT_TARGET 2>/dev/null || true
  # 4. summary — literal format required by ta-26 TC-13 (R-015a)
  printf 'TA-%s standalone: %d passed, %d failed\n' "$_PG_EXTRA_NN" "$pass" "$fail"
  # 5. rc precedence (plan.md "### Finalize precedence")
  if [ "${_PG_EXTRA_PREREQ_MISSING:-0}" = "1" ]; then
    if [ "$fail" -gt 0 ]; then
      printf '  [INFO] prerequisite absent but %d failure(s) already recorded — rc=1 takes precedence over rc=3\n' "$fail"
      exit 1
    fi
    exit 3
  fi
  if [ "$_PG_EXTRA_ORIGINAL_RC" != "0" ]; then
    exit "$_PG_EXTRA_ORIGINAL_RC"
  fi
  if [ "$fail" -gt 0 ]; then
    exit 1
  fi
  exit 0
}
