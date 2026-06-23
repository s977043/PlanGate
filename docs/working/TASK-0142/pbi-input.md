# PBI INPUT PACKAGE — TASK-0142

## Context / Why

Issue #493「探索的デバッグタスク対応強化」の PBI-493-02。

「仮説→検証→学習→AC 更新」の**探索ループ**と、CI/EAS ビルド等の**長時間外部検証待機**、
**インシデント駆動の計画修正**という3要件を、docs のみで先行定義する。

PlanGate の既存 workflow（WF-01〜06）は「要件が固まってから計画・実装」を前提にしており、
「やってみて初めて問題が露呈する」探索的タスクへの対応指針が不足している。

Codex 設計相談（2026-06-23）で確認:
- PBI-493-02 は docs 追加のみ・HO 非対象・独立実装可能
- 探索フェーズを WF-07 として新規定義し、既存 BLOCKED/Deferred と連携させる

## What（Scope）

### In scope

- **AC-1**: `docs/workflows/07_exploratory_debug.md` 新規作成（WF-07）
  - 探索フェーズ定義: 仮説→検証→学習→AC 更新ループ
  - 長時間外部検証: `waiting_external_verification` サブ状態（BLOCKED と連携）
  - インシデント駆動の計画修正: 検証失敗時の AC 更新手順
  - 既存 WF との接続（WF-01 からの分岐条件）
- **AC-2**: `docs/workflows/README.md` に WF-07 の参照を追加
- **AC-3**: `docs/workflows/execution-sequence.md` に探索モードの分岐を追記

### Out of scope

- acceptance-tester エージェントの改修（HO 対象）→ 別 PBI
- workflow-conductor.md の変更（HO 対象）→ 別 PBI
- PBI-493-01（長時間検証の bin/plangate コマンド）→ 別 PBI
- PBI-493-03（検証失敗ゲートの機械的強制）→ 別 PBI

## 受入基準

| ID | 基準 |
|----|------|
| AC-1 | `docs/workflows/07_exploratory_debug.md` が存在し、探索ループ・待機・修正ゲートの3要件を定義する |
| AC-2 | `docs/workflows/README.md` に WF-07 が追記される |
| AC-3 | `docs/workflows/execution-sequence.md` に探索モード分岐が追記される |
| AC-4 | markdownlint PASS（L-0）|

## Notes from Refinement

- WF-07 は WF-01〜06 と同列の「opt-in ワークフロー」として位置づける
- 「仮説」と「AC」は PlanGate の acceptance criteria と同一概念として扱う
- `waiting_external_verification` は working-context.md §BLOCKED 状態の拡張として記述

## Estimation Evidence

- Risks: doc の新設は markdownlint / リンク切れに注意
- Unknowns: execution-sequence.md の既存構造（読んでから判断）
- Assumptions: docs/workflows/ は HO 非対象（確認済み）

**モード判定**: light（doc 新設 + 既存 doc 更新 2 件、HO なし）
**変更種別**: doc
**doc-light 対象**: ✅（doc のみ、承認境界パスなし）
