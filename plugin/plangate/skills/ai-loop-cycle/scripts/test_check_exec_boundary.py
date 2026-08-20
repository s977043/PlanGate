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

__doc__ = """test_check_exec_boundary.py — check_exec_boundary.py（AST 実行境界検査器）の unittest。

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

import ast
import contextlib
import pathlib
import subprocess
import sys
import unittest
from unittest import mock

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

    退避 / 復元に `getattr(ceb, key)` も `ceb.__dict__[key]` も使わず
    `unittest.mock.patch.object` に委ねる。理由 = **本ファイル自身が検査対象**
    であり、属性名が変数の `getattr`（R1-A-1）も `__dict__` 添字（R2-a-2）も
    fail-closed で violation になるため。旧実装は後者で前者を迂回しており、
    それ自体が「検査器の穴を使って検査器を回避した」実例だった。
    """
    with contextlib.ExitStack() as stack:
        for key, value in attrs.items():
            stack.enter_context(mock.patch.object(ceb, key, value))
        yield


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
        """変異注入: 是正前の定数へ戻すと A-3 の 4 形がすり抜ける。

        `A-3/ctypes` だけは R2-a-2 で**独立した第 2 層**（基底が解決できない
        属性参照のうち実行系の名前 = `INDIRECT_EXEC_ATTRS`）にも掛かるように
        なったため、R1-A-3 の定数だけを戻しても落ちない。第 2 層も外すと
        すり抜けることを次のテストで別途固定する（層の独立性の実証）。
        """
        labels = ("A-3/pty", "A-3/os.posix_spawn",
                  "A-3/multiprocessing", "A-3/asyncio-shell")
        with _patched(FORBIDDEN_MODULE_ROOTS=self.LEGACY_FORBIDDEN_ROOTS,
                      OS_EXEC_ATTRS=self.LEGACY_OS_EXEC_ATTRS,
                      ASYNCIO_EXEC_ATTRS=()):
            for label in labels:
                with self.subTest(case=label, phase="mutated"):
                    self.assertEqual(ceb.check_source(*R1_REPRODUCTIONS[label]), [])
            with self.subTest(case="A-3/ctypes", phase="second-layer-holds"):
                self.assertTrue(ceb.check_source(*R1_REPRODUCTIONS["A-3/ctypes"]))
        for label in labels + ("A-3/ctypes",):
            with self.subTest(case=label, phase="fixed"):
                self.assertTrue(ceb.check_source(*R1_REPRODUCTIONS[label]))

    def test_mutation_both_layers_off_restores_the_ctypes_hole(self):
        """変異注入: R1-A-3 定数 + R2-a-2 第 2 層の**両方**を外すと ctypes が復活する。

        「R1-A-3 の定数がまだ load-bearing である」ことの実証（第 2 層が
        できたから元の層が不要になった、という誤読を防ぐ）。
        """
        case = R1_REPRODUCTIONS["A-3/ctypes"]
        with _patched(FORBIDDEN_MODULE_ROOTS=self.LEGACY_FORBIDDEN_ROOTS,
                      OS_EXEC_ATTRS=self.LEGACY_OS_EXEC_ATTRS,
                      ASYNCIO_EXEC_ATTRS=(),
                      INDIRECT_EXEC_ATTRS=frozenset()):
            self.assertEqual(ceb.check_source(*case), [])
        self.assertTrue(ceb.check_source(*case))


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
        with _patched(_gh_exec_discipline=lambda *_a, **_kw: []):
            self.assertEqual(ceb.check_source(name, source), [])
        self.assertTrue(ceb.check_source(name, source))

    def test_discipline_does_not_apply_to_other_modules(self):
        """test_*.py の `subprocess.run` は argv 不変条件側で扱う（二重適用しない）。"""
        source = ("import subprocess\nimport sys\ndef helper():\n"
                  "    return subprocess.run([sys.executable, \"x.py\"])\n")
        self.assertEqual(ceb.check_source("test_x.py", source), [])


# ---------------------------------------------------------------------------
# R2-a-1 / R2-a-2: 束縛伝播（データフロー追跡）と fail-closed 既定
# ---------------------------------------------------------------------------

