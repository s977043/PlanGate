# TASK-0146 テストケース — EHS-2/3 bin/plangate 配線

## 受入基準 → テストケースマッピング

| 受入基準 | テストケース |
|---------|-----------|
| EHS-3 が cmd_verify V-1 失敗経路に配線 | TC-01 |
| EHS-3 strict 時は fix-loop 上限超過で block | TC-02 |
| EHS-3 非 strict では warn のみ（既存挙動不変） | TC-03 |
| EHS-2 が handoff --verify に配線 | TC-04 |
| EHS-2 strict 時は 6要素不足で block | TC-05 |
| patched bin/plangate が構文健全 | TC-06 |

## テストケース一覧

### TC-01: EHS-3 配線確認（静的）

| 項目 | 内容 |
|------|------|
| 前提条件 | apply-script 適用済み |
| 入力 | `grep -q "EHS-3" bin/plangate` |
| 期待出力 | exit 0（EHS-3 文字列が存在） |
| 種別 | 静的検査 |

### TC-02: EHS-3 strict 時 block

| 項目 | 内容 |
|------|------|
| 前提条件 | apply-script 適用済み |
| 入力 | `bin/plangate` の EHS-3 block コード存在確認（awk で `EHS-3 BLOCK` 直後 `return 1` を検索） |
| 期待出力 | found |
| 種別 | 静的検査 |

### TC-03: EHS-3 非 strict 既定（warn のみ）

| 項目 | 内容 |
|------|------|
| 前提条件 | apply-script 適用済み |
| 入力 | `grep -q ':-normal' bin/plangate` |
| 期待出力 | exit 0（non-strict 既定の担保） |
| 種別 | 静的検査 |

### TC-04: EHS-2 配線確認（静的）

| 項目 | 内容 |
|------|------|
| 前提条件 | apply-script 適用済み |
| 入力 | `grep -q "EHS-2" bin/plangate && grep -q -- "--verify" bin/plangate` |
| 期待出力 | exit 0（`--verify` フラグと EHS-2 が共存） |
| 種別 | 静的検査 |

### TC-05: EHS-2 strict 時 block

| 項目 | 内容 |
|------|------|
| 前提条件 | apply-script 適用済み |
| 入力 | `awk '/EHS-2 BLOCK/{flag=2} flag && --flag && /return 1/{found=1} END{exit !found}' bin/plangate` |
| 期待出力 | exit 0 (found) |
| 種別 | 静的検査 |

### TC-06: patched bin/plangate 構文健全

| 項目 | 内容 |
|------|------|
| 前提条件 | apply-script 適用済み |
| 入力 | `sh -n bin/plangate` |
| 期待出力 | exit 0（構文エラーなし） |
| 種別 | 構文検査 |

## エッジケース

- EHS-1（TASK-0145）未適用でも ta-47 は独立して動作する（SKIP ガードは EHS-2/3 キーワードの存在で判定）
- `PLANGATE_BYPASS_HOOK=1` 設定時は check-fix-loop.sh / check-handoff-elements.sh がスルー（TA内では BYPASS 使用可）
