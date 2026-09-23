# Plan Design Principles Eval — Execution Packet

> Issue: #1337
> Protocol: PDP-EVAL-v1
> Status: config frozen / model runs not executed

## 1. Purpose

この文書は新しいrunnerではない。既存 `codex exec` を用いる **operator procedure** を固定する。

評価checkout:
- baseline: `612c3dacacf76c0bfd72559fbbe0bc41bc41443d`
- candidate: `4b3f4017ad6c2a64813524ec8567a289f722cb45`

generator:
- `gpt-5.6-sol`
- `model_reasoning_effort="high"`

reviewer:
- separate `gpt-5.6-terra`
- `model_reasoning_effort="high"`

## 2. Why plugin bundle

固定SHAの上流 `.agents/skills/ai-dev-plan/` はSkill本文を持つが bundled `references/` を持たない。
配布物として同期された `plugin/plangate/skills/ai-dev-plan/` は、両SHAでSkill + bundled referencesを保持する。

そのためgeneratorには次を明示する。

> Use `plugin/plangate/skills/ai-dev-plan/SKILL.md` as the ai-dev-plan skill. Resolve bundled references relative to that skill directory. Use only files from this checkout and the selected materialized PBI. Do not use network access.

PR #1336の効果はSkill本文だけでなくplan/test template変更を含むため、評価対象はPlan-generation harness差分である。

## 3. Isolated independent checkout

各generationは **linked worktreeではなく、選択variant SHAだけを持つ独立checkout** を使う。
model-visible checkoutからsource repo / peer variant / current mainのGit objectsへ到達できてはならない。

operator materializationの例:

```sh
mkdir -p "$WT"
git -C "$WT" init
git -C "$WT" fetch --depth=1 "$SOURCE_URL" "$VARIANT_SHA"
git -C "$WT" checkout --detach FETCH_HEAD

# materialization後、model-visible execution前にsource取得経路を除去
git -C "$WT" remote remove origin 2>/dev/null || true
git -C "$WT" config --unset-all remote.origin.url 2>/dev/null || true
```

上記は例であり、採用方式は§8.2のnegative controlsを満たす必要がある。
特に次を必須とする。

- selected SHAだけが取得可能
- peer SHA / current main SHAの `git cat-file -e` は失敗
- shared `git-common-dir` なし
- source/peerを指す alternates なし
- partial-clone/promisor なし
- source remoteなし
- model-visible runtimeからsource repo path / socket / mountへ到達不能

run前に `docs/working/eval-inputs/PDP-EVAL-v1/manifest.md` でblobを確認し、
選択ケースの凍結済みPBIだけをbyte-for-byte copyする:

```text
$WT/docs/working/TASK-EVAL-PDPXX/pbi-input.md
```

source文書からrun時に再生成しない。

禁止:
- linked worktreeをgenerator checkoutに使う
- current mainのeval plan/rubricをcheckoutへコピー
- 他7ケースをコピー
- 過去run outputをコピー
- workspace間でCodex threadをresume

### Frozen PBI copy verification

copy後にSHA256を取得し、同一pairのbaseline/candidateで一致を確認する。

```sh
sha256sum "$WT/docs/working/TASK-EVAL-PDPXX/pbi-input.md"
```

macOSでは `shasum -a 256` を使う。

hash mismatchならCodexを起動せず `INCONCLUSIVE_INPUT_MISMATCH`。

## 4. Generator invocation template

```sh
cd "$WT"

git status --porcelain=v1 --untracked-files=all >"$RUN_ROOT/pre-status.txt"

timeout 600 codex \
  --model gpt-5.6-sol \
  -c 'model_reasoning_effort="high"' \
  -c 'approval_policy="never"' \
  -c 'sandbox_workspace_write.network_access=false' \
  --sandbox workspace-write \
  exec \
  --ephemeral \
  --json \
  --output-last-message "$RUN_ROOT/final.md" \
  "$PROMPT" \
  >"$RUN_ROOT/events.jsonl" \
  2>"$RUN_ROOT/stderr.log"
```

