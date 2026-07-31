#!/usr/bin/env python3
"""test_plan_package.py — plan_package.py の unittest カバレッジ（外部依存なし）。

実行: python3 scripts/ai-loop/test_plan_package.py

契約正本: docs/workflows/ai-loop/c3-prime-contract.md（TASK-0872 T-2）
カバー: TC-01(層2) / TC-02 / TC-03(表駆動) / TC-04 / TC-06 / TC-08a / TC-09(Unit) /
TC-11 / EC-1 / EC-3（test-cases.md の対応表参照）
"""

from __future__ import annotations

import hashlib
import inspect
import json
import os
import pathlib
import sys
import tempfile
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

import plan_package  # noqa: E402

PLAN_BODY = """# EXECUTION PLAN — TASK-9999

## Goal

sandbox タスクの目的記述。

## Files / Components to Touch

**PR-1**: `scripts/ai-loop/sandbox_a.py` / `docs/workflows/ai-loop/sandbox.md`

## Testing Strategy

- Unit: sandbox
- Verification Automation: `true && echo ok`

## Mode判定

**モード**: standard
"""

def _make_task_dir(tmp, omit=(), empty=(), c1_verdict="PASS", c2_verdict="approve",
                   c1_hash=None, c2_hash=None, c1_markers=1, c2_markers=1,
                   c1_extra="", c2_extra=""):
    """sandbox の Plan Package 6 要素を生成する（c3-prime-contract.md §1 マーカー準拠）。

    omit で欠落・empty で 0 byte を再現。c1_hash/c2_hash 指定でマーカーの
    plan= を上書き（stale 再現）。c*_markers でマーカー行数を制御（0=未対応
    artifact / 2=重複追記攻撃）。c*_extra はマーカー後に追記される自然文
    （F-1 の追記攻撃再現用）。
    """
    task_dir = pathlib.Path(tmp) / "TASK-9999"
    task_dir.mkdir(parents=True, exist_ok=True)
    contents = {
        "pbi-input.md": "# PBI INPUT — TASK-9999\n",
        "plan.md": PLAN_BODY,
        "todo.md": "# TODO\n- [ ] T-1\n",
        "test-cases.md": "# TEST CASES\n| AC-1 | TC-01 |\n",
    }
    for name, body in contents.items():
        if name in omit:
            continue
        (task_dir / name).write_text("" if name in empty else body, encoding="utf-8")

    plan_sha = "sha256:" + hashlib.sha256(PLAN_BODY.encode("utf-8")).hexdigest()
    c1_marker = f"C1-VERDICT: {c1_verdict} plan={c1_hash or plan_sha}\n"
    c2_marker = f"C2-VERDICT: {c2_verdict} plan={c2_hash or plan_sha}\n"
    if "review-self.md" not in omit:
        body = "# C-1 セルフレビュー — TASK-9999\n\n> 判定: **PASS**（WARN 0 件・FAIL 0 件）\n\n" \
            + c1_marker * c1_markers + c1_extra
        (task_dir / "review-self.md").write_text(
            "" if "review-self.md" in empty else body, encoding="utf-8")
    if "review-external.md" not in omit:
        body = "# C-2 外部レビュー結果 — TASK-9999\n\n" \
            + c2_marker * c2_markers + c2_extra
        (task_dir / "review-external.md").write_text(
            "" if "review-external.md" in empty else body, encoding="utf-8")
    return task_dir


