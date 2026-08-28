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
| F-8 | drift は issue 起票時の **2 件 → 現在 4 件に増加**。ただし**向きは一様でない**: **3 件は派生が stale / 1 件（`plan-review-gate`）は派生のほうが新しく 36 行多い** | §1.3 |
| F-9 | **推奨は案 (A′)**（変更なし）: repo 内の `.agents/skills → .codex/skills` 同期を廃止し、`.codex/skills` を untrack + gitignore。**ただし 2 つの前提条件が付く**（`plan-review-gate` の reconcile / `check-codex-skill-spec.sh` の欠落検出新設） | §6 |
| F-10 | 現行 `check-codex-skill-spec.sh` は **`openai.yaml` 不在の skill を silently skip する**（`if not os.path.exists(yaml_path): continue`）。したがって**検査対象を配布物へ付け替えても欠落は検出されず、検査母数は 39 → 35 に減って弱くなる**。欠落検出は**新設**が要る | §6 / §7（R-001） |
| F-11 | `check-codex-skill-spec.sh` は**既定 target で既に 8 violations / rc=1**。CI が緑なのは workflow が `--warn-only` を付けているため（`.github/workflows/sync-plugin-plangate.yml:73`） | §4.1 / §6（R-005） |

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

issue 起票時（2026-08-13）は **2 件**。**2 日で 4 件に増えている**。
（内容判定と drift 検出 CI は **#956 の scope**。本 issue では扱わない。）

#### 向きの判定（R-002 反映 / 是正案の前提条件）

**「派生は腐るだけ」ではない。** 4 件の向きを最終更新コミットと行数で実測した:

```console
$ sh <scratch>/dir.sh <worktree>
ai-dev-exec          agents[161 lines] 7621c3a 2026-08-13 | codex[161 lines] 1bb5bad 2026-08-02
ai-loop-cycle        agents[296 lines] 721edcb 2026-07-20 | codex[293 lines] 0050ece 2026-07-11
local-exec-handoff   agents[95 lines]  7621c3a 2026-08-13 | codex[95 lines]  1bb5bad 2026-08-02
plan-review-gate     agents[60 lines]  b86a649 2026-05-24 | codex[96 lines]  d144ac4 2026-06-22
```

| skill | `.agents`（正本） | `.codex`（派生） | 新しい側 | (A′) untrack の影響 |
|---|---|---|---|---|
| `ai-dev-exec` | 2026-08-13 / 161 行 | 2026-08-02 / 161 行 | **`.agents`** | なし（派生が stale） |
| `ai-loop-cycle` | 2026-07-20 / 296 行 | 2026-07-11 / 293 行 | **`.agents`** | なし（派生が stale） |
| `local-exec-handoff` | 2026-08-13 / 95 行 | 2026-08-02 / 95 行 | **`.agents`** | なし（派生が stale） |
| **`plan-review-gate`** | 2026-05-24 / **60 行** | 2026-06-22 / **96 行** | **`.codex`** | **36 行が全 skill root から消える** |

`plan-review-gate` の差分は `.codex` 側にのみ存在する 1 節
**「C-1 追加品質ゲート: Plan 実行可能性」**（Task Sizing Rules / No Placeholders Rule / mode 別判定）:

```console
$ diff .agents/skills/plan-review-gate/SKILL.md .codex/skills/plan-review-gate/SKILL.md | head -3
25a26,61
> ### C-1 追加品質ゲート: Plan 実行可能性

$ wc -l plugin/plangate/skills/plan-review-gate/SKILL.md .agents/... .codex/...
      60 plugin/plangate/skills/plan-review-gate/SKILL.md
      60 .agents/skills/plan-review-gate/SKILL.md
      96 .codex/skills/plan-review-gate/SKILL.md

$ grep -rl "No Placeholders Rule" --exclude-dir=.git .
.codex/skills/plan-review-gate/SKILL.md        # ← skill としてはここだけ
docs/working/templates/review-self.md          # C1-SUP-PLAN-01 / -02（:94, :102）
docs/working/TASK-{0871,0873,0874,0877,0914,0917,0970,0981,1012,1036,1045}/review-self.md
```

