#!/bin/sh
# PG_EXTRA_CAPABILITY: standalone-capable
# TA-94 — ai-loop V2 PBI materializer (#1442).
#
# This is the CI execution path for scripts/ai-loop/test_pbi_materializer.py.
# It prevents a false green where the Python test file exists but never executes.

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
pg_extra_contract_init ta-94-pbi-materializer standalone-capable

if pg_extra_contract_is_standalone; then
  unset PLANGATE_SKIP_REASON PLANGATE_HOOK_TASK PLANGATE_HOOK_FILE \
    PLANGATE_BYPASS_HOOK PLANGATE_HOOK_STRICT PG_HARNESS_SOURCED \
    PLANGATE_ALLOW_MASS_DELETE 2>/dev/null || true
fi

if [ "$_pg_extra_mode" = harness ]; then
  _T94_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
else
  _T94_ROOT="${_pg_extra_dir%/tests/extras}"
fi

_T94_AI_LOOP="$_T94_ROOT/scripts/ai-loop"
_T94_PLUGIN="$_T94_ROOT/plugin/plangate/skills/ai-loop-cycle/scripts"
_T94_PY="${PLANGATE_PYTHON:-python3}"

printf 'TA-94: ai-loop V2 PBI materializer (#1442)\n'

_t94_tmp=$(mktemp -d)
register_cleanup "$_t94_tmp"

# 1. Unit suite must actually execute at least one test and report OK.
_t94_log="$_t94_tmp/unit.log"
_t94_rc=0
"$_T94_PY" "$_T94_AI_LOOP/test_pbi_materializer.py" >"$_t94_log" 2>&1 || _t94_rc=$?
_t94_n=$(sed -n 's/^Ran \([0-9][0-9]*\) tests* in .*/\1/p' "$_t94_log" | head -1)
[ -n "$_t94_n" ] || _t94_n=0
if [ "$_t94_rc" -eq 0 ] && [ "$_t94_n" -gt 0 ] && grep -q '^OK' "$_t94_log"; then
  printf '  [PASS] unit: test_pbi_materializer.py (Ran %s tests / OK)\n' "$_t94_n"
  pass=$((pass + 1))
else
  printf '  [FAIL] unit: test_pbi_materializer.py failed (rc=%s ran=%s)\n' "$_t94_rc" "$_t94_n" >&2
  sed 's/^/    /' "$_t94_log" >&2
  fail=$((fail + 1))
fi

# 2. Distribution mirror must be byte-identical after sync.
if cmp -s "$_T94_AI_LOOP/pbi_materializer.py" "$_T94_PLUGIN/pbi_materializer.py" \
  && cmp -s "$_T94_AI_LOOP/test_pbi_materializer.py" "$_T94_PLUGIN/test_pbi_materializer.py"; then
  printf '  [PASS] distribution: source/plugin materializer + test are byte-identical\n'
  pass=$((pass + 1))
else
  printf '  [FAIL] distribution: plugin mirror drift detected\n' >&2
  fail=$((fail + 1))
fi

# 3. Existing execution-boundary checker must include the new source tree without violation.
_t94_boundary="$_t94_tmp/boundary.log"
_t94_rc=0
"$_T94_PY" "$_T94_AI_LOOP/check_exec_boundary.py" >"$_t94_boundary" 2>&1 || _t94_rc=$?
if [ "$_t94_rc" -eq 0 ] && grep -q 'clean' "$_t94_boundary"; then
  printf '  [PASS] execution boundary: clean\n'
  pass=$((pass + 1))
else
  printf '  [FAIL] execution boundary: not clean (rc=%s)\n' "$_t94_rc" >&2
  sed 's/^/    /' "$_t94_boundary" >&2
  fail=$((fail + 1))
fi

# 4. First slice must remain shadow-only: parser must not expose a write mode.
if grep -q 'choices=("shadow",)' "$_T94_AI_LOOP/pbi_materializer.py" \
  && ! grep -Eq 'choices=.*write|--write|auto[_-]?write' "$_T94_AI_LOOP/pbi_materializer.py"; then
  printf '  [PASS] rollout boundary: shadow-only CLI; no write mode\n'
  pass=$((pass + 1))
else
  printf '  [FAIL] rollout boundary: shadow-only CLI invariant missing\n' >&2
  fail=$((fail + 1))
fi

