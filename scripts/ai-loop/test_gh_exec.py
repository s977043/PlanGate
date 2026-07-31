#!/usr/bin/env python3
"""test_gh_exec.py — gh_exec.py（唯一の gh / git 実行境界 allowlist）の unittest。

実行: python3 scripts/ai-loop/test_gh_exec.py

契約正本: docs/working/TASK-0917/plan.md「論点 D2 / D2-A の設計詳細（実装契約）」
カバー: test-cases.md TC-20（allow 経路の一意性）/ TC-21（既知禁止の検算）/
TC-22（補集合の自動追随）/ TC-23（フラグ次元）/ TC-24（正規化回避 + 短縮形の一律 deny）/
TC-25（argv[0] 固定）/ TC-26（負側テストの無害性）/ TC-27（git 側の危険形）/
TC-28（graphql / --cache が rule table に存在しない）/ TC-29（gh api GET の正側）/
TC-30（push_pr_head() の事前検査）。

設計上の注意:
- **実ネットワークに出ない**。`gh_exec.subprocess` をモジュール属性ごと spy に差し替え、
  `run` / `check_output` の呼び出し回数を数える（TC-26）。
- 変異注入は **rule table の一時差し替え**（`dataclasses.replace`）で行い、
  作業ツリーのファイルは 1 バイトも書き換えない。
- 本ファイル自身が `check_exec_boundary.py` の検査対象（`test_*.py`）であるため、
  `subprocess` を import せず実プロセスも起動しない。
"""

from __future__ import annotations

import dataclasses
import json
import pathlib
import sys
import unittest

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import gh_exec  # noqa: E402

REPO = "s977043/plangate"
OTHER_REPO = "other/other"
SHA = "0123456789abcdef0123456789abcdef01234567"


# ---------------------------------------------------------------------------
# spy（実プロセスを起動しないための subprocess 差し替え）
# ---------------------------------------------------------------------------

class _Completed:
    """subprocess.CompletedProcess 相当の最小スタブ。"""

    def __init__(self, returncode: int = 0, stdout: str = "", stderr: str = "") -> None:
        self.returncode = returncode
        self.stdout = stdout
        self.stderr = stderr


class _SubprocessSpy:
    """`gh_exec.subprocess` を丸ごと置き換える spy。実行は一切しない。"""

    def __init__(self, handler=None) -> None:
        self.calls: list = []
        self._handler = handler

    def _dispatch(self, entry, argv, kwargs):
        self.calls.append((entry, list(argv), dict(kwargs)))
        if self._handler is None:
            return _Completed(0, "", "")
        return self._handler(list(argv))

    def run(self, argv, **kwargs):
        return self._dispatch("run", argv, kwargs)

    def check_output(self, argv, **kwargs):
        return self._dispatch("check_output", argv, kwargs).stdout


class SpyMixin:
    """各テストで `gh_exec.subprocess` を spy へ差し替える（tearDown で復元）。"""

    handler = None

    def setUp(self) -> None:
        super().setUp()
        self._orig_subprocess = gh_exec.subprocess
        self.spy = _SubprocessSpy(self.handler)
        gh_exec.subprocess = self.spy

    def tearDown(self) -> None:
        gh_exec.subprocess = self._orig_subprocess
        super().tearDown()

    def assertNoSpawn(self):
        self.assertEqual(
            self.spy.calls, [],
            f"deny 経路で subprocess が呼ばれた: {self.spy.calls}")


# ---------------------------------------------------------------------------
# 共通データ（正側の代表コマンド / 補集合生成の語彙）
# ---------------------------------------------------------------------------

def _api(path: str) -> list:
    return ["api", path, "--method", "GET"]


#: 実 rule table では allow される代表コマンド（TC-20 の入力集合）。
def allowed_gh_commands(body_file: str) -> list:
    return [
        ["pr", "view", "1", "--json", "headRefName,baseRefName", "--repo", REPO],
        ["pr", "view", "feat/task-0917-delivery", "--json", "headRefName"],
        ["pr", "diff", "1", "--name-only", "--repo", REPO],
        ["pr", "checks", "1", "--json", "name,state", "--repo", REPO],
        ["pr", "comment", "1", "--body-file", body_file, "--repo", REPO],
        _api(f"repos/{REPO}/commits/{SHA}/check-runs"),
        _api(f"repos/{REPO}/pulls/1"),
        _api(f"repos/{REPO}/pulls/1/reviews?per_page=100"),
        _api(f"repos/{REPO}/rules/branches/main"),
    ]


