# Handoff — TASK-0092 / #196 PBI-HI-002 Eval comparison for harness changes
## 1. 要件適合確認
| AC | 判定 |
|----|------|
| AC1 baseline↔target 比較結果 | PASS (T1) |
| AC2 release blocker 明示 | PASS (T2) |
| AC3 latency/cost/hook/V-1 first/fix loop 比較対象 | PASS (T3) |
| AC4 profile/prompt/workflow metadata 記録 | PASS (T4) |
| AC5 代表 TASK 3 件以上 | PASS (T5) |
| AC6 eval-runner.md 運用手順追記 | PASS (T6) |
| AC7 PBI-HI-000 baseline 接続 | PASS (T7) |
V-1 全 PASS（E1 既存非破壊・E2 schema PASS 含む）。V-3（Codex）critical/major 0・
minor 2 → 全反映・APPROVE。
## 2. 既知課題
- latency/fix_loop/v1_first_pass は測定基盤が無い TASK で `n/a`（Non-goal: 全
  provider session log parser 非対応）。--session-log / metrics 連携時に充実。
- hook_violation は監査ログ依存（ログ未生成 TASK は n/a）。
## 3. V2 候補
- metrics events.ndjson との直接連携（fix_loop/v1_first_pass を events から）。
- 複数 baseline 系列の時系列比較（#200 Reporting & Retrospective と連携）。
- release gate への自動接続（regressed で CI block、人間承認は維持）。
## 4. 妥協点
- additive 設計（--harness-compare 独立 early-return）で既存 eval を一切変更
  しない方針を優先（judge 非新設・Non-goal 遵守）。測定不能値は n/a 許容。
## 5. 引き継ぎ
#196 を standard で実装。eval-runner.py に harness_compare を additive 追加
（--dogfood と同型 early-return）、eval-comparison.schema.json + mapping +
docs 2 件運用手順 + PBI-HI-000 接続。V-3 で空 targets 弾き / hook token 境界
一致を反映。これで v8.7.0 残: #203 Tool Error Taxonomy / #204 PlanGateBench Fixture。
## 6. テスト結果
V-1: T1-T7 + E1/E2 全 PASS。V-3 APPROVE・minor 2 反映後回帰全 PASS。
