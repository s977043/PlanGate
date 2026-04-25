# EXECUTION PLAN: TASK-0029 Intent / Mode Classifier と Skill Policy Router

> 生成日: 2026-04-26

## Goal

Intent Classifier と Skill Policy Router を Markdown/Skill ベースで実装し、
PlanGate v7 ハイブリッドアーキテクチャのゲート制御を自動化する基盤を整備する。

## Constraints

- TypeScript 基盤なし → SKILL.md（Markdown）で実装
- Rule 2: SKILL.md にプロジェクト固有情報を入れない
- Rule 5: handoff.md を必須出力とする
- Markdownlint に通る Markdown を書く

## Non-goals

- TypeScript / JSON Schema 実装
- CI への自動フック統合
- GUI / CLI ツール化

## Approach Overview

1. `intent-classifier` SKILL.md: 依頼文 → Intent（7 分類）+ confidence + reasoning を構造化 JSON で返す
2. `skill-policy-router` SKILL.md: Intent + Mode → GatePolicy を返す Mode 別ポリシー表を持つ
3. `mode-classification.md`: `full` → `high-risk` リネーム + GatePolicy 定義セクション追加

## Work Breakdown

### Step 1: ワーキングコンテキスト作成

- Output: pbi-input.md / plan.md / todo.md / test-cases.md / INDEX.md / current-state.md
- Owner: implementation-agent
- Risk: なし

### Step 2: intent-classifier/SKILL.md 実装

- Output: plugin/plangate/skills/intent-classifier/SKILL.md
- Owner: implementation-agent
- Risk: 分類ロジックの曖昧さ → reasoning フィールドで補完
- チェックポイント: 7 分類の網羅性確認

### Step 3: skill-policy-router/SKILL.md 実装

- Output: plugin/plangate/skills/skill-policy-router/SKILL.md
- Owner: implementation-agent
- Risk: GatePolicy フィールドの解釈ずれ → Issue #54 仕様を正本とする
- チェックポイント: Mode 別ポリシー表の正確性

### Step 4: mode-classification.md 更新

- Output: plugin/plangate/rules/mode-classification.md（`full` → `high-risk` リネーム + GatePolicy セクション追加）
- Owner: implementation-agent
- Risk: 参照元への影響 → grep で確認

### Step 5: test-cases.md 突合 + handoff.md 作成

- Output: handoff.md（受入基準 PASS/FAIL 判定）
- Owner: implementation-agent
- Risk: なし

## Files / Components to Touch

| ファイル | 変更種別 |
|---------|---------|
| `plugin/plangate/skills/intent-classifier/SKILL.md` | 新規 |
| `plugin/plangate/skills/skill-policy-router/SKILL.md` | 新規 |
| `plugin/plangate/rules/mode-classification.md` | 更新 |
| `docs/working/TASK-0029/` 配下一式 | 新規 |

## Testing Strategy

- Unit: test-cases.md の 7 受入基準を acceptance-tester エージェントが突合
- Integration: なし（Markdown ベースのため）
- E2E: なし
- Verification: SKILL.md の出力フォーマット仕様との目視突合

## Risks & Mitigations

| リスク | 対策 |
|-------|------|
| `full` 参照箇所の残存 | grep で確認後リネーム |
| Rule 2 違反（プロジェクト固有情報の混入） | レビュー時に grep でチェック |

## Questions / Unknowns

- `plan` スキルの扱い: skill-policy-router の optional に含める（明示なし → 保守的に optional）

## Mode 判定

**モード**: standard

**判定根拠**:

- 変更ファイル数: 3（新規 2 + 更新 1）→ standard
- 受入基準数: 7 → standard
- 変更種別: 小規模機能追加（Skill 新規 + ルール更新）→ standard
- リスク: 中（既存ルールのリネームあり）→ standard
- **最終判定**: standard
