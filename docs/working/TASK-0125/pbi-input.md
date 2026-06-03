# PBI INPUT PACKAGE: TASK-0125

## Context / Why
Issue #430「Codex Dynamic Workflows 風の計画承認ゲート」を PlanGate に取り込む。
先行議論（Codex/Gemini 相談）で「新ゲート追加でなく c3.json の `gate_checks` フィールド拡張」が適切という合意を得た。
Goal/Scope/Risk は plan.md の既存セクションと重なるため再定義せず、承認時の checklist として機械可読化する。

Closes #430

## What

### In scope
- `schemas/c3-approval.schema.json` に `gate_checks` プロパティを additive 追加
- `docs/ai/gate-checks.md` を新規作成（フィールド仕様・適用条件・ultra-light/light 非対象の明示）
- `docs/working/templates/` への記録（c3 テンプレートなし → handoff テンプレートのコメント更新のみ）

### Out of scope
- Evidence Gate（handoff.md との時系列逆転のため不採用）
- ultra-light / light モードへの適用（AC-8 安全側と整合、lite_eligible=false 連動は別 PBI）
- `.claude/rules/working-context.md` 等 HO 対象パスの変更（Human 適用のみ）
- CLI 自動化（Markdown/スキーマ先行、CLI は後段）

## 受入基準

| AC | 内容 |
|----|------|
| AC-01 | `c3-approval.schema.json` に `gate_checks` オブジェクトが optional property として追加されている |
| AC-02 | `gate_checks` は `goal / scope / risk` の 3 項目 boolean を持ち、standard 以上でのみ推奨と明記 |
| AC-03 | `docs/ai/gate-checks.md` が作成され、Evidence Gate 不採用理由・適用条件・ultra-light/light 除外が明示されている |
| AC-04 | 既存の c3.json（`additionalProperties: false`）との後方互換が維持される（既存 c3.json が validation エラーにならない） |

## Estimation Evidence

### Risks / Unknowns
- `additionalProperties: false` の制約下での additive 拡張 → optional property として追加すれば互換維持可能
- `gate_checks` のフィールド名・型は Codex 提案に基づく（変更不可ではない）

### Assumptions
- `gate_checks` は c3.json に optional で追加し、未記入でも既存フローを壊さない
- mode = standard 以上が「推奨」（強制はしない）