# 5. Shadow comparison must execute through the CLI and remain evaluation-only.
_t94_input="$_t94_tmp/input.json"
_t94_expected="$_t94_tmp/expected.json"
_t94_compare="$_t94_tmp/compare.json"
cat >"$_t94_input" <<'JSON'
{
  "task_id": "TASK-1442",
  "title": "shadow probe",
  "author": "human",
  "application_timing": "follow_up",
  "target_layer": "delivery",
  "goal": "probe goal",
  "problem": "probe problem",
  "source_run_refs": [],
  "claims": [],
  "requirements": [],
  "acceptance_criteria": [],
  "in_scope": [],
  "out_of_scope": [],
  "risks": [],
  "unknowns": [],
  "assumptions": [],
  "harness_candidate_ref": null
}
JSON
cat >"$_t94_expected" <<'JSON'
{
  "oracle_ref": "docs/working/TASK-1442/review-shadow.md",
  "decision": "create_new",
  "matched_ref": null,
  "readiness_status": "ready",
  "readiness_route": "future_run"
}
JSON
_t94_rc=0
"$_T94_PY" "$_T94_AI_LOOP/pbi_materializer.py" \
  --input "$_t94_input" --expected "$_t94_expected" --format json \
  >"$_t94_compare" 2>"$_t94_tmp/compare.err" || _t94_rc=$?
if [ "$_t94_rc" -eq 0 ] \
  && grep -q '"shadow_comparison"' "$_t94_compare" \
  && grep -q '"status": "match"' "$_t94_compare" \
  && ! grep -Eq '"write"|"promote"|"apply"' "$_t94_compare"; then
  printf '  [PASS] shadow comparison: CLI emits match evidence without write/promotion authority\n'
  pass=$((pass + 1))
else
  printf '  [FAIL] shadow comparison: CLI wiring/evaluation-only invariant failed (rc=%s)\n' "$_t94_rc" >&2
  sed 's/^/    /' "$_t94_tmp/compare.err" >&2
  fail=$((fail + 1))
fi

# 6. Train/test batch evaluation must execute through the CLI and remain no-write.
_t94_batch="$_t94_tmp/batch.json"
_t94_batch_out="$_t94_tmp/batch-out.json"
cat >"$_t94_batch" <<'JSON'
[
  {
    "case_ref": "train-01",
    "split": "train",
    "payload": {
      "task_id": "TASK-1442",
      "title": "batch train probe",
      "author": "ai",
      "application_timing": "follow_up",
      "target_layer": "delivery",
      "goal": "probe goal",
      "problem": "probe problem",
      "source_run_refs": [],
      "claims": [
        {
          "id": "CLM-001",
          "text": "probe observation",
          "source_ref": "run-evidence:train-01",
          "source_kind": "run_evidence",
          "claim_class": "observed",
          "supports": "Problem"
        }
      ],
      "requirements": [],
      "acceptance_criteria": [],
      "in_scope": [],
      "out_of_scope": [],
      "risks": [],
      "unknowns": [],
      "assumptions": [],
      "harness_candidate_ref": null
    },
    "existing_work": [],
    "expected": {
      "oracle_ref": "docs/working/TASK-1442/train-01.md",
      "decision": "create_new",
      "matched_ref": null,
      "readiness_status": "ready",
      "readiness_route": "future_run"
    }
  },
  {
    "case_ref": "test-01",
    "split": "test",
    "payload": {
      "task_id": "TASK-1442",
      "title": "batch test probe",
      "author": "ai",
      "application_timing": "follow_up",
      "target_layer": "delivery",
      "goal": "probe goal",
      "problem": "probe problem",
      "source_run_refs": [],
      "claims": [
        {
          "id": "CLM-001",
          "text": "probe observation",
          "source_ref": "run-evidence:test-01",
          "source_kind": "run_evidence",
          "claim_class": "observed",
          "supports": "Problem"
        }
      ],
      "requirements": [],
      "acceptance_criteria": [],
      "in_scope": [],
      "out_of_scope": [],
      "risks": [],
      "unknowns": [],
      "assumptions": [],
      "harness_candidate_ref": null
    },
    "existing_work": [],
    "expected": {
      "oracle_ref": "docs/working/TASK-1442/test-01.md",
      "decision": "create_new",
      "matched_ref": null,
      "readiness_status": "ready",
      "readiness_route": "future_run"
    }
  }
]
JSON
_t94_rc=0
"$_T94_PY" "$_T94_AI_LOOP/pbi_materializer.py"   --eval-batch "$_t94_batch" --format json   >"$_t94_batch_out" 2>"$_t94_tmp/batch.err" || _t94_rc=$?
if [ "$_t94_rc" -eq 0 ]   && grep -q '"mode": "shadow_evaluation"' "$_t94_batch_out"   && grep -q '"write_allowed": false' "$_t94_batch_out"   && grep -q '"automatic_promotion": false' "$_t94_batch_out"   && grep -q '"holdout_isolation_enforced": false' "$_t94_batch_out"   && grep -q '"generalization_claim_allowed": false' "$_t94_batch_out"   && grep -q '"exact_match_rate": 1.0' "$_t94_batch_out"   && grep -q '"split": "train"' "$_t94_batch_out"   && grep -q '"split": "test"' "$_t94_batch_out"; then
  printf '  [PASS] shadow batch: train/test CLI path fired with no write/promotion authority\n'
  pass=$((pass + 1))
