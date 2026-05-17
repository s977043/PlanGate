# テストケース — TASK-0101 / #277
| ID | AC | 期待 | 種別 |
|----|----|------|------|
| T1 | AC1 | _paths.py に REPO_ROOT/SCRIPTS_DIR/WORKING_DIR/SCHEMAS_DIR 固定定数 | import 検証 |
| T2 | AC2 | 11 script が from _paths import・ローカル `=Path(__file__)` path 定義除去 | 構造突合 |
| T3 | AC3 | sh tests/run-tests.sh 全 PASS（回帰なし）| テスト実行 |
| T4 | AC4 | keep-rate/context/report/validate-schemas/eval-runner/metrics_reporter/schema_mapping smoke OK + metrics plan_hash 等価 | smoke |
| T5 | AC5 | scripts/hooks・bin/plangate・plan_hash_util git diff 空 | diff |
## Edge
- E1: 直接実行(python3 scripts/x.py)と被import(schema_mapping)両経路で _paths 解決
- E2: alias（REPO/WORKING 等既存名）維持で下流参照不変＝behavior-preserving
