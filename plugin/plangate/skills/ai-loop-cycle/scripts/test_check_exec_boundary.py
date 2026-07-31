#!/usr/bin/env python3
"""test_check_exec_boundary.py — check_exec_boundary.py（AST 実行境界検査器）の unittest。

実行: python3 scripts/ai-loop/test_check_exec_boundary.py

契約正本: docs/working/TASK-0917/plan.md「D2-A の設計詳細」+
「`test_*.py` の argv 先頭要素 不変条件（精緻化 / C-1 F-1 の裁定）」
カバー: test-cases.md TC-31（AST 境界検査）/ TC-31b（grandfather 例外リストの凍結）/
TC-31c（import 形の解決・別名/直接 import の変異注入）

設計上の注意:
- 違反注入は **一時文字列を検査関数へ渡す**形で行い、作業ツリーのファイルは書き換えない
- substring 走査は使わない（`discovery.py` の docstring に "subprocess" の禁止宣言文が
  実在するため、grep 方式だと偽陽性になる。本テストはその偽陽性が出ないことも固定する）
"""

from __future__ import annotations

import ast
import pathlib
import subprocess
import sys
import unittest

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import check_exec_boundary as ceb  # noqa: E402

SCRIPT = HERE / "check_exec_boundary.py"

# TC-31b: 凍結されるべき唯一の grandfather 例外（ファイル名 + 関数名で特定）。
EXPECTED_GRANDFATHER = ("test_c3prime_verify.py", "_run")


# ---------------------------------------------------------------------------
# ヘルパ（テスト側の検出力実証用）
# ---------------------------------------------------------------------------

def _codes(violations):
    return sorted(v.code for v in violations)


def _freeze_grandfather(entries) -> None:
    """例外リストが 1 件から増えていないことを検査する（TC-31b の本体）。

    件数固定のアサートを含むのが要点。件数を見ない弱い版（`_weak_freeze_grandfather`）
    では 2 件目の追加を検出できないことを別テストで実証する。
    """
    if len(entries) != 1:
        raise AssertionError(f"grandfather 例外リストは 1 件固定: {list(entries)}")
    if tuple(entries[0]) != EXPECTED_GRANDFATHER:
        raise AssertionError(f"grandfather 例外の内容が想定外: {entries[0]}")


def _weak_freeze_grandfather(entries) -> None:
    """棄却された弱い検査（メンバーシップのみ・件数を見ない）。TC-31b の変異注入用。"""
    if EXPECTED_GRANDFATHER not in {tuple(e) for e in entries}:
        raise AssertionError("grandfather 例外に既知エントリが無い")


def _naive_attribute_only_calls(source: str):
    """棄却された素朴実装: `ast.Attribute(value=Name('subprocess'))` だけを見る走査。

    TC-31c の検出力実証に使う。import 形の解決を外すとこの実装に退化し、
    別名 import / 直接 import が **すべてすり抜ける**ことを固定する。
    """
    found = []
    for node in ast.walk(ast.parse(source)):
        if (isinstance(node, ast.Call)
                and isinstance(node.func, ast.Attribute)
                and isinstance(node.func.value, ast.Name)
                and node.func.value.id == "subprocess"
                and node.func.attr in ("run", "check_output", "Popen",
                                       "call", "check_call")):
            found.append(node)
    return found


# 変異注入テンプレート（TC-31c）: import 形の 3 バリエーション。
ALIAS_FORMS = {
    "import-as": (
        "import subprocess as sp\n"
        "def t():\n"
        "    sp.run([\"python3\", \"x.py\"])\n"
    ),
    "from-import": (
        "from subprocess import run\n"
        "def t():\n"
        "    run([\"python3\", \"x.py\"])\n"
    ),
    "from-import-as": (
        "from subprocess import check_output as co\n"
        "def t():\n"
        "    co([\"python3\", \"x.py\"])\n"
    ),
}


# ---------------------------------------------------------------------------
# TC-31 ①: 現行ツリーが clean（substring 走査を使っていないこと含む）
# ---------------------------------------------------------------------------

