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

import importlib.util
import tempfile
import unittest
from pathlib import Path

SOURCE = Path(__file__).with_name("improvement_seed_delta.py")
SPEC = importlib.util.spec_from_file_location("improvement_seed_delta", SOURCE)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)

SEED_A = "2026-06-07 — task-A"
SEED_B = "2026-06-08 — task-B"


class SeedInventoryTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.seeds = self.root / "seeds.md"
        self.digest = self.root / "digest.md"
        self.seeds.write_text(
            f"# Seeds\n\n## {SEED_A}\n- confirmed_by: human\n"
            f"\n## {SEED_B}\n- confirmed_by: human\n",
            encoding="utf-8",
        )
        self.digest.write_text(
            f"# Digest\n\n## 対象エントリ\n\n- {SEED_A}\n\n## 次節\n",
            encoding="utf-8",
        )

    def test_unindexed_entry_is_review_candidate_without_writing_files(self):
        before = (self.seeds.read_bytes(), self.digest.read_bytes())
        result = MODULE.inventory(self.seeds, self.digest, threshold=1)
        self.assertEqual(result["unindexed_entries"], [SEED_B])
        self.assertEqual(result["status"], "REVIEW_CANDIDATE")
        self.assertEqual((self.seeds.read_bytes(), self.digest.read_bytes()), before)

    def test_below_threshold_does_not_pretend_to_promote(self):
        result = MODULE.inventory(self.seeds, self.digest, threshold=2)
        self.assertEqual(result["status"], "BELOW_THRESHOLD")
        self.assertEqual(result["authority"], "READ_ONLY_UNVERIFIED_MARKER_NO_PROMOTION")

    def test_missing_human_confirmation_is_rejected(self):
        self.seeds.write_text(f"## {SEED_A}\n- confirmed_by: human\n\n## {SEED_B}\n- reason: drafted\n", encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "confirmation marker"):
            MODULE.inventory(self.seeds, self.digest, 1)

    def test_duplicate_seed_identity_is_rejected(self):
        self.seeds.write_text(f"## {SEED_A}\n- confirmed_by: human\n\n## {SEED_A}\n- confirmed_by: human\n", encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "duplicate"):
            MODULE.inventory(self.seeds, self.digest, 1)

    def test_unknown_digest_identity_is_rejected(self):
        self.digest.write_text("# Digest\n\n## 対象エントリ\n\n- 2026-06-09 — unknown\n", encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "absent or lack a confirmation marker"):
            MODULE.inventory(self.seeds, self.digest, 1)

    def test_malformed_digest_does_not_pass_as_empty(self):
        self.digest.write_text("# Digest\n\n## no-index\n", encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "missing the target entry section"):
            MODULE.inventory(self.seeds, self.digest, 1)

    def test_all_entries_indexed_has_zero_delta(self):
        self.digest.write_text(f"## 対象エントリ\n\n- {SEED_A}\n- {SEED_B}\n", encoding="utf-8")
        result = MODULE.inventory(self.seeds, self.digest, 1)
        self.assertEqual(result["unindexed_count"], 0)
        self.assertEqual(result["status"], "BELOW_THRESHOLD")

    def test_nonpositive_threshold_rejected(self):
        with self.assertRaisesRegex(ValueError, "threshold"):
            MODULE.inventory(self.seeds, self.digest, 0)


if __name__ == "__main__":
    unittest.main()
