# TASK-1651 INDEX

> 最終更新: 2026-11-13 10:00
> 更新契約: `.claude/rules/working-context.md`「INDEX.md（L0 索引）の鮮度契約」に従う。

## チケット概要

ta-10 TC-7 の絶対パス漏れ検査を `/Users/` 固定から OS 非依存の再帰検査（`project_root` 1 キーのみ許可）に直し、docstring と契約を揃える（issue #1651）。

## 現在のフェーズ

C-3 待ち

> **plan.md への移行が必要**（TASK 文脈付きセッション）。計画本文は `plan-draft.md` にあり、c3.json はまだ発行できない。
> C-2: APPROVE（minor 3 / info 1、R-001〜R-004 を反映済み。review-external.md）。
> 簡易 C-1 判定: WARN（critical=0, major=0, minor=1: D-1 の Human 確認）。

## 次のアクション

1. `PLANGATE_HOOK_TASK=TASK-1651` のセッションで plan-draft.md を plan.md へ移す（plan-draft.md は削除）
2. Human が `bin/plangate approve TASK-1651`（C-3。D-1 の明示確認を含む）
3. exec（todo.md T-1 から）

## ファイルマップ

| ファイル | 説明 |
|---------|------|
| pbi-input.md | 要件・受入基準 |
| plan-draft.md | 計画本文（plan.md へ移動予定） |
| todo.md | タスク一覧 |
| test-cases.md | テストケース・変異注入計画 |
| review-self.md | C-1 結果 |
| review-external.md | C-2 指摘 R-001〜R-004 と監査表 |
| status.md | フェーズ履歴 |

## 変更ファイル一覧（概要）

`tests/extras/ta-10-doctor-fix.sh`（TC-7 / TC-7b）、`scripts/doctor_check.py`（docstring のみ）
