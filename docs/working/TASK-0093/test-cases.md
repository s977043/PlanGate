# テストケース — TASK-0093 / #203
| ID | AC | 期待 | 種別 |
|----|----|------|------|
| T1 | AC1 | docs/ai/tool-error-taxonomy.md 存在 | ファイル存在 |
| T2 | AC2 | 9 category（edit_patch_failure…unknown_tool_error）一覧 | 構造突合 |
| T3 | AC3 | §3 Recovery policy に category 別ポリシー | 構造突合 |
| T4 | AC4 | retryable/soft_warning/release_blocker 境界表 | 構造突合 |
| T5 | AC5 | tool-error-taxonomy §7 + model-profiles §8-bis retry_strategy 接続 | 構造突合 |
| T6 | AC6 | schema に tool_error event + tool_error_category（jsonschema validate）+ metrics §3.5 | 機械検証 |
| T7 | AC7 | §6 unknown→backlog 還流（EPIC #193 PBI 化）運用 | 構造突合 |
## Edge
- E1: schema additive 非破壊（既存 hook_violation event が 1.0 で valid のまま）
- E2: core-contract §5 が正本参照化（重複定義なし）
- E3: Non-goal C-3/C-4 緩和なし明記
