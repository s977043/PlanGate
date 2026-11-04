# TASK-1544 INDEX

> 最終更新: 2026-10-26 06:25
> 更新契約: `.claude/rules/working-context.md`「INDEX.md（L0 索引）の鮮度契約」に従い、
> plan 完了時に生成し、**以降はフェーズ遷移のたびに更新する**。

## チケット概要（1-2文）

Growth Harness L1（#1544）。`retro_enabled: true` かつ C-3 APPROVED の run だけで handoff の既知課題から seeds 下書きを作り、`confirmed_by` 入りの下書きだけを seeds に追記する最小の生成器と、その機械検査 TA-118 を追加する。

## 現在のフェーズ

C-3 待ち（C-1: PASS・WARN 1 件。C-2 未実施）

## 次のアクション

Human が C-3 を判断し `approvals/c3.json` を発行 → `PLANGATE_HOOK_TASK=TASK-1544` で起動したセッションで exec

## ファイルマップ（読み込み優先度）

| ファイル | フェーズ依存 | 説明 |
|---------|------------|------|
| pbi-input.md | plan, review | 要件・受入基準 |
| plan.md | exec, review | 実行計画 |
| todo.md | exec | タスク一覧 |
| test-cases.md | exec, review | 組合せ表・変異注入計画 |
| review-self.md | C-3, review | C-1 結果 |

## 変更ファイル一覧（概要）

`scripts/retro_seed_draft.py`（新規）, `tests/extras/ta-118-retro-seed-draft.sh`（新規）, `docs/workflows/06_retro.md`
