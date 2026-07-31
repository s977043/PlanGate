#!/usr/bin/env python3
"""test_collector.py — collector.py（snapshot 供給者 / AC-1・AC-2・AC-9・論点 D3）の unittest。

実行: python3 scripts/ai-loop/test_collector.py

契約正本: docs/working/TASK-0917/plan.md 論点 D3 / 「⚠️ 設計を変えた実測: Collector の
主経路は REST GET」/ Work Breakdown Step 5。
カバー: test-cases.md
  TC-01 / TC-01a / TC-01b / TC-01c / TC-02 / TC-03（AC-1: head SHA 束縛 + review 縮約）
  TC-04 / TC-05 / TC-06（AC-2: required_checks ⊇ 照合と取得失敗の fail-closed）
  TC-32 / TC-33 / TC-34（AC-9: raw check evidence の同梱と導出照合）
  TC-35 / TC-36（changed_files の実測供給と fail-open 封じ）
  TC-37 / TC-38（conflict_resolution は三点が揃うときのみ出力）
  TC-39（未完了 check-run の status → conclusion 写像）
  TC-E1 / TC-E2 / TC-E3（rate limit / timeout / ancestry 解決不能）

設計上の注意:
- **実ネットワークに出ない**。`gh_exec` は fixture（`FakeGh`）を注入して差し替え、
  `subprocess` は一度も呼ばれない（本ファイル自身も `check_exec_boundary.py` の
  検査対象であり、`subprocess` を import しない）。
- 変異注入は **monkeypatch（関数の差し替え）と一時 dict** のみで行い、作業ツリーの
  ファイルは 1 バイトも書き換えない。
- `delivery.py` は main の実物を呼ぶ（AC-7: 一行も変更しない）。
"""

from __future__ import annotations

import ast
import copy
import json
import pathlib
import sys
import tempfile
import unittest

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import collector  # noqa: E402
import delivery  # noqa: E402  判定エンジンの実物（AC-7: 変更しない）
import gh_exec  # noqa: E402  Denied / 例外型の単一定義

REPO = "s977043/plangate"
PR = 917
TASK = "TASK-0917"
H0 = "0" * 40  # 旧 head
H1 = "1" * 40  # 現 head
SRC = "a" * 40  # c3 の source_sha

PLAN_TEXT = """# EXECUTION PLAN — TASK-0917

## Files / Components to Touch

| # | ファイル | 種別 |
|---|---------|------|
| 1 | `scripts/ai-loop/collector.py` | 新設 |
| 2 | `scripts/ai-loop/test_collector.py` | 新設 |

## Testing Strategy
"""

PLAN_TEXT_NO_PATHS = "# EXECUTION PLAN\n\n## Goal\n\nなし\n"


# ---------------------------------------------------------------------------
# fixture: gh_exec の差し替え（実ネットワークに出ない）
# ---------------------------------------------------------------------------

class FakeProc:
    """`subprocess.CompletedProcess` の最小互換（returncode / stdout / stderr）。"""

    def __init__(self, returncode=0, stdout="", stderr=""):
        self.returncode = returncode
        self.stdout = stdout
        self.stderr = stderr


def _ok(payload) -> FakeProc:
    return FakeProc(0, json.dumps(payload))


class Boom(RuntimeError):
    """timeout / 実行不能 相当（`Denied` ではない例外 = retry 対象）。"""


class FakeGh:
    """`gh_exec` の代替。route 名 → 応答（FakeProc / 例外 / callable）で駆動する。

    route 名: pull / check-runs / reviews / rules / diff / ancestry
    """

    def __init__(self, routes):
        self.routes = dict(routes)
        self.gh_calls = []
        self.git_calls = []

    # -- route 解決 -------------------------------------------------------
    @staticmethod
    def _gh_route(args):
        if args and args[0] == "api":
            endpoint = args[1] if len(args) > 1 else ""
            if "/check-runs" in endpoint:
                return "check-runs"
            if "/reviews" in endpoint:
                return "reviews"
            if "/rules/branches/" in endpoint:
                return "rules"
            return "pull"
        return "gh:" + " ".join(map(str, args))

    @staticmethod
    def _git_route(args):
        if args and args[0] == "diff":
            return "diff"
        if args and args[0] == "merge-base":
            return "ancestry"
        return "git:" + " ".join(map(str, args))

    def _respond(self, route, args):
        if route not in self.routes:
            raise AssertionError(f"fixture 未定義の route: {route} ({args})")
        reply = self.routes[route]
        if callable(reply):
            reply = reply(args)
        if isinstance(reply, BaseException):
            raise reply
        return reply

    # -- gh_exec 互換 API -------------------------------------------------
    def run_gh(self, args, *, repo, cwd=None, rules=None):
        args = list(args)
        self.gh_calls.append((tuple(args), repo))
        return self._respond(self._gh_route(args), args)

    def run_git(self, args, *, cwd=None, rules=None):
        args = list(args)
        self.git_calls.append(tuple(args))
        return self._respond(self._git_route(args), args)


def _check_run(name, *, head_sha=H1, status="completed", conclusion="success",
               run_id=None, completed_at="2026-07-31T00:00:00Z"):
    return {
        "id": run_id if run_id is not None else abs(hash((name, head_sha))) % 10**7,
        "name": name,
        "head_sha": head_sha,
        "status": status,
        "conclusion": conclusion,
        "completed_at": completed_at,
    }


def _check_runs_payload(runs):
    return {"total_count": len(runs), "check_runs": list(runs)}


