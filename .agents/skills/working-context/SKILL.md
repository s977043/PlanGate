---
name: working-context
description: "PlanGate の TASK-XXXX 作業コンテキストを Progressive Disclosure で読込・更新する。Use when: セッション再開時、フェーズ遷移時、status.md/current-state.md/handoff.md を更新したい時。"
---

# Working Context (PlanGate / Codex 共用)

PlanGate の `docs/working/TASK-XXXX/` 配下を **L0〜L3 の Progressive Disclosure プロトコル** で読み込み、更新する skill。

## Read First (L0 / 常に読む)

1. `CLAUDE.md`
2. `AGENTS.md`
3. `.claude/rules/working-context.md`（ディレクトリ構造・段階別出力・handoff 必須化の正本）
4. `docs/working/TASK-XXXX/INDEX.md`
5. `docs/working/TASK-XXXX/current-state.md`

## L1（フェーズに応じて）

- plan → `pbi-input.md`
- exec → `plan.md`, `todo.md`, `test-cases.md`
- review → `plan.md`, `review-self.md`, `review-external.md`
- status → `status.md`, `todo.md`

## L2（根拠が必要な時のみ）

- `evidence/{c1-review,c2-review,test-runs,verification,e2e}/`
- `decision-log.jsonl`

## L3（横断分析が必要な時のみ）

- `status.md` 全体、他チケットの working context

## Output

- `docs/working/TASK-XXXX/status.md`（フェーズ履歴・追記）
- `docs/working/TASK-XXXX/current-state.md`（今の状態スナップショット・上書き）
- `docs/working/TASK-XXXX/handoff.md`（WF-05 完了時のみ、Rule 5 / 6 要素必須）

## Rules

- INDEX.md が無ければフォールバックで status.md を直接読む（旧形式互換）
- セッション開始は L0 → L1 の順で必要分だけ読む（不要 read を抑制）
- 計画からの逸脱は status.md「計画からの変更点」セクションに記録
- 完了タスクは todo.md と status.md の両方を更新
- current-state.md は ~20 行のスナップショット、status.md は履歴アーカイブ
- handoff.md は WF-05 完了時に 1 回発行（6 要素: 要件適合 / 既知課題 / V2 候補 / 妥協点 / 引き継ぎ文書 / テスト結果）

## CLI 呼び出し

- 共通: `bin/plangate context TASK-XXXX` または `./scripts/ai-dev-workflow TASK-XXXX context`

## 次フェーズへ

セッション再開後は現フェーズに応じて `ai-dev-plan` / `plan-review-gate` / `ai-dev-exec` / `ai-dev-verify` を呼ぶ。
