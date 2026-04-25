# EXECUTION TODO: TASK-0029

> 生成日: 2026-04-26

## Agent タスク

### 準備フェーズ

- [x] A-1: 既存 SKILL.md フォーマット確認（brainstorming / self-review を参照）
- [x] A-2: mode-classification.md 現状確認
- [x] A-3: handoff テンプレート確認
- [x] A-4: docs/working/TASK-0029/ ディレクトリ作成
- [x] A-5: pbi-input.md 作成
- [x] A-6: plan.md 作成
- [x] A-7: todo.md 作成（このファイル）
- [x] A-8: test-cases.md 作成

### 実装フェーズ

- [x] A-9: intent-classifier/SKILL.md 実装
  - 🚩 チェックポイント: 7 分類の網羅性、structured output フォーマット確認
- [x] A-10: skill-policy-router/SKILL.md 実装
  - 🚩 チェックポイント: Mode 別ポリシー表の正確性、GatePolicy フィールド網羅
- [x] A-11: mode-classification.md 更新（`full` → `high-risk` リネーム + GatePolicy セクション追加）
  - 🚩 チェックポイント: `full` の残存がないことを grep で確認

### 検証フェーズ

- [x] A-12: test-cases.md 受入基準 7 件を自己突合
- [x] A-13: Markdownlint 確認（主要ファイルの構文チェック）
- [x] A-14: handoff.md 作成

### 完了フェーズ

- [x] A-15: git commit (feature/task-0029-intent-classifier)

## Human タスク

- [ ] H-1: C-3 ゲート（plan / test-cases の承認）
- [ ] H-2: C-4 ゲート（PR レビュー / GitHub）

## 依存関係

- A-9, A-10, A-11 は A-1〜A-8 完了後に実行
- A-12〜A-14 は A-9〜A-11 完了後に実行
- H-1 は A-8 完了後（plan/test-cases 確認のため）
- H-2 は A-15 完了後

## 完了条件

- 全受入基準（AC-1〜AC-7）が PASS
- Markdownlint エラーなし
- handoff.md が発行されている
- feature ブランチへのコミット完了
