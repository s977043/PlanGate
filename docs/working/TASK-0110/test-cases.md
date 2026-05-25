# TASK-0110 TEST CASES

> Source: plan.md / AC-1..AC-7

## 受入基準 → テストケースマッピング

| AC | TC |
|----|-----|
| AC-1: dry-run で全 null 検出 + sample 出力 | TC-01 |
| AC-2: apply で atomic 更新 + .bak 保持 | TC-02, TC-03 |
| AC-3: 適用後 check-skip-acknowledged.sh PASS | TC-04 |
| AC-4: byte-equal except 2 field | TC-05 |
| AC-5: --apply は --acknowledged-by 必須 | TC-06 |
| AC-6: dry-run 結果 evidence 保存 | TC-07 |
| AC-7: ta-14 unit test 追加 | TC-08 |

## テストケース一覧

| ID | 内容 | コマンド/手順 | 期待 |
|----|------|-------------|------|
| TC-01 | fixture jsonl (全 null) で dry-run → 全件検出 + reason 分布出力 | `python3 scripts/batch-acknowledge-skip-decisions.py --dry-run --log tests/fixtures/skip-log-all-null.jsonl` | exit 0 + 検出件数 + reason 集計 |
| TC-02 | fixture jsonl で apply → 2 field のみ追記 | `python3 scripts/batch-acknowledge-skip-decisions.py --apply --acknowledged-by tester --log /tmp/test.jsonl` | exit 0 + ack 済化 |
| TC-03 | apply 後に .bak が残存 | apply 後 `ls /tmp/test.jsonl.bak` | ファイル存在 |
| TC-04 | apply 後 check-skip-acknowledged.sh PASS | `sh scripts/check-skip-acknowledged.sh` (LOG=/tmp/test.jsonl) | exit 0 |
| TC-05 | byte-equal except 2 field | apply 前後の jsonl を diff、acknowledged_by/at の 2 field 以外不変 | diff で 2 field のみ差分 |
| TC-06 | apply で --acknowledged-by 空文字 reject | `python3 scripts/batch-acknowledge-skip-decisions.py --apply --acknowledged-by "" --log /tmp/test.jsonl` | exit !=0 + reject message |
| TC-07 | dry-run 結果が evidence/dry-run-result.md に保存 | T-04 実行後 `ls docs/working/TASK-0110/evidence/dry-run-result.md` | ファイル存在 |
| TC-08 | ta-14 が tests/run-tests.sh から自動 discovery + PASS | `sh tests/run-tests.sh` | 全 case PASS (count 増加) |
| TC-09 | 既に ack 済 entry は触らない (idempotent) | fixture (全 ack 済) で apply → no-op | exit 0 + 変更 0 件 |

## エッジケース

- 空 jsonl: dry-run / apply 共に no-op (exit 0)
- jsonl 破損 (parse error) entry: スキップ + warning 出力 (apply は abort)
- 1 行のみの jsonl: 正常処理
