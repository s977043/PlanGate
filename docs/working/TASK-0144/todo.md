---
task_id: TASK-0144
artifact_type: todo
schema_version: 1
---

# EXECUTION TODO — TASK-0144（C-2 反映版）

> C-2 指摘 R-001/R-002 反映: cmd_exec は変更しない。cmd_approve に conversation 対応を追加。

## 準備フェーズ

- [x] T-01: 既存スキーマ・bin/plangate・EH-3 コード調査（完了）
  - Owner: AI
  - rollback: 不要（読取のみ）

## 実装フェーズ

- [ ] T-02: `.plangate.yml` サンプル作成
  - Owner: AI (直接 Write)
  - rollback: `rm .plangate.yml`
  - 内容: `c3_approval: {mode: cli}` （デフォルト・コメント付き）

- [ ] T-03: `schemas/plangate-config.schema.json` 作成（apply-script に含める）
  - Owner: AI（apply-script 生成）→ Human（--apply 実行）
  - rollback: `rm schemas/plangate-config.schema.json`
  - HO パス: schemas/*.schema.json

- [ ] T-04: `schemas/c3-approval.schema.json` に source フィールド追加（apply-script）
  - Owner: AI（apply-script 生成）→ Human（--apply 実行）
  - rollback: .bak から復元
  - HO パス: schemas/*.schema.json
  - R-004 反映: additionalProperties:false のため schema 追加必須。旧 c3.json も valid を確認。

- [ ] T-05: `scripts/hooks/check-plan-hash.sh` に conversation モード経路追加（apply-script）
  - Owner: AI（apply-script 生成）→ Human（--apply 実行）
  - rollback: .bak から復元
  - HO パス: scripts/hooks/*.sh
  - R-003 反映: SKIP は「通す」だけ。中身検証は EH-2 と AI 生成コードに委ねる。
  - 🚩 チェックポイント: conversation モードで c3.json Write が SKIP (exit 0) する

- [ ] T-06: `bin/plangate` に config 読み込み + approve/doctor 分岐追加（apply-script）
  - Owner: AI（apply-script 生成）→ Human（--apply 実行）
  - rollback: bin/plangate.bak から復元
  - HO パス: bin/plangate
  - R-001/R-002 反映: cmd_exec は変更しない。cmd_approve に conversation モード対応を追加。
  - R-005 反映: .plangate.yml 存在 + 読めない/不正 mode → stderr WARN
  - 🚩 チェックポイント: `bin/plangate doctor` に承認モードが表示される

- [ ] T-07: apply-script 作成（`scripts/_apply_task_0144_patches.py` + wrapper）
  - Owner: AI (直接 Write)
  - rollback: `rm scripts/_apply_task_0144_patches.py scripts/apply-task-0144-c3-mode.sh`
  - 含む patch: T-03/T-04/T-05/T-06

- [ ] T-08: テスト作成 `tests/extras/ta-45-c3-mode-config.sh`
  - Owner: AI (直接 Write)
  - rollback: `rm tests/extras/ta-45-c3-mode-config.sh`
  - R-006 反映: TC-06 に plangate-config.schema.json の検証 TC を追加
  - R-008 反映: TC-07 から件数固定を削除（0 failed のみ確認）

- [ ] T-09: docs 更新（`docs/ai/settings-wiring-contract.md` EH-3 conversation 経路明記）
  - Owner: AI（doc-light SKIP、HO なし）
  - rollback: git restore

## 検証フェーズ

- [ ] T-10: dry-run 確認 `sh scripts/apply-task-0144-c3-mode.sh --dry-run`
  - Owner: AI + Human 目視確認

- [ ] T-11: `sh tests/run-tests.sh` → apply 前は ta-45 TC-01 が SKIP
  - Owner: AI

## 完了フェーズ

- [ ] T-12: working context 更新（status.md / current-state.md）
  - Owner: AI

## 👤 Human Gate

- [ ] H-01: C-3 レビュー・承認（`bin/plangate approve TASK-0144` または会話内 APPROVE）
- [ ] H-02: `sh scripts/apply-task-0144-c3-mode.sh --apply` 実行
- [ ] H-03: apply 後 `sh tests/run-tests.sh` で ta-45 全 TC PASS 確認
- [ ] H-04: C-4 PR レビュー

## ⚠️ 依存関係

- T-07 が完了するまで H-02 は実行不可
- H-02 が完了するまで apply 後テストは実行不可（ta-45 TC-02〜06 は apply 後のみ PASS）
- H-01 (C-3) は T-08/T-09 完了後に実施
