# tests/extras/ta-88-reviewer-normalization.sh
# PG_EXTRA_CAPABILITY: standalone-capable
# Sourced by tests/run-tests.sh — uses $pass / $fail counters
# #1394: external reviewer normalization contract / anti-false-green tests.
#
# This test intentionally exercises provider-specific JSON that cannot pass by
# merely concatenating reviewer stdout into review-external.md.

# ---- extras execution contract bootstrap (#921) ----------------------------
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
pg_extra_contract_init ta-88-reviewer-normalization standalone-capable

if pg_extra_contract_is_standalone; then
  unset PLANGATE_SKIP_REASON PLANGATE_HOOK_TASK PLANGATE_HOOK_FILE \
    PLANGATE_BYPASS_HOOK PLANGATE_HOOK_STRICT PG_HARNESS_SOURCED \
    PLANGATE_ALLOW_MASS_DELETE 2>/dev/null || true
fi

printf '\n=== TA-88: reviewer normalization (#1394) ===\n'

t88_pass() { pass=$((pass + 1)); printf '  [PASS] %s\n' "$1"; }
t88_fail() { fail=$((fail + 1)); printf '  [FAIL] %s\n' "$1" >&2; }

_T88_ROOT="$(CDPATH= cd -- "$_pg_extra_dir/../.." && pwd)"
_T88_SCRIPT="$_T88_ROOT/scripts/reviewer_normalize.py"
_T88_FIX="$_T88_ROOT/tests/fixtures/reviewer-normalization"
_T88_PY="${PLANGATE_PYTHON:-python3}"

if [ ! -f "$_T88_SCRIPT" ]; then
  t88_fail "reviewer_normalize.py が存在しない"
else

# TC-01: River Review current output shape is actually normalized.
_t88_rc=0
_t88_out=$(
  PYTHONDONTWRITEBYTECODE=1 "$_T88_PY" "$_T88_SCRIPT" \
    --adapter river-review-v1 \
    --provider river-review \
    --lane design \
    --input "$_T88_FIX/river-valid.json"
) || _t88_rc=$?

if [ "$_t88_rc" = "0" ] && printf '%s' "$_t88_out" | "$_T88_PY" -c '
import json,sys
d=json.load(sys.stdin)
assert d["schema_version"] == 1
assert d["execution_status"] == "executed"
assert d["normalization_status"] == "valid"
assert d["reviewer_id"] == "river-review"
assert d["lane"] == "design"
assert d["position_capability"] == "unavailable"
assert d["positions"] == []
assert len(d["findings"]) == 2
f=d["findings"][0]
assert f["source_finding_ref"] == "RR-101"
assert f["severity"] == "major"
assert "AC-3" in f["evidence_refs"]
assert "plan.md#step-4" in f["evidence_refs"]
assert "docs/working/TASK-9999/plan.md:42" in f["evidence_refs"]
assert "decision" not in d
'; then
  t88_pass "TC-01 current River Review issues[] → deterministic normalized findings"
else
  printf '%s\n' "$_t88_out" >&2
  t88_fail "TC-01 River Review normalization failed (rc=$_t88_rc)"
fi

# TC-02: zero findings MUST NOT imply support / position.
_t88_rc=0
_t88_zero=$(
  PYTHONDONTWRITEBYTECODE=1 "$_T88_PY" "$_T88_SCRIPT" \
    --adapter river-review-v1 \
    --provider river-review \
    --lane design \
    --input "$_T88_FIX/river-zero.json"
) || _t88_rc=$?

if [ "$_t88_rc" = "0" ] && printf '%s' "$_t88_zero" | "$_T88_PY" -c '
import json,sys
d=json.load(sys.stdin)
assert d["findings"] == []
assert d["positions"] == []
assert d["position_capability"] == "unavailable"
assert not any(p.get("stance") == "support" for p in d["positions"])
'; then
  t88_pass "TC-02 zero findings != support stance"
else
  printf '%s\n' "$_t88_zero" >&2
  t88_fail "TC-02 zero finding semantics were not preserved"
fi

# TC-03: explicit position-capable producer is preserved exactly enough for #1354.
_t88_rc=0
_t88_explicit=$(
  PYTHONDONTWRITEBYTECODE=1 "$_T88_PY" "$_T88_SCRIPT" \
    --adapter plangate-normalized-v1 \
    --provider explicit-producer \
    --lane codebase \
    --input "$_T88_FIX/plangate-explicit.json"
) || _t88_rc=$?

