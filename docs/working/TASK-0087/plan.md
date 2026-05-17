# EXECUTION PLAN — TASK-0087 / #225

## Goal
バージョニング安定性ポリシーを正本化し、導入側が CHANGELOG だけで
アップグレード安全性を判断できる基盤を docs として提供する。

## Constraints / Non-goals
- docs のみ。release-please 採番ロジック・CI 強制は変更しない（後続）。
- 既存正本（mode-classification の lite_eligible 固定条項）と矛盾させない。

## Approach Overview
新規正本 `docs/ai/versioning-stability-policy.md` を作成。Breaking Change
定義（Schema/Hook/Workflow/CLI）・安定性レベル宣言・CHANGELOG 影響度タグ・
移行ガイド要件・LTS 方針を記載。`oss-governance.md` から参照リンクを追加。

## Work Breakdown
| Step | Output | Owner | Risk | 🚩 |
|------|--------|-------|------|----|
| S1 | versioning-stability-policy.md 作成 | agent | 低 | 🚩 AC1-4 充足確認 |
| S2 | oss-governance.md に参照節追加 | agent | 低 | 🚩 AC5 リンク到達確認 |

## Files / Components to Touch
- `docs/ai/versioning-stability-policy.md`（新規）
- `docs/oss-governance.md`（参照節追加）

## Testing Strategy
Verification: 受入基準 5 件を test-cases.md で文書構造突合（grep）。Unit/E2E: 該当なし（docs）。

## Risks & Mitigations
- 既存運用との齟齬 → 既存正本を参照し緩和不可条項を明記
- タグ運用の形骸化 → §7 で C-4 観点・安全側採用を規定

## Questions / Unknowns
なし

## Mode判定
**モード**: light
**判定根拠**:
- 変更ファイル数: 2 → 低
- 受入基準数: 5 → 中
- 変更種別: docs 新規 + 参照追加 → 低
- リスク: 低（docs のみ・実行系不変）
- **最終判定**: light（docs only・実行コード非変更のため受入基準数より実リスクを優先）