else
  printf '  [FAIL] shadow batch: train/test CLI path failed (rc=%s)\n' "$_t94_rc" >&2
  sed 's/^/    /' "$_t94_tmp/batch.err" >&2
  fail=$((fail + 1))
fi


# 7. Repository-grounded historical replay must stay separate from synthetic/live evidence.
_t94_history="$_T94_ROOT/tests/fixtures/ai-loop/pbi-materializer/historical-replay.json"
_t94_history_out="$_t94_tmp/history-out.json"
_t94_rc=0
"$_T94_PY" "$_T94_AI_LOOP/pbi_materializer.py" \
  --eval-batch "$_t94_history" --authority-root "$_T94_ROOT" --format json \
  >"$_t94_history_out" 2>"$_t94_tmp/history.err" || _t94_rc=$?
if [ "$_t94_rc" -eq 0 ] \
  && grep -q '"historical_replay_cases": 2' "$_t94_history_out" \
  && grep -q '"synthetic_fixture_cases": 0' "$_t94_history_out" \
  && grep -q '"live_shadow_cases": 0' "$_t94_history_out" \
  && grep -q '"evidence_class": "historical_replay"' "$_t94_history_out" \
  && grep -q '"exact_match_rate": 1.0' "$_t94_history_out" \
  && grep -q '"scope": "post_admission_materialization"' "$_t94_history_out" \
  && grep -q '"materialization_admission_evaluated": false' "$_t94_history_out" \
  && grep -q '"no_action_coverage": false' "$_t94_history_out" \
  && grep -q '"historical_live_oracle_repository_visibility_enforced": true' "$_t94_history_out" \
  && grep -q '"source_oracle_artifact_separation_enforced": true' "$_t94_history_out" \
  && grep -q '"oracle_independence_enforced": false' "$_t94_history_out" \
  && grep -q '"live_shadow_capture_metadata_enforced": true' "$_t94_history_out" \
  && grep -q '"live_shadow_label_alone_sufficient": false' "$_t94_history_out" \
  && grep -q '"live_shadow_run_evidence_binding_enforced": true' "$_t94_history_out" \
  && grep -q '"run_evidence_schema_revalidated": true' "$_t94_history_out" \
  && grep -q '"runtime_head_to_run_evidence_binding_enforced": true' "$_t94_history_out" \
  && grep -q '"live_capture_requires_concrete_final_head_sha": true' "$_t94_history_out" \
  && grep -q '"unavailable_final_head_live_capture_supported": false' "$_t94_history_out" \
  && grep -q '"run_evidence_task_binding_reverified": false' "$_t94_history_out" \
  && grep -q '"write_review_eligible": false' "$_t94_history_out" \
  && grep -q '"observed_decisions": \[' "$_t94_history_out" \
  && grep -q '"create_new"' "$_t94_history_out" \
  && grep -q '"write_allowed": false' "$_t94_history_out"; then
  printf '  [PASS] historical replay: 2 repository-grounded cases evaluated separately from synthetic/live evidence\n'
  pass=$((pass + 1))
else
  printf '  [FAIL] historical replay: repository-grounded corpus failed (rc=%s)\n' "$_t94_rc" >&2
  sed 's/^/    /' "$_t94_tmp/history.err" >&2
  fail=$((fail + 1))
fi

# 8. Repository-grounded PBI admission replay must cover materialize + no_action.
_t94_admission="$_T94_ROOT/tests/fixtures/ai-loop/pbi-materializer/historical-admission.json"
_t94_admission_out="$_t94_tmp/admission-out.json"
_t94_rc=0
"$_T94_PY" "$_T94_AI_LOOP/pbi_materializer.py" \
  --eval-admission-batch "$_t94_admission" --authority-root "$_T94_ROOT" --format json \
  >"$_t94_admission_out" 2>"$_t94_tmp/admission.err" || _t94_rc=$?