#: R2 敵対レビューで「MISS（すり抜け）」と実測された 6 形。すべて DETECTED になること。
#: 束縛表を `import` 文だけから作ると、**変数への代入 1 行**で 1〜3・6 の全検査が
#: 迂回できた（R2-a-1）。加えて未知の名前を「トークンでない」と判定していたため
#: `__dict__` 添字も無検査だった（R2-a-2）。
R2_REPRODUCTIONS = {
    # gh_exec.py 内部の構造規律（R1-A-4）の復活
    "R2/gh_exec-alias-shell-true": (
        "gh_exec.py",
        "import subprocess\n_run = subprocess.run\ndef run_gh(a):\n"
        "    return _run([\"gh\"]+a, shell=True)\n"),
    "R2/gh_exec-os-alias": (
        "gh_exec.py",
        "import subprocess\nimport os\n_os = os\ndef run_gh(a):\n"
        "    _os.system(\"x\")\n"),
    # 全モジュール共通の実行系トークン deny（R1-A-1 / A-3）の復活
    "R2/module-alias-attr": (
        "collector.py", "import os\nmod = os\ndef x():\n    mod.system(\"x\")\n"),
    "R2/getattr-on-alias": (
        "collector.py",
        "import os\nmod = os\ndef x():\n    getattr(mod,\"system\")(\"x\")\n"),
    "R2/dunder-dict-subscript": (
        "collector.py", "import os\ndef x():\n    os.__dict__[\"system\"](\"x\")\n"),
    # test_*.py の argv 不変条件（R1）の復活
    "R2/test-argv-via-alias": (
        "test_x.py",
        "import subprocess\n_run = subprocess.run\ndef x():\n"
        "    _run([\"gh\",\"pr\",\"merge\",\"1\"])\n"),
}

#: 正当な Python の書き方。**1 件も violation を出してはならない**（偽陽性ゼロ）。
BENIGN_SOURCES = {
    "getattr-default-on-local": (
        "collector.py",
        "def x(proc):\n    return getattr(proc, \"returncode\", 1)\n"),
    "re-compile": ("collector.py", "import re\nPAT = re.compile(r\"a+\")\n"),
    "os-environ": ("collector.py", "import os\ndef x():\n    return os.environ.get(\"HOME\")\n"),
    "os-path-join": (
        "collector.py",
        "import os\ndef x(a, b):\n    return os.path.join(a, b)\n"),
    "self-method-call": (
        "collector.py",
        "class C:\n    def a(self):\n        return self.b()\n"
        "    def b(self):\n        return 1\n"),
    "local-dataclass-method": (
        "collector.py",
        "import dataclasses\n@dataclasses.dataclass\nclass R:\n    n: int\n"
        "    def run(self):\n        return self.n\n"
        "def x():\n    return R(1).run()\n"),
    "json-dumps": (
        "collector.py",
        "import json\ndef x(d):\n    return json.dumps(d, ensure_ascii=False)\n"),
    "pathlib-chain": (
        "collector.py",
        "import pathlib\ndef x(p):\n    return pathlib.Path(p).resolve().parent\n"),
    "local-var-method-chain": (
        "collector.py",
        "def x(view):\n    return view.stdout.strip().splitlines()\n"),
    "alias-of-benign-module": (
        "collector.py", "import json\n_j = json\ndef x(d):\n    return _j.loads(d)\n"),
    "test-subprocess-sys-executable": (
        "test_x.py",
        "import subprocess\nimport sys\ndef x():\n"
        "    subprocess.run([sys.executable, \"a.py\"])\n"),
    "enumerate-over-local-callables": (
        "collector.py",
        "def x(handlers, ctx):\n    for h in handlers:\n        h(ctx)\n"),
}


#: **束縛伝播でしか捕まらない**形（fail-closed 層は属性名で判定するため
#: `run` のような一般的な名前には掛からない）。伝播の検出力実証に使う。
PROPAGATION_ONLY_SOURCES = {
    # `gh_exec.py` は `subprocess` 自体は合法なので、別名を解決できるかどうかで
    # 「`_spawn()` の外での呼び出し」を検出できるか否かが決まる。
    "module-alias-subprocess-run": (
        "gh_exec.py",
        "import subprocess\n_sp = subprocess\ndef run_gh(a):\n    return _sp.run(a)\n"),
    "func-alias-argv-in-test": R2_REPRODUCTIONS["R2/test-argv-via-alias"],
}