def _review(state, *, commit_id=H1, submitted_at="2026-07-31T00:00:00Z", rid=1):
    return {"id": rid, "state": state, "commit_id": commit_id,
            "submitted_at": submitted_at}


def _rules_payload(contexts):
    return [{
        "type": "required_status_checks",
        "parameters": {
            "required_status_checks": [{"context": c} for c in contexts],
        },
    }]


def _routes(*, check_runs=None, reviews=None, contexts=("A",),
            mergeable=True, changed=("scripts/ai-loop/collector.py",),
            ancestry_rc=0, base_ref="main"):
    runs = check_runs if check_runs is not None else [_check_run("A")]
    revs = reviews if reviews is not None else [_review("APPROVED")]
    return {
        "pull": _ok({"number": PR, "mergeable": mergeable,
                     "head": {"sha": H1}, "base": {"ref": base_ref}}),
        "check-runs": _ok(_check_runs_payload(runs)),
        "reviews": _ok(revs),
        "rules": _ok(_rules_payload(contexts)),
        "diff": FakeProc(0, "".join(p + "\n" for p in changed)),
        "ancestry": FakeProc(ancestry_rc, ""),
    }


def _collect(routes, *, plan_text=PLAN_TEXT, **kwargs):
    """既定では `dod_reevaluate` receipt を注入する（record I/O をテストしない回）。"""
    if "record_entries" not in kwargs and "record_path" not in kwargs:
        kwargs["record_entries"] = _merge_ready_entries()
    fake = FakeGh(routes)
    snapshot = collector.collect(
        task_id=TASK, repo=REPO, pr_number=PR, source_sha=SRC,
        plan_text=plan_text, gh=fake, **kwargs)
    return snapshot, fake


def _assess(snapshot, entries=()):
    return delivery.assess(snapshot, list(entries))


def _merge_ready_entries():
    """`dod_evaluated=True` を導出させる record entries（dod_reevaluate receipt）。"""
    return [{"kind": "receipt", "action_kind": "dod_reevaluate",
             "pr_number": PR, "head_sha": H1, "result_ref": "dod:ok"}]


# ---------------------------------------------------------------------------
# AC-1: head SHA 束縛 + review 縮約規則（TC-01 / TC-01a-c / TC-02 / TC-03）
# ---------------------------------------------------------------------------

class TestAc1HeadShaBinding(unittest.TestCase):
    """AC-1: snapshot が head SHA に束縛される（`checks[].sha` / `review.sha`）。"""

    def test_tc01_all_checks_bound_to_head_sha(self):
        snapshot, _ = _collect(_routes(check_runs=[
            _check_run("A"), _check_run("B")]))
        self.assertEqual([c["sha"] for c in snapshot["checks"]], [H1, H1])
        self.assertEqual(snapshot["head_sha"], H1)
        self.assertEqual(snapshot["review"]["sha"], H1)
        self.assertEqual(delivery.validate_snapshot(snapshot), [])

    def test_tc01a_review_state_lowercased(self):
        """REST の `APPROVED` を `approved` へ正規化する（delivery.py は小文字比較）。"""
        snapshot, _ = _collect(_routes(reviews=[_review("APPROVED")]))
        self.assertEqual(snapshot["review"]["state"], "approved")

    def test_tc01b_latest_non_dismissed_review_wins(self):
        snapshot, _ = _collect(_routes(reviews=[
            _review("COMMENTED", submitted_at="2026-07-31T00:00:00Z", rid=1),
            _review("APPROVED", submitted_at="2026-07-31T01:00:00Z", rid=2),
            _review("DISMISSED", submitted_at="2026-07-31T02:00:00Z", rid=3),
        ]))
        self.assertEqual(snapshot["review"], {"state": "approved", "sha": H1})

    def test_tc01c_old_head_approval_not_adopted(self):
        snapshot, _ = _collect(_routes(reviews=[
            _review("APPROVED", commit_id=H0)]))
        self.assertEqual(snapshot["review"], {"state": "none", "sha": H1})
        self.assertEqual(delivery.validate_snapshot(snapshot), [])
        self.assertEqual(_assess(snapshot)["state"], "WAITING_FOR_REVIEW")

    def test_tc02_stale_check_runs_excluded(self):
        """旧 head の check-run は `checks[]` に採用しない → WAITING_FOR_CHECKS。"""
        snapshot, _ = _collect(_routes(check_runs=[
            _check_run("A", head_sha=H0, conclusion="failure"),
        ]))
        self.assertEqual(snapshot["checks"], [])
        self.assertEqual(snapshot["escalation_flags"], [])
        self.assertEqual(_assess(snapshot)["state"], "WAITING_FOR_CHECKS")

    def test_tc02_mixed_heads_only_current_adopted(self):
        snapshot, _ = _collect(_routes(check_runs=[
            _check_run("A", head_sha=H0, conclusion="failure"),
            _check_run("A", head_sha=H1, conclusion="success"),
        ]))
        self.assertEqual([(c["name"], c["sha"], c["conclusion"])
                          for c in snapshot["checks"]], [("A", H1, "success")])

    def test_tc03_status_check_rollup_not_on_snapshot_path(self):
        """`gh pr view --json statusCheckRollup` を経路に使っていない（設計固定）。

        docstring では**根拠として言及する**ため、判定は AST で
        「docstring 以外の文字列リテラル」に限定する（substring 走査を使わない）。
        """
        source = (HERE / "collector.py").read_text(encoding="utf-8")
        tree = ast.parse(source)
        docstrings = set()
        for node in ast.walk(tree):
            if isinstance(node, (ast.Module, ast.ClassDef, ast.FunctionDef,
                                 ast.AsyncFunctionDef)):
                doc = ast.get_docstring(node, clean=False)
                if doc is not None:
                    docstrings.add(doc)
        live = [n.value for n in ast.walk(tree)
                if isinstance(n, ast.Constant) and isinstance(n.value, str)
                and n.value not in docstrings]
        for token in ("statusCheckRollup", "latestReviews", "pr view", "pr checks"):
            self.assertFalse([s for s in live if token in s],
                             f"snapshot 生成経路に {token} を使っている")
        self.assertIn("statusCheckRollup", ast.get_docstring(tree) or "",
                      "設計根拠（per-check の sha を持たない）が docstring に無い")

    def test_only_rest_get_endpoints_are_called(self):
        """Collector が叩くのは REST GET 4 本のみ（gh pr view / checks を使わない）。"""
        _, fake = _collect(_routes())
        self.assertTrue(fake.gh_calls)
        for args, repo in fake.gh_calls:
            self.assertEqual(args[0], "api", f"gh api 以外を呼んでいる: {args}")
            self.assertEqual(repo, REPO)
            # 実際に gh_exec の allowlist を通ることを実物で照合する
            gh_exec.authorize_gh(list(args), repo=REPO)


