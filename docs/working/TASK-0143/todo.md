---
task_id: TASK-0143
artifact_type: todo
schema_version: 1
status: draft
---

# EXECUTION TODO — TASK-0143

## 🤖 Agent タスク

### 準備フェーズ
- [x] T-01: pbi-input.md 作成（本 PBI の目的・スコープ・AC 定義）
- [x] T-02: EH-4/5/7 スクリプト仕様調査（スクリプト内容・テスト構造の把握）
- [x] T-03: bin/plangate の cmd_verify / cmd_doctor 現状把握
- [x] T-04: plan.md / todo.md / test-cases.md 生成

### 実装フェーズ
- [ ] T-05: `scripts/apply-task-0143-eh457-wiring.sh` 作成
  - cmd_verify に EH-4（strict）呼び出し追加
  - cmd_verify に EH-5（warn）呼び出し追加
  - cmd_doctor に CLI Hook Wiring セクション追加
  - depends_on: T-04
  - rollback: apply 前は不要、apply 後は `git checkout bin/plangate`
  - 🚩 作成後 dry-run 出力を確認してから次へ

- [ ] T-06: `docs/ai/settings-wiring-contract.md` に CLI 配線セクション追記
  - 「EH-4 / EH-5: bin/plangate verify に配線」
  - 「EH-7: doctor 可視化（merge 前手動実行推奨）」
  - depends_on: T-04
  - rollback: `git checkout docs/ai/settings-wiring-contract.md`

- [ ] T-07: `docs/ai/hook-enforcement.md` 更新
  - 配線状態表: EH-4/5 → ✅ CLI 配線（apply 後）、EH-7 → ⏳ doctor のみ
  - EHS-1〜3 設計セクション追加（発火条件・連携仕様）
  - depends_on: T-04
  - rollback: `git checkout docs/ai/hook-enforcement.md`

- [ ] T-08: `tests/extras/ta-44-eh457-cli-wiring.sh` 新規作成
  - TC-01: apply-script 未適用 → SKIP
  - TC-02: EH-4 strict ブロック確認（test-cases.md なし → exit 1）
  - TC-03: doctor に CLI Hook Wiring セクション出力確認
  - TC-04: EH-4/5/7 スクリプト存在確認
  - depends_on: T-05
  - rollback: `git checkout tests/extras/ta-44-eh457-cli-wiring.sh`

- [ ] T-09: `tests/run-tests.sh` に ta-44 source 追加
  - depends_on: T-08
  - rollback: `git checkout tests/run-tests.sh`

### 検証フェーズ
- [ ] T-10: `sh tests/run-tests.sh` 実行（ta-44 SKIP 確認、他テスト 0 FAIL）
  - depends_on: T-05, T-08, T-09
  - 🚩 既存 332 tests PASS + ta-44 SKIP が確認できたら次へ

- [ ] T-11: C-1 セルフレビュー実施（review-self.md 生成）
  - depends_on: T-05〜T-10 完了後
  - rollback: 不要

- [ ] T-12: current-state.md 更新
  - depends_on: T-11

## 👤 Human タスク

- [ ] H-01: C-3 レビュー（plan / todo / test-cases 確認・三値判断）
  - depends_on: T-11（C-1 完了後）
  - 🚩 APPROVE: exec フェーズへ / CONDITIONAL: 反映後 exec / REJECT: plan 再生成

- [ ] H-02: apply-script 適用（HO パス Human Gate）
  - `sh scripts/apply-task-0143-eh457-wiring.sh --dry-run` で差分確認
  - `sh scripts/apply-task-0143-eh457-wiring.sh --apply` で適用
  - depends_on: H-01 APPROVE 後、T-05 完了後

- [ ] H-03: C-4 PR レビュー（GitHub 上）
  - depends_on: PR 作成後

## ⚠️ 依存関係

```
T-01 → T-02 → T-03 → T-04
T-04 → T-05 → T-08 → T-09 → T-10 → T-11
T-04 → T-06
T-04 → T-07
T-11 → H-01 → H-02 → T-10（apply 後検証）→ PR → H-03
```

## 完了条件

- `sh tests/run-tests.sh` で 0 FAIL（ta-44 は apply 前 SKIP、apply 後 PASS）
- `docs/ai/settings-wiring-contract.md` に CLI 配線セクション存在
- `docs/ai/hook-enforcement.md` 配線表 + EHS-1〜3 設計追加
- apply 後: `bin/plangate verify TASK-0143` が EH-4 を呼び audit log に記録される
- `docs/working/improvement-seeds.md` に本 PBI の retro エントリ追記
