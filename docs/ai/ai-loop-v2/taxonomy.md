# ai-loop V2 Taxonomy — 4 軸の分離（Lifecycle State / Terminal Outcome / Stop Reason / Policy Verdict）

> **Status**: Phase 0.1 canon（#1275）
> **North Star**: [`north-star.md`](./north-star.md) §8 / §20
> **Role**: V2 の Run を記述する語彙を 4 つの直交軸に固定する。Legacy ai-loop の語彙とは境界を分け、V2 namespace では混在を禁止する。

## 1. なぜ分離するか

Legacy ai-loop では `AUTO_APPROVED / HUMAN_ESCALATED / BLOCKED` が「裁定結果」「Run の終端」「停止理由」を兼ね、`no_progress` や `budget_exhausted` が state と decision の両方に現れた（#894 の `termination.decision` enum、#1025 の `status` enum、#869 の内側ループ成果）。1 つの enum に「今どこにいるか」「どう終わったか」「なぜ止まったか」「Policy が何と言ったか」を詰めると、Agent ごとに解釈が分かれ、RunEvidence の比較が成立しない。

V2 では次の 4 軸を**別フィールド**で持つ。

| 軸                   | 問い                         | 値域の性質                    |
| -------------------- | ---------------------------- | ----------------------------- |
| **Lifecycle State**  | Run は今どこにいるか         | 非終端。遷移する              |
| **Terminal Outcome** | Run はどう終わったか         | 終端。1 Run に高々 1 つ       |
| **Stop Reason**      | なぜ継続できなかったか       | Outcome の根拠。複数可        |
| **Policy Verdict**   | Policy Gate は何と判定したか | Gate の出力。Outcome ではない |

## 2. Lifecycle State

| State              | 意味                                                                                       |
| ------------------ | ------------------------------------------------------------------------------------------ |
| `PLANNING`         | Plan / LoopContract を作成中                                                               |
| `PLAN_VERIFYING`   | Initial Plan Verification（Requirements / Design / Technical / Research evidence）を実行中 |
| `EXECUTING`        | Builder が artifact を作成中                                                               |
| `VERIFYING`        | Verifier pipeline を実行中                                                                 |
| `DIAGNOSING`       | Verify FAIL の観測を FailureRecord に正規化中                                              |
| `REPAIRING`        | Plan は有効。artifact を修正中                                                             |
| `REPLANNING`       | Plan が無効。Plan を作り直し中（完了後は `PLAN_VERIFYING` へ戻る）                         |
| `PR_CONVERGING`    | PR 作成後の CI / review / conflict 収束中                                                  |
| `WAITING_HUMAN`    | Human action（C-3 / 判断 / 承認）待ち                                                      |
| `WAITING_EXTERNAL` | 外部（CI / provision / API）待ち                                                           |

原則:

- State は **進行中の位置**だけを表す。`NO_PROGRESS` / `BLOCKED` / `MERGE_READY` を State にしない。
- `WAITING_*` は停止ではなく待機。再開条件は RunState の `pending_action` が持つ。
- Legacy の PR サブステート（`WAITING_FOR_CHECKS` / `CHECKS_FAILED` / `REVIEW_REPAIR` / `CONFLICT` / `MERGE_READY_CANDIDATE`）は `PR_CONVERGING` の内部詳細として再利用してよいが、V2 の Lifecycle State 値域には昇格させない。

## 3. Terminal Outcome

| Outcome           | 意味                                                               |
| ----------------- | ------------------------------------------------------------------ |
| `MERGE_READY`     | Delivery 契約を満たし、C-4 / merge（Human-owned）待ちで停止        |
| `HUMAN_ESCALATED` | AI では継続できず、Human の判断へ返した                            |
| `BLOCKED`         | 外部条件・権限・境界により継続不能。Human 判断ではなく条件解除待ち |

原則:

- Outcome は **Delivery Run の終端**であり Policy の裁定ではない。`AUTO_APPROVED` は Outcome にならない。
- `HUMAN_ESCALATED` / `BLOCKED` は必ず 1 つ以上の Stop Reason を伴う。
- `MERGE_READY` は Stop Reason を伴わない（正常終端）。

## 4. Stop Reason

| Reason                 | 意味                                                                  | 検出主体                      |
| ---------------------- | --------------------------------------------------------------------- | ----------------------------- |
| `NO_PROGRESS`          | iteration 間で evidence delta / blocker delta / artifact delta が無い | Decision Engine               |
| `REPEATED_FAILURE`     | 同一 failure fingerprint が閾値回反復                                 | Decision Engine               |
| `OSCILLATION`          | resolved → reintroduced → resolved の往復、または修正 A/B の反復      | Decision Engine               |
| `BUDGET_EXHAUSTED`     | iteration / time / token / cost / repair round の上限到達             | Decision Engine               |
| `POLICY_DENIED`        | Policy Verdict が `DENIED`                                            | Policy Gate                   |
| `VERIFIER_UNAVAILABLE` | 必須 Verifier が実行不能・判定不能（fail-open しない）                | Verifier pipeline             |
| `REQUIREMENT_CONFLICT` | 受入基準同士、または Plan と受入基準が矛盾                            | Plan Verification / Diagnoser |
| `STATE_CONFLICT`       | RunState の revision CAS 失敗（並行 resume 等）                       | RunState store                |

原則:

