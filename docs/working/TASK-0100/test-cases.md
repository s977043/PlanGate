# テストケース — TASK-0100
| ID | AC | 期待 | 種別 |
|----|----|------|------|
| T1 | AC1 | plan_hash_util に current_plan_hash/current_plan_hash_prefixed/recorded_plan_hash | 構造突合+import |
| T2 | AC2 | keep-rate/context-engine/metrics_collector が plan_hash_util 使用・local _read_c3_plan_hash 除去 | 構造突合 |
| T3 | AC3 | 3 消費者出力が main 版と in-place 等価（TASK-0095/0090/0096）| 機械等価 |
| T4 | AC4 | ta-11: 正常/注入/無=shell≡python、不正JSON=python strict 拒否(仕様) 全 PASS | テスト実行 |
| T5 | AC5 | run-tests.sh 全件 0 failed（回帰なし）| テスト実行 |
## Edge
- E1: check-plan-hash.sh 無変更（git diff 空）= 承認境界 shell 正本不触
- E2: util recorded_plan_hash が不正JSON で None（strict・承認境界保護）
