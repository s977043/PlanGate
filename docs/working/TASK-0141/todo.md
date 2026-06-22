# EXECUTION TODO — TASK-0141

## 🤖 Agent タスク

### Phase 1: 準備

- [x] A-01 issue #500 / #527 の現状確認（check-c3-approval.sh / check-plan-exists.sh / ta-06 精読）
- [x] A-02 Codex 設計相談（python3 パターン / stdin fallback 方針）

### Phase 2: 実装

- [ ] A-03 apply-script 生成: scripts/apply-task-0141-eh2-strict.sh
  - EH-2: grep/sed → python3 strict JSON（check-c3-approval.sh）
  - EH-2: stdin fallback 追加
  - EH-1: stdin fallback 追加（check-plan-exists.sh）
  - --dry-run / --apply 両対応・冪等ガード
  - rollback: スクリプト削除で元 hooks はそのまま（適用前は変化なし）

- [ ] A-04 ta-43 新設: tests/extras/ta-43-eh2-strict-json.sh
  - TC-01〜06 実装（hooks コピーで fixture テスト、ta-39 パターン踏襲）
  - rollback: ファイル削除

- [ ] A-05 ta-06 修正: tests/extras/ta-06-hooks.sh
  - >/dev/null 2>&1 を除去、PASS/FAIL 計上形式に変更
  - rollback: git restore tests/extras/ta-06-hooks.sh

### Phase 3: 検証

- [ ] A-06 tests/run-tests.sh で全 PASS 確認（FAIL=0）
- [ ] A-07 apply-script --dry-run で期待差分確認

### Phase 4: 完了

- [ ] A-08 handoff.md 生成（V-1 PASS 後）

## 👤 Human タスク

- [ ] H-01 C-3 ゲート: plan/todo/test-cases/review-self 確認・APPROVE
  - depends_on: A-03/A-04/A-05 完了後
  - 承認: bin/plangate approve TASK-0141（別ターミナルで実行）
- [ ] H-02 HO 適用: sh scripts/apply-task-0141-eh2-strict.sh --dry-run → --apply
  - depends_on: H-01 APPROVED + PR マージ後
- [ ] H-03 C-4 ゲート: GitHub PR レビュー・マージ
