# PG_EXTRA_CAPABILITY: standalone-capable
# TA-116 — Growth Harness L2 must fail closed for unconfirmed/unknown seeds.
if [ "${PG_HARNESS_SOURCED:-0}" = "1" ] && [ -n "${FIXTURES_DIR:-}" ] && [ -n "${EXTRAS_DIR:-}" ]; then
  _pg_extra_mode=harness
  _pg_extra_dir="$EXTRAS_DIR"
else
  _pg_extra_mode=standalone
  _pg_extra_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
  unset PLANGATE_SKIP_REASON PLANGATE_HOOK_TASK PLANGATE_HOOK_FILE \
    PLANGATE_BYPASS_HOOK PLANGATE_HOOK_STRICT PG_HARNESS_SOURCED \
    PLANGATE_ALLOW_MASS_DELETE 2>/dev/null || true
fi
_pg_extra_helper="$_pg_extra_dir/_extra-contract.sh"
if [ ! -r "$_pg_extra_helper" ]; then
  printf '  [FAIL] TA-116 helper missing\n' >&2
  if [ "$_pg_extra_mode" = harness ]; then fail=$((fail + 1)); return 0; fi
  exit 1
fi
. "$_pg_extra_helper"
pg_extra_contract_init ta-116-improvement-seed-delta standalone-capable

if [ "$_pg_extra_mode" = harness ]; then
  _t116_root="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
else
  _t116_root="${_pg_extra_dir%/tests/extras}"
fi
_t116_tmp="$(mktemp -d)"
register_cleanup "$_t116_tmp"
printf 'TA-116: Growth Harness L2 seed inventory (#1545)\n'
_t116_rc=0
python3 "$_t116_root/scripts/test_improvement_seed_delta.py" >"$_t116_tmp/unit.log" 2>&1 || _t116_rc=$?
if [ "$_t116_rc" -eq 0 ] && grep -q '^OK' "$_t116_tmp/unit.log"; then
  printf '  [PASS] confirmed/unconfirmed and negative control unit tests\n'; pass=$((pass + 1))
else
  printf '  [FAIL] Growth Harness L2 unit tests (rc=%s)\n' "$_t116_rc" >&2
  cat "$_t116_tmp/unit.log" >&2
  fail=$((fail + 1))
fi
_t116_rc=0
python3 "$_t116_root/scripts/improvement_seed_delta.py" \
  --seeds "$_t116_root/docs/working/improvement-seeds.md" \
  --digest "$_t116_root/docs/working/improvement-digest.md" \
  >"$_t116_tmp/inventory.json" 2>"$_t116_tmp/error.log" || _t116_rc=$?
if [ "$_t116_rc" -eq 0 ] && python3 - "$_t116_tmp/inventory.json" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as handle:
    x = json.load(handle)
assert x["entries_with_confirmation_marker"] == x["already_indexed"] + x["unindexed_count"]
assert x["authority"] == "READ_ONLY_UNVERIFIED_MARKER_NO_PROMOTION"
assert x["status"] in ("BELOW_THRESHOLD", "REVIEW_CANDIDATE")
PY
then
  printf '  [PASS] current digest delta is read-only and internally consistent\n'; pass=$((pass + 1))
else
  printf '  [FAIL] current seed/digest mismatch (rc=%s)\n' "$_t116_rc" >&2
  cat "$_t116_tmp/error.log" >&2
  fail=$((fail + 1))
fi
unset _t116_root _t116_rc _t116_tmp 2>/dev/null || true
pg_extra_contract_finalize
