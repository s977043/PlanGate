# Sprint Retrospective — <期間 / sprint 名>

> 生成補助: `sh bin/plangate report --from <YYYY-MM-DD> --to <YYYY-MM-DD>`
> の出力（`docs/working/_reports/`）を貼り付けてから記入する。
> 正本: [`docs/ai/reporting.md`](../../ai/reporting.md) / EPIC #193。

## 1. PlanGate Report（貼付）

<!-- bin/plangate report の Markdown をここに貼る -->

## 2. KPT

### Keep（続ける）
-

### Problem（課題）
-

### Try（次に試す）
-

## 3. AI harness improvement 用の問い（#200）

- [ ] C-3 CONDITIONAL/REJECTED が増えた要因は？ plan 品質のどこか？
- [ ] C-4 REQUEST_CHANGES の頻出指摘パターンは？ exec/レビュー観点か？
- [ ] V-1 first pass rate の変動要因は？ test-cases 精度か exec 手順か？
- [ ] fix loop が伸びた TASK の共通要因は？ EHS-3 escalation は機能したか？
- [ ] hook violation 傾向（どの EH-x が多いか）と是正済みか？
- [ ] Keep Rate が低い成果物の種類は？（code/plan/acceptance/handoff）
- [ ] latency / cost が悪化した profile/mode は？ Model Profile 見直し要否？
- [ ] 上記から **次の harness improvement PBI 候補**を 1〜3 件抽出したか？

## 4. 次アクション（追跡可能に）

| アクション | Owner | 期限 | 関連 PBI 候補 |
|-----------|-------|------|--------------|
|           |       |      |              |

> 抽出した PBI 候補は EPIC #193 配下で人間が起票判断（advisory・
> LLM judge を hard gate にしない・C-3/C-4 を緩和しない / #200 Non-goal）。
