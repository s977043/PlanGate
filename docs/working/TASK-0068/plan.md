# EXECUTION PLAN: TASK-0068

## Goal
v8.6.0 機能を機械可読化、自動化、時刻フィルタで完結。

## Mode
high-risk

## Approach
1. metrics_reporter.py に render_markdown_section / filter_since、CLI args (--markdown-section / --since)
2. main() 分岐に --markdown-section 優先（json と排他）
3. bin/plangate cmd_metrics に --markdown-section / --since 追加
4. scripts/doctor_check.py 新設（16 check の JSON 出力）
5. cmd_doctor に --json 早期分岐（python script へリダイレクト）
6. handoff template / metrics.md 更新
7. ta-09 +5 cases

## Files
- scripts/metrics_reporter.py (修正)
- scripts/doctor_check.py (新規)
- bin/plangate (修正、metrics と doctor)
- docs/working/templates/handoff.md (修正、コマンド例)
- docs/ai/metrics.md (修正、§3.7 追加)
- tests/extras/ta-09-metrics.sh (修正)
- docs/working/TASK-0068/* (新規)

## Test
- 自動: tests/run-tests.sh 48 → 52 (一部既存テスト変更ないので +5 だが既存 by_mode で +1 → 計 +5 程度)
- 手動: bin/plangate metrics --markdown-section / --since / bin/plangate doctor --json
