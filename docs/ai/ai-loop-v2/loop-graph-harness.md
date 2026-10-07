# ai-loop V2 — Loop / Graph / Harness Responsibility Model

> **Status**: ai-loop V2 の責務解釈ガイド。正本は [`north-star.md`](./north-star.md) と companion canon であり、本書はそれらに従属する。
> **Purpose**: Loop / Graph / Harness の境界を明確にし、二重正本や不要な Graph runtime を作らずに設計判断できるようにする。
> **Maintainer**: #894（本書全体の保守担当。2026-10-01 Human 決定、記録 #894 issuecomment-5924518240）。§2 の concern ごとの owner とも、§2 の「Canon / Trust Boundary の維持」の行（#1275）とも別。
> **Derived from**: canon 6 本（`north-star.md` / `taxonomy.md` / `harness-manifest.md` / `evaluation-trust-boundary.md` / `artifact-responsibilities.md` / `phase0-migration.md`）@ `b1217b41`。**本書は canon ではないため `phase0-migration.md` §7 の canon 7 本には加えない。** 下記が `b1217b41` 以外を返したら canon が動いているので、§2 の責務表と §3 の境界規則を読み直すこと。
>
> ```sh
> git log -1 --format=%h origin/main -- docs/ai/ai-loop-v2/north-star.md \
>   docs/ai/ai-loop-v2/taxonomy.md docs/ai/ai-loop-v2/harness-manifest.md \
>   docs/ai/ai-loop-v2/evaluation-trust-boundary.md \
>   docs/ai/ai-loop-v2/artifact-responsibilities.md \
>   docs/ai/ai-loop-v2/phase0-migration.md
> ```

## 1. Core model

ai-loop V2 では Loop / Graph / Harness を、置換関係ではなく異なる責務として扱う。

> **Loop is the unit of feedback and convergence. Graph is the unit of coordination topology. Harness is the execution environment that makes both reliable.**

- **Loop**: Evidence を観測し、進捗を判断し、repair / replan / stop しながら bounded goal へ収束させる。
- **Graph**: node / edge / branch / join / wait / resume / recovery を通じて、複数責務の実行順序と遷移を明示する。
- **Harness**: context / tool / permission / state primitive / verifier / policy / budget / observability を提供し、Loop と Graph を安全・再現可能に実行する。

`Prompt -> Context -> Harness -> Loop -> Graph` を成熟度や年代順として扱わない。Graph は Loop を置き換えない。

## 2. Composition rules

Loop と Graph は直交し、必要に応じて合成する。

- Graph は複数の Loop を含められる。
- Loop は複数の Graph node を巡回できる。
- Loop 自体を、より大きな Graph の node として扱える。
- node は Agent / LLM に限定しない。deterministic code / tool / verifier / gate / Human action / another Loop も node になれる。

V2 の既存責務へ当てはめると次のようになる。

**本表が責務と owner の唯一の対応表である**（§8 で再掲しない）。

| Concern | 責務 | Owner / 正本 |
|---|---|---|
| 1 Task を Evidence で `MERGE_READY` へ収束 | Loop | Delivery Loop / [`north-star.md`](./north-star.md) |
| 複数 Run から Harness N+1 Candidate を作り評価（Harness Evolution） | Loop | Evolution Loop / #869 |
| stop / progress / retry strategy | Loop | #894 / [`north-star.md`](./north-star.md) §8（Decision core は子の #1393） |
| durable state / Human interrupt / wait-resume / recovery | Graph + Harness | #1025（RunState CAS は子の #1392） |
| Work Item Graph / Assignment の宣言（decomposition / dependency / join policy / bounded dynamic policy。immutable） | Graph | #911 / #1385 |
| runtime graph の事実（instantiation / route / join）と、その projection としての effective runtime graph | Graph + Harness evidence | #874（V2 event stream） |
| node 遷移の妥当性評価（Trajectory evaluation） | Graph + Evaluation | #908 |
| RunEvidence / failure evidence | Harness evidence | #874 / [`artifact-responsibilities.md`](./artifact-responsibilities.md) |
| Harness identity / activation | Harness | [`harness-manifest.md`](./harness-manifest.md) |
| evaluator / protected authority | Harness trust boundary | [`evaluation-trust-boundary.md`](./evaluation-trust-boundary.md) |
| Canon / Trust Boundary の維持 | Harness canon | #1275 + V2 companion canon |

