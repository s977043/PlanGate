# C-1 セルフレビュー — TASK-0872

> 実施: 2026-07-20 / 対象: plan.md / todo.md / test-cases.md（B-3 生成物）
> 判定: **PASS**（WARN 2 件・FAIL 0 件）

## Plan チェック（7 項目）

| # | 項目 | 判定 | 根拠 |
|---|------|------|------|
| C1-PLAN-01 | 受入基準網羅性 | PASS | AC-1〜11（issue verbatim）すべてが Work Breakdown の Step と test-cases.md の TC-01〜12 に写像されている（test-cases.md のマッピング表で全数確認） |
| C1-PLAN-02 | Unknowns 処理 | PASS | 3 件を Questions / Unknowns に明示し、C-3 確認 2 件（CI 登録形式 / EH-3 非対応の非退行方針）と実装時確定 1 件（C-1 evidence 判定粒度）に振り分け。推測で確定扱いにしていない |
| C1-PLAN-03 | スコープ制御 | PASS | Non-goals（issue verbatim 4 件）+ 不変条件（WF-00〜07 / legacy 契約 byte 不変 / Phase 1 policy）を Constraints に明記。Replan Triggers に機械値あり |
| C1-PLAN-04 | テスト戦略 | PASS | Unit / Integration / E2E / Edge / Verification Automation すべて具体コマンドで記載。9 シナリオ→TC 対応表あり |
| C1-PLAN-05 | Work Breakdown Output | PASS | 全 9 Step に Output / Owner / Risk / 🚩 が揃う。Output の無い Step なし |
| C1-PLAN-06 | 依存関係 | PASS | PR-1 → H-2 → PR-2 の直列制約、H-3（HO 適用）の BLOCKED 化条件を todo ⚠️ 節に明示 |
| C1-PLAN-07 | 動作検証自動化 | PASS | `python3 test_arbiter.py && test_plan_package.py && sh tests/run-tests.sh && bin/plangate doctor` を Stop Condition と連動 |

## ToDo チェック（5 項目）

| # | 項目 | 判定 | 根拠 |
|---|------|------|------|
| C1-TODO-01 | タスク粒度 | **WARN** | T-9（arbiter.py 入力契約拡張）と T-15（bin/plangate patch 生成）は 2-5 分粒度を超える見込み。exec 開始時に implementer がサブ分割する前提を注記（分割単位: presence gate / provenance 刻印 / approval_kind 出力）。plan 段階での過剰分割は避けた |
| C1-TODO-02 | depends_on 設定 | PASS | 全 24 タスク（T-1〜20 / H-1〜4）に depends_on 記載。循環なし |
| C1-TODO-03 | チェックポイント設定 | PASS | 実装・HO・マージの要所 12 箇所に 🚩。Human ゲート（H-1〜4）明示 |
| C1-TODO-04 | Iron Law 遵守 | PASS | main 直接 push なし（PR 前提）/ HO は patch 生成のみで AI 適用なし / exec は C-3 APPROVED 後のみ / L-0〜V-4 は conductor 制御で todo に含めない |
| C1-TODO-05 | 完了条件 | PASS | Stop Condition + DoD（issue の close 条件 verbatim）+ T-19/T-20 の evidence 保存で機械確認可能 |

## TestCases チェック（3 項目）

| # | 項目 | 判定 | 根拠 |
|---|------|------|------|
| C1-TC-01 | 受入基準との紐付き | PASS | AC-1〜11 → TC-01〜12 全数マッピング + 9 シナリオ → TC 対応表 |
| C1-TC-02 | Edge case 網羅 | PASS | EC-1〜6（0 byte / 未知フィールド / hash 正規化 / 未知 approval_kind / legacy 併存 / source_sha 不一致）。EC-5/EC-6 は契約確定を要する旨明示 |
| C1-TC-03 | 自動化可否 | **WARN** | TC-08 / TC-09 の E2E は CI yml 配線が HO のため、Human 適用（H-3）完了までローカル実行のみ。CI green の確認は H-4 に紐付く（自動化不能ではなく適用待ち） |

## 指摘事項まとめ

- WARN-1（C1-TODO-01）: T-9 / T-15 の粒度超過 → exec 時にサブ分割（対応方針記載済み、plan 修正不要）
- WARN-2（C1-TC-03）: E2E の CI 実行は HO 適用後 → 依存は todo の H-3/H-4 で追跡済み（構造上の制約であり plan 修正不要）

**総合判定: PASS**（軽微 WARN のみ・FAIL なし）。C-2 外部レビューへ進む。

---

## 簡易 C-1 再実行（C-2 確定反映後 / 2026-07-20 00:18）

> 対象: R-001〜R-013 の 1 回確定反映後の plan.md / todo.md / test-cases.md（review-external.md 監査表参照）

| # | 項目 | 判定 | 根拠 |
|---|------|------|------|
| C1-PLAN-01 | 受入基準網羅性 | PASS | AC-1（二層検証 TC-01）・AC-3（表駆動 6 ケース TC-03）・AC-5（reviewer snapshot TC-06）・AC-7（TC-08a/08b/13 の三層）・AC-8（source_sha 系 TC-09c）で強化。マッピング表更新済み |
| C1-PLAN-02 | Unknowns 処理 | PASS | CI 登録形式は R-013 で解消（extras パターン確定）。残 2 件（EH-3 非対応方針 = C-3 確認 / C-1 evidence 判定粒度 = 暫定実装明記） |
| C1-PLAN-03 | スコープ制御 | PASS | 追加 2 ファイル（schema_mapping.py / sync-plugin-plangate.sh）は AC-7 成立の必須条件（CI FAIL・サイレント欠落の回避）で In scope 内。実数 19〜20 は Replan 閾値 22 の範囲内・Metrics Evidence 更新済み |
| C1-PLAN-04 | テスト戦略 | PASS | E2E を tests/extras + fixtures 既存パターンへ確定（HO 面積縮小）。TC-13 追加 |
| C1-PLAN-05 | Work Breakdown Output | PASS | Step 0（契約 5 要件）/ Step 2（timestamp 注入）/ Step 3（シナリオ 5 の PR-1 Unit）/ Step 4（sync 整合判定）すべて Output 更新済み |
| C1-PLAN-06 | 依存関係 | PASS | T-11b 追加・旧 T-17 を T-18 へ統合・H-3 の depends_on を T-16 へ修正。循環なし |
| C1-PLAN-07 | 動作検証自動化 | PASS | 検証コマンド不変 + TA-30 拡張（plan_package 展開先自立 PASS）を T-18 に追加 |

**再判定: PASS**（レーン A reject の major 5 件・レーン B conditional の major 3 件はすべて反映済み。C-3 提示可）。
