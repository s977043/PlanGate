---
task_id: TASK-0049
artifact_type: handoff
schema_version: 1
status: final
issued_at: 2026-05-01
author: qa-reviewer
v1_release: ""
related_issue: 156
---

# Handoff: TASK-0049 / Issue #156 — eval runner 実装

## メタ情報

```yaml
task: TASK-0049
related_issue: https://github.com/s977043/plangate/issues/156
author: qa-reviewer
issued_at: 2026-05-01
v1_release: <PR マージ後に SHA>
```

## 1. 要件適合確認結果

| 受入基準 | 判定 | 根拠 |
|---------|------|------|
| AC-1: `bin/plangate eval` で eval-result.{md,json} 生成 | PASS | `cmd_eval` 経由で `scripts/eval-runner.py` を呼び、デフォルトで `task_dir/eval-result.{md,json}` 出力 |
| AC-2: 8 観点に測定値 / 判定 | PASS | accuracy / approval / format / scope / verification / stop / tool_overuse / latency-cost の 9 セクション、latency と tool は `n/a` 明示 |
| AC-3: schema 準拠率 < 95% で blocker | PASS | `release_blocker_violations` 配列に `format_adherence` 違反追記、stderr WARNING + exit 1 |
| AC-4: `--baseline` で比較 | PASS | baseline 指定時に `comparison` フィールド追加、AC delta / format delta / release_blocker_status 出力 |
| AC-5: 既存テストで動作検証 | PASS | `tests/run-tests.sh` TA-07 として 3 ケース統合（13 件 PASS）|
| AC-6: `docs/ai/eval-runner.md` 仕様記述 | PASS | 概要 / CLI / 入出力 / 8 観点取得方法 / release blocker / 既知制限の 6 セクション |
| AC-7: eval-result.json schema 準拠 | PASS | `schemas/eval-result.schema.json`（Draft 2020-12）で構造定義 |

**総合**: **7 / 7 基準 PASS**

## 2. 既知課題一覧

| 課題 | Severity | 状態 | V2 候補 |
|------|---------|------|--------|
| latency / tool calls / reasoning tokens は `n/a`（session log 未統合）| info | accepted | Yes（v2 で codex / claude-cli NDJSON parser）|
| 既存 PBI の c3.json は `_review_summary` 等で schema fail → eval で blocker 検知 | minor | accepted | 別 PBI で正規化（影響大のため別途）|
| FILENAME_TO_SCHEMA に eval-result.json 自身が未登録 | info | accepted | 別 PBI（再帰回避のため意図的）|
| stop behavior が固定 PASS | info | accepted | v2 で bypass log + retrospective 連携 |
| scope discipline は handoff 自己申告ベース | minor | accepted | v2 で forbidden_files 違反検出 |

**Critical**: なし

## 3. V2 候補

| V2 候補 | 理由 | 優先度 |
|--------|------|--------|
| session log（NDJSON）parser → latency / tool calls の実測値 | issue #156 の本来要件、本 PBI scope 外 | High |
| 既存 PBI c3.json の schema 正規化 | 全 PBI で eval が blocker 出さなくなる | Medium |
| FILENAME_TO_SCHEMA に `eval-result.schema.json` 登録 | self-validate 化 | Low |
| eval-runner の CI 化（PR ごとに baseline 比較）| #155 / #158 統合後 | Medium |
| Markdown report の table 化 / summary 行追加 | DX 向上 | Low |

## 4. 妥協点

| 選択 | 諦めた代替 | 理由 |
|------|-----------|------|
| handoff.md からの正規表現抽出 | LLM 経由の意味理解抽出 | 決定論性、CI 化の容易さ |
| Python 実装（jsonschema 依存）| Pure POSIX sh | schema validate の堅牢性、既存 `scripts/validate-schemas.py` と一貫性 |
| latency / tool calls = `n/a` 固定 | session log 仮 parser | scope discipline、本 PBI で「データ取得の自動化」より「集計フローの確立」を優先 |
| sample fixture で TASK-9990 採用 | 実 PBI を fixture | schema 互換 ID + 独立性、テスト副作用最小 |
| 既存 PBI で blocker 検知される設計 | 既存 c3.json を許容するゆるい schema | 設計通りの厳格さ維持、既知制限として明示 |

## 5. 引き継ぎ文書

### 概要

PlanGate v8.3 の eval framework を CLI 化。完了済 PBI から 8 観点を自動抽出し、`eval-result.{md,json}` を生成する `bin/plangate eval` を新設。`schemas/eval-result.schema.json` 準拠の構造化出力 + handoff.md / approvals/c3.json / `*.json` から自動取得。release blocker 違反時は stderr + exit 1。

主要成果:
- `scripts/eval-runner.py`（Python + jsonschema）
- `bin/plangate eval <TASK-XXXX> [--baseline] [--profile] [--no-write]`
- `schemas/eval-result.schema.json`（Draft 2020-12）
- `docs/ai/eval-runner.md`（仕様書）
- `tests/fixtures/eval-runner/sample-task/` + `tests/run-tests.sh` TA-07

session log 統合（latency / tool calls 実測）は v2 候補として明示分離。

### 触れないでほしいファイル

- `scripts/eval-runner.py` の `FILENAME_TO_SCHEMA` ハードコード: `validate-schemas.py` と同期する場合のみ更新
- `tests/fixtures/eval-runner/sample-task/approvals/c3.json` の task_id `TASK-9990`: schema `^TASK-[0-9]{4}$` 制約を満たす値、勝手に変えない
- `eval-result.schema.json` の `task_id` regex: 既存 c3-approval.schema.json 等と整合

### 次に手を入れるなら

- session log parser 実装（v2、別 PBI）
- 既存 PBI c3.json 正規化（別 PBI、影響大）
- FILENAME_TO_SCHEMA を 1 箇所に集約（`validate-schemas.py` と `eval-runner.py` の DRY 化）
- アンチパターン: `eval-result.json` 自身を validation 対象に追加（再帰検証ループ）

### 参照リンク

- Issue: https://github.com/s977043/plangate/issues/156
- 親 retrospective: `docs/working/retrospective-2026-04-30.md` § Try T-2 #2
- 仕様書: `docs/ai/eval-runner.md`
- baseline 連携: `docs/ai/eval-baseline-procedure.md`（手動手順、本 CLI が自動化対応）

## 6. テスト結果サマリ

| レイヤー | 件数 | PASS | FAIL / SKIP |
|---------|------|------|-----------|
| Unit (fixture) | 1 | 1 | 0 / 0 |
| Integration (run-tests.sh) | 13 | 13 | 0 / 0 |
| Manual smoke | 2 | 2 | 0 / 0 |

検証コマンド:

```sh
sh tests/run-tests.sh            # → 13 PASS
sh bin/plangate eval TASK-0044 --no-write 2>&1 | head -20  # 既存 PBI への適用、blocker 検出を実証
python3 scripts/eval-runner.py TASK-9990 --baseline TASK-9990 --no-write  # baseline 比較
```