if [ "$_t94_rc" -eq 0 ] \
  && grep -q '"mode": "admission_evaluation"' "$_t94_admission_out" \
  && grep -q '"historical_replay_cases": 2' "$_t94_admission_out" \
  && grep -q '"no_action_coverage": true' "$_t94_admission_out" \
  && grep -q '"materialize_coverage": true' "$_t94_admission_out" \
  && grep -q '"discover_more_coverage": false' "$_t94_admission_out" \
  && grep -q '"decision_coverage_complete": false' "$_t94_admission_out" \
  && grep -q '"live_shadow_capture_metadata_enforced": true' "$_t94_admission_out" \
  && grep -q '"live_shadow_label_alone_sufficient": false' "$_t94_admission_out" \
  && grep -q '"live_shadow_run_evidence_binding_enforced": true' "$_t94_admission_out" \
  && grep -q '"run_evidence_schema_revalidated": true' "$_t94_admission_out" \
  && grep -q '"runtime_head_to_run_evidence_binding_enforced": true' "$_t94_admission_out" \
  && grep -q '"live_capture_requires_concrete_final_head_sha": true' "$_t94_admission_out" \
  && grep -q '"unavailable_final_head_live_capture_supported": false' "$_t94_admission_out" \
  && grep -q '"run_evidence_task_binding_reverified": false' "$_t94_admission_out" \
  && grep -q '"write_review_eligible": false' "$_t94_admission_out" \
  && grep -q '"write_allowed": false' "$_t94_admission_out" \
  && grep -q '"close_allowed": false' "$_t94_admission_out" \
  && grep -q '"suppression_allowed": false' "$_t94_admission_out"; then
  printf '  [PASS] admission replay: historical materialize/no_action evaluated with no close/write authority\n'
  pass=$((pass + 1))
else
  printf '  [FAIL] admission replay: historical admission corpus failed (rc=%s)\n' "$_t94_rc" >&2
  sed 's/^/    /' "$_t94_tmp/admission.err" >&2
  fail=$((fail + 1))
fi

# 9. Passive capture CLI must fire and remain stdout-only/non-authoritative.
_t94_signal="$_t94_tmp/live-signal.json"
_t94_capture_out="$_t94_tmp/live-capture.json"
_t94_forbidden_ref="docs/working/TASK-1442/evidence/pbi-materializer-shadow/__ta94_should_not_be_written.json"
cat >"$_t94_signal" <<'JSON'
{
  "signal_id": "SIG-TA94-LIVE",
  "source_ref": "TASK-1442/delivery/record.jsonl",
  "source_kind": "existing_behavior",
  "claim_class": "observed",
  "statement": "TA-94 passive capture probe.",
  "disposition": "actionable",
  "target_layer": "delivery",
  "candidate_problem": "Probe the passive live-shadow capture path."
}
JSON
_t94_rc=0
"$_T94_PY" "$_T94_AI_LOOP/pbi_materializer.py" \
  --capture-signal "$_t94_signal" \
  --capture-task-id TASK-1442 \
  --capture-run-id ta94-live-run \
  --captured-at 2026-10-03T04:00:00Z \
  --runtime-head-sha aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa \
  --capture-ref "$_t94_forbidden_ref" \
  --format json \
  >"$_t94_capture_out" 2>"$_t94_tmp/capture.err" || _t94_rc=$?
if [ "$_t94_rc" -eq 0 ] \
  && grep -q '"mode": "passive_shadow_capture"' "$_t94_capture_out" \
  && grep -q '"write_allowed": false' "$_t94_capture_out" \
  && grep -q '"close_allowed": false' "$_t94_capture_out" \
  && grep -q '"suppression_allowed": false' "$_t94_capture_out" \
  && grep -q '"oracle_attached": false' "$_t94_capture_out" \
  && grep -q '"signal_hash": "sha256:' "$_t94_capture_out" \
  && [ ! -e "$_T94_ROOT/$_t94_forbidden_ref" ]; then
  printf '  [PASS] passive capture: CLI fires via stdout only with no write/close/suppression/oracle authority\n'
  pass=$((pass + 1))
else
  printf '  [FAIL] passive capture: CLI path or no-write invariant failed (rc=%s)\n' "$_t94_rc" >&2
  sed 's/^/    /' "$_t94_tmp/capture.err" >&2
  fail=$((fail + 1))
fi

# 10. Aggregate write-review assessment must fire without granting write authority.
_t94_review_root="$_t94_tmp/review-root"
mkdir -p "$_t94_review_root/docs/reports" "$_t94_review_root/docs/reviews" "$_t94_review_root/scripts"
printf '# Independent oracle review\n' >"$_t94_review_root/docs/reviews/oracle.md"

