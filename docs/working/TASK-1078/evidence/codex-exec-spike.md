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

---

# 追記: 2 回目の実走（U-1 / U-2 の確定）

- 実施日: 2026-08-13（Human が P0 を承認し **`codex exec` 1 回**を追加許可）
- サンドボックス: `/private/tmp/cx1078b`（新規に `git init`。実リポジトリのファイルは不使用）+ 隔離 `CODEX_HOME=/tmp/cx1078b-home`（auth は symlink）
- **`codex exec` 実行回数: 1 回**（累計 2 回。exit code **0** / usage: input 42755・cached 32384・output 302・reasoning 114 / `-m gpt-5.4-mini`）

## 結論

| ID | 判定 | 根拠 |
|---|---|---|
| **U-1** | **確定（実務上の答え）**: bare `permissionDecision:"allow"` は **エラーにならず、ツールも実行された** | probe が bare allow を返した直後に `command_execution` が `exit_code: 0` で完了。stderr / `--json` イベント列に `unsupported permissionDecision:allow` は **1 件も出ていない** |
| **U-2** | **確定（fail-open を再現）**: 空 reason の `deny` は **ブロックしなかった** | probe が `permissionDecision:"deny"` + `permissionDecisionReason:""` を返したにもかかわらず `echo world > zzdenyme.txt` が **`exit_code: 0` で実行され、ファイルが実在** |

**ただし両判定には後述の制約（`permission_mode=bypassPermissions`）がある。** 「なぜ通ったか」の因果までは 1 回の run では切り分けられていない。

## 前回失敗（probe 0 回）の是正

| 変更点 | 前回 run | 今回 run |
|---|---|---|
| `--ephemeral` | あり | **外した** |
| `--dangerously-bypass-hook-trust` | なし | **付けた** |
| prompt | ファイル作成（`apply_patch` 経路のみ・モデルが Step 1 で自発停止） | **shell ツールを明示指定** + **deny 対象を先** + 「ブロックされても retry せず次へ進め」 |
| 結果 | probe 呼び出し **0 回** | probe A **2 回** / probe B **2 回** |

> 2 変数を同時に変えたため、**発火を可能にしたのが bypass フラグか `--ephemeral` 除去かは切り分けていない**（未検証）。

## exec 前後の `hooks/list`（登録証跡・課金ゼロ）

exec **前**（trust 付与後）／exec **後** とも同一で、3 件すべて登録・`warnings: []`:

```
/private/tmp/cx1078b/.codex/hooks.json:pre_tool_use:0:0   preToolUse    trustStatus=trusted
/private/tmp/cx1078b/.codex/hooks.json:pre_tool_use:1:0   preToolUse    trustStatus=trusted
/private/tmp/cx1078b/.codex/hooks.json:session_start:0:0  sessionStart  trustStatus=trusted
```

- top-level に **`description` を置いた hooks.json は warning なしで受理**された → 実リポジトリの `$schema_note` / `$note` は **`description` へ寄せれば解消する**ことを実測で裏取り。
- trust は `CODEX_HOME/config.toml` の `[hooks.state."<key>"] trusted_hash = "sha256:…"` で `untrusted` → `trusted` に遷移（前回同様、hook 単位）。

### 事前検証（撃つ前に実施・課金ゼロ）

1. probe スクリプト単体テスト: deny / bare allow / silent の 3 分岐が設計どおり出力し `rc=0` になることを確認（codex 非経由）。
2. `SessionStart` probe を仕込み、app-server `thread/start` で発火するかを untrusted / trusted の両方で試行 → **どちらも発火せず**（thread は起動している）。**app-server 経由の thread/start では SessionStart hook が発火しない**（＝課金ゼロで hook 発火を確認する経路は見つからなかった）。SC-1（登録の確認）は `hooks/list` で満たしたうえで実走した。

## probe が受け取った実 payload（実物・2 件）

deny 分岐（call-1）:

```json
{"session_id":"019ff91f-8934-7822-b0d6-c4b33ec7c47f","turn_id":"019ff91f-8af4-71f2-bf1e-995bdd97a1ab",
 "transcript_path":"/private/tmp/cx1078b-home/sessions/2026/08/13/rollout-2026-08-13T12-17-01-019ff91f-8934-7822-b0d6-c4b33ec7c47f.jsonl",
 "cwd":"/private/tmp/cx1078b","hook_event_name":"PreToolUse","model":"gpt-5.4-mini",
 "permission_mode":"bypassPermissions","tool_name":"Bash",
 "tool_input":{"command":"echo world > zzdenyme.txt"},"tool_use_id":"call_Wyf83x9bGH3DqsJVCY1vqTNG"}
```

bare allow 分岐（call-2）: 同形で `tool_input.command` が `echo hello > allowprobe.txt` / `tool_use_id: call_F4qM1tIz9kk5kKEMoMIqgb9r`。

**先行スパイクの schema 実測が実 payload で裏付けられた点**:

