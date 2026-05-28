# TASK-0118 TEST CASES

## マッピング

| AC | TC |
|----|-----|
| AC-1 slash command 新規 | TC-01 |
| AC-2 skill 新規 | TC-02 |
| AC-3 質問テンプレ 4 選択肢 + 工数 + 3 軸 | TC-03 |
| AC-4 Phase 分割表 template | TC-04 |
| AC-5 TASK-0117 連携明記 | TC-05 |
| AC-6 PocketEitan 実例 ≥ 2 件 | TC-06 |
| AC-7 ta-21 機械検証 | TC-07 |
| AC-8 markdownlint + regression | TC-08 |

## ケース

| ID | 内容 | コマンド | 期待 |
|----|------|---------|------|
| TC-01 | slash command 存在 | `test -f .claude/commands/codex-mvp-split.md` | exit 0 |
| TC-02 | skill 存在 + frontmatter | `grep -E '^name:|^description:' .agents/skills/codex-mvp-split/SKILL.md` | 両 field 該当 |
| TC-03 | 質問テンプレに 4 選択肢 (A/B/C/D) + 工数 (S/M/L) + 判断 3 軸 | `grep -cE '\(A\).*独立\|\(B\).*拡張\|\(C\).*導線\|\(D\).*独自' .claude/commands/codex-mvp-split.md docs/ai/codex-mvp-split.md` | ≥ 4 |
| TC-04 | Phase 分割表 template が PBI INPUT PACKAGE template に追加 | `grep -nE 'Phase 分割表\|Phase.*工数\|Phase.*状態' docs/working/templates/pbi-input.md` | 該当 |
| TC-05 | TASK-0117 (#351) 連携明記 | `grep -nE 'TASK-0117\|事前メトリクス検証' docs/ai/codex-mvp-split.md` | 該当 |
| TC-06 | PocketEitan 実例 2 件 | `grep -cE 'PocketEitan\|例文音読カード\|TASK-srs-unification' docs/ai/codex-mvp-split.md` | ≥ 2 |
| TC-07 | ta-21 dispatcher 認識 + PASS | `sh tests/run-tests.sh` | TA-21 全 case PASS |
| TC-08 | markdownlint + regression | `npx markdownlint-cli docs/ai/codex-mvp-split.md && sh tests/run-tests.sh` | exit 0 |

## エッジケース

- skill / command が `.claude/commands/` か `.claude/skills/` か不確実 (TASK-0117 と同様の R-001 リスク) → T-01 で実体確認、本 PBI plan は `.claude/commands/` 優先 (slash command 用途)
