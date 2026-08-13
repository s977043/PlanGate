# TASK-1078 P0-2 測定スパイク: Codex CLI が hook へ渡す実 payload

- 実施日: 2026-08-13
- ブランチ: `spike/1078-codex-payload`（base = `origin/main` @ `304518bb`）
- 対象: codex-cli **0.144.1**（実体 = `/opt/homebrew/lib/node_modules/@openai/codex/node_modules/@openai/codex-darwin-arm64/vendor/aarch64-apple-darwin/bin/codex`, Mach-O arm64）
- 結論: **payload 形状は確定した。ただし「稼働中の Codex セッションからの実観測」ではなく、CLI バイナリに埋め込まれた JSON Schema（正本の wire contract）+ 公式仕様 の一致による確定である。**

## 取得経路の内訳

| 経路 | 結果 |
|---|---|
| A-1 公式仕様 | ✅ 取得。`https://developers.openai.com/codex/hooks` は **308 → `https://learn.chatgpt.com/docs/hooks`**。イベント一覧・共通フィールド・PreToolUse スキーマ・応答解釈を確認 |
| A-2 サンドボックス実走 | ❌ **未実施（停止条件 SC-2 に該当）**。`codex exec` はモデル API 呼び出しを必然的に伴う（課金 / 外部通信）ため、指示どおり実行せず停止 |
| A-3 bridge のログ経路 | ❌ 不発。`.codex/hooks/eh-bridge.sh` に `log` / `audit` / `tee` は **0 件**。一時ファイル `/tmp/eh-bridge-out.$$` は同一実行内で `rm -f` される（永続ログなし）。`docs/working/_audit/` にも hook payload なし |
| A-4 logs sqlite | ❌ 不発（ただし別の意味で有用）。リポジトリ直下に `logs_2.sqlite` は **存在しない**。実体は `~/.codex/logs_2.sqlite`（100MB）。`logs` テーブルを読み取り専用コピーで検索したところ hook 関連 4 行はすべて **過去の AI が手で組んだ合成 payload**（`jq -n '{hook_event_name:"PreToolUse",...}'`）であり、**Codex 本体が生成した実 payload は 1 件も記録されていない** |
| A-5（追加）バイナリ埋め込み Schema | ✅ **本スパイクの決め手**。0.144.1 バイナリに hook I/O の draft-07 JSON Schema が pretty-print されたまま埋め込まれている（`pre-tool-use.command.input` 等 10 イベント分） |

> 先行調査の `codex debug prompt-input` 失敗は再現確認していない。`codex debug` のサブコマンドは `models` / `app-server` / `prompt-input` のみで、hook payload を吐く経路は存在しない。

## 実測 payload スキーマ（PreToolUse / 入力）