- Stop Reason は **Outcome の理由**であり、State でも Outcome でもない。
- 1 つの Outcome に複数の Reason を付けてよい（例: `BUDGET_EXHAUSTED` + `REPEATED_FAILURE`）。
- Reason は FailureRecord / RunEvidence に evidence refs 付きで残す。

## 5. Policy Verdict

| Verdict          | 意味                                                                                        |
| ---------------- | ------------------------------------------------------------------------------------------- |
| `AUTO_APPROVED`  | Policy profile の範囲内で Human 承認なしに次段へ進んでよい                                  |
| `HUMAN_REQUIRED` | Human の判断が必要（→ State `WAITING_HUMAN`。Human が拒否すれば Outcome `HUMAN_ESCALATED`） |
| `DENIED`         | Policy が禁止（→ Stop Reason `POLICY_DENIED`）                                              |

原則:

- Verdict は **Policy Gate の出力**であり、Delivery の成功と同一視しない（`Loop Execution != Auto Approval`）。
- `AUTO_APPROVED` は C-3' 等の **optional autonomy / policy profile** の語彙。V2 Core の Delivery 成立条件にしない。
- deterministic verifier の FAIL を Verdict で上書きできない。Verdict は Verifier evidence の**後**に評価される。

## 6. 組み合わせ規則

### 許容例

```yaml
state: WAITING_HUMAN # 進行中
policy_verdict: HUMAN_REQUIRED
```

```yaml
outcome: HUMAN_ESCALATED
stop_reasons: [NO_PROGRESS]
policy_verdict: HUMAN_REQUIRED
```

```yaml
outcome: BLOCKED
stop_reasons: [VERIFIER_UNAVAILABLE]
```

```yaml
outcome: MERGE_READY
stop_reasons: []
policy_verdict: AUTO_APPROVED # profile が許す場合のみ。無くても MERGE_READY は成立する
```

### 禁止例（V2 namespace では invalid）

```yaml
state: NO_PROGRESS # Stop Reason を State にしている
```

```yaml
outcome: AUTO_APPROVED # Policy Verdict を Outcome にしている
```

```yaml
state: MERGE_READY # Outcome を State にしている
```

```yaml
policy_verdict: MERGE_READY # Outcome を Verdict にしている
```

```yaml
outcome: HUMAN_ESCALATED # Reason が無い
stop_reasons: []
```

## 7. Legacy 語彙との境界

| Legacy の用法                                                                                                                                          | V2 での読み替え                                                                                                                                   |
| ------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| C-3' arbiter の `AUTO_APPROVED / HUMAN_ESCALATED / BLOCKED`（`scripts/ai-loop/arbiter.py`、`docs/workflows/ai-loop/**`）                               | `AUTO_APPROVED` → Policy Verdict。`HUMAN_ESCALATED` / `BLOCKED` → Terminal Outcome。Legacy 実装は変更しない                                       |
| #1025 の `status: RUNNING / WAITING_HUMAN / WAITING_EXTERNAL / BLOCKED / COMPLETED`                                                                    | `RUNNING` → Lifecycle State 群、`WAITING_*` → State、`BLOCKED` → Outcome、`COMPLETED` → Outcome（`MERGE_READY` 等）へ分解                         |
| #894 `termination.decision: continue \| success \| blocked \| human_escalated \| budget_exhausted \| no_progress \| repeated_failure \| policy_denied` | `continue` → Decision Engine の継続判断（Outcome ではない）、`success` → `MERGE_READY`、`blocked / human_escalated` → Outcome、残り → Stop Reason |
| Legacy RunEvidence schema `terminal_state`（`docs/schemas/run-evidence.schema.json`）                                                                  | 値域は V2 Terminal Outcome と一致。名称は V2 では `outcome`。Legacy schema は変更しない                                                           |
| `docs/workflows/ai-loop/delivery-state-machine.md` の PR サブステート                                                                                  | `PR_CONVERGING` の内部詳細（reusable pattern）。V2 Lifecycle State に昇格しない                                                                   |

Legacy 文書・Issue の履歴は書き換えない。V2 namespace（`docs/ai/ai-loop-v2/**` と V2 として起票・rebaseline された Issue）で本 taxonomy 以外の語彙を **canon として**使うことを禁止する。Legacy を参照する場合は `evidence` / `reusable pattern` と明示する。

## 8. 機械検証（Phase 0.1 では手順・Phase 1 で fixture 化）

V2 namespace に対して次を検査する。いずれも 0 件が期待値。

```sh
git grep -nE '^\s*state:\s*(NO_PROGRESS|REPEATED_FAILURE|OSCILLATION|BUDGET_EXHAUSTED|POLICY_DENIED|VERIFIER_UNAVAILABLE|REQUIREMENT_CONFLICT|STATE_CONFLICT|MERGE_READY|HUMAN_ESCALATED|BLOCKED)\b' -- docs/ai/ai-loop-v2 | grep -v '禁止例'
git grep -nE '^\s*outcome:\s*(AUTO_APPROVED|HUMAN_REQUIRED|DENIED)\b' -- docs/ai/ai-loop-v2 | grep -v '禁止例'
git grep -nE '^\s*policy_verdict:\s*(MERGE_READY|HUMAN_ESCALATED|BLOCKED)\b' -- docs/ai/ai-loop-v2 | grep -v '禁止例'
```

Phase 1 で `tests/extras/` に fixture 化し、本節の禁止例を negative control として固定する（[`phase0-migration.md`](./phase0-migration.md) §8）。
