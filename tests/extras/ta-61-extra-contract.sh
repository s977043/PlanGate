# tests/extras/ta-61-extra-contract.sh
# PG_EXTRA_CAPABILITY: standalone-capable
# Sourced by tests/run-tests.sh — uses $pass / $fail counters
# TASK-0921 (#921) Slice 1: extras execution contract regression test.
#
# Verifies the shared standalone/harness exit contract (_extra-contract.sh):
#   - capability markers (exactly one per file, first 20 lines)
#   - marker/init agreement (basename test-id)
#   - rc layers 0/1/2/3 + force-fail probe differential (TC-12)
#   - migration-period allowlist soundness (_pending_migration / TC-25)
#   - dual-shell (dash/bash) skip-guard behaviour (TC-29 / issue #1026)
# Recursion guard: PG_T61_NO_RECURSE=1 skips the nested full-suite and
# sandbox cases (TC-14 / TC-15 runner / TC-16 / TC-17 sandbox / TC-29).

if [ "${PG_HARNESS_SOURCED:-0}" = "1" ] && [ -n "${FIXTURES_DIR:-}" ] && [ -n "${EXTRAS_DIR:-}" ]; then
  _pg_extra_mode=harness
  _pg_extra_dir="$EXTRAS_DIR"
else
  _pg_extra_mode=standalone
  _pg_extra_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
fi
_pg_extra_helper="$_pg_extra_dir/_extra-contract.sh"
if [ ! -r "$_pg_extra_helper" ]; then
  printf '  [FAIL] helper unresolved: %s\n' "$_pg_extra_helper" >&2
  if [ "$_pg_extra_mode" = harness ]; then
    fail=$((fail + 1))
    return 0
  fi
  exit 1
fi
. "$_pg_extra_helper"
pg_extra_contract_init ta-61-extra-contract standalone-capable

# ta-26 TC-33（静的検査 / README 規約 8）準拠: FIXTURES_DIR:- を含む extras は
# standalone 経路で runner と同一の 7 env unset を自ファイル内に持つ必要がある。
# helper init が既に unset 済みのため機能的には冪等（静的包含要件のための明示行）。
if pg_extra_contract_is_standalone; then
  unset PLANGATE_SKIP_REASON PLANGATE_HOOK_TASK PLANGATE_HOOK_FILE PLANGATE_BYPASS_HOOK PLANGATE_HOOK_STRICT PG_HARNESS_SOURCED PLANGATE_ALLOW_MASS_DELETE 2>/dev/null || true
fi

printf '\n=== TA-61: extras execution contract (#921 Slice 1) ===\n'

t61_pass() { pass=$((pass + 1)); printf '  [PASS] %s\n' "$1"; }
t61_fail() { fail=$((fail + 1)); printf '  [FAIL] %s\n' "$1" >&2; }
t61_info() { printf '  [INFO] %s\n' "$1"; }

_T61_SELF_ID=ta-61-extra-contract
_T61_GLOB='ta-*.sh'
_T61_DIR="$_pg_extra_dir"
_T61_ROOT="$(CDPATH= cd -- "$_T61_DIR/../.." && pwd)"
_T61_HELPER="$_T61_DIR/_extra-contract.sh"
_T61_RUNNER="$_T61_ROOT/tests/run-tests.sh"
_T61_NO_RECURSE="${PG_T61_NO_RECURSE:-0}"

_T61_TMP=$(mktemp -d)
register_cleanup "$_T61_TMP"

# per-file timeout (R-026): >=180s; timeout(1) on CI, perl alarm fallback on macOS
if command -v timeout >/dev/null 2>&1; then
  _t61_to() { timeout 180 "$@"; }
else
  _t61_to() { perl -e 'alarm 180; exec @ARGV' "$@"; }
fi

# ---------------------------------------------------------------------------
# Migration-period allowlist (Human 決定 4 / MJ-E): explicit list embedded in
# this file. Generated from the Task 1 inventory (evidence:
# docs/working/TASK-0921/evidence/test-runs/pending-migration-gen.log) —
# never resolved by a predicate. Delete a line per migrated file; delete the
# whole function at Slice 2 completion (TC-24 / AC-5).
_pending_migration() {
  cat <<'EOF'
ta-04-check-pr-issue-link.sh
ta-05-validate-schemas.sh
ta-06-hooks.sh
ta-07-eval-runner.sh
ta-08-codex-log-parser.sh
ta-09-metrics.sh
ta-10-doctor-fix.sh
ta-11-plan-hash-contract.sh
ta-12-maintenance.sh
ta-13-plangate-setup.sh
ta-14-codex-guarded.sh
ta-14-skip-acknowledge.sh
ta-15-codex-hook-bridge.sh
ta-16-pollution-guard.sh
ta-17-pre-push-guard.sh
ta-18-tag-main-parity.sh
ta-19-plan-metrics-verification.sh
ta-20-codex-review.sh
ta-21-codex-mvp-split.sh
ta-22-git-add-scope.sh
ta-23-gh-account-pin.sh
ta-24-parallel-review.sh
ta-25-approval-token-guard.sh
ta-26-plugin-sync.sh
ta-27-codex-commands.sh
ta-28-plugin-version.sh
ta-29-committed-pollution.sh
ta-30-install-skills.sh
ta-31-codex-plugin-status.sh
ta-32-real-ssot-pollution.sh
ta-33-agent-model-tier.sh
ta-34-cli-min-coverage.sh
ta-35-yaml-schema.sh
ta-36-fixloop-event.sh
ta-37-cli-coverage-batch2.sh
ta-38-agent-tools.sh
ta-41-approve-hardening.sh
ta-42-cli-subcommands.sh
ta-54-ai-loop-link-selfcontained.sh
ta-55-c3prime-accept.sh
ta-56-delivery.sh
ta-57-pr-convergence.sh
ta-58-git-destructive-guard.sh
ta-59-apply-settings-merge.sh
ta-60-run-evidence.sh
EOF
}

# ---------------------------------------------------------------------------
# Discovery (TC-28: same glob definition as the runner's extras loop)
_T61_DISCOVERED=$( (cd "$_T61_DIR" && ls $_T61_GLOB 2>/dev/null) || true )
_T61_DISC_COUNT=0
for _t61_b in $_T61_DISCOVERED; do _T61_DISC_COUNT=$((_T61_DISC_COUNT + 1)); done

if [ "$_T61_DISC_COUNT" -gt 0 ]; then
  t61_pass "TA-61 discovery: runtime inventory non-empty ($_T61_DISC_COUNT files)"
else
  t61_fail "TA-61 discovery: no $_T61_GLOB files discovered under $_T61_DIR"
fi

