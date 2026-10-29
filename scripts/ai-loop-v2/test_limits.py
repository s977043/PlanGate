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

LIMITS_PATH = HERE / "limits.py"
SIBLING_MODULES = {p.stem for p in HERE.glob("*.py")} - {"limits"}
BYTE_CONSTANTS = {"MAX_DECISION_EVENT_BYTES", "DECISION_FIXED_OVERHEAD", "ENVELOPE_OVERHEAD"}


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

    def test_no_byte_constants(self) -> None:
        for name in BYTE_CONSTANTS:
            self.assertFalse(hasattr(limits, name), name)

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
