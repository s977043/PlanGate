#!/bin/sh
# PG_EXTRA_CAPABILITY: standalone-capable
# TA-111 — status phase follows C-3 decision/verification readiness (#1482).

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
  printf '  [FAIL] helper unresolved: %s\n' "$_pg_extra_helper" >&2
  if [ "$_pg_extra_mode" = harness ]; then fail=$((fail + 1)); return 0; fi
  exit 1
fi
. "$_pg_extra_helper"
pg_extra_contract_init ta-111-status-c3-phase standalone-capable

if [ "$_pg_extra_mode" = harness ]; then
  _T111_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
  _T111_BIN="$PLANGATE_BIN"
else
  _T111_ROOT="${_pg_extra_dir%/tests/extras}"
  _T111_BIN="$_T111_ROOT/bin/plangate"
  pass=0
  fail=0
fi

printf 'TA-111: status phase follows C-3 readiness (#1482)\n'

_t111_id=9900
while [ "$_t111_id" -le 9999 ] && [ -e "$_T111_ROOT/docs/working/TASK-$_t111_id" ]; do
  _t111_id=$((_t111_id + 1))
done
if [ "$_t111_id" -gt 9999 ]; then
  printf '  [FAIL] fixture: no unused TASK-99xx id available\n' >&2
  fail=$((fail + 1))
  pg_extra_contract_finalize
  if [ "$_pg_extra_mode" = harness ]; then return 0; else exit 1; fi
fi

_T111_TASK="TASK-$_t111_id"
_T111_DIR="$_T111_ROOT/docs/working/$_T111_TASK"
mkdir -p "$_T111_DIR/approvals"
register_cleanup "$_T111_DIR"

cat >"$_T111_DIR/pbi-input.md" <<EOF
# PBI INPUT — $_T111_TASK
EOF
cat >"$_T111_DIR/plan.md" <<EOF
# EXECUTION PLAN — $_T111_TASK
EOF
cat >"$_T111_DIR/todo.md" <<'EOF'
# TODO
EOF
cat >"$_T111_DIR/test-cases.md" <<'EOF'
# TEST CASES
EOF

_t111_sha() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}
_T111_PLAN_HASH="$(_t111_sha "$_T111_DIR/plan.md")"

_t111_status() {
  _t111_out=""
  _t111_rc=0
  _t111_out="$(sh "$_T111_BIN" status "$_T111_TASK" 2>&1)" || _t111_rc=$?
}

_t111_assert_unresolved() {
  _t111_label=$1
  _t111_status
  if [ "$_t111_rc" -eq 0 ] \
    && printf '%s' "$_t111_out" | grep -Fq 'Current: C-3 — approval unresolved' \
    && printf '%s' "$_t111_out" | grep -Fq "Next:    plangate validate $_T111_TASK" \
    && ! printf '%s' "$_t111_out" | grep -Fq 'Current: D / V'; then
    printf '  [PASS] %s\n' "$_t111_label"; pass=$((pass + 1))
  else
    printf '  [FAIL] %s\n%s\n' "$_t111_label" "$_t111_out" >&2; fail=$((fail + 1))
  fi
}

rm -f "$_T111_DIR/approvals/c3.json"
_t111_status
if [ "$_t111_rc" -eq 0 ] \
  && printf '%s' "$_t111_out" | grep -Fq 'Current: C-3 — human review pending' \
  && printf '%s' "$_t111_out" | grep -Fq "plangate approve $_T111_TASK"; then
  printf '  [PASS] missing C-3: Human review remains pending\n'; pass=$((pass + 1))
else
  printf '  [FAIL] missing C-3 phase\n%s\n' "$_t111_out" >&2; fail=$((fail + 1))
fi

printf '%s\n' '{"c3_status":"REJECTED"}' >"$_T111_DIR/approvals/c3.json"
_t111_assert_unresolved 'legacy REJECTED: does not advance to D/V'

printf '%s\n' '{"c3_status":"CONDITIONAL"}' >"$_T111_DIR/approvals/c3.json"
_t111_assert_unresolved 'legacy CONDITIONAL: does not advance to D/V'

printf '%s\n' '{not-json' >"$_T111_DIR/approvals/c3.json"
_t111_assert_unresolved 'unreadable C-3 JSON: fails safe to diagnosis'

