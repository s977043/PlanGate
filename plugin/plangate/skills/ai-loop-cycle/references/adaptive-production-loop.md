# adaptive-production-loop — bounded adaptive production loop

> 適用制限（Phase 1 rollout eligibility）の正本: [`rollout-policy.md`](./rollout-policy.md)
> 位置づけ: Issue #709 の正本。`Generate → Evaluate → Remember → Schedule → Optimize → Recurse` を ai-loop-workflow に取り込むための上位概念。

---

## 1. 目的

ai-loop-workflow を、低リスク帯に限定した **bounded adaptive production loop** として定義する。

```text
Generate → Evaluate → Remember → Schedule → Optimize → Recurse
```

このループは「人間なしで完全自律する仕組み」ではない。PlanGate では、以下の境界を固定したまま、AI が自己改善できる範囲を限定する。

- policy / HO / C-4 merge は Human-owned 固定
- touches-HO は常に human escalate
- 学習ループは承認境界そのものを自己変更しない
- PlanGate 本番フロー（WF-00〜WF-07）は置き換えない

---

## 2. `/goal` と `/loop` を混同しない

外部ツールの `/goal`・`/loop`・scheduled task 系の挙動は、ai-loop-workflow の設計語彙へそのまま持ち込まない。

PlanGate では、以下のように責務を分離する。

| 概念 | PlanGate 上の責務 | 混同してはいけない点 |
| --- | --- | --- |
| Goal / Exit Criteria | 何を達成すれば終わりかを定義する | `interval` の有無では決まらない |
| Schedule | 次にいつ・何を実行するかを決める | Schedule は goal 達成判断ではない |
| Evaluate | 継続 / 停止 / escalate / block を判定する | 再実行すること自体は評価ではない |
| Loop | 上記を接続した運用単位 | 単なる定期実行ではない |

重要な整理:

- `/loop <interval> ...` 型は **cadence polling** に近い。固定間隔で再実行する schedule であり、goal 達成判断を持つとは限らない。
- `/loop ...` のように interval を省いた self-paced 型でも、PlanGate 上は **Schedule が動的化しただけ** と扱う。Goal / Exit Criteria / Evaluate が明示されていなければ、closed loop とは呼ばない。
- `/goal` 型は Goal / Exit Criteria を含む方向に近いが、PlanGate では外部ツールの完了判断へ委ねきらず、DoD・検証・停止条件・escalate 条件を文書側に固定する。

したがって、ai-loop-workflow における closed/open の違いは **interval の有無ではなく、明示された Goal / Evaluate / Stop / Memory / Escalation Contract の有無**で決まる。

---

## 3. 6 層モデル

| 層 | 責務 | ai-loop-workflow 上の対応 |
| --- | --- | --- |
| Generate | plan / todo / test-cases / diff / PR を生成する | WF-00〜03、exec、PR 作成 |
| Evaluate | 生成物に「No」と言う | C-1、C-2、C-3' Arbiter、CI、AI review、DoD 判定 |
| Remember | 実行結果・判断・指摘・反証を保存する | decision record、review-feedback-loop、suppression、provenance |
| Schedule | 次アクションを選ぶ | retry、queue、CI fix、review comment handling、stop、block、human escalate |
| Optimize | 保存した記録を次回の振る舞いへ反映する | skill / gate / suppression / diff-audit 観点の更新 |
| Recurse | 1 サイクルの出力を次サイクルの入力へ戻す | 次回 pre-check、次回 C-3'、次回 PR 前 diff-audit |

---

## 4. 1 サイクルの contract

ai-loop-workflow の 1 サイクルは、以下の contract を満たす場合のみ closed loop として扱う。

| contract | 必須条件 |
| --- | --- |
| Goal | `MERGE_READY` 到達条件が明示されている |
| Evaluate | C-1 / C-2 / C-3' / CI / AI review / DoD の判定点がある |
| Stop | 裁定の terminal state（`AUTO_APPROVED` / `HUMAN_ESCALATED` / `BLOCKED`）がある。`MERGE_READY` は裁定でなく Delivery の DoD 状態、round limit exceeded は `HUMAN_ESCALATED` への遷移理由（語彙群区別の正本 = [`00_concept.md`](./00_concept.md) §2.3） |
| Memory | decision record、採用/不採用理由、CI/AI review 指摘、suppression を保存する |
| Schedule | 次アクションの優先順位と retry 上限がある |
| Boundary | policy / HO / C-4 merge を AI が自己変更しない |