`approval_policy="never"` は非対話runの承認ポリシーを明示するcanonical config overrideとして固定する。
workspace-writeを使うのは、ai-dev-plan本来の契約どおり `plan.md / todo.md / test-cases.md` 等のPlan artifactを実ファイルとして生成させるため。
networkは明示的に `sandbox_workspace_write.network_access=false` とする。
MCP / app / external repo / browserを使用しない。

共通promptはgenerator input文書の「共通依頼」に加え、plugin Skill pathと次のwrite boundaryを明示する。

> Create only planning artifacts under `docs/working/TASK-EVAL-PDPXX/`. Do not modify source code, configuration, rules, skills, templates, hooks, or files outside that task directory. Do not implement the requested product change.

baseline/candidateでprompt bytesを同一にする。

### Post-run artifact capture / write-scope evidence

run後にoperatorが:

```sh
git status --porcelain=v1 --untracked-files=all >"$RUN_ROOT/post-status.txt"
find "docs/working/TASK-EVAL-PDPXX" -type f -print | sort >"$RUN_ROOT/task-files.txt"
```

を取得する。

PBIはrun前からoperatorが配置した入力なので、pre/post manifestで区別する。
生成されたPlan artifactを `$RUN_ROOT/artifacts/` へoperatorがcopyし、hashを保存する。

- `plan.md`
- `todo.md`
- `test-cases.md`
- Skill契約上生成された `INDEX.md` / `decision-log.jsonl` 等

task directory外へのwriteは削除して隠さない。
`out_of_scope_writes` として保存し、scope disciplineの採点対象にする。

## 5. Budget contract

Codex CLIのhard output-token capに依存しない。
`--json` event streamのusageを**事後の固定ceiling**として判定する。

generator:
- input <= 64,000 tokens
- output <= 16,000 tokens
- timeout <= 600 seconds

超過:
- output自体をFAIL採点へ混ぜない
- status = `INCONCLUSIVE_BUDGET`
- 当該pairを同じbudgetの新run setへ移すか、pilot全体のbudgetをHuman判断で再設計する
- 途中からbudgetだけ増やしたrunを既存setへ混ぜない

### Pilot-wide budget

- 48 generator runs: max 3,840,000 tokens
- 48 blind scoring runs: max 3,456,000 tokens
- combined max: **7,296,000 tokens**
- retryもこの総量へ加算
- 総量超過見込みなら新run開始禁止

## 6. Activation evidence

events JSONLとfinal outputから記録する。

必須:
- repo SHA
- plugin Skill path / Git blob
- refs path / Git blob
- selected PBI hash
- actual model ID / effort
- relevant read/tool events
- resolution failure
- generated artifacts / final responseでSkill/Principles/Templateの影響が観測できる箇所

「Skillを読んだ」という自己申告だけではactivation proofにしない。

## 7. Blind reviewer

reviewer workspaceには次だけを置く。

- selected materialized PBI
- anonymous generated artifact bundle
- anonymous final response
- frozen rubric

置かない:
- generator checkout
- repo SHA
- baseline/candidate label
- generator events/stderr
- pairのもう片方のvariant identity

review commandは同じread-only/no-network policyで `gpt-5.6-terra` / high。
approvalはgeneratorと同じく `-c 'approval_policy="never"'` を使う。
reviewer ceilingは input 64k / output 8k / timeout 600s。
critical regression / Other change / INCONCLUSIVEはHuman adjudicationへ送る。

## 8. Storage

run中:
```text
$TMPDIR/plangate-pdp-eval-v1/
```

完了後:
- raw final outputs
- JSONL event logs
- hashes
- scoring
- pair judgment
をrepoへ取り込む。

run中のoutput rootをgeneratorの独立checkout / model-visible environmentから読める場所へ置かない。

## 8.1 Runtime compatibility freeze

Current OpenAI guidance requires **Codex CLI 0.144.0 or newer** to access GPT-5.6 in Codex.

At smoke start:

1. run `codex --version`;
2. require version >= `0.144.0`;
3. write the exact version string to the run ledger;
4. use that exact CLI version for Smoke A/B/C, all 48 generations, and all blind scoring calls.

A CLI upgrade/downgrade during the run set is a condition change:
- do not continue the existing set;
- preserve old evidence;
- either restore the frozen CLI version or start a new evaluation set.

