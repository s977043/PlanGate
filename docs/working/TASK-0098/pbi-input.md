# PBI INPUT — TASK-0098 / #200 PBI-HI-006 Reporting & Retrospective

## Context / Why
eval/metrics/Keep Rate の結果をメンテナ個人確認に閉じず、sprint
retrospective で使え次の改善 PBI へ変換できる形にする。継続運用化。

## What
- In: scripts/reporting.py / bin/plangate report / docs/ai/reporting.md（正本）/
  docs/working/templates/retrospective-template.md
- Out: Web dashboard / 外部 BI 連携 / Slack・Discussions 自動投稿 /
  LLM judge を hard gate / C-3・C-4 緩和

## 受入基準（#200）
- AC1: bin/plangate report --from --to で期間指定 report
- AC2: metrics/eval/keep rate を集計
- AC3: sprint retrospective に貼れる Markdown 生成
- AC4: docs/ai/reporting.md に運用手順
- AC5: retrospective template に AI harness improvement 用の問い追加
- AC6: 次の harness improvement PBI 候補を抽出できる

## Notes
決定論・ローカル artifact のみ（events.ndjson は任意）。keep-rate-result.json
は #198/PR#272 提供（無ければ '-'・前方参照）。advisory・承認境界不変。

## Estimation
Risks: fix_loop 日付誤マッチ（緩和: 1-2桁・非日付・上限50・smoke 検証済）/
keep-rate 前方参照（緩和: 任意入力・graceful）/ Unknowns: なし
