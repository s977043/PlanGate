# TASK-0116 TEST CASES

## マッピング

| AC | TC |
|----|-----|
| AC-1 Iron Law doc 追加 | TC-01 |
| AC-2 機械検証 script | TC-02, TC-03, TC-04 |
| AC-3 rule link | TC-05 |
| AC-4 失敗時 `-f` 手順 doc | TC-06 |
| AC-5 ta-18 fixture | TC-07 |
| AC-6 regression + lint | TC-08, TC-09 |
| ~~AC-7 doctor 統合~~ | ~~TC-10~~ (削除済) |

## ケース

| ID | 内容 | コマンド | 期待 |
|----|------|---------|------|
| TC-01 | `docs/release-process.md` に Iron Law | `grep -nE 'NO RELEASE WITHOUT TAG-MAIN PARITY' docs/release-process.md` | 該当 |
| TC-02 | script: tag = main 一致時 exit 0 | fixture repo で tag を HEAD に + script 実行 | exit 0 |
| TC-03 | script: tag != main 不一致時 exit 1 | fixture で tag を別 commit に + script | exit 1 + メッセージ |
| TC-04 | script: tag 不在時 exit 1 + 明確メッセージ | 存在しない tag を引数 | exit 1 |
| TC-05 | `.claude/rules/responsibility-classes.md` に検証 link | `grep -nE 'check-tag-main-parity\|release-process' .claude/rules/responsibility-classes.md` | 該当 |
| TC-06 | docs に `-f` 貼り替え手順 (Human オペレーション) | `grep -nE 'git push -f.*tag\|tag -fa' docs/release-process.md` | 該当 |
| TC-07 | ta-18 dispatcher 認識 + 3 case PASS | `sh tests/run-tests.sh` | TA-18 全 case PASS |
| TC-08 | 既存テスト regression なし | `sh tests/run-tests.sh && sh tests/hooks/run-tests.sh` | 全 PASS |
| TC-09 | shellcheck + markdownlint | `shellcheck scripts/check-tag-main-parity.sh && npx markdownlint-cli docs/release-process.md` | exit 0 |
| ~~TC-10 (stretch)~~ | ~~doctor 統合~~ — V2 候補に降格 (Codex 9 PBI review 反映) | — | — |

## エッジケース

- lightweight tag (annotated でない): `^{commit}` peel で吸収、TC-02/03 で確認
- detached HEAD で実行: 警告 + exit 1
- remote main fetch 失敗 (offline): 警告 + skip (exit 0 ではなく明確メッセージで abort)
