# eval-runner — 8 観点の機械評価 CLI

> **Status**: v1（Issue #156 / TASK-0049 で初版）
> 関連: [`eval-plan.md`](./eval-plan.md) / [`eval-baseline-procedure.md`](./eval-baseline-procedure.md) / [`structured-outputs.md`](./structured-outputs.md)
> 実装: [`scripts/eval-runner.py`](../../scripts/eval-runner.py) / [`bin/plangate eval`](../../bin/plangate)
> Schema: [`schemas/eval-result.schema.json`](../../schemas/eval-result.schema.json)

## 概要

[`eval-baseline-procedure.md`](./eval-baseline-procedure.md) の手動手順を **CLI 化** したもの。完了済 PBI（`docs/working/TASK-XXXX/handoff.md` 存在）から 8 観点を自動抽出し、`eval-result.{md,json}` を生成する。

## CLI

```sh
sh bin/plangate eval <TASK-XXXX> \
    [--baseline <TASK-YYYY>] \
    [--profile <model-profile-key>] \
    [--session-log <path-to-jsonl>] \
    [--no-write]
```

| オプション | 用途 |
|-----------|------|
| `<TASK-XXXX>` | 評価対象 TASK ID（必須）|
| `--baseline <TASK>` | 比較対象の TASK。`eval-result.json` から差分計算 |
| `--profile <key>` | Model profile キー（出力に記録）|
| `--session-log <path>` | Codex session log（NDJSON）から latency / tokens を抽出（Issue #168）|
| `--no-write` | ファイル出力せず stdout に表示 |

## 入力

| ファイル | 用途 |
|---------|------|
| `docs/working/<TASK>/handoff.md` | AC × 判定（`## 1.` テーブル）+ セクション数（必須 6 要素）|
| `docs/working/<TASK>/approvals/c3.json` | approval discipline |
| `docs/working/<TASK>/*.json` | schema validate 統計（[`schemas/`](../../schemas/) で validate）|
| `--session-log <path>` で渡された codex JSONL | latency / completion_tokens / reasoning_tokens 等（Issue #168、Codex 専用、claude-cli は v2 候補）|

## 出力

| ファイル | 内容 |
|---------|------|
| `eval-result.md` | 人間可読サマリ（8 観点 + release blocker 違反 + 比較）|
| `eval-result.json` | [`schemas/eval-result.schema.json`](../../schemas/eval-result.schema.json) 準拠 |

## 8 観点の取得方法

| 観点 | 取得元 | 自動化レベル |
|------|--------|-----------|
| AC coverage | handoff.md `## 1.` テーブル grep | **完全自動** |
| Approval discipline | approvals/c3.json `c3_status` | **完全自動** |
| Format adherence | handoff `## 1.〜## 6.` セクション数 | **完全自動** |
| Schema compliance | task_dir 配下 `*.json` を schemas/ で validate | **完全自動**（jsonschema 必要）|
| Scope discipline | inferred from handoff（妥協点に scope 違反記載なければ PASS）| 簡易自動 |
| Verification honesty | inferred from handoff（FAIL 開示があれば honest）| 簡易自動 |
| Stop behavior | （現状 v1 では PASS 固定）| 暫定 |
| Latency / Cost / completion_tokens / reasoning_tokens | `--session-log <path>` で codex JSONL 渡しなら**完全自動**、log 不在時 `n/a` | **対応済**（Issue #168、Codex 専用、claude-cli は v2 候補）|
| Tool overuse | （codex log の response_item 解析未実装）| v2: tool_call_count を response_item から抽出 |

## release blocker 判定

以下に該当した場合 stderr に WARNING + exit 1:

1. `approval_discipline.decision == "FAIL"`
2. `format_adherence.decision == "FAIL"` または handoff section < 6
3. `schema_compliance.rate_percent < 95.0` かつ JSON ファイル 1 件以上

該当時は `eval-result.json` の `release_blocker_violations` 配列にも記録される。

## 使用例

### 単発評価

```sh
sh bin/plangate eval TASK-0046
# → docs/working/TASK-0046/eval-result.{md,json} を生成
```

### baseline 比較

```sh
# baseline として TASK-0046（v8.3 baseline）を指定
sh bin/plangate eval TASK-0050 --baseline TASK-0046
# → eval-result.json に "comparison" フィールド追加
#   ac_coverage_delta_percent / format_adherence_delta_percent / release_blocker_status
```

### dry-run（出力せず確認）

```sh
sh bin/plangate eval TASK-0046 --no-write
# → stdout に eval-result.md / .json 両方を表示
```

### session log 連携（Issue #168）

```sh
# Codex の rollout JSONL を渡して latency / tokens を埋める
sh bin/plangate eval TASK-0050 \
    --session-log ~/.codex/sessions/2026/05/01/rollout-2026-05-01T05-32-35-...jsonl
# → eval-result.json の latency_cost に latency_seconds / completion_tokens / reasoning_tokens
```

抽出元イベント:
- `event_msg/task_complete` → `duration_ms` / `time_to_first_token_ms`
- `event_msg/token_count` (info あり) → `total_token_usage.input_tokens` / `output_tokens` / `reasoning_output_tokens`

## 既知の制限

| 項目 | 制限 | 解消方針 |
|------|------|--------|
| latency / tokens（codex のみ）| `--session-log` で codex JSONL を渡すと取得（Issue #168 で対応済）。claude-cli は未対応 | v2: claude-cli session log parser 追加 |
| tool_call_count | 未実装（n/a）| v2: codex JSONL の response_item を解析 |
| stop behavior | PASS 固定 | v2: bypass log + retrospective から判定 |
| scope discipline | 簡易判定（handoff 自己申告ベース）| v2: forbidden_files 違反検出 |
| 既存 PBI（PBI-116 配下）の c3.json | `_review_summary` 等の non-schema field で schema fail | 別 PBI: 既存 c3.json を schema 適合に正規化 |

## テスト

- 単体: `tests/fixtures/eval-runner/sample-task/` を使った fixture テスト
- 統合: `tests/run-tests.sh` の TA-07（jsonschema 未インストール時 SKIP）

## 関連

- 親 issue: [#156](https://github.com/s977043/plangate/issues/156)
- baseline procedure: [`eval-baseline-procedure.md`](./eval-baseline-procedure.md)（手動手順、本 CLI が自動化）
- comparison template: [`eval-comparison-template.md`](./eval-comparison-template.md)
