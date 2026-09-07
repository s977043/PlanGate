# V2 Artifact Responsibilities — 責務分離・Event Projection・Optimistic Concurrency

> **Status**: Phase 0.1 canon（#1275）
> **North Star**: [`north-star.md`](./north-star.md) §5 / §6 / §7 / §10
> **Role**: [`phase0-migration.md`](./phase0-migration.md) §6 の artifact budget に含まれる各 artifact の責務境界を固定し、#894 の `LoopControlContract` を分解する。RunEvidence を event projection として位置づけ、RunState の並行制御を定める。詳細 schema は Phase 1。

## 1. 責務分離

| Artifact                                     | 責務                                                                                                                                                                      | 持たないもの                     | 可変性                                                    |
| -------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------- | --------------------------------------------------------- |
| **LoopContract**                             | Plan Package から導出される Run の契約: 受入基準・allowed scope・必須 Verifier・budget・task profile                                                                      | 現在位置・判定結果・停止理由     | Run 開始時に固定（Replan で新 revision）                  |
| **RunState** | 現在位置（Lifecycle State）・`revision`・`pending_action`・`policy_verdict`（現在値）・`harness_manifest_ref`・`plan_hash` / `source_sha` binding・`resumed_from_run_id`（BLOCKED 後の新 Run 連結） | 判定ロジック・Evidence 本体 | mutable。revision CAS で進む（§4） |
| **VerificationResult**                       | 1 Verifier の 1 回の出力: `verifier_id` / `kind` / `status: pass \| fail \| unavailable \| inconclusive` / evidence refs / bound artifact hash                            | 継続判断・Outcome                | immutable。artifact hash / source SHA / head SHA に束縛   |
| **FailureRecord**                            | 失敗の正規化: observation / failure fingerprint / evidence refs / cause hypothesis / repairability / result                                                               | 判定                             | immutable。observation と cause hypothesis を別フィールド |
| **Decision Engine**（artifact ではなく責務） | LoopContract + RunState + VerificationResult 群 + FailureRecord 群 + Policy Verdict から **continue / repair / replan / stop** と Terminal Outcome + Stop Reason を決める | artifact の生成・Verifier の実行 | 決定は RunEvent（`decision_made`）として記録              |
| **RunEvidence**                              | 1 Run の deterministic projection（§3）                                                                                                                                   | 唯一の mutable source of truth   | 再生成可能。event stream から導出                         |
| **HarnessImprovementCandidate**              | 1 Candidate = 1 Hypothesis（North Star §13）+ evaluation plan digest                                                                                                      | baseline の identity 定義        | Candidate 作成後、evaluation plan は不変                  |
| **HarnessExperimentResult**                  | baseline / candidate の paired 比較結果・activation・Promotion Decision                                                                                                   | Promotion の実行                 | immutable                                                 |
| **PromotionDecision**                        | `PASS \| FAIL \| INCONCLUSIVE` と根拠                                                                                                                                     | merge / 適用                     | Human-owned の最終 Promotion とは別                       |
| **HarnessManifest**                          | Harness identity（[`harness-manifest.md`](./harness-manifest.md)）                                                                                                        | Run の状態                       | immutable・content-addressed                              |

原則:

- **Builder != Verifier != Decision Engine**。Builder は artifact を作り、Verifier は VerificationResult を作り、Decision Engine だけが Outcome を決める。
- **Verifier != Decision Engine**: VerificationResult に `blocking` を持たせてよいが、「継続するか」は Decision Engine が決める。
- deterministic verifier の `fail` は、上位層（independent reviewer / policy gate）の `pass` で上書きできない。Decision Engine はこの順序を規則として持つ。

## 2. #894 `LoopControlContract` の分解

Issue #894 が 1 つの `LoopControlContract` に置いていた要素を上表へ写像する。**問題設定（Verifier 階層・停止予算・進捗判定・採用コスト）は維持し、artifact だけ分解する。**

| #894 の要素                                                                                         | V2 artifact                                                              |
| --------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------ |
| `stage` / `attempt` / `state: running \| verifying \| repairing \| stopped`                         | RunState（Lifecycle State は [`taxonomy.md`](./taxonomy.md) §2）         |
| `artifact_refs.{plan_hash, source_sha, head_sha}`                                                   | RunState の binding                                                      |
| `artifact_refs.harness_version`                                                                     | RunState `harness_manifest_ref`                                          |
| `budgets.*`                                                                                         | LoopContract                                                             |
| `progress.*`（fingerprint / evidence delta / blocker delta）                                        | Decision Engine の入力。値は RunEvent から導出                           |
| `verifier_results[]`                                                                                | VerificationResult（1 件 1 artifact）                                    |
| `termination.decision` / `reason_code`                                                              | Terminal Outcome + Stop Reason（RunEvent `decision_made` → RunEvidence） |
| `metrics.*`                                                                                         | RunEvidence（projection で算出）                                         |
| Verifier 階層（deterministic → specification → independent reviewer → policy gate → loop decision） | Decision Engine の評価順序規則。**不変**                                 |
| 必須 fixture 12 本                                                                                  | Phase 1 の Decision Engine fixture として **KEEP**                       |

