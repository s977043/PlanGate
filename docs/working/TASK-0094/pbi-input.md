# PBI INPUT — TASK-0094 / #204 PBI-HI-011 PlanGateBench Fixture Suite

## Context / Why
Harness Eval expansion(#196) を安定運用するには、毎回同じ評価ケースで
profile/prompt/workflow/context 変更を比較できる固定 fixture が必要。
代表パターン未固定だと比較対象が揺れ改善/劣化判断が不安定。

## What
- In: examples/eval-fixtures/**（8 fixture・各 fixture.md）/ docs/ai/plangatebench.md
  （正本+追加ルール）/ docs/ai/eval-runner.md（接続注記）
- Out: 完全自動実行エンジン / 全 provider 網羅 / 外部 benchmark 互換 /
  LLM judge 採点 / performance benchmark

## 受入基準（#204）
- AC1: PlanGateBench fixture directory が存在
- AC2: 代表 fixture 5 件以上
- AC3: 各 fixture に eval focus / expected behavior 記載
- AC4: scope discipline / approval discipline / verification honesty を含む fixture
- AC5: bin/plangate eval との接続方針が記載
- AC6: PBI-HI-002(#196) eval comparison と矛盾しない
- AC7: fixture 追加ルールが plangatebench.md に記載

## Notes
fixture は「シナリオ定義の固定」（非実行・契約）。#196 schema 非変更。
fixture 名はリネーム=破壊的（versioning-policy §2）。

## Estimation
Risks: #196 と矛盾（緩和: schema 非変更・補完位置付け明記）/ Non-goal 侵食
（緩和: 各 fixture に非実行注記）/ Unknowns: なし
