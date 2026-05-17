# テストケース — TASK-0097 / #199
| ID | AC | 期待 | 種別 |
|----|----|------|------|
| T1 | AC1 | context-manifest.schema.json 存在・JSON 妥当 | 機械検証 |
| T2 | AC2 | manifest に contract_context/dynamic_context 分離（kind enum 別）| 構造突合 |
| T3 | AC3 | context TASK --phase execute --profile p で manifest md/json 出力 | smoke |
| T4 | AC4 | mode 別 budget（ultra_light=compact/3 … critical=expanded/24）適用 | smoke |
| T5 | AC5 | plan_hash 不一致注入で approved_plan stale/invalidated + exit 1 | smoke |
| T6 | AC6 | context-engine.md に Prompt Assembly 4層接続方針 + EH-3 整合 | 構造突合 |
| T7 | AC7 | 明示 CLI のみ動作（bin/plangate diff=context 追加のみ・既存非破壊）| 構造突合 |
## Edge
- E1: 生成 context-manifest.json が schema validate PASS
- E2: C-3/C-4 緩和なし・ゲート非代替が doc/note に明記