## 3. RunEvidence = deterministic event projection

```text
RunEvent stream（append-only）
  -> deterministic projection（同じ stream からは同じ結果）
  -> RunEvidence
```

| 要素            | 内容                                                                                                                                                                                                                                                                                                   |
| --------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| RunEvent stream | append-only の event 列。V2 の RunEvent 型（`decision_made` / `component_selected` / `component_fired` / Outcome / Stop Reason / Policy Verdict を運ぶ）は **Phase 1 で V2 側に定義**する。既存 `docs/working/_metrics/events.ndjson`（`schemas/plangate-event.schema.json` は event 12 種・`additionalProperties: false`）と `<task_dir>/delivery/record.jsonl`（`scripts/ai-loop/delivery.py`）/ `decision-log.jsonl` は **metrics / phase 遷移の補助入力**として projection に読めるが、Legacy schema へ V2 event 型を追加しない |
| projection      | 純関数。入力 = event stream + HarnessManifest ref。出力 = RunEvidence。timestamp・順序以外の外部状態を読まない                                                                                                                                                                                         |
| RunEvidence | 1 Run の要約。`harness_manifest_ref` / `outcome` / `stop_reasons[]` / `policy_verdicts[]`（Run 中の Verdict 履歴。RunState が持つ現在値 `policy_verdict` とは別）/ VerificationResult refs / FailureRecord refs / metrics / evidence refs / `evidence_status: ready \| partial \| invalid` |

原則:

- **RunEvidence を唯一の mutable source of truth にしない**。正本は event stream。RunEvidence は再生成可能なキャッシュ。
- 同一 event stream から同一 RunEvidence を再生成できること（#874 AC「同一入力 events から同一 RunEvidence を再生成できる」を KEEP）。
- **completed run だけを前提にしない**。projection は途中の stream からも部分 RunEvidence（`evidence_status: partial`）を出せる。`ready` は projection が Outcome まで到達し `harness_manifest_ref` を持つ場合、`invalid` は stream の欠損・改竄・binding 不一致を検出した場合（Legacy `complete / partial` とは値域が異なる。V2 schema は Phase 1）。

### Evolution input に含める Run

`MERGE_READY` だけを Evolution の材料にしない。少なくとも次を projection の対象にし、pattern 検出（North Star §2 の Evolution Loop 責務 `Run -> RunEvidence -> Retrospective -> Pattern / Friction / Success`）へ渡す。

| 入力                                                          | 何が学べるか                                  |
| ------------------------------------------------------------- | --------------------------------------------- |
| `HUMAN_ESCALATED` / `BLOCKED`                                 | 止まった理由（Stop Reason）の分布・境界の摩擦 |
| `WAITING_HUMAN` / `WAITING_EXTERNAL` の滞留                   | Human intervention rate・外部依存             |
| crash / 中断（stream が途中で終わる）                         | Durable Run State の欠陥・resume 契約の穴     |
| `NO_PROGRESS` / `REPEATED_FAILURE` / `OSCILLATION`            | Repair 戦略・Verifier の検出力                |
| `VERIFIER_UNAVAILABLE`                                        | Verifier の可用性・fail-closed の頻度         |
| duplicate action prevented（intent 済み action の再発行抑止） | intent / receipt 契約の効果                   |
| replan（`REPLANNING` への遷移）                               | Plan の品質・Plan Verification の検出力       |

## 4. RunState の Optimistic Concurrency（#1025 hardening）

2 Agent / 2 Session が同じ Run を同時に resume した場合、last-write-wins を許さない。

```text
read RunState (revision = N)
  -> decide transition（純関数）
  -> compare-and-swap(expected_revision = N, new_state, revision = N + 1)
       success -> proceed
       mismatch -> STATE_CONFLICT（fail-closed。書かない・再試行しない・Human または再 read）
```

原則:

- **revision は単調増加**。後退・同値上書きは拒否（#1025 AC-6 と一貫）。
- CAS の失敗は Stop Reason `STATE_CONFLICT` として記録し、RunEvent に残す。
- 複数プロセスからの CAS は **ファイルロック等の inter-process 排他 + atomic rename** で実装する（#1025 C-2 finding 1「multi-process CAS には inter-process lock が要る」を AC に昇格）。
- **intent → external action → receipt の idempotency は維持**。CAS は RunState の遷移を守り、intent / receipt は外部副作用の重複を守る。両者は別の契約。
- Human-owned approval artifact の発行経路は変えない。

### 必須 fixture（#1025 へ追加）

| fixture                                                          | 期待                                                             |
| ---------------------------------------------------------------- | ---------------------------------------------------------------- |
| concurrent resume: 2 writer が同じ revision N を読み、両方が CAS | ちょうど 1 つが成功し revision N+1、もう 1 つは `STATE_CONFLICT` |
| stale writer: revision N−1 を持つ writer が CAS                  | `STATE_CONFLICT`。state は変わらない                             |
| CAS 成功後に同じ writer が同じ revision で再 CAS                 | `STATE_CONFLICT`（冪等ではなく明示失敗）                         |
| crash between decide and CAS                                     | 次の reader は revision N のまま。pending_action は増殖しない    |

## 5. Legacy との関係

| Legacy                                                                                             | 扱い                                                                                                                |
| -------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| `docs/workflows/ai-loop/run-evidence-contract.md`（producer 24 キー・受理器・privacy 禁止キー 14） | reusable pattern。特に privacy 禁止キーと「受理器が生成側の申告を信頼しない」規則は V2 projection でも KEEP         |
| `docs/schemas/run-evidence.schema.json`                                                            | Legacy schema。変更しない。V2 RunEvidence schema は Phase 1 で別に定義し、`terminal_state` → `outcome` の写像を持つ |
| `scripts/ai-loop/run_evidence.py` / `run_evidence_verify.py`                                       | Legacy 実装。projection の参照実装として読む。変更しない                                                            |
| `docs/workflows/ai-loop/delivery-state-machine.md` の `record.jsonl`                               | PR_CONVERGING 内部の event 源として再利用可                                                                         |

## 6. 測定契約（North Star §18 の 3 系統）

> North Star §18 が要求する 3 系統の評価軸について、**測定契約**（何をどう測るか）を定める。
> **本節は設計であり、collector / schema の本実装は Phase 1**（追跡: #1285）。
> §5 のとおり **Legacy schema は拡張しない**。必要な時刻フィールドは **V2 RunEvidence schema**（Phase 1 で新規定義）に持たせる。

### 6-1. 欠測語彙は既存の 3 層をそのまま使う（新語を作らない）

| 語                         | 層                                                                    | 意味                                                                        | 誰が付けるか |
| -------------------------- | --------------------------------------------------------------------- | --------------------------------------------------------------------------- | ------------ |
| `"unavailable"`            | **フィールド値**                                                      | そのフィールドの供給元が構造的に無い / 解決できない                         | producer     |
| `INCONCLUSIVE`             | **Promotion Decision の判定値**（§`evaluation-trust-boundary.md` §5） | 評価が成立しない。判定を下せる evidence が揃わない。**`PASS` 側へ倒さない** | 評価系       |
| `evidence_status: partial` | **受理器が導出する判定**                                              | projection が部分的にしか成立しない。**生成側が自己申告してはならない**     | 受理器       |

**層が違うため競合しない。** 3 系統の新指標にもこの 3 層をそのまま使う。

**観測できない値を `0` や成功として扱わない。** これは Legacy 契約に既にある規則で（`run-evidence-contract.md` の
「`0` で埋めてはならない」および `--pr-number` を `0` に倒す fail-open 経路を禁じた実測）、V2 でも維持する。

**仮説の棄却・Candidate の不採用**（妥当な Evidence に基づく学習）と、**評価不成立**（`INCONCLUSIVE`）を区別する。
前者は Evidence が揃ったうえでの結論、後者は Evidence が揃わなかったこと。混同すると、
評価が成立しなかった Candidate を「不採用と判断した」と記録してしまう。

### 6-2. 3 系統の測定契約

