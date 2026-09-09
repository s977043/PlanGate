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

__doc__ = """corpus_hash.py の単体テスト（#1299）。

要点は positive control と **対照** の対で置くこと:
scripts/hooks/ を 1 バイト変えたとき、新定義（full）では hash が変わり、
#1299 以前の定義（carve-out のみ）では変わらないことを同じ probe で示す。
片値だけを見て「効いた」と書けないようにする。
"""

import os
import re
import shutil
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import corpus_hash  # noqa: E402
import run_evidence  # noqa: E402

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SHA256_RE = re.compile(r"^sha256:[0-9a-f]{64}$")


def _make_fixture_root():
    """最小の擬似 repo を作る（carve-out 側 1 件 + enforcement 側 1 件）。"""
    root = tempfile.mkdtemp(prefix="pg-corpus-hash-")
    os.makedirs(os.path.join(root, "scripts", "ai-loop"))
    os.makedirs(os.path.join(root, "scripts", "hooks"))
    with open(os.path.join(root, "scripts", "ai-loop", "engine.py"), "w") as fh:
        fh.write("engine v1\n")
    with open(os.path.join(root, "scripts", "hooks", "check-plan-hash.sh"), "w") as fh:
        fh.write("#!/bin/sh\nexit 0\n")
    return root


