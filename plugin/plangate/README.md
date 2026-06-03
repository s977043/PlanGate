# plangate — Claude Code plugin

PlanGate — a governance OS for AI-assisted coding.
Provides Intent/Mode classification, a 4-Gate approval system, and an agent control layer as a Claude Code plugin.

- **Version**: v8.10.0
- **Source**: https://github.com/s977043/plangate

## Install

### Claude Code へのインストール

#### 前提条件

- Claude Code CLI（最新版推奨）
- git

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
  "plugins": [
    "/path/to/plangate/plugin/plangate"
  ]
}
```

#### 方法 B: ファイルを手動コピー

```bash
# 1. リポジトリをクローン
git clone https://github.com/s977043/plangate.git

# 2. plugin ディレクトリの中身を .claude/ 配下にコピー
cd plangate
cp -r plugin/plangate/agents/* /your-project/.claude/agents/
cp -r plugin/plangate/skills/* /your-project/.claude/skills/
cp -r plugin/plangate/commands/* /your-project/.claude/commands/
cp -r plugin/plangate/rules/* /your-project/.claude/rules/
```

#### インストール確認

Claude Code セッション内で以下を実行:

```
/setup-team
```

エージェント一覧と利用可能スキルが表示されれば成功。

---

### Codex へのインストール

#### 前提条件

- Codex CLI（最新版推奨）
- git, sh

#### 手順

```bash
# 1. リポジトリをクローン
git clone https://github.com/s977043/plangate.git
cd plangate

# 2. インストールスクリプトを実行（.codex/skills/ にスキルを同期）
sh scripts/install-plangate-skills-to-codex.sh
```

実行すると `.codex/skills/<skill-name>/` 配下に各スキルの `SKILL.md` と `agents/openai.yaml` が生成されます。

#### インストール確認

```bash
ls .codex/skills/ | grep -v '^\.' | wc -l
# 29 前後のスキルディレクトリが表示されれば成功
```

Codex UI を開き、スキル選択ペインで PlanGate スキル（例: `ai-dev-plan`, `brainstorming` など）が表示されることを確認。

#### アップデート

```bash
cd plangate
git pull
sh scripts/install-plangate-skills-to-codex.sh
```

スクリプトは冪等に動作します（未変更スキルはスキップ、`--force` で強制上書き）。

#### スクリプトオプション

| オプション | 説明 |
|-----------|------|
| `--force` | 既存スキルも強制上書き |
| `--json` | インストール結果を JSON で stdout に出力（CI向け） |
| `--source DIR` | ソースディレクトリを上書き（plugin/plangate/skills/ にも適用可） |

環境変数 `PLANGATE_SKILLS_DIR` でもソースディレクトリを指定できます。

---

## Contents

```text
plugin/plangate/
├── .claude-plugin/
│   └── plugin.json         # manifest (v8.10.0)
├── agents/                 # 24 agents
├── assets/                 # アイコン等のアセット
│   ├── plangate-small.svg  # icon_small (32x32)
│   └── plangate.png        # icon_large (128x128)
├── skills/                 # 15 skills
│   ├── brainstorming/
│   ├── self-review/
│   ├── subagent-driven-development/
│   ├── systematic-debugging/
│   ├── codex-multi-agent/
│   ├── setup-team/
│   ├── intent-classifier/
│   ├── skill-policy-router/
│   ├── evidence-ledger/
│   ├── design-gate/
│   ├── review-gate/
│   ├── context-packager/
│   ├── subagent-dispatch/
│   └── pr-decision/
├── commands/               # 7 commands
│   ├── working-context.md
│   ├── ai-dev-workflow.md
│   ├── pg-think.md
│   ├── pg-hunt.md
│   ├── pg-check.md
│   ├── pg-verify.md
│   └── pg-tdd.md
├── rules/                  # 9 rules
│   ├── working-context.md
│   ├── review-principles.md
│   ├── mode-classification.md
│   ├── evidence-ledger.md
│   ├── design-gate.md
│   ├── review-gate.md
│   ├── completion-gate.md
│   ├── subagent-roles.md
│   └── worktree-policy.md
├── hooks/                  # (reserved — 現バージョンでは未実装)
└── scripts/                # (reserved — 現バージョンでは未実装)
```

> **NOTE**: `.agents/skills/` には 29 スキルが存在しますが、`plugin/plangate/skills/` には 15 スキルが含まれています。
> 差分（14 スキル）は plugin 向け整理中です。全スキルを使うには `--source` オプションで `.agents/skills/` を指定して Codex インストールを実行してください。

---

## Basic Usage

### Start a workflow

```
/working-context TASK-XXXX
/ai-dev-workflow TASK-XXXX plan
/ai-dev-workflow TASK-XXXX exec
```

### Invoke skills explicitly

```
plangate:brainstorming
plangate:self-review
plangate:subagent-driven-development
plangate:systematic-debugging
plangate:codex-multi-agent
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

- [ ] **ファイル整合性**: `plugin/plangate/skills/` のスキル数が `.agents/skills/` と一致していること（現状 15 vs 29 — 差分解消中）
- [ ] **README 正確性**: Contents 欄のエージェント数・スキル数が実態と一致していること（agents: 24、skills: 15）
- [ ] **openai.yaml 完全性**: 全スキルの `agents/openai.yaml` に 5 フィールド（display_name / short_description / icon_small / icon_large / default_prompt）が揃っていること
- [ ] **アセット存在確認**: `plugin/plangate/assets/` に `plangate-small.svg` と `plangate.png` が実在すること
- [ ] **インストールスクリプト動作確認**: `install-plangate-skills-to-codex.sh` をクリーン環境で実行し、全スキルが `.codex/skills/` に展開されること
- [ ] **Claude Code インストール確認**: `plugin/plangate/` をプラグインパスとして指定し、Claude Code セッション内でスキル・コマンド・エージェントが認識されること（`/setup-team` で確認）
- [ ] **hooks 配線状況の明示**: `plugin/plangate/hooks/` が reserved である旨を明記済み
- [ ] **バージョン整合性**: `plugin/plangate/.claude-plugin/plugin.json` の version と `CHANGELOG.md` の最新リリースバージョンが一致していること
- [ ] **CI 同期チェック**: `.agents/skills/` と `plugin/plangate/skills/` の差分を検出する CI ジョブが存在すること

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

## Known Limitations

- Post-install behavior depends on Claude Code internals (refer to runtime verification results)
- `test-engineer` and `release-manager` agents are not bundled (they do not exist in `.claude/` either)
- `plugin/plangate/skills/` には 15 スキルが含まれていますが、`.agents/skills/` の 29 スキルとの差分（14 スキル）は整理中です

## Future / RFC

- **Parent-Child PBI Orchestrator Mode** (specification only, see [`docs/orchestrator-mode.md`](../../docs/orchestrator-mode.md) and [`docs/rfc/plangate-decompose.md`](../../docs/rfc/plangate-decompose.md)): a layer above single-PBI control that decomposes a parent PBI into multiple child PBIs and runs each through PlanGate. Implementation (Parent Supervisor / Integration Agent / `plangate decompose` CLI / Hook-based gate enforcement) is tracked in follow-up PBIs.
- **Plugin スキル完全同期**: `.agents/skills/` の 29 スキルをすべて `plugin/plangate/skills/` に同期し、CI で差分検出ジョブを整備

## References

- Migration guide: [docs/plangate-plugin-migration.md](../../docs/plangate-plugin-migration.md)
- Orchestrator Mode spec: [docs/orchestrator-mode.md](../../docs/orchestrator-mode.md)
- Settings wiring contract: [docs/ai/settings-wiring-contract.md](../../docs/ai/settings-wiring-contract.md)
- Project repository: <https://github.com/s977043/plangate>
- Parent issue: [#16](https://github.com/s977043/plangate/issues/16)

## License

See the LICENSE file at the repository root.