## 3. Boundary rules

責務が重なる箇所では、次で分ける。

### Loop owns convergence semantics

Loop は「次に何をすべきか」のうち、Evidence と Contract に基づく収束判断を持つ。

```text
continue | repair | replan | stop / escalate
```

単なる `retry < N` は Loop ではない。Iteration 間で progress / evidence delta / failure fingerprint を比較する原則は [`north-star.md`](./north-star.md) §8 を正とする。

### Graph owns coordination topology

Graph は「どの責務へ遷移するか」を明示する。

```text
node -> edge -> node
      branch / join / wait / resume / recovery
```

Graph の node 到達だけでは、その node の Contract が満たされた証拠にならない。完了判定は Verifier / Evidence / Gate の責務を維持する。

### Harness owns reliable execution conditions

Harness は Graph state の意味そのものではなく、state を安全に保存・復元する primitive や runtime 条件を提供する。

- Graph: `current_node`, transition, waiting / recovery path の意味
- Harness: persistence, checkpoint, CAS, tool / permission, verifier availability, activation evidence

Active Run 中の Harness identity は [`harness-manifest.md`](./harness-manifest.md) に従い固定する。

## 4. Static Workflow / Runtime Graph distinction

固定された workflow と runtime graph を区別する。分岐が存在するだけでは runtime graph ではない。

### Static Workflow（default）

実行前に graph shape と transition rule が確定しており、runtime は定義済み条件を評価して経路を実行する。

```text
Request -> Plan -> Build -> Verify -> PR
                    └-> Repair -> Verify
```

単純・反復可能・安全境界が明確な処理では、Static Workflow を優先する。

### Adaptive Routing

node catalog と安全境界は事前定義し、**次にどの既知 node へ遷移するか**を runtime の Evidence / State / Policy に基づいて選択する。Static Workflow と異なり、transition target を個別の固定条件へ完全には焼き込まない。

```text
Known nodes / allowed edges
        +
RunState / Evidence / Policy
        ↓
Routing Decision
        ↓
selected next node
```

### Bounded Dynamic Graph

parallel worker 数、context subset、approved template の specialization など、**実行前に完全列挙しにくい coordination topology**を runtime で構成する。ただし自由生成にはしない。

runtime が決めてよい対象:

- approved template（WorkItemGraph の `work_item_templates[]`）からの work item instance の specialization。specialization してよい field は allowlist に限り、**新しい AC を追加しない・template / parent の scope を拡大しない**
- 既存 work item の partition（分割）。parent work item からの instance として event stream に記録し、active な WorkItemGraph は編集しない。新しい AC・権限・scope を追加しない。分割後の所有・join 条件・検証単位は #1385 の WorkItemGraph Contract が定める（2026-10-01 Human 決定、記録 #1385 issuecomment-5924407778）
- bounded な worker 数と assignment
- context subset
- allowed edge 内の branch / join
- Loop の convergence decision に従う repair / replan / recovery への route（repair / replan の要否そのものは判定しない）

runtime が変更してはいけない対象:

- Human-owned authority
- protected policy / permission boundary
- Evaluation Trust Boundary
- Verifier / Gate の authority
- acceptance threshold
- active Run の Harness identity
- protected surface の定義
- active な WorkItemGraph / Assignment artifact（in-place で編集しない）

> **Dynamic topology does not mean dynamic authority.**