# TC-28: the runner's extras loop must source the very same glob
if grep -Fq '"$EXTRAS_DIR"/'"$_T61_GLOB" "$_T61_RUNNER"; then
  t61_pass "TC-28: contract discovery glob ($_T61_GLOB) equals the runner's source glob"
else
  t61_fail "TC-28: runner extras loop does not use \"\$EXTRAS_DIR\"/$_T61_GLOB — discovery set != source set (see $_T61_RUNNER)"
fi

# Covered set = discovered - pending (self stays covered; skipped only in exec loops)
_T61_PENDING=$(_pending_migration)
_t61_in_pending() {
  # $1 = basename with .sh
  printf '%s\n' "$_T61_PENDING" | grep -Fxq "$1"
}

# ---------------------------------------------------------------------------
# TC-25: allowlist soundness + non-vacuity (MJ-I / MN-E / M-14)
_t61_tc25_ok=1
_T61_PENDING_COUNT=0
for _t61_b in $_T61_PENDING; do
  _T61_PENDING_COUNT=$((_T61_PENDING_COUNT + 1))
  if [ ! -f "$_T61_DIR/$_t61_b" ]; then
    t61_fail "TC-25: _pending_migration entry does not exist: $_t61_b"
    _t61_tc25_ok=0
    continue
  fi
  case "$_t61_b" in
    ta-*.sh) : ;;
    *) t61_fail "TC-25: _pending_migration entry does not match $_T61_GLOB: $_t61_b"; _t61_tc25_ok=0 ;;
  esac
  if grep -q 'pg_extra_contract_init' "$_T61_DIR/$_t61_b"; then
    t61_fail "TC-25: already-migrated file still listed in _pending_migration: $_t61_b"
    _t61_tc25_ok=0
  fi
done
[ "$_t61_tc25_ok" = "1" ] && t61_pass "TC-25: every _pending_migration entry exists and is genuinely unmigrated ($_T61_PENDING_COUNT entries)"

# TC-25 assert 1: covered set minus self is non-empty
_T61_COVERED_MINUS_SELF=0
for _t61_b in $_T61_DISCOVERED; do
  _t61_in_pending "$_t61_b" && continue
  [ "${_t61_b%.sh}" = "$_T61_SELF_ID" ] && continue
  _T61_COVERED_MINUS_SELF=$((_T61_COVERED_MINUS_SELF + 1))
done
if [ "$_T61_COVERED_MINUS_SELF" -gt 0 ]; then
  t61_pass "TC-25(1): covered set minus self is non-empty ($_T61_COVERED_MINUS_SELF files)"
else
  t61_fail "TC-25(1): covered set minus self is EMPTY — allowlist has swallowed every file (over-broad _pending_migration in $_T61_DIR)"
fi

# TC-25 assert 2: pending is a proper subset of discovered
_t61_sub_ok=1
for _t61_b in $_T61_PENDING; do
  printf '%s\n' "$_T61_DISCOVERED" | grep -Fxq "$_t61_b" || _t61_sub_ok=0
done
if [ "$_t61_sub_ok" = "1" ] && [ "$_T61_PENDING_COUNT" -lt "$_T61_DISC_COUNT" ]; then
  t61_pass "TC-25(2): _pending_migration is a proper subset of the discovered set"
else
  t61_fail "TC-25(2): _pending_migration is not a proper subset of the discovered set (pending=$_T61_PENDING_COUNT discovered=$_T61_DISC_COUNT sub_ok=$_t61_sub_ok)"
fi
# TC-25 assert 3 (loop execution count) is asserted after the per-file loops below.

# ---------------------------------------------------------------------------
# TC-20: basename test-id uniqueness over ALL discovered files (allowlist-exempt)
_t61_dups=$(printf '%s\n' "$_T61_DISCOVERED" | sed 's/\.sh$//' | sort | uniq -d)
if [ -z "$_t61_dups" ]; then
  t61_pass "TC-20: every discovered ta-*.sh has a unique basename test-id"
else
  t61_fail "TC-20: duplicate basename test-id(s) in $_T61_DIR: $_t61_dups"
fi

# ---------------------------------------------------------------------------
# TC-27: independent syntax case (R-029-3) — distinct from the rc=2 namespace
_t61_syn_ok=1
for _t61_b in $_T61_DISCOVERED; do
  if ! sh -n "$_T61_DIR/$_t61_b" 2>/dev/null; then
    t61_fail "TC-27: SYNTAX ERROR (not a harness-only rejection): $_T61_DIR/$_t61_b"
    _t61_syn_ok=0
  fi
done
sh -n "$_T61_HELPER" 2>/dev/null || { t61_fail "TC-27: SYNTAX ERROR: $_T61_HELPER"; _t61_syn_ok=0; }
sh -n "$_T61_RUNNER" 2>/dev/null || { t61_fail "TC-27: SYNTAX ERROR: $_T61_RUNNER"; _t61_syn_ok=0; }
[ "$_t61_syn_ok" = "1" ] && t61_pass "TC-27: sh -n clean for helper, runner and every ta-*.sh"

# ---------------------------------------------------------------------------
# TC-09 / TC-10: marker spec (R-027) + marker/init agreement, covered set + self
_T61_MARKER_ERE='^[[:space:]]*#[[:space:]]*PG_EXTRA_CAPABILITY:[[:space:]]*(standalone-capable|harness-only)[[:space:]]*$'
_t61_marker_count() { head -20 "$1" | grep -cE "$_T61_MARKER_ERE" || true; }
_t61_marker_value() {
  head -20 "$1" | sed -nE 's/^[[:space:]]*#[[:space:]]*PG_EXTRA_CAPABILITY:[[:space:]]*(standalone-capable|harness-only)[[:space:]]*$/\1/p' | head -1
}