cat >"$_t94_review_root/docs/reports/materialization.json" <<'JSON'
{
  "mode": "shadow_evaluation",
  "write_allowed": false,
  "automatic_promotion": false,
  "metrics": {"overall": {"errors": 0}},
  "rollout_evidence": {
    "live_shadow_cases": 3,
    "observed_decisions": ["create_new", "link_only", "update_existing"]
  },
  "rollout_quality": {
      "scope": "live_shadow_only",
      "live_case_total": 3,
      "evaluable_case_total": 3,
      "unevaluable_error_cases": 0,
      "quality_review_complete": true,
      "duplicate_false_positive_count": 0,
      "duplicate_false_positive_denominator": 1,
      "duplicate_false_positive_rate": 0.0,
      "duplicate_false_negative_count": 0,
      "duplicate_false_negative_denominator": 2,
      "duplicate_false_negative_rate": 0.0,
      "decision_mismatch_count": 0,
      "matched_ref_mismatch_count": 0,
      "readiness_mismatch_count": 0,
      "exact_mismatch_count": 0,
      "rejection_error_occurrences_by_category": {
        "privacy": 0,
        "circular_or_derived": 0,
        "acceptance_basis": 0,
        "claim_class": 0,
        "source_reference": 0,
        "live_binding": 0,
        "other": 0
      },
      "provenance_rejection_error_occurrences": {
        "circular_or_derived": 0,
        "acceptance_basis": 0,
        "claim_class": 0,
        "source_reference": 0
      },
      "thresholds_applied": false,
      "acceptance_decision": "not_evaluated",
      "acceptance_owner": "human_or_rollout_policy"
    },
  "cases": [
    {"case_ref": "M-CREATE", "evidence_class": "live_shadow", "status": "match", "mismatches": [], "actual_decision": "create_new", "actual_readiness_route": "future_run", "expected_decision": "create_new"},
    {"case_ref": "M-LINK", "evidence_class": "live_shadow", "status": "match", "mismatches": [], "actual_decision": "link_only", "actual_readiness_route": "future_run", "expected_decision": "link_only"},
    {"case_ref": "M-UPDATE", "evidence_class": "live_shadow", "status": "match", "mismatches": [], "actual_decision": "update_existing", "actual_readiness_route": "future_run", "expected_decision": "update_existing"}
  ]
}
JSON

cat >"$_t94_review_root/docs/reports/admission.json" <<'JSON'
{
  "mode": "admission_evaluation",
  "write_allowed": false,
  "close_allowed": false,
  "suppression_allowed": false,
  "automatic_promotion": false,
  "metrics": {"overall": {"errors": 0}},
  "rollout_evidence": {"live_shadow_cases": 3},
  "rollout_quality": {
      "scope": "live_shadow_only",
      "live_case_total": 3,
      "evaluable_case_total": 3,
      "unevaluable_error_cases": 0,
      "quality_review_complete": true,
      "materialize_false_positive_count": 0,
      "materialize_false_positive_denominator": 2,
      "materialize_false_positive_rate": 0.0,
      "materialize_false_negative_count": 0,
      "materialize_false_negative_denominator": 1,
      "materialize_false_negative_rate": 0.0,
      "decision_mismatch_count": 0,
      "rejection_error_occurrences_by_category": {
        "privacy": 0,
        "circular_or_derived": 0,
        "acceptance_basis": 0,
        "claim_class": 0,
        "source_reference": 0,
        "live_binding": 0,
        "other": 0
      },
      "provenance_rejection_error_occurrences": {
        "circular_or_derived": 0,
        "acceptance_basis": 0,
        "claim_class": 0,
        "source_reference": 0
      },
      "thresholds_applied": false,
      "acceptance_decision": "not_evaluated",
      "acceptance_owner": "human_or_rollout_policy"
    },
  "coverage": {
    "decision_coverage_complete": true,
    "observed_admission_decisions": ["discover_more", "materialize", "no_action"]
  },
  "cases": [
    {"case_ref": "A-DISCOVER", "evidence_class": "live_shadow", "status": "match", "actual": "discover_more", "expected": "discover_more"},
    {"case_ref": "A-MATERIALIZE", "evidence_class": "live_shadow", "status": "match", "actual": "materialize", "expected": "materialize"},
    {"case_ref": "A-NO-ACTION", "evidence_class": "live_shadow", "status": "match", "actual": "no_action", "expected": "no_action"}
  ]
}
JSON

