# TASK-1086 調査: `.codex/skills` と `.agents/skills` の二重 root 登録

> 対象 issue: [#1086](https://github.com/s977043/plangate/issues/1086)
> 本ドキュメントは **調査と是正方針の設計まで**。破壊的操作（`.codex/skills` の削除 / `git rm`）は実施していない。
> 測定環境: `main` = `0385457`（2026-08-15）/ codex-cli **0.144.1** / macOS 15.6 (darwin 25.6.0)
> 測定はすべて worktree `.claude/worktrees/agent-a86447c7e5f9e8b33` 内で実施（cwd 依存の root 探索を含むため、絶対パスは worktree のもの）。

---

## 0. 結論サマリ

| # | 確定した事実 | 根拠 |
|---|---|---|
| F-1 | issue の「件数差 1」は **解消済み**。両 root とも **39 件**、名前の和集合 39・差分 0 | §1 |
| F-2 | `.codex/skills` は **repo に 120 ファイル commit 済み**（SKILL.md 39 + `agents/openai.yaml` + `assets/*.svg` 等） | §1 |
| F-3 | 二重 root は **どの repo 設定ファイル由来でもない**。**Codex CLI の既定 project-scoped 探索**が `<cwd>/.codex/skills` と `<cwd>/.agents/skills` の **両方**を root にする | §2（隔離 `CODEX_HOME` + 合成 fixture の実測） |
| F-4 | 現時点のモデル可視一覧: **合計 115 / ユニーク 75 / 重複エントリ 40**。うち **39 が r0(`.codex/skills`) ⇄ r3(`.agents/skills`)** 由来、1 が `.system` 由来（対象外） | §2 |
| F-5 | `.codex/skills` を消すと **r0 は消え、`.agents/skills` の skill は残ってロードされる**（fixture 実測） | §2.3 |
| F-6 | **導入先ユーザーは影響を受けない**。`install.sh --codex` は `plugin/plangate/skills` を **ユーザー自身の** `.codex/skills` に展開する経路であり、**上流 repo の commit 済み `.codex/skills` を配っていない** | §3 |
| F-7 | 壊れるのは **上流 repo 内部の 2 経路のみ**: `scripts/check-codex-skill-spec.sh`（**dir 不在で rc=1 クラッシュ / `--warn-only` でも落ちる**・CI 配線あり）と `scripts/sync-plugin-installed.sh`（silent skip） | §4 |
| F-8 | drift は issue 起票時の **2 件 → 現在 4 件に増加**（`ai-dev-exec` / `ai-loop-cycle` / `local-exec-handoff` / `plan-review-gate`）。派生コピーは放っておくと腐る | §1.3 |
| F-9 | **推奨は案 (A′)**: repo 内の `.agents/skills → .codex/skills` 同期を廃止し、`.codex/skills` を untrack + gitignore。合わせて `check-codex-skill-spec.sh` の検査対象を **配布物 `plugin/plangate/skills`** に付け替える | §6 |
| F-10 | 副産物（スコープ外）: `plugin/plangate/skills` は 39 skill 中 **openai.yaml が 35 件しかない**（4 件欠落）。現行の spec 検査は `.codex/skills`(39/39) だけを見ているため、**配布物の欠落が検査に映らない** | §7 |

---

## 1. 実測: 件数・名前・git 追跡状況

### 1.1 コマンドと出力

```console
$ git rev-parse HEAD
03854570c4e4c70fb5699e5069da94f0429cd8d0
$ git rev-parse origin/main
03854570c4e4c70fb5699e5069da94f0429cd8d0        # local == origin/main

$ find .agents/skills -maxdepth 2 -name SKILL.md | wc -l
      39
$ find .codex/skills  -maxdepth 2 -name SKILL.md | wc -l
      39
$ git ls-files .codex/skills  | wc -l
     120
$ git ls-files .agents/skills | wc -l
      45
```

名前の和集合・差分:

```console
$ comm -23 a.txt c.txt      # .agents にのみ存在
（出力なし）
$ comm -13 a.txt c.txt      # .codex にのみ存在
（出力なし）
$ cat a.txt c.txt | sort -u | wc -l
      39
```

### 1.2 集計表

| 指標 | 値 | 備考 |
|---|---|---|
| `.agents/skills` の SKILL.md | **39** | 正本（`.codex/instructions.md:53`） |
| `.codex/skills` の SKILL.md | **39** | 派生。issue 時点の 38 → PR #1084 で解消済み |
| 名前の和集合 | **39** | |
| `.agents` のみ / `.codex` のみ | **0 / 0** | 完全一致 |
| `git ls-files .codex/skills` | **120** | SKILL.md 39 + `agents/openai.yaml` 39 + `assets/plangate-small.svg` 39 + references 等 3 |
| `git ls-files .agents/skills` | **45** | SKILL.md 39 + README.md + references/assets 5 |
| `.codex/skills` の `agents/openai.yaml` | **39** | 生成物（`install-plangate-skills-to-codex.sh` が生成） |

> `.codex/skills/.system/` は `.gitignore:32` で除外済み・`git ls-files .codex/skills/.system` → 0（issue の記載どおり）。

### 1.3 drift 再測定（#956 scope だが、案の判断材料になるため測定）

```console
$ sh scratchpad/drift.sh <worktree>
DIFF ai-dev-exec (4 行)
DIFF ai-loop-cycle (22 行)
DIFF local-exec-handoff (4 行)
DIFF plan-review-gate (37 行)
differing=4
```

issue 起票時（2026-08-13）は **2 件**。**2 日で 4 件に増えている**。派生コピーを commit で保持する運用は放置すると必ず腐る、という追加証拠。
（内容判定と drift 検出 CI は **#956 の scope**。本 issue では扱わない。）

---

## 2. 実測: なぜ両方が root になるのか

### 2.1 repo 設定は skill root を一切宣言していない

| 候補ファイル | skill root 宣言 | 実測 |
|---|---|---|
| `.codex/config.toml` | **なし** | 全 105 行中、`skills` を設定するキーは 0。内容は `approval_policy` / `sandbox_mode` / `project_doc_fallback_filenames` / `[features]` / `[agents.*]` / `[shell_environment_policy]` のみ |
| `plugin/plangate/.codex-plugin/plugin.json` | `"skills": "./skills/"` | **plugin 配布物の内部パス**。repo の `.codex/skills` とは無関係 |
| `install.sh` | `CODEX_DIR="${TARGET_DIR:-$(pwd)/.codex/skills}"`（:231） | **導入先での生成先**。root 登録ではない |
| `scripts/install-plangate-skills-to-codex.sh` | `CODEX_SKILLS_DIR="$ROOT_DIR/.codex/skills"`（:18） | **上流 repo 内での生成先**。root 登録ではない |
| `.codex/instructions.md` | 正本を `.agents/skills` と宣言（:53, :60-61） | 宣言のみ。ローダーへの強制力なし |

**どのファイルも `.codex/skills` を root として登録していない。** 登録しているのは Codex CLI 自身。

### 2.2 隔離 `CODEX_HOME` での実測（repo 本体）

```console
$ CODEX_HOME=<scratch>/codexhome codex debug prompt-input > pi-isolated.json
（rc=0）
```

出力中の `<skills_instructions>` ブロック:

```text
### Skill roots
- `r0` = `<worktree>/.codex/skills`
- `r1` = `/Users/user/.agents/skills`
- `r2` = `<scratch>/codexhome/skills/.system`
- `r3` = `<worktree>/.agents/skills`
```

集計:

```console
total entries: 115
per-root: {'r0': 39, 'r1': 32, 'r2': 5, 'r3': 39}
unique names: 75
duplicated names: 39
dup root-combos: {('r0', 'r3'): 38, ('r0', 'r2', 'r3'): 1}
```

| 指標 | issue 時点（2026-08-13） | 本調査（2026-08-15 / `0385457`） |
|---|---|---|
| 合計エントリ | 114 | **115** |
| ユニーク名 | 75 | **75** |
| 重複エントリ | 39 | **40** |
| うち r0⇄r3 由来 | 38 | **39** |
| うち `.system` 由来（対象外） | 1 | **1**（`skill-creator`） |

> `CODEX_HOME` は scratchpad に隔離してあるため、**r0 は `CODEX_HOME/skills` ではない**。
> つまり `<repo>/.codex/skills` は **CODEX_HOME 経由ではなく cwd 起点の project-scoped root として**登録されている。
> （`scripts/codex-local.sh:32` は `CODEX_HOME=$repo_root/.codex` を export するが、**それが無くても r0 は出る**。）

### 2.3 由来対応表（合成 fixture による決定的検証）

repo を一切変更せず、scratchpad に最小 fixture を作って計測した（`scratchpad/probe.sh`）:

```text
probe/
├── .agents/skills/probe-a/SKILL.md
└── .codex/skills/{probe-a,probe-c}/SKILL.md
```

```console
[before] rc=0
    - probe-a: … (file: <probe>/.agents/skills/probe-a/SKILL.md)
    - probe-a: … (file: <probe>/.codex/skills/probe-a/SKILL.md)
    - probe-c: … (file: <probe>/.codex/skills/probe-c/SKILL.md)

# probe/.codex/skills を削除して再測定
[after-remove-codex-skills] rc=0
    - probe-a: … (file: <probe>/.agents/skills/probe-a/SKILL.md)
```

**root 登録の由来対応表**:

| root | 実体 | 登録主体 | repo 側の設定ファイル | 本 issue |
|---|---|---|---|---|
| `r0` | `<cwd>/.codex/skills` | **Codex CLI 既定の project-scoped 探索** | **なし**（`install-plangate-skills-to-codex.sh` が中身を生成しているだけ） | **対象** |
| `r1` | `~/.agents/skills` | Codex CLI 既定の user-scoped 探索 | なし（ユーザー個人領域） | 対象外（Non-goals） |
| `r2` | `$CODEX_HOME/skills/.system` | Codex runtime がマウント | `.gitignore:32` で commit 除外 | 対象外 |
| `r3` | `<cwd>/.agents/skills` | **Codex CLI 既定の project-scoped 探索** | なし（正本宣言は `.codex/instructions.md:53`） | 残す側 |

**結論**: 「両方 root になる」のは repo の設定ミスではなく **Codex CLI の既定挙動**。したがって是正手段は「**片方のディレクトリを cwd から無くす**」しかない（root 探索仕様の変更提案は Non-goals）。

### 2.4 案 (c)「config で root を除外」の可否

候補キーを `-c` で与えて効果を測った（`scratchpad/probe2.sh`。fixture の `probe-c` が `.codex/skills` 側）:

```console
skills.enabled=false                          rc=0 probe-a=1 probe-c=1
skills.roots=[]                               rc=0 probe-a=1 probe-c=1
skills.exclude_roots=[".codex/skills"]        rc=0 probe-a=1 probe-c=1
experimental_skills.enabled=false             rc=0 probe-a=1 probe-c=1
features.skills=false                         rc=0 probe-a=1 probe-c=1
totally_bogus_key_xyz=1                       rc=0 probe-a=1 probe-c=1
```

**判定**: 候補キーはいずれも無効。ただし **最終行のとおり Codex は未知キーを無言で受理する**（rc=0）ので、これは「**指定した候補キーは存在しない**」の証拠であって「**そのような knob が一切存在しない**」の証明ではない。
`codex --help` / `codex debug --help` にも skill root を制御するオプションは無い。
→ **案 (c) は「公開された制御手段が見つからない」ため採らない**。採るなら Codex 公式ドキュメント（config-schema）の一次確認が別途要る。

---

## 3. 導入先ユーザーへの影響（最重要の確認）

「`.codex/skills` を消すと導入先で skill が読めなくなる」経路が無いかを、install 導線を実際に読んで確認した。

### 3.1 2 つの install スクリプトは別物

| スクリプト | source | target | 用途 |
|---|---|---|---|
| `scripts/install-plangate-skills-to-codex.sh` | `$ROOT_DIR/.agents/skills`（:25） | `$ROOT_DIR/.codex/skills` **固定**（:18。`--target` 無し） | **上流 repo 内部**の派生生成 |
| `plugin/plangate/scripts/install-plangate-skills.sh` | `$PLUGIN_DIR/skills`（:10） | `--target`（既定 `<git root>/.codex/skills`、:44） | **導入先ユーザー**への展開 |

`install.sh --codex`（:229-241）が呼ぶのは **後者**:

```sh
CODEX_DIR="${TARGET_DIR:-$(pwd)/.codex/skills}"
sh "$PLUGIN_DIR/scripts/install-plangate-skills.sh" --target "$CODEX_DIR" $_codex_force
```

### 3.2 帰結

- 導入先の `.codex/skills` は **`plugin/plangate/skills` から生成**される。**上流 repo が commit している `.codex/skills` は配布経路に一切登場しない**。
- `codex plugin add plangate@plangate`（marketplace 経路）も `plugin/plangate/.codex-plugin/plugin.json` の `"skills": "./skills/"` を見る。ここでも上流 `.codex/skills` は不要。
- **したがって、上流 repo から `.codex/skills` を untrack しても、導入先ユーザーの skill 可用性は変わらない。**
- ただし **導入先では `.codex/skills`(生成) と `.agents/skills`(もし置いていれば) の二重 root が同じ構造で起こりうる**。PlanGate は導入先に `.agents/skills` を作らない（`install.sh --claude` は `.claude/` へ、`--codex` は `.codex/skills` へ）ので、**導入先で二重になるのは「導入先が自前で `.agents/skills` を持っている場合」だけ**。これは案の選択とは独立の注意点として `docs/staged-adoption-guide.md` 等に注記する価値がある。

---

## 4. `.codex/skills` を消した / 外した場合に壊れるもの（grep 全数）

`grep -rc "\.codex/skills" --exclude-dir=.git -r .` の全ヒットを、`.codex/skills` 配下の自己ヒットを除いて分類した（全 48 ファイル）。

### 4.1 実行系（壊れる / 要改修）

| ファイル | 参照 | 影響 | 対応 |
|---|---|---|---|
| **`scripts/check-codex-skill-spec.sh:11`** | `TARGET_DIR="$REPO_ROOT/.codex/skills"` | **クラッシュ**。dir 不在で `os.listdir` が `FileNotFoundError` → **`--warn-only` でも rc=1**（実測: `sh scripts/check-codex-skill-spec.sh --warn-only --target /nonexistent-dir-xyz` → `FileNotFoundError` / `rc=1`） | **必須改修**。§6 の案 (A′) では検査対象を `plugin/plangate/skills` に付け替える |
| **`.github/workflows/sync-plugin-plangate.yml:73`** | `run: sh scripts/check-codex-skill-spec.sh --warn-only` | 上記が rc=1 で **main push 時の job が落ちる** | **workflow は HO 対象なので触らない**。スクリプト側の既定 TARGET_DIR を変えれば workflow 無変更で解決する |
| `scripts/sync-plugin-installed.sh:103` | `REPO_CODEX_SKILLS="$REPO_ROOT/.codex/skills"` | クラッシュしない。`[ -d ... ]` ガードがあり「Codex skills ディレクトリ未検出（スキップ）」で **silent skip** | **要改修**（silent green を残さない）。source を `plugin/plangate/skills` へ変更 or 明示 WARN |
| `scripts/install-plangate-skills-to-codex.sh` | 生成スクリプト本体 | 案 (A′) では **役割そのものを廃止**（`mkdir -p` するので単体では壊れない） | 廃止 or 明示的に「上流 repo では使わない」と明記 |

### 4.2 テスト（壊れない — 実測で確認）

| ファイル | 参照 | 判定 |
|---|---|---|
| `tests/extras/ta-30-install-skills.sh:37` | **コメントのみ**（「repo の `.codex/skills` を上書きする事故を防ぐため temp target を使う」） | **影響なし**。テストは temp target で実行 |
| `tests/extras/ta-64-skill-frontmatter.sh:202,214` | `_t64_base` = **tmp 配下の合成 fixture** に `.codex/skills` を作って走査漏れを検査 | **影響なし**。repo の実ディレクトリを見ていない |
| `scripts/check-skill-frontmatter.py:141,346,353` | 既定 root に `.codex/skills` を含む / self-test Case 13 は合成 base | **影響なし**（存在しない root はスキップされる。ta-64 TC-11「0 件走査は exit 2」は `.agents/.claude/plugin` の 100+ 件が残るため発火しない） |
| `tests/fixtures/codex-log/sample.jsonl` | ログ fixture の文字列 | 影響なし |

### 4.3 ドキュメント（記述の追随が要る）

| ファイル | 参照 | 対応 |
|---|---|---|
| `.codex/instructions.md:53,58,60-61` | 正本宣言 | **AC-5 の対象**。「`.codex/skills` は上流 repo では持たない / 導入先の生成先」を明記 |
| `.codex/README.md:110,112` | `.system` の扱い | 追随（`.system` 記述は維持） |
| `docs/ai/settings-wiring-contract.md:278` | 「`.codex/` は変更しない・同期で追従」 | **矛盾するので更新必須**（同期を廃止するため） |
| `README.md:154` / `README_en.md:151` / `docs/pages/guides/getting-started.md:41` / `docs/plangate-plugin-migration.md:42,151,279` / `plugin/plangate/README.md:110-127,162,317` | **導入先ユーザー向けの `install.sh --codex` 説明** | **変更不要**（§3 のとおり導入経路は不変） |
| `.gitignore:32` | `.codex/skills/.system/` | 案 (A′) で `.codex/skills/` に拡張（`.system` 行は包含されるので整理） |
| `docs/ai/subagent-delegation/README.md:84,178` / `AGENT_LEARNINGS.md:118` / `CHANGELOG.md` / `docs/working/**` | 履歴・説明の言及 | 変更不要（過去記録） |

> `.codex/**` は **Hardening Override 対象パスに含まれない**（HO は `.claude/rules` / `.claude/settings*` / `.claude/commands` / `.claude/agents` / `scripts/hooks` / `bin/plangate` / `schemas` / `.github/workflows` / `AGENTS.md` / `CLAUDE.md`）。ただし **`.github/workflows/**` は HO なので触らない**（§4.1 のとおり触らずに解ける）。

---

## 5. #1081 との切り分け

| 観点 | **#1086（本 issue）** | **#1081** |
|---|---|---|
| プラットフォーム | **Codex CLI** | **Claude Code plugin** |
| 重複の主体 | **同一 skill が 2 つの root から 2 回** | **`commands/*.md` が Skill として登録**され skill 名と衝突 |
| 対象ファイル | `.codex/skills` / `.agents/skills` / `install*.sh` / `check-codex-skill-spec.sh` | `plugin/plangate/commands/*.md` / `plugin/plangate/.claude-plugin/plugin.json` |
| 重複件数 | 39（r0⇄r3） | 3（同名衝突）+ 3（junk: `ai-dev-workflow` / `ai-loop-workflow` / `README`） |
| **重なる部分** | ① 症状が同じ（**skill 一覧の予算を食う / 同名衝突の勝者が不定**）② **AC の書き方が同じ**（「root を外した」ではなく「**モデル可視一覧から消えた**」を完了条件にする）③ 検証手段が同じ系統（`codex debug prompt-input` / `claude plugin details`） | 同左 |
| **重ならない部分** | 変更ファイル・原因機構・ローダーが完全に別。**片方を直しても他方は残る** | 同左 |

**結論**: 依存関係なし・**並行で進められる**。ファイル衝突も無い。共有すべきは「モデル可視一覧を判定基準にする」という **AC の書き方だけ**。

---

## 6. 是正案の比較

### 案の定義

- **(A)** `.codex/skills` を repo から untrack + gitignore し、**上流 repo でも `install.sh --codex` 相当で必要時に生成**する
- **(A′)**（推奨）**(A) + 上流 repo では `.codex/skills` を生成しない**（`scripts/install-plangate-skills-to-codex.sh` を上流用途から退役）。上流の Codex セッションは `.agents/skills`（正本）のみを読む
- **(B)** `.codex/skills` を正本に格上げし `.agents/skills` を廃止
- **(C)** Codex の config で `.codex/skills` を root から除外
- **(D)** 現状維持（重複を許容し、drift 検出のみ #956 で強化）

### 比較表

| 観点 | **(A) untrack + 各自生成** | **(A′) untrack + 上流では生成しない（推奨）** | **(B) `.codex` を正本化** | **(C) config で除外** | **(D) 現状維持** |
|---|---|---|---|---|---|
| **二重登録の解消** | ❌ **不完全**。生成した瞬間に repo 内に `.codex/skills` が復活し、**そのマシンでは重複が戻る** | ✅ **完全**。上流 cwd に `.codex/skills` が存在しない | ✅ 完全（`.agents/skills` を消せば） | ❓ **手段が確認できない**（§2.4） | ❌ 解消しない |
| **影響範囲（コード）** | `.gitignore` / `check-codex-skill-spec.sh` / `sync-plugin-installed.sh` | 左に加え `install-plangate-skills-to-codex.sh` の退役 | **`sync-plugin-plangate.sh:24`（`SKILLS_DIR=.agents/skills`）**・`check-skill-frontmatter.py`・`ta-64`・`.codex/instructions.md`・#956 の前提 **すべて**を反転 | 不明（設定 1 行 + 検証） | なし |
| **影響範囲（ファイル数）** | 120 ファイルを untrack | 同左 | **45 ファイルを移動 + 全参照の反転** | 0 | 0 |
| **後方互換** | ✅ 導入先の導線は不変（§3） | ✅ 同左 | ⚠️ 上流の正本パスが変わる。`.agents/skills` を参照する外部（Codex Cloud 設定・他 repo の踏襲）が壊れうる | ✅ | ✅ |
| **導入先ユーザーへの影響** | **なし**（`install.sh --codex` は plugin から生成） | **なし** | **なし**（配布物は `plugin/plangate/skills`） | なし | なし |
| **実装コスト** | 小（半日） | **小〜中**（半日〜1日。退役の後始末を含む） | **大**（#956 との整合を先に取る必要。issue も明記） | 小だが**先に一次仕様確認が要る** | 0 |
| **#956 との関係** | drift 対象が消えるため #956 の一部が自然消滅 | **同左（drift 4 件が構造的に消える）** | ⚠️ #956 の Non-goals「生成関係は維持」と衝突 | 影響なし（drift は残る） | #956 が必要なまま |
| **残るリスク** | ① 生成した dev マシンで重複再発 ② `.codex/skills` を local に持つ人が「更新したつもり」になる | ① 上流 repo で Codex 用 `openai.yaml` の実物検証を失う → **検査対象を `plugin/plangate/skills` に付け替えて回収**（§7 と同時に解決） ② 誰かが手で `install-plangate-skills-to-codex.sh` を叩くと復活 → **AC-4 の再発検出で捕まえる** | ① 反転作業自体の事故 ② 正本の二重定義期間 | ① 未知キーは無言で受理されるため「効いたつもり」になる（**#1078 と同型の false green**） | ① 一覧予算の圧迫継続 ② drift 増加（2→4 で実証済み） |
| **AC-1/2 を満たせるか** | ⚠️ 生成前の clean clone では満たすが、**生成後は満たさない** | ✅ 満たす | ✅ 満たす | ❓ | ❌ |

### 推奨: **(A′)**

理由（優先順位: 要件適合性 → 安全性 → 保守性 → 実装コスト → 拡張性）:

1. **要件適合性**: AC-1/AC-2（モデル可視一覧から重複が消えること）を **恒久的に**満たすのは (A′) と (B) だけ。(A) は「生成した瞬間に戻る」ため **AC を満たさない状態が正常運用に含まれてしまう**。
2. **安全性**: 導入先ユーザーへの影響ゼロが **install 導線の実読で確認済み**（§3）。(B) は正本反転で `sync-plugin-plangate.sh` を含む多数の経路を同時に反転させる必要があり、事故面が大きい。
3. **保守性**: 「正本 1 つ・派生は配布時にだけ生成」という形になり、`.codex/instructions.md` の宣言と実態が初めて一致する（AC-5）。drift（現在 4 件）も構造的に消える。
4. **実装コスト**: (B) の 1/3 以下。
5. **是正が新しい穴を作らないかの照合**:
   - **穴 1**: `check-codex-skill-spec.sh` が対象を失い、**openai.yaml の仕様検査が消える**（＝「消したら検査も消えた」パターン）。→ **検査対象を配布物 `plugin/plangate/skills` に付け替える**。これは §7 の既存ギャップ（35/39）も同時に埋めるので、**検査は消えるどころか強くなる**。
   - **穴 2**: `sync-plugin-installed.sh` が `[ -d ]` ガードで **silent skip** する（＝「設定の存在を効果の証拠にする」パターン）。→ source を `plugin/plangate/skills` に変え、**未検出時は WARN を出す**。
   - **穴 3**: 誰かが `install-plangate-skills-to-codex.sh` を叩いて復活させる。→ **AC-4 の再発検出**（`tests/extras/ta-NN-*.sh` で「tracked な `.codex/skills/*/SKILL.md` が 0 件」を検査）＋ 意図的復元での検出実証（空振り検査にしない）。

### (A′) の実装スケッチ（exec 用・本 PBI では未実施）

| # | 変更 | Owner | 備考 |
|---|---|---|---|
| 1 | `git rm -r --cached .codex/skills`（120 ファイル） | AI（**要 C-3 承認**） | **本調査では未実施** |
| 2 | `.gitignore` に `.codex/skills/` を追加（`:32` の `.system` 行を包含して整理） | AI | |
| 3 | `scripts/check-codex-skill-spec.sh` の既定 `TARGET_DIR` を `plugin/plangate/skills` へ変更 + **dir 不在を明示 FAIL/WARN で扱う**（現状は traceback） | AI | **workflow は無変更で済む**（HO 回避） |
| 4 | `scripts/sync-plugin-installed.sh` の Codex source を `plugin/plangate/skills` へ変更 + 未検出時 WARN | AI | |
| 5 | `scripts/install-plangate-skills-to-codex.sh` を退役（削除 or 「導入先専用・上流では実行しない」を冒頭に明記） | AI | 削除する場合は `CHANGELOG` / `docs/plangate-plugin-migration.md` を確認 |
| 6 | `.codex/instructions.md` / `.codex/README.md` / `docs/ai/settings-wiring-contract.md:278` の記述を実態へ | AI | **AC-5**。#1078 と `.codex/` で競合しうるので着手前に順序調整 |
| 7 | `tests/extras/ta-NN-codex-single-skill-root.sh` を新設（AC-4） | AI | 検査案: (i) `git ls-files .codex/skills` が 0 (ii) 意図的に fixture を tracked 状態で作ると **検出される**ことを実証 |
| 8 | AC-1/2/3 を `codex debug prompt-input` の前後出力で実証 | AI | 本調査の §2.2 が **是正前 baseline** として使える |

> **注意（#1084/#1085 由来の教訓と整合）**: 手順 3 で `plugin/plangate/skills` を対象にすると **4 件が openai.yaml 欠落で即 FAIL する**（§7）。exec では「対象を付け替える PR」と「4 件を埋める PR」の順序を決めること（付け替えだけ先に入れると CI が赤になる）。

---

## 7. スコープ外で見つけた問題

| # | 内容 | 実測 | 提案 |
|---|---|---|---|
| S-1 | **配布物 `plugin/plangate/skills` の openai.yaml が 4 件欠落**: `ai-loop-cycle` / `breakdown-gate` / `ref-integrity-scan` / `subagent-delegation-brief`（39 skill 中 35 件のみ） | `find plugin -name openai.yaml \| wc -l` → 35 / `find plugin/plangate/skills -maxdepth 2 -name SKILL.md \| wc -l` → 39 | **別 issue 起票を推奨**。現行の `check-codex-skill-spec.sh` は `.codex/skills`(39/39) だけを見ているため **配布物の欠落が検査に映らない false green**（#1085 と同型） |
| S-2 | `check-codex-skill-spec.sh` は **target dir 不在で python traceback + rc=1**。`--warn-only` を無視する | `sh scripts/check-codex-skill-spec.sh --warn-only --target /nonexistent-dir-xyz` → `FileNotFoundError` / rc=1 | 案 (A′) 手順 3 で同時に修正 |
| S-3 | `.agents/skills` と `.codex/skills` の drift が **2 → 4 件に増加**（`ai-dev-exec` / `local-exec-handoff` が新規） | §1.3 | **#956 に追記**（件数を契約値にしない形で） |
| S-4 | 導入先が自前で `.agents/skills` を持っている場合、`install.sh --codex` 後に **導入先でも同じ二重 root が起こる** | §3.2（機構は §2.3 で実証済み） | `docs/staged-adoption-guide.md` 等に注記（本 issue の scope 外だが同一機構） |

---

## 8. Human 判断が要る点

| # | 論点 | 選択肢 | 備考 |
|---|---|---|---|
| H-1 | **案の確定**（(A′) を採るか） | (A) / **(A′)** / (B) / (C) / (D) | 本調査の推奨は (A′)。(B) は #956 との整合を先に取る必要 |
| H-2 | **`.codex/skills` 120 ファイルの untrack 実行** | 承認 / 保留 | **不可逆に近い破壊的操作**。本調査では未実施。exec 時に名指し承認が要る |
| H-3 | `scripts/install-plangate-skills-to-codex.sh` を **削除するか / 注記のみで残すか** | 削除 / 残す | 残すと「叩けば復活する」経路が残る（AC-4 の検査で捕捉はできる） |
| H-4 | **#1078 との `.codex/` 作業順序** | #1078 先行 / 本 issue 先行 / 並行 | issue 本文も「順序調整が要る」と明記。`.codex/instructions.md` を両方が触る |
| H-5 | **S-1（配布物 openai.yaml 4 件欠落）を本 issue に取り込むか別 issue にするか** | 取り込む / 別 issue | 取り込むと scope が広がるが、手順 3 の CI 赤を避けるには順序制御が要る |
| H-6 | Mode 判定 | standard / high-risk | 変更ファイル数 120+（untrack）・配布経路に触れる・CI 配線 1 本に影響 → **high-risk 相当を推奨**。HO 対象パスは含まないが `.github/workflows` は触らない設計にしてある |

---

## 9. 再現手順（本調査の evidence 生成）

```sh
# 1. 件数・git 追跡
find .agents/skills -maxdepth 2 -name SKILL.md | wc -l
find .codex/skills  -maxdepth 2 -name SKILL.md | wc -l
git ls-files .codex/skills  | wc -l
git ls-files .agents/skills | wc -l

# 2. モデル可視一覧（隔離 CODEX_HOME）
CODEX_HOME=<scratch>/codexhome codex debug prompt-input > pi.json   # rc=0
#    → JSON 内 <skills_instructions> の "### Skill roots" / "### Available skills" を集計

# 3. root 由来の決定的検証（repo 非破壊 / 合成 fixture）
sh <scratch>/probe.sh     # .codex/skills 有/無 で前後比較

# 4. config knob の有無
sh <scratch>/probe2.sh

# 5. 参照全数
grep -rc "\.codex/skills" --exclude-dir=.git -r . | grep -v ':0$'

# 6. spec check の dir 不在時挙動
sh scripts/check-codex-skill-spec.sh --warn-only --target /nonexistent-dir-xyz ; echo rc=$?
```

### 未実施（正直な記録）

- **`sh tests/run-tests.sh` の baseline（AC-6）は本調査では取得していない。** 起動はしたが、
  同一マシンで他セッションの full-suite が並走しており（`ta-61` が入れ子で full-suite を再実行する構造）、
  完走前に自分の実行を中断した。**「rc=0 だった」とは書けない** ので、baseline は
  **exec 開始時に単独実行で再測定すること**（issue AC-6 も「件数は exec 開始時に再測定」と規定している）。
- 本調査で新規に実行したのは **読み取り専用の測定のみ**。`.codex/skills` を含む repo ファイルは一切変更していない
  （追加したのは本ファイルのみ）。fixture はすべて scratchpad 配下に作成した。
