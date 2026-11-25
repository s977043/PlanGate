# TASK-1391 スライス A — T2 RED 実測（2026-11-26）

実装は未変更（branch HEAD `4b9b4394` の `scripts/ai-loop-v2/`）。追加したテストだけを走らせた結果。

## test_delivery_v2.py

```text
python3 scripts/ai-loop-v2/test_delivery_v2.py
Ran 79 tests
FAILED (failures=6, errors=72, skipped=1)
```

- 既存 28 件は全件 PASS のまま
- 追加 51 件のうち PASS は 4 件で、いずれも旧実装でも成り立つ GREEN 対照: EV-15 / EV-35 / EV-36 / PJ-15
- skip 1 件: `test_ev22_decision_event_bytes_rechecked_at_append_only`（理由「#1623 待ち（H-10 = c）」）
- EV-14 / EV-16 は旧実装で素通りしたため、新しい `plan_contract_bound` payload を受理する positive control を足して RED にした

## test_ratchet.py

```text
python3 scripts/ai-loop-v2/test_ratchet.py
Ran 49 tests
FAILED (failures=3)   # PJ-23a: evidence_status = invalid / done / 欠落 のどれでも PASS が返る
```

## R-009 の実行再現

境界（`plan_contract_bound`）なし・`inputs: []` の `MERGE_READY` decision 1 件だけの stream を旧実装で投影した。

```text
python3 <scratchpad>/r009_repro.py scripts/ai-loop-v2
ready
```
