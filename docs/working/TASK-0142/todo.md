# EXECUTION TODO — TASK-0142

## 🤖 Agent タスク

### 準備フェーズ

- [x] A-01: pbi-input.md 作成
- [x] A-02: plan.md 生成
- [x] A-03: todo.md 生成（本ファイル）
- [x] A-04: test-cases.md 生成
- [ ] A-05: C-1 セルフレビュー
  - rollback: 不要（plan 再生成のみ）

### 実装フェーズ

- [ ] A-06: `docs/workflows/07_exploratory_debug.md` 作成（AC-1）
  - rollback: ファイル削除
- [ ] A-07: `docs/workflows/README.md` 更新（AC-2）
  - rollback: git restore
- [ ] A-08: `docs/workflows/execution-sequence.md` 更新（AC-3）
  - rollback: git restore
- [ ] A-09: L-0 markdownlint（AC-4）
  - rollback: 不要

### 検証フェーズ

- [ ] A-10: V-1 受け入れ検査（ファイル存在 + 内容確認）

### 完了フェーズ

- [ ] A-11: PR 作成

## 👤 Human タスク

- [ ] H-01: C-3 承認（diff 確認・APPROVE）
- [ ] H-02: C-4 PR レビュー

## ⚠️ 依存関係

- A-06〜08 は H-01（C-3）後に開始（doc-light autonomous APPROVE 可）
- A-10 は A-06〜09 完了後

## 🚩 チェックポイント

- **CP1**: plan.md 確認後 → H-01 C-3 gate
- **CP2**: 3ファイル実装完了後 → A-09 L-0
- **CP3**: L-0 PASS 後 → A-10 V-1
