# PBI INPUT PACKAGE: TASK-0062 (PBI-HI-001 / Issue #195)

## Why
EPIC #193 後続改善 (Eval expansion / Model Profile v2 / Keep Rate / Dynamic Context Engine) を比較で判断するため、PlanGate workflow event を構造化 metrics として保存・集計可能にする。

## What
In scope:
- plangate-event.schema.json
- metrics_collector.py（TASK 配下から event 導出 + NDJSON append）
- metrics_reporter.py（events.ndjson から TASK / aggregate summary）
- bin/plangate metrics サブコマンド
- .gitignore で events.ndjson 除外（privacy §8）
- docs/ai/metrics.md 運用手順
- tests/extras/ta-09-metrics.sh smoke test

Out: ダッシュボード、LLM judge、Keep Rate、Dynamic Context、外部DB、hook 自動 emit (v8.7+)

## Mode
high-risk（コード追加 + schema + CLI + tests + 既存 .gitignore 修正）

## AC
Issue #195 の 7 項目
