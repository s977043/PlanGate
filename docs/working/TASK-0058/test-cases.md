# TEST CASES: TASK-0058

| AC | TC | 検証 |
|----|----|------|
| AC-1 | TC-1 | EH-7 4 mode（PASS / warn / strict / bypass）|
| AC-2 | TC-2 | EHS-1 5 mode（PASS / warn / strict / light skip / bypass）|
| AC-3 | TC-3 | hook 単体 42 PASS |
| AC-4 | TC-4 | run-tests.sh 24 PASS |
| AC-5 | TC-5 | hook-enforcement v5 / 10/10 |
| AC-6 | TC-6 | PR body に closes #169 |
| AC-7 | TC-7 | 既存 8 hook 無変更 |

## TC-1（EH-7）

```sh
# fixture: BOTH_APPROVED → c3 APPROVED + c4-approval APPROVED
sh scripts/hooks/check-merge-approvals.sh TASK-HOOKTEST13 | grep PASS

# fixture: C3_ONLY → c4 不在
sh scripts/hooks/check-merge-approvals.sh TASK-HOOKTEST14 2>&1 | grep WARNING

# strict + 両方なし → exit 1
PLANGATE_HOOK_STRICT=1 sh scripts/hooks/check-merge-approvals.sh TASK-HOOKTEST15; echo "exit=$?"  # 1

# bypass overrides strict → exit 0
PLANGATE_BYPASS_HOOK=1 PLANGATE_HOOK_STRICT=1 sh scripts/hooks/check-merge-approvals.sh TASK-HOOKTEST15 | grep BYPASS
```

## TC-2（EHS-1）

```sh
# review-external あり standard → PASS
PLANGATE_HOOK_MODE=standard sh scripts/hooks/check-v3-review.sh TASK-HOOKTEST16 | grep PASS

# 不在 default → WARNING
PLANGATE_HOOK_MODE=standard sh scripts/hooks/check-v3-review.sh TASK-HOOKTEST17 2>&1 | grep WARNING

# 不在 strict + high-risk → exit 1
PLANGATE_HOOK_STRICT=1 PLANGATE_HOOK_MODE=high-risk sh scripts/hooks/check-v3-review.sh TASK-HOOKTEST17; echo "exit=$?"  # 1

# light mode → SKIP（strict 関係なし）
PLANGATE_HOOK_STRICT=1 PLANGATE_HOOK_MODE=light sh scripts/hooks/check-v3-review.sh TASK-HOOKTEST17 | grep SKIP

# bypass overrides
PLANGATE_BYPASS_HOOK=1 PLANGATE_HOOK_STRICT=1 PLANGATE_HOOK_MODE=critical sh scripts/hooks/check-v3-review.sh TASK-HOOKTEST17 | grep BYPASS
```

## TC-3 / TC-4

```sh
sh tests/hooks/run-tests.sh    # Results: 42 passed
sh tests/run-tests.sh          # Results: 24 passed
```

## TC-5

```sh
grep "Status.*v5" docs/ai/hook-enforcement.md
grep "10/10" docs/ai/hook-enforcement.md
```

## TC-6

PR 本文に `closes #169`（auto-close）。
