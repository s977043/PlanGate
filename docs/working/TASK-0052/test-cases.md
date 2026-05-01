# TEST CASES: TASK-0052 / Issue #171

| AC | TC | 検証 |
|----|----|------|
| AC-1〜AC-3 | TC-1 | 連続実行で idempotent |
| AC-4 | TC-2 | 不在 user で exit 1 |
| AC-5 | TC-3 | gh 不在シミュレーション（PATH 制限） |
| AC-6 | TC-4 | settings.example に SessionStart 登録 |

## TC-1
```sh
sh scripts/gh-pin-account.sh; echo "exit=$?"
sh scripts/gh-pin-account.sh; echo "exit=$?"
# 期待: 両方 exit=0、2 回目は "already pinned"
```

## TC-2
```sh
PLANGATE_GH_USER=non-existent-user sh scripts/gh-pin-account.sh; echo "exit=$?"
# 期待: exit=1、stderr に "not in gh auth status"
```

## TC-4
```sh
grep -E '"SessionStart"' .claude/settings.example.json
grep -E "gh-pin-account.sh" .claude/settings.example.json
```