class BindingPropagationTests(unittest.TestCase):
    """R2-a-1: 束縛は `import` だけでなく代入も伝播する（データフロー追跡）。"""

    def test_all_r2_reproductions_are_detected(self):
        for label, (name, source) in R2_REPRODUCTIONS.items():
            with self.subTest(case=label):
                self.assertTrue(ceb.check_source(name, source), f"{label} がすり抜けた")

    def test_no_false_positive_on_benign_sources(self):
        """偽陽性ゼロの実証: 正当な書き方 12 種が 1 件も違反にならない。"""
        for label, (name, source) in BENIGN_SOURCES.items():
            with self.subTest(case=label):
                self.assertEqual(ceb.check_source(name, source), [])

    def test_chained_alias_is_propagated(self):
        source = "import os\na = os\nb = a\ndef x():\n    b.system(\"x\")\n"
        self.assertIn(ceb.CODE_EXEC_TOKEN, _codes(ceb.check_source("collector.py", source)))

    def test_tuple_assignment_is_propagated(self):
        source = "import os\nimport sys\na, b = os, sys\ndef x():\n    a.system(\"x\")\n"
        self.assertIn(ceb.CODE_EXEC_TOKEN, _codes(ceb.check_source("collector.py", source)))

    def test_multiple_assignment_is_propagated(self):
        source = "import os\na = b = os\ndef x():\n    b.popen(\"x\")\n"
        self.assertIn(ceb.CODE_EXEC_TOKEN, _codes(ceb.check_source("collector.py", source)))

    def test_annotated_assignment_is_propagated(self):
        source = "import os\nm: object = os\ndef x():\n    m.system(\"x\")\n"
        self.assertIn(ceb.CODE_EXEC_TOKEN, _codes(ceb.check_source("collector.py", source)))

    def test_function_default_argument_is_propagated(self):
        source = ("import subprocess\ndef x(runner=subprocess.run):\n"
                  "    return runner([\"gh\", \"pr\", \"merge\", \"1\"])\n")
        self.assertIn(ceb.CODE_EXEC_TOKEN, _codes(ceb.check_source("collector.py", source)))

    def test_keyword_only_default_is_propagated(self):
        source = ("import os\ndef x(*, m=os):\n    m.system(\"x\")\n")
        self.assertIn(ceb.CODE_EXEC_TOKEN, _codes(ceb.check_source("collector.py", source)))

    def test_alias_of_exec_function_in_test_module_is_argv_checked(self):
        """test_*.py: 別名経由でも argv 不変条件が効く（正側 = sys.executable は通る）。"""
        ok = ("import subprocess\nimport sys\n_run = subprocess.run\n"
              "def x():\n    _run([sys.executable, \"a.py\"])\n")
        self.assertEqual(ceb.check_source("test_x.py", ok), [])

    def test_mutation_disabling_propagation_restores_propagation_only_holes(self):
        """変異注入: 伝播を外すと（＝ import 文だけの旧モデル）別名がすり抜ける。

        R2 の 6 形のうち 4 形は **fail-closed 層（R2-a-2）にも**掛かるため、
        伝播だけを外しても落ちない（層が独立している証拠）。ここでは
        「伝播でしか捕まらない形」を使って伝播そのものの検出力を実証する。
        """
        for label, (name, source) in PROPAGATION_ONLY_SOURCES.items():
            with self.subTest(case=label, phase="fixed"):
                self.assertTrue(ceb.check_source(name, source))
        with _patched(_propagate_bindings=lambda *_a, **_kw: False):
            for label, (name, source) in PROPAGATION_ONLY_SOURCES.items():
                with self.subTest(case=label, phase="mutated"):
                    self.assertEqual(ceb.check_source(name, source), [])

    def test_mutation_disabling_all_r2_layers_restores_all_six_holes(self):
        """変異注入: R2 で足した層を**すべて**外すと 6 形すべてがすり抜ける。

        R2-a-1（束縛伝播）/ R2-a-2（イントロスペクション・間接実行名・
        `gh_exec.py` 厳格解決）の合成で 6 形が塞がっていることの実証。
        """
        with _patched(_propagate_bindings=lambda *_a, **_kw: False,
                      INTROSPECTION_ATTRS=frozenset(),
                      INDIRECT_EXEC_ATTRS=frozenset(),
                      _gh_exec_indirect_calls=lambda *_a, **_kw: []):
            for label in R2_REPRODUCTIONS:
                with self.subTest(case=label, phase="mutated"):
                    self.assertEqual(ceb.check_source(*R2_REPRODUCTIONS[label]), [])
        for label in R2_REPRODUCTIONS:
            with self.subTest(case=label, phase="fixed"):
                self.assertTrue(ceb.check_source(*R2_REPRODUCTIONS[label]))

    def test_propagation_reaches_fixed_point_without_infinite_loop(self):
        """伝播は不動点で停止する（自己参照の代入でも停止すること）。"""
        source = "import os\na = os\na = a\ndef x():\n    a.system(\"x\")\n"
        self.assertIn(ceb.CODE_EXEC_TOKEN, _codes(ceb.check_source("collector.py", source)))