def _sha256_hex(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


class TaskIdTests(unittest.TestCase):
    """TC-01 層 2: task_id 形式検証（fail-closed）。"""

    def test_valid_task_id(self):
        self.assertEqual(plan_package.validate_task_id("TASK-9999"), [])

    def test_invalid_task_ids(self):
        for bad in ("", None, "task-9999", "TASK-999", "TASK-08722", "run sandbox 説明"):
            with self.subTest(bad=bad):
                self.assertTrue(plan_package.validate_task_id(bad))


class PresenceTests(unittest.TestCase):
    """TC-02: 4 成果物 + evidence の presence gate（全数パターン）。"""

    def test_all_present_ok(self):
        with tempfile.TemporaryDirectory() as tmp:
            task_dir = _make_task_dir(tmp)
            self.assertEqual(plan_package.check_presence(task_dir), [])

    def test_each_artifact_missing_fails(self):
        for name in ("pbi-input.md", "plan.md", "todo.md", "test-cases.md",
                     "review-self.md", "review-external.md"):
            with self.subTest(missing=name):
                with tempfile.TemporaryDirectory() as tmp:
                    task_dir = _make_task_dir(tmp, omit=(name,))
                    errors = plan_package.check_presence(task_dir)
                    self.assertTrue(errors)
                    self.assertTrue(any(name in e for e in errors),
                                    f"欠落ファイル名 {name} がエラーに含まれない: {errors}")

    def test_zero_byte_artifact_fails(self):
        # EC-1: 存在するが空 → integrity で fail-closed
        with tempfile.TemporaryDirectory() as tmp:
            task_dir = _make_task_dir(tmp, empty=("plan.md",))
            errors = plan_package.check_presence(task_dir)
            self.assertTrue(any("plan.md" in e for e in errors))


class EvidenceTests(unittest.TestCase):
    """TC-03: C-1/C-2 × 欠落/FAIL/stale の表駆動 6 ケース + TC-04 根拠出力
    + #887 F-1（追記反転・重複・未対応 artifact）/ F-2（hash 決定論 stale）。"""

    STALE_HASH = "sha256:" + "0" * 64

    def test_evidence_anomaly_table(self):
        # C-1/C-2 × 欠落 / FAIL(reject) / stale の 6 ケース（R-002 / F-2）
        cases = [
            ("c1-missing", dict(omit=("review-self.md",))),
            ("c2-missing", dict(omit=("review-external.md",))),
            ("c1-fail", dict(c1_verdict="FAIL")),
            ("c2-reject", dict(c2_verdict="reject")),
            ("c1-stale", dict(c1_hash=self.STALE_HASH)),
            ("c2-stale", dict(c2_hash=self.STALE_HASH)),
        ]
        for label, kwargs in cases:
            with self.subTest(case=label):
                with tempfile.TemporaryDirectory() as tmp:
                    task_dir = _make_task_dir(tmp, **kwargs)
                    errors = plan_package.check_evidence(task_dir)
                    self.assertTrue(errors, f"{label}: 単独異常で fail-closed になっていない")

    def test_stale_reason_is_traceable(self):
        # TC-04: stale 根拠（ファイル名 + stale）が機械追跡可能（hash 照合ベース / F-2）
        with tempfile.TemporaryDirectory() as tmp:
            task_dir = _make_task_dir(tmp, c1_hash=self.STALE_HASH)
            errors = plan_package.check_evidence(task_dir)
            self.assertTrue(any("review-self.md" in e and "stale" in e.lower() for e in errors),
                            f"stale 根拠が出力に含まれない: {errors}")

    def test_f1_appended_text_cannot_flip_verdict(self):
        # #887 F-1: FAIL マーカーの後に自然文の「判定: PASS」等を追記しても反転しない
        with tempfile.TemporaryDirectory() as tmp:
            task_dir = _make_task_dir(
                tmp, c1_verdict="FAIL",
                c1_extra="\n参考メモ: 修正後は 判定: PASS となる見込み。\n判定: **PASS**\n")
            errors = plan_package.check_evidence(task_dir)
            self.assertTrue(errors, "F-1: 追記テキストで FAIL→PASS 反転した")

    def test_f1_duplicate_marker_fail_closed(self):
        # #887 F-1: マーカー 2 回（PASS を追記する攻撃）は曖昧 = fail-closed
        with tempfile.TemporaryDirectory() as tmp:
            task_dir = _make_task_dir(tmp, c1_markers=2)
            errors = plan_package.check_evidence(task_dir)
            self.assertTrue(errors, "F-1: 重複マーカーが受理された")

    def test_f5_legacy_artifact_without_marker_fail_closed(self):
        # #887 F-5: マーカー未対応の実 artifact 形式（自然文の判定行のみ）は fail-closed
        with tempfile.TemporaryDirectory() as tmp:
            task_dir = _make_task_dir(tmp, c1_markers=0)
            errors = plan_package.check_evidence(task_dir)
            self.assertTrue(errors, "F-5: マーカー無し artifact が受理された")

    def test_malformed_prefix_line_fail_closed(self):
        # #887 Codex minor: 有効マーカー 1 行 + プレフィックスのみ一致する文法外の
        # 追記行（末尾空白等）がある場合、完全一致は 1 でもプレフィックス 2 で fail-closed
        with tempfile.TemporaryDirectory() as tmp:
            task_dir = _make_task_dir(
                tmp, c1_extra="C1-VERDICT: PASS plan=sha256:deadbeef  extra\n")
            errors = plan_package.check_evidence(task_dir)
            self.assertTrue(errors, "文法外プレフィックス行が受理された")

    def test_mtime_does_not_affect_verdict(self):
        # #887 F-2: mtime をどう操作しても判定は変わらない（決定論）
        with tempfile.TemporaryDirectory() as tmp:
            task_dir = _make_task_dir(tmp)
            old = 946684800  # 2000-01-01
            os.utime(task_dir / "review-self.md", (old, old))
            self.assertEqual(plan_package.check_evidence(task_dir), [],
                             "F-2: mtime 操作が判定に影響した")

    def test_evidence_ok(self):
        with tempfile.TemporaryDirectory() as tmp:
            task_dir = _make_task_dir(tmp)
            self.assertEqual(plan_package.check_evidence(task_dir), [])


class HashTests(unittest.TestCase):
    """TC-09(Unit): artifact_hashes / plan_hash / plan_package_hash の契約。"""

    def test_hashes_shape_and_values(self):
        with tempfile.TemporaryDirectory() as tmp:
            task_dir = _make_task_dir(tmp)
            hashes = plan_package.compute_hashes(task_dir)
            self.assertEqual(set(hashes["artifact_hashes"].keys()),
                             {"pbi-input.md", "plan.md", "todo.md", "test-cases.md",
                              "review-self.md", "review-external.md"})
            # 全値が sha256: prefix + 小文字 hex（EC-3: 正規化しない前提の生成側規律）
            for v in hashes["artifact_hashes"].values():
                self.assertRegex(v, r"^sha256:[0-9a-f]{64}$")
            self.assertEqual(hashes["plan_hash"],
                             "sha256:" + _sha256_hex(task_dir / "plan.md"))
            # plan_package_hash = artifact_hashes の正規化 JSON の sha256（契約 §2）
            canon = json.dumps(hashes["artifact_hashes"], sort_keys=True,
                               separators=(",", ":")).encode("utf-8")
            self.assertEqual(hashes["plan_package_hash"],
                             "sha256:" + hashlib.sha256(canon).hexdigest())

    def test_one_byte_change_changes_package_hash(self):
        with tempfile.TemporaryDirectory() as tmp:
            task_dir = _make_task_dir(tmp)
            before = plan_package.compute_hashes(task_dir)
            with open(task_dir / "todo.md", "a", encoding="utf-8") as f:
                f.write("x")
            after = plan_package.compute_hashes(task_dir)
            self.assertNotEqual(before["plan_package_hash"], after["plan_package_hash"])
            self.assertEqual(before["plan_hash"], after["plan_hash"])  # plan.md は不変


class DeriveLoopspecTests(unittest.TestCase):
    """TC-11: LoopSpec 決定論的派生・全必須フィールド・冪等。"""

    def test_derive_covers_all_required_fields(self):
        with tempfile.TemporaryDirectory() as tmp:
            task_dir = _make_task_dir(tmp)
            spec = plan_package.derive_loopspec(task_dir, "TASK-9999",
                                                maker="implementation_agent",
                                                checker="qa_reviewer")
            loop = spec["loop"]
            self.assertEqual(loop["name"], "plan-first-task-9999")
            self.assertEqual(loop["trigger"]["type"], "manual")
            self.assertIn("sandbox タスクの目的記述", loop["goal"]["description"])
            self.assertEqual(loop["goal"]["exit_criteria_ref"],
                             "docs/working/TASK-9999/test-cases.md")
            self.assertEqual(loop["context"]["include"], ["plan_package", "diff", "test_results"])
            self.assertEqual(loop["context"]["exclude"], ["stale_tool_outputs"])
            self.assertEqual(loop["context"]["external_sources"], [])
            self.assertIn("scripts/ai-loop/sandbox_a.py", loop["scope"]["allowed_paths"])
            self.assertEqual(loop["actors"], {"maker": "implementation_agent",
                                              "checker": "qa_reviewer"})
            self.assertEqual(loop["verification"]["deterministic"][0]["cmd"], "true")
            self.assertEqual(loop["verification"]["review"],
                             ["requirements_fit", "architecture_consistency"])
            self.assertEqual(loop["stopping_rule"]["terminal_state_ref"], "decision-table.md")
            self.assertEqual(loop["stopping_rule"]["round_limit_ref"],
                             "execution-runbook.md §2-(7)")
            self.assertEqual(loop["memory"]["write"], ["decision_record"])
            self.assertEqual(loop["memory"]["ref"], "execution-runbook.md §2-(4)")
            self.assertEqual(loop["escalation"]["touches_ho"], "unconditional")
            self.assertEqual(loop["escalation"]["budget_ref"], "arbiter-policy.md §7")

    def test_maker_equals_checker_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            task_dir = _make_task_dir(tmp)
            with self.assertRaises(plan_package.PlanPackageError):
                plan_package.derive_loopspec(task_dir, "TASK-9999",
                                             maker="same", checker="same")

    def test_no_files_to_touch_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            task_dir = _make_task_dir(tmp)
            (task_dir / "plan.md").write_text(
                "# PLAN\n\n## Goal\n\nx\n\n## Testing Strategy\n\n- Verification Automation: `true`\n",
                encoding="utf-8")
            with self.assertRaises(plan_package.PlanPackageError):
                plan_package.derive_loopspec(task_dir, "TASK-9999",
                                             maker="a", checker="b")

    def test_idempotent_derivation(self):
        # シナリオ 9: 同一入力 2 回 → byte 同一
        with tempfile.TemporaryDirectory() as tmp:
            task_dir = _make_task_dir(tmp)
            s1 = plan_package.derive_loopspec(task_dir, "TASK-9999", maker="a", checker="b")
            s2 = plan_package.derive_loopspec(task_dir, "TASK-9999", maker="a", checker="b")
            self.assertEqual(json.dumps(s1, sort_keys=True), json.dumps(s2, sort_keys=True))


class ExtractAllowedPathsTests(unittest.TestCase):
    """TASK-0917 T-19 / plan.md 論点 D3 `allowed_paths`: `extract_allowed_paths(plan_text)`。

    契約:
    - **plan テキストだけ**を受け取る純関数（task_dir / maker / checker を取らない
      = `derive_loopspec()` の presence 検査・maker/checker 検証を巻き込まない）
    - `## Files / Components to Touch` 節のバッククォート内 `a/b` 形式を抽出
    - **節が無い / 抽出 0 件は例外ではなく空リスト**を返す（呼び出し側 Collector が
      `escalation_flags` へ倒せる形。D3「抽出 0 件は `escalation_flags` へ」）
    - ファイルシステムに触れない（実在しないパスもそのまま返す）
    """

    def test_signature_takes_plan_text_only(self):
        # 「plan テキストだけを受け取る純関数」を署名で固定する（derive_loopspec の
        # maker/checker 検証を巻き込まないことの構造的保証）。
        params = list(inspect.signature(plan_package.extract_allowed_paths).parameters)
        self.assertEqual(params, ["plan_text"])

    def test_extracts_paths_from_files_section(self):
        paths = plan_package.extract_allowed_paths(PLAN_BODY)
        self.assertEqual(paths,
                         ["scripts/ai-loop/sandbox_a.py",
                          "docs/workflows/ai-loop/sandbox.md"])

    def test_missing_section_returns_empty_list_not_exception(self):
        text = "# PLAN\n\n## Goal\n\nx\n\n## Testing Strategy\n\n- `scripts/a.py`\n"
        self.assertEqual(plan_package.extract_allowed_paths(text), [])

    def test_section_present_but_no_paths_returns_empty_list(self):
        text = ("# PLAN\n\n## Files / Components to Touch\n\n"
                "特に無し（`todo` のような単語だけ・パス形式ではない）\n\n"
                "## Testing Strategy\n\n- x\n")
        self.assertEqual(plan_package.extract_allowed_paths(text), [])

    def test_ignores_paths_outside_files_section(self):
        text = ("# PLAN\n\n## Goal\n\n`docs/outside/goal.md` を触る\n\n"
                "## Files / Components to Touch\n\n`scripts/ai-loop/inside.py`\n\n"
                "## Testing Strategy\n\n`tests/outside/after.sh`\n")
        self.assertEqual(plan_package.extract_allowed_paths(text),
                         ["scripts/ai-loop/inside.py"])

    def test_does_not_touch_filesystem(self):
        # 実在しないパスでも抽出結果に現れる（存在検査をしない = 純関数）。
        text = ("## Files / Components to Touch\n\n"
                "`no/such/file_does_not_exist.py`\n\n## Testing Strategy\n")
        self.assertEqual(plan_package.extract_allowed_paths(text),
                         ["no/such/file_does_not_exist.py"])

    def test_deterministic(self):
        self.assertEqual(plan_package.extract_allowed_paths(PLAN_BODY),
                         plan_package.extract_allowed_paths(PLAN_BODY))

    def test_matches_derive_loopspec_allowed_paths(self):
        # public 化しても `derive_loopspec()` の allowed_paths と同値（単一実装）。
        with tempfile.TemporaryDirectory() as tmp:
            task_dir = _make_task_dir(tmp)
            spec = plan_package.derive_loopspec(task_dir, "TASK-9999",
                                                maker="a", checker="b")
            self.assertEqual(spec["loop"]["scope"]["allowed_paths"],
                             plan_package.extract_allowed_paths(PLAN_BODY))

    def test_zero_extraction_does_not_block_caller_but_still_blocks_derive(self):
        # 抽出 0 件: extract は空リスト（呼び出し側が escalation_flags へ倒せる）。
        # 一方 derive_loopspec は従来どおり PlanPackageError（既存挙動不変）。
        plan_text = ("# PLAN\n\n## Goal\n\nx\n\n## Testing Strategy\n\n"
                     "- Verification Automation: `true`\n")
        self.assertEqual(plan_package.extract_allowed_paths(plan_text), [])
        with tempfile.TemporaryDirectory() as tmp:
            task_dir = _make_task_dir(tmp)
            (task_dir / "plan.md").write_text(plan_text, encoding="utf-8")
            with self.assertRaises(plan_package.PlanPackageError):
                plan_package.derive_loopspec(task_dir, "TASK-9999",
                                             maker="a", checker="b")


class BuildC3PrimeTests(unittest.TestCase):
    """TC-08a: c3-prime record 生成（PR-1 Unit）+ TC-06 reviewer snapshot 照合。"""

    @staticmethod
    def _build(task_dir, **overrides):
        kwargs = dict(
            task_id="TASK-9999",
            source_sha="abc1234",
            target_sha="abc1234",
            verdicts={"model_a": "approve", "model_b": "approve"},
            reviewer_evidence={"model_a": "record#a", "model_b": "record#b"},
            decision="AUTO_APPROVED",
            policy_ref="auto-approve-lite-clean@v4",
            issued_at="2100-01-01T00:00:00Z",
            issued_by="arbiter-v0.1",
        )
        kwargs.update(overrides)
        return plan_package.build_c3_prime(task_dir, **kwargs)

    def test_valid_build(self):
        with tempfile.TemporaryDirectory() as tmp:
            task_dir = _make_task_dir(tmp)
            record = self._build(task_dir)
            self.assertEqual(record["approval_kind"], "c3-prime")
            self.assertEqual(record["phase"], "C-3'")
            self.assertEqual(record["decision"], "AUTO_APPROVED")
            self.assertEqual(record["task_id"], "TASK-9999")
            self.assertEqual(record["source_sha"], "abc1234")
            self.assertEqual(record["issued_at"], "2100-01-01T00:00:00Z")
            self.assertNotIn("c3_status", record)  # 契約 §5: c3_status を含めない
            self.assertRegex(record["plan_hash"], r"^sha256:[0-9a-f]{64}$")
            # TC-06: reviewer snapshot が三つ組全一致で刻印される
            for m in ("model_a", "model_b"):
                snap = record["reviewers"][m]
                self.assertEqual(snap["plan_hash"], record["plan_hash"])
                self.assertEqual(snap["source_sha"], record["source_sha"])
                self.assertEqual(snap["plan_package_hash"], record["plan_package_hash"])
                self.assertEqual(snap["verdict"], "approve")
                self.assertTrue(snap["evidence_ref"])
            self.assertIn("c1_evidence_ref", record)
            self.assertIn("c2_evidence_ref", record)

    def test_source_sha_target_sha_mismatch_rejected(self):
        # 契約 §2 R-011: source_sha != target_sha は生成拒否
        with tempfile.TemporaryDirectory() as tmp:
            task_dir = _make_task_dir(tmp)
            with self.assertRaises(plan_package.PlanPackageError):
                self._build(task_dir, target_sha="fff9999")

    def test_presence_failure_blocks_build(self):
        # TC-02 接続: presence 異常時は AUTO_APPROVED record を組めない
        with tempfile.TemporaryDirectory() as tmp:
            task_dir = _make_task_dir(tmp, omit=("todo.md",))
            with self.assertRaises(plan_package.PlanPackageError):
                self._build(task_dir)

    def test_evidence_failure_blocks_build(self):
        with tempfile.TemporaryDirectory() as tmp:
            task_dir = _make_task_dir(tmp, c1_verdict="FAIL")
            with self.assertRaises(plan_package.PlanPackageError):
                self._build(task_dir)

    def test_f3_decision_verdict_mismatch_rejected(self):
        # #887 F-3: AUTO_APPROVED は両 reviewer approve のときのみ（生成側検証）
        with tempfile.TemporaryDirectory() as tmp:
            task_dir = _make_task_dir(tmp)
            with self.assertRaises(plan_package.PlanPackageError):
                self._build(task_dir,
                            verdicts={"model_a": "reject", "model_b": "reject"},
                            decision="AUTO_APPROVED")

    def test_f3_non_auto_decision_with_rejects_allowed(self):
        # reject を含んでも decision が非 AUTO_APPROVED なら record 生成可（整合）
        with tempfile.TemporaryDirectory() as tmp:
            task_dir = _make_task_dir(tmp)
            record = self._build(task_dir,
                                 verdicts={"model_a": "approve", "model_b": "reject"},
                                 decision="HUMAN_ESCALATED")
            self.assertEqual(record["decision"], "HUMAN_ESCALATED")

    def test_decision_must_be_in_allowlist(self):
        # #887 Codex major: decision の 3 値 allowlist（契約外の値を record にしない）
        with tempfile.TemporaryDirectory() as tmp:
            task_dir = _make_task_dir(tmp)
            for bad in ("unknown", "NOT_A_DECISION", "approved", ""):
                with self.subTest(decision=bad):
                    with self.assertRaises(plan_package.PlanPackageError):
                        self._build(task_dir,
                                    verdicts={"model_a": "approve", "model_b": "approve"},
                                    decision=bad)

    def test_verdict_must_be_approve_or_reject(self):
        # #887 Codex major: reviewer verdict の allowlist
        with tempfile.TemporaryDirectory() as tmp:
            task_dir = _make_task_dir(tmp)
            with self.assertRaises(plan_package.PlanPackageError):
                self._build(task_dir,
                            verdicts={"model_a": "approve", "model_b": "maybe"},
                            decision="HUMAN_ESCALATED")

    def test_evidence_reread_failure_is_fail_closed(self):
        # #887 Codex 新規バグ: compute_hashes 後の TOCTOU 改変で再読が失敗しても
        # #None を含む record を返さず PlanPackageError
        with tempfile.TemporaryDirectory() as tmp:
            task_dir = _make_task_dir(tmp)
            orig = plan_package.compute_hashes

            def patched(td):
                r = orig(td)
                (task_dir / "review-external.md").write_text("# broken\n", encoding="utf-8")
                return r

            plan_package.compute_hashes = patched
            try:
                with self.assertRaises(plan_package.PlanPackageError):
                    self._build(task_dir)
            finally:
                plan_package.compute_hashes = orig

    def test_serialization_constraint(self):
        # 契約 §5: json.dumps(indent=2, sort_keys=True) でトップレベル plan_hash 行が 1 回のみ
        with tempfile.TemporaryDirectory() as tmp:
            task_dir = _make_task_dir(tmp)
            record = self._build(task_dir)
            text = plan_package.serialize_c3_prime(record)
            top_level_plan_hash = [ln for ln in text.splitlines()
                                   if ln.startswith('  "plan_hash"')]
            self.assertEqual(len(top_level_plan_hash), 1)
            self.assertNotIn('"c3_status"', text)
            self.assertEqual(json.loads(text)["approval_kind"], "c3-prime")

    def test_idempotent_build(self):
        # シナリオ 9: issued_at 注入により同一入力 2 回で byte 同一
        with tempfile.TemporaryDirectory() as tmp:
            task_dir = _make_task_dir(tmp)
            r1 = self._build(task_dir)
            r2 = self._build(task_dir)
            self.assertEqual(plan_package.serialize_c3_prime(r1),
                             plan_package.serialize_c3_prime(r2))


if __name__ == "__main__":
    unittest.main(verbosity=2)
