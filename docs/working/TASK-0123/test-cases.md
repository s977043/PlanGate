# TASK-0123 TEST CASES

## 受入基準 → テストケースマッピング

| AC | テストケース |
|----|------------|
| AC-1 | TC-01, TC-02, TC-03 |
| AC-2 | TC-04, TC-05 |
| AC-3 | TC-06, TC-07, TC-08 |
| AC-4 | TC-09 |
| AC-5 | TC-10 |
| AC-6 | TC-11 |

---

## テストケース一覧

### AC-1: 署名なし / 鍵不一致の maintenance.json が EH-3 で block される

#### TC-01: 署名フィールドなし（従来形式）でも鍵設定済みなら block

| 項目 | 内容 |
|------|------|
| 前提条件 | `PLANGATE_MAINTENANCE_KEY=testkey` 設定済み |
| 入力 | `hmac_sha256` フィールドなしの有効な maintenance.json（v1 形式） |
| 期待出力 | EH-3 が exit 2 で block |
| 種別 | Unit |
| テストファイル | `ta-25-maintenance-hmac.sh` |
| 自動化 | 可 |

#### TC-02: 署名値が不一致の場合 block

| 項目 | 内容 |
|------|------|
| 前提条件 | `PLANGATE_MAINTENANCE_KEY=testkey` 設定済み |
| 入力 | `hmac_sha256: "wrongvalue"` を持つ maintenance.json |
| 期待出力 | EH-3 が exit 2 で block |
| 種別 | Unit |
| テストファイル | `ta-25-maintenance-hmac.sh` |
| 自動化 | 可 |

#### TC-03: AI が Bash で直接 maintenance.json を書いた場合（鍵不明=署名なし）block

| 項目 | 内容 |
|------|------|
| 前提条件 | `PLANGATE_MAINTENANCE_KEY=testkey` 設定済み |
| 入力 | `approved_by: "ai-agent"` / `hmac_sha256` なしの maintenance.json |
| 期待出力 | EH-3 が exit 2 で block（TC-01 と同等だが意図を明示） |
| 種別 | Unit |
| テストファイル | `ta-25-maintenance-hmac.sh` |
| 自動化 | 可 |

---

### AC-2: 正規フロー（人間 TTY + 鍵設定済み）が EH-3 を通過する

#### TC-04: 正しい HMAC 署名付き maintenance.json が EH-3 を通過する

| 項目 | 内容 |
|------|------|
| 前提条件 | `PLANGATE_MAINTENANCE_KEY=testkey` 設定済み |
| 入力 | `hmac_sha256` が正しく計算された maintenance.json（`PLANGATE_FAKE_KEY=testkey` で生成） |
| 期待出力 | EH-3 が exit 0 で通過（MAINTENANCE_SKIP） |
| 種別 | Unit |
| テストファイル | `ta-25-maintenance-hmac.sh` |
| 自動化 | 可 |

#### TC-05: 鍵未設定環境では署名なしでも通過（後方互換）

| 項目 | 内容 |
|------|------|
| 前提条件 | `PLANGATE_MAINTENANCE_KEY` 未設定 |
| 入力 | v1 形式 maintenance.json（`hmac_sha256` なし） |
| 期待出力 | EH-3 が exit 0 で通過（後方互換） |
| 種別 | Unit |
| テストファイル | `ta-25-maintenance-hmac.sh` |
| 自動化 | 可 |

---

### AC-3: 承認トークン系 path が PreToolUse ガードで block される

#### TC-06: `docs/working/_maintenance/maintenance.json` への Write が block される

| 項目 | 内容 |
|------|------|
| 前提条件 | `check-approval-token-write.sh` が hook に配線済み |
| 入力 | `tool_input.file_path = "docs/working/_maintenance/maintenance.json"` |
| 期待出力 | hook が exit 2 で block |
| 種別 | Unit |
| テストファイル | `ta-26-approval-token-guard.sh` |
| 自動化 | 可 |

#### TC-07: `docs/working/TASK-0099/approvals/c3.json` への Write が block される

| 項目 | 内容 |
|------|------|
| 前提条件 | `check-approval-token-write.sh` が hook に配線済み |
| 入力 | `tool_input.file_path = "docs/working/TASK-0099/approvals/c3.json"` |
| 期待出力 | hook が exit 2 で block |
| 種別 | Unit |
| テストファイル | `ta-26-approval-token-guard.sh` |
| 自動化 | 可 |

#### TC-08: 承認トークン以外のファイルへの Write は通過する

| 項目 | 内容 |
|------|------|
| 前提条件 | `check-approval-token-write.sh` が hook に配線済み |
| 入力 | `tool_input.file_path = "docs/working/TASK-0099/plan.md"` |
| 期待出力 | hook が exit 0 で通過 |
| 種別 | Unit |
| テストファイル | `ta-26-approval-token-guard.sh` |
| 自動化 | 可 |

---

### AC-4: CI が AI 系譜由来 / 自己署名 maintenance.json を検出して fail

#### TC-09: CI workflow が hmac_sha256 なしの maintenance.json をステージングで fail する

| 項目 | 内容 |
|------|------|
| 前提条件 | `PLANGATE_MAINTENANCE_KEY_CI` が GitHub Secrets に登録済み |
| 入力 | `docs/working/_maintenance/maintenance.json` が staging に含まれ `hmac_sha256` フィールドなし |
| 期待出力 | CI job が非ゼロで fail |
| 種別 | Integration（CI） |
| テストファイル | `.github/workflows/check-maintenance-signature.yml` |
| 自動化 | 可（CI） |

---

### AC-5: 既存正規フローに回帰なし

#### TC-10: ta-12-maintenance.sh の全テストが引き続き PASS

| 項目 | 内容 |
|------|------|
| 前提条件 | TASK-0123 実装 + patch apply 済み |
| 入力 | `sh tests/run-tests.sh`（ta-12 を含む） |
| 期待出力 | ta-12 の全テスト PASS（FAIL 0） |
| 種別 | Regression |
| テストファイル | `tests/extras/ta-12-maintenance.sh` |
| 自動化 | 可 |

---

### AC-6: tests/run-tests.sh で全件 PASS

#### TC-11: `sh tests/run-tests.sh` 全件 PASS

| 項目 | 内容 |
|------|------|
| 前提条件 | TASK-0123 実装 + patch apply 済み + settings.json hook wiring 済み |
| 入力 | `sh tests/run-tests.sh` |
| 期待出力 | 全テスト PASS（FAIL 0） |
| 種別 | Integration |
| テストファイル | 全 extras |
| 自動化 | 可 |

---

## エッジケース

| # | エッジケース | 期待動作 |
|---|------------|---------|
| E-1 | maintenance.json が malformed JSON の場合 | EH-3 が INVALID として block |
| E-2 | `hmac_sha256` フィールドが空文字列の場合 | EH-3 が不一致として block |
| E-3 | `PLANGATE_MAINTENANCE_KEY` が空文字列の場合 | 鍵未設定と同等として扱い後方互換（or block）※設計判断が必要 |
| E-4 | `approvals/` 配下の `.json` 以外ファイルへの Write | block しない（json 限定） |
| E-5 | macOS と Linux で openssl 出力形式が異なる場合 | 正規化処理で吸収（`awk '{print $NF}'` 等） |
| E-6 | `PLANGATE_BYPASS_HOOK=1` 設定時の approval-token-guard | BYPASS_HOOK は check-approval-token-write.sh では無効（常時 block） |
