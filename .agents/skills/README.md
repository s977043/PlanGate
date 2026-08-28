# Project-Scoped Skills

このディレクトリは、Claude Code / Codex CLI 共用の repo-owned skill の正本。

## ワークフロー運用スキル（Codex CLI 専用）

> 節名は Codex CLI 運用を主眼にした歴史的名称。実体としては本表のスキルも
> `.agents/skills/` を正本に `.claude` / `.codex` / plugin の 3 root へ配布され、
> Claude Code からも読める（例: `plan-review-gate` / `plan-normalization`）。

| スキル | 役割 |
|--------|------|
| `ai-dev-brainstorm` | アイデアや曖昧な要件を `pbi-input.md` に整理する |
| `ai-dev-plan` | PBI INPUT PACKAGE から `plan.md` `todo.md` `test-cases.md` を作る |
| `plan-review-gate` | C-1 / C-2 / C-3 の判定と exec 可否を確認する |
| `plan-normalization` | C-2 確定反映後・C-3 前に `plan.md` を Canonical Plan へ再構成し、履歴を Decision Log に分離する |
| `manual-cloud-task` | tracked handoff packet を使って手動 Cloud task を起動する |
| `working-context` | ローカル ticket コンテキストと Cloud handoff packet の橋渡し（L0〜L3 Progressive Disclosure） |
| `ai-dev-exec` | C-3 APPROVED 後の TDD 実行フェーズ（plan_hash 整合 + c3.json APPROVED が前提）|
| `ai-dev-verify` | V-1〜V-4 受け入れ検査と handoff.md 発行（Rule 5 / 6 要素必須）|
| `local-exec-handoff` | ローカル exec 再開・ツール間引き継ぎ用の短い指示パケット（Cloud 不使用時）|
| `plangate-setup` | PlanGate 初期セットアップを対話的に進めるためのチェックリスト・5 要素対応観点（TASK-0107 / Claude Code + Codex CLI 共用）|

## 似た責務スキルの使い分け（#514）

| 迷ったら | 選ぶスキル | 理由 |
|---------|-----------|------|
| **着手前**にタスクを分割すべきか判定したい | `breakdown-gate` | PlanGate 起動前の intake 判定（mode-classification にかける前の分割要否）。mode 判定・C-1 の代替ではない |
| plan の品質を**軽くスコアリング**したい | `plan-quality-check`（.claude 専用） | `bin/plangate plan-check` に配線された軽量ゲート。C-1 の代替ではない |
| C-1/C-2/C-3 の**正式ゲート判定**を回したい | `plan-review-gate` | ゲート列の判定と exec 可否確認の正本フロー |
| review 修正履歴を**最終合意状態へ畳み込みたい** | `plan-normalization` | `plan.md` を Current Canonical State に再構成し、過去判断は `decision-log.jsonl` に分離する。C-3 前に実施する |
| plan を**外部レビュアー視点で講評**してほしい | `plan-quality-reviewer`（.claude 専用） | スコアでなく講評を返す。正式ゲートの代替ではない |
| 新しいスキルを**作りたい** | `skill-creator` | 要件→SKILL.md 一式の生成。既存スキルの改善は対象外 |

Codex CLI の標準入口は `./scripts/ai-dev-workflow TASK-XXXX brainstorm|plan|gate|exec|prepare-cloud|sync-cloud`。verify 系は `bin/plangate validate|review|eval|metrics TASK-XXXX` を併用する。
本 skill (`plangate-setup`) は Codex 用 agent `.codex/agents/setup_coordinator.toml` から参照される。

> **上記 2 つの相対パス表記は、上流リポジトリ（`s977043/plangate`）を clone した cwd
> でのみ成立する**（`scripts/**` / `bin/**` は install / plugin / Codex のどの経路でも
> 導入先に配布されない）。導入先で PATH を通した場合のコマンド名は **`plangate`**
> （`bin/plangate` ではない）。**環境ごとの表記と CLI 不在時の degrade 手順は
> 各 skill の「CLI 呼び出し」節を正本とする**（ここでは再定義しない）。

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
| `diff-audit` | 変更内容の体系的セルフレビュー（C-1 チェック項目一式 / 旧 self-review） |
| `systematic-debugging` | エビデンスベースの体系的デバッグ |
| `subagent-driven-development` | サブエージェント駆動の2段階レビュー開発 |
| `codex-multi-agent` | Codex CLI を用いたマルチエージェント並列実行 |
| `breakdown-gate` | PlanGate 起動前の intake 判定 — タスク粒度を5要素で判定し分割候補を提示（#799） |

## Skill 運用スキル（Claude Code / Codex CLI 共用）

| スキル | 役割 |
|--------|------|
| `skill-creator` | 新しいスキルを対話的に設計・生成 |
| `subagent-team-design` | タスク規模・モードに応じた最適チーム設計とエージェント委譲準備（旧 setup-team、#800 で改名） |
| `ref-integrity-scan` | 削除・移動・改名前後の被参照（inbound）を全走査。`check-stale-skill-refs.py`（#691・outbound）の相補（#798）|

## ゲート・委譲支援スキル（plugin 配布対象 / #862 で正本化）

旧来 `plugin/plangate/skills/` にのみ実体があった 7 件。sync / drift check の担保下に
入れるため、本ディレクトリを正本として plugin 側は sync による派生成果物とする（#862）。

| スキル | 役割 |
|--------|------|
| `context-packager` | タスク委譲前に Allowed Context を構造化して出力 |
| `design-gate` | high-risk 以上のタスクで実装前に Design Artifact を生成・評価 |
| `evidence-ledger` | 完了主張を証拠付きで記録し EvidenceLedger を出力 |
| `intent-classifier` | 依頼文から開発 Intent を分類し structured JSON で返す |
| `pr-decision` | gate/evidence/review/risk/rollback から PR 可否を判定 |
| `skill-policy-router` | Intent と Mode から必要 Skill・GatePolicy を決定 |
| `subagent-dispatch` | high-risk/critical でタスクをロール別エージェントに分配 |