cat >"$_t94_tmp/write-review-assessment.json" <<'JSON'
{
  "materialization_report": {
    "mode": "shadow_evaluation",
    "write_allowed": false,
    "automatic_promotion": false,
    "metrics": {"overall": {"errors": 0}},
    "rollout_evidence": {
      "live_shadow_cases": 3,
      "observed_decisions": ["create_new", "link_only", "update_existing"]
    },
    "rollout_quality": {
        "scope": "live_shadow_only",
        "live_case_total": 3,
        "evaluable_case_total": 3,
        "unevaluable_error_cases": 0,
        "quality_review_complete": true,
        "duplicate_false_positive_count": 0,
        "duplicate_false_positive_denominator": 1,
        "duplicate_false_positive_rate": 0.0,
        "duplicate_false_negative_count": 0,
        "duplicate_false_negative_denominator": 2,
        "duplicate_false_negative_rate": 0.0,
        "decision_mismatch_count": 0,
        "matched_ref_mismatch_count": 0,
        "readiness_mismatch_count": 0,
        "exact_mismatch_count": 0,
        "rejection_error_occurrences_by_category": {
          "privacy": 0,
          "circular_or_derived": 0,
          "acceptance_basis": 0,
          "claim_class": 0,
          "source_reference": 0,
          "live_binding": 0,
          "other": 0
        },
        "provenance_rejection_error_occurrences": {
          "circular_or_derived": 0,
          "acceptance_basis": 0,
          "claim_class": 0,
          "source_reference": 0
        },
        "thresholds_applied": false,
        "acceptance_decision": "not_evaluated",
        "acceptance_owner": "human_or_rollout_policy"
      },
    "cases": [
      {"case_ref": "M-CREATE", "evidence_class": "live_shadow", "status": "match", "mismatches": [], "actual_decision": "create_new", "actual_readiness_route": "future_run", "expected_decision": "create_new"},
      {"case_ref": "M-LINK", "evidence_class": "live_shadow", "status": "match", "mismatches": [], "actual_decision": "link_only", "actual_readiness_route": "future_run", "expected_decision": "link_only"},
      {"case_ref": "M-UPDATE", "evidence_class": "live_shadow", "status": "match", "mismatches": [], "actual_decision": "update_existing", "actual_readiness_route": "future_run", "expected_decision": "update_existing"}
    ]
  },
  "materialization_report_ref": "docs/reports/materialization.json",
  "admission_report": {
    "mode": "admission_evaluation",
    "write_allowed": false,
    "close_allowed": false,
    "suppression_allowed": false,
    "automatic_promotion": false,
    "metrics": {"overall": {"errors": 0}},
    "rollout_evidence": {"live_shadow_cases": 3},
    "rollout_quality": {
        "scope": "live_shadow_only",
        "live_case_total": 3,
        "evaluable_case_total": 3,
        "unevaluable_error_cases": 0,
        "quality_review_complete": true,
        "materialize_false_positive_count": 0,
        "materialize_false_positive_denominator": 2,
        "materialize_false_positive_rate": 0.0,
        "materialize_false_negative_count": 0,
        "materialize_false_negative_denominator": 1,
        "materialize_false_negative_rate": 0.0,
        "decision_mismatch_count": 0,
        "rejection_error_occurrences_by_category": {
          "privacy": 0,
          "circular_or_derived": 0,
          "acceptance_basis": 0,
          "claim_class": 0,
          "source_reference": 0,
          "live_binding": 0,
          "other": 0
        },
        "provenance_rejection_error_occurrences": {
          "circular_or_derived": 0,
          "acceptance_basis": 0,
          "claim_class": 0,
          "source_reference": 0
        },
        "thresholds_applied": false,
        "acceptance_decision": "not_evaluated",
        "acceptance_owner": "human_or_rollout_policy"
      },
    "coverage": {
      "decision_coverage_complete": true,
      "observed_admission_decisions": ["discover_more", "materialize", "no_action"]
    },
    "cases": [
      {"case_ref": "A-DISCOVER", "evidence_class": "live_shadow", "status": "match", "actual": "discover_more", "expected": "discover_more"},
      {"case_ref": "A-MATERIALIZE", "evidence_class": "live_shadow", "status": "match", "actual": "materialize", "expected": "materialize"},
      {"case_ref": "A-NO-ACTION", "evidence_class": "live_shadow", "status": "match", "actual": "no_action", "expected": "no_action"}
    ]
  },
  "admission_report_ref": "docs/reports/admission.json",
  "context": {
    "design_dependency_finalized": true,
    "latest_full_test_green": true,
    "generalization_claim_requested": false,
    "independent_oracle_review_ref": "docs/reviews/oracle.md",
    "isolated_holdout_review_ref": null
  }
}
JSON