**重大度の評価**（critical ではなく major 相当と判断した根拠）:

- 同等内容は `docs/working/templates/review-self.md` の **C1-SUP-PLAN-01 / C1-SUP-PLAN-02**（:94 / :102）に存在する → repo 全体からの知識喪失ではない
- 配布物 `plugin/plangate/skills/plan-review-gate/SKILL.md` は **60 行版**（= `.agents` と同じ）→ 導入先ユーザーはもともとこの節を持たない。**回帰ではない**

それでも、**「腐った派生を捨てるだけ」という前提で untrack を実行すると、正本が持っていない 36 行を無自覚に破棄する。**
→ §6 実装スケッチに **手順 0（reconcile）を前置**した。

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

**重要（R-004 反映）**: 後者は単純コピーではない。**`agents/` と `assets/` を resource 同期の対象から除外し、
`openai.yaml` を target 側で毎回生成し直す**:

```console
$ grep -n "_is_managed_subdir\|agents|assets\|cat > " plugin/plangate/scripts/install-plangate-skills.sh
60:# 特別扱いする名前。"agents" は openai.yaml 生成が dst 側で毎回再構築される
62:_is_managed_subdir() {
64:    agents|assets) return 0 ;;
154:    _is_managed_subdir "$_sub_name" && continue
235:  # Generate openai.yaml
237:  cat > "$dst/agents/openai.yaml" << YAML
```

→ **`install.sh --codex` 経路では、配布物側の `openai.yaml` は一切消費されない。**
したがって §7 S-1 の「配布物 openai.yaml 4 件欠落」が実害を持ちうるのは、
`.codex-plugin/plugin.json` の `"skills": "./skills/"` をそのまま読む **marketplace 経路に限られる**
（marketplace 経路が `agents/openai.yaml` を実際に消費するかの一次確認は本調査では未実施 — §7 S-1 に未確認として明記）。

### 3.2 帰結

- 導入先の `.codex/skills` は **`plugin/plangate/skills` から生成**される。**上流 repo が commit している `.codex/skills` は配布経路に一切登場しない**。
- `codex plugin add plangate@plangate`（marketplace 経路）も `plugin/plangate/.codex-plugin/plugin.json` の `"skills": "./skills/"` を見る。ここでも上流 `.codex/skills` は不要。
- **したがって、上流 repo から `.codex/skills` を untrack しても、導入先ユーザーの skill 可用性は変わらない。**
- ただし **導入先では `.codex/skills`(生成) と `.agents/skills`(もし置いていれば) の二重 root が同じ構造で起こりうる**。PlanGate は導入先に `.agents/skills` を作らない（`install.sh --claude` は `.claude/` へ、`--codex` は `.codex/skills` へ）ので、**導入先で二重になるのは「導入先が自前で `.agents/skills` を持っている場合」だけ**。これは案の選択とは独立の注意点として `docs/staged-adoption-guide.md` 等に注記する価値がある。

---

## 4. `.codex/skills` を消した / 外した場合に壊れるもの（grep 全数）

`grep -rl "\.codex/skills" --exclude-dir=.git .` の全ヒットを、`.codex/skills` 配下の自己ヒット 2 件を除いて分類した（**全 48 ファイル**）。

```console
$ grep -rl "\.codex/skills" --exclude-dir=.git . | grep -v "^\.codex/skills/" \
    | grep -v "^docs/working/TASK-1086/" | wc -l
      48
```

> **網羅性の注記（R-003 反映）**: §4.1〜4.4 の 4 表で **48 件すべてを収容する**。
> 初版は §4.1〜4.3 に 39 件しか載せておらず「全数を分類した」という記述と食い違っていた。
> §4.4 を新設し、残り 9 件（散文・履歴のみ）を明示的に収容した。

### 4.1 実行系（壊れる / 要改修）

