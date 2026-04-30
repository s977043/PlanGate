# Eval Case: format adherence

> [`eval-plan.md`](../eval-plan.md) の 8 観点の 1 つ / **release blocker（schema 準拠率 < 95%）**

## Trigger

- 機械判定対象成果物が schema 不適合（[`structured-outputs.md`](../structured-outputs.md) 4 schema）
- handoff.md が必須 6 要素を欠く
- markdown lint FAIL

## Detection

```bash
# schema 準拠率（Issue #158 で CI 統合済）
# review-result / acceptance-result / mode-classification / handoff-summary 等
# 各 JSON ファイルを schemas/ で validate
sh bin/plangate validate-schemas TASK-XXXX
# → Summary: PASS=N, FAIL=N, SKIP=N, ERROR=N
# 準拠率 = PASS / (PASS + FAIL)

# CI 自動検証
# .github/workflows/schema-validate.yml が PR の docs/working/**/*.json を
# basename → schema 自動マッピングで validate（違反時 CI FAIL）

# handoff 必須 6 要素
grep -cE "^## [1-6]\." docs/working/TASK-XXXX/handoff.md  # 期待: 6

# markdown lint
markdownlint docs/working/TASK-XXXX/*.md
```

## Pass / Fail criteria

| 判定 | 条件 |
|------|------|
| PASS | schema 準拠率 ≥ 95%、handoff 6 要素完備、markdown lint 0 error |
| WARN | schema 準拠率 95-99%（軽微）、または handoff 6 要素のうち 1 件不備 |
| FAIL | schema 準拠率 < 95%、または handoff 6 要素のうち 2 件以上不備 |

## release blocker 暫定基準

[`eval-plan.md`](../eval-plan.md) § 6 で **schema 準拠率 < 95% は release blocker（暫定値）**。本観点の WARN/FAIL とは別判定。

## Model 適性

`outcome_first_strict` (gpt-5_5_pro) が format adherence で最も強い。`explicit_short` (gpt-5_mini) は形式維持に注意。

## 関連

- [`structured-outputs.md`](../structured-outputs.md)
- [`schemas/handoff-summary.schema.json`](../../schemas/handoff-summary.schema.json)
- [`hook-enforcement.md`](../hook-enforcement.md) EHS-2（handoff 必須 6 要素チェック）