Runtime config contract:
- `model_reasoning_effort="high"`
- `approval_policy="never"`
- generator `sandbox=workspace-write`
- generator `sandbox_workspace_write.network_access=false`
- reviewer `sandbox=read-only`
- no browser/MCP/network augmentation

Documentation support is not activation proof. Smoke must still verify the local installation.

## 8.2 読み取り隔離のpreflight（smoke前）

別worktree / 別temp directoryへの配置だけを読み取り拒否の証拠にしない。
linked worktreeは共有Git object databaseへ到達できるため、**generatorのmodel-visible checkoutには使用しない**。
rubricや他run outputを兄弟directoryへ置くだけ、source repoをread-only mountするだけ、promptで「読むな」と指示するだけも隔離証拠にはしない。

本preflightは **A: model-free sandbox control** と **B: actual tool-boundary control** の二段で扱う。
Aの文書/command確認だけではMajor findingをcloseしない。BをSmoke A/B/Cのactual tool eventで実証して初めてclose候補とする。

### 8.2.1 Model-visible filesystemの構成

Generator A/Bには、variantごとに**共有Git object databaseを持たない独立checkout**を用意する。

推奨順:

1. **物理隔離**: container / VM / namespace等で、選択variant checkoutと選択PBIだけをmount/copyし、rubric・他case・他run output・source repo・current mainをmountしない。
2. **明示的read-deny**: exact Codex CLIで有効なpermission profile / filesystem policyを使い、禁止rootをread-denyする。canaryで実測できた場合だけ採用する。

linked worktree単体は不可。

独立checkoutは shallow clone等で作成し、少なくとも次を実測する。

- selected variant SHA: `git cat-file -e <selected_sha>^{commit}` = success
- peer variant SHA: `git cat-file -e <peer_sha>^{commit}` = fail
- current main SHA: `git cat-file -e <current_main_sha>^{commit}` = fail
- `git rev-parse --git-common-dir` がsource repo / peer checkoutの共有Git directoryを指さない
- `.git/objects/info/alternates` が存在しない、またはsource/peer object DBを指さない
- partial-clone/promisor設定を使わない（`extensions.partialClone` / `remote.*.promisor` が無い）
- operator materialization完了後はmodel-visible checkoutから `origin` 等のsource remoteを削除する
- source repoへのfile path / socket / mountがmodel-visible environmentから到達不能

baseline/candidateでcheckout構成手順を同一にする。
`git cat-file` のnegative controlはnetwork/file remoteへlazy fetchできない状態で実行する。

### 8.2.2 許可/禁止データ

| 実行主体 | 許可する評価データ | 到達させない評価データ |
| --- | --- | --- |
| Generator A/B | 当該variant独立checkout・bundled references・選択したfrozen PBI | rubric、他ケース、他run output、current main、peer variant、source repo/shared Git objects |
| Reviewer C | §7の匿名artifact bundle・PBI・rubric（smoke時は§9のreviewer smoke input） | generator checkout、variant mapping、generator logs、他の採点結果 |

CLI実行に必要なruntime/authは別途許可する。認証情報をcanaryとして使わず、内容をread/display/copyしない。
CLIのモデル接続経路と、model-issued tool subprocessのnetwork-off条件を区別する。

### 8.2.3 Canary controls

operator専用host領域にrun固有の**無害なcanary**を作り、実データをprobeに使わない。

最低限:

- allowed canary: selected PBI/checkout側
- denied rubric canary
- denied peer-variant canary
- denied other-run canary
- denied source/shared-Git canary

operatorは各canaryについて host側の存在・SHA256・absolute pathを記録する。
「存在しないpathをreadして失敗」はnegative controlとして無効。

### 8.2.4 A — model-free Codex sandbox control

exact frozen Codex CLIで `codex sandbox --help` を保存し、このCLIが提供するCodex sandbox commandを使ってprobeする。
現行CLI実装には `codex sandbox` があり、permission profileまたは `--sandbox-state-json` を用いたsandbox command実行面を持つ。

ただし、**preflightとgenerator/reviewerのeffective policyが同一であることを証明できる場合だけ** equivalence evidenceとして使う。

許可read:
- allowed canaryをreadできる

禁止read:
- denied rubric / peer / other-run / source-Git canaryをreadできない

