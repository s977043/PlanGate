# Handoff — TASK-0096 / #198 PBI-HI-004 Keep Rate v1
## 1. 要件適合確認
| AC | 判定 |
|----|------|
| AC1 Code Keep Rate 算出 | PASS（allowlist 化・docs/schema は unknown 正規化）|
| AC2 Plan Keep Rate 算出 | PASS（plan_hash 実検証付き）|
| AC3 Acceptance Keep Rate 算出 | PASS（AC 突合 coverage 注記）|
| AC4 Handoff Keep Rate 定義/算出方針 | PASS（keep-rate.md §3）|
| AC5 算出不能=unknown 明記 | PASS（reason 付き・0 と区別）|
| AC6 results JSON/Markdown 保存 | PASS（schema validate）|
| AC7 keep-rate.md 運用手順 | PASS（§6）|
| AC8 PBI-HI-001 metrics 接続 | PASS（別系統 artifact・event schema 非変更）|
V-1 全 PASS。V-3（Codex）critical 0/major 3/minor 2 → 全反映・回帰 PASS。
## 2. 既知課題
- Code Keep Rate は git log token 境界 + 存続率の軽量近似（全履歴 blame は
  Non-goal）。docs/schema 主体 TASK は「no code files」= unknown（設計通り）。
- Acceptance は handoff AC 表書式依存。書式差異時は unknown + coverage 注記。
## 3. V2 候補
- metrics events.ndjson 直接連携（fix_loop/v1_first を events 由来に）。
- Handoff Keep Rate の意味的参照判定（#200 Reporting 連携）。
- Code Keep Rate の行 blame 精密化（重い解析・別 PBI）。
## 4. 妥協点
- 決定論・軽量に限定（GitHub 全履歴解析/LLM judge/外部基盤は Non-goal）。
  advisory（ゲート非使用）で承認境界不変。
## 5. 引き継ぎ
#198 を standard で実装。keep-rate.py（4 メトリクス・unknown フォールバック）
+ keep-rate-result.schema.json + schema_mapping 登録 + bin/plangate keep-rate
+ keep-rate.md 正本。stash 退避→ main 再ブランチ復元時に bin/plangate・
schema_mapping を #213(plan-check)/#268/#269 と統合解消。V-3 で allowlist /
token 境界 / plan_hash 実検証 / AC 突合 を反映。
**EPIC #193 残: #199 Dynamic Context Engine v1 / #200 Reporting（次バッチ）。**
## 6. テスト結果
V-1: AC1-8 + E1/E2 全 PASS。V-3 反映後 smoke/schema 機械確認 PASS。