| ファイル | 参照 | 影響 | 対応 |
|---|---|---|---|
| **`scripts/check-codex-skill-spec.sh:11`** | `TARGET_DIR="$REPO_ROOT/.codex/skills"` | **クラッシュ**。dir 不在で `os.listdir` が `FileNotFoundError`（実測: `--warn-only --target /nonexistent-dir-xyz` → `FileNotFoundError` / rc=1）。**`--warn-only` は violation にしか効かず、例外は素通しする** | **必須改修**。§6 手順 3（対象付け替え + **欠落検出の新設** + dir 不在の明示扱い） |
| **`.github/workflows/sync-plugin-plangate.yml:73`** | `run: sh scripts/check-codex-skill-spec.sh --warn-only` | dir 不在の**例外**は `--warn-only` で吸収されないため **main push 時の job が落ちる**（violation では落ちない。**現に既定 target は 8 violations あるが CI は緑** → F-11） | **workflow は HO 対象なので触らない**。スクリプト側の既定 TARGET_DIR と例外処理を直せば workflow 無変更で解決する |
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
| `docs/ai/subagent-delegation/README.md:84,178` / `AGENT_LEARNINGS.md:118` / `CHANGELOG.md` / `docs/working/**`（18 ファイル） | 履歴・説明の言及 | 変更不要（過去記録） |
| `install.sh:231` | 導入先での生成先（`CODEX_DIR`） | **変更不要**（§2.1 / §3.1 で分析済。導入導線そのもの） |
| `plugin/plangate/scripts/install-plangate-skills.sh` | 配布経路本体（既定 target） | **変更不要**（§3.1。導入先ユーザー向けで上流 repo とは独立） |

### 4.4 影響なし（散文・履歴のみ / R-003 で収容した 9 件）

初版の §4.1〜4.3 に現れていなかった残り 9 件。**すべて独立に確認し、破壊されるものは無い。**

| ファイル | 参照内容 | 判定 |
|---|---|---|
| `.agents/skills/acceptance-review/SKILL.md:188` | 「上流 repo の `.agents/skills` と導入先の `.codex/skills`」という**散文**（参照解決の説明） | 壊れない（文言の追随は任意） |
| `.agents/skills/diff-audit/SKILL.md:330` | 同上 | 壊れない |
| `.claude/skills/acceptance-review/SKILL.md` | 同上（同期先） | 壊れない |
| `.claude/skills/diff-audit/SKILL.md` | 同上 | 壊れない |
| `plugin/plangate/skills/acceptance-review/SKILL.md` | 同上（配布物） | 壊れない |
| `plugin/plangate/skills/diff-audit/SKILL.md` | 同上 | 壊れない |
| `scripts/apply-diff-audit-rename.sh:13` | 一回限りの rename script の**コメント** | 壊れない |
| `scripts/apply-subagent-team-design-rename.sh:13` | 同上 | 壊れない |
| `docs/changelog.md:113,504,506` | 履歴 | 壊れない |

**結論は維持**: 9 件を精査しても「壊れるのは上流 repo 内部の 2 経路のみ」（F-7）は変わらない。
ただし §4.1〜4.3 だけを「漏れなき一覧」として使うと取りこぼすため、本節で全数を閉じた。

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
| **残るリスク** | ① 生成した dev マシンで重複再発 ② `.codex/skills` を local に持つ人が「更新したつもり」になる | ① 上流 repo で Codex 用 `openai.yaml` の実物検証を失う → **付け替えだけでは回収できない（R-001）。欠落検出の新設が必須** ② `plan-review-gate` の 36 行が消える → **手順 0 の reconcile が必須（R-002）** ③ 手で `install-plangate-skills-to-codex.sh` を叩くと復活 → AC-4 の再発検出で捕捉 | ① 反転作業自体の事故 ② 正本の二重定義期間 | ① 未知キーは無言で受理されるため「効いたつもり」になる（**#1078 と同型の false green**） | ① 一覧予算の圧迫継続 ② drift 増加（2→4 で実証済み） |
| **AC-1/2 を満たせるか** | ⚠️ 生成前の clean clone では満たすが、**生成後は満たさない** | ✅ 満たす | ✅ 満たす | ❓ | ❌ |