| 項目                    | Time to Learning                                                                                                                                                                    | Evidence 取得後の意思決定待ち時間                                                         | 失敗の検知 / 影響 / 復旧 / 再発                                                    |
| ----------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------- |
| **測定目的**            | 問題の観測 → 判断に必要な妥当な Evidence 取得までの時間を短くする                                                                                                                   | Evidence はあるのに判断が滞る時間を可視化する                                             | 誤りを前提に、早期検知・影響限定・復旧・再発防止を可能にする                       |
| **対象**                | **Product 側 / Harness 側の両方**（両者を混同しない。North Star §1 の定義に従い、Product 側 = 価値仮説の学習条件、Harness 側 = §14 の評価成立）                                     | **主に Harness 側**（Run 内の Human 待ち）。C-4 以降の待ちは Run の外                     | **両方**。Harness 側 = Verifier FAIL / Stop Reason、Product 側 = リリース後の障害  |
| **起点**                | **未定（Phase 1）**。「問題の観測」を刻む RunEvent が現行に無い（Legacy の `state` entry は delivery 層の状態遷移であって観測ではない）。V2 RunEvent 型の定義（§3）と同時に確定する | `VerificationResult` の生成時刻（**Phase 1 artifact**。現行に無い）                       | 検知 = failure の**発生**時刻（現行の 24 properties のいずれにも対応概念が無い）   |
| **終点**                | **判断に必要な妥当な Evidence の取得時点**。**その後の意思決定待ち時間とは分ける**（North Star §18）                                                                                | Human の判断確定時刻                                                                      | 復旧 = repair 完了時刻（Legacy の `repair_rounds` は**回数のみで時刻を持たない**） |
| **単位**                | **未定（Phase 1）**。暦時間 / round 数 / iteration 数のいずれか。round 数なら Legacy `repair_rounds` で近似可、暦時間なら不可                                                       | 暦時間（それ以外では「待ち」を表現できない）                                              | 検知・復旧 = 時間 / **影響 = 未定（後述）** / 再発 = 回数                          |
| **集計対象**            | **1 Run 内**                                                                                                                                                                        | 1 Run 内                                                                                  | **再発は本質的に Run 横断** → 後述の禁止に従い RunEvidence に載せない              |
| **必要な event**        | 「問題の観測」を刻む RunEvent（Phase 1）                                                                                                                                            | `WAITING_HUMAN` の進入 / 離脱の 2 event（State は `taxonomy.md` にあるが event は未定義） | failure 発生 event + 復旧 event。`FailureRecord`（§1 の artifact）の生成時刻       |
| **欠測時**              | 6-1 の 3 層に従う。**`0` で埋めない**                                                                                                                                               | 同左                                                                                      | 同左                                                                               |
| **直接観測 / 外部受領** | Harness 側は**直接観測**。**Product 側は外部受領**（North Star §18「V2 が直接観測できる範囲と外部から受け取る Evidence を区別する」/ §19 Non-goals）                                | **直接観測**（Run 内の Human 待ち）。C-4 以降は Run の外 = 外部受領                       | 検知・repair は直接観測。**リリース後の影響・再発は外部受領**                      |
| **保存・算出の責務**    | 保存 = **event stream（正本）** / 算出 = **projection（純関数、§3）**。RunEvidence は再生成可能なキャッシュであり mutable source of truth にしない                                  | 同左                                                                                      | 同左。**Run 横断の再発率は RunEvidence の外**                                      |

### 6-3. Run 横断の集計を RunEvidence に載せない

`recurrence`（再発）は本質的に Run 横断だが、**RunEvidence に載せてはならない**。Legacy 契約が
「corpus 集計値を載せると、arbiter record が 1 件増えるだけで**過去 run の RunEvidence の byte が変わる**」として
禁じており（`run-evidence-contract.md`）、V2 の projection も同じ性質を要する（§3 の「同一 event stream から
同一 RunEvidence が再生成される」が壊れる）。**集計は上位層の責務**とする。

### 6-4. 未定として残すもの（Phase 1 / 後続 issue）

| 項目                           | 理由                                                                                                                                                                                                                     |
| ------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `Time to Learning` の**起点**  | 「問題の観測」を刻む RunEvent が現行に無い。V2 RunEvent 型の定義と同時に確定する                                                                                                                                         |
| **影響（impact）の定義・単位** | 正本のどこにも定義が無い。何をもって「影響」とするかを決めないと単位を選べない                                                                                                                                           |
| 各フィールドの**供給元**       | Legacy 契約は「`now()` を直接参照しない。すべての timestamp は注入」と定めており、**フィールドを増やしても供給経路が無ければ値は入らない**。V2 は event stream から取るのか注入かを、フィールドごとに Phase 1 で確定する |

**未定を「測れる」と書かない。** 上表の「未定」は #1285 の Acceptance Criteria が要求する記載であり、
埋まっていないこと自体が Phase 1 への引き継ぎ事項である。

## 7. 学習条件と Delivery Contract の接続