_t61_tc0910_ok=1
_T61_HARNESS_ONLY_LIST=""
_T61_STANDALONE_LIST=""
for _t61_b in $_T61_DISCOVERED; do
  _t61_in_pending "$_t61_b" && continue
  _t61_f="$_T61_DIR/$_t61_b"
  _t61_id="${_t61_b%.sh}"
  _t61_n=$(_t61_marker_count "$_t61_f")
  if [ "$_t61_n" != "1" ]; then
    t61_fail "TC-09: marker count is $_t61_n (want exactly 1 in first 20 lines): $_t61_f"
    _t61_tc0910_ok=0
    continue
  fi
  _t61_cap=$(_t61_marker_value "$_t61_f")
  # init agreement: first pg_extra_contract_init call names basename id + same capability
  _t61_initline=$(grep -E '^pg_extra_contract_init[[:space:]]' "$_t61_f" | head -1)
  if [ -z "$_t61_initline" ]; then
    t61_fail "TC-10: no top-level pg_extra_contract_init call: $_t61_f"
    _t61_tc0910_ok=0
    continue
  fi
  _t61_arg1=$(printf '%s\n' "$_t61_initline" | awk '{print $2}')
  _t61_arg2=$(printf '%s\n' "$_t61_initline" | awk '{print $3}')
  if [ "$_t61_arg1" != "$_t61_id" ]; then
    t61_fail "TC-10: init test-id '$_t61_arg1' != basename id '$_t61_id': $_t61_f"
    _t61_tc0910_ok=0
  fi
  if [ "$_t61_arg2" != "$_t61_cap" ]; then
    t61_fail "TC-10: init capability '$_t61_arg2' != marker '$_t61_cap': $_t61_f"
    _t61_tc0910_ok=0
  fi
  if [ "$_t61_cap" = "harness-only" ]; then
    _T61_HARNESS_ONLY_LIST="$_T61_HARNESS_ONLY_LIST $_t61_b"
  else
    _T61_STANDALONE_LIST="$_T61_STANDALONE_LIST $_t61_b"
  fi
done
[ "$_t61_tc0910_ok" = "1" ] && t61_pass "TC-09/TC-10: covered files carry exactly one marker and a matching basename init"

# ---------------------------------------------------------------------------
# TC-11: harness-only all-file direct execution (rc=2 AND id-bearing message)
_T61_HO_COUNT=0
for _t61_b in $_T61_HARNESS_ONLY_LIST; do
  _T61_HO_COUNT=$((_T61_HO_COUNT + 1))
  _t61_id="${_t61_b%.sh}"
  _t61_rc=0
  _t61_out=$(PG_EXTRA_CONTRACT_PROBE='' PG_EXTRA_CONTRACT_TARGET='' _t61_to sh "$_T61_DIR/$_t61_b" </dev/null 2>&1) || _t61_rc=$?
  if [ "$_t61_rc" = "2" ] && printf '%s\n' "$_t61_out" | grep -Fq "[ERROR] $_t61_id is harness-only"; then
    t61_pass "TC-11: $_t61_id direct execution rejected (rc=2 + id-bearing message)"
  else
    t61_fail "TC-11: $_t61_id direct execution not rejected as specified (rc=$_t61_rc)"
  fi
done
if [ "$_T61_HO_COUNT" = "0" ]; then
  t61_info "TC-11: harness-only in-scope count is 0 — vacuous PASS (recorded, not hidden; full coverage arrives in Slice 2)"
fi

# ---------------------------------------------------------------------------
# TC-12 / TC-13 / TC-15(loop) / TC-17(live): standalone-capable per-file loops
# Stage 1 classify (probe absent) -> stage 2 assert per class (C-1 MN-4).
_T61_EXEC_COUNT=0
_T61_PREREQ_ABSENT=""
_T61_GUARDED_ENVS=$(sed -n 's/^unset \(.*\) 2>\/dev\/null.*$/\1/p' "$_T61_RUNNER" | head -1)
if [ -n "$_T61_GUARDED_ENVS" ]; then
  t61_pass "TC-15: guarded env set derived at runtime from the runner's unset list"
else
  t61_fail "TC-15: could not derive the guarded env set from $_T61_RUNNER"
fi
_t61_contam_args() {
  # emits VAR=value words for env(1); PG_HARNESS_SOURCED gets the realistic '1'
  for _t61_v in $_T61_GUARDED_ENVS; do
    if [ "$_t61_v" = "PG_HARNESS_SOURCED" ]; then
      printf '%s=1\n' "$_t61_v"
    else
      printf '%s=t61junk\n' "$_t61_v"
    fi
  done
}

for _t61_b in $_T61_STANDALONE_LIST; do
  _t61_id="${_t61_b%.sh}"
  [ "$_t61_id" = "$_T61_SELF_ID" ] && continue
  _t61_f="$_T61_DIR/$_t61_b"
  # Stage 1 — classify with a clean, probe-free run (counted for TC-25(3))
  _T61_EXEC_COUNT=$((_T61_EXEC_COUNT + 1))
  _t61_rc=0
  _t61_out=$(PG_EXTRA_CONTRACT_PROBE='' PG_EXTRA_CONTRACT_TARGET='' _t61_to sh "$_t61_f" </dev/null 2>&1) || _t61_rc=$?
  if [ "$_t61_rc" = "124" ] || [ "$_t61_rc" = "142" ]; then
    t61_fail "TC-12: stage-1 run TIMED OUT (>180s, treated as FAIL not SKIP): $_t61_id"
    continue
  fi
  case "$_t61_rc" in
    0)
      # prerequisite-satisfied class
      # TC-13: clean run must not print [FAIL]
      if printf '%s\n' "$_t61_out" | grep -Fq '[FAIL]'; then
        t61_fail "TC-13: $_t61_id clean standalone run printed [FAIL] while returning rc=0"
      else
        t61_pass "TC-12(a)/TC-13: $_t61_id clean standalone run rc=0 with no [FAIL]"
      fi
      # TC-12(b): force-fail probe -> rc=1 AND probe marker (R-029-1)
      _t61_prc=0
      _t61_pout=$(PG_EXTRA_CONTRACT_PROBE=force-fail PG_EXTRA_CONTRACT_TARGET="$_t61_id" _t61_to sh "$_t61_f" </dev/null 2>&1) || _t61_prc=$?
      if [ "$_t61_prc" = "1" ] && printf '%s\n' "$_t61_pout" | grep -Fq "PG_EXTRA_CONTRACT_PROBE_FIRED:$_t61_id"; then
        t61_pass "TC-12(b): $_t61_id force-fail probe propagates to rc=1 with probe marker"
      else
        t61_fail "TC-12(b): $_t61_id probe differential failed (rc=$_t61_prc; finalize not reached or marker missing)"
      fi
      # TC-15 (loop): contaminated env must behave like the clean baseline
      _t61_crc=0
      _t61_cout=$(_t61_to env $(_t61_contam_args) PG_EXTRA_CONTRACT_PROBE=force-fail PG_EXTRA_CONTRACT_TARGET=ta-00-none sh "$_t61_f" </dev/null 2>&1) || _t61_crc=$?
      if [ "$_t61_crc" = "0" ]; then
        t61_pass "TC-15: $_t61_id contaminated-env standalone run matches clean baseline (rc=0)"
      else
        t61_fail "TC-15: $_t61_id contaminated-env standalone run diverged (rc=$_t61_crc)"
      fi
      ;;
    3)
      # prerequisite-absent class -> TC-17 (live): rc=3 must come from pg_extra_contract_skip
      _T61_PREREQ_ABSENT="$_T61_PREREQ_ABSENT $_t61_id"
      if printf '%s\n' "$_t61_out" | grep -Fq "PG_EXTRA_CONTRACT_SKIP:$_t61_id"
      then
        t61_pass "TC-17(live): $_t61_id prerequisite-absent rc=3 with pg_extra_contract_skip diagnostic"
      else
        t61_fail "TC-17(live): $_t61_id returned rc=3 without the pg_extra_contract_skip diagnostic (rc=3 by a forbidden route)"
      fi
      ;;
    *)
      t61_fail "TC-12: $_t61_id stage-1 classification failed — rc=$_t61_rc is neither 0 nor 3 (fail-closed)"
      ;;
  esac