_t94_review_out="$_t94_tmp/write-review-out.json"
_t94_rc=0
"$_T94_PY" "$_T94_AI_LOOP/pbi_materializer.py" \
  --assess-write-review "$_t94_tmp/write-review-assessment.json" \
  --authority-root "$_t94_review_root" --format json \
  >"$_t94_review_out" 2>"$_t94_tmp/write-review.err" || _t94_rc=$?
if [ "$_t94_rc" -eq 0 ] \
  && grep -q '"mode": "write_review_assessment"' "$_t94_review_out" \
  && grep -q '"write_review_ready": true' "$_t94_review_out" \
  && grep -q '"write_allowed": false' "$_t94_review_out" \
  && grep -q '"close_allowed": false' "$_t94_review_out" \
  && grep -q '"suppression_allowed": false' "$_t94_review_out" \
  && grep -q '"automatic_promotion": false' "$_t94_review_out" \
  && grep -q '"report_artifact_authorship_verified": false' "$_t94_review_out" \
  && grep -q '"quality_thresholds_applied": false' "$_t94_review_out" \
  && grep -q '"quality_acceptance_decided": false' "$_t94_review_out" \
  && grep -q '"duplicate_false_positive_rate": 0.0' "$_t94_review_out" \
  && grep -q '"duplicate_false_negative_rate": 0.0' "$_t94_review_out" \
  && grep -q '"acceptance_decision": "not_evaluated"' "$_t94_review_out" \
  && grep -q '"materialization_report_hash": "sha256:' "$_t94_review_out" \
  && grep -q '"admission_report_hash": "sha256:' "$_t94_review_out"; then
  printf '  [PASS] write-review assessment: CLI fires with traceable reports and no mutation authority\n'
  pass=$((pass + 1))
else
  printf '  [FAIL] write-review assessment: CLI wiring or authority invariant failed (rc=%s)\n' "$_t94_rc" >&2
  sed 's/^/    /' "$_t94_tmp/write-review.err" >&2
  fail=$((fail + 1))
fi

# 11. Cross-module live-shadow E2E: capture -> RunEvidence binding -> admission evaluation.
_t94_live_root="$_t94_tmp/live-root"
mkdir -p \
  "$_t94_live_root/docs/live" \
  "$_t94_live_root/docs/reviews" \
  "$_t94_live_root/scripts" \
  "$_t94_live_root/TASK-9999/delivery"
printf '{"kind":"state","state":"MERGE_READY"}\n' \
  >"$_t94_live_root/TASK-9999/delivery/record.jsonl"
printf '# Independent live admission oracle\n' \
  >"$_t94_live_root/docs/reviews/live-admission.md"

_t94_live_signal="$_t94_tmp/e2e-live-signal.json"
cat >"$_t94_live_signal" <<'JSON'
{
  "signal_id": "SIG-TA94-E2E",
  "source_ref": "TASK-9999/delivery/record.jsonl",
  "source_kind": "existing_behavior",
  "claim_class": "observed",
  "statement": "Completed run has no new PBI-worthy finding.",
  "disposition": "informational",
  "target_layer": "delivery",
  "candidate_problem": null
}
JSON

_t94_live_capture_ref="docs/live/capture.json"
_t94_live_ev_ref="docs/live/run-evidence.json"
_t94_rc=0
"$_T94_PY" "$_T94_AI_LOOP/pbi_materializer.py" \
  --capture-signal "$_t94_live_signal" \
  --capture-task-id TASK-9999 \
  --capture-run-id run-01 \
  --captured-at 2099-12-31T12:00:00Z \
  --runtime-head-sha abcdef1234567890abcdef1234567890abcdef12 \
  --capture-ref "$_t94_live_capture_ref" \
  --format json \
  >"$_t94_live_root/$_t94_live_capture_ref" \
  2>"$_t94_tmp/e2e-capture.err" || _t94_rc=$?

if [ "$_t94_rc" -eq 0 ]; then
  "$_T94_PY" - \
    "$_T94_ROOT/tests/fixtures/run-evidence/fx-01-first-pass.json" \
    "$_t94_live_root/$_t94_live_ev_ref" \
    "$_t94_live_capture_ref" <<'PY'
import json
import pathlib
import sys

