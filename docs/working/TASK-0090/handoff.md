# Handoff — TASK-0090 / #224 Plugin モード成熟化と移行パス
## 1. 要件適合確認
| AC | 判定 |
|----|------|
| AC1 Plugin 安定性宣言（コンポーネント別） | PASS (T1) |
| AC2 release archive バージョン同期 | PASS (T2, V-3 MJ-1 反映) |
| AC3 カスタマイズ API（overlay precedence/境界/記録） | PASS (T3) |
| AC4 手動コピー版移行 Step1-4 | PASS (T4) |
| AC5 既存 doc / versioning-policy 相互参照 | PASS (T5, 前方参照=#263 マージ順依存・§4-bis 記録) |
| AC6 hooks/rules 上書き境界 + 人間承認 | PASS (T6, V-3 MJ-3 反映) |
V-1 全 PASS。V-3（Codex）critical 0 / major 3 / minor 3 → 全反映・回帰 PASS。
## 2. 既知課題
- **マージ順依存**: versioning-stability-policy.md は #225/PR #263 のファイル。
  推奨マージ順 #263 → 本 PR（#264）。本書 §1 に安定性定義を自己完結内挿済の
  ため本 PR 先行でもリンクは #263 マージで解決（読解は可能）。
- §3.1 versioning-policy → plugin-stability-and-sync 逆リンクは #263 マージ後の
  後続（本ブランチに当該ファイル無いため未実施）。
- 消費側 CI のバージョン乖離検出は手順正本まで（実装は別 PBI）。
## 3. V2 候補
- `bin/plangate` に plugin 同期サブコマンド（release archive 取得自動化）。
- 消費側 CI 用バージョン突合スクリプト + GitHub Action テンプレ。
- #263 マージ後に versioning-policy §3.1 へ逆リンク追記（小 PBI）。
## 4. 妥協点
- 同期方式を release archive に確定（submodule/npm 不採用＝消費側に新規依存を
  強制しないユーザー決定）。実装（スクリプト/サブコマンド）は Out of scope。
## 5. 引き継ぎ
#224 を standard/docs で実装。plugin-stability-and-sync.md を正本化（安定性
宣言/release archive 同期/overlay カスタマイズ API/手動コピー版移行 Step1-4）。
plangate-plugin-migration.md から逆参照を結線。V-3 で展開パス(strip=3)・未存在
正本依存・hooks overlay 境界矛盾・version 2 軸を修正。これで #224-#227（OSS
採用基盤 4 件）すべて実装完了。マージ順は #263→#264 推奨。
## 6. テスト結果
V-1: T1-T6 + E1/E2 全 PASS。V-3 反映後回帰全 PASS。

## 7. C-4 ラウンド更新（PR #266 / 2026-05-17）
- #263/#264/#265 マージ済（#225/#226/#227 CLOSED）。本 PR は main 追従済（0 behind）。
- versioning-stability-policy.md が main 在席 → 前方参照リンク解決済（§4-bis 改題）。
- gemini-code-assist medium 3 件全反映: ghost-file 冪等化 / 消費側相対リンク 4 箇所を絶対 URL 化 / #263 マージ済表現更新。
- 回帰 V-1 全 PASS・shell 構文 OK。残: #224 / PR #266 の人間承認＋マージのみ（Human-owned）。
