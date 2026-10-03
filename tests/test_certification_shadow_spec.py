#!/usr/bin/env python3
"""Non-authoritative executable specification for Certification View (#1460).

This file intentionally does NOT import scripts/ai-loop-v2/decision_core.py.
The current Decision implementation is provisional relative to the #1393 owner
contract. The spec consumes owner-derived artifact verdicts as injected input
and verifies only Certification's projection boundary.
"""
from __future__ import annotations

import copy
import inspect
import unittest

AUTHORITATIVE = False
IMPLEMENTATION_MODE = "executable_spec"
OWNER_API_CONNECTED = False
_ALLOWED_VERDICTS = frozenset({"pass", "fail", "unavailable"})


def _key(verifier):
    if (
        not isinstance(verifier, tuple)
        or len(verifier) != 2
        or not all(isinstance(value, str) and value for value in verifier)
    ):
        raise ValueError("required verifier must be (verifier_id, kind)")
    return verifier


def _canonical_refs(refs):
    if refs is None:
        return ()
    if not isinstance(refs, (list, tuple, set, frozenset)):
        raise ValueError("evidence refs must be a collection")
    unique = set()
    for ref in refs:
        if not isinstance(ref, str) or not ref:
            raise ValueError("evidence ref must be a non-empty string")
        unique.add(ref)
    return tuple(sorted(unique))


def compose_certification(
    *,
    target_ref,
    loop_contract_ref,
    required_verifiers,
    owner_artifact_verdicts,
    supporting_verification_refs=None,
    supplemental_evidence_refs=None,
):
    """Project owner Decision verdicts without deriving or changing them.

    The owner Decision contract remains authoritative for artifact-verdict
    semantics. This function only checks exact required-set parity and renders
    a deterministic, non-authoritative view.
    """
    if not isinstance(target_ref, str) or not target_ref:
        raise ValueError("target_ref")
    if not isinstance(loop_contract_ref, str) or not loop_contract_ref:
        raise ValueError("loop_contract_ref")

    required_input = tuple(_key(item) for item in required_verifiers)
    if not required_input or len(set(required_input)) != len(required_input):
        raise ValueError("required_verifiers")
    # #1393 models required_verifiers as a set. Canonicalize the projection so
    # equivalent owner inputs do not produce order-dependent report bytes.
    required = tuple(sorted(required_input))

    if not isinstance(owner_artifact_verdicts, dict):
        raise ValueError("owner_artifact_verdicts")
    if set(owner_artifact_verdicts) != set(required):
        raise ValueError("owner verdict keys must exactly match required_verifiers")

    refs_by_verifier = supporting_verification_refs or {}
    if not isinstance(refs_by_verifier, dict):
        raise ValueError("supporting_verification_refs")
    if not set(refs_by_verifier).issubset(set(required)):
        raise ValueError("supporting refs for non-required verifier")

    projected = []
    for verifier_id, kind in required:
        key = (verifier_id, kind)
        verdict = owner_artifact_verdicts[key]
        if verdict not in _ALLOWED_VERDICTS:
            raise ValueError("unknown owner artifact verdict")
        projected.append(
            {
                "verifier_id": verifier_id,
                "kind": kind,
                "artifact_verdict": verdict,
                "supporting_verification_refs": list(
                    _canonical_refs(refs_by_verifier.get(key, ()))
                ),
            }
        )

    return {
        "authoritative": AUTHORITATIVE,
        "mode": IMPLEMENTATION_MODE,
        "target_ref": target_ref,
        "loop_contract_ref": loop_contract_ref,
        "required_verifiers": projected,
        "supplemental_evidence_refs": list(
            _canonical_refs(supplemental_evidence_refs or ())
        ),
    }


def verdict_map(projection):
    return {
        (item["verifier_id"], item["kind"]): item["artifact_verdict"]
        for item in projection["required_verifiers"]
    }


