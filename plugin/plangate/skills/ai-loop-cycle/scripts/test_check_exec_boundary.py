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
import contextlib
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
        """`subprocess` 自体は許可。ただし R1-A-4 の構造規律
        （`_spawn()` 経由 / 監査済み入口からの呼び出し）を満たす形であること。"""
        source = ("import subprocess\n"
                  "def _spawn(argv):\n"
                  "    return subprocess.run(argv, capture_output=True, text=True)\n"
                  "def run_gh(argv):\n"
                  "    return _spawn(argv)\n")
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
# R1-A-1〜A-4: 敵対レビュー R1 で実測されたすり抜けの回帰固定
# ---------------------------------------------------------------------------

@contextlib.contextmanager
def _patched(**attrs):
    """`check_exec_boundary` のモジュール属性を一時差し替えする（変異注入用）。

    「検査を外すと元のすり抜けが復活する」ことを実証するために使う。
    作業ツリーのファイルは 1 バイトも書き換えない。

    退避に `getattr(ceb, key)` を使わないのは、本ファイル自身が検査対象であり
    **属性名が変数の `getattr` は fail-closed で violation** になるため（R1-A-1）。
    """
    saved = {key: ceb.__dict__[key] for key in attrs}
    try:
        for key, value in attrs.items():
            setattr(ceb, key, value)
        yield
    finally:
        for key, value in saved.items():
            setattr(ceb, key, value)


#: R1 で「MISS（すり抜け）」と実測された再現コード。すべて DETECTED になること。
R1_REPRODUCTIONS = {
    # A-1: 動的属性アクセス
    "A-1/getattr-literal": (
        "collector.py",
        "import os\ndef x(cmd):\n    getattr(os, \"system\")(cmd)\n"),
    "A-1/getattr-concat": (
        "collector.py",
        "import os\ndef x(cmd):\n    getattr(os, \"sys\" + \"tem\")(cmd)\n"),
    # A-2: 動的コード生成
    "A-2/exec": (
        "collector.py",
        "def x(cmd):\n    exec(\"import os; os.system(cmd)\")\n"),
    "A-2/eval": ("collector.py", "def x(cmd):\n    eval(cmd)\n"),
    "A-2/compile": ("collector.py", "def x(cmd):\n    compile(cmd, \"<s>\", \"exec\")\n"),
    # A-3: 難読化なしの直書き
    "A-3/pty": (
        "collector.py",
        "import pty\ndef x():\n    pty.spawn([\"gh\",\"pr\",\"merge\",\"1\"])\n"),
    "A-3/ctypes": (
        "collector.py",
        "import ctypes\ndef x(c):\n    ctypes.CDLL(\"libc\").system(c)\n"),
    "A-3/os.posix_spawn": (
        "collector.py",
        "import os\ndef x():\n    os.posix_spawn(\"/bin/sh\", [], os.environ)\n"),
    "A-3/multiprocessing": ("collector.py", "import multiprocessing\n"),
    "A-3/asyncio-exec": (
        "collector.py",
        "import asyncio\nasync def x():\n"
        "    await asyncio.create_subprocess_exec(\"gh\", \"pr\", \"merge\", \"1\")\n"),
    "A-3/asyncio-shell": (
        "collector.py",
        "import asyncio\nasync def x():\n"
        "    await asyncio.create_subprocess_shell(\"gh pr merge 1\")\n"),
    # A-4: 唯一の境界の内部
    "A-4/gh_exec-shell-true": (
        "gh_exec.py",
        "import subprocess\ndef rogue(cmd):\n"
        "    return subprocess.run(cmd, shell=True)\n"),
}


class R1ReproductionTests(unittest.TestCase):
    """R1 critical 4 件の再現コードが是正後に必ず検出されること。"""

    def test_all_r1_reproductions_are_detected(self):
        for label, (name, source) in R1_REPRODUCTIONS.items():
            with self.subTest(case=label):
                self.assertTrue(ceb.check_source(name, source),
                                f"{label} がすり抜けた")

    def test_current_tree_has_no_false_positive_after_hardening(self):
        """正側: 追加した検査で現行 26 ファイルに偽陽性が出ないこと。"""
        targets = ceb.default_targets()
        self.assertGreaterEqual(len(targets), 26)
        self.assertEqual(ceb.check_paths(targets), [])


