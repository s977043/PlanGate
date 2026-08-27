# TASK-1232 / PR #1249 受入基準の訂正記録

> PR #1249（ai-dev 実行資材の plugin 同梱 / #1232 AC-1〜5）マージ後の敵対レビューで、
> **成立していない AC / 前提の記述**が 4 件見つかった。AC を「PASS だった」と残したまま是正だけ
> するとレビュー記録が実態と食い違うため、訂正をここに集約する。
>
> 測定は本ファイル作成時点の `origin/main`（`64a5e4d`）+ 是正差分に対する実測。
> 件数・パス構成は運用で変わるため、**契約値ではなく測定値**として読むこと。
>
> **2 巡目（`e34331f` に対する敵対レビュー）で critical 2 + minor 4 が追加検出された。
> 是正は §6 に集約している。§4 の数値は 2 巡目で実測し直した値に差し替え済み、
> §5 の索引は「記録だけがあって実装が無かった」行を明示した。**

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

> **数値訂正（2 巡目レビュー MINOR-3）**: 下表の「HEAD 時点」列は当初 117/76/87/68 と
> 書いていたが、それは **是正差分を入れる前（`64a5e4d`）の値**であり HEAD の値ではなかった。
> 再実測して差し替える。測定は `diff <.agents 側> <.codex 側> | grep -c '^[<>]'`。

| skill | merge-base 時点（`179117c^`） | 是正前（`64a5e4d`） | HEAD 時点 |
|-------|------------------------------|--------------------|----------|
| `ai-dev-plan` | **DIFF**（12 行） | DIFF（117 行） | DIFF（**128 行**） |
| `ai-dev-exec` | **DIFF**（8 行） | DIFF（76 行） | DIFF（**87 行**） |
| `ai-dev-verify` | **DIFF**（8 行） | DIFF（87 行） | DIFF（**98 行**） |
| `ai-dev-brainstorm` | **IDENTICAL**（0 行） | DIFF（68 行） | DIFF（**79 行**） |

4 本中 **3 本は #1249 以前から乖離していた**（#1144 由来のブロックが `.codex` 側に
無かった）。「今回はじめて乖離した」という前提は事実と異なる。

**本 PR は既存 drift を 4 本すべてで拡大している（+11 行 × 4）**。`.codex` 経路の
非対称を明記した 11 行ブロックを `.agents/skills/**` と `plugin/plangate/skills/**` にだけ
入れ、`.codex/skills/*/SKILL.md` には入れていないため（実測: 当該ブロックの grep 一致は
`.agents` 4/4・`plugin` 4/4・`.codex` 0/4）。とくに `ai-dev-brainstorm` は merge-base 時点で
**IDENTICAL だったものが 79 行 DIFF になった** ＝ #1249 と本 PR で初めて乖離した 1 本である。

`.codex/skills/` は `scripts/install-plangate-skills-to-codex.sh` が `.agents/skills/` から
生成するドッグフーディング成果物なので、同スクリプトを流せば追従する。本 PR では
**意図的に流していない**（経路一本化が #1086 の裁定待ちで、いま流すと裁定前の構造を
既成事実化するため）。**drift を縮小したのではなく拡大したまま残している**ことを
既知課題として記録する。

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
| MAJOR-3 ソース不在の無警告脱落 | `scripts/sync-plugin-plangate.sh`（`_warn` + 期待集合へ保持して削除保留）。**`e34331f` 時点では未実装のまま索引だけ書かれていた** — §6 CRITICAL-1 で実装 | `ta-26` TC-42 |
| MAJOR-3 per-skill guard の弱さ | 同スクリプトの限界注記を実測へ差し替え | `ta-26` TC-44 |
| MINOR-1 AC-3 の rc=2 | 本ファイル §2 | — |
| MINOR-2 stale-refs の空振り | 本ファイル §3 | — |
| MINOR-3 `.codex` 前提の誤り / Codex 経路の矛盾 | 本ファイル §4 + 4 skill の SKILL.md | — |
| MINOR-4 二重管理の挙動誤記 | `scripts/sync-plugin-plangate.sh` のコメントを実測へ差し替え（「互いに消し合う」→ 一方向 COPY→DELETE の非収束）。**`e34331f` 時点では未実装** — §6 CRITICAL-1 で実装 | `ta-26` TC-43 |
| MINOR-5 入口コマンドの `../` リンク 3 本 | `patches/ai-dev-workflow-command-links.patch`（Human 適用） | — |

