# PBI INPUT PACKAGE: Intent / Mode Classifier と Skill Policy Router の実装

> 生成日: 2026-04-26
> 関連 Issue: #54

## Context / Why

PlanGate v7.1.0 完了後の次フェーズ（Epic #53「PlanGateをAIコーディングの開発統制OSへ拡張する」Phase 1）。

AIエージェントがユーザーの依頼を受け取ったとき、「どの Intent か」「どの Mode か」を自動判定し、それに応じた Skill・Gate 要件（GatePolicy）を導出できるようにする。これにより、エージェントが適切なワークフロー制御を自律的に実行できる基盤を整備する。

## What（Scope）

### In scope

- Intent Classifier Skill（7 分類: feature / bug / refactor / research / review / docs / ops）
- Skill Policy Router Skill（Intent + Mode → GatePolicy の変換）
- mode-classification.md の `full` → `high-risk` リネームと GatePolicy 定義セクション追加
- docs/working/TASK-0029/ 配下のワーキングコンテキスト一式

### Out of scope

- TypeScript / JSON Schema での型定義
- CI での自動 lint/validation
- 既存ワークフローへの自動フック統合
- GUI / CLI ツール化

## 受入基準

- [ ] AC-1: Intent を 7 分類できる（structured output）
- [ ] AC-2: Mode を判定できる（定量・定性基準）
- [ ] AC-3: Intent + Mode から GatePolicy を返せる
- [ ] AC-4: high-risk 以上で approval/worktree/TDD/review/verify が必須になる
- [ ] AC-5: ultra-light/light では重いゲートを要求しない
- [ ] AC-6: docs/working/TASK-0029/test-cases.md にテストケースが記述されている
- [ ] AC-7: README または docs に mode 分類基準が記載されている

## Notes from Refinement

- `full` → `high-risk` リネームは plugin/plangate/rules/mode-classification.md のみ変更。
  CLAUDE.md の参照コメント（system-reminder）はプロジェクト外なので変更しない
- Markdown/Skill ベース実装（TypeScript 基盤なし）
- Rule 2 遵守: SKILL.md に TASK 番号・プロジェクト固有情報を入れない

## Estimation Evidence

### Risks

- mode-classification.md の `full` → `high-risk` リネームが既存参照箇所に影響する可能性

### Unknowns

- GatePolicy の "plan" スキルが skill-policy-router の `requiredSkills` に含まれるべきか（Issue #54 仕様では明示なし → optional 扱いとする）

### Assumptions

- SKILL.md はプロンプトとして AI が実行する構造化ドキュメント
- "unit test" は test-cases.md + acceptance-tester エージェントによる突合で代替する
