#!/bin/sh
# PG_EXTRA_CAPABILITY: standalone-capable
# TA-87 — ai-loop V2 Delivery-first executable specification (#1383).
#
# This test intentionally lives under tests/** only. It is a non-authoritative
# executable specification, not a Production V2 runtime or Decision Engine.

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
pg_extra_contract_init ta-87-ai-loop-v2-delivery-e2e standalone-capable

if [ "$_pg_extra_mode" = harness ]; then
  _T87_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
else
  _T87_ROOT="${_pg_extra_dir%/tests/extras}"
fi

_T87_REPAIR="$_T87_ROOT/tests/fixtures/ai-loop-v2/delivery/repair-convergence.json"
_T87_NOPROGRESS="$_T87_ROOT/tests/fixtures/ai-loop-v2/delivery/no-progress-stop.json"

printf 'TA-87: ai-loop V2 Delivery E2E executable specification (#1383)\n'

if [ ! -r "$_T87_REPAIR" ] || [ ! -r "$_T87_NOPROGRESS" ]; then
  printf '  [FAIL] fixture missing\n' >&2
  fail=$((fail + 1))
  pg_extra_contract_finalize
  if pg_extra_contract_is_standalone; then exit 1; fi
  return 0
fi

_T87_OUT=$(python3 - "$_T87_REPAIR" "$_T87_NOPROGRESS" <<'PY'
import copy
import json
import sys

repair_path, no_progress_path = sys.argv[1:3]

ALLOWED_STATES = {
    "PLANNING", "PLAN_VERIFYING", "EXECUTING", "VERIFYING", "DIAGNOSING",
    "REPAIRING", "REPLANNING", "PR_CONVERGING", "WAITING_HUMAN",
    "WAITING_EXTERNAL",
}
ALLOWED_OUTCOMES = {"MERGE_READY", "HUMAN_ESCALATED", "BLOCKED"}
ALLOWED_STOP_REASONS = {
    "NO_PROGRESS", "REPEATED_FAILURE", "OSCILLATION", "BUDGET_EXHAUSTED",
    "POLICY_DENIED", "VERIFIER_UNAVAILABLE", "REQUIREMENT_CONFLICT",
    "STATE_CONFLICT",
}
ALLOWED_ACTIONS = {"continue", "repair", "replan", "stop"}
ALLOWED_VERIFICATION = {"pass", "fail", "unavailable", "inconclusive"}


class SpecError(Exception):
    pass


def req(condition, message):
    if not condition:
        raise SpecError(message)


def load(path):
    with open(path, encoding="utf-8") as fh:
        return json.load(fh)


def project(trace):
    verification_refs = []
    failure_refs = []
    outcome = None
    stop_reasons = []
    for event in trace["events"]:
        if event["type"] == "verification_recorded":
            verification_refs.append(event["verification"]["id"])
        elif event["type"] == "failure_recorded":
            failure_refs.append(event["failure"]["id"])
        elif event["type"] == "decision_made":
            decision = event["decision"]
            if decision.get("outcome") is not None:
                outcome = decision["outcome"]
                stop_reasons = list(decision.get("stop_reasons", []))
    return {
        "outcome": outcome,
        "stop_reasons": stop_reasons,
        "verification_result_refs": verification_refs,
        "failure_record_refs": failure_refs,
        "evidence_status": "ready" if outcome is not None else "partial",
    }


def validate_common(trace):
    req(trace.get("schema_version") == "spec-1", "schema_version")
    req(trace.get("kind") == "ai_loop_v2_delivery_e2e_trace", "kind")
    req(trace.get("authoritative") is False, "fixture must be non-authoritative")
    harness = trace.get("harness_manifest_ref")
    req(isinstance(harness, str) and harness.startswith("sha256:"), "harness ref")
    events = trace.get("events")
    req(isinstance(events, list) and events, "events")

    seqs = [e.get("seq") for e in events]
    req(seqs == sorted(seqs) and len(seqs) == len(set(seqs)), "event seq")
    revisions = [e.get("revision") for e in events]
    req(all(isinstance(r, int) and not isinstance(r, bool) for r in revisions), "revision type")
    req(revisions == sorted(revisions), "revision monotonic")

    for event in events:
        req(event.get("harness_manifest_ref") == harness, "harness drift")
        state = event.get("state")
        req(state in ALLOWED_STATES, f"invalid lifecycle state: {state!r}")
        req(event.get("type") not in {"merge_executed", "auto_merge", "production_promotion"},
            "fixture must not perform merge/promotion")

        if event["type"] == "verification_recorded":
            verification = event.get("verification", {})
            req(verification.get("status") in ALLOWED_VERIFICATION, "verification status")
            req(verification.get("kind") in {"deterministic", "specification", "independent_model", "policy"},
                "verification kind")
            req(isinstance(verification.get("bound_artifact_ref"), str), "bound artifact ref")
        elif event["type"] == "failure_recorded":
            failure = event.get("failure", {})
            req(bool(failure.get("observation")), "failure observation")
            req(bool(failure.get("fingerprint")), "failure fingerprint")
            req("cause_hypothesis" in failure, "cause hypothesis field must be separate")
            req("decision" not in failure, "FailureRecord must not own decision")
        elif event["type"] == "decision_made":
            decision = event.get("decision", {})
            req(decision.get("action") in ALLOWED_ACTIONS, "decision action")
            outcome = decision.get("outcome")
            req(outcome is None or outcome in ALLOWED_OUTCOMES, "terminal outcome")
            reasons = decision.get("stop_reasons", [])
            req(all(r in ALLOWED_STOP_REASONS for r in reasons), "stop reason")
            if outcome == "MERGE_READY":
                req(reasons == [], "MERGE_READY must not carry failure stop reason")

    expected = trace.get("expected_projection")
    p1 = project(trace)
    p2 = project(trace)
    req(p1 == p2, "projection must be deterministic")
    req(p1 == expected, f"projection mismatch: {p1!r} != {expected!r}")


def validate_repair(trace):
    validate_common(trace)
    req(trace.get("scenario") == "repair-convergence", "repair scenario")
    events = trace["events"]

    worker = next(e for e in events if e["type"] == "worker_completed")
    req("decision" not in worker and "outcome" not in worker,
        "worker self-report cannot complete run")

    verifications = [e for e in events if e["type"] == "verification_recorded"]
    deterministic = [e for e in verifications if e["verification"]["kind"] == "deterministic"]
    req(len(deterministic) >= 2, "need fail + reverify")
    req(deterministic[0]["verification"]["status"] == "fail", "initial deterministic fail")
    req(any(e["verification"]["kind"] == "independent_model"
            and e["verification"]["status"] == "pass" for e in verifications),
        "independent PASS fixture required to prove no override")

    decisions = [e for e in events if e["type"] == "decision_made"]
    req(decisions[0]["decision"]["action"] == "repair",
        "deterministic FAIL must lead to repair despite model PASS")
    req(decisions[0]["decision"].get("outcome") is None,
        "repair decision cannot terminate successfully")

    change = next(e for e in events if e["type"] == "artifact_changed")
    req(change["before_artifact_ref"] != change["after_artifact_ref"], "repair artifact delta")
    req(change.get("scope_ok") is True, "repair scope")

    final_det = deterministic[-1]["verification"]
    req(final_det["status"] == "pass", "fresh deterministic PASS")
    req(final_det["bound_artifact_ref"] == change["after_artifact_ref"],
        "stale verification after artifact change")

    convergence = next(e["convergence"] for e in events if e["type"] == "pr_convergence_recorded")
    req(convergence == {
        "ci": "pass",
        "required_reviews": "pass",
        "blocking_threads": 0,
        "conflict": False,
        "scope": "pass",
    }, "MERGE_READY convergence preconditions")

    final = decisions[-1]["decision"]
    req(final["action"] == "stop" and final["outcome"] == "MERGE_READY",
        "final MERGE_READY decision")


def validate_no_progress(trace):
    validate_common(trace)
    req(trace.get("scenario") == "no-progress-stop", "no-progress scenario")
    events = trace["events"]

    failures = [e["failure"] for e in events if e["type"] == "failure_recorded"]
    req(len(failures) >= 2, "repeated failures")
    req(failures[-2]["fingerprint"] == failures[-1]["fingerprint"], "same normalized failure")

    repair = next(e for e in events if e["type"] == "repair_attempted")
    progress = next(e["progress"] for e in events if e["type"] == "progress_assessed")
    for key in (
        "previous_failure_fingerprint", "current_failure_fingerprint",
        "artifact_changed", "evidence_delta", "resolved_blockers",
        "introduced_blockers", "no_progress",
    ):
        req(key in progress, f"progress field missing: {key}")

    req(progress["previous_failure_fingerprint"] == progress["current_failure_fingerprint"],
        "failure delta")
    req(progress["artifact_changed"] is False, "artifact delta required")
    req(progress["evidence_delta"] == [], "evidence delta required")
    req(progress["resolved_blockers"] == [], "blocker delta required")
    req(repair["before_artifact_ref"] == repair["after_artifact_ref"], "repair must show no artifact delta")
    req(progress["no_progress"] is True, "no_progress conclusion")

    final = [e for e in events if e["type"] == "decision_made"][-1]["decision"]
    req(final["action"] == "stop", "no-progress must stop")
    req(final["stop_reasons"] == ["NO_PROGRESS"], "NO_PROGRESS is Stop Reason")
    req(final["outcome"] in {"HUMAN_ESCALATED", "BLOCKED"}, "existing terminal outcome")


def expect_reject(label, trace, validator):
    try:
        validator(trace)
    except SpecError:
        print(f"  [PASS] mutant rejected: {label}")
        return
    raise SpecError(f"mutant survived: {label}")


repair = load(repair_path)
no_progress = load(no_progress_path)

validate_repair(repair)
print("  [PASS] repair-convergence executable trace")
validate_no_progress(no_progress)
print("  [PASS] no-progress-stop executable trace")

# Mutation 1: Worker self-report becomes terminal success.
m = copy.deepcopy(repair)
m["events"][1]["decision"] = {"action": "stop", "outcome": "MERGE_READY", "stop_reasons": []}
expect_reject("worker self-report completion", m, validate_repair)

# Mutation 2: Independent model PASS overrides deterministic FAIL.
m = copy.deepcopy(repair)
m["events"][5]["decision"] = {
    "action": "stop", "inputs": ["v1", "v2"], "outcome": "MERGE_READY", "stop_reasons": []
}
expect_reject("model PASS overrides deterministic FAIL", m, validate_repair)

# Mutation 3: Fresh PASS is actually bound to stale artifact.
m = copy.deepcopy(repair)
m["events"][7]["verification"]["bound_artifact_ref"] = m["events"][6]["before_artifact_ref"]
expect_reject("stale verification reused after repair", m, validate_repair)

# Mutation 4: Harness identity changes during the run.
m = copy.deepcopy(repair)
m["events"][4]["harness_manifest_ref"] = "sha256:" + "9" * 64
expect_reject("active-run harness drift", m, validate_repair)

# Mutation 5: Test fixture tries to encode an auto merge side effect.
m = copy.deepcopy(repair)
m["events"].append({
    "seq": 11, "type": "merge_executed", "state": "PR_CONVERGING",
    "revision": 8, "harness_manifest_ref": m["harness_manifest_ref"],
})
expect_reject("auto merge side effect", m, validate_repair)

# Mutation 6: NO_PROGRESS is derived from retry count only.
m = copy.deepcopy(no_progress)
m["events"][7]["progress"] = {"retry_count": 2, "no_progress": True}
expect_reject("retry-count-only no progress", m, validate_no_progress)

# Mutation 7: NO_PROGRESS is incorrectly stored as a Lifecycle State.
m = copy.deepcopy(no_progress)
m["events"][8]["state"] = "NO_PROGRESS"
expect_reject("NO_PROGRESS used as lifecycle state", m, validate_no_progress)

# Mutation 8: Meaningful artifact delta is incorrectly called no progress.
m = copy.deepcopy(no_progress)
m["events"][4]["after_artifact_ref"] = "sha256:" + "b" * 64
m["events"][7]["progress"]["artifact_changed"] = True
expect_reject("meaningful artifact delta mislabeled no-progress", m, validate_no_progress)

print("  [PASS] 8 mutation classes killed")
PY
)
_T87_RC=$?

printf '%s\n' "$_T87_OUT"
if [ "$_T87_RC" -eq 0 ]; then
  pass=$((pass + 1))
  printf '  [PASS] TC-ALL: executable specification + mutation suite\n'
else
  fail=$((fail + 1))
  printf '  [FAIL] TC-ALL: executable specification failed (rc=%s)\n' "$_T87_RC" >&2
fi

pg_extra_contract_finalize
