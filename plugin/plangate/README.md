# plangate — Claude Code plugin

PlanGate — AI コーディングの開発統制 OS。Intent/Mode 分類、4 Gate システム、エージェント統制層を提供する Claude Code plugin。

- **Version**: 0.5.0
- **Source**: https://github.com/s977043/plangate

## インストール

### 前提

- Claude Code CLI（最新版推奨）
- git

### 手順

```bash
# 1. plangate リポジトリをクローン
git clone https://github.com/s977043/plangate.git
cd plangate

# 2. plugin を Claude Code に登録（CC の公式手順に従う）
# 例: Claude Code の plugin インストールコマンド経由
# または .claude/settings.json で plugin path を指定
```

詳細なインストール手順は Claude Code 公式ドキュメントを参照してください。

## 同梱内容

```text
plugin/plangate/
├── .claude-plugin/
│   └── plugin.json         # manifest (v0.4.0)
├── agents/                 # 6 agents
├── skills/                 # 14 skills
│   ├── brainstorming/
│   ├── self-review/
│   ├── subagent-driven-development/
│   ├── systematic-debugging/
│   ├── codex-multi-agent/
│   ├── setup-team/            # TASK-0035 追加
│   ├── intent-classifier/     # Phase 1 追加
│   ├── skill-policy-router/   # Phase 1 追加
│   ├── evidence-ledger/       # Phase 1 追加
│   ├── design-gate/           # Phase 2 追加
│   ├── review-gate/           # Phase 2 追加
│   ├── context-packager/      # Phase 3 追加
│   ├── subagent-dispatch/     # Phase 3 追加
│   └── pr-decision/           # Phase 3 追加
├── commands/               # 7 commands
│   ├── working-context.md
│   ├── ai-dev-workflow.md
│   ├── pg-think.md            # Phase 1 追加
│   ├── pg-hunt.md             # Phase 1 追加
│   ├── pg-check.md            # Phase 1 追加
│   ├── pg-verify.md           # Phase 1 追加
│   └── pg-tdd.md              # Phase 2 追加
├── rules/                  # 8 rules
│   ├── working-context.md
│   ├── review-principles.md
│   ├── mode-classification.md
│   ├── evidence-ledger.md     # Phase 1 追加
│   ├── design-gate.md         # Phase 2 追加
│   ├── review-gate.md         # Phase 2 追加
│   ├── completion-gate.md     # Phase 2 追加
│   ├── subagent-roles.md      # Phase 3 追加
│   └── worktree-policy.md     # Phase 3 追加
├── hooks/                  # (reserved for future)
└── scripts/                # (reserved for future)
```

## 基本的な使い方

### ワークフロー起動

```
/working-context TASK-XXXX
/ai-dev-workflow TASK-XXXX plan
/ai-dev-workflow TASK-XXXX exec
```

### Skills の明示呼び出し

```
plangate:brainstorming
plangate:self-review
plangate:subagent-driven-development
plangate:systematic-debugging
plangate:codex-multi-agent
```

### Agents の明示呼び出し（Task ツール経由）

```python
Task(subagent_type="plangate:workflow-conductor", ...)
Task(subagent_type="plangate:spec-writer", ...)
Task(subagent_type="plangate:implementer", ...)
Task(subagent_type="plangate:linter-fixer", ...)
Task(subagent_type="plangate:acceptance-tester", ...)
Task(subagent_type="plangate:code-optimizer", ...)
```

### Rules の参照

plugin 内 agents は plugin ルート相対パスで rules を参照します:

```markdown
> 判定基準の正本: `plugin/plangate/rules/mode-classification.md`
```

## トラブルシュート

### Q. `plangate:<skill>` が認識されない

- Plugin が正しくインストール・有効化されているか確認
- Claude Code を再起動

### Q. legacy `.claude/` と競合する

- Plugin 側と legacy 側は併存可能（デュアル運用）
- 明示的な prefix（`plangate:`）で区別可能
- 完全分離したい場合は `.claude/` 側のファイルを一時リネーム or 削除

### Q. 未同梱 agent（例: backend-specialist）を使いたい

本 plugin には含まれません。以下で入手:

```bash
git clone https://github.com/s977043/plangate.git
cp plangate/.claude/agents/backend-specialist.md <your-project>/.claude/agents/
```

詳細は [migration note](../../docs/plangate-plugin-migration.md) 参照。

### Q. Hooks を使いたい

現バージョンでは hooks 未実装（ディレクトリ枠のみ）。将来バージョンで対応予定。

## 既知の制約

- plugin install 後の挙動は Claude Code の内部仕様に依存（詳細は runtime 検証結果を参照）
- `test-engineer` / `release-manager` agent 未同梱（`.claude/` にも存在しない）

## 参考

- 詳細な移行ガイド: [docs/plangate-plugin-migration.md](../../docs/plangate-plugin-migration.md)
- プロジェクト本体: https://github.com/s977043/plangate
- 親 Issue: [#16](https://github.com/s977043/plangate/issues/16)

## ライセンス

本リポジトリ root の LICENSE を参照。
