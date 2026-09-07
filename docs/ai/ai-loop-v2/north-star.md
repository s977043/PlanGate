# ai-loop V2 North Star — Self-Evolving Development Harness

> **Status**: Phase 0 **MERGED**（PR #1273・Human C-4 DONE）/ Independent Review **PENDING（separate checker required）** / Phase 0.1 **CANON_HARDENING**（#1275）
> **Companion canon**: [`taxonomy.md`](./taxonomy.md) / [`harness-manifest.md`](./harness-manifest.md) / [`evaluation-trust-boundary.md`](./evaluation-trust-boundary.md) / [`artifact-responsibilities.md`](./artifact-responsibilities.md)
> **Role**: V2 の最上位判断基準。詳細実装仕様ではなく、目的・不変原則・境界・成功条件を固定する。

## 1. North Star

ai-loop V2 は、検証可能な開発成果と、次の判断に使える Evidence を継続的に生み出し、その経験から開発システム自体を改善するための Harness である。

品質・安全性・Evidence の妥当性を守りながら、問題の観測から判断に必要な Evidence を得るまでの時間、回避可能な確認・復旧負担、失敗の影響と再発を減らす。Time to Learning の短縮だけを目的に、必要な観測を打ち切ったり、成功条件を緩めたりしない。

本文で使う語を次のとおり定義する。

- **価値仮説**: 変更がユーザー・事業にもたらす効果についての、まだ検証されていない想定。Product 側の語。
- **学習条件**: 価値仮説を検証したと言えるために必要な観測条件（何を・どの母集団で・どの水準で観測するか）。Product 側の語であり、Harness 改善の評価成立条件（§14 の evaluation plan）とは別物として扱う。
- **妥当な Evidence**: 出所と取得条件が辿れ、主張の範囲を超えて一般化していない Evidence。自己申告のみに依拠しない（§6）。
- **基礎的な安全境界**: 事故の観測を待たずに設置する最低限の防護。Human-owned 境界の保護、不可逆操作の停止、承認境界の保護を指す。

> **AI が開発を実行し、その結果を検証し、失敗と成功を振り返り、自らの Skill / Agent / Flow / Verifier を改善し、その改善が本当に有効かを独立検証したうえで、次の Harness version を作れる開発システムを構築する。**

一言で表す。

> **AI builds software. AI also improves the system that builds software.**

ただし、自己進化と実行中の自己変更は分離する。

> **Self-Evolution != Live Self-Modification**

```text
Harness N
  -> Delivery Run
  -> Evidence
  -> Retrospective
  -> Improvement Candidate
  -> Experiment / Evaluation / Canary
  -> Promotion Ready
  -> Human Decision
  -> Harness N+1
```

## 2. Three responsibilities

### Deliver

1 Task を `MERGE_READY` へ収束させる。

```text
Request
  -> Plan
  -> Plan Verification
       - Requirements Review
       - Design Review
       - Technical / Feasibility Review
       - Research Evidence Review (when required)
  -> Plan Gate
  -> Execute -> Verify -> Diagnose -> Repair / Replan -> Verify
  -> PR Convergence -> MERGE_READY
```

Initial Plan も Plan Verification を通る。Replan 時だけ Plan Review する構造にしない（§9）。

Delivery は合意した Contract のもとで実行する。探索を支える実装では、実装の受入基準と価値仮説の学習条件を区別し、必要な観測条件と Evidence の返却先を明確にする。`MERGE_READY` は必須の検証・PR 収束を含む Delivery 契約全体を満たし、C-4 / merge（Human-owned）待ちで停止した終端である（[`taxonomy.md`](./taxonomy.md) §3）。これは価値仮説の検証完了を意味しない（本 North Star が置く区別であり、taxonomy 側の規定ではない）。Product Discovery 全体やリリース後の観測・意思決定を V2 に内包せず、それらへ Evidence を接続する。

### Learn

Run の観測・検証結果を記録し、成功・失敗・摩擦を振り返って、次の判断に再利用できる Evidence にする。観測事実、原因仮説、未確認事項を区別する。

