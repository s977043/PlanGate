#!/usr/bin/env python3
"""Non-authoritative executable specification for Certification View (#1460).

This file intentionally does NOT import scripts/ai-loop-v2/decision_core.py.
The current Decision implementation is provisional relative to the #1393 owner
contract. The spec consumes owner-derived artifact verdicts as injected input
and verifies only Certification's projection boundary.
"""
from __future__ import annotations

import ast
import copy
import inspect
import unittest

AUTHORITATIVE = False
IMPLEMENTATION_MODE = "executable_spec"
OWNER_API_CONNECTED = False
_ALLOWED_VERDICTS = frozenset({"pass", "fail", "unavailable"})
_TOP_LEVEL_PROJECTION_FIELDS = frozenset(
    {
        "authoritative",
        "mode",
        "owner_api_connected",
        "verdict_source",
        "target_ref",
        "loop_contract_ref",
        "required_verifiers",
        "shared_required_evidence_refs",
        "supplemental_evidence_refs",
    }
)
_REQUIRED_VERIFIER_FIELDS = frozenset(
    {
        "verifier_id",
        "kind",
        "artifact_verdict",
        "supporting_verification_refs",
    }
)


def _identity(value, label):
    if not isinstance(value, str) or not value or value != value.strip():
        raise ValueError(label)
    return value


def _key(verifier):
    if not isinstance(verifier, tuple) or len(verifier) != 2:
        raise ValueError("required verifier must be (verifier_id, kind)")
    verifier_id, kind = verifier
    return (
        _identity(verifier_id, "verifier_id"),
        _identity(kind, "verifier kind"),
    )


def _canonical_refs(refs):
    if refs is None:
        return ()
    if not isinstance(refs, (list, tuple, set, frozenset)):
        raise ValueError("evidence refs must be a collection")
    unique = set()
    for ref in refs:
        unique.add(_identity(ref, "evidence ref"))
    return tuple(sorted(unique))