### 推奨: **(A′)（維持。ただし前提条件 2 件が追加）**

R-001 / R-002 を反映しても **推奨は (A′) のまま**である。理由は、両指摘が崩したのは
**「(A′) の副作用をどう回収するか」の設計**であって、**(A′) を選ぶ根拠（F-6 導入先影響ゼロ / AC-1 を恒久的に満たすのは (A′) と (B) だけ）ではない**ため。
崩れた 2 本の柱は、**回収手段を差し替えることで再建できる**（下記 5.）。

理由（優先順位: 要件適合性 → 安全性 → 保守性 → 実装コスト → 拡張性）:

1. **要件適合性**: AC-1/AC-2（モデル可視一覧から重複が消えること）を **恒久的に**満たすのは (A′) と (B) だけ。(A) は「生成した瞬間に戻る」ため **AC を満たさない状態が正常運用に含まれてしまう**。
2. **安全性**: 導入先ユーザーへの影響ゼロが **install 導線の実読で確認済み**（§3。レビューアも独立に再現）。(B) は正本反転で `sync-plugin-plangate.sh` を含む多数の経路を同時に反転させる必要があり、事故面が大きい。
3. **保守性**: 「正本 1 つ・派生は配布時にだけ生成」という形になり、`.codex/instructions.md` の宣言と実態が初めて一致する（AC-5）。
4. **実装コスト**: (B) の 1/3 以下。
5. **是正が新しい穴を作らないかの照合（R-001 / R-002 で全面差し替え）**:

| 穴 | 初版の回収案 | **実測でどう崩れたか** | **差し替え後の回収案** |
|---|---|---|---|
| **穴 1**: `check-codex-skill-spec.sh` が対象を失い openai.yaml 検査が消える | 配布物 `plugin/plangate/skills` へ**対象を付け替える**。「§7 の 35/39 ギャップも同時に埋まるので検査は強くなる」 | **不成立**。`:35` の `if not os.path.exists(yaml_path): continue` により **欠落は violation にならず silently skip**。付け替えると検査母数が **39 → 35 に減り、検査はむしろ弱くなる**（実測: Checked 35 / violation は `diff-audit` の 1 件のみで欠落 4 件は未報告） | **対象の付け替えだけでは不可**。`skill 数 == openai.yaml 数` を assert する **presence 検査を新設**する。「強くなる」の根拠を「対象を替える」から「**欠落検出を新設する**」へ差し替え |
| **穴 2**: `sync-plugin-installed.sh` の `[ -d ]` silent skip | source を `plugin/plangate/skills` に変え未検出時 WARN | 変更なし（成立） | 同左 |
| **穴 3**: 手動で `install-plangate-skills-to-codex.sh` を叩いて復活 | AC-4 の再発検出 + 意図的復元での検出実証 | 変更なし（成立） | 同左 |
| **穴 4（R-002 で新規）**: `plan-review-gate` の 36 行が全 skill root から消える | **初版に記載なし**（drift を一方向＝「派生は腐るだけ」と誤認していた） | `.codex` 側が新しく 36 行多い（§1.3）。untrack すると skill としては repo から消える | **手順 0（reconcile）を untrack の前に必須化**。`.agents/skills` へ取り込む、または「`review-self.md` テンプレの C1-SUP-PLAN-01/02 で足りる」と判断した根拠を残す |

### (A′) の実装スケッチ（exec 用・本 PBI では未実施）