src = pathlib.Path(sys.argv[1])
dst = pathlib.Path(sys.argv[2])
capture_ref = sys.argv[3]
record = json.loads(src.read_text(encoding="utf-8"))
record["evidence_refs"] = list(dict.fromkeys(record["evidence_refs"] + [capture_ref]))
dst.write_text(
    json.dumps(record, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
PY
  _t94_rc=$?
fi

_t94_live_batch="$_t94_tmp/e2e-live-admission.json"
cat >"$_t94_live_batch" <<JSON
[
  {
    "case_ref": "LIVE-TA94-E2E",
    "split": "test",
    "evidence_class": "live_shadow",
    "evidence_refs": [
      "TASK-9999/delivery/record.jsonl",
      "$_t94_live_capture_ref",
      "$_t94_live_ev_ref"
    ],
    "live_capture": {
      "capture_ref": "$_t94_live_capture_ref",
      "run_evidence_ref": "$_t94_live_ev_ref"
    },
    "signal": {
      "signal_id": "SIG-TA94-E2E",
      "source_ref": "TASK-9999/delivery/record.jsonl",
      "source_kind": "existing_behavior",
      "claim_class": "observed",
      "statement": "Completed run has no new PBI-worthy finding.",
      "disposition": "informational",
      "target_layer": "delivery",
      "candidate_problem": null
    },
    "expected": {
      "oracle_ref": "docs/reviews/live-admission.md",
      "admission_decision": "no_action"
    }
  }
]
JSON

_t94_live_out="$_t94_tmp/e2e-live-out.json"
if [ "$_t94_rc" -eq 0 ]; then
  "$_T94_PY" "$_T94_AI_LOOP/pbi_materializer.py" \
    --eval-admission-batch "$_t94_live_batch" \
    --authority-root "$_t94_live_root" --format json \
    >"$_t94_live_out" 2>"$_t94_tmp/e2e-live.err" || _t94_rc=$?
fi

if [ "$_t94_rc" -eq 0 ] \
  && grep -q '"mode": "admission_evaluation"' "$_t94_live_out" \
  && grep -q '"live_shadow_cases": 1' "$_t94_live_out" \
  && grep -q '"no_action_coverage": true' "$_t94_live_out" \
  && grep -q '"live_case_total": 1' "$_t94_live_out" \
  && grep -q '"materialize_false_positive_rate": 0.0' "$_t94_live_out" \
  && grep -q '"materialize_false_negative_rate": null' "$_t94_live_out" \
  && grep -q '"thresholds_applied": false' "$_t94_live_out" \
  && grep -q '"upstream_source_repository_visibility_enforced": true' "$_t94_live_out" \
  && grep -q '"source_capture_run_evidence_separation_enforced": true' "$_t94_live_out" \
  && grep -q '"upstream_source_preexistence_verified": false' "$_t94_live_out" \
  && grep -q '"write_allowed": false' "$_t94_live_out" \
  && grep -q '"close_allowed": false' "$_t94_live_out" \
  && grep -q '"suppression_allowed": false' "$_t94_live_out"; then
  printf '  [PASS] live-shadow E2E: capture -> RunEvidence binding -> admission evaluation\n'
  pass=$((pass + 1))
else
  printf '  [FAIL] live-shadow E2E: cross-module chain failed (rc=%s)\n' "$_t94_rc" >&2
  sed 's/^/    /' "$_t94_tmp/e2e-capture.err" >&2
  sed 's/^/    /' "$_t94_tmp/e2e-live.err" >&2
  fail=$((fail + 1))
fi

# 12. Operational skill wiring must be present on every shipped execution surface.
_t94_agents_skill="$_T94_ROOT/.agents/skills/ai-loop-cycle/SKILL.md"
_t94_codex_skill="$_T94_ROOT/.codex/skills/ai-loop-cycle/SKILL.md"
_t94_plugin_skill="$_T94_ROOT/plugin/plangate/skills/ai-loop-cycle/SKILL.md"
_t94_claude_skill="$_T94_ROOT/.claude/skills/ai-loop-cycle/SKILL.md"
if cmp -s "$_t94_agents_skill" "$_t94_codex_skill" \
  && cmp -s "$_t94_agents_skill" "$_t94_plugin_skill" \
  && grep -q '## Step 6: RunEvidence + passive PBI live-shadow capture' "$_t94_agents_skill" \
  && grep -q -- '--capture-signal' "$_t94_agents_skill" \
  && grep -q -- '--evidence-ref' "$_t94_agents_skill" \
  && grep -q 'signal が無い run にダミー signal / capture を作ってはならない' "$_t94_agents_skill" \
  && grep -q '## Step 6: RunEvidence + passive PBI live-shadow capture' "$_t94_claude_skill" \
  && grep -q 'scripts/ai-loop/pbi_materializer.py' "$_t94_claude_skill"; then
  printf '  [PASS] skill wiring: agents/codex/plugin aligned; Claude local flow wired\n'
  pass=$((pass + 1))
else
  printf '  [FAIL] skill wiring: live-shadow operational instructions drifted\n' >&2
  fail=$((fail + 1))
fi

rm -rf "$_t94_tmp"
pg_extra_contract_finalize