ALLOWED_GIT_COMMANDS = [
    ["rev-parse", "HEAD"],
    ["merge-base", "--is-ancestor", SHA, "HEAD"],
    ["log", "--max-count", "1", "--format", "%H"],
    ["status", "--porcelain"],
    ["diff", "--name-only", "main...HEAD"],
    ["ls-remote", "--get-url", "origin"],
    ["show", "--no-patch", "--format", "%H", "HEAD"],
]

#: TC-22 の直積生成に使う語彙（allowlist を拡張しても本集合は変えずに追随する）。
NOUNS = ("pr", "issue", "repo", "api", "release", "run", "workflow", "gist", "auth")
VERBS = ("merge", "close", "reopen", "ready", "edit", "delete", "create", "review",
         "sync", "rerun", "cancel", "checkout", "lock", "unlock", "transfer",
         "view", "diff", "checks", "comment", "list", "status")


# ===========================================================================
# TC-20 / T-7: allow 経路の一意性 + 関数末尾の無条件 deny
# ===========================================================================

class AllowPathUniquenessTests(SpyMixin, unittest.TestCase):
    """TC-20: rule table を空にすると、それまで allow だった全ケースが Denied になる。

    これは「allow が rule table 経由でしか成立しない」ことの**検出力の実証**である。
    関数末尾に無条件 `raise Denied` が置かれているため fallthrough allow は起きない。
    """

    def test_all_allowed_commands_pass_with_real_table(self):
        body = str(gh_exec.make_comment_body_file("notice"))
        for args in allowed_gh_commands(body):
            with self.subTest(args=args):
                argv = gh_exec.authorize_gh(args, repo=REPO)
                self.assertEqual(argv[0], "gh")

    def test_empty_rule_table_denies_every_previously_allowed_command(self):
        body = str(gh_exec.make_comment_body_file("notice"))
        for args in allowed_gh_commands(body):
            with self.subTest(args=args):
                with self.assertRaises(gh_exec.Denied):
                    gh_exec.authorize_gh(args, repo=REPO, rules=())

    def test_empty_git_rule_table_denies_every_previously_allowed_command(self):
        for args in ALLOWED_GIT_COMMANDS:
            with self.subTest(args=args):
                gh_exec.authorize_git(args)          # 実 table では allow
                with self.assertRaises(gh_exec.Denied):
                    gh_exec.authorize_git(args, rules=())

    def test_authorize_gh_ends_with_unconditional_deny(self):
        """rule が 1 件も match しない入力は必ず Denied（fallthrough allow 無し）。"""
        for args in (["nonexistent"], ["pr"], ["pr", "nonexistent", "1"], []):
            with self.subTest(args=args):
                with self.assertRaises(gh_exec.Denied):
                    gh_exec.authorize_gh(args, repo=REPO)
        self.assertNoSpawn()


# ===========================================================================
# TC-21 / T-8: 既知禁止 9 種の検算
# ===========================================================================

class KnownForbiddenTests(SpyMixin, unittest.TestCase):
    """TC-21: 既知禁止 9 種の検算。

    **これは allowlist の正しさの担保ではなく取りこぼしの検算である。**
    既知禁止の列挙は網羅性を証明しない。網羅性は TC-20（allow 経路の一意性）と
    TC-22（補集合の自動追随）の構造的検査が担う。本テストは「構造は正しいのに
    実際の禁止コマンドが通る」という取りこぼしを検出するための二次防御にすぎない。
    """

    KNOWN_FORBIDDEN = (
        ["pr", "merge", "1"],
        ["pr", "review", "1", "--approve"],
        ["pr", "close", "1"],
        ["pr", "reopen", "1"],
        ["pr", "ready", "1"],
        ["pr", "edit", "1"],
        ["api", "-X", "DELETE", f"repos/{REPO}/git/refs/heads/x"],
        ["api", "-X", "PUT", f"repos/{REPO}/pulls/1/merge"],
        ["repo", "sync"],
    )

    #: 短縮形を使わない long 形の等価入力（短縮形 deny に頼らないことの確認）。
    KNOWN_FORBIDDEN_LONG = (
        ["api", "--method", "DELETE", f"repos/{REPO}/git/refs/heads/x"],
        ["api", "--method", "PUT", f"repos/{REPO}/pulls/1/merge"],
        ["api", "--method", "GET", f"repos/{REPO}/pulls/1/merge"],
        ["pr", "merge", "1", "--squash", "--admin"],
    )

    def test_known_forbidden_are_denied(self):
        for args in self.KNOWN_FORBIDDEN + self.KNOWN_FORBIDDEN_LONG:
            with self.subTest(args=args):
                with self.assertRaises(gh_exec.Denied):
                    gh_exec.run_gh(args, repo=REPO)
        self.assertNoSpawn()


