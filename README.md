# PlanGate

「計画を承認しないとAIは1行もコードを書けない」ゲート型AI駆動開発ワークフロー。

## 解説記事

<!-- TODO: note公開後にURLを差し替え -->
- [AIコーディングの暴走を「仕組み」で止める — PlanGateという開発フロー](https://note.com/xxx)（note）

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
/scripts                 - 起動スクリプト
```

## PlanGate v5

「計画を承認しないとAIは1行もコードを書けない」ゲート型ワークフロー。
PBI（プロダクトバックログアイテム）からPlan生成、レビュー、Agent実行までを体系化し、obra/superpowersの思想（Iron Law、合理化テーブル、2-5分粒度、TDD先行）を取り込んだv5。

詳細: [docs/plangate.md](docs/plangate.md)

### クイックスタート（コマンド3つで完了）

```bash
# 1. 作業コンテキスト作成
/working-context TASK-XXXX

# 2. Plan + ToDo + Test Cases生成 → セルフレビュー → 外部AIレビュー（一括自動実行）
/ai-dev-workflow TASK-XXXX plan

# 3. 人間レビュー（PlanGateゲート）後、Agent実行
/ai-dev-workflow TASK-XXXX exec
```

### Iron Law（各フェーズの不可侵ルール）

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
| エージェント | `.claude/agents/` | `workflow-conductor`（exec管理の司令塔、8役割: フェーズ遷移・品質ゲート・スキル委譲・status.md管理・fix loop管理・モード分岐制御・L-0管理・チェックポイント管理） |
| スキル | `.claude/skills/` | 7スキル（下表参照） |

### スキル一覧

| スキル | 説明 |
|--------|------|
| `skill-creator` | 新しいClaude Codeスキルを対話的に設計・生成 |
| `skill-optimizer` | 既存スキルの評価・改善 |
| `skill-ops-planner` | スキルポートフォリオの運用計画・ロードマップ作成 |
| `self-review` | 変更内容の15項目体系的セルフレビュー |
| `brainstorming` | アイデアから設計書（PBI INPUT PACKAGE）への昇華 |
| `subagent-driven-development` | サブエージェント駆動の2段階レビュー開発 |
| `systematic-debugging` | エビデンスベースの体系的デバッグ |

## 内容

### Claude Code活用
- Claude Codeを使った開発ワークフローの効率化
- 実践的なTips・ベストプラクティス
- ショートカット・カスタマイズ設定

### AIエージェント構築
- Claude API / Agent SDKを使ったエージェント実装
- マルチエージェント構成のパターン
- ツール連携・MCPサーバーの活用

### プロンプトエンジニアリング
- 効果的なプロンプト設計のパターン集
- コンテキスト管理・Few-shot学習の実践例
- ユースケース別プロンプトサンプル

## 対象読者

- AIを活用した開発に興味があるエンジニア
- Claude Code / Anthropic APIを使い始めたい方
- AI駆動開発のベストプラクティスを探している方

## ライセンス

MIT