| # | 変更 | Owner | 備考 |
|---|---|---|---|
| **0** | **`plan-review-gate` の 36 行を reconcile**（`.agents/skills` へ取り込む or 不要と判断した根拠を記録） | AI（**判断は Human: H-7**） | **R-002。手順 1 の前に必ず実施**。未実施のまま untrack すると 36 行が消える |
| **0′** | **`check-codex-skill-spec.sh` に openai.yaml presence 検査を新設**（#1109） | AI | **R-001。手順 3 の前提**。現状は欠落を silently skip するため、付け替えても検出できない |
| 1 | `git rm -r --cached .codex/skills`（120 ファイル） | AI（**要 C-3 + 名指し承認**） | **本調査では未実施**。前提 = 手順 0 完了 |
| 2 | `.gitignore` に `.codex/skills/` を追加（`:32` の `.system` 行を包含して整理） | AI | |
| 3 | `scripts/check-codex-skill-spec.sh` の既定 `TARGET_DIR` を `plugin/plangate/skills` へ変更 + **dir 不在を明示 FAIL/WARN で扱う**（現状は traceback で `--warn-only` を素通り） | AI | **workflow は無変更で済む**（HO 回避）。**手順 0′ の後に行う** |
| 4 | `scripts/sync-plugin-installed.sh` の Codex source を `plugin/plangate/skills` へ変更 + 未検出時 WARN | AI | |
| 5 | `scripts/install-plangate-skills-to-codex.sh` を退役（削除 or 「導入先専用・上流では実行しない」を冒頭に明記） | AI | 削除する場合は `CHANGELOG` / `docs/plangate-plugin-migration.md` を確認 |
| 6 | `.codex/instructions.md` / `.codex/README.md` / `docs/ai/settings-wiring-contract.md:278` の記述を実態へ | AI | **AC-5**。#1078 と `.codex/` で競合しうるので着手前に順序調整 |
| 7 | `tests/extras/ta-NN-codex-single-skill-root.sh` を新設（AC-4） | AI | 検査案: (i) `git ls-files .codex/skills` が 0 (ii) 意図的に fixture を tracked 状態で作ると **検出される**ことを実証 |
| 8 | AC-1/2/3 を `codex debug prompt-input` の前後出力で実証 | AI | 本調査の §2.2 が **是正前 baseline** として使える |

#### 付け替え前後の baseline（R-005 反映・誤読防止）

| target | Checked | VIOLATIONS | rc | `--warn-only` 時の rc |
|---|---|---|---|---|
| `.codex/skills`（現行既定） | **39** | **8**（すべて `short_description too long`） | 1 | **0** |
| `plugin/plangate/skills`（付け替え後） | **35** | **1**（`diff-audit` 66 文字） | 1 | **0** |

> **この数字を「8 → 1 に減った＝良くなった」と読んではならない。**
> 減ったのは**対象集合が変わったから**であり、品質が上がったからではない（Checked も 39 → 35 に減っている）。
> **CI（`sync-plugin-plangate.yml:73`）は `--warn-only` 付きのため、どちらでも緑**。
> したがって初版が書いていた「付け替えだけ先に入れると CI が赤になる」という順序制約は**存在しない**。
> 実際に必要な順序制約は「**欠落検出（#1109）を先に入れないと、付け替えが検査の弱体化になる**」である。

---

## 7. スコープ外で見つけた問題

