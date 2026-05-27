# AGENTS.md

> **実行契約**: [`docs/ai/core-contract.md`](docs/ai/core-contract.md)（Iron Law / Stop rules / Output discipline の正本）
> **プロジェクトルール**: [`docs/ai/project-rules.md`](docs/ai/project-rules.md)（必読、AI 運用 4 原則の正本）
> **再利用可能な学び**: `AGENT_LEARNINGS.md`（一時メモ・進行中検討は書かない）

## 読む順序

1. `docs/ai/project-rules.md`
2. 本ファイル
3. `.codex/instructions.md`

## このリポジトリの性質

- PlanGate のワークフロー / 設定 / 運用ドキュメント管理
- `package.json` なし → 一般的な lint / test / typecheck コマンドは未定義
- 実行入口: `./scripts/ai-dev-workflow` / `./scripts/codex-local.sh` / `bin/plangate`
- **推奨ガード入口**: `scripts/codex-guarded.sh` (PR #343 / #347。session 前後の plan_hash drift 検知と物理 hook bridge を有効化)

## Cursor 固有参照

- 導入手順: [`docs/cursor/quickstart.md`](docs/cursor/quickstart.md)
- RFC: [`docs/rfc/provider-cursor.md`](docs/rfc/provider-cursor.md)
- Hook 配線: `.cursor/hooks.json` → `scripts/hooks/cursor-adapter.sh`
- ルール: `.cursor/rules/plangate.mdc`
- スキル symlink: `.cursor/skills/` → `.agents/skills/`（正本は `.agents/skills/`）

## Codex 固有参照

- 実行設定: `.codex/config.toml` / `.codex/instructions.md` / `.codex/agents/*.toml`
- **Agent Bridge**: `.codex/agents/` の各 agent は Claude Code 側の agent 定義を `instructions` で参照する bridge 構成 (#341)。
- 共有スキル: `.agents/skills/`（Claude Code と共用）
- 役割分担: `docs/ai/tool-roles.md`
- 作業コンテキストプロトコル（Progressive Disclosure）: `.claude/rules/working-context.md`
- ワークフロー: `docs/ai-driven-development.md` / Orchestrator: `docs/orchestrator-mode.md`

## 出力

- 日本語（コミットメッセージ・PR 文面含む）




## Codex CLI 固有参照 (PR #343/#347)

- 正規入口: `scripts/codex-guarded.sh --task TASK-XXXX exec --full-auto`
- 物理 hook: `.codex/hooks.json` + `.codex/hooks/eh-bridge.sh` (EH-1/2/3/6/9 を Codex 側でも発火)
- 強制等価: `docs/ai/settings-wiring-contract.md` §Codex CLI parity


<claude-mem-context>
# Memory Context

# [plangate] recent context, 2026-05-27 11:04am GMT+9

Legend: 🎯session 🔴bugfix 🟣feature 🔄refactor ✅change 🔵discovery ⚖️decision 🚨security_alert 🔐security_note
Format: ID TIME TYPE TITLE
Fetch details: get_observations([IDs]) | Search: mem-search skill

Stats: 12 obs (3,999t read) | 379,925t work | 99% savings

### May 24, 2026
S1704 PlanGate skill review and full CLI alignment — reviewing .codex/runtime-home-v2/skills/ai-dev-plan/SKILL.md and fixing all identified issues across 4 PRs (May 24 at 3:32 PM)
### May 25, 2026
S1705 PlanGate skill review and full CLI alignment — reviewing ai-dev-plan/SKILL.md, fixing all identified issues across 4 PRs, filing remaining PBIs as GitHub Issues (May 25 at 7:00 AM)
S1707 PlanGate skill review and full CLI alignment — all AI-autonomous work complete; two Human-owned patches designed, tested, and ready for application (May 25 at 7:10 AM)
### May 26, 2026
6599 7:35p ⚖️ TASK-0117 外部レビュー: ai-dev-plan skill への事前メトリクス検証 step 追加 (PR #364)
6598 " 🔵 TASK-0111 C-2 評価: exec 着手前の状態確認完了
6600 7:40p 🔵 ai-dev-plan SKILL.md の実在パスは .agents/skills/ — plan.md の参照パスが誤り
6601 " 🔵 TASK-0112 (PR #357 merged): mode-classification.md に「承認境界周辺→最低高」例外ルール追加済
6602 " 🔵 PlanGate skill 配置アーキテクチャ: .claude/skills/ vs .agents/skills/ の責務境界
### May 27, 2026
6621 6:50a ⚖️ TASK-0117 PR #364 C-2 Final Approval: APPROVE after R-001..R-005 All Reflected
6626 " ⚖️ TASK-0111 T-01 PR #366 Wording Fix Review Gate
6622 " 🔵 TASK-0117 Deliverables Not Yet Created — Only SKILL.md Exists on Wrong Branch
6623 6:51a 🔵 PR #364 MERGED — Contains Only Planning Docs; SKILL.md Pre-dates TASK-0117 Exec
6624 " 🔵 TASK-0117 plan.md Header/Body Mode Inconsistency: `light` vs `standard`
6625 6:52a 🔵 TASK-0117 INDEX.md and current-state.md Contain Pre-R-002 Stale Values on Merged Branch
6627 6:53a 🔴 PR #366 MERGED: TASK-0111 T-01 Evidence Wording Fix

Access 380k tokens of past work via get_observations([IDs]) or mem-search skill.
</claude-mem-context>