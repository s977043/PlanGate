# TEST CASES — TASK-0130 (#544 Phase1)

## 受入基準 → テストケース

| AC | TC | 前提 | 入力/操作 | 期待出力 | 種別 |
|----|----|------|----------|----------|------|
| AC-01 | TC-01 | S1完了 | ai-driven-development.md Prompt1 を grep | Loop Scope/Stop Condition/Resume Condition/Replan Triggers/Revert Policy/Loop Attempts の6見出しが存在 | 自動(grep) |
| AC-02 | TC-02 | S1完了 | Verification Automation 節を grep | 「実行コマンド」「Rule4」等の固定文言が存在 | 自動(grep) |
| AC-03 | TC-03 | S2 apply後(人間) | working-context.md plan.md必須要素を grep | 条項項目が必須要素に追記 | 自動(grep) |
| AC-04 | TC-04 | S3完了 | plan-quality-check/review-self.md を確認 | 「Stop Condition記入」「Replan Triggers機械値1つ以上」検出項目が存在 | 自動(grep) |
| AC-05 | TC-05 | S1完了 | 各条項欄を grep | 「Phase1」「Phase2」「#543」等の honest framing 文言が存在 | 自動(grep) |
| AC-06 | TC-06 | S1完了 | Replan Triggers節を grep | 「自己設置Gate」「/goal」「自動解除しない」文言が存在 | 自動(grep) |
| AC-07 | TC-07 | 全Step | plan.md Mode判定 + doctor | high-risk/lite_eligible=false/Standard同期C-3明記・doctor PASS | 自動+目視 |

## エッジケース

- EC-01: working-context.md を AI が誤って直接編集 → S2 は apply-script のみであることを確認(直接 diff がHOファイルに無いこと)
- EC-02: 条項欄が rev.3 §3 と項目ズレ → grep 突合で検出
- EC-03: C-1 検出が plan-quality-check と review-self.md で矛盾 → 正本一本化を確認