class FailClosedDefaultTests(unittest.TestCase):
    """R2-a-2: 「解決できない = トークンでない」を「解決できない = violation」へ反転。"""

    def test_dunder_dict_with_literal_key_resolves_to_token(self):
        source = "import os\ndef x():\n    os.__dict__[\"system\"](\"x\")\n"
        self.assertIn(ceb.CODE_EXEC_TOKEN, _codes(ceb.check_source("collector.py", source)))

    def test_dunder_dict_with_variable_key_is_fail_closed(self):
        source = "import os\ndef x(k):\n    return os.__dict__[k]\n"
        self.assertIn(ceb.CODE_INDIRECT_EXEC,
                      _codes(ceb.check_source("collector.py", source)))

    def test_dunder_dict_without_subscript_is_fail_closed(self):
        source = "import os\ndef x():\n    d = os.__dict__\n    return d\n"
        self.assertIn(ceb.CODE_INDIRECT_EXEC,
                      _codes(ceb.check_source("collector.py", source)))

    def test_other_introspection_attrs_are_fail_closed(self):
        for attr in ("__globals__", "__builtins__", "__subclasses__",
                     "__getattribute__", "__code__"):
            with self.subTest(attr=attr):
                source = f"def x(f):\n    return f.{attr}\n"
                self.assertIn(ceb.CODE_INDIRECT_EXEC,
                              _codes(ceb.check_source("collector.py", source)))

    def test_declaration_dunders_are_not_flagged(self):
        """`__slots__` / `__repr__` / `__name__` 等の宣言系は対象外（偽陽性ガード）。"""
        source = ("class C:\n    __slots__ = (\"a\",)\n"
                  "    def __repr__(self):\n        return type(self).__name__\n")
        self.assertEqual(ceb.check_source("collector.py", source), [])

    def test_unresolved_base_with_exec_attr_is_fail_closed(self):
        source = "def x(m, c):\n    return m.system(c)\n"
        self.assertIn(ceb.CODE_EXEC_TOKEN, _codes(ceb.check_source("collector.py", source)))

    def test_unresolved_base_with_benign_attr_is_not_flagged(self):
        source = "def x(proc):\n    return proc.returncode\n"
        self.assertEqual(ceb.check_source("collector.py", source), [])

    def test_execute_is_not_confused_with_os_exec_family(self):
        """`cursor.execute()` は prefix 一致では倒さない（`OS_EXEC_FAMILY` は完全一致）。"""
        source = "def x(cursor, q):\n    return cursor.execute(q)\n"
        self.assertEqual(ceb.check_source("collector.py", source), [])

    def test_getattr_on_unresolved_base_with_exec_name_is_fail_closed(self):
        source = "def x(m, c):\n    return getattr(m, \"system\")(c)\n"
        self.assertIn(ceb.CODE_EXEC_TOKEN, _codes(ceb.check_source("collector.py", source)))

    def test_getattr_on_unresolved_base_with_benign_name_passes(self):
        source = "def x(proc):\n    return getattr(proc, \"returncode\", 1)\n"
        self.assertEqual(ceb.check_source("collector.py", source), [])

    def test_mutation_disabling_indirect_attrs_restores_the_hole(self):
        cases = ("def x(m, c):\n    return m.system(c)\n",
                 "def x(m, c):\n    return getattr(m, \"system\")(c)\n")
        with _patched(INDIRECT_EXEC_ATTRS=frozenset()):
            for source in cases:
                with self.subTest(source=source, phase="mutated"):
                    self.assertEqual(ceb.check_source("collector.py", source), [])
        for source in cases:
            with self.subTest(source=source, phase="fixed"):
                self.assertTrue(ceb.check_source("collector.py", source))


class GhExecStrictResolutionTests(unittest.TestCase):
    """R2-a-2 不変条件 8(d): `gh_exec.py` は呼び出し先の静的解決を要求する。"""

    def test_real_gh_exec_passes_strict_resolution(self):
        source = (HERE / "gh_exec.py").read_text(encoding="utf-8")
        self.assertEqual(ceb.check_source("gh_exec.py", source), [])

    def test_unresolvable_bare_call_is_flagged(self):
        source = ("def run_gh(handlers, a):\n    for h in handlers:\n"
                  "        return h(a)\n")
        self.assertIn(ceb.CODE_GH_EXEC_INDIRECT_CALL,
                      _codes(ceb.check_source("gh_exec.py", source)))

    def test_module_local_and_builtin_calls_pass(self):
        source = ("def helper(a):\n    return len(str(a))\n"
                  "def run_gh(a):\n    return helper(a)\n")
        self.assertEqual(ceb.check_source("gh_exec.py", source), [])

    def test_exception_list_is_exactly_one_entry(self):
        entries = ceb.GH_EXEC_INDIRECT_CALL_EXCEPTIONS
        self.assertEqual(len(entries), 1, f"例外は 1 件固定: {list(entries)}")
        self.assertEqual(tuple(entries[0]), ("authorize_gh", "condition"))

    def test_exception_is_scoped_to_function_and_callee_name(self):
        """例外は (関数名, 呼び出し名) の組で効く（別関数の同名呼び出しは通さない）。"""
        outside = ("def authorize_git(rule, ctx):\n    for _n, condition in rule:\n"
                   "        condition(ctx)\n")
        self.assertIn(ceb.CODE_GH_EXEC_INDIRECT_CALL,
                      _codes(ceb.check_source("gh_exec.py", outside)))
        inside = ("def authorize_gh(rule, ctx):\n    for _n, condition in rule:\n"
                  "        condition(ctx)\n")
        self.assertEqual(ceb.check_source("gh_exec.py", inside), [])

    def test_mutation_extra_exception_would_suppress_a_real_violation(self):
        rogue = ("def run_gh(handlers, a):\n    for h in handlers:\n"
                 "        return h(a)\n")
        self.assertTrue(ceb.check_source("gh_exec.py", rogue))
        with _patched(GH_EXEC_INDIRECT_CALL_EXCEPTIONS=(
                ("authorize_gh", "condition"), ("run_gh", "h"))):
            self.assertEqual(ceb.check_source("gh_exec.py", rogue), [])

    def test_strict_resolution_does_not_apply_to_other_modules(self):
        source = ("def x(handlers, a):\n    for h in handlers:\n"
                  "        return h(a)\n")
        for name in ("collector.py", "test_x.py"):
            with self.subTest(module=name):
                self.assertEqual(ceb.check_source(name, source), [])


