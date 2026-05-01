# TEST CASES: TASK-0053 / Issue #167

| AC | TC | 検証 |
|----|----|------|
| AC-1 | TC-1 | 6 PBI で validate-schemas PASS |
| AC-2 | TC-2 | 6 PBI で eval blocker 0 |
| AC-3 | TC-3 | 既存 c3.json 無変更（git diff で確認）|
| AC-4 | TC-4 | typo（`c3_statu`）が依然として拒否される |
| AC-5 | TC-5 | tests/run-tests.sh 21 PASS |

## TC-1
```sh
for t in TASK-0039 TASK-0040 TASK-0041 TASK-0042 TASK-0043 TASK-0044; do
  sh bin/plangate validate-schemas $t/approvals/c3.json && echo "$t: OK"
done
```

## TC-2
```sh
for t in TASK-0039 TASK-0040 TASK-0041 TASK-0042 TASK-0043 TASK-0044; do
  python3 scripts/eval-runner.py $t --no-write 2>&1 | grep -A2 "Release Blocker" | grep "なし"
done
# 期待: 6 行ヒット
```

## TC-4
```sh
echo '{"task_id":"TASK-0001","phase":"C-3","c3_statu":"APPROVED","approved_by":"x","approved_at":"2026-01-01T00:00:00Z","plan_hash":"sha256:0000000000000000000000000000000000000000000000000000000000000000"}' > /tmp/typo-c3.json
sh bin/plangate validate-schemas /tmp/typo-c3.json
# 期待: FAIL (c3_status missing + c3_statu unknown)
```
