#!/usr/bin/env python3
from __future__ import annotations

import copy
import importlib.util
import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = ROOT / "scripts" / "intent_context_contract.py"
FIXTURE_PATH = ROOT / "tests" / "fixtures" / "intent-context" / "valid" / "intent-context.json"

spec = importlib.util.spec_from_file_location("intent_context_contract", MODULE_PATH)
contract = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(contract)


class IntentContextContractTests(unittest.TestCase):
    def setUp(self) -> None:
        self.raw = FIXTURE_PATH.read_bytes()
        self.base = json.loads(self.raw)

    def errors(self, payload):
        return contract.validate_package(payload)

    def test_01_valid_fixture(self):
        self.assertEqual([], self.errors(self.base))

    def test_02_timestamp_only_change_keeps_context_ref(self):
        other = copy.deepcopy(self.base)
        other["created_at"] = "2026-09-24T10:40:00Z"
        other["sources"][0]["observed_at"] = "2026-09-24T10:39:00Z"
        self.assertEqual(
            contract.compute_context_ref(self.base),
            contract.compute_context_ref(other),
        )

    def test_03_resolver_version_only_change_keeps_context_ref(self):
        other = copy.deepcopy(self.base)
        other["resolver_version"] = "intent-context/1.0.1"
        self.assertEqual(
            contract.compute_context_ref(self.base),
            contract.compute_context_ref(other),
        )

    def test_04_semantic_change_changes_context_ref(self):
        other = copy.deepcopy(self.base)
        other["constraints"][0]["statement"] = "semantic change"
        self.assertNotEqual(
            contract.compute_context_ref(self.base),
            contract.compute_context_ref(other),
        )

    def test_05_set_like_order_is_canonicalized(self):
        other = copy.deepcopy(self.base)
        other["sources"].append({
            "source_id": "SRC-002",
            "kind": "spec",
            "ref": "docs/spec.md",
            "revision_ref": "git:1111111111111111111111111111111111111111",
            "content_digest": None,
            "authority": "supporting",
            "authority_basis": {"kind": "repository_canon", "ref": "docs/spec.md"},
            "freshness": "current",
            "freshness_basis": {
                "kind": "bound_revision",
                "ref": "git:1111111111111111111111111111111111111111",
            },
            "observed_at": "2026-09-23T10:39:01Z",
        })
        other["intent"]["summary"]["source_ids"] = ["SRC-002", "SRC-001"]
        reordered = copy.deepcopy(other)
        reordered["sources"].reverse()
        reordered["intent"]["summary"]["source_ids"].reverse()
        self.assertEqual(
            contract.compute_context_ref(other),
            contract.compute_context_ref(reordered),
        )

    def test_06_snapshot_ref_tracks_exact_bytes(self):
        changed = self.raw.replace(
            b'"created_at": "2026-09-23T10:40:00Z"',
            b'"created_at": "2026-09-24T10:40:00Z"',
        )
        self.assertNotEqual(
            contract.compute_snapshot_ref(self.raw),
            contract.compute_snapshot_ref(changed),
        )

    def test_07_duplicate_source_id_rejected(self):
        bad = copy.deepcopy(self.base)
        bad["sources"].append(copy.deepcopy(bad["sources"][0]))
        self.assertTrue(any("duplicate source_id" in x for x in self.errors(bad)))

    def test_08_unknown_source_reference_rejected(self):
        bad = copy.deepcopy(self.base)
        bad["constraints"][0]["source_ids"] = ["SRC-NOPE"]
        self.assertTrue(any("unknown source_id" in x for x in self.errors(bad)))

    def test_09_current_without_observed_identity_rejected(self):
        bad = copy.deepcopy(self.base)
        bad["sources"][0]["revision_ref"] = None
        bad["sources"][0]["content_digest"] = None
        self.assertNotEqual([], self.errors(bad))

    def test_10_current_with_unavailable_basis_rejected(self):
        bad = copy.deepcopy(self.base)
        bad["sources"][0]["freshness_basis"] = {"kind": "unavailable", "ref": None}
        self.assertNotEqual([], self.errors(bad))

    def test_11_authoritative_without_valid_basis_rejected(self):
        bad = copy.deepcopy(self.base)
        bad["sources"][0]["authority_basis"] = {
            "kind": "unverified_default",
            "ref": None,
        }
        self.assertNotEqual([], self.errors(bad))

    def test_12_authoritative_basis_requires_ref(self):
        bad = copy.deepcopy(self.base)
        bad["sources"][0]["authority_basis"]["ref"] = None
        self.assertNotEqual([], self.errors(bad))

    def test_13_current_freshness_basis_requires_ref(self):
        bad = copy.deepcopy(self.base)
        bad["sources"][0]["freshness_basis"]["ref"] = None
        self.assertNotEqual([], self.errors(bad))

    def test_14_absolute_local_source_ref_rejected(self):
        bad = copy.deepcopy(self.base)
        bad["sources"][0]["ref"] = "/Users/example/private/spec.md"
        self.assertTrue(
            any("absolute local path" in x for x in self.errors(bad))
        )

    def test_15_self_hash_field_rejected(self):
        bad = copy.deepcopy(self.base)
        bad["context_ref"] = "sha256:" + "b" * 64
        self.assertNotEqual([], self.errors(bad))

    def test_16_final_acceptance_criteria_field_rejected(self):
        bad = copy.deepcopy(self.base)
        bad["acceptance_criteria"] = ["must not be package-owned"]
        self.assertNotEqual([], self.errors(bad))

    def test_17_unsourced_assumption_is_valid(self):
        self.assertEqual([], self.base["assumptions"][0]["source_ids"])
        self.assertEqual([], self.errors(self.base))

    def test_18_unknown_conflict_statement_ref_rejected(self):
        bad = copy.deepcopy(self.base)
        bad["sources"].append({
            "source_id": "SRC-002",
            "kind": "discussion",
            "ref": "https://example.invalid/thread/1",
            "revision_ref": "rev-1",
            "content_digest": None,
            "authority": "authoritative",
            "authority_basis": {
                "kind": "explicit_human_designation",
                "ref": "human:task-owner",
            },
            "freshness": "current",
            "freshness_basis": {
                "kind": "explicit_human_assertion",
                "ref": "human:task-owner",
            },
            "observed_at": "2026-09-23T10:39:02Z",
        })
        bad["conflicts"] = [{
            "conflict_id": "CFT-001",
            "statement_refs": ["OUT-001", "CON-NOPE"],
            "source_ids": ["SRC-001", "SRC-002"],
            "description": "conflict",
        }]
        self.assertTrue(any("unknown statement" in x for x in self.errors(bad)))

    def test_19_raw_body_is_rejected(self):
        bad = copy.deepcopy(self.base)
        bad["sources"][0]["raw_body"] = "do not copy source bodies"
        self.assertNotEqual([], self.errors(bad))

    def test_20_non_ascii_canonical_hash_golden_vector(self):
        self.assertEqual(
            "sha256:731ad74c6dd72c1576f775a0abef976bb707773aee0cd34d45a797bb8a284b9d",
            contract.c3_contract.canonical_hash({"text": "日本語", "n": 1}),
        )


if __name__ == "__main__":
    unittest.main()
