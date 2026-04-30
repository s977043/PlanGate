# Project-Scoped Skills

このディレクトリは、Claude Code / Codex CLI 共用の repo-owned skill の正本。

## ワークフロー運用スキル（Codex CLI 専用）

| スキル | 役割 |
|--------|------|
| `ai-dev-brainstorm` | アイデアや曖昧な要件を `pbi-input.md` に整理する |
| `ai-dev-plan` | PBI INPUT PACKAGE から `plan.md` `todo.md` `test-cases.md` を作る |
| `plan-review-gate` | C-1 / C-2 / C-3 の判定と exec 可否を確認する |
| `manual-cloud-task` | tracked handoff packet を使って手動 Cloud task を起動する |
| `working-context` | ローカル ticket コンテキストと Cloud handoff packet の橋渡し |

Codex CLI の標準入口は `./scripts/ai-dev-workflow TASK-XXXX brainstorm|plan|gate|prepare-cloud|exec|status|sync-cloud`。

## v7 ハイブリッドアーキテクチャ対応スキル（Claude Code / Codex CLI 共用）

WF-01〜WF-05 の各 phase で呼び出す再利用可能スキル。

| カテゴリ | スキル | 役割 |
|---------|--------|------|
| Scan | `context-load` | 前提・制約・品質基準を抽出し context artifact にサマライズ |
| Scan | `requirement-gap-scan` | 要件の抜け漏れ・矛盾・曖昧さを検出 |
| Check | `nonfunctional-check` | 非機能要件（性能・セキュリティ・可用性）を確認 |
| Check | `edgecase-enumeration` | エッジケースを網羅的に列挙 |
| Check | `risk-assessment` | 実装リスクを評価し対策を提示 |
| Design | `acceptance-criteria-build` | 受け入れ条件（AC）を GIVEN/WHEN/THEN 形式で構造化 |
| Design | `architecture-sketch` | モジュール境界・データフロー・依存関係を設計 |
| Build | `feature-implement` | design artifact に従って最小単位で実装・テスト・自己レビュー |
| Review | `acceptance-review` | 実装結果を AC と照合し適合/不足を明確化 |
| Review | `known-issues-log` | 既知課題・技術的負債・V2 候補を構造化して記録 |

## 汎用スキル（Claude Code / Codex CLI 共用）

| スキル | 役割 |
|--------|------|
| `brainstorming` | アイデアから設計書（PBI INPUT PACKAGE）への昇華 |
| `self-review` | 変更内容の17項目体系的セルフレビュー |
| `systematic-debugging` | エビデンスベースの体系的デバッグ |
| `subagent-driven-development` | サブエージェント駆動の2段階レビュー開発 |
| `codex-multi-agent` | Codex CLI を用いたマルチエージェント並列実行 |

## Skill 運用スキル（Claude Code / Codex CLI 共用）

| スキル | 役割 |
|--------|------|
| `skill-creator` | 新しいスキルを対話的に設計・生成 |
| `skill-ops-planner` | スキルポートフォリオの運用計画・ロードマップ作成 |
| `skill-optimizer` | 既存スキルの評価・改善 |
| `setup-team` | タスク規模・モードに応じた最適チーム設計とエージェント委譲準備 |
