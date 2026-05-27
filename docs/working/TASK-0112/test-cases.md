# TASK-0112 TEST CASES

## マッピング

| AC | TC |
|----|-----|
| AC-1: 例外ルール追記 | TC-01 |
| AC-2: 対象パス一覧 = Hardening Override | TC-02 |
| AC-3: working-context.md AC-10/AC-8 相互参照 | TC-03 |
| AC-4: 監査ログ CLI 例外 | TC-04 |
| AC-5: 自動推定安全側 | TC-05 |
| AC-6: markdownlint + リンク健全性 | TC-06 |

## ケース

| ID | 内容 | コマンド | 期待 |
|----|------|---------|------|
| TC-01 | 「承認境界周辺の変更 → 最低でも『高』」追加 | `grep -n '承認境界周辺の変更.*最低でも.*高' .claude/rules/mode-classification.md` | 該当 1 件 |
| TC-02 (R-003/R-005) | 対象パス一覧が check-plan-hash.sh L124-134 case 文と **9 カテゴリで完全一致** | `awk '/承認境界周辺の変更/,/^## /' .claude/rules/mode-classification.md | grep -cE '\.claude/rules|\.claude/settings|\.claude/commands|\.claude/agents|scripts/hooks|bin/plangate|schemas/|workflows|AGENTS|CLAUDE'` | カテゴリ count >= 9 |
| TC-03 | working-context.md AC-10/AC-8 への相互参照 | `grep -nE 'AC-10\|AC-8\|working-context' .claude/rules/mode-classification.md` | 該当 |
| TC-04 | 監査ログ一括変更 CLI 例外 (TASK-0110 を例示) | `grep -nE '監査ログ.*一括\|TASK-0110' .claude/rules/mode-classification.md` | 該当 |
| TC-05 | 自動推定安全側 (不確実→該当扱い) | `grep -nE '安全側\|不確実.*該当' .claude/rules/mode-classification.md` | 該当 |
| TC-06 | markdownlint pass | `npx markdownlint-cli '.claude/rules/mode-classification.md'` | exit 0 |

## エッジケース

- 既存 3 例外ルール (セキュリティ/DB/公開 API) は不変 (`grep -A3 '例外ルール' .claude/rules/mode-classification.md` で 3 項目残存)