`.claude/commands/**` / `.github/workflows/**` はいずれも Hardening Override のため
AI は適用できない。**patch を適用したあとに `sh scripts/sync-plugin-plangate.sh` を
実行して配布ミラー（`plugin/plangate/commands/ai-dev-workflow.md`）を追従させること**
（配布ミラーは同期生成物であり、直接編集すると drift になる）。

## 6. 2 巡目 敵対レビューの是正（critical 2 + minor 4）

> 1 巡目の是正差分（`e34331f`）に対する 2 巡目。**1 巡目の是正そのものを疑う**焦点
> （[`review-principles.md`](../../../.claude/rules/review-principles.md) §7-quater）で
> 回したところ、「記録と実装の乖離」「ガードが壊れても緑」「抽出が形状依存で lossy」の
> 3 クラスが出た。いずれも**前ラウンドが構造的に見られなかった層**である。

### CRITICAL-1: 是正の記録と実装が乖離し、ブランチが自分のテストで赤だった

**実測**: `git diff --name-only 64a5e4d..e34331f | grep -c sync-plugin-plangate.sh` → **0**。
§5 の索引は MAJOR-3 / MINOR-4 の是正先を `scripts/sync-plugin-plangate.sh` と書いていたが、
**同ファイルは 1 行も変更されていなかった**。実装は base のまま
`[ -f "$REPO_ROOT/$_ad_src" ] || continue` で、ソース不在時に無警告でソースを落とし、
その basename が期待集合から抜けて直後の削除ループが配布物を実削除していた。

結果、本 PR が新規追加した **TC-42 が自分のブランチで FAIL**（`sh tests/extras/ta-26-plugin-sync.sh`
→ `38 passed, 2 failed` / TC-13 も道連れ）。**「恒久 red の extras は `ta-61` も道連れにする」
という理由で KNOWN-GAP 方式を選んだ同じ PR が、別経路で同じ状態を作っていた。**

**採った選択肢**: **(A) 実装する**。理由は 2 つ。

1. TC-42 は「ソース不在は WARN + 削除保留」という**仕様をすでに書いている**。(B)（TC-42 を
   消して未是正として記録し直す）は、実害（上流の rename 1 本で配布物が rc=0・無警告で
   消える）をそのまま残す。実測でも `core-contract.md` のパスを 1 文字変えるだけで
   4 skill 分が黙って消えることが再現している。
2. `scripts/*.sh` は Hardening Override 対象**外**（HO は `scripts/hooks/*.sh`）なので、
   AI が適用してよい領域である＝(B) を選ぶべき責務上の理由が無い。

**実装**（`scripts/sync-plugin-plangate.sh`）:

- 期待集合を組む段でソース不在を検出したら `_warn` を出し、**basename を期待集合に残す**
  （削除保留）。map には入れない（ソース実パスが無くリンク同一実体判定に使えないため）。
- **`_warn` が出ても exit code は 0 のまま**＝それだけでは CI は緑である。削除を保留する以上
  ファイル状態も変わらないので `git diff --quiet` も緑になる。そこで警告が人に届く経路を
  2 つ確保した:
  - 終端で件数と対象を **stderr へまとめて再掲**（ローカル実行者向け）
  - `GITHUB_ACTIONS` 下では **`::warning::` アノテーション**を出す（緑の run でも
    job サマリと該当 step に表示され、一覧から拾える）