done
[ -n "$_T61_PREREQ_ABSENT" ] && t61_info "stage-1 prerequisite-absent class:$_T61_PREREQ_ABSENT"

# TC-25 assert 3: the per-file loop actually started executing at least one file
if [ "$_T61_EXEC_COUNT" -gt 0 ]; then
  t61_pass "TC-25(3): per-file execution loop started $_T61_EXEC_COUNT file run(s) (non-zero)"
else
  t61_fail "TC-25(3): per-file execution loop executed ZERO files — contract checks are vacuous (covered set collapsed in $_T61_DIR)"
fi

# ---------------------------------------------------------------------------
# TC-19: README documents rc layers / marker / probe / rc=2 namespace
_t61_readme="$_T61_DIR/README.md"
_t61_tc19_ok=1
for _t61_tok in 'rc=0' 'rc=1' 'rc=2' 'rc=3' 'PG_EXTRA_CAPABILITY' 'pg_extra_contract_skip' 'PG_EXTRA_CONTRACT_PROBE' '別名前空間' 'standalone-capable' 'harness-only'; do
  if ! grep -Fq "$_t61_tok" "$_t61_readme" 2>/dev/null; then
    t61_fail "TC-19: README lacks required token: $_t61_tok"
    _t61_tc19_ok=0
  fi
done
[ "$_t61_tc19_ok" = "1" ] && t61_pass "TC-19: README documents rc 0/1/2/3, marker convention, probe and the rc=2 namespace note"

# ---------------------------------------------------------------------------
# Synthetic helper-unit cases (TC-01..TC-08, TC-21, TC-23 synthetic, TC-26)
_T61_FX="$_T61_TMP/fx"
mkdir -p "$_T61_FX"

# TC-01: harness mode is non-invasive (counters kept, probe env not read)
cat > "$_T61_FX/tc01.sh" <<'FX01'
PG_HARNESS_SOURCED=1
FIXTURES_DIR="$T61_FXDIR"
EXTRAS_DIR="$T61_FXDIR"
PG_EXTRA_CONTRACT_PROBE=force-fail
PG_EXTRA_CONTRACT_TARGET=ta-90-fx
pass=5
fail=7
. "$T61_HELPER"
pg_extra_contract_init ta-90-fx standalone-capable
pg_extra_contract_finalize
[ "$pass" = "5" ] || { echo "counters reset: pass=$pass"; exit 61; }
[ "$fail" = "7" ] || { echo "counters touched: fail=$fail"; exit 62; }
[ -n "${PG_EXTRA_CONTRACT_PROBE:-}" ] || { echo "probe env consumed in harness mode"; exit 63; }
[ "$(trap -p EXIT 2>/dev/null || true)" = "" ] || { echo "exit trap installed"; exit 64; }
exit 0
FX01
_t61_rc=0
_t61_out=$(T61_HELPER="$_T61_HELPER" T61_FXDIR="$_T61_FX" sh "$_T61_FX/tc01.sh" </dev/null 2>&1) || _t61_rc=$?
if [ "$_t61_rc" = "0" ]; then
  t61_pass "TC-01: harness-mode init/finalize is non-invasive and ignores probe env"
else
  t61_fail "TC-01: harness-mode invasion detected (rc=$_t61_rc): $_t61_out"
fi

# TC-01b/TC-01c: the harness predicate is a 3-condition AND (HR-4 = (b)) —
# any missing condition must resolve to STANDALONE (counters are reset)
cat > "$_T61_FX/tc01b.sh" <<'FX01B'
PG_HARNESS_SOURCED="${T61_PHS:-0}"
FIXTURES_DIR="$T61_FXDIR"
EXTRAS_DIR="${T61_EXD:-}"
pass=5
fail=7
. "$T61_HELPER"
pg_extra_contract_init ta-90-fx standalone-capable
[ "$pass" = "0" ] || { echo "not standalone: pass=$pass"; exit 65; }
[ "$fail" = "0" ] || { echo "not standalone: fail=$fail"; exit 66; }
pass=$((pass + 1))
pg_extra_contract_finalize
FX01B
_t61_rc=0
_t61_out=$(T61_HELPER="$_T61_HELPER" T61_FXDIR="$_T61_FX" T61_PHS=0 T61_EXD="$_T61_FX" sh "$_T61_FX/tc01b.sh" </dev/null 2>&1) || _t61_rc=$?
if [ "$_t61_rc" = "0" ]; then
  t61_pass "TC-01b: PG_HARNESS_SOURCED!=1 (FIXTURES/EXTRAS set) resolves to standalone"
else
  t61_fail "TC-01b: partial predicate resolved to harness (rc=$_t61_rc): $_t61_out"
fi
_t61_rc=0
_t61_out=$(T61_HELPER="$_T61_HELPER" T61_FXDIR="$_T61_FX" T61_PHS=1 T61_EXD= sh "$_T61_FX/tc01b.sh" </dev/null 2>&1) || _t61_rc=$?
if [ "$_t61_rc" = "0" ]; then
  t61_pass "TC-01c: empty EXTRAS_DIR (PG_HARNESS_SOURCED=1 + FIXTURES_DIR set) resolves to standalone (HR-4)"
else
  t61_fail "TC-01c: 2-condition predicate regression — empty EXTRAS_DIR treated as harness (rc=$_t61_rc): $_t61_out"
fi

# TC-02: harness-only direct misuse -> rc=2 before body, id-bearing stderr
cat > "$_T61_FX/tc02.sh" <<'FX02'
. "$T61_HELPER"
pg_extra_contract_init ta-91-fxho harness-only
: > "$T61_FXDIR/tc02-body-sentinel"
FX02
_t61_rc=0
_t61_out=$(T61_HELPER="$_T61_HELPER" T61_FXDIR="$_T61_FX" sh "$_T61_FX/tc02.sh" </dev/null 2>&1) || _t61_rc=$?
if [ "$_t61_rc" = "2" ] && printf '%s\n' "$_t61_out" | grep -Fq '[ERROR] ta-91-fxho is harness-only' && [ ! -f "$_T61_FX/tc02-body-sentinel" ]; then
  t61_pass "TC-02: harness-only direct misuse -> rc=2 with message, before any body side effect"
