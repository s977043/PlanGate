# AIDLE 2026: タスク性質に応じた探索・Factory・既知実行の適用検討

> Status: **非規範的な設計候補 / 未採用**（2026-10-18）
> Source: [AIDLE Extended 2026 レポート前編](https://note.com/ai_dev_leaders/n/ndd23a2abf5be)（2026-10-15、イベント主催者の発言要約）
> Tracking: [#911](https://github.com/s977043/PlanGate/issues/911)（Intent-to-Execution）、[#920](https://github.com/s977043/PlanGate/issues/920)（Software Factory、closed）、[#1343](https://github.com/s977043/PlanGate/issues/1343)（Human Attention）

## 何を参考にするか

記事はNotion CTOのMax氏による仕事の3分類（まだ答えがない／成功パターンの横展開／正解が明確）を紹介する。Notionでの効果、PR採用率、失敗率、コストの独立した定量検証を提供するものではない。以下は**記事の実装仕様ではなくPlanGate側の候補解釈**。

| タスクの性質（参考分類） | 最小の進め方（候補） | 先に確認するEvidence |
| --- | --- | --- |
| 未知・探索 | Bounded Discovery → 仮説 → 小さなSpike → Plan Verification | Goal、Unknown、反証条件、影響範囲 |
| 再現パターンの横展開 | 既存パターンの出典確認 → 少数例で検証 → 適用範囲を限定 | 成功事例のrevision、変動点、回帰・受入テスト |
| 正解が明確 | 既存仕様・テスト・AC照合 → bounded execution → Verify | 期待値の独立性、現行revision、検証コマンド |

タスクの**性質**、変更の**危険度**、**実行権限**は別軸。高リスクな「正解が明確な仕事」が承認不要になるわけではない。分類不明・Evidence不足は `unknown` と明記し、探索へ戻して根拠を揃える。3分類を既存`taxonomy.md`のLifecycle State / Outcome / Stop Reason / Policy Verdictへ追加しない。

## 既存設計との対応

- 分類候補の入口は既存Plan PackageのGoal / Assumptions / Unknowns / Constraints。新しいLifecycle State、Router、authoritative schemaは設けない。
- ai-loop V2 `north-star.md`のBounded Discovery depth調整（uncertainty / impact / irreversibility / evidence quality）を使う。分類ラベルだけで実行・承認を変更しない。
- #911のContext Package / Work Itemでsource revision・AC・assumptionを引き渡す。#920のFactory方針を再実装しない。
- Verificationと判定を分離し、Builderの説明や自己評価を独立Evidenceとみなさない。
- C-3 / C-3' の現行policy、C-4 / merge（Human-owned）、HO-paths・権限境界を保持する。文書を置くこと自体にruntime enforcementはない。
- Discovery / Spike には C-3 の境界を適用する。**未承認の production code 変更は禁止**。read-only調査と、明示された承認範囲の隔離検証を区別し、Spikeを理由にHO領域や承認前変更へ進まない。
- Plan→Work Item→Runの引き渡しでは、分類理由を提案データとして扱い、risk_class / execution_profile / allowed_paths / AC を再推定・上書きしない。根拠が不十分ならunknownのまま停止・照会する。

## 最小検証（コード変更前）

1. 既存の完了Taskから、低リスク・再現可能で実施条件が明確な候補を事前選択する（機密情報を流用しない）。
2. タスク性質を**人間が理由・Evidence付きで暫定分類**し、分類不一致やunknownを記録する。自動判定は先行導入しない。
3. 同じ受入条件・リスク・モデル・effort・検証を揃え、従来の固定手順と分類に応じた手順を比較する（交絡を開示）。
4. 成功率・回帰・Evidence欠損・再作業・停止・総Token/Elapsedを追跡する。Human Attentionは**計測可能な場合だけ**active supervision time / 割り込みを独立記録し、`human_interventions`（介入回数）や経過時間から推定しない。使用量だけを効果とは扱わない。
5. 比較対象が揃わない、重大回帰や独立検証欠損があれば `INCONCLUSIVE` / stop。導入・自動実行へ進めない。

## 成立条件・残件

- [x] AIDLE記事の主張と独自適用解釈を分離し、既存責務への対応を整理（この文書）。
- [ ] #911でWork Item入力に分類根拠を持たせる必要性を、実タスクで検証する（新fieldを先に追加しない）。
- [ ] 代表タスクのAC / Verification / Risk・Stop・Human承認要件を事前固定する。
- [ ] DATの比較結果とRiver Reviewのレビュー深度評価を参照し、採用/見送りをHumanが判断する。
- [ ] 実導入する場合は別PR・再レビュー・CI / 負例テストを行う。**この文書のマージでは採用とみなさない**。

## セルフレビュー観点（独立承認ではない）

1. 元記事の報告と提案を分離したか／Factory効果を既成事実にしていないか。
2. タスク種別がリスク判定・Human authority・既存taxonomyを書き換えていないか。
3. 対照条件・評価指標・欠測・停止条件・責務ownerを定義しているか。

Cross-repo: [DAT #93](https://github.com/s977043/dynamic-agent-topology/issues/93)、[River Review #2034](https://github.com/s977043/river-review/issues/2034)。
