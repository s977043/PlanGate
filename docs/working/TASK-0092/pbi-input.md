# PBI INPUT — TASK-0092 / #196 PBI-HI-002 Eval comparison for harness changes

## Context / Why
profile/prompt/workflow 変更の採用を「感覚」でなく eval 比較で判断するため、
PBI-HI-000 baseline と PBI-HI-001 metrics を踏まえ、ハーネス変更前後比較を
eval-runner で扱えるようにする。

## What
- In: scripts/eval-runner.py（additive --harness-compare）/ schemas/eval-comparison.schema.json /
  scripts/schema_mapping.py 登録 / docs/ai/eval-runner.md / docs/ai/eval-comparison-template.md /
  bin/plangate（cmd_eval 素通しで対応済）
- Out: 新 LLM judge / 外部ダッシュボード / 全 provider session log parser / Keep Rate / Dynamic Context

## 受入基準（#196）
- AC1: baseline と target の比較結果が出せる
- AC2: release blocker が比較結果に明示される
- AC3: latency/cost/hook violation/V-1 first pass/fix loop count が比較対象に含まれる
- AC4: profile/prompt/workflow 変更の metadata を記録できる
- AC5: 代表 TASK 3 件以上で比較できる
- AC6: docs/ai/eval-runner.md に運用手順が追記されている
- AC7: PBI-HI-000 の baseline と接続できる

## Notes
既存 8 観点・build_eval_result を再利用（judge 非新設）。--harness-compare は
--dogfood と同じ additive 独立 early-return（既存挙動不変）。測定不能メトリクスは n/a。

## Estimation
Risks: 既存 eval パス破壊（緩和: additive early-return・既存テスト不変）/
Unknowns: なし / Assumptions: baseline JSON は PBI-HI-000 形式
