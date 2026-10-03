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
  && grep -q '### 6.4 Evidence collector（実runでの推奨経路）' "$_t94_agents_skill" \
  && grep -q 'pbi_live_shadow_collector.py' "$_t94_agents_skill" \
  && grep -q -- '--case-artifact-ref' "$_t94_agents_skill" \
  && grep -q '### 6.6 Live Materialization review（post-admission）' "$_t94_agents_skill" \
  && grep -q 'materialization-inventory' "$_t94_agents_skill" \
  && grep -q '### 6.7 Live collection plan（read-only / non-quota）' "$_t94_agents_skill" \
  && grep -q 'collection-plan' "$_t94_agents_skill" \
  && grep -q 'coverage_gap_basis = reviewed_expected_decisions' "$_t94_agents_skill" \
  && grep -q 'maker_actual_counts_as_ground_truth_coverage = false' "$_t94_agents_skill" \
  && grep -q 'signal が無い run にダミー signal / capture を作ってはならない' "$_t94_agents_skill" \
  && grep -q '## Step 6: RunEvidence + passive PBI live-shadow capture' "$_t94_claude_skill" \
  && grep -q 'scripts/ai-loop/pbi_materializer.py' "$_t94_claude_skill" \
  && grep -q 'scripts/ai-loop/pbi_live_shadow_collector.py' "$_t94_claude_skill"; then
  printf '  [PASS] skill wiring: agents/codex/plugin aligned; Claude local flow wired\n'
  pass=$((pass + 1))
else
  printf '  [FAIL] skill wiring: live-shadow operational instructions drifted\n' >&2
  fail=$((fail + 1))
fi

# 13. Live-shadow collector must be installed, fired, blind, and evaluator-compatible.
_t94_collector="$_T94_AI_LOOP/pbi_live_shadow_collector.py"
_t94_collector_test="$_T94_AI_LOOP/test_pbi_live_shadow_collector.py"
_t94_plugin_collector="$_T94_ROOT/plugin/plangate/skills/ai-loop-cycle/scripts/pbi_live_shadow_collector.py"
_t94_plugin_collector_test="$_T94_ROOT/plugin/plangate/skills/ai-loop-cycle/scripts/test_pbi_live_shadow_collector.py"
_t94_collector_log="$_t94_tmp/collector-unit.log"
_t94_rc=0
"$_T94_PY" "$_t94_collector_test" >"$_t94_collector_log" 2>&1 || _t94_rc=$?
if [ "$_t94_rc" -eq 0 ] \
  && grep -Eq 'Ran [1-9][0-9]* tests?' "$_t94_collector_log" \
  && grep -q '^OK$' "$_t94_collector_log" \
  && cmp -s "$_t94_collector" "$_t94_plugin_collector" \
  && cmp -s "$_t94_collector_test" "$_t94_plugin_collector_test"; then
  printf '  [PASS] live collector: unit suite fired and plugin mirrors are byte-identical\n'
  pass=$((pass + 1))
else
  printf '  [FAIL] live collector: unit suite/distribution check failed (rc=%s)\n' "$_t94_rc" >&2
  sed 's/^/    /' "$_t94_collector_log" >&2
  fail=$((fail + 1))
fi

_t94_collect_root="$_t94_tmp/collector-root"
mkdir -p "$_t94_collect_root/scripts" "$_t94_collect_root/docs" "$_t94_collect_root/TASK-9999/delivery"
printf '{"kind":"state","state":"MERGE_READY"}\n' >"$_t94_collect_root/TASK-9999/delivery/record.jsonl"

_t94_collect_signal="$_t94_tmp/collector-signal.json"
cat >"$_t94_collect_signal" <<'JSON'
{
  "signal_id": "SIG-TA94-COLLECTOR",
  "source_ref": "TASK-9999/delivery/record.jsonl",
  "source_kind": "existing_behavior",
  "claim_class": "observed",
  "statement": "Completed run has no new PBI-worthy finding.",
  "disposition": "informational",
  "target_layer": "delivery",
  "candidate_problem": null
}
JSON

_t94_cbase="docs/working/TASK-9999/evidence/pbi-live-shadow/run-01"
_t94_ccap="$_t94_cbase/capture.json"
_t94_cev="$_t94_cbase/run-evidence.json"
_t94_cpacket="$_t94_cbase/review-packet.json"
_t94_coracle="$_t94_cbase/oracle.json"
_t94_ccase="$_t94_cbase/admission-case.json"
_t94_rc=0