def compose_certification(
    *,
    target_ref,
    loop_contract_ref,
    required_verifiers,
    owner_target_ref,
    owner_loop_contract_ref,
    owner_artifact_verdicts,
    supporting_verification_refs=None,
    supplemental_evidence_refs=None,
):
    """Project owner Decision verdicts without deriving or changing them.

    The owner Decision contract remains authoritative for artifact-verdict
    semantics. This function only checks exact required-set parity and renders
    a deterministic, non-authoritative view.
    """
    _identity(target_ref, "target_ref")
    _identity(loop_contract_ref, "loop_contract_ref")
    _identity(owner_target_ref, "owner_target_ref")
    _identity(owner_loop_contract_ref, "owner_loop_contract_ref")
    if owner_target_ref != target_ref:
        raise ValueError("owner verdict target binding mismatch")
    if owner_loop_contract_ref != loop_contract_ref:
        raise ValueError("owner verdict contract binding mismatch")

    if not isinstance(required_verifiers, (list, tuple, set, frozenset)):
        raise ValueError("required_verifiers")
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

    refs_by_verifier = (
        {} if supporting_verification_refs is None else supporting_verification_refs
    )
    if not isinstance(refs_by_verifier, dict):
        raise ValueError("supporting_verification_refs")
    if not set(refs_by_verifier).issubset(set(required)):
        raise ValueError("supporting refs for non-required verifier")
    for verifier, refs in refs_by_verifier.items():
        _key(verifier)
        if not isinstance(refs, (list, tuple, set, frozenset)):
            raise ValueError("supporting evidence refs must be collections")

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

    ref_use_counts = {}
    for item in projected:
        for ref in item["supporting_verification_refs"]:
            ref_use_counts[ref] = ref_use_counts.get(ref, 0) + 1
    required_support_refs = set(ref_use_counts)
    shared_required_refs = sorted(
        ref for ref, count in ref_use_counts.items() if count > 1
    )
    supplemental = [
        ref
        for ref in _canonical_refs(supplemental_evidence_refs)
        if ref not in required_support_refs
    ]

    return {
        "authoritative": AUTHORITATIVE,
        "mode": IMPLEMENTATION_MODE,
        "owner_api_connected": OWNER_API_CONNECTED,
        "verdict_source": "injected_owner_oracle",
        "target_ref": target_ref,
        "loop_contract_ref": loop_contract_ref,
        "required_verifiers": projected,
        "shared_required_evidence_refs": shared_required_refs,
        "supplemental_evidence_refs": supplemental,
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
            required_verifiers=required if required is not None else (self.D,),
            owner_target_ref="sha256:" + "a" * 64,
            owner_loop_contract_ref="loop-contract:1",
            owner_artifact_verdicts=owner,
            supporting_verification_refs=refs,
            supplemental_evidence_refs=supplemental,
        )

    def test_mode_is_explicitly_non_authoritative(self):
        projection = self._compose({self.D: "pass"})
        self.assertFalse(projection["authoritative"])
        self.assertEqual(projection["mode"], "executable_spec")
        self.assertFalse(projection["owner_api_connected"])
        self.assertEqual(projection["verdict_source"], "injected_owner_oracle")

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

    def test_identity_inputs_reject_blank_or_surrounding_whitespace(self):
        bad_values = ("", " ", "  value", "value  ")
        for bad in bad_values:
            with self.subTest(value=repr(bad)):
                with self.assertRaises(ValueError):
                    compose_certification(
                        target_ref=bad,
                        loop_contract_ref="loop-contract:1",
                        required_verifiers=(self.D,),
                        owner_target_ref=bad,
                        owner_loop_contract_ref="loop-contract:1",
                        owner_artifact_verdicts={self.D: "pass"},
                    )

        with self.assertRaises(ValueError):
            self._compose(
                {(" verifier", "deterministic"): "pass"},
                required=((" verifier", "deterministic"),),
            )
        with self.assertRaises(ValueError):
            self._compose(
                {self.D: "pass"},
                refs={self.D: [" evidence-ref "]},
            )

    def test_owner_verdict_binding_must_match_projection_target_and_contract(self):
        kwargs = {
            "target_ref": "sha256:" + "a" * 64,
            "loop_contract_ref": "loop-contract:1",
            "required_verifiers": (self.D,),
            "owner_artifact_verdicts": {self.D: "pass"},
        }
        with self.assertRaises(ValueError):
            compose_certification(
                **kwargs,
                owner_target_ref="sha256:" + "b" * 64,
                owner_loop_contract_ref="loop-contract:1",
            )
        with self.assertRaises(ValueError):
            compose_certification(
                **kwargs,
                owner_target_ref="sha256:" + "a" * 64,
                owner_loop_contract_ref="loop-contract:other",
            )

    def test_required_verifier_collection_shape_is_explicit(self):
        wrong_required = (None, "deterministic.tests", {"deterministic.tests": "deterministic"})
        for value in wrong_required:
            with self.subTest(required=repr(value)):
                with self.assertRaises(ValueError):
                    compose_certification(
                        target_ref="sha256:" + "a" * 64,
                        loop_contract_ref="loop-contract:1",
                        required_verifiers=value,
                        owner_target_ref="sha256:" + "a" * 64,
                        owner_loop_contract_ref="loop-contract:1",
                        owner_artifact_verdicts={},
                    )

        with self.assertRaises(ValueError):
            self._compose(
                {self.D: "pass"},
                refs={self.D: None},
            )

    def test_falsy_wrong_types_do_not_collapse_to_empty_inputs(self):
        wrong_support = ([], "", set(), frozenset())
        for value in wrong_support:
            with self.subTest(supporting_type=type(value).__name__):
                with self.assertRaises(ValueError):
                    self._compose(
                        {self.D: "pass"},
                        refs=value,
                    )

        wrong_supplemental = ("", {}, 0, False)
        for value in wrong_supplemental:
            with self.subTest(supplemental=repr(value)):
                with self.assertRaises(ValueError):
                    self._compose(
                        {self.D: "pass"},
                        supplemental=value,
                    )

    def test_empty_required_set_is_rejected(self):
        with self.assertRaises(ValueError):
            self._compose({}, required=())

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

    def test_shared_required_evidence_is_explicit_not_independent(self):
        projection = self._compose(
            {self.D: "pass", self.C: "pass"},
            required=(self.D, self.C),
            refs={
                self.D: ["shared-ref", "d-only"],
                self.C: ["shared-ref", "c-only"],
            },
        )
        self.assertEqual(
            projection["shared_required_evidence_refs"],
            ["shared-ref"],
        )

    def test_same_ref_is_not_counted_as_required_and_supplemental(self):
        projection = self._compose(
            {self.D: "pass"},
            refs={self.D: ["shared-ref", "required-only"]},
            supplemental=["shared-ref", "supplemental-only"],
        )
        item = projection["required_verifiers"][0]
        self.assertEqual(
            item["supporting_verification_refs"],
            ["required-only", "shared-ref"],
        )
        self.assertEqual(
            projection["supplemental_evidence_refs"],
            ["supplemental-only"],
        )
        self.assertEqual(projection["shared_required_evidence_refs"], [])

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

    def test_projection_surface_is_closed_and_reviewable(self):
        projection = self._compose(
            {self.D: "pass", self.C: "unavailable"},
            required=(self.D, self.C),
        )
        self.assertEqual(set(projection), _TOP_LEVEL_PROJECTION_FIELDS)
        for item in projection["required_verifiers"]:
            self.assertEqual(set(item), _REQUIRED_VERIFIER_FIELDS)

        prohibited_parallel_semantics = {
            "status",
            "score",
            "confidence",
            "risk",
            "policy_verdict",
            "decision",
            "outcome",
            "state",
            "stop_reason",
            "promotion_decision",
        }
        self.assertTrue(
            set(projection).isdisjoint(prohibited_parallel_semantics)
        )

    def test_projection_cannot_be_self_promoted_by_caller(self):
        parameters = set(inspect.signature(compose_certification).parameters)
        forbidden_controls = {
            "authoritative",
            "mode",
            "owner_api_connected",
            "verdict_source",
            "decision",
            "policy_verdict",
            "outcome",
            "state",
        }
        self.assertTrue(parameters.isdisjoint(forbidden_controls))

        projection = self._compose({self.D: "pass"})
        self.assertTrue(
            {"decision", "policy_verdict", "outcome", "state", "action"}.isdisjoint(
                projection
            )
        )
        self.assertFalse(projection["authoritative"])
        self.assertFalse(projection["owner_api_connected"])

    def test_projection_boundary_has_no_decision_or_io_dependency(self):
        module = inspect.getmodule(compose_certification)
        tree = ast.parse(inspect.getsource(module))

        imported = set()
        for node in ast.walk(tree):
            if isinstance(node, ast.Import):
                imported.update(alias.name.split(".")[0] for alias in node.names)
            elif isinstance(node, ast.ImportFrom) and node.module:
                imported.add(node.module.split(".")[0])

        self.assertTrue(
            imported.issubset({"__future__", "ast", "copy", "inspect", "unittest"})
        )
        self.assertNotIn("decision_core", imported)

        compose_node = next(
            node
            for node in tree.body
            if isinstance(node, ast.FunctionDef)
            and node.name == "compose_certification"
        )
        forbidden_calls = {"open", "exec", "eval", "__import__", "input"}
        called_names = {
            node.func.id
            for node in ast.walk(compose_node)
            if isinstance(node, ast.Call) and isinstance(node.func, ast.Name)
        }
        self.assertTrue(called_names.isdisjoint(forbidden_calls))

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
