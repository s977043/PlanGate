---
task_id: TASK-0086
artifact_type: pbi-input
schema_version: 1
status: draft
---
# PBI INPUT PACKAGE — TASK-0086
> #231 PBI-HI-015: Dogfooding Eval v1（single judge + human rationale / v8.8.0 / high-risk）

## Context / Why
PlanGate 自身を評価する dogfooding eval。#228 評価5項目を judge prompt 化し
過去 TASK の handoff/events/decision-log を入力に「実行品質を機械判定」。
依存: #228(✅main)/#229(✅main)/#230(PR #261・gate-event-normalization 正本)。

## What — Scope
### In scope
- single judge + human-readable rationale（multi-judge 撤回）
- 評価5項目（#228 run-outcome-review と整合）:
  1. PBI 入力→AC/Design/Task 分解が妥当か
  2. handoff 6 要素が満たされているか
  3. C-3/C-4 判定に必要な証跡があるか
  4. Trace Timeline(experimental #229) に評価可能イベントが揃っているか
  5. Stop rules / core-contract 違反がないか
- 外部 fixture 意識（作者 repo 依存前提を排除・tests/fixtures/eval-runner 等）
- `bin/plangate eval --dogfood <TASK>` コマンド（eval-runner.py に mode 追加）
- 結果を `docs/working/TASK-XXXX/eval-dogfood.md` に rationale 付き出力
- #230 gate-event-normalization を judge 入力前処理として参照
### Out of scope
- multi-judge consensus / 自動学習 / Keep Rate(#198) / A/B 基盤
- LLM 不確実性管理（v8.9.0）

## Acceptance Criteria
- [ ] AC-1: `bin/plangate eval --dogfood <TASK>` が動作し5項目を single judge で判定
- [ ] AC-2: 結果が markdown + rationale 付きで `docs/working/TASK-XXXX/eval-dogfood.md` に出力
- [ ] AC-3: 既存 TASK 3件以上で評価サンプルが残る（実 TASK or fixture）
- [ ] AC-4: 外部 fixture 意識（作者 repo specific 前提を排除）
- [ ] AC-5: 5項目 judge prompt が #228 run-outcome-review と整合
- [ ] AC-6: #229 timeline output を入力として読める / #230 正規化を前処理参照
- [ ] AC-7: 既存 eval（8-aspect `eval <TASK>`）非破壊・hook/CLI 回帰なし

## Notes from Refinement
- single judge（Round4確定）。rationale=human-readable。v1 は構造判定+
  judge-prompt テンプレ（LLM 判定は外部レビュー基盤と同パターンで呼べる形）
- #230(#261) 未マージ→自己完結＋依存明記（gate-event-normalization 参照は
  #261 マージで解決。F2 §5-bis と同パターン）

## Estimation Evidence
**Risks**: judge 出力の揺らぎ→v1 は決定論構造判定を主・LLM rationale は補助。
eval-runner 統合で既存破壊リスク→--dogfood は独立 mode（非破壊）。
**Unknowns**: judge LLM 呼び出し方式（v1 は prompt 生成+構造判定で最小）。
Mode=high-risk（V-3+V-4 必須）