else
  t61_fail "TC-02: harness-only misuse handling broken (rc=$_t61_rc sentinel=$([ -f "$_T61_FX/tc02-body-sentinel" ] && echo yes || echo no))"
fi

# TC-03/TC-04/TC-05: standalone pass -> rc0 / fail -> rc1 (explicit tail finalize)
cat > "$_T61_FX/tc03.sh" <<'FX03'
. "$T61_HELPER"
pg_extra_contract_init ta-92-fx standalone-capable
pass=$((pass + 1))
pg_extra_contract_finalize
FX03
_t61_rc=0
_t61_out=$(T61_HELPER="$_T61_HELPER" sh "$_T61_FX/tc03.sh" </dev/null 2>&1) || _t61_rc=$?
if [ "$_t61_rc" = "0" ] && printf '%s\n' "$_t61_out" | grep -Fq 'TA-92 standalone: 1 passed, 0 failed'; then
  t61_pass "TC-03: standalone all-pass -> rc=0 with summary literal"
else
  t61_fail "TC-03: standalone pass path broken (rc=$_t61_rc): $_t61_out"
fi

cat > "$_T61_FX/tc04.sh" <<'FX04'
. "$T61_HELPER"
pg_extra_contract_init ta-93-fx standalone-capable
if [ "${T61_ALT_PATH:-0}" = "1" ]; then
  fail=$((fail + 1))
else
  fail=$((fail + 1))
fi
pg_extra_contract_finalize
FX04
_t61_rc=0
_t61_out=$(T61_HELPER="$_T61_HELPER" sh "$_T61_FX/tc04.sh" </dev/null 2>&1) || _t61_rc=$?
if [ "$_t61_rc" = "1" ] && printf '%s\n' "$_t61_out" | grep -Fq 'TA-93 standalone: 0 passed, 1 failed'; then
  t61_pass "TC-04: standalone internal fail -> rc=1"
else
  t61_fail "TC-04: standalone fail propagation broken (rc=$_t61_rc): $_t61_out"
fi
_t61_rc=0
_t61_out=$(T61_HELPER="$_T61_HELPER" T61_ALT_PATH=1 sh "$_T61_FX/tc04.sh" </dev/null 2>&1) || _t61_rc=$?
if [ "$_t61_rc" = "1" ]; then
  t61_pass "TC-05: alternate body path still reaches tail finalize -> rc=1"
else
  t61_fail "TC-05: alternate path lost the failure (rc=$_t61_rc)"
fi

# TC-06: preserve specific nonzero original rc (HJ-4 = (b) 保持)
cat > "$_T61_FX/tc06.sh" <<'FX06'
. "$T61_HELPER"
pg_extra_contract_init ta-94-fx standalone-capable
[ "${T61_WITH_FAIL:-0}" = "1" ] && fail=$((fail + 1))
sh -c 'exit 3'
pg_extra_contract_finalize
FX06
_t61_rc=0
_t61_out=$(T61_HELPER="$_T61_HELPER" sh "$_T61_FX/tc06.sh" </dev/null 2>&1) || _t61_rc=$?
_t61_rc2=0
_t61_out2=$(T61_HELPER="$_T61_HELPER" T61_WITH_FAIL=1 sh "$_T61_FX/tc06.sh" </dev/null 2>&1) || _t61_rc2=$?
if [ "$_t61_rc" = "3" ] && [ "$_t61_rc2" = "3" ]; then
  t61_pass "TC-06: specific nonzero original rc (3) preserved with fail=0 and fail>0"
else
  t61_fail "TC-06: original rc not preserved (fail0->rc=$_t61_rc fail1->rc=$_t61_rc2)"
fi

# TC-07: only registered cleanup paths are drained
cat > "$_T61_FX/tc07.sh" <<'FX07'
. "$T61_HELPER"
pg_extra_contract_init ta-95-fx standalone-capable
mkdir -p "$T61_FXDIR/tc07-reg1" "$T61_FXDIR/tc07-reg2" "$T61_FXDIR/tc07-sentinel"
register_cleanup "$T61_FXDIR/tc07-reg1" "$T61_FXDIR/tc07-reg2"
pass=$((pass + 1))
pg_extra_contract_finalize
FX07
_t61_rc=0
_t61_out=$(T61_HELPER="$_T61_HELPER" T61_FXDIR="$_T61_FX" sh "$_T61_FX/tc07.sh" </dev/null 2>&1) || _t61_rc=$?
if [ "$_t61_rc" = "0" ] && [ ! -d "$_T61_FX/tc07-reg1" ] && [ ! -d "$_T61_FX/tc07-reg2" ] && [ -d "$_T61_FX/tc07-sentinel" ]; then
  t61_pass "TC-07: standalone finalize drains registered paths only; unregistered sentinel survives"
else
  t61_fail "TC-07: cleanup drain contract broken (rc=$_t61_rc reg1=$([ -d "$_T61_FX/tc07-reg1" ] && echo kept || echo gone) sentinel=$([ -d "$_T61_FX/tc07-sentinel" ] && echo kept || echo gone))"
fi
rm -rf "$_T61_FX/tc07-sentinel" 2>/dev/null || true

# TC-08: invalid capability fails closed before body
cat > "$_T61_FX/tc08.sh" <<'FX08'
. "$T61_HELPER"
pg_extra_contract_init ta-96-fx totally-bogus
: > "$T61_FXDIR/tc08-body-sentinel"
FX08
_t61_rc=0
_t61_out=$(T61_HELPER="$_T61_HELPER" T61_FXDIR="$_T61_FX" sh "$_T61_FX/tc08.sh" </dev/null 2>&1) || _t61_rc=$?
if [ "$_t61_rc" != "0" ] && [ ! -f "$_T61_FX/tc08-body-sentinel" ]; then
  t61_pass "TC-08: invalid capability fails closed before body (rc=$_t61_rc)"
else
  t61_fail "TC-08: invalid capability was accepted (rc=$_t61_rc sentinel=$([ -f "$_T61_FX/tc08-body-sentinel" ] && echo yes || echo no))"
fi

# Probe fail-closed: PROBE set + TARGET unset -> diagnostic + nonzero (裁定 ②)
_t61_rc=0
_t61_out=$(T61_HELPER="$_T61_HELPER" PG_EXTRA_CONTRACT_PROBE=force-fail sh "$_T61_FX/tc03.sh" </dev/null 2>&1) || _t61_rc=$?
if [ "$_t61_rc" != "0" ] && printf '%s\n' "$_t61_out" | grep -q 'PG_EXTRA_CONTRACT_TARGET'; then
  t61_pass "TC-12(fail-closed): probe with unset TARGET is a diagnostic nonzero, not a no-op (rc=$_t61_rc)"
