# EXECUTION PLAN: TASK-0053 / Issue #167

> Mode: **light**（当初 standard 想定だが Option B 採用で 2 ファイル変更のみ）

## Goal

`patternProperties: { "^_": {} }` を c3 / c4 schema に追加。既存 c3.json を **無変更** のまま schema 適合化し、人間可読 annotation（`_review_summary` 等）の保持と機械検証を両立。

## Approach

JSON Schema の標準機能 `patternProperties` を活用:
- `properties` で定義した key と `patternProperties` にマッチする key 以外は `additionalProperties: false` で拒否
- `^_` プレフィクスの key は内容自由（schema `{}` = anything）

これにより:
- 既存 c3.json の `_review_summary` `_schema_reference` `_note` が許容される
- typo（例: `c3_statu` を `c3_status` の typo として書いた）は引き続き拒否される
- 厳しさは維持しつつ、annotation 文化を許容

## 変更ファイル

| ファイル | 種別 |
|---------|------|
| `schemas/c3-approval.schema.json` | 編集（`patternProperties` 追加）|
| `schemas/c4-approval.schema.json` | 編集（同等の予防修正）|
| `docs/working/TASK-0053/*` | 新規 |

## Mode判定

light（schema 2 ファイル + 既存ファイル無変更、後方互換維持、リスク極低）

## Risks & Mitigations

| Risk | Mitigation |
|------|----------|
| `_*` プレフィクスの誤用（typo を許容してしまう）| `^_` で頭文字限定、既存 annotation 文化に沿うパターンのみ許容 |
| 他 schema との不整合 | c3 / c4 のみ修正、他 schema は影響受けず |

## 確認方法

- 全 6 PBI で `bin/plangate validate-schemas TASK-XXXX` が PASS
- 全 6 PBI で `bin/plangate eval TASK-XXXX --no-write` が `Release Blocker 違反: なし（PASS）`
- `sh tests/run-tests.sh` → 21 PASS