# ===========================================================================
# TC-22 / T-9: 補集合の自動追随
# ===========================================================================

class ComplementTests(SpyMixin, unittest.TestCase):
    """TC-22: サブコマンド語彙 × 動詞の直積を回し、allowlist 外が全件 Denied。

    allowlist を将来拡張しても本 TC は手作業更新なしで自動追随する
    （allow 側の判定は `rule_literal_prefixes()` から導出する）。
    """

    def test_complement_of_allowlist_is_denied(self):
        prefixes = gh_exec.rule_literal_prefixes(gh_exec.GH_RULES)
        self.assertTrue(prefixes, "rule table の literal prefix が空")
        checked = 0
        for noun in NOUNS:
            for verb in VERBS:
                if (noun,) in prefixes or (noun, verb) in prefixes:
                    continue
                checked += 1
                with self.subTest(noun=noun, verb=verb):
                    with self.assertRaises(gh_exec.Denied):
                        gh_exec.run_gh([noun, verb, "1"], repo=REPO)
        self.assertGreater(checked, 100, "直積が十分な件数を回っていない")
        self.assertNoSpawn()

    def test_git_complement_of_allowlist_is_denied(self):
        allowed = {r.sub for r in gh_exec.GIT_READ_RULES}
        forbidden = ("push", "commit", "reset", "checkout", "branch", "tag", "clean",
                     "rebase", "merge", "cherry-pick", "stash", "restore", "remote",
                     "fetch", "pull", "am", "apply", "config", "gc", "update-ref")
        for sub in forbidden:
            self.assertNotIn(sub, allowed)
            with self.subTest(sub=sub):
                with self.assertRaises(gh_exec.Denied):
                    gh_exec.run_git([sub, "origin", "main"])
        self.assertNoSpawn()


# ===========================================================================
# TC-23 / T-10: フラグ次元
# ===========================================================================

class FlagDimensionTests(SpyMixin, unittest.TestCase):
    """TC-23: サブコマンド名だけの allow では「PR の履歴を変える操作」を通してしまう。"""

    def test_pr_comment_history_mutating_flags_are_denied(self):
        body = str(gh_exec.make_comment_body_file("notice"))
        cases = (
            ["pr", "comment", "1", "--delete-last", "--yes"],
            ["pr", "comment", "1", "--edit-last"],
            ["pr", "comment", "1", "--edit-last", "--body-file", body],
            ["pr", "comment", "1", "-w"],
            ["pr", "comment", "1", "-e"],
            ["pr", "comment", "1", "--create-if-none", "--body-file", body],
            ["pr", "comment", "1", "--editor"],
            ["pr", "comment", "1", "--web"],
            ["pr", "comment", "1", "--body", "inline"],
        )
        for args in cases:
            with self.subTest(args=args):
                with self.assertRaises(gh_exec.Denied):
                    gh_exec.run_gh(args, repo=REPO)
        self.assertNoSpawn()

    def test_pr_comment_requires_wrapper_generated_body_file(self):
        with self.assertRaises(gh_exec.Denied):
            gh_exec.run_gh(["pr", "comment", "1"], repo=REPO)
        with self.assertRaises(gh_exec.Denied):
            gh_exec.run_gh(["pr", "comment", "1", "--body-file", "/etc/passwd"],
                           repo=REPO)
        self.assertNoSpawn()

    def test_unknown_flags_on_read_subcommands_are_denied(self):
        cases = (
            ["pr", "view", "1", "--web"],
            ["pr", "diff", "1", "--web"],
            ["pr", "checks", "1", "--watch"],
            ["pr", "checks", "1", "--fail-fast"],
            ["api", f"repos/{REPO}/pulls/1", "--cache", "1h"],
        )
        for args in cases:
            with self.subTest(args=args):
                with self.assertRaises(gh_exec.Denied):
                    gh_exec.run_gh(args, repo=REPO)
        self.assertNoSpawn()

    def test_repo_flag_must_be_bound_to_actual_repo(self):
        with self.assertRaises(gh_exec.Denied):
            gh_exec.run_gh(["pr", "view", "1", "--repo", OTHER_REPO], repo=REPO)
        self.assertNoSpawn()


# ===========================================================================
# TC-24 / T-11: 正規化回避 + 短縮形の一律 deny
# ===========================================================================

