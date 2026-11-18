# Verification-First × PlanGate / River Review — 既存フローへの適応検討

> Status: **Discussion / Proposal / no runtime change**（2026-11-09）。承認前の設計記録であり、Core Contract、North Star、C-3/C-3'、C-4、Hook、Gate、Permission、HO の正本を変更しない。
> 対象: `s977043/PlanGate` の観測時 `main` = `9445df175e93fab31493274915bb35ab01cad4f1`。実装前には最新 HEAD と関連 Issue/PR を再取得する。
> 相互参照: `s977043/river-review` の `docs/development/verification-first-review-optimization-2026-11.md`（別 PR）。本書は PlanGate が管理する仕様・実行・承認境界だけを扱い、River Review の内部設計を複製しない。

## 1. 要点 / 本書の位置づけ

**検証能力を高めて人間と AI の重複レビューを減らせるかを実証する。ただし、証拠と承認を同一視しない。**

検討の発端は [kaito 氏の X 投稿（2026-11-08）](https://x.com/cu30rry_/status/2119388210057171374)。実 E2E・形式検証・決定論化を優先し、敵対的レビューのコストを減らすという方向を参考にする。一方、仕様・仮定が誤っていれば形式検証も全システムの正しさを保証できず、no-look merge の一般化は採用しない。独立したレビューが重大な不整合を見つけるケースもある（River Review #2875）。

適応方針:

1. **既存 North Star を正本のまま使う**。Builder != Verifier、Verifier != Decision Engine、Evidence before judgment、Repair != Replan。
2. **新しい Verification Gate / Evidence Gate を作らない**。既存 Plan Verification、Testing Strategy、L-0〜V-4、RunEvidence、評価 Trust Boundary へ不足分だけ結び付ける。
3. **レビューの一律削減はしない**。River Review の評価で、見逃し率・誤検知・Human Attention・コストの差が立証されたリスク区分だけ次段へ進める。
4. **承認権限は不変**。C-3' は既に承認された eligible policy profile の範囲のみ。C-4 / merge、HO、Policy / Permission、Protected Gate は Human-owned。

本書自体は AI が仕様や権限を変更する許可ではない。実装 Phase ごとに既存の C-3 / Human 判断を経る。

## 2. SSoT と Issue の重複解消

| 領域 | 現行 Owner / 正本 | 対応する検討 |
| --- | --- | --- |
| 実行・承認の原則 | `docs/ai/core-contract.md`、`docs/ai/project-rules.md` | 本書では編集せず、そのまま適用 |
| Verification-First の核心 | `docs/ai/ai-loop-v2/north-star.md`、[#870](https://github.com/s977043/PlanGate/issues/870) | Verifier-driven Delivery と Evidence-driven Evolution を再利用 |
| AI 自己評価の信頼境界 | `docs/ai/ai-loop-v2/evaluation-trust-boundary.md` | I0〜I4、Candidate が自分の evaluator を変更できない規律を維持 |
| 実行可能な検証戦略 | [#1430](https://github.com/s977043/PlanGate/issues/1430) | Self-Healing / E2E選定 / CI段階化 / Agentic E2E の不足差分を既存Issueで検討 |
| 状態遷移・再開時の不変条件 | [#1640](https://github.com/s977043/PlanGate/issues/1640) | 異常系の組合せ表を Plan の前段に追加するかを比較評価 |
| Fresh Context な計画レビュー | [#1618](https://github.com/s977043/PlanGate/issues/1618) | C-2 advisory として理解・実装準備の欠落を確認。新 C-2 Gate を追加しない |
| 実コマンド証拠 | `docs/ai/quality-command-evidence.md` | 既存 EvidenceItem / verification ledger を参照し、別 ledger は作らない |
| Runtime Evidence | [#1620](https://github.com/s977043/PlanGate/issues/1620) | 実ユーザーログ・原因仮説・再現テスト候補の分離（本件の初回実装範囲外） |
| Reviewer / Coverage / Risk | [River Review #2212](https://github.com/s977043/river-review/issues/2212)、[#2781](https://github.com/s977043/river-review/issues/2781)、[#2701](https://github.com/s977043/river-review/issues/2701) | River Review に判断材料の評価を依頼し、PlanGate は caller として扱う |

なお `docs/working/discussions/2026-06-11-governed-autonomy-river-review.md` は歴史的構想であり、その時点の自律承認案を現在の権限ルールへ自動昇格させない。現在の North Star、Core Contract、rollout policy を優先する。

## 3. Plan / Specification の質を上げる（検討案）

### 3.1 何を検証するかを実装前に固定する

計画段階の対象は、受入基準の文面だけでなく、次の追跡関係の **欠落を見つけること**。

`Goal / Problem -> Requirement -> Acceptance Criteria -> Plan decision -> Task -> Verification / Evidence`

通常の変更では、必要な検証に絞る。すべてに形式仕様や多段レビューを要求しない。仕様が曖昧なものは `unknown` を残して必要な discovery / Human decision を求める。AI がもっともらしい期待値を創作しない。

### 3.2 状態遷移・再開・権限などは反例を先に置く

[#1640](https://github.com/s977043/PlanGate/issues/1640) の検討例。以下は**形式の例示**であり、製品の新規必須テンプレートではない。

| 入力条件の例 | 期待する状態 / 不変条件 | 再開可能性 | 安価な妥当検証 |
| --- | --- | --- | --- |
| 正常完了、証拠・使用量が整合 | Completed / 正常な完了記録 | 条件に従う | Unit / Integration |
| 回収例外・部分的な証拠欠落 | 成功扱いにしない。欠落を記録 | 不整合が残る間は禁止 | 境界テスト・Fault injection |
| state と trace が矛盾 | 矛盾を補記だけで解消したとみなさない | 人間または正規復旧手順へ | Property / State transition test |
| 権限外 actor からの変更 | 許可境界で fail-closed | 自動続行不可 | Permission matrix / Security test |

重要なのは、表の項目数ではなく **要件に違反する具体的な反例を実装・テストが検出できること**。同種の指摘が繰り返される時にだけ表を追加する方式と、常時要求する方式を比較し、過剰な計画負荷を測る。

### 3.3 修復可能な HOW と、承認が必要な WHAT

| HOW：既存 Plan / AC の範囲で修復候補 | WHAT：要件・リスク・権限の変更として Replan 候補 |
| --- | --- |
| テストの locator、待機条件、fixture、モック、環境準備、再現手順の安定化 | 期待結果、業務ルール、受入基準、権限、価格、認証挙動、重大な user journey を緩める変更 |

HOW でも安全・scope・承認済み計画への影響を検査する。WHAT は単なる repair で書き換えず、既存の **Replan -> Plan Verification -> Plan Gate** に戻す。無限試行を避けるため、`NO_PROGRESS` / `REPEATED_FAILURE` / `OSCILLATION` / `BUDGET_EXHAUSTED` 等の既存 stop reason を使う。

## 4. Verification Strategy は既存レイヤーで最適化

| 層 | 主な対象 | 原則 |
| --- | --- | --- |
| L0 Static | lint、typecheck、構文、ルール | 決定論的で安価な検査を最初に実行 |
| L1 Logic | 計算、バリデーション、状態遷移、不変条件 | Unit / Property / 必要なら対象を絞った形式検証 |
| L2 Boundary | DB、API、権限、複数コンポーネント | Integration / Contract / 故障注入 |
| L3 Behavior | 重要な user journey | 再現可能な E2E と実アプリの証拠 |

[#1430](https://github.com/s977043/PlanGate/issues/1430) の PR / Merge・Release / Nightly の3層CI案も**設計候補**のまま扱う。Agentic E2E は探索・候補発見、決定論的 E2E は明示アサーションを持つ検証。Agentic E2E の報告だけで Gate の PASS にしない。

形式検証を追加するなら、適用範囲・仕様・環境仮定・実装との対応・証明ツールの version を確認する。形式仕様を AI 自身に生成させた場合、**仕様が要件を忠実に表現しているか**を別の観点で監査する。全アプリの無条件の正しさを宣言しない。

## 5. Evidence / Review / Decision の分離

```text
PlanGate: Requirement / Plan / Authorization
  -> Builder: Implementation artifacts
  -> Verifier: actual execution and evidence
  -> River Review: alignment / coverage / risk / independent findings
  -> PlanGate Caller: policy-bound continue / repair / replan / escalate
  -> MERGE_READY -> Human-owned C-4 / merge
```

River Review はレビュー用の判断材料を返す。PlanGate はその**実行有無・出所・対象 revision**を照合して caller 側の判断へ供給する。Review verdict は承認トークンでなく、検証失敗を覆すこともできない。

Evidence の受入時に確認したい属性（新 Schema を宣言するものではない）:

1. 対象の repo / commit SHA / Plan hash / Acceptance Criteria と証拠の紐付け。
2. 実行した verifier / command / exit / timestamp / environment と artifact refs。
3. `PASS` と required check 実行率 / skip / timeout / stale / not_executed を別に把握。
4. 仕様の忠実性、十分な negative controls、重要な未検証条件。
5. Independent Reviewer の実際の利用可否（別 context / actor / model など。未確認は unknown）。
6. security / irreversible / HO の hard floor と、Human approval が必要な理由。

これらは既存 canonical artifacts / RunEvidence / Review Coverage / caller report から導出できるものから始める。新しい authoritative artifact、独自DB、独自 Gate を増やさない。

## 6. 3群比較と合格条件

同一対象 SHA、同じ事前固定された受入基準・モデル条件・実行環境で、以下を比較する。別プロジェクトの [ai-agent-template #220](https://github.com/s977043/ai-agent-template/issues/220) は実装方式の PoC、River Review [#2701](https://github.com/s977043/river-review/issues/2701) は reviewer の人間確認済み ground-truth / paired replay の受け口とし、評価系を複製しない。

| A | B | C |
| --- | --- | --- |
| 現行の多段レビュー | Verification-First + 必要な独立レビュー | B + provenance / verification sufficiency / coverage の独立監査 |

必ず含めるケース: 低リスク docs、auth 1行変更、状態遷移の異常系、green unit test だが破壊的 migration、実行されなかった E2E、stale SHA、AI が期待値を実装に合わせるケース、reviewer timeout、CI job 起動失敗。

評価指標:

- 確認済み critical / major の見逃し件数と分母。重大な退行は**1件でも FAIL**。
- 誤検知 / 過剰エスカレーション、人間の確認時間、rounds-to-pass。
- Token・実費・wall time、修復の収束率、未実行率。
- 検証対象の coverage / negative control / mutation detection（実行母数と未実行を分ける）。
- Evidence provenance / current-head consistency / Human-owned boundary 逸脱の有無。

独立評価の条件、fixture、試行回数、コスト上限、critical regression、判定閾値を**候補の実装前に事前固定**する。実ケースが足りないときは `INCONCLUSIVE`、PASSにしない。結果を見てから基準を緩めない。

## 7. 実行順序（各段階は独立にレビュー・承認）

1. **Phase 0 — read-only Gap Analysis**: #1430、#1640、#1618、#870 と既存 artifact・gate の実体を再照合。River Review #2781/#2212 と必要最小の接続面を確認。本書は出発点であり、実装済み宣言ではない。
2. **Phase 1 — shadow evidence evaluation**: 既存 test / evaluation substrate で A/B/C を比較。Gate・C-3・C-4・Schema・Hook は不変。実行証拠・障害ケースを確認する。
3. **Phase 2 — advisory integration**: 同条件で改善し、重大な退行がゼロの時のみ、River Review の判断材料を既存 C-2/V-3/Caller の Decision Brief に提示。必要に応じて追加検証を推奨するが、権限を増やさない。
4. **Phase 3 — 限定的な深度最適化の採用判断**: 低リスク・可逆なケースから別 PR / Human decision で検討。Human-required を自動で downgrade しない。検証条件を変える場合は別評価とする。

**Gate / Verifier / Policy / Hook 自体の変更は高リスクな権威変更**。Evaluation Trust Boundary に従い適切な独立度（I3以上、Human-owned境界への接触はI4）と Human 判断を要求する。

## 8. 先行して確認する不具合・停止条件

River Review 側には [#2880](https://github.com/s977043/river-review/issues/2880)（detector へ届かない差分）、[#2870](https://github.com/s977043/river-review/issues/2870)（routing gap）、[#2812](https://github.com/s977043/river-review/issues/2812)（LLM未実行なのに clean 表示）がある。PlanGate 側には [#1641](https://github.com/s977043/PlanGate/issues/1641)（TASK / plan-hash 境界）と [#1642](https://github.com/s977043/PlanGate/issues/1642)（Codex/Cursor hook の実行非対称）がある。

これらが未解決の間も read-only / shadow 比較は行えるが、**レビューの自動省略・承認境界の変更は採用しない**。

残る**不確実性**は、テストで観測していない条件、形式仕様と本来の業務要件の忠実性、実CIでの hook / verifier の発火、異なるモデル・context の実効的な独立性、実運用でのコスト差である。これらを推測で埋めず、未測定は `unknown` / `INCONCLUSIVE` と記録する。

停止・Human escalation 条件:

- 観測が欠測なのに PASS / clean に写像される。
- Plan hash / target SHA が stale または出所が偽装・不明。
- 仕様の WHAT を repair が勝手に変更する。
- deterministic FAIL を LLM PASS が上書きする。
- HO、C-3、C-4、Permission / Policy、GitHubマージ保護に触れる。
- 同じ失敗の繰り返し、進捗なし、モデル費用上限超過、重要な見逃しの増加。

## 9. 後続エージェントへの引き継ぎ

次回はこの検討資料だけで作業開始せず、まず現行の [North Star](https://github.com/s977043/PlanGate/blob/main/docs/ai/ai-loop-v2/north-star.md)、[Core Contract](https://github.com/s977043/PlanGate/blob/main/docs/ai/core-contract.md)、[Evaluation Trust Boundary](https://github.com/s977043/PlanGate/blob/main/docs/ai/ai-loop-v2/evaluation-trust-boundary.md)、各 Issue/PR の latest head を読む。

初回の成果は **既存 Issue への不足・重複の対応表**と、事前固定した paired shadow 評価案。採用判断を補強できないうちは新規 Gate・Skill・Schema を作らない。Human に必要な判断は、(1) 事前固定した評価条件、(2) 評価結果、(3) 承認境界に影響する変更の可否、の3点に絞る。

**本書の記録は実装や検証の完了ではない。** プロジェクトの正式な設計変更は既存の承認フローに従う。
