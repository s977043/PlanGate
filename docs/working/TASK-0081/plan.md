---
task_id: TASK-0081
artifact_type: plan
schema_version: 1
status: draft
---

# EXECUTION PLAN — TASK-0081 責務4分類 rules 正本化（S4）

## Goal

散在する責務分界を `.claude/rules/responsibility-classes.md` 単一正本に集約
（AI/Human/CI/Workflow-owned）。既存ルールは参照を足すのみ（本文不変）。

## Constraints / Non-goals

- 既存ルール本文の責務記述を改変しない（additive・参照付けのみ）
- 強制機構は変更しない（分類の正本化＝ドキュメントのみ）
- TASK-0071 S3 / merge 自動化（Human-owned 固定）は Non-goal

## Approach Overview

1. responsibility-classes.md 新設（4分類定義・例・既存ルール対応表）
2. hybrid-architecture.md に参照リンク追加（重複させない）
3. 既存個別責務記述（TASK-0077 AC-4 / settings-wiring-contract / working-context
   タスクロック / orchestrator-mode）との整合確認（矛盾ゼロ）

## Work Breakdown

| Step | 内容 | Output | Owner | Risk | 🚩 |
|------|------|--------|-------|------|----|
| S1 | 散在責務記述の棚卸し（hybrid Rule1-5 / orchestrator AS-1..5 / working-context / settings-wiring / TASK-0077 AC-4） | 対応表 | agent | low | - |
| S2 | responsibility-classes.md 正本作成（4分類+例+既存対応） | 新 rules | agent | med | 🚩AC-1,2,3 |
| S3 | hybrid-architecture.md に参照追加（additive） | 差分 | agent | low | 🚩AC-4 |
| S4 | 整合確認（既存責務記述と矛盾なし・本文不変） | 確認結果 | agent | med | 🚩AC-5,6 |
| V | V-1 / V-3（standard: Codex+Gemini） | レビュー | agent | med | - |

## Files / Components to Touch

- `.claude/rules/responsibility-classes.md`（新規・正本）
- `.claude/rules/hybrid-architecture.md`（参照リンク追加のみ）
- 参照のみ（不変）: orchestrator-mode.md / working-context.md /
  mode-classification.md / docs/ai/settings-wiring-contract.md /
  docs/working/TASK-0077/

## Testing Strategy

- 構造検証: 4分類・各例・既存対応表 が responsibility-classes.md に存在（grep）
- additive 確認: 既存ルール本文の責務記述に削除/改変なし（diff＝hybrid は
  参照行追加のみ・他 rules は無変更）
- 整合: settings-wiring-contract 責務分離表 / TASK-0077 AC-4 と矛盾なし（突合）
- 回帰: hook テスト 78/0・doc 整合

## Risks & Mitigations

- R1: 既存記述と矛盾 → S4 整合確認・本正本を上位集約と位置づけ（個別は具体例）
- R2: 重複定義 → hybrid は参照のみ。本文は responsibility-classes.md に一本化
- R3: スコープ膨張 → 既存本文改変しない（additive）を不変条件化

## Questions / Unknowns

- なし（4分類は direction-codex-gemini.md C4 で確定）

## Mode判定

**モード**: standard

**判定根拠**:
- 変更ファイル数: 2（新規 rules + hybrid 参照1行） → 中
- 受入基準数: 6 → 中
- 変更種別: governance rules 正本の新設（additive・強制機構不変） → 中
- リスク: 中（rules 正本だが本文改変なし・docs のみ）
- **最終判定**: standard（V-3 実施・V-2/V-4 スキップ）
