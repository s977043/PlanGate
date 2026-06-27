# TASK-0147 テストケース定義 — validation_bias conductor export（#527 follow-up）

> 自動化: `tests/extras/ta-49-bias-export.sh`。未適用時 SKIP（HO apply 前は CI 非破壊）。

## 受入基準 → テストケースマッピング

| AC | 内容 | TC |
|----|------|----|
| AC-1 | `--profile <strict系key>` で `validation_bias=strict` を解決し `PLANGATE_VALIDATION_BIAS=strict` を export | TC-01 |
| AC-2 | normal/lenient profile では strict を export しない（既定 normal＝既存挙動不変） | TC-02 |
| AC-3 | env で `PLANGATE_VALIDATION_BIAS` が既設定なら上書きしない（明示注入尊重） | TC-03 |
| AC-4 | 不正/未知 profile key・yaml 欠落/破損は安全側（normal fallback、strict にしない）**かつ stderr に警告を出力**（サイレント失敗防止） | TC-04, TC-06 |
| AC-5 | patched `bin/plangate` が構文健全（`sh -n`） | TC-05 |

## テストケース一覧（適用後）

| TC | 前提 | 入力 / 検査 | 期待 | 種別 |
|----|------|------------|------|------|
| TC-01 | apply 済み | `verify --profile gpt-5_5_pro`（strict profile）でヘルパー解決 | export=strict、EHS 有効 | 解決ロジック |
| TC-02 | apply 済み | normal profile 指定 / 無指定 | export されない or normal | 解決ロジック |
| TC-03 | apply 済み | `PLANGATE_VALIDATION_BIAS=normal` 環境下で strict profile 指定 | env 尊重（上書きしない） | 優先順位 |
| TC-04 | apply 済み | 未知 profile key | strict にならない（安全側）+ stderr に警告 | 異常系 |
| TC-05 | apply 済み | `sh -n bin/plangate` | exit 0 | 構文 |
| TC-06 | apply 済み | `model-profiles.yaml` 欠落/破損 | normal fallback + stderr に警告（サイレント失敗しない） | 異常系 |

## エッジケース

- **未適用状態**: マーカ不在 → 全 TC SKIP（CI 非破壊）。
- **`model-profiles.yaml` 欠落/破損**: 解決失敗時は normal fallback（strict 化しない安全側）+ stderr 警告（TC-06）。
- **strict profile + env 明示 normal**: TC-03 が優先順位を担保（env > profile）。

## 統合確認（sandbox）

- strict profile 解決後、`verify` で EHS-1（V-3）/ EHS-3（fix-loop）、`handoff --verify` で EHS-2 が実際に block すること。
