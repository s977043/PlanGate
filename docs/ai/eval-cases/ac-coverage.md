# Eval Case: AC coverage

> [`eval-plan.md`](../eval-plan.md) の 8 観点の 1 つ / WARN

## Trigger

- pbi-input.md の AC が test-cases.md の TC でカバーされていない
- 親 PBI の parent-AC が子 PBI の `covers_parent_ac` で網羅されていない
- handoff.md の要件適合確認結果に AC が記載されていない

## Detection

```bash
# 子 PBI 内の AC × TC マッピング
grep -E "^- \[.\] AC-" docs/working/TASK-XXXX/pbi-input.md | wc -l  # AC 数（完了/未完了の両方をカウント）
grep -E "^### TC-" docs/working/TASK-XXXX/test-cases.md | wc -l    # TC 数
# AC → TC マッピング表が test-cases.md に存在するか確認

# 親 PBI の parent-AC カバレッジ
yq '.child_pbi.covers_parent_ac[]' docs/working/PBI-XXX/children/*.yaml | sort -u
# vs parent-plan.md の parent-AC 一覧
```

## Pass / Fail criteria

| 判定 | 条件 |
|------|------|
| PASS | 全 AC が TC マッピングあり、parent-AC が `covers_parent_ac` で網羅 |
| WARN | 1〜2 件の AC が TC 不足、または parent-AC のカバレッジに穴あり |
| FAIL | 半数以上の AC が TC 不足（release blocker ではないが要対応） |

## release blocker 該当外

WARN として記録、handoff で開示、retrospective で対応議論。

## 関連

- handoff 必須要素 #1（要件適合確認結果）
- Parent Integration Gate での parent-AC カバレッジ検証
