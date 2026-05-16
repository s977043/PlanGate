# WF-06 Retro（opt-in 終端フェーズ）

> PlanGate × Workflow/Skill/Agent ハイブリッドアーキテクチャ 実行層 / 終端 phase（opt-in）
> 起源: field feedback #235。関連: #228（テンプレ）/ #200（集計）/ #231（judge）

## 目的

run（PBI/TASK）完了時に振り返りドラフトを生成し、改善ネタを append-only で
蓄積する。**自動なのはドラフトのみ・確定は人間**（承認境界を撤廃しない）。

## opt-in 起動（既定 OFF）

本フェーズは **既定で発火しない**。正本の opt-in source は
**C-3 承認済み pbi-input の `retro_enabled: true`** のみ
（[`docs/ai/retro-phase.md`](../ai/retro-phase.md) §1）。
明示コマンド `/ai-dev-workflow TASK-XXXX retro` は**将来 CLI（未実装）**で
現時点の正本起動方式ではない。env による有効化は採用しない。
未指定 run は WF-05 handoff で完了し、本フェーズは存在しないものとして扱う。

## 入力

- WF-05 の handoff（完了資産）
- 対象 run の status.md / current-state.md（事実参照のみ）

## 完了条件

- #228 固定 5 項目のドラフトが生成されている
  （目的達成可否 / 失敗・手戻り / 次回再利用すべき判断 /
  効いた skill・gate・artifact / 1 人運用で負荷が高かった箇所）
- ドラフトは **スコアリング（良し悪し判定）を含まない**（#231 judge と責務非重複）
- 人間が 1 行で confirm / skip している
- confirm 時、`docs/working/improvement-seeds.md` に append-only で 1 エントリ追記されている
- skip 時、seeds 追記なしで run は正常終了している

## 呼び出す Skill

- `retrospective-improvement`（Retro カテゴリ。テンプレ仕様は #228 に従う＝
  本 phase は #228 を再定義せず実行フェーズ化する接続層）

## 主担当 Agent

- `retrospective-analyst`（ドラフト生成のみ。確定は人間）

## 次への引き継ぎ

- artifact: **improvement-seeds**（`docs/working/improvement-seeds.md`、append-only、run またぎ累積）
- 受け取り先: #200 期間集計 CLI（improvement-seeds.md を入力源に吸い上げ）

## 制約（Rule 1 準拠）

本 phase 定義は順序と完了条件のみ。生成手順・観点は Skill / Agent に委譲。
既定 ON 化・全 run 強制発火・自動確定は **禁止**（#228 設計判断との両立条件）。