class CertificationShadowSpecTests(unittest.TestCase):
    D = ("deterministic.tests", "deterministic")
    C = ("completion.evidence", "deterministic")
    MODEL = ("independent.review", "independent_model")

    def _compose(self, owner, *, required=None, refs=None, supplemental=None):
        return compose_certification(
            target_ref="sha256:" + "a" * 64,
            loop_contract_ref="loop-contract:1",
            required_verifiers=required or (self.D,),
            owner_artifact_verdicts=owner,
            supporting_verification_refs=refs,
            supplemental_evidence_refs=supplemental,
        )

    def test_mode_is_explicitly_non_authoritative(self):
        projection = self._compose({self.D: "pass"})
        self.assertFalse(projection["authoritative"])
        self.assertEqual(projection["mode"], "executable_spec")

    def test_projection_preserves_injected_owner_verdict_map_exactly(self):
        owner = {self.D: "fail", self.C: "pass"}
        projection = self._compose(
            owner,
            required=(self.D, self.C),
            refs={self.D: ["v-fail"], self.C: ["v-complete"]},
            supplemental=["model-review-pass"],
        )
        self.assertEqual(verdict_map(projection), owner)
        self.assertEqual(
            projection["supplemental_evidence_refs"], ["model-review-pass"]
        )

    def test_missing_or_extra_owner_verdict_is_rejected(self):
        with self.assertRaises(ValueError):
            self._compose({self.D: "pass"}, required=(self.D, self.C))
        with self.assertRaises(ValueError):
            self._compose(
                {self.D: "pass", self.MODEL: "pass"},
                required=(self.D,),
            )

    def test_unknown_owner_verdict_is_rejected(self):
        with self.assertRaises(ValueError):
            self._compose({self.D: "trusted"})

    def test_duplicate_refs_do_not_increase_evidence_count(self):
        projection = self._compose(
            {self.D: "fail"},
            refs={self.D: ["v2", "v1", "v2", "v1"]},
            supplemental=["review:2", "review:1", "review:1"],
        )
        item = projection["required_verifiers"][0]
        self.assertEqual(item["artifact_verdict"], "fail")
        self.assertEqual(item["supporting_verification_refs"], ["v1", "v2"])
        self.assertEqual(
            projection["supplemental_evidence_refs"],
            ["review:1", "review:2"],
        )

    def test_equivalent_set_inputs_have_canonical_projection_order(self):
        owner = {self.D: "pass", self.C: "unavailable"}
        first = self._compose(
            owner,
            required=(self.D, self.C),
            refs={self.D: ["v2", "v1"], self.C: ["v3"]},
            supplemental=["z", "a"],
        )
        second = self._compose(
            owner,
            required=(self.C, self.D),
            refs={self.D: ["v1", "v2"], self.C: ["v3"]},
            supplemental=["a", "z"],
        )
        self.assertEqual(first, second)

    def test_non_required_evidence_never_becomes_required(self):
        projection = self._compose(
            {self.D: "pass"},
            supplemental=["model-pass", "security-note"],
        )
        self.assertEqual(list(verdict_map(projection)), [self.D])
        self.assertEqual(
            projection["supplemental_evidence_refs"],
            ["model-pass", "security-note"],
        )
        self.assertEqual(len(projection["required_verifiers"]), 1)

    def test_mode_a_has_no_owner_api_or_raw_verification_input(self):
        self.assertFalse(OWNER_API_CONNECTED)
        parameters = set(inspect.signature(compose_certification).parameters)
        self.assertIn("owner_artifact_verdicts", parameters)
        self.assertNotIn("verification_results", parameters)
        self.assertNotIn("contract_bound_seq", parameters)
        self.assertNotIn("run_state", parameters)

    def test_projection_does_not_mutate_inputs_or_decision_output(self):
        owner = {self.D: "pass"}
        refs = {self.D: ["v1"]}
        decision = {
            "action": "stop",
            "outcome": "MERGE_READY",
            "stop_reasons": [],
            "inputs": ["v1"],
        }
        before = copy.deepcopy((owner, refs, decision))
        self._compose(owner, refs=refs)
        self.assertEqual((owner, refs, decision), before)

    def test_injected_oracle_scenarios_are_preserved_without_rederivation(self):
        # These are injected fixture-oracle values, NOT a live parity check.
        # They represent expected future #1393 artifact_verdicts(...) outputs.
        # Certification intentionally does not recompute the owner semantics.
        cases = {
            "pass_before_contract_boundary": "unavailable",
            "current_bound_pass": "pass",
            "required_fail_plus_later_model_pass": "fail",
            "unavailable_or_inconclusive_only": "unavailable",
            "stale_or_wrong_artifact": "unavailable",
            "non_required_model_result_present": "pass",
        }
        for name, owner_verdict in cases.items():
            with self.subTest(name=name):
                projection = self._compose(
                    {self.D: owner_verdict},
                    supplemental=(
                        ["model-pass"]
                        if name in {
                            "required_fail_plus_later_model_pass",
                            "non_required_model_result_present",
                        }
                        else []
                    ),
                )
                self.assertEqual(verdict_map(projection)[self.D], owner_verdict)


if __name__ == "__main__":
    unittest.main()
