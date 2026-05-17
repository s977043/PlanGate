# EXECUTION PLAN — TASK-0090 / #224

## Goal
Plugin モードの安定性・バージョン同期（release archive）・カスタマイズ API・
手動コピー版移行を正本化し、消費側の二重管理を解消可能にする。

## Constraints / Non-goals
- docs のみ。plugin.json/plugin 実ファイル/同期スクリプト/消費側改修は変更しない。
- 既存 plangate-plugin-migration.md の段階移行・FAQ を再定義しない（参照）。
- 同期方式は release archive に確定（submodule/npm 不採用、ユーザー決定）。

## Approach Overview
新規正本 docs/ai/plugin-stability-and-sync.md：§1 安定性宣言（versioning §3
整合）/ §2 release archive 同期（pin/update/検証）/ §3 カスタマイズ API
（overlay precedence/可否境界/記録）/ §4 手動コピー版移行 Step1-4。既存
migration doc と versioning-policy §3.1 から相互参照を結線。

## Work Breakdown
| Step | Output | Owner | Risk | 🚩 |
|------|--------|-------|------|----|
| S1 | plugin-stability-and-sync.md 正本 | agent | 中 | 🚩 AC1-4,AC6 |
| S2 | migration doc / versioning-policy 相互参照 | agent | 低 | 🚩 AC5 |

## Files / Components to Touch
- docs/ai/plugin-stability-and-sync.md（新規）
- docs/plangate-plugin-migration.md（手動コピー版移行 正本リンク追加）
- docs/ai/versioning-stability-policy.md（§3.1 Plugin row リンク）

## Testing Strategy
- Verification: AC1-6 を grep 構造突合（test-cases.md）。bash 取得手順は
  構文確認（コマンド形のみ・実行はしない＝消費側手順）。
- Unit/E2E: 該当なし（docs・実行系非変更）。

## Risks & Mitigations
- 既存 doc 二重定義 → 段階移行は既存正本参照、本書は手動コピー起点+同期+
  カスタマイズに限定
- カスタマイズでゲート無効化 → §3.2 で rules/hooks 上書き境界 + 人間承認要件
- 同期方式の将来見直し → versioning-policy §6 LTS と連動する旨明記

## Questions / Unknowns
- 消費側 CI でのバージョン乖離検出は任意（本 PBI は手順正本まで）

## Mode判定
**モード**: standard
**判定根拠**:
- 変更ファイル数: 3 → 中
- 受入基準数: 6 → 中
- 変更種別: feat（成熟化正本・外部採用 IF）→ 中
- リスク: 中（消費側運用契約・既存 doc 整合）
- **最終判定**: standard（V-3 外部レビュー実施）
