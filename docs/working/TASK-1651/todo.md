# TASK-1651 EXECUTION TODO

> 計画本文: plan-draft.md（plan.md への移動待ち）。Mode: standard。

## 🤖 Agent タスク

### 準備

- [ ] T-1 前提の実測（U-1 / U-2）: `sh bin/plangate doctor --json --scope {v8.6.0,hooks,maintenance}` の出力から絶対パス値を列挙し、`grep -n PLANGATE_PROJECT_ROOT_SOURCE bin/plangate` を読む
  - owner: agent / depends_on: C-3 APPROVED
  - 完了条件: `project_root` 以外の絶対パス値 0 件、SOURCE は識別子のみ。evidence/test-runs/t1-json-paths.txt に記録
  - rollback: 不要（読み取りのみ）
  - 🚩 違えば Stop して Human 判断

### 実装

- [ ] T-2 検査器関数 + TC-7b を追加（RED → GREEN）
  - owner: agent / depends_on: T-1
  - 完了条件: TC-7b が PASS。旧検査相当で `/home/runner/...` 合成入力を検出できないことを evidence に記録
  - rollback: `git checkout -- tests/extras/ta-10-doctor-fix.sh`
  - 🚩 todo / status 更新
- [ ] T-3 TC-7 を新検査器へ切り替え、見出しコメントを D-4 の契約に更新
  - owner: agent / depends_on: T-2
  - 完了条件: macOS で TC-7 PASS（変更前 FAIL の記録あり）
  - rollback: `git checkout -- tests/extras/ta-10-doctor-fix.sh`
  - 🚩 todo / status 更新
- [ ] T-4 `scripts/doctor_check.py` docstring の Privacy 文を D-4 の契約に更新
  - owner: agent / depends_on: T-3
  - 完了条件: `python3 -m py_compile scripts/doctor_check.py` 成功、`--json` 出力が変更前後でバイト一致
  - rollback: `git checkout -- scripts/doctor_check.py`
  - 🚩 todo / status 更新

### 検証

- [ ] T-5 変異注入 M-1〜M-3（test-cases.md）。M-1 / M-2 は TC-7、M-3 は TC-7b（TC-03）が FAIL、戻して PASS（R-002）
  - owner: agent / depends_on: T-4
  - 完了条件: 結果と各変異の stderr を evidence/test-runs/mutation.txt に記録（R-004）。変異は commit しない
  - rollback: `git checkout -- scripts/doctor_check.py tests/extras/ta-10-doctor-fix.sh`
- [ ] T-6 `sh tests/run-tests.sh`（harness 経由）と main での対照実行
  - owner: agent / depends_on: T-5
  - 完了条件: ta-10 全 PASS、既存 FAIL を増やさない（main 対照で帰属）
  - rollback: 不要（実行のみ）

### 完了

- [ ] T-7 status.md / INDEX.md / handoff.md を更新
  - owner: agent / depends_on: T-6
  - 完了条件: handoff 6 要素。U-3 を既知課題に記載
  - rollback: `git checkout -- docs/working/TASK-1651/`

## 👤 Human タスク

- [ ] H-0 TASK 文脈付きセッション（`PLANGATE_HOOK_TASK=TASK-1651`）で plan-draft.md を plan.md へ移す
- [ ] H-1 C-3: `bin/plangate approve TASK-1651`（plan.md 確定後）
- [ ] H-2 C-4: PR レビュー / merge

## ⚠️ 依存関係

H-0 → H-1 → T-1 → T-2 → T-3 → T-4 → T-5 → T-6 → T-7 → H-2
