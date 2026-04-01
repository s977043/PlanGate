# Project-Scoped Skills

このディレクトリは、Codex Cloud / Codex CLI で使う repo-owned skill の正本。

## Repo-Owned Skills

- `ai-dev-brainstorm` - アイデアや曖昧な要件を `pbi-input.md` に整理する
- `ai-dev-plan` - PBI INPUT PACKAGE から `plan.md` `todo.md` `test-cases.md` を作る
- `plan-review-gate` - C-1 / C-2 / C-3 の判定と exec 可否を確認する
- `manual-cloud-task` - tracked handoff packet を使って手動 Cloud task を起動する
- `working-context` - ローカル ticket コンテキストと Cloud handoff packet の橋渡し

Codex CLI の標準入口は `./scripts/ai-dev-workflow TASK-XXXX brainstorm|plan|gate|prepare-cloud|exec|status|sync-cloud`。
