# V2 Artifact Responsibilities — 責務分離・Event Projection・Optimistic Concurrency

> **Status**: Phase 0.1 canon（#1275）
> **North Star**: [`north-star.md`](./north-star.md) §5 / §6 / §7 / §10
> **Role**: [`phase0-migration.md`](./phase0-migration.md) §6 の artifact budget に含まれる各 artifact の責務境界を固定し、#894 の `LoopControlContract` を分解する。RunEvidence を event projection として位置づけ、RunState の並行制御を定める。詳細 schema は Phase 1。

## 1. 責務分離

| Artifact                                     | 責務                                                                                                                                                                      | 持たないもの                     | 可変性                                                    |
| -------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------- | --------------------------------------------------------- |
| **LoopContract**                             | Plan Package から導出される Run の契約: 受入基準・allowed scope・必須 Verifier・budget・task profile                                                                      | 現在位置・判定結果・停止理由     | Run 開始時に固定（Replan で新 revision）                  |
| **RunState**                                 | 現在位置（Lifecycle State）・`revision`・`pending_action`・`harness_manifest_ref`・`plan_hash` / `source_sha` binding                                                     | 判定ロジック・Evidence 本体      | mutable。revision CAS で進む（§4）                        |
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

`MERGE_READY` だけを Evolution の材料にしない。少なくとも次を projection の対象にし、pattern 検出（North Star §17）へ渡す。

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
