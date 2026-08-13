# TASK-1078 U-1 / U-2 / U-3 実走スパイク: Codex CLI hook の発火・応答検証

- 実施日: 2026-08-13
- ブランチ: `spike/1078-codex-exec`（base = `origin/main`）
- 対象: codex-cli **0.144.1**
- 先行: `spike/1078-codex-payload` の `codex-payload-spike.md`（payload schema 実測）
- サンドボックス: `/private/tmp/codex-hook-spike-1078`（`git init` した最小プロジェクト。実リポジトリのファイルは 1 つも使用・複製していない）+ 隔離 `CODEX_HOME=/tmp/codex-hook-spike-1078-home`（`auth.json` は実 home への symlink。コピーせず）
- **`codex exec` 実行回数: 1 回**（`-m gpt-5.4-mini` / 1 turn / usage: input 31285・cached 18688・output 294・reasoning 205）

## 結論（先に）

| ID | 問い | 判定 | 根拠 |
|---|---|---|---|
| **U-3** | `trusted_hash` が無い hooks.json は発火するか | **確定（ただし想定と別の理由で発火しない）** | 実リポジトリの `.codex/hooks.json` は **`$schema_note` により JSON 全体が parse 拒否**され、hook が **1 件も登録されない**。trust 以前の問題。加えて、正常な project hooks.json も `trusted_hash` 無しでは `trustStatus:"untrusted"` として登録される |
| **U-1** | bare `permissionDecision:"allow"` は受理されるか | **未確定** | 1 回の `codex exec` で **probe hook が 1 度も呼ばれなかった**ため、応答自体を返せていない |
| **U-2** | 空 reason の `deny` は deny として通るか | **未確定** | 同上（deny 分岐に到達せず） |

**最重要**: U-3 は「trust の問題」ではなく **「設定ファイルが読めていない」** ことが実測で判明した。**EH-1 / 2 / 3 / 6 / 9 は Codex セッションで一度も発火していない。**

---

## 1. 測定手段（課金ゼロ経路の発見）

`codex exec` を使わずに hook の登録状態を取得できる経路を発見した。

- `codex app-server`（stdio JSON-RPC）に **`hooks/list`** メソッドが存在する（`codex app-server generate-json-schema --out DIR` で確認。`ClientRequest.json` に `Hooks/listRequest` / `HooksListParams`）。
- 応答 `HooksListEntry` は `hooks[] { key, eventName, matcher, command, source, currentHash, trustStatus, enabled }` と **`warnings[]` / `errors[]`** を返す。
- `HookTrustStatus` の enum は **`managed` / `untrusted` / `trusted` / `modified`**。
- **モデル呼び出しを伴わない＝課金ゼロ。**

不発だった経路:

| 経路 | 結果 |
|---|---|
| `codex doctor` | hook に関する項目が **1 つも無い**（config / auth / sandbox / mcp などのみ） |
| `codex debug prompt-input` | 隔離せずとも成功したが、**hook 情報を一切含まない**（`hook` の一致は skill 名 `*-webhooks` のみ）。skill 可視性の診断用であり本件には無効 |
| `-c 'projects."…".trust_level="trusted"'` | **効かない**（project trust は CLI override 層から読まれない）。`CODEX_HOME` 隔離 + その config.toml への記載でのみ有効化できた |
| `-c 'hooks.pre_tool_use=…'` / `hooks.PreToolUse=…` | hook が登録されず。`--strict-config` 併用時は app-server が即死（stderr 未取得） |

## 2. U-3: 実リポジトリの hook は 1 件も登録されていない（確定）

`hooks/list`（cwd = `/Users/user/Documents/GitHub/plangate`、読み取りのみ）の実応答:

```json
{"cwd":"/Users/user/Documents/GitHub/plangate",
 "hooks":[{"key":"river-review@river-review-marketplace:hooks/hooks.json:post_tool_use:0:0",
           "eventName":"postToolUse","source":"plugin","trustStatus":"trusted", ...}],
 "warnings":["failed to parse hooks config /Users/user/Documents/GitHub/plangate/.codex/hooks.json: unknown field `$schema_note`, expected `description` or `hooks` at line 2 column 16"],
 "errors":[]}
```

- 登録されたのは **river-review plugin の PostToolUse 1 件のみ**。
- **PlanGate の PreToolUse 5 件（EH-1 / 2 / 3 / 6 / 9）は 1 件も登録されていない。**
- 原因は **`.codex/hooks.json` の 2 行目 `"$schema_note"`**。top-level は **`description` と `hooks` の 2 キーしか許容しない**（`deny_unknown_fields`）。`$note`（3 行目）も同様に不正。
- **1 キーの違反でファイル全体が捨てられる**（部分適用ではない）。

### 独立再現（実リポジトリのファイルを使わずに）

サンドボックスに自作した hooks.json へ `"$schema_note"` を 1 行足しただけで同一挙動:

```json
{"cwd":"/private/tmp/codex-hook-spike-1078","hooks":[],
 "warnings":["failed to parse hooks config /private/tmp/codex-hook-spike-1078/.codex/hooks.json: unknown field `$schema_note`, expected `description` or `hooks` at line 2 column 16"]}
```

同じファイルから `$schema_note` を除くと hook は登録された（後述）。**決定論的。**

### 付随して確定した 2 つのゲート

1. **project trust**: 未 trusted のプロジェクトでは project-local hooks が**読まれない**。実測 warning:
   `Project-local config, hooks, and exec policies are disabled in the following folders until the project is trusted, but skills still load.`
   → `~/.codex/config.toml` の `[projects."<path>"] trust_level = "trusted"` が前提。**plangate は trusted 済み**なので、実リポジトリの欠落原因はこれではない。