class CurrentTreeCleanTests(unittest.TestCase):
    def test_tc31_current_tree_is_clean(self):
        violations = ceb.check_paths(ceb.default_targets())
        self.assertEqual(violations, [], f"現行ツリーに違反: {violations}")

    def test_tc31_cli_exits_zero_on_clean_tree(self):
        proc = subprocess.run([sys.executable, str(SCRIPT)],
                              capture_output=True, text=True)
        self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)

    def test_tc31_discovery_docstring_is_not_false_positive(self):
        source = (HERE / "discovery.py").read_text(encoding="utf-8")
        self.assertIn("subprocess", source, "前提: docstring に禁止宣言文が実在する")
        self.assertEqual(ceb.check_source("discovery.py", source), [])

    def test_tc31_delivery_substring_scan_source_is_untouched(self):
        """AC-7: `delivery.py` 系の既存 substring 走査を一字も変えていないこと。"""
        source = (HERE / "test_delivery.py").read_text(encoding="utf-8")
        self.assertIn("test_tc18_pure_verdict_source", source)
        self.assertEqual(ceb.check_source("test_delivery.py", source), [])


# ---------------------------------------------------------------------------
# TC-31 ②: gh_exec.py 以外のモジュールで実行系トークンを検出
# ---------------------------------------------------------------------------

class ExecTokenDetectionTests(unittest.TestCase):
    CASES = {
        "subprocess": "import subprocess\n",
        "subprocess-as": "import subprocess as sp\n",
        "subprocess-from": "from subprocess import run\n",
        "os.system": "import os\ndef f():\n    os.system(\"gh pr merge 1\")\n",
        "os.popen": "import os\ndef f():\n    os.popen(\"gh pr merge 1\")\n",
        "os.execv": "import os\ndef f():\n    os.execv(\"/bin/sh\", [\"sh\"])\n",
        "os.spawnl": "import os\ndef f():\n    os.spawnl(0, \"/bin/sh\")\n",
        "os-from-system": "from os import system\n",
        "urllib": "import urllib.request\n",
        "urllib-from": "from urllib import request\n",
        "socket": "import socket\n",
        "http.client": "import http.client\n",
        "http-from-client": "from http import client\n",
        "requests": "import requests\n",
        "importlib.import_module": (
            "import importlib\ndef f():\n    importlib.import_module(\"subprocess\")\n"),
        "import_module-from": "from importlib import import_module\n",
        "dunder-import": "def f():\n    return __import__(\"subprocess\")\n",
    }

    def test_tc31_exec_tokens_flagged_in_ordinary_module(self):
        for label, source in self.CASES.items():
            with self.subTest(token=label):
                violations = ceb.check_source("collector.py", source)
                self.assertTrue(violations, f"{label} が検出されなかった")
                self.assertIn(ceb.CODE_EXEC_TOKEN, _codes(violations))

    def test_tc31_clean_module_has_no_violation(self):
        source = "import json\nimport pathlib\n\n\ndef f(x):\n    return json.dumps(x)\n"
        self.assertEqual(ceb.check_source("collector.py", source), [])

    def test_tc31_string_literal_mentioning_subprocess_is_not_flagged(self):
        source = ('"""禁止: subprocess での gh 呼び出し / os.system / urllib。"""\n'
                  "TOKENS = (\"subprocess\", \"os.system\", \"urllib\", \"socket\")\n")
        self.assertEqual(ceb.check_source("collector.py", source), [])


# ---------------------------------------------------------------------------
# TC-31 ④: gh_exec.py は「除外」ではなく逆向きホワイトリスト検査
# ---------------------------------------------------------------------------

