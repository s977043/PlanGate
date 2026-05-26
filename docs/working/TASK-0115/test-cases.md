# TASK-0115 TEST CASES

## マッピング

| AC | TC |
|----|-----|
| AC-1 rule 追加 | TC-01 |
| AC-2 4 項目含む | TC-02, TC-03, TC-04, TC-05 |
| AC-3 AI 運用 4 原則 階層 | TC-06 |
| AC-4 TASK-0112 重複なし | TC-07 |
| AC-5 markdownlint | TC-08 |

## ケース

| ID | 内容 | コマンド | 期待 |
|----|------|---------|------|
| TC-01 | Bash 連結コマンド error guard セクション存在 | `grep -nE 'Bash 連結.*error guard\|連結コマンド.*guard' .claude/rules/responsibility-classes.md` | 該当 |
| TC-02 | `&&` 連結 or `set -e` 明示 | `grep -nE '&&|set -e' .claude/rules/responsibility-classes.md` 直近セクション内 | 該当 |
| TC-03 | git push 前 branch verify 明示 | `grep -nE 'rev-parse.*HEAD\|branch verify' .claude/rules/responsibility-classes.md` | 該当 |
| TC-04 | protected branch 事前確認 明示 | `grep -nE 'protected branch\|main.*事前確認' .claude/rules/responsibility-classes.md` | 該当 |
| TC-05 | INC-2026-05-26-001 参照 | `grep -nE 'INC-2026-05-26-001\|incidents/2026-05-26' .claude/rules/responsibility-classes.md` | 該当 |
| TC-06 | AI 運用 4 原則 階層明示 (第 1 原則の運用解釈) | `grep -nE 'AI 運用 4 原則\|第 1 原則' .claude/rules/responsibility-classes.md` 該当セクション | 該当 |
| TC-07 | TASK-0112 (mode-classification) 重複定義なし | mode 分類規則を再定義していない (相互参照のみ) | grep で mode-classification 言及あり、定義重複なし |
| TC-08 | markdownlint pass | `npx markdownlint-cli '.claude/rules/responsibility-classes.md'` | exit 0 |

## エッジケース

- 既存セクション順序を壊さない (新セクションは末尾追加 or 文脈的に最適位置)
