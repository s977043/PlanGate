---
name: ai-dev-brainstorm
description: "アイデアや曖昧な要件を PlanGate の PBI INPUT PACKAGE に対話的に整理する。Use when: docs/working/TASK-XXXX/pbi-input.md を新規作成したい時、要件をブレストして PBI に落としたい時。"
---

# AI-Driven Brainstorm (PlanGate / Codex 共用)

PlanGate ワークフローの **brainstorm フェーズ** を Codex / Claude Code 両方で実行する skill。

## Read First

1. `CLAUDE.md`
2. `AGENTS.md`
3. `.claude/rules/working-context.md`（PBI INPUT PACKAGE の必須要素・ディレクトリ構造の正本）
4. `docs/ai-driven-development.md`
   - 最低限: `## ワークフロー全体像`、`## ゲート条件`、`## 成果物の保存先`
5. `docs/working/TASK-XXXX/status.md`（存在する場合）

## Output

- `docs/working/TASK-XXXX/pbi-input.md`
- 必要に応じて `docs/working/TASK-XXXX/status.md`（フェーズ進捗の初期記録）

## Rules

- 1 問ずつ進める（最大 3 問の確認質問・多肢選択推奨）
- まだ `plan.md` / `todo.md` / `test-cases.md` は作成しない
- `pbi-input.md` の必須要素は `.claude/rules/working-context.md` の「pbi-input.md」節を参照
- 既存コードや関連制約はコードベースを確認してから要約する

## CLI 呼び出し

- 実コマンド: `./scripts/ai-dev-workflow TASK-XXXX brainstorm`
- skill 側はプロンプト規約のみ（Rule 2 遵守）

## 次フェーズへ

brainstorm 完了後は `ai-dev-plan` skill で B-1→B-2→B-3 フローを実行する。
