# PBI INPUT — TASK-0093 / #203 PBI-HI-010 Tool Error Taxonomy and Recovery Policy

## Context / Why
ツール失敗を一時失敗で片付けず分類・回復・計測可能にする。失敗種別ごとに
回復方法が異なるため category を正規化し recovery policy を固定、Model Profile
v2 retry_strategy と Metrics v1 tool_error event に接続する。

## What
- In: docs/ai/tool-error-taxonomy.md（正本）/ schemas/plangate-event.schema.json
  （additive: tool_error event + tool_error_category）/ core-contract.md §5 集約 /
  model-profiles.md retry_strategy 接続 / metrics.md tool_error 記録
- Out: provider runtime 全面実装 / 全 provider エラー形式 / 自動修復完全実装 /
  外部監視連携 / C-3・C-4 緩和

## 受入基準（#203）
- AC1: tool-error-taxonomy.md が存在
- AC2: tool error category 一覧化
- AC3: category ごと recovery policy 定義
- AC4: release blocker/soft warning/retryable の区別定義
- AC5: Model Profile v2 retry_strategy と接続
- AC6: Metrics v1 event schema に記録できる方針
- AC7: unknown error を harness improvement backlog に戻す運用定義

## Notes
core-contract.md §5（delegation_unavailable 最小定義）を本正本に集約（参照化）。
schema は 1.1 additive（既存 event 非破壊）。Privacy: message/stack 非 emit。

## Estimation
Risks: schema 破壊（緩和: additive enum 追加・既存 event validate 確認）/
core-contract 二重定義（緩和: 参照化）/ Unknowns: なし
