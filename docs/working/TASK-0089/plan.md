# EXECUTION PLAN — TASK-0089 / #227

## Goal
C-2/V-3 外部レビューア接続を正規化し PlanGate+river-reviewer 併用時の設定・
データフロー・責務分担を正本化（3 導入パターン選択可能化）。

## Constraints / Non-goals
- docs + schema + example のみ。bin/plangate review 実装は変更しない。
- review-principles §7-bis の 2 レーン責務契約・5 観点・判定基準を変更しない。
- events 発火実装は別 PBI（参照定義まで）。

## Approach Overview
external-reviewer-interface.md を正本化（IF / 変換 / severity / 責務 / 3 パターン）。
plangate-reviewers.schema.json で機械検証可能化。.plangate-reviewers.example.yaml
を最小構成例として提供（.example で非有効化）。§7-bis・contracts/review.md から
接続 IF として参照（契約不変・ポインタ追記のみ）。

## Work Breakdown
| Step | Output | Owner | Risk | 🚩 |
|------|--------|-------|------|----|
| S1 | external-reviewer-interface.md 正本 | agent | 中 | 🚩 AC1-4 |
| S2 | plangate-reviewers.schema.json + example | agent | 中 | 🚩 AC5 schema validate |
| S3 | §7-bis / contracts 接続（契約不変） | agent | 中 | 🚩 AC6 矛盾なし |

## Files / Components to Touch
- docs/ai/external-reviewer-interface.md（新規）
- schemas/plangate-reviewers.schema.json（新規）
- .plangate-reviewers.example.yaml（新規・非有効）
- .claude/rules/review-principles.md（§7-bis ポインタ追記・契約不変）
- docs/ai/contracts/review.md（関連リンク追記）

## Testing Strategy
- Verification: AC1-6 を grep 構造突合 + schema を python json.load + example を
  jsonschema validate（PyYAML/jsonschema 利用、無ければ schema JSON 妥当性のみ）。
- Unit/E2E: 該当なし（IF 定義・実行系非変更）。

## Risks & Mitigations
- 二重定義リスク → §7-bis を正本参照、IF は接続のみと明記
- severity 語彙乖離 → §3.2 を唯一の変換点・未知は安全側 major
- example の誤有効化 → `.example.yaml` 命名で非有効・コピー手順明記

## Questions / Unknowns
- river-reviewer Finding JSON の正確なキー名 → #802 準拠を前提（変換表は論理対応）

## Mode判定
**モード**: standard
**判定根拠**:
- 変更ファイル数: 5 → 中
- 受入基準数: 6 → 中
- 変更種別: feat（IF + schema 新規）→ 中
- リスク: 中（外部接続規約・既存契約との整合要）
- **最終判定**: standard（V-3 外部レビュー実施）
