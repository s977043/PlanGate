# Handoff — TASK-0089 / #227 river-reviewer 外部レビューア標準 IF
## 1. 要件適合確認
| AC | 判定 |
|----|------|
| AC1 .plangate-reviewers.yaml IF 定義 | PASS (T1) |
| AC2 Finding→review-external 変換 + severity 1:1 | PASS (T2) |
| AC3 責務分担表（C-1/C-2/V-1/V-3） | PASS (T3) |
| AC4 3 導入パターン | PASS (T4) |
| AC5 JSON Schema + example validate | PASS (T5, V-3 MJ-1 反映後も PASS) |
| AC6 §7-bis 接続・契約不変 | PASS (T6) |
V-1 全 PASS。V-3（Codex）critical 0 / major 1 / minor 1 → 全反映・回帰 PASS。
## 2. 既知課題
- river-reviewer Finding JSON の正確なキー名は s977043/river-reviewer#802 準拠前提（論理対応表）。実 IF 結線時に突合が必要。
## 3. V2 候補
- bin/plangate review が .plangate-reviewers.yaml を読み込む実装（本 PBI は IF 定義まで）。
- events 発火実装（review_id/lane/severity/reflected_in/status、#230 連携）。
- river-reviewer 側 #802 と双方向の設定例同期。
## 4. 妥協点
- 実行系（bin/plangate review）変更を Out of scope とし IF/schema/example に限定（接続規約の正本化を優先）。
## 5. 引き継ぎ
#227 を standard で実装。external-reviewer-interface.md を正本化、
plangate-reviewers.schema.json + .plangate-reviewers.example.yaml を提供、
review-principles §7-bis / contracts/review.md へ接続（既存 2 レーン契約は不変）。
V-3 で output_mapping 必須化（schema/doc 整合）と導入パターン表の schema 整合を修正。
これで #224-227 のうち #225/#226/#227 完了。残り #224 Plugin 成熟化。
## 6. テスト結果
V-1: T1-T6 + E2 全 PASS。V-3 反映後回帰 T1/T4/T5 PASS。example schema validate PASS。