class GhExecReverseWhitelistTests(unittest.TestCase):
    def test_tc31_gh_exec_allows_subprocess(self):
        source = ("import subprocess\n"
                  "def run_gh(argv):\n"
                  "    return subprocess.run(argv, capture_output=True, text=True)\n")
        self.assertEqual(ceb.check_source("gh_exec.py", source), [])

    def test_tc31_gh_exec_rejects_os_system(self):
        source = "import os\ndef f():\n    os.system(\"gh pr merge 1\")\n"
        violations = ceb.check_source("gh_exec.py", source)
        self.assertTrue(violations, "gh_exec.py 内の os.system が素通りした")
        self.assertIn(ceb.CODE_GH_EXEC_EXTRA_TOKEN, _codes(violations))

    def test_tc31_gh_exec_rejects_other_exec_tokens(self):
        for label, source in (("urllib", "import urllib.request\n"),
                              ("socket", "import socket\n"),
                              ("requests", "import requests\n"),
                              ("http.client", "import http.client\n"),
                              ("os.popen", "import os\ndef f():\n    os.popen(\"x\")\n")):
            with self.subTest(token=label):
                violations = ceb.check_source("gh_exec.py", source)
                self.assertIn(ceb.CODE_GH_EXEC_EXTRA_TOKEN, _codes(violations))

    def test_tc31_gh_exec_is_not_excluded_from_scanning(self):
        """除外実装への退化検出: gh_exec.py を対象外にすると本テストが空振りする。"""
        self.assertNotEqual(ceb.check_source("gh_exec.py", "import socket\n"), [])


# ---------------------------------------------------------------------------
# TC-31 ③⑤: test_*.py の argv 先頭要素 不変条件（精緻化版）
# ---------------------------------------------------------------------------

class ArgvHeadInvariantTests(unittest.TestCase):
    def test_tc31_sys_executable_head_is_allowed(self):
        source = ("import subprocess\nimport sys\n"
                  "def t():\n"
                  "    subprocess.run([sys.executable, \"x.py\"], capture_output=True)\n")
        self.assertEqual(ceb.check_source("test_x.py", source), [])

    def test_tc31_readonly_git_subcommands_are_allowed(self):
        for sub in sorted(ceb.GIT_READONLY_SUBCOMMANDS):
            with self.subTest(sub=sub):
                source = ("import subprocess\n"
                          "def t():\n"
                          f"    subprocess.check_output([\"git\", \"{sub}\", \"--x\"])\n")
                self.assertEqual(ceb.check_source("test_x.py", source), [])

    def test_tc31_write_git_subcommands_are_flagged(self):
        for sub in ("push", "commit", "checkout", "reset", "branch", "stash"):
            with self.subTest(sub=sub):
                source = ("import subprocess\n"
                          "def t():\n"
                          f"    subprocess.run([\"git\", \"{sub}\", \"-f\"])\n")
                violations = ceb.check_source("test_x.py", source)
                self.assertIn(ceb.CODE_ARGV_HEAD, _codes(violations))

    def test_tc31_bare_git_without_subcommand_is_flagged(self):
        source = ("import subprocess\n"
                  "def t():\n"
                  "    subprocess.run([\"git\"])\n")
        self.assertIn(ceb.CODE_ARGV_HEAD, _codes(ceb.check_source("test_x.py", source)))

    def test_tc31_python3_literal_head_is_flagged(self):
        source = ("import subprocess\n"
                  "def t():\n"
                  "    subprocess.run([\"python3\", \"x.py\"])\n")
        self.assertIn(ceb.CODE_ARGV_HEAD, _codes(ceb.check_source("test_x.py", source)))

    def test_tc31_all_subprocess_entry_points_are_checked(self):
        for fn in sorted(ceb.SUBPROCESS_ENTRY_POINTS):
            with self.subTest(entry_point=fn):
                source = ("import subprocess\n"
                          "def t():\n"
                          f"    subprocess.{fn}([\"python3\", \"x.py\"])\n")
                self.assertIn(ceb.CODE_ARGV_HEAD,
                              _codes(ceb.check_source("test_x.py", source)))

    def test_tc31_unresolvable_argv_is_fail_closed(self):
        source = ("import subprocess\n"
                  "def t(args):\n"
                  "    return subprocess.run(args, capture_output=True)\n")
        self.assertIn(ceb.CODE_ARGV_UNRESOLVED,
                      _codes(ceb.check_source("test_x.py", source)))

    def test_tc31_argv_built_by_call_is_fail_closed(self):
        source = ("import subprocess\n"
                  "def t(base):\n"
                  "    subprocess.run(list(base) + [\"x\"])\n")
        self.assertTrue(ceb.check_source("test_x.py", source))

    def test_tc31_star_import_is_fail_closed(self):
        source = "from subprocess import *\n"
        self.assertIn(ceb.CODE_IMPORT_UNRESOLVED,
                      _codes(ceb.check_source("test_x.py", source)))

    def test_tc31_invariant_applies_only_to_test_modules(self):
        """モジュール側は argv 以前に EXEC_TOKEN で落ちる（迂回路を作らない）。"""
        source = ("import subprocess\nimport sys\n"
                  "def t():\n"
                  "    subprocess.run([sys.executable, \"x.py\"])\n")
        self.assertIn(ceb.CODE_EXEC_TOKEN, _codes(ceb.check_source("collector.py", source)))

    def test_tc31_test_modules_may_use_subprocess_only(self):
        """test_*.py は subprocess のみ許可。他の実行系トークンは迂回路にさせない。"""
        for label, source in (("socket", "import socket\n"),
                              ("requests", "import requests\n"),
                              ("urllib", "import urllib.request\n"),
                              ("os.system",
                               "import os\ndef t():\n    os.system(\"gh pr merge 1\")\n")):
            with self.subTest(token=label):
                self.assertIn(ceb.CODE_EXEC_TOKEN,
                              _codes(ceb.check_source("test_x.py", source)))

    def test_tc31_real_test_discovery_git_status_is_permanently_allowed(self):
        source = (HERE / "test_discovery.py").read_text(encoding="utf-8")
        self.assertEqual(source.count('["git", "status", "--porcelain"]'), 2)
        self.assertEqual(ceb.check_source("test_discovery.py", source), [])

    def test_tc31_real_test_c3prime_verify_is_clean_via_grandfather(self):
        source = (HERE / "test_c3prime_verify.py").read_text(encoding="utf-8")
        self.assertEqual(ceb.check_source("test_c3prime_verify.py", source), [])
        # grandfather を外すと違反として現れる（例外リストが load-bearing である証明）
        self.assertTrue(ceb.check_source("test_c3prime_verify.py", source,
                                         grandfather=()))


