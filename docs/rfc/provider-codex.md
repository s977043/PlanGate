# RFC: PlanGate × Codex CLI Provider Integration

| 項目 | 値 |
|------|---|
| **Status** | Implemented (TASK-0089/0109、merged 2026-05-28) |
| **Author** | TASK-0109 / #315 |
| **Created** | 2026-05-28 |
| **Related** | [provider-cursor.md](./provider-cursor.md), [provider-gemini-cli.md](./provider-gemini-cli.md), [provider-opencode.md](./provider-opencode.md) |

## Summary

PlanGate を [Codex CLI](https://github.com/openai/codex) (OpenAI) で完全同等に使うための provider integration。`bin/plangate` の `PLANGATE_IMPL_AGENT=codex` / `PLANGATE_EXTERNAL_REVIEWER=codex` (既定) を Claude Code parity レベルまで配線し、`.codex/hooks.json` で 5 EH hook (EH-1/2/3/6/9) を bridge 経由で強制する。

## Motivation

PlanGate v8.x の標準は Claude Code (`.claude/settings.json` で hook 配線、`.claude/agents/`/`.claude/skills/` で workflow 駆動)。Codex CLI 利用者にも同等の **承認境界 / Hook 強制 / 外部レビュー** を提供する。

## Provider 比較

| 機能 | Claude Code | Codex CLI | Cursor | Gemini CLI |
|------|-------------|-----------|--------|------------|
| native hook 機構 | ✅ `.claude/settings.json` | ✅ `.codex/hooks.json` | ✅ `.cursor/hooks.json` | ❌ |
| 外部レビュー | ✅ (built-in subagent) | ✅ `bin/plangate review --reviewer codex` | (代替) | ✅ `--reviewer gemini` |
| exec | ✅ Claude Code subagent | (代替: `/ai-dev-workflow exec`) | partial | (代替) |
| Hardening Override 適用 | ✅ scripts/hooks/check-plan-hash.sh | ✅ via eh-bridge.sh | ✅ via cursor-adapter.sh | N/A |

## Architecture

```
┌─────────────────────┐
│  Codex CLI session  │
│  (codex exec / e)   │
└──────────┬──────────┘
           │ Edit / Write / apply_patch / Bash
           ↓
┌─────────────────────────────────────────────────┐
│  .codex/hooks.json  (PreToolUse)                │
│   - matcher: "apply_patch|Edit|Write"           │
│     → .codex/hooks/eh-bridge.sh check-plan-exists.sh   (EH-1)│
│     → .codex/hooks/eh-bridge.sh check-c3-approval.sh   (EH-2)│
│     → .codex/hooks/eh-bridge.sh check-plan-hash.sh     (EH-3)│
│     → .codex/hooks/eh-bridge.sh check-forbidden-files.sh (EH-6)│
│   - matcher: "Bash"                             │
│     → .codex/hooks/eh-bridge.sh check-delegation-commit-boundary.sh (EH-9)│
└──────────┬──────────────────────────────────────┘
           │ JSON {tool_input.file_path}
           ↓
┌─────────────────────────────────────────────────┐
│  .codex/hooks/eh-bridge.sh (汎用 bridge)        │
│   - Python で tool_input から file_path 抽出   │
│   - PLANGATE_HOOK_FILE / PLANGATE_HOOK_TASK set │
│   - scripts/hooks/<name>.sh 実行                 │
│   - exit code / stdout JSON を Codex の         │
│     {hookSpecificOutput: {permissionDecision}}  │
│     形式に変換                                   │
└──────────┬──────────────────────────────────────┘
           │ allow / deny / ask
           ↓
┌─────────────────────────────────────────────────┐
│  PlanGate scripts/hooks/*.sh (Claude と共有)    │
│   - check-plan-exists.sh / check-c3-approval.sh  │
│   - check-plan-hash.sh / check-forbidden-files.sh│
│   - check-delegation-commit-boundary.sh         │
└─────────────────────────────────────────────────┘
```

## Implementation Components

### 1. `.codex/hooks.json` (TASK-0089 / PR #347 で merged)

5 hook 配線済:
- PreToolUse matcher `apply_patch|Edit|Write`: EH-1, EH-2, EH-3, EH-6
- PreToolUse matcher `Bash`: EH-9

### 2. `.codex/hooks/eh-bridge.sh` (TASK-0089 / PR #347)

汎用 bridge スクリプト。Claude の `scripts/hooks/cursor-adapter.sh` の Codex 版。

### 3. `.codex/config.toml`

```toml
approval_policy = "on-request"
sandbox_mode = "workspace-write"
project_doc_fallback_filenames = ["AGENTS.md", "CLAUDE.md"]
```

### 4. `scripts/codex-local.sh`

Codex CLI ラッパ (project-local CODEX_HOME 設定 + auth.json symlink 管理)。

### 5. `bin/plangate review --reviewer codex` (TASK-0109 / 本 PBI で実装)

```sh
PLANGATE_EXTERNAL_REVIEWER=codex bin/plangate review TASK-XXXX --phase c2
```

実装 (R-005/R-006/R-007/R-010 反映):

```sh
codex)
  if ! command -v codex >/dev/null 2>&1; then
    printf 'error: codex CLI not found\n' >&2
    return 1
  fi
  codex_tmpfile=$(mktemp)
  trap "rm -f $codex_tmpfile" EXIT
  if ! timeout 600 codex exec --skip-git-repo-check --sandbox read-only \
      --output-last-message "$codex_tmpfile" "$prompt" >&2; then
    printf 'error: codex exec failed or timeout (600s)\n' >&2
    return 1
  fi
  result=$(cat "$codex_tmpfile")
  ;;
```

セキュリティ原則:
- `--sandbox read-only`: review プロセスはファイル改変不可 (R-005 CRITICAL)
- `timeout 600`: hang 防止 (R-006、codex CLI に `--timeout` なし)
- `--output-last-message <tmpfile>`: stdout 解析の脆さ回避 (R-007)
- `command -v codex` check: 未 install 時の error handling (R-010)

## Role Mapping (Codex Agent ↔ PlanGate Role)

| Codex Agent | PlanGate Role | 配置 |
|-------------|---------------|------|
| Codex CLI session | implementation-agent (exec) | (interactive / `codex exec`) |
| `bin/plangate review --reviewer codex` | review-external (C-2/V-3) | CLI 経由 |
| `.codex/agents/*.toml` (TASK-0089) | 各種 subagent (qa-reviewer 等) | `.codex/agents/` |
| `.codex/hooks/eh-bridge.sh` (PreToolUse) | hook strict (承認境界守護) | `.codex/hooks.json` |

詳細: [.codex/README.md](../../.codex/README.md) / [TASK-0089 handoff](../working/TASK-0089/handoff.md)

## Setup (Human オペレーション)

```sh
# 1. Codex CLI install
npm i -g @openai/codex
codex login

# 2. PlanGate project-local 設定 (既に repo に含まれている)
ls .codex/        # config.toml / hooks.json / agents/ / hooks/
sh scripts/codex-local.sh  # 初回は auth symlink 作成

# 3. 使用例
codex exec --skip-git-repo-check "TASK-0109 の plan を生成"
# → .codex/hooks.json 経由で EH-1/2/3/6 強制発火
# → 承認境界違反は block

# 4. 外部 review
PLANGATE_EXTERNAL_REVIEWER=codex bin/plangate review TASK-0109 --phase c2
# → --sandbox read-only で review (改変防止)
```

## Status / Stability

- **Hooks**: ✅ Stable (TASK-0089 / PR #347 merged 2026-05-25)
- **review --reviewer codex**: ✅ Stable (TASK-0109 / 本 PBI merged 2026-05-28)
- **Provider parity**: ✅ Claude Code 同等レベル達成

## Known Limitations

| 制約 | 対処 |
|------|------|
| `codex exec` の長時間応答 | `timeout 600` で wrap (R-006) |
| stdout に思考 / metadata 混在 | `--output-last-message` で clean 出力 (R-007) |
| `--no-verify` 相当の bypass 機構 | Codex CLI は標準で hook bypass 困難 (Claude/Cursor より strict) |
| Cloudshell など `.git` 非存在環境 | `--skip-git-repo-check` で対応 |

## V2 候補

- `bin/plangate exec --agent codex` (現状は `codex exec` 直接で対応、CLI ラッパ化検討)
- 外部 review の concurrent 実行 (Codex + Gemini 並列起動)
- `.codex/agents/` の動的 subagent 選択 (現状静的)

## References

- Codex CLI: <https://github.com/openai/codex>
- Codex hooks spec: <https://developers.openai.com/codex/hooks>
- Claude Code parity: [.claude/settings.json](../../.claude/settings.json) と等価
- Cursor parity: [provider-cursor.md](./provider-cursor.md)
- TASK-0089 (Codex subagent infrastructure): PR #335/#341
- TASK-0109 (本 PBI): #315
- PR #347 (`.codex/hooks` physical bridge)
