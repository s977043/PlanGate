# TASK-0145 テストケース定義 — EHS strict 発火配線（#527）

> 自動化: `tests/extras/ta-46-ehs-wiring.sh`（`tests/run-tests.sh` から source）。
> 未適用時は SKIP（HO apply 済みでなければ CI を割らない方針＝ta-43/ta-44 同方式）。

## 受入基準 → テストケースマッピング

| AC | 内容 | TC |
|----|------|----|
| AC-1 | `bin/plangate verify` が `validation_bias=strict` を EHS-1 発火条件に配線 | TC-01 |
| AC-2 | strict 時の V-3 不合格は block（`return 1`） | TC-02 |
| AC-3 | 非 strict（既定 normal）では非発火＝既存挙動不変 | TC-03 |
| AC-4 | patched `bin/plangate` が構文健全（`sh -n` 通過） | TC-04 |

## テストケース一覧（適用後）

| TC | 前提 | 入力 / 検査 | 期待 | 種別 |
|----|------|------------|------|------|
| TC-01 | apply 済み | `PLANGATE_VALIDATION_BIAS:-normal` と `"strict"` 分岐が存在 | PASS | grep 静的検査 |
| TC-02 | apply 済み | `EHS-1 BLOCK` 直後に `return 1` | PASS | grep 静的検査 |
| TC-03 | apply 済み | `:-normal` 既定値が存在（非発火担保） | PASS | grep 静的検査 |
| TC-04 | apply 済み | `sh -n bin/plangate` | exit 0 | 構文検査 |

## エッジケース

- **未適用状態**: `EHS-1 BLOCK` マーカ不在 → 全 TC を実行せず SKIP（CI 非破壊）。
- **env 未設定**: `PLANGATE_VALIDATION_BIAS` 未設定時は `:-normal` で normal 扱い → EHS-1 非発火（安全側）。
- **strict だが V-3 合格**: block せず通過（block は V-3 不合格時のみ）。

## 現状の実行結果

- 未適用ツリー: `[SKIP] EHS-1 未適用`（確認済み 2026-06-27）
- sandbox 適用: TC-01〜04 全 PASS（plan.md / status.md 記載）
- suite 全体: 349 passed / 0 failed
