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

## 3. Isolated worktree

各generationは新規detached worktreeを作る。

```sh
git worktree add --detach "$WT" "$VARIANT_SHA"
```

run前に `docs/working/eval-inputs/PDP-EVAL-v1/manifest.md` でblobを確認し、選択ケースの凍結済みPBIだけをbyte-for-byte copyする:

```text
$WT/docs/working/TASK-EVAL-PDPXX/pbi-input.md
```

へコピーする。source文書からrun時に再生成しない。

禁止:
- current mainのeval plan/rubricをworktreeへコピー
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

run中のoutput rootをgenerator worktreeから読める場所へ置かない。

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

## 8.2 読み取り隔離のpreflight（smoke前・モデル呼び出しなし）

別worktree / 別temp directoryへの配置だけを読み取り拒否の証拠にしない。
linked worktreeは共有Git管理領域への参照を持つため、共有object databaseからの取得経路も対象にする。
本節は§3の作業場所に加える検証条件であり、新しい評価runnerではない。

operatorは既存の実行環境で次の境界を用意し、その構成・版・許可mount/pathを記録する。
具体的な隔離方式が未設定なら、以下をPASSにせず停止する。

| 実行主体 | 許可する評価データ | 到達させない評価データ |
| --- | --- | --- |
| Generator A/B | 当該SHAのcheckout・bundled references・選択したPBI | rubric、他ケース、他run output、current main、共有Git objects内の非選択版 |
| Reviewer C | §7の匿名bundle・PBI・rubric（smoke時は§9の3ファイル） | checkout、variant mapping、generator logs、他の採点結果 |

CLI実行に必要なruntimeは別途許可する。認証情報をこの検証のために読取・表示・コピーしない。
CLIのモデル接続経路と、モデルが利用するtoolのnetwork-off条件を区別する。
Git共有領域を単にread-only mountしても、禁止データの読み取り防止にはならない。
mount・process・Git objects等を経由して禁止データへ到達しない構成が必要である。
runtime構成の変更はbaseline/candidate両方に同じ条件で適用し、run途中で変更しない。

### 検証手順

1. operator専用領域にrun固有の無害なcanaryを置き、operator側で存在とhashを確認する。
   rubric、他run output、variant mapping、共有Git領域の各禁止経路をダミーデータで代表させる。
   本物のrubricや秘密情報を読ませて試験しない。
2. モデルのtool subprocessと同じ実効UID・mount・sandbox条件で、許可入力のreadが成功することを確認する。
   この条件の同一性を確認できなければ未検証とする。
3. 同じ条件で禁止経路へのreadを試み、全て拒否されることを確認する。
   absolute path、親directory、symlink、共有Git object参照を、存在する経路に応じて含める。
   このprobeはoperatorによる事前検証で、生成promptや採点入力へ加えない。
4. 記録するのは実行構成、probe command、exit code、期待値・実測値、operator側のcanary hash。
   読取成功・設定不明・probe未実施はPASSにしない。
   単なる存在しないpathへのread失敗では不十分で、手順1の存在証拠と対にする。
5. 検証後も同じ境界でSmoke A/B/Cを実行する。
   canaryや検証ログは許可入力へ混ぜない。境界変更時は再検証する。

### 判定・引き継ぎ

- `isolation_preflight`: PASS / FAIL / NOT_RUN
- `runtime_identity`: OS・CLI版・隔離方式/版・構成hash
- `positive_controls`: 許可入力のread成功証拠
- `negative_controls`: 禁止経路別のread拒否証拠
- `tool_boundary_equivalence`: probeとtool subprocessの条件一致証拠
- `evidence_location`: operator専用証跡の保存先

1つでも欠ければ `INCONCLUSIVE_NOT_RUN` のままsmoke・48生成を開始しない。
試験用canaryへの到達は隔離FAILであり、実データの流出を意味するとは断定しない。
本節の文書レビュー完了は、実環境の隔離PASSや追加Major findingの解消を意味しない。

## 9. Operator smoke gate

SmokeはP01〜P24を一切消費しない。**3 callsだけ**実施する。

### Smoke A/B — baseline / candidate generator surface

各variantのdetached worktreeに、評価8ケースとは無関係な一時入力だけを作る。

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

> This is execution-path smoke, not an evaluation case. Read `plugin/plangate/skills/ai-dev-plan/SKILL.md` and at least two bundled references relative to that Skill. Create only `docs/working/TASK-EVAL-SMOKE/smoke-output.md`. In that file list the Skill path and reference paths actually read, then write `SMOKE_OK`. Do not inspect evaluation rubric or PDP-01..08 inputs. Do not implement product code.

baselineとcandidateに1callずつ、generatorと同じmodel/flagsで実行する。

PASS:
- exit 0
- final response captured
- JSONL captured
- `smoke-output.md` exists and contains `SMOKE_OK`
- plugin Skill + >=2 referencesのread evidence
- task directory外write = 0
- network usage = 0

### Smoke C — blind reviewer surface

repo checkoutを渡さない空temp directoryで、次の3ファイルだけを置く。

- `pbi-input.md`: smoke identifier only
- `anonymous-output.md`: `SMOKE_OK`
- frozen rubric copy

`gpt-5.6-terra` / high / read-only / no-networkで:

> This is reviewer-path smoke only. Confirm you can read the three provided files. Output exactly a short SMOKE_REVIEW_OK record. Do not infer or request a repository variant.

PASS:
- exit 0
- `SMOKE_REVIEW_OK`
- model ID / usage in event evidence
- repo / variant identity unavailable

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

- [ ] §8.2 isolation preflight PASS（許可read・禁止read・実行境界一致の証拠）

- [ ] `codex --version` >= 0.144.0 and exact version frozen in ledger
- [ ] baseline Smoke A PASS
- [ ] candidate Smoke B PASS
- [ ] reviewer Smoke C PASS
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
