# PBI INPUT PACKAGE: TASK-0049 / Issue #156

> Source: [#156 [EPIC] eval runner 実装 — reasoning token / latency / tool call 自動集計](https://github.com/s977043/plangate/issues/156)
> Mode: **high-risk**

## Context / Why

v8.3.0 で 8 観点の eval framework（[`eval-plan.md`](../../ai/eval-plan.md) + [`eval-cases/`](../../ai/eval-cases/) × 8）を整備したが、**現状は手動測定前提**。session log からの reasoning_token / latency / tool call 集計、schema 準拠率チェックを自動化することで、Model Profile 変更 / プロンプト変更時の回帰検出をスケーラブルにする。

## What

### In scope

- `scripts/eval-runner.py`: Python implementation、handoff.md / approvals/c3.json / `*.json` から 8 観点抽出
- `bin/plangate eval <TASK-XXXX> [--baseline <TASK-YYYY>] [--profile <key>] [--no-write]`: CLI wrapper
- `schemas/eval-result.schema.json`: 出力 JSON の schema
- `docs/ai/eval-runner.md`: CLI 仕様 + 取得方法 + 制限事項
- `tests/fixtures/eval-runner/sample-task/`: 独立 fixture（schema 適合の c3.json + 6 要素 handoff）
- `tests/run-tests.sh` TA-07: 統合テスト（3 ケース）

### Out of scope

- session log（codex / claude-cli NDJSON）の自動 parser → v2（latency / tool call の正確な実測）
- 全 mode / provider の網羅 → v2
- 既存 PBI（PBI-116 配下）の `_review_summary` 等 non-schema field の正規化 → 別 PBI

## Acceptance Criteria

- AC-1: `bin/plangate eval TASK-XXXX` が正常終了し eval-result.{md,json} を生成
- AC-2: 8 観点すべてに測定値 / 判定が含まれる（latency / tool calls は `n/a` を明示）
- AC-3: schema 準拠率 < 95% で release blocker 警告（stderr + exit 1）
- AC-4: `--baseline` 指定で比較表形式の差分を出力
- AC-5: 既存テスト × 1 件以上で eval runner の振る舞いを検証（TA-07: 3 ケース）
- AC-6: `docs/ai/eval-runner.md` に CLI 仕様 + 実装方針が記述されている
- AC-7: schema 化された eval-result.json は `schemas/eval-result.schema.json` で validate 可能

## Notes

- 推奨 mode: **high-risk**
- 依存: #155 完了済（baseline 値が動作確認の正解として機能）
- 関連: `tests/run-tests.sh`、`bin/plangate validate-schemas`（#158）
- session log 自動取得は v2、本 PBI は **既存 artifact ベースの自動化** に集中
