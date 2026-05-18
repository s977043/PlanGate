# Handoff — TASK-0103 / #281 reporting 精度 follow-up
## 1. 要件適合確認
| AC | 判定 |
|----|------|
| AC1 test/dev 除外+判定軸明文化 | PASS（_is_test_hook_row 構造化・§4-bis）|
| AC2 run スコープ・未指定 period 等価 | PASS（V-3 MJ-1: hook も限定・task_count とスコープ一致）|
| AC3 events/log 不在で従来等価 | PASS（opt-in default off・2 期間 in-place 等価）|
| AC4 全スイート回帰なし | PASS（68 passed 0 failed）|
| AC5 reporting.md 運用手順+精度限界 | PASS（§4-bis 判定軸/run スコープ/run_id limitation）|
V-1 全 PASS。V-3（Codex）REQUEST_CHANGES→major 2 全反映→回帰 PASS。

## 2. 経緯
#281/#282 状態確認 + Codex 相談 →「#281=Do（最小・承認境界外・reporting
単独）/ #282=Defer（承認境界・Human トリガ）」確定。#281 実装、V-3 で
--tasks の hook スコープ漏れ/空入力判定を是正。

## 3. 既知課題 / V2
- 真の run-id スコープは run_id インフラ新設要＝Out-of-scope。--tasks は
  run=TASK セットの軽量近似（§4-bis 明記）。
- #282（check-plan-hash.sh strict 化）は承認境界ゆえ Defer（別 issue・Human トリガ）。

## 4. 妥協点
- run スコープは run_id でなく TASK セット近似（インフラ新設回避・Codex 助言）。
- 両機能 opt-in default off（behavior-preserving 厳守）。

## 5. 引き継ぎ
#281: reporting に test/dev 構造化フィルタ（TASK-HOOKTEST/tests/fixtures・
`-`/実TASK 残置＝実 violation 隠さない）と run(task-set)スコープを opt-in 追加。
未指定で従来 period 完全等価。V-3 で hook violation も run スコープ限定・
空入力 exit2 を是正。#282 は Defer（Human トリガ待ち）。

## 6. テスト結果
V-1 AC1-5 + V-3 反映後: 2 期間 in-place 等価 / フィルタ 3381→1103 /
run スコープ task_count・hook 一致 / --tasks '' exit2 / run-tests 68/0。