"$_T94_PY" "$_t94_collector" --repo-root "$_t94_collect_root" capture \
  --signal "$_t94_collect_signal" \
  --task-id TASK-9999 --run-id run-01 \
  --captured-at 2099-12-31T12:00:00Z \
  --runtime-head-sha abcdef1234567890abcdef1234567890abcdef12 \
  --capture-ref "$_t94_ccap" \
  >"$_t94_tmp/collector-capture.out" 2>"$_t94_tmp/collector-capture.err" || _t94_rc=$?

if [ "$_t94_rc" -eq 0 ]; then
  "$_T94_PY" - \
    "$_T94_ROOT/tests/fixtures/run-evidence/fx-01-first-pass.json" \
    "$_t94_collect_root/$_t94_cev" \
    "$_t94_ccap" <<'PY'
import json
import pathlib
import sys

src = pathlib.Path(sys.argv[1])
dst = pathlib.Path(sys.argv[2])
capture_ref = sys.argv[3]
record = json.loads(src.read_text(encoding="utf-8"))
record["run_id"] = "run-02"
record["evidence_refs"] = list(dict.fromkeys(
    record["evidence_refs"]
    + ["TASK-9999/delivery/record.jsonl", capture_ref]
))
dst.parent.mkdir(parents=True, exist_ok=True)
dst.write_text(
    json.dumps(record, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
PY
  _t94_rc=$?
fi

if [ "$_t94_rc" -eq 0 ]; then
  "$_T94_PY" "$_t94_collector" --repo-root "$_t94_collect_root" packet \
    --capture-ref "$_t94_ccap" \
    --run-evidence-ref "$_t94_cev" \
    --packet-ref "$_t94_cpacket" \
    >"$_t94_tmp/collector-packet.out" 2>"$_t94_tmp/collector-packet.err" || _t94_rc=$?
fi

if [ "$_t94_rc" -eq 0 ]; then
  "$_T94_PY" - \
    "$_T94_ROOT/scripts/ai-loop" \
    "$_t94_collect_root/$_t94_cpacket" \
    "$_t94_collect_root/TASK-9999/delivery/record.jsonl" \
    "$_t94_collect_root/$_t94_coracle" \
    "$_t94_cpacket" <<'PY'
import hashlib
import json
import pathlib
import sys

sys.path.insert(0, sys.argv[1])
import pbi_materializer as pm

packet_path = pathlib.Path(sys.argv[2])
source_path = pathlib.Path(sys.argv[3])
oracle_path = pathlib.Path(sys.argv[4])
packet_ref = sys.argv[5]
packet = json.loads(packet_path.read_text(encoding="utf-8"))
oracle = {
    "schema_version": 1,
    "domain": "plangate.pbi-live-shadow-admission-oracle/v1",
    "case_ref": "LIVE-TA94-COLLECTOR",
    "packet_ref": packet_ref,
    "packet_hash": pm._canonical_json_hash(packet),
    "reviewed_source_ref": "TASK-9999/delivery/record.jsonl",
    "reviewed_source_sha256": "sha256:" + hashlib.sha256(source_path.read_bytes()).hexdigest(),
    "expected_admission_decision": "no_action",
    "independent_review_asserted": True,
    "maker_actual_not_consulted_asserted": True,
}
oracle_path.parent.mkdir(parents=True, exist_ok=True)
oracle_path.write_text(
    json.dumps(oracle, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
PY
  _t94_rc=$?
fi

if [ "$_t94_rc" -eq 0 ]; then
  "$_T94_PY" "$_t94_collector" --repo-root "$_t94_collect_root" case \
    --packet-ref "$_t94_cpacket" \
    --oracle-ref "$_t94_coracle" \
    --case-artifact-ref "$_t94_ccase" \
    >"$_t94_tmp/collector-case.out" 2>"$_t94_tmp/collector-case.err" || _t94_rc=$?
fi

_t94_collector_batch="$_t94_tmp/collector-batch.json"
if [ "$_t94_rc" -eq 0 ]; then
  "$_T94_PY" - "$_t94_collect_root/$_t94_ccase" "$_t94_collector_batch" <<'PY'
import json
import pathlib
import sys

case = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
pathlib.Path(sys.argv[2]).write_text(
    json.dumps([case], ensure_ascii=False, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
PY
  _t94_rc=$?
fi

if [ "$_t94_rc" -eq 0 ]; then
  "$_T94_PY" "$_T94_AI_LOOP/pbi_materializer.py" \
    --eval-admission-batch "$_t94_collector_batch" \
    --authority-root "$_t94_collect_root" --format json \
    >"$_t94_tmp/collector-eval.out" 2>"$_t94_tmp/collector-eval.err" || _t94_rc=$?
fi

if [ "$_t94_rc" -eq 0 ] \
  && grep -q '"artifact_reused": false' "$_t94_tmp/collector-capture.out" \
  && grep -q '"actual_decision_disclosed": false' "$_t94_tmp/collector-packet.out" \
  && ! grep -q '"actual_admission_decision"' "$_t94_tmp/collector-packet.out" \
  && grep -q '"oracle_authorship_verified": false' "$_t94_tmp/collector-case.out" \
  && grep -q '"mode": "admission_evaluation"' "$_t94_tmp/collector-eval.out" \
  && grep -q '"status": "match"' "$_t94_tmp/collector-eval.out" \
  && grep -q '"live_shadow_cases": 1' "$_t94_tmp/collector-eval.out" \
  && grep -q '"write_allowed": false' "$_t94_tmp/collector-eval.out" \
  && grep -q '"suppression_allowed": false' "$_t94_tmp/collector-eval.out"; then
  printf '  [PASS] live collector E2E: capture -> blind packet -> oracle -> case -> evaluator\n'
  pass=$((pass + 1))
else
  printf '  [FAIL] live collector E2E failed (rc=%s)\n' "$_t94_rc" >&2
  for _t94_err in collector-capture.err collector-packet.err collector-case.err collector-eval.err; do
    [ -f "$_t94_tmp/$_t94_err" ] && sed 's/^/    /' "$_t94_tmp/$_t94_err" >&2
  done
  fail=$((fail + 1))
fi

_t94_inventory_out="$_t94_tmp/collector-inventory.out"
_t94_inventory_rc=0
"$_T94_PY" "$_t94_collector" --repo-root "$_t94_collect_root" inventory \
  >"$_t94_inventory_out" 2>"$_t94_tmp/collector-inventory.err" || _t94_inventory_rc=$?
if [ "$_t94_inventory_rc" -eq 0 ] \
  && grep -q '"mode": "pbi_live_shadow_inventory"' "$_t94_inventory_out" \
  && grep -q '"tracked_live_case_total": 1' "$_t94_inventory_out" \
  && grep -q '"evaluated_case_total": 1' "$_t94_inventory_out" \
  && grep -q '"invalid_case_total": 0' "$_t94_inventory_out" \
  && grep -q '"task_namespace_binding_enforced": true' "$_t94_inventory_out" \
  && grep -q '"duplicate_logical_case_ids_rejected": true' "$_t94_inventory_out" \
  && grep -q '"runtime_execution_verified": false' "$_t94_inventory_out" \
  && grep -q '"source_preexistence_verified": false' "$_t94_inventory_out" \
  && grep -q '"reviewer_identity_verified": false' "$_t94_inventory_out" \
  && grep -q '"representative_coverage_claim_allowed": false' "$_t94_inventory_out" \
  && grep -q '"quality_acceptance_decided": false' "$_t94_inventory_out" \
  && grep -q '"write_allowed": false' "$_t94_inventory_out"; then
  printf '  [PASS] live inventory: tracked chain revalidated without runtime/quality overclaim\n'
  pass=$((pass + 1))
else
  printf '  [FAIL] live inventory: CLI wiring or trust-boundary invariant failed (rc=%s)\n' "$_t94_inventory_rc" >&2
  sed 's/^/    /' "$_t94_tmp/collector-inventory.err" >&2
  fail=$((fail + 1))
fi

# 14. Post-admission live Materialization must fire end to end without write authority.
_t94_mat_root="$_t94_tmp/materialization-root"
mkdir -p "$_t94_mat_root/scripts" "$_t94_mat_root/docs" "$_t94_mat_root/TASK-9999/delivery"
printf '{"kind":"state","state":"MERGE_READY"}\n' >"$_t94_mat_root/TASK-9999/delivery/record.jsonl"

_t94_mat_signal="$_t94_tmp/materialization-signal.json"
cat >"$_t94_mat_signal" <<'JSON'
{
  "signal_id": "SIG-TA94-MATERIALIZE",
  "source_ref": "TASK-9999/delivery/record.jsonl",
  "source_kind": "existing_behavior",
  "claim_class": "observed",
  "statement": "Observed delivery evidence requires follow-up work.",
  "disposition": "actionable",
  "target_layer": "delivery",
  "candidate_problem": "Observed delivery evidence should become a follow-up PBI."
}
JSON

_t94_mbase="docs/working/TASK-9999/evidence/pbi-live-shadow/run-02"
_t94_mcap="$_t94_mbase/capture.json"
_t94_mev="$_t94_mbase/run-evidence.json"
_t94_mpacket="$_t94_mbase/review-packet.json"
_t94_maoracle="$_t94_mbase/admission-oracle.json"
_t94_macase="$_t94_mbase/admission-case.json"
_t94_mpayload="$_t94_mbase/materialization-payload.json"
_t94_mexisting="$_t94_mbase/existing-work.json"
_t94_moracle="$_t94_mbase/materialization-oracle.json"
_t94_mcase="$_t94_mbase/materialization-case.json"
_t94_mat_rc=0

"$_T94_PY" "$_t94_collector" --repo-root "$_t94_mat_root" capture \
  --signal "$_t94_mat_signal" \
  --task-id TASK-9999 --run-id run-02 \
  --captured-at 2099-12-31T12:00:00Z \
  --runtime-head-sha abcdef1234567890abcdef1234567890abcdef12 \
  --capture-ref "$_t94_mcap" \
  >"$_t94_tmp/mat-capture.out" 2>"$_t94_tmp/mat-capture.err" || _t94_mat_rc=$?

if [ "$_t94_mat_rc" -eq 0 ]; then
  "$_T94_PY" - \
    "$_T94_ROOT/tests/fixtures/run-evidence/fx-01-first-pass.json" \
    "$_t94_mat_root/$_t94_mev" \
    "$_t94_mcap" <<'PY'
import json
import pathlib
import sys

src = pathlib.Path(sys.argv[1])
dst = pathlib.Path(sys.argv[2])
capture_ref = sys.argv[3]
record = json.loads(src.read_text(encoding="utf-8"))
record["evidence_refs"] = list(dict.fromkeys(
    record["evidence_refs"]
    + ["TASK-9999/delivery/record.jsonl", capture_ref]
))
dst.parent.mkdir(parents=True, exist_ok=True)
dst.write_text(
    json.dumps(record, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
PY
  _t94_mat_rc=$?
fi

if [ "$_t94_mat_rc" -eq 0 ]; then
  "$_T94_PY" "$_t94_collector" --repo-root "$_t94_mat_root" packet \
    --capture-ref "$_t94_mcap" \
    --run-evidence-ref "$_t94_mev" \
    --packet-ref "$_t94_mpacket" \
    >"$_t94_tmp/mat-packet.out" 2>"$_t94_tmp/mat-packet.err" || _t94_mat_rc=$?
fi

if [ "$_t94_mat_rc" -eq 0 ]; then
  "$_T94_PY" - \
    "$_T94_ROOT/scripts/ai-loop" \
    "$_t94_mat_root/$_t94_mpacket" \
    "$_t94_mat_root/TASK-9999/delivery/record.jsonl" \
    "$_t94_mat_root/$_t94_maoracle" \
    "$_t94_mpacket" <<'PY'
import hashlib
import json
import pathlib
import sys

sys.path.insert(0, sys.argv[1])
import pbi_materializer as pm

packet_path = pathlib.Path(sys.argv[2])
source_path = pathlib.Path(sys.argv[3])
oracle_path = pathlib.Path(sys.argv[4])
packet_ref = sys.argv[5]
packet = json.loads(packet_path.read_text(encoding="utf-8"))
oracle = {
    "schema_version": 1,
    "domain": "plangate.pbi-live-shadow-admission-oracle/v1",
    "case_ref": "LIVE-TA94-ADMISSION-MATERIALIZE",
    "packet_ref": packet_ref,
    "packet_hash": pm._canonical_json_hash(packet),
    "reviewed_source_ref": "TASK-9999/delivery/record.jsonl",
    "reviewed_source_sha256": "sha256:" + hashlib.sha256(source_path.read_bytes()).hexdigest(),
    "expected_admission_decision": "materialize",
    "independent_review_asserted": True,
    "maker_actual_not_consulted_asserted": True,
}
oracle_path.parent.mkdir(parents=True, exist_ok=True)
oracle_path.write_text(
    json.dumps(oracle, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
PY
  _t94_mat_rc=$?
fi

if [ "$_t94_mat_rc" -eq 0 ]; then
  "$_T94_PY" "$_t94_collector" --repo-root "$_t94_mat_root" case \
    --packet-ref "$_t94_mpacket" \
    --oracle-ref "$_t94_maoracle" \
    --case-artifact-ref "$_t94_macase" \
    >"$_t94_tmp/mat-admission-case.out" 2>"$_t94_tmp/mat-admission-case.err" || _t94_mat_rc=$?
fi

if [ "$_t94_mat_rc" -eq 0 ]; then
  "$_T94_PY" - \
    "$_T94_ROOT/scripts/ai-loop" \
    "$_t94_mat_root/$_t94_macase" \
    "$_t94_mat_root/$_t94_mpayload" \
    "$_t94_mat_root/$_t94_mexisting" \
    "$_t94_mat_root/$_t94_moracle" \
    "$_t94_macase" "$_t94_mpayload" "$_t94_mexisting" <<'PY'
import json
import pathlib
import sys

sys.path.insert(0, sys.argv[1])
import pbi_materializer as pm

admission_path = pathlib.Path(sys.argv[2])
payload_path = pathlib.Path(sys.argv[3])
existing_path = pathlib.Path(sys.argv[4])
oracle_path = pathlib.Path(sys.argv[5])
admission_ref, payload_ref, existing_ref = sys.argv[6:9]

admission_case = json.loads(admission_path.read_text(encoding="utf-8"))
payload = {
    "task_id": "TASK-9999",
    "title": "TA-94 live materialization follow-up",
    "author": "ai",
    "application_timing": "follow_up",
    "target_layer": "delivery",
    "goal": "Preserve observed delivery evidence as follow-up work",
    "problem": "Observed delivery evidence should become a follow-up PBI.",
    "source_run_refs": ["docs/working/TASK-9999/evidence/pbi-live-shadow/run-02/run-evidence.json"],
    "claims": [
        {
            "id": "CLM-TA94-MAT-001",
            "text": "Observed delivery evidence requires follow-up work.",
            "source_ref": "TASK-9999/delivery/record.jsonl",
            "source_kind": "existing_behavior",
            "claim_class": "observed",
            "supports": "Problem"
        }
    ],
    "requirements": [],
    "acceptance_criteria": [],
    "in_scope": ["Create a future delivery follow-up proposal"],
    "out_of_scope": ["Mutate the current run"],
    "risks": ["Synthetic TA-94 case is not rollout evidence"],
    "unknowns": [],
    "assumptions": [],
    "harness_candidate_ref": None
}
existing_work = []
payload_path.write_text(
    json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
existing_path.write_text(
    json.dumps(existing_work, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
oracle = {
    "schema_version": 1,
    "domain": "plangate.pbi-live-shadow-materialization-oracle/v1",
    "case_ref": "LIVE-TA94-MATERIALIZATION",
    "admission_case_ref": admission_ref,
    "admission_case_hash": pm._canonical_json_hash(admission_case),
    "payload_ref": payload_ref,
    "payload_hash": pm._canonical_json_hash(payload),
    "existing_work_ref": existing_ref,
    "existing_work_hash": pm._canonical_json_hash(existing_work),
    "expected": {
        "decision": "create_new",
        "matched_ref": None,
        "readiness_status": "ready",
        "readiness_route": "future_run"
    },
    "independent_review_asserted": True,
    "maker_actual_not_consulted_asserted": True
}
oracle_path.write_text(
    json.dumps(oracle, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
PY
  _t94_mat_rc=$?
fi

if [ "$_t94_mat_rc" -eq 0 ]; then
  "$_T94_PY" "$_t94_collector" --repo-root "$_t94_mat_root" materialization-case \
    --admission-case-ref "$_t94_macase" \
    --payload-ref "$_t94_mpayload" \
    --existing-work-ref "$_t94_mexisting" \
    --oracle-ref "$_t94_moracle" \
    --case-artifact-ref "$_t94_mcase" \
    >"$_t94_tmp/mat-case.out" 2>"$_t94_tmp/mat-case.err" || _t94_mat_rc=$?
fi

_t94_mat_inventory="$_t94_tmp/mat-inventory.out"
if [ "$_t94_mat_rc" -eq 0 ]; then
  "$_T94_PY" "$_t94_collector" --repo-root "$_t94_mat_root" materialization-inventory \
    >"$_t94_mat_inventory" 2>"$_t94_tmp/mat-inventory.err" || _t94_mat_rc=$?
fi

if [ "$_t94_mat_rc" -eq 0 ] \
  && grep -q '"mode": "pbi_live_shadow_collect_reviewed_materialization_case"' "$_t94_tmp/mat-case.out" \
  && grep -q '"admission_materialize_match_revalidated": true' "$_t94_tmp/mat-case.out" \
  && grep -q '"mode": "pbi_live_shadow_materialization_inventory"' "$_t94_mat_inventory" \
  && grep -q '"tracked_live_case_total": 1' "$_t94_mat_inventory" \
  && grep -q '"evaluated_case_total": 1' "$_t94_mat_inventory" \
  && grep -q '"observed_materialization_decisions"' "$_t94_mat_inventory" \
  && grep -q '"create_new"' "$_t94_mat_inventory" \
  && grep -q '"duplicate_false_positive_rate": 0.0' "$_t94_mat_inventory" \
  && grep -q '"duplicate_false_negative_rate": null' "$_t94_mat_inventory" \
  && grep -q '"materialization_decision_coverage_complete": false' "$_t94_mat_inventory" \
  && grep -q '"runtime_execution_verified": false' "$_t94_mat_inventory" \
  && grep -q '"quality_acceptance_decided": false' "$_t94_mat_inventory" \
  && grep -q '"write_allowed": false' "$_t94_mat_inventory"; then
  printf '  [PASS] live Materialization E2E: admitted case -> reviewed materialization -> inventory\n'
  pass=$((pass + 1))
else
  printf '  [FAIL] live Materialization E2E failed (rc=%s)\n' "$_t94_mat_rc" >&2
  for _t94_err in mat-capture.err mat-packet.err mat-admission-case.err mat-case.err mat-inventory.err; do
    [ -f "$_t94_tmp/$_t94_err" ] && sed 's/^/    /' "$_t94_tmp/$_t94_err" >&2
  done
  fail=$((fail + 1))
fi

# 15. Collection plan must use reviewed expectations and remain non-quota/read-only.
_t94_collect_plan="$_t94_tmp/collection-plan-no-action.out"
_t94_mat_plan="$_t94_tmp/collection-plan-materialize.out"
_t94_plan_rc=0

"$_T94_PY" "$_t94_collector" --repo-root "$_t94_collect_root" collection-plan \
  >"$_t94_collect_plan" 2>"$_t94_tmp/collection-plan-no-action.err" || _t94_plan_rc=$?

if [ "$_t94_plan_rc" -eq 0 ]; then
  "$_T94_PY" "$_t94_collector" --repo-root "$_t94_mat_root" collection-plan \
    >"$_t94_mat_plan" 2>"$_t94_tmp/collection-plan-materialize.err" || _t94_plan_rc=$?
fi

if [ "$_t94_plan_rc" -eq 0 ]; then
  "$_T94_PY" - "$_t94_collect_plan" "$_t94_mat_plan" <<'PY'
import json
import pathlib
import sys

no_action = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
materialize = json.loads(pathlib.Path(sys.argv[2]).read_text(encoding="utf-8"))

assert no_action["mode"] == "pbi_live_shadow_collection_plan"
assert materialize["mode"] == "pbi_live_shadow_collection_plan"

assert no_action["observation_gap_count"] == 5
assert materialize["observation_gap_count"] == 4

for plan in (no_action, materialize):
    boundary = plan["policy_boundary"]
    assert boundary["opportunistic_observation_only"] is True
    assert boundary["synthetic_case_generation_for_coverage_allowed"] is False
    assert boundary["historical_relabeling_allowed"] is False
    assert boundary["decision_coverage_quota_defined"] is False
    assert boundary["source_kind_coverage_requirement_defined"] is False
    assert boundary["representative_coverage_claim_allowed"] is False
    assert boundary["coverage_complete_implies_representative"] is False
    assert boundary["observation_gap_is_quota"] is False
    assert boundary["observation_gap_is_case_generation_instruction"] is False
    assert boundary["coverage_gap_basis"] == "reviewed_expected_decisions"
    assert boundary["maker_actual_counts_as_ground_truth_coverage"] is False
    assert boundary["runtime_execution_verified"] is False
    assert boundary["quality_acceptance_decided"] is False
    assert plan["authority"]["read_only"] is True
    assert plan["authority"]["write_allowed"] is False

assert (
    no_action["inventory_snapshot"]["admission"]["reviewed_expected_decisions"]
    == ["no_action"]
)
assert (
    no_action["inventory_snapshot"]["admission"]["observed_actual_decisions"]
    == ["no_action"]
)
assert all(
    not item["currently_collectable"]
    for item in no_action["observation_gaps"]
    if item["stage"] == "materialization"
)

assert (
    materialize["inventory_snapshot"]["admission"]["reviewed_expected_decisions"]
    == ["materialize"]
)
assert (
    materialize["inventory_snapshot"]["materialization"]["reviewed_expected_decisions"]
    == ["create_new"]
)
assert all(
    item["currently_collectable"]
    for item in materialize["observation_gaps"]
    if item["stage"] == "materialization"
)
PY
  _t94_plan_rc=$?
fi

if [ "$_t94_plan_rc" -eq 0 ]; then
  printf '  [PASS] live collection plan: reviewed coverage drives non-quota targets\n'
  pass=$((pass + 1))
else
  printf '  [FAIL] live collection plan: coverage/prerequisite boundary failed (rc=%s)\n' "$_t94_plan_rc" >&2
  for _t94_err in collection-plan-no-action.err collection-plan-materialize.err; do
    [ -f "$_t94_tmp/$_t94_err" ] && sed 's/^/    /' "$_t94_tmp/$_t94_err" >&2
  done
  fail=$((fail + 1))
fi

# 16. Write-capable rollout policy must remain explicitly non-active.
_t94_write_policy="$_T94_ROOT/docs/working/TASK-1442/write-capable-rollout-policy.md"
if [ -f "$_t94_write_policy" ] \
  && grep -q 'Status: \*\*DRAFT / NON-ACTIVE\*\*' "$_t94_write_policy" \
  && grep -q 'rollout_mode = shadow_only' "$_t94_write_policy" \
  && grep -q 'effective_stage = R0 Shadow' "$_t94_write_policy" \
  && grep -q 'R1_enabled = false' "$_t94_write_policy" \
  && grep -q 'R2_enabled = false' "$_t94_write_policy" \
  && grep -q 'automatic_mutation_allowed = false' "$_t94_write_policy" \
  && ! grep -q 'R1_enabled = true' "$_t94_write_policy" \
  && ! grep -q 'R2_enabled = true' "$_t94_write_policy" \
  && ! grep -q 'automatic_mutation_allowed = true' "$_t94_write_policy" \
  && ! grep -Eq 'effective_stage = R[123]' "$_t94_write_policy" \
  && grep -q 'one mutation attempt = one semantic target' "$_t94_write_policy" \
  && grep -q 'multi-target transaction = unsupported' "$_t94_write_policy" \
  && grep -q 'automatic_retry_allowed = false' "$_t94_write_policy" \
  && grep -q 'Policy version: `pbi-write-rollout/v1`' "$_t94_write_policy" \
  && grep -q 'policy_sha256 = sha256:<exact content bytes>' "$_t94_write_policy" \
  && grep -q 'current_policy_sha256 != activated_policy_sha256' "$_t94_write_policy" \
  && grep -q 'rollback_plan_exists != rollback_execution_authorized' "$_t94_write_policy" \
  && grep -q 'full target backup を既定にしない' "$_t94_write_policy" \
  && grep -q 'docs/working/TASK-XXXX/evidence/pbi-write-attempts/<attempt-id>/' "$_t94_write_policy" \
  && grep -q 'unknown' "$_t94_write_policy" \
  && grep -q 'automatic retry forbidden' "$_t94_write_policy" \
  && grep -q 'Writer != Post-write Verifier' "$_t94_write_policy" \
  && grep -q '少なくとも初回 activation は Human-owned とする' "$_t94_write_policy" \
  && grep -q 'policy definition' "$_t94_write_policy" \
  && grep -q '!= rollout activation' "$_t94_write_policy"; then
  printf '  [PASS] write rollout policy: draft remains R0/non-active and fail-closed\n'
  pass=$((pass + 1))
else
  printf '  [FAIL] write rollout policy: non-activation contract drifted\n' >&2
  fail=$((fail + 1))
fi

rm -rf "$_t94_tmp"
pg_extra_contract_finalize