| # | 内容 | 実測 | 提案 |
|---|---|---|---|
| S-1 | **配布物 `plugin/plangate/skills` の openai.yaml が 4 件欠落**: `ai-loop-cycle` / `breakdown-gate` / `ref-integrity-scan` / `subagent-delegation-brief`（39 skill 中 35 件のみ）。**実害の範囲は限定的**: `install.sh --codex` 経路は target 側で `openai.yaml` を再生成するため無影響（§3.1）。影響しうるのは **marketplace 経路のみ**（ただし marketplace が `agents/openai.yaml` を実消費するかは**本調査では未確認**） | `find plugin -name openai.yaml` → 35 / `find plugin/plangate/skills -maxdepth 2 -name SKILL.md` → 39 | **#1109 として起票済み**。**欠落は現行検査では検出されない**（`:35` で silently skip）ため、**presence 検査の新設**が本体（対象の付け替えでは解決しない） |
| S-2 | `check-codex-skill-spec.sh` は **target dir 不在で python traceback + rc=1**。`--warn-only` は violation にしか効かず**例外は素通しする** | `sh scripts/check-codex-skill-spec.sh --warn-only --target /nonexistent-dir-xyz` → `FileNotFoundError` / rc=1 | 案 (A′) 手順 3 で同時に修正 |
| S-2′ | **`check-codex-skill-spec.sh` は既定 target で既に 8 violations / rc=1**。CI が緑なのは `--warn-only` のため（F-11 / R-005） | `sh scripts/check-codex-skill-spec.sh` → Checked 39 / VIOLATIONS (8) / rc=1 | 付け替え前後の比較で誤読しないよう §6 に baseline を明記済み。8 件の内容是正自体は本 issue の scope 外 |
| S-3 | `.agents/skills` と `.codex/skills` の drift が **2 → 4 件に増加**。**向きは一様でなく 1 件（`plan-review-gate`）は派生が新しい**（§1.3） | §1.3 の向き判定表 | **#956 に追記**（件数を契約値にしない形で）。`plan-review-gate` の 36 行は **#956 と本 issue の両方に跨る**（内容判定=#956 / 破棄回避=本 issue 手順 0） |
| S-4 | 導入先が自前で `.agents/skills` を持っている場合、`install.sh --codex` 後に **導入先でも同じ二重 root が起こる** | §3.2（機構は §2.3 で実証済み） | `docs/staged-adoption-guide.md` 等に注記（本 issue の scope 外だが同一機構） |

---

## 8. Human 判断が要る点

| # | 論点 | 選択肢 | 備考 |
|---|---|---|---|
| H-1 | **案の確定**（(A′) を採るか） | (A) / **(A′)** / (B) / (C) / (D) | 本調査の推奨は (A′)。(B) は #956 との整合を先に取る必要 |
| H-2 | **`.codex/skills` 120 ファイルの untrack 実行** | 承認 / 保留 | **不可逆に近い破壊的操作**。本調査では未実施。exec 時に名指し承認が要る。**前提条件: 手順 0（`plan-review-gate` 36 行の reconcile）完了**（R-002。未実施のまま実行すると 36 行が消える） |
| H-3 | `scripts/install-plangate-skills-to-codex.sh` を **削除するか / 注記のみで残すか** | 削除 / 残す | 残すと「叩けば復活する」経路が残る（AC-4 の検査で捕捉はできる） |
| H-4 | **#1078 との `.codex/` 作業順序** | #1078 先行 / 本 issue 先行 / 並行 | issue 本文も「順序調整が要る」と明記。`.codex/instructions.md` を両方が触る |
| H-5 | **#1109（openai.yaml 欠落 + presence 検査新設）を本 issue に取り込むか分けるか** | 取り込む / 別 issue（#1109 で起票済） | **順序制約あり**: #1109 の presence 検査を先に入れないと、手順 3 の付け替えは**検査の弱体化**になる（R-001）。CI が赤くなる問題は存在しない（`--warn-only`） |
| H-6 | Mode 判定 | standard / high-risk | 変更ファイル数 120+（untrack）・配布経路に触れる・CI 配線 1 本に影響 → **high-risk 相当を推奨**。HO 対象パスは含まないが `.github/workflows` は触らない設計にしてある |
| **H-7** | **`plan-review-gate` の 36 行（C-1 追加品質ゲート）の扱い** | ① `.agents/skills` へ取り込む / ② `review-self.md` テンプレの C1-SUP-PLAN-01/02 で足りるとして破棄 / ③ #956 側で判断 | **R-002 由来の新規**。配布物は 60 行版で導入先は元々持っていない（回帰ではない）が、**skill としては `.codex` にしか無い**。②を選ぶ場合は「破棄の根拠」を明文で残すこと |

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

