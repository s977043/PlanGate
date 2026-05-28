# TASK-0120 TEST CASES

| AC | TC |
|----|-----|
| AC-1 switch 後 gh 実行 | TC-01 |
| AC-2 冪等 (既に s977043 なら skip) | TC-02 |
| AC-3 doc | TC-03 |
| AC-4 SessionStart hook 責務整理 | TC-04 |
| AC-5 ta-23 | TC-05 |
| AC-6 shellcheck + regression | TC-06 |

| ID | 内容 | 期待 |
|----|------|------|
| TC-01 | ラッパが gh auth switch --user s977043 を含む | grep 該当 |
| TC-02 | 既に s977043 active なら switch skip (冪等ロジック) | grep 該当 |
| TC-03 | doc 主要 section (運用 / 責務整理) | grep 該当 |
| TC-04 | doc に SessionStart gh-pin-account との責務整理 | grep 該当 |
| TC-05 | ta-23 dispatcher 認識 | PASS |
| TC-06 | shellcheck scripts/gh-s977043.sh + regression | exit 0 |
