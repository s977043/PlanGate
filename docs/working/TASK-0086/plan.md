---
task_id: TASK-0086
artifact_type: plan
schema_version: 1
status: draft
---
# EXECUTION PLAN — TASK-0086 Dogfooding Eval v1（#231・high-risk）
## Goal
`eval --dogfood <TASK>` で #228 5項目を single judge 構造判定 + rationale 出力。
既存 8-aspect eval 非破壊・#230 正規化参照・外部 fixture 意識。
## Constraints / Non-goals
- 既存 eval-runner（8-aspect `eval <TASK>`）を破壊しない（--dogfood 独立 mode）
- multi-judge / 自動学習 / Keep Rate は Non-goal
- #230(#261) 未マージ→自己完結＋依存明記
## Work Breakdown
| Step | 内容 | Output | Risk | 🚩 |
|------|------|--------|------|----|
| S1 | 現状調査: eval-runner.py argparse/8-aspect・#228 5項目・fixture 構造 | メモ | low | - |
| S2 | judge-prompt テンプレ docs（#228 5項目→judge 化・#230 正規化前処理参照） | docs | med | 🚩AC-5,6 |
| S3 | eval-runner.py に --dogfood mode 追加（5項目構造判定+rationale・独立） | py差分 | high | 🚩AC-1,7 |
| S4 | eval-dogfood.md 出力（rationale 付き）・fixture 3件で sample | py+fixture | med | 🚩AC-2,3,4 |
| S5 | 回帰: 既存 eval 8-aspect 非破壊・hook/CLI・--dogfood 動作 | テスト | high | 🚩AC-7 |
| V | V-1 / V-3(Codex+Gemini) / V-4(high-risk) | レビュー | high | - |
## Files
- scripts/eval-runner.py(--dogfood mode 追加) / bin/plangate(usage 追記) /
  docs/ai/dogfooding-eval.md(judge prompt 正本) / tests/fixtures/eval-runner/
  (sample-task ×3) / docs eval-dogfood サンプル
## Testing Strategy
- --dogfood が fixture TASK で5項目判定+eval-dogfood.md 生成
- 既存 `eval <TASK>`（8-aspect）出力不変（回帰）
- judge prompt が #228 5項目と一致 / #230 正規化参照あり / #229 timeline 読込
- hook 78/0・CLI 64/0・eval-runner 非破壊
## Risks & Mitigations
- R1: judge 揺らぎ→v1 構造判定主・LLM rationale 補助・決定論部分を AC 化
- R2: eval-runner 破壊→--dogfood は argparse 独立サブ・既存パス不変
- R3: #230 未マージ→gate-event-normalization 参照は依存明記(F2 §5-bis パターン)
## Mode判定
**モード**: high-risk（judge設計/eval統合/LLM揺らぎ。V-3+V-4 必須）
