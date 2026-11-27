#!/usr/bin/env python3
""":"
# --- PG-SH-GUARD (#1169): sh / bash 誤起動ガード ---
# sh はこのファイルの module docstring を二重引用符文字列として読むため、
# docstring 内のバッククォートがコマンド置換として評価され、repo を書き換える
# 副作用が起きる。python3 以外のインタプリタでは何も評価する前にここで止める。
echo "ERROR: $0 is a Python script; do not run it with sh/bash." >&2
echo "       Use: python3 $0 [args...]" >&2
exit 2
":"""
from __future__ import annotations

import ast
import pathlib
import sys
import unittest

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import limits  # noqa: E402
from fixtures.decision_event_worst_case import (  # noqa: E402
    byte_parts, canonical_bytes, worst_case_event,
)

LIMITS_PATH = HERE / "limits.py"
SIBLING_MODULES = {p.stem for p in HERE.glob("*.py")} - {"limits"}
EXPECTED_BYTES = {
    (None, False): 26738,
    (None, True): 26827,
    ("MERGE_READY", True): 26832,
    ("BLOCKED", False): 26945,
    ("BLOCKED", True): 27034,
    ("HUMAN_ESCALATED", False): 26953,
    ("HUMAN_ESCALATED", True): 27042,
}


def _forbidden_imports(source: str, siblings: set[str]) -> set[str]:
    """Return the sibling modules (and ``<relative>``) that ``source`` imports.

    Residual threat: only static ``import`` / ``from ... import`` statements are
    seen. Dynamic imports (``__import__(...)``, ``importlib.import_module(...)``)
    are not detected.
    """
    imported = set()
    for node in ast.walk(ast.parse(source)):
        if isinstance(node, ast.Import):
            imported.update(alias.name.split(".")[0] for alias in node.names)
        elif isinstance(node, ast.ImportFrom):
            if node.level:
                imported.add("<relative>")
            elif node.module:
                imported.add(node.module.split(".")[0])
    return imported & (siblings | {"<relative>"})


class LimitsFixtureTest(unittest.TestCase):
    """DI-46 (R-086 / R-087 / R-090 / R-091)."""

    def test_values(self) -> None:
        self.assertEqual(limits.MAX_INPUT_REFS, 256)
        self.assertEqual(limits.MAX_REQUIRED_VERIFIERS, 16)
        self.assertEqual(limits.MAX_REF_CHARS, 71)

    def test_ref_chars_matches_sha256_form(self) -> None:
        self.assertEqual(limits.MAX_REF_CHARS, len("sha256:" + "0" * 64))

    def test_decision_event_bytes(self) -> None:
        cases = {
            (outcome, artifact)
            for outcome in (None, "MERGE_READY", "BLOCKED", "HUMAN_ESCALATED")
            for artifact in (False, True)
            if outcome != "MERGE_READY" or artifact
        }
        self.assertEqual(EXPECTED_BYTES.keys(), cases)
        for (outcome, artifact), expected in EXPECTED_BYTES.items():
            with self.subTest(outcome=outcome, artifact=artifact):
                for input_count in (0, 128, 256):
                    event = worst_case_event(outcome, artifact=artifact, input_count=input_count)
                    size = len(canonical_bytes(event))
                    self.assertEqual(size, expected - int(0 < input_count < 256))
                    self.assertEqual(sum(byte_parts(event)), size)
                    self.assertLessEqual(size, limits.MAX_DECISION_EVENT_BYTES)

    def test_byte_part_bounds(self) -> None:
        parts = [
            byte_parts(worst_case_event(outcome, artifact=artifact, input_count=256))
            for outcome, artifact in EXPECTED_BYTES
        ]
        input_max, fixed_max, envelope_max = map(max, zip(*parts))
        self.assertEqual(fixed_max, limits.DECISION_FIXED_OVERHEAD)
        self.assertEqual(envelope_max, limits.ENVELOPE_OVERHEAD)
        self.assertEqual(input_max + fixed_max + envelope_max, limits.MAX_DECISION_EVENT_BYTES)

    def test_terminal_reserve_contract(self) -> None:
        terminal_reserve = (1, limits.MAX_DECISION_EVENT_BYTES)
        event = worst_case_event("HUMAN_ESCALATED", artifact=True, input_count=256)
        self.assertGreaterEqual(terminal_reserve[0], 1)
        self.assertGreaterEqual(terminal_reserve[1], len(canonical_bytes(event)))

    def test_imports_no_ai_loop_v2_module(self) -> None:
        self.assertTrue(SIBLING_MODULES, "sibling module discovery is empty")
        source = LIMITS_PATH.read_text(encoding="utf-8")
        self.assertEqual(_forbidden_imports(source, SIBLING_MODULES), set())

    def test_import_check_positive_control(self) -> None:
        siblings = {"run_event", "decision_core"}
        cases = {
            "import run_event\n": {"run_event"},
            "from . import x\n": {"<relative>"},
            "from decision_core import y\n": {"decision_core"},
        }
        for source, expected in cases.items():
            with self.subTest(source=source):
                self.assertEqual(_forbidden_imports(source, siblings), expected)


if __name__ == "__main__":
    unittest.main()
