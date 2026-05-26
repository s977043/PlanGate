# Before / After: PlanGate

> **Status**: v0
> **Review cadence**: Monthly

## 目的

PlanGate を導入すると AI 開発の何が変わるかを Before / After で説明する。

PM / PO / EM / CTO に対して、PlanGate の価値を短時間で伝えるために使う。

## Core contrast

| Before: AI coding agent only | After: PlanGate |
| --- | --- |
| AI がすぐ実装に入る | AI はまず計画と受入条件を作る |
| PBI の意図が曖昧なまま進む | PBI 理解が plan として残る |
| 受入条件が後付けになる | test-cases が実装前に固定される |
| スコープ逸脱に気づきにくい | C-3 承認でスコープを止める |
| PR レビューで初めて問題に気づく | 実装前・実装後に Gate がある |
| AI 作業がブラックボックスになる | plan / review / handoff が残る |
| テスト未実行が曖昧になる | verification honesty を要求する |
| チームごとに運用がバラつく | PBI 単位の標準 workflow に揃う |

## PM perspective

| Before | After |
| --- | --- |
| AI の作業がロードマップやリリース判断と接続しづらい | plan / verification / handoff が残るため判断材料になる |
| 速く作ったが、意図と違うものができる | C-3 で実装前に方向性を確認できる |
| スコープが広がっても事後に気づく | PBI と plan の差分を確認できる |
| AI の成果を説明しづらい | 何を、なぜ、どう検証したかが残る |

## PO perspective

| Before | After |
| --- | --- |
| 受入条件が曖昧なまま実装される | test-cases が実装前に作られる |
| Done の定義が実装中に揺れる | C-3 承認で Done 条件を固定する |
| PBI の意図がコードに反映されたか判断しづらい | plan と acceptance の対応を確認できる |
| AI が勝手に改善案を足す | scope discipline により PBI 外を抑制する |

## Engineering perspective

| Before | After |
| --- | --- |
| AI の変更理由が読みづらい | plan / todo / review が残る |
| 実装後にテスト観点を探す | test-cases が先にある |
| PR レビューで初めて設計ズレに気づく | C-3 / C-4 で前後に判断点がある |
| AI の失敗パターンが蓄積されない | metrics / eval / hook violation を改善に使える |

## One-slide version

```text
Before:
AI writes code fast, but scope, acceptance criteria, and verification can drift.

After:
PlanGate makes AI plan first, get approval, implement within scope, verify, and hand off evidence.

Result:
AI development becomes manageable product delivery.
```

## Main message

PlanGate の価値は、AI の速度を落とすことではない。

AI が速く動く前に、何を作るか、なぜ作るか、どう検証するかを固定することで、速さをプロダクト価値に接続することである。
