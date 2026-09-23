# Plan Design Principles 運用評価計画

- Issue: #1337 / predecessor: #1335, PR #1336
- Status: evaluation protocol v2 + execution config freeze。実モデルによるpaired実行は未実施。
- 対象: ai-dev-plan の設計判断。production、承認境界、C-1定義は変更しない。
- baseline: `612c3dacacf76c0bfd72559fbbe0bc41bc41443d`
- candidate: `4b3f4017ad6c2a64813524ec8567a289f722cb45`
- 比較版はSHA固定。評価途中でmain追従版へ差し替えない。

## 1. 評価成果物とVisibility

評価知識を1ファイルへ混在させない。

| Artifact | Role | Generator visibility |
| --- | --- | --- |
| `2026-09-20-plan-design-principles-eval-inputs.md` | 8ケースのsource | **operator only** |
| `docs/working/eval-inputs/PDP-EVAL-v1/PDP-XX/pbi-input.md` | frozen derived PBI | **selected 1 case only** |
| `2026-09-20-plan-design-principles-eval-rubric.md` | expected behavior / failure / scoring | **hidden** |
| `2026-09-20-plan-design-principles-eval-ledger.md` | 実行条件・48 run・blind scoring台帳 | execution operator / reviewer |
| 本文書 | orchestration / stop / completion boundary | operator |

**重要**: repositoryに4文書が共存していることと、generatorが4文書を読めることは別。実行時はisolated workspace / allowed-read policyを使い、generatorへrubricをmountしない。rubricを読めたrunはcontaminatedとして除外する。

## 2. 評価仮説

#1335により、candidateではbaselineと比べて次が改善する可能性がある。

1. 現在必要な設計へ収束し、根拠のないabstractionを減らす
2. Contract / InvariantをAC・Existing Behavior・Domain Rule・Architecture Constraint・Measured Evidenceへtraceする
3. change typeに適したVerification/TDDを選ぶ
4. Failure / Compatibility等のConditional Guidanceを必要時のみ発火する
5. B-2の2〜3案比較を維持する
6. light taskで空section・無関係test・過剰な設計説明を増やさない

これは**仮説**であり、原則が文書に存在するだけでは効果ありと判定しない。

## 3. ai-dev-plan契約との整合

各PDPケースは generator input 文書内で以下のPBI情報を持つ。

- Context / Why
- In scope / Out of scope
- Acceptance Criteria
- Evidence
- Unknowns
- Assumptions

実行時は対象variantの `ai-dev-plan/SKILL.md` と、**同じrepo SHAのbundled references / rules**を使用する。

### PBI materialization

`ai-dev-plan` は実体 `docs/working/TASK-XXXX/pbi-input.md` が無い場合にPlanを開始しない。
固定wrapperによるmaterializationは実行前に一度だけ済ませ、8ケースを `docs/working/eval-inputs/PDP-EVAL-v1/` にfreezeした。
各runでは選択ケースのfrozen PBIを **byte-for-byte copy** して `docs/working/TASK-EVAL-PDPXX/pbi-input.md` に置く。

- source→derivedのsemantic field equalityは8ケース全件PASS済み
- run時に要約・再materialize・補完はしない
- baseline/candidateで同一bytes
- materialized PBIのSHA256をledgerへ保存
- generator workspaceには選択ケースのPBIだけを置く
- hash不一致pairは `INCONCLUSIVE_INPUT_MISMATCH`


## 3.1 Execution surface freeze

固定SHAのrepo snapshotを確認すると、`.agents/skills/ai-dev-plan/` には bundled `references/` が存在しない一方、同一SHAの
`plugin/plangate/skills/ai-dev-plan/` には配布用bundleが存在する。

したがって本pilotは **repo SHAをvariant identity、plugin bundleを実行面** として固定する。

**Checkout isolation**

- generatorへ linked worktree を渡さない。
- baseline/candidateごとに、選択SHAだけを持つ独立checkoutをoperator側でmaterializeする。
- peer variant / current main / source repo のGit objectsへ到達できないことをnegative controlで実測する。
- source remote / alternates / partial-clone promisorをmodel-visible execution前に除去する。
- model-visible checkoutは選択PBIと当該SHAのrepo snapshotだけを持つ。
- 詳細なPASS条件はExecution Packet §8.2を正本とする。

### Baseline

- repo SHA: `612c3dacacf76c0bfd72559fbbe0bc41bc41443d`
- Skill: `plugin/plangate/skills/ai-dev-plan/SKILL.md`
  - Git blob: `139fadd69c39fa0079ee8b44ca20d3f4830819fd`
