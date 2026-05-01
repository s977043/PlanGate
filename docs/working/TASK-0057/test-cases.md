# TEST CASES: TASK-0057

| AC | TC | 検証 |
|----|----|------|
| AC-1 | TC-1 | EH-4 3 mode |
| AC-2 | TC-2 | EH-5 3 mode |
| AC-3 | TC-3 | EH-6 3 mode + SKIP |
| AC-4 | TC-4 | hook 単体 33 PASS |
| AC-5 | TC-5 | run-tests.sh 24 PASS |
| AC-6 | TC-6 | settings.example に EH-6 |
| AC-7 | TC-7 | hook-enforcement v4 / 8/10 |
| AC-8 | TC-8 | 既存 hook 無変更 |

## TC-3（EH-6 主要ケース）

```sh
# fixture: PBI-9999/children/PBI-9999-01.yaml に
#   forbidden_files: [src/auth/**, prisma/schema.prisma, .github/workflows/**]
#   allowed_files:   [src/foo/**, tests/foo/**, ...]

# 1. allowed file → continue:true
PLANGATE_HOOK_TASK=TASK-HOOKTEST-FF PLANGATE_HOOK_FILE=src/foo/bar.ts \
  sh scripts/hooks/check-forbidden-files.sh
# 期待: {"continue":true}

# 2. forbidden file default → continue:true + WARNING
PLANGATE_HOOK_TASK=TASK-HOOKTEST-FF PLANGATE_HOOK_FILE=src/auth/login.ts \
  sh scripts/hooks/check-forbidden-files.sh 2>&1
# 期待: WARNING + {"continue":true}

# 3. forbidden file strict → continue:false
PLANGATE_HOOK_STRICT=1 PLANGATE_HOOK_TASK=TASK-HOOKTEST-FF PLANGATE_HOOK_FILE=src/auth/login.ts \
  sh scripts/hooks/check-forbidden-files.sh
# 期待: {"continue":false,"stopReason":"..."}

# 4. bypass overrides strict
PLANGATE_BYPASS_HOOK=1 PLANGATE_HOOK_STRICT=1 PLANGATE_HOOK_TASK=TASK-HOOKTEST-FF \
  PLANGATE_HOOK_FILE=src/auth/login.ts \
  sh scripts/hooks/check-forbidden-files.sh
# 期待: {"continue":true}

# 5. PLANGATE_HOOK_TASK 未指定 → SKIP
PLANGATE_HOOK_FILE=src/auth/login.ts sh scripts/hooks/check-forbidden-files.sh
# 期待: {"continue":true}（false-positive guard）
```

## TC-4 / TC-5

```sh
sh tests/hooks/run-tests.sh    # 33 PASS
sh tests/run-tests.sh          # 24 PASS
```

## TC-7

```sh
grep "Status.*v4" docs/ai/hook-enforcement.md
grep "8/10 hooks" docs/ai/hook-enforcement.md
```
