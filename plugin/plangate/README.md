# plangate — Claude Code plugin

**AI に実装を任せる前に、何を変更し、何を検証し、誰が承認するかを揃えるプラグインです。**

例えば「説明文を直して」という依頼を、変更範囲・受入条件を持つ計画へ整理し、人間が確認してから実装へ進めます。
これは利用イメージであり、実行結果の報告ではありません。まずは検証用プロジェクトで、導入状態の確認から試してください。

English: A lightweight governance harness for AI coding agents. Start by checking installation; planning, approval, and hook enforcement are separate steps.

**導入しただけでは hook 強制は有効になりません。** 配布するのは agent / skill / command / rule の定義です。
ゲートの機械的な保護は別途設定・検証が必要です。設定を変える前に [Hooks の設定について](#hooks-の設定について) を確認してください。

- **Version**: v8.24.0
- **Source**: <https://github.com/s977043/plangate>

## Install

推奨の導入経路は Marketplace 経由です（Claude Code は下記
[方法 A](#方法-a-marketplace-経由推奨)、Codex は [Codex の方法 A](#方法-a-marketplace-経由推奨-1)。
root の [README.md](../../README.md) の Option A と同じ）。
初回は利用する CLI の方法 A を一つ選んでください。`install.sh` は root README の Option B に相当する代替経路です。
Marketplace 版と併用すると資産が二重に配置されます（方法 A の注意を参照）。

### Claude Code へのインストール

#### 方法 A: Marketplace 経由（推奨）

root の [README.md](../../README.md) の Option A と同じ手順です。

前提: Claude Code と git が利用可能であること。検証用プロジェクトで Claude Code を開きます。

セッション内スラッシュコマンド（インストール画面では、このプロジェクトだけに適用する local scope を選択）:

```text
/plugin marketplace add s977043/PlanGate
/plugin install plangate@plangate
```

CLI から:

```bash
claude plugin marketplace add s977043/PlanGate
claude plugin install plangate@plangate --scope local
claude plugin list
```

**最初の成功確認**: `claude plugin list` で `plangate@plangate` の導入先 scope と有効状態を確認します。
プラグイン一覧への表示は、計画生成や hook の動作を検証したことにはなりません。
次は [最初の計画を作る](#start-a-workflow) へ進みます。試す前に [やめ方と残るもの](#やめ方と残るもの) も確認できます。

> **注意（併用による二重配置）**: Marketplace 経由で plugin を有効化しているプロジェクトで
> `install.sh`（代替経路、および方法 C の `install.sh --claude`）を実行すると、
> 同じ agents / skills / commands / rules が `.claude/agents/` / `.claude/skills/` /
> `.claude/commands/` / `.claude/rules/`（および `plangate-manifest.json`）にも配置され、
> plugin 版と二重になります。デュアル運用は技術的に可能ですが、併用は推奨しません。

#### 前提条件

- Claude Code CLI（最新版推奨）
- git
- `bin/plangate` CLI（本プラグイン同梱の一部のコマンド / スキル / エージェントが使用。内訳は下記）。Plugin 単体導入時は PATH に無いため、リポジトリ clone と PATH への追加が必要です。一時的な追加: `git clone https://github.com/s977043/plangate.git ~/plangate && export PATH="$HOME/plangate/bin:$PATH"`（永続化するには `~/.bashrc` / `~/.zshrc` 等に追記）
  - **カウント対象**: 同梱の **コマンド定義**（`commands/*.md`）/ **スキル本体**（`skills/*/SKILL.md`）/ **エージェント本文**（`agents/*.md`）の 3 種のみ。**正は次の再現コマンドの出力**であり、その下の一覧は測定時点のスナップショットです。スキルの追加・削除で変動するため、**件数は契約値として扱わないでください**。

    ```bash
    # plugin/plangate/ 直下で実行
    grep -rl 'bin/plangate' commands/*.md skills/*/SKILL.md agents/*.md
    ```

    commit `2447bf8` 時点の測定結果:

    - コマンド: `plangate-setup`
    - スキル: `ai-dev-exec` / `ai-dev-plan` / `ai-dev-verify` / `ai-loop-cycle` / `intent-classifier` / `local-exec-handoff` / `plan-review-gate` / `plangate-setup` / `skill-policy-router` / `working-context`
    - エージェント: `setup-coordinator` / `workflow-conductor`

  - **カウント対象外**: 説明用ドキュメント内の言及（本 README 自身 / `skills/README.md` / `rules/**`）は CLI 依存に数えません。また `skills/ai-loop-cycle/` 同梱の `references/` / `scripts/` にも `bin/plangate` の記述がありますが、これは HO（Hardening Override）パス指定および「本番フローから呼ばれない隔離 PoC」であることの明示であり、CLI 依存ではありません。範囲を指定しない下記コマンドはこれらも拾うため、カウント対象より多い結果を返します（その差分がカウント対象外にあたります）。

    ```bash
    # plugin/plangate/ 直下で実行（カウント対象 + カウント対象外）
    grep -rl 'bin/plangate' .
    ```

#### 方法 B: プラグインパスを直接指定

作者向けの一時検証では、セッション限定の読み込みを使えます。Marketplace 導入とは別経路です。

```bash
git clone https://github.com/s977043/plangate.git /path/to/plangate
cd /path/to/your-project
claude --plugin-dir /path/to/plangate/plugin/plangate
```

終了後、`--plugin-dir` を付けずに起動すればこの読み込み指定はなくなります。
セッション中に作成したファイルは残ります。組織の管理ポリシーで使用できない場合は、回避せず管理者へ確認してください。

#### 方法 C: ファイルを手動コピー

```bash
# 1. リポジトリをクローン（ホームディレクトリ等に）
git clone https://github.com/s977043/plangate.git ~/plangate

# 2. 対象プロジェクトへ移動してインストール
cd /your-project
sh ~/plangate/install.sh --claude
```

または手動コピー:

```bash
cp -r ~/plangate/plugin/plangate/agents/*   /your-project/.claude/agents/
cp -r ~/plangate/plugin/plangate/skills/*   /your-project/.claude/skills/
cp -r ~/plangate/plugin/plangate/commands/* /your-project/.claude/commands/
cp -r ~/plangate/plugin/plangate/rules/*    /your-project/.claude/rules/
```

#### インストール確認

方法 A は `/plugin` の Installed 一覧、または `claude plugin list` で導入状態を確認します。
方法 A / B は、そのプラグインを読み込んだセッションで `/` を入力し、`/plangate:` のコマンド表示を確認します。
方法 B はセッション限定なので、永続インストール済みであることは要求しません。
方法 C は plugin の一覧ではなく、導入先の `.claude/commands/` 等の配置と、`/working-context` などローカル定義の表示を確認します。
直接展開版と plugin 版では名前空間が異なります。再読み込みを求められた場合は、CLI の案内に従います。

---

### Codex へのインストール

#### 前提条件

- Codex CLI（最新版推奨）
- git, sh
- `bin/plangate` CLI（PlanGate のゲート検証を使う場合）。Plugin 単体では PATH に無いため、リポジトリ clone が必要（上記 Claude Code 前提条件参照）

#### 方法 A: Marketplace 経由（推奨）

```bash
# marketplace を登録（出力に Installed marketplace root が表示される）
codex plugin marketplace add s977043/PlanGate
codex plugin add plangate@plangate
```

> `marketplace add` は配布元の登録です。続けて `plugin add` でプラグインを導入します。
> Codex の導入サブコマンドは `install` ではなく `add` です。

#### 方法 B: スクリプトで .codex/skills/ に直接展開

```bash
# 1. リポジトリをクローン
git clone https://github.com/s977043/plangate.git
cd plangate

# 2. インストールスクリプトを実行（.codex/skills/ にスキルを同期）
sh plugin/plangate/scripts/install-plangate-skills.sh
```

実行すると `.codex/skills/<skill-name>/` 配下に各スキルの `SKILL.md` と `agents/openai.yaml` が生成されます。

#### インストール確認

```bash
# 方法 B（直接展開）の場合
# 展開先のスキル数と、配布元 plugin/plangate/skills の SKILL.md 数が
# 一致すれば成功（スキル追加で増えるため、絶対件数ではなく両者の一致で判定します）
ls .codex/skills/ | grep -v '^\.' | wc -l
ls -d /path/to/plangate/plugin/plangate/skills/*/ | wc -l
```

Codex UI を開き、スキル選択ペインで PlanGate スキル（例: `ai-dev-plan`, `brainstorming` など）が表示されることを確認。

Marketplace 経由では、Marketplace の登録（`codex plugin marketplace add`）とプラグインの導入（`codex plugin add`）を分けて考え、導入状態を確認します。

```bash
codex plugin list --json
```

`installed` 配列の PlanGate エントリを確認し、その `installed` と `enabled` が true であることを確かめます。
Marketplace の一覧やキャッシュディレクトリがあるだけでは、プラグインが利用可能になった証拠にはなりません。
コマンドが見つからない場合は `codex --version` と `codex plugin --help` を確認し、対応する CLI を用意してから進めてください。

#### アップデート

Marketplace 経由:

```bash
codex plugin marketplace upgrade plangate
```

スクリプト経由（方法 B）:

```bash
cd plangate
git pull
sh plugin/plangate/scripts/install-plangate-skills.sh --force
```

スクリプトは冪等に動作します（未変更スキルはスキップ、`--force` で強制上書き）。

#### スクリプトオプション

| オプション     | 説明                                                                                   |
| -------------- | -------------------------------------------------------------------------------------- |
| `--force`      | 既存スキルも強制上書き                                                                 |
| `--json`       | インストール結果を JSON で stdout に出力（CI向け）                                     |
| `--source DIR` | ソースディレクトリを上書き                                                             |
| `--target DIR` | インストール先を上書き（デフォルト: `$(git rev-parse --show-toplevel)/.codex/skills`） |

環境変数 `PLANGATE_SKILLS_DIR` でもソースディレクトリを指定できます。

---

<a id="手動インストール"></a>

<a id="ワンコマンドインストールinstallsh"></a>

### 代替経路: install.sh で直接展開

```bash
git clone https://github.com/s977043/plangate.git /path/to/plangate
cd /path/to/your-project
sh /path/to/plangate/install.sh --claude --dry-run
# 展開先と変更内容を確認してから --dry-run を外します
```

オプション:

```bash
sh /path/to/plangate/install.sh --claude              # Claude Code のみ
sh /path/to/plangate/install.sh --codex               # Codex のみ
sh /path/to/plangate/install.sh --target /path/to/dir # インストール先を指定
sh /path/to/plangate/install.sh --dry-run             # 変更内容を確認（実行しない）
```

この経路はローカルコピーを直接管理したい場合の代替です。Marketplace 版と同じプロジェクトに重ねて導入しないでください。
`install.sh` の manifest 生成・撤去には Python 3 が必要です。

## やめ方と残るもの

まず実行中の作業を終え、必要な成果物・設定差分を確認してください。導入経路ごとに撤去方法が異なります。

### Marketplace 版

Claude Code の方法 A で local scope に導入した場合は、同じ検証用プロジェクトから実行します。
一時停止だけなら disable を使います。uninstall は保存済みのオプション等を削除する場合があるため、必要な記録を先に保全してください。

```bash
claude plugin disable plangate@plangate --scope local
# 撤去する場合。--keep-data はプラグインの永続データを保持します。
claude plugin uninstall plangate@plangate --scope local --keep-data
claude plugin list
```

user / project scope に導入した場合は、その導入先 scope を指定してください。
共有設定を変更する project scope の撤去は、影響を確認してから行います。

Codex の方法 A の撤去:

```bash
codex plugin remove plangate@plangate
codex plugin list --json
```

marketplace 登録とプラグインの導入は別です。登録元を消す操作は、同じ配布元を使う他のプラグインへの影響もあるため、この手順には含めません。

### スクリプト・手動コピー版

Marketplace の uninstall / remove では、直接配置したファイルは撤去されません。
root の `install.sh --uninstall` は Claude Code 側の manifest を使う処理で、Codex の直接展開版の撤去コマンドではありません。
まず導入先のバックアップ・manifest・変更差分を確認します。

```bash
cd /path/to/your-project
sh /path/to/plangate/install.sh --uninstall --dry-run
```

**dry-run の削除候補に導入前からあるファイルや編集済みファイルが含まれる場合は、実行を止めてください。**
manifest があるだけで安全に元へ戻せるとは限りません（既存ファイルが削除対象になる再現済みの問題: [#1636](https://github.com/s977043/PlanGate/issues/1636)）。手動コピー版と Codex の直接展開版は、導入前との差分から PlanGate 由来と確認できたものだけを個別に撤去します。
`.claude/` や `.codex/` 全体を削除しないでください。

**残るもの**: 作業中に作成した `docs/working/` の成果物、手動で追加した hook 設定、PATH の追記などは、プラグインの撤去だけでは自動では戻りません。
設定ファイル全体を置換せず、導入前の記録と比較して必要な箇所だけを戻してください。

## Contents

下記はディレクトリ **構成** のみを示します。各ディレクトリの **中身（名前一覧）は
下の `### Agents` / `### Skills` / `### Commands` / `### Rules` が正**であり、
ここには件数もファイル名も重複させません（同じ集合を 2 箇所に書くと片方だけ更新されて腐るため）。

```text
plugin/plangate/
├── .claude-plugin/
│   └── plugin.json         # manifest（version はこのファイルが正）
├── .codex-plugin/
│   └── plugin.json         # Codex 用 manifest（.claude-plugin と parity）
├── agents/                 # 一覧は Agents 節
├── assets/                 # アイコン等のアセット
│   └── plangate-small.svg  # icon_small / icon_large 兼用 (SVG)
├── skills/                 # 一覧は Skills 節（.agents/skills/ から同期 + plugin 専用スキルを含む上位集合）
├── commands/               # 一覧は Commands 節
├── rules/                  # 一覧は Rules 節
├── hooks/                  # (reserved — 現バージョンでは未実装)
└── scripts/                # install-plangate-skills.sh
    └── install-plangate-skills.sh
```

> **NOTE**: `plugin/plangate/assets/` には `plangate-small.svg` のみ含まれます。
> `plangate.png` は同梱されていないため、`openai.yaml` の `icon_large` も
> `plangate-small.svg`（SVG）を使用します。

**以下 4 節の読み方**: 各節の **正は再現コマンドの出力**であり、その下の一覧は
測定時点のスナップショットです。追加・削除で変動するため、**件数は契約値として
扱わないでください**（そもそも件数を書きません）。各コマンドは `README.md` を
除外した「定義本体」のみを列挙します。

### Agents

責務別エージェント定義。plan / exec / review / verify / orchestrate などの単一責務を持つ（`agents/` 配下）。

```bash
# plugin/plangate/ 直下で実行
ls agents/*.md | grep -v 'README\.md$' | xargs -n1 basename | sed 's/\.md$//'
```

commit `86d05f7` 時点の測定結果:

`acceptance-tester` / `code-optimizer` / `documentation-writer` / `explorer-agent` / `implementation-agent` / `implementer` / `linter-fixer` / `orchestrator` / `project-planner` / `qa-reviewer` / `requirements-analyst` / `retrospective-analyst` / `setup-coordinator` / `skill-designer` / `solution-architect` / `spec-writer` / `workflow-conductor`

> **model について**: 配布版の agents はすべて `model: inherit`（メイン会話のモデルに追従）に正規化されています。導入先でエージェント別にモデルを使い分けたい場合は、本家の [docs/ai/model-profiles.md §11](https://github.com/s977043/plangate/blob/main/docs/ai/model-profiles.md)（定型=sonnet / 判断系=inherit の 2 tier 設計）を参考に frontmatter の `model:` を調整してください。

### Skills

再利用可能なスキル定義（`.agents/skills/` から同期 + plugin 専用スキルを含む上位集合。`skills/` 配下）。

```bash
# plugin/plangate/ 直下で実行
ls -d skills/*/ | xargs -n1 basename
```

commit `86d05f7` 時点の測定結果:

`acceptance-criteria-build` / `acceptance-review` / `ai-dev-brainstorm` / `ai-dev-exec` / `ai-dev-plan` / `ai-dev-verify` / `ai-loop-cycle` / `architecture-sketch` / `brainstorming` / `breakdown-gate` / `codex-multi-agent` / `codex-mvp-split` / `context-load` / `context-packager` / `design-gate` / `diff-audit` / `edgecase-enumeration` / `evidence-ledger` / `feature-implement` / `intent-classifier` / `known-issues-log` / `local-exec-handoff` / `manual-cloud-task` / `nonfunctional-check` / `plan-review-gate` / `plangate-setup` / `pr-decision` / `ref-integrity-scan` / `requirement-gap-scan` / `review-gate` / `risk-assessment` / `skill-creator` / `skill-policy-router` / `subagent-delegation-brief` / `subagent-dispatch` / `subagent-driven-development` / `subagent-team-design` / `systematic-debugging` / `working-context`

### Commands

スラッシュコマンド定義（`commands/` 配下）。

```bash
# plugin/plangate/ 直下で実行
ls commands/*.md | grep -v 'README\.md$' | xargs -n1 basename | sed 's/\.md$//'
```

commit `86d05f7` 時点の測定結果:

`ai-dev-workflow` / `ai-loop-workflow` / `codex-mvp-split` / `plangate-setup` / `working-context`

### Rules

運用ルール定義（`rules/` 配下）。

```bash
# plugin/plangate/ 直下で実行
ls rules/*.md | xargs -n1 basename | sed 's/\.md$//'
```

commit `86d05f7` 時点の測定結果:

`hybrid-architecture` / `mode-classification` / `orchestrator-mode` / `responsibility-classes` / `review-principles` / `working-context`

---

## Basic Usage

### Start a workflow

以下は **Claude Code の Marketplace 版**の例です。検証用プロジェクトで、利用中の番号と重ならない `TASK-XXXX` を選びます。
CLI と参照資料の前提条件を確認し、まず作業コンテキストを作成します。

```text
/plangate:working-context TASK-XXXX
```

作成先の `docs/working/TASK-XXXX/pbi-input.md` または対話入力に、目的・変更する範囲・受入条件を記入します。
次に計画を生成します（これは実装の承認ではありません）。

```text
/plangate:ai-dev-workflow TASK-XXXX plan
```

**初回体験は計画の確認まで**で止めます。`docs/working/TASK-XXXX/` の `plan.md`、`todo.md`、`test-cases.md` を開き、
依頼した範囲と受入条件が反映されているかを確認してください。ファイルの存在だけでは成功と判定しません。
参照資料・テンプレート・外部レビュー手段を利用できない場合は、その不足を明記し、検証済みや承認済みとは扱いません。
コマンドが認識されない場合は `/plugin` の Installed と、名前空間付きコマンドの表示を確認します。

**C-3: 人間の計画レビューと承認が完了してから**、別の操作として実装へ進みます。
この README の実行例は承認記録の代わりになりません。
導入先には `bin/plangate` が配布されないため、exec を機械的に止める仕組みは働きません。C-3 の承認は運用で守ってください。

```text
/plangate:ai-dev-workflow TASK-XXXX exec
```

English: Stop after planning for the first trial. Inspect the scope and acceptance criteria in the generated artifacts.
Execution requires human review and approval at C-3; an installed plugin or generated plan is not approval.
PR の C-4 レビューとマージの責務は変更しません。詳細は [Core Contract](../../docs/ai/core-contract.md) を参照してください。

### Invoke skills explicitly

```text
plangate:brainstorming
plangate:diff-audit
plangate:subagent-driven-development
plangate:systematic-debugging
plangate:codex-multi-agent
plangate:ai-dev-plan
plangate:ai-dev-exec
plangate:ai-dev-verify
```

### Invoke agents (via the Task tool)

```python
Task(subagent_type="plangate:workflow-conductor", ...)
Task(subagent_type="plangate:spec-writer", ...)
Task(subagent_type="plangate:implementer", ...)
Task(subagent_type="plangate:linter-fixer", ...)
Task(subagent_type="plangate:acceptance-tester", ...)
Task(subagent_type="plangate:code-optimizer", ...)
```

### Rule references

Agents inside the plugin reference rules using paths relative to the plugin root:

```markdown
> Authoritative source: `plugin/plangate/rules/mode-classification.md`
```

---

## Hooks の設定について

`plugin/plangate/hooks/` は現バージョンでは **reserved（未実装）** です。

EH-1/2/3/6/9 などの Hook を使用するには、別途手動設定が必要です:

1. `.codex/hooks/` に hook スクリプトを配置（Codex 用）
2. `.claude/settings.json` の `hooks` セクションに hook を登録（Claude Code 用）

詳細は [`docs/ai/settings-wiring-contract.md`](../../docs/ai/settings-wiring-contract.md) を参照してください。

---

## 配布チェックリスト

- [ ] **ファイル整合性**: `plugin/plangate/skills/` が `.agents/skills/` を包含する上位集合であること（`scripts/sync-plugin-plangate.sh` で同期。`context-packager` 等の plugin 専用スキルを含む）
- [ ] **README 正確性**: Contents 欄の `### Agents` / `### Skills` / `### Commands` / `### Rules` の各再現コマンドを実行し、直下のスナップショット一覧と**集合として**一致していること（一致しなければ一覧と測定 commit を更新する。件数は記載しない）
- [ ] **openai.yaml 完全性**: 全スキルの `agents/openai.yaml` に 6 フィールド（display_name / short_description / icon_small / icon_large / default_prompt / brand_color）が揃い、`scripts/check-codex-skill-spec.sh` を PASS すること
- [ ] **アセット存在確認**: `plugin/plangate/assets/` に `plangate-small.svg` が実在すること（PNG は不要）
- [ ] **インストールスクリプト動作確認**: `install-plangate-skills.sh` をクリーン環境で実行し、全スキルが `.codex/skills/` に展開されること
- [ ] **Claude Code インストール確認**: `plugin/plangate/` をプラグインパスとして指定し、Claude Code セッション内でスキル・コマンド・エージェントが認識されること（`/subagent-team-design` で確認）
- [ ] **hooks 配線状況の明示**: `plugin/plangate/hooks/` が reserved である旨を明記済み
- [ ] **バージョン整合性**: `plugin/plangate/.claude-plugin/plugin.json` の version と `CHANGELOG.md` の最新リリースバージョンが一致していること
- [ ] **CI 同期チェック**: `.agents/skills/` → `plugin/plangate/skills/` の同期差分を検出する CI ジョブ（`sync-plugin-plangate.yml`）が存在すること

---

## Troubleshooting

### `plangate:<skill>` is not recognized

- Verify the plugin is correctly installed and enabled
- Restart Claude Code

### Conflict with a legacy `.claude/` directory

- The plugin and a legacy `.claude/` setup can coexist (dual-mode operation)
- Use the explicit `plangate:` prefix to target the plugin side
- Do not delete the entire `.claude/` directory. Review installation records and local changes, then follow [やめ方と残るもの](#やめ方と残るもの).

### Using an agent not bundled in this plugin (e.g. `backend-specialist`)

Project-specific agents are not included in this plugin. Obtain them directly:

```bash
git clone https://github.com/s977043/plangate.git
cp plangate/.claude/agents/backend-specialist.md <your-project>/.claude/agents/
```

See the [migration guide](../../docs/plangate-plugin-migration.md) for details.

### Using hooks

Hooks are not implemented in this version (directory structure reserved). Planned for a future release.
EH-1/2/3/6/9 を使うには `.codex/hooks/` と `.claude/settings.json` の手動設定が必要です（上記「Hooks の設定について」を参照）。

> **前提コマンド（フック配線を行う場合のみ）**: **`jq` と `sed` が PATH に必要**です。
> EH-13（承認トークン書き込みガード）は v8.19.0 で fail-closed 化され、いずれかが不在だと
> **判定不能として `exit 2`（block）** します（PlanGate 本体リポジトリの
> `scripts/check-approval-token-write.sh` にある `command -v jq` / `command -v sed`）。
> 結果として **Edit / Write と Bash が止まります**（EH-13 の matcher は `Edit|Write` と `Bash`）。
>
> **本プラグインを導入するだけなら `jq` / `sed` は不要です** — プラグインが配布するのは
> skill / agent / command / rules であり、**フックは配布しない**ためです
> （`claude plugin details plangate@plangate` の Component inventory が `Hooks (0)` を返す）。
>
> 回避策と移行手順は
> [CHANGELOG v8.19.0 の「⚠️ 更新前に必ずお読みください」](https://github.com/s977043/plangate/blob/main/CHANGELOG.md)
> を参照してください。

---

## ai-loop-workflow（同梱 PoC / low-risk 帯限定）

本プラグインには `ai-loop-workflow`（human-on-the-loop 裁定ループ、通称 arbiter）の
docs・裁定エンジン・skill が **参照用 PoC として同梱**されています。

Plugin は `docs/` を配布対象として認識しません（公式仕様: プラグインが読み込むのは
`agents/` / `commands/` / `skills/` 等の定義ディレクトリのみで、任意のディレクトリを
自動配布する仕組みはありません）。そのため本 PoC は Agent Skills の **bundled
resources** 方式（skill ディレクトリ内に `references/` + `scripts/` を自己完結で
同梱する構成）で配布されます。

### 内容

`skills/ai-loop-cycle/` が唯一の配布単位です（`.agents/skills/ai-loop-cycle/` から
同期される配布版正本。PlanGate リポジトリ固有パスを抽象化済み）:

- `skills/ai-loop-cycle/SKILL.md` — 1 サイクル（C-3' 裁定）実行手順
- `skills/ai-loop-cycle/references/` — ai-loop-workflow の同梱 docs（1 サイクル
  手順・lite 判定 4 軸・W チェック・裁定分岐・思想層。フラット配置、17 ファイル。
  `docs/workflows/ai-loop/` + `docs/ai/ai-loop/` の思想・仕様層から同期）
- `skills/ai-loop-cycle/scripts/arbiter.py` + `test_arbiter.py` — L2 裁定エンジンと
  そのテスト（`scripts/ai-loop/` から同期）

### 導入手順

```bash
# marketplace 経由でインストール済みの場合、上記一式は自動的に含まれます
codex plugin marketplace add s977043/PlanGate
codex plugin add plangate@plangate
# または方法 B（スクリプト展開）/ 手動コピーでも同様に含まれます
```

導入後、`skills/ai-loop-cycle/SKILL.md` を呼び出す前に
**`${CLAUDE_PLUGIN_ROOT}/skills/ai-loop-cycle/references/ho-paths.md`
の雛形注記に従い、導入先プロジェクト固有の HO（Hardening Override）パス一覧を
確定**してください。未確定のまま運用すると、arbiter は安全側 escalate（human
escalate）に倒れます（不変条件であり緩和不可）。

裁定エンジンを直接呼び出す場合は、スキルディレクトリ内の同梱パスを参照します:

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/skills/ai-loop-cycle/scripts/arbiter.py" --input /path/to/input.json
```

### 適用境界

- **低リスク帯限定**: lite 帯候補（変更規模小・新規設計なし・既存パターン踏襲・
  可逆）の変更のみを対象とする PoC です。high-risk / critical 相当の変更には
  使用しないでください（使っても flow フェーズで即 human escalate になります）。
- **HITL/HOTL 前提**: 自動承認（`AUTO_APPROVED`）後も PR レビュー・CI ゲートは
  省略されません。`HUMAN_ESCALATED` は必ず人間へ提示し、AI が自己解決しては
  なりません。
- **PlanGate 本番ゲート非適用**: 本 PoC は PlanGate の本番承認フロー
  （WF-00〜WF-07・C-3/C-4 ゲート）を置き換えるものではなく、それらとは独立した
  隔離実験です。導入先の本番ゲートとは統合しません。
- **摩擦台帳・run 記録は導入先で用意**: 裁定 record・摩擦台帳（frictions log）の
  保存先・フォーマットは本プラグインでは規定しません。`skills/ai-loop-cycle/`
  の記載に従い、導入先プロジェクトのディレクトリ規約に合わせて用意してください。

---

## Known Limitations

- Post-install behavior depends on Claude Code internals (refer to runtime verification results)
- `test-engineer` and `release-manager` agents are not bundled (they do not exist in `.claude/` either)
- `plugin/plangate/hooks/` は reserved（未実装）。EH-1/2/3/6/9 の利用には手動設定が必要

## Future / RFC

- **Parent-Child PBI Orchestrator Mode** (specification only, see [`docs/orchestrator-mode.md`](../../docs/orchestrator-mode.md) and [`docs/rfc/plangate-decompose.md`](../../docs/rfc/plangate-decompose.md)): a layer above single-PBI control that decomposes a parent PBI into multiple child PBIs and runs each through PlanGate. Implementation (Parent Supervisor / Integration Agent / `plangate decompose` CLI / Hook-based gate enforcement) is tracked in follow-up PBIs.
- **Hooks 実装**: `plugin/plangate/hooks/` に EH-1/2/3/6/9 を同梱し、インストールスクリプトで自動配線

## References

CLI の導入・撤去・名前空間は公式仕様で確認します（2026-11-03 照合）。この README は各端末での実機試験結果ではありません。
使っている版でコマンドが認識されない場合は、`claude --version` / `codex --version` と各 `plugin --help` を確認し、別構文を推測して続行しないでください。

- Claude Code plugin CLI: <https://code.claude.com/docs/en/plugins/cli-reference>
- Claude Code plugin discovery and scope: <https://code.claude.com/docs/en/discover-plugins>
- Codex CLI plugin and marketplace commands: <https://learn.chatgpt.com/docs/cli/reference>

- Migration guide: [docs/plangate-plugin-migration.md](../../docs/plangate-plugin-migration.md)
- Orchestrator Mode spec: [docs/orchestrator-mode.md](../../docs/orchestrator-mode.md)
- Settings wiring contract: [docs/ai/settings-wiring-contract.md](../../docs/ai/settings-wiring-contract.md)
- Project repository: <https://github.com/s977043/plangate>
- Parent issue: [#16](https://github.com/s977043/plangate/issues/16)

## License

See the LICENSE file at the repository root.
