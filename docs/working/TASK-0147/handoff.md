# TASK-0147 Handoff — validation_bias conductor export 配線（#527 follow-up）

> WF-05 完了資産（Rule 5）。issue #644 / plan PR #643（マージ済み）の実装フェーズ。

## 1. 要件適合確認結果（AC ごと）

| AC | 内容 | 判定 | 根拠 |
|----|------|------|------|
| AC-1 | `--profile <strict系>` で `PLANGATE_VALIDATION_BIAS=strict` を export | PASS（sandbox）| ta-49 TC-01 / 統合解決 gpt-5_5_pro→strict |
| AC-2 | normal/lenient・無指定では strict を export しない | PASS | ta-49 TC-02 |
| AC-3 | env 既設定なら上書きしない | PASS（sandbox）| ta-49 TC-03（`[ -z "${PLANGATE_VALIDATION_BIAS:-}" ]` ガード） |
| AC-4 | 不正/未知 key・yaml 破損は安全側 normal + stderr 警告 | PASS | ta-49 TC-04 / TC-06 |
| AC-5 | patched `bin/plangate` 構文健全 | PASS（sandbox）| ta-49 TC-05（`sh -n`） |

## 2. 既知課題一覧

- `bin/plangate` / `workflow-conductor.md`（HO）は PR 時点で未パッチ（apply-script のみ同梱）。適用は Human が PR マージ後に `--apply`。
- `model-profiles.yaml` の「active profile」自動選択は本 PBI 対象外（明示 `--profile` のみ）。
- conductor が `--profile` を必ず渡すことの強制はしない（強制は CLI 側に閉じる・補足は非強制）。

## 3. V2 候補

- `model-profiles.yaml` の active profile 自動選択（案C）。
- `plugin/plangate/agents/workflow-conductor.md`（export 版）への補足同期（plugin sync）。
- hook-enforcement.md の follow-up 記述を「配線済み（実 run 発火）」へ更新。

## 4. 妥協点（採用しなかった選択肢と理由）

- **conductor 手順で env export を強制（案B）**: プロンプト依存で強制力なし → CLI 側 export（案A）を主、conductor は非強制の補足に限定。
- **`--validation-bias` 直フラグ**: profile と二重管理になる → 既存 `--profile` に一本化し profile から解決。
- **active profile 自動解決（案C）**: active 概念が未定義 → スコープ外。

## 5. 引き継ぎ文書（サマリ）

EHS-1/2/3 は配線・適用済みだったが発火条件 `PLANGATE_VALIDATION_BIAS` を実 run で供給する経路が欠けていた（TASK-0146 Non-goals / issue #644）。本 PBI で `bin/plangate verify`/`handoff --verify` が `--profile <key>` を受理し `model-profiles.yaml` の `validation_bias` を解決して内部 export する経路を配線。strict profile で EHS が実発火し、normal/lenient・env 明示時は従来挙動。HO のため実ツリー本体は未改変、Human が `sh scripts/apply-task-0147-bias-export.sh --apply` で適用する。

## 6. テスト結果サマリ

- `tests/extras/ta-49-bias-export.sh`: 未適用ツリーで層A 4 PASS / 層B SKIP、sandbox 適用で TC-01〜06 全 PASS
- `sh tests/run-tests.sh`: 363 passed / 0 failed
