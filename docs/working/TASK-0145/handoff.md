# TASK-0145 Handoff — EHS strict 発火配線（#527 増分1: EHS-1）

> WF-05 完了資産（Rule 5）。本 PR は増分1（EHS-1）のみ。増分2/3 は別 PR。

## 1. 要件適合確認結果（AC ごと）

| AC | 内容 | 判定 | 根拠 |
|----|------|------|------|
| AC-1 | strict を EHS-1 発火条件に配線 | PASS（sandbox）| ta-46 TC-01 |
| AC-2 | strict 時 V-3 不合格を block（`return 1`）| PASS（sandbox）| ta-46 TC-02 |
| AC-3 | 既定 normal で非発火＝既存挙動不変 | PASS（sandbox）| ta-46 TC-03 |
| AC-4 | patched `bin/plangate` 構文健全 | PASS（sandbox）| ta-46 TC-04 |

> 実ツリーは HO 未適用のため ta-46 は SKIP。適用は Human-owned（`--apply`）。

## 2. 既知課題一覧

- `bin/plangate` 本体は PR 時点で未パッチ（apply-script のみ同梱）。適用は Human が PR マージ後に実施。
- `hook-enforcement.md` 冒頭「12/12」はスクリプト実装数を指し、物理配線は別途進行（#500）。本 PR で EHS-1 行を「apply-script 準備済み・適用待ち」に更新。
- strict の注入経路（conductor の env export）は未配線 → 既定 normal で安全側。

## 3. V2 候補

- conductor が `model-profiles.yaml` active profile から `PLANGATE_VALIDATION_BIAS` を解決・export する経路の正規化。
- `--profile` 直接解決ヘルパーの追加（env 注入方式の代替）。

## 4. 妥協点（採用しなかった選択肢と理由）

- **`bin/plangate` を AI 直接編集**: HO パスのため不可 → apply-script + Human 適用方式を採用（TASK-0143 eh457 と同方式）。
- **行番号ベース patch**: bin/plangate の行変化で破綻するため不採用 → 文字列アンカー方式 + dry-run。
- **増分2/3 同梱**: PR 肥大・レビュー困難を避け増分分割（本 PR は EHS-1 のみ）。

## 5. 引き継ぎ文書（サマリ）

EPIC #527 の残「EHS-1/2/3 strict 発火配線」を main 方針（`bin/plangate` ベース）で引き取り。増分1 で EHS-1（strict 時 V-3 必須化）を apply-script として実装。env `PLANGATE_VALIDATION_BIAS`（既定 normal）で発火制御し、非 strict は既存挙動不変。HO のため実ツリー本体は未改変、Human が `--apply` で適用する。次は PR → C-3（人間必須）→ マージ → apply の順。増分2（EHS-3）/ 増分3（EHS-2）は別 PR。

## 6. テスト結果サマリ

- `tests/extras/ta-46-ehs-wiring.sh`: 未適用ツリーで SKIP（確認 2026-06-27）/ sandbox 適用で TC-01〜04 PASS
- `sh tests/run-tests.sh`: 349 passed / 0 failed
