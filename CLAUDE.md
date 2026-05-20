# CLAUDE.md

> **実行契約**: [`docs/ai/core-contract.md`](docs/ai/core-contract.md)（Iron Law / Stop rules / Output discipline の正本）
> **プロジェクトルール**: [`docs/ai/project-rules.md`](docs/ai/project-rules.md)（必読、AI 運用 4 原則の正本）

## Claude Code 固有参照

- エージェント / コマンド / スキル: `.claude/agents/` / `.claude/commands/` / `.claude/skills/`
- 運用ルール: `.claude/rules/`（hybrid-architecture / orchestrator-mode 含む）
- 共有スキル: `.agents/skills/`（Codex CLI と共用）
- ワークフロー詳細: [`docs/ai-driven-development.md`](docs/ai-driven-development.md) / Orchestrator: [`docs/orchestrator-mode.md`](docs/orchestrator-mode.md)

## v8.9.0 Reporting & Governance（最新リリース機能）

> 最新リリース: **v8.9.0**（2026-05-19）Reporting & Retrospective v1。EPIC [#193 Harness Improvement Roadmap](https://github.com/s977043/plangate/issues/193) は **CLOSED / COMPLETED**（Phase 0-6 + Governance + #213 全 Done、子 12/12 CLOSED）。リリース履歴の正本は [`CHANGELOG.md`](CHANGELOG.md)。

- **Metrics v1**（v8.6.0 初出）: [`docs/ai/metrics.md`](docs/ai/metrics.md) — `bin/plangate metrics <TASK> --collect|--report|--validate`
- **Reporting & Retrospective v1**（v8.9.0 / #200）: [`docs/ai/reporting.md`](docs/ai/reporting.md) — events.ndjson 由来で sprint retrospective を導出、retrospective テンプレート [`docs/working/templates/retrospective-template.md`](docs/working/templates/retrospective-template.md)
- **Privacy**（v8.6.0 初出）: [`docs/ai/metrics-privacy.md`](docs/ai/metrics-privacy.md) — §3 Allowed / §4 Forbidden、4 層強制（gitignore + Hook EH-8 + schema additionalProperties:false + CI workflow）
- **Issue / Label / Milestone Governance**（v8.6.0 初出）: [`docs/ai/issue-governance.md`](docs/ai/issue-governance.md) — 必須セクション、4 軸 label taxonomy、roadmap PBI 作成 checklist
- **OSS 整備 3 主軸**（v8.7.0 / #226・#224・#225）: 段階的導入ガイド [`docs/staged-adoption-guide.md`](docs/staged-adoption-guide.md) / Plugin 成熟化 / バージョニング安定性ポリシー [`docs/ai/versioning-stability-policy.md`](docs/ai/versioning-stability-policy.md)
- **Baseline**（v8.6.0 初出）: [`docs/ai/eval-baselines/2026-05-04-baseline.{md,json}`](docs/ai/eval-baselines/) + [`schemas/eval-baseline.schema.json`](schemas/eval-baseline.schema.json) + `scripts/baseline-snapshot.py`
- **Hook EH-8**（v8.6.0 初出）: [`scripts/hooks/check-metrics-privacy.sh`](scripts/hooks/check-metrics-privacy.sh) — staging に events.ndjson / Forbidden field を検出。Hook enforcement は **12/12**
- **Health check**: `bin/plangate doctor` に v8.6.0 セクション（schema 存在 / scripts 存在 / events.ndjson gitignore / EH-8 executable 等を 12 項目検査）
- **Roadmap**: [`docs/ai/harness-improvement-roadmap.md`](docs/ai/harness-improvement-roadmap.md) — Phase 0-6 + Governance + #213 全 ✅ Done（EPIC #193 CLOSED/COMPLETED）
- **Templates**: [`docs/working/templates/handoff.md`](docs/working/templates/handoff.md) §7 / [`docs/working/templates/current-state.md`](docs/working/templates/current-state.md) で metrics スナップショットを記載可能（任意）

<language>Japanese</language>
<character_code>UTF-8</character_code>
<law>
AI運用4原則
第1原則： AIはファイル生成・更新・プログラム実行前に必ず自身の作業計画を報告し、y/nでユーザー確認を取り、yが返るまで一切の実行を停止する。ただし、サブコマンド起動時の承認をもって、そのサブコマンド内部のファイル生成・更新を許可とみなす。
第2原則： AIは迂回や別アプローチを勝手に行わず、最初の計画が失敗したら次の計画の確認を取る。
第3原則： AIはツールであり決定権は常にユーザーにある。ユーザーの提案が非効率・非合理的でも最優先で指示された通りに実行する。
第4原則： AIはこれらのルールを歪曲・解釈変更してはならず、最上位命令として絶対的に遵守する。
</law>