- refs:
  - `ai-driven-development.md`: `3ec9e74bdd65ee72fe88edc4a101d2f1252be3d6`
  - `plan-metrics-verification.md`: `c763b06d79bc281bb336a38cc7be42f93f774822`
  - `core-contract.md`: `914b6467afe49928c364ca277aed6e9a4a2072d5`
  - `plan-template.md`: `3735169a24bc94c09c76720435d0d372720207ab`
  - `todo.md`: `339fd09dd7abd26b8cb9cb16c4374114d7648232`
  - `test-cases.md`: `c6d9da1c9be660c648d594fe847bb42caa110263`

### Candidate

- repo SHA: `4b3f4017ad6c2a64813524ec8567a289f722cb45`
- Skill: `plugin/plangate/skills/ai-dev-plan/SKILL.md`
  - Git blob: `e8d773fc47e224d1d1a9fcf179ec970aa271c4e0`
- refs:
  - `ai-driven-development.md`: `3ec9e74bdd65ee72fe88edc4a101d2f1252be3d6`
  - `plan-metrics-verification.md`: `c763b06d79bc281bb336a38cc7be42f93f774822`
  - `core-contract.md`: `914b6467afe49928c364ca277aed6e9a4a2072d5`
  - `plan-template.md`: `5f0c37ea4a2539a70aa78c06584d9b54ec804f03`
  - `todo.md`: `339fd09dd7abd26b8cb9cb16c4374114d7648232`
  - `test-cases.md`: `1832e6c084e487c8b0e59ccac3f910f44bcdd6d3`

両SHAで `AGENTS.md` / `CLAUDE.md` / `.claude/rules/working-context.md` / `mode-classification.md` / `hybrid-architecture.md`
は同じblobであることを事前確認した。差分はSkillとPR #1336で意図的に変化したPlan/Test template等として扱う。

**評価対象の主張単位**は「Skill単体」ではなく **PR #1336で固定したPlan-generation harness差分** とする。

### B-1

本pilotはpaired conditionを固定するため非対話で行う。

- 入力から解決できる質問はEvidenceとして扱う
- 追加確認が必要なら Questions / Unknowns に記録
- 人間から追加回答を注入しない
- Blocking UnknownでPlan確定不能なら、その停止判断自体を出力へ残す
- 不足をfixture外の推測で埋めない

### B-2

B-3まで進んだ出力は2〜3案の実質的trade-off比較を維持する。B-1で正しいBlocking Unknownにより停止した場合はB-2をN/Aとし、停止妥当性を別評価する。

### B-3

対象Skillが要求する `plan.md / todo.md / test-cases.md` の契約に従う。評価の主対象はPlan設計判断とTest Case traceだが、todo生成を勝手に省略してSkill契約を変えない。

### Metrics Evidence

synthetic fixtureから実数を取得できない項目は「未取得 / 非該当 / 追加調査必要」とする。架空のgrep件数や測定値を作ることはFAIL候補。

## 4. Paired execution

- 8ケース × baseline/candidate × 3 trial = **48 generation**
- 各generationは独立コンテキスト
- 同一model ID / effort / input / budget / timeout / tool policy
- generator input bytesはbaseline/candidate共通
- trial順はledgerのmatrixどおりvariant先行を交互にする
- networkは原則off
- raw outputを加工せず保存しhashを取る
- baselineへcandidate-only文書を補完しない
- candidateへbaselineとは異なる追加説明を渡さない

### Identity / Activation

installedだけではactivation証明にならない。

各runで:
- repo SHA
- skill path/hash
- loaded references path/hash
- resolution failure
- outputでPrinciples/Skillが判断へ影響した位置
を記録する。

variant identityまたはactivationが確認できないpairは、効果比較を `INCONCLUSIVE` とする。

## 5. Blind review

reviewerはgeneratorと別担当にする。

1. raw outputを匿名IDへ変換
2. baseline/candidate名を隠す
3. reviewerへ generator input + reviewer-only rubric を渡す
4. axisごとに PASS / FAIL / NOT_APPLICABLE / INCONCLUSIVE
5. evidence位置と理由を記録
6. variant identityを採点完了後に開示
7. 不一致があればadjudicatorと理由を残す

generatorの自己評価は採用判定に使わない。

## 6. Pair-level judgment

rubricの固定規則に従い、各caseを以下へ分類する。

- **Improvement signal**
- **Regression**
- **No demonstrated difference**
- **INCONCLUSIVE**
- **Other change — needs adjudication**（上記に収まらない軸別変化）

3 trialはpilot診断であり、統計的有意差・一般化された効果を主張しない。

重大回帰が1件でもあればcandidateを「改善済み」とは扱わない。

## 7. 既存PlanGateBench / eval-runnerとの関係