2. **hook trust**: trust されたプロジェクトでも、`trusted_hash` を持たない project hook は **`trustStatus:"untrusted"`** で登録される（実測）。`trusted_hash` を `CODEX_HOME/config.toml` の
   `[hooks.state."<abs-path>/.codex/hooks.json:pre_tool_use:0:0"] trusted_hash = "sha256:…"` に書くと **`trusted`** に変わることを実測（同一ファイル内の別 matcher group `:1:0` は `untrusted` のまま = **hash は hook 単位**）。

## 3. U-1 / U-2: 未確定（probe が 1 度も呼ばれなかった）

### 実行したコマンド（1 回のみ）

```sh
CODEX_HOME=/tmp/codex-hook-spike-1078-home \
codex exec -m gpt-5.4-mini -s workspace-write --ephemeral --json \
  "Step 1: create a file named allowprobe.txt containing the text hello. Step 2: create a file named zzdenyme.txt containing the text world. …"
# exit code = 0
```

事前に `hooks/list` で登録状態を較正済み:

| hook | key | trustStatus |
|---|---|---|
| probe A（bare allow / 空 reason deny を返す） | `…/hooks.json:pre_tool_use:0:0` | **trusted** |
| probe B（記録のみ・無出力） | `…/hooks.json:pre_tool_use:1:0` | **untrusted** |

### 観測結果

| 観測点 | 実測 |
|---|---|
| `apply_patch` による `allowprobe.txt` 生成 | **成功**（`item.completed` / ファイル実在） |
| **probe A（trusted）の呼び出し回数** | **0**（stdin / argv / env の記録ディレクトリが 1 つも生成されず） |
| **probe B（untrusted）の呼び出し回数** | **0** |
| `--json` イベント列の hook 関連イベント | **0 件**（`HookStartedNotification` / `HookCompletedNotification` に相当する出力なし） |
| 隔離 `CODEX_HOME` の `logs_2.sqlite` | `codex exec` プロセスの行が **そもそも記録されていない**（app-server 4 プロセス分のみ） |
| **probe が受け取った実 payload** | **存在しない**（1 度も呼ばれていないため） |

### 未確定の理由（候補・いずれも未検証）

1. `codex exec`（非対話）は PreToolUse hook を評価しない
2. `--ephemeral` が hook を無効化する
3. 手書きの `[hooks.state]` による trust が `hooks/list` では反映されるが **実行時には効かない**（＝実行時は untrusted 扱いで skip）
4. matcher `.*` が `apply_patch` 経路に適用されない（この run では shell ツールが 1 度も呼ばれず、`apply_patch` のみで検証した）

また、モデルが **Step 1 だけ実行して停止**した（「2 つ目に触れる前に一旦止めます」）ため、**deny 分岐（`zzdenyme`）には設計上到達していない**。

**コスト制約により 2 回目の `codex exec` は実行していない。**

## 4. #1078 に効く帰結

1. **「Codex CLI parity — 達成済」は成立していない。** EH-1/2/3/6/9 は **登録すらされていない**（発火有無以前）。`docs/ai/settings-wiring-contract.md` / `docs/plangate.md:500` / `harness-improvement-roadmap.md:78` の記述は実態と乖離。
2. **最小の是正は `$schema_note` / `$note` の除去**（`description` へ寄せる）。ただしこれは「hook が動き出す」ことを意味するため、**bridge の全 deny 問題（stdin 非転送 / パス解決 / `apply_patch` の parse-unknown）を先に直さないと、修正した瞬間に Codex が使用不能になる**（#1078 起票者の指摘どおり）。
3. **`trusted_hash` の運用が新たな前提**として要る。project hooks は既定 `untrusted`。`hooks.json` を編集するたび hash が変わるため、**「編集 → 再 trust」が運用フローに必要**。CI で検出する場合は `hooks/list` の `warnings` / `trustStatus` が機械可読な単一情報源になる。
4. **`hooks/list` は課金ゼロの回帰検査に使える。** 「PlanGate hook が N 件・すべて enabled・warnings 空」を CI / doctor で検査すれば、今回の 3 年分の silent failure 型（parse 拒否）を機械検出できる。

## 5. 検証状態

- **実行済み**: `hooks/list`（実リポジトリ / サンドボックス / trust 有無 / `$schema_note` 有無の 4 条件）、`codex doctor`、`codex debug prompt-input`、`codex features list`（2 home）、`codex exec` **1 回**、`thread/shellCommand` 経由の hook 発火確認（発火せず＝ただしクライアント駆動 shell のため PreToolUse 対象外の可能性あり・非決定的）
- **未実行**: 2 回目の `codex exec`（`--dangerously-bypass-hook-trust` 付き / 非 `--ephemeral` / shell ツールを強制する prompt）
- **未検証**: U-1（bare allow の受理可否）、U-2（空 reason deny の fail-open 有無）、`codex exec` が PreToolUse hook を評価するか否か

## 6. 次の一手（要 Human 判断）

**P0**: U-1 / U-2 を確定するための **2 回目の `codex exec`** を許可するか。推奨条件（1 回で取り切る）:
`--dangerously-bypass-hook-trust` を付け、`--ephemeral` を外し、prompt で **shell コマンドの実行を明示**（`apply_patch` 以外の経路も踏ませる）、かつ **deny 対象を先**にする。

**P1**: `$schema_note` / `$note` の除去（＋ bridge 修正との順序）。単独で先に入れると全 deny 化するため、**bridge 修正と同一 PR** にすべき。

**P2**: `hooks/list` ベースの機械検査（doctor / CI）の追加。
