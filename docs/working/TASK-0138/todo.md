# EXECUTION TODO — TASK-0138 (#528)

## 🤖 Agent タスク

### 準備フェーズ

- [x] T0: pbi-input.md 作成完了
- [x] T1: plan.md / todo.md / test-cases.md 生成（本ファイル）
- [x] T2: C-1 セルフレビュー（review-self.md）

### 実装フェーズ（C-3 APPROVED 後）

- [ ] T3: `check-plan-hash.sh` 差分パッチ（doc-light ブロック挿入）を `scripts/apply-eh3-doc-light.sh` に記述
  - Owner: agent
  - rollback: apply 未実行のため不要
  - depends_on: C-3 APPROVED
  - 🚩 ta-14 全 TC PASS（hook 自体は人間適用前なので simulate でテスト）

- [ ] T4: `tests/extras/ta-39-eh3-doc-light.sh` 作成
  - Owner: agent
  - rollback: ファイル削除
  - depends_on: T3（apply 内容に合わせた TC）

- [ ] T5: `tests/run-tests.sh` に ta-39 を登録（1行追加）
  - Owner: agent
  - rollback: 1行削除

### 検証フェーズ（Human が apply-script 実行後）

- [ ] T6: apply-script 実行後、`sh tests/extras/ta-14-hook-eh3.sh` PASS 確認
  - Owner: agent（実行確認）
- [ ] T7: `sh tests/extras/ta-39-eh3-doc-light.sh` 全 TC PASS 確認
  - Owner: agent
- [ ] T8: `sh tests/run-tests.sh` PASS 確認
  - Owner: agent

### 完了フェーズ

- [ ] T9: handoff.md 生成
  - Owner: agent
- [ ] T10: PR 作成
  - Owner: agent

## 👤 Human タスク

- [ ] H1: C-3 ゲート（plan レビュー + `bin/plangate approve TASK-0138`）
  - 🚩 H1 前に: review-self.md + C-3 HTML を確認
- [ ] H2: apply-script 実行（`sh scripts/apply-eh3-doc-light.sh`）
  - 🚩 H2 前に: dry-run で差分確認
- [ ] H3: C-4 PR レビュー・マージ

## ⚠️ 依存関係

```
T0 → T1 → T2 → C-3 → T3 → T4 → T5 → H2(apply) → T6 → T7 → T8 → T9 → T10 → H3
```
