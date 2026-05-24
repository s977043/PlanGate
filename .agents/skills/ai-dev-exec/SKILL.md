---
name: ai-dev-exec
description: "PlanGate の exec フェーズを TDD で実行する。Use when: C-3 APPROVED 後にコード実装を開始したい時、workflow-conductor 配下で実装タスクを進めたい時。"
---

# AI-Driven Exec (PlanGate / Codex 共用)

PlanGate ワークフローの **exec フェーズ（WF-04 Build & Refine）** を Codex / Claude Code 両方で実行する skill。

## 前提条件（exec 開始ゲート）

- `docs/working/TASK-XXXX/approvals/c3.json` が存在し `c3_status: APPROVED`
- `bin/plangate validate TASK-XXXX` PASS（plan_hash 整合 / artifact 整合 / EH-3 整合）
- `bin/plangate exec TASK-XXXX` は APPROVED c3.json のみ受理（CLI 側で機械チェック）

これらが満たされなければ exec を**開始しない**。

> **settings タスクロック** (`bin/plangate doctor --check-settings`) は **V-1 / handoff 完了の前提条件**（`.claude/rules/working-context.md` 正本）。exec 入口では block しない。詳細は `ai-dev-verify` skill。

## Read First

1. `CLAUDE.md`
2. `AGENTS.md`
3. `.claude/rules/working-context.md`（exec phase の出力規約）
4. `.claude/rules/hybrid-architecture.md`（Rule 1〜5）
5. `.claude/rules/responsibility-classes.md`（AI-owned / Human-owned 境界）
6. `docs/working/TASK-XXXX/plan.md` / `todo.md` / `test-cases.md`
7. `docs/working/TASK-XXXX/current-state.md`

## Rules

- **TDD 厳守**: Red → Green → Refactor。test-cases.md の各 AC に対応するテストを先に書く。
- **todo.md 順守**: depends_on を尊重し、🚩 checkpoint ごとに current-state.md 更新。
- **計画逸脱の即時記録**: 計画外のリネーム / 削除 / 設計変更は status.md「計画からの変更点」に記録。
- **scope 越境禁止**: plan.md「Files / Components to Touch」外の変更は禁止。必要時は plan 再生成 + C-3 再承認。
- **L-0〜V-4 は workflow-conductor が自動制御**: 本 skill 範囲外。
- **AI 自己改変ガード尊重**: `.claude/settings*.json` / Hardening Override 対象は触らない（Human-owned）。
- **decision-log.jsonl 追記**: 主要判断は append-only で記録。

## Output

- 実装コード（plan.md「Files / Components to Touch」内）
- テストコード（test-cases.md と 1:1 対応）
- `docs/working/TASK-XXXX/current-state.md` 更新
- `docs/working/TASK-XXXX/status.md` 追記
- `docs/working/TASK-XXXX/decision-log.jsonl` 追記

## CLI 呼び出し

- exec dispatch: `bin/plangate exec TASK-XXXX [--mode <mode>]`（APPROVED c3.json のみ受理）
- 機械検証: `bin/plangate validate TASK-XXXX`
- 並行で `./scripts/ai-dev-workflow TASK-XXXX exec` も利用可

## 次フェーズへ

exec 完了後は `ai-dev-verify` skill で V-1〜V-4 + handoff.md 発行。L-0〜V-4 は workflow-conductor が自動進行。