記録:
- `codex --version`
- `codex sandbox --help`
- OS / sandbox backend
- permission/sandbox stateの識別情報または構成hash
- probe command
- exit code
- stdout/stderr
- expected / actual

`codex sandbox` commandの存在だけ、またはbuilt-in `:workspace` が動くことだけではPASSにしない。
実際のeval境界より広いprofileでprobeした結果もPASSにしない。

### 8.2.5 B — Smoke内actual tool-boundary control

AだけではMajor findingをcloseしない。
Smoke A/B/Cで**実際のmodel-issued tool boundary**からcanary probeを実行し、JSONL/tool eventで証明する。

Smoke A/B:
- operatorが `docs/working/TASK-EVAL-SMOKE/isolation-probe.sh` を配置する
- scriptはallowed canary read成功 + 全denied canary read失敗を検証し、成功時のみ `ISOLATION_TOOL_OK`
- smoke promptは最初のtool actionとしてこのscriptを1回実行するよう要求する
- JSONLに実tool call・exit codeを残す
- runtime/sandbox identityはeventに出る場合はその値を保存し、出ない場合はoperator manifestのexact CLI version / config hash / isolation hashとactual control結果を対にする
- modelの「読めなかった」という自己申告だけでは不可

Smoke C:
- reviewer temp environmentにもreviewer用canary probeを置く
- anonymous allowed inputsはread成功
- generator checkout / variant mappingを代表するdenied canaryはread失敗
- JSONL/tool eventでactual boundaryを記録する

AとBのruntime identity / policy hash / CLI versionが一致しない場合はFAILではなく **NOT_RUN / reconfigure** とし、評価runへ進まない。

### 8.2.6 判定・引き継ぎ

記録:

- `checkout_isolation`: PASS / FAIL / NOT_RUN
- `sandbox_preflight`: PASS / FAIL / NOT_RUN
- `actual_tool_boundary`: PASS / FAIL / NOT_RUN
- `runtime_identity`: OS・exact CLI版・sandbox backend・隔離方式/版・構成hash
- `positive_controls`: 許可read成功証拠
- `negative_controls`: 禁止経路別read拒否証拠
- `tool_boundary_equivalence`: model-free probeとactual toolの条件一致証拠
- `evidence_location`: operator専用証跡保存先

PASS条件:

1. independent checkoutでpeer/current-main Git objectsへ到達せず、remote / alternates / promisor経由の再取得経路も無い
2. model-free positive/negative controlsが期待どおり
3. Smoke actual tool positive/negative controlsが期待どおり
4. preflightとSmokeでruntime identity / policyが一致
5. canary / probe logがP01..P24の入力へ混入しない

1つでも欠ければ `INCONCLUSIVE_NOT_RUN` のまま48生成を開始しない。
canaryへ到達した場合はisolation FAILとして停止するが、実データ流出が起きたとは断定しない。
本節の文書レビューやPR mergeだけではMajor findingをcloseしない。

## 9. Operator smoke gate

SmokeはP01〜P24を一切消費しない。**3 callsだけ**実施する。

### Smoke A/B — baseline / candidate generator surface

各variantの独立checkoutに、評価8ケースとは無関係な一時入力だけを作る。

```text
docs/working/TASK-EVAL-SMOKE/pbi-input.md
```

内容:

```markdown
---
task_id: TASK-EVAL-SMOKE
artifact_type: pbi-input
schema_version: 1
status: draft
---

# PBI INPUT PACKAGE — TASK-EVAL-SMOKE

## Context / Why
Codex CLI execution-path smoke only.

## What — Scope

### In scope
- bundled ai-dev-plan Skill / references が読めること
- TASK-EVAL-SMOKE 配下へファイルを書けること

### Out of scope
- product design evaluation
- baseline/candidate quality comparison

## Acceptance Criteria
- SMOKE-01: Skill path と2つ以上の bundled reference pathを列挙する
- SMOKE-02: `docs/working/TASK-EVAL-SMOKE/smoke-output.md` を作る

## Notes from Refinement

### Evidence
- This input is not part of PDP-01..08.

## Estimation Evidence
**Risks**: none
**Unknowns**: none
**Assumptions**: smoke output is discarded from scoring
```

共通smoke prompt:

