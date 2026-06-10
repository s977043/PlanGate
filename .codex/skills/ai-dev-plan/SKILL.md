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
- B-1（最大 3 問の確認質問）→ **事前メトリクス検証 (mandatory gate)** → B-2（2〜3 案の trade-off 比較）→ B-3（3 ファイル同時生成）

### 事前メトリクス検証 (B-1 → B-2 mandatory gate / #351 TASK-0117)

> 正本: [`docs/ai/plan-metrics-verification.md`](../../../docs/ai/plan-metrics-verification.md)

「全部 / 全件 / 残り N 件」系の対象は **実数を取得** してから B-2 へ進む。

**検証コマンド例** (.git / node_modules 等を除外):

```sh
grep -rln --exclude-dir={.git,node_modules,dist,docs/working} <symbol> --include='*.md' -- . | wc -l
find . -name <pattern> -not -path './.git/*' -not -path './node_modules/*' | wc -l
# 推奨: rg --files <path> | wc -l
```

**判定基準** (実数 / AI 見積もり):

- ≥ 3 倍 → **スコープ縮小 or 別タスクへ切替**
- 1〜3 倍 → 採用、plan の Risks に記録
- < 1 倍 → 採用、Mode を 1 段下げる候補

**plan.md template に `## Metrics Evidence` 欄を必須化** (実数 / 見積もり / ratio / 判定 を残す出力契約 / AC-8)。

**未取得時の分岐 (安全側 / R-001/R-004)**: 実数取得不能 / Plan Health 未算出 / 「全件」系の対象が曖昧な場合は **必ず Mode 引き上げ側に倒す** (`mode-classification.md` AC-8 安全側不変条件と一貫)。

### todo.md 規約

- タスク粒度 2-5 分、`Owner: agent / human` 必須、`depends_on` / `files` 必須
- L-0〜V-4・PR 作成は workflow-conductor が自動制御するため含めない

### test-cases.md 規約

- 各 AC → テストケースのマッピング必須、Edge case を含める

### 監査

- decision-log.jsonl に B-1/B-2/B-3 の主要判断を append-only で記録
- mode が `critical` で `lite_eligible=true` の場合は人間の C-3 明示承認記録が前提（`mode-classification.md` AC-11）

## 計画の構造化観点（river-review rr-upstream-create-plan-001 由来 / #517 受け入れ）

plan.md 生成時、以下の観点を Work Breakdown / Risks に反映する:

1. **仮説と確定事項の分離** — 判断に必要な事実が欠けていれば Questions / Unknowns に
   質問として先出しし、仮説（未確認の前提）と確定事項を混ぜない。情報不足のまま
   推測で進めない
2. **リスクの 3 点セット** — Risks には `内容 / 検証手段 / Fallback` を揃える。
   不確実性（互換性・性能・移行・セキュリティ）ごとに検証方法が無いリスクを残さない
3. **人間ゲートの明示** — 設計確認・仕様確認など人間レビューが必要なブレーキ
   ポイントを Work Breakdown の 🚩 チェックポイントとして明示する（自己設置 Gate は
   勝手に解除しない — responsibility-classes.md 準拠）
4. **速く学べる順** — ステップは検証が早く回る順に並べ、クリティカルパスを明示。
   並列可能な作業はまとめて示す

> 出典: river-review `rr-upstream-create-plan-001`（skill インベントリ監査で
> 「plan を作る側 = PlanGate の責務」と整理され移管。s977043/river-review#1105）

## CLI 呼び出し

- 実コマンド: `./scripts/ai-dev-workflow TASK-XXXX plan`
- 機械検証: `bin/plangate validate TASK-XXXX`（plan_hash 整合）

## 次フェーズへ

plan 完了後は `plan-review-gate` skill で C-1 → C-2 → C-3（c3.json APPROVED）。exec は `ai-dev-exec` skill。
