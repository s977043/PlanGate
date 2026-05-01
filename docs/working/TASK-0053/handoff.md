---
task_id: TASK-0053
artifact_type: handoff
schema_version: 1
status: final
issued_at: 2026-05-01
author: qa-reviewer
v1_release: ""
related_issue: 167
---

# Handoff: TASK-0053 / Issue #167 — c3.json schema 違反正規化（Option B）

## 1. 要件適合確認結果

| AC | 判定 | 根拠 |
|----|------|------|
| AC-1: 6 PBI で validate-schemas PASS | PASS | TASK-0039〜0044 全件 PASS（直接 `python3 -c` で確認、その後 `sh tests/run-tests.sh` 21 件 PASS）|
| AC-2: eval で blocker 0 | PASS | 全 6 PBI で `Release Blocker 違反: なし（PASS）` |
| AC-3: 既存 c3.json 無変更 | PASS | `git status` でも `docs/working/` に変更なし、schema 緩和のみで対応 |
| AC-4: typo 拒否維持 | PASS | `^_` 接頭以外の未知 key は依然 `additionalProperties: false` で拒否 |
| AC-5: tests 21 PASS | PASS | `Results: 21 passed, 0 failed` |

**総合**: **5 / 5 PASS**

## 2. 既知課題一覧

| 課題 | Severity | 状態 |
|------|---------|------|
| `^_` 接頭の慣例が schema-wide には未統一 | info | accepted（c3/c4 のみ修正、必要時に他 schema も追加）|
| review-result.schema.json 等での同需要は未着手 | info | accepted（V2 候補）|

## 3. V2 候補

| V2 候補 | 理由 | 優先度 |
|--------|------|--------|
| 全 schema に `^_` patternProperties 統一 | annotation 文化の標準化 | Low |
| `_review_summary` を正式 property として schema 化 | 構造化 + 可読性向上 | Low |

## 4. 妥協点

| 選択 | 諦めた代替 | 理由 |
|------|-----------|------|
| Option B（schema 緩和）| Option A（既存 c3.json 正規化）| 履歴汚染ゼロ、変更ファイル 2 件で完結、原則 backward-compatible |
| `^_` プレフィクス限定 | 任意 additional property 許容 | typo 検出の厳しさ維持 |
| c4-approval も予防修正 | c3 のみ修正 | 将来 c4-approval.json が運用始まったときに同問題を出さない |

## 5. 引き継ぎ文書

### 概要

`bin/plangate eval` が PBI-116 配下 6 件で format adherence の release blocker を量産していた問題（retrospective 2026-05-01 P-3）を schema 緩和で解消。`patternProperties: { "^_": {} }` を c3 / c4 schema に追加し、`_review_summary` 等の human-readable annotation を許容。既存 c3.json を一切変更せず、変更ファイル 2 件で完結。

### 触れないでほしいファイル

- `schemas/c3-approval.schema.json` の `patternProperties.^_`: 緩和の核
- 既存 `docs/working/TASK-0039〜0044/approvals/c3.json`: schema 緩和で適合化済、再正規化不要

### 次に手を入れるなら

- 新 schema 作成時は `_*` 慣例を念頭に `patternProperties` を初期から追加するか検討
- アンチパターン: `additionalProperties: true` で全許容（typo 検出が効かなくなる）

## 6. テスト結果サマリ

| レイヤー | 件数 | PASS | FAIL / SKIP |
|---------|------|------|-----------|
| 既存 PBI 突合 | 6 | 6 | 0 / 0 |
| eval blocker 検査 | 6 | 6 | 0 / 0 |
| Integration（tests/run-tests.sh）| 21 | 21 | 0 / 0 |

検証コマンド:
```sh
sh tests/run-tests.sh                                                   # 21 PASS
for t in TASK-0039 TASK-0040 TASK-0041 TASK-0042 TASK-0043 TASK-0044; do
  python3 scripts/eval-runner.py $t --no-write | grep "Release Blocker"
done                                                                     # 全件 "なし（PASS）"
```
