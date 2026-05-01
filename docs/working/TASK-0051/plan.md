# EXECUTION PLAN: TASK-0051 / Issue #172

> Mode: **light**

## Goal

`FILENAME_TO_SCHEMA` を 1 箇所（`scripts/schema_mapping.py`）に集約し、両 script が import で参照する形に変更。同期漏れリスクを構造的に解消する。

## Approach

1. `scripts/schema_mapping.py` を新設（FILENAME_TO_SCHEMA / SCHEMAS_DIR / lookup_schema()）
2. `scripts/validate-schemas.py` の同名定義を削除し、`sys.path` を経由して import
3. `scripts/eval-runner.py` も同じく import に置換、版番を 1.0.0 → 1.1.0 に上げる
4. `tests/run-tests.sh` で 21 件 PASS 維持を確認

## 変更ファイル

| ファイル | 種別 |
|---------|------|
| `scripts/schema_mapping.py` | 新規 |
| `scripts/validate-schemas.py` | 編集（mapping 削除 + import）|
| `scripts/eval-runner.py` | 編集（mapping 削除 + import + version bump）|
| `docs/working/TASK-0051/*` | 新規 |

## Mode判定

light（純粋なリファクタリング、機能変更なし、後方互換維持）

## Risks & Mitigations

| Risk | Mitigation |
|------|----------|
| `sys.path.insert` による import が CI で失敗 | 既に `evaluate_schema_compliance` 内で同手法を使っており動作実績あり |
| eval-runner の旧 version 1.0.0 を期待する fixture | EVAL_RUNNER_VERSION は eval-result.json `evaluator_version` に出力、機械検証なし → safe |

## 確認方法

- `python3 scripts/validate-schemas.py tests/fixtures/schema-validate/valid/c3.json` → PASS
- `python3 scripts/validate-schemas.py tests/fixtures/schema-validate/invalid/c3.json` → exit 1
- `sh tests/run-tests.sh` → 21 PASS