class DynamicAttributeAccessTests(unittest.TestCase):
    """R1-A-1: `getattr` 経由の実行系トークン。"""

    def test_literal_attribute_is_resolved_as_token(self):
        source = "import os\ndef x(cmd):\n    getattr(os, \"system\")(cmd)\n"
        violations = ceb.check_source("collector.py", source)
        self.assertIn(ceb.CODE_EXEC_TOKEN, _codes(violations))
        self.assertIn("os.system", repr(violations))

    def test_non_literal_attribute_is_fail_closed(self):
        for label, expr in (("concat", "\"sys\" + \"tem\""),
                            ("variable", "name"),
                            ("fstring", "f\"sys{'tem'}\""),
                            ("join", "\"\".join([\"sys\", \"tem\"])")):
            with self.subTest(form=label):
                source = (f"import os\ndef x(cmd, name):\n"
                          f"    getattr(os, {expr})(cmd)\n")
                self.assertIn(ceb.CODE_DYNAMIC_UNRESOLVED,
                              _codes(ceb.check_source("collector.py", source)))

    def test_alias_import_is_resolved_too(self):
        source = "import os as o\ndef x(cmd):\n    getattr(o, \"system\")(cmd)\n"
        self.assertIn(ceb.CODE_EXEC_TOKEN,
                      _codes(ceb.check_source("collector.py", source)))

    def test_benign_literal_getattr_is_not_flagged(self):
        """偽陽性ガード: `getattr(proc, \"returncode\", 1)`（executor.py 実使用形）。"""
        source = ("def x(proc):\n"
                  "    return getattr(proc, \"returncode\", 1)\n")
        self.assertEqual(ceb.check_source("collector.py", source), [])

    def test_getattr_on_non_exec_module_attr_is_not_flagged(self):
        source = "import json\ndef x(v):\n    return getattr(json, \"dumps\")(v)\n"
        self.assertEqual(ceb.check_source("collector.py", source), [])

    def test_gh_exec_is_also_covered(self):
        source = "import os\ndef x(cmd):\n    getattr(os, \"system\")(cmd)\n"
        self.assertIn(ceb.CODE_GH_EXEC_EXTRA_TOKEN,
                      _codes(ceb.check_source("gh_exec.py", source)))

    def test_mutation_disabling_getattr_check_restores_the_hole(self):
        """変異注入: getattr 検出を外すと R1 の再現コードが両方すり抜ける。"""
        with _patched(DYNAMIC_ATTR_BUILTIN="__disabled__"):
            for label in ("A-1/getattr-literal", "A-1/getattr-concat"):
                name, source = R1_REPRODUCTIONS[label]
                self.assertEqual(ceb.check_source(name, source), [],
                                 f"{label} は変異後すり抜けるはず")
        for label in ("A-1/getattr-literal", "A-1/getattr-concat"):
            name, source = R1_REPRODUCTIONS[label]
            self.assertTrue(ceb.check_source(name, source))


class DynamicCodeGenerationTests(unittest.TestCase):
    """R1-A-2: `eval` / `exec` / `compile` は全モジュールで deny。"""

    def test_all_dynamic_builtins_are_flagged_everywhere(self):
        for builtin in ceb.DYNAMIC_CODE_BUILTINS:
            for module, code in (("collector.py", ceb.CODE_EXEC_TOKEN),
                                 ("gh_exec.py", ceb.CODE_GH_EXEC_EXTRA_TOKEN),
                                 ("test_x.py", ceb.CODE_EXEC_TOKEN)):
                with self.subTest(builtin=builtin, module=module):
                    source = f"def x(cmd):\n    {builtin}(cmd)\n"
                    self.assertIn(code, _codes(ceb.check_source(module, source)))

    def test_attribute_form_compile_is_not_a_false_positive(self):
        """`re.compile` は builtin `compile` ではない（gh_exec.py 実使用形）。"""
        source = "import re\nP = re.compile(r\"x\")\n"
        self.assertEqual(ceb.check_source("gh_exec.py", source), [])
        self.assertEqual(ceb.check_source("collector.py", source), [])

    def test_mutation_disabling_dynamic_builtins_restores_the_hole(self):
        with _patched(DYNAMIC_CODE_BUILTINS=()):
            name, source = R1_REPRODUCTIONS["A-2/exec"]
            self.assertEqual(ceb.check_source(name, source), [])
        self.assertTrue(ceb.check_source(*R1_REPRODUCTIONS["A-2/exec"]))


