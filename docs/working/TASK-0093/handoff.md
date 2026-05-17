# Handoff — TASK-0093 / #203 PBI-HI-010 Tool Error Taxonomy and Recovery Policy
## 1. 要件適合確認
| AC | 判定 |
|----|------|
| AC1 tool-error-taxonomy.md 存在 | PASS |
| AC2 category 一覧（10）| PASS |
| AC3 category 別 recovery policy | PASS |
| AC4 release blocker/soft warning/retryable 境界 | PASS |
| AC5 Model Profile v2 retry_strategy 接続 | PASS |
| AC6 Metrics v1 event schema 記録方針（schema additive + 機械検証）| PASS (V-3 MJ-1 反映) |
| AC7 unknown→harness backlog 還流運用 | PASS |
V-1 全 PASS。V-3（Codex）critical 0 / major 2 / minor 3 → 全反映・回帰 PASS。
## 2. 既知課題
- tool_error event の自動 emit 実装は別 PBI（本 PBI は taxonomy + schema +
  記録方針まで。runtime 実装は Non-goal）。
- delegation_unavailable は分類上 retryable* だが実体は topology fallback
  （回数 retry はしない・注記済）。
## 3. V2 候補
- metrics_collector.py に tool_error 自動導出（hook-events/エラーログから）。
- retry_strategy を model-profiles.yaml に実値域として追加（#197 連携）。
- unknown_tool_error 集計の #200 Reporting 連携で新 category PBI 化の自動提案。
## 4. 妥協点
- schema は additive のみ（tool_error 専用 conditional + schema_version 1.1
  固定）。runtime 自動 emit・自動修復は実装せず方針定義に留める（Non-goal）。
## 5. 引き継ぎ
#203 を standard で実装。tool-error-taxonomy.md 正本（10 category/severity/
recovery/classification/metrics/backlog/profile 接続）、plangate-event.schema
additive（tool_error + tool_error_category + conditional）、core-contract §5
集約・model-profiles §8-bis・metrics §3.8 接続。V-3 で schema conditional /
別軸明記 / fallback 注記 / 採番を修正。これで v8.7.0 残: #204 PlanGateBench Fixture。
## 6. テスト結果
V-1: AC1-7 + E1-E3 全 PASS。V-3 反映後 schema 正/異常/非破壊を jsonschema 機械確認。
