# カスタムスキル一覧

PlanGate ワークフロー v5 で使用するスキル群。

## スキル

| スキル | 説明 | カテゴリ |
| ------ | ---- | -------- |
| `skill-creator` | 新しいClaude Codeスキルを対話的に設計・生成するワークフロー | developer-tools |
| `skill-optimizer` | 既存スキルの評価・改善（成功基準ベースの小さな変更） | developer-tools |
| `skill-ops-planner` | スキルポートフォリオの運用計画・ロードマップ作成 | developer-tools |
| `brainstorming` | アイデアや要件を対話的に設計書（PBI INPUT PACKAGE）へ昇華 | workflow |
| `self-review` | 変更内容に対する詳細セルフレビュー（15項目チェック） | review |
| `systematic-debugging` | バグや障害の体系的調査・根本原因特定 | debugging |
| `subagent-driven-development` | 実装タスクのサブエージェント委譲・品質管理 | workflow |

## 配置ルール

- スキルは `.claude/skills/<skill-name>/SKILL.md` に配置する
- フォルダー名はkebab-case
- 詳細ドキュメントは `references/` に分離する
- テンプレート等は `assets/` に配置する
