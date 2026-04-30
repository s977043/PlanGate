# C-1 SELF REVIEW — TASK-0039 (PBI-116-01 / Issue #117)

> 17 項目セルフレビュー。各項目を PASS / WARN / FAIL で判定。

## サマリ

| 区分 | PASS | WARN | FAIL |
|------|------|------|------|
| Plan（7 項目） | 6 | 1 | 0 |
| ToDo（5 項目） | 5 | 0 | 0 |
| TestCases（5 項目） | 5 | 0 | 0 |
| **合計（17 項目）** | **16** | **1** | **0** |

**総合判定**: **PASS**（WARN 1 件は minor、Child C-3 で確認）

## Plan チェック（7 項目）

### C1-PLAN-01: 受入基準網羅性
- **判定**: PASS
- **根拠**: pbi-input.md の AC-1〜AC-6（6 項目）が全て plan.md の Approach Overview / Work Breakdown / test-cases.md にマッピング済

### C1-PLAN-02: Unknowns 処理
- **判定**: PASS
- **根拠**: plan.md の Questions / Unknowns セクションに Q1〜Q3 を提示、各 A1〜A3 で初期方針を記述

### C1-PLAN-03: スコープ制御
- **判定**: PASS
- **根拠**: Constraints / Non-goals セクションで明示。子 PBI YAML の `forbidden_files`（bin/**, schemas/**, .github/workflows/** 等）と整合

### C1-PLAN-04: テスト戦略
- **判定**: PASS
- **根拠**: Testing Strategy で Unit / Integration / E2E / Edge cases / Verification Automation を全網羅。doc-review PBI のため Unit は該当なしと明記

### C1-PLAN-05: Work Breakdown Output
- **判定**: PASS
- **根拠**: 全 Step（Step 1〜8）に具体的な Output を明記（`evidence/inventory.md`, `docs/ai/core-contract.md`, 行数記録, etc）

### C1-PLAN-06: 依存関係
- **判定**: PASS
- **根拠**: 各 Step の前後関係が記述、Step 1（棚卸し）→ Step 2（Core Contract）→ Step 3-6（薄型化）→ Step 7（検証）→ Step 8（完了）の順序が明示

### C1-PLAN-07: 動作検証自動化
- **判定**: WARN
- **根拠**: Verification Automation セクションあり、grep / wc / lint / diff で 8/13 のテストケースを自動化可能。ただし TC-E3 / TC-E4（手動 E2E: Claude Code / Codex CLI 起動確認）は自動化困難で、手動依存が残る
- **対応**: WARN として記録。Child C-3 で「手動 E2E のみ許容するか」を判定。許容する場合は scope 内、許容しない場合は手動 E2E をワークフロー化する追加 PBI を提起

## ToDo チェック（5 項目）

### C1-TODO-01: タスク粒度（必須）
- **判定**: PASS
- **根拠**: T-1〜T-28 が各 2-5 分粒度（grep 実行 / 分類 / セクション 1 つ作成 / 行数記録 等）。例外として T-10（CLAUDE.md 書き換え）は単一タスクで 5-15 分かかる可能性があるが、Step 単位で分割可能なため許容範囲

### C1-TODO-02: depends_on 設定（必須）
- **判定**: PASS
- **根拠**: 全 28 タスクに `depends_on` を明記。直列実行（並列性なし）

### C1-TODO-03: チェックポイント設定（推奨）
- **判定**: PASS
- **根拠**: 全タスクに 🚩 マーク

### C1-TODO-04: Iron Law 遵守（必須）
- **判定**: PASS
- **根拠**: todo.md の冒頭で `NO SCOPE CHANGE WITHOUT USER APPROVAL` を明示。「タスク粒度ルール」セクションでスコープ外作業の禁止を明示

### C1-TODO-05: 完了条件（推奨）
- **判定**: PASS
- **根拠**: 各タスクの記述に動詞 + 対象 + 完了確認方法（lint 通過 / 行数記録 / 8 セクション完備 等）が含まれる

## TestCases チェック（5 項目）

### C1-TC-01: 受入基準との紐付き（必須）
- **判定**: PASS
- **根拠**: 受入基準 → テストケース マッピングテーブルで AC-1〜AC-6 が TC-1〜TC-8 にマッピング済（重複あり、抜け漏れなし）

### C1-TC-02: Edge case 網羅（必須）
- **判定**: PASS
- **根拠**: TC-E1〜TC-E5 を定義（Iron Law 重複整理 / Plugin 同期漏れ / Codex CLI 起動 / Claude Code 起動 / hard-mandate 例外承認）

### C1-TC-03: 自動化可否（推奨）
- **判定**: PASS
- **根拠**: 各 TC に「種別」列で自動/部分自動/手動を明示。自動化サマリで全 TC 一覧化

### C1-TC-04: 検証コマンド明示
- **判定**: PASS
- **根拠**: 各 TC の「入力」欄に具体的な grep / wc / diff コマンド or 動作を明記

### C1-TC-05: 期待出力の具体性
- **判定**: PASS
- **根拠**: 各 TC の「期待出力」欄が具体的（「8 セクション全てがマッチ」「行数が baseline × 0.5 以下」等）

## 総合判定

**判定**: **PASS**

### 根拠サマリ
- 17 項目中 16 PASS / 1 WARN / 0 FAIL
- WARN は手動 E2E の自動化困難という性質上やむを得ない範囲
- スコープ・依存・テスト戦略の全てで重大な欠陥なし

### Child C-3 ゲートへの推奨

- **APPROVE 候補**: 計画品質は exec 開始可能なレベル
- **CONDITIONAL の場合の指摘候補**: TC-E3 / TC-E4（手動 E2E）の許容判断を明示
- **REJECT 候補**: なし

### 次の必須ステップ

1. C-2 外部AIレビュー（Codex 必須、high-risk のため） — 次セッション
2. Child C-3 ゲート判断 — 👤 ユーザー
3. APPROVED 後 exec 開始

## メタ情報

| 項目 | 値 |
|------|---|
| レビュー対象 | plan.md / todo.md / test-cases.md |
| レビュー実施者 | Claude (self-review) |
| 実施日 | 2026-04-30 |
| 17 項目チェックリスト出典 | `docs/ai-driven-development.md` の Prompt 2 / `.claude/rules/working-context.md` |