class CorpusHashTest(unittest.TestCase):
    def setUp(self):
        self.root = _make_fixture_root()
        self.addCleanup(shutil.rmtree, self.root, True)

    # --- TC-01: 形式と決定論 ------------------------------------------------
    def test_tc01_format_and_determinism(self):
        first = corpus_hash.compute(self.root)
        self.assertRegex(first, SHA256_RE)
        self.assertEqual(first, corpus_hash.compute(self.root), "同一入力で値が揺れる")

    def test_tc01c_same_content_in_another_directory_is_same_hash(self):
        """**別ディレクトリに同じ内容を置いたら同じ hash**（#1311 レビュー D-1）。

        TC-01 は同一 root を 2 回計算するだけなので、`__pycache__` のような
        「実行するたびに増える生成物」を corpus に取り込む欠陥を原理的に検出できない。
        実測では同一 commit の 2 clone で値が違っていた（`.pyc` は mtime を埋め込む）。
        """
        other = _make_fixture_root()
        self.addCleanup(shutil.rmtree, other, True)
        self.assertEqual(
            corpus_hash.compute(self.root),
            corpus_hash.compute(other),
            "同じ内容でもディレクトリが違うと hash が変わる（絶対パス混入か生成物の取り込み）",
        )

    def test_tc01d_generated_caches_do_not_move_the_hash(self):
        """`__pycache__` / `*.pyc` を置いても hash が動かないこと（D-1 の positive control）。

        producer 自身が import で `.pyc` を作るため、除外しないと
        **初回実行の時点で自分の生成物が自分の corpus に入る**。
        """
        before = corpus_hash.compute(self.root)
        cache = os.path.join(self.root, "scripts", "ai-loop", "__pycache__")
        os.makedirs(cache, exist_ok=True)
        with open(os.path.join(cache, "engine.cpython-314.pyc"), "wb") as fh:
            fh.write(b"\x00\x01mtime-dependent-garbage")
        self.assertEqual(
            before,
            corpus_hash.compute(self.root),
            "__pycache__ の中身が corpus_hash を動かしている",
        )
        # 対照: 除外していない通常ファイルなら動く（検査が空振りでないこと）
        with open(os.path.join(self.root, "scripts", "ai-loop", "extra.py"), "w") as fh:
            fh.write("x\n")
        self.assertNotEqual(
            before,
            corpus_hash.compute(self.root),
            "通常ファイルの追加でも hash が動かない = 走査そのものが空振り",
        )

    def test_tc01b_accepted_by_run_evidence_validator(self):
        """run_evidence.py の受理 pattern（契約 §4-1）に通ること。"""
        self.assertTrue(run_evidence._SHA256.fullmatch(corpus_hash.compute(self.root)))

    # --- TC-02 / TC-03: positive control と対照 -----------------------------
    def test_tc02_hook_change_moves_full_hash(self):
        before = corpus_hash.compute(self.root, "full")
        hook = os.path.join(self.root, "scripts", "hooks", "check-plan-hash.sh")
        with open(hook, "a") as fh:
            fh.write("#")  # 1 バイト
        self.assertNotEqual(before, corpus_hash.compute(self.root, "full"),
                            "enforcement 層の変更が full corpus_hash に現れない（#1299 再発）")

    def test_tc03_control_old_scope_is_blind_to_hook_change(self):
        """対照: #1299 以前の定義（carve-out のみ）では同じ変更で hash が動かない。"""
        before = corpus_hash.compute(self.root, "carve-out")
        hook = os.path.join(self.root, "scripts", "hooks", "check-plan-hash.sh")
        with open(hook, "a") as fh:
            fh.write("#")
        self.assertEqual(before, corpus_hash.compute(self.root, "carve-out"),
                         "対照が成立していない（carve-out が hook を含んでしまっている）")

    def test_tc03b_carve_out_change_still_moves_full_hash(self):
        """enforcement 追加で従来の対象範囲を壊していないこと（回帰）。"""
        before = corpus_hash.compute(self.root, "full")
        with open(os.path.join(self.root, "scripts", "ai-loop", "engine.py"), "a") as fh:
            fh.write("#")
        self.assertNotEqual(before, corpus_hash.compute(self.root, "full"))

    # --- TC-04: scope の集合関係 -------------------------------------------
    def test_tc04_full_is_union_of_both_scopes(self):
        full = set(corpus_hash.collect(REPO_ROOT, "full"))
        carve = set(corpus_hash.collect(REPO_ROOT, "carve-out"))
        enf = set(corpus_hash.collect(REPO_ROOT, "enforcement"))
        self.assertEqual(full, carve | enf, "full が和集合になっていない")
        self.assertEqual(carve & enf, set(), "carve-out と enforcement が重複している")

    def test_tc04b_enforcement_covers_hooks_dir(self):
        """空 glob で貫通しないこと（実 repo で 1 件以上・hook 本体を含む）。"""
        enf = corpus_hash.collect(REPO_ROOT, "enforcement")
        hooks = [p for p in enf if p.startswith("scripts/hooks/")]
        self.assertGreater(len(hooks), 0, "scripts/hooks/** が 0 件（glob 空振り）")
        self.assertIn("scripts/hooks/check-plan-hash.sh", enf)
        self.assertIn("scripts/check-approval-token-write.sh", enf)

    # --- TC-05: fail-closed -------------------------------------------------
    def test_tc05_empty_corpus_is_fail_closed(self):
        empty = tempfile.mkdtemp(prefix="pg-corpus-hash-empty-")
        self.addCleanup(shutil.rmtree, empty, True)
        with self.assertRaises(ValueError):
            corpus_hash.compute(empty)
        self.assertEqual(corpus_hash.main(["--root", empty]), 2)

    # --- TC-06: 非対称の明示 ------------------------------------------------
    def test_tc06_exclusions_are_documented(self):
        keys = " ".join(corpus_hash.EXCLUSIONS)
        self.assertIn(".claude/settings.json", keys)
        self.assertIn(".github/workflows/**", keys)
        for name, reason in corpus_hash.EXCLUSIONS.items():
            self.assertTrue(reason.strip(), "%s の除外理由が空" % name)

    # --- TC-07: CLI ---------------------------------------------------------
    def test_tc07_cli_scopes_exit_zero(self):
        for scope in ("full", "carve-out", "enforcement"):
            self.assertEqual(corpus_hash.main(["--root", REPO_ROOT, "--scope", scope]), 0)


if __name__ == "__main__":
    unittest.main(verbosity=1)
