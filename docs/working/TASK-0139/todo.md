# EXECUTION TODO — TASK-0139 (#550)

## 🤖 Agent タスク

### 準備
- [x] T0: pbi-input.md / plan.md / todo.md / test-cases.md 生成
- [x] T1: C-1 セルフレビュー

### 実装（C-3 APPROVED 後）
- [ ] T2: 既存テストで FAKE_PPID_COMM 使用箇所を grep して PLANGATE_TEST_MODE=1 追記
  - depends_on: C-3 APPROVED
  - rollback: git revert
- [ ] T3: `scripts/apply-approve-hardening.sh` 生成（bin/plangate パッチ）
  - rollback: 不要（apply 前）
- [ ] T4: `docs/decisions/adr-001-approve-out-of-band.md` 作成（HO 対象外）
  - rollback: ファイル削除
- [ ] T5: `tests/extras/ta-40-approve-hardening.sh` 作成（TC-01〜04）
  - rollback: ファイル削除
- [ ] T6: `tests/run-tests.sh` に ta-40 登録（1行追加）

### Human Apply 後の検証
- [ ] T7: `sh scripts/apply-approve-hardening.sh` 適用後に ta-40 全 TC PASS 確認
- [ ] T8: `sh tests/run-tests.sh` PASS 確認

### 完了
- [ ] T9: handoff.md 生成
- [ ] T10: PR 作成

## 👤 Human タスク
- [ ] H1: C-3 承認（`bin/plangate approve TASK-0139`）
- [ ] H2: `sh scripts/apply-approve-hardening.sh`（bin/plangate HO 適用）
- [ ] H3: C-4 PR レビュー・マージ

## 依存関係
```
T0→T1→C-3→T2→T3→T4→T5→T6→H2(apply)→T7→T8→T9→T10→H3
```
