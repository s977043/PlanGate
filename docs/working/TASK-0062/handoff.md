# Handoff: TASK-0062 (PBI-HI-001 / Issue #195 / Metrics v1)

## 1. 要件適合確認結果

| AC | 検証 | 判定 |
|----|------|------|
| AC-01 plangate-event.schema.json 存在 | `schemas/plangate-event.schema.json` (110+ 行、11 events) | ✅ PASS |
| AC-02 events.ndjson に append-only 記録 | TASK-0059 で 0 → 4 行に増加（`docs/working/_metrics/events.ndjson`）| ✅ PASS |
| AC-03 `bin/plangate metrics <TASK>` で summary 出力 | `--report` で TASK-0059 summary 表示確認 | ✅ PASS |
| AC-04 hook violation / C-3 / V-1 / C-4 最低集計 | reporter 出力に C-3 dict / V-1 dict / C-4 dict / hook_violations 含む | ✅ PASS |
| AC-05 既存 workflow 不影響（opt-in） | tests/run-tests.sh 32/32 PASS、CLI 既存サブコマンド全動作 | ✅ PASS |
| AC-06 docs/ai/metrics.md 運用手順 | 9 章構成、CLI 使用例 / privacy / schema 検証 / baseline 比較 | ✅ PASS |
| AC-07 PBI-HI-000 baseline と比較可能 | metrics.md §6 で `2026-05-04-baseline.json` とのフィールドマッピング提供 | ✅ PASS |

**全 7/7 PASS**

### 追加検証
- **TC-A schema validation**: jsonschema で全 event 検証 → ta-09 で確認
- **TC-B privacy**: collector が emit するフィールドは §3 Allowed のみ。file path / stack trace / prompt は schema 上に定義しないため emit 不能
- **TC-C gitignore**: `docs/working/_metrics/events.ndjson` が git check-ignore で除外確認

## 2. 既知課題

- **hook 自動 emit は scope 外**: 現状は手動で append（doc に記載済）。v8.7+ で hook 側を改修する候補
- **pr_created / c4_decided は collector 未実装**: TASK ディレクトリだけでは推測困難、GitHub API 連携が必要 → v2 候補
- **fix_loop_count の自動カウント未実装**: 現状は手動 append のみ → v2 候補

## 3. V2 候補

- Hook 側からの自動 emit (#195 完了後の v8.7+)
- GitHub API 経由で pr_created / c4_decided を取得
- ダッシュボード UI（明示的 Non-goal）
- LLM judge による満足度判定
- Keep Rate (#198) / Dynamic Context (#199) との接続
- 外部 DB 連携（明示的 Non-goal）

## 4. 妥協点

- **Collector が emit する events は 6 種類**: 11 events 中 task_initialized / plan_generated / c3_decided / exec_started / v1_completed / handoff_completed / external_review_completed の 7 events を自動導出（pr_created / c4_decided / hook_violation / fix_loop_incremented は手動 append または v2）
  - 理由: TASK ディレクトリ内の artifact から決定論的に推測できる範囲を優先。Issue #195 の AC-04「最低限集計」は満たしつつ、過剰実装を避けた
- **AC count は handoff.md の絵文字マーカー (✅/❌/⚠️) ベース**: 絵文字テンプレートに依存するが、handoff template が確定しているため安定
- **schema validation は ta-09 内**: CI 統合は run-tests.sh 経由で実施

## 5. 引き継ぎ文書

新規ファイル 7 件 + 修正 2 件:

**新規:**
- `schemas/plangate-event.schema.json` — JSON Schema（11 events、conditional required）
- `scripts/metrics_collector.py` — TASK → NDJSON 抽出
- `scripts/metrics_reporter.py` — NDJSON → summary
- `docs/ai/metrics.md` — 運用 guide
- `tests/extras/ta-09-metrics.sh` — 8 test cases
- `docs/working/_metrics/.gitkeep` — placeholder
- `docs/working/TASK-0062/` — PBI artifacts (4 files)

**修正:**
- `bin/plangate` — `cmd_metrics` 関数追加 + dispatcher + help text
- `.gitignore` — `docs/working/_metrics/events.ndjson` 除外

PBI-HI-001 完了により、v8.6.0 milestone の P0 4 件全て完走（#194, #201, #202, #195）。後続 EPIC #193 改善で本 metrics を実利用シグナルとして活用。

## 6. テスト結果サマリ

- L-0 markdown lint: CI で確認
- V-1 受入基準照合: 7/7 PASS（TC-A/B/C 補助検証含めて 10/10 PASS）
- 自動テスト: `sh tests/run-tests.sh` → 32/32 PASS（ta-09 で 8 cases 含む）
- 手動動作確認:
  - `bin/plangate metrics TASK-0059 --collect` → 4 events emit
  - `bin/plangate metrics TASK-0059 --report` → summary 表示
  - `bin/plangate metrics --report --aggregate` → 集約表示
  - `bin/plangate metrics --report --json` → JSON 出力
  - `git check-ignore docs/working/_metrics/events.ndjson` → ignored
- 影響範囲: opt-in CLI 拡張のみ、既存 workflow / tests 影響なし
