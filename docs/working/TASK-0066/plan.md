# EXECUTION PLAN: TASK-0066

## Goal
v8.6.0 機能の整合性検査を CLI / CI 両面で常時運用化。

## Mode
high-risk

## Approach
1. bin/plangate cmd_doctor に v8.6.0 セクション追加
2. bin/plangate cmd_metrics に --validate モード追加（python3 heredoc で jsonschema validate）
3. scripts/schema_mapping.py に baseline mapping
4. .github/workflows/metrics-privacy.yml 新設
5. ta-09 に 4 cases 追加

## Files
- bin/plangate (修正、cmd_doctor + cmd_metrics + help)
- scripts/schema_mapping.py (修正)
- .github/workflows/metrics-privacy.yml (新規)
- tests/extras/ta-09-metrics.sh (修正、+4 cases)
- docs/working/TASK-0066/* (新規)

## Test
- 自動: tests/run-tests.sh 42 → 46 (regression 0)
- 手動: bin/plangate doctor / bin/plangate metrics --validate
- CI: GitHub Actions 動作確認（PR 作成後）
