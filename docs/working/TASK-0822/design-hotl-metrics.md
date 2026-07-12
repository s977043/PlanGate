# TASK-0822 項目3: HOTL健全性メトリクス 設計

親: #822 EPIC。既存 scripts/ai-loop/metrics.py の collect() を拡張する（additive・既存フィールド不変）。

## Goal

collect() の戻り値に以下を追加し、HOTLが安全に機能しているかを事後監査可能にする:

1. escalate_rate: HUMAN_ESCALATED の全体に占める割合（decision_countsから導出）
2. human_intervention_rate: HUMAN_ESCALATED + BLOCKED の割合（人間が最終的に関与した割合）
3. reversal_rate: 同一run_id内で、あるroundがBLOCKED/HUMAN_ESCALATEDの後、後続roundでAUTO_APPROVEDに至ったrunの割合（reject後の巻き戻し=収束したrunの比率）。run_countが0の場合はNone

## 実装方針（additive・既存ロジック不変）

- decision_counts dictを読むだけでescalate_rateとhuman_intervention_rateは算出できる
- reversal_rateは既存の_group_by_run()が返すgrouped構造を再利用し、各runについて「途中に非AUTO_APPROVEDがあり最終roundがAUTO_APPROVED」を判定する
- 分母0のケースはfirst_passのdenominator=0パターンに倣いrate: Noneを返す

## 出力への追加（既存キー不変・新キーのみ）

report["hotl_health"] = {
  "escalate_rate": {"count": N, "total": M, "rate": float|None},
  "human_intervention_rate": {"count": N, "total": M, "rate": float|None},
  "reversal": {"reversed_runs": N, "run_count": M, "rate": float|None},
}

render_markdown()に「## HOTL健全性」セクションを追加。

## テスト

- decision_counts={AUTO_APPROVED:8,HUMAN_ESCALATED:2,BLOCKED:1}のescalate_rate/human_intervention_rateを厳密一致で検証
- round1=BLOCKED→round2=AUTO_APPROVEDのrunがreversed_runsにカウントされる
- 全roundAUTO_APPROVEDのrunはreversedにカウントされない
- 最終roundがHUMAN_ESCALATEDのまま終わるrunはreversedにカウントされない（未収束）
- run_count=0の場合reversal.rateがNone
- 既存全テストが回帰なく通ること

## 制約

既存フィールドを変更しない・後方互換を壊さない