# ---------------------------------------------------------------------------
# R3-1: 添字式（ast.Subscript）経路 / R3-3: TYPE_CHECKING 偽陽性
# ---------------------------------------------------------------------------

#: R3 敵対レビューで「MISS（すり抜け）」と実測された 3 形。すべて DETECTED になること。
#: R2 までは `ast.Attribute` チェーンしか解決していなかったため、**意味が同じでも
#: AST の形が `ast.Subscript` なだけ**で検査の視野外になっていた。
#: 非対称性が症状として現れていた:
#:   - `os.__dict__["system"]` は DETECTED / `vars(os)["system"]` は MISS
#:   - `sys.modules["subprocess"].Popen` は DETECTED / `.run` は MISS
R3_REPRODUCTIONS = {
    "R3/vars-subscript": (
        "collector.py",
        "import os\ndef x():\n    vars(os)[\"system\"](\"cmd\")\n"),
    "R3/sys-modules-run": (
        "collector.py",
        "import sys\ndef x(a):\n    sys.modules[\"subprocess\"].run(a)\n"),
    "R3/gh_exec-sys-modules-shell-true": (
        "gh_exec.py",
        "import sys\ndef run_gh(a):\n"
        "    sys.modules[\"subprocess\"].run(a, shell=True)\n"),
}

#: R3 是正で新たに「正当な書き方」として通ることを固定する形（偽陽性ゼロの実証）。
#: 添字は Python の日常語彙なので、ここが崩れると CI が正当なコードを止める。
R3_BENIGN_SOURCES = {
    "type-checking-block": (
        "collector.py",
        "from typing import TYPE_CHECKING\nif TYPE_CHECKING:\n"
        "    import subprocess\ndef f(x: \"subprocess.Popen\") -> None:\n    pass\n"),
    "type-checking-qualified": (
        "collector.py",
        "from __future__ import annotations\nimport typing\n"
        "if typing.TYPE_CHECKING:\n    import subprocess\n"
        "def f(x: subprocess.Popen) -> None:\n    pass\n"),
    "plain-dict-subscript": ("collector.py", "def x(d):\n    return d[\"key\"]\n"),
    "list-index": ("collector.py", "def x(lst):\n    return lst[0]\n"),
    "os-environ-subscript": (
        "collector.py", "import os\ndef x():\n    return os.environ[\"HOME\"]\n"),
    "argv-slice": ("collector.py", "import sys\ndef x():\n    return sys.argv[1:]\n"),
    "fstring-subscript": ("collector.py", "def x(d):\n    return f\"{d['k']}\"\n"),
    "functools-partial": (
        "collector.py",
        "import functools\ndef x(f, a):\n    return functools.partial(f, a)\n"),
    "custom-decorator": (
        "collector.py", "def deco(f):\n    return f\n@deco\ndef g():\n    return 1\n"),
    "comprehension-subscript": (
        "collector.py", "def x(items):\n    return [i[\"name\"] for i in items]\n"),
    "nested-dict-subscript": (
        "collector.py", "def x(cfg):\n    return cfg[\"a\"][\"b\"]\n"),
    "module-level-dict-lookup": (
        "collector.py", "M = {\"a\": 1}\ndef x():\n    return M[\"a\"]\n"),
    "subscript-assign-target": ("collector.py", "def x(d, v):\n    d[\"k\"] = v\n"),
    "type-checking-else-branch-is-benign": (
        "collector.py",
        "from typing import TYPE_CHECKING\nif TYPE_CHECKING:\n    import subprocess\n"
        "else:\n    import json\ndef f():\n    return json.dumps({})\n"),
}


