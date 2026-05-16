---
task_id: TASK-0076
artifact_type: plan
schema_version: 1
status: draft
---

# EXECUTION PLAN — TASK-0076 F5-BC（C-2 責務分離 + 反映差分管理）

## Goal

C-2 を 2 レーン（設計妥当性 / コードベース整合）に責務分離し、C-2 指摘を
review-external.md 追記専用に集約・exec 開始時 1 回確定反映する運用を確立。
承認境界・5 観点は不変。

## Constraints / Non-goals

- 承認境界・review-principles の 5 観点・Severity 定義は変更しない
- A(Lite分岐)/D(C-3降格) は TASK-0077（別 PBI）
- #227/#200/#230 の実装本体は Non-goal（責務契約/接続点の定義のみ）
- 強制 Hook 追加なし（プロセス/doc のソフト改善）

## Approach Overview

1. C-2 責務契約（2 レーン・読む/読まない・実装詳細は V-3）を review-principles
   または C-2 正本に定義
2. C 反映フロー（review-external.md 追記専用集約・exec 開始時 1 回確定・
   指摘ID→反映コミット差分追跡）を working-context / workflow に定義
3. #227/#200/#230 への接続点を参照定義
4. 既存観点・承認境界の不変を回帰確認

## Work Breakdown

| Step | 内容 | Output | Owner | Risk | 🚩 |
|------|------|--------|-------|------|----|
| S1 | 現状調査: review-principles / C-2 記述 / working-context 反映フロー / #227 #200 #230 | 調査メモ | agent | low | - |
| S2 | 差分追跡の具体形 意思決定（指摘ID採番 / コミット trailer / events）→ C-3 | design note | agent | med | 🚩C-3判断 |
| S3 | B: C-2 2 レーン責務契約を定義（review-principles or C-2 正本） | 差分 | agent | med | 🚩AC-1〜3 |
| S4 | C: review-external 追記専用集約 + exec開始時1回確定 + 差分追跡 を定義 | 差分 | agent | med | 🚩AC-4〜6 |
| S5 | working-context / 該当 workflow に C 反映フロー反映 | 差分 | agent | med | 🚩AC-7 |
| S6 | #227/#200/#230 接続点参照定義 | 差分 | agent | low | 🚩AC-6 |
| S7 | 既存観点・承認境界不変 + doc 整合 回帰 | テスト結果 | agent | med | 🚩AC-8 |
| V | V-1 / V-3（standard: Codex+Gemini） | レビュー | agent | med | - |

## Files / Components to Touch（S1 確定）

- `.claude/rules/review-principles.md`（C-2 2 レーン責務契約）
- `.claude/rules/working-context.md`（C 反映フロー / review-external 追記専用）
- 該当 workflow（C-2 / 反映に言及する箇所、S1 で特定）
- #227/#200/#230 参照ドキュメント（接続点）

## Testing Strategy

- 構造検証: 2 レーン定義・読む/読まない・V-3 移譲 が grep で存在
- 反映フロー: review-external 追記専用・exec開始時1回確定・指摘ID→コミット が定義
- 不変確認: 5 観点 / Severity / 承認境界が変更されていない（diff レビュー）
- 回帰: 既存 hook テスト / doc 整合性

## Risks & Mitigations

- R1: 責務分界誤りで C-2 形骸化 → 「5 観点・承認境界不変」を明記、設計妥当性
  レーンも受入基準網羅は担保
- R2: exec開始時1回確定が C-3 後改変と誤認 → plan_hash/EH-3 と整合する運用
  （確定反映は C-3 前 or CONDITIONAL 反映として既存フローに乗せる）を明記
- R3: スコープが A/D に滲む → TASK-0077 と明示分離済

## Questions / Unknowns

- ~~差分追跡形~~ → **C-3確定: 指摘ID（review-external に R-001..）+ 反映コミットに `Refs: R-001`。#230 events 連携は実装時 additive**

## Mode判定

**モード**: standard

**判定根拠**:
- 変更ファイル数: 3-4 → 中
- 受入基準数: 8 → 高だが doc/プロセス定義で実装軽量
- 変更種別: レビュー運用の責務分界 + 反映フロー（強制力不変） → 中
- リスク: 中（C-2 運用に触るが観点・承認境界は不変）
- **最終判定**: standard（V-3 実施・V-2/V-4 スキップ）
