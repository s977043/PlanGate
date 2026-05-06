# PBI INPUT PACKAGE: TASK-0064 (v8.6.0 改善 PR3)

## Why
PR #209 (Metrics v1) handoff の「妥協点」で hook_violation / pr_created を「手動 append または v2」と記録した。v8.6.0 範囲の改善として自動取得を実装し、metrics の運用負荷を下げる。

## What
- A-1: metrics_collector が docs/working/_audit/hook-events.log から hook_violation を自動 emit
- A-2: metrics_collector が git log の handoff.md commit から pr_created を自動 emit
- ta-09 にテスト追加（5 cases）
- docs/ai/metrics.md §3 を「自動取得済」へ更新

Out: c4_decided（GH API 必要、v8.7+ V2 候補に残置）

## Mode
high-risk（collector ロジック追加 + テスト + doc）

## AC
- [ ] hook_violation が hook-events.log から自動 emit される
- [ ] PASS / BYPASS / 別 TASK のログは emit されない（filter 動作）
- [ ] hook_name → hook_id (EH-1〜EH-8 / EHS-1〜EHS-3) の正しい mapping
- [ ] VIOLATION → block, WARNING → warn の result mapping
- [ ] pr_created が git log から自動抽出される
- [ ] events.ndjson が valid JSON のまま、schema 妥当
- [ ] ta-09 で +5 cases 追加
- [ ] privacy §4 違反なし（message column / commit hash / branch 等は emit しない）
- [ ] 既存テスト 0 件 regress