# ---------------------------------------------------------------------------
# TC-31b: grandfather 例外リストが 1 件から増えないことの固定
# ---------------------------------------------------------------------------

class GrandfatherFrozenTests(unittest.TestCase):
    def test_tc31b_exception_list_is_exactly_one_entry(self):
        _freeze_grandfather(ceb.GRANDFATHER_ARGV_EXCEPTIONS)
        self.assertEqual(len(ceb.GRANDFATHER_ARGV_EXCEPTIONS), 1)
        self.assertEqual(tuple(ceb.GRANDFATHER_ARGV_EXCEPTIONS[0]), EXPECTED_GRANDFATHER)

    def test_tc31b_second_entry_breaks_the_freeze(self):
        """変異注入: 2 件目を足すと本 TC が FAIL する（= 増加が機械的にブロックされる）。"""
        mutated = list(ceb.GRANDFATHER_ARGV_EXCEPTIONS) + [("test_collector.py", "_run")]
        with self.assertRaises(AssertionError):
            _freeze_grandfather(mutated)

    def test_tc31b_weakened_freeze_check_is_vacuous(self):
        """件数アサートを外した弱い版では 2 件目の追加を検出できない（検出力の実証）。"""
        mutated = list(ceb.GRANDFATHER_ARGV_EXCEPTIONS) + [("test_collector.py", "_run")]
        _weak_freeze_grandfather(mutated)  # 例外にならない = 空振りする

    def test_tc31b_extra_entry_would_suppress_a_real_violation(self):
        """例外リストの増加が「違反の隠蔽」に直結することを固定する。"""
        source = ("import subprocess\n"
                  "def _run(args):\n"
                  "    return subprocess.run(args)\n")
        self.assertTrue(ceb.check_source("test_collector.py", source))
        self.assertEqual(
            ceb.check_source("test_collector.py", source,
                             grandfather=(("test_collector.py", "_run"),)),
            [])

    def test_tc31b_grandfather_is_scoped_to_file_and_function(self):
        source = ("import subprocess\n"
                  "def _run(args):\n"
                  "    return subprocess.run(args)\n"
                  "def other(args):\n"
                  "    return subprocess.run(args)\n")
        violations = ceb.check_source(
            "test_collector.py", source,
            grandfather=(("test_collector.py", "_run"),))
        self.assertEqual(len(violations), 1, violations)
        # 別ファイルでは同名関数でも例外にならない
        self.assertTrue(ceb.check_source(
            "test_other.py", source, grandfather=(("test_collector.py", "_run"),)))


