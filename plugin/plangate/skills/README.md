# Project-Scoped Skills

このディレクトリは、Claude Code / Codex CLI 共用の repo-owned skill の正本。

## ワークフロー運用スキル（Codex CLI 専用）

| スキル | 役割 |
|--------|------|
| `ai-dev-brainstorm` | アイデアや曖昧な要件を `pbi-input.md` に整理する |
| `ai-dev-plan` | PBI INPUT PACKAGE から `plan.md` `todo.md` `test-cases.md` を作る |
| `plan-review-gate` | C-1 / C-2 / C-3 の判定と exec 可否を確認する |
| `manual-cloud-task` | tracked handoff packet を使って手動 Cloud task を起動する |
| `working-context` | ローカル ticket コンテキストと Cloud handoff packet の橋渡し（L0〜L3 Progressive Disclosure） |
| `ai-dev-exec` | C-3 APPROVED 後の TDD 実行フェーズ（plan_hash 整合 + c3.json APPROVED が前提）|
| `ai-dev-verify` | V-1〜V-4 受け入れ検査と handoff.md 発行（Rule 5 / 6 要素必須）|
| `local-exec-handoff` | ローカル exec 再開・ツール間引き継ぎ用の短い指示パケット（Cloud 不使用時）|
| `plangate-setup` | PlanGate 初期セットアップを対話的に進めるためのチェックリスト・5 要素対応観点（TASK-0107 / Claude Code + Codex CLI 共用）|

Codex CLI の標準入口は `./scripts/ai-dev-workflow TASK-XXXX brainstorm|plan|gate|exec|prepare-cloud|sync-cloud`。verify 系は `bin/plangate validate|review|eval|metrics TASK-XXXX` を併用する。
本 skill (`plangate-setup`) は Codex 用 agent `.codex/agents/setup_coordinator.toml` から参照される。

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
| `setup-team` | タスク規模・モードに応じた最適チーム設計とエージェント委譲準備 |

## plugin 限定スキルの status（#514）

以下 8 スキルは `.agents/skills/`（共有 SSoT）に存在せず **plugin 配布専用**。
v7 統制層（TASK-0029 / TASK-0033）で plugin に直接追加され、導入先リポジトリで
Intent/Mode 分類・4 Gate・エージェント統制を動かすための製品面コンポーネント:

| スキル | 役割 | status |
|--------|------|--------|
| `intent-classifier` | 依頼の意図分類（mode 判定の前段） | plugin 専用・現役 |
| `skill-policy-router` | mode に応じた skill 選択ルーティング | plugin 専用・現役 |
| `design-gate` / `review-gate` | 設計/レビューゲートの実行枠 | plugin 専用・現役 |
| `context-packager` | サブエージェントへの文脈パッケージング | plugin 専用・現役 |
| `subagent-dispatch` | サブエージェント委譲の定型化 | plugin 専用・現役 |
| `evidence-ledger` | レビュー根拠の台帳化 | plugin 専用・現役 |
| `pr-decision` | PR 作成可否の判定 | plugin 専用・現役 |

本リポジトリ自身の運用では同等機能を rules / workflow / bin/plangate が担うため
`.agents/skills` には置かない（共有 SSoT へ昇格する場合は #514 の後続判断）。