WorkItemGraph / Assignment は immutable な宣言である。runtime の instantiation / route / join は V2 event stream（RunEvent）の事実として記録し、effective runtime graph はその projection として導出する。**WorkItemGraph とは別に、2 つ目の可変なグラフ状態ストアを作らない。** replan は active graph を書き換えず、新しい immutable WorkItemGraph を作り `supersedes_graph_ref` で前の graph を指す（supersession）。owner は §2 の表を参照する。

### Runtime Graph Decision Record（informative shape）

runtime graph の構成・遷移判断は、少なくとも次の情報へ束縛できる必要がある。**これは新しい schema / SSoT ではない。** 宣言（WorkItemGraph / Assignment）と runtime の事実（event stream）と projection の owner は §2 の表を参照する。下記は event stream に記録される判断の意味を説明する informative shape であり、persisted な field 名は owner 側が確定する。

```yaml
graph_decision:
  run_id: ""
  graph_ref: ""              # 判断が従う immutable WorkItemGraph
  supersedes_graph_ref: ""   # replan で新しい graph を作った場合のみ
  observed_state_ref: ""
  evidence_refs: []
  convergence_decision_ref: ""
  policy_ref: ""
  template_refs: []          # approved work_item_templates[] のみ
  allowed_edges_ref: ""
  decision:
    action: route | spawn | join | wait | resume | recover
    route_kind: normal | repair | replan | recovery
    target_nodes: []
  context_refs: []
  budget_ref: ""
  reason_code: ""
```

`action` に終了（terminate）を置かない。Terminal Outcome / Stop Reason の決定は Decision Engine の責務である（[`artifact-responsibilities.md`](./artifact-responsibilities.md)）。Graph は `convergence_decision_ref` が指す決定に従って terminal へ route するだけで、その場合も `action: route` として記録する。ここでの convergence は Loop の収束判断（#894）を指し、RunState の `PR_CONVERGING` や `pr_convergence`（PR の収束観測）とは別の概念である（ただし `PR_CONVERGING` の間は、`pr_convergence` が Decision Engine の入力の 1 つになる。#1393）。

原則:

1. Graph decision は current RunState / Evidence / Contract / Policy と、必要に応じて #894 が所有する convergence decision から導出する。Graph 自身が repair / replan の要否を再判定しない。
2. 新しい node type / authority / permission を実行中に創設しない。
3. worker 数・parallelism・token / time / cost は事前定義 budget を超えない。
4. join condition は worker の自己申告ではなく Evidence で判定する。
5. context subset を変更した場合は provenance を残す。
6. graph_ref / supersession / routing decision / reason / Evidence を event stream から復元可能にする。
7. `unknown` / conflict / missing evidence を都合よく route せず fail-closed または Human escalation とする。
8. deterministic rule で十分な routing を LLM 判断へ昇格させない。
9. active Run 中の self-modifying graph は禁止する。active な WorkItemGraph は in-place で編集せず、replan は新しい immutable WorkItemGraph と supersession で表す。Graph 改善は Evolution Loop で Candidate 化し、次の Harness version へ反映する。

### Selection rule

```text
Can a linear/static workflow express the task safely?
  yes -> Static Workflow
  no
   ↓
Is the node catalog fixed and only routing varies?
  yes -> Adaptive Routing
  no
   ↓
Does runtime need to instantiate bounded topology?
  yes -> Bounded Dynamic Graph
  no / unbounded -> do not execute; replan or escalate
```

この区別は Work Item Graph / Assignment の宣言と接続する。Graph runtime の generic engine を先に作らず、durable state・convergence / stop・trajectory evaluation・event stream は §2 の既存 owner を再利用する。

### Execution Strategy is orthogonal to Graph topology

