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

    def test_empty_confirmation_does_not_take_next_line(self):
        self.seeds.write_text(f"## {SEED_A}\n- confirmed_by: human\n\n## {SEED_B}\n- confirmed_by:\n- reason: x\n", encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "confirmation marker"):
            MODULE.inventory(self.seeds, self.digest, 1)

    def test_noncanonical_seed_heading_is_rejected(self):
        for heading in ("## 2026-06-09 - task-C", "### 2026-06-09 — task-C"):
            with self.subTest(heading=heading):
                self.seeds.write_text(
                    f"## {SEED_A}\n- confirmed_by: human\n\n{heading}\n- reason: drafted\n", encoding="utf-8"
                )
                with self.assertRaisesRegex(ValueError, "canonical"):
                    MODULE.inventory(self.seeds, self.digest, 1)

    def test_duplicated_digest_section_is_rejected(self):
        self.digest.write_text(
            f"## 対象エントリ\n\n- {SEED_A}\n\n## 対象エントリ\n\n- 2026-06-09 — ghost\n", encoding="utf-8"
        )
        with self.assertRaisesRegex(ValueError, "more than one"):
            MODULE.inventory(self.seeds, self.digest, 1)

    def test_placeholder_confirmation_is_rejected(self):
        self.seeds.write_text(f"## {SEED_A}\n- confirmed_by: <Human>\n", encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "confirmation marker"):
            MODULE.inventory(self.seeds, self.digest, 1)

    def test_lookalike_seed_headings_are_rejected(self):
        headings = (
            "##　2026-06-09 — task-C",
            "## 2026-06-09 — task-C",
            "# 2026-06-09 — task-C",
            " ## 2026-06-09 — task-C",
            "## task-C 2026-06-09",
            "##2026-06-09 — task-C",
            "##\t2026-06-09 — task-C",
        )
        for heading in headings:
            with self.subTest(heading=heading):
                self.seeds.write_text(
                    f"## {SEED_A}\n- confirmed_by: human\n\n{heading}\n- reason: drafted\n", encoding="utf-8"
                )
                with self.assertRaisesRegex(ValueError, "canonical"):
                    MODULE.inventory(self.seeds, self.digest, 1)

    def test_non_seed_heading_without_date_is_accepted(self):
        self.seeds.write_text(
            f"# Seeds\n\n## 概要\n\n## {SEED_A}\n- confirmed_by: human\n### 補足\n", encoding="utf-8"
        )
        result = MODULE.inventory(self.seeds, self.digest, 1)
        self.assertEqual(result["entries_with_confirmation_marker"], 1)

    def test_code_block_heading_is_not_rejected(self):
        self.seeds.write_text(
            f"## {SEED_A}\n- confirmed_by: human\n\n```markdown\n## 2026-06-09 - template\n- confirmed_by: <human>\n```\n",
            encoding="utf-8",
        )
        result = MODULE.inventory(self.seeds, self.digest, 1)
        self.assertEqual(result["entries_with_confirmation_marker"], 1)

    def test_confirmation_inside_code_block_is_not_accepted(self):
        self.seeds.write_text(
            f"## {SEED_A}\n- confirmed_by: human\n\n## {SEED_B}\n```\n- confirmed_by: human\n```\n", encoding="utf-8"
        )
        with self.assertRaisesRegex(ValueError, "confirmation marker"):
            MODULE.inventory(self.seeds, self.digest, 1)

    def test_seed_heading_inside_code_block_is_not_counted(self):
        self.seeds.write_text(
            f"## {SEED_A}\n- confirmed_by: human\n\n~~~\n## {SEED_B}\n- confirmed_by: human\n~~~\n", encoding="utf-8"
        )
        result = MODULE.inventory(self.seeds, self.digest, 1)
        self.assertEqual(result["entries_with_confirmation_marker"], 1)

    def test_unclosed_fence_is_rejected(self):
        for fence in ("```", "~~~"):
            with self.subTest(fence=fence):
                self.seeds.write_text(
                    f"## {SEED_A}\n- confirmed_by: human\n\n{fence}\nsample\n\n## 2026-06-09 — x\n- reason: d\n",
                    encoding="utf-8",
                )
                with self.assertRaisesRegex(ValueError, "unclosed code fence"):
                    MODULE.inventory(self.seeds, self.digest, 1)

    def test_fence_closes_only_with_same_kind_and_sufficient_length(self):
        for opening, inner in (("````", "```"), ("```", "~~~"), ("~~~~", "~~~"), ("```", "``` info")):
            with self.subTest(opening=opening, inner=inner):
                self.seeds.write_text(
                    f"## {SEED_A}\n- confirmed_by: human\n\n{opening}\n{inner}\n## {SEED_B}\n- confirmed_by: human\n",
                    encoding="utf-8",
                )
                with self.assertRaisesRegex(ValueError, "unclosed code fence"):
                    MODULE.inventory(self.seeds, self.digest, 1)

    def test_longer_closing_fence_closes(self):
        self.seeds.write_text(
            f"## {SEED_A}\n- confirmed_by: human\n\n````\n```\n## {SEED_B}\n- confirmed_by: human\n`````\n",
            encoding="utf-8",
        )
        result = MODULE.inventory(self.seeds, self.digest, 1)
        self.assertEqual(result["entries_with_confirmation_marker"], 1)

    def test_negative_confirmation_is_rejected(self):
        for value in ("no", "No", "false", "-", "n/a", "なし", "no（後で確認）"):
            with self.subTest(value=value):
                self.seeds.write_text(f"## {SEED_A}\n- confirmed_by: {value}\n", encoding="utf-8")
                with self.assertRaisesRegex(ValueError, "confirmation marker"):
                    MODULE.inventory(self.seeds, self.digest, 1)

    def test_bom_prefixed_first_seed_is_counted(self):
        self.seeds.write_text(f"﻿## {SEED_A}\n- confirmed_by: pending\n", encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "confirmation marker"):
            MODULE.inventory(self.seeds, self.digest, 1)

        self.seeds.write_text(
            f"﻿## {SEED_B}\n- confirmed_by: human\n\n## {SEED_A}\n- confirmed_by: human\n",
            encoding="utf-8",
        )
        self.digest.write_text(f"﻿## 対象エントリ\n\n- {SEED_A}\n", encoding="utf-8")
        result = MODULE.inventory(self.seeds, self.digest, 1)
        self.assertEqual(result["unindexed_entries"], [SEED_B])

    def write_seeds(self, tail: str) -> None:
        self.seeds.write_text(f"## {SEED_A}\n- confirmed_by: human\n\n{tail}", encoding="utf-8")

    def count(self) -> int:
        return MODULE.inventory(self.seeds, self.digest, 1)["entries_with_confirmation_marker"]

    def test_tc_r4_02_seed_inside_html_comment_is_not_counted(self):
        self.write_seeds(f"<!--\n## {SEED_B}\n- confirmed_by: human\n-->\n")
        self.assertEqual(self.count(), 1)

    def test_tc_r4_03_name_starting_with_negative_word_is_rejected(self):
        for value in ("Na Yeon", "No Kim"):
            with self.subTest(value=value):
                self.seeds.write_text(f"## {SEED_A}\n- confirmed_by: {value}\n", encoding="utf-8")
                with self.assertRaisesRegex(ValueError, "confirmation marker"):
                    MODULE.inventory(self.seeds, self.digest, 1)

    def test_tc_html_01_unclosed_html_comment_is_rejected(self):
        self.write_seeds(f"<!--\nnote\n\n## {SEED_B}\n- reason: drafted\n")
        with self.assertRaisesRegex(ValueError, "unclosed HTML"):
            MODULE.inventory(self.seeds, self.digest, 1)

    def test_tc_html_02_single_line_comment_seed_is_not_counted(self):
        self.write_seeds(f"<!-- ## {SEED_B} -->\n")
        self.assertEqual(self.count(), 1)

    def test_tc_html_03_confirmation_inside_comment_is_not_accepted(self):
        self.write_seeds(f"## {SEED_B}\n<!--\n- confirmed_by: human\n-->\n")
        with self.assertRaisesRegex(ValueError, "confirmation marker"):
            MODULE.inventory(self.seeds, self.digest, 1)

    def test_tc_html_04_div_block_ends_at_blank_line(self):
        self.write_seeds(f"<div>\n## 2026-06-09 — hidden\n</div>\n\n## {SEED_B}\n- confirmed_by: human\n")
        self.assertEqual(self.count(), 2)

    def test_tc_html_05_fence_and_comment_nesting(self):
        self.write_seeds(f"```\n<!--\n```\n\n## {SEED_B}\n- confirmed_by: human\n")
        self.assertEqual(self.count(), 2)
        self.write_seeds(f"<!--\n```\n-->\n\n## {SEED_B}\n- confirmed_by: human\n")
        self.assertEqual(self.count(), 2)

    def test_tc_blk_01_to_03_out_of_scope_date_headings_are_rejected(self):
        for tail in (
            f"> ## {SEED_B}\n- confirmed_by: human\n",
            f"- ## {SEED_B}\n  - confirmed_by: human\n",
            f"{SEED_B}\n---\n- confirmed_by: human\n",
            f"{SEED_B}\n===\n- confirmed_by: human\n",
        ):
            with self.subTest(tail=tail):
                self.write_seeds(tail)
                with self.assertRaisesRegex(ValueError, "canonical"):
                    MODULE.inventory(self.seeds, self.digest, 1)

    def test_tc_blk_04_indented_code_seed_is_not_counted(self):
        self.write_seeds(f"    ## {SEED_B}\n    - confirmed_by: human\n")
        self.assertEqual(self.count(), 1)

    def test_tc_blk_04b_indented_heading_in_list_item_is_rejected(self):
        self.write_seeds(f"- item\n\n    ## {SEED_B}\n")
        with self.assertRaisesRegex(ValueError, "canonical"):
            MODULE.inventory(self.seeds, self.digest, 1)

    def test_tc_blk_05_four_space_fence_does_not_open(self):
        self.write_seeds(f"    ```\n\n## {SEED_B}\n- confirmed_by: human\n")
        self.assertEqual(self.count(), 2)

    def test_tc_blk_06_crlf_matches_lf(self):
        self.seeds.write_bytes(f"## {SEED_A}\r\n- confirmed_by: human\r\n\r\n## {SEED_B}\r\n- confirmed_by: human\r\n".encode())
        self.digest.write_bytes(f"## 対象エントリ\r\n\r\n- {SEED_A}\r\n".encode())
        self.assertEqual(MODULE.inventory(self.seeds, self.digest, 1)["unindexed_entries"], [SEED_B])

    def test_tc_inv_01_02_invisible_characters_in_heading_are_rejected(self):
        for heading in (
            "## 2026-06-09​ — task-C",
            "## 2026-06-09 — task​C",
            "## 2026-06-09 — task﻿C",
            "## 2026-06-09 — task⁠C",
            "​## 2026-06-09 — task-C",
            "## ２０２６-06-09 — task-C",
        ):
            with self.subTest(heading=heading):
                self.write_seeds(f"{heading}\n- confirmed_by: human\n")
                with self.assertRaisesRegex(ValueError, "canonical"):
                    MODULE.inventory(self.seeds, self.digest, 1)

    def test_tc_inv_03_invisible_character_in_confirmation_is_rejected(self):
        for value in ("​no", "hu​man", "human "):
            with self.subTest(value=value):
                self.seeds.write_text(f"## {SEED_A}\n- confirmed_by: {value}\n", encoding="utf-8")
                with self.assertRaisesRegex(ValueError, "confirmation marker"):
                    MODULE.inventory(self.seeds, self.digest, 1)

    def test_tc_inv_04_invisible_character_in_digest_index_is_rejected(self):
        self.digest.write_text(f"## 対象エントリ\n\n- {SEED_A}​\n", encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "seed identity format"):
            MODULE.inventory(self.seeds, self.digest, 1)

    def test_tc_neg_01_ordinary_names_are_accepted(self):
        for value in ("naoki", "nobu", "masatake.komine（「confirm」指示にて）"):
            with self.subTest(value=value):
                self.seeds.write_text(f"## {SEED_A}\n- confirmed_by: {value}\n", encoding="utf-8")
                self.assertEqual(self.count(), 1)

    def test_tc_neg_02_negative_with_separator_is_rejected(self):
        for value in ("no, later", "no　後で", "no\t後で"):
            with self.subTest(value=value):
                self.seeds.write_text(f"## {SEED_A}\n- confirmed_by: {value}\n", encoding="utf-8")
                with self.assertRaisesRegex(ValueError, "confirmation marker"):
                    MODULE.inventory(self.seeds, self.digest, 1)

    def test_nested_confirmation_does_not_hide_a_second_marker(self):
        self.seeds.write_text(f"## {SEED_A}\n- confirmed_by: human\n  - confirmed_by: no\n", encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "confirmation marker"):
            MODULE.inventory(self.seeds, self.digest, 1)

    def test_digest_section_rejects_non_list_blocks(self):
        self.digest.write_text(f"## 対象エントリ\n\n- {SEED_A}\n<!--\n- 2026-06-09 — ghost\n-->\n", encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "unrecognized record"):
            MODULE.inventory(self.seeds, self.digest, 1)

    def test_tc_struct_01_no_whole_document_regex(self):
        source = SOURCE.read_text(encoding="utf-8")
        self.assertIn("re.compile", source)  # positive control: the probe reads the real module
        for forbidden in ("re.MULTILINE", "re.DOTALL", "(?m)", "(?s)", "finditer"):
            self.assertNotIn(forbidden, source)

    def test_tc_struct_02_imports_are_standard_library(self):
        import ast
        import sys
        tree = ast.parse(SOURCE.read_text(encoding="utf-8"))
        names = {a.name.split(".")[0] for n in ast.walk(tree) if isinstance(n, ast.Import) for a in n.names}
        names |= {n.module.split(".")[0] for n in ast.walk(tree) if isinstance(n, ast.ImportFrom) and n.module}
        self.assertTrue(names)
        self.assertEqual(names - set(sys.stdlib_module_names), set())


if __name__ == "__main__":
    unittest.main()
