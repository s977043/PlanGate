# TASK-0146 EXECUTION TODO — EHS-2/3 bin/plangate 配線（#527 増分2/3）

## 🤖 Agent タスク

### 準備

- [ ] T-01: `scripts/_apply_task_0146_patches.py` 作成（EHS-3 P1 + EHS-2 P2）
  - Owner: agent
  - rollback: ファイル削除
- [ ] T-02: `scripts/apply-task-0146-ehs23-wiring.sh` 作成（dry-run/--apply wrapper）
  - Owner: agent
  - rollback: ファイル削除
- [ ] T-03: `tests/extras/ta-47-ehs23-wiring.sh` 作成（TC-01〜06）
  - Owner: agent
  - rollback: ファイル削除
- [ ] T-04: dry-run 実行 → diff が期待通りであることを確認
  - 🚩 チェックポイント: `sh scripts/apply-task-0146-ehs23-wiring.sh` で diff 確認
  - rollback: 不要（dry-run のみ）

### 検証

- [ ] T-05: `sh tests/run-tests.sh` を実行 → ta-47 SKIP・全体 0 FAIL
  - Owner: agent
  - rollback: 不要

### 完了

- [ ] T-06: `docs/ai/hook-enforcement.md` EHS-2/3 を「⏳ 設計済み・未実装」→「✅ CLI 配線（apply 後）」へ更新
  - Owner: agent
  - rollback: git revert
- [ ] T-07: `docs/working/TASK-0146/` 各ファイル整備（review-self.md、INDEX.md 等）
  - Owner: agent

## 👤 Human タスク

- [ ] H-01 [C-3ゲート]: plan/todo/test-cases をレビューして APPROVE / CONDITIONAL / REJECT を判断
  - **depends_on**: T-01〜T-07 完了、C-1 セルフレビュー通過
- [ ] H-02 [exec後]: `sh scripts/apply-task-0146-ehs23-wiring.sh --apply` を実行
  - **depends_on**: H-01 C-3 APPROVE
- [ ] H-03: `sh tests/run-tests.sh` を実行 → ta-47 全 TC PASS を確認
  - **depends_on**: H-02

## ⚠️ 依存関係

- T-04 は T-01〜03 完了後
- T-05 は T-04 完了後
- H-01 は T-07 完了後（C-1 PASS 後）
- H-02 は H-01 APPROVE 後
- H-03 は H-02 完了後
