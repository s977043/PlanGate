# plangate — Claude Code plugin

PlanGate — a governance OS for AI-assisted coding.
Provides Intent/Mode classification, a 4-Gate approval system, and an agent control layer as a Claude Code plugin.

- **Version**: v8.18.0
- **Source**: <https://github.com/s977043/plangate>

## Install

### ワンコマンドインストール（推奨）

```bash
git clone https://github.com/s977043/plangate.git
cd plangate
sh install.sh          # .claude/ と .codex/ を自動検出してインストール
```

オプション:

```bash
sh install.sh --claude              # Claude Code のみ
sh install.sh --codex               # Codex のみ
sh install.sh --target /path/to/dir # インストール先を指定
sh install.sh --dry-run             # 変更内容を確認（実行しない）
```

### 手動インストール

### Claude Code へのインストール

#### 前提条件

- Claude Code CLI（最新版推奨）
- git
- `bin/plangate` CLI（一部のコマンド/スキル — `/plangate-setup`・`ai-dev-plan`・`ai-dev-exec`・`ai-dev-verify`・`plan-review-gate`・`working-context`・`local-exec-handoff` — が使用）。Plugin 単体導入時は PATH に無いため、リポジトリ clone と PATH への追加が必要です。一時的な追加: `git clone https://github.com/s977043/plangate.git ~/plangate && export PATH="$HOME/plangate/bin:$PATH"`（永続化するには `~/.bashrc` / `~/.zshrc` 等に追記）

#### 方法 A: プラグインパスを直接指定（推奨）

```bash
# 1. リポジトリをクローン（またはサブモジュールとして追加）
git clone https://github.com/s977043/plangate.git /path/to/plangate

# 2. プロジェクトの .claude/settings.json にプラグインパスを追加
# （手動で settings.json を編集する）
```

`プロジェクト/.claude/settings.json` に以下を追加:

```json
{
  "plugins": ["/path/to/plangate/plugin/plangate"]
}
```

#### 方法 B: ファイルを手動コピー

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

Claude Code セッション内で以下を実行:

```text
/subagent-team-design
```

エージェント一覧と利用可能スキルが表示されれば成功。

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
```

> Codex には `plugin install` サブコマンドはありません。`marketplace add` で登録が完了します。

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
ls .codex/skills/ | grep -v '^\.' | wc -l
# 35 前後のスキルディレクトリが表示されれば成功（plugin/plangate/skills の全スキルが展開されます）
```

Codex UI を開き、スキル選択ペインで PlanGate スキル（例: `ai-dev-plan`, `brainstorming` など）が表示されることを確認。

> **確認の注意**: `codex plugin marketplace list` は現行 Codex CLI では未実装（`unrecognized subcommand`）です。
> Marketplace 登録の確認は、`codex plugin marketplace add` 実行時の出力 `Installed marketplace root: <path>` と、
> その root 配下 `plugin/plangate/.claude-plugin/plugin.json` の `version` を参照してください。

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

## Contents

```text
plugin/plangate/
├── .claude-plugin/
│   └── plugin.json         # manifest (v8.11.0)
├── agents/                 # 17 agents
├── assets/                 # アイコン等のアセット
│   └── plangate-small.svg  # icon_small / icon_large 兼用 (SVG)
├── skills/                 # 35 skills（.agents/skills/ から同期 + plugin 専用スキルを含む上位集合）
│   ├── acceptance-criteria-build/
│   ├── acceptance-review/
│   ├── ai-dev-brainstorm/
│   ├── ai-dev-exec/
│   ├── ai-dev-plan/
│   ├── ai-dev-verify/
│   ├── architecture-sketch/
│   ├── brainstorming/
│   ├── codex-multi-agent/
│   ├── codex-mvp-split/
│   ├── context-load/
│   ├── context-packager/
│   ├── design-gate/
│   ├── edgecase-enumeration/
│   ├── evidence-ledger/
│   ├── feature-implement/
│   ├── intent-classifier/
│   ├── known-issues-log/
│   ├── local-exec-handoff/
│   ├── manual-cloud-task/
│   ├── nonfunctional-check/
│   ├── plan-review-gate/
│   ├── plangate-setup/
│   ├── pr-decision/
│   ├── requirement-gap-scan/
│   ├── review-gate/
│   ├── risk-assessment/
│   ├── diff-audit/
│   ├── subagent-team-design/
│   ├── skill-creator/
│   ├── skill-policy-router/
│   ├── subagent-dispatch/
│   ├── subagent-driven-development/
│   ├── systematic-debugging/
│   └── working-context/
├── commands/               # 4 commands
│   ├── working-context.md
│   ├── ai-dev-workflow.md
│   ├── codex-mvp-split.md
│   └── plangate-setup.md
├── rules/                  # 6 rules
│   ├── hybrid-architecture.md
│   ├── mode-classification.md
│   ├── orchestrator-mode.md
│   ├── responsibility-classes.md
│   ├── review-principles.md
│   └── working-context.md
├── hooks/                  # (reserved — 現バージョンでは未実装)
└── scripts/                # install-plangate-skills.sh
    └── install-plangate-skills.sh
```

> **NOTE**: `plugin/plangate/assets/` には `plangate-small.svg` のみ含まれます。
> `plangate.png` は同梱されていないため、`openai.yaml` の `icon_large` も
> `plangate-small.svg`（SVG）を使用します。

### Agents (23)

責務別エージェント定義。plan / exec / review / verify / orchestrate などの単一責務を持つ（`agents/` 配下）。

> **model について**: 配布版の agents はすべて `model: inherit`（メイン会話のモデルに追従）に正規化されています。導入先でエージェント別にモデルを使い分けたい場合は、本家の [docs/ai/model-profiles.md §11](https://github.com/s977043/plangate/blob/main/docs/ai/model-profiles.md)（定型=sonnet / 判断系=inherit の 2 tier 設計）を参考に frontmatter の `model:` を調整してください。

### Skills (37)

再利用可能なスキル定義（`.agents/skills/` から同期 + plugin 専用スキルを含む上位集合。`skills/` 配下）。

### Commands (4)

スラッシュコマンド定義（`/working-context` / `/ai-dev-workflow` / `/codex-mvp-split` / `/plangate-setup`。`commands/` 配下）。

### Rules (6)

運用ルール定義（hybrid-architecture / mode-classification / orchestrator-mode / responsibility-classes / review-principles / working-context。`rules/` 配下）。

---

## Basic Usage

### Start a workflow

```text
/working-context TASK-XXXX
/ai-dev-workflow TASK-XXXX plan
/ai-dev-workflow TASK-XXXX exec
```

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
- [ ] **README 正確性**: Contents 欄のエージェント数・スキル数が実態と一致していること（agents: 23、skills: 37）
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
- To fully separate, temporarily rename or remove files in `.claude/`

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

- Migration guide: [docs/plangate-plugin-migration.md](../../docs/plangate-plugin-migration.md)
- Orchestrator Mode spec: [docs/orchestrator-mode.md](../../docs/orchestrator-mode.md)
- Settings wiring contract: [docs/ai/settings-wiring-contract.md](../../docs/ai/settings-wiring-contract.md)
- Project repository: <https://github.com/s977043/plangate>
- Parent issue: [#16](https://github.com/s977043/plangate/issues/16)

## License

See the LICENSE file at the repository root.
