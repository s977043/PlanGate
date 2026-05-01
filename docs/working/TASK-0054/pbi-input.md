# PBI INPUT PACKAGE: TASK-0054 / Issue #168

> Source: [#168 eval runner の session log NDJSON parser 統合](https://github.com/s977043/plangate/issues/168)
> Mode: **high-risk** → 実装で **standard** に縮減（Codex log のみ scope 制限）

## Context / Why

`bin/plangate eval`（#156 / TASK-0049）で 8 観点のうち latency / tool calls / reasoning_tokens は session log 未統合のため `n/a`。本 PBI で **codex CLI の rollout JSONL** を解析する parser を統合し、latency / tokens を実測値で埋める。retrospective 2026-05-01 Try T-2 #2。

## What

### In scope
- `scripts/parsers/codex_log_parser.py`: NDJSON 解析、metrics dict を返す純関数
- `scripts/eval-runner.py` に `--session-log <path>` オプション追加、log 提供時 latency_cost を実測値で埋める
- log 不在時は従来通り `n/a` 動作（後方互換）
- `tests/fixtures/codex-log/sample.jsonl`: 実 rollout-*.jsonl から取得した最小 fixture
- `tests/extras/ta-08-codex-log-parser.sh`: 3 ケース統合
- `docs/ai/eval-runner.md`: session log 連携を「既知の制限」から「対応済」へ移行

### Out of scope（v2 候補）
- claude-cli session log parser（`~/.claude/sessions/*.json` は対話履歴を含まない、別場所要調査）
- tool_call_count の抽出（codex JSONL の response_item を解析）
- session log 自動検出（cwd → 最新 rollout-*.jsonl 推測）

## Acceptance Criteria

- AC-1: `python3 scripts/parsers/codex_log_parser.py <path>` が JSON dict（latency_seconds 含む）を返す
- AC-2: `bin/plangate eval TASK-XXXX --session-log <path>` が latency_cost.decision = PASS、latency_seconds 数値で出力
- AC-3: log 不在時の従来 `n/a` 動作を維持（21/21 PASS が崩れない）
- AC-4: tests/run-tests.sh が **24 件 PASS**（既存 21 + TA-08 3 件）
- AC-5: docs/ai/eval-runner.md に `--session-log` 仕様 + 抽出元イベントが記述
- AC-6: 既存 c3.json schema 違反問題（#167）の解消後も新規導入されない（schema validate 24/24 PASS の前提）
