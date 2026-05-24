---
name: ai-dev-plan
description: "PBI INPUT PACKAGE から PlanGate の plan.md / todo.md / test-cases.md を B-1→B-2→B-3 フローで作成する。Use when: docs/working/TASK-XXXX/pbi-input.md を元に実行計画を作りたい時。"
---

# AI-Driven Plan (PlanGate / Codex 共用)

PlanGate ワークフローの **plan フェーズ（WF-02〜WF-03 相当）** を Codex / Claude Code 両方で実行する skill。実行ロジックは `bin/plangate` CLI に集約し、skill はプロンプト規約のみを担う。

## Read First

1. `CLAUDE.md`
2. `AGENTS.md`
3. `.claude/rules/working-context.md`（B フェーズ 3 ファイル同時生成・段階別出力・ゲート条件）
4. `.claude/rules/mode-classification.md`（5 段階 mode + `lite_eligible` 派生属性）
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

### B-1 → B-2 → B-3 フロー（必須）

- **B-1**: PBI INPUT の曖昧点を最大 3 問の確認質問（多肢選択推奨）で解消。曖昧さがなければスキップ可。
- **B-2**: 2〜3 アプローチ案を trade-off 付きで比較し推薦案を明示。比較結果は plan.md「アプローチ比較」セクションに記載。
- **B-3**: 確定仕様で plan.md + todo.md + test-cases.md を**同時生成**。

### plan.md 必須セクション

- Goal / Constraints / Non-goals / Approach Overview
- **確認事項**（B-1 の Q&A、無ければ「該当なし」明記）
- **アプローチ比較**（B-2、無ければ「該当なし」明記）
- Work Breakdown（Step ごとに Output / Owner / Risk / 🚩 checkpoint）
- Files / Components to Touch
- Testing Strategy
- Risks & Mitigations
- Questions / Unknowns
- **Mode判定**: 5 段階（ultra-light / light / standard / high-risk / critical）+ 判定根拠
- **lite_eligible**: true / false + 根拠（AC-8 安全側 / AC-11 critical 原則 false）

### todo.md 規約

- タスク粒度 2-5 分
- `Owner: agent / human` 必須
- `depends_on` / `files` を必ず付ける
- L-0〜V-4・PR 作成は workflow-conductor が自動制御するため含めない
- 🤖 Agent / 👤 Human のフェーズ分離を明示

### test-cases.md 規約

- 各 AC → テストケースのマッピング必須
- 前提条件 / 入力 / 期待出力 / 種別（unit / integration / e2e / verification）
- Edge case を含める

### 監査・整合

- Unknowns は plan に明記（隠さない）
- decision-log.jsonl に B-1/B-2/B-3 の主要判断を append-only で記録
- mode が `critical` で `lite_eligible=true` の場合は人間の C-3 明示承認記録が前提（AC-11）

## CLI 呼び出し

- 共通: `bin/plangate plan TASK-XXXX` または `./scripts/ai-dev-workflow TASK-XXXX plan`

## 次フェーズへ

plan 完了後は `plan-review-gate` skill で C-1（17 項目）→ C-2（R-NNN 集約）→ C-3（c3.json APPROVED）。exec は `ai-dev-exec` skill。
