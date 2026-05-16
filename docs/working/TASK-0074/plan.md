---
task_id: TASK-0074
artifact_type: plan
schema_version: 1
status: draft
---

# EXECUTION PLAN — TASK-0074 Design/UI Addendum（F3）

## Goal

UI/デザインタスクで追加指示の往復をゼロにするため、pbi-input テンプレに
条件付き Design/UI Addendum を追加し、Figma 有無で真実源を分岐固定する。

## Constraints / Non-goals

- 非 UI タスクに認知負荷を増やさない（条件付き・削除可明記）
- 一律必須化しない（参照なしの明示逃げ道を残す＝ゲート回避防止）
- Figma MCP 自動取得・視覚回帰自動化は Non-goal
- 強制 Hook は追加しない（テンプレ/spec/doc のソフト誘導）

## Approach Overview

1. bin/plangate init の pbi-input heredoc に Addendum を追加（条件付き）
2. Figma 有無分岐 + UI 判定トリガ + 参照なし明示の spec 文書を新設
3. design.md テンプレに視覚設計セクション追加（Addendum と整合）
4. 生成回帰（init で正しく出る・非UIで削除可）確認

## Work Breakdown

| Step | 内容 | Output | Owner | Risk | 🚩 |
|------|------|--------|-------|------|----|
| S1 | 現状調査: init heredoc / design.md テンプレ / 既存 UI 言及 | 調査メモ | agent | low | - |
| S2 | UI 判定トリガ方式の意思決定（自動推定 vs 手動宣言）→ C-3 | design note | agent | med | 🚩C-3判断 |
| S3 | pbi-input テンプレに Addendum 追加（踏襲元最優先・条件付き） | bin/plangate 差分 | agent | med | 🚩AC-1〜3,5,6 |
| S4 | Figma 有無分岐 + 判定トリガ spec 文書新設 | spec md | agent | med | 🚩AC-4,5 |
| S5 | design.md テンプレ視覚設計セクション追加 | template 差分 | agent | low | 🚩AC-7 |
| S6 | 生成回帰（init）+ doc 整合 | テスト結果 | agent | med | 🚩AC-8 |
| V | V-1 / V-3（standard: Codex+Gemini） | レビュー | agent | med | - |

## Files / Components to Touch（S1 確定）

- `bin/plangate`（pbi-input heredoc に Addendum）
- `docs/ai/`（Design/UI Addendum spec 新設、配置 S1 で確定）
- `docs/working/templates/design.md`（視覚設計セクション）
- 既存 doc の参照追記（必要時）

## Testing Strategy

- 生成回帰: `bin/plangate init` で Addendum が条件付きで出力される
- 構造検証: 必須フィールド（踏襲元最優先含む）が grep で存在
- 分岐仕様: Figma 有/無/参照なし の3経路が spec に明記（文書検証）
- 非UI: Addendum は「UI のみ・削除可」と明記され強制でない
- 回帰: 既存 init 出力（Why/What/AC）が壊れない、doc 整合性

## Risks & Mitigations

- R1: テンプレ肥大 → 条件付き見出し + 「非UIは本節削除可」明記
- R2: UI 判定の誤り → S2 で方式確定、参照なし明示で曖昧進行を防ぐ
- R3: bin/plangate 破壊 → init 生成回帰テストで担保

## Questions / Unknowns

- ~~UI判定~~ → **C-3確定: pbi-input の is_ui_task 人手宣言を基本 + 変更ファイル傾向の自動ヒントを補助警告**

## Mode判定

**モード**: standard

**判定根拠**:
- 変更ファイル数: 3-4 → 中
- 受入基準数: 8 → 高だが定型テンプレ追加で実装は軽量
- 変更種別: テンプレ/spec/doc 追加（強制力なし） → 中
- リスク: 中（bin/plangate 触るが heredoc 追記のみ）
- **最終判定**: standard（V-3 実施、V-2/V-4 スキップ）