class NormalizationEvasionTests(SpyMixin, unittest.TestCase):
    """TC-24: `--k=v` 分解 / 短縮形の一律 deny / endpoint の実値束縛。"""

    def test_method_normalization_evasion_is_denied(self):
        base = f"repos/{REPO}/pulls/1"
        cases = (
            ["api", base, "--method=post"],
            ["api", base, "--method=POST"],
            ["api", base, "--method", "post"],
            ["api", base, "--method", "GET", "--method", "POST"],
            ["api", base, "--method", "POST", "--method", "GET"],
            ["api", base, "-XPOST"],
            ["api", base, "-X", "POST"],
            ["api", base, "-X", "GET"],       # GET でも短縮形なので deny
        )
        for args in cases:
            with self.subTest(args=args):
                with self.assertRaises(gh_exec.Denied):
                    gh_exec.run_gh(args, repo=REPO)
        self.assertNoSpawn()

    def test_short_flags_are_always_denied(self):
        body = str(gh_exec.make_comment_body_file("notice"))
        cases = (
            ["api", f"repos/{REPO}/pulls/1", "-f", "k=v"],
            ["api", f"repos/{REPO}/pulls/1", "-F", "k=v"],
            ["api", f"repos/{REPO}/pulls/1", "-q", ".x"],
            ["pr", "comment", "1", "-b", "x"],
            ["pr", "comment", "1", "-F", body],
            ["pr", "view", "1", "-q", ".x"],
            ["pr", "view", "1", "-"],
        )
        for args in cases:
            with self.subTest(args=args):
                with self.assertRaises(gh_exec.Denied):
                    gh_exec.run_gh(args, repo=REPO)
        self.assertNoSpawn()

    def test_combined_short_flag_is_split_then_denied(self):
        """`-XPOST` は分解したうえで「短縮形が使われた」ことを理由に deny する。"""
        with self.assertRaises(gh_exec.Denied) as ctx:
            gh_exec.authorize_gh(["api", f"repos/{REPO}/pulls/1", "-XPOST"], repo=REPO)
        self.assertEqual(ctx.exception.reason, gh_exec.REASON_SHORT_FLAG)
        self.assertIn("-X", str(ctx.exception))
        self.assertIn("POST", str(ctx.exception))

    def test_body_params_force_post_and_are_denied(self):
        base = f"repos/{REPO}/pulls/1"
        cases = (
            ["api", base, "--raw-field", "k=v"],
            ["api", base, "--field", "k=v"],
            ["api", base, "--input", "-"],
            ["api", base, "--method", "GET", "--field", "k=v"],
        )
        for args in cases:
            with self.subTest(args=args):
                with self.assertRaises(gh_exec.Denied):
                    gh_exec.run_gh(args, repo=REPO)
        self.assertNoSpawn()

    def test_double_dash_passthrough_is_denied(self):
        with self.assertRaises(gh_exec.Denied):
            gh_exec.run_gh(["pr", "view", "1", "--", "pr", "merge"], repo=REPO)
        self.assertNoSpawn()

    def test_endpoint_placeholder_and_foreign_repo_are_denied(self):
        cases = (
            ["api", "repos/{owner}/{repo}/pulls/1", "--method", "GET"],
            ["api", f"repos/{OTHER_REPO}/pulls/1", "--method", "GET"],
            ["api", f"repos/{REPO}/pulls/1/merge", "--method", "GET"],
            ["api", f"repos/{REPO}/rulesets", "--method", "GET"],
            ["api", f"repos/{REPO}/rulesets/14939019", "--method", "GET"],
            ["api", "graphql", "--method", "GET"],
            ["api", "graphql"],
            ["api", f"repos/{REPO}/pulls/1/../../../{OTHER_REPO}/pulls/1"],
        )
        for args in cases:
            with self.subTest(args=args):
                with self.assertRaises(gh_exec.Denied):
                    gh_exec.run_gh(args, repo=REPO)
        self.assertNoSpawn()


# ===========================================================================
# TC-25 / T-12: argv[0] 固定
# ===========================================================================

class Argv0Tests(SpyMixin, unittest.TestCase):
    """TC-25: wrapper が `argv[0]` を caller から受け取らない。"""

    def test_caller_supplied_argv0_never_assembles(self):
        cases = (
            ["sh", "-c", "gh pr merge 1"],
            ["/usr/bin/env", "gh", "pr", "merge", "1"],
            ["/usr/bin/gh", "pr", "merge", "1"],
            ["gh"],
            ["gh", "pr", "merge", "1"],
            ["bash", "-lc", "gh pr merge 1"],
        )
        for args in cases:
            with self.subTest(args=args):
                with self.assertRaises(gh_exec.Denied):
                    gh_exec.run_gh(args, repo=REPO)
        self.assertNoSpawn()

    def test_authorized_argv_head_is_fixed_by_wrapper(self):
        argv = gh_exec.authorize_gh(["pr", "view", "1", "--json", "headRefName"],
                                    repo=REPO)
        self.assertEqual(argv[0], "gh")
        git_argv = gh_exec.authorize_git(["status", "--porcelain"])
        self.assertEqual(git_argv[0], "git")


