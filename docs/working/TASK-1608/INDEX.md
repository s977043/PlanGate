# TASK-1608 INDEX

> 最終更新: 2026-10-27 10:00（plan 改訂 4 を確定反映、C-3 再承認待ち）
> 更新契約: `.claude/rules/working-context.md`「INDEX.md（L0 索引）の鮮度契約」に従う。

## チケット概要（1-2文）

`scripts/improvement_seed_delta.py` の正規表現による Markdown 構造推定を、標準ライブラリの行単位ブロック状態機械へ置き換える（#1608）。#1574 で 4 ラウンド続けて新しい回避クラスが出たための設計変更。

## 現在のフェーズ

C-3 待ち

## 次のアクション

plan 改訂 4（改訂 3 + L2 R-013〜R-018・D-017 hashFiles ガード）の C-3 再承認（Human、plan_hash 変更。既存 c3.json 24a35af0… は無効）。簡易 C-1 は WARN（review-self.md）。承認後 T-23〜T-26、HO patch（`ho/`）は Human が feature ブランチ → PR で #1611 より先に main へ（H-6）。

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
