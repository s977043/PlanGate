# Codex Settings

Codex 固有の設定はこのディレクトリに集約する。

## 起動方法

このリポジトリの設定を使うには、`./scripts/codex-local.sh ...` を使う。ラッパーが repo 内の runtime home を使い、`.codex/` の設定と `~/.codex` の認証を合成して起動する。

```bash
./scripts/codex-local.sh exec --json "確認のみ。1行で返答。"
```

## Files

- `config.toml` - Codex CLI の実行設定
- `instructions.md` - Codex 向けの読み込みガイド
- `agents/*.toml` - Codex 用 custom subagents
- `manual-cloud-task.md` - 手動 Cloud task 用の tracked handoff packet

## Auth

- Codex CLI の認証は `~/.codex/auth.json` または `OPENAI_API_KEY` 系の環境変数を使う
- repo 内の `.codex/` には認証情報をコミットしない

## AI-Dev Workflow

- `./scripts/ai-dev-workflow STRATEGY-XXXX brainstorm` - PBI INPUT PACKAGE を対話的に整える
- `./scripts/ai-dev-workflow STRATEGY-XXXX plan` - plan / todo / test-cases / self-review / external-review / handoff draft を半自動生成
- `./scripts/ai-dev-workflow STRATEGY-XXXX gate` - C-1 / C-2 / C-3 の gate を確認する
- `./scripts/ai-dev-workflow STRATEGY-XXXX prepare-cloud` - Cloud task 用 packet をローカル ticket 情報から再生成
- `./scripts/ai-dev-workflow STRATEGY-XXXX exec` - workflow_conductor 前提で exec を進める
- `./scripts/ai-dev-workflow STRATEGY-XXXX status` - 現在フェーズと次アクションを要約する
- `./scripts/ai-dev-workflow STRATEGY-XXXX sync-cloud` - Cloud task の結果を local status/todo に同期

## Claude Code / Codex 対比

| Claude Code | Codex |
|---|---|
| `/ai-dev-workflow STRATEGY-XXXX brainstorm` | `./scripts/ai-dev-workflow STRATEGY-XXXX brainstorm` |
| `/ai-dev-workflow STRATEGY-XXXX plan` | `./scripts/ai-dev-workflow STRATEGY-XXXX plan` |
| `/ai-dev-workflow STRATEGY-XXXX exec` | `./scripts/ai-dev-workflow STRATEGY-XXXX exec` |
| `/ai-dev-workflow STRATEGY-XXXX status` | `./scripts/ai-dev-workflow STRATEGY-XXXX status` |

Codex only:

- `./scripts/ai-dev-workflow STRATEGY-XXXX gate`
- `./scripts/ai-dev-workflow STRATEGY-XXXX prepare-cloud`
- `./scripts/ai-dev-workflow STRATEGY-XXXX sync-cloud`

## Project-Scoped Skills

Codex Cloud / Codex CLI で使う repo-owned skill の正本は `.agents/skills/` に置く。

- `ai-dev-brainstorm` - アイデアや要件を `pbi-input.md` に整理する
- `ai-dev-plan` - PBI INPUT PACKAGE から plan / todo / test-cases を生成する
- `plan-review-gate` - C-1 / C-2 / C-3 の判定と exec 可否を確認する
- `manual-cloud-task` - tracked handoff packet を使って Codex Cloud の手動 task 実行フローを組み立てる
- `working-context` - ローカル ticket コンテキストの更新ルール

## Claude Code Skills（共有）

以下は `.claude/skills/` に正本があり、Codex からも参照可能なスキル。

- `self-review` - `.claude/skills/self-review/SKILL.md`
- `brainstorming` - `.claude/skills/brainstorming/SKILL.md`
- `systematic-debugging` - `.claude/skills/systematic-debugging/SKILL.md`
- `subagent-driven-development` - `.claude/skills/subagent-driven-development/SKILL.md`
- `skill-creator` - `.claude/skills/skill-creator/SKILL.md`
- `codex-multi-agent` - `.claude/skills/codex-multi-agent/SKILL.md`

## Cloud Handoff

- `manual-cloud-task.md` は、Cloud task に渡す tracked handoff packet の正本
- `manual-cloud-task.md` は `./scripts/ai-dev-workflow STRATEGY-XXXX prepare-cloud` で再生成できる

## Agents

- `claude_code_reviewer` - Claude Code CLI に PR レビューを委譲する bridge agent

## Review Bridge

Codex から Claude Code に PR レビューを委譲したい場合は、`claude_code_reviewer` を使うか、直接 `scripts/codex-claude-review.sh <PR番号>` を実行する。

```bash
./scripts/codex-claude-review.sh 1356
```

注意:

- `claude` CLI と `gh` CLI が利用可能であること
- Codex サンドボックス内では API 接続制約により失敗する場合がある

## Sandbox / Delegation Policy

- `project_planner` は `read-only` を使う。役割が情報収集と計画整理に限定され、書き込みを前提にしないため
- `workflow_conductor` / `orchestrator` / specialist 群は `workspace-write` を使う。成果物生成、handoff 更新、実装反映を担うため
- `max_depth = 1` は意図的な制限。conductor / orchestrator が specialist に1段だけ委譲し、specialist から再帰的に多段委譲させない
- この制限で、責務分離は維持しつつ、委譲の追跡不能化と無制限 fan-out を避ける

## System Skills

- `.codex/skills/.system/` は OpenAI 提供の system / vendor skill 置き場
- repo 固有 skill の正本には使わない
- Codex から `.claude/skills/` は参照しない。必要なものは `.agents/skills/` に移す
- Claude Code 側の既存スキル一覧は `.claude/skills/README.md` を参照する