参考一次情報: GitHub の [Project HydraFusion](https://github.blog/ai-and-ml/github-copilot/project-hydrafusion-frontier-quality-via-multi-model-orchestration/) と [VS Code 1.140](https://code.visualstudio.com/updates/v1_140)。ここでは research preview の runtime を依存として採用せず、公開された execution pattern / guardrail を設計入力としてのみ扱う。

HydraFusion で示された `single / cascade / critique` は、上記の Static Workflow / Adaptive Routing /
Bounded Dynamic Graph と同じ taxonomy ではない。前者は **1 つの approved Work Item / Graph node をどの実行構成で解くか**、
後者は **責務や node をどう配置・遷移させるか** を表す。

したがって PlanGate では Execution Strategy を、Model / Effort / Role / Graph topology / Judgment authority から
独立した execution-time lens として扱う。Execution Strategy を選んでも WorkItemGraph の scope、Acceptance Criteria、
Human-owned authority、Verifier / Gate の authority は変わらない。

```text
Approved Work Item / Graph node
        ↓
Execution Strategy
  ├─ single
  ├─ cascade
  └─ critique
        ↓
RunEvidence / Verification
        ↓
Gate / Human authority
```

| Strategy | Vendor-neutral semantics | 適する条件 | 境界 |
|---|---|---|---|
| `single` | 1 worker / 1 solving path で実行する | bounded・低不確実性・追加独立判断の便益が小さい | 失敗時に strategy 内で無制限 retry せず #894 の convergence / stop に従う |
| `cascade` | 低コスト側の path を先に実行し、事前定義した quality signal が不足した場合だけ別の stronger path へ escalation する | cost / latency を抑えつつ quality floor を守りたい | cascade 内の quality check は PlanGate Gate そのものではない。terminal authority を持たない |
| `critique` | Builder の候補を read-only Reviewer が独立に批評し、Builder が bounded な修正を行う | ambiguity / risk / independent judgment need が高い | Reviewer は patch / merge authority を持たない。Reviewer と Verifier は別責務であり、review 完了を verification 成功とみなさない |

`critique` の independence は「モデル数」だけでは証明しない。少なくとも execution provenance を残し、
必要な trust level に応じて model/provider/context/tool/host の分離を評価する。external verifier が必要な境界は
[`adr-007-external-runtime-verifier-boundary.md`](../../decisions/adr-007-external-runtime-verifier-boundary.md) と
Evaluation Trust Boundary の既存規則を正とする。

#### Strategy selection inputs

strategy recommendation は、少なくとも次を入力候補とする。

- task complexity / uncertainty
- risk class / protected-surface proximity
- cost / latency / token budget
- independent judgment need
- prior Run の failure / repair evidence
- provider / model capability availability

ただし、deterministic rule で十分な場合は LLM router を使わない。未知・矛盾・evidence 不足を
`single` へ都合よく丸めず、shadow recommendation または Human escalation とする。

strategy の declaration / selection / observation の owner を本節で新設しない。Work Item / Assignment の宣言は #911、runtime の実行事実は #874、recommendation / outcome の評価は #908、strategy rule 自体の改善は #869 を正とする。persisted field が必要になった場合は、先に owner 側 Contract を変更し、本書から新しい SSoT を作らない。

#### Orchestration guardrails

HydraFusion の運用原則は新しい owner を作らず、既存責務へ次のように対応付ける。

| Guardrail | PlanGate interpretation | Owner / evidence |
|---|---|---|
| Complete accounting | 成功した最終 leg だけでなく draft / critique / revision / escalation / retry / fallback / cancelled / failed を含む全 leg の model/provider、token、time、cost、outcome を追跡可能にする | #874 RunEvent / RunEvidence、#908 operational evaluation |
| Bounded execution | timeout / retry / fallback / parallelism / token / time / cost を budget と stop policy の内側に置き、停止時は可能な範囲で in-flight leg と retry backoff へ cancellation を伝播する | #894 convergence / stop policy、Harness / host の execution primitive、Work Item の `budget_profile` / `budget_ref` |
| Isolated review | critique の Reviewer を Builder の write authority から分離し、必要な independence を provenance で説明可能にする | Evaluation Trust Boundary、ADR-007、River Review の review / verifier contract |
| Fail-safe application | review / verification / routing が failed / cancelled / unknown のとき変更適用や authority 昇格へ進めず、partial result を clean success に変換しない | Verifier / Gate / Human-owned C-4・merge boundary |
| Validated routing | 実行前に strategy definition / provider・model availability / fallback / budget compatibility を検証し、default-on 前には shadow / paired evaluation で便益も検証する | Harness preflight、#908 Run Eval、#869 Harness Evolution |

ここでいう `fail-safe application` は PlanGate が patch application を新たに所有するという意味ではない。
既存どおり、Execution Strategy は protected authority を変更せず、不可逆な採用判断を代替しない。

`bounded execution` を満たすには、単に caller が待機を打ち切るだけでは不十分である。host / provider が cancellation を提供する場合は in-flight request と backoff へ伝播し、提供できない場合はその limitation を Evidence に残して bounded と断定しない。fallback は事前に許可・予算化された経路に限定し、routing / fallback validation が失敗した場合は実行を開始しないか Human escalation へ送る。

#### Adoption rule

Execution Strategy の runtime 自動選択は、最初から production default にしない。

1. **Interpretation only**: taxonomy と owner mapping を明文化する。
2. **Observe-only**: 実際に使った strategy と、推奨 strategy を別々に記録する。
3. **Paired evaluation**: #869 / #908 で quality / coverage / repair round / cost / latency /
   Human correction burden を baseline と比較する。
4. **Opt-in routing**: critical regression がなく、routing の便益が evidence で示された範囲だけ有効化する。
5. **Evolution**: strategy / threshold / routing rule の改善は active Run の self-modification ではなく
   #869 の Candidate として次の Harness version に反映する。

## 5. Minimum topology principle

**まず最小の制御構造を選ぶ。** AI を使うこと自体は Graph 導入理由にならない。

単一 Loop を優先する条件:

- bounded goal が 1 つ
- 実行がほぼ線形
- meaningful な parallel / join がない
- durable Human / External wait-resume がない
- 独立した trust domain への handoff が不要
- failure を同一 Loop 内の repair / replan で表現できる

明示的な Graph を導入する条件:

- branch ごとに Contract / permission が異なる
- parallel work を明示的な join 条件で収束させる必要がある
- Planner / Builder / Verifier / Decision Engine 間の handoff を durable にする必要がある
- Human / External wait を session / process loss を越えて resume する必要がある
- independent reviewer / evaluator を別 trust path として隔離する必要がある
- recovery / rollback が通常経路と異なる
- 複数の sub-Loop を orchestration する必要がある

> **Do not graph what a single Loop can express clearly. Do not hide real coordination complexity inside one opaque Loop.**

## 6. Graph safety invariants

Graph を使う場合も、V2 の既存 invariant を弱めない。

1. node は primary responsibility を明確にし、plan / build / verify / decide を無制限に同居させない。
2. non-trivial edge は Evidence / Policy / Human or External event のいずれかに根拠を持つ。
3. interruption が重要な state は conversation history や live process を正本にしない。
4. parallel work の完了は worker の自己申告ではなく join condition と Evidence で判定する。
5. retry / repair / replan / wait / escalate / rollback / stop を暗黙の例外経路にしない。
6. C-4 / Merge / policy / permission / First Principles / Production Harness promotion の Human-owned authority は Graph edge によって AI-owned へ変換しない。
7. Candidate は Graph を変更しても、自分を裁く authority を変更できない。

> **Candidate cannot modify the authority that judges the candidate.**

## 7. Diagnosis heuristic

失敗を Model に帰属する前に、周辺システムを確認する。

```text
Harness -> Loop -> Graph -> Model -> External
```

これは診断順序の heuristic であり、新しい persisted failure taxonomy ではない。FailureRecord / RunEvidence の schema は companion canon と #874 を正とする。

## 8. Precedence

Issue #923 は Harness / Loop / Graph の横断整理を提案したが、実装責務が既存 Issue に存在するため **SUPERSEDED** で close 済みである。本書は #923 を reopen せず、概念の解釈だけを残す。

owner と正本の対応は **§2 の表が唯一**である。ここで再掲しない（2 箇所を同期し続ける状態を作らないため）。

優先順位は次のとおり。

1. **owner 側で具体的な Contract が定義されたら owner 側を正とする**
2. canon（`north-star.md` と companion canon）が本書と食い違ったら **canon を正とし、本書を直す**
3. 本書は 1 / 2 のいずれも定めていない範囲の**解釈**だけを持つ

## 9. Non-goals

- LangGraph 等の特定 Graph framework を導入すること
- concrete requirement より先に generic Graph runtime を作ること
- 全 workflow を Graph 化すること
- Delivery Loop / Evolution Loop の用語を Graph に置き換えること
- state / outcome / stop reason / failure schema を本書で再定義すること
- Graph routing を Verifier / Gate の代替にすること
- Human-owned authority を縮小すること

## 10. Working rule

設計責務に迷ったときは、次の 3 問で判断する。

```text
How does this work converge and stop?    -> Loop
What coordinates the next transition?   -> Graph
What makes execution reliable and safe? -> Harness
```

そのうえで、要件を満たせる**最小の既存 owner**へ実装責務を置く。

## 11. Harness composition lens

外部の Harness 設計で見かける「N 層」は、PlanGate では **固定 taxonomy や成熟度モデルとして採用しない**。層数や名称を正本にすると、既存の Loop / Graph / Harness owner と二重管理になり、モデルや runtime の進化に追随しにくくなるためである。

代わりに、Harness を設計・棚卸しするときは「その部品が何の責務を担うか」という lens で見る。複数の責務を同じファイルや runtime component が担っていてもよいが、責務と authority は分離して説明できなければならない。

| Responsibility lens | 例示 surface（owner の定義ではない） | 見ること |
|---|---|---|
| Governing instructions | Prompt / policy / repository instructions | 何を必須・禁止・推奨としているか。Human-owned authority を変更していないか |
| Context & steering | context selection / retrieval / compression / handoff | 必要な情報だけを適切な鮮度・provenance で渡しているか |
| Capabilities | Skill / Agent / tool | どの能力を再利用可能な単位として提供しているか |
| Coordination | Flow / Routing / Graph | 誰が次に動くか、branch / join / wait / resume をどう表現するか |
| Enforcement | Verifier / Gate / Hook / permission | 自己申告ではなく、どの条件を機械的・独立に確認するか |
| State & memory | RunState / event stream / evidence / retained learning | 中断・再開・振り返りに必要な事実を conversation 外へ残せているか |
| Evaluation & observability | RunEvidence / eval / metrics / activation evidence | 実際に発火し、Evidence を生み、判断へ影響し、改善効果を比較できるか |

この表は owner の新設でも、surface と責務の 1:1 対応表でもない。1 component が複数責務を担う場合も、1 責務が複数 component に分散する場合もある。**owner の対応は §2 の表だけを正とする。** Verifier / Gate の identity と activation は [`harness-manifest.md`](./harness-manifest.md)、改善候補・評価・簡素化・Promotion authority は [`north-star.md`](./north-star.md) §11〜15 が正である。

### Harness Health: 5 つを分離して見る

Harness の棚卸しでは、次の 5 つを別の問いとして扱う。存在確認だけで効果を主張しない。これらを単一の `Harness Health Score` に集約することは既定としない。異なる性質の Evidence と authority を 1 数値へ潰すと、弱い軸を他の高得点で相殺できてしまうためである。

| Dimension | Question | Evidence / authority |
|---|---|---|
| Identity / Presence | 何が、どの内容で存在しているか | HarnessManifest の content identity / `installed` / `registered` |
| Runtime Activation | その Run で本当に選択・実行されたか | `selected` / `fired` / `produced_evidence` / `influenced_decision`。定義は [`harness-manifest.md`](./harness-manifest.md) §4 |
| Effectiveness | 発火した結果、期待した品質・安全性・効率を改善したか | baseline vs candidate、critical regression、false positive / false negative、time / token / cost 等。正本は [`north-star.md`](./north-star.md) §14 / §18 |
| Governance | その component が authority / approval / permission / protected boundary を正しく維持しているか | Human-owned boundary、policy / permission、Evaluation Trust Boundary。維持コストを理由に弱体化しない |
| Maintainability | 重複・競合・旧 workaround・context burden を増やさず維持できるか | maintenance cost、duplication / conflict / legacy debt。Instruction Debt は `instruction-debt-audit` を利用 |

判定の順序は次を基本とする。

    present?
      no  -> missing / intentionally absent を区別。missing なら CREATE candidate を検討
      yes -> activated?
               no  -> dead / unreachable / wrong routing の可能性
               yes -> effectiveness evidence sufficient?
                        no  -> INCONCLUSIVE / gather evidence
                        yes -> effective?
                                 no  -> UPDATE / MERGE / DEPRECATE / REMOVE_FROM_FLOW / SIMPLIFY candidate
                                 yes -> KEEP candidate
    then check Governance and Maintainability independently before promotion

特に `installed` / `registered` は **availability evidence** であって **effectiveness evidence** ではない。`fired` も「動いた」証拠であり、「良くした」証拠ではない。Effectiveness は同一条件の比較や regression evidence で別途評価する。測定不能・サンプル不足・activation 不成立は `INCONCLUSIVE` とし、効果なしと扱わない。

### Lightweight operational audit

Harness Health を実務で使うときも、repository 全体を無条件に棚卸ししない。まず監査対象と期待責務を絞る。

1. **Scope**: 対象 component / surface / workflow を限定する。
2. **Expected responsibility**: その対象が担うべき責務と、担わなくてよい責務を明示する。
3. **Evidence window**: どの Run / fixture / period / model profile を根拠にするかを固定する。
4. **Identity / Presence**: 実体・content identity・registration を確認する。
5. **Runtime Activation**: 選択・発火・Evidence 生成・判断影響を、必要な activation level まで確認する。
6. **Effectiveness**: baseline / candidate または同等条件の比較で、期待効果と regression を確認する。
7. **Governance**: protected authority / permission / approval / trust boundary を弱めていないか確認する。
8. **Maintainability**: 重複・競合・旧 workaround・context burden・maintenance cost を確認する。
9. **Disposition**: Evidence が十分なものだけを KEEP / CREATE / UPDATE / SPLIT / MERGE / DEPRECATE / REMOVE_FROM_FLOW / SIMPLIFY の Candidate 入力にする。不足は `INCONCLUSIVE` のまま残す。

監査結果は新しい SSoT や persisted schema を要求しない。既存の issue / review / retrospective / Evolution Candidate へ必要な Evidence refs と rationale を渡せればよい。

`instruction-debt-audit` は Instruction / Skill / Agent / Hook / Permission 等の **instruction surface の Maintainability 監査**に再利用できるが、Harness 全体の Runtime Activation / Effectiveness / Governance 判定を代替しない。

#### Comparability rule

Effectiveness は「変更前後で数字が違った」だけで判定しない。North Star §14 の Same Fixture 原則に従い、Harness 変更以外の主要条件を揃えるか、Candidate scope に含めて明示する。

最低限、比較時に次を確認する。

- baseline / candidate の `harness_manifest_ref` が取得でき、差分対象を説明できる
- fixture / task profile / acceptance contract が同等である
- model / reasoning effort / routing / verifier set / policy profile の差が Candidate scope 外なら固定されている
- trial count / critical regression condition / threshold が Candidate 実装前に固定されている

Candidate scope 外の主要条件が同時に変わり、影響を分離できない場合は `INCONCLUSIVE` とする。

複数 component を意図的に 1 Candidate としてまとめること自体は禁止しない。ただしその場合に主張できるのは **bundle 全体の効果**までであり、追加の比較 Evidence なしに個別 component の寄与へ因果帰属しない。

#### Expected activation and negative evidence

`fired` が観測されなかったことだけで、component を dead / ineffective と判定しない。rare-path safety guard、failure-only verifier、rollback / recovery path は、通常 Run で発火しないこと自体が正常な場合がある。

Activation を評価する前に、その component の **expected activation condition** を明示する。

| Observation | Interpretation | Next action |
|---|---|---|
| expected trigger が観測されていない + non-fired | no observation。dead の証拠ではない | 必要なら targeted fixture / replay で確認 |
| expected trigger が観測された + non-fired | routing / registration / trigger defect の強い finding | activation path を診断 |
| fired したが evidence / decision に接続されない | activation は成立、integration / effectiveness が未成立 | produced_evidence / influenced_decision を追跡 |
| activation 自体を観測できない | `INCONCLUSIVE` | observability gap を先に補う |

rare-path component の確認では、production で危険条件を意図的に発生させることを既定としない。isolated test / sealed fixture / historical replay / safe fault injection など、authority と安全境界を維持できる検証手段を優先する。

とくに Verifier / Gate の変更は [`harness-manifest.md`](./harness-manifest.md) §4 と [`north-star.md`](./north-star.md) §14 に従い、単なる発火ではなく必要な activation level（原則 `influenced_decision`）まで確認する。

#### Redundancy safety check

重複して見える component を MERGE / DEPRECATE / REMOVE_FROM_FLOW 候補にする前に、その重複が **defense-in-depth / independent failure mode / platform fallback / compatibility boundary** として意図的に存在していないか確認する。

同じ目的を持つ 2 つの guard があっても、片方が runtime enforcement、もう片方が CI regression detection を担うなら単純な duplicate ではない。削減候補は、片方を外しても required detection / authority / fallback が維持される Evidence がある場合に限る。

### Audit disposition は候補であり、権限ではない

棚卸し結果は、実装を直接変更する命令ではなく Evolution Candidate の入力として扱う。

| Disposition | 意味 | 次の扱い |
|---|---|---|
| KEEP | 現時点の Evidence では変更理由がない | 現状維持。必要なら継続観測 |
| CREATE | 既存 component で表せない具体的な責務 gap が Evidence 付きで確認された | Reuse Before Create を再確認してから Candidate 化 |
| UPDATE | 責務は必要だが内容・trigger・routing 等に改善余地がある | North Star §13 の Candidate 化 |
| SPLIT | 1 component に複数責務が過密に集中している | Candidate 化して独立評価 |
| MERGE | 重複 component を統合できる可能性がある | activation / regression を比較して Candidate 化 |
| DEPRECATE | 利用停止候補。即削除ではない | replacement / migration / rollback を含めて Candidate 化 |
| REMOVE_FROM_FLOW / SIMPLIFY | component 自体を消さず経路や複雑性を減らす候補 | baseline 比較後に Candidate 化 |
| INCONCLUSIVE | 判断に必要な Evidence が不足 | 変更せず、観測・fixture・activation evidence を補う |

これらは audit disposition であり、Production Harness を直接変更する authority を持たない。とくに Gate / Verifier の削除・緩和・適用範囲縮小、Hook / Permission / Approval boundary 等は [`north-star.md`](./north-star.md) §15 の Human Gate を維持する。

### Composition rule

Harness の設計判断では、部品数や layer 数を増やすことを進化とみなさない。

    Observed need
      -> responsibility is already covered?
           YES -> reuse / adjust / simplify
           NO  -> add the smallest missing capability
      -> verify activation
      -> verify effectiveness
      -> promote only within existing authority boundary

したがって、外部事例から新しい「層」を取り込む場合も、まず既存 primitive へ写像し、**既存責務で表せない具体的な gap がある場合だけ**新しい component / artifact / owner を検討する。これは North Star §11 の Reuse Before Create と §12 の simplification を、Harness 全体の構成判断へ適用するための解釈である。

## References

Informative only. Repository canon takes precedence.

- #923 — Harness / Loop / Graph Engineering responsibility separation (SUPERSEDED)
- https://x.com/Sumanth_077/status/2097689190712692965 — Loop vs Graph Engineering discussion