# ---------------------------------------------------------------------------
# AC-2: required_checks ⊇ 照合（TC-04 / TC-05 / TC-06）
# ---------------------------------------------------------------------------

class TestAc2RequiredChecks(unittest.TestCase):
    """AC-2: required checks の ⊇ 照合（Collector pre-check / D1-A）。"""

    def test_tc04_partial_registration_green_is_escalated(self):
        snapshot, _ = _collect(_routes(contexts=("A", "B"),
                                       check_runs=[_check_run("A")]))
        self.assertIn(f"{collector.FLAG_REQUIRED_CHECKS_MISSING}:B",
                      snapshot["escalation_flags"])
        result = _assess(snapshot, _merge_ready_entries())
        self.assertEqual(result["state"], "HUMAN_ESCALATED")

    def test_tc04_mutation_removing_supset_check_reaches_merge_ready(self):
        """検出力の実証: ⊇ 照合を外すと部分登録 green が `MERGE_READY` に到達する。"""
        snapshot, _ = _collect(_routes(contexts=("A", "B"),
                                       check_runs=[_check_run("A")]))
        mutated = copy.deepcopy(snapshot)
        mutated["escalation_flags"] = [
            f for f in mutated["escalation_flags"]
            if not f.startswith(collector.FLAG_REQUIRED_CHECKS_MISSING)]
        self.assertEqual(_assess(mutated, _merge_ready_entries())["state"],
                         "MERGE_READY")

    def test_tc05_all_required_present(self):
        snapshot, _ = _collect(_routes(
            contexts=("A", "B"),
            check_runs=[_check_run("A"), _check_run("B")]))
        self.assertEqual(snapshot["escalation_flags"], [])
        self.assertEqual(_assess(snapshot, _merge_ready_entries())["state"],
                         "MERGE_READY")

    def test_tc05_superset_is_allowed(self):
        """`checks[]` が required の真の上位集合でも通す（⊇ であって = ではない）。"""
        snapshot, _ = _collect(_routes(
            contexts=("A",), check_runs=[_check_run("A"), _check_run("extra")]))
        self.assertEqual(snapshot["escalation_flags"], [])

    def test_tc06_fetch_failure_is_fail_closed(self):
        """403 / rate limit / 想定外形式は config fallback を使わず fail-closed。"""
        cases = {
            "403": FakeProc(1, "", "HTTP 403: Resource not accessible"),
            "rate limit": FakeProc(1, "", "API rate limit exceeded"),
            "unexpected": _ok({"unexpected": "shape"}),
            "broken json": FakeProc(0, "{not json"),
            "denied": gh_exec.Denied(gh_exec.REASON_CONSTRAINT, "endpoint 外"),
        }
        for label, reply in cases.items():
            with self.subTest(label=label):
                routes = _routes(contexts=("A",))
                routes["rules"] = reply
                snapshot, _ = _collect(routes)
                flags = [f for f in snapshot["escalation_flags"]
                         if f.startswith(collector.FLAG_REQUIRED_CHECKS_FETCH_FAILED)]
                self.assertEqual(len(flags), 1, snapshot["escalation_flags"])
                # snapshot は破棄せず assess() を通す（record に state entry が残る）
                self.assertEqual(delivery.validate_snapshot(snapshot), [])
                result = _assess(snapshot, _merge_ready_entries())
                self.assertEqual(result["state"], "HUMAN_ESCALATED")
                self.assertTrue([e for e in result["new_entries"]
                                 if e.get("kind") == "state"])

    def test_tc06_no_config_fallback_symbol(self):
        """取得失敗時に読みにいく config / キャッシュ経路が存在しないこと。"""
        source = (HERE / "collector.py").read_text(encoding="utf-8")
        tree = ast.parse(source)
        names = {n.id for n in ast.walk(tree) if isinstance(n, ast.Name)}
        names |= {n.attr for n in ast.walk(tree) if isinstance(n, ast.Attribute)}
        for banned in ("REQUIRED_CHECKS_FALLBACK", "DEFAULT_REQUIRED_CHECKS",
                       "required_checks_cache"):
            self.assertNotIn(banned, names)

    def test_empty_ruleset_means_no_required_checks(self):
        """required_status_checks ルールが 0 件なら ⊇ は自明に成立（実 config 状態）。"""
        routes = _routes()
        routes["rules"] = _ok([])
        snapshot, _ = _collect(routes)
        self.assertEqual(snapshot["escalation_flags"], [])
        self.assertEqual(snapshot["required_checks"], [])

    def test_missing_required_not_flagged_while_checks_in_flight(self):
        """⊇ 照合は check 集合が settled のときだけ発火する（AC-4 の 1 周を殺さない）。

        repair push 直後は required check がまだ 1 件も登録されていない / pending の
        ため、常時発火させると `WAITING_FOR_CHECKS` に倒れるべき局面まで
        `HUMAN_ESCALATED` になり「repair → 最新 head 再評価」が回らなくなる。
        settled でない間は `waiting_checks` が先に立つので merge 側へ fail-open に
        ならない（下の 2 ケースがそれを示す）。
        """
        cases = {
            "未登録": [],
            "pending 混在": [_check_run("A"),
                              _check_run("B", status="in_progress",
                                         conclusion=None)],
        }
        for label, runs in cases.items():
            with self.subTest(label=label):
                snapshot, _ = _collect(_routes(contexts=("A", "B"),
                                               check_runs=runs))
                self.assertEqual(snapshot["escalation_flags"], [])
                self.assertEqual(_assess(snapshot, _merge_ready_entries())["state"],
                                 "WAITING_FOR_CHECKS")

    def test_required_checks_union_across_rules(self):
        """複数の required_status_checks ルールは union で扱う。"""
        routes = _routes(check_runs=[_check_run("A")])
        routes["rules"] = _ok(_rules_payload(("A",)) + _rules_payload(("B", "A")))
        snapshot, _ = _collect(routes)
        self.assertEqual(snapshot["required_checks"], ["A", "B"])
        self.assertIn(f"{collector.FLAG_REQUIRED_CHECKS_MISSING}:B",
                      snapshot["escalation_flags"])


