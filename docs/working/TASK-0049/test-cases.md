# TEST CASES: TASK-0049 / Issue #156

## 受入基準 → テストケースマッピング

| AC | TC | 種別 |
|----|----|----|
| AC-1 | TC-1 | fixture 経由で eval 実行 |
| AC-2 | TC-2 | output 内 8 観点行確認 |
| AC-3 | TC-3 | schema 違反 → exit 1 |
| AC-4 | TC-4 | --baseline 動作 |
| AC-5 | TC-5 | tests/run-tests.sh TA-07 PASS |
| AC-6 | TC-6 | docs/ai/eval-runner.md 存在 |
| AC-7 | TC-7 | eval-result.json を schema validate |

## テストケース

### TC-1〜TC-5: 統合テスト（tests/run-tests.sh TA-07）

```sh
sh tests/run-tests.sh
# 期待: TA-07 で 3 件 PASS（sample task / stdout / usage）
```

### TC-3: schema 違反 → release blocker

```sh
# 既存 TASK-0044 の c3.json は _review_summary を含み schema fail
sh bin/plangate eval TASK-0044 --no-write 2>&1 | grep "release blocker"
# 期待: "format_adherence: schema compliance ... < 95%"
echo $?  # 期待: 1
```

### TC-4: --baseline 比較

```sh
sh bin/plangate eval TASK-9990 --baseline TASK-9990 --no-write 2>&1 | grep "Baseline 比較"
# 期待: ヒット
```

### TC-6: docs

```sh
test -f docs/ai/eval-runner.md && grep -q "8 観点の機械評価" docs/ai/eval-runner.md
# 期待: 0
```

### TC-7: schema validate eval-result.json

```sh
# fixture から eval-result.json を生成し schema validate
python3 scripts/eval-runner.py TASK-9990  # eval-result.json 出力
sh bin/plangate validate-schemas docs/working/TASK-9990/eval-result.json 2>&1
# 期待: PASS（FILENAME_TO_SCHEMA に eval-result.json マッピングなし → SKIP も許容）
# 注: 本 PBI ではマッピング登録は scope 外（別 PBI で validate-schemas に追加）
```