class SubscriptResolutionTests(unittest.TestCase):
    """R3-1: `ast.Subscript` も束縛解決の対象にする（不変条件 9）。"""

    def test_all_r3_reproductions_are_detected(self):
        for label, (name, source) in R3_REPRODUCTIONS.items():
            with self.subTest(case=label):
                self.assertTrue(ceb.check_source(name, source), f"{label} がすり抜けた")

    def test_vars_subscript_resolves_to_the_same_token_as_dunder_dict(self):
        """非対称性の解消: `vars(os)["system"]` と `os.__dict__["system"]` は同じ。"""
        via_vars = ceb.check_source(
            "collector.py", "import os\ndef x():\n    vars(os)[\"system\"](\"c\")\n")
        via_dict = ceb.check_source(
            "collector.py", "import os\ndef x():\n    os.__dict__[\"system\"](\"c\")\n")
        self.assertIn(ceb.CODE_EXEC_TOKEN, _codes(via_vars))
        self.assertIn(ceb.CODE_EXEC_TOKEN, _codes(via_dict))
        self.assertIn("os.system", repr(via_vars))
        self.assertIn("os.system", repr(via_dict))

    def test_sys_modules_run_and_popen_are_both_blocked(self):
        """非対称性の解消: `.Popen` だけでなく `.run` も塞がる。"""
        for attr in ("run", "Popen", "check_output", "call", "check_call"):
            with self.subTest(attr=attr):
                source = (f"import sys\ndef x(a):\n"
                          f"    sys.modules[\"subprocess\"].{attr}(a)\n")
                self.assertIn(ceb.CODE_EXEC_TOKEN,
                              _codes(ceb.check_source("collector.py", source)))

    def test_gh_exec_shell_true_via_sys_modules_is_flagged(self):
        name, source = R3_REPRODUCTIONS["R3/gh_exec-sys-modules-shell-true"]
        codes = _codes(ceb.check_source(name, source))
        self.assertIn(ceb.CODE_GH_EXEC_SHELL, codes)
        self.assertIn(ceb.CODE_GH_EXEC_SPAWN_SITE, codes)

    def test_globals_subscript_resolves_to_module_binding(self):
        source = ("import subprocess\ndef x(a):\n"
                  "    globals()[\"subprocess\"].run(a)\n")
        self.assertIn(ceb.CODE_EXEC_TOKEN,
                      _codes(ceb.check_source("collector.py", source)))

    def test_vars_on_propagated_alias_is_resolved(self):
        """束縛伝播（不変条件 7）と添字解決（不変条件 9）が合成される。"""
        source = "import os\nm = os\ndef x(c):\n    vars(m)[\"system\"](c)\n"
        self.assertIn(ceb.CODE_EXEC_TOKEN,
                      _codes(ceb.check_source("collector.py", source)))

    def test_argv_invariant_applies_to_subscript_call_sites_in_tests(self):
        """`test_*.py` の argv 不変条件が添字経路にも効く（除外の穴を作らない）。"""
        for label, source in (
                ("vars", "import subprocess\ndef x():\n"
                         "    vars(subprocess)[\"run\"]([\"gh\",\"pr\",\"merge\",\"1\"])\n"),
                ("sys.modules", "import sys\ndef x():\n"
                                "    sys.modules[\"subprocess\"]"
                                ".run([\"gh\",\"pr\",\"merge\",\"1\"])\n")):
            with self.subTest(form=label):
                self.assertIn(ceb.CODE_ARGV_HEAD,
                              _codes(ceb.check_source("test_x.py", source)))

    def test_argv_positive_case_via_subscript_passes(self):
        source = ("import sys\ndef x():\n"
                  "    sys.modules[\"subprocess\"].run([sys.executable, \"a.py\"])\n")
        self.assertEqual(ceb.check_source("test_x.py", source), [])

    def test_no_false_positive_on_r3_benign_sources(self):
        """偽陽性ゼロの実証: 添字を含む正当な書き方 14 種が 1 件も違反にならない。"""
        self.assertGreaterEqual(len(R3_BENIGN_SOURCES), 8)
        for label, (name, source) in R3_BENIGN_SOURCES.items():
            with self.subTest(case=label):
                self.assertEqual(ceb.check_source(name, source), [])

    def test_current_tree_is_still_clean_after_r3(self):
        targets = ceb.default_targets()
        self.assertGreaterEqual(len(targets), 26)
        self.assertEqual(ceb.check_paths(targets), [])

    def test_mutation_disabling_subscript_layer_restores_all_three_holes(self):
        """変異注入: 添字解決 + 添字 fail-closed を外すと R3 の 3 形が復活する。"""
        with _patched(_resolve_subscript=lambda binds, node: None,
                      _resolve_namespace_call=lambda binds, node: None,
                      _collect_subscript_unresolved=lambda *_a, **_kw: []):
            for label, (name, source) in R3_REPRODUCTIONS.items():
                with self.subTest(case=label, phase="mutated"):
                    self.assertEqual(ceb.check_source(name, source), [],
                                     f"{label} は変異後すり抜けるはず")
        for label, (name, source) in R3_REPRODUCTIONS.items():
            with self.subTest(case=label, phase="fixed"):
                self.assertTrue(ceb.check_source(name, source))

    def test_mutation_disabling_only_resolution_leaves_fail_closed_layer(self):
        """層の独立性: 解決だけを外しても fail-closed 層が 3 形すべてを受け止める。

        解決層（`_resolve_subscript` / `_resolve_namespace_call`）を外すと
        「実行系トークンとしての識別」は失われるが、
          - `vars(os)["system"](...)` は**添字式の呼び出し**の基底が解決不能
          - `sys.modules["subprocess"]` は `sys.modules` 参照の fail-closed
        に落ちる。**両層を同時に外して初めてすり抜ける**
        （`test_mutation_disabling_subscript_layer_restores_all_three_holes`）
        ことが、層が独立している証拠になる。
        """
        with _patched(_resolve_subscript=lambda binds, node: None,
                      _resolve_namespace_call=lambda binds, node: None):
            for label, (name, source) in R3_REPRODUCTIONS.items():
                with self.subTest(case=label):
                    self.assertIn(ceb.CODE_INDIRECT_EXEC,
                                  _codes(ceb.check_source(name, source)))