else
  t61_fail "TC-12(fail-closed): probe with unset TARGET did not fail closed (rc=$_t61_rc)"
fi

# skip-with-fail precedence (MN-2): fail>0 before skip -> rc=1, not rc=3
cat > "$_T61_FX/tcskip.sh" <<'FXSK'
. "$T61_HELPER"
pg_extra_contract_init ta-97-fx standalone-capable
[ "${T61_PRE_FAIL:-0}" = "1" ] && fail=$((fail + 1))
pg_extra_contract_skip "fixture prerequisite absent"
FXSK
_t61_rc=0
_t61_out=$(T61_HELPER="$_T61_HELPER" sh "$_T61_FX/tcskip.sh" </dev/null 2>&1) || _t61_rc=$?
_t61_rc2=0
_t61_out2=$(T61_HELPER="$_T61_HELPER" T61_PRE_FAIL=1 sh "$_T61_FX/tcskip.sh" </dev/null 2>&1) || _t61_rc2=$?
if [ "$_t61_rc" = "3" ] && printf '%s\n' "$_t61_out" | grep -Fq 'PG_EXTRA_CONTRACT_SKIP:ta-97-fx'; then
  t61_pass "TC-17(synthetic): pg_extra_contract_skip with fail=0 -> rc=3 with diagnostic"
else
  t61_fail "TC-17(synthetic): skip path broken (rc=$_t61_rc): $_t61_out"
fi
if [ "$_t61_rc2" = "1" ]; then
  t61_pass "TC-17(precedence): fail>0 before skip -> rc=1 takes precedence over rc=3"
else
  t61_fail "TC-17(precedence): fail>0 before skip returned rc=$_t61_rc2 (want 1)"
fi
# probe on a prerequisite-absent run must NOT force rc=1
_t61_rc=0
_t61_out=$(T61_HELPER="$_T61_HELPER" PG_EXTRA_CONTRACT_PROBE=force-fail PG_EXTRA_CONTRACT_TARGET=ta-97-fx sh "$_T61_FX/tcskip.sh" </dev/null 2>&1) || _t61_rc=$?
if [ "$_t61_rc" = "3" ]; then
  t61_pass "TC-17(probe): force-fail probe does not fire on a prerequisite-absent run (rc=3)"
else
  t61_fail "TC-17(probe): probe fired on a prerequisite-absent run (rc=$_t61_rc, want 3)"
fi

# TC-21: register_cleanup not redefined in harness; helper is set -eu source-safe
cat > "$_T61_FX/tc21.sh" <<'FX21'
set -eu
PG_HARNESS_SOURCED=1
FIXTURES_DIR="$T61_FXDIR"
EXTRAS_DIR="$T61_FXDIR"
pass=0
fail=0
register_cleanup() { printf 'harness-def:%s\n' "$1"; }
. "$T61_HELPER"
pg_extra_contract_init ta-89-fx standalone-capable
register_cleanup probe-path
pg_extra_contract_finalize
exit 0
FX21
_t61_rc=0
_t61_out=$(T61_HELPER="$_T61_HELPER" T61_FXDIR="$_T61_FX" sh "$_T61_FX/tc21.sh" </dev/null 2>&1) || _t61_rc=$?
if [ "$_t61_rc" = "0" ] && printf '%s\n' "$_t61_out" | grep -Fq 'harness-def:probe-path'; then
  t61_pass "TC-21: harness register_cleanup untouched; helper sources cleanly under set -eu"
else
  t61_fail "TC-21: harness register_cleanup was redefined or set -eu source failed (rc=$_t61_rc): $_t61_out"
fi

# TC-23 (synthetic): probe env is captured at init and never reaches children
cat > "$_T61_FX/tc23.sh" <<'FX23'
. "$T61_HELPER"
pg_extra_contract_init ta-88-fx standalone-capable
sh -c 'printf "child-sees:%s:%s\n" "${PG_EXTRA_CONTRACT_PROBE:-none}" "${PG_EXTRA_CONTRACT_TARGET:-none}"'
pass=$((pass + 1))
pg_extra_contract_finalize
FX23
_t61_rc=0
_t61_out=$(T61_HELPER="$_T61_HELPER" PG_EXTRA_CONTRACT_PROBE=force-fail PG_EXTRA_CONTRACT_TARGET=ta-88-fx sh "$_T61_FX/tc23.sh" </dev/null 2>&1) || _t61_rc=$?
if printf '%s\n' "$_t61_out" | grep -Fq 'child-sees:none:none' && [ "$_t61_rc" = "1" ] && printf '%s\n' "$_t61_out" | grep -Fq 'PG_EXTRA_CONTRACT_PROBE_FIRED:ta-88-fx'; then
  t61_pass "TC-23(synthetic): probe env does not leak into children, yet the probe still fires at finalize"
else
  t61_fail "TC-23(synthetic): probe env leaked or probe lost (rc=$_t61_rc): $_t61_out"
fi

# TC-26: non-zero return on the source path never truncates a set -eu harness
cat > "$_T61_FX/tc26-file1.sh" <<'FX26A'
printf 'mini-marker: file1\n'
. "$T61_HELPER"
pg_extra_contract_init ta-87-fx standalone-capable
fail=$((fail + 1))
pg_extra_contract_finalize
FX26A
cat > "$_T61_FX/tc26-file2.sh" <<'FX26B'
printf 'mini-marker: file2-after-failing-file\n'
FX26B
cat > "$_T61_FX/tc26-runner.sh" <<'FX26R'
set -eu
pass=0
fail=0
_PG_CLEANUP_PATHS=""
register_cleanup() { :; }
_pg_drain_cleanup() { :; }
PG_HARNESS_SOURCED=1
FIXTURES_DIR="$T61_FXDIR"
EXTRAS_DIR="$T61_FXDIR"
. "$T61_FXDIR/tc26-file1.sh"
. "$T61_FXDIR/tc26-file2.sh"
_pg_drain_cleanup
printf 'Results: %d passed, %d failed\n' "$pass" "$fail"
FX26R
_t61_rc=0
_t61_out=$(T61_HELPER="$_T61_HELPER" T61_FXDIR="$_T61_FX" sh "$_T61_FX/tc26-runner.sh" </dev/null 2>&1) || _t61_rc=$?
if printf '%s\n' "$_t61_out" | grep -Fq 'mini-marker: file2-after-failing-file' && printf '%s\n' "$_t61_out" | grep -Fq 'Results: 0 passed, 1 failed'; then
  t61_pass "TC-26: a failing sourced file does not truncate the set -eu harness (marker + Results both present)"
