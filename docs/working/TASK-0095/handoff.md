# Handoff — TASK-0095 / #197 PBI-HI-003 Model Profile v2
## 1. 要件適合確認
| AC | 判定 |
|----|------|
| AC1 edit_interface_preference schema 化 | PASS |
| AC2 retry_strategy schema 化 | PASS |
| AC3 context_acquisition schema 化 | PASS |
| AC4 provider_capabilities schema 化 | PASS |
| AC5 既存 profile v2 移行 | PASS |
| AC6 legacy_or_unknown fallback 維持 | PASS（escalate/lazy/patch非対応/max_retries:0）|
| AC7 Core Contract/Gate/Artifact schema 不変明記 | PASS（yaml+md）|
| AC8 #196 eval comparison で v1 baseline 比較 | PASS（前方参照明記）|
V-1 全 PASS（v1 後方互換含む）。V-3（Codex）critical 0/major 1/minor 2 → 全反映。
## 2. 既知課題
- **前方参照依存**: retry 対象 category 正本 = #203/PR #269、v1↔v2 比較 CLI =
  #196/PR #268。推奨マージ順: PR #268・#269 → 本 PR（未マージでも schema/yaml/
  doc は単独有効、CLI/category 正本連携のみ従属）。
- runtime での profile 適用（edit_interface 切替・retry 実行）は別 PBI（本 PBI
  は schema/設定/doc の判定根拠まで）。
## 3. V2 候補
- runtime で edit_interface_preference / retry_strategy を実行（provider adapter）。
- telemetry_tags を metrics events に接続（#198 Keep Rate / #200 Reporting）。
- 新 provider/世代の enum 追加（additive・別 PBI）。
## 4. 妥協点
- telemetry を free-form でなく固定 enum registry に（privacy 構造排除を優先・
  拡張は schema 改訂 additive）。runtime 実装は Non-goal で判定根拠に留める。
## 5. 引き継ぎ
#197 を standard で実装。model-profile.schema v2（version enum[1,2]+5 optional）、
model-profiles.yaml v2 移行（4 profile・legacy 安全側）、md §8-bis v2 doc。
V-3 で telemetry enum 化 / yaml コメント所属 / legacy max_retries:0 を修正。
次は #198 Keep Rate v1。
## 6. テスト結果
V-1: AC1-8 + E1/E2 全 PASS。V-3 反映後 v2/v1 jsonschema 機械確認 PASS。
