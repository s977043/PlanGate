# TASK-0147 EXECUTION TODO — validation_bias conductor export 配線（#527 follow-up）

## 🤖 Agent タスク

### 準備

- [ ] `model-profiles.yaml` の profile 構造・`validation_bias` 値域確認（済: normal/strict/lenient）
  - rollback: 不要（読取）
- [ ] 既存 `--profile` 受理箇所（context/eval）の引数処理パターン踏襲方針確定
  - rollback: 不要（設計）

### 実装

- [ ] `scripts/_resolve_validation_bias.py`（profile key → bias 解決）
  - rollback: ファイル削除
- [ ] `scripts/apply-task-0147-bias-export.sh` + `_apply_task_0147_patches.py`（HO apply、dry-run/--apply、文字列アンカー）
  - rollback: ファイル削除（HO 本体未改変なら影響なし）
- [ ] `tests/extras/ta-49-bias-export.sh`（未適用 SKIP / 適用後 TC-01〜05）
  - rollback: ファイル削除

### 検証

- [ ] sandbox 適用で TC-01〜05 PASS・`sh -n` OK・strict profile で EHS 実発火確認
- [ ] `sh tests/run-tests.sh` 0 FAIL

### 完了整備

- [ ] hook-enforcement.md follow-up 記述を「配線済み」へ更新（#642 マージ後に調整）
- [ ] working-context（status/current-state/handoff）整備
- [ ] PR 作成

## 👤 Human タスク

- [ ] **C-3 ゲート**: high-risk / HO 2 種 → **人間 C-3 必須**（autonomous APPROVE 不可）
- [ ] **apply-script 適用**: `sh scripts/apply-task-0147-bias-export.sh --apply`（bin/plangate + workflow-conductor の HO 改変）
- [ ] **新 issue 起票**: EPIC #527（CLOSED）の follow-up としてスコープ限定で起票
- [ ] **C-4 ゲート**: PR レビュー → マージ

## ⚠️ 依存関係

- 本 PBI は TASK-0145/0146（EHS 配線済み・main マージ済み）を前提
- PR #642（doc 同期）と hook-enforcement.md が競合しうる → #642 先行マージ推奨

## スコープ外（別 PBI）

- `model-profiles.yaml` の "active profile" 自動選択（案C）
- conductor が `--profile` を必ず渡すことの強制（プロンプト止まり＝CLI 側に強制を閉じる）
