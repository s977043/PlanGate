# TASK-1544 INDEX

> 最終更新: 2026-11-13 15:00
> 更新契約: `.claude/rules/working-context.md`「INDEX.md（L0 索引）の鮮度契約」に従い、
> plan 完了時に生成し、**以降はフェーズ遷移のたびに更新する**。

## チケット概要（1-2文）

Growth Harness L1（#1544）。`retro_enabled: true` かつ C-3 APPROVED の run だけで handoff の既知課題から seeds 下書きを作り、`confirmed_by` 入りの下書きだけを seeds に追記する最小の生成器と、その機械検査 TA-118 を追加する。

## 現在のフェーズ

C-2（plan.md への移行待ち。C-2 指摘 R-001〜R-009 と敵対レビュー R1 の R-010〜R-017 を plan-draft.md 等へ反映済み・簡易 C-1: PASS・WARN 1 件。C-2 R2 未実施。Mode: high-risk）

## 次のアクション

C-2 敵対レビュー R2（是正が効いているか・是正が新しい穴を生んでいないか）→ `PLANGATE_HOOK_TASK=TASK-1544` で起動したセッションで plan-draft.md を plan.md へ移し plan-draft.md を削除 → Human が C-3 を判断し `approvals/c3.json`（確定後 plan の plan_hash）を発行 → exec

## ファイルマップ（読み込み優先度）

| ファイル | フェーズ依存 | 説明 |
|---------|------------|------|
| pbi-input.md | plan, review | 要件・受入基準 |
| plan-draft.md | plan, review | 実行計画（plan.md へ移行待ち） |
| review-external.md | C-3, review | C-2 指摘 R-001〜R-017・回避クラス台帳・監査表 |
| status.md | status | フェーズ履歴 |
| todo.md | exec | タスク一覧 |
| test-cases.md | exec, review | 組合せ表・変異注入計画 |
| review-self.md | C-3, review | C-1 結果 |

## 変更ファイル一覧（概要）

`scripts/retro_seed_draft.py`（新規）, `tests/extras/ta-118-retro-seed-draft.sh`（新規）, `docs/workflows/06_retro.md`
