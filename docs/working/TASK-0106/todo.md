# TASK-0106 EXECUTION TODO

> Source: plan.md / Mode: high-risk / Generated: 2026-05-20

## 🤖 Agent タスク

### Phase 1: 準備
- [ ] **T-01**: 既存 `schemas/maintenance.schema.json` の depend 箇所を全 grep し改修影響範囲を確定（owner=agent / Risk=low / 🚩 影響リスト確定）
- [ ] **T-02**: 既存 EH-3 hook テスト（`tests/hooks/run-tests.sh`）を読み、回帰観点を抽出（owner=agent / Risk=low）

### Phase 2: 実装
- [ ] **T-03**: schema 拡張（allowed_paths/one_shot/consumed_at optional 追加、additionalProperties:false 維持）+ schema-validate テスト追加（owner=agent / Risk=low / depends_on=T-01 / 🚩 既存 schema test PASS）
- [ ] **T-04**: `bin/plangate maintenance start/stop` CLI 実装 — TDD（失敗テスト先 → 実装 → green）（owner=agent / Risk=medium / depends_on=T-03 / 🚩 CLI 単体 PASS）
- [ ] **T-05**: EH-3 hook 改修 — path scope check + TTL check + atomic one-shot consume（owner=agent / Risk=**high** / depends_on=T-04 / 🚩 既存 30 分窓テスト PASS + 新動作テスト PASS + 承認境界回帰なし）
- [ ] **T-06**: Hardening Override 実装（`.claude/rules/*.md` / `.claude/settings*.json` / `scripts/hooks/*.sh` を窓内でも block）（owner=agent / Risk=high / depends_on=T-05 / 🚩 Override 対象パスの block テスト PASS）
- [ ] **T-07a**: `bin/plangate doctor` テキスト出力に有効窓表示行追加（owner=agent / Risk=low / depends_on=T-04 / 🚩 doctor 出力テスト PASS）
- [ ] **T-07b**: `scripts/doctor_check.py` JSON 構造化出力に maintenance 状態追加（R-006）（owner=agent / Risk=low / depends_on=T-07a / 🚩 `doctor --json` で maintenance フィールド PASS）

### Phase 3: 検証
- [ ] **T-08**: E2E テスト（start→edit 1回通過→consume→2回目 block→stop で完全失効）（owner=agent / Risk=medium / depends_on=T-05/T-06 / 🚩 E2E PASS）
- [ ] **T-09**: 後方互換テスト — 既存 30 分窓 maintenance.json が動作（owner=agent / Risk=high / depends_on=T-05 / 🚩 既存 78 hook PASS + 68 CLI PASS 維持）
- [ ] **T-10**: 承認境界回帰テスト — env 経路では maintenance 有効化されない + `maintenance start` は非対話/CI/agent 実行で reject（R-001/R-011）（owner=agent / Risk=**critical** / depends_on=T-05 / 🚩 TC-10/TC-25/TC-26/TC-29 全 PASS）

### Phase 4: 完了
- [ ] **T-11**: `docs/ai/maintenance-cli.md` 運用 guide 作成（owner=agent / Risk=low）
- [ ] **T-12**: handoff.md 作成（必須 6 要素）+ V-1 受け入れ検査（test-cases.md 全件突合）（owner=agent / Risk=low / depends_on=全完了 / 🚩 全 AC PASS）

## 👤 Human タスク

- [ ] **H-01**: **C-3 ゲート（exec 前ゲート）** — plan/todo/test-cases/review-self.md 確認 → APPROVE/CONDITIONAL/REJECT 三値判定 → `approvals/c3.json` 発行（**必須・AI 不可**）
- [ ] **H-02**: **C-4 ゲート（PR レビュー）** — exec 完了後の PR を GitHub 上で確認 → APPROVE/REQUEST CHANGES/REJECT
- [ ] **H-03**: **merge** — C-4 APPROVE 後の squash merge（**Human-owned 固定**）

## ⚠️ 依存関係

- T-04..T-10 は H-01（C-3）通過後にのみ着手可（PlanGate ワークフロー: C-3 前は exec 不可）
- T-03 まで（schema 拡張）も承認境界 schema 変更のため C-3 前に AI が単独実装してはいけない（plan 段階のみ）
- 全 T-* 完了 → PR 作成 → H-02 → H-03

## Iron Law 遵守

- 任意の Edit/Write 前に PLANGATE_HOOK_FILE / PLANGATE_HOOK_TASK=TASK-0106 を設定するか、`bin/plangate maintenance` 経由（実装後の dogfooding）
- workflow-conductor が自動制御する V 系（L-0/V-1/V-3）は本 todo に含めない

## 完了条件

todo の全項目 ✅ + handoff.md 6 要素 + 全 AC PASS + tests/run-tests.sh 68+α PASS + tests/hooks/run-tests.sh 78+α PASS
