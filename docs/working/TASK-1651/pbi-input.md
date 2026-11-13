# TASK-1651 PBI INPUT PACKAGE

> 出典: issue #1651（照合: origin/main `8a689907`）。静的読解のみで作成し、テストは実行していない。

## Context / Why

- macOS では `tests/extras/ta-10-doctor-fix.sh` の TC-7 が必ず FAIL する。ローカルの `run-tests.sh` に恒常的なノイズが出ており、V-1 のたびに帰属作業が要る（TASK-1197 / TASK-1408）。
- 原因: `scripts/doctor_check.py` の `main()`（:484-485）が、どの scope の JSON にも `project_root = str(REPO)`（絶対パス）と `project_root_source` を足す（#1497 / `3c34d2f6`）。TC-7（:317）は JSON 全体を文字列にして `"/Users/"` を含めば privacy leak と判定する。
- Linux CI の checkout は `/home/runner/work/...` なので `"/Users/"` に一致せず、CI は緑のまま絶対パス漏れの検査が空振りしている。
- 契約がずれている。`doctor_check.py` の docstring（:21）は "no paths beyond what is already public"、TC-7 の見出し（:294）は「絶対パス値は JSON に含まれない」と書く一方、実装は `project_root` を意図して出している。

## What（Scope）

### In scope

- `tests/extras/ta-10-doctor-fix.sh` の TC-7（検査ロジックと見出しコメント）
- `scripts/doctor_check.py` の docstring（契約の文言だけ。挙動は変えない）

### Out of scope

- `bin/plangate`（HO 対象。doctor 引数の転送は変更しない）
- `doctor_check.py` の JSON 出力の変更（`project_root` の削除・相対化・opt-in 化 = 是正案 B / C）
- #921（extras の standalone FAIL が exit code に反映されない件）
- `metrics-privacy.md` の改訂

## 受入基準

| ID | 基準（issue の AC に対応） |
|----|------|
| AC-1 | macOS と Linux の両方で、TC-7 が **hooks scope の JSON**（`doctor --json --scope hooks`）について、契約上許可した 1 キー（トップレベル `project_root`）以外に絶対パスの文字列値があれば検出する（他 scope は TC-7 の対象外。残存脅威は plan-draft.md「残存脅威」節。R-001） |
| AC-2 | `project_root` 以外のキーに絶対パスを入れた変異で TC-7 が FAIL する（陽性対照） |
| AC-3 | `doctor_check.py` の docstring と TC-7 の見出しコメントが同じ契約を書いている |

## Notes from Refinement

- issue の是正案 A〜D のうち A を推奨する（plan.md D-1）。
- `project_root` は #1497 で意図して追加された診断情報であり、非 JSON の doctor も `PlanGate Doctor target: <path>` を出す。出力は送信も永続化もされない。

## Estimation Evidence

- Risks: 除外を広く取りすぎると検査が弱まる（除外は完全一致のキー 1 つに限る）。再帰検査が既存の他 scope の正当な値（相対パス等）に誤反応する。
- Unknowns: `project_root` 以外に絶対パスを出している既存キーが hooks scope にあるか（exec の最初に実測する）。`metrics-privacy.md` §4 が CLI 出力全般に及ぶか（issue では未読）。
- Assumptions: hooks scope の JSON 出力は、`project_root` を除けば現状でも絶対パスを含まない。
