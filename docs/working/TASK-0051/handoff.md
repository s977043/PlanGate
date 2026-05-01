---
task_id: TASK-0051
artifact_type: handoff
schema_version: 1
status: final
issued_at: 2026-05-01
author: qa-reviewer
v1_release: ""
related_issue: 172
---

# Handoff: TASK-0051 / Issue #172 — FILENAME_TO_SCHEMA 一元化

## メタ情報

```yaml
task: TASK-0051
related_issue: https://github.com/s977043/plangate/issues/172
author: qa-reviewer
issued_at: 2026-05-01
v1_release: <PR マージ後に SHA>
```

## 1. 要件適合確認結果

| AC | 判定 | 根拠 |
|----|------|------|
| AC-1: `schema_mapping.py` 単独 import 可能 | PASS | `from schema_mapping import FILENAME_TO_SCHEMA, lookup_schema, SCHEMAS_DIR` で 16 件 mapping を取得 |
| AC-2: 両 script が共通 module 参照 | PASS | validate-schemas.py / eval-runner.py から重複 mapping を削除、`sys.path.insert + from schema_mapping import` で取得 |
| AC-3: 21 件 PASS | PASS | `sh tests/run-tests.sh` → `Results: 21 passed, 0 failed` |
| AC-4: ハードコード重複ゼロ | PASS | `grep '"c3-approval.schema.json"' scripts/*.py` → schema_mapping.py 1 件のみ |

**総合**: **4 / 4 PASS**

## 2. 既知課題一覧

| 課題 | Severity | 状態 |
|------|---------|------|
| `validate-schemas.py` 自体のファイル名にハイフン残存 | info | accepted（後方互換維持、bin/plangate / workflow が依存）|
| `sys.path.insert` 方式は若干 hacky | info | accepted（PEP 660 editable install を導入するほどの規模ではない）|

## 3. V2 候補

| V2 候補 | 理由 | 優先度 |
|--------|------|--------|
| scripts/ を Python package 化（`scripts/__init__.py` + 親モジュール）| import の hacky さ解消 | Low |
| schema_mapping を JSON 化（言語非依存）| sh / Python 両用 | Low（現状用途は Python のみ）|

## 4. 妥協点

| 選択 | 諦めた代替 | 理由 |
|------|-----------|------|
| schema_mapping.py（Python module）| schemas/_filename-mapping.json（言語非依存）| 利用箇所が Python のみ、import 直接で型安全 |
| `sys.path.insert` 方式 | `validate-schemas.py` を `validate_schemas.py` にリネーム | bin/plangate / workflow / docs の参照を変更しない（後方互換）|
| `EVAL_RUNNER_VERSION` を 1.0.0 → 1.1.0 にバンプ | 据え置き | 内部構造変更を eval-result.json に記録 |

## 5. 引き継ぎ文書

### 概要

`scripts/validate-schemas.py` と `scripts/eval-runner.py` で重複していた `FILENAME_TO_SCHEMA` mapping（16 entry）を `scripts/schema_mapping.py` に集約。両 script は `sys.path.insert(0, 'scripts')` 経由で import する形に変更。21 件テスト PASS 維持、後方互換維持。

主要成果:
- `scripts/schema_mapping.py` 新設（16 entry mapping + lookup_schema()）
- `scripts/validate-schemas.py`: 重複削除 + import
- `scripts/eval-runner.py`: 重複削除 + import + version 1.0.0 → 1.1.0
- 新 schema 追加時の更新箇所が 1 つに集約 → 同期漏れリスク解消

### 触れないでほしいファイル

- `scripts/schema_mapping.py` の `FILENAME_TO_SCHEMA` キー: basename がそのまま検証対象 JSON 名前と一致する規約
- `scripts/validate-schemas.py` のファイル名: bin/plangate / workflow が依存

### 次に手を入れるなら

- 新 schema 追加: `scripts/schema_mapping.py` の `FILENAME_TO_SCHEMA` に 1 行追加するだけ
- アンチパターン: 個別 script に mapping を再追加（DRY 原則違反）

## 6. テスト結果サマリ

| レイヤー | 件数 | PASS | FAIL / SKIP |
|---------|------|------|-----------|
| Integration（tests/run-tests.sh）| 21 | 21 | 0 / 0 |
| Manual smoke | 3 | 3 | 0 / 0 |

検証コマンド:
```sh
sh tests/run-tests.sh                                                    # 21 PASS
python3 scripts/validate-schemas.py tests/fixtures/schema-validate/valid/c3.json    # PASS
python3 scripts/validate-schemas.py tests/fixtures/schema-validate/invalid/c3.json  # exit 1
```
