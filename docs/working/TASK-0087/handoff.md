# Handoff — TASK-0087 / #225 バージョニング安定性ポリシー明文化

## 1. 要件適合確認結果
| AC | 内容 | 判定 |
|----|------|------|
| AC1 | Schema/Hook/Workflow/CLI 別 Breaking Change 定義 | PASS (T1) |
| AC2 | コンポーネント別 Stable/Beta/Experimental 宣言 | PASS (T2) |
| AC3 | CHANGELOG 影響度タグ + 記載例 | PASS (T3) |
| AC4 | 安定版（LTS）運用方針 | PASS (T4) |
| AC5 | oss-governance.md から到達 | PASS (T5) |
V-1: 全 PASS（light のため V-3 スキップ）。

## 2. 既知課題
- CHANGELOG 既存エントリへの遡及タグ付けは未実施（Out of scope）。
- 影響度タグの CI 強制（付与漏れ検出 lint）は未実装。

## 3. V2 候補
- 次回リリース PR から影響度タグ運用を実適用し、付与漏れ検出を CI 化。
- #224 release archive 方式確定時に §6 LTS 方針を再評価・具体化。
- release-please 設定と `feat!:` 運用ガイドの整合明文化。

## 4. 妥協点
- LTS ブランチは「当面採用なし」に留めた（単一 active line 維持）。複数 major
  並行保守の需要が顕在化していない現状でブランチ運用コストを避けるため。

## 5. 引き継ぎ文書
#225 を docs only / light で実装。正本 `docs/ai/versioning-stability-policy.md`
を新規作成し Breaking Change 定義（4 コンポーネント）・安定性レベル宣言・
CHANGELOG 影響度タグ・移行ガイド要件・LTS 方針を規定。`oss-governance.md`
に参照節を追加。release-please 採番ロジック・CI 強制は変更せず後続 PBI。
次は #226 段階的導入ガイド。

## 6. テスト結果サマリ
T1-T5 + E1 すべて PASS（grep 構造突合）。c3.json schema required/plan_hash OK。
