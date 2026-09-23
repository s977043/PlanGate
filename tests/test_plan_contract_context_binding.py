#!/usr/bin/env python3
from __future__ import annotations

import copy
import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
AI_LOOP = ROOT / "scripts" / "ai-loop"
sys.path.insert(0, str(AI_LOOP))
sys.path.insert(0, str(ROOT / "scripts"))

import c3_contract
import plan_package
import intent_context_contract

spec = importlib.util.spec_from_file_location(
    "plan_contract", AI_LOOP / "plan_contract.py"
)
plan_contract = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(plan_contract)

FIXTURE = ROOT / "tests" / "fixtures" / "intent-context" / "valid" / "intent-context.json"


class PlanContractContextBindingTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory(dir=ROOT / "docs" / "working")
        self.task_dir = Path(self.tmp.name) / "TASK-1403"
        self.task_dir.mkdir(parents=True)
        self.intent = json.loads(FIXTURE.read_text(encoding="utf-8"))
        self.intent["task_id"] = "TASK-1403"
        self.intent["context_id"] = "CTX-TASK-1403"
        self._write_intent(self.intent)
        self._write_plan_with_current_marker()
        for name in ("pbi-input.md", "todo.md", "test-cases.md"):
            (self.task_dir / name).write_text(f"# {name}\ncontent\n", encoding="utf-8")
        # legacy C-3 fixture only needs non-empty review artifacts for Plan Package hash
        (self.task_dir / "review-self.md").write_text("# self\nPASS\n", encoding="utf-8")
        (self.task_dir / "review-external.md").write_text("# external\napprove\n", encoding="utf-8")
        self._write_legacy_approval()

    def tearDown(self) -> None:
        self.tmp.cleanup()

    def _write_intent(self, payload: dict) -> bytes:
        raw = (json.dumps(payload, ensure_ascii=False, indent=2) + "\n").encode("utf-8")
        (self.task_dir / "intent-context.json").write_bytes(raw)
        return raw

    def _semantic_ref(self, payload=None):
        return intent_context_contract.compute_context_ref(payload or self.intent)

    def _write_plan_with_current_marker(self):
        ref = self._semantic_ref()
        text = (
            "# Plan\n\n"
            "Intent-Context-ID: CTX-TASK-1403\n"
            f"Intent-Context-Ref: {ref}\n\n"
            "## Goal\nShip safely.\n"
        )
        (self.task_dir / "plan.md").write_text(text, encoding="utf-8")

    def _write_legacy_approval(self, extra=None):
        plan_hash = c3_contract.sha256_of_file(self.task_dir / "plan.md")
        data = {
            "task_id": "TASK-1403",
            "phase": "C-3",
            "c3_status": "APPROVED",
            "approved_by": "human",
            "approved_at": "2026-09-24T00:00:00Z",
            "plan_hash": plan_hash,
            "source": "conversation",
        }
        if extra:
            data.update(extra)
        p = self.task_dir / "approvals"
        p.mkdir(exist_ok=True)
        (p / "c3.json").write_text(
            json.dumps(data, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )

    def test_01_valid_context_binding(self):
        record = plan_contract.build_record(self.task_dir)
        self.assertEqual([], plan_contract.validate_record(self.task_dir, record))
        self.assertEqual(self._semantic_ref(), record["context_binding"]["context_ref"])

    def test_02_no_context_is_backward_compatible(self):
        (self.task_dir / "intent-context.json").unlink()
        (self.task_dir / "plan.md").write_text(
            "# Plan\n\n## Goal\nShip safely.\n", encoding="utf-8"
        )
        self._write_legacy_approval()
        record = plan_contract.build_record(self.task_dir)
        self.assertNotIn("context_binding", record)
        self.assertEqual([], plan_contract.validate_record(self.task_dir, record))

    def test_03_timestamp_only_snapshot_change_does_not_stale(self):
        record = plan_contract.build_record(self.task_dir)
        old_snapshot = record["context_binding"]["snapshot_ref"]
        changed = copy.deepcopy(self.intent)
        changed["created_at"] = "2026-09-25T00:00:00Z"
        changed["sources"][0]["observed_at"] = "2026-09-25T00:00:01Z"
        raw = self._write_intent(changed)
        self.assertEqual(
            record["context_binding"]["context_ref"],
            intent_context_contract.compute_context_ref(changed),
        )
        self.assertNotEqual(
            old_snapshot, intent_context_contract.compute_snapshot_ref(raw)
        )
        self.assertEqual([], plan_contract.validate_record(self.task_dir, record))

    def test_04_semantic_context_change_stales_binding(self):
        record = plan_contract.build_record(self.task_dir)
        changed = copy.deepcopy(self.intent)
        changed["constraints"][0]["statement"] = "semantic change"
        self._write_intent(changed)
        errors = plan_contract.validate_record(self.task_dir, record)
        self.assertTrue(errors)

    def test_05_context_task_mismatch_fails(self):
        bad = copy.deepcopy(self.intent)
        bad["task_id"] = "TASK-9999"
        self._write_intent(bad)
        with self.assertRaises(plan_contract.PlanContractError):
            plan_contract.build_record(self.task_dir)

    def test_06_invalid_context_fails(self):
        bad = copy.deepcopy(self.intent)
        bad["constraints"][0]["source_ids"] = ["SRC-NOPE"]
        self._write_intent(bad)
        with self.assertRaises(plan_contract.PlanContractError):
            plan_contract.build_record(self.task_dir)

    def test_07_plan_marker_is_required_and_approval_bound(self):
        (self.task_dir / "plan.md").write_text(
            "# Plan\n\n## Goal\nNo context marker.\n", encoding="utf-8"
        )
        self._write_legacy_approval()
        with self.assertRaises(plan_contract.PlanContractError):
            plan_contract.build_record(self.task_dir)

    def test_08_stale_plan_hash_fails(self):
        record = plan_contract.build_record(self.task_dir)
        with (self.task_dir / "plan.md").open("a", encoding="utf-8") as fh:
            fh.write("\nchanged after approval\n")
        self.assertTrue(plan_contract.validate_record(self.task_dir, record))

    def test_09_approval_digest_change_fails(self):
        record = plan_contract.build_record(self.task_dir)
        self._write_legacy_approval({"_note": "same approval semantics, different bytes"})
        errors = plan_contract.validate_record(self.task_dir, record)
        self.assertTrue(any("approval_ref" in e for e in errors))

    def test_10_sidecar_contains_refs_not_context_claims(self):
        record = plan_contract.build_record(self.task_dir)
        blob = json.dumps(record, ensure_ascii=False)
        for forbidden in (
            "desired_outcomes",
            "constraints",
            "acceptance_inputs",
            "assumptions",
            "unknowns",
            "conflicts",
            "sources",
        ):
            self.assertNotIn(f'"{forbidden}"', blob)

    def test_11_duplicate_plan_context_marker_rejected(self):
        plan = self.task_dir / "plan.md"
        with plan.open("a", encoding="utf-8") as fh:
            fh.write(f"Intent-Context-Ref: {self._semantic_ref()}\n")
        self._write_legacy_approval()
        with self.assertRaises(plan_contract.PlanContractError):
            plan_contract.build_record(self.task_dir)

    def _authoritative_conflict_payload(self):
        payload = copy.deepcopy(self.intent)
        payload["sources"].append({
            "source_id": "SRC-002",
            "kind": "spec",
            "ref": "docs/other-spec.md",
            "revision_ref": "git:1111111111111111111111111111111111111111",
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
            "observed_at": "2026-09-24T00:00:00Z",
        })
        payload["constraints"].append({
            "constraint_id": "CON-002",
            "category": "scope",
            "statement": "conflicting authoritative requirement",
            "source_ids": ["SRC-002"],
        })
        payload["conflicts"] = [{
            "conflict_id": "CFT-001",
            "statement_refs": ["OUT-001", "CON-002"],
            "source_ids": ["SRC-001", "SRC-002"],
            "description": "authoritative requirements disagree",
        }]
        return payload

    def _prepare_c3_prime_evidence(self):
        plan_hash = c3_contract.sha256_of_file(self.task_dir / "plan.md")
        (self.task_dir / "review-self.md").write_text(
            f"C1-VERDICT: PASS plan={plan_hash}\n", encoding="utf-8"
        )
        (self.task_dir / "review-external.md").write_text(
            f"C2-VERDICT: approve plan={plan_hash}\n", encoding="utf-8"
        )

    def test_12_authoritative_conflict_blocks_auto_approval(self):
        payload = self._authoritative_conflict_payload()
        self._write_intent(payload)
        self._prepare_c3_prime_evidence()
        with self.assertRaises(plan_package.PlanPackageError) as ctx:
            plan_package.build_c3_prime(
                self.task_dir,
                "TASK-1403",
                "a" * 40,
                "a" * 40,
                {"model_a": "approve", "model_b": "approve"},
                {"model_a": "review-a.md", "model_b": "review-b.md"},
                "AUTO_APPROVED",
                "policy/ref",
                "2026-09-24T00:00:00Z",
                "arbiter-test",
            )
        self.assertIn("authoritative conflict", str(ctx.exception))

    def test_13_authoritative_conflict_can_escalate(self):
        payload = self._authoritative_conflict_payload()
        self._write_intent(payload)
        self._prepare_c3_prime_evidence()
        record = plan_package.build_c3_prime(
            self.task_dir,
            "TASK-1403",
            "a" * 40,
            "a" * 40,
            {"model_a": "approve", "model_b": "approve"},
            {"model_a": "review-a.md", "model_b": "review-b.md"},
            "HUMAN_ESCALATED",
            "policy/ref",
            "2026-09-24T00:00:00Z",
            "arbiter-test",
        )
        self.assertEqual("HUMAN_ESCALATED", record["decision"])

    def test_14_authoritative_conflict_helper_is_deterministic(self):
        payload = self._authoritative_conflict_payload()
        self.assertEqual(
            ["CFT-001"], intent_context_contract.authoritative_conflicts(payload)
        )

    def test_15_bundled_intent_context_helper_imports(self):
        bundled = (
            ROOT
            / "plugin"
            / "plangate"
            / "skills"
            / "ai-loop-cycle"
            / "scripts"
            / "intent_context_contract.py"
        )
        spec = importlib.util.spec_from_file_location("bundled_intent_context_contract", bundled)
        module = importlib.util.module_from_spec(spec)
        assert spec.loader is not None
        spec.loader.exec_module(module)
        self.assertEqual(
            intent_context_contract.c3_contract.canonical_hash({"text": "日本語", "n": 1}),
            module.c3_contract.canonical_hash({"text": "日本語", "n": 1}),
        )


if __name__ == "__main__":
    unittest.main()