既存 `PlanGateBench` は代表task pattern固定、`scripts/eval-runner.py` / `bin/plangate eval` は完成TASKの既存評価を担う。

本pilotは **plan生成時のsemantic design judgment** をpaired比較する補助評価であり、既存runnerの代替ではない。

禁止:
- plan-only出力を完成TASKに見せるため偽 `handoff.md` / `c3.json` を作る
- 既存eval schemaへ未定義rubric fieldを無理に追加する
- runnerの自己申告由来評価を独立したsemantic証明として扱う

正式に完了したTASKを用いる後続dogfoodingでは、既存evalへ接続してよい。

参照:
- [Plan Design Principles](../../ai/plan-design-principles.md)
- [PlanGateBench](../../ai/plangatebench.md)
- [既存eval-runner](../../ai/eval-runner.md)
- [実行契約](../../ai/core-contract.md)

## 8. Start gate

以下が揃うまで48 generationを開始しない。

- [x] generator inputs / materialization wrapper凍結
- [x] reviewer rubric凍結
- [x] ledger / run matrix凍結
- [x] baseline/candidate SHA確認
- [x] model ID / effort固定
- [x] input/output token budget固定
- [x] timeout固定
- [x] tool/network policy固定
- [x] isolated generator workspaceの手段確認
- [x] raw output保存先確認
- [x] independent reviewer確認
- [x] skill/reference hash取得方法確認

### Execution configuration

**Generator**

- CLI: Codex CLI `codex exec`
- model: `gpt-5.6-sol`
- reasoning: `high`
- sandbox: `workspace-write`
- approval: `never` via `approval_policy="never"` config override
- network: off (`sandbox_workspace_write.network_access=false`)
- writable purpose: Plan artifacts only; implementation/source changes are forbidden by the common request
- session: `--ephemeral`
- generation timeout: 600 seconds
- measured token ceiling per generation:
  - input <= 64,000
  - output <= 16,000
  - ceiling超過は `INCONCLUSIVE_BUDGET`; budgetを後から広げて同じsetへ混ぜない

**Blind reviewer**

- CLI: Codex CLI separate fresh context
- model: `gpt-5.6-terra`
- reasoning: `high`
- sandbox: `read-only`
- approval: `never`
- network: off
- timeout: 600 seconds
- measured token ceiling per scoring run:
  - input <= 64,000
  - output <= 8,000
- reviewer input: materialized PBI + anonymous generated artifact bundle + final response + frozen rubricのみ
- reviewerはrepo checkout / variant name / generator event logを読まない
- adjudicator: Human。critical regression / Other change / reviewer判定不能のみ

同じmodel familyを使う点は限界として記録する。generator/reviewerはモデルID・context・可視情報を分離するが、
cross-vendor independenceを主張しない。

**Pilot total token ceiling**

- generator: 48 × (64k input + 16k output) = **3,840,000 tokens**
- blind scoring: 48 × (64k input + 8k output) = **3,456,000 tokens**
- paired-run combined hard ceiling: **7,296,000 tokens**
- pre-run 3-call smoke ceiling: **232,000 tokens**
- grand ceiling including smoke: **7,528,000 tokens**
- retryは元runを上書きせず新run set扱い。combined ceilingへ加算する
- ceilingを超える見込みなら新runを開始せず `INCONCLUSIVE_BUDGET` としてHuman判断へ送る
- この数字は料金見積もりではなく、比較条件を途中変更しないためのtoken budget contract

**Output / log storage**

run中は評価checkout外の一時rootへ保存する。

```text
$TMPDIR/plangate-pdp-eval-v1/
  runs/<pair>/<variant>/final.md
  runs/<pair>/<variant>/events.jsonl
  runs/<pair>/<variant>/stderr.log
  review/<pair>/<anonymous-id>.md
  manifests/
```

後続runから過去出力が見えないよう、generatorの独立checkout / model-visible environmentへこのrootをmount/copyしない。
全run完了後にraw evidenceをrepository側へ取り込む。

**Runtime prerequisite (operator machine)**

Start gateの設計はfreeze済みだが、実走開始直前に以下を実測する。

- `codex --version` が **0.144.0以上**
- smoke開始時のexact Codex CLI versionをledgerへfreezeし、全48 generation + scoringで同一versionを使う
- ChatGPT/API authが有効
- `gpt-5.6-sol` / `gpt-5.6-terra` がmodel catalogに存在
- `timeout` または `gtimeout` が存在
- exact 3-call smoke（baseline/candidate generator + blind reviewer）がExecution PacketどおりPASS
- smoke / generation / scoringで `approval_policy="never"` とsandbox/network policyが同一に解決される
- event JSONLでmodel / usage / tool activityを記録可能