仮説の棄却や Candidate の不採用も、妥当な Evidence に基づくなら学習として扱う。評価実験の成立と Candidate の採用可否は別であり、Evidence 不足を、評価計画（§14）の成立や採用可能と見なさない。不足の原因や観測・検証上の摩擦は、次の改善の材料として残す。

```text
Run -> RunEvidence -> Retrospective -> Pattern / Friction / Success
```

### Evolve

Evidence から Harness 改善候補を作成・検証する。

```text
Pattern -> Hypothesis -> Skill / Agent / Flow / Verifier Candidate
        -> Experiment -> Independent Evaluation -> Canary -> Promotion Ready
```

## 3. Stable boundaries

### ai-dev-workflow remains stable

`ai-dev-workflow` の利用者向け契約を V2 のために変更しない。

```text
Request -> Plan -> C-1 -> C-2 -> Human C-3 -> Execute -> Verify -> PR_CREATED
```

V2 は ai-dev command を内側から直接チェーンすることを前提とせず、必要な既存能力を共通 primitive / adapter として利用する。

### Human-owned authority remains human-owned

少なくとも次は Human-owned のままとする。

- C-4
- Merge
- Hardening Override
- approval / permission / security policy
- GitHub protection / ruleset
- First Principles
- Production Harness への最終 Promotion

AI は proposal / patch / evidence / experiment / promotion-ready PR までは作れる。不可逆な Production 適用の最終権限は Human が持つ。

## 4. Delivery Loop and Evolution Loop are separate

Delivery と Evolution は同じ state / gate / success condition で表現しない。

- **Delivery Loop**: 1 Task / 1 Run を `MERGE_READY` へ収束
- **Evolution Loop**: 複数 Run を材料に次の Harness version を作る

C-3' / auto approval は ai-loop の本体ではない。**Autonomy / Policy profile の一選択肢**として扱う。

> Loop Execution != Auto Approval

## 5. Responsibility separation

最低限、次の責務を分離する。

```text
Planner -> Builder -> Verifier -> Diagnoser -> Decision Engine
```

原則:

- Builder != Verifier
- Verifier != Decision Engine
- Improvement Proposer != Promotion Evaluator

同じ Model を利用する場合でも、context / role / run を分離する。独立度は I0（same context）〜 I4（Human + machine independent evidence）で段階化し、Verifier / Gate / Policy / protected Flow の変更は通常の Prompt 変更より高い独立度を要求する（[`evaluation-trust-boundary.md`](./evaluation-trust-boundary.md) §4）。

## 6. Evidence before judgment

Worker の「完了」「PASS」等の自己申告を完了根拠にしない。報告は主張として受け取り、対象の成果物・外部状態・検証結果との対応を確認する。検証不能を「対象なし」や PASS として扱わない。

```text
Worker -> Artifact -> Verifier -> Evidence -> Decision Engine
```

> Worker produces artifacts. Verifier produces evidence. Gate decides whether the contract is satisfied.

Verifier は安価で決定論的なものを優先する。

1. deterministic verifier
2. specification verifier
3. independent reviewer
4. policy gate
5. loop decision

決定論的 FAIL を LLM の PASS で上書きしない。

## 7. Failure is an artifact

Failure を会話だけに残さない。最低限、以下を正規化する。

- observation
- failure fingerprint
- evidence refs
- cause hypothesis
- repairability
- result

Observation と Cause Hypothesis を別フィールドにする。

## 8. Loop means progress, not retry

単純な `retry < N` だけで継続しない。Iteration 間で最低限以下を比較する。

- blocking findings
- acceptance criteria delta
- failure fingerprint
- artifact delta
- evidence delta
- resolved blockers
- introduced blockers

Run の記述は 4 軸を別フィールドで持つ（正本: [`taxonomy.md`](./taxonomy.md)）。