# ===========================================================================
# TC-26 / T-12: 負側テストの無害性（subprocess が一度も呼ばれない）
# ===========================================================================

class NoSpawnOnDenyTests(SpyMixin, unittest.TestCase):
    """TC-26: deny ケース全件で `subprocess.run` / `check_output` の呼び出し 0 回。"""

    def test_no_subprocess_call_for_any_deny_case(self):
        body = str(gh_exec.make_comment_body_file("notice"))
        deny_gh = list(KnownForbiddenTests.KNOWN_FORBIDDEN)
        deny_gh += list(KnownForbiddenTests.KNOWN_FORBIDDEN_LONG)
        deny_gh += [
            ["pr", "comment", "1", "--delete-last", "--yes"],
            ["pr", "comment", "1", "--body-file", "/etc/passwd"],
            ["api", f"repos/{REPO}/pulls/1", "-XPOST"],
            ["api", "graphql"],
            ["api", f"repos/{REPO}/pulls/1", "--cache", "1h"],
            ["sh", "-c", "gh pr merge 1"],
            ["pr", "comment", "1", "--edit-last", "--body-file", body],
        ]
        for args in deny_gh:
            with self.subTest(args=args):
                with self.assertRaises(gh_exec.Denied):
                    gh_exec.run_gh(args, repo=REPO)
        deny_git = (
            ["push", "origin", "--force", "HEAD:main"],
            ["push", "origin", "+HEAD:main"],
            ["branch", "-d", "x"],
        )
        for args in deny_git:
            with self.subTest(args=args):
                with self.assertRaises(gh_exec.Denied):
                    gh_exec.run_git(args)
        self.assertNoSpawn()

    def test_spy_is_actually_wired(self):
        """spy 自体が空振りしていないこと（正側で 1 回呼ばれる）の対照実験。"""
        gh_exec.run_gh(["pr", "view", "1", "--json", "headRefName"], repo=REPO)
        self.assertEqual(len(self.spy.calls), 1)
        self.assertEqual(self.spy.calls[0][1][0], "gh")


# ===========================================================================
# TC-27 / T-13: git 側の危険形
# ===========================================================================

class GitDangerousFormTests(SpyMixin, unittest.TestCase):
    """TC-27: 危険形が allowlist 経路に存在せず、構造化 API も生成しない。"""

    DANGEROUS = (
        ["push", "origin", "--force", "HEAD:main"],
        ["push", "origin", "--force-with-lease", "HEAD:main"],
        ["push", "--force", "origin", "main"],
        ["push", "origin", "-d", "feat/x"],
        ["push", "origin", "--delete", "feat/x"],
        ["push", "origin", "+HEAD:refs/heads/main"],
        ["push", "origin", ":feat/x"],
        ["push", "--mirror", "origin"],
        ["push", "origin", "--prune"],
        ["push", "origin", "--receive-pack=/bin/sh"],
        ["-c", "core.hooksPath=/dev/null", "push", "origin", "HEAD:main"],
        ["branch", "-d", "feat/x"],
        ["branch", "-D", "feat/x"],
        ["update-ref", "-d", "refs/heads/main"],
    )

    def test_dangerous_git_forms_are_denied(self):
        for args in self.DANGEROUS:
            with self.subTest(args=args):
                with self.assertRaises(gh_exec.Denied):
                    gh_exec.run_git(args)
        self.assertNoSpawn()

    def test_push_is_not_reachable_via_readonly_allowlist(self):
        self.assertNotIn("push", {r.sub for r in gh_exec.GIT_READ_RULES})

    def test_push_argv_builder_never_emits_dangerous_tokens(self):
        argv = gh_exec.build_push_argv(branch="feat/task-0917-delivery")
        self.assertEqual(argv[:3], ["git", "push", "origin"])
        self.assertEqual(len(argv), 4)
        refspec = argv[3]
        self.assertFalse(refspec.startswith("+"))
        self.assertFalse(refspec.startswith(":"))
        # フラグは 1 つも組み立てない（substring ではなく argv 要素単位で照合する。
        # branch 名 "feat/task-0917-delivery" は "-d" を部分文字列として含むため、
        # substring 照合だと偽陽性になる）。
        for element in argv:
            self.assertFalse(element.startswith("-"),
                             f"push argv にフラグが混入: {element!r}")
        dangerous = {"--force", "--force-with-lease", "--delete", "--mirror",
                     "--prune", "--receive-pack", "--no-verify", "-d", "-f", "-u"}
        self.assertEqual(set(argv) & dangerous, set())

    def test_push_argv_builder_rejects_dangerous_branch_names(self):
        for branch in ("+main", ":main", "--force", "a..b", "a:b", "", "--mirror",
                       "refs/heads/main:refs/heads/other"):
            with self.subTest(branch=branch):
                with self.assertRaises(gh_exec.Denied):
                    gh_exec.build_push_argv(branch=branch)

    def test_readonly_git_operand_forms_are_constrained(self):
        cases = (
            ["diff", "--name-only", "-main"],
            ["log", "--format", "%H", ":x"],
            ["rev-parse", "+HEAD"],
            ["show", "--format", "%H", "a;b"],
            ["status", "--porcelain", "$(whoami)"],
        )
        for args in cases:
            with self.subTest(args=args):
                with self.assertRaises(gh_exec.Denied):
                    gh_exec.run_git(args)
        self.assertNoSpawn()


