# ai-loop V2 North Star — Self-Evolving Development Harness

> **Status**: Phase 0 canonical candidate
> **Role**: V2 の最上位判断基準。詳細実装仕様ではなく、目的・不変原則・境界・成功条件を固定する。

## 1. North Star

ai-loop V2 が目指すものは、単なる「長時間自律実行する Coding Agent」ではない。

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
Plan -> Execute -> Verify -> Diagnose -> Repair / Replan -> Verify
     -> PR -> CI / Review -> MERGE_READY
```

### Learn

Run を振り返り、成功・失敗・摩擦を再利用可能な Evidence に変換する。

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

同じ Model を利用する場合でも、context / role / run を分離する。

## 6. Evidence before judgment

Worker の「完了」「PASS」等の自己申告を完了根拠にしない。

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

正式な停止理由に以下を含める。

- `NO_PROGRESS`
- `REPEATED_FAILURE`
- `OSCILLATION`
- `BUDGET_EXHAUSTED`
- `POLICY_DENIED`
- `BLOCKED`
- `HUMAN_ESCALATED`

> **止まれることは自律性の失敗ではなく、自律性の要件である。**

## 9. Repair and Replan are different

```text
Verify FAIL
  -> Diagnose
  -> Plan valid?
       YES -> Repair
       NO  -> Replan -> Plan Review
```

Plan が変更された場合、旧 Plan に束縛された verification evidence は再検証する。

## 10. Harness version is immutable during a Run

Run 開始時に `harness_version` を固定する。

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

Candidate が実際に対象経路で発火したことを Activation Check で確認する。重要変更では held-out / sealed regression set を使う。

## 15. Evolution authority levels

- **E0 Observe**: Evidence 収集
- **E1 Propose**: 改善 Candidate 生成
- **E2 Experiment**: 隔離環境で実装・検証
- **E3 Canary**: low-risk surface で限定利用
- **E4 Promotion Ready**: Production 適用可能な PR を完成

V2 初期目標は **E4**。AI による Production Harness の自動 merge は Non-goal。

初期に実験しやすい領域: Prompt / Context / Skill instruction / review rubric / test strategy。

条件付き領域: 新 Skill / 新 Agent / Agent role / Verifier 追加 / Flow stage 追加・順序変更。

Human Gate 必須: Gate・Verifier 削除、Stop / Escalation policy、Hook、Permission、Approval boundary、HO、C-4、Merge、First Principles。

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
Request -> Plan -> Execute -> Verify FAIL -> Diagnose -> Repair
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
- human intervention rate
- regression rate
- verifier false-positive / false-negative rate
- cost per accepted change
- rollback rate

品質・安全性を速度やコストで上書きしない。

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
> **良い Loop とは長く動く Loop ではない。正しく検証し、必要なら止まり、経験から次のより良い Harness を作れる Loop である。**