if [ "$_t88_rc" = "0" ] && printf '%s' "$_t88_explicit" | "$_T88_PY" -c '
import json,sys
d=json.load(sys.stdin)
assert d["reviewer_id"] == "explicit-producer"
assert d["lane"] == "codebase"
assert d["position_capability"] == "explicit"
assert len(d["positions"]) == 1
p=d["positions"][0]
assert p["position_id"] == "p1"
assert p["source_finding_ref"] == "PG-201"
assert p["stance"] == "oppose"
assert p["severity"] == "critical"
assert p["assumptions"] == ["The current plan assumes the operation is reversible."]
'; then
  t88_pass "TC-03 explicit position contract is preserved without semantic inference"
else
  printf '%s\n' "$_t88_explicit" >&2
  t88_fail "TC-03 explicit position normalization failed"
fi

# TC-04: malformed JSON is fail-visible, never equivalent to clean zero findings.
_t88_rc=0
_t88_bad=$(
  PYTHONDONTWRITEBYTECODE=1 "$_T88_PY" "$_T88_SCRIPT" \
    --adapter river-review-v1 \
    --provider river-review \
    --lane design \
    --input "$_T88_FIX/malformed.json" 2>/dev/null
) || _t88_rc=$?

if [ "$_t88_rc" = "2" ] && printf '%s' "$_t88_bad" | "$_T88_PY" -c '
import json,sys
d=json.load(sys.stdin)
assert d["normalization_status"] == "invalid"
assert d["execution_status"] == "executed"
assert d["findings"] == []
assert d["positions"] == []
assert d["limitations"]
'; then
  t88_pass "TC-04 malformed JSON → rc=2 + invalid envelope (not clean)"
else
  printf '%s\n' "$_t88_bad" >&2
  t88_fail "TC-04 malformed JSON did not fail visibly (rc=$_t88_rc)"
fi

# TC-05: runtime identity wins over provider self-assertion.
_t88_tmp=$(mktemp)
register_cleanup "$_t88_tmp" 2>/dev/null || true
cat > "$_t88_tmp" <<'EOF'
{
  "reviewer_id": "spoofed-reviewer",
  "lane": "spoofed-lane",
  "position_capability": "unavailable",
  "findings": [],
  "positions": [],
  "limitations": []
}
EOF
_t88_rc=0
_t88_identity=$(
  PYTHONDONTWRITEBYTECODE=1 "$_T88_PY" "$_T88_SCRIPT" \
    --adapter plangate-normalized-v1 \
    --provider trusted-runtime \
    --lane security \
    --input "$_t88_tmp"
) || _t88_rc=$?

if [ "$_t88_rc" = "0" ] && printf '%s' "$_t88_identity" | "$_T88_PY" -c '
import json,sys
d=json.load(sys.stdin)
assert d["reviewer_id"] == "trusted-runtime"
assert d["lane"] == "security"
'; then
  t88_pass "TC-05 provider/lane provenance comes from runtime context"
else
  t88_fail "TC-05 self-asserted identity overrode runtime identity"
fi

# TC-06: unknown severity uses existing safe fallback (major), never info.
_t88_tmp2=$(mktemp)
register_cleanup "$_t88_tmp2" 2>/dev/null || true
"$ _T88_PY" >/dev/null 2>&1 && : # unreachable sentinel; catches accidental shell interpolation changes

"$ _T88_PY" 2>/dev/null || true
# Build from a known-good fixture without requiring jq.
"$ _T88_PY" - "$_T88_FIX/river-valid.json" "$_t88_tmp2" <<'PY'
import json,sys
src=json.load(open(sys.argv[1], encoding="utf-8"))
src["issues"][0]["severity"]="future-new-severity"
json.dump(src, open(sys.argv[2], "w", encoding="utf-8"))
PY
_t88_rc=0
_t88_sev=$(
  PYTHONDONTWRITEBYTECODE=1 "$_T88_PY" "$_T88_SCRIPT" \
    --adapter river-review-v1 \
    --provider river-review \
    --lane design \
    --input "$_t88_tmp2"
) || _t88_rc=$?

if [ "$_t88_rc" = "0" ] && printf '%s' "$_t88_sev" | "$_T88_PY" -c '
import json,sys
d=json.load(sys.stdin)
assert d["findings"][0]["severity"] == "major"
'; then
  t88_pass "TC-06 unknown severity → major safe fallback"
else
  t88_fail "TC-06 unknown severity did not fail safe"
fi

fi

pg_extra_contract_finalize