# ---------------------------------------------------------------------------
# AC-9: raw check evidence（TC-32 / TC-33 / TC-34）
# ---------------------------------------------------------------------------

class TestAc9RawEvidence(unittest.TestCase):
    """AC-9（縮小実施）: raw 同梱 + `checks[]` の導出照合。

    限界: 本 AC は **Collector が生成した snapshot の内部整合**まで。手作りの
    snapshot を `delivery.py` へ直接投入する経路は塞がない。
    """

    def test_tc32_raw_embedded_and_derivation_verified(self):
        raw = [_check_run("A", run_id=11), _check_run("B", run_id=12,
                                                      conclusion="neutral")]
        snapshot, _ = _collect(_routes(check_runs=raw, contexts=("A", "B")))
        embedded = snapshot[collector.RAW_CHECK_RUNS_KEY]
        self.assertEqual([e["id"] for e in embedded], [11, 12])
        for entry in embedded:
            for key in ("id", "name", "head_sha", "status", "conclusion",
                        "completed_at"):
                self.assertIn(key, entry)
        self.assertEqual([c["check_run_id"] for c in snapshot["checks"]], [11, 12])
        self.assertEqual(collector.verify_snapshot_evidence(snapshot), [])
        self.assertEqual(snapshot["escalation_flags"], [])

    def test_tc33_tampered_checks_rejected(self):
        raw = [_check_run("A", run_id=11, conclusion="failure")]
        snapshot, _ = _collect(_routes(check_runs=raw, contexts=("A",)))
        tampered = copy.deepcopy(snapshot)
        tampered["checks"][0]["conclusion"] = "success"
        flags = collector.verify_snapshot_evidence(tampered)
        self.assertEqual(flags, [f"{collector.FLAG_RAW_EVIDENCE_MISMATCH}:A"])
        tampered["escalation_flags"] = list(tampered["escalation_flags"]) + flags
        self.assertEqual(_assess(tampered, _merge_ready_entries())["state"],
                         "HUMAN_ESCALATED")

    def test_tc33_tampered_sha_rejected(self):
        """改竄が sha 側（旧 head を現 head に見せかける）でも検出する。"""
        snapshot, _ = _collect(_routes(check_runs=[_check_run("A", run_id=11)]))
        tampered = copy.deepcopy(snapshot)
        tampered[collector.RAW_CHECK_RUNS_KEY][0]["head_sha"] = H0
        self.assertEqual(collector.verify_snapshot_evidence(tampered),
                         [f"{collector.FLAG_RAW_EVIDENCE_MISMATCH}:A"])

    def test_tc34_missing_raw_entry_rejected(self):
        """raw が無いことを「照合 OK」と扱わない（fail-closed）。"""
        snapshot, _ = _collect(_routes(check_runs=[_check_run("A", run_id=11)]))
        stripped = copy.deepcopy(snapshot)
        stripped[collector.RAW_CHECK_RUNS_KEY] = []
        flags = collector.verify_snapshot_evidence(stripped)
        self.assertEqual(flags, [f"{collector.FLAG_RAW_EVIDENCE_MISSING}:A"])
        stripped["escalation_flags"] = list(stripped["escalation_flags"]) + flags
        self.assertEqual(_assess(stripped, _merge_ready_entries())["state"],
                         "HUMAN_ESCALATED")

    def test_tc34_missing_raw_key_rejected(self):
        snapshot, _ = _collect(_routes(check_runs=[_check_run("A", run_id=11)]))
        stripped = copy.deepcopy(snapshot)
        del stripped[collector.RAW_CHECK_RUNS_KEY]
        self.assertEqual(collector.verify_snapshot_evidence(stripped),
                         [f"{collector.FLAG_RAW_EVIDENCE_MISSING}:A"])

    def test_collector_self_check_runs_on_build(self):
        """照合は Collector 内で自動実行される（呼び忘れを設計で許さない）。"""
        original = collector.checks_from_raw

        def tampering(raw_entries, head_sha):
            checks, flags = original(raw_entries, head_sha)
            for check in checks:
                check["conclusion"] = "success"
            return checks, flags

        collector.checks_from_raw = tampering
        try:
            snapshot, _ = _collect(_routes(check_runs=[
                _check_run("A", run_id=11, conclusion="failure")]))
        finally:
            collector.checks_from_raw = original
        self.assertIn(f"{collector.FLAG_RAW_EVIDENCE_MISMATCH}:A",
                      snapshot["escalation_flags"])
        self.assertEqual(_assess(snapshot, _merge_ready_entries())["state"],
                         "HUMAN_ESCALATED")

    def test_ac9_limitation_documented(self):
        doc = ast.get_docstring(ast.parse(
            (HERE / "collector.py").read_text(encoding="utf-8"))) or ""
        self.assertIn("手作り", doc)
        self.assertIn("delivery.py", doc)