- `hook_event_name: "PreToolUse"` が **実在**（EH-13 の jq 判定は成立する）
- `tool_name` は **`Bash`**（shell 実行時）。`tool_input.command` は **Claude と同名**
- **`agent_id` / `agent_type` は今回の payload に存在しない**（schema の `required` には無い項目）
- 入力は **stdin のみ**。`env.txt` を全件記録したが **`CODEX_HOOK_*` 系の env は 1 件も無い**（bridge が env 経由で受け取れる情報は無い）

## `--json` イベント列（抜粋・実物）

```
{"type":"item.completed","item":{"id":"item_0","type":"error","message":"`--dangerously-bypass-hook-trust` is enabled. Enabled hooks may run without review for this invocation."}}
{"type":"item.completed","item":{"id":"item_3","type":"command_execution","command":"/bin/zsh -lc 'echo world > zzdenyme.txt'","exit_code":0,"status":"completed"}}
{"type":"item.completed","item":{"id":"item_5","type":"command_execution","command":"/bin/zsh -lc 'echo hello > allowprobe.txt'","exit_code":0,"status":"completed"}}
```

`unsupported permissionDecision` / `without a non-empty permissionDecisionReason` に相当する出力は **stderr・イベント列・隔離 home の `logs_2.sqlite`・session rollout jsonl のいずれにも存在しない**（`codex exec` の実行自体が `logs_2.sqlite` に記録されないことも確認）。

## 🔴 判定の制約（正直な限界）

1. **`permission_mode` が `bypassPermissions` だった**（サンドボックス config の `approval_policy = "never"` + `-s workspace-write` に由来）。したがって U-2 の観測は
   - (a) **空 reason ゆえに deny が無効化された**（＝ bridge の fail-open リスクが実在）
   - (b) **`bypassPermissions` ではあらゆる deny が無視される**
   の **2 通りに解釈でき、1 回の run では切り分けられない**。
   **切り分けには「非空 reason の deny」を対照にした追加 run が要る**（同一 config で非空 reason の deny がブロックすれば (a) が確定）。
2. U-1 の「受理」と「無視（既定 allow のまま進行）」は、**既定が allow である以上この観測では区別できない**。確実に言えるのは **「bare allow を返してもエラーにならず、セッションも壊れない」** ところまで。

## #1078 への含意

- **bridge の正常系（bare allow）は少なくとも実害を出さない**。優先度は下げてよい。
- **bridge の deny 経路は危険**。`reason` が空になる条件（PlanGate hook が無出力で rc=2）は現実に起こりうるため、**`eh-bridge.sh:84` は reason が空なら固定文言を必ず埋める**べき（`deny` を必ず非空 reason で返す）。上記制約 1 が (b) だったとしても、**この修正は無害かつ必要**。
- **`.codex/hooks.json` の top-level は `description` / `hooks` のみ**。`$schema_note` / `$note` は除去必須（今回 `description` での受理を実測）。

## 検証状態（追記分）

- **実行済み**: probe 単体テスト、exec 前後の `hooks/list`、SessionStart 発火試験（untrusted / trusted）、**`codex exec` 1 回**、payload / イベント列 / logs / rollout の突合
- **未実行**: 非空 reason の deny を対照とする追加 run（3 回目の exec）
- **未検証**: `bypassPermissions` 以外の permission_mode での deny 挙動 / bare allow が「受理」か「無視」か / 発火を可能にしたのが bypass フラグか `--ephemeral` 除去か

---

# 追記 2: 3 回目の実走（交絡の切り分け・U-1 / U-2 の因果確定）

- 実施日: 2026-08-13（Human が 3 回目の `codex exec` を 1 回だけ承認）
- サンドボックス: `/private/tmp/cx1078c` + 隔離 `CODEX_HOME=/tmp/cx1078c-home`（auth は symlink）
- **`codex exec` 実行回数: 1 回**（累計 3 回。exit code **0** / usage: input 57399・cached 46592・output 415・reasoning 129）
- **run #2 と同一 config**（`approval_policy="never"` / `-s workspace-write` / `--dangerously-bypass-hook-trust`）＝ **同一条件下の対照実験**

## 結論（交絡は解消した）

| ID | 判定 | 根拠 |
|---|---|---|
| **U-2** | **(a) が確定**: **空 reason 固有の fail-open**。`bypassPermissions` が deny を一律無視しているのではない | **同一セッション・同一 config** で、**非空 reason の deny は BLOCK し**、**空 reason の deny は BLOCK しなかった** |
| **U-1** | **確定: allow は「無視」ではなく「受理」されている** | allow に `updatedInput` を添えたところ、**実行されたコマンドが書き換え後の内容だった**（`echo C > allowupdated.txt` → **`echo REWRITTEN > allowaccepted.txt`**）。hook の判定が確実に消費されている |

## 1 回の run で 3 分岐を観測（probe A が 3 回呼ばれた）