| 軸 | 値域（最低限） |
|---|---|
| Lifecycle State | `PLANNING` / `PLAN_VERIFYING` / `EXECUTING` / `VERIFYING` / `DIAGNOSING` / `REPAIRING` / `REPLANNING` / `PR_CONVERGING` / `WAITING_HUMAN` / `WAITING_EXTERNAL` |
| Terminal Outcome | `MERGE_READY` / `HUMAN_ESCALATED` / `BLOCKED` |
| Stop Reason | `NO_PROGRESS` / `REPEATED_FAILURE` / `OSCILLATION` / `BUDGET_EXHAUSTED` / `POLICY_DENIED` / `VERIFIER_UNAVAILABLE` / `REQUIREMENT_CONFLICT` / `STATE_CONFLICT` / `HUMAN_REJECTED` |
| Policy Verdict | `AUTO_APPROVED` / `HUMAN_REQUIRED` / `DENIED` |

`NO_PROGRESS` は State ではなく Stop Reason、`AUTO_APPROVED` は Outcome ではなく Policy Verdict、`MERGE_READY` は Verdict ではなく Outcome である。

> **止まれることは自律性の失敗ではなく、自律性の要件である。**

## 9. Repair and Replan are different

```text
Verify FAIL
  -> Diagnose
  -> Plan valid?
       YES -> Repair
       NO  -> Replan -> Plan Verification -> Plan Gate
```

Delivery の Plan / Contract に含まれる目的・受入基準・学習条件の変更が必要な場合は、暗黙に書き換えず、変更提案を明示して Replan / Plan Verification / Plan Gate を通す。判断主体と承認権限は既存の境界に従い、合格させるために条件を緩めない。

この Replan は、Evolution Candidate の実装前に固定した評価計画・採用閾値を同じ Candidate の評価中に変更する権限を与えない。評価条件そのものの変更は別 Candidate・別評価として扱い、§14 と Evaluation Trust Boundary の保護・Human-owned 規則に従う。

Plan が変更された場合、旧 Plan に束縛された verification evidence は再検証する。Initial Plan と Replan 後の Plan は同じ Plan Verification を通る（§2）。

## 10. Harness identity is immutable during a Run

Run 開始時に **HarnessManifest**（[`harness-manifest.md`](./harness-manifest.md)）を固定し、RunState / RunEvidence は `harness_manifest_ref` で束縛する。`harness_version` 文字列は人間向けラベルであり、同一性の根拠にしない。

Active Run 中に Skill / Agent / Flow / Verifier contract / Gate / Policy / Budget policy を暗黙変更しない。

改善は `Harness N+1 Candidate` として別 Task / Branch / Run で検証する。

## 11. Harness evolution scope

Evolution Loop は次を正式な改善対象とする。

- Prompt
- Context selection / retrieval / compression / handoff
- Skill
- Agent
- Flow
- Verifier
- Routing
- Eval / Test

Skill / Agent / Flow / Verifier は既存 Component の更新だけでなく新規作成も扱う。

正式な operation:

- CREATE
- UPDATE
- SPLIT
- MERGE
- DEPRECATE

ただし **Reuse Before Create** を原則とする。

```text
Improvement Need
  -> Existing Harness Search
  -> existing component can solve it?
       YES -> REUSE / UPDATE
       NO  -> CREATE
```

> **Create Last.**

## 12. Evolution includes simplification

Harness の進化を Component 数の増加と定義しない。

次も改善候補に含める。

- unused / duplicate Skill
- overlapping Agent role
- redundant Flow stage
- harmful / noisy Verifier
- ineffective Prompt
- unnecessary Context retrieval

必要に応じて MERGE / DEPRECATE / REMOVE_FROM_FLOW / SIMPLIFY を提案する。

運用で検査を追加・変更する動機は、原則として観測した事故や失敗パターンへ紐づけ、適用範囲・誤検知・維持コストも評価する。基礎的な安全境界の設置は事故の発生を待たない。

簡素化は、必要な能力・検出力・安全条件を維持できることを Evidence で確かめて採用する。読まれない警告も範囲調整・統合・廃止の検討対象とするが、Gate・Verifier の削除・緩和・適用範囲縮小の権限はいずれも §15 に従う（範囲調整・統合が適用範囲の縮小を伴う場合を含む）。

