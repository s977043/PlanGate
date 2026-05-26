# TASK-0117 TEST CASES

## マッピング

| AC | TC |
|----|-----|
| AC-1 skill にセクション追加 | TC-01 |
| AC-2 検証コマンド例 | TC-02 |
| AC-3 判定基準数値 | TC-03 |
| AC-4 既存実例 ≥ 1 | TC-04 |
| AC-5 TASK-0112 相互参照 | TC-05 |
| AC-6 ta-19 機械検証 | TC-06 |
| AC-7 markdownlint + regression | TC-07, TC-08 |

## ケース

| ID | 内容 | コマンド | 期待 |
|----|------|---------|------|
| TC-01 | skill に「事前メトリクス検証」セクション存在 | `grep -nE '事前メトリクス検証\|事前.*メトリクス' .agents/skills/ai-dev-plan/SKILL.md` (or 該当 file) | 該当 |
| TC-02 | 検証コマンド例 (grep/wc/find) 明記 | `grep -nE 'grep -rln\|wc -l\|find .* -name' .agents/skills/ai-dev-plan/SKILL.md` | 該当 |
| TC-03 | 判定基準数値 (3 倍以上 / 1〜3 倍 / < 1 倍) 明記 | `grep -nE '3 倍\|3倍\|1〜3' .agents/skills/ai-dev-plan/SKILL.md docs/ai/plan-metrics-verification.md` | 該当 |
| TC-04 | PocketEitan 実例 (17 グループ / 1697 ファイル) 記載 | `grep -nE '1697\|17 グループ\|PocketEitan' docs/ai/plan-metrics-verification.md` | 該当 |
| TC-05 | TASK-0112 (mode 例外ルール) への相互参照 | `grep -nE 'mode-classification\|TASK-0112' docs/ai/plan-metrics-verification.md .agents/skills/ai-dev-plan/SKILL.md` | 該当 |
| TC-06 | ta-19 dispatcher 認識 + PASS | `sh tests/run-tests.sh` | TA-19 全 case PASS |
| TC-07 | 既存テスト regression なし | `sh tests/run-tests.sh && sh tests/hooks/run-tests.sh` | 全 PASS |
| TC-08 | markdownlint | `npx markdownlint-cli docs/ai/plan-metrics-verification.md` | exit 0 |

| **TC-09 (R-003 / AC-8)** | plan.md template に `## Metrics Evidence` 欄が含まれる | `grep -nE 'Metrics Evidence' docs/ai/plan-metrics-verification.md` | 該当 |

## エッジケース

- skill 実体は `.agents/skills/ai-dev-plan/SKILL.md` (`.claude/skills/` 配下ではない / R-001)
