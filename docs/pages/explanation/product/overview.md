# Product Overview: PlanGate

> **Status**: v0（Product narrative draft）
> **Review cadence**: Monthly
> **Owner**: Product / Maintainer

## Summary

PlanGate is a governance-first workflow harness for AI coding agents.

It prevents AI agents from writing production code until a human-approved plan, task list, and acceptance test set exist.

Unlike agent frameworks that focus primarily on autonomy and speed, PlanGate focuses on approval boundaries, auditability, and Scrum-friendly delivery.

## 日本語概要

PlanGate は、AI コーディングエージェントをプロダクト開発に安全に組み込むためのゲート型ワークフローハーネスである。

AI がいきなりコードを書くのではなく、まず PBI を読み、計画、TODO、テストケースを作り、人間が承認してから実装へ進む。

実装後は検証、レビュー、handoff を残す。これにより、AI 開発を「速いが危ないもの」から、「説明可能で、検証可能で、チームで運用可能なプロダクトデリバリー」に変える。

## Problem

AI コーディングエージェントは実装速度を大きく上げる。一方で、次の問題が起きやすい。

| Problem | Description |
| --- | --- |
| スコープ逸脱 | PBI の範囲を超えて実装が広がる |
| 受入条件の曖昧化 | Done の条件が実装後に後付けされる |
| 実装前レビューの欠落 | 何を作るかを確認する前にコードが進む |
| AI 作業のブラックボックス化 | どの判断で何を変更したか追跡しづらい |
| 検証証拠の不足 | テスト未実行や残リスクが曖昧になる |
| PM / PO の責任境界の崩れ | 価値、スコープ、Done を誰が保証するか不明確になる |

AI 開発で本当に怖いのは、コードが遅いことではなく、間違ったものを速く作ってしまうことである。

## Target users

| User | Needs |
| --- | --- |
| PM | AI 開発を管理可能なプロダクトデリバリーにしたい |
| PO | PBI、受入条件、Done の定義を AI 開発でも守りたい |
| EM | AI エージェントの利用をチーム標準として安全に運用したい |
| CTO | AI 開発の速度と統制を両立したい |
| Developer | AI に任せた作業をレビュー可能・検証可能にしたい |
| OSS adopter | AI coding workflow を自分のチームに導入しやすくしたい |

## Solution

PlanGate は、PBI 単位の開発に以下の流れを導入する。

```text
PBI
→ plan / todo / test-cases
→ C-3 approval
→ implementation
→ verification
→ C-4 review
→ handoff
```

中核は次のルールである。

```text
No approved plan, no code.
```

AI は C-3 承認前に本番コードを書けない。実装前に、何を作るか、どう進めるか、何を満たせば Done かを成果物として残す。

## Core value

| Value | Description |
| --- | --- |
| Approval boundary | C-3 / C-4 により、人間の判断点を固定する |
| Scope discipline | PBI 外の作業を増やさない |
| Acceptance clarity | test-cases により Done の条件を実装前に固定する |
| Verification honesty | 未実行、失敗、残リスクを隠さない |
| Auditability | plan、review、verification、handoff を残す |
| Scrum-friendly delivery | PBI、受入条件、Done、handoff と接続する |
| Harness improvement | eval、metrics、Keep Rate により PlanGate 自体を継続改善する |

## How it works

1. PM / PO / Developer が PBI または issue を入力する。
2. AI が `pbi-input.md`、`plan.md`、`todo.md`、`test-cases.md` を作る。
3. 人間が C-3 で plan、todo、test-cases を承認する。
4. AI が承認済み plan に沿って実装する。
5. L-0 / V-1〜V-4 で検証する。
6. 人間が C-4 で実装結果をレビューする。
7. 変更内容、検証結果、残リスク、次アクションを handoff として残す。

## Success metrics

PlanGate の価値は、生成量ではなく、採用される作業、検証可能性、手戻り削減で測る。

| Metric | Meaning |
| --- | --- |
| C-3 approval rate | plan 品質 |
| C-3 conditional / reject rate | PBI / plan の曖昧さ |
| V-1 first pass rate | 受入条件と実装の一致度 |
| C-4 request changes rate | 実装・レビュー品質 |
| Hook violation rate | Gate / scope / evidence 違反傾向 |
| Code Keep Rate | AI が書いたコードが残った割合 |
| Plan Keep Rate | 承認済 plan が実装後も維持された割合 |
| Acceptance Keep Rate | test-cases が検証まで有効だった割合 |
| Handoff usefulness | 後続 PBI で handoff が参照されたか |

## Non-goals

PlanGate は以下を目的にしない。

- AI を完全自律でマージ・デプロイさせること
- C-3 / C-4 の人間判断をなくすこと
- すべてのタスクに重いプロセスを強制すること
- 特定 provider 専用 workflow にすること
- Cursor / Claude Code / Codex の代替になること

PlanGate は、AI coding agents の代替ではなく、それらをプロダクト開発に安全に接続するための上位ハーネスである。

## Main message

PlanGate は、AI が速くコードを書く時代に、PM / PO が守るべき「何を作るか」「なぜ作るか」「Done とは何か」を失わないためのゲート型ハーネスである。
