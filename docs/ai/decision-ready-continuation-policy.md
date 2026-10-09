# Decision-Ready Continuation Policy — 判断の準備と前進を分離する

> **Status**: Proposed living operating policy / 2026-10-10 — PRレビューと現行承認経路の適用前。自律度・実行権限を新たに付与しない
> **Scope**: PlanGateのIssue棚卸し、Discovery、Plan、Delivery、PRレビュー、運用改善への**横断的な判断ガイド**
> **Owner**: Human maintainer / established authority owner
> **Source of observation**: [Issue #1503 HOTL-oriented execution plan](https://github.com/s977043/PlanGate/issues/1503#issuecomment-6088658245) / [#1035 HOTL ladder recheck](https://github.com/s977043/PlanGate/issues/1035#issuecomment-6088629231)
> **Nature**: 新しいGate、Job、Schema、必須フォーム、独立の意思決定機関、権限委譲、既存ポリシーの代替ではない

## 1. 判断が残っていても、作業全体を止めない

> **Decision required != All work blocked.**
>
> **Prepare the decision, continue what is authorized, isolate the actual boundary.**

「人間の判断が必要」は、Issue全体を凍結するラベルではない。AIは**既に与えられた権限・変更範囲・実行契約の内側で**、再調査、事実確認、反証、代替案の比較、最小実験、検証、パッチ/PRの準備、次の実行可能な作業を進める。

人間には**問題の再調査作業ではなく、権限者しかできない実際の判断**を届ける。人間がその判断を保留しても、依存しない安全な作業は前進する。

これは**HITLを全面的にHOTLへ切り替える宣言ではない**。PlanGateの統制モデルは既存の[ai-loop design philosophy](./ai-loop/design-philosophy.md)に従う **HIC（枠を制定）＋HOTL（許可済みの範囲で監督）＋HITL（例外・保護境界）**の組合せ。依存する承認が無い実装を「先行可能」と称して実行しない。

## 2. 私たちが優先する4つの行動

1. **Context before escalation**: 現在の実装・Issue・PR・正本・承認履歴を確かめ、既決事項を再質問しない。事実、報告、推論、未確認を分ける。
2. **Continue within authority**: 実際に許された操作を小さく完了する。禁止操作の直前では、代替のread-only検証・patch作成・レビュー・独立した別タスクへ進む。
3. **Decision, not homework**: 人が判断する時は、推奨案・他案・Evidence・安全性・影響・戻し方・**求める具体的な1判断**を揃える。人にIssue全文の再読や調査のやり直しを要求しない。
4. **Feedback over ceremony**: 1回の完璧な計画より、検証可能な小さな前進と振り返り。毎回同じ資料・新しいチェックリスト・Gateを増やさない。手順が過重なら減らす。

アジャイル宣言を基礎とする外部ナレッジの扱いは [Practice Evolution Policy](./practice-evolution-policy.md) に従う。ここでは価値や承認条件を重複定義せず、**その価値を日常作業へ適用する行動選択**に絞る。

## 3. 「停止」ではなく「実行可能な境界」を見つける

以下は**運用上の説明モデル**であり、新しいLifecycle Stateや権限ロールではない。

| 観点 | AIが今できることの例 | 最後に越えてはいけない境界 |
| --- | --- | --- |
| **E0 — Observe** | 最新main SHAとIssue/PR/AC、出典、依存関係、リスクを確認。read-only解析と既存試験の結果を整理 | 秘密情報や他人の権限で実行、Evidenceの捏造 |
| **E1 — Prepare / low-risk upkeep** | 許可されたIssueのリンク・非破壊的な説明修正、既存ラベル分類、再現fixture/差分案、判断パケット | 人間所有のスコープ変更・認可状態・milestone commitmentをAIが確定しない |
| **E2 — Authorized execution** | **現在のC-3/C-3'、mode、allowed_paths等を実際に満たす場合だけ**小さく実装・テスト・独立レビュー・PR作成・修正し、MERGE_READYを目指す | 未承認のコード実装、HO適用、C-4・merge、policy/権限の自己変更 |
| **E3 — Handoff-ready** | HO patch・read-only preflight・リスク比較・人間の1操作用手順・rollbackとverifyを完成。依存しないE0〜E2へ移る | AI発行の「Human承認」や独立したExternal attestationを装わない |
| **E4 — Human / external operator** | 本人・権限を持つoperatorが本当の判断/適用/承認を行い、その証跡を参照する | AI自身が他者になりすまして判断・権限を発行しない |

**No implied permission**: E0/E1/E2という記号自体は実行許可ではない。書き込みの可否は[Core Contract](./core-contract.md)、[Project Rules](./project-rules.md)、[Responsibility Classes](../../.claude/rules/responsibility-classes.md)、[ai-loop rollout policy](../workflows/ai-loop/rollout-policy.md)、対象のPlan/承認履歴が決める。

例: C-3待ちの実装はその承認が成立するまで書かない。しかし仕様の衝突、テストの仮説、差分案、担当者が使う検証コマンド、別の独立Issueの調査は進められる。**CLI・Bash・環境変数・資格情報の切替を使ったGateの迂回は、前進ではない。**

## 4. 1つの判断を小さくする — Decision-Ready Handoff

人間への依頼は、既存Issue・PR・handoff・ADRの**その場所**に次を必要なだけ表現する。別のauthoritative artifactや必須テンプレートを作らない。

| 要素 | 伝える内容 |
| --- | --- |
| **Decision / owner** | 誰の何の判断か。既に許されている作業と分離して、Yes/Noまたは選択肢を具体化 |
| **Current facts** | 観測日時・main SHA・関連Issue/PR・既承認決定とその効力。reported/inferredはラベル付け |
| **Options / recommendation** | 現状維持も含む選択肢と、暫定推奨・採用理由・反証条件。外部の定石も無批判に適用しない |
| **Impact / risk** | 実装/運用コスト、失敗・回帰・不可逆性、境界、何が不明か。安全リスクを省略しない |
| **Already done** | AIが実測・準備・検証したもの。PR/テスト/独立レビューの**実在**する結果と未達AC |
| **Human-only step** | 必要なら誰がどの正本で何を操作するか、期待結果、失敗時停止/rollback、decision evidence |
| **Independent next actions** | 判断を待ってもAIが進めるタスク。依存先と再評価のきっかけ |

原則は **1 decision → short recommendation + evidence links**。長大な分析を人間に再実行させない一方、重要な否定的証拠・重大な反対意見を省かない（[Human Attention Architecture](../working/discussions/2026-09-22-human-attention-architecture.md) の **Compression != Suppression**）。

### 判断待ちを具体化する状態表現（記録例）

既存のIssueコメントに、例えば次の短い表現で十分。

```text
Now: VERIFIED / IN_PROGRESS / NOT_STARTED（対象を明示）
Already authorized: read-only review + negative fixture + patch proposal
Only blocked operation: apply Human-owned settings change
Decision needed: owner approves/rejects exact patch + risk
While pending: continue independent tests and related Issue review
Evidence: <actual issue / PR / commit / test refs>
Revisit: on new approval, changed main, failed test, or changed scope
```

この自由記述は運用の便宜であり、新しいステータス列挙、approval token、Human署名、CI通過条件ではない。

## 5. 既決事項を尊重し、独自の裁定を増やさない

- **承認済みの案は原則再審査しない**。判断時の前提が今も成立するかを照合し、未承認の**実行操作だけ**を切り出す。
- **候補を作ったことは権限の成立ではない**。レビューコメント、CI green、内部preflight、AIが生成したADR、runbookは、Human-owned判断や実行外部証跡に昇格しない。
- **Closed / not planned != implemented**。旧Epicの出口条件は、現在の目的に照らして新しいownerと検証条件を探す。旧コードを黙って復活させない。
- **保留が合理的な場合もある**。安全・利用者価値・独立性の実証がない場合は実施しない。ただし権限を要しない準備作業まで永久に停止させない。
- **Humanが不在だから許可したことにしない**。例外が許されるのは既存の正式なルールと実証済みの適格条件で許可されたときだけ。

## 6. PlanGateの具体的な適用例（2026-10-10の事実）

| Issue | 既知の状態 / 実際の前進 | AIが先に終えられること | 最終的に必要な判断 |
| --- | --- | --- | --- |
| [#1086](https://github.com/s977043/PlanGate/issues/1086) | A'（Codexの派生skillsをuntrack）がHuman承認済み、untrack操作H-2は別承認 | 既存ファイル/内容の保全、影響範囲の再計測、untrackのpreview、restore確認・PR下書き | **H-2の具体的な操作許可** |
| [#1144](https://github.com/s977043/PlanGate/issues/1144) | pluginへhooks/CLIを配らないという過去のHuman判断があり、技術的には配布可能と判明 | 現行配布・依存・利用者影響を実測し、方針維持案と変更案を比較 | **従来方針を変更するか** |
| [#1519](https://github.com/s977043/PlanGate/issues/1519) | 事後reviewと是正PR #1543のmergeは確認済み。過去のpre-merge承認不成立は消えない | 事故の事実・再発防止・未達ACを整理し、重複レビュー作業を減らす | **過去の承認逸脱に対する処置** |
| [#1437](https://github.com/s977043/PlanGate/issues/1437) | AIとHumanが同じadmin資格情報を利用できた実害がある | 最小権限のactor/credential matrix、403負側試験、実際の隔離案と復旧手順 | **資格情報分離/Ruleset適用** |
| [#1473](https://github.com/s977043/PlanGate/issues/1473) | ADR-007はProposed/NOT_MADE、構造的なP0準備は済んでいる | Option A/Bの候補比較、read-only preflight、nonce・issuer・admin分離の検証観点を完成 | **Humanが本当の独立管理主体を指定し、別operatorが操作** |
| [#1503](https://github.com/s977043/PlanGate/issues/1503) | Issueを108件確認し、初回2バッチで古い前提を修正 | 非破壊的な棚卸しを継続し、根拠を最新化、実行可能なnext stepを切り分ける | **明示的に保護されたscope変更・不可逆操作のみ** |

これらは**2026-10-10時点のスナップショット**。実行前に常に最新のIssue・main・正本を照合し、既決事項を不必要に再確認せず、変わった前提は記録する。

## 7. 失敗を早期発見し、運用を進化させる

**繰り返し**: 検討 → 異なる観点からのレビュー → 許可済みの小さな対応 → 実物・Evidenceのレビュー。何かを決定するための資料ができたら、**その資料が判断の負担を本当に減らしたか**を振り返る。

観測対象の例:
- Time to usable Evidence / Time to MERGE_READY。完成と偽らず、runの対象・基点を明示。
- Human Decision Wait（wall-clock）とHuman Attention（active cognitive time）を**別々**に計測。
- Humanに渡した判断依頼の追加質問、すでに存在するEvidenceの再調査、誤った「Human待ち」分類。
- Critical visibilityの欠落、誤Close・残AC漏れ、false green、rollback時間、実装の手戻り。
- Human依頼件数が減ったとしても**正しさ、安全性、重要Evidenceの見える状態が劣化したら採用しない**。

定義と測定上の注意は [Human Attention Metrics](../working/discussions/2026-09-23-human-attention-metrics.md) と [V2 North Star](./ai-loop-v2/north-star.md) を参照する。新しい監視ダッシュボードや個人評価KPIは作らない。測れていない改善を「効果あり」にしない。

**Process Evolution**: 小バッチでfrictionを1つ選び、必要なら運用上の適用方法を調整する（Keep / Adapt / Revert / Defer）。価値が立証されないなら新ルールを足さず、不要な手順を減らす。経験則と外部ナレッジの採用判断は [Practice Evolution Policy](./practice-evolution-policy.md) の範囲で扱う。

## 8. 境界・導入・非ゴール

**正本と責務の分離**:
- 原則・HIC/HOTL/HITL: [design-philosophy.md](./ai-loop/design-philosophy.md)
- ai-loop正規経路と権限条件: [00_concept.md](../workflows/ai-loop/00_concept.md) / [rollout-policy.md](../workflows/ai-loop/rollout-policy.md)
- HO / 実装とマージの責務: [responsibility-classes.md](../../.claude/rules/responsibility-classes.md)
- Human向け投影の圧縮・メトリクス: [Human Attention Architecture](../working/discussions/2026-09-22-human-attention-architecture.md) / [Metrics](../working/discussions/2026-09-23-human-attention-metrics.md)
- Issue運用の現在の正本: [issue-governance.md](./issue-governance.md)。具体例: [#1503](https://github.com/s977043/PlanGate/issues/1503)

**このポリシーだけで行わないこと**: C-3/C-3'の権限拡大・条件緩和、C-4/mergeの解禁、AIのHO patch適用、管理資格情報の切替、policy/ruleset変更、外部Verifierの自己承認、Issueの自動一括Close、WIP上限の強制導入。HOTL移行の段階と出口条件は [#1035](https://github.com/s977043/PlanGate/issues/1035)、merge解禁を検討する入口基準は [hotl-merge-entry-criteria.md](./ai-loop/hotl-merge-entry-criteria.md) がそれぞれ所有する。

### 変化の履歴

| 日付 | 観測・提案 | 判定 / 次の検証 |
| --- | --- | --- |
| 2026-10-10 | #1503の棚卸しで、Human判断を一律停止理由にすると既決事項・安全な調査・PR準備まで滞留することを特定 | **提案**: Decision-Ready Continuationを運用上の選択のガイドにする。効果未計測 |
| 2026-10-10 | #1035出口条件にclosed/not planned参照が残存。#1086には方針承認済みだが実行承認別の例 | 歴史的事実と現在の実行許可を分離。Issueの実装完了やHOTL解禁を主張しない |
