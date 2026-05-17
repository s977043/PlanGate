# テストケース — TASK-0099
| ID | AC | 期待 | 種別 |
|----|----|------|------|
| T1 | AC1 | keep-rate.py: 一括 git show・_unknown/_ratio・UNKNOWN/REFERENCED 定数・_read_c3_plan_hash(json)・top hashlib | 構造突合+compile |
| T2 | AC2 | context-engine.py: _POLICY_ORDER 単一・c3 json・nesting 緩和・コメント trim | 構造突合+compile |
| T3 | AC3 | 両ファイル出力が main 版と in-place 等価（TASK-0095/0087/0090/0096）| 機械等価比較 |
| T4 | AC4 | context-engine MJ-2 回帰（plan_hash 無→invalidated+exit1）+ schema validate PASS | smoke |
## Edge
- E1: re/json import 整合・py_compile OK
