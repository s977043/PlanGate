# TEST CASES: TASK-0047 / Issue #158

## 受入基準 → テストケースマッピング

| AC | TC | 種別 |
|----|----|----|
| AC-1 | TC-1 | grep verification（5 contracts）|
| AC-2 | TC-2 | yaml syntax + paths filter |
| AC-3 | TC-3 | fixture: invalid → exit 1 |
| AC-4 | TC-4 | fixture: valid → exit 0 |
| AC-5 | TC-5 | grep `validate-schemas` in eval-cases |
| AC-6 | TC-6 | CI behavior on PR with no JSON |
| AC-7 | TC-7 | structured-outputs.md § 8 存在 |

## テストケース

### TC-1: contracts schema reference

```sh
for f in plan review verify handoff classify; do
  grep -q "schema-validate" "docs/ai/contracts/$f.md" \
    && echo "$f: OK" \
    || echo "$f: MISSING"
done
# 期待: 全 5 件 OK
```

### TC-2: workflow yaml syntax

- `.github/workflows/schema-validate.yml` が存在
- `on: pull_request:` + `paths:` に `docs/working/**/*.json` を含む

### TC-3: invalid → FAIL

```sh
sh bin/plangate validate-schemas tests/fixtures/schema-validate/invalid/c3.json
# 期待: exit 1, "FAIL" を含む出力
```

### TC-4: valid → PASS

```sh
sh bin/plangate validate-schemas tests/fixtures/schema-validate/valid/c3.json
# 期待: exit 0, "PASS=1" を含む出力
```

### TC-5: format-adherence Detection

```sh
grep -q "validate-schemas" docs/ai/eval-cases/format-adherence.md
# 期待: 一致
```

### TC-6: 既存 PBI で skip

PR が `docs/working/**/*.json` を一切編集しなければ、workflow は paths filter により起動しない（または起動しても 0 件で skip step 通過）。

### TC-7: structured-outputs.md § 8

```sh
grep -E "^## 8\. CI 統合" docs/ai/structured-outputs.md
# 期待: 一致
```