- exit code は変えない。保留は fail ではなく「spec を実パスへ追従させよ」という追従通知で
  あり、非ゼロにすると TC-42 が要求する rc=0 と衝突し、かつ extras の standalone rc 契約
  （0 か 3）も壊す。

**残る限界**: `::warning::` は job を赤くしない。「誰も見なければ配布物は保留されたまま
古くなる」という状態は残る（保留＝削除しないだけで、新しいソースからの更新は止まる）。
これを赤にするには CI 側の扱いを変える必要があり、`.github/workflows/**` は HO のため
本 PR の範囲外。

### MAJOR-2(new): KNOWN-GAP flag が「あらゆる失敗」を PASS に吸収していた

`ta-71` TC-20 のシェル層は python の rc が非ゼロなら何でも `uncovered` に落としていた。
python 側の `assert` は「未被覆」だけでなく `PARSE-FAIL: _ai_dev_ref_spec が見つからない` /
`spec ソース抽出が空振り` / `paths: ブロックが 2 つ未満` も投げるため、**flag が存在する
現状ではこれら全部が KNOWN-GAP として受理され PASS** になっていた。危険なのは
「flag がある期間」＝ Human が patch を当てるまでの**無期限の窓**である。

**是正**: python 側の PARSE-FAIL を専用 rc（`sys.exit(9)`）に分離し、シェル層で
**`rc=9` は flag の有無に関わらず `t71_fail`** にした。

### MAJOR-3(new): spec ソース抽出が字句形状依存で silently lossy

`re.findall(r"'([^' ]+\.(?:md|json|yaml))\s+([^']+)'")` はシングルクォート + 特定拡張子と
いう**書き方**にしか当たらない。ダブルクォート表記・`.sh` 拡張子・既存行のクォート変更が
いずれも無警告で母数から落ち、`srcs >= 10`（実測 15）は 5 本、`PAIRS >= 20`（実測 24）は
4 本の消失を許していた。**floor は「完全な空振り」しか止めない。**

**是正**: 抽出した `_ai_dev_ref_spec` を **実際に `sh` で実行し、その実出力を正とする**
（`ta-71` / `ta-26` の両方に同型のヘルパ `_t*_spec_dump` を置いた）。クォート種別・拡張子・
行継続はシェル自身が解釈するため形状に依存しない。取得失敗（関数が無い / 一覧が無い /
出力が空）は PARSE-FAIL として扱う（`ta-71` では rc=9 に合流する）。

### MINOR-1: `cp -r` のディレクトリ特別扱いがコメント行でも成立していた

`ta-26` TC-40 の `dirs` 抽出が **ta-26 の生テキスト全体**を走査していたため、実行されない
コメント行 `# ... cp -r "$PG_T26_ROOT/docs" foo` を 1 行足すだけで「docs/ 配下は全供給済み」
と誤認し、陽性コントロール（sandbox 一覧から 1 件落とす変異）が無効化できた。

**是正**: sandbox builder を `# >>> PG_T26_SANDBOX_BUILDER_BEGIN` /
`# <<< PG_T26_SANDBOX_BUILDER_END` で囲み、**その区間の、コメントでない行**からのみ抽出する。
マーカーの移動・削除は PARSE-FAIL になる。副作用として `sandbox_dirs` の実測が 5 → 4 に
減ったが、これは 5 件目が **TC-40 自身の説明コメント**に書かれた `cp -r "$PG_T26_ROOT/<dir>"`
という偽の一致だったためで、母数が正しくなった側の変化である。

### MINOR-2: 「未被覆一覧を毎回出力」が実際には半分しか出ていなかった

`cut -c1-600` で 1 行に潰してから切っていたため、`sorted(set(bad))` の並びの都合で
**push 側だけが表示され pull_request 側 14 件が 1 件も見えていなかった**。
**1 行 1 パスで全件出す**ように変更（実測 28 行が出る）。呼び出し側で切り詰めない。

