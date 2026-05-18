# EXECUTION PLAN — TASK-0103 / #281

## Goal
reporting に test/dev 構造化フィルタと run(task-set) スコープを opt-in 追加。
未指定で従来 period 挙動と完全等価。

## Constraints / Non-goals
- schema/period 破壊・run_id インフラ新設・承認境界変更・#282 はしない。

## Approach Overview
_is_test_hook_row（構造化判定）+ _hook_violations(exclude_test) +
collect(only_tasks,exclude_test) + main 引数(--exclude-test-hooks/--tasks 共に
opt-in default off)。reporting.md §4-bis に判定軸・limitation 明文化。2 期間
in-place 等価 + フィルタ/スコープ smoke + 全スイートで検証。

## Work Breakdown
| Step | Output | Owner | Risk | 🚩 |
|------|--------|-------|------|----|
| S1 | _is_test_hook_row + filter/scope 配線 | agent | 中 | 🚩 AC1/2 |
| S2 | reporting.md §4-bis 明文化 | agent | 低 | 🚩 AC1/5 |
| S3 | 等価+フィルタ+スコープ+全スイート | agent | 中 | 🚩 AC2/3/4 |

## Files / Components to Touch
- scripts/reporting.py / docs/ai/reporting.md（単独）

## Testing Strategy
- Verification: opt-in 未指定で main 版と 2 期間 in-place 等価 /
  --exclude-test-hooks で 3340→1082 減少 / --tasks で対象限定・空 exit2 /
  run-tests.sh 全件 / scope=reporting.py+reporting.md のみ / compile。

## Risks & Mitigations
- 実 violation 誤除外 → 構造化キー（HOOKTEST/fixtures）限定・`-` 残置
- period 破壊 → opt-in default off・2 期間 in-place 等価で機械保証

## Questions / Unknowns
なし

## Mode判定
**モード**: standard
**判定根拠**: reporting.py + doc・opt-in 追加・behavior-preserving 検証要 →
standard（V-3 実施）
