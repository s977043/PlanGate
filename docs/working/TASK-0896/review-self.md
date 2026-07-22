# C-1 セルフレビュー — TASK-0896

> 実施: 2026-07-22 / 対象: plan.md / todo.md / test-cases.md（B-3 生成物）
> 判定: **PASS**（WARN 1 件・FAIL 0 件）

## Plan チェック（7 項目）

| # | 項目 | 判定 | 根拠 |
|---|------|------|------|
| C1-PLAN-01 | 受入基準網羅性 | PASS | AC-1〜8（issue verbatim）すべてが Work Breakdown の Step 1〜5 と test-cases.md の TC-1〜12 に写像（マッピング表で全数確認。AC-6 は TC-10 静的検査 + 回帰テストで機械化） |
| C1-PLAN-02 | Unknowns 処理 | PASS | pbi-input の Unknowns 2 件は確定済みを追認（論点 3 / test 粒度）。未確定の 2 件（#873 実装順 / EPIC 追記コメント）は **C-3 論点として人間へ明示送付**し推測で確定していない |
| C1-PLAN-03 | スコープ制御 | PASS | Non-goals（issue verbatim 3 件: 全統合しない / 契約不変 / 機能変更ゼロ）+ 不変条件（偽造 14 reject / 4 系 green / 非対称保存）を Constraints に明記。Replan Triggers に機械値（ファイル数 >13 / 既存テスト期待値変更 = 即 Replan）あり |
| C1-PLAN-04 | テスト戦略 | PASS | Unit / Integration / E2E / Edge / Verification Automation すべて具体コマンド。既存テストがメッセージ非検証である実測（assert 0 件)に基づき「判定結果ベースの不変確認」を明示 |
| C1-PLAN-05 | Work Breakdown Output | PASS | Step 0〜6 全てに Output / Owner / Risk / 🚩 / rollback。Output の無い Step なし |
| C1-PLAN-06 | 依存関係 | PASS | コミット a→b→c→d 直列（各コミット green 維持）。C-3 APPROVED 前に exec 開始しない構造を todo ⚠️ 節に明示 |
| C1-PLAN-07 | 動作検証自動化 | PASS | `python3 test_c3_contract.py && test_arbiter.py && test_plan_package.py && test_c3prime_verify.py && sh tests/run-tests.sh` を Stop Condition と連動 |

## ToDo チェック（5 項目）

| # | 項目 | 判定 | 根拠 |
|---|------|------|------|
| C1-TODO-01 | タスク粒度 | **WARN** | T-11（arbiter + c3prime の両置換 + 偽造 14 検証）と T-15（敵対レビュー）は 2-5 分粒度を超える見込み。T-11 は exec 時に「arbiter 置換 → 検証」「c3prime 置換 → 検証」の 2 サブへ分割する前提を注記。T-15 は subagent 派遣 1 アクション + disposition で構造上分割不能 |
| C1-TODO-02 | depends_on 設定 | PASS | 全 17 タスクに depends_on 記載。循環なし・直列制約がコミット戦略と一致 |
| C1-TODO-03 | チェックポイント設定 | PASS | 全タスクに 🚩。Human ゲート（C-3 / C-4）明示 |
| C1-TODO-04 | Iron Law 遵守 | PASS | main 直接 push なし（PR 前提）/ 非 HO 確認済み（HO 適用タスクなし）/ exec は C-3 APPROVED 後のみ / L-0〜V-4 は conductor 制御で todo に含めない |
| C1-TODO-05 | 完了条件 | PASS | 各実装タスクに「4 系テスト green」の機械確認条件 + rollback 記載（high-risk 必須要件充足） |

## TestCases チェック（3 項目）

| # | 項目 | 判定 | 根拠 |
|---|------|------|------|
| C1-TC-01 | 受入基準との紐付き | PASS | AC-1〜8 → TC-1〜12 全数マッピング（表で確認） |
| C1-TC-02 | Edge case 網羅 | PASS | TC-6（strict/lenient 非対称の両側固定 = 本 PBI 最重要 edge）+ TC-E1〜E3（空 reviewers / None 一致 / bundled 自立） |
| C1-TC-03 | 自動化可否 | PASS | TC-12（敵対レビュー記録）のみ性質上手動（記録検査）、他 11 件は全て自動実行可能なコマンド付き |

## 指摘事項まとめ

- WARN-1（C1-TODO-01）: T-11 の粒度超過 → exec 時に 2 サブ分割（対応方針記載済み・plan 修正不要）

**総合判定: PASS**（軽微 WARN 1 件のみ・FAIL なし）。C-2 外部レビュー（2 レーン）へ進む。

---

## 簡易 C-1 再実行（C-2 確定反映後 / 2026-07-22）

R-001/R-003〜R-010 反映後の plan/todo/test-cases を再確認:

| 項目 | 判定 | 根拠 |
|------|------|------|
| 受入基準網羅性 | PASS | AC-1 の REQUIRED_KEYS 系が Step 1 / TC-1 / TC-2 に写像された（R-001 是正で AC-1 完全網羅） |
| スコープ制御 | PASS | R-010 の ta-55 追記は CI 実行経路の最小追加（+1 ファイル・Replan 閾値 14 内・非 HO）。Non-goals 逸脱なし |
| テスト戦略 | PASS | 純粋性検証（R-003）・順序契約/代表文言回帰（R-004）が TC-5 に追加され「振る舞い不変」の検証手段が閉じた |
| 整合性 | PASS | Metrics 実数 9 / 比率 1.0 / Replan 閾値 14 / Files to Touch 9 で全記述一致（stale 記述の残存を grep で全数確認済み） |

**総合判定: PASS** — C-3（Human）へ。
