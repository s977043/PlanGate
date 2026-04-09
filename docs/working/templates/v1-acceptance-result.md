# TASK-XXXX V-1 受入テスト結果

> 実行日: YYYY-MM-DD HH:MM

## テスト結果サマリー

| result | 件数 |
|--------|------|
| PASS | {0} |
| FAIL | {0} |

## テストケース別結果

| TC-ID | テスト名 | result | evidence_ref | 実行コマンド |
|-------|---------|--------|-------------|------------|
| TC-1 | {テスト名} | PASS / FAIL | {evidence/test-runs/YYYY-MM-DD-exec.log#L42} | {phpunit --filter=testMethodName} |
| TC-2 | {テスト名} | PASS / FAIL | {evidence/test-runs/YYYY-MM-DD-exec.log#L58} | {phpunit --filter=testMethodName} |

## エッジケース結果

| TC-ID | テスト名 | result | evidence_ref | 実行コマンド |
|-------|---------|--------|-------------|------------|
| TC-E1 | {テスト名} | PASS / FAIL | {evidence/test-runs/YYYY-MM-DD-exec.log#L89} | {phpunit --filter=testMethodName} |

## FAIL がある場合の詳細

### {TC-ID}: {テスト名}

- **期待結果**: {test-cases.md の期待出力}
- **実際の結果**: {実行時の出力}
- **原因分析**: {なぜ失敗したか}
- **対応**: {修正方針}