# ===========================================================================
# TC-28: graphql / --cache が rule table に存在しない
# ===========================================================================

class RuleTableStructureTests(unittest.TestCase):
    """TC-28: rule table そのものへの構造的アサート。"""

    def test_no_rule_allows_graphql(self):
        for rule in gh_exec.GH_RULES:
            literals = [v for v in rule.verbs if isinstance(v, str)]
            self.assertNotIn("graphql", literals, rule.name)

    def test_no_rule_allows_cache_flag(self):
        for rule in gh_exec.GH_RULES:
            self.assertNotIn("--cache", dict(rule.flags), rule.name)

    def test_no_rule_allows_body_params_without_constraint(self):
        api = gh_exec.rule_by_name("api")
        cond_names = {name for name, _ in api.conditions}
        self.assertEqual(cond_names & set(gh_exec.API_GET_CONDITION_NAMES),
                         set(gh_exec.API_GET_CONDITION_NAMES))

    def test_every_flag_is_long_form(self):
        for rule in gh_exec.GH_RULES:
            for flag, _ in rule.flags:
                self.assertTrue(flag.startswith("--"), f"{rule.name}: {flag}")
        for rule in gh_exec.GIT_READ_RULES:
            for flag, _ in rule.flags:
                self.assertTrue(flag.startswith("--"), f"{rule.sub}: {flag}")

    def test_git_read_rules_cover_exactly_the_seven_readonly_subcommands(self):
        self.assertEqual(
            {r.sub for r in gh_exec.GIT_READ_RULES},
            {"rev-parse", "merge-base", "log", "status", "diff", "ls-remote", "show"})


# ===========================================================================
# TC-29 / T-14: gh api GET の正側 + 読み取り系 git の正側
# ===========================================================================

