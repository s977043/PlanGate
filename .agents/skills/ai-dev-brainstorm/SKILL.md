---
name: ai-dev-brainstorm
description: "アイデアや曖昧な要件を Codex 用の PBI INPUT PACKAGE に対話的に整理する。Use when: docs/working/TASK-XXXX/pbi-input.md を新規作成したい時、要件をブレストして PBI に落としたい時。"
---

# AI-Driven Brainstorm

Codex で AI駆動開発ワークフローの brainstorm フェーズを実行するための skill。

## Read First

1. `CLAUDE.md`
2. `AGENTS.md`
3. `docs/ai-driven-development.md`
4. `docs/working/TASK-XXXX/status.md`（存在する場合）

## Output

- `docs/working/TASK-XXXX/pbi-input.md`
- 必要に応じて `docs/working/TASK-XXXX/status.md`

## Rules

- 1質問ずつ進める
- まだ `plan.md` / `todo.md` / `test-cases.md` は作成しない
- `pbi-input.md` には Why / What / Acceptance Criteria / Constraints / Non-goals を明記する
- 既存コードや関連制約はコードベースを確認してから要約する
- 設計が曖昧なまま実装へ進まない

## Codex Cloud Note

この skill は brainstorm フェーズ専用。plan 生成は `ai-dev-plan`、exec 前 gate 判定は `plan-review-gate`、Cloud handoff は `manual-cloud-task` を使う。

Codex CLI では通常 `./scripts/ai-dev-workflow TASK-XXXX brainstorm` から呼び出す。
