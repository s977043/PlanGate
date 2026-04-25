# EXECUTION PLAN: TASK-0030

## Goal

Evidence Ledger v1 を Markdown/Skill ベースで実装し、完了宣言に証拠を必須にする基盤を作る。

## Constraints / Non-goals

- TypeScript コード不要（リポジトリに TS 基盤なし）
- GitHub Checks 連携は対象外
- TASK 番号をスキルファイルに含めない（Rule 2）

## Approach Overview

1. SKILL.md でスキーマ定義と手順を定義
2. rules/evidence-ledger.md で Completion Gate ブロック条件を正本化
3. working context で受入基準とテストケースを記録

## Work Breakdown

| Step | 出力 | Owner |
|------|------|-------|
| 1. working context 作成 | pbi-input/plan/todo/test-cases/INDEX/current-state | agent |
| 2. SKILL.md 実装 | plugin/plangate/skills/evidence-ledger/SKILL.md | agent |
| 3. Rule 実装 | plugin/plangate/rules/evidence-ledger.md | agent |
| 4. 受入検査 | test-cases.md 突合 | agent |
| 5. handoff 作成 | handoff.md | agent |

## Testing Strategy

test-cases.md の5件を acceptance-tester で突合。Markdownlint で lint 確認。

## Mode 判定

**モード**: standard

**判定根拠**:
- 変更ファイル数: 9 → standard
- 受入基準数: 5 → standard
- 変更種別: 新機能追加 → standard
- **最終判定**: standard
