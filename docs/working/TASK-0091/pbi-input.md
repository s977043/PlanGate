# PBI INPUT — TASK-0091 / #213 PBI-PQ-001 Lightweight Plan Quality Checks

## Context / Why
gstack 的な重い AI ワークフローを直接移植せず、PlanGate の初期価値「計画品質」
を軽量に構造化する。計画の不足・リスク・前提・完了条件・次アクションを
JSON で抽出し、将来の Gate/Review/QA/Release 拡張の土台にする。

## What
- In: schemas/plan-quality-check.schema.json / .claude/skills/plan-quality-check/SKILL.md /
  docs/ai/plan-quality-checks.md（正本）/ bin/plangate plan-check 軽量サブコマンド
- Out: gstack slash command 移植 / browser daemon / PR review automation /
  QA automation / Release・Security Gate / AI 判定の人間承認代替

## 受入基準（#213）
- AC1: Plan/Risk/Done Check の責務が文書化
- AC2: Missing Items/Risks/Assumptions/Done Criteria/Next Actions の出力構造定義
- AC3: Plan Health Score の最小内訳定義
- AC4: AI 出力が自由文だけでなく JSON として扱える
- AC5: 軽量 Check は手動実行できる
- AC6: Check 結果を Plan の状態として保存できる方針
- AC7: heavy Gate/PR review/browser QA に依存しない
- AC8: gstack は参考思想に留め直接移植しない方針が明記

## Notes
skill は Rule 2 準拠（案件固有名なし）。decision は助言で承認境界不変。
schema は issue 提案構造に準拠。CLI は --init/--validate のみ（AI 非起動）。

## Estimation
Risks: skill への案件固有混入（緩和: Rule 2 機械検出）/ CLI が重くなる
（緩和: scaffold+validate のみ）/ Unknowns: なし
