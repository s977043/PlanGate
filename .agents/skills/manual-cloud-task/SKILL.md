---
name: manual-cloud-task
description: "tracked handoff packet を使って Codex Cloud task を手動起動するための指示を組み立てる。Use when: Codex Cloud で exec 相当の作業を手動で進めたい時。"
---

# Manual Cloud Task

## Read First

1. `CLAUDE.md`
2. `AGENTS.md`
3. `.codex/manual-cloud-task.md`

## Rules

- Cloud task は人間が手動起動する
- GitHub コメントで exec を起動しない
- C-3 未承認なら停止する
- Cloud task は tracked handoff packet を唯一の作業指示として扱う
- `docs/working/` の ticket ファイルはローカル側の作業材料であり、Cloud task から直接読める前提にしない

## Deliverable

Cloud task にそのまま貼れる短い実行指示を作る。

通常は `./scripts/ai-dev-workflow TASK-XXXX prepare-cloud` で packet を整え、Cloud task 実行後は `./scripts/ai-dev-workflow TASK-XXXX sync-cloud` でローカル文書へ戻す。