else
  t61_fail "TC-26: source-path truncation detected (rc=$_t61_rc): $_t61_out"
fi

# ---------------------------------------------------------------------------
# Sandbox cases (skipped when PG_T61_NO_RECURSE=1): TC-16 / TC-17 / TC-29
if [ "$_T61_NO_RECURSE" = "1" ]; then
  t61_info "recursion guard active (PG_T61_NO_RECURSE=1): TC-14 / TC-15(runner) / TC-16 / TC-17(sandbox) / TC-29 skipped in this nested run"
else
  if ! command -v git >/dev/null 2>&1; then
    t61_fail "sandbox: git unavailable — TC-16 / TC-17 / TC-29 cannot be built (fail-closed, not SKIP)"
  else
    _T61_SB="$_T61_TMP/sandbox"
    mkdir -p "$_T61_SB/repo"
    _t61_sb_ok=1
    # tracked worktree copy + untracked-but-not-ignored files (TDD loop support);
    # intermediate tar to avoid macOS bsdtar pipe write errors (plan MN-G note)
    ( cd "$_T61_ROOT" && git ls-files -z -c -o --exclude-standard | tar --null -T - -cf "$_T61_SB/tree.tar" ) 2>/dev/null || _t61_sb_ok=0
    if [ "$_t61_sb_ok" = "1" ]; then
      tar -xf "$_T61_SB/tree.tar" -C "$_T61_SB/repo" 2>/dev/null || _t61_sb_ok=0
    fi
    if [ "$_t61_sb_ok" != "1" ] || [ ! -f "$_T61_SB/repo/tests/extras/$_T61_SELF_ID.sh" ]; then
      t61_fail "sandbox: repo worktree copy failed under $_T61_SB (fail-closed)"
    else
      _T61_SBX="$_T61_SB/repo/tests/extras"
      # --- strip measured predicate strings (copy side only) to make the
      #     whole-file-guard prerequisites absent (plan sandbox construction)
      _t61_strip() { # $1=file $2=pattern
        grep -v "$2" "$1" > "$1.t61" && mv "$1.t61" "$1"
      }
      _t61_strip "$_T61_SB/repo/scripts/hooks/check-plan-hash.sh" 'EH-3_DOC_LIGHT_SKIP' || _t61_sb_ok=0
      _t61_strip "$_T61_SB/repo/scripts/hooks/check-c3-approval.sh" '_eh2_stdin' || _t61_sb_ok=0
      _t61_strip "$_T61_SB/repo/bin/plangate" 'check-test-cases\.sh' || _t61_sb_ok=0
      _t61_strip "$_T61_SB/repo/bin/plangate" 'check-verification-evidence\.sh' || _t61_sb_ok=0
      _t61_strip "$_T61_SB/repo/bin/plangate" 'EHS-1 BLOCK' || _t61_sb_ok=0
      _t61_strip "$_T61_SB/repo/bin/plangate" 'EHS-3' || _t61_sb_ok=0
      _t61_strip "$_T61_SB/repo/bin/plangate" 'TASK-0147' || _t61_sb_ok=0
      rm -f "$_T61_SB/repo/schemas/plangate-config.schema.json"
      # ta-43/ta-44 の SKIP 分岐は apply-script の dry-run 出力を検査する。
      # 述語だけを剥がした sandbox では実 apply-script が「old 文字列不在」で
      # ERROR を返し t43_fail が発火してしまう（それは rc=1 優先の正当経路だが、
      # 本 TC の目的は「clean な前提未充足 = rc=3」の検査）。sandbox 側の
      # apply-script を期待差分を出す stub に差し替えて clean skip を構成する。
      printf '%s\n' '#!/bin/sh' 'printf "stub dry-run: python3 _eh2_stdin patch preview\\n"' 'exit 0' > "$_T61_SB/repo/scripts/apply-task-0141-eh2-strict.sh"
      printf '%s\n' '#!/bin/sh' 'printf "stub dry-run: check-test-cases Patch 1 preview\\n"' 'exit 0' > "$_T61_SB/repo/scripts/apply-task-0143-eh457-wiring.sh"
      [ "$_t61_sb_ok" = "1" ] || t61_fail "sandbox: predicate stripping failed (fail-closed)"

      # --- TC-17 (sandbox) + TC-29 (dual shell): 6 whole-file guards -> rc=3;
      #     ta-49 (section skip) -> rc follows preceding TCs + SKIP diagnostic
      _T61_DASH=""
      if command -v dash >/dev/null 2>&1; then
        _T61_DASH=$(command -v dash)
      fi
      if [ -z "$_T61_DASH" ]; then
        t61_fail "TC-29: dash cannot be resolved — FAIL, not SKIP (F6)"
      else
        t61_info "TC-29 shells: dash=$_T61_DASH bash=$(command -v bash)"
        for _t61_id in ta-39-eh3-doc-light ta-43-eh2-strict-json ta-44-eh457-cli-wiring ta-45-c3-mode-config ta-46-ehs-wiring ta-47-ehs23-wiring; do
          _t61_f="$_T61_SBX/$_t61_id.sh"
          _t61_drc=0
          _t61_dout=$(PG_EXTRA_CONTRACT_PROBE='' PG_EXTRA_CONTRACT_TARGET='' _t61_to "$_T61_DASH" "$_t61_f" </dev/null 2>&1) || _t61_drc=$?
          _t61_brc=0
          _t61_bout=$(PG_EXTRA_CONTRACT_PROBE='' PG_EXTRA_CONTRACT_TARGET='' _t61_to bash "$_t61_f" </dev/null 2>&1) || _t61_brc=$?
          if [ "$_t61_drc" = "3" ] && [ "$_t61_brc" = "3" ] && printf '%s\n' "$_t61_dout" | grep -Fq "PG_EXTRA_CONTRACT_SKIP:$_t61_id" && printf '%s\n' "$_t61_bout" | grep -Fq "PG_EXTRA_CONTRACT_SKIP:$_t61_id"; then
            t61_pass "TC-17/TC-29: $_t61_id prerequisite-absent -> rc=3 with skip diagnostic under BOTH dash and bash"
          else
            t61_fail "TC-17/TC-29: $_t61_id dual-shell mismatch or wrong rc (dash=$_t61_drc bash=$_t61_brc, want 3/3)"
          fi
        done
        # ta-49: section-scoped skip — rc follows layer-A TCs (0 or 1), never 3
        _t61_f="$_T61_SBX/ta-49-bias-export.sh"
        _t61_drc=0
        _t61_dout=$(PG_EXTRA_CONTRACT_PROBE='' PG_EXTRA_CONTRACT_TARGET='' _t61_to "$_T61_DASH" "$_t61_f" </dev/null 2>&1) || _t61_drc=$?
        _t61_brc=0
        _t61_bout=$(PG_EXTRA_CONTRACT_PROBE='' PG_EXTRA_CONTRACT_TARGET='' _t61_to bash "$_t61_f" </dev/null 2>&1) || _t61_brc=$?
        if [ "$_t61_drc" = "$_t61_brc" ] && { [ "$_t61_drc" = "0" ] || [ "$_t61_drc" = "1" ]; } && printf '%s\n' "$_t61_dout" | grep -q '\[SKIP\]' && printf '%s\n' "$_t61_bout" | grep -q '\[SKIP\]'; then
          t61_pass "TC-29: ta-49-bias-export section skip -> identical rc=$_t61_drc (0/1, never 3) + SKIP diagnostic under both shells"
        else
          t61_fail "TC-29: ta-49-bias-export dual-shell mismatch (dash=$_t61_drc bash=$_t61_brc) or SKIP diagnostic missing"
        fi
      fi

      # --- TC-16: new file without contract makes the sandbox contract TA fail
      cat > "$_T61_SBX/ta-97-probe-a.sh" <<'P16A'
