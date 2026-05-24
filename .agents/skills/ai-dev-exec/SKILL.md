---
name: ai-dev-exec
description: "PlanGate の exec フェーズを TDD で実行する。Use when: C-3 APPROVED 後にコード実装を開始したい時、workflow-conductor 配下で実装タスクを進めたい時。"
---

# AI-Driven Exec (PlanGate / Codex 共用)

PlanGate ワークフローの **exec フェーズ（WF-04 Build & Refine）** を Codex / Claude Code 両方で実行する skill。

## 前提条件（必須）

- `docs/working/TASK-XXXX/approvals/c3.json` が存在し `c3_status: APPROVED`
- `plan_hash` が現 plan.md の SHA-256 と一致（EH-3 PASS）
- `bin/plangate doctor --check-settings` が PASS（settings タスクロック・Shadow Config 防止）

これらが満たされなければ exec を**開始しない**。

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

- 共通: `bin/plangate exec TASK-XXXX`（APPROVED c3.json のみ受理）

## 次フェーズへ

exec 完了後は workflow-conductor が L-0（リンター）→ V-1（受け入れ検査）→ V-2/V-3/V-4 を自動進行。verify 観点は `ai-dev-verify` skill。
