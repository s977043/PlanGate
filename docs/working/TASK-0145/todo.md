# TASK-0145 EXECUTION TODO — EHS strict 発火配線（#527）

> plan.md と同時管理。L-0〜V-4 / PR 作成は workflow-conductor 自動制御のため含めない。

## 🤖 Agent タスク

### 準備

- [x] EPIC #527 残（EHS-1/2/3）の main 方針確認（`bin/plangate` ベース、TASK-0143 eh457 後続）
  - rollback: 不要（読取のみ）
- [x] EHS-1 発火条件の設計（env `PLANGATE_VALIDATION_BIAS`、既定 normal 安全側）
  - rollback: 不要（設計のみ）

### 実装（増分1: EHS-1）

- [x] `scripts/_apply_task_0145_patches.py`（文字列アンカー方式・dry-run/--apply）
  - rollback: ファイル削除（HO 本体は未改変のため影響なし）
- [x] `scripts/apply-task-0145-ehs-wiring.sh`（HO apply ラッパ）
  - rollback: ファイル削除
- [x] `tests/extras/ta-46-ehs-wiring.sh`（未適用 SKIP / 適用後 TC-01〜04）
  - rollback: ファイル削除

### 検証

- [x] sandbox 適用検証（`sh -n` OK・TC-01〜04 全 PASS、実ツリー HO 非改変）
- [x] `sh tests/run-tests.sh` 0 FAIL（349 passed・ta-46 は未適用 SKIP）

### 完了整備（本作業）

- [x] working-context 整備（todo / test-cases / status / current-state / handoff）
- [x] `docs/ai/hook-enforcement.md` の EHS-1 配線状態を実態（apply-script 準備済み・適用待ち）へ整合
- [ ] PR 作成（C-4 ゲート用）

## 👤 Human タスク

- [ ] **C-3 ゲート**: 増分1 plan 承認（high-risk / HO パス → 人間 C-3 必須）
- [ ] **apply-script 適用**: `sh scripts/apply-task-0145-ehs-wiring.sh --apply`（HO `bin/plangate` 改変は Human-owned）
  - 適用後: ta-46 が SKIP→TC-01〜04 PASS、`bin/plangate doctor` で確認
- [ ] **C-4 ゲート**: PR レビュー → マージ

## ⚠️ 依存関係

- apply-script 適用（Human）は PR マージ後に実施（HO 本体は PR には含めない＝apply-script のみ同梱）
- 増分2（EHS-3）/ 増分3（EHS-2）は本 PR スコープ外（別 PR）

## 残スコープ外（別タスク / 別 PR）

- 増分2: EHS-3 fix-loop 上限 strict 配線（`check-fix-loop.sh`）
- 増分3: EHS-2 handoff 6要素 strict 配線（`check-handoff-elements.sh`）
- conductor が `model-profiles.yaml` active profile から `PLANGATE_VALIDATION_BIAS` を export する経路の明文化