> This is execution-path smoke, not an evaluation case. As your first tool action, run `sh docs/working/TASK-EVAL-SMOKE/isolation-probe.sh` exactly once. Continue only if it exits 0 and prints `ISOLATION_TOOL_OK`. Then read `plugin/plangate/skills/ai-dev-plan/SKILL.md` and at least two bundled references relative to that Skill. Create only `docs/working/TASK-EVAL-SMOKE/smoke-output.md`. In that file list the Skill path and reference paths actually read, then write `SMOKE_OK`. Do not inspect evaluation rubric or PDP-01..08 inputs. Do not implement product code.

baselineとcandidateに1callずつ、generatorと同じmodel/flagsで実行する。

PASS:
- exit 0
- final response captured
- JSONL captured
- `smoke-output.md` exists and contains `SMOKE_OK`
- actual tool JSONLに `isolation-probe.sh` 実行 + `ISOLATION_TOOL_OK` + exit 0
- plugin Skill + >=2 referencesのread evidence
- task directory外write = 0
- network usage = 0

### Smoke C — blind reviewer surface

repo checkoutを渡さない空temp directoryで、次の3ファイルだけを置く。

- `pbi-input.md`: smoke identifier only
- `anonymous-output.md`: `SMOKE_OK`
- frozen rubric copy

`gpt-5.6-terra` / high / read-only / no-networkで:

> This is reviewer-path smoke only. As your first tool action, run the provided reviewer isolation probe exactly once. Continue only if it exits 0 and prints `ISOLATION_REVIEW_OK`. Then confirm you can read the three allowed files. Output exactly a short SMOKE_REVIEW_OK record. Do not infer or request a repository variant.

PASS:
- reviewerにshell/file-read toolが実際にprovisionされている
- exit 0
- `SMOKE_REVIEW_OK`
- actual tool JSONLに reviewer isolation probe + `ISOLATION_REVIEW_OK` + exit 0
- model ID / usage in event evidence
- variant mapping canaryがread不能
- reviewer input directoryにcheckout / mapping / generator logが存在しない

reviewerがread-onlyでtoolを受け取れない場合は `INCONCLUSIVE_NOT_RUN`。
この場でreviewerだけworkspace-writeへ変更して既存run setへ混ぜない。設定変更が必要なら評価条件変更として新しいreview decisionを記録し、Smoke A/B/Cからやり直す。

### Smoke budget

Smokeはpair budgetとは分離して上限固定する。

- 2 generator smoke calls: 2 × (64k + 16k) = 160k
- 1 reviewer smoke call: 1 × (64k + 8k) = 72k
- setup smoke ceiling: **232,000 tokens**

したがって全工程の最大contractは:

- smoke: 232,000
- paired generation + scoring: 7,296,000
- **grand ceiling: 7,528,000 tokens**

smoke failure時:
- P01を開始しない
- status = `INCONCLUSIVE_NOT_RUN`
- failed smoke evidenceを保存
- flag/model/auth変更後に再smokeする場合も旧証跡を上書きしない

### Checklist

- [ ] §8.2 independent checkout PASS（peer/current-main Git objects不可視）
- [ ] §8.2 model-free `codex sandbox` control PASS
- [ ] Smoke A/B/C actual tool-boundary control PASS
- [ ] preflight / Smoke runtime identity・policy一致

- [ ] `codex --version` >= 0.144.0 and exact version frozen in ledger
- [ ] baseline Smoke A PASS
- [ ] candidate Smoke B PASS
- [ ] reviewer Smoke C PASS（read-onlyでactual tool provisionを含む）
- [ ] actual model IDs match frozen config
- [ ] workspace-write + network-off + `approval_policy=never` + ephemeral confirmed
- [ ] all three smoke calls use the frozen exact Codex CLI version
- [ ] JSONL usage / tool events captured
- [ ] final response captured
- [ ] task artifact write captured
- [ ] out-of-scope write = 0
- [ ] reviewer has no variant identity

3 smokeすべてPASSするまで48runを開始しない。


## 10. Known limitation

generatorとreviewerは別model ID・別contextだが同じOpenAI/Codex family。
cross-vendor blind reviewではない。このpilotではvariant biasを減らす独立contextとして採用し、
モデルfamily共通blind spotの除去までは主張しない。
