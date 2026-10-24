# TASK-1608 INDEX

> 最終更新: 2026-10-24 10:00（Human 裁定 (c) で plan 改訂、再承認待ち）
> 更新契約: `.claude/rules/working-context.md`「INDEX.md（L0 索引）の鮮度契約」に従う。

## チケット概要（1-2文）

`scripts/improvement_seed_delta.py` の正規表現による Markdown 構造推定を、標準ライブラリの行単位ブロック状態機械へ置き換える（#1608）。#1574 で 4 ラウンド続けて新しい回避クラスが出たための設計変更。

## 現在のフェーズ

C-3 待ち

## 次のアクション

Human 裁定 (c)（D-011）を plan D-1b / AC-11 / TC-CB-* / todo T-13〜T-16 に反映済み、簡易 C-1 PASS。Human が改訂 plan を再承認し、新しい plan_hash で `approvals/c3.json` を再発行 → exec 再開（T-13 から）。既存の c3.json は初版の plan_hash で、本改訂には無効。V-1 判定は handoff.md §1（WARN、中間）。

## ファイルマップ（読み込み優先度）

| ファイル | フェーズ依存 | 説明 |
|---------|------------|------|
| pbi-input.md | plan, review | 要件・受入基準 AC-1〜11 |
| plan.md | exec, review | 実行計画（Mode: high-risk / 敵対レビュー下限 2） |
| todo.md | exec | タスク一覧 |
| test-cases.md | exec, review | 回避クラス台帳の回帰ケース |
| review-self.md | C-3, review | C-1 結果 |
| review-external.md | review | 敵対レビュー R1〜R4 と回避クラス台帳 |
| handoff.md | 引き継ぎ | 中間 handoff（BLOCKED 時点） |
| evidence/test-runs/ | 根拠 | RED ログ・単体ログ・変異注入・現行データ出力 |
| status.md | status, 復旧 | フェーズ履歴 |
| current-state.md | status, 復旧 | 現在状態 |
| decision-log.jsonl | 監査 | 判断履歴 |

## 変更ファイル一覧（概要）

`scripts/improvement_seed_delta.py` / `scripts/test_improvement_seed_delta.py`（HO パスなし）