> North Star §1 が定義する **価値仮説 / 学習条件 / 観測条件 / Evidence の返却先** の**保持先**を定める。
> **新 artifact を増やさない**（North Star §11「Component を増やすこと自体を進化と定義しない」/ §6 artifact budget）。

### 7-1. 保持先

既存の **Plan Package**（`pbi-input.md` / `plan.md` / `todo.md` / `test-cases.md` / `review-self.md` / `review-external.md`
の 6 要素全数必須）に置く。**6 要素の `artifact_hashes` と `plan_package_hash` が既に存在する**ため、
節を追加すれば**束縛 hash は既存機構でそのままかかる**（新 hash 機構も新 artifact も不要）。

| 概念                  | 保持先                                                                    | 根拠                                                                                                                                                                          |
| --------------------- | ------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **価値仮説**          | `pbi-input.md`（Context / Why・Assumptions）                              | 既存節に自然に収まる。複数仮説を分離参照するなら**仮説 ID の採番**が要る（運用規約）                                                                                          |
| **学習条件**          | `plan.md` の**新 subsection**（既存の Success Criteria とは**別に**置く） | North Star §1 は学習条件を受入基準と**別物**と定義している。既存 Success Criteria は「AC ↔ test case ID」の写像のみで、「何を・どの母集団で・どの水準で観測するか」を持てない |
| **観測条件**          | `plan.md` の同 subsection                                                 | 既存 Verification Plan は **Harness 側 verifier の観測条件**であり、Product 側の母集団・観測期間・水準を書く場所が無い                                                        |
| **Evidence の返却先** | `plan.md` の同 subsection（**識別子のみ**）                               | 詳細は 7-3                                                                                                                                                                    |

**LoopContract 側は導出規則の追加のみ**とする（§2 のとおり LoopContract は Plan Package から導出される）。

### 7-2. Plan Verification が「学習条件の変更」を機械判定するための最小構造

North Star §9 は学習条件の変更を Replan / Plan Verification / Plan Gate 通過のトリガにしているが、
**現行の束縛 hash では判定できない** — `plan_hash` は `plan.md` **全体**の hash なので、
typo 修正でも変わり（偽陽性）、学習条件を別ファイルに書けば検出できない（偽陰性）。

最小構造は 3 点:

1. **学習条件を安定 ID 付きの列挙単位にする**（既存の `R-NNN` / AC 番号と同じ運用）。ID があって初めて「どの条件が変わったか」を差分で言える
2. **その列挙の正規化表現に対する section-level hash** を `plan_hash` とは**別に**持つ。導出は既存の `canonical_hash()` を再利用する（独自 hash 実装を作らない）
3. **承認 record に additive に刻む**（既存の optional フィールドと同じパターン）

これで `plan_hash` 不一致（= 何かが変わった）と学習条件 hash 不一致（= Replan トリガ）を**分離**できる。

**注意**: `artifact_hashes` は 6 要素全数必須なので、**学習条件を新ファイルに切り出すと 6 要素契約に触れる**。
`plan.md` の節に置いて section hash を取る方が既存契約を壊さない。

### 7-3. 境界を壊さないための制約（重要）

| 制約                                                           | 理由                                                                                                                                                                                                                                      |
| -------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **学習条件を Verifier pipeline の blocking rule に接続しない** | 接続すると、学習条件が満たされるまで `MERGE_READY` に到達しなくなり、**Delivery の終端が価値検証完了へ移動する**。学習条件は「LoopContract に**記録され**、Replan トリガの**入力になる**」に留め、`VerificationResult` を生む対象にしない |
| **Evidence の返却先は「置く先の宣言」に留める**                | V2 が値を**取りに行く**先として定義すると、Product Discovery の orchestration を内包することになり North Star §19 Non-goals を侵す                                                                                                        |
| **返却先の識別子を RunEvidence に入れない**                    | 外部 URL を持たせると privacy 検査（URL 削減）と衝突する。**plan 側に識別子を置き、RunEvidence には入れない**                                                                                                                             |
| **`MERGE_READY` の意味を変えない**                             | Delivery の終端は `MERGE_READY` を維持する。実装の完成を価値仮説の検証完了とみなさない（North Star §2 / `taxonomy.md` §3）                                                                                                                |

### 7-4. Phase 1 で確定するもの

LoopContract / VerificationResult / FailureRecord / RunEvent の schema は Phase 1 で定義するため（§1）、
**4 概念の最終的なフィールド名は現時点で確定できない**。本節が固定するのは**保持先の方針と境界条件**であり、
フィールド定義は Phase 1 の設計項目である。
