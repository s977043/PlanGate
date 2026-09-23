#!/usr/bin/env python3
from __future__ import annotations

import copy
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = ROOT / "scripts" / "context-engine.py"
FIXTURE_PATH = ROOT / "tests" / "fixtures" / "intent-context" / "valid" / "intent-context.json"
SCHEMA_PATH = ROOT / "schemas" / "context-manifest.schema.json"

spec = importlib.util.spec_from_file_location("context_engine", MODULE_PATH)
engine = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(engine)


class ContextEngineIntentContextTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory(dir=ROOT / "docs" / "working")
        self.working = Path(self.tmp.name)
        self.task_id = "TASK-1399"
        self.task_dir = self.working / self.task_id
        self.task_dir.mkdir(parents=True)
        self.old_working = engine.WORKING
        engine.WORKING = self.working
        self.base = json.loads(FIXTURE_PATH.read_text(encoding="utf-8"))
        self.base["task_id"] = self.task_id

    def tearDown(self) -> None:
        engine.WORKING = self.old_working
        self.tmp.cleanup()

    def write_package(self, payload: dict) -> bytes:
        raw = (json.dumps(payload, ensure_ascii=False, indent=2) + "\n").encode("utf-8")
        (self.task_dir / "intent-context.json").write_bytes(raw)
        return raw

    def build(self):
        return engine.build(self.task_id, "execute", "standard", None)

    def test_01_absent_package_preserves_legacy_shape(self):
        manifest = self.build()
        self.assertNotIn("intent_context", manifest)
        self.assertEqual(
            ["pbi_input", "approved_plan", "test_cases", "c3_approval"],
            [x["kind"] for x in manifest["contract_context"]],
        )

    def test_02_valid_package_emits_refs_only(self):
        raw = self.write_package(self.base)
        manifest = self.build()
        ref = manifest["intent_context"]
        self.assertEqual("present", ref["status"])
        self.assertEqual(self.base["context_id"], ref["context_id"])
        self.assertEqual(
            engine.intent_context_contract.compute_context_ref(self.base),
            ref["context_ref"],
        )
        self.assertEqual(
            engine.intent_context_contract.compute_snapshot_ref(raw),
            ref["snapshot_ref"],
        )
        self.assertEqual(
            {"path", "status", "context_id", "context_ref", "snapshot_ref"},
            set(ref),
        )

    def test_03_timestamp_only_reresolution_keeps_semantic_ref(self):
        self.write_package(self.base)
        first = self.build()["intent_context"]
        changed = copy.deepcopy(self.base)
        changed["created_at"] = "2026-09-24T10:40:00Z"
        changed["sources"][0]["observed_at"] = "2026-09-24T10:39:00Z"
        self.write_package(changed)
        second = self.build()["intent_context"]
        self.assertEqual(first["context_ref"], second["context_ref"])
        self.assertNotEqual(first["snapshot_ref"], second["snapshot_ref"])

    def test_04_semantic_invalid_package_exposes_no_refs(self):
        bad = copy.deepcopy(self.base)
        bad["constraints"][0]["source_ids"] = ["SRC-NOPE"]
        self.write_package(bad)
        ref = self.build()["intent_context"]
        self.assertEqual({"path", "status"}, set(ref))
        self.assertEqual("invalid", ref["status"])

    def test_05_format_invalid_package_exposes_no_refs(self):
        bad = copy.deepcopy(self.base)
        bad["created_at"] = "not-a-date-time"
        self.write_package(bad)
        self.assertEqual(
            "invalid", self.build()["intent_context"]["status"]
        )

    def test_06_task_mismatch_is_invalid(self):
        bad = copy.deepcopy(self.base)
        bad["task_id"] = "TASK-OTHER"
        self.write_package(bad)
        ref = self.build()["intent_context"]
        self.assertEqual("invalid", ref["status"])
        self.assertNotIn("context_ref", ref)

    def test_07_package_claims_are_not_copied(self):
        self.write_package(self.base)
        ref = self.build()["intent_context"]
        for forbidden in (
            "sources",
            "intent",
            "constraints",
            "acceptance_inputs",
            "assumptions",
            "unknowns",
            "conflicts",
        ):
            self.assertNotIn(forbidden, ref)

    def test_08_generated_manifest_matches_draft07_schema(self):
        from jsonschema import Draft7Validator

        self.write_package(self.base)
        schema = json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))
        Draft7Validator(schema).validate(self.build())


if __name__ == "__main__":
    unittest.main()
