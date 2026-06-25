---
task_id: TASK-0144
artifact_type: test-cases
schema_version: 1
---

# TEST CASES — TASK-0144（C-2 反映版）

> C-2 指摘 R-006/R-007/R-008 反映済み

## 受入基準 → テストケースマッピング

| AC | TC | 種別 |
|----|-----|------|
| AC-01 | TC-01: conversation モード + exec 前に c3.json 生成 → exec 通過 | Integration |
| AC-02 | TC-02: cli モード（.plangate.yml あり）→ 現行動作維持 | Integration |
| AC-02 | TC-03: .plangate.yml 未存在 → cli フォールバック | Integration |
| AC-03 | TC-04: AI 生成 c3.json に source: conversation フィールド | Unit |
| AC-04 | TC-05: doctor が承認モードを出力 | Unit |
| AC-05 | TC-06: plangate-config.schema.json が mode enum を検証 | Unit |
| AC-06 | TC-07: sh tests/run-tests.sh 0 FAIL（regression） | Integration |

## テストケース一覧

### TC-01: conversation モード + exec 前に c3.json 生成 → exec 通過

- **前提条件**: `.plangate.yml` に `c3_approval: {mode: conversation}` が設定済み、apply-script 適用済み
- **入力**: exec 前に c3.json が生成済み（source: conversation, c3_status: APPROVED, plan_hash 付き）の状態で `bin/plangate exec TASK` 実行
- **期待出力**: exec が c3.json の存在・APPROVED を確認して通過（cmd_exec は変更なし）
- **種別**: Integration（apply 後のみ）
- **R-001/R-002 反映**: c3.json は exec 前に生成済みである必要がある

### TC-02: cli モード（.plangate.yml あり）→ 現行動作維持

- **前提条件**: `.plangate.yml` に `c3_approval: {mode: cli}` が設定済み
- **入力**: c3.json が未存在の状態で `bin/plangate exec TASK` 実行
- **期待出力**: exec が「approvals/c3.json not found」エラーで exit 1
- **種別**: Integration

### TC-03: .plangate.yml 未存在 → cli フォールバック

- **前提条件**: `.plangate.yml` が存在しない
- **入力**: EH-3 が c3.json への Write を試みる
- **期待出力**: maintenance.json なしの場合は BLOCK（cli 動作）
- **種別**: Integration

### TC-04: AI 生成 c3.json に source: conversation フィールド

- **前提条件**: conversation モード有効
- **入力**: AI が approvals/c3.json を生成
- **期待出力**: `jq .source approvals/c3.json` = `"conversation"`
- **種別**: Unit

### TC-05: doctor が承認モードを出力

- **前提条件**: apply-script 適用済み
- **入力**: `bin/plangate doctor`
- **期待出力**: 出力に `C-3 Approval Mode` または `c3_approval.mode` の表示（cli または conversation）
- **種別**: Unit（grep で確認）

### TC-06: plangate-config.schema.json が mode enum を検証（R-006 反映）

- **前提条件**: `schemas/plangate-config.schema.json` 存在、apply-script 適用済み
- **入力 (PASS)**: `c3_approval: {mode: cli}` の yaml が schema に適合
- **入力 (FAIL)**: `c3_approval: {mode: invalid}` の yaml が schema に不適合
- **期待出力**: python3 jsonschema で PASS/FAIL を確認
- **種別**: Unit

### TC-07: sh tests/run-tests.sh 0 FAIL（R-008 反映: 件数固定なし）

- **前提条件**: apply-script 適用済み
- **入力**: `sh tests/run-tests.sh`
- **期待出力**: `0 failed`（件数は問わない）
- **種別**: Integration

## エッジケース

| ケース | 期待挙動 |
|------|---------|
| `.plangate.yml` に `c3_approval.mode` キーなし | `cli` フォールバック |
| `.plangate.yml` に不正な mode 値（例: `foo`）| `cli` フォールバック + stderr WARN（R-005 反映） |
| `.plangate.yml` 存在 + PyYAML 未インストール | `cli` フォールバック + stderr WARN |
| `.plangate.yml` 存在 + 構文エラー（不正 YAML） | `cli` フォールバック + stderr WARN（R-005 反映） |
| c3.json が既に存在する状態で conversation モード exec | 既存 c3.json を使用（cmd_exec 変更なし） |
| approvals/ ディレクトリが未存在 | `mkdir -p` で自動生成 |
| 既存 c3.json（source フィールドなし）の schema 検証 | source が optional のため valid（R-004 反映） |