# ---------------------------------------------------------------------------
# source_sha_ancestry / dod_evaluated / allowed_paths（D3）
# ---------------------------------------------------------------------------

class TestD3SuppliedKeys(unittest.TestCase):
    """論点 D3: 非 GitHub 由来キーの供給経路。"""

    def test_ancestry_three_valued(self):
        """exit 0 → True / 1 → False / それ以外 → None（TC-E3）。"""
        expected = {0: True, 1: False, 128: None, 129: None}
        for rc, want in expected.items():
            with self.subTest(rc=rc):
                snapshot, fake = _collect(_routes(ancestry_rc=rc))
                self.assertIs(snapshot["source_sha_ancestry"], want)
                self.assertIn(("merge-base", "--is-ancestor", SRC, H1),
                              fake.git_calls)

    def test_ancestry_denied_is_none(self):
        routes = _routes()
        routes["ancestry"] = gh_exec.Denied(gh_exec.REASON_SLOT, "operand 不正")
        snapshot, _ = _collect(routes)
        self.assertIsNone(snapshot["source_sha_ancestry"])
        self.assertEqual(_assess(snapshot, _merge_ready_entries())["state"],
                         "HUMAN_ESCALATED")

    def test_ancestry_false_is_fail_closed(self):
        snapshot, _ = _collect(_routes(ancestry_rc=1))
        self.assertEqual(_assess(snapshot, _merge_ready_entries())["state"],
                         "HUMAN_ESCALATED")

    def test_dod_evaluated_true_when_receipt_bound_to_head(self):
        self.assertTrue(collector.derive_dod_evaluated(
            _merge_ready_entries(), PR, H1))

    def test_dod_evaluated_false_cases(self):
        cases = {
            "未存在": [],
            "旧 head": [{"kind": "receipt", "action_kind": "dod_reevaluate",
                         "pr_number": PR, "head_sha": H0}],
            "別 PR": [{"kind": "receipt", "action_kind": "dod_reevaluate",
                        "pr_number": 1, "head_sha": H1}],
            "intent のみ": [{"kind": "intent", "action_kind": "dod_reevaluate",
                             "pr_number": PR, "head_sha": H1}],
            "直近が旧 head": [
                {"kind": "receipt", "action_kind": "dod_reevaluate",
                 "pr_number": PR, "head_sha": H1},
                {"kind": "receipt", "action_kind": "dod_reevaluate",
                 "pr_number": PR, "head_sha": H0},
            ],
        }
        for label, entries in cases.items():
            with self.subTest(label=label):
                self.assertFalse(collector.derive_dod_evaluated(entries, PR, H1))

    def test_dod_evaluated_flows_into_snapshot(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = pathlib.Path(tmp) / "record.jsonl"
            path.write_text("".join(
                json.dumps(e, sort_keys=True) + "\n" for e in _merge_ready_entries()),
                encoding="utf-8")
            snapshot, _ = _collect(_routes(), record_path=path)
        self.assertTrue(snapshot["dod_evaluated"])
        self.assertEqual(_assess(snapshot)["state"], "MERGE_READY")

    def test_broken_record_is_fail_closed(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = pathlib.Path(tmp) / "record.jsonl"
            path.write_text("{壊れた\n", encoding="utf-8")
            snapshot, _ = _collect(_routes(), record_path=path)
        self.assertFalse(snapshot["dod_evaluated"])
        self.assertTrue([f for f in snapshot["escalation_flags"]
                         if f.startswith(collector.FLAG_RECORD_UNREADABLE)])
        self.assertEqual(_assess(snapshot)["state"], "HUMAN_ESCALATED")

    def test_allowed_paths_extracted_from_plan(self):
        snapshot, _ = _collect(_routes())
        self.assertEqual(snapshot["allowed_paths"],
                         ["scripts/ai-loop/collector.py",
                          "scripts/ai-loop/test_collector.py"])

    def test_allowed_paths_zero_extraction_is_escalated(self):
        """抽出 0 件は `escalation_flags` へ（破棄・例外 exit しない）。

        `changed_files` が空でないときは `plan_deviation`（優先度 2）が
        `escalation_flags`（優先度 3）より先に立つため `EXEC_RETURN`。
        いずれにせよ `MERGE_READY` には到達しない（fail-closed）。
        """
        snapshot, _ = _collect(_routes(), plan_text=PLAN_TEXT_NO_PATHS)
        self.assertEqual(snapshot["allowed_paths"], [])
        self.assertIn(collector.FLAG_ALLOWED_PATHS_EMPTY,
                      snapshot["escalation_flags"])
        self.assertEqual(delivery.validate_snapshot(snapshot), [])
        self.assertEqual(_assess(snapshot, _merge_ready_entries())["state"],
                         "EXEC_RETURN")

        no_diff, _ = _collect(_routes(changed=()), plan_text=PLAN_TEXT_NO_PATHS)
        self.assertEqual(no_diff["changed_files"], [])
        self.assertEqual(_assess(no_diff, _merge_ready_entries())["state"],
                         "HUMAN_ESCALATED")

    def test_allowed_paths_uses_plan_package(self):
        """抽出は `plan_package.extract_allowed_paths` を再利用する（再実装しない）。"""
        import plan_package
        self.assertEqual(collector.extract_allowed_paths(PLAN_TEXT),
                         plan_package.extract_allowed_paths(PLAN_TEXT))


# ---------------------------------------------------------------------------
# changed_files / conflict_resolution / status 写像（TC-35〜TC-39）
# ---------------------------------------------------------------------------

class TestSnapshotSupplyContract(unittest.TestCase):
    """AC 横断: snapshot 供給契約の健全性（R-017 / R-019 / R-026）。"""

    def test_tc35_changed_files_from_read_only_git(self):
        snapshot, fake = _collect(_routes(changed=(
            "scripts/ai-loop/collector.py", "scripts/ai-loop/test_collector.py")))
        self.assertEqual(snapshot["changed_files"],
                         ["scripts/ai-loop/collector.py",
                          "scripts/ai-loop/test_collector.py"])
        diff_calls = [c for c in fake.git_calls if c[0] == "diff"]
        self.assertEqual(len(diff_calls), 1)
        self.assertEqual(diff_calls[0][:2], ("diff", "--name-only"))
        self.assertEqual(diff_calls[0][2], f"origin/main...{H1}")
        gh_exec.authorize_git(list(diff_calls[0]))

    def test_tc36_changed_files_failure_is_fail_closed(self):
        for label, reply in {
            "非 0 終了": FakeProc(128, "", "fatal: bad revision"),
            "実行不能": Boom("git がない"),
            "denied": gh_exec.Denied(gh_exec.REASON_SLOT, "operand 不正"),
        }.items():
            with self.subTest(label=label):
                routes = _routes()
                routes["diff"] = reply
                snapshot, _ = _collect(routes)
                self.assertEqual(snapshot["changed_files"], [])
                self.assertTrue(
                    [f for f in snapshot["escalation_flags"]
                     if f.startswith(collector.FLAG_CHANGED_FILES_UNAVAILABLE)])
                self.assertEqual(_assess(snapshot, _merge_ready_entries())["state"],
                                 "HUMAN_ESCALATED")

    def test_tc36_mutation_empty_changed_files_is_fail_open(self):
        """検出力の実証: 空リストで埋めると `plan_deviation` が恒久的に不発になる。"""
        snapshot, _ = _collect(_routes(changed=("docs/other/leak.md",)))
        self.assertEqual(_assess(snapshot)["state"], "EXEC_RETURN")
        mutated = copy.deepcopy(snapshot)
        mutated["changed_files"] = []
        mutated["escalation_flags"] = []
        self.assertEqual(_assess(mutated, _merge_ready_entries())["state"],
                         "MERGE_READY")

    def test_tc37_conflict_resolution_emitted_only_when_complete(self):
        cr = {"base_sha": H0, "head_sha": H1, "result_sha": "c" * 40}
        snapshot, _ = _collect(_routes(mergeable=False), conflict_resolution=cr)
        self.assertEqual(snapshot["conflict_resolution"], cr)

    def test_tc37_partial_conflict_resolution_is_not_emitted(self):
        for label, cr in {
            "result 欠落": {"base_sha": H0, "head_sha": H1},
            "空文字": {"base_sha": H0, "head_sha": H1, "result_sha": ""},
            "空 dict": {},
            "dict でない": "resolved",
        }.items():
            with self.subTest(label=label):
                snapshot, _ = _collect(_routes(mergeable=False),
                                       conflict_resolution=cr)
                self.assertNotIn("conflict_resolution", snapshot)

    def test_tc38_key_absent_when_no_conflict(self):
        snapshot, _ = _collect(_routes())
        self.assertNotIn("conflict_resolution", snapshot)
        self.assertEqual(_assess(snapshot, _merge_ready_entries())["state"],
                         "MERGE_READY")

    def test_tc38_mutation_always_emitting_causes_permanent_conflict(self):
        """検出力の実証: 常時出力すると `cr_incomplete` でどの PR も CONFLICT になる。"""
        snapshot, _ = _collect(_routes())
        mutated = copy.deepcopy(snapshot)
        mutated["conflict_resolution"] = {}
        self.assertEqual(_assess(mutated, _merge_ready_entries())["state"],
                         "CONFLICT")

    def test_tc39_status_mapped_to_conclusion(self):
        for status in ("queued", "in_progress"):
            with self.subTest(status=status):
                snapshot, _ = _collect(_routes(check_runs=[
                    _check_run("A", status=status, conclusion=None,
                               completed_at=None)]))
                self.assertEqual(snapshot["checks"][0]["conclusion"], status)
                self.assertEqual(delivery.validate_snapshot(snapshot), [])
                self.assertEqual(_assess(snapshot, _merge_ready_entries())["state"],
                                 "WAITING_FOR_CHECKS")

    def test_tc39_mutation_without_mapping_never_reaches_waiting(self):
        """検出力の実証: 写像を外すと `conclusion=None` で WAITING に到達しない。"""
        naive = [{"name": "A", "sha": H1, "conclusion": None}]
        base, _ = _collect(_routes(check_runs=[
            _check_run("A", status="in_progress", conclusion=None)]))
        mutated = copy.deepcopy(base)
        mutated["checks"] = naive
        reasons = delivery.validate_snapshot(mutated)
        self.assertTrue([r for r in reasons if "checks" in r], reasons)
        with self.assertRaises(delivery.SnapshotError):
            _assess(mutated, _merge_ready_entries())

        original = collector.conclusion_for
        collector.conclusion_for = lambda entry: entry.get("conclusion")
        try:
            broken, _ = _collect(_routes(check_runs=[
                _check_run("A", status="in_progress", conclusion=None)]))
        finally:
            collector.conclusion_for = original
        self.assertNotEqual(_assess(broken, _merge_ready_entries())["state"],
                            "WAITING_FOR_CHECKS")

    def test_r018_mutation_without_lowercase_never_reaches_merge_ready(self):
        """検出力の実証: `state.lower()` を外すと `review_ok` が常に False。"""
        original = collector.reduce_review

        def upper(raw_reviews, head_sha):
            review = original(raw_reviews, head_sha)
            return {**review, "state": review["state"].upper()}

        collector.reduce_review = upper
        try:
            broken, _ = _collect(_routes())
        finally:
            collector.reduce_review = original
        self.assertEqual(broken["review"]["state"], "APPROVED")
        self.assertEqual(_assess(broken, _merge_ready_entries())["state"],
                         "WAITING_FOR_REVIEW")

    def test_mergeable_normalized_to_enum(self):
        for value, want in ((True, "MERGEABLE"), (False, "CONFLICTING"),
                            (None, "UNKNOWN"), ("MERGEABLE", "MERGEABLE"),
                            ("CONFLICTING", "CONFLICTING"), ("weird", "UNKNOWN")):
            with self.subTest(value=value):
                snapshot, _ = _collect(_routes(mergeable=value))
                self.assertEqual(snapshot["mergeable"], want)
                self.assertIn(snapshot["mergeable"], delivery.MERGEABLE_VALID)

    def test_required_keys_present(self):
        snapshot, _ = _collect(_routes())
        for key in collector.REQUIRED_SNAPSHOT_KEYS:
            self.assertIn(key, snapshot)
        self.assertEqual(len(collector.REQUIRED_SNAPSHOT_KEYS), 12)
        self.assertEqual(delivery.validate_snapshot(snapshot), [])

    def test_ci_taxonomy_key_absent_when_unresolved(self):
        snapshot, _ = _collect(_routes(check_runs=[
            _check_run("A", conclusion="failure")]))
        self.assertNotIn("ci_failure_taxonomy", snapshot)
        self.assertEqual(_assess(snapshot, _merge_ready_entries())["state"],
                         "HUMAN_ESCALATED")

    def test_ci_taxonomy_applied_from_log(self):
        snapshot, _ = _collect(
            _routes(check_runs=[_check_run("A", conclusion="failure")]),
            ci_log_text="Error: API rate limit exceeded")
        self.assertEqual(snapshot["ci_failure_taxonomy"], "environment")
        self.assertEqual(_assess(snapshot, _merge_ready_entries())["state"],
                         "CHECKS_FAILED")


# ---------------------------------------------------------------------------
# エッジケース（TC-E1 / TC-E2）
# ---------------------------------------------------------------------------

class TestEdgeCases(unittest.TestCase):

    def test_tce1_check_runs_rate_limit(self):
        routes = _routes()
        routes["check-runs"] = FakeProc(1, "", "API rate limit exceeded")
        snapshot, _ = _collect(routes)
        self.assertEqual(snapshot["checks"], [])
        self.assertTrue([f for f in snapshot["escalation_flags"]
                         if f.startswith(collector.FLAG_CHECK_RUNS_FETCH_FAILED)])
        self.assertEqual(_assess(snapshot, _merge_ready_entries())["state"],
                         "HUMAN_ESCALATED")

    def test_tce2_timeout_retries_then_fails_closed(self):
        calls = {"n": 0}

        def boom(_args):
            calls["n"] += 1
            raise Boom("timeout")

        routes = _routes()
        routes["reviews"] = boom
        snapshot, _ = _collect(routes)
        self.assertEqual(calls["n"], collector.FETCH_ATTEMPTS)
        self.assertGreater(collector.FETCH_ATTEMPTS, 1)
        self.assertTrue([f for f in snapshot["escalation_flags"]
                         if f.startswith(collector.FLAG_REVIEWS_FETCH_FAILED)])
        self.assertEqual(snapshot["review"], {"state": "none", "sha": H1})
        self.assertEqual(_assess(snapshot, _merge_ready_entries())["state"],
                         "HUMAN_ESCALATED")

    def test_denied_is_not_retried(self):
        calls = {"n": 0}

        def denied(_args):
            calls["n"] += 1
            raise gh_exec.Denied(gh_exec.REASON_CONSTRAINT, "endpoint 外")

        routes = _routes()
        routes["reviews"] = denied
        _collect(routes)
        self.assertEqual(calls["n"], 1)

    def test_pull_fetch_failure_uses_expected_head_sha(self):
        routes = _routes()
        routes["pull"] = FakeProc(1, "", "HTTP 502")
        snapshot, _ = _collect(routes, expected_head_sha=H1, base_ref="main")
        self.assertEqual(snapshot["head_sha"], H1)
        self.assertEqual(snapshot["mergeable"], "UNKNOWN")
        self.assertTrue([f for f in snapshot["escalation_flags"]
                         if f.startswith(collector.FLAG_PULL_FETCH_FAILED)])
        self.assertEqual(_assess(snapshot, _merge_ready_entries())["state"],
                         "HUMAN_ESCALATED")

    def test_pull_fetch_failure_without_fallback_raises(self):
        routes = _routes()
        routes["pull"] = FakeProc(1, "", "HTTP 502")
        with self.assertRaises(collector.CollectorError):
            _collect(routes)

    def test_paginated_responses_are_merged(self):
        """`--paginate` の連結 JSON を全件マージする（最新 review を取りこぼさない）。"""
        routes = _routes()
        routes["reviews"] = FakeProc(0, json.dumps([
            _review("COMMENTED", submitted_at="2026-07-31T00:00:00Z", rid=1),
        ]) + "\n" + json.dumps([
            _review("APPROVED", submitted_at="2026-07-31T05:00:00Z", rid=2),
        ]))
        routes["check-runs"] = FakeProc(0, json.dumps(
            _check_runs_payload([_check_run("A", run_id=1)])) + "\n" + json.dumps(
            _check_runs_payload([_check_run("B", run_id=2)])))
        snapshot, _ = _collect(routes)
        self.assertEqual(snapshot["review"]["state"], "approved")
        self.assertEqual([c["name"] for c in snapshot["checks"]], ["A", "B"])

    def test_unparsable_check_run_is_dropped_with_flag(self):
        routes = _routes(check_runs=[
            _check_run("A"),
            {"id": 9, "name": "B", "head_sha": H1, "status": "completed",
             "conclusion": None},
        ])
        snapshot, _ = _collect(routes)
        self.assertEqual([c["name"] for c in snapshot["checks"]], ["A"])
        self.assertTrue([f for f in snapshot["escalation_flags"]
                         if f.startswith(collector.FLAG_CHECK_RUN_UNPARSABLE)])
        self.assertEqual(delivery.validate_snapshot(snapshot), [])

    def test_snapshot_is_json_serializable(self):
        snapshot, _ = _collect(_routes())
        json.loads(json.dumps(snapshot, sort_keys=True))


# ---------------------------------------------------------------------------
# I/O 層と純関数層の分離（T-26）
# ---------------------------------------------------------------------------

class TestLayerSeparation(unittest.TestCase):
    """純関数層は raw JSON dict を受け取り、gh / git を一切呼ばない（discovery.py 慣習）。"""

    def test_build_snapshot_is_pure(self):
        raw = collector.RawInputs(
            head_sha=H1, base_ref="main",
            pull=collector.Fetched({"mergeable": True}),
            check_runs=collector.Fetched([_check_run("A")]),
            reviews=collector.Fetched([_review("APPROVED")]),
            required_checks=collector.Fetched(["A"]),
            changed_files=collector.Fetched(["scripts/ai-loop/collector.py"]),
            ancestry=collector.Fetched(True))
        snapshot = collector.build_snapshot(
            task_id=TASK, pr_number=PR, head_sha=H1, raw=raw,
            plan_text=PLAN_TEXT, record_entries=_merge_ready_entries())
        self.assertEqual(delivery.validate_snapshot(snapshot), [])
        self.assertEqual(_assess(snapshot)["state"], "MERGE_READY")

    def test_build_snapshot_is_deterministic(self):
        raw = collector.RawInputs(
            head_sha=H1, base_ref="main",
            pull=collector.Fetched({"mergeable": True}),
            check_runs=collector.Fetched([_check_run("A")]),
            reviews=collector.Fetched([_review("APPROVED")]),
            required_checks=collector.Fetched(["A"]),
            changed_files=collector.Fetched(["scripts/ai-loop/collector.py"]),
            ancestry=collector.Fetched(True))
        first = collector.build_snapshot(
            task_id=TASK, pr_number=PR, head_sha=H1, raw=raw, plan_text=PLAN_TEXT)
        second = collector.build_snapshot(
            task_id=TASK, pr_number=PR, head_sha=H1, raw=raw, plan_text=PLAN_TEXT)
        self.assertEqual(json.dumps(first, sort_keys=True),
                         json.dumps(second, sort_keys=True))

    def test_pure_layer_functions_take_plain_data(self):
        checks, flags = collector.checks_from_raw([_check_run("A")], H1)
        self.assertEqual(flags, [])
        self.assertEqual(checks[0]["name"], "A")
        self.assertEqual(collector.reduce_review([], H1),
                         {"state": "none", "sha": H1})
        self.assertEqual(collector.missing_required_checks(["A", "B"], checks), ["B"])
        self.assertEqual(collector.normalize_mergeable(True), "MERGEABLE")
        self.assertEqual(collector.conclusion_for(
            _check_run("A", status="queued", conclusion=None)), "queued")

    def test_io_layer_is_the_only_gh_caller(self):
        """`gh` / `git` を呼ぶのは I/O 層の関数だけ（純関数層から呼ばない）。"""
        tree = ast.parse((HERE / "collector.py").read_text(encoding="utf-8"))
        callers = set()
        for func in ast.walk(tree):
            if not isinstance(func, (ast.FunctionDef, ast.AsyncFunctionDef)):
                continue
            for node in ast.walk(func):
                if (isinstance(node, ast.Attribute)
                        and node.attr in ("run_gh", "run_git")):
                    callers.add(func.name)
        self.assertTrue(callers)
        self.assertTrue(callers <= collector.IO_LAYER_FUNCTIONS,
                        f"純関数層が gh/git を呼んでいる: "
                        f"{sorted(callers - collector.IO_LAYER_FUNCTIONS)}")
        for name in collector.PURE_LAYER_FUNCTIONS:
            self.assertNotIn(name, callers)


if __name__ == "__main__":
    unittest.main(verbosity=2)