これを満たさない反復は、PlanGate では **scheduled repetition** または **polling** と呼び、closed loop とは呼ばない。

---

## 5. Scheduling 判断表

PR 作成後から `MERGE_READY` までの Schedule は、以下の優先順位で決める。

| 優先度 | 条件 | 次アクション | terminal state |
| --- | --- | --- | --- |
| 1 | boundary=touches-HO / policy 変更 / irreversible 変更 | human escalate | `HUMAN_ESCALATED` |
| 2 | 対応ラウンド上限 3 超過 | human escalate | `HUMAN_ESCALATED` |
| 3 | 同型指摘の再発 | review-feedback-loop へ還元し、Optimize 対象へ送る | recurse |
| 4 | CI failed | CI failure を調査・修正し、強化セルフレビューを再実行して push | continue |
| 5 | merge conflict | conflict 解消、三点照合、`--force-with-lease` push | continue |
| 6 | critical / major の AI review 指摘あり | 採用して修正、または理由付き不採用を記録 | continue or escalate |
| 7 | minor / info のみ | 採用/不採用理由を記録し、DoD 判定へ進む | `MERGE_READY` candidate |
| 8 | CI green かつ AI review 全件対応済み | C-4 待ちへ遷移 | `MERGE_READY` |

Schedule は「次に動く」ための判断であり、Schedule 自身が品質評価を兼ねてはならない。品質判断は Evaluate 層に残す。

---

## 6. Remember と Optimize の分離

`review-feedback-loop.md` は、指摘の収集から観点還元までを扱うため、Remember と Optimize が混ざりやすい。

PlanGate では以下に分ける。

### Remember

事実を残す。

- decision record
- CI 失敗内容
- AI review 指摘
- 採用 / 理由付き不採用
- suppression の機械反証
- human reject / human override

### Optimize

保存された事実をもとに、次回の振る舞いを更新する。

- diff-audit 観点を追加する
- readiness gate の観点を更新する
- suppression を追加する
- scheduling policy を調整する
- skill の手順を更新する

禁止事項:

- 記録なしに prompt / skill / gate を更新しない
- policy / HO / C-4 merge 境界を AI が自己更新しない
- false-positive 抑制を理由に critical / major 指摘を無視しない

---

## 7. Recurse 条件

1 サイクルの出力は、次サイクルの入力へ戻す。

| 出力 | 次サイクルへの戻し先 |
| --- | --- |
| CI failure | 強化セルフレビュー / test checklist |
| AI review true-positive | diff-audit / readiness gate |
| AI review false-positive | suppression |
| human reject | C-3' 判定条件 / policy draft |
| round limit exceeded | scheduling policy / escalate budget |
| `MERGE_READY` 到達 | 成功パターンとして decision record に保存 |

Recurse は無限継続ではない。次サイクルへ渡す情報を保存した時点で 1 サイクルは完了し、terminal state に従って停止または C-4 待ちへ遷移する。

---

## 8. 採用する表現

ai-loop-workflow の説明では、以下の表現を採用する。

> ai-loop-workflow は、低リスク帯かつ承認境界に触れない範囲で、Generate → Evaluate → Remember → Schedule → Optimize → Recurse の自己改善ループを回す。policy / HO / C-4 merge は Human-owned 固定であり、AI は自己改善ループを通じて承認境界そのものを自己変更しない。

以下の表現は採用しない。

- 人間なしで完全自律する
- `/loop` を入れれば closed loop になる
- interval を省けば goal 駆動になる
- AI が policy / HO / merge 境界を自己改善できる
- scheduled task を PlanGate の Evaluate と同一視する

---

## 9. 関連ドキュメント

- [`00_concept.md`](./00_concept.md) — ai-loop-workflow の位置づけ、C-3'、`MERGE_READY` 責務範囲（責務・terminal state の正本 = §2）
- [`execution-runbook.md`](./execution-runbook.md) — 1 サイクルの実行手順、PR 後の CI / AI review 対応ループ
- [`review-feedback-loop.md`](./review-feedback-loop.md) — Remember / Optimize の実体となるレビュー指摘還元ループ
- [`flow-detect.md`](./flow-detect.md) — C-3' の flow→detect→escalate 動作フロー
- [`decision-table.md`](./decision-table.md) — terminal state と decision record
- [`docs/ai/ai-loop/arbiter-policy.md`](./arbiter-policy.md) — Human-owned 境界と escalate 予算
