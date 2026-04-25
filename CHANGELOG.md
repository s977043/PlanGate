# Changelog

PlanGate の主要リリース履歴。

このファイルは各リリース時点の内容を記録するものであり、この pull request の差分一覧ではない。

## v7.3.1 - 2026-04-26

plugin v0.5.0: setup-team を skill 一覧に追加、broken reference 制約の削除、README バージョン更新。

- `plugin/plangate/README.md` — skill 数 11 → 14、setup-team 追加、既知制約から解消済み broken reference を削除
- `plugin/plangate/.claude-plugin/plugin.json` — v0.4.0 → v0.5.0、description に Setup Team を追記
- `docs/working/TASK-0037/handoff.md` — Rule 5 完了資産を発行

## v7.3.0 - 2026-04-26

モード命名の完全統一、setup-team スキル追加、pg-check × skill-policy-router 連携明示を行ったリリース。

### setup-team スキル追加（TASK-0035）

- `plugin/plangate/skills/setup-team/` — タスク規模・モードに応じたマルチエージェントチーム設計スキルを追加
- `.claude/skills/setup-team/` / `.agents/skills/setup-team/` にも同一ファイルを配置
- `skills/codex-multi-agent/SKILL.md` の broken reference（`../setup-team/SKILL.md`）を解消

### full → high-risk モード命名完全統一（TASK-0036）

- `plugin/plangate/agents/workflow-conductor.md` — 5 箇所置換（フェーズ表、判定ロジック、status.md テンプレート、V-2 記述）
- `plugin/plangate/agents/code-optimizer.md` — frontmatter description + When You Should Be Used
- `plugin/plangate/rules/working-context.md` — V-2 記述・plan.md テンプレート・status.md テンプレート
- `plugin/plangate/commands/ai-dev-workflow.md` — Mode判定テンプレート
- `.claude/` 側の対応ファイル（agents/workflow-conductor.md, agents/code-optimizer.md, agents/README.md, rules/mode-classification.md, rules/working-context.md, commands/ai-dev-workflow.md）も同様に更新

### pg-check × skill-policy-router 連携明示（TASK-0037）

- `plugin/plangate/commands/pg-check.md` — GatePolicy との連携セクションを追加
- `skill-policy-router` が `check` を requiredSkills に含む場合に `/pg-check` が自動要求される旨を明記

## v7.2.0 - 2026-04-26

Epic [#53](https://github.com/s977043/plangate/issues/53)「PlanGate を AI コーディングの開発統制 OS へ拡張する」の Phase 1〜3 を完了したリリース。

### Phase 1: 軽量スキル基盤（#54/#55/#56）

- `skills/intent-classifier/` — User Request を 7 分類（feature / bug / refactor / research / review / docs / ops）
- `skills/skill-policy-router/` — Intent + Mode → GatePolicy（requiredSkills / requiresEvidence / requiresFailingTestFirst / requiresWorktree）
- `skills/evidence-ledger/` — EvidenceLedger スキーマ・証拠記録・Completion Gate 連携
- `rules/evidence-ledger.md` — Completion Gate ブロック条件正本
- `rules/mode-classification.md` — `full` → `high-risk` リネーム + GatePolicy 定義追加
- `/pg-think` / `/pg-hunt` / `/pg-check` / `/pg-verify` コマンド追加

### Phase 2: 強制ゲート基盤（#57）

- `rules/design-gate.md` + `skills/design-gate/` — high-risk 以上で Design Artifact 8 項目必須
- `commands/pg-tdd.md` — Red→Green→Refactor TDD cycle + Evidence Ledger 連携
- `rules/review-gate.md` + `skills/review-gate/` — 6 観点レビュー、critical finding → Completion Gate ブロック
- `rules/completion-gate.md` — 全 Gate 通過を一元管理する 5 条件チェックポイント
- `rules/mode-classification.md` — Gate 適用マトリクス追加

### Phase 3: エージェント統制基盤（#58）

- `skills/context-packager/` — Allowed Context 6 要素を構造化して出力
- `rules/subagent-roles.md` — 6 ロール定義（planner / implementer / reviewer / security-reviewer / test-reviewer / documentation-reviewer）
- `skills/subagent-dispatch/` — 依存関係グラフ生成・並列実行可能タスク特定・dispatch
- `rules/worktree-policy.md` — high-risk: 必須(推奨), critical: 必須(強制)。`requiresWorktree` フラグ接続
- `skills/pr-decision/` — Evidence Ledger + Review Gate + GateStatus から APPROVE / BLOCK / CONDITIONAL 判定

### ドキュメント・その他

- `docs/plangate-v7-hybrid.md` — PlanGate Control OS 理想ワークフロー節を追加
- `plugin.json` — v0.3.0 → v0.4.0

## v7.1.0 - 2026-04-23

README 刷新、GitHub Pages 公開、Claude Code / Codex CLI 共用スキルの整備を行ったリリース。

- README をハーネスエンジニアリング上の位置づけを軸に再構成
- `docs/philosophy.md` を追加し、思想・問題設定・PlanGate の設計解釈を分離
- GitHub Pages 用の `docs/index.md` と `docs/_config.yml` を整備
- MIT `LICENSE` を追加
- `.agents/skills/` に Codex CLI / Claude Code 共用スキルを追加
- GitHub Pages を `main` / `docs` で公開

## v7.0.0 - 2026-04-20

Workflow / Skill / Agent の 3 層で実行層を再構築したハイブリッドアーキテクチャのリリース。

- `docs/plangate-v7-hybrid.md` を追加
- WF-01〜WF-05 の Workflow 定義を追加
- v7 用 Skill / Agent の責務分離を整理
- `design.md` と `handoff.md` を成果物として強化

## v6.0.0 - 2026-04-09

Context Engineering、18 エージェント体制、5 段階モード分類を含むロードマップリリース。

- `docs/plangate-v6-roadmap.md` を追加
- context engineering 統合の方向性を整理
- タスク規模別の実行モード分類を整理

## v5.0.0 - 2026-04-09

L-0 リンター自動修正とハーネスエンジニアリング知見を統合したリリース。

- L-0 リンター自動修正ループを設計
- V-1〜V-4 の検証段階を整理
- ハーネスエンジニアリング観点を PlanGate に統合

## v4.0.0 - 2026-04-09

takt 知見を統合し、実装後検証と C-3 三値ゲートを強化したリリース。

- V-1〜V-4 の検証構造を導入
- C-3 ゲートを APPROVE / CONDITIONAL / REJECT の三値に整理
- マルチエージェント協調の実践知見を反映

## v3.0.0 - 2026-04-09

AI 駆動開発ワークフローの基盤リリース。

- PBI から Plan / ToDo / Test Cases を生成する基本フローを整理
- 計画承認後に Agent 実行へ進むゲート型モデルを定義
- Claude Code を中心とした AI 駆動開発ワークフローを文書化
