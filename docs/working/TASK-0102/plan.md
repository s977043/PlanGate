# EXECUTION PLAN — TASK-0102 / #200 v2 events 厳密化

## Goal
reporting の v1_first_pass/fix_loop を events.ndjson 由来で厳密化、events
不在時は status.md fallback（behavior-preserving）。

## Constraints / Non-goals
- 他 improvement-seeds / events schema / status.md 削除 / hook・C-3/C-4 は
  変更しない。reporting.py 単独変更。

## Approach Overview
metrics_reporter.load_events 再利用で events.ndjson を 1 回ロード→task 別
index。_events_signals で v1_first_pass(初回 v1_completed verdict==PASS)/
fix_loop(fix_loop_incremented count max) 導出。collect で precedence
events>status.md>unknown。events 不在は [] → status.md fallback = 従来等価。

## Work Breakdown
| Step | Output | Owner | Risk | 🚩 |
|------|--------|-------|------|----|
| S1 | _events_signals + load_events 再利用 import | agent | 中 | 🚩 AC1/AC4 |
| S2 | collect precedence 統合 | agent | 中 | 🚩 AC1 |
| S3 | 等価(events不在)+厳密化(events有)+全スイート検証 | agent | 中 | 🚩 AC2/3/5 |

## Files / Components to Touch
- scripts/reporting.py（単独）

## Testing Strategy
- Verification: events 不在で main 版と in-place 等価（2 期間）/ 合成
  events.ndjson で厳密値（TASK-0095 PASS→True, TASK-0090 FAIL/fix_loop 2）/
  run-tests.sh 全件 / metrics_reporter/_paths/shell/bin 無変更 diff / compile。

## Risks & Mitigations
- 挙動変化 → events 不在 in-place 等価で機械保証（2 期間 OK）
- 再実装 → load_events 再利用（reporting に重複定義しない）
- scope → reporting.py のみ・他 git diff 空で確認

## Questions / Unknowns
なし

## Mode判定
**モード**: standard
**判定根拠**: reporting.py 単独だが events 連携・precedence ロジック追加・
behavior-preserving 検証要 → standard（V-3 実施）