class DirectExecModuleTests(unittest.TestCase):
    """R1-A-3: 難読化なしの直書きで通っていたモジュール / 属性。"""

    #: 是正前の定数（変異注入用）。
    LEGACY_FORBIDDEN_ROOTS = ("urllib", "socket", "http", "requests")
    LEGACY_OS_EXEC_ATTRS = ("system", "popen")

    def test_new_forbidden_roots_are_flagged(self):
        for root in ("pty", "ctypes", "multiprocessing"):
            with self.subTest(root=root):
                self.assertIn(root, ceb.FORBIDDEN_MODULE_ROOTS)
                self.assertIn(ceb.CODE_EXEC_TOKEN,
                              _codes(ceb.check_source("collector.py",
                                                      f"import {root}\n")))
                self.assertIn(ceb.CODE_EXEC_TOKEN,
                              _codes(ceb.check_source("collector.py",
                                                      f"from {root} import spawn\n")))

    def test_os_posix_spawn_family_is_flagged(self):
        for attr in ("posix_spawn", "posix_spawnp", "forkpty"):
            with self.subTest(attr=attr):
                source = f"import os\ndef x():\n    os.{attr}(\"/bin/sh\", [], {{}})\n"
                self.assertIn(ceb.CODE_EXEC_TOKEN,
                              _codes(ceb.check_source("collector.py", source)))

    def test_os_prefix_family_still_flagged(self):
        """既存の prefix 判定（exec* / spawn*）を壊していないこと。"""
        for attr in ("execv", "execve", "spawnl", "spawnvp"):
            with self.subTest(attr=attr):
                source = f"import os\ndef x():\n    os.{attr}(\"/bin/sh\")\n"
                self.assertIn(ceb.CODE_EXEC_TOKEN,
                              _codes(ceb.check_source("collector.py", source)))

    def test_benign_os_attributes_are_not_flagged(self):
        for attr in ("environ", "path", "getcwd", "sep"):
            with self.subTest(attr=attr):
                self.assertEqual(
                    ceb.check_source("collector.py",
                                     f"import os\nV = os.{attr}\n"), [])

    def test_asyncio_subprocess_helpers_are_flagged(self):
        for attr in ceb.ASYNCIO_EXEC_ATTRS:
            with self.subTest(attr=attr):
                source = f"import asyncio\nasync def x():\n    await asyncio.{attr}(\"x\")\n"
                self.assertIn(ceb.CODE_EXEC_TOKEN,
                              _codes(ceb.check_source("collector.py", source)))
                self.assertIn(ceb.CODE_EXEC_TOKEN,
                              _codes(ceb.check_source(
                                  "collector.py", f"from asyncio import {attr}\n")))

    def test_benign_asyncio_usage_is_not_flagged(self):
        source = "import asyncio\ndef x(c):\n    return asyncio.run(c)\n"
        self.assertEqual(ceb.check_source("collector.py", source), [])

    def test_mutation_legacy_constants_restore_all_three_holes(self):
        """変異注入: 是正前の定数へ戻すと A-3 の 5 形すべてがすり抜ける。"""
        labels = ("A-3/pty", "A-3/ctypes", "A-3/os.posix_spawn",
                  "A-3/multiprocessing", "A-3/asyncio-shell")
        with _patched(FORBIDDEN_MODULE_ROOTS=self.LEGACY_FORBIDDEN_ROOTS,
                      OS_EXEC_ATTRS=self.LEGACY_OS_EXEC_ATTRS,
                      ASYNCIO_EXEC_ATTRS=()):
            for label in labels:
                with self.subTest(case=label, phase="mutated"):
                    self.assertEqual(ceb.check_source(*R1_REPRODUCTIONS[label]), [])
        for label in labels:
            with self.subTest(case=label, phase="fixed"):
                self.assertTrue(ceb.check_source(*R1_REPRODUCTIONS[label]))


