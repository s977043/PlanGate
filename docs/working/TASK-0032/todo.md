# EXECUTION TODO — TASK-0032

## メタ情報

```yaml
task: TASK-0032
related_issue: https://github.com/s977043/plangate/issues/57
phase: B（EXECUTION TODO）
created_at: 2026-04-26
```

## 凡例

- `[x]` = 完了
- `[ ]` = 未着手 / 作業中
- `[Agent]` = AIエージェントが実行
- `[Human]` = 人間が実行

---

## Phase A: Design Gate / TDD Gate / Review Gate（完了済み）

### 準備

- [x] `[Agent]` ブランチ `feature/task-0032-gate-system-design` 作成

### 実装: Agent A（Design Gate）

- [x] `[Agent]` `plugin/plangate/rules/design-gate.md` 作成
- [x] `[Agent]` `plugin/plangate/skills/design-gate/SKILL.md` 作成
- [x] `[Agent]` コミット: `feat(gate): TASK-0032 Design Gate 実装 (#57)`

### 実装: Agent B（TDD Gate + Review Gate）

- [x] `[Agent]` `plugin/plangate/commands/pg-tdd.md` 作成
- [x] `[Agent]` `plugin/plangate/rules/review-gate.md` 作成
- [x] `[Agent]` `plugin/plangate/skills/review-gate/SKILL.md` 作成
- [x] `[Agent]` コミット: `feat(gate): TASK-0032 TDD Gate + Review Gate 実装 (#57)`

### 検証: Phase A

- [x] `[Agent]` Phase A の 5 ファイルが揃っていることを確認

---

## Phase B: Completion Gate + Mode マトリクス + Working Context（本フェーズ）

### 準備

- [x] `[Agent]` ブランチ `feature/task-0032-gate-system-completion` 作成
- [x] `[Agent]` `feature/task-0032-gate-system-design` をマージ
- [x] `[Agent]` `feature/task-0032-gate-system-tdd-review` をマージ

### 実装: Agent C（Completion Gate）

- [x] `[Agent]` `plugin/plangate/rules/completion-gate.md` 作成
  - 5 ブロック条件を記述
  - Mode 別適用マトリクスを記述
  - PASSED / BLOCKED 出力形式を JSON で記述

### 実装: Agent C（Mode マトリクス統合）

- [x] `[Agent]` `plugin/plangate/rules/mode-classification.md` に「## Gate 適用マトリクス」セクションを追加
  - 既存内容を変更・削除しないこと

### 実装: Agent C（Working Context）

- [x] `[Agent]` `docs/working/TASK-0032/pbi-input.md` 作成
- [x] `[Agent]` `docs/working/TASK-0032/plan.md` 作成
- [x] `[Agent]` `docs/working/TASK-0032/todo.md` 作成（本ファイル）
- [x] `[Agent]` `docs/working/TASK-0032/test-cases.md` 作成
- [x] `[Agent]` `docs/working/TASK-0032/INDEX.md` 作成
- [x] `[Agent]` `docs/working/TASK-0032/current-state.md` 作成
- [x] `[Agent]` `docs/working/TASK-0032/handoff.md` 作成

### 検証: Phase B 🚩チェックポイント

- [ ] `[Agent]` completion-gate.md の 5 ブロック条件が全て記述されているか確認（AC-1〜5）
- [ ] `[Agent]` mode-classification.md の Gate マトリクスで ultra-light/light が `-` になっているか確認（AC-6）
- [ ] `[Agent]` completion-gate.md に「critical で rollback plan 必須」が明記されているか確認（AC-2）
- [ ] `[Agent]` completion-gate.md に「Evidence Ledger passed が必須条件」が明記されているか確認（AC-5）

### コミット

- [ ] `[Agent]` `git add` して `git commit -m "feat(gate): TASK-0032 Completion Gate + Mode マトリクス + Working Context (#57)"`

---

## Human タスク

### C-3: exec 前ゲート（計画承認）

- [x] `[Human]` plan.md の内容確認・承認（承認済み、本実装の前提）

### C-4: PR レビュー

- [ ] `[Human]` GitHub 上でプルリクエストをレビュー
- [ ] `[Human]` APPROVE / REQUEST CHANGES / REJECT を判断

---

## 依存関係

| タスク | 依存先 |
|--------|--------|
| completion-gate.md 作成 | design-gate.md / review-gate.md / evidence-ledger.md（参照元） |
| mode-classification.md 更新 | completion-gate.md（Gate 適用マトリクスで参照） |
| handoff.md 作成 | 全実装ファイルの完成後 |
| C-4 PRレビュー | Agent C の全タスク完了後 |