# pattern A: no marker, no init
printf 'pattern-a body\n'
P16A
      cat > "$_T61_SBX/ta-98-probe-b.sh" <<'P16B'
# PG_EXTRA_CAPABILITY: standalone-capable
# pattern B: marker only, no matching init
printf 'pattern-b body\n'
P16B
      cat > "$_T61_SBX/ta-99-probe-c.sh" <<'P16C'
# PG_EXTRA_CAPABILITY: standalone-capable
# pattern C: marker + matching init but NO tail pg_extra_contract_finalize
if [ "${PG_HARNESS_SOURCED:-0}" = "1" ] && [ -n "${FIXTURES_DIR:-}" ] && [ -n "${EXTRAS_DIR:-}" ]; then
  _pg_extra_mode=harness
  _pg_extra_dir="$EXTRAS_DIR"
else
  _pg_extra_mode=standalone
  _pg_extra_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
fi
_pg_extra_helper="$_pg_extra_dir/_extra-contract.sh"
if [ ! -r "$_pg_extra_helper" ]; then
  printf '  [FAIL] helper unresolved: %s\n' "$_pg_extra_helper" >&2
  if [ "$_pg_extra_mode" = harness ]; then
    fail=$((fail + 1))
    return 0
  fi
  exit 1
fi
. "$_pg_extra_helper"
pg_extra_contract_init ta-99-probe-c standalone-capable
:
P16C
      _t61_rc=0
      _t61_out=$(PG_T61_NO_RECURSE=1 PG_EXTRA_CONTRACT_PROBE='' PG_EXTRA_CONTRACT_TARGET='' sh "$_T61_SBX/$_T61_SELF_ID.sh" </dev/null 2>&1) || _t61_rc=$?
      _t61_hit_a=0; _t61_hit_b=0; _t61_hit_c=0
      printf '%s\n' "$_t61_out" | grep -q 'TC-09.*ta-97-probe-a' && _t61_hit_a=1
      printf '%s\n' "$_t61_out" | grep -q 'TC-10.*ta-98-probe-b' && _t61_hit_b=1
      printf '%s\n' "$_t61_out" | grep -q 'TC-12(b).*ta-99-probe-c' && _t61_hit_c=1
      if [ "$_t61_rc" != "0" ] && [ "$_t61_hit_a" = "1" ] && [ "$_t61_hit_b" = "1" ] && [ "$_t61_hit_c" = "1" ]; then
        t61_pass "TC-16: sandbox contract TA fails on all three contract-less new-file patterns (rc=$_t61_rc)"
      else
        t61_fail "TC-16: sandbox contract TA missed a pattern (rc=$_t61_rc A=$_t61_hit_a B=$_t61_hit_b C=$_t61_hit_c)"
      fi
    fi
  fi
fi

# ---------------------------------------------------------------------------
# TC-14 / TC-15(runner): full-suite children — standalone runs only (nesting
# the suite inside the harness run would recurse; the enclosing harness run
# itself is the TC-14 evidence there, captured by T-08).
if [ "$_T61_NO_RECURSE" = "1" ] || [ "${PG_T61_SKIP_SUITE:-0}" = "1" ]; then
  # PG_T61_SKIP_SUITE=1: test-only knob for the mutation driver — skips only
  # the full-suite children while keeping the sandbox cases running.
  :
elif pg_extra_contract_is_standalone; then
  _T61_LAST=$(cd "$_T61_DIR" && ls $_T61_GLOB | tail -1)
  _T61_LAST_NN=$(printf '%s\n' "$_T61_LAST" | sed -nE 's/^ta-0*([0-9]+).*/\1/p')
  _t61_rc=0
  _t61_out=$(PG_T61_NO_RECURSE=1 sh "$_T61_RUNNER" </dev/null 2>&1) || _t61_rc=$?
  if [ "$_t61_rc" = "0" ] && printf '%s\n' "$_t61_out" | grep -Eq 'Results: [0-9]+ passed, 0 failed' && printf '%s\n' "$_t61_out" | grep -q "=== TA-$_T61_LAST_NN"; then
    t61_pass "TC-14: harness regression — suite rc=0, 0 failed, runtime-resolved last file ($_T61_LAST) reached"
  else
    t61_fail "TC-14: harness regression failed (rc=$_t61_rc, last=$_T61_LAST)"
  fi
  # TC-15 (runner): contaminated env incl. probe vars must not affect the harness
  _t61_rc=0
  _t61_out=$(env $(_t61_contam_args) PG_EXTRA_CONTRACT_PROBE=force-fail PG_EXTRA_CONTRACT_TARGET=ta-26-plugin-sync PG_T61_NO_RECURSE=1 sh "$_T61_RUNNER" </dev/null 2>&1) || _t61_rc=$?
  if [ "$_t61_rc" = "0" ] && printf '%s\n' "$_t61_out" | grep -Eq 'Results: [0-9]+ passed, 0 failed'; then
    t61_pass "TC-15: contaminated-env harness run (guarded envs + probe vars) matches clean baseline"
  else
    t61_fail "TC-15: contaminated-env harness run diverged (rc=$_t61_rc)"
  fi
else
  t61_info "TC-14/TC-15(runner): asserted in standalone contract-TA runs; this harness run is itself the TC-14 subject (see full-suite evidence)"
fi

rm -rf "$_T61_TMP" 2>/dev/null || true

pg_extra_contract_finalize