バイナリ内の埋め込み Schema を verbatim 引用（title: `pre-tool-use.command.input`）:

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "additionalProperties": false,
  "definitions": { "NullableString": { "type": ["string", "null"] } },
  "properties": {
    "agent_id":        { "type": "string" },
    "agent_type":      { "type": "string" },
    "cwd":             { "type": "string" },
    "hook_event_name": { "const": "PreToolUse", "type": "string" },
    "model":           { "type": "string" },
    "permission_mode": { "enum": ["default","acceptEdits","plan","dontAsk","bypassPermissions"], "type": "string" },
    "session_id":      { "type": "string" },
    "tool_input":      true,
    "tool_name":       { "type": "string" },
    "tool_use_id":     { "type": "string" },
    "transcript_path": { "$ref": "#/definitions/NullableString" },
    "turn_id":         { "description": "Codex extension: expose the active turn id to internal turn-scoped hooks.", "type": "string" }
  },
  "required": [
    "cwd","hook_event_name","model","permission_mode","session_id",
    "tool_input","tool_name","tool_use_id","transcript_path","turn_id"
  ],
  "title": "pre-tool-use.command.input",
  "type": "object"
}
```

## 実測 payload スキーマ（PreToolUse / 出力）

title: `pre-tool-use.command.output`:

```json
{
  "definitions": {
    "PreToolUseDecisionWire": { "enum": ["approve", "block"], "type": "string" },
    "PreToolUsePermissionDecisionWire": { "enum": ["allow", "deny", "ask"], "type": "string" },
    "PreToolUseHookSpecificOutputWire": {
      "additionalProperties": false,
      "properties": {
        "additionalContext":        { "default": null, "type": "string" },
        "hookEventName":            { "const": "PreToolUse", "type": "string" },
        "permissionDecision":       { "$ref": "#/definitions/PreToolUsePermissionDecisionWire", "default": null },
        "permissionDecisionReason": { "default": null, "type": "string" },
        "updatedInput":             { "default": null }
      },
      "required": ["hookEventName"]
    }
  },
  "properties": {
    "continue":          { "default": true,  "type": "boolean" },
    "decision":          { "$ref": "#/definitions/PreToolUseDecisionWire", "default": null },
    "hookSpecificOutput":{ "$ref": "#/definitions/PreToolUseHookSpecificOutputWire", "default": null },
    "reason":            { "default": null, "type": "string" },
    "stopReason":        { "default": null, "type": "string" },
    "suppressOutput":    { "default": false, "type": "boolean" },
    "systemMessage":     { "default": null, "type": "string" }
  },
  "title": "pre-tool-use.command.output"
}
```

同バイナリに埋め込まれた **実行時バリデーションのエラーメッセージ群**（verbatim）:

```text
PreToolUse hook returned unsupported continue:false
PreToolUse hook returned unsupported stopReason
PreToolUse hook returned unsupported suppressOutput
PreToolUse hook returned unsupported decision:approve
PreToolUse hook returned unsupported permissionDecision:ask
PreToolUse hook returned unsupported permissionDecision:allow
PreToolUse hook returned permissionDecision:deny without a non-empty permissionDecisionReason
PreToolUse hook returned permissionDecisionReason without permissionDecision
PreToolUse hook returned updatedInput without permissionDecision:allow
PreToolUse hook returned reason without decision
```

→ Schema 上は `allow|deny|ask` を許すが、**0.144.1 の実行時は「素の `permissionDecision:"allow"`」と `"ask"` を "unsupported" として弾く分岐を持つ**（`allow` は `updatedInput` 同伴時のみ意味を持つ読み）。また **`deny` は非空の `permissionDecisionReason` が必須**。

## 「特に取りたい情報」1〜5 の結果

| # | 知りたいこと | 結果 |
|---|---|---|
| 1 | `hook_event_name` フィールドの有無と値 | **存在する。`required`。PreToolUse では `const: "PreToolUse"`。** EH-13 の `== "PreToolUse"` 判定は成立する |
| 2 | `tool_name` の実値（apply_patch 時） | **`apply_patch`**。公式仕様の列挙は `Bash` / `apply_patch` / MCP ツール（`mcp__*`）/ ローカル関数ツール（`update_plan`, `spawn_agent`）。バイナリの `ToolCallKind` は `exec_command / write_stdin / apply_patch / web / spawn_agent / assign_agent_task / send_message / wait_agent / close_agent`。シェル実行の hook 側 tool_name は **`Bash`**（`codex_core` に単独文字列として存在）。**`Edit` / `Write` / `MultiEdit` は Codex に存在しない** |
| 3 | `tool_input.command` / `tool_input.file_path` は Claude と同名か | **`tool_input` は schema 上 `true`（任意の JSON）＝ツール依存。Codex 側にフィールド名の契約はない。** `Bash` は `command` を持つ（`command` / `cwd` / `env` の文字列が exec 経路に存在）。`apply_patch` は Claude の `file_path` 相当を**持たない**（パッチ本文中の `*** Update File:` を掘る必要があり、これが `eh-bridge.sh` の python 抽出が存在する理由）。**`file_path` が来る保証はない** |
| 4 | stdin か引数 / env か | **stdin。** schema title が `*.command.input` / `*.command.output` であり、`CODEX_HOOK_*` 系の env 変数はバイナリ内に **1 件も存在しない**（`CODEX_` 前置の全 env 名を列挙して確認）。公式仕様も「Every hook receives JSON on stdin」と明記 |
| 5 | 戻り値の解釈（permissionDecision か exit code か） | **両方。** exit code 2 = block（stderr に理由）、exit code 0 + JSON = 構造化判定。0.144.1 は上記バリデーションを追加で掛ける |

## #1078 に効く副次的な発見

1. **`eh-bridge.sh` の `permissionDecision:"allow"` は 0.144.1 の "unsupported" 分岐に当たる可能性が高い**（`PreToolUse hook returned unsupported permissionDecision:allow`）。allow は `{}` 空出力か exit 0 のみで表現すべき。**要実走確認（未検証）**。
2. **`eh-bridge.sh` の deny で `reason` が空文字になり得る**（PlanGate hook が何も出力せず rc=2 の場合）。0.144.1 は `permissionDecision:deny without a non-empty permissionDecisionReason` を弾くため、**deny が deny として通らない fail-open リスク**。
3. **`.codex/hooks.json` の matcher `apply_patch|Edit|Write` のうち `Edit` / `Write` は Codex に存在せず死に文字列**。実質 `apply_patch` のみ。
4. **`tool_use_id` / `turn_id` / `agent_id` / `agent_type` / `permission_mode` は Claude 側 payload に無い Codex 固有フィールド**。逆に Claude の `tool_input.file_path` 前提は Codex では成立しない。
5. **hook trust の存在**: hooks config は `matcher` / `hooks` / `enabled` / **`trusted_hash`** を持ち、`--dangerously-bypass-hook-trust` フラグと `config/batchWrite failed while updating hook trust in TUI` が実在する。現行 `.codex/hooks.json` に `trusted_hash` は無く、**hook が実際に発火しているかは未検証**。
6. `codex features list` 実測: `hooks = stable / true`、`plugin_hooks = removed / false`。

## 検証状態

- **実行済み**: バイナリ Schema 抽出 / 公式仕様取得 / `codex features list` / `~/.codex/logs_2.sqlite` の読み取り専用検索 / bridge のログ経路調査
- **未実行**: `codex exec` によるサンドボックス実走（SC-2 により停止）
- **未検証**: 上記「副次的な発見」1・2・5（実走が必要）