class SubscriptFailClosedTests(unittest.TestCase):
    """R3-1 の fail-closed 層（不変条件 9 の後段）。"""

    def test_subscript_call_with_unresolvable_base_is_flagged(self):
        source = "def x(table, a):\n    return table[\"run\"](a)\n"
        self.assertIn(ceb.CODE_INDIRECT_EXEC,
                      _codes(ceb.check_source("collector.py", source)))

    def test_subscript_call_with_variable_key_is_flagged(self):
        source = "def x(table, k, a):\n    return table[k](a)\n"
        self.assertIn(ceb.CODE_INDIRECT_EXEC,
                      _codes(ceb.check_source("collector.py", source)))

    def test_dynamic_attr_family_without_literal_subscript_is_flagged(self):
        for builtin, source in (
                ("vars", "import os\ndef x(k):\n    return vars(os)[k]\n"),
                ("globals", "def x():\n    return globals()\n"),
                ("locals", "def x():\n    return locals()\n"),
                ("dir", "import os\ndef x():\n    return dir(os)\n")):
            with self.subTest(builtin=builtin):
                self.assertIn(ceb.CODE_DYNAMIC_UNRESOLVED,
                              _codes(ceb.check_source("collector.py", source)))

    def test_sys_modules_without_literal_subscript_is_flagged(self):
        for label, source in (
                ("variable-key", "import sys\ndef x(n):\n    return sys.modules[n]\n"),
                ("bare", "import sys\ndef x():\n    return sys.modules\n")):
            with self.subTest(form=label):
                self.assertIn(ceb.CODE_INDIRECT_EXEC,
                              _codes(ceb.check_source("collector.py", source)))

    def test_dynamic_attr_family_is_a_family_not_a_single_builtin(self):
        """`vars` / `globals` / `locals` / `dir` を明示的に族として扱っている。"""
        self.assertEqual(ceb.DYNAMIC_ATTR_FAMILY,
                         frozenset({"vars", "globals", "locals", "dir"}))


class TypeCheckingExclusionTests(unittest.TestCase):
    """R3-3: `if TYPE_CHECKING:` の型専用 import を偽陽性にしない（不変条件 10）。"""

    def test_type_checking_import_is_not_flagged(self):
        for label, source in (
                ("bare", "from typing import TYPE_CHECKING\nif TYPE_CHECKING:\n"
                         "    import subprocess\n"
                         "def f(x: \"subprocess.Popen\") -> None:\n    pass\n"),
                ("qualified", "import typing\nif typing.TYPE_CHECKING:\n"
                              "    import subprocess\n"
                              "def f(x: \"subprocess.Popen\") -> None:\n    pass\n")):
            with self.subTest(form=label):
                self.assertEqual(ceb.check_source("collector.py", source), [])

    def test_else_branch_of_type_checking_still_runs_and_is_checked(self):
        """`else:` は実行されるので対象外にしない（緩めすぎの防止）。"""
        source = ("from typing import TYPE_CHECKING\nif TYPE_CHECKING:\n"
                  "    import json\nelse:\n    import subprocess\n")
        self.assertIn(ceb.CODE_EXEC_TOKEN,
                      _codes(ceb.check_source("collector.py", source)))

    def test_ordinary_if_block_is_not_excluded(self):
        source = "def x(flag):\n    if flag:\n        import subprocess\n"
        self.assertIn(ceb.CODE_EXEC_TOKEN,
                      _codes(ceb.check_source("collector.py", source)))

    def test_annotation_is_excluded_only_with_future_annotations(self):
        """PEP 563 が効く（= 注釈が評価されない）ときだけ注釈を対象外にする。"""
        with_future = ("from __future__ import annotations\nimport os\n"
                       "def f(x: os.system) -> None:\n    pass\n")
        self.assertEqual(ceb.check_source("collector.py", with_future), [])
        without_future = "import os\ndef f(x: os.system) -> None:\n    pass\n"
        self.assertIn(ceb.CODE_EXEC_TOKEN,
                      _codes(ceb.check_source("collector.py", without_future)))

    def test_runtime_code_inside_a_type_checking_module_is_still_checked(self):
        """TYPE_CHECKING を持つモジュールでも本体コードは通常どおり検査される。"""
        source = ("from typing import TYPE_CHECKING\nif TYPE_CHECKING:\n"
                  "    import subprocess\ndef f(cmd):\n    import os\n"
                  "    os.system(cmd)\n")
        self.assertIn(ceb.CODE_EXEC_TOKEN,
                      _codes(ceb.check_source("collector.py", source)))


