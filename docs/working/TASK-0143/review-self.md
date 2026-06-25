# TASK-0143 セルフレビュー結果（C-1）

> mode=high-risk → 17項目フルチェック対象。本書は Plan 7 + ToDo 5 + TestCases 3 + B-1/B-2 の 2 = 17 項目。

## Plan チェック（7項目）

| # | 項目 | 判定 | 根拠 |
|---|------|------|------|
| C1-PLAN-01 | 受入基準網羅性 | PASS | #527 配線系 AC（12/12 表・doctor drift 検出）を本PBI AC-1〜2 に対応付け、固有 AC-3〜5 を追加 |
| C1-PLAN-02 | Unknowns 処理 | PASS | 群B発火層を明示 Unknown 化し C-3 確定事項として切り出し（candidate1 提示）。EH-7 GH連携も判断項目化 |
| C1-PLAN-03 | スコープ制御 | PASS | Non-goal に「hook ロジック新規実装」「GH branch protection 自動連携」を明記。`scripts/hooks/` は凍結 |
| C1-PLAN-04 | テスト戦略 | PASS | Unit/Integration/Regression/Wiring negative を Testing Strategy + test-cases.md に定義 |
| C1-PLAN-05 | Work Breakdown Output | PASS | 各 Step に Output 列を明記（doc/差分/メモ） |
| C1-PLAN-06 | 依存関係 | PASS | todo.md 依存関係節で T3〜6 が T1/T2 後、T6 が C-3 後、検証が実装後と明示 |
| C1-PLAN-07 | 動作検証自動化 | PASS | `sh tests/run-tests.sh` 全 PASS を V-1 前提に設定。doctor negative test 自動化 |

## ToDo チェック（5項目）

| # | 項目 | 判定 | 根拠 |
|---|------|------|------|
| C1-TODO-01 | タスク粒度 | PASS | 準備2 / 実装5 / 検証4 / 完了1 に分割、各々単一責務 |
| C1-TODO-02 | depends_on 設定 | PASS | 依存関係節で明示 |
| C1-TODO-03 | チェックポイント設定 | PASS | 各実装タスクに 🚩 を付与 |
| C1-TODO-04 | Iron Law 遵守 | PASS | 承認境界 → C-3 ゲートを Human タスク先頭に固定。AI は `scripts/hooks/` 非改変 |
| C1-TODO-05 | 完了条件 / rollback | PASS | 各実装/テストタスクに rollback 手順を記載（承認境界 high-risk 必須要件を充足） |

## TestCases チェック（3項目）

| # | 項目 | 判定 | 根拠 |
|---|------|------|------|
| C1-TC-01 | 受入基準との紐付き | PASS | AC→TC マッピング表で AC-1〜5 全てに TC を割当 |
| C1-TC-02 | Edge case 網羅 | PASS | E1（段階化両モード）/ E2（EH-7二重化未完）/ E3（コメント行誤判定）/ E4（群B保留時の段階リリース） |
| C1-TC-03 | 自動化可否 | PASS | 全 TC が run-tests / doctor で自動実行可能（手動依存なし） |

## B-1 / B-2（追加2項目 / mode=high-risk）

| # | 項目 | 判定 | 根拠 |
|---|------|------|------|
| C1-B-01 | 承認境界 Hardening Override 整合 | PASS | 触れるパス（settings.example / bin/plangate / workflows / CLAUDE系doc）を high-risk 固定・lite_eligible=false と明記。`scripts/hooks/` 凍結 |
| C1-B-02 | 段階的ロールバック | PASS | default=warning 段階導入 + 各タスク rollback 手順 + 群B保留時の群A単独リリース可（E4）で段階的後退を確保 |

## 総合判定

**PASS**（FAIL 0 / WARN 0）

- 17項目すべて PASS。evidence は PASS のため省略（判定根拠を本書に記載）。
- **C-3 で必ず確定すべき2点**: ① 群B発火層 candidate1（conductor 単一判定層）の承認 ② EH-7 GitHub branch protection 連携を本PBIに含めるか別PBIに切り出すか。
- C-3 APPROVE 後に exec（T1 から）着手可能。