class PositiveAllowTests(SpyMixin, unittest.TestCase):
    """TC-29 / TC-14: 4 endpoint の GET と読み取り系 git 7 サブコマンドが allow。"""

    def test_four_api_endpoints_are_allowed(self):
        endpoints = (
            f"repos/{REPO}/commits/{SHA}/check-runs",
            f"repos/{REPO}/commits/0123abc/check-runs",
            f"repos/{REPO}/pulls/12345",
            f"repos/{REPO}/pulls/1/reviews",
            f"repos/{REPO}/pulls/1/reviews?per_page=100",
            f"repos/{REPO}/rules/branches/main",
            f"repos/{REPO}/rules/branches/feat/task-0917-delivery",
        )
        for ep in endpoints:
            with self.subTest(endpoint=ep):
                argv = gh_exec.authorize_gh(["api", ep, "--method", "GET"], repo=REPO)
                self.assertEqual(argv[:2], ["gh", "api"])
                # `--method` 省略（既定 GET）も allow
                gh_exec.authorize_gh(["api", ep], repo=REPO)
                gh_exec.authorize_gh(["api", ep, "--jq", ".[]"], repo=REPO)
                gh_exec.authorize_gh(["api", ep, "--paginate"], repo=REPO)

    def test_pr_view_json_fields_are_allowed(self):
        argv = gh_exec.authorize_gh(
            ["pr", "view", "1", "--json", "headRefName,baseRefName", "--repo", REPO],
            repo=REPO)
        self.assertEqual(argv, ["gh", "pr", "view", "1", "--json",
                                "headRefName,baseRefName", "--repo", REPO])

    def test_pr_view_rejects_unknown_json_field(self):
        with self.assertRaises(gh_exec.Denied):
            gh_exec.authorize_gh(["pr", "view", "1", "--json", "closingIssues"],
                                 repo=REPO)

    def test_pr_comment_with_wrapper_temp_body_file_is_allowed(self):
        path = gh_exec.make_comment_body_file("承認後に head が変わりました")
        self.assertTrue(path.exists())
        self.assertEqual(path.read_text(encoding="utf-8"),
                         "承認後に head が変わりました")
        argv = gh_exec.authorize_gh(
            ["pr", "comment", "1", "--body-file", str(path), "--repo", REPO],
            repo=REPO)
        self.assertIn("--body-file", argv)

    def test_comment_pr_helper_uses_wrapper_temp_file(self):
        gh_exec.comment_pr(repo=REPO, pr_number=1, body="hello")
        self.assertEqual(len(self.spy.calls), 1)
        argv = self.spy.calls[0][1]
        self.assertEqual(argv[:4], ["gh", "pr", "comment", "1"])
        self.assertIn("--body-file", argv)
        body_path = pathlib.Path(argv[argv.index("--body-file") + 1])
        self.assertEqual(body_path.read_text(encoding="utf-8"), "hello")

    def test_readonly_git_subcommands_are_allowed(self):
        for args in ALLOWED_GIT_COMMANDS:
            with self.subTest(args=args):
                argv = gh_exec.authorize_git(args)
                self.assertEqual(argv[0], "git")
                self.assertEqual(argv[1], args[0])


# ===========================================================================
# TC-30 / T-17: push_pr_head() の事前検査
# ===========================================================================

def _push_handler(*, head_ref="feat/task-0917-delivery", base_ref="main",
                  origin_url=f"git@github.com:{REPO}.git", ancestor_rc=0):
    def handler(argv):
        if argv[:3] == ["gh", "pr", "view"]:
            return _Completed(0, json.dumps(
                {"headRefName": head_ref, "baseRefName": base_ref}))
        if argv[:2] == ["git", "ls-remote"]:
            return _Completed(0, origin_url + "\n")
        if argv[:2] == ["git", "merge-base"]:
            return _Completed(ancestor_rc, "")
        if argv[:2] == ["git", "push"]:
            return _Completed(0, "pushed")
        raise AssertionError(f"想定外の argv: {argv}")
    return handler


class PushPreCheckTests(SpyMixin, unittest.TestCase):
    """TC-30: 4 つの事前検査のいずれかが不成立なら push に到達しない。"""

    BRANCH = "feat/task-0917-delivery"

    def _run_push(self, handler):
        self.spy = _SubprocessSpy(handler)
        gh_exec.subprocess = self.spy
        return gh_exec.push_pr_head(
            repo=REPO, branch=self.BRANCH, expected_parent_sha=SHA, cwd=str(HERE))

    def _pushed(self):
        return [c for c in self.spy.calls if c[1][:2] == ["git", "push"]]

    def test_happy_path_pushes_once(self):
        result = self._run_push(_push_handler())
        self.assertTrue(result.pushed)
        pushes = self._pushed()
        self.assertEqual(len(pushes), 1)
        self.assertEqual(pushes[0][1],
                         ["git", "push", "origin", f"HEAD:refs/heads/{self.BRANCH}"])

    def test_branch_mismatch_with_head_ref_name_refuses(self):
        with self.assertRaises(gh_exec.Denied):
            self._run_push(_push_handler(head_ref="other-branch"))
        self.assertEqual(self._pushed(), [])

    def test_branch_equal_to_base_ref_name_refuses(self):
        with self.assertRaises(gh_exec.Denied):
            self._run_push(_push_handler(head_ref=self.BRANCH, base_ref=self.BRANCH))
        self.assertEqual(self._pushed(), [])

    def test_origin_url_mismatch_refuses(self):
        for url in (f"git@github.com:{OTHER_REPO}.git",
                    f"https://github.com/{OTHER_REPO}",
                    "git@github.com:s977043/plangate-evil.git"):
            with self.subTest(url=url):
                with self.assertRaises(gh_exec.Denied):
                    self._run_push(_push_handler(origin_url=url))
                self.assertEqual(self._pushed(), [])

    def test_https_origin_url_is_accepted(self):
        result = self._run_push(
            _push_handler(origin_url=f"https://github.com/{REPO}.git"))
        self.assertTrue(result.pushed)

    def test_non_fast_forward_refuses(self):
        with self.assertRaises(gh_exec.Denied):
            self._run_push(_push_handler(ancestor_rc=1))
        self.assertEqual(self._pushed(), [])

    def test_default_branch_push_is_denied_even_if_gh_agrees(self):
        with self.assertRaises(gh_exec.Denied):
            self.spy = _SubprocessSpy(_push_handler(head_ref="main", base_ref="main"))
            gh_exec.subprocess = self.spy
            gh_exec.push_pr_head(repo=REPO, branch="main",
                                 expected_parent_sha=SHA, cwd=str(HERE))
        self.assertEqual(self._pushed(), [])

    def test_invalid_expected_parent_sha_refuses(self):
        for sha in ("", "zzzz", "12345", "../../etc", SHA + "0" * 5):
            with self.subTest(sha=sha):
                self.spy = _SubprocessSpy(_push_handler())
                gh_exec.subprocess = self.spy
                with self.assertRaises(gh_exec.Denied):
                    gh_exec.push_pr_head(repo=REPO, branch=self.BRANCH,
                                         expected_parent_sha=sha, cwd=str(HERE))
                self.assertEqual(self._pushed(), [])


