# TASK-XXXX Current State

> 更新: YYYY-MM-DD HH:MM

## フェーズ: {brainstorm | plan | C-1 | C-2 | C-3待ち | exec | done}
## 進捗: {T-1〜T-5 完了 / T-6 実行中 / T-7〜T-12 未着手}

## 直近の完了タスク

- {T-5: typecheck/lint/test 全PASS（YYYY-MM-DD HH:MM）}

## 現在のタスク

- {T-6: ArticleDetailQueryService に tryRedirectByDifferentType() を追加 [実行中]}

## ブロッカー

{なし / あれば記載。例: "T-6 で N+1 クエリ疑惑 → backend-specialist に確認依頼中"}

## 次のアクション

- {T-6 完了後 → T-7（テスト実行しPASS確認）へ進む}

## 計画からの乖離

{なし / あれば要約。例: "T-4 で正規表現を変更（decision-log参照）"}

## Metrics スナップショット（v8.6.0+、任意）

> opt-in。取得していない場合は省略してよい。privacy: §3 Allowed のみ。

```text
bin/plangate metrics TASK-XXXX --report
```

直近の取得値（必要に応じてセッション開始時 / 終了時に上書き）:

- events: {N}
- mode: {ultra-light / light / standard / high-risk / critical}
- C-3 verdict: {APPROVED / CONDITIONAL / REJECTED / 未到達}
- V-1 verdict: {PASS / FAIL / WARN / 未実施}
- hook violations: {N}（種別: {EH-N: block/warn ×N}）
- 直近の events.ndjson 行数: {N}（`wc -l docs/working/_metrics/events.ndjson`）

参照: [docs/ai/metrics.md](../../ai/metrics.md)
