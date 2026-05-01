# EXECUTION PLAN: TASK-0049 / Issue #156

> Mode: **high-risk**

## Goal

PlanGate eval framework の手動手順（[`eval-baseline-procedure.md`](../../ai/eval-baseline-procedure.md)）を CLI 化し、完了済 PBI から 8 観点を自動抽出して `eval-result.{md,json}` を生成する。

## Constraints / Non-goals

- session log parser は **v2 候補**（本 PBI 範囲外）。latency / tool calls は `n/a` 明示
- 既存 PBI の c3.json schema 不適合（`_review_summary` 等）の正規化は別 PBI
- `bin/plangate eval` の戻り値は release blocker 違反時に exit 1 する設計（CI 統合余地確保）

## Approach Overview

### 1. Python 実装 `scripts/eval-runner.py`

- `argparse` で `<TASK> --baseline --profile --no-write`
- handoff.md から AC テーブルを正規表現抽出（`^\|\s*AC[-_ ]?\d+...\|\s*(PASS|FAIL|WARN)\s*\|`）
- `## 1.` 〜 `## 6.` の section 数 grep
- approvals/c3.json から `c3_status` 抽出
- task_dir 配下 `*.json` を `FILENAME_TO_SCHEMA` で自動検出 + jsonschema validate
- release blocker 違反検出 → stderr WARNING + exit 1
- baseline 指定時は baseline TASK の eval-result.json または新規評価して差分計算

### 2. CLI wrapper `bin/plangate eval`

- 既存 `cmd_validate` パターンに合わせ POSIX sh wrapper
- python3 への引数透過

### 3. Schema `schemas/eval-result.schema.json`

- Draft 2020-12、`$id` は plangate 既存と整合
- 8 観点 + release_blocker_violations + comparison（optional）

### 4. テスト

- `tests/fixtures/eval-runner/sample-task/`: schema 適合 c3.json（task_id: TASK-9990）+ 完備 handoff
- `tests/run-tests.sh` TA-07: 3 ケース
  1. sample task → exit 0（blocker なし）
  2. stdout に "AC coverage" 含む
  3. usage text

### 5. ドキュメント

- `docs/ai/eval-runner.md`: 概要 / CLI / 入出力 / 8 観点取得方法 / release blocker / 既知制限

## Work Breakdown

| Step | Output | 🚩 |
|------|--------|----|
| 1 | schemas/eval-result.schema.json | structure 確定 |
| 2 | scripts/eval-runner.py | sample task で動作確認 |
| 3 | bin/plangate eval wrapper | help / dispatch 動作確認 |
| 4 | tests/fixtures/eval-runner/ + TA-07 | 13 件 PASS |
| 5 | docs/ai/eval-runner.md | CLI 仕様明記 |
| 6 | TASK-0049/handoff.md | Rule 5 必須 |

## Files / Components to Touch

| ファイル | 種別 |
|---------|------|
| `schemas/eval-result.schema.json` | 新規 |
| `scripts/eval-runner.py` | 新規 |
| `bin/plangate` | 編集（cmd_eval + dispatch + help）|
| `tests/fixtures/eval-runner/sample-task/{handoff.md, approvals/c3.json}` | 新規 |
| `tests/run-tests.sh` | 編集（TA-07 追加）|
| `docs/ai/eval-runner.md` | 新規 |
| `docs/working/TASK-0049/*` | 新規 |

## Testing Strategy

- Unit: sample fixture で full lifecycle（read → eval → write）
- Integration: `tests/run-tests.sh` TA-07 で 3 ケース
- E2E（manual）: 本 session で TASK-0044 等への適用を確認、release blocker 検知を実証

## Risks & Mitigations

| Risk | Mitigation |
|------|----------|
| 既存 PBI の c3.json が schema 違反で全件 blocker 化 | 既知制限として `eval-runner.md` に明記、修正は別 PBI |
| jsonschema 未インストール時に動作しない | TA-07 を python3 jsonschema 検出で SKIP、CI は workflow で install |
| AC テーブル正規表現が PR 文書のばらつきで誤検出 | 厳密パターン採用 + TASK-0044 等で動作実績確認済 |
| eval-result.json 自身を再評価で循環 | rglob 走査時に `eval-result.json` を除外 |
| latency / tool calls の `n/a` が baseline と紛らわしい | comparison では数値同士のみ delta 計算、`n/a` は表示のみ |

## Mode判定

**モード**: high-risk

**判定根拠**:
- 変更ファイル数: 7 → high-risk
- 受入基準数: 7 → high-risk
- 変更種別: CLI 新設 + schema 新規 + Python 実装 → high-risk
- リスク: 既存 PBI の評価で blocker 大量検出（既知制限）→ 中
- ロールバック: 容易（PR revert）→ 中
- **最終判定**: high-risk

## 確認方法

- `sh tests/run-tests.sh` → 13 件 PASS
- `sh bin/plangate eval TASK-0044 --no-write` で実 PBI 評価が動く（schema fail 警告付き、設計通り）
- `python3 scripts/eval-runner.py TASK-0046 --baseline TASK-0046 --no-write` で comparison 出力（n=0 で variance なし）