# ===========================================================================
# 検出力の実証（変異注入 / 一時的な rule table 差し替えのみ）
# ===========================================================================

class MutationDetectionTests(SpyMixin, unittest.TestCase):
    """テストが空振りでないことを、rule table の変異注入で実証する。

    変異は `dataclasses.replace` による**一時オブジェクト**で行い、
    `gh_exec.py` 本体も作業ツリーのファイルも書き換えない。
    """

    def _mutate(self, rule_name, drop_condition):
        mutated = []
        for rule in gh_exec.GH_RULES:
            if rule.name == rule_name:
                kept = tuple(c for c in rule.conditions if c[0] != drop_condition)
                self.assertEqual(len(kept), len(rule.conditions) - 1,
                                 f"落とす条件 {drop_condition} が存在しない")
                rule = dataclasses.replace(rule, conditions=kept)
            mutated.append(rule)
        return tuple(mutated)

    def test_mutation_body_file_constraint_removed_allows_arbitrary_file(self):
        """`--body-file` の wrapper-temp 制約を外すと任意ファイルが通る。"""
        args = ["pr", "comment", "1", "--body-file", "/etc/passwd", "--repo", REPO]
        with self.assertRaises(gh_exec.Denied):
            gh_exec.authorize_gh(args, repo=REPO)                    # 実 table: deny
        mutant = self._mutate("pr comment", "body_file_wrapper_temp")
        argv = gh_exec.authorize_gh(args, repo=REPO, rules=mutant)   # 変異: allow
        self.assertIn("/etc/passwd", argv)

    def test_mutation_api_get_condition_removed_allows_post_promoting_params(self):
        """GET 強制 3 条件のうち `no_body_params` を外すと `--field`（= -f）が通る。

        短縮形 `-f` は正規化層で先に deny されるため、本変異注入では long 形
        `--field k=v`（`-f` と等価・gh は body param があると自動で POST へ昇格）
        を使って条件の実効性を示す。
        """
        args = ["api", f"repos/{REPO}/pulls/1", "--method", "GET", "--field", "k=v"]
        with self.assertRaises(gh_exec.Denied):
            gh_exec.authorize_gh(args, repo=REPO)
        mutant = self._mutate("api", "no_body_params")
        argv = gh_exec.authorize_gh(args, repo=REPO, rules=mutant)
        self.assertIn("--field", argv)

    def test_mutation_api_method_condition_removed_allows_post(self):
        args = ["api", f"repos/{REPO}/pulls/1", "--method", "POST"]
        with self.assertRaises(gh_exec.Denied):
            gh_exec.authorize_gh(args, repo=REPO)
        mutant = self._mutate("api", "method_is_get")
        self.assertIn("--method", gh_exec.authorize_gh(args, repo=REPO, rules=mutant))

    def test_mutation_api_endpoint_condition_removed_allows_merge_endpoint(self):
        args = ["api", f"repos/{REPO}/pulls/1/merge", "--method", "GET"]
        with self.assertRaises(gh_exec.Denied):
            gh_exec.authorize_gh(args, repo=REPO)
        mutant = self._mutate("api", "endpoint_bound")
        self.assertIn(f"repos/{REPO}/pulls/1/merge",
                      gh_exec.authorize_gh(args, repo=REPO, rules=mutant))


if __name__ == "__main__":
    unittest.main(verbosity=2)
