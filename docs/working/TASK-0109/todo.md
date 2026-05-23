# TASK-0109 EXECUTION TODO

> Source: plan.md / Mode: standard / Generated: 2026-05-22

## 🤖 Agent タスク

### Phase 1: 準備
- [ ] **T-01**: `.cursor/hooks/` 構造把握 (cursor-adapter.sh + plangate-eh1-plan.sh + plangate-eh2-c3.sh) + `scripts/codex-local.sh` ラッパ責務確認 + `bin/plangate review` 現状 codex case (placeholder) コード抽出 (owner=agent / Risk=low / 🚩 既存資産マップ完成)

### Phase 2: 実装
- [ ] **T-02 (CX-1)**: `bin/plangate` review 関数 codex case を `codex exec --skip-git-repo-check` 直接呼出に実装、stdout を review-external.md に追記。gemini case 構造踏襲 (owner=agent / Risk=medium / depends_on=T-01 / 🚩 gemini case regression なし + 新 codex review 動作)
- [ ] **T-03 (CX-2a)**: `.codex/hooks/codex-adapter.sh` 設計+実装、`.codex/README.md` に責務分界表 (codex-local.sh = auth / codex-adapter.sh = hook bridge) 追加 (owner=agent / Risk=**high** / depends_on=T-01 / 🚩 既存 scripts/hooks 呼出経由で独自ロジック追加なし)
- [ ] **T-04 (CX-2b)**: `.codex/hooks/plangate-eh1-plan.sh` / `plangate-eh2-c3.sh` を `.cursor/hooks/` 翻訳で追加 (`scripts/hooks/check-plan-exists.sh` / `check-c3-approval.sh` を呼ぶ shim) (owner=agent / Risk=high / depends_on=T-03 / 🚩 EH-1 block / EH-2 skip 動作確認)
- [ ] **T-05 (CX-3)**: `docs/rfc/provider-codex.md` 新規。既存 provider-cursor/gemini-cli/opencode RFC structure 踏襲、CX-1/CX-2 完了後の正本ポインタ集約 (owner=agent / Risk=low / depends_on=T-02,T-04 / 🚩 既存 3 RFC との structure 整合)

### Phase 3: 検証
- [ ] **T-06**: `tests/extras/ta-13-codex-review.sh` 新規 — CX-1 wiring を fake codex で fixture test (owner=agent / Risk=medium / depends_on=T-02 / 🚩 `tests/run-tests.sh` 101+1 件 PASS)
- [ ] **T-07**: `tests/hooks/codex-adapter-test.sh` 新規 — CX-2 hook adapter を cursor-adapter-test.sh と同 pattern で fixture test (owner=agent / Risk=medium / depends_on=T-04 / 🚩 `tests/hooks/run-tests.sh` 79+1 件 PASS)
- [ ] **T-08**: 既存テスト regression — `tests/run-tests.sh` 101/0 + `tests/hooks/run-tests.sh` 79/0 維持 (owner=agent / Risk=low / 🚩 全 PASS)
- [ ] **T-09**: 承認境界回帰 — `bin/plangate doctor` で codex CLI 検出が継続動作、`PLANGATE_IMPL_AGENT:-codex` / `PLANGATE_EXTERNAL_REVIEWER:-codex` 既定不変 (owner=agent / Risk=medium / depends_on=T-02 / 🚩 doctor PASS + 既定値検証)

### Phase 4: 完了
- [ ] **T-10**: handoff.md 作成 (Rule 5 必須 6 要素) + V-1 (test-cases 全件突合) (owner=agent / Risk=low / depends_on=全完了 / 🚩 AC-1..6 PASS)

## 👤 Human タスク

- [ ] **H-01**: **C-3 ゲート** — plan/todo/test-cases/review-self を確認 → APPROVE/CONDITIONAL/REJECT → `approvals/c3.json` 発行
- [ ] **H-02**: **C-4 ゲート (PR レビュー)** — exec 完了後 PR 確認
- [ ] **H-03**: **merge** — Human-owned 固定

## ⚠️ 依存関係

- T-02..T-09 は H-01 (C-3) 通過後にのみ着手可
- T-01 (read-only 調査) は C-3 前可
- T-03 → T-04 (hook adapter 設計 → 実配線)
- T-02/T-04 → T-05 (RFC は実装完了後)
- T-02 → T-06、T-04 → T-07

## Iron Law 遵守

- Edit/Write 前に PLANGATE_HOOK_TASK=TASK-0109 設定
- `.codex/hooks/` は Hardening Override 対象外 (新規パス) だが、`bin/plangate` は Override 対象 → 改修時は **maintenance window (#289/TASK-0106 で実装済 CLI 経由)** または直接 PLANGATE_HOOK_TASK 設定必須

## 完了条件

全 T + handoff 6 要素 + AC-1..6 + tests/run-tests 101+1/0 + tests/hooks 79+1/0