printf '%s\n' '{"c3_status":"REJECTED"}' >"$_T111_DIR/approvals/c3.json"
touch "$_T111_DIR/handoff.md"
_t111_assert_unresolved 'handoff present + REJECTED C-3: does not report Done'
rm -f "$_T111_DIR/handoff.md"

printf '%s\n' '{"c3_status":"APPROVED","plan_hash":"sha256:0000000000000000000000000000000000000000000000000000000000000000"}' >"$_T111_DIR/approvals/c3.json"
_t111_assert_unresolved 'legacy APPROVED with stale plan_hash: does not advance to D/V'

printf '%s\n' '{"approval_kind":"c3-prime"}' >"$_T111_DIR/approvals/c3.json"
_t111_assert_unresolved 'invalid c3-prime: verification failure does not advance to D/V'

printf '%s\n' '{"c3_status":"APPROVED","plan_hash":"sha256:'"$_T111_PLAN_HASH"'"}' >"$_T111_DIR/approvals/c3.json"
_t111_status
if [ "$_t111_rc" -eq 0 ] \
  && printf '%s' "$_t111_out" | grep -Fq 'C-3: APPROVED' \
  && printf '%s' "$_t111_out" | grep -Fq 'Current: D / V — exec or verification'; then
  printf '  [PASS] legacy APPROVED + matching plan_hash: advances to D/V\n'; pass=$((pass + 1))
else
  printf '  [FAIL] valid legacy approval phase\n%s\n' "$_t111_out" >&2; fail=$((fail + 1))
fi

# Build a verifier-valid c3-prime record without invoking approval authority.
cat >"$_T111_DIR/review-self.md" <<EOF
# C-1
C1-VERDICT: PASS plan=sha256:$_T111_PLAN_HASH
EOF
cat >"$_T111_DIR/review-external.md" <<EOF
# C-2
C2-VERDICT: approve plan=sha256:$_T111_PLAN_HASH
EOF
python3 - "$_T111_ROOT" "$_T111_DIR" "$_T111_TASK" <<'PY'
import json, pathlib, sys
root = pathlib.Path(sys.argv[1])
task_dir = pathlib.Path(sys.argv[2])
task_id = sys.argv[3]
sys.path.insert(0, str(root / "scripts" / "ai-loop"))
import plan_package
h = plan_package.compute_hashes(task_dir)
source_sha = "abc1234"
reviewers = {
    "model_a": {"verdict":"approve","plan_hash":h["plan_hash"],"source_sha":source_sha,
                "plan_package_hash":h["plan_package_hash"],"evidence_ref":"record#a"},
    "model_b": {"verdict":"approve","plan_hash":h["plan_hash"],"source_sha":source_sha,
                "plan_package_hash":h["plan_package_hash"],"evidence_ref":"record#b"},
}
record = {
    "task_id": task_id, "approval_kind":"c3-prime", "phase":"C-3'",
    "decision":"AUTO_APPROVED", "source_sha":source_sha,
    "plan_hash":h["plan_hash"], "plan_package_hash":h["plan_package_hash"],
    "artifact_hashes":h["artifact_hashes"],
    "c1_evidence_ref":"review-self.md#PASS",
    "c2_evidence_ref":"review-external.md#approve",
    "reviewers":reviewers, "policy_ref":"test@v1",
    "issued_at":"2100-01-01T00:00:00Z", "issued_by":"ta-109",
}
(task_dir / "approvals" / "c3.json").write_text(json.dumps(record, sort_keys=True), encoding="utf-8")
PY
_t111_status
if [ "$_t111_rc" -eq 0 ] \
  && printf '%s' "$_t111_out" | grep -Fq 'C-3: AUTO_APPROVED (c3-prime verified)' \
  && printf '%s' "$_t111_out" | grep -Fq 'Current: D / V — exec or verification'; then
  printf '  [PASS] valid c3-prime: verified readiness advances to D/V\n'; pass=$((pass + 1))
else
  printf '  [FAIL] valid c3-prime phase\n%s\n' "$_t111_out" >&2; fail=$((fail + 1))
fi

rm -rf "$_T111_DIR"
pg_extra_contract_finalize
