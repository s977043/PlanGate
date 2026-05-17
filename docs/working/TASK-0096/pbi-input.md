# PBI INPUT — TASK-0096 / #198 PBI-HI-004 Keep Rate v1

## Context / Why
AI が生成した code/plan/test-cases/handoff が PR merge 後・後続 PBI で
どれだけ残ったか未計測。「生成」でなく「採用・残存」を改善対象にする。

## What
- In: scripts/keep-rate.py / bin/plangate keep-rate / schemas/keep-rate-result.schema.json /
  docs/ai/keep-rate.md（正本）/ scripts/schema_mapping.py 登録
- Out: 外部分析基盤 / GitHub 全履歴完全解析 / LLM judge 満足度 / DCE / release blocker 強制

## 受入基準（#198）
- AC1: Code Keep Rate を算出できる
- AC2: Plan Keep Rate を算出できる
- AC3: Acceptance Keep Rate を算出できる
- AC4: Handoff Keep Rate の定義と算出方針が文書化
- AC5: 算出不能時は unknown と明記
- AC6: results が JSON/Markdown で保存
- AC7: docs/ai/keep-rate.md に運用手順
- AC8: PBI-HI-001 metrics と接続できる

## Notes
決定論・軽量（ローカル git+artifact のみ）。advisory（ゲート非使用）。
unknown は 0 でなく測定不能/未観測。event schema 非変更（#203/#197 と非衝突）。

## Estimation
Risks: 全履歴解析誘惑（緩和: git log --grep+存続率の軽量近似）/ ゲート誤用
（緩和: advisory 明記・Non-goal）/ Unknowns: なし