## 13. Improvement Candidate contract principle

Harness 変更を直接始めない。

> **1 Candidate = 1 Hypothesis**

Candidate は最低限以下を持つ。

- source runs
- observed pattern
- cause hypothesis
- target component
- existing alternatives / reuse result
- proposed change
- expected effect
- risk / boundary impact
- complexity delta
- context / maintenance cost
- evaluation plan
- canary plan
- rollback plan

## 14. Evolution evaluation

Harness 改善は baseline と candidate を同一 fixture / task で比較する。

```text
Same Fixture
  -> Harness N baseline
  -> Harness N+1 candidate
  -> Compare
```

最低限評価する。

- acceptance / critical regression
- first-pass success
- repair rounds / replan count
- human intervention
- false positive / false negative
- time / token / cost
- activation
- rollback

Candidate が実際に対象経路で発火したことを Activation Check で確認する（`installed` / `registered` / `selected` / `fired` / `produced_evidence` / `influenced_decision` の 6 段階。`fired` 以上を要求）。重要変更では held-out / sealed regression set を使う。

Verifier / Gate の改善では、存在や発火だけでなく、既知の欠陥を検出でき、その結果が期待した続行・停止の判断へ接続されることを確かめる。要求段階は一般則の `fired` 以上ではなく **`influenced_decision`**（[`harness-manifest.md`](./harness-manifest.md) の 6 段階定義）とする。検出力・適用範囲・誤検知も改善の評価対象とする。

評価の結果は `PASS` / `FAIL` / `INCONCLUSIVE` の 3 値で、evaluation plan（fixture IDs / task profile / trial count / metrics / threshold / critical regression condition）は Candidate 実装前に固定する。

> **Candidate cannot modify the authority that judges the candidate.**

正本: [`evaluation-trust-boundary.md`](./evaluation-trust-boundary.md)。

## 15. Evolution authority levels

- **E0 Observe**: Evidence 収集
- **E1 Propose**: 改善 Candidate 生成
- **E2 Experiment**: 隔離環境で実装・検証
- **E3 Canary**: low-risk surface で限定利用
- **E4 Promotion Ready**: Production 適用可能な PR を完成

V2 初期目標は **E4**。AI による Production Harness の自動 merge は Non-goal。

初期に実験しやすい領域: Prompt / Context / Skill instruction / review rubric / test strategy。

条件付き領域: 新 Skill / 新 Agent / Agent role / Verifier 追加 / Flow stage 追加・順序変更。

Human Gate 必須: Gate・Verifier 削除、Stop / Escalation policy、Hook、Permission、Approval boundary、HO、C-4、Merge、First Principles、Gate・Verifier の緩和・適用範囲縮小（無効化 / 条件付き skip / 適用対象の縮小を含み、削除と同じ扱い）。

## 16. Bootstrap policy

V2 初期実装は Stable Harness で作る。

```text
ai-dev-workflow -> V2 Plan -> C-1 -> C-2 -> Human C-3
                -> Implementation -> Verification -> PR_CREATED
```

Delivery V2 が検証されるまで、V2 自身を V2 で開発しない。

## 17. Release boundaries

### Delivery V2 first release

最低限、次を E2E で実証する。

```text
Request -> Plan -> Plan Verify -> Execute -> Verify FAIL -> Diagnose -> Repair
        -> Verify PASS -> PR -> Review finding -> Repair -> MERGE_READY
```

さらに:

```text
NO_PROGRESS -> safe stop / escalation
```

Delivery が安定する前に Evolution を Production feedback loop として接続しない。

### Self-Evolving Harness completion

```text
Development Run
 -> RunEvidence
 -> Retrospective
 -> Pattern Detection
 -> Improvement Classification
 -> Skill / Agent / Flow / Verifier
 -> Reuse or Create
 -> Harness Candidate
 -> AI Implementation
 -> Independent Evaluation
 -> Baseline Comparison
 -> Canary
 -> Promotion Ready
 -> Human Merge
 -> Harness N+1
```

