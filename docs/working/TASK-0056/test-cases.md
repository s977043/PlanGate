# TEST CASES: TASK-0056

| AC | TC | 検証 |
|----|----|------|
| AC-1 | TC-1 | EH-1 3 mode |
| AC-2 | TC-2 | EH-3 3 mode |
| AC-3 | TC-3 | hook 単体 21 PASS |
| AC-4 | TC-4 | run-tests.sh 24 PASS |
| AC-5 | TC-5 | settings.example に 3 hook |
| AC-6 | TC-6 | hook-enforcement v3 |
| AC-7 | TC-7 | 既存 EH-2 挙動無変更 |

## TC-1（EH-1）
```sh
# default + plan あり → continue:true
PLANGATE_HOOK_TASK=TASK-0056 sh scripts/hooks/check-plan-exists.sh | grep '"continue":true'

# default + plan なし → continue:true + WARNING
PLANGATE_HOOK_TASK=TASK-9990 sh scripts/hooks/check-plan-exists.sh 2>&1 | grep WARNING

# strict + plan なし → continue:false
PLANGATE_HOOK_STRICT=1 PLANGATE_HOOK_TASK=TASK-9990 sh scripts/hooks/check-plan-exists.sh | grep '"continue":false'

# bypass + strict → continue:true（bypass 優先）
PLANGATE_BYPASS_HOOK=1 PLANGATE_HOOK_STRICT=1 PLANGATE_HOOK_TASK=TASK-9990 sh scripts/hooks/check-plan-exists.sh | grep '"continue":true'
```

## TC-2（EH-3）
```sh
# fixture: 一致 → exit 0 + matches
sh scripts/hooks/check-plan-hash.sh TASK-HOOKTEST07 | grep matches

# fixture: 不一致 default → exit 0 + WARNING
sh scripts/hooks/check-plan-hash.sh TASK-HOOKTEST08 2>&1 | grep WARNING

# fixture: 不一致 strict → exit 1
PLANGATE_HOOK_STRICT=1 sh scripts/hooks/check-plan-hash.sh TASK-HOOKTEST08; echo "exit=$?"  # 期待: 1

# fixture: bypass → exit 0
PLANGATE_BYPASS_HOOK=1 PLANGATE_HOOK_STRICT=1 sh scripts/hooks/check-plan-hash.sh TASK-HOOKTEST08; echo "exit=$?"  # 期待: 0
```

## TC-3〜TC-4
```sh
sh tests/hooks/run-tests.sh
# 期待: Results: 21 passed, 0 failed

sh tests/run-tests.sh
# 期待: Results: 24 passed, 0 failed
```

## TC-5
```sh
grep -E "check-plan-exists|check-c3-approval|check-plan-hash" .claude/settings.example.json
# 期待: 3 件すべてマッチ
```

## TC-6
```sh
grep "Status.*v3" docs/ai/hook-enforcement.md
grep "5/10 hooks" docs/ai/hook-enforcement.md
```

## TC-7
```sh
# 既存 EH-2 fixture テスト
sh tests/hooks/run-tests.sh 2>&1 | grep "check-c3-approval"
# 期待: 既存 5 件 PASS
```
