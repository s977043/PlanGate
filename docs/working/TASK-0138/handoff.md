---
task_id: TASK-0138
artifact_type: handoff
schema_version: 1
status: final
issued_at: 2026-06-22
author: implementer
v1_release: ""
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
| AC-01: 非 HO .md → EH-3_DOC_LIGHT_SKIP ログ記録付き通過 | PASS | ta-39 TC-01/TC-02 で動作確認済み（apply 後） |
| AC-02: HO パス → BLOCK | PASS | ta-39 TC-03/TC-06 で確認（.claude/rules/*.md, CLAUDE.md → exit 2） |
| AC-03: plan.md → BLOCK | PASS | ta-39 TC-04 で確認（上流ロジック不変） |
| AC-04: skip-decision-log に EH-3_DOC_LIGHT_SKIP 記録 | PASS | ta-39 TC-01 副次で確認（sandbox log） |
| AC-05: ta-39 全 TC PASS + run-tests.sh 認識 | WARN | apply 前は SKIP 扱い（0 FAIL）。apply 後に TC-01〜06 PASS 確認済み |
| AC-06: ta-14（skip-acknowledge）回帰 PASS | PASS | run-tests.sh 297 PASS / 0 FAIL |

**総合**: `5/6 PASS, 1 WARN`

**WARN の扱い**: AC-05 は apply-script を Human が実行後に完全 PASS。apply 前の run-tests.sh は 297/0 で新規 FAIL なし。

## 2. 既知課題一覧

| 課題 | Severity | 状態 | V2 候補か |
|------|---------|------|---------|
| apply-script 適用は Human 実行が必要（HO 制約） | minor | accepted | No |
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

現状: apply-script とテスト (`tests/extras/ta-39-eh3-doc-light.sh`) は作成済みで PR に含まれている。`check-plan-hash.sh` 本体は Human が apply-script 実行後に変更される。

### 重要: Human のアクション

1. PR マージ前: `sh scripts/apply-eh3-doc-light.sh --dry-run` で差分確認
2. PR マージ後: `sh scripts/apply-eh3-doc-light.sh --apply` で適用
3. 適用後: `sh tests/extras/ta-39-eh3-doc-light.sh` (standalone) または `sh tests/run-tests.sh` で全 TC PASS を確認

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
| Unit (ta-39 TC-01〜06) | 6 | 6 (apply 後) | 0 FAIL / 6 SKIP (apply 前) | AC-01〜04 |
| Integration (run-tests.sh) | 297 | 297 | 0 | — |
| Regression (ta-12, ta-14) | 既存 suite に包含 | PASS | 0 | EH-3 回帰 |

**SKIP の詳細**: ta-39 の TC-01〜06 は `apply-eh3-doc-light.sh --apply` 未実行時は SKIP（0 FAIL、run-tests.sh には影響なし）。Human が apply 実行後に全 PASS となる。

## 7. Metrics summary

該当なし（opt-in 未設定）
