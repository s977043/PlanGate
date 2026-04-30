# EXECUTION PLAN: TASK-0047 / Issue #158

> Mode: **high-risk**

## Goal

PlanGate v8.3 で整備済の 4 schema を **実プロンプト + CI** に接続し、format adherence の release blocker 観点を機械検証可能にする。既存 PBI / 挙動は破壊しない（後方互換維持）。

## Constraints / Non-goals

- 既存 `bin/plangate validate` の挙動は **変更しない**（新サブコマンド分離）
- 既存 PBI（PBI-116 配下）の JSON 遡及追加は本 PBI 範囲外（CI は対象 JSON が無ければ skip）
- jsonschema パッケージはローカル必須にしない（CI workflow で install、test は環境検出で skip）

## Approach Overview

### 1. CI / 検証ロジック

- `scripts/validate-schemas.py`（Python）: 単一ファイル / `--dir` / `--files-from` の 3 入力、`FILENAME_TO_SCHEMA` で basename → schema 自動マッピング
- `bin/plangate validate-schemas`（POSIX sh）: TASK ID 拡張（→ `--dir <task-dir>`）+ Python スクリプトへ委譲
- `.github/workflows/schema-validate.yml`: PR で `docs/working/**/*.json` を抽出、`pip install jsonschema` 後 validate

### 2. プロンプト側（contracts）

5 つの phase contract に schema reference を追記:
- plan.md: Output discipline + 関連
- review.md: Output discipline
- verify.md: Output discipline
- handoff.md: Output discipline
- classify.md: Output discipline + 関連

### 3. ドキュメント

- `structured-outputs.md` § 8: CI 統合 / マイグレーション / 後方互換性
- `eval-cases/format-adherence.md`: Detection 手順を新 CI に整合

### 4. テスト

- `tests/fixtures/schema-validate/{valid,invalid}/c3.json`
- `tests/run-tests.sh`: TA-05 として 3 テストケース統合（valid PASS / invalid FAIL / usage text）
- jsonschema 未インストール環境では `[SKIP]` 表示

## Work Breakdown

| Step | Output | 🚩 |
|------|--------|----|
| 1 | `scripts/validate-schemas.py` | Python script で valid / invalid 動作確認 |
| 2 | `bin/plangate validate-schemas` 追加 | usage / TASK 展開 / `--dir` 動作確認 |
| 3 | fixture + run-tests.sh 統合 | `sh tests/run-tests.sh` 全 PASS |
| 4 | contracts/*.md × 5 編集 | schema reference 明記 |
| 5 | structured-outputs.md § 8 追記 | マイグレーションガイド |
| 6 | format-adherence.md Detection 整合 | CI 実装との一致 |
| 7 | `.github/workflows/schema-validate.yml` | PR で起動、JSON 不在 skip |
| 8 | TASK-0047/handoff.md | Rule 5 必須 |

## Files / Components to Touch

| ファイル | 種別 |
|---------|------|
| `scripts/validate-schemas.py` | 新規 |
| `bin/plangate` | 編集（cmd_validate_schemas + dispatch + help）|
| `.github/workflows/schema-validate.yml` | 新規 |
| `tests/fixtures/schema-validate/{valid,invalid}/c3.json` | 新規 |
| `tests/run-tests.sh` | 編集（TA-05 追加）|
| `docs/ai/contracts/{plan,review,verify,handoff,classify}.md` | 編集 |
| `docs/ai/structured-outputs.md` | 編集（§ 8 追加）|
| `docs/ai/eval-cases/format-adherence.md` | 編集（Detection）|
| `docs/working/TASK-0047/*` | 新規 |

## Testing Strategy

- Unit (fixture): valid / invalid c3.json で Python script の挙動を保証（TA-05 で 3 件）
- Integration: `bin/plangate validate-schemas` が python wrapper として正しく動作（TA-05）
- E2E: 本 PR 自身に `docs/working/TASK-0047/approvals/c3.json` 等の JSON は含まれず、CI は skip 動作で確認（後方互換性検証）
- 別途、本 PR で `tests/fixtures/schema-validate/valid/c3.json` を追加するため schema-validate workflow が **fixtures 経由で valid 判定**（path に `tests/fixtures/` も対象になるよう考慮 → 但し `docs/working/**/*.json` のみ対象なので影響なし）

## Risks & Mitigations

| Risk | Mitigation |
|------|----------|
| jsonschema 依存でローカル test fail | `python3 -c 'import jsonschema'` で利用可能性チェック、不可なら SKIP メッセージ |
| 既存 PBI（PBI-116 配下）の JSON が新 CI で fail | 既存配下に JSON は無く、対象 JSON 0 件で skip 動作（AC-6） |
| `bin/plangate validate` 拡張による後方互換破壊 | 既存 cmd_validate に触らず、新サブコマンド分離で達成 |
| schema 自体のバグで正常 JSON が fail | first error path をエラーメッセージに含め、PR コメントで確認可能 |

## Mode判定

**モード**: high-risk

**判定根拠**:
- 変更ファイル数: 9 → high-risk
- 受入基準数: 7 → high-risk
- 変更種別: CI 新設 + CLI 拡張 + 複数 doc 編集 → high-risk
- リスク: 既存 PBI への影響、後方互換性必要 → 中
- ロールバック: 容易（PR revert）→ 中
- **最終判定**: high-risk

## Questions / Unknowns

- 解決済: jsonschema は CI で `pip install` で十分（runner 標準で Python 3.12 使用）
- 解決済: 既存 PBI への影響は対象 JSON 0 件で skip 動作で回避

## 確認方法

- `sh tests/run-tests.sh` → 全 13 件 PASS（TA-05 含む）
- `sh bin/plangate validate-schemas tests/fixtures/schema-validate/valid/c3.json` → PASS
- `sh bin/plangate validate-schemas tests/fixtures/schema-validate/invalid/c3.json` → FAIL（exit 1）
- `.github/workflows/schema-validate.yml` の paths filter で本 PR が trigger 対象になることを yaml で確認
