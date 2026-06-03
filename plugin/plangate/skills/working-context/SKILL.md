---
name: working-context
description: "PlanGate の TASK-XXXX 作業コンテキストを Progressive Disclosure で読込・更新する。Use when: セッション再開時、フェーズ遷移時、status.md/current-state.md/handoff.md を更新したい時。"
---

# Working Context (PlanGate / Codex 共用)

PlanGate の `docs/working/TASK-XXXX/` 配下を **L0〜L3 の Progressive Disclosure プロトコル** で読み込み、更新する skill。プロトコル詳細は `.claude/rules/working-context.md` を正本とする。

## Read First (L0 / 常に読む)

1. `CLAUDE.md`
2. `AGENTS.md`
3. `.claude/rules/working-context.md`（ディレクトリ構造・段階別出力・handoff 必須化・L0〜L3 プロトコルの正本）
4. `docs/working/TASK-XXXX/INDEX.md`
5. `docs/working/TASK-XXXX/current-state.md`

## L1 / L2 / L3 の読み込み対象

`.claude/rules/working-context.md` の「コンテキスト読み込みプロトコル（Progressive Disclosure）」表を参照（重複を避けるため本 skill では再掲しない）。

## Output

- `docs/working/TASK-XXXX/status.md`（フェーズ履歴・追記）
- `docs/working/TASK-XXXX/current-state.md`（今の状態スナップショット・上書き）
- `docs/working/TASK-XXXX/handoff.md`（WF-05 完了時のみ、Rule 5 / 6 要素は正本参照）

## Rules

- INDEX.md が無ければフォールバックで status.md を直接読む（旧形式互換）
- セッション開始は L0 → L1 の順で必要分だけ読む（不要 read を抑制）
- 計画からの逸脱は status.md「計画からの変更点」セクションに記録
- handoff.md は WF-05 完了時に 1 回発行（6 要素は `.claude/rules/working-context.md` および `docs/working/templates/handoff.md` を正本とする）

## CLI 呼び出し

- セッション再開時の current-state 表示: `bin/plangate resume TASK-XXXX`
- 動的 context 取得（opt-in / Issue #199）: `bin/plangate context TASK-XXXX --phase <plan|exec|review|status>`（**`--phase` 必須**）
- 状態確認: `bin/plangate status TASK-XXXX`

## 次フェーズへ

セッション再開後は現フェーズに応じて `ai-dev-plan` / `plan-review-gate` / `ai-dev-exec` / `ai-dev-verify` を呼ぶ。
