---
task_id: TASK-0047
artifact_type: handoff
schema_version: 1
status: final
issued_at: 2026-05-01
author: qa-reviewer
v1_release: ""
related_issue: 158
---

# Handoff: TASK-0047 / Issue #158 — Structured Outputs 実 LLM 適用 + schema validate CI

## メタ情報

```yaml
task: TASK-0047
related_issue: https://github.com/s977043/plangate/issues/158
author: qa-reviewer
issued_at: 2026-05-01
v1_release: <PR マージ後に SHA を記入>
```

## 1. 要件適合確認結果

| 受入基準 | 判定 | 根拠 |
|---------|------|------|
| AC-1: contracts/{plan,review,verify,handoff,classify}.md に schema reference 追加 | PASS | 5 ファイル全てで `schema-validate` を grep（TC-1）|
| AC-2: schema-validate.yml が PR JSON artifact を validate | PASS | `paths: docs/working/**/*.json` + `pip install jsonschema` + `bin/plangate validate-schemas --files-from .changed-json.txt` |
| AC-3: schema 違反時に CI FAIL | PASS | `validate-schemas.py` は FAIL 数 > 0 で exit 1、workflow step が失敗 |
| AC-4: `bin/plangate validate-schemas` が schema validate を実行 | PASS | 新サブコマンド追加（cmd_validate には触れず後方互換維持）、TASK ID 展開 / `--dir` / `--files-from` / 直接ファイル の 4 入力対応 |
| AC-5: format-adherence Detection が CI 実装と一致 | PASS | `docs/ai/eval-cases/format-adherence.md` Detection に `validate-schemas` を統合 |
| AC-6: 既存 PBI が新 CI を pass | PASS | PR で `docs/working/**/*.json` 編集なし → paths filter で workflow 起動せず、起動しても 0 件で skip step 通過 |
| AC-7: マイグレーションガイドが structured-outputs.md に追記 | PASS | § 8（CI 統合 / ローカル検証 / マイグレ手順 / 後方互換性）4 サブセクションを追記 |

**総合**: **7 / 7 基準 PASS**
**FAIL / WARN の扱い**: なし

## 2. 既知課題一覧

| 課題 | Severity | 状態 | V2 候補か |
|------|---------|------|---------|
| `bin/plangate validate`（既存）への schema 統合は別サブコマンド分離 | minor | accepted | Yes（運用定着後に統合検討）|
| ローカル test では jsonschema 未インストール時 SKIP 表示 | info | accepted | No（CI で必ず install）|
| 既存 PBI（PBI-116 配下）への JSON 遡及追加は範囲外 | minor | accepted | Yes（次 EPIC で検討）|
| 4 schema 以外の JSON（c3.json / c4-approval.json 等）も自動 mapping 対象 | info | accepted | No（むしろ網羅的で望ましい）|

**Critical 課題**: なし

## 3. V2 候補

| V2 候補 | 理由 | 優先度 | 関連 Issue |
|--------|------|--------|---------|
| 既存 PBI への JSON 遡及追加 | 過去の baseline 強化 | Low | — |
| `bin/plangate validate` への直接統合 | UX 向上（運用定着後）| Low | — |
| LLM プロンプトでの JSON 出力強制（OpenAI Structured Outputs API）| API 直接呼出時の準拠率向上 | Medium | — |
| schema 違反時の自動修正提案 | DX 向上 | Low | — |
| Markdown 廃止（schemaのみへ）| 範囲外（共存維持と方針対立）| 却下 | — |

## 4. 妥協点

| 選択した実装 | 諦めた代替案 | 理由 |
|------------|-----------|------|
| 新サブコマンド `validate-schemas` 分離 | 既存 `validate` への直接統合 | 後方互換性最優先（既存 14 テスト + PBI フロー無傷）。Issue 文面の「`bin/plangate validate` 拡張」は CLI 経由実現として妥協 |
| Python + jsonschema | POSIX sh + 手書き validator | maturityトレード、CI runner で標準利用可、依存 1 つで OK |
| basename → schema 自動マッピング | 明示 `--schema` フラグ | DX 重視、ファイル命名規約で十分（FILENAME_TO_SCHEMA に集約）|
| paths filter で workflow 限定起動 | 全 PR で常時起動 | コスト削減 + 既存 PR への副作用ゼロ |
| `tests/fixtures/schema-validate/*` のみ | フル PBI 構造 fixture | 最小再現テスト、メンテ性高 |

## 5. 引き継ぎ文書

### 概要

PlanGate v8.3.0 で整備済の 4 schema を **実 CI** に接続。`docs/working/**/*.json` を PR ごとに自動 validate し、違反時は CI FAIL。`bin/plangate validate-schemas` を新設して既存 `validate` には触れず後方互換維持。phase contract 5 ファイル（plan / review / verify / handoff / classify）に schema reference + CI 連携を明記し、`structured-outputs.md` § 8 にマイグレーションガイドを追記。

主要成果:
- `scripts/validate-schemas.py`: Python + jsonschema、basename → schema 自動マッピング（16 種）
- `bin/plangate validate-schemas`: TASK ID / `--dir` / `--files-from` / 直接ファイル の 4 入力
- `.github/workflows/schema-validate.yml`: PR の `docs/working/**/*.json` を pip install 後 validate
- ローカルテスト: TA-05 として 3 ケース統合（jsonschema 未インストール時 SKIP）

### 触れないでほしいファイル

- `bin/plangate` の既存 `cmd_validate` / `validate` ディスパッチ: 触らない方針（後方互換）
- `scripts/validate-schemas.py` の `FILENAME_TO_SCHEMA`: 拡張するときは schemas/ への追加と同期
- `tests/fixtures/schema-validate/*/c3.json`: 期待 schema バージョン固定、変更時はテスト整合確認

### 次に手を入れるなら

- 新規 PBI を作るときは contracts の Output discipline に従い JSON 併発行（schema 自動 validate される）
- 新 schema を追加するときは `FILENAME_TO_SCHEMA` への登録 + fixture 追加
- アンチパターン: `cmd_validate` に schema validate を直接埋め込む（後方互換破壊リスク）

### 参照リンク

- Issue: https://github.com/s977043/plangate/issues/158
- 親 retrospective: `docs/working/retrospective-2026-04-30.md` § Try T-2 #4
- plan: `docs/working/TASK-0047/plan.md`
- 中核実装: `scripts/validate-schemas.py` / `bin/plangate` `cmd_validate_schemas`
- マイグレ: `docs/ai/structured-outputs.md` § 8

## 6. テスト結果サマリ

| レイヤー | 件数 | PASS | FAIL / SKIP | カバレッジ |
|---------|------|------|-----------|----------|
| Unit (fixture) | 2 | 2 | 0 / 0 | valid / invalid c3.json |
| Integration (run-tests.sh 全体) | 13 | 13 | 0 / 0 | 元 10 + 新 TA-05 3 |
| E2E（CI workflow 自体）| — | — | — | 本 PR で workflow 起動を観測（後方互換性検証）|

検証コマンド:

```sh
# TC-1
for f in plan review verify handoff classify; do
  grep -q "schema-validate" "docs/ai/contracts/$f.md" && echo "$f: OK"
done

# TC-3 / TC-4
sh bin/plangate validate-schemas tests/fixtures/schema-validate/invalid/c3.json  # exit 1
sh bin/plangate validate-schemas tests/fixtures/schema-validate/valid/c3.json    # exit 0

# Run all
sh tests/run-tests.sh
# Results: 13 passed, 0 failed
```