## 18. Success metrics

Candidate 数や Component 数を KPI にしない。

主に以下を見る。

- first-pass acceptance rate
- repair rounds
- replan count
- no-progress rate
- human intervention rate（§14 の `human intervention` に対応。実装は `scripts/ai-loop/metrics.py` の `human_intervention_rate`）
  - 内訳として avoidable human intervention / confirmation / recovery burden（証拠不足に起因する再確認・手動復旧の負担）を分けて見る
- regression rate
- verifier false-positive / false-negative rate
- cost per accepted change
- rollback rate

加えて、目的に応じて次の評価軸を見る。測定定義・対象範囲は詳細の評価計画で定める。

- Time to Learning: 問題の観測から、次の判断に必要な妥当な Evidence を得るまでの時間
- Evidence 取得後の意思決定待ち時間（Time to Learning と分ける）
- failure detection time / impact / recovery cost / recurrence

これら 3 つは Phase 1 時点では未対応であり、算出には [`run-evidence.schema.json`](../../schemas/run-evidence.schema.json) の拡張（現行は `started_at` / `completed_at` の 2 時刻のみで、Evidence 取得時刻・判断時刻・failure 発生時刻に対応するフィールドが無く、`escalation` / `quality_metrics` は `additionalProperties: false` のため追加できない）を要する。

Product 側と Harness 側の学習を混同せず、V2 が直接観測できる範囲と外部から受け取る Evidence を区別する。必要な人間判断は維持し、証拠不足による聞き直し・反復確認・手動復旧の負担を減らす。承認時には Evidence・残存リスク・未解決事項を提示して判断を支える。

品質・安全性・Evidence の妥当性を速度やコストで上書きしない。

## 19. Non-goals

- 無停止の完全自律
- AI 自身による Production merge
- Active Run 中の Harness 自己変更
- Model weight の自己学習
- hidden CoT の保存
- raw session transcript の学習資産化
- Component を増やすこと自体
- Human authority の撤廃
- PlanGate 全体を巨大な AI OS / control plane にすること
- Product Discovery 全体やリリース後の価値検証の orchestration

## 20. Decision priority

迷った場合は次の順で判断する。

1. Safety
2. Correctness
3. Verifiability
4. Reproducibility
5. Recoverability
6. Simplicity
7. Autonomy
8. Speed
9. Cost

自律性向上のために検証可能性を犠牲にしない。

## 21. Required review questions for every V2 Plan / PR

### North Star alignment

- Delivery / Learn / Evolve のどこを改善するか
- どの原則に基づくか
- 既存 Harness の再利用では解決できないか
- 新 Component を増やす必要が本当にあるか

### Verification

- 成功を何で観測するか
- deterministic verifier は何か
- negative control はあるか
- regression をどう検出するか

### Safety

- Human-owned boundary へ触れないか
- Active Harness を変更しないか
- rollback 可能か
- failure 時にどこで止まるか

### Evolution

- RunEvidence へ何を残すか
- 効果を後から測定できるか
- 効果がなかった場合に廃止可能か

これらへ回答できない Plan は実装へ進めない。

## 22. North Star statement

> **ai-loop V2 は、AI に無制限な自律性を与えるための仕組みではない。**
>
> **AI が自律的に開発し、自分の失敗と成功を Evidence として学び、Skill・Agent・Flow・Verifier を改善し、その改善自体を検証可能・rollback 可能な Software Engineering Process として運用するための Harness である。**
>
> **良い Loop は、正しく検証し、必要なら止まり、経験から次のより良い Harness を作れる。誤りを前提に、早期検知・影響限定・復旧・再発防止を可能にする。**
>
> **Delivery は合意した Contract のもとで MERGE_READY まで進める。実行中の Harness は固定し、C-4・マージ・次版 Harness の本番への最終 Promotion と既存の Human-owned 境界を維持する。**
