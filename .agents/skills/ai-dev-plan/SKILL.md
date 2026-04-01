---
name: ai-dev-plan
description: "PBI INPUT PACKAGE から AI駆動開発用の plan.md / todo.md / test-cases.md を作成する。Use when: docs/working/TASK-XXXX/pbi-input.md を元に実行計画を作りたい時。"
---

# AI-Driven Plan

`docs/ai-driven-development.md` の plan フェーズを Codex で実行するための skill。

## Read First

1. `CLAUDE.md`
2. `AGENTS.md`
3. `docs/ai-driven-development.md`
   - 最低限読む範囲: `## 概要`、`## ワークフロー全体像`、`## ゲート条件`、`## PBI INPUT PACKAGE`、`### Prompt 1: Plan + ToDo + Test Cases生成`
4. `docs/working/TASK-XXXX/pbi-input.md`

## Output

- `docs/working/TASK-XXXX/plan.md`
- `docs/working/TASK-XXXX/todo.md`
- `docs/working/TASK-XXXX/test-cases.md`

## Rules

- タスクは 2-5 分粒度に分解する
- `Owner: agent / human` を必ず明記する
- `depends_on` と `files` を todo に含める
- テストは受入基準とのマッピングを持たせる
- Unknowns がある場合は plan に明記する

## Codex Cloud Note

この skill は plan 生成までを扱う。exec の起動は `manual-cloud-task` skill を参照し、承認済み内容は `.codex/manual-cloud-task.md` に転記する。

Codex CLI では通常 `./scripts/ai-dev-workflow TASK-XXXX plan` から呼び出す。
