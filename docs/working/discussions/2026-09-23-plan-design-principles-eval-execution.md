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

run前に選択ケースの凍結済みPBIだけを:

```text
$WT/docs/working/TASK-EVAL-PDPXX/pbi-input.md
```

へコピーする。

禁止:
- current mainのeval plan/rubricをworktreeへコピー
- 他7ケースをコピー
- 過去run outputをコピー
- workspace間でCodex threadをresume

## 4. Generator invocation template

```sh
timeout 600 codex exec \
  --ephemeral \
  --model gpt-5.6-sol \
  -c 'model_reasoning_effort="high"' \
  --sandbox read-only \
  --ask-for-approval never \
  --json \
  --output-last-message "$RUN_ROOT/final.md" \
  "$PROMPT" \
  >"$RUN_ROOT/events.jsonl" \
  2>"$RUN_ROOT/stderr.log"
```

networkはCodex read-only sandboxのdefault無効を使う。network enable overrideを渡さない。
MCP / app / external repo / browserを使用しない。

共通promptはgenerator input文書の「共通依頼」に加え、plugin Skill pathを明示する。
baseline/candidateでprompt bytesを同一にする。

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
- final outputでSkill/Principles/Templateの影響が観測できる箇所

「Skillを読んだ」という自己申告だけではactivation proofにしない。

## 7. Blind reviewer

reviewer workspaceには次だけを置く。

- selected materialized PBI
- anonymous final output
- frozen rubric

置かない:
- generator checkout
- repo SHA
- baseline/candidate label
- generator events/stderr
- pairのもう片方のvariant identity

review commandは同じread-only/no-network policyで `gpt-5.6-terra` / high。
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

## 9. Operator smoke gate

48run前に1つも本番pairを消費せず確認する。

- [ ] `codex --version`
- [ ] `gpt-5.6-sol` available
- [ ] `gpt-5.6-terra` available
- [ ] read-only / approval never / ephemeral が起動
- [ ] networkを使わない
- [ ] JSONLにusage / tool eventsが残る
- [ ] final messageを別fileへ保存できる
- [ ] baseline/candidate両方でplugin Skill + refsを読める
- [ ] reviewer workspaceからvariant identityを読めない

smokeで失敗したら48runを開始しない。

## 10. Known limitation

generatorとreviewerは別model ID・別contextだが同じOpenAI/Codex family。
cross-vendor blind reviewではない。このpilotではvariant biasを減らす独立contextとして採用し、
モデルfamily共通blind spotの除去までは主張しない。
