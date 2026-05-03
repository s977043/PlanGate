# Product Demo Script: PlanGate

> **Status**: v0
> **Review cadence**: Monthly

## 目的

このドキュメントは、PlanGate の価値をデモで説明するためのスクリプトである。

対象は PM / PO / EM / CTO / Developer。説明よりも、実際の流れを見せることで PlanGate の価値を伝える。

## Demo goal

このデモで伝えることは 1 つである。

```text
AI がコードを書く前に、必ず「何を作るか」「どう検証するか」が残る。
```

## Demo story

AI に小さな PBI を渡す。

AI はすぐにコードを書かない。まず plan、todo、test-cases を作る。

人間が C-3 で承認するまで、AI は production code を編集できない。

承認後、AI は実装し、検証し、handoff を残す。

これにより、AI 開発が単なる自動実装ではなく、計画・承認・検証・引き継ぎを持つプロダクトデリバリーになる。

## 5-minute demo

### Step 1: PBI を入力する

```text
docs/working/TASK-XXXX/pbi-input.md
```

伝えるポイント:

- 入口は PBI
- 実装指示ではなく、価値・受入条件を含む作業単位
- PM / PO が責任を持つ情報と接続する

### Step 2: AI が planning artifacts を作る

```text
docs/working/TASK-XXXX/plan.md
docs/working/TASK-XXXX/todo.md
docs/working/TASK-XXXX/test-cases.md
```

伝えるポイント:

- PBI の理解が plan として外化される
- Done の条件が test-cases として実装前に固定される
- 実装前にレビューできる

### Step 3: C-3 approval を見せる

```text
docs/working/TASK-XXXX/approvals/c3.json
```

伝えるポイント:

- No approved plan, no code
- 人間の判断点が実装前にある
- 速さよりも、正しい方向に進むことを優先する

### Step 4: 実装する

```text
git diff
```

伝えるポイント:

- AI は自由に広げるのではなく、承認済み plan に沿って進める
- scope discipline が働く
- PR レビュー前に実装の根拠がある

### Step 5: 検証する

```text
docs/working/TASK-XXXX/verification.md
docs/working/TASK-XXXX/evidence/
```

伝えるポイント:

- verification honesty
- V-1 first pass / fix loop
- Done を雰囲気で判断しない

### Step 6: C-4 review と handoff

```text
docs/working/TASK-XXXX/approvals/c4.json
docs/working/TASK-XXXX/handoff.md
```

伝えるポイント:

- 実装後の人間判断点がある
- 後続 PBI へ引き継げる
- AI の作業がブラックボックスにならない

## 15-minute demo

5-minute demo に加えて、以下を見せる。

### Hook enforcement

見せる内容:

- C-3 承認前に production code を編集しようとすると警告 / block される
- plan_hash がズレると検知される
- test-cases / evidence がない場合に警告される

伝えるポイント:

```text
PlanGate は単なるルール文書ではなく、破ってはいけない条件を runtime / hook 側に寄せます。
```

### Eval / Metrics

見せる内容（実装済み、v8.6.0）:

```text
bin/plangate eval
bin/plangate metrics TASK-XXXX --collect
bin/plangate metrics TASK-XXXX --report
bin/plangate metrics --report --aggregate
```

伝えるポイント:

- 感覚ではなく、eval と metrics で改善する
- C-3 / V-1 / C-4 / hook violation を機械的に集計できる
- metrics log は public repo にコミットしない設計（[metrics-privacy.md](../../docs/ai/metrics-privacy.md)）
- baseline ([eval-baselines/2026-05-04-baseline.md](../../docs/ai/eval-baselines/2026-05-04-baseline.md)) と差分比較可能
- PlanGate 自体もハーネス製品として改善する

### Keep Rate concept (Roadmap, v8.8.0)

見せる内容:

- Code Keep Rate
- Plan Keep Rate
- Acceptance Keep Rate
- Handoff Keep Rate

伝えるポイント:

```text
PlanGate は、AI が何を生成したかではなく、何が採用され残ったかを重視します。
```

## Audience-specific emphasis

| Audience | Emphasize |
| --- | --- |
| PM | リリース判断、リスク管理、証跡 |
| PO | PBI、受入条件、Done の定義 |
| EM | チーム標準、レビュー負荷、手戻り削減 |
| CTO | AI 導入の統制、監査可能性、再現性 |
| Developer | 実装前の方針確認、レビューしやすさ、検証証拠 |

## Demo closing

```text
PlanGate は AI の速度を否定しません。
AI が速く動く前に、何を作るか、なぜ作るか、どう検証するかを固定します。
だから AI 開発を、速いだけでなく、説明可能で、検証可能で、チームで運用可能なものにできます。
```

## Demo checklist

- [ ] PBI がある
- [ ] plan / todo / test-cases がある
- [ ] C-3 approval を見せられる
- [ ] 承認前に code を書けないことを説明できる
- [ ] git diff を見せられる
- [ ] verification evidence を見せられる
- [ ] C-4 / handoff を見せられる
- [ ] PM / PO 向けの価値に戻して説明できる
