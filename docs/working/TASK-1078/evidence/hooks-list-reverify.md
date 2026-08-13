# TASK-1078 独立再検証: `hooks/list` による Codex hook 登録状態の実測

- 実施日: 2026-08-13
- 実施者: 文書是正担当（`spike/1078-codex-exec` とは独立に再実行）
- 対象: codex-cli **0.144.1**（`/opt/homebrew/bin/codex`）
- 目的: 「`.codex/hooks.json` が parse 拒否され PlanGate hook が 1 件も登録されていない」を
  **文書是正の前提として自分の手で再現**する
- **課金**: ゼロ（`hooks/list` はモデル呼び出しを伴わない）

## 手順（第三者が再実行できる完全な形）

`codex app-server`（stdio JSON-RPC）を起動し、以下 3 行を **1 行 1 メッセージ**で stdin に送る。

```json
{"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"clientInfo": {"name": "probe", "title": "probe", "version": "0.0.1"}}}
{"jsonrpc": "2.0", "method": "initialized", "params": {}}
{"jsonrpc": "2.0", "id": 2, "method": "hooks/list", "params": {"cwd": "/Users/user/Documents/GitHub/plangate"}}
```

`id: 2` の応答を読んだ時点で終了してよい。**モデル呼び出しは発生しない。**

## 実応答

**生の stdout を無加工で [`hooks-list-raw.json`](./hooks-list-raw.json) に添付**（送信した
request 3 件も同ファイルに含む）。以下は要点の抜粋（`<repo>` 等の置換はしていない）:

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
    "failed to parse hooks config /Users/user/Documents/GitHub/plangate/.codex/hooks.json: unknown field `$schema_note`, expected `description` or `hooks` at line 2 column 16"
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

→ 先行スパイク（`codex-exec-spike.md` — **本ブランチには存在せず、別ブランチ
`spike/1078-codex-exec` 上にある**。PR #1082 として作成済み）の結論を**独立に再現**した。
**EH-1 / EH-2 / EH-3 / EH-6 / EH-9 は Codex セッションで一度も発火していない。**

## bridge の decision 実測（C-1 差し戻しの検証 / 2 度目の是正）

当初「注記キーを除去すると全操作が deny され Codex が使用不能になる」と記述したが、
**実測で否定された**。`eh-bridge.sh` に PreToolUse payload（`tool_name: apply_patch` /
`tool_input.command` に `*** Update File: <path>`）を直接投入した結果:

| 対象ファイル | hook | rc | decision |
|---|---|---|---|
| `bin/plangate` | check-plan-exists / check-c3-approval / check-forbidden-files / check-plan-hash | 0 | **allow** |
| `docs/working/TASK-1078/plan.md` | 同上 4 本 | 0 | **allow** |
| **`.claude/settings.json`（HO パス）** | 同上 4 本 | 0 | **allow** |

**12 / 12 が `allow`。Hardening Override パスですら通る。**

補助確認（bridge を介さず env のみで hook を直接起動）:

```text
PLANGATE_HOOK_FILE=".claude/settings.json" sh scripts/hooks/check-forbidden-files.sh </dev/null
  → {"continue":true} / rc=0
PLANGATE_HOOK_FILE=".claude/settings.json" sh scripts/hooks/check-plan-hash.sh </dev/null
  → [Hook EH-3 PASS] plan_hash matches current plan.md / rc=0
```

**結論**: bridge は **deny ではなく allow に倒れる**。したがって注記キー除去の危険性は
「Codex が使えなくなる」ことではなく、**「登録されたのに強制力は 0 のまま、外形上は
parity 回復に見える」**ことである。詳細と欠陥一覧（B-1〜B-4）は
`docs/ai/settings-wiring-contract.md` §Codex CLI parity を正本とする。

## 併せて自分の目で確認した事項

| # | 事項 | 確認方法 | 結果 |
|---|------|---------|------|
| 1 | `.codex/hooks.json` の仕様外 top-level キー | ファイル実読 | 2 行目 `$schema_note` / 3 行目 `$note`。`hooks` と同階層 |
| 2 | `.claude/settings.example.json` の wiring 総数 | `json.load` で全 event / matcher / hooks を列挙 | **11 件**（内訳は settings-wiring-contract.md の等価強制マトリクス と一致） |
| 3 | `.codex/hooks.json` の記述 hook 数 | ファイル実読 | **5 件**（PreToolUse `apply_patch\|Edit\|Write` 4 + `Bash` 1） |
| 4 | bridge のパス解決 | `eh-bridge.sh` L25-31 | `scripts/hooks/$HOOK_NAME` を**ハードコード**。not-found 時は **`deny`** を返す（L29）。**ただし配線済み 5 本は実在するため、この分岐には入らない**（not-found deny は未配線 hook を名前だけ足したときのみ発火） |
| 5 | bridge の stdin 非転送 | `eh-bridge.sh` L33 / L69 | L33 `INPUT=$(cat)` で**吸い切り**、L69 `sh "$HOOK_SCRIPT"` へ**渡していない**（hook 側の stdin は EOF） |
| 6 | bridge の rc 翻訳 | `eh-bridge.sh` L79-90 | rc 0 → bare `allow` / rc 1・2 → `deny` / **それ以外 → `allow`（fail-open）** |

## 3 軸の数え直し（本再検証の結論）

| 軸 | 定義 | Claude | Codex | 根拠 |
|----|------|--------|-------|------|
| A. 記述（declared） | 設定ファイルに書かれている件数 | **11** | **5** | 上記 #2 / #3 |
| B. 登録（registered） | ランタイムが登録した件数 | **未測定** | **0** | Codex は `hooks/list` 実応答。**Claude 側は同等の問い合わせを本 PBI で実施していない** |
| C. 強制力（enforced） | 発火して block した件数（上限は軸 B） | **未測定** | **0** | B = 0 より上限 0（下限の実走確認は未取得） |

**「5 / 11」は軸 A の数であり、強制力の数ではない。Codex の強制力は 0 / 11。**
**Claude 側の 11 も軸 A の数**であり、「11 件効いている」ことを本 PBI は示していない。

## 検証状態

- **実行済み**: `hooks/list`（本リポジトリ cwd・生 stdout を `hooks-list-raw.json` に添付）、
  `.codex/hooks.json` 実読、`.claude/settings.example.json` の wiring 全数列挙、
  `eh-bridge.sh` 実読、**bridge への payload 投入による decision 実測（12 ケース）**、
  hook の env-only 直接起動（2 本）
- **未実行**: `codex exec` の実走（モデル API 課金を伴うため）／Claude 側ランタイムの
  hook 登録状態の問い合わせ（軸 B / C が「未測定」である理由）
- **未検証**: U-1（bare `allow` の受理可否）/ U-2（空 reason `deny` の fail-open 有無）
  — 別走で**観測はあるが `permission_mode=bypassPermissions` の交絡により因果未確定**。
  **本再検証はこれらに依存しない**（登録 0 件が上位の制約のため）
