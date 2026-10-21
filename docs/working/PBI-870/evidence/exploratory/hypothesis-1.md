# 仮説-1: イテレーション運用は V2 の「Run を跨いだ継続価値の判断層」のモデルになる

> 状態: 未検証。V2 の設計判断には使わない。
> 一次ソース: <https://github.com/s977043/PlanGate/issues/870#issuecomment-6310129824>

## 仮説

V2 の Stop Reason（NO_PROGRESS 等）は主に 1 Run の中で止まるための仕組み。Iteration 1 から始めた運用（[開始記録](https://github.com/s977043/PlanGate/issues/870#issuecomment-6310093146)）は一段上の層で、Run / イテレーションを跨いで「この方向を続ける価値があるか」を判断している。この層は現行 Delivery Loop に明示されていない（推測: #1345 Loop Decision Surface / #1348・#1376 Evolution の領域）。

| 本運用 | V2 の対応概念 |
|---|---|
| 透明性: SHA 付き実測だけの状況の一枚 | RunEvidence（自己申告を completion evidence にしない） |
| 検査: C-3 / C-4 + 振り返り | Verify / PR Convergence |
| 適応: 続ける / 方向転換 / やめる | Repair / Replan / STOP・ESCALATE |
| やめる条件 1（AC が増えない） | NO_PROGRESS（#1383 AC-7: retry 回数でなく evidence delta） |
| やめる条件 2（C-3 再発行の連続） | Replan 反復の上限 |
| やめる条件 3（新しい失敗クラスが続く） | 敵対レビューの収束判定（review-principles §7-quater） |

## 検証手順

1. 2〜3 イテレーション運用する
2. 各イテレーション末のレビューで「どの条件・指標を判断に使ったか / 使わなかったか」を記録する
3. 効いた条件だけを V2 の issue に起こす。効かなかった条件は運用からも外す

## 予測結果

- RESOLVED: 判断に効いた条件がある
- REJECTED: どれも使われなかった・判断を誤らせた
- DEFERRED: イテレーションが進まず評価不能

## 検証結果

<!-- 検証完了後に記入 -->
- 結果: <RESOLVED|REJECTED|DEFERRED>
- 判明した事実: <text>
- 次の仮説: <text or なし>

## AC への影響

<!-- 前提変更があれば記入 -->
- 影響 AC: <ID or なし>
- 変更内容: <text>
