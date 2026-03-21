# ai-dev-lab

AI駆動開発（AI-Driven Development）の実践知識・サンプル・ノウハウをまとめたリポジトリです。

## 概要

このリポジトリは、AIをフル活用した開発スタイル（AI-Driven Development）を探求・記録することを目的としています。Claude Codeの活用、AIエージェントの構築、効果的なプロンプト設計など、AI時代の開発手法を実践ベースでまとめています。

## リポジトリ構成

```
/docs                    - ナレッジ・ガイドドキュメント
  /working               - チケット単位の作業コンテキスト（セッション永続化用）
/.claude
  /rules                 - Claude Code運用ルール
  /commands              - カスタムスラッシュコマンド
  /agents                - エージェント定義
  /skills                - カスタムスキル
```

## AI駆動開発ワークフロー v3

PBI（プロダクトバックログアイテム）からPlan生成、レビュー、Agent実行までを体系化したワークフローを搭載しています。
obra/superpowersの思想（Iron Law、合理化テーブル、2-5分粒度、TDD先行）を取り込んだv3。

詳細: [docs/ai-driven-development.md](docs/ai-driven-development.md)

### クイックスタート（コマンド3つで完了）

```bash
# 1. 作業コンテキスト作成
/working-context TASK-XXXX

# 2. Plan + ToDo + Test Cases生成 → セルフレビュー → 外部AIレビュー（一括自動実行）
/ai-dev-workflow TASK-XXXX plan

# 3. 人間レビュー（C-3ゲート）後、Agent実行
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

## Claude Code設定

| カテゴリ | パス | 説明 |
|---------|------|------|
| ルール | `.claude/rules/` | 作業コンテキスト管理、レビュー原則 |
| コマンド | `.claude/commands/` | `/working-context`, `/ai-dev-workflow` |
| エージェント | `.claude/agents/` | `workflow-conductor`（exec管理の司令塔） |
| スキル | `.claude/skills/` | 7スキル（下表参照） |

### スキル一覧

| スキル | 説明 |
|--------|------|
| `skill-creator` | 新しいClaude Codeスキルを対話的に設計・生成 |
| `skill-optimizer` | 既存スキルの評価・改善 |
| `skill-ops-planner` | スキルポートフォリオの運用計画・ロードマップ作成 |
| `self-review` | 変更内容の12フェーズ体系的セルフレビュー |
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
