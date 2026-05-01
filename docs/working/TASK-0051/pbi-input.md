# PBI INPUT PACKAGE: TASK-0051 / Issue #172

> Source: [#172 FILENAME_TO_SCHEMA 一元化](https://github.com/s977043/plangate/issues/172)
> Mode: **light**

## Context / Why

`scripts/validate-schemas.py`（#158）と `scripts/eval-runner.py`（#156）の両方で同じ `FILENAME_TO_SCHEMA` を別々にハードコード。schema 追加時に 2 箇所更新が必要 → 同期漏れリスク。retrospective 2026-05-01 Try T-6。

## What

### In scope
- `scripts/schema_mapping.py` 新設（import 可能名、ハイフン回避）
- `scripts/validate-schemas.py` から FILENAME_TO_SCHEMA / SCHEMAS_DIR / lookup_schema を削除し import に置換
- `scripts/eval-runner.py` から同マッピングを削除し import に置換
- 21 件 PASS 維持

### Out of scope
- `scripts/validate-schemas.py` 自体のリネーム（後方互換維持、bin/plangate / workflow が依存）
- JSON 設定ファイル化（Python module で十分、build/parse コスト不要）

## Acceptance Criteria

- AC-1: `scripts/schema_mapping.py` が単独で `from schema_mapping import FILENAME_TO_SCHEMA, lookup_schema, SCHEMAS_DIR` できる
- AC-2: `scripts/validate-schemas.py` / `scripts/eval-runner.py` が共通 module を参照
- AC-3: `sh tests/run-tests.sh` 21 件 PASS
- AC-4: 同じ key を複数 module でハードコードしている箇所がゼロ
