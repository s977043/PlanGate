# HOTL merge 解禁の入口基準（Phase 5 entry criteria）

> 対応 issue: [#733](https://github.com/s977043/plangate/issues/733)（本書は issue 中 Phase A の成果物）
> 根拠となる第一原理: [`design-philosophy.md`](./design-philosophy.md) §1.1（human-on-the-loop の外部定義整合）/
> I-1（承認境界の不可侵）/ I-8（枠内自律は低リスク帯に限定・可逆性の担保）

---

## 0. 決定権の所在（不変・最初に読むこと）

- **C-4 merge の解禁判定（HIC 決定）は、第 0 の承認境界として永久に Human-owned である。**
  AI は本書のような**条件整備・入口基準の draft 提案**までを担当し、解禁の可否判定・
  policy 発行を代行しない（[`design-philosophy.md`](./design-philosophy.md) I-1 /
  [`arbiter-policy.md`](./arbiter-policy.md) §6）。
- **本書は現行の「C-4 merge = HITL」を一切変更しない。** 本書のいかなる記述も、
  merge の自動化・省略・条件緩和を意味しない。全条件が将来充足されたとしても、
  解禁するかどうか・どの対象クラスに限定するかは §5 Phase D で人間が判定する。
- 本書はあくまで「**解禁を検討可能にするための前提条件のリスト**」であり、
  本書の存在自体が解禁への既定路線を意味しない。

---

## 1. 背景

[`design-philosophy.md`](./design-philosophy.md) §1.1 は、ai-loop の統制構造が
HIC（枠の制定者）+ HOTL（監視・停止）+ HITL（例外・境界）のハイブリッドであり、
C-4 merge は現行 policy で **HITL 固定**（[`arbiter-policy.md`](./arbiter-policy.md) §2
永久 Human-owned 4 項目・[`responsibility-classes.md`](../../../.claude/rules/responsibility-classes.md)・
orchestrator-mode.md AS-3）であることを明文化した。

一方、[`concept.md`](./concept.md) §6 Phase 5「解禁判定: policy maturity で領域ごと
on-the-loop 委譲を拡大（人間が判定）」は、将来の HOTL merge を排除していない。
つまり現行思想は「永久禁止」ではなく「**解禁条件を人間が握る**」である。

本書は、その解禁条件（入口基準）を正式化し、Phase B 以降の前提整備を計画するための
土台を提供する。

---

## 2. 入口基準 6 条件

各条件について、**現状**・**検証方法（何をもって充足とするか）**・**関連正本** を定義する。

### 条件 1: provenance 発行元検証（署名 / HMAC）

| 項目                 | 内容                                                                                                                                                                                                                                                                                                        |
| -------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 前提条件             | `issued_by`（誰が承認したか）の自己申告を解消し、署名 / HMAC 等で発行元の真正性を検証可能にする                                                                                                                                                                                                             |
| 現状                 | ❌ 未適用                                                                                                                                                                                                                                                                                                   |
| 検証方法（充足条件） | (a) provenance schema（[`decision-table.md`](../../workflows/ai-loop/decision-table.md) §5）に `hmac_signature`（または同等の署名フィールド）が定義されている、かつ (b) 署名検証ロジックのテストが PASS する、かつ (c) 署名なし・改ざんされた provenance が reject されることを確認する自動テストが存在する |
| 関連                 | TASK-0123 Part B（Human 判断待ち）/ PlanGate [#420](https://github.com/s977043/plangate/issues/420) 同型 / [`design-philosophy.md`](./design-philosophy.md) I-3 既知の限界注記                                                                                                                              |

### 条件 2: 事後 revert の自動化 + post-merge 監視

| 項目                 | 内容                                                                                                                                                                                                                                                                                          |
| -------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 前提条件             | merge 後に問題が判明した際、自動的に revert でき、post-merge の異常を検知する監視が CB-1〜3 と接続されている                                                                                                                                                                                  |
| 現状                 | ❌ 未設計                                                                                                                                                                                                                                                                                     |
| 検証方法（充足条件） | (a) revert 自動化スクリプト（または CI job）が存在し、実際に revert PR を生成するデモ実行が成功する、かつ (b) post-merge 監視が CB-1（事後 reject 即時停止）/ CB-2（連続 incident による policy 自動失効）/ CB-3（escalate 予算超過）のいずれかをトリガーできることを確認するテストが存在する |
| 関連                 | [`decision-table.md`](../../workflows/ai-loop/decision-table.md) §6 サーキットブレーカー                                                                                                                                                                                                      |

### 条件 3: 対象クラスの厳格限定

| 項目                 | 内容                                                                                                                                                                                                                                                                                                                                               |
| -------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 前提条件             | HOTL merge を許可する対象を「docs-only / ai-loop PoC 配下 / doc-light 相当」等の低リスク帯に限定し、lite 判定の 4 軸 + 可逆性（[`design-philosophy.md`](./design-philosophy.md) I-8）を merge クラスにも適用する                                                                                                                                   |
| 現状                 | △ [`lite-criteria.md`](../../workflows/ai-loop/lite-criteria.md) は存在するが、merge クラスは現行判定から除外されている                                                                                                                                                                                                                            |
| 検証方法（充足条件） | (a) [`lite-criteria.md`](../../workflows/ai-loop/lite-criteria.md) §2 判定軸に「merge を含む変更」の扱いが明記され、可逆性要件（§2「可逆性要件の根拠」節）を満たすことが確認できる、かつ (b) [`flow-detect.md`](../../workflows/ai-loop/flow-detect.md) §2 の `class`（merge 含む / 含まない）軸が実データで正しく分類されることをテストで確認する |
| 関連                 | [`design-philosophy.md`](./design-philosophy.md) 語彙集「L2 入力 4 軸」`class` / [`flow-detect.md`](../../workflows/ai-loop/flow-detect.md) §2                                                                                                                                                                                                     |

### 条件 4: veto window 設計

| 項目                 | 内容                                                                                                                                                                                                                                                                                                                                           |
| -------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 前提条件             | merge-ready 通知後、人間に N 時間の veto 猶予を与え、沈黙時のみ auto-merge する（EU AI Act 型 human oversight と整合）                                                                                                                                                                                                                         |
| 現状                 | ❌ 未設計                                                                                                                                                                                                                                                                                                                                      |
| 検証方法（充足条件） | (a) veto window の時間 N と通知チャネルが明文化されている、かつ (b) veto 発火時に merge が確実にブロックされることを確認するテストが存在する、かつ (c) 沈黙判定（何をもって「沈黙」とするか — 例: N 時間以内に応答なし）のロジックが決定論的でテスト可能である（[`design-philosophy.md`](./design-philosophy.md) I-3 検証可能性 4 条件と整合） |
| 関連                 | EU AI Act 型 human oversight / [`design-philosophy.md`](./design-philosophy.md) §1.1 一般定義対応表                                                                                                                                                                                                                                            |

### 条件 5: policy maturity の計測

| 項目                 | 内容                                                                                                                                                                                                                                                                            |
| -------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 前提条件             | 誤検知率・escalate 率・CB 発火履歴等の定量指標を計測し、policy が安定運用に足る成熟度にあることを示す                                                                                                                                                                           |
| 現状                 | ❌ 未到達                                                                                                                                                                                                                                                                       |
| 検証方法（充足条件） | (a) 上記指標が metrics v1（[`docs/ai/metrics.md`](../metrics.md)）に接続されている、かつ (b) ai-loop PoC の実走データが一定期間（具体的な期間・サンプル数は Phase C で確定）蓄積されている、かつ (c) 指標の閾値（例: 誤検知率 X% 未満）が事前に定義され、実測値と比較可能である |
| 関連                 | [`concept.md`](./concept.md) §6 Phase 5 / metrics v1                                                                                                                                                                                                                            |

### 条件 6: 統制の実質性検証（sockpuppet 禁止との整合）

| 項目                 | 内容                                                                                                                                                                                                                                                                                                                                                                                                 |
| -------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 前提条件             | auto-approve 機構（PlanGate #620 apply-script 等）が、sockpuppet マージ禁止（[`responsibility-classes.md`](../../../.claude/rules/responsibility-classes.md)）と実質的に整合するかを再確認する                                                                                                                                                                                                       |
| 現状                 | ❌ 未検証                                                                                                                                                                                                                                                                                                                                                                                            |
| 検証方法（充足条件） | (a) auto-approve が発行する provenance の `issued_by` が実在する人間権限に紐づくこと（条件 1 と連動）、かつ (b) auto-approve 経路が「別アカウントでの自己承認」と機能的に等価にならないことをレビューし、レビュー結果を issue に記録する、かつ (c) [`responsibility-classes.md`](../../../.claude/rules/responsibility-classes.md) の merge = Human-owned 固定の記述と矛盾しないことを人間が確認する |
| 関連                 | [`responsibility-classes.md`](../../../.claude/rules/responsibility-classes.md)                                                                                                                                                                                                                                                                                                                      |

---

## 3. 条件充足の判定原則

- 6 条件は **すべて充足して初めて Phase D（解禁判定）の検討対象になる**。一部充足では
  Phase D に進まない（design-philosophy I-4 安全側デフォルトと同じ考え方を条件充足判定にも適用する）。
- 各条件の「検証方法」欄は**充足の必要条件**であり、Phase B で個別 PBI 化した際に、
  実装 PBI の受入基準へそのまま転記できる粒度で書いている。
- 条件充足の確認（チェック）自体は AI が実施してよいが、**充足したと最終的にみなし
  Phase D へ進める判断は人間が行う**（本書 §0 と同じ境界）。

---

## 4. Phase B 個別 PBI 候補

issue #733 の段階計画（Phase A〜D）のうち、**Phase B（前提整備・個別 PBI 化）** の候補を列挙する。
各候補は独立 PBI として起票し、HO パスに触れる部分は apply-script 方式
（[`responsibility-classes.md`](../../../.claude/rules/responsibility-classes.md) 準拠）で扱う。

| 候補 PBI                        | 対応条件 | 概要                                                               | 備考                                                                   |
| ------------------------------- | -------- | ------------------------------------------------------------------ | ---------------------------------------------------------------------- |
| provenance 署名検証の導入       | 条件 1   | HMAC 等での `issued_by` 発行元検証をスキーマ + 実装に追加          | TASK-0123 Part B / #420 と連携。Phase A 段階では起票のみ、実装は別 PBI |
| revert 自動化 + post-merge 監視 | 条件 2   | CB-1〜3 と接続した自動 revert パイプライン                         | decision-table.md §6 の既存 CB 定義を前提に設計                        |
| veto window 機構                | 条件 4   | merge-ready 通知 → N 時間 veto 猶予 → 沈黙時 auto-merge のロジック | 通知チャネル・沈黙判定の決定論化が焦点                                 |

条件 3（対象クラス限定）・条件 5（policy maturity 計測）・条件 6（統制実質性検証）は、
Phase B で個別実装 PBI を新設するのではなく、既存の [`lite-criteria.md`](../../workflows/ai-loop/lite-criteria.md)
（条件 3）・metrics v1 接続（条件 5・Phase C）・レビュー記録（条件 6）の**追記・確認作業**として
扱う想定である。個別 PBI 化が必要と判断された場合は、本表に追加する。

---

## 5. design-philosophy.md §1.1 との相互参照

本書は [`design-philosophy.md`](./design-philosophy.md) §1.1 の以下の記述を具体化したものである:

> touches-HO / C-4 merge（常時同期ブロック）: **HITL**（現行 policy。touches-HO は恒久固定。
> C-4 merge の解禁判定は concept.md Phase 5 の HIC 決定として Human に留保 — 入口基準は
> [#733](https://github.com/s977043/plangate/issues/733)）

design-philosophy.md 側は本書へのリンクを追加すること（design-philosophy.md 側の編集は
本書の担当範囲外であり、統合担当が §1.1 または §10 関連ドキュメントへの参照追加を行う）。

---

## 6. 非ゴール（issue #733 と同一）

- C-4 merge の HITL 解除（Phase D まで一切行わない）
- branch protection / `bin/plangate` / `schemas/` の変更（HO・Phase B 以降で apply-script 方式）
- 人間承認ゼロの正当化（[`design-philosophy.md`](./design-philosophy.md) I-1 により永久に扱わない）

---

## 7. 関連ドキュメント

- [`design-philosophy.md`](./design-philosophy.md) §1.1 / I-1 / I-8
- [`concept.md`](./concept.md) §6 Phase 5
- [`arbiter-policy.md`](./arbiter-policy.md) §2 / §6
- [`decision-table.md`](../../workflows/ai-loop/decision-table.md) §5 provenance スキーマ / §6 サーキットブレーカー
- [`lite-criteria.md`](../../workflows/ai-loop/lite-criteria.md)
- [`responsibility-classes.md`](../../../.claude/rules/responsibility-classes.md)
- issue [#733](https://github.com/s977043/plangate/issues/733) / TASK-0123 Part B / PlanGate [#420](https://github.com/s977043/plangate/issues/420) / [#620](https://github.com/s977043/plangate/issues/620)
