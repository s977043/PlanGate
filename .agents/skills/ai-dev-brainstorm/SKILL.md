---
name: ai-dev-brainstorm
description: "アイデアや曖昧な要件を PlanGate の PBI INPUT PACKAGE に対話的に整理する。Use when: docs/working/TASK-XXXX/pbi-input.md を新規作成したい時、要件をブレストして PBI に落としたい時。"
---

# AI-Driven Brainstorm (PlanGate / Codex 共用)

PlanGate ワークフローの **brainstorm フェーズ（WF-01 / phase 0）** を Codex / Claude Code 両方で実行する skill。

## Read First

1. `CLAUDE.md`
2. `AGENTS.md`
3. `.claude/rules/working-context.md`（PBI INPUT PACKAGE の必須要素・ディレクトリ構造）
4. `.claude/rules/mode-classification.md`（後段の mode 判定材料を意識）
5. `docs/ai-driven-development.md`
   - 最低限: `## ワークフロー全体像`、`## ゲート条件`、`## 成果物の保存先`
6. `docs/working/TASK-XXXX/status.md`（存在する場合）

## Output

- `docs/working/TASK-XXXX/pbi-input.md`
- 必要に応じて `docs/working/TASK-XXXX/status.md`（フェーズ進捗の初期記録）

## Rules

- 1 問ずつ進める（最大 3 問の確認質問・多肢選択推奨）
- まだ `plan.md` / `todo.md` / `test-cases.md` は作成しない（plan フェーズの責務）
- `pbi-input.md` には以下を明記:
  - Context / Why（なぜやるか）
  - What（Scope）: In scope / Out of scope
  - 受入基準（Acceptance Criteria, AC-1, AC-2, ...）
  - Notes from Refinement
  - Estimation Evidence: Risks / Unknowns / Assumptions
- 既存コードや関連制約はコードベースを確認してから要約する
- 設計が曖昧なまま実装へ進まない（plan フェーズへの handoff 品質を担保）

## CLI 呼び出し

- 共通: `bin/plangate brainstorm TASK-XXXX` または `./scripts/ai-dev-workflow TASK-XXXX brainstorm`
- skill 側はプロンプト規約のみ。実行ロジックは CLI 側（Rule 2 遵守）

## 次フェーズへ

brainstorm 完了後は `ai-dev-plan` skill で B-1→B-2→B-3 フローを実行する。
