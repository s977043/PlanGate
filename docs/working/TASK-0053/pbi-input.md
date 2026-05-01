# PBI INPUT PACKAGE: TASK-0053 / Issue #167

> Source: [#167 既存 PBI c3.json schema 違反正規化](https://github.com/s977043/plangate/issues/167)
> Mode: **standard** → 実装で **light** に縮減（schema 緩和のみで完結）

## Context / Why

retrospective 2026-05-01 P-3 / Try T-1。#158（schema validate CI）/ #156（eval runner）を実装したところ、PBI-116 配下 6 件の `approvals/c3.json` が `c3-approval.schema.json` の `additionalProperties: false` 制約に違反していると判明（`_review_summary` `_schema_reference` `_note` 等の human-readable annotation が含まれる）。`bin/plangate eval` で format adherence の release blocker が量産されていた。

## What

### 採用方針: Option B（schema を緩める）

`additionalProperties: false` を維持しつつ、`patternProperties: { "^_": {} }` を追加して **アンダースコア接頭の key だけを許容**。既存ファイルは無変更で schema 適合化、人間可読の annotation を保持できる。

### In scope
- `schemas/c3-approval.schema.json` に `patternProperties` 追加
- `schemas/c4-approval.schema.json` に同等の修正（予防的、c4 ファイル不在でも将来対応）
- 既存 6 件の c3.json が schema validate PASS
- eval runner で blocker 0 確認

### Out of scope
- 他 schema（review-result / handoff-summary 等）の同等改修（必要時に別 PBI）
- Option A（既存ファイル正規化）はリジェクト（手間 + 履歴汚染）

## Acceptance Criteria

- AC-1: 既存 6 件の c3.json が `bin/plangate validate-schemas TASK-XXXX` で PASS
- AC-2: `bin/plangate eval TASK-XXXX` で format adherence の release blocker が 0
- AC-3: 既存 review_summary 情報が失われていない（schema 緩和のみで既存ファイル無変更）
- AC-4: schema 変更が `_*` 接頭以外の未知 key は引き続き拒否（厳しさ維持）
- AC-5: tests/run-tests.sh 21 件 PASS 維持
