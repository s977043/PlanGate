# テストケース — TASK-0096 / #198
| ID | AC | 期待 | 種別 |
|----|----|------|------|
| T1 | AC1 | keep-rate.py が Code Keep Rate（git log --grep 存続率）算出 | smoke |
| T2 | AC2 | Plan Keep Rate（todo done 比率）算出 | smoke |
| T3 | AC3 | Acceptance Keep Rate（handoff AC PASS 比率）算出 | smoke |
| T4 | AC4 | keep-rate.md §3 に Handoff Keep Rate 定義+算出方針 | 構造突合 |
| T5 | AC5 | 算出不能で value:"unknown"+reason（0 でない）| smoke |
| T6 | AC6 | keep-rate-result.{json,md} 保存 + JSON が schema validate | 機械検証 |
| T7 | AC7 | keep-rate.md §6 運用手順 | 構造突合 |
| T8 | AC8 | keep-rate.md §5 metrics(PBI-HI-001) 接続方針（別系統・event schema 非変更）| 構造突合 |
## Edge
- E1: advisory/ゲート非使用が JSON note + doc + 出力に明記
- E2: event schema(plangate-event) 未変更（#203/#197 非衝突）
