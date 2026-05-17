# PBI INPUT — TASK-0095 / #197 PBI-HI-003 Model Profile v2

## Context / Why
Core Contract/Gate/Artifact schema はモデル非依存だが、編集形式の得手不得手・
失敗回復方針・provider capability はモデル別。差分をプロンプト全文 fork でなく
Model Profile v2 に閉じ込め、provider/model 別実行スタイルを選択可能にする。

## What
- In: schemas/model-profile.schema.json（v2 additive）/ docs/ai/model-profiles.yaml
  （v2 移行）/ docs/ai/model-profiles.md（v2 doc）
- Out: モデル別プロンプト全文 fork / provider runtime 全面刷新 / Cursor/Gemini/
  OpenCode 完全実装 / Dynamic Context Engine 実装 / Keep Rate 算出

## 受入基準（#197）
- AC1: edit_interface_preference が schema 化
- AC2: retry_strategy が schema 化
- AC3: context_acquisition が schema 化
- AC4: provider_capabilities が schema 化
- AC5: 既存 profile が v2 に移行
- AC6: legacy_or_unknown fallback 維持
- AC7: Core Contract/Gate/Artifact schema をモデル別に変更しない明記
- AC8: PBI-HI-002(#196) eval comparison で v1 baseline と比較できる

## Notes
新 5 フィールドは optional・version enum[1,2]＝v1 後方互換。retry_strategy の
category 正本は #203(PR#269 前方参照)。#196(PR#268) で v1↔v2 比較。telemetry_tags
は privacy §4 準拠（鍵/秘匿不可）。

## Estimation
Risks: schema v1 破壊（緩和: optional+version enum・v1 validate 確認）/
#203/#196 前方参照（緩和: 依存・マージ順明記）/ Unknowns: なし
