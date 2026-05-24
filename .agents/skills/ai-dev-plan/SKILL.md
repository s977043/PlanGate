---
name: ai-dev-plan
description: "PBI INPUT PACKAGE から PlanGate の plan.md / todo.md / test-cases.md を B-1→B-2→B-3 フローで作成する。Use when: docs/working/TASK-XXXX/pbi-input.md を元に実行計画を作りたい時。"
---

# AI-Driven Plan (PlanGate / Codex 共用)

PlanGate ワークフローの **plan フェーズ（WF-02〜WF-03）** を Codex / Claude Code 両方で実行する skill。実行ロジックは `scripts/ai-dev-workflow` / `bin/plangate` CLI 側に集約し、skill は読む順序と入出力規約のみを担う。

## Read First

1. `CLAUDE.md`
2. `AGENTS.md`
3. `.claude/rules/working-context.md`（B フェーズ 3 ファイル同時生成・段階別出力・ゲート条件の正本）
4. `.claude/rules/mode-classification.md`（5 段階 mode + `lite_eligible` 派生属性の正本）
5. `.claude/rules/hybrid-architecture.md`（Rule 1〜5 / handoff 必須化）
6. `docs/ai-driven-development.md`
   - 最低限: `## ワークフロー全体像`、`### タスク規模によるモード分岐（5 モード）`、`## ゲート条件`、`### Prompt 1: Plan + ToDo + Test Cases生成`
7. `docs/working/TASK-XXXX/pbi-input.md`

## Output

- `docs/working/TASK-XXXX/plan.md`
- `docs/working/TASK-XXXX/todo.md`
- `docs/working/TASK-XXXX/test-cases.md`
- `docs/working/TASK-XXXX/INDEX.md`（任意・無ければ生成）
- `docs/working/TASK-XXXX/decision-log.jsonl`（初期化）

## Rules

### フロー（詳細は正本参照）

- **B-1 / B-2 / B-3** フローおよび plan.md 必須セクション（確認事項 / アプローチ比較 / Mode判定 / lite_eligible 等）は `docs/ai-driven-development.md` の `### Prompt 1: Plan + ToDo + Test Cases生成` と `.claude/rules/mode-classification.md` を **正本** とする。skill は順序のみを示す。
- B-1（最大 3 問の確認質問）→ B-2（2〜3 案の trade-off 比較）→ B-3（3 ファイル同時生成）

### todo.md 規約

- タスク粒度 2-5 分、`Owner: agent / human` 必須、`depends_on` / `files` 必須
- L-0〜V-4・PR 作成は workflow-conductor が自動制御するため含めない

### test-cases.md 規約

- 各 AC → テストケースのマッピング必須、Edge case を含める

### 監査

- decision-log.jsonl に B-1/B-2/B-3 の主要判断を append-only で記録
- mode が `critical` で `lite_eligible=true` の場合は人間の C-3 明示承認記録が前提（`mode-classification.md` AC-11）

## CLI 呼び出し

- 実コマンド: `./scripts/ai-dev-workflow TASK-XXXX plan`
- 機械検証: `bin/plangate validate TASK-XXXX`（plan_hash 整合）

## 次フェーズへ

plan 完了後は `plan-review-gate` skill で C-1 → C-2 → C-3（c3.json APPROVED）。exec は `ai-dev-exec` skill。