### MINOR-3: `.codex` drift の数値訂正 → §4 に反映済み

### MINOR-4: PlanGate 作業コンテキストの未整備（記録のみ）

`docs/working/TASK-1232/` には `ac-corrections.md` と `patches/` しか無く、
[`working-context.md`](../../../.claude/rules/working-context.md) が定める
`plan.md` / `todo.md` / `test-cases.md` / `INDEX.md` / `current-state.md` / `status.md` /
`handoff.md` / `approvals/c3.json` は**いずれも不在**である。

**本 PR では作成しない**（事実の記録にとどめる）。理由: `plan.md` は EH-3
（`scripts/hooks/check-plan-hash.sh`）が basename `plan.md` を block するため、
TASK コンテキストを持たないセッションからは書けない。整備は Human が
`PLANGATE_HOOK_TASK` を設定した起動で行う必要がある。

**したがって #1232 / #1249 系の一連の作業は、PlanGate の C-3 承認記録を持たない**。
本ファイルが事実上の唯一の作業記録になっている点を、次に触る担当者への申し送りとして残す。

### 検証（2 巡目）

| 対象 | 結果 |
|------|------|
| `sh tests/extras/ta-26-plugin-sync.sh` | **rc=0 / 40 passed, 0 failed**（是正前は rc=1 / 38 passed, 2 failed） |
| `sh tests/extras/ta-71-ci-static-lint.sh` | rc=0 / 23 passed, 0 failed |
| `sh tests/extras/ta-69-distribution-checks.sh` | rc=0 / 27 passed, 0 failed |
| `sh scripts/sync-plugin-plangate.sh --dry-run` | rc=0 / `Sync complete — no changes` |

変異マトリクス（**是正前に SURVIVE を実測 → 是正 → 同じ変異で KILL**）:

| # | 変異 | 是正前 | 是正後 |
|---|------|-------|-------|
| CRITICAL-1 | ソース 1 本を削除（上流 rename の模擬） | 配布物が rc=0・無警告で DELETE = **TC-42 FAIL / スイート赤** | WARN + 保持 = TC-42 PASS |
| MAJOR-2(new) | `_ai_dev_ref_spec` をリネーム（＝検査器を壊す） | `23 passed, 0 failed`（**SURVIVE**） | `TC-20 FAIL`（rc=9 / **KILL**） |
| MAJOR-3(new) | spec に `"newref.md docs/ai/newref.md"` をダブルクォートで追加 | 旧字句抽出は `PAIRS=24 srcs=15`（無変化＝**SURVIVE**） | 実出力は `PAIRS=26 srcs=16`・未被覆一覧に `newref.md` が出る（**KILL**） |
| MINOR-1 | sandbox 一覧から `handoff.md` を落とし、末尾にコメント `cp -r "$PG_T26_ROOT/docs" foo` を足す | `40 passed, 0 failed`（**SURVIVE**） | `TC-40 FAIL`（**KILL**） |

false positive の確認: 上記変異をすべて戻した状態で `ta-26` / `ta-71` / `ta-69` がいずれも
0 failed であること、および `--dry-run` が `no changes` であることを実測済み（上表）。

### 残存脅威モデル（本 2 巡目で守らないもの）

- **`::warning::` は job を赤くしない**。spec ソース不在が長期に放置される経路は残る。
- **spec の「実行結果を正とする」抽出は、関数の切り出し（`awk` の
  `^_ai_dev_ref_spec() {` … `^}`）に依存する**。この 2 行のアンカーを崩す書き換えは
  PARSE-FAIL として赤くなる（黙って通ることはない）が、アンカー自体は字句依存である。
- **`ta-71` TC-20 は「paths: が spec を被覆するか」しか見ない**。workflow の job 定義・
  条件式・concurrency などが壊れて drift-check が実質動かないケースは対象外。
- 本検査は多層防御の 1 層であり、最終的な保証は **C-4 Human レビュー**と
  branch protection が担う。
