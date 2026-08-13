# TASK-1078 独立再検証: `hooks/list` による Codex hook 登録状態の実測

- 実施日: 2026-08-13
- 実施者: 文書是正担当（`spike/1078-codex-exec` とは独立に再実行）
- 対象: codex-cli **0.144.1**（`/opt/homebrew/bin/codex`）
- 目的: 「`.codex/hooks.json` が parse 拒否され PlanGate hook が 1 件も登録されていない」を
  **文書是正の前提として自分の手で再現**する
- **課金**: ゼロ（`hooks/list` はモデル呼び出しを伴わない）

## 手順

`codex app-server`（stdio JSON-RPC）に対し `initialize` → `initialized` → `hooks/list` を送信。

```text
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"clientInfo":{...}}}
{"jsonrpc":"2.0","method":"initialized","params":{}}
{"jsonrpc":"2.0","id":2,"method":"hooks/list","params":{"cwd":"<repo>"}}
```

## 実応答（抜粋・verbatim）

```json
{
  "hooks": [
    {
      "key": "river-review@river-review-marketplace:hooks/hooks.json:post_tool_use:0:0",
      "eventName": "postToolUse",
      "source": "plugin",
      "enabled": true,
      "trustStatus": "trusted"
    }
  ],
  "warnings": [
    "failed to parse hooks config <repo>/.codex/hooks.json: unknown field `$schema_note`, expected `description` or `hooks` at line 2 column 16"
  ],
  "errors": []
}
```

## 判定

| 項目 | 実測 |
|------|------|
| 登録された hook 総数 | **1**（river-review plugin の PostToolUse のみ） |
| **PlanGate 由来の hook 登録数** | **0** |
| `.codex/hooks.json` の parse | **拒否**（top-level `$schema_note` が仕様外） |
| top-level に許容されるキー | **`description` / `hooks` の 2 つのみ** |

→ 先行スパイク（`codex-exec-spike.md`）の結論を**独立に再現**した。
**EH-1 / EH-2 / EH-3 / EH-6 / EH-9 は Codex セッションで一度も発火していない。**

## 併せて自分の目で確認した事項

| # | 事項 | 確認方法 | 結果 |
|---|------|---------|------|
| 1 | `.codex/hooks.json` の仕様外 top-level キー | ファイル実読 | 2 行目 `$schema_note` / 3 行目 `$note`。`hooks` と同階層 |
| 2 | `.claude/settings.example.json` の wiring 総数 | `json.load` で全 event / matcher / hooks を列挙 | **11 件**（内訳は settings-wiring-contract.md の等価強制マトリクス と一致） |
| 3 | `.codex/hooks.json` の記述 hook 数 | ファイル実読 | **5 件**（PreToolUse `apply_patch\|Edit\|Write` 4 + `Bash` 1） |
| 4 | bridge のパス解決 | `eh-bridge.sh` L25-31 | `scripts/hooks/$HOOK_NAME` を**ハードコード**。not-found 時は **`deny`** を返す（L29） |
| 5 | bridge の stdin 非転送 | `eh-bridge.sh` L33 / L69 | L33 `INPUT=$(cat)` で**吸い切り**、L69 `sh "$HOOK_SCRIPT"` へ**渡していない**（hook 側の stdin は EOF） |
| 6 | bridge の rc 翻訳 | `eh-bridge.sh` L79-90 | rc 0 → bare `allow` / rc 1・2 → `deny` / **それ以外 → `allow`（fail-open）** |

## 3 軸の数え直し（本再検証の結論）

| 軸 | 定義 | 数 | 根拠 |
|----|------|----|------|
| A. 記述（declared） | 設定ファイルに書かれている件数 | Claude 11 / **Codex 5** | 上記 #2 / #3 |
| B. 登録（registered） | ランタイムが登録した件数 | **Codex 0** | `hooks/list` 実応答 |
| C. 強制力（enforced） | 発火して block した件数 | **Codex 0** | B = 0 の論理的帰結 |

**「5 / 11」は軸 A の数であり、強制力の数ではない。強制力は 0 / 11。**

## 検証状態

- **実行済み**: `hooks/list`（本リポジトリ cwd）、`.codex/hooks.json` 実読、
  `.claude/settings.example.json` の wiring 全数列挙、`eh-bridge.sh` 実読
- **未実行**: `codex exec` の実走（モデル API 課金を伴うため。U-1 / U-2 は別途確定作業中）
- **未検証**: U-1（bare `allow` の受理可否）/ U-2（空 reason `deny` の fail-open 有無）
  — **本再検証はこれらに依存しない**（登録 0 件が上位の制約のため）