| # | ツール入力 | probe が返した判定 | 結果 |
|---|---|---|---|
| 1 | `echo A > zznonempty.txt` | `deny` + **非空** reason | **ブロックされた**（`command_execution` イベントが**発生していない** / `zznonempty.txt` は**存在しない**）|
| 2 | `echo B > zzemptyreason.txt` | `deny` + **空** reason | **実行された**（`exit_code: 0` / ファイル実在）|
| 3 | `echo C > allowupdated.txt` | `allow` + `updatedInput` | **書き換えられて実行**（`/bin/zsh -lc 'echo REWRITTEN > allowaccepted.txt'`）|

### 決定的証跡（stderr 実物）

```text
2026-08-13T04:29:18.329123Z ERROR codex_core::tools::router:
error=Command blocked by PreToolUse hook: PlanGate probe: blocked by policy (non-empty reason control).
Command: echo A > zznonempty.txt
```

- **非空 reason の deny は `codex_core::tools::router` で確実にブロックされ、reason がそのままエラー文言に載る。**
- **空 reason の deny については、対応するエラー行が 1 件も出ていない**（＝**黙って握り潰されている**）。ログ・イベント列・stderr のいずれにも警告なし。

### `--json` イベント列（抜粋・実物）

```
{"type":"item.completed","item":{"id":"item_3","type":"agent_message","text":"The first command was blocked, so I'm moving to the second command without retrying the first."}}
{"type":"item.completed","item":{"id":"item_4","type":"command_execution","command":"/bin/zsh -lc 'echo B > zzemptyreason.txt'","exit_code":0,"status":"completed"}}
{"type":"item.completed","item":{"id":"item_6","type":"command_execution","command":"/bin/zsh -lc 'echo REWRITTEN > allowaccepted.txt'","exit_code":0,"status":"completed"}}
```

## exec 前後の `hooks/list`（登録証跡）

前後で同一・`warnings: []`:

```
/private/tmp/cx1078c/.codex/hooks.json:pre_tool_use:0:0  enabled=true  trustStatus=untrusted
```

`trustStatus=untrusted` のままだが `--dangerously-bypass-hook-trust` により発火した（run #2 と同条件）。**「登録されていること」は撃つ前に確認済み（SC-1 充足）。**

## probe が受け取った実 payload（実物）

```json
{"session_id":"019ff961-93b2-7f90-bf75-3c3f482673b6","turn_id":"019ff961-947f-7d52-a06a-c0c2749a4a5a",
 "transcript_path":"…/rollout-2026-08-13T13-29-09-019ff961-….jsonl","cwd":"/private/tmp/cx1078c",
 "hook_event_name":"PreToolUse","model":"gpt-5.4-mini","permission_mode":"bypassPermissions",
 "tool_name":"Bash","tool_input":{"command":"echo A > zznonempty.txt"},"tool_use_id":"call_uRqCRWdmQkXaIHdepPL4q1bV"}
```

（3 件目も同形で `tool_input.command` が `echo C > allowupdated.txt` / `tool_use_id: call_VkCzlLNzqdgSYHE77igKtVPd`）

> **`permission_mode` は今回も `bypassPermissions` だが、その下で非空 reason の deny が現に BLOCK した**ため、「bypassPermissions だから deny が効かない」という説明は**実測で否定された**。

## 🔴 #1078 への確定的な含意

1. **`eh-bridge.sh:84` の deny は、`reason` が空になった瞬間に無効化される（fail-open）。しかも警告が一切出ない。**
   PlanGate hook が**無出力で rc=2** を返すケース（`/tmp/eh-bridge-out.$$` が空 or 生成されない）は現実に起こりうるため、**これは実在するセキュリティホール**。
   → **修正**: `reason` が空なら固定文言（例: `PlanGate <hook> blocked (no output)`）を必ず埋める。**これは 1 行で塞げる。**
2. **allow 判定は確実に消費される**（`updatedInput` まで反映）。bridge の正常系 allow は**実害なし**。ただし **`updatedInput` を返せばツール入力を書き換えられる**＝ **hook 側に強い権限がある**ことも同時に判明した（bridge がバグで `updatedInput` を返すことは無いが、設計上の注意点）。
3. **deny が効くこと自体は実証された。** 「Codex 側の hook には強制力が無い」わけではなく、**強制力はあるが PlanGate 側の bridge がそれを空 reason で捨てている**、が正しい理解。

## 検証状態（追記 2 分）

- **実行済み**: probe 単体テスト（3 分岐）、exec 前後の `hooks/list`、**`codex exec` 1 回**（累計 3 回）、stderr / `--json` / ファイル実在の 3 系統突合
- **未実行**: `bypassPermissions` 以外の permission_mode での再確認（今回の切り分けには不要）
- **未検証**: bare allow（`updatedInput` 無し）が「受理」か「無視」かの厳密な区別 — ただし **`updatedInput` 付き allow が受理されたことで、allow 判定の経路自体は生きていると確認できた**ため、実務上の残リスクはない
- **失敗**: なし
