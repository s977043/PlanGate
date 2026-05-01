# TEST CASES: TASK-0051 / Issue #172

| AC | TC | 検証 |
|----|----|------|
| AC-1 | TC-1 | `python3 -c 'from schema_mapping import FILENAME_TO_SCHEMA'` |
| AC-2 | TC-2 | grep で重複定義がないこと |
| AC-3 | TC-3 | `sh tests/run-tests.sh` 21 件 PASS |
| AC-4 | TC-4 | repo 全体で `c3-approval.schema.json` という string が schema_mapping.py 1 箇所のみ |

## TC-1
```sh
cd /path/to/plangate
python3 -c "import sys; sys.path.insert(0, 'scripts'); from schema_mapping import FILENAME_TO_SCHEMA, lookup_schema, SCHEMAS_DIR; print(len(FILENAME_TO_SCHEMA))"
# 期待: 16
```

## TC-2
```sh
grep -l '"c3-approval.schema.json"' scripts/*.py
# 期待: schema_mapping.py のみ
```

## TC-3
```sh
sh tests/run-tests.sh
# 期待: Results: 21 passed, 0 failed
```
