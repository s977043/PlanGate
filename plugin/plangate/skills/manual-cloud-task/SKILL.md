---
name: manual-cloud-task
description: "tracked handoff packet を使って Codex Cloud task を手動起動するための指示を組み立てる。Use when: Codex Cloud で exec 相当の作業を手動で進めたい時（PlanGate ではローカル実行が原則・本 skill は optional）。"
---

# Manual Cloud Task (PlanGate / optional)

> **PlanGate での位置付け**: PlanGate は Claude Code / Codex CLI どちらも**ローカル実行が原則**。Codex Cloud を使う場合のみ本 skill を使う（optional）。ローカル exec 再開には `local-exec-handoff` skill を参照。

## Read First

1. `CLAUDE.md`
2. `AGENTS.md`
3. `.claude/rules/working-context.md`（C-3 / handoff 要件）
4. `.codex/manual-cloud-task.md`

## Rules

- Cloud task は人間が手動起動する（AI が自動起動しない）
- GitHub コメント経由で exec を起動しない
- C-3 未承認なら停止する（`approvals/c3.json` APPROVED 必須）
- Cloud task は tracked handoff packet を**唯一の作業指示**として扱う
- `docs/working/` の ticket ファイルはローカル側の作業材料であり、Cloud task から直接読める前提にしない

## Deliverable

Cloud task にそのまま貼れる短い実行指示を作成。承認済み内容は `.codex/manual-cloud-task.md` に転記する。

## CLI 呼び出し

- packet 作成: `./scripts/ai-dev-workflow TASK-XXXX prepare-cloud`
- Cloud task 実行後の同期: `./scripts/ai-dev-workflow TASK-XXXX sync-cloud`

## ローカル実行に切り替えるとき

Codex Cloud を使わずローカル Codex CLI で exec する場合は本 skill ではなく `local-exec-handoff` + `ai-dev-exec` を使う。