class GhExecInternalDisciplineTests(unittest.TestCase):
    """R1-A-4: 「唯一の境界」の内部に無検査の抜け道を残さない。"""

    def test_real_gh_exec_passes_the_discipline(self):
        source = (HERE / "gh_exec.py").read_text(encoding="utf-8")
        self.assertEqual(ceb.check_source("gh_exec.py", source), [])

    def test_shell_true_is_flagged(self):
        source = ("import subprocess\ndef _spawn(cmd):\n"
                  "    return subprocess.run(cmd, shell=True)\n")
        self.assertIn(ceb.CODE_GH_EXEC_SHELL,
                      _codes(ceb.check_source("gh_exec.py", source)))

    def test_non_literal_shell_value_is_fail_closed(self):
        source = ("import subprocess\nS = False\ndef _spawn(cmd):\n"
                  "    return subprocess.run(cmd, shell=S)\n"
                  "def run_gh(a):\n    return _spawn(a)\n")
        self.assertIn(ceb.CODE_GH_EXEC_SHELL,
                      _codes(ceb.check_source("gh_exec.py", source)))

    def test_kwargs_expansion_is_fail_closed(self):
        source = ("import subprocess\ndef _spawn(cmd, **kw):\n"
                  "    return subprocess.run(cmd, **kw)\n"
                  "def run_gh(a):\n    return _spawn(a)\n")
        self.assertIn(ceb.CODE_GH_EXEC_SHELL,
                      _codes(ceb.check_source("gh_exec.py", source)))

    def test_shell_false_literal_is_allowed(self):
        source = ("import subprocess\ndef _spawn(cmd):\n"
                  "    return subprocess.run(cmd, shell=False)\n"
                  "def run_gh(a):\n    return _spawn(a)\n")
        self.assertEqual(ceb.check_source("gh_exec.py", source), [])

    def test_subprocess_call_outside_spawn_is_flagged(self):
        source = ("import subprocess\ndef rogue(cmd):\n"
                  "    return subprocess.run(cmd)\n")
        self.assertIn(ceb.CODE_GH_EXEC_SPAWN_SITE,
                      _codes(ceb.check_source("gh_exec.py", source)))

    def test_module_level_subprocess_call_is_flagged(self):
        source = "import subprocess\nR = subprocess.run([\"gh\", \"pr\", \"merge\"])\n"
        self.assertIn(ceb.CODE_GH_EXEC_SPAWN_SITE,
                      _codes(ceb.check_source("gh_exec.py", source)))

    def test_unaudited_spawn_caller_is_flagged(self):
        source = ("import subprocess\ndef _spawn(a):\n"
                  "    return subprocess.run(a)\n"
                  "def rogue(a):\n    return _spawn(a)\n")
        self.assertIn(ceb.CODE_GH_EXEC_SPAWN_CALLER,
                      _codes(ceb.check_source("gh_exec.py", source)))

    def test_audited_spawn_callers_pass(self):
        for caller in ceb.GH_EXEC_SPAWN_CALLERS:
            with self.subTest(caller=caller):
                source = ("import subprocess\ndef _spawn(a):\n"
                          "    return subprocess.run(a)\n"
                          f"def {caller}(a):\n    return _spawn(a)\n")
                self.assertEqual(ceb.check_source("gh_exec.py", source), [])

    def test_spawn_caller_set_is_frozen_at_three(self):
        """監査済み入口が 3 件から増えないことを固定する（grandfather と同型）。

        件数を見ない弱い検査では 4 件目の追加を検出できない（下の変異注入で実証）。
        """
        self.assertEqual(len(ceb.GH_EXEC_SPAWN_CALLERS), 3,
                         f"監査済み入口が増えている: {ceb.GH_EXEC_SPAWN_CALLERS}")
        self.assertEqual(tuple(ceb.GH_EXEC_SPAWN_CALLERS),
                         ("run_gh", "run_git", "push_pr_head"))

    def test_mutation_extra_spawn_caller_would_suppress_a_real_violation(self):
        source = ("import subprocess\ndef _spawn(a):\n"
                  "    return subprocess.run(a)\n"
                  "def rogue(a):\n    return _spawn(a)\n")
        self.assertTrue(ceb.check_source("gh_exec.py", source))
        with _patched(GH_EXEC_SPAWN_CALLERS=ceb.GH_EXEC_SPAWN_CALLERS + ("rogue",)):
            self.assertEqual(ceb.check_source("gh_exec.py", source), [])

    def test_mutation_word_only_reverse_whitelist_restores_the_hole(self):
        """変異注入: 是正前の「語の有無しか見ない」実装ではすり抜ける。"""
        name, source = R1_REPRODUCTIONS["A-4/gh_exec-shell-true"]
        with _patched(_gh_exec_discipline=lambda tree, binds, n: []):
            self.assertEqual(ceb.check_source(name, source), [])
        self.assertTrue(ceb.check_source(name, source))

    def test_discipline_does_not_apply_to_other_modules(self):
        """test_*.py の `subprocess.run` は argv 不変条件側で扱う（二重適用しない）。"""
        source = ("import subprocess\nimport sys\ndef helper():\n"
                  "    return subprocess.run([sys.executable, \"x.py\"])\n")
        self.assertEqual(ceb.check_source("test_x.py", source), [])


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
