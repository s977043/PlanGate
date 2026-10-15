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

## handoff 既知課題からのドラフト作成（#1544）

この手順は opt-in された run にのみ適用する。起動可否の正本は
[`retro-phase.md`](../ai/retro-phase.md) §1。high-risk 以上への opt-in
**推奨**についても同文書 §1-a を参照し、本書では新しい起動条件を作らない。

1. **起動判定**: C-3 承認済み pbi-input に `retro_enabled: true` があるか確認する。
   未指定・false・承認証跡不明の場合は、ドラフト作成も seeds 追記も行わず停止する。
2. **事実抽出**: 同じ run の WF-05 `handoff.md` の「既知課題一覧」・
   「妥協点」・「テスト結果サマリ」から候補を抽出する。
   複数の課題を複数 run として数えず、根拠を辿れない推測は未確認と扱う。
3. **ドラフト**: #228 に沿った 5 項目を作成し、`confirmed_by` は空欄にする。
   観測できなかった項目は「未確認」と書き、推測で成功や原因を補わない。
4. **人間判断**: 人間に confirm / skip を求める。自分で `confirmed_by` を埋めない。
5. **保存**: confirm が記録された場合だけ、[正本の §2](../ai/retro-phase.md) のスキーマで
   `docs/working/improvement-seeds.md` に 1 run 1 エントリを追記する。
   skip や判断未了の場合は元ファイルを変更しない。

検査観点（手動・現時点では自動化済みと主張しない）:

- `retro_enabled: false` / キーなし / C-3 未承認ではドラフトも追記も発生しない
- opt-in true でも `confirmed_by` が空欄なら追記しない
- confirm 済みの場合に限り 1 run 1 エントリが追記され、既存行は不変

## 完了条件

- #228 固定 5 項目のドラフトが生成されている
  （目的達成可否 / 失敗・手戻り / 次回再利用すべき判断 /
  効いた skill・gate・artifact / ツール・プロセス上の摩擦点）
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
