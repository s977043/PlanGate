# TASK-0020 Plugin Install Syntax 引用

> 作成日: 2026-04-20
> 参照元: TASK-0017 evidence/plugin-spec-research.md, TASK-0018 evidence/invocation-syntax.md

## Plugin ディレクトリ構造（TASK-0017 で確定）

```text
plugin/plangate/
├── .claude-plugin/
│   └── plugin.json
├── agents/
├── commands/
├── skills/
├── rules/
├── hooks/
├── scripts/
└── README.md
```

## Install 手順（想定）

### ローカル導入

```bash
# 1. plangate リポジトリをクローン or pull
git clone https://github.com/s977043/plangate.git
cd plangate

# 2. Claude Code にローカル plugin として追加（具体手順は Claude Code の公式手順に従う）
# 例: Claude Code 側で plugin ディレクトリを指定、または symlink 作成
```

### Marketplace 導入（将来、未対応）

現時点では marketplace 公開は対象外。将来検討。

## 呼び出し Syntax（TASK-0018 で確定）

### Skills

```
plangate:brainstorming
plangate:self-review
plangate:subagent-driven-development
plangate:systematic-debugging
plangate:codex-multi-agent
```

### Commands

```
/working-context     # plugin または legacy、解決順は Claude Code 内部仕様
/ai-dev-workflow
```

### Agents

```
Task(subagent_type="plangate:workflow-conductor", ...)
Task(subagent_type="plangate:spec-writer", ...)
Task(subagent_type="plangate:implementer", ...)
Task(subagent_type="plangate:linter-fixer", ...)
Task(subagent_type="plangate:acceptance-tester", ...)
Task(subagent_type="plangate:code-optimizer", ...)
```

## Rules 参照

plugin 内 agents から rules を参照する場合:

```markdown
> 判定基準の正本: `plugin/plangate/rules/mode-classification.md`
```

## 使用上の注意

- plugin 同梱対象は本リポジトリに存在する中核のみ（7 skills + 8 agents + 3 rules ではなく、実態として **7 導線（5 skills + 2 commands）+ 6 agents + 3 rules**）
- 未同梱（`pr-review-response`, `pr-code-review`, `setup-team`, `test-engineer`, `release-manager`）は別途手配
- Codex CLI は本 plugin の対象外（別 plugin の `openai-codex/codex` 等を利用）