# ---------------------------------------------------------------------------
# R3-2 / R3-4 / 残存脅威モデル: コード中の主張が実態と一致していること
# ---------------------------------------------------------------------------

class DocumentedClaimsTests(unittest.TestCase):
    """コード中の主張は「実測で真」でなければならない（誤った安心を残さない）。

    R3-2 で `INDIRECT_EXEC_ATTRS` のコメントが**実態と食い違っていた**
    （「別名経由の `subprocess.run` は束縛伝播が解決するので検出力は落ちない」
    と無条件に書いていたが `sys.modules["subprocess"].run` がすり抜けていた）。
    同じ事故を繰り返さないよう、主張の前提を機械で固定する。
    """

    SOURCE = SCRIPT.read_text(encoding="utf-8")

    def test_alias_claim_is_true_for_every_acquisition_route(self):
        """R3-2: 「モジュール内で subprocess を取得する経路は塞いである」の実測。"""
        routes = {
            "import-as": "import subprocess as sp\ndef x(a):\n    sp.run(a)\n",
            "from-import": "from subprocess import run\ndef x(a):\n    run(a)\n",
            "assign-alias": ("import subprocess\n_run = subprocess.run\n"
                             "def x(a):\n    _run(a)\n"),
            "dunder-dict": ("import sys\ndef x(a):\n"
                            "    sys.__dict__[\"modules\"]"
                            "[\"subprocess\"].run(a)\n"),
            "dunder-dict-via-alias": ("import sys\n"
                                      "_t = sys.__dict__[\"modules\"]\n"
                                      "def x(a):\n    _t[\"subprocess\"].run(a)\n"),
            "vars": ("import subprocess\ndef x(a):\n"
                     "    vars(subprocess)[\"run\"](a)\n"),
            "sys-modules": ("import sys\ndef x(a):\n"
                            "    sys.modules[\"subprocess\"].run(a)\n"),
            "globals": ("import subprocess\ndef x(a):\n"
                        "    globals()[\"subprocess\"].run(a)\n"),
        }
        for label, source in routes.items():
            with self.subTest(route=label):
                self.assertTrue(ceb.check_source("collector.py", source),
                                f"{label} の取得経路がすり抜けた")

    def test_documented_residual_gap_is_actually_a_gap(self):
        """R3-2: 「残余」として明記した形が本当に残余であること（虚偽記載の防止）。

        `def f(m, a): m.run(a)` は偽陽性回避のため意図的に検出しない。
        「塞げていない」と書いた以上、塞がっていないことも固定する。
        """
        source = "def f(m, a):\n    return m.run(a)\n"
        self.assertEqual(ceb.check_source("collector.py", source), [])

    def test_indirect_exec_attrs_comment_states_the_residual(self):
        self.assertIn("塞げていない残余", self.SOURCE)
        self.assertIn("モジュール外から渡ってくる", self.SOURCE)

    def test_frozen_exception_comment_states_the_rules_constraint(self):
        """R3-4: `rules=` 差し替え禁止という前提がコード中に凍結されていること。"""
        self.assertIn("`rules=` を外部から差し替えないこと", self.SOURCE)

    def test_module_docstring_states_the_residual_threat_model(self):
        doc = ceb.__doc__ or ""
        self.assertIn("残存脅威モデル", doc)
        self.assertIn("完全性は主張しない", doc)
        self.assertIn("多層防御の 1 層", doc)
        for round_label in ("R1", "R2", "R3"):
            with self.subTest(round=round_label):
                self.assertIn(round_label, doc)

    def test_module_docstring_names_the_real_guarantors(self):
        doc = ceb.__doc__ or ""
        for guarantor in ("gh_exec", "C-4", "branch protection"):
            with self.subTest(guarantor=guarantor):
                self.assertIn(guarantor, doc)

    def test_runbook_documents_the_residual_threat_model(self):
        runbook = (HERE.parents[1] / "docs" / "workflows" / "ai-loop"
                   / "execution-runbook.md")
        self.assertTrue(runbook.is_file(), f"runbook が無い: {runbook}")
        text = runbook.read_text(encoding="utf-8")
        for phrase in ("残存脅威モデル", "多層防御", "完全性"):
            with self.subTest(phrase=phrase):
                self.assertIn(phrase, text)


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
