# TASK-1232 / PR #1249 受入基準の訂正記録

> PR #1249（ai-dev 実行資材の plugin 同梱 / #1232 AC-1〜5）マージ後の敵対レビューで、
> **成立していない AC / 前提の記述**が 4 件見つかった。AC を「PASS だった」と残したまま是正だけ
> するとレビュー記録が実態と食い違うため、訂正をここに集約する。
>
> 測定は本ファイル作成時点の `origin/main`（`64a5e4d`）+ 是正差分に対する実測。
> 件数・パス構成は運用で変わるため、**契約値ではなく測定値**として読むこと。

## 1. AC-5「CI の `paths:` は拡張不要」→ **撤回**（Human-owned 未適用アクションへ）

**当時の記述**: `.github/workflows/sync-plugin-plangate.yml` の `paths:` は拡張不要 = PASS。

**実測**: 成立しない。`_ai_dev_ref_spec` が読む同梱元のうち、以下は `on.push.paths` /
`on.pull_request.paths` の**どちらにも入っていない**（`tests/extras/ta-71` TC-20 が機械照合）:

```
docs/ai-driven-development.md
docs/plangate.md
docs/ai/core-contract.md
docs/ai/plan-metrics-verification.md
docs/ai/settings-wiring-contract.md
docs/working/templates/**（9 テンプレート）
```

これらだけを変える PR では **drift-check job がそもそも起動しない**。実際に 2 回起きている
（PR 内で手作業の再生成コミットが必要になった / マージ直後に配布物が stale 化し、後続の
bot PR は別要因で `plugin/plangate/**` が触れられたため偶然起動しただけ）。

**扱い**: PASS ではなく **Human-owned の未適用アクション**。`.github/workflows/**` は
Hardening Override のため AI は適用できない。

- 適用用 patch: [`patches/sync-plugin-paths.patch`](./patches/sync-plugin-paths.patch)
- 追跡: `tests/extras/ta-71-ci-static-lint.sh` TC-20 + KNOWN-GAP flag
  `tests/fixtures/sync-paths-known-gap-1249.flag`

### 追跡機構を「恒久 FAIL」にしなかった理由

当初は TC-20 を **patch 適用まで FAIL のまま**にした（未適用の追跡シグナルを
赤で残す意図）。しかし実測したところ、それは**別の不変条件を壊す**:

extras は standalone で `rc=0` か `rc=3`（`pg_extra_contract_skip` 由来）の
いずれかであることが harness の契約で、`ta-61-extra-contract.sh` の TC-12 が
fail-closed で検査している。恒久 red の extras は自分 1 件では済まず、

```
[FAIL] TC-12: ta-71-ci-static-lint stage-1 classification failed
       — rc=1 is neither 0 nor 3 (fail-closed)
```

を道連れにする（フルスイート実測で確認）。

そこで `ta-65` が #1089 で確立した **KNOWN-GAP flag 方式**に揃えた。gap の受理は
flag ファイルの存在に紐づけ、**4 状態すべてでドリフトが赤くなる**ようにしてある:

| flag | `paths:` の被覆 | 判定 |
| --- | --- | --- |
| あり | 未被覆 | PASS（既知 gap として受理。**未被覆パス一覧を毎回出力**） |
| あり | 被覆済 | **FAIL** — stale 宣言（patch 適用済み。flag を消すこと） |
| なし | 未被覆 | **FAIL** — 未適用 or `paths:` の退行 |
| なし | 被覆済 | PASS（適用後の定常状態） |

4 状態とも実測で確認済み（被覆側は `PG_TA71_SYNC_WORKFLOW` に patch 適用後の
ファイルを渡して検証。本体 workflow は 1 バイトも触っていない）。
「黙って緑」になる経路は無く、flag 自体が未適用アクションの greppable な記録になる。

## 2. AC-3「配布 32 ファイル全数で rc=2 が 0 件」→ **文言訂正**

**当時の記述**: 配布 32 ファイルすべてが hook rc=0。

**実測**（`PLANGATE_SKIP_REASON` を **unset** して EH-3 = `scripts/hooks/check-plan-hash.sh`
に各ファイルを `PLANGATE_HOOK_FILE` で通す）:

| 対象 | 件数 | EH-3 rc |
|------|-----:|--------|
| `.md` 配布物（`SKILL.md` + `references/**`） | 28 | **0**（28/28） |
| `agents/openai.yaml` | 4 | **2** |

**訂正後の文言**: 「`.md` 配布物 28/28 が rc=0。`agents/openai.yaml` 4 件は
pre-existing の rc=2」。

**rc=2 の理由**（環境由来であり #1249 の同梱物固有ではない）: EH-3 は doc-light 経路で
`.md` のみの変更を SKIP するが `.yaml` は SKIP せず、ブランチ名から導出した TASK 文脈
（例: `fix/1232-…` → `TASK-1232`）の `plan.md` が不在なため rc=2 を返す。
`ai-loop-cycle/agents/openai.yaml` も同条件で同じ rc になる。
元の計測が rc=0 だったのは、セッション env に `PLANGATE_SKIP_REASON` が設定されていて
hook が SKIP していたためで、**測定条件の記録漏れ**だった。