# ---------------------------------------------------------------------------
# TC-31c: import 形の解決（別名 / 直接 import の変異注入）
# ---------------------------------------------------------------------------

class ImportFormResolutionTests(unittest.TestCase):
    def test_tc31c_alias_forms_are_all_flagged(self):
        for label, source in ALIAS_FORMS.items():
            with self.subTest(form=label):
                violations = ceb.check_source("test_x.py", source)
                self.assertIn(ceb.CODE_ARGV_HEAD, _codes(violations),
                              f"{label} がすり抜けた: {violations}")

    def test_tc31c_naive_attribute_only_scan_misses_all_three(self):
        """検出力の実証: import 解決を外すと 3 形とも clean になってしまう。"""
        for label, source in ALIAS_FORMS.items():
            with self.subTest(form=label):
                self.assertEqual(_naive_attribute_only_calls(source), [],
                                 f"{label} は素朴実装では検出されないはず")

    def test_tc31c_naive_scan_does_detect_plain_attribute_form(self):
        """素朴実装が「何も検出しない壊れた関数」ではないことの対照実験。"""
        plain = ("import subprocess\n"
                 "def t():\n"
                 "    subprocess.run([\"python3\", \"x.py\"])\n")
        self.assertEqual(len(_naive_attribute_only_calls(plain)), 1)

    def test_tc31c_alias_positive_case_passes(self):
        source = ("import subprocess as sp\nimport sys\n"
                  "def t():\n"
                  "    sp.run([sys.executable, \"x.py\"], capture_output=True)\n")
        self.assertEqual(ceb.check_source("test_x.py", source), [])

    def test_tc31c_direct_import_positive_case_passes(self):
        source = ("from subprocess import run, check_output\nimport sys\n"
                  "def t():\n"
                  "    run([sys.executable, \"x.py\"])\n"
                  "    check_output([\"git\", \"status\", \"--porcelain\"])\n")
        self.assertEqual(ceb.check_source("test_x.py", source), [])

    def test_tc31c_alias_forms_in_ordinary_module_are_exec_token_violations(self):
        for label, source in ALIAS_FORMS.items():
            with self.subTest(form=label):
                self.assertIn(ceb.CODE_EXEC_TOKEN,
                              _codes(ceb.check_source("collector.py", source)))


# ---------------------------------------------------------------------------
# CLI 契約
# ---------------------------------------------------------------------------

class CliTests(unittest.TestCase):
    def test_cli_reports_violations_and_exits_nonzero(self):
        import tempfile
        with tempfile.TemporaryDirectory() as tmp:
            target = pathlib.Path(tmp) / "collector.py"
            target.write_text("import socket\n", encoding="utf-8")
            proc = subprocess.run(
                [sys.executable, str(SCRIPT), "--dir", tmp],
                capture_output=True, text=True)
            self.assertNotEqual(proc.returncode, 0)
            self.assertIn("collector.py", proc.stdout + proc.stderr)

    def test_cli_clean_dir_exits_zero(self):
        import tempfile
        with tempfile.TemporaryDirectory() as tmp:
            (pathlib.Path(tmp) / "collector.py").write_text("import json\n",
                                                            encoding="utf-8")
            proc = subprocess.run(
                [sys.executable, str(SCRIPT), "--dir", tmp],
                capture_output=True, text=True)
            self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)

    def test_syntax_error_is_fail_closed(self):
        self.assertIn(ceb.CODE_SYNTAX,
                      _codes(ceb.check_source("collector.py", "def broken(:\n")))


if __name__ == "__main__":
    unittest.main(verbosity=2)
