# Metrics v1 — Operational Guide

> **Status**: v1
> **Review cadence**: On change
> **Owner**: Engineering / Governance
> **Issue**: [#195 PBI-HI-001](https://github.com/s977043/plangate/issues/195)
> **Related**: [docs/ai/metrics-privacy.md](./metrics-privacy.md), [docs/ai/eval-baselines/2026-05-04-baseline.md](./eval-baselines/2026-05-04-baseline.md)

## 1. 目的

PlanGate workflow event を構造化 metrics として保存・集計可能にする。Hook violation / C-3 / V-1 / C-4 の最小集計から始め、後続の Eval expansion (#196) / Model Profile v2 (#197) / Keep Rate (#198) / Dynamic Context Engine (#199) の効果測定基盤として機能させる。

**opt-in**: 既存 workflow を壊さず、`bin/plangate metrics` を呼んだときのみ動く。

## 2. 構成

| ファイル | 役割 |
|---------|------|
| `schemas/plangate-event.schema.json` | event の JSON Schema |
| `scripts/metrics_collector.py` | TASK ディレクトリから event を導出して NDJSON へ append |
| `scripts/metrics_reporter.py` | events.ndjson から TASK 別 / aggregate summary を生成 |
| `bin/plangate metrics` | 上記のラッパ CLI |
| `docs/working/_metrics/events.ndjson` | append-only metrics log（**.gitignore 対象、commit 禁止**）|

## 3. 使い方

### 3.1 Collect（TASK の現在状態から event を導出）

```bash
bin/plangate metrics TASK-0061 --collect
```

実行内容: `docs/working/TASK-0061/` の以下ファイル群を読み、event を抽出して `docs/working/_metrics/events.ndjson` に append する。

| 対象ファイル / ソース | 導出 event |
|------------|----------|
| `pbi-input.md` | `task_initialized` |
| `plan.md` | `plan_generated` (plan_hash 含む、mode 自動検出) |
| `approvals/c3.json` | `c3_decided` (verdict: APPROVED/CONDITIONAL/REJECTED) |
| `evidence/` | `exec_started` (最初の evidence 作成時刻) |
| `handoff.md` | `v1_completed` (AC PASS/FAIL カウント) + `handoff_completed` |
| `review-external.md` | `external_review_completed` |
| `docs/working/_audit/hook-events.log` | `hook_violation` (v8.6.0 PR3、A-1: VIOLATION/WARNING を自動変換、PASS/BYPASS は emit せず、message column は privacy §4 のため emit せず)|
| `git log` on `handoff.md` | `pr_created` (v8.6.0 PR3、A-2: squash-merge subject 末尾の `(#NN)` から PR 番号抽出、`pr_number` のみ emit)|

**dry-run** で append 前に内容確認:

```bash
bin/plangate metrics TASK-0061 --collect --dry-run
```

### 3.2 Report（summary 表示）

```bash
# TASK 単位
bin/plangate metrics TASK-0061 --report

# 全 TASK 集約
bin/plangate metrics --report --aggregate

# JSON 出力（baseline 比較用）
bin/plangate metrics TASK-0061 --report --json
```

### 3.3 hook_violation の自動取得（v8.6.0 PR3 / A-1）

`bin/plangate metrics --collect` 実行時、`docs/working/_audit/hook-events.log` を自動的に読み込み、対象 TASK の **VIOLATION / WARNING** ログを `hook_violation` event に変換して emit する。

| audit log level | hook_result |
|----------------|-------------|
| `VIOLATION` / `BLOCK` | `block` |
| `WARNING` / `WARN` | `warn` |
| `PASS` / `BYPASS` | emit しない（success / bypass はノイズ） |

hook script 名は schema 準拠の hook_id に変換される（例: `check-c3-approval` → `EH-2`、`check-merge-approvals` → `EH-7`、`check-metrics-privacy` → `EH-8`）。**audit log の message 列は metrics-privacy.md §4 違反を避けるため emit しない**。

手動 append が必要な場合は schema 準拠 NDJSON を `>>` で追記可能：

```bash
echo '{"schema_version":"1.0","ts":"2026-05-04T07:00:00Z","task_id":"TASK-0061","event":"hook_violation","hook_id":"EH-1","hook_result":"block"}' \
  >> docs/working/_metrics/events.ndjson
```

### 3.4 pr_created の自動取得（v8.6.0 PR3 / A-2）

`handoff.md` をタッチした最新 git commit を対象に、subject 末尾の `(#NN)` パターン（squash-merge convention）から PR 番号を抽出し、`pr_created` event を emit する。`pr_number` のみ記録され、commit ハッシュ・ブランチ名・著者・本文は emit しない（privacy §4 準拠）。

git が無い / commit が見つからない場合は silent に skip。

### 3.5 mode 別集計（v8.6.0 PR6 / H-3）

`bin/plangate metrics --report --aggregate` または `--report --json` の出力に `By mode` セクション / `by_mode` フィールドが追加される。

- TASK ごとに plan_generated event の `mode` を解決して、各 mode の C-3 / V-1 / C-4 verdict と hook violation を別々に集計
- V-1 PASS rate (%) も自動計算
- harness 変更が mode 別にどう効いたかを比較可能（後続 PBI-HI-002 / #196 Eval expansion でフル活用予定）

出力例（aggregate text）：

```text
## By mode (H-3)
- **light**: V-1 12/14 PASS (85.71%) / C-3 APPROVED=10 / hook_violations=2
- **standard**: V-1 5/5 PASS (100.0%) / C-3 APPROVED=5 / hook_violations=0
```

### 3.6 整合性検証（v8.6.0 PR5 / H-1）

`bin/plangate metrics --validate` で `events.ndjson` 全行を `plangate-event.schema.json` で validate。違反は line:reason 形式で最大 20 件報告、exit 1。jsonschema 未導入時は SKIP（exit 0）。

## 4. Privacy

[`metrics-privacy.md`](./metrics-privacy.md) 準拠。`metrics_collector.py` は §3 (Allowed) のフィールドのみ emit する。

| 保存される | 例 |
|-----------|-----|
| event 種別、phase、mode | `task_initialized`, `B`, `light` |
| TASK ID | `TASK-0061` |
| plan_hash | `sha256:...` (内容そのものは保存しない) |
| AC count | `ac_total: 6, ac_pass: 6, ac_fail: 0` |
| verdict | `APPROVED`, `PASS`, `FAIL`, `WARN` |
| timestamp | UTC ISO 8601 |

| 保存されない | 理由 |
|-------------|-----|
| ファイルパス、ファイル名 | privacy §4 Forbidden |
| stack trace、command output | 同上 |
| user prompt、handoff 本文 | 同上 |
| provider raw response | 同上 |

`docs/working/_metrics/events.ndjson` は **.gitignore で除外**。commit されない。

## 5. Schema 検証

```bash
python3 -c "import json,jsonschema,sys; \
  schema=json.load(open('schemas/plangate-event.schema.json')); \
  events=[json.loads(l) for l in open('docs/working/_metrics/events.ndjson') if l.strip()]; \
  [jsonschema.validate(e,schema) for e in events]; \
  print(f'{len(events)} events valid')"
```

## 6. Baseline 比較

[`docs/ai/eval-baselines/2026-05-04-baseline.json`](./eval-baselines/2026-05-04-baseline.json) と互換のフィールド命名:

| baseline.json | metrics summary |
|--------------|-----------------|
| `tasks[].ac_coverage_pct` | `summary.v1` から算出 (PASS/FAIL/WARN ratio) |
| `tasks[].approval_discipline` | `summary.c3` の APPROVED 有無 |
| `aggregate.release_blocker_total` | hook_violations.total + c3 REJECTED + v1 FAIL |

baseline と metrics summary を組み合わせると、改善前後の差分が機械比較可能。

## 7. Non-goals (Metrics v1)

- ダッシュボード UI（v2+ 候補）
- LLM judge による満足度判定
- Keep Rate 算出（PBI-HI-004 / #198）
- Dynamic Context Engine（PBI-HI-005 / #199）
- 外部 DB（DataDog 等）への保存
- Hook 側からの自動 emit（v8.7+ 候補、scope 外）
- 暗号化ストレージ

## 8. 後続改善の接続点

| Roadmap | metrics v1 への接続 |
|--------|-------------------|
| **#196 Eval expansion** | `summary.v1` / `summary.hook_violations` を mode 別に判定 |
| **#197 Model Profile v2** | event に `model_profile` 追加で profile 別比較 |
| **#198 Keep Rate v1** | `plan_hash` 履歴と handoff 後の差分で算出 |
| **#199 Dynamic Context** | `task_initialized` 時に context manifest 識別子を記録 |

## 9. 関連

- [Issue #195 PBI-HI-001 Metrics v1](https://github.com/s977043/plangate/issues/195)
- [docs/ai/metrics-privacy.md](./metrics-privacy.md) — §3 Allowed / §4 Forbidden / privacy 強制 3 層
- [docs/ai/eval-baselines/2026-05-04-baseline.md](./eval-baselines/2026-05-04-baseline.md) — 比較起点 baseline
- [docs/ai/harness-improvement-roadmap.md](./harness-improvement-roadmap.md) — Phase 1 (#195) を含むロードマップ
- [docs/ai/issue-governance.md](./issue-governance.md) — Issue / Label / Milestone Governance（v8.6.0 governance trio の一角）
- [schemas/plangate-event.schema.json](../../schemas/plangate-event.schema.json)
- [scripts/hooks/check-metrics-privacy.sh](../../scripts/hooks/check-metrics-privacy.sh) — EH-8 privacy 強制 hook
- [examples/sample-task/metrics-events.ndjson](../../examples/sample-task/metrics-events.ndjson) / [metrics-summary.md](../../examples/sample-task/metrics-summary.md) — 利用例
