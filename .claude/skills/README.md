# カスタムスキル一覧

PlanGate ワークフロー v5 / v6 / **v7** で使用するスキル群。

## スキル

| スキル | 説明 | カテゴリ |
| ------ | ---- | -------- |
| `skill-creator` | 新しいClaude Codeスキルを対話的に設計・生成するワークフロー | developer-tools |
| `skill-optimizer` | 既存スキルの評価・改善（成功基準ベースの小さな変更） | developer-tools |
| `skill-ops-planner` | スキルポートフォリオの運用計画・ロードマップ作成 | developer-tools |
| `brainstorming` | アイデアや要件を対話的に設計書（PBI INPUT PACKAGE）へ昇華 | workflow |
| `self-review` | 変更内容に対する詳細セルフレビュー（17項目チェック） | review |
| `systematic-debugging` | バグや障害の体系的調査・根本原因特定 | debugging |
| `subagent-driven-development` | 実装タスクのサブエージェント委譲・品質管理 | workflow |
| `codex-multi-agent` | マルチエージェントでタスク分解・委譲・並列実行・結果統合 | workflow |
| `setup-team` | タスク規模・モードに応じた最適チーム設計とエージェント委譲準備 | workflow |

## v7 ハイブリッドアーキテクチャ用 Skill（10 個）

v7（`docs/plangate-v7-hybrid.md`）で追加された **再利用可能 Skill**。Rule 2 準拠（再利用単位限定、案件固有情報なし）。

| スキル | カテゴリ | 想定 Phase | 役割 |
|--------|---------|-----------|------|
| `context-load` | Scan | WF-01 | CLAUDE.md と依頼文から前提を抽出 |
| `requirement-gap-scan` | Scan | WF-02 | 要件の抜け漏れ検出 |
| `nonfunctional-check` | Check | WF-02 | 性能・保守性・安全性の確認 |
| `edgecase-enumeration` | Check | WF-02 | 境界条件・例外条件の列挙 |
| `risk-assessment` | Check | WF-02 / WF-03 | 制約・未確定要素の洗い出し |
| `acceptance-criteria-build` | Design | WF-02 | 受け入れ条件の明文化 |
| `architecture-sketch` | Design | WF-03 | 構成案の叩き台作成 |
| `feature-implement` | Build | WF-04 | 個別機能の実装 |
| `acceptance-review` | Review | WF-05 | 要件適合レビュー |
| `known-issues-log` | Review | WF-05 | 妥協点・既知不具合の文書化 |

マッピング: [docs/workflows/skill-mapping.md](../../docs/workflows/skill-mapping.md)

## 配置ルール

- スキルは `.claude/skills/<skill-name>/SKILL.md` に配置する
- フォルダー名はkebab-case
- 詳細ドキュメントは `references/` に分離する
- テンプレート等は `assets/` に配置する
