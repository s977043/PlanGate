# PBI INPUT — TASK-0097 / #199 PBI-HI-005 Dynamic Context Engine v1

## Context / Why
高度モデル・複数 provider 対応に phase/mode/profile 別 context 組み立てが要る
が、PBI/C-3 承認 plan/test-cases/approval は契約コンテキストとして固定すべき。
両者を分離し Prompt Assembly・EH-3 と矛盾しない Context Engine v1 を作る。

## What
- In: schemas/context-manifest.schema.json / scripts/context-engine.py /
  bin/plangate context / docs/ai/context-engine.md（正本）/ schema_mapping 登録
- Out: Vector DB/embedding / 全 prompt の engine 移行 / C-3・C-4 緩和 /
  Keep Rate 算出 / provider runtime 全面刷新

## 受入基準（#199）
- AC1: context-manifest.schema.json が存在
- AC2: contract と dynamic context が分離
- AC3: bin/plangate context <TASK> --phase execute --profile <p> で resolved 出力
- AC4: mode/profile に応じた context budget 適用
- AC5: stale plan/stale c3 が Hook/validate と矛盾しない
- AC6: Prompt Assembly 接続方針が context-engine.md に記載
- AC7: 既存 workflow を壊さず opt-in で使える

## Notes
opt-in（明示実行のみ）。EH-3 plan_hash と同方向（stale→invalidated・exit 1
advisory、ゲート置換せず補完）。決定論（Vector なし）。承認境界不変。

## Estimation
Risks: EH-3 と矛盾（緩和: plan_hash 実照合・invalidated・ゲート非代替明記）/
opt-in 破壊（緩和: 明示 CLI のみ・既存非破壊 diff 検証）/ Unknowns: なし
