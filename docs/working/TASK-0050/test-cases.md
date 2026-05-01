# TEST CASES: TASK-0050 / Issue #170

| AC | TC | 検証 |
|----|----|------|
| AC-1 | TC-1 | `sh tests/run-tests.sh` で 21/21 PASS |
| AC-2 | TC-2 | `tests/extras/` 配下に 4 ファイル + README、本体は loader 化 |
| AC-3 | TC-3 | README に「新規追加手順」セクションあり |

## TC-1

```sh
sh tests/run-tests.sh
# 期待: Results: 21 passed, 0 failed
```

## TC-2

```sh
ls tests/extras/
# 期待: README.md ta-04-check-pr-issue-link.sh ta-05-validate-schemas.sh ta-06-hooks.sh ta-07-eval-runner.sh
grep -c "for extra in" tests/run-tests.sh
# 期待: 1 以上
```

## TC-3

```sh
grep -E "新しいテスト追加方法|新規追加手順|規約" tests/extras/README.md
```
