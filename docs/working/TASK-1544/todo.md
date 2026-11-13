# TASK-1544 EXECUTION TODO

## Mode

high-risk（plan.md「Mode判定」。R-NNN 反映で AC 6 件となり standard から引き上げ）

## 前提（R-NNN 反映後）

- [ ] T-0: plan-draft.md を plan.md へ移し、plan-draft.md を削除する。`PLANGATE_HOOK_TASK=TASK-1544` のセッションで行う。plan.md 確定後に Human が c3.json（確定後 plan の plan_hash）を発行する — owner: agent / 🚩 / rollback: `git checkout -- docs/working/TASK-1544/`

## 🤖 Agent タスク

### 1. 準備

- [ ] T-1: EH-3 の起動条件を確認する（`PLANGATE_HOOK_TASK=TASK-1544` で起動したセッションか）。違えば停止して再起動を依頼する — owner: agent / 🚩 / rollback: 不要

### 2. 実装

- [ ] T-2: `tests/extras/ta-118-retro-seed-draft.sh` を書き、生成器が無い状態で FAIL を記録（RED） — owner: agent / depends_on: T-1 / 🚩 / rollback: ファイル削除
- [ ] T-3: `scripts/retro_seed_draft.py` を実装し TA-118 全 PASS（GREEN）。ゲート 1〜5・終了コード 0/2〜7・`--out` の `lexists` + `O_EXCL`・sha256 再照合つき `os.replace` を含む（R-010〜R-016） — owner: agent / depends_on: T-2 / 🚩 / rollback: ファイル削除
- [ ] T-4: `docs/workflows/06_retro.md` の検査観点節を更新 — owner: agent / depends_on: T-3 / rollback: `git checkout -- docs/workflows/06_retro.md`

### 3. 検証

- [ ] T-3b: 生成器の module docstring に残存脅威モデル（R-017 の U+3164 を含む）と confirmed_by の信頼境界を書く（R-004 / R-008 / R-017） — owner: agent / depends_on: T-3 / rollback: 該当 docstring を戻す
- [ ] T-5: 変異注入 M-1〜M-7・M-2b・M-6b（test-cases.md）。各 TC の終了コードは完全一致で照合する（R-010）を実行し、結果を status.md に記録 — owner: agent / depends_on: T-3 / 🚩 / rollback: `git checkout -- scripts/retro_seed_draft.py`
- [ ] T-6: `sh tests/run-tests.sh` を実行し、main の同じ実行と FAIL 件数を対照 — owner: agent / depends_on: T-4 / 🚩 / rollback: 不要

### 4. 完了

- [ ] T-7: status.md / handoff.md / INDEX.md を更新 — owner: agent / depends_on: T-6 / rollback: 不要

## 👤 Human タスク

- [ ] H-1: C-3 判断と `approvals/c3.json` の発行（exec の前）
- [ ] H-2: C-4 レビューと merge

## ⚠️ 依存関係（Agent ↔ Human）

- H-1 は T-0（plan.md 確定）の後
- T-1 以降は H-1（C-3 APPROVED）の後
- H-2 は T-7 の後

## 対象外（workflow-conductor が自動制御するため書かない）

L-0 / V-1〜V-4 / PR 作成
