# PBI INPUT — TASK-0102 / #200 v2: reporting の v1/fix_loop を events 厳密化

## Context / Why
#200 dogfooding 振り返り（本セッション run）で v1_first_pass が最低シグナル
（観測 1/32）と判明。status.md ヒューリスティックは低精度。Metrics v1 の
events.ndjson（v1_completed/fix_loop_incremented）が決定論正本。ユーザー指示
「improvement-seeds を 1 件実装」で本候補（#200 handoff §3 既記載 v2）を選定。

## What
- In: scripts/reporting.py — events.ndjson 由来で v1_first_pass/fix_loop を
  厳密導出、events 不在時は status.md ヒューリスティックへ fallback。
  metrics_reporter.load_events を再利用（再実装回避）。
- Out: 他 improvement-seeds（hook test フィルタ/run-id スコープ）/ events
  schema 変更 / status.md ヒューリスティック削除 / hook violation・C-3/C-4 変更

## 受入基準
- AC1: events.ndjson の v1_completed(verdict)/fix_loop_incremented(fix_loop_count)
  から v1_first_pass/fix_loop を導出（precedence: events > status.md > unknown）
- AC2: events 不在（gitignore・clean checkout）で従来挙動と完全等価
  （behavior-preserving）
- AC3: events 存在時に厳密値が反映（初回 v1_completed PASS→True / FAIL→False、
  fix_loop_count max）
- AC4: metrics_reporter.load_events を再利用（reporting に再実装しない）
- AC5: 全スイート回帰なし（run-tests.sh）

## Notes
events.ndjson は .gitignore 対象（metrics.md §2）→ clean checkout で不在＝
load_events []→status.md fallback で従来挙動。reporting.py のみ変更
（metrics_reporter/_paths/shell/bin/schema 不変）。

## Estimation
Risks: events 不在で挙動変化（緩和: in-place 等価検証 2 期間）/ 再実装重複
（緩和: load_events 再利用）/ Unknowns: なし
