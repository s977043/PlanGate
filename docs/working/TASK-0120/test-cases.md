# TASK-0120 TEST CASES

## マッピング

| AC | TC |
|----|-----|
| AC-1 switch 後 gh 実行 | TC-01 |
| AC-2 冪等 (既に s977043 なら skip) | TC-02 |
| AC-3 doc | TC-03 |
| AC-4 SessionStart hook 責務整理 | TC-04 |
| AC-5 ta-23 | TC-05 |
| AC-6 shellcheck + regression | TC-06 |

## テストケース一覧

| ID | 前提条件 | 入力 | 期待出力 | 種別 |
|----|----------|------|----------|------|
| TC-01 | gh CLI install 済 | `grep 'gh auth switch --user s977043' scripts/gh-s977043.sh` | 該当 1 件以上 | 構造 |
| TC-02 | active account 取得可能 | ラッパ内に「既に s977043 なら switch skip」の冪等ロジック | grep 該当 | 構造 |
| TC-03 | doc 存在 | `grep -E '## 運用\|## 責務整理' docs/ai/github-account-pinning.md` | 該当 | 構造 |
| TC-04 | SessionStart hook 把握 | doc に gh-pin-account hook との責務整理記述 | grep 該当 | 構造 |
| TC-05 | tests/run-tests.sh 実行 | `sh tests/run-tests.sh` | TA-23 全 case PASS | 統合 |
| TC-06 | shellcheck install 済 | `shellcheck scripts/gh-s977043.sh && sh tests/run-tests.sh` | exit 0 | 統合 |

## エッジケース

- s977043 が gh auth に未登録: switch 失敗 → warning + 続行 (権限不足環境)
- 既に s977043 active: switch skip (冪等)
- gh CLI 未 install: ラッパ冒頭で error + exit
