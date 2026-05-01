# TEST CASES: TASK-0055

| AC | TC | 検証 |
|----|----|------|
| AC-1 | TC-1 | 6 PBI eval exit 0 |
| AC-2 | TC-2 | 数値一貫性 |
| AC-3 | TC-3 | schema compliance 100% |
| AC-4 | TC-4 | template 更新 |
| AC-5 | TC-5 | procedure v2 |

## TC-1
```sh
for t in TASK-0039 TASK-0040 TASK-0041 TASK-0042 TASK-0043 TASK-0044; do
  python3 scripts/eval-runner.py $t --no-write >/dev/null 2>&1; echo "$t exit=$?"
done
# 期待: 全件 exit=0
```

## TC-3
```sh
for t in TASK-0039 TASK-0040 TASK-0041 TASK-0042 TASK-0043 TASK-0044; do
  python3 scripts/eval-runner.py $t --no-write 2>&1 | grep "Schema compliance"
done
# 期待: 全件 "100.0%"
```

## TC-4 / TC-5
```sh
grep -E "^\| v8\.4" docs/ai/eval-comparison-template.md
grep "Status.*v2" docs/ai/eval-baseline-procedure.md
```
