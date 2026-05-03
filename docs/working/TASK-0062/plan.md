# EXECUTION PLAN: TASK-0062 (PBI-HI-001 Metrics v1)

## Goal
Metrics v1 を opt-in で実装し、後続 EPIC #193 改善の効果測定基盤を提供する。

## Mode 判定
- 変更ファイル数: 9 → high-risk
- 受入基準数: 7 → standard寄り
- 変更種別: 機能追加 (CLI / schema / scripts / tests) → high-risk
- リスク: 中（既存挙動 opt-in、CLI 表面拡張のみ）
- **最終判定**: **high-risk**（mode-classification 表通り）

## Approach

### コンポーネント
1. JSON Schema (`schemas/plangate-event.schema.json`)
   - 11 event types (issue #195 表通り)
   - privacy: §3 Allowed のみ、§4 Forbidden は schema にも生やさない
   - conditional required (c3/c4/v1/hook/fix_loop)
2. Collector (`scripts/metrics_collector.py`)
   - TASK ディレクトリ → event NDJSON
   - dry-run / events-log オーバーライド対応
   - mode 自動検出 (plan.md から regex)
   - ✅PASS/❌FAIL/⚠️WARN マーカーから AC count
3. Reporter (`scripts/metrics_reporter.py`)
   - --task / --aggregate / --json
   - hook violation / C-3 / V-1 / C-4 / fix_loop_max を集計
4. CLI wrapper (`bin/plangate metrics`)
   - --collect (default) / --report / --aggregate / --json / --events-log
5. .gitignore 追記 (privacy §8 準拠)
6. doc (`docs/ai/metrics.md`)
7. test (`tests/extras/ta-09-metrics.sh`、8 テストケース)

## Files
| File | 種別 |
|------|-----|
| schemas/plangate-event.schema.json | 新規 |
| scripts/metrics_collector.py | 新規 |
| scripts/metrics_reporter.py | 新規 |
| bin/plangate | 修正 (cmd_metrics 追加 + dispatcher + help) |
| .gitignore | 修正 (events.ndjson 除外) |
| docs/ai/metrics.md | 新規 |
| tests/extras/ta-09-metrics.sh | 新規 |
| docs/working/_metrics/.gitkeep | 新規 (placeholder) |
| docs/working/TASK-0062/* | 新規 (PBI artifacts) |

## Testing
- L-0: markdown lint, shellcheck
- V-1: 受入基準 7 項目
- 自動: tests/run-tests.sh で 32/32 PASS（ta-09: 8 cases 含む）
- Schema validation: jsonschema による全 event 検証

## Risks
- (低) bin/plangate の既存 dispatcher 修正で他コマンドに影響 → 既存テスト全 PASS で確認
- (低) 既存 .gitignore 修正で他ファイルに影響 → 末尾追加のみ
- (低) python 3.10+ syntax (dict union `|`) → 既存 eval-runner.py が同 syntax を採用済み、host check 済み