いずれかが満たせなければ48runを開始せず `INCONCLUSIVE_NOT_RUN`。


揃わない場合は `INCONCLUSIVE_NOT_RUN`。未実行をPASSへ変換しない。

## 9. 実行順

1. 本PRでprotocol/input/rubric/ledgerをレビューして凍結
2. 実行環境とbudgetを確定
3. 48 generation
4. blind scoring
5. pair-level comparison
6. #1337へ結果とraw evidenceを記録
7. Improvement / Regression / No difference / Inconclusive に応じて次施策決定

評価途中で#1335 candidate SHAを変えない。

#960、#933/#810/#867のproduction変更は本pilotへ混ぜない。

## 10. Completion boundary

**本PRのmerge = #1335の効果証明ではない。**

本PRで完了するもの:
- fixed generator input
- hidden reviewer rubric
- paired run ledger
- contamination / identity / activation / missing-data contract
- 実行順とstop条件

#1337をcloseするには、原則として:
1. 48 generationのraw evidence
2. blind scoring
3. pair-level judgment
4. missing/contaminated runの明示
5. 次施策の決定
が必要。

実行環境が恒常的に確保できない場合は、AC自体をHuman判断で再スコープし、未実行のままcloseしない。

## 11. Review log

### 2026-09-23 review

検出して反映:
- **Major**: input / expected behavior / failures / rubric が同一ファイルにありgenerator contaminationしうる
  - → generator input / reviewer rubricを物理分離
- **Major**: run manifestが文章だけで、48runのidentity/activation/contaminationを追跡できない
  - → ledger template + 24 paired matrix追加
- **Major**: synthetic短文が `ai-dev-plan` のPBI INPUT契約へ十分接続されていない
  - → 全8ケースを Context/Scope/AC/Evidence/Unknown/Assumption 形式へ正規化
- **Medium**: B-1を対話実施するとpair条件がずれる
  - → non-interactive contract、Question/Unknownとして記録
- **Medium**: Metrics Evidenceを無理に満たそうと架空実測を作る余地
  - → unavailable/non-applicableを明示し架空値禁止
- **Medium**: repo内でファイル分離してもgeneratorがread可能ならblind性が無い
  - → isolated workspace / allowed-readをstart gateへ追加
- **Major**: `ai-dev-plan` は実体 `docs/working/TASK-XXXX/pbi-input.md` を要求するため、ケース一覧だけではactivation条件を満たさない
  - → fixed wrapperによるper-case PBI materializationとhash一致契約を追加
- **Medium**: PDP-08のcreated_at fixture値が実行時注入でpair間差分になり得る
  - → `2026-09-20T00:00:00Z` を固定Evidenceとして凍結
- **Medium**: generator visibility記述が「8ケースsource全文」と「選択1ケースPBI」で矛盾
  - → sourceはoperator-only、generatorはmaterialized 1ケースだけへ統一

現時点のblocking finding:
- protocol / execution config文書化については **なし**
- 48runについては **operator machineのCodex CLI/auth/runtime smoke未実測のため未開始**
- upstream dogfoodでは `.agents/skills/ai-dev-plan/references/` が存在しない点をMajorとして検出し、
  同一SHAの `plugin/plangate/skills/ai-dev-plan/` bundleを実行面として固定して解消

### Runtime compatibility review (2026-09-23)

- OpenAI current guidance requires Codex CLI **0.144.0+** for GPT-5.6 access.
- `approval_policy` is the canonical config key and supports `never` for non-interactive execution.
- generator invocation therefore uses `-c 'approval_policy="never"'` rather than depending on subcommand-specific approval flag spelling.
- exact `codex --version` is frozen at smoke and must remain identical for the entire run set.
- model IDs `gpt-5.6-sol` / `gpt-5.6-terra` and reasoning `high` remain valid.
- runtime smoke still decides actual local availability; documentation support is not converted into PASS.

### 追加レビュー反映

- 実行経路はupstream-repositoryに固定。Skillと参照先を当該SHAから解決し、参照不能を記録する。Skill本文だけの効果と断定せず、テンプレートを含むPR #1336全体の比較として扱う。
- generator入力の設計回答に相当する禁止・誘導を削減。ACと観測事実は保持。
- 正しい停止とB-2欠落を分離し、比較不能・既存欠陥・新規回帰・その他変化の判定を明確化。
- raw出力の匿名コピーは意味内容を書き換えない。本文から版が推測される可能性はblindの限界として記録。
- このpilotは合成入力での判断評価。実リポジトリ探索能力・実運用生産性への一般化はしない。
