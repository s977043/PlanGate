# TASK-0114 TEST CASES

## マッピング

| AC | TC |
|----|-----|
| AC-1 protected block | TC-01, TC-02 |
| AC-2 install + .bak | TC-03 |
| AC-3 env override | TC-04 |
| AC-4 ガイド | TC-05 |
| AC-5 ta-17 fixture | TC-06 |
| AC-6 regression | TC-07 |
| AC-7 lint | TC-08 |

## ケース

| ID | 内容 | 手順 | 期待 |
|----|------|------|------|
| TC-01 | main push block | hook stdin に `refs/heads/main` push entry | exit 1 + メッセージ |
| TC-02 | feature branch push OK | stdin に `refs/heads/feature/x` | exit 0 |
| TC-03 | install + .bak 保持 | 既存 `.git/hooks/pre-push` 存在下で install | 既存→.bak + 新規配置 |
| TC-04 (R-001/R-007 glob): env override で glob 評価 | env `PLANGATE_PROTECTED_BRANCHES="release/*"` 設定後 (a) `release/v1` push → exit 1、(b) `main` push → exit 0 (override で main は protected list 外、release/* glob は機能) | (a) exit 1、(b) exit 0 |
| TC-05 | ガイド 主要セクション存在 | `grep -E '## install\|## bypass\|## emergency' docs/ai/direct-push-prevention.md` | 該当 |
| TC-06 | ta-17 dispatcher 認識 | `sh tests/run-tests.sh` | TA-17 全 case PASS |
| TC-07 | 既存テスト regression なし | `sh tests/run-tests.sh && sh tests/hooks/run-tests.sh` | 全 PASS |
| TC-08 | shellcheck + markdownlint | `shellcheck scripts/templates/pre-push.sample scripts/install-pre-push.sh && npx markdownlint-cli docs/ai/direct-push-prevention.md` | exit 0 |
| TC-09 (R-004): integration | `--no-verify` bypass (emergency) | **fixture では検証不可**、integration test (一時 repo で `git push --no-verify`) または doc 確認に分離 | exit 0 (git client が hook skip)、doc に明記済確認 |
| TC-10 | release/* glob match | stdin に `refs/heads/release/v2.0.0` | exit 1 |

## エッジケース

- empty stdin (no push): exit 0
- delete remote branch (`local_sha = 0...`): protected でも許可 (delete は別操作)