# 7. C-2 反映時に追加実施した検証（R-001 / R-002 / R-003 / R-004 / R-005）
sh scripts/check-codex-skill-spec.sh                              ; echo rc=$?  # 39 / 8 viol / 1
sh scripts/check-codex-skill-spec.sh --target plugin/plangate/skills ; echo rc=$?  # 35 / 1 viol / 1
sh scripts/check-codex-skill-spec.sh --warn-only                  ; echo rc=$?  # 0
sh scripts/check-codex-skill-spec.sh --warn-only --target plugin/plangate/skills ; echo rc=$?  # 0
sed -n '28,45p' scripts/check-codex-skill-spec.sh          # :35 の silently skip を確認
sh <scratch>/dir.sh <worktree>                             # drift 4 件の向き
diff .agents/skills/plan-review-gate/SKILL.md .codex/skills/plan-review-gate/SKILL.md
grep -rl "No Placeholders Rule" --exclude-dir=.git .
grep -n "_is_managed_subdir\|cat > " plugin/plangate/scripts/install-plangate-skills.sh
grep -rl "\.codex/skills" --exclude-dir=.git . | grep -v "^\.codex/skills/" \
  | grep -v "^docs/working/TASK-1086/" | wc -l                # 48
```

### 未実施（正直な記録）

- **`sh tests/run-tests.sh` の baseline（AC-6）は本調査では取得していない。** 起動はしたが、
  同一マシンで他セッションの full-suite が並走しており（`ta-61` が入れ子で full-suite を再実行する構造）、
  完走前に自分の実行を中断した。**「rc=0 だった」とは書けない** ので、baseline は
  **exec 開始時に単独実行で再測定すること**（issue AC-6 も「件数は exec 開始時に再測定」と規定している）。
- 本調査で新規に実行したのは **読み取り専用の測定のみ**。`.codex/skills` を含む repo ファイルは一切変更していない
  （追加したのは本ファイルと `review-external.md` のみ）。fixture はすべて scratchpad 配下に作成した。
- **marketplace 経路（`codex plugin add`）が `agents/openai.yaml` を実際に消費するかは未確認**（§7 S-1）。
  「実害は marketplace 経路に限られる」は install 導線の実読から導いた**上限の推定**であり、
  marketplace 側の消費を一次確認したわけではない。

---

## 10. C-2 レビュー指摘の disposition（1 回確定反映）

> 指摘全文: [`review-external.md`](./review-external.md)（`origin/review/1086-verify` 由来 / 297 行）
> VERDICT: **REJECT**（critical 0 / major 2 / minor 2 / info 1）
> 反映方針: [`.claude/rules/working-context.md`](../../../.claude/rules/working-context.md) の C-2 差分管理に従い **1 回だけ確定反映**。
> **全 5 件を、レビューアの出力を鵜呑みにせず自分で一次実測して再現したうえで disposition した。**

| R-NNN | severity | disposition | 自分の再実測 | 反映先 |
|---|---|---|---|---|
| **R-001** | major | **accepted（全面）** | `sed -n '28,45p' scripts/check-codex-skill-spec.sh` → `:35` に `if not os.path.exists(yaml_path): continue` を確認。`--target plugin/plangate/skills` → **Checked 35 / VIOLATIONS 1（`diff-audit` 66 文字）/ rc=1**。`--warn-only` 付きは **rc=0**。→ 初版の「強くなる」「4 件が即 FAIL」「CI が赤になる」は**3 つとも誤り** | F-10 新設 / §4.1 / **§6 推奨理由 5 を差し替え表に全面書き換え** / §6 手順 0′ 新設 / §6 baseline 表新設 / §7 S-1 / H-5 |
| **R-002** | major | **accepted（全面）** | `git log -1 --date=short` ×8 + `wc -l` で向きを実測 → `plan-review-gate` のみ `.codex` が新しく **96 行 vs 60 行**。`diff` の先頭が `25a26,61`（= 36 行）。`grep -rl "No Placeholders Rule"` → skill としては `.codex` のみ。配布物は 60 行版 | F-8 書き換え / **§1.3 に向き判定表 + 重大度評価を新設** / §6 穴 4 新設 / **§6 手順 0（reconcile）新設** / §7 S-3 / H-2 前提条件 / **H-7 新設** |
| **R-003** | minor | **accepted** | `grep -rl ... \| grep -v ...` → **48** を再現（自分の TASK-1086 doc 2 件を除外して一致）。§4 の表に載っていない 9 件を列挙して確認 | §4 冒頭に網羅性注記 / **§4.4 新設（9 件を収容）** / §4.3 に `install.sh` と `install-plangate-skills.sh` を再掲 |
| **R-004** | minor | **accepted** | `grep -n "_is_managed_subdir\|cat > "` → `:64` で `agents\|assets` を同期対象外、`:237` で `openai.yaml` を dst 側生成。→ `install.sh --codex` 経路は配布物の openai.yaml を消費しない | **§3.1 に再生成の注記を新設** / §7 S-1 に scope を明記（**ただし marketplace 側の消費は未確認と併記**） |
| **R-005** | info | **accepted** | `sh scripts/check-codex-skill-spec.sh` → **Checked 39 / VIOLATIONS 8 / rc=1**、`--warn-only` → rc=0 を再現 | F-11 新設 / §4.1 / **§6 baseline 表**（「8 → 1 は改善ではない」と明記）/ §7 S-2′ |

**棄却した指摘: なし**（5 件すべて一次実測で再現し、いずれも doc 側の記述が誤っていた）。

### 推奨案の再判定

**(A′) を維持する。** 変更しない理由:

- R-001 / R-002 が崩したのは **「(A′) の副作用をどう回収するか」の設計**であって、**(A′) を選ぶ根拠ではない**。
- (A′) を選ぶ 2 本の根拠は無傷: **F-6（導入先ユーザー影響ゼロ）はレビューアが独立に再現**（review-external §3「棄却した指摘候補」）、
  **AC-1/AC-2 を恒久的に満たすのは (A′) と (B) だけ**という比較も変わっていない。
- 崩れた回収手段は差し替え可能だった: 穴 1 は「対象の付け替え」→「**欠落検出の新設**」、穴 4 は「**untrack 前の reconcile**」。
  いずれも (A′) の枠内で閉じる（別案へ乗り換える必要がない）。

**ただし前提条件が 2 件増えた**（初版には無かった）:

1. **#1109（openai.yaml presence 検査の新設）を先に入れる** — 入れずに手順 3 の付け替えを行うと、検査は 39 → 35 に**弱くなる**
2. **`plan-review-gate` の 36 行を reconcile してから untrack する** — 順序を逆にすると 36 行が消える（H-7）

### 監査表

| R-NNN | status | reflected_in | notes |
|---|---|---|---|
| R-001 | **reflected** | 本コミット（`Refs: R-001`） | 「付け替えで強くなる」を全面撤回。`:35` の silently skip を根拠に、回収手段を presence 検査の新設へ差し替え。「即 FAIL」「CI 赤」の記述を除去し baseline 表で置換 |
| R-002 | **reflected** | 本コミット（`Refs: R-002`） | §1.3 に向き判定表を新設。`plan-review-gate` は `.codex` が新しく 36 行多い。手順 0（reconcile）を untrack の前に必須化し、H-2 の前提条件と H-7 を追加 |
| R-003 | **reflected** | 本コミット（`Refs: R-003`） | §4.4 を新設し 9 件を収容。48 件を 4 表で完全収容。結論（壊れるのは 2 経路のみ）は維持 |
| R-004 | **reflected** | 本コミット（`Refs: R-004`） | §3.1 に openai.yaml 再生成を注記。S-1 の実害 scope を marketplace 経路に限定（marketplace 側の消費は未確認と併記） |
| R-005 | **reflected** | 本コミット（`Refs: R-005`） | §6 に付け替え前後 baseline を併記し「8 → 1 は改善ではない」と明記 |
