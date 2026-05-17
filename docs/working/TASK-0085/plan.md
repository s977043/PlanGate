---
task_id: TASK-0085
artifact_type: plan
schema_version: 1
status: draft
---
# EXECUTION PLAN — TASK-0085 Gate Event Normalization（#230・light）
## Goal
gate_id/phase/status 正規化ルールを docs 正本化 + privacy-safe fixture。
既存 vocabulary/schema 非破壊・後方互換。
## Constraints / Non-goals
- schema は変更しない（or additive のみ）。既存 verdict/hook_result enum 不変
- Hook 強制実装/#231 本体 は Non-goal
## 変更内容（light）
- 新規 docs/ai/gate-event-normalization.md（判定ルール/gate_id命名/phase対応表/
  status 正規化マップ）
- 新規 fixture（privacy-safe sample events・schema valid）
- metrics.md / hook-enforcement.md から参照リンク（additive）
## 確認方法
- AC-1〜7 を grep/構造 + schema 整合 + fixture schema valid + 回帰
## Mode判定
**モード**: light（docs+fixture 中心・schema 非破壊・コード最小）。V-3 は #231
入力正本のため実施（light だが下流影響を考慮）
