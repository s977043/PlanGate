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

# [plangate] recent context, 2026-05-26 5:20am GMT+9

Legend: 🎯session 🔴bugfix 🟣feature 🔄refactor ✅change 🔵discovery ⚖️decision 🚨security_alert 🔐security_note
Format: ID TIME TYPE TITLE
Fetch details: get_observations([IDs]) | Search: mem-search skill

Stats: 12 obs (4,335t read) | 410,476t work | 99% savings

### May 24, 2026
S1704 PlanGate skill review and full CLI alignment — reviewing .codex/runtime-home-v2/skills/ai-dev-plan/SKILL.md and fixing all identified issues across 4 PRs (May 24 at 3:32 PM)
### May 25, 2026
S1705 PlanGate skill review and full CLI alignment — reviewing ai-dev-plan/SKILL.md, fixing all identified issues across 4 PRs, filing remaining PBIs as GitHub Issues (May 25 at 7:00 AM)
S1707 PlanGate skill review and full CLI alignment — all AI-autonomous work complete; two Human-owned patches designed, tested, and ready for application (May 25 at 7:10 AM)
6233 9:00a 🔵 PlanGate PR #325/#327/#330 Documentation Verification (Read-Only Audit)
6234 " 🔵 PlanGate Doc Verification: Most Target Files Unreadable or Empty
6236 9:01a 🔵 PlanGate PR #325/#327/#330 Doc Audit: Concrete Findings Per Checklist Item
6237 9:02a 🔵 PlanGate Doc Audit: Definitive Findings — New Skills Unregistered, Env Vars Undocumented, B-1→B-3 Flow Gap
6276 11:04a ⚖️ PlanGate Codex Parity Gap #336 — 設計調査タスク発行
6277 " 🔵 PlanGate hook 配線の実体確認 — .claude/settings.json 全構造
6278 " 🔵 Codex CLI の sandbox_mode と forbidden_files 相当制御の確認結果
6279 " 🔵 PlanGate リポジトリ構成 — .claude/.codex/.agents 三層アーキテクチャの確認
6286 11:05a ⚖️ TASK-0111: pages/ → docs/pages/ 移設設計レビュー (C-2 外部レビュー)
6280 " 🔵 hook スクリプト全体構造と Codex parity gap の技術的詳細
6281 11:06a 🔵 bin/plangate exec の Codex 経路は情報表示のみ — 実行ゲートなし
6287 11:11a 🔵 TASK-0111 C-2レビュー用リポジトリ現状調査結果

Access 410k tokens of past work via get_observations([IDs]) or mem-search skill.
</claude-mem-context>