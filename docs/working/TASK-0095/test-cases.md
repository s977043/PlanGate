# テストケース — TASK-0095 / #197
| ID | AC | 期待 | 種別 |
|----|----|------|------|
| T1 | AC1 | schema $defs/profile に edit_interface_preference | 機械検証 |
| T2 | AC2 | schema に retry_strategy（on_edit/on_test/max_retries/backoff）| 機械検証 |
| T3 | AC3 | schema に context_acquisition（strategy/initial_context_budget）| 機械検証 |
| T4 | AC4 | schema に provider_capabilities（supports_*）| 機械検証 |
| T5 | AC5 | yaml version:2 + 4 profile が v2 フィールド保持・jsonschema valid | 機械検証 |
| T6 | AC6 | legacy_or_unknown が存在し安全側（escalate/lazy/patch非対応）| 構造突合 |
| T7 | AC7 | yaml/md に Core Contract/Gate/Artifact schema 不変明記 | 構造突合 |
| T8 | AC8 | md に #196 eval comparison で v1 baseline 比較（harness_metadata profile）記載 | 構造突合 |
## Edge
- E1: v1（version=1・v2フィールドなし最小 profile）が jsonschema valid（後方互換）
- E2: telemetry_tags が pattern 制約（鍵/秘匿不可・privacy §4 注記）