## 3. AC「`check-stale-skill-refs.py` rc=0 / WARN 0」→ **空振り。明示走査へ差し替え**

**実測**: `scripts/check-stale-skill-refs.py` の既定走査 root は **`.claude/**` のみ**
（`.claude/skills/**` / `.claude/commands/**` / `.claude/agents/**`）。#1249 の変更ファイルに
`.claude/` 配下は **0 件**で、ai-dev-* skill の正本は `.agents/skills/` にある
（`.claude/skills/ai-dev-plan/` は存在しない）。つまり当該 AC は **1 ファイルも検査せずに
rc=0 を得ていた**。

**差し替え後**（明示走査）:

```sh
python3 scripts/check-stale-skill-refs.py '.agents/skills/ai-dev-*/SKILL.md'
```

測定結果: **WARN 4 件・rc=1**。内訳は 4 skill すべて同一クラスで、`<skill_dir>` 環境表の
`install.sh --claude` 導入先の行（`.claude/skills/ai-dev-<name>/`）を「非実在パス」として
拾ったもの。これは **導入先での着地点**であって上流のファイル参照ではないため、検査器から
見た false positive にあたる。`ai-loop-cycle` の同型の行が既定走査で緑なのは、
`.claude/skills/ai-loop-cycle/` が上流にたまたま実在する（ドッグフーディングで配置済み）
ためであり、**規約が守られているからではない**。

**扱い**: 本 4 件は #1249 由来の pre-existing。是正差分で新規 WARN は増えていない
（差分適用後の測定でも 4 件・同一クラス）。ai-dev-* を `.claude/skills/` へ配置するか
検査器側にプレースホルダ規則を足すかは別 PBI。

## 4. 「`.codex` は変更前は byte-identical だった」→ **誤り**

**実測**（PR #1249 の merge-base = `179117c^` で `.agents/skills/<s>/SKILL.md` と
`.codex/skills/<s>/SKILL.md` を `cmp`）:

| skill | merge-base 時点 | HEAD 時点 |
|-------|----------------|----------|
| `ai-dev-plan` | **DIFF**（12 行） | DIFF（117 行） |
| `ai-dev-exec` | **DIFF**（8 行） | DIFF（76 行） |
| `ai-dev-verify` | **DIFF**（8 行） | DIFF（8 行 → HEAD で 87 行） |
| `ai-dev-brainstorm` | IDENTICAL | DIFF（68 行） |

4 本中 **3 本は #1249 以前から乖離していた**（#1144 由来のブロックが `.codex` 側に
無かった）。「今回はじめて乖離した」という前提は事実と異なる。

**併せて是正した構造的な矛盾**: `scripts/install-plangate-skills-to-codex.sh`（上流 repo が
自分の `.codex/skills/` を作るドッグフーディング経路）は source が `.agents/skills/` であり、
そこには ai-dev-* の `references/` が存在しない（`references/` は
`scripts/sync-plugin-plangate.sh` が `plugin/plangate/skills/**` にだけ生成する）。
したがって上流の `.codex/skills/<skill>/references/` は **構造上つねに不在**なのに、
配る SKILL.md は「Codex 経由も `<skill_dir>/references/` で解決可」と書いていた。
配布経路（`plugin/plangate/scripts/install-plangate-skills.sh`。source は
`plugin/plangate/skills/`）では記述どおり成立するので、矛盾するのは**上流の
ドッグフーディング経路だけ**である。この非対称を 4 skill の SKILL.md に明記した。
経路自体の一本化は **#1086 の裁定待ち**。

## 5. 是正の所在（索引）

| 指摘 | 是正の所在 | 回帰を止めるもの |
| --- | --- | --- |
| MAJOR-1 CI `paths:` 未拡張 | `patches/sync-plugin-paths.patch`（Human 適用）+ KNOWN-GAP flag | `ta-71` TC-20 |
| MAJOR-2 新規 guard にテスト 0 件 | — | `ta-26` TC-39〜TC-44（新規 6 TC） |
| MAJOR-3 ソース不在の無警告脱落 | `scripts/sync-plugin-plangate.sh`（`_warn` + 削除保留） | `ta-26` TC-42 |
| MAJOR-3 per-skill guard の弱さ | 同スクリプトの限界注記を実測へ差し替え | `ta-26` TC-44 |
| MINOR-1 AC-3 の rc=2 | 本ファイル §2 | — |
| MINOR-2 stale-refs の空振り | 本ファイル §3 | — |
| MINOR-3 `.codex` 前提の誤り / Codex 経路の矛盾 | 本ファイル §4 + 4 skill の SKILL.md | — |
| MINOR-4 二重管理の挙動誤記 | `scripts/sync-plugin-plangate.sh` のコメントを実測へ差し替え | `ta-26` TC-43 |
| MINOR-5 入口コマンドの `../` リンク 3 本 | `patches/ai-dev-workflow-command-links.patch`（Human 適用） | — |

`.claude/commands/**` / `.github/workflows/**` はいずれも Hardening Override のため
AI は適用できない。**patch を適用したあとに `sh scripts/sync-plugin-plangate.sh` を
実行して配布ミラー（`plugin/plangate/commands/ai-dev-workflow.md`）を追従させること**
（配布ミラーは同期生成物であり、直接編集すると drift になる）。
