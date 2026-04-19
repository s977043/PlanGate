# PlanGate

「計画を承認しないとAIは1行もコードを書けない」ゲート型AI駆動開発ワークフロー。

## 解説記事

- [AIコーディングの暴走を「仕組み」で止める — PlanGateという開発フロー](https://note.com/mine_unilabo/n/n3aae6b5467b9)（note）

## 概要

PlanGateは、PBI（プロダクトバックログアイテム）からPlan生成、レビュー、Agent実行までを体系化したゲート型ワークフローです。obra/superpowersの思想（Iron Law、合理化テーブル、2-5分粒度、TDD先行）を取り込み、Claude CodeやCodex CLIと組み合わせてAI駆動開発を実践するためのフレームワークを提供しています。

## リポジトリ構成

```
/docs                    - ナレッジ・ガイドドキュメント
  /ai                    - 共通ルール・役割分担（project-rules.md, tool-roles.md）
  /working               - チケット単位の作業コンテキスト（セッション永続化用）
/.claude                 - Claude Code固有の設定
  /rules                 - Claude Code運用ルール
  /commands              - カスタムスラッシュコマンド
  /agents                - エージェント定義（詳細版、正本）
  /skills                - カスタムスキル
/.codex                  - Codex CLI固有の設定
  /agents                - エージェント定義（要約版 .toml）
/plugin/plangate         - Claude Code plugin として配布可能なパッケージ
  /.claude-plugin        - plugin manifest
  /agents                - 中核6 agents（ワークフロー中核）
  /skills                - 中核5 skills
  /commands              - 主要導線2 commands
  /rules                 - 判定ルール3ファイル
/scripts                 - 起動スクリプト
```

## クイックスタート（コマンド3つで完了）

詳細: [docs/plangate.md](docs/plangate.md)

```bash
# 1. 作業コンテキスト作成
/working-context TASK-XXXX

# 2. Plan + ToDo + Test Cases生成 → セルフレビュー → 外部AIレビュー（一括自動実行）
/ai-dev-workflow TASK-XXXX plan

# 3. 人間レビュー（PlanGateゲート）後、Agent実行
/ai-dev-workflow TASK-XXXX exec
```

## Iron Law（各フェーズの不可侵ルール）

| フェーズ/スキル | Iron Law |
| --- | --- |
| brainstorming | `NO CODE WITHOUT APPROVED DESIGN FIRST` |
| plan | `NO EXECUTION WITHOUT REVIEWED PLAN FIRST` |
| exec | `NO SCOPE CHANGE WITHOUT USER APPROVAL` |
| subagent-driven-development | `NO MERGE WITHOUT TWO-STAGE REVIEW` |
| self-review | `NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE` |
| systematic-debugging | `NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST` |

## Claude Code + Codex CLI併用

本リポジトリはClaude CodeとCodex CLIの両方に対応している。共通ルールは`docs/ai/project-rules.md`に一元化し、ツール固有の入口ファイル（`CLAUDE.md`, `AGENTS.md`）は薄く保つ構成。

詳細: [docs/ai/tool-roles.md](docs/ai/tool-roles.md)

Codex 側はルートの [AGENTS.md](AGENTS.md) を入口にし、再利用可能な学びは [AGENT_LEARNINGS.md](AGENT_LEARNINGS.md) に蓄積する。

| ツール | 入口ファイル | 固有設定 |
| --- | --- | --- |
| Claude Code | `CLAUDE.md` | `.claude/`（agents, commands, skills, rules） |
| Codex CLI | `AGENTS.md` | `.codex/`（config.toml, agents, instructions.md） |
| 共通 | `docs/ai/project-rules.md` | `docs/plangate.md`, `docs/ai-driven-development.md` |

## Claude Code設定

| カテゴリ | パス | 説明 |
|---------|------|------|
| ルール | `.claude/rules/` | 作業コンテキスト管理、レビュー原則 |
| コマンド | `.claude/commands/` | `/working-context`, `/ai-dev-workflow` |
| エージェント | `.claude/agents/` | 18エージェント体制（詳細は `.claude/agents/README.md` 参照） |
| スキル | `.claude/skills/` | 7スキル（下表参照） |

### スキル一覧

| スキル | 説明 |
|--------|------|
| `skill-creator` | 新しいClaude Codeスキルを対話的に設計・生成 |
| `skill-optimizer` | 既存スキルの評価・改善 |
| `skill-ops-planner` | スキルポートフォリオの運用計画・ロードマップ作成 |
| `self-review` | 変更内容の17項目体系的セルフレビュー |
| `brainstorming` | アイデアから設計書（PBI INPUT PACKAGE）への昇華 |
| `subagent-driven-development` | サブエージェント駆動の2段階レビュー開発 |
| `systematic-debugging` | エビデンスベースの体系的デバッグ |

## Claude Code plugin として利用する

他プロジェクトで PlanGate のワークフローを使いたい場合、`plugin/plangate/` を Claude Code plugin として導入できます。

### 同梱範囲（plugin 版）

| カテゴリ | 件数 | 内訳 |
|---------|-----|------|
| Skills | 5 | `brainstorming`, `self-review`, `subagent-driven-development`, `systematic-debugging`, `codex-multi-agent` |
| Commands | 2 | `working-context`, `ai-dev-workflow` |
| Agents | 6 | `workflow-conductor`, `spec-writer`, `implementer`, `linter-fixer`, `acceptance-tester`, `code-optimizer` |
| Rules | 3 | `working-context.md`, `review-principles.md`, `mode-classification.md` |

### 新旧導入方法の差分

| 項目 | 従来（`.claude/` 直置き） | plugin（`plugin/plangate/`） |
|------|----------------------|-------------------------|
| 導入方法 | リポジトリを clone してそのまま使用 | Claude Code に plugin として追加 |
| 導入単位 | リポジトリ全体 | plugin パッケージ |
| 同梱範囲 | 全 skills / 全 18 agents / 全 rules | 中核 5 skills + 2 commands + 6 agents + 3 rules |
| カスタム agents | repo 側で編集 | plugin 導入先リポジトリ側で `.claude/` に拡張 |
| アップデート | `git pull` | plugin アップデート |
| 対象ユーザー | PlanGate 本体開発 | 他プロジェクトで PlanGate を運用したい開発者 |

### plugin 未同梱 agents の扱い

以下はプロジェクト固有前提や専門用途のため **plugin には含まれません**。必要に応じて `.claude/agents/` から個別にコピーしてください。

- **プロジェクト固有**: `backend-specialist`, `frontend-specialist`, `database-architect`, `devops-engineer`（Laravel/PostgreSQL/ECS 等の前提あり）
- **専門用途**: `security-auditor`, `penetration-tester`, `performance-optimizer`（opt-in 想定）
- **補助**: `migration-agent`, `research-analyst`, `explorer-agent`, `project-planner`, `retrospective-analyst`, `scrum-master`, `agile-coach`, `documentation-writer`, `debugger`, `prompt-engineer`, `orchestrator`, `claude-code-reviewer`, `skill-designer`

入手方法: `git clone https://github.com/s977043/plangate.git && cp .claude/agents/<name>.md <your-project>/.claude/agents/`

### Codex CLI は plugin 対象外

本 plugin は **Claude Code 専用**です。Codex CLI 向け設定（`.codex/`）は plugin に同梱しません。Codex との連携は `openai-codex/codex` plugin 等を別途導入してください。

### 移行ガイド

詳細な移行手順、デュアル運用、将来計画は [docs/plangate-plugin-migration.md](docs/plangate-plugin-migration.md) 参照。

## ドキュメント

| ドキュメント | 内容 |
| --- | --- |
| [docs/plangate.md](docs/plangate.md) | PlanGateガイド（全体像・設計思想・他手法との比較） |
| [docs/ai-driven-development.md](docs/ai-driven-development.md) | ワークフロー詳細・プロンプト集 |
| [docs/plangate-v4-design.md](docs/plangate-v4-design.md) | v4設計 — takt知見統合 |
| [docs/plangate-v5-design.md](docs/plangate-v5-design.md) | v5設計 — L-0リンター自動修正・ハーネスエンジニアリング知見統合 |
| [docs/plangate-v6-roadmap.md](docs/plangate-v6-roadmap.md) | v6ロードマップ — ハーネスエンジニアリング差分解消 |

## 向いているチーム

- AIコーディングエージェントを**プロダクション開発**に使いたい
- Vibe Codingの限界を感じている
- 「AIに任せたいが、暴走が怖い」と感じている
- アジャイルでスプリント単位のPBIを回している

## 向いていない場合

- プロトタイプや実験的な開発（Vibe Codingの方が速い）
- 1人で完結する個人プロジェクト（PlanGateはオーバースペック）
- AI開発をまだ試したことがない（まずはVibe Codingで体験するのが先）

## ライセンス

MIT
