# EXECUTION PLAN: TASK-0054 / Issue #168

> Mode: **high-risk → standard**（Codex log のみ scope 制限で軽量化）

## Goal

Codex CLI の rollout JSONL を解析する純関数 parser + eval-runner への optional 統合。`--session-log` 渡しで latency / completion_tokens / reasoning_tokens を実測値化する。log 不在時は従来通り n/a で後方互換維持。

## Approach

1. **Phase 1 調査済み**: codex JSONL の event 構造を実物から確認
   - `event_msg/task_complete`: `duration_ms`, `time_to_first_token_ms`
   - `event_msg/token_count`: `info.total_token_usage` に input/output/reasoning tokens
   - `response_item`: tool call は別フィールド、本 PBI scope 外

2. **Phase 2 実装**:
   - `scripts/parsers/codex_log_parser.py`: pure function `parse(path) -> dict`
   - `scripts/eval-runner.py` に `parse_session_log()` ヘルパ + `--session-log` CLI option
   - `latency_cost` セクションを実測値で埋める、`decision` を log 提供時 `PASS` に
   - `_render_latency_line()` ヘルパで Markdown summary を更新（latency=Xs, completion=Ntok 等）

3. **Phase 3 テスト**:
   - `tests/fixtures/codex-log/sample.jsonl`: 実 codex log を fixture 化（12 行、small）
   - `tests/extras/ta-08-codex-log-parser.sh`: parser 単体 2 件 + eval 統合 1 件 = 3 ケース
   - tests/run-tests.sh 24/24 PASS

4. **Phase 4 ドキュメント**:
   - eval-runner.md の「8 観点の取得方法」表を更新（n/a → 対応済）
   - 「使用例」に session log 連携セクション追加
   - 「既知の制限」を更新（claude-cli は v2 候補、tool_call_count は v2）

## 変更ファイル

| ファイル | 種別 |
|---------|------|
| `scripts/parsers/__init__.py` | 新規（空、package 化）|
| `scripts/parsers/codex_log_parser.py` | 新規 |
| `scripts/eval-runner.py` | 編集（version 1.1 → 1.2、`--session-log` + parse_session_log + latency_cost 拡張 + _render_latency_line）|
| `tests/fixtures/codex-log/sample.jsonl` | 新規（実 codex log のコピー）|
| `tests/extras/ta-08-codex-log-parser.sh` | 新規 |
| `docs/ai/eval-runner.md` | 編集（CLI / 入力 / 8 観点表 / 使用例 / 既知の制限）|
| `docs/working/TASK-0054/*` | 新規 |

## Mode判定

**standard**（当初 high-risk 想定だが、Codex log のみ + log 不在時の後方互換維持で実装範囲が縮減）

判定根拠:
- 変更ファイル数: 7 → standard
- 受入基準数: 6 → standard
- 変更種別: 新 parser + CLI option + doc → standard
- リスク: log 不在時の動作維持で副作用なし、新オプションは opt-in → 中
- ロールバック: 容易（PR revert）→ 中

## Risks & Mitigations

| Risk | Mitigation |
|------|----------|
| codex log spec が version で変わる | 取得不可フィールドは `None` を返す best-effort 設計 |
| set -e + command substitution + python の interaction で test が止まる | TA-08 を `&&/||` で exit code を明示捕捉、trap を使わずに rm 直接 |
| eval-runner v1.1 を仮定する既存呼び出し | `--session-log` は optional、未指定時は従来動作完全維持 |
| claude-cli log 統合の期待 | スコープ外、handoff の V2 候補に明示 |

## 確認方法

- `python3 scripts/parsers/codex_log_parser.py tests/fixtures/codex-log/sample.jsonl` → JSON dict 出力
- `sh bin/plangate eval TASK-9991 --session-log tests/fixtures/codex-log/sample.jsonl` → `Latency / Cost: **PASS** (latency=...)` 行
- `sh tests/run-tests.sh` → 24/24 PASS
