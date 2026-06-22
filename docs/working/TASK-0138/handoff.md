---
task_id: TASK-0138
artifact_type: handoff
schema_version: 1
status: final
issued_at: 2026-06-22
author: implementer
v1_release: "feat/task-0138-528-eh3-doc-light (a87cca7)"
---

# Handoff Package — TASK-0138 (#528)

## メタ情報

```yaml
task: TASK-0138
related_issue: https://github.com/s977043/plangate/issues/528
author: implementer
issued_at: 2026-06-22
v1_release: (PR merge SHA)
```

## 1. 要件適合確認結果

| 受入基準 | 判定 | 根拠 / コメント |
|---------|------|---------------|
| AC-01: 非 HO .md → EH-3_DOC_LIGHT_SKIP ログ記録付き通過 | PASS | ta-39 TC-01/TC-02 PASS |
| AC-02: HO パス → BLOCK | PASS | ta-39 TC-03/TC-06 PASS（.claude/rules/*.md, CLAUDE.md → exit 2） |
| AC-03: plan.md → BLOCK | PASS | ta-39 TC-04 PASS（上流ロジック不変） |
| AC-04: skip-decision-log に EH-3_DOC_LIGHT_SKIP 記録 | PASS | ta-39 TC-01 副次 PASS（sandbox log） |
| AC-05: ta-39 全 TC PASS + run-tests.sh 認識 | PASS | run-tests.sh 300 PASS / 0 FAIL、TA-39 7 TC 全 PASS |
| AC-06: ta-12（maintenance + EH-3 v2）回帰 PASS | PASS | maintenance guard 修正（a87cca7）後 300/0 PASS |

**総合**: `6/6 PASS`

## 2. 既知課題一覧

| 課題 | Severity | 状態 | V2 候補か |
|------|---------|------|---------|
| apply-script 適用は Human 実行が必要（HO 制約） | minor | resolved（実行済み） | No |
| maintenance guard 追加が必要だったことが apply 後テストで判明（TA-12 7件 FAIL） | minor | resolved（a87cca7 fix-eh3-doc-light-maint-guard.sh で修正） | No |
| ta-39 TC-01 副次は sandbox log を確認するため実 audit log 汚染なし（意図通り） | info | accepted | No |

## 3. V2 候補

| V2 候補 | 理由 | 推定優先度 | 関連 Issue |
|--------|------|----------|-----------|
| ta-14（ta-12: maintenance + EH-3 v2）の ta-39 内での回帰テスト統合 | 現在は run-tests.sh 全体で担保、ta-39 内には含まない | Low | — |
| TASK 文脈あり（task_id 非空）の .md ファイルの doc-light 適用 | 現在は task_id 空のみが対象 | Low | #528 follow-up |

## 4. 妥協点

| 選択した実装 | 諦めた代替案 | 理由 |
|------------|-----------|------|
| apply-script 経由の Human 適用 | AI が直接 check-plan-hash.sh を編集 | HO 制約（scripts/hooks/*.sh は AI 編集不可） |
| ta-39 は apply 前 SKIP / apply 後 PASS の二相設計 | apply 前 FAIL にして強制 | 未適用状態でも suite 全体を壊さない設計が優先 |
| sed 経由の拡張子判定 (`sed 's/.*\.//'`) | bash parameter expansion | sh POSIX 互換性（bash 非依存） |

## 5. 引き継ぎ文書

### 概要

TASK-0138 は EH-3 hook (`scripts/hooks/check-plan-hash.sh`) に doc-light 経路を追加する PBI。
対象ファイルが HO（Hardening Override）パスのため、AI は `scripts/apply-eh3-doc-light.sh`（apply-script）を生成し、Human が `sh scripts/apply-eh3-doc-light.sh --apply` で適用する設計。

現状: `check-plan-hash.sh` へのパッチ適用済み（Human が `apply-eh3-doc-light.sh --apply` を実行）。
その後 TA-12 FAIL が判明したため `fix-eh3-doc-light-maint-guard.sh --apply` を追加実行して修正。
全 3 コミット（8485765, 14320d3, a87cca7）が `feat/task-0138-528-eh3-doc-light` ブランチに含まれる。

### Human のアクション（完了済み）

1. ~~`sh scripts/apply-eh3-doc-light.sh --apply` — 実行済み~~
2. ~~`sh scripts/fix-eh3-doc-light-maint-guard.sh --apply` — 実行済み~~
3. `sh tests/run-tests.sh` — 300 PASS / 0 FAIL 確認済み

### 触れないでほしいファイル

- `scripts/hooks/check-plan-hash.sh`: HO 対象。apply-script 経由のみ変更
- `scripts/apply-eh3-doc-light.sh`: 内容を変更すると Human 適用時に壊れる可能性

### 次に手を入れるなら

- apply 後の ta-39 は `前提確認: doc-light 経路が check-plan-hash.sh に存在` が PASS になる
- ta-39 の TC-01 副次はサンドボックス log（_T39_TMP）を確認するため実 audit log を汚染しない
- `skip-decision-log.jsonl` の `EH-3_DOC_LIGHT_SKIP` エントリは `acknowledged_by: null` のまま（AC に合致）

### 参照リンク

- 関連 Issue: https://github.com/s977043/plangate/issues/528
- pbi-input.md: `docs/working/TASK-0138/pbi-input.md`
- plan.md: `docs/working/TASK-0138/plan.md`
- test-cases.md: `docs/working/TASK-0138/test-cases.md`

## 6. テスト結果サマリ

| レイヤー | 件数 | PASS | FAIL / SKIP | カバレッジ |
|---------|------|------|-----------|----------|
| Unit (ta-39 TC-01〜06) | 7 | 7 | 0 FAIL | AC-01〜04 |
| Integration (run-tests.sh) | 300 | 300 | 0 | — |
| Regression (ta-12 maintenance, ta-14 skip-acknowledge) | 既存 suite に包含 | PASS | 0 | EH-3 回帰 |

**ブランチのコミット構成**:
- `8485765`: apply-script + ta-39 テスト（HO ファイル以外）
- `14320d3`: check-plan-hash.sh パッチ適用（Human 実行）
- `a87cca7`: maintenance guard 追加 + TA-12 TC-10 修正（regression fix）

## 7. Metrics summary

該当なし（opt-in 未設定）
