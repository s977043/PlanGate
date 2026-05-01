# TEST CASES: TASK-0048 / Issue #157

## 受入基準 → テストケースマッピング

| AC | TC | 種別 |
|----|----|----|
| AC-1 | TC-1 | hook unit (c3-approval strict) |
| AC-2 | TC-2 | hook unit (handoff strict) |
| AC-3 | TC-3 | hook unit (fix-loop strict) |
| AC-4 | TC-4 | tests/hooks/run-tests.sh 全 PASS |
| AC-5 | TC-5 | bypass 動作 + 監査 log |
| AC-6 | TC-6 | grep "Implementation: Done" |
| AC-7 | TC-7 | default mode 作業妨害なし |

## テストケース

### TC-1〜TC-3: 各 hook の strict mode block 挙動

`tests/hooks/run-tests.sh` 内に統合済。具体:
- TC-1: `PLANGATE_HOOK_STRICT=1 PLANGATE_HOOK_TASK=TASK-HOOKTEST02 sh check-c3-approval.sh` → `"continue":false` を含む
- TC-2: `PLANGATE_HOOK_STRICT=1 sh check-handoff-elements.sh <incomplete>` → exit 1
- TC-3: `PLANGATE_HOOK_STRICT=1 sh check-fix-loop.sh <task with count=6>` → exit 1

### TC-4: 全 hook テスト統合

```sh
sh tests/hooks/run-tests.sh
# 期待: Results: 12 passed, 0 failed

sh tests/run-tests.sh
# 期待: Results: 11 passed, 0 failed（TA-06 で hook 子テストを呼ぶ）
```

### TC-5: bypass + 監査ログ

```sh
PLANGATE_BYPASS_HOOK=1 sh scripts/hooks/check-c3-approval.sh TASK-NONEXISTENT
# 期待: continue:true, 監査 log に "BYPASS" レベル追記

cat docs/working/_audit/hook-events.log | grep BYPASS  # 期待: 1 件以上
```

### TC-6: hook-enforcement.md status

```sh
grep -E "Status: v2|Implementation: Done" docs/ai/hook-enforcement.md
# 期待: 一致
```

### TC-7: default mode 作業妨害なし

`.claude/settings.example.json` は example のみで実 `.claude/settings.json` には登録されないため、本 PR マージ時点で AI 作業に影響なし。手動で実 settings.json に登録した場合も default mode（環境変数未設定）では continue:true で作業継続。
