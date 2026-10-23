# TASK-1608 INDEX

> 最終更新: 2026-10-24 (plan 生成時)
> 更新契約: `.claude/rules/working-context.md`「INDEX.md（L0 索引）の鮮度契約」に従う。

## チケット概要（1-2文）

`scripts/improvement_seed_delta.py` の正規表現による Markdown 構造推定を、標準ライブラリの行単位ブロック状態機械へ置き換える（#1608）。#1574 で 4 ラウンド続けて新しい回避クラスが出たための設計変更。

## 現在のフェーズ

C-3 待ち

## 次のアクション

Human が C-3 判断（Q-1〜Q-4 への回答を含む）→ APPROVED の `approvals/c3.json` を Human が発行 → exec（todo T-1 から）。

## ファイルマップ（読み込み優先度）

| ファイル | フェーズ依存 | 説明 |
|---------|------------|------|
| pbi-input.md | plan, review | 要件・受入基準 AC-1〜9 |
| plan.md | exec, review | 実行計画（Mode: high-risk / 敵対レビュー下限 2） |
| todo.md | exec | タスク一覧 |
| test-cases.md | exec, review | 回避クラス台帳の回帰ケース |
| review-self.md | C-3, review | C-1 結果 |
| status.md | status, 復旧 | フェーズ履歴 |
| current-state.md | status, 復旧 | 現在状態 |
| decision-log.jsonl | 監査 | 判断履歴 |

## 変更ファイル一覧（概要）

`scripts/improvement_seed_delta.py` / `scripts/test_improvement_seed_delta.py`（HO パスなし）
