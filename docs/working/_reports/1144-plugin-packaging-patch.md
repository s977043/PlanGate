# #1144 plugin packaging 設計（案 A / run-from-plugin・patch 設計書）

> **本書は patch 設計書であり、`scripts/` / `plugin/` / `.claude/` の実ファイルを本 PR で編集していない**。差分はすべて本書内に提示する。
>
> - 起点: `origin/main` = `01c8946da4ef0f1f147aca39bfd97af2a963018c`
> - ブランチ: `docs/1144-plugin-packaging`
> - 対象 issue: #1144 / 方針: **案 A（run-from-plugin）確定**（issue 方針決定コメント）
> - **前提となる先行設計**: [`1144-root-resolution-patch.md`](./1144-root-resolution-patch.md)（PR #1147・main マージ済）。**root 解決の設計は本書で再設計しない**。本書はその Stage 5（配布の有効化）の詳細設計である
> - 変更ファイル: 本ファイル 1 件のみ

---

## 0. 要約（結論先行）

| 論点 | 結論 |
|---|---|
| 同梱本数 | **17 本全部は同梱しない。** Claude Code harness が自ら起動できる **8 本 + root ヘルパー 1 本 = 9 ファイル**（Stage 5a）。#1079 解消後に EH-13 を追加して 10 ファイル（Stage 5b） |
| 除外の中核根拠 | **呼び出し元が導入先に存在しないスクリプトを配ると「置いてあるのに効かない」を作る**（#1078 の再演）。6 本は `bin/plangate` からしか呼ばれず、その `bin/plangate` は未配布（#1057） |
| **配ってはならない 1 本** | **`scripts/gh-pin-account.sh`**（既定で **`gh` active account を `s977043` へ切り替える**）。導入先に配ると**利用者の GitHub 認証を第三者アカウントへ切り替えにいく**。本書で除外を確定する（**新規発見**） |
| 同梱機構 | **新機構を作らない。** 既存 `_sync_ai_loop_file()`（`scripts/ai-loop/*.py` → `skills/ai-loop-cycle/scripts/`）をそのまま再利用し、「明示列挙 + 対の allowlist + stale 削除」の前例を踏襲。ただし列挙を **変数 1 本に単一化**して ta-60 型の drift を構造的に消す |
| `hooks.json` | `.codex/hooks.json` の**形**（matcher / timeout / 1 エントリ 1 hook）は踏襲し、**`$schema_note` / `$note` の注記キーは踏襲しない**（#1078 実測: 注記キー 1 つで **JSON 全体 parse 拒否 → hook 登録 0 件**）。**先行設計 §6-1 の draft はこの点で誤り**（§7-1） |
| timeout | **全 hook に宣言**。既定は **600 秒**（公式ドキュメント実測）＝無宣言は事実上ハング。実測最大 1.5 秒に対し **10**（`check-plan-hash.sh` のみ **15**、`.codex/hooks.json` と同値）|
| 未確認事項 | 公式ドキュメントで **3 点のうち 3 点とも記述は見つかった**（§6）。ただし**記述と実挙動の一致は未実測**であり、AC-1 の実走で確定させる。**新たな未確認 2 件**（timeout 打ち切り時の rc 扱い / 上流リポジトリでの二重発火）を追加 |

---

## 1. 何を `plugin/plangate/hooks/` へ同梱するか

### 1-1. 判断基準（3 つ）

1. **導入先に呼び出し元が実在するか。** plugin は `hooks/hooks.json` 経由でしか hook を起動できない。`bin/plangate` や CI workflow からしか呼ばれないスクリプトは、配っても**誰も起動しない**。
2. **導入先で無害か。** 上流リポジトリ固有の値を既定に持つスクリプトは配らない（`hybrid-architecture.md` Rule 4 の配布時抽象化）。
3. **前提依存が導入導線で担保されているか。** 依存不在で **fail-closed → 全 Edit/Write/Bash が止まる**スクリプトは、#1079（`jq` / `sed` の導入導線）が解けるまで載せない。

### 1-2. 全 20 スクリプトの分類（実測）

対象は `scripts/hooks/*.sh` **17 本** + `settings.example.json` が配線する `scripts/` 直下 **3 本**。

| # | script | 起動元（実測） | 同梱 | 理由 |
|---|---|---|:--:|---|
| 1 | `scripts/hooks/check-plan-exists.sh` | Claude PreToolUse | **5a** | harness が起動する |
| 2 | `scripts/hooks/check-c3-approval.sh` | Claude PreToolUse | **5a** | 同上 |
| 3 | `scripts/hooks/check-plan-hash.sh` | Claude PreToolUse | **5a** | **中核ゲート**（HO + plan_hash） |
| 4 | `scripts/hooks/check-forbidden-files.sh` | Claude PreToolUse | **5a** | 同上 |
| 5 | `scripts/hooks/check-delegation-commit-boundary.sh` | Claude PreToolUse(Bash) | **5a** | 同上 |
| 6 | `scripts/hooks/check-post-edit-diff.sh` | Claude PostToolUse | **5a** | 同上 |
| 7 | `scripts/hooks/check-stop-diff-status.sh` | Claude Stop | **5a** | 同上 |
| 8 | `scripts/check-git-destructive.sh` | Claude PreToolUse(Bash) | **5a** | `jq` は任意（非搭載時 fallback あり・L106） |
| 9 | `scripts/hooks/_plangate-root.sh`（**新設 / 先行設計 §3-1**） | 各 hook が `$0` 相対で source | **5a** | **これが無いと全 hook が fail-closed で止まる** |
| 10 | `scripts/check-approval-token-write.sh` | Claude PreToolUse(Edit\|Write / Bash) | **5b** | **`jq` / `sed` 不在で `exit 2`**（L367 / L383）。#1079 の導線整備後 |
| 11 | `scripts/gh-pin-account.sh` | Claude SessionStart | **不可** | **`DESIRED_USER=${PLANGATE_GH_USER:-s977043}`（L21）。導入先の `gh` active account を上流メンテナのアカウントへ切り替えにいく** |
| 12 | `scripts/hooks/cursor-adapter.sh` | `.cursor/hooks/*.sh` が**利用者リポジトリの** `scripts/hooks/cursor-adapter.sh` を `exec` | 不可 | 呼び出し元が plugin を見ない（`.cursor/hooks/plangate-eh1-plan.sh:3`）。plugin 経路では到達不能 |
| 13 | `scripts/hooks/check-test-cases.sh`（EH-4） | `bin/plangate:2197` | 保留 | **`bin/plangate` 未配布（#1057）** |
| 14 | `scripts/hooks/check-verification-evidence.sh`（EH-5） | `bin/plangate:2214` | 保留 | 同上 |
| 15 | `scripts/hooks/check-merge-approvals.sh`（EH-7） | 手動 / `bin/plangate:603` の案内 | 保留 | 同上 |
| 16 | `scripts/hooks/check-v3-review.sh`（EHS-1） | CLI（mode 連携） | 保留 | 同上 |
| 17 | `scripts/hooks/check-handoff-elements.sh`（EHS-2） | `bin/plangate:2266` | 保留 | 同上 |
| 18 | `scripts/hooks/check-fix-loop.sh`（EHS-3） | `bin/plangate:2206` | 保留 | 同上。**状態ファイルを書く唯一の hook**（二重発火時の副作用面も大きい） |
| 19 | `scripts/hooks/check-metrics-privacy.sh`（EH-8） | CI `metrics-privacy.yml:77` / `codex-guarded.sh:129` / `doctor` | 不可 | harness hook ではない。CI/CLI 経路の資産 |
| 20 | `scripts/hooks/check-ai-memory-pollution.sh` | git `pre-commit`（`scripts/templates/pre-commit.sample:10`） | 不可 | git hook であり Claude hook ではない |

**同梱数: Stage 5a = 9 ファイル / Stage 5b = 10 ファイル。未配布 = 10 本（うち 6 本は #1057 解消で追加可能）。**

> **「17 本全部」を採らなかった理由（要点）**: (a) 6 本は起動元 `bin/plangate` が未配布で**確実に起動されない**、(b) 1 本は**導入先の認証を書き換える実害**がある、(c) 1 本は呼び出し元が plugin を見ない、(d) 2 本は CI / git hook の資産。**「置いてあるが効かない」を 10 本ぶん配ることは、#1144 が是正しようとしている「宣言と実効の乖離」を別の形で再生産する。**

### 1-3. 同梱に必要な差分 — `scripts/sync-plugin-plangate.sh`

**前例の踏襲**: `_sync_ai_loop_file()`（L262-280）は「src ファイル 1 本 → dst ディレクトリへリンク変換なしの単純コピー」であり、`.py` 専用ではない。**そのまま再利用する（新関数を作らない）。**

改善点 1 つだけ入れる: ai-loop の `.py` は「for ループの列挙」と「削除 allowlist の `case`」に**同じ basename を二重に書いて** ta-60 が drift 検出しているが、hook 側は**列挙を変数 1 本に単一化**して drift の発生余地自体を消す（`_ai_loop_schema_files` が既に採っている形と同型）。

```diff
--- a/scripts/sync-plugin-plangate.sh
+++ b/scripts/sync-plugin-plangate.sh
@@ (bundled schema ブロックの直後 / version 同期ブロックの直前)
+# ── enforcement 層（hook）の同梱（#1144 Stage 5a） ─────────────────────────
+# plugin 導入先では hooks/hooks.json が ${CLAUDE_PLUGIN_ROOT}/hooks/<name> を起動する。
+# 同梱するのは「Claude Code harness 自身が起動できる」ものだけ:
+#   - bin/plangate からしか呼ばれない EH-4/5/7/EHS-1/2/3 は #1057 解消まで同梱しない
+#   - gh-pin-account.sh は既定が上流固有アカウント（s977043）のため同梱不可
+#   - cursor-adapter.sh は .cursor/hooks/*.sh が利用者リポジトリ側を exec するため到達不能
+#   - check-metrics-privacy.sh / check-ai-memory-pollution.sh は CI / git hook 経路の資産
+#   - check-approval-token-write.sh（EH-13）は jq/sed 不在で fail-closed するため #1079 後（Stage 5b）
+# ⚠️ 列挙は下の 2 変数が唯一の正。コピーループと stale 削除ループの両方が同じ変数を
+#    読むため、片側だけ更新する drift は構造的に起こらない（ai-loop の .py 二重列挙とは
+#    異なる形。tests/extras/ta-60-run-evidence.sh ⑤ 相当の照合は不要）。
+PLUGIN_HOOKS_DIR="$PLUGIN_DIR/hooks"
+_plugin_hook_files_from_hooks="_plangate-root.sh check-plan-exists.sh check-c3-approval.sh check-plan-hash.sh check-forbidden-files.sh check-delegation-commit-boundary.sh check-post-edit-diff.sh check-stop-diff-status.sh"
+_plugin_hook_files_from_scripts="check-git-destructive.sh"
+for _name in $_plugin_hook_files_from_hooks; do
+  [ -f "$REPO_ROOT/scripts/hooks/$_name" ] || continue
+  _sync_ai_loop_file "$REPO_ROOT/scripts/hooks/$_name" "$PLUGIN_HOOKS_DIR" "hooks"
+done
+for _name in $_plugin_hook_files_from_scripts; do
+  [ -f "$REPO_ROOT/scripts/$_name" ] || continue
+  _sync_ai_loop_file "$REPO_ROOT/scripts/$_name" "$PLUGIN_HOOKS_DIR" "hooks"
+done
+# stale 削除（*.sh のみ。hooks.json は手動管理の配布物・.gitkeep は対象外）
+if [ -d "$PLUGIN_HOOKS_DIR" ]; then
+  for _f in "$PLUGIN_HOOKS_DIR"/*.sh; do
+    [ -f "$_f" ] || continue
+    _base="$(basename "$_f")"
+    case " $_plugin_hook_files_from_hooks $_plugin_hook_files_from_scripts " in
+      *" $_base "*) : ;;
+      *)
+        if [ "$DRY_RUN" = "1" ]; then _drylog "WOULD DELETE: hooks/$_base"
+        else rm "$_f"; _log "DELETE: hooks/$_base"; fi
+        changed=1
+        ;;
+    esac
+  done
+fi
```

**Stage 5b の追加差分**（#1079 解消後）:

```diff
-_plugin_hook_files_from_scripts="check-git-destructive.sh"
+_plugin_hook_files_from_scripts="check-git-destructive.sh check-approval-token-write.sh"
```

**付随して必要な事実**:

- **`.gitignore` に阻害なし**（`plugin/` 配下の ignore は `__pycache__` 2 行のみ）。`plugin/plangate/hooks/*.sh` は tracked になる。
- **実行権限に依存しない**。`hooks.json` は `sh "<path>"` 形式で起動するため、marketplace 展開で実行ビットが落ちても動く（`.codex/hooks.json` と同じ流儀）。
- **`hooks.json` 自体は同期対象にしない**。`.claude/settings.example.json` は「利用者が自分で書く雛形」、`hooks/hooks.json` は「plugin 配布物」で、matcher 集合は同じでもパスとコメントの形が違う。機械変換より**手動 1 ファイル + §5 の機械照合**のほうが誤変換リスクが低い。

---

## 2. `plugin/plangate/hooks/hooks.json` の内容

### 2-1. 設計上の決定 3 点

| 決定 | 根拠 |
|---|---|
| **top-level に注記キーを置かない**（`$schema_note` / `$note` / `_comment_` を一切書かない） | **#1078 実測**: `.codex/hooks.json` の `$schema_note` 1 行で **JSON 全体が parse 拒否 → hook 登録 0 件**（`docs/working/TASK-1078/evidence/codex-exec-spike.md:14,48`）。Claude Code 側の未知キー扱いは**未検証**であり、「存在するのに 0 件登録」は本 issue が是正しようとしている症状そのもの。**説明は本書と README に置き、配布 JSON には置かない** |
| **スクリプト位置 = `${CLAUDE_PLUGIN_ROOT}` / project root = hook 内部で解決** | `.codex/hooks.json` の `$(git rev-parse --show-toplevel)` は **bridge スクリプトの位置**を解決しているだけで、`eh-bridge.sh` は内部で `$REPO_ROOT/scripts/hooks/<name>` を再導出する＝**利用者リポジトリに `scripts/hooks/` が実在する前提**。plugin 配布ではこれは成り立たない（先行設計 §7-1） |
| **位置引数を渡さない** | `check-plan-hash.sh:51-52` が `task_id=${PLANGATE_HOOK_TASK:-${1:-}}` / `target_file=${PLANGATE_HOOK_FILE:-${2:-}}` ＝ **env が位置引数に優先**。加えて未設定時は stdin JSON の `tool_input.file_path` を jq/python3 で読む（L60-73）。`settings.example.json` の `${PLANGATE_HOOK_TASK:-} ${PLANGATE_HOOK_FILE:-}` は shell 展開に依存する形で、plugin 側の placeholder 展開規則は未検証のため**渡さないほうが安全**（機能は落ちない） |

### 2-2. matcher 配置（`.claude/settings.example.json` の 11 配線との差分）

| # | 配線（settings.example.json） | plugin hooks.json | 差分理由 |
|---|---|---|---|
| 1 | SessionStart → `gh-pin-account.sh` | **載せない** | §1-2 #11（導入先の gh account を書き換える） |
| 2 | PreToolUse `Edit\|Write` → `check-plan-exists.sh` | 同一 | — |
| 3 | PreToolUse `Edit\|Write` → `check-c3-approval.sh` | 同一 | — |
| 4 | PreToolUse `Edit\|Write` → `check-plan-hash.sh`（引数 2 個） | **引数なし**で同一 matcher | §2-1 第 3 行 |
| 5 | PreToolUse `Edit\|Write` → `check-forbidden-files.sh` | 同一 | — |
| 6 | PreToolUse `Bash` → `check-delegation-commit-boundary.sh` | 同一 | — |
| 7 | PreToolUse `Edit\|Write` → `check-approval-token-write.sh` | **Stage 5b** | #1079（jq/sed 不在で fail-closed） |
| 8 | PreToolUse `Bash` → `check-approval-token-write.sh` | **Stage 5b** | 同上 |
| 9 | PreToolUse `Bash` → `check-git-destructive.sh` | 同一 | — |
| 10 | PostToolUse `Edit\|Write\|MultiEdit` → `check-post-edit-diff.sh` | 同一 | — |
| 11 | Stop → `check-stop-diff-status.sh` | 同一（matcher なし） | — |

> **`#1104`（書き込みガードが `Edit|Write` のみで Bash 経路が無防備）は本書では matcher を変更しない。** 変更すると「配布と穴埋めを同一 PR で混ぜる」ことになり、AC-4（上流の退行なし）の切り分けが不能になる。§7 で既知ギャップとして扱う。

### 2-3. Stage 5a の `hooks.json`（全文）

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "sh \"${CLAUDE_PLUGIN_ROOT}/hooks/check-plan-exists.sh\"",
            "timeout": 10
          },
          {
            "type": "command",
            "command": "sh \"${CLAUDE_PLUGIN_ROOT}/hooks/check-c3-approval.sh\"",
            "timeout": 10
          },
          {
            "type": "command",
            "command": "sh \"${CLAUDE_PLUGIN_ROOT}/hooks/check-plan-hash.sh\"",
            "timeout": 15
          },
          {
            "type": "command",
            "command": "sh \"${CLAUDE_PLUGIN_ROOT}/hooks/check-forbidden-files.sh\"",
            "timeout": 10
          }
        ]
      },
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "sh \"${CLAUDE_PLUGIN_ROOT}/hooks/check-delegation-commit-boundary.sh\"",
            "timeout": 10
          },
          {
            "type": "command",
            "command": "sh \"${CLAUDE_PLUGIN_ROOT}/hooks/check-git-destructive.sh\"",
            "timeout": 10
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Edit|Write|MultiEdit",
        "hooks": [
          {
            "type": "command",
            "command": "sh \"${CLAUDE_PLUGIN_ROOT}/hooks/check-post-edit-diff.sh\"",
            "timeout": 10
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "sh \"${CLAUDE_PLUGIN_ROOT}/hooks/check-stop-diff-status.sh\"",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

### 2-4. Stage 5b の追加差分（#1079 解消後）

```diff
       {
         "matcher": "Edit|Write",
         "hooks": [
+          {
+            "type": "command",
+            "command": "sh \"${CLAUDE_PLUGIN_ROOT}/hooks/check-approval-token-write.sh\"",
+            "timeout": 10
+          },
           {
             "type": "command",
             "command": "sh \"${CLAUDE_PLUGIN_ROOT}/hooks/check-plan-exists.sh\"",
@@
       {
         "matcher": "Bash",
         "hooks": [
+          {
+            "type": "command",
+            "command": "sh \"${CLAUDE_PLUGIN_ROOT}/hooks/check-approval-token-write.sh\"",
+            "timeout": 10
+          },
           {
             "type": "command",
             "command": "sh \"${CLAUDE_PLUGIN_ROOT}/hooks/check-delegation-commit-boundary.sh\"",
```

### 2-5. `timeout` 値の根拠

**既定は 600 秒**（公式 hooks ドキュメント: `command` / `http` / `mcp_tool` の既定 timeout = 600s。`UserPromptSubmit` は 30s、`MessageDisplay` は 10s）。**つまり無宣言の現行 Claude 配線は「10 分ハングしうる」状態**であり、#1101 が指摘した「暴走が block でなくハングになる」は既定値の問題として実在する。

本 worktree（`01c8946`）での実測（wall clock・`sh <hook>` 直接起動・env は unset）:

| hook | 実測 | 宣言値 | 根拠 |
|---|---:|---:|---|
| `check-stop-diff-status.sh` | **1.49 s** | 10 | 最遅。`git status --short` + `git diff --check`。**利用者リポジトリのサイズに比例**するため実測の ~7 倍を確保 |
| `check-plan-exists.sh` | 0.87 s | 10 | stdin 読取 + jq/python3 fallback |
| `check-forbidden-files.sh` | 0.44 s | 10 | python3 で YAML parse |
| `check-plan-hash.sh`（HO ヒット） | 0.30 s | **15** | HO 経路は最短。**非 HO 経路は python3 起動 ×3 + `flock` + maintenance token 消費**を通るため単独で長い。`.codex/hooks.json` の既存値（15）と同値に揃え、経路間で説明のつかない非対称を作らない |
| `check-approval-token-write.sh` | 0.13 s | 10 | jq 1 回 |

**方針**: `.codex/hooks.json` が既に採用している **10 / 15** を Claude 側にもそのまま採る。値を独自に最適化すると「同じ hook が経路ごとに違う上限を持つ」状態を新たに作る（#1144 が問題視した非対称の再生産）。

> ⚠️ **timeout 打ち切り時の rc がどう扱われるか（block か素通りか）は未検証**（§6-4）。「timeout を宣言したからハングが block になる」は**まだ実測されていない仮説**であり、AC で確定させる。

---

## 3. `plugin/plangate/.claude-plugin/plugin.json` への `hooks` 宣言

```diff
--- a/plugin/plangate/.claude-plugin/plugin.json
+++ b/plugin/plangate/.claude-plugin/plugin.json
@@
   "skills": "./skills/",
+  "hooks": "./hooks/hooks.json",
   "repository": "https://github.com/s977043/plangate",
```

- 公式ドキュメントは `hooks` を **文字列パス**（`"./config/hooks.json"`）または **インラインオブジェクト**として受ける。**パス指定を採る**（インラインだと manifest が肥大し、`hooks.json` 単体の JSON 検証・差分レビューができなくなる）。
- **`.codex-plugin/plugin.json` は変更しない。** Codex は `.codex/hooks.json` + `eh-bridge.sh` 経路を持ち、plugin 経由で hook を配らない。
- **parity 検査は落ちない**（**先行設計 §6-2 の「無記載だと parity 検査が落ちる」は誤り**）。`scripts/check-plugin-manifest-parity.sh` の比較対象は **`name` / `version` / `skills` の 3 フィールドのみ**（同スクリプト L: `for field, transform in (('name',...), ('version',...), ('skills', norm_skills))`）。`hooks` は比較対象外なので除外記述を足す必要もない。
  - ただし **`docs/ai/settings-wiring-contract.md` §Codex CLI parity に「hook の配布経路は Claude=plugin / Codex=`.codex/` で非対称」と 1 行残す**こと（無記載だと次の担当者が「parity 漏れ」と誤読する）。

---

## 4. ドキュメントの追従

### 4-1. `plugin/plangate/README.md:298-310`「Hooks の設定について」

```diff
 ## Hooks の設定について

-`plugin/plangate/hooks/` は現バージョンでは **reserved（未実装）** です。
-
-EH-1/2/3/6/9 などの Hook を使用するには、別途手動設定が必要です:
-
-1. `.codex/hooks/` に hook スクリプトを配置（Codex 用）
-2. `.claude/settings.json` の `hooks` セクションに hook を登録（Claude Code 用）
-
-詳細は [`docs/ai/settings-wiring-contract.md`](../../docs/ai/settings-wiring-contract.md) を参照してください。
+本プラグインは **enforcement 層（hook）を同梱して配布** します（v8.21.0 / #1144）。
+`plugin/plangate/hooks/hooks.json` が `${CLAUDE_PLUGIN_ROOT}/hooks/*.sh` を起動するため、
+**プラグインを有効化すれば追加の手動配線なしで発火します**（`.claude/settings.json` への
+コピーは不要）。
+
+### 配布される hook（8 本 + root 解決ヘルパー）
+
+| Event / matcher | hook | 役割 |
+|---|---|---|
+| PreToolUse `Edit\|Write` | `check-plan-exists.sh` | EH-1 plan.md 不在検知 |
+| PreToolUse `Edit\|Write` | `check-c3-approval.sh` | EH-2 C-3 承認ゲート |
+| PreToolUse `Edit\|Write` | `check-plan-hash.sh` | **EH-3 Hardening Override + plan_hash 改竄検知** |
+| PreToolUse `Edit\|Write` | `check-forbidden-files.sh` | EH-6 scope 外編集検知 |
+| PreToolUse `Bash` | `check-delegation-commit-boundary.sh` | EH-9 委譲 commit/push 境界 |
+| PreToolUse `Bash` | `check-git-destructive.sh` | EH-12 protected branch の破壊的 git 操作 |
+| PostToolUse `Edit\|Write\|MultiEdit` | `check-post-edit-diff.sh` | 編集直後の whitespace / conflict marker 検査 |
+| Stop | `check-stop-diff-status.sh` | セッション停止時の軽量 verify（**常時 non-blocking**） |
+| （内部） | `_plangate-root.sh` | 各 hook が source する project root 解決ヘルパー |
+
+### 配布されない hook（10 本）
+
+| hook | 配布しない理由 |
+|---|---|
+| `check-test-cases.sh`（EH-4）/ `check-verification-evidence.sh`（EH-5）/ `check-merge-approvals.sh`（EH-7）/ `check-v3-review.sh`（EHS-1）/ `check-handoff-elements.sh`（EHS-2）/ `check-fix-loop.sh`（EHS-3） | **`bin/plangate` からのみ起動**され、その `bin/plangate` は本プラグインでは配布されない（[#1057](https://github.com/s977043/plangate/issues/1057)）。CLI 配布後に同梱予定 |
+| `check-approval-token-write.sh`（EH-13） | `jq` / `sed` 不在時に **fail-closed で Edit/Write/Bash を全停止**するため、導入導線の前提整備（[#1079](https://github.com/s977043/plangate/issues/1079)）完了後に同梱 |
+| `check-metrics-privacy.sh`（EH-8） | CI workflow / `codex-guarded.sh` / `doctor` 経路の資産で、Claude harness の hook ではない |
+| `check-ai-memory-pollution.sh` | git `pre-commit` 用（`scripts/templates/pre-commit.sample`）。Claude hook ではない |
+| `cursor-adapter.sh` | Cursor 用ブリッジ。`.cursor/hooks/*.sh` が利用者リポジトリ側のパスを `exec` するため plugin 経由では到達しない |
+| `gh-pin-account.sh` | **既定で `gh` の active account を上流メンテナのアカウントへ切り替える**ため、配布すると利用者の認証状態を壊す |
+
+### 前提コマンド
+
+| コマンド | 必須 | 不在時の挙動 |
+|---|---|---|
+| `sh` / `git` | 必須 | 非 git ディレクトリでは git 系 hook は no-op |
+| `python3` | **実質必須** | `check-forbidden-files.sh` / `check-plan-hash.sh` の判定本体が python3 |
+| `jq` | 推奨 | 不在時は python3 / grep fallback（EH-13 を同梱する将来版では**必須**） |
+| `sha256sum` または `shasum` | 必須 | plan_hash 突合に使用 |
+
+詳細な配線契約は
+[settings-wiring-contract.md](https://github.com/s977043/plangate/blob/main/docs/ai/settings-wiring-contract.md)
+を参照してください（**#954 クラス C 是正**: 導入先で解決しない相対リンク
+`../../docs/...` を絶対 URL へ置換）。
+
+> ⚠️ **上流リポジトリ（plangate 本体）で本プラグインを有効化する場合**: `.claude/settings.json`
+> の既存配線と **plugin 側の配線が両方走ります**（公式仕様: plugin の hook は settings 側の
+> 同名ハンドラと別物として扱われる）。二重発火を避けたい場合は settings 側か plugin 側の
+> どちらかに寄せてください。
```

### 4-2. `plugin/plangate/README.md:360`（Troubleshooting「Using hooks」節）

**現行 L352-368 は配布後に虚偽になる。** 特に L360 の「本プラグインを導入するだけなら `jq` / `sed` は不要です」は、hook を配った瞬間に**逆**になる（EH-13 は Stage 5b で同梱され、fail-closed）。

```diff
 ### Using hooks

-Hooks are not implemented in this version (directory structure reserved). Planned for a future release.
-EH-1/2/3/6/9 を使うには `.codex/hooks/` と `.claude/settings.json` の手動設定が必要です（上記「Hooks の設定について」を参照）。
-
-> **前提コマンド（フック配線を行う場合のみ）**: **`jq` と `sed` が PATH に必要**です。
-> EH-13（承認トークン書き込みガード）は v8.19.0 で fail-closed 化され、いずれかが不在だと
-> **判定不能として `exit 2`（block）** します（PlanGate 本体リポジトリの
-> `scripts/check-approval-token-write.sh` にある `command -v jq` / `command -v sed`）。
-> 結果として **Edit / Write と Bash が止まります**（EH-13 の matcher は `Edit|Write` と `Bash`）。
->
-> **本プラグインを導入するだけなら `jq` / `sed` は不要です** — プラグインが配布するのは
-> skill / agent / command / rules であり、**フックは配布しない**ためです
-> （`claude plugin details plangate@plangate` の Component inventory が `Hooks (0)` を返す）。
->
-> 回避策と移行手順は
-> [CHANGELOG v8.19.0 の「⚠️ 更新前に必ずお読みください」](https://github.com/s977043/plangate/blob/main/CHANGELOG.md)
-> を参照してください。
+Hooks are bundled and wired via `hooks/hooks.json` (#1144). 有効化されているかは
+`claude plugin details plangate@plangate` の Component inventory が **`Hooks (8)`**
+を返すことで確認できます（`Hooks (0)` なら `plugin.json` の `hooks` 宣言か
+`hooks/hooks.json` の JSON parse を疑ってください）。
+
+> **前提コマンド**: **`python3` と `sha256sum`（または `shasum`）が PATH に必要**です。
+> `jq` は無くても fallback で動作します（上記「前提コマンド」表を参照）。
+>
+> ⚠️ **EH-13（承認トークン書き込みガード / `check-approval-token-write.sh`）を同梱する版
+> （Stage 5b・#1079 対応後）では `jq` と `sed` が必須**になります。v8.19.0 で fail-closed
+> 化されており、いずれかが不在だと **判定不能として `exit 2`（block）** し、結果として
+> **Edit / Write と Bash が止まります**。導入前に `command -v jq` / `command -v sed` を
+> 確認してください。
+>
+> 回避策と移行手順は
+> [CHANGELOG v8.19.0 の「⚠️ 更新前に必ずお読みください」](https://github.com/s977043/plangate/blob/main/CHANGELOG.md)
+> を参照してください。
```

### 4-3. 配布チェックリスト（`plugin/plangate/README.md:319` 付近）

```diff
-- [ ] **hooks 配線状況の明示**: `plugin/plangate/hooks/` が reserved である旨を明記済み
+- [ ] **hooks 同梱の実測**: `plugin/plangate/hooks/` に `hooks.json` + 同梱 `*.sh` が実在し、
+      `sh scripts/check-settings-wiring.sh --target plugin` が PASS すること
+- [ ] **hooks の実発火確認**: クリーンな別ディレクトリで HO パスへの書き込みが
+      **`HARDENING_OVERRIDE` を出力して block** されること（rc だけで判定しない / 本書 §5）
+- [ ] **未配布 hook の明示**: README「配布されない hook」表が `scripts/hooks/` の実態と一致すること
```

### 4-4. 3 導入経路の到達表（AC-10）— README へ追加

| 経路 | agents / skills / commands / rules | **hooks** | `bin/plangate` |
|---|:--:|:--:|:--:|
| marketplace（`/plugin marketplace add` → install） | ○ | **○（本 patch 後）** | ✗（#1057） |
| `install.sh` | ○ | **○（下記差分適用後）** | ✗（#1057） |
| 手動 `cp -r` | ○（README 案内の 4 dir） | **○（案内に `hooks` を追加）** | ✗ |

`install.sh` 差分:

```diff
-  for dir in agents skills commands rules; do
+  for dir in agents skills commands rules hooks; do
```

> ⚠️ **`install.sh` 経路は「コピー先が `<project>/.claude/hooks/`」であり、そこに置いても Claude Code は自動配線しない**（settings.json / plugin manifest のどちらからも参照されない）。**コピーするだけでは効かない**ため、README の `install.sh` 節に「`hooks` は marketplace 経由でのみ自動配線される。`install.sh` 経路では `.claude/settings.json` への手動配線が別途必要」と明記すること。**ここを書かないと「配った＝効いた」の誤認を新たに作る。**

---

## 5. 検証設計

### 5-1. 判定原則（3 つ・いずれも実測由来）

1. **`rc` だけで判定しない。** `scripts/hooks/*.sh` の HO `case` を削除した複製でも **7 件すべて rc=2 のまま**になる（非 `.md` は SKIP 拒否で 2 を返すため）。**判定は出力文字列 `HARDENING_OVERRIDE` の有無で行う。**
2. **env を unset して実行する。** `target_file=${PLANGATE_HOOK_FILE:-${2:-}}`（`check-plan-hash.sh:52`）で **env が位置引数に優先**するため、汚染されたセッション env のまま測ると別のものを測る。`PLANGATE_HOOK_FILE` / `PLANGATE_HOOK_STRICT` / `PLANGATE_BYPASS_HOOK`（加えて `PLANGATE_HOOK_TASK` / `PLANGATE_SKIP_REASON`）を **`env -u` で落とす**。
3. **絶対パスで測る。** Claude Code が `tool_input.file_path` に渡すのは絶対パス。相対パスで測ると HO が効いているように見える（issue の訂正コメントで実証済み）。

### 5-2. 手順（クリーンな別ディレクトリ）

```sh
# --- 準備: 上流とは無関係の空プロジェクトを作る ---
CLEAN=$(mktemp -d)
git -C "$CLEAN" init -q
mkdir -p "$CLEAN/docs/working"
printf '# consumer project\n' > "$CLEAN/CLAUDE.md"

# --- 配布物を「plugin インストール先」の形で配置する ---
PLUGROOT=$(mktemp -d)/plangate
mkdir -p "$PLUGROOT"
cp -R plugin/plangate/hooks "$PLUGROOT/hooks"
cp -R plugin/plangate/.claude-plugin "$PLUGROOT/.claude-plugin"
```

| TC | 目的 | 実行 | 合格条件 |
|---|---|---|---|
| **P-1** | `hooks.json` が JSON として妥当 | `python3 -c "import json;json.load(open('plugin/plangate/hooks/hooks.json'))"` | rc=0 |
| **P-2** | manifest 宣言 | `python3 -c "import json;d=json.load(open('plugin/plangate/.claude-plugin/plugin.json'));assert d['hooks']=='./hooks/hooks.json'"` | rc=0 |
| **P-3** | 参照 ↔ 実体の一致 | `hooks.json` の全 `command` から basename を抽出し、`plugin/plangate/hooks/` に実在するか照合（§5-4 の機械検査） | 不足 0 |
| **P-4** | **HO block（中核・AC-2）** | `env -u PLANGATE_HOOK_FILE -u PLANGATE_HOOK_STRICT -u PLANGATE_BYPASS_HOOK -u PLANGATE_HOOK_TASK -u PLANGATE_SKIP_REASON CLAUDE_PROJECT_DIR="$CLEAN" PLANGATE_HOOK_FILE="$CLEAN/CLAUDE.md" sh "$PLUGROOT/hooks/check-plan-hash.sh"` | **stdout/stderr に `HARDENING_OVERRIDE` を含み** rc=2 |
| **P-5** | **`docs/working/TASK-XXXX/` 不在でも通さない（AC-3）** | P-4 と同じで `CLAUDE_PROJECT_DIR` 配下に TASK ディレクトリを作らない | 同上（`DOC_LIGHT_SKIP` が出たら **FAIL**） |
| **P-6** | **root 未解決の fail-closed** | `env -u CLAUDE_PROJECT_DIR ...` かつ cwd を **非 git ディレクトリ**にして P-4 を再実行 | rc=2 かつ root 未解決メッセージ。**`DOC_LIGHT_SKIP` / rc=0 なら FAIL** |
| **P-7** | ヘルパー欠落時の fail-closed | `$PLUGROOT/hooks/_plangate-root.sh` を退避して P-4 | rc=2 かつ `_plangate-root.sh not found` |
| **P-8** | **検出力（変異注入 / AC-5）** | `$PLUGROOT/hooks/check-plan-hash.sh` の HO `case` から `AGENTS.md\|CLAUDE.md)` 行を削除した複製で P-4 | **`HARDENING_OVERRIDE` が出力されないこと**（＝TC が FAIL する）を確認。**rc は 2 のままなので rc では検出できない** |
| **P-9** | 上流の退行なし（AC-4） | `sh tests/hooks/run-tests.sh` / `sh tests/run-tests.sh` | 着手時 baseline に対し**新規 FAIL 0**（絶対件数は契約値にしない） |
| **P-10** | **harness 実発火（AC-1）** | `$CLEAN` で Claude Code を起動 → plugin を有効化 → `CLAUDE.md` への Write を試行 | **ツール呼び出しが block され**、`claude plugin details plangate@plangate` が `Hooks (8)` を返す |

> **P-10 が本体である。** P-1〜P-9 は「スクリプト単体で正しく振る舞う」ことしか示さない。**「配置されている」ではなく「block した」**を証跡にするのが AC-1 の要求であり、それを満たすのは P-10 だけ。**P-10 の証跡には、block されたときの harness 側メッセージ全文を貼ること。**

### 5-3. 二重発火の確認（上流リポジトリ・新規）

上流 plangate では `.claude/settings.json` の 11 配線と plugin 配線が**両方走る**（§6-3）。以下を測る:

- `docs/working/_audit/hook-events.log` の当該 hook 行が **1 回の Edit で 2 行**増えるか
- 2 重に block メッセージが出るか（UX 劣化）
- **`check-fix-loop.sh` は同梱しないため、状態ファイルの二重 increment は起きない**（同梱判断の副次的な妥当性）

### 5-4. `scripts/check-settings-wiring.sh` への `--target plugin` 追加（AC-6）

現行は `--target user|example` で `.claude/settings*.json` の `hooks.PreToolUse[].hooks[].command` を部分文字列照合している（同スクリプト L14-16 / L36-70）。**同じ照合器に第 3 の target を足すだけ**で「経路ごとに 1 行」（#984 の形）が成立する。

```diff
 case "$target" in
   user) F="$ROOT/.claude/settings.json" ;;
   example) F="$ROOT/.claude/settings.example.json" ;;
-  *) printf 'error: --target must be user|example\n' >&2; exit 2 ;;
+  plugin) F="$ROOT/plugin/plangate/hooks/hooks.json" ;;
+  *) printf 'error: --target must be user|example|plugin\n' >&2; exit 2 ;;
 esac
```

python 側（要点のみ）:

```diff
 checks = [
     ("check-plan-exists.sh", "Edit|Write", "EH-1 plan-exists"),
     ("check-c3-approval.sh", "Edit|Write", "EH-2 c3-approval"),
     ("check-forbidden-files.sh", "Edit|Write", "EH-6 forbidden-files"),
     ("check-plan-hash.sh", "Edit|Write", "EH-3 plan-hash"),
-    ("${PLANGATE_HOOK_FILE:-}", "Edit|Write", "EH-3 の PLANGATE_HOOK_FILE 引数(P4(d)/AC-8)"),
     ("check-delegation-commit-boundary.sh", "Bash", "EH-9 delegation-commit-boundary"),
 ]
+if target != "plugin":
+    # plugin 経路は位置引数を渡さない（env / stdin 経由。本書 §2-1）
+    checks.append(("${PLANGATE_HOOK_FILE:-}", "Edit|Write", "EH-3 の PLANGATE_HOOK_FILE 引数(P4(d)/AC-8)"))
+
+if target == "plugin":
+    # 参照 ↔ 実体の一致（#1144 AC-6）: command が指す basename が配布物に実在するか
+    import os, re
+    hooks_dir = os.path.dirname(os.path.abspath(F))
+    for _matcher, c in cmds:
+        for base in re.findall(r"\$\{CLAUDE_PLUGIN_ROOT\}/hooks/([A-Za-z0-9_.-]+\.sh)", c):
+            if not os.path.isfile(os.path.join(hooks_dir, base)):
+                miss.append(f"配布物欠落: hooks/{base}")
+    # root ヘルパーは全 hook が source するため単独で必須
+    if not os.path.isfile(os.path.join(hooks_dir, "_plangate-root.sh")):
+        miss.append("配布物欠落: hooks/_plangate-root.sh")
+    # timeout 無宣言（既定 600s = 事実上ハング）を検出
+    for blk in pre if isinstance(pre, list) else []:
+        for h in (blk or {}).get("hooks", []) or []:
+            if isinstance(h, dict) and h.get("type") == "command" and "timeout" not in h:
+                miss.append(f"timeout 未宣言: {h.get('command','')[:60]}")
```

> `PostToolUse` / `Stop` も同じ検査に含めるなら、`pre` の収集を `for ev in ("PreToolUse","PostToolUse","Stop")` へ一般化する（現行は PreToolUse のみ）。**この一般化を入れる場合、`--target user|example` の判定結果が変わらないことを先に確認すること**（既存 2 target の挙動不変が AC-4）。

---

## 6. 未確認事項（AC で実測して確定させる）

> **重要**: 以下 3 点は「公式ドキュメントで確認できなかった」という前提で渡されたが、**公式ドキュメントには記述があった**（§7-2 の食い違い）。ただし **記述と実挙動の一致は未実測**であり、#1078（「宣言はあるが登録 0 件だった」）の実績がある以上、**ドキュメントの記述を根拠に AC を省略してはならない**。

| # | 論点 | 公式ドキュメントの記述 | 実測での確定方法 |
|---|---|---|---|
| **U-1** | plugin hook はインストールだけで有効になるか（利用者 opt-in の要否） | 「plugin をインストール・有効化すれば hook は自動的に有効。追加設定不要」 | **P-10**。加えて `claude plugin details plangate@plangate` の Component inventory が `Hooks (8)` を返すこと（`Hooks (0)` は #1078 型の silent parse 失敗） |
| **U-2** | plugin hook と利用者 `.claude/settings.json` hooks の併存・順序・非ゼロ終了時 | 「マッチする hook は**並列**に走る。同一 handler が複数 settings ファイルにあれば 1 回だけ走るが、**plugin / skill 側のコピーは別物として残る**」＝**両方走る（＝二重発火）** | **§5-3**。監査ログ行数で二重を実測。exit 2 は「その action を block するだけで兄弟 hook は走る」とされる点も併せて確認 |
| **U-3** | `${CLAUDE_PLUGIN_ROOT}` が hook プロセスへ export されるか | 「`CLAUDE_PROJECT_DIR` / `CLAUDE_PLUGIN_ROOT` / `CLAUDE_PLUGIN_DATA` を spawn したプロセスの環境変数として export する」 | P-10 中に `env | grep CLAUDE_` 相当を出力する一時 hook を 1 本足して実測。**先行設計のヘルパーは `$0` 兄弟解決を採っており、U-3 が否定されても成立する**（依存していない） |
| **U-4**（**新規**） | **timeout 打ち切り時の rc 扱い**（block か素通りか） | **記述を確認できず** | 意図的に `sleep 30` する一時 hook を `timeout: 2` で配線し、**ツール呼び出しが止まるか通るか**を実測。**通るなら「timeout 宣言でハングが block になる」は成り立たない**（§2-5 の仮説が崩れる） |
| **U-5**（**新規**） | 既定 timeout 600 秒の実挙動 | 「`command` の既定 timeout は 600 秒」 | U-4 と同じ hook を `timeout` 無宣言で配線し、600 秒近く待たされるかを確認（**現行 Claude 配線 11 本すべてがこの状態**） |

---

## 7. 配布で一緒に配られる既知の穴 — **配布前に閉じるか、既知ギャップとして明記するかの判断が要る**

**本 patch を適用すると、以下の穴も同時に導入先へ配られる。** いずれも本書のスコープでは**閉じていない**（閉じると「配布」と「穴埋め」が同一 PR に混ざり、AC-4 の退行切り分けが不能になる）。**配布を有効化する PR の C-3 で、Human が「先に閉じる / 既知ギャップとして README + CHANGELOG に明記して配る」を選択すること。**

| # | 穴 | 配布後の影響 | 推奨 |
|---|---|---|---|
| **G-1** | **#1101: HO 迂回（`..` traversal / 大小文字）**。`check-plan-hash.sh` の `_norm_target` は小文字化しない（`_tf_lc` の小文字化は plan.md 判定にのみ使われる）。**macOS の大小非区別 FS では `Claude.md` が `CLAUDE.md` に到達しつつ HO をすり抜ける**（issue 実測: どちらも FS 到達可能） | **中核ゲートに穴が空いたまま配る**ことになる。しかも導入先の多くは macOS | **配布前に閉じる**（承認境界そのものの穴。`scripts/hooks/*.sh` = HO → Human 適用） |
| **G-2** | **#1104: 書き込みガード 5 本が `Edit\|Write` のみに配線**（Bash 経路が無防備） | `sh -c 'cat > CLAUDE.md'` 系が素通り。**配布によって「守られている」という期待だけが増える** | 配布前に閉じるのが望ましいが、matcher 追加は誤検出面が広い。**最低限、README の「配布される hook」表に「Bash 経由の書き込みは対象外」と明記** |
| **G-3** | **強制力の非対称**: `check-plan-hash.sh` の plan_hash mismatch は `PLANGATE_HOOK_STRICT=1` 時に **exit 1**（L371-374）。`.codex/hooks/eh-bridge.sh` は rc=1 も deny に変換するが、**Claude Code は rc=1 を non-blocking として扱う**（公式: exit 2 のみ blocking）。**同じ違反が Codex では block・Claude では素通り** | **配布で弱いほう（Claude）が広がる**。`.cursor/rules/plangate.mdc:41` が `PLANGATE_HOOK_STRICT=1` を推奨しているため、推奨に従った利用者ほど落差に当たる | 是正は 1 行（`exit 1` → `exit 2`）だが `PLANGATE_HOOK_STRICT` の 3 mode 意味論に触れる。**別 issue で扱い、本 issue では「既知ギャップ」として明記**するのが妥当 |
| G-4 | `install.sh` 経路は hooks をコピーしても**自動配線されない**（§4-4 の注記） | 「入れたのに効かない」 | README に明記（本書 §4-4 で対応済み） |
| G-5 | 上流リポジトリでの**二重発火**（§5-3 / U-2） | 監査ログ二重・block メッセージ二重 | 実測して README / CHANGELOG に記載 |

---

## 8. 実行した検証コマンドと exit code

すべて worktree `/Users/user/Documents/GitHub/plangate/.claude/worktrees/agent-ab74e0f2b03332bd1`（`01c8946`）内で実行。パイプ末尾に `| head` / `| tail` を置いて rc を判定していない。

| # | コマンド | rc | 結果 |
|---|---|---|---|
| V1 | `ls scripts/hooks/*.sh \| wc -l` | 0 | **17 本**（issue の主張と一致） |
| V2 | `ls -A plugin/plangate/hooks/` | 0 | **`.gitkeep` のみ**（配布 0 本、変わらず） |
| V3 | `cat plugin/plangate/.claude-plugin/plugin.json` | 0 | `hooks` 宣言なし（`skills` のみ） |
| V4 | `grep -n -E 'command -v ...\|bin/plangate\|python3\|sha256sum\|jq \|flock' <10 scripts>` | 0 | **`bin/plangate` の実行は 0 件**（`check-plan-hash.sh:101` は HO パターン文字列 / `check-approval-token-write.sh:353` はメッセージ）。前提どおり |
| V5 | `sed -n '1,40p' scripts/gh-pin-account.sh` | 0 | **`DESIRED_USER=${PLANGATE_GH_USER:-s977043}`**（配布不可の根拠） |
| V6 | `time env -u PLANGATE_HOOK_FILE -u PLANGATE_HOOK_STRICT -u PLANGATE_BYPASS_HOOK -u PLANGATE_HOOK_TASK sh scripts/hooks/check-plan-exists.sh` | **0** | `{"continue":true}` / 0.868 s |
| V7 | `time env -u ... PLANGATE_HOOK_FILE="$PWD/CLAUDE.md" sh scripts/hooks/check-plan-hash.sh` | **2** | **`HARDENING_OVERRIDE: CLAUDE.md は maintenance 窓内でも常時 block`** / 0.298 s（絶対パス + 正規配置で HO が効くことの確認） |
| V8 | `time env -u ... PLANGATE_HOOK_TASK=TASK-0001 PLANGATE_HOOK_FILE="$PWD/README.md" sh scripts/hooks/check-forbidden-files.sh` | 0 | `{"continue":true}` / 0.442 s |
| V9 | `time env -u ... sh scripts/hooks/check-stop-diff-status.sh` | 0 | 1.487 s（**最遅**） |
| V10 | `time env -u ... sh scripts/check-approval-token-write.sh` | **2** | `BLOCK (parse-unknown): empty stdin`（fail-closed の確認）/ 0.129 s |
| V11 | `cat scripts/check-plugin-manifest-parity.sh` | 0 | 比較対象は **name / version / skills の 3 フィールドのみ**（`hooks` 追加は parity に無影響） |
| V12 | `sed -n '19,80p' scripts/check-settings-wiring.sh` | 0 | 現行 target は `user\|example`、照合は `PreToolUse` のみ |
| V13 | `sed -n '95,120p' install.sh` | 0 | `for dir in agents skills commands rules; do`（4 dir） |
| V14 | `grep -n 'hooks\|plugin' .gitignore` | 0 | `plugin/plangate/**/__pycache__` の 2 行のみ。**`hooks/*.sh` を阻害しない** |
| V15 | `git grep -n 'schema_note'` | 0 | #1078 の証跡（`$schema_note` で **JSON 全体 parse 拒否 → hook 登録 0 件**） |
| V16 | 本書 §2-3 の `hooks.json` を一時ファイルへ書き出し `python3 -c "import json; json.load(open(...))"` | **0** | **JSON 構文検証 PASS**（一時ファイルは削除済み） |
| V17 | 同じく §2-4 適用後（EH-13 2 エントリ追加）の全文を検証 | **0** | **JSON 構文検証 PASS**（一時ファイルは削除済み） |
| V18 | 公式ドキュメント参照（plugins-reference / hooks） | — | `hooks` フィールドはパス or インライン / `${CLAUDE_PLUGIN_ROOT}` は hook プロセスへ export / **`timeout` 既定 600 秒** / exit 2 のみ blocking / **plugin hook と settings hook は両方走る** |

---

## 9. 前提として渡された事実との食い違い

| # | 渡された前提 | 実測 | 影響 |
|---|---|---|---|
| **1** | 「`.codex/hooks.json` の形を踏襲する」 | **注記キー（`$schema_note` / `$note`）は踏襲してはならない。** #1078 実測で **JSON 全体が parse 拒否され hook 登録 0 件**になっている。**先行設計 `1144-root-resolution-patch.md` §6-1 の draft `hooks.json` は `$schema_note` を含んでおり、そのまま採用すると同じ事故を Claude 経路で再演する可能性がある** | §2-1 / §2-3 で注記キーを全排除。**先行設計の当該ブロックは本書で置き換える** |
| **2** | 「未確認: plugin hook の自動有効化 / settings hooks との併存 / `${CLAUDE_PLUGIN_ROOT}` の export」 | **3 点とも公式ドキュメントに記述があった**（§6 の U-1/U-2/U-3）。特に **U-2 は「両方走る＝二重発火」** という設計に効く回答 | §6 に記述を明記しつつ、**AC での実測は省略しない**（#1078 の「宣言はあるが 0 件」実績） |
| **3** | 「`timeout` の値の根拠を示すこと（`.codex/hooks.json` は 10）」 | **既定値は 600 秒**（公式）。つまり無宣言は「未設定」ではなく「10 分」。#1101 の「ハングが block にならない」は既定値の帰結として実在 | §2-5。**ただし timeout 打ち切り時の rc 扱いは未確認**（U-4）で、「timeout 宣言 → ハングが block になる」は仮説のまま |
| **4** | （前提外の新規発見）「中核 hook は外部依存が `jq` / `sha256sum` / `sed` / `python3` のみ」 | 一致。ただし **`scripts/gh-pin-account.sh` は `gh` に依存し、かつ既定で上流固有アカウント（`s977043`）へ切り替える** | §1-2 #11。**配布不可**として除外を確定 |
| **5** | （前提外の新規発見）「`plugin.json` に `hooks` を宣言すると parity 検査が落ちるので除外記述が要る」（先行設計 §6-2） | **落ちない。** `check-plugin-manifest-parity.sh` は `name` / `version` / `skills` の 3 フィールドしか比較しない | §3。除外記述は不要。代わりに `settings-wiring-contract.md` に非対称の 1 行を残す |

---

## 10. 責務まとめ

| 作業 | 責務 |
|---|---|
| 本設計書の作成 / 検証 / patch 提示 | **AI-owned**（完了） |
| `scripts/hooks/*.sh`（`_plangate-root.sh` 新設・root 解決適用・G-1 の HO 迂回是正） | **Human-owned**（HO 9 カテゴリ） |
| `.claude/settings.example.json` の `timeout` 追加 | **Human-owned**（HO） |
| `plugin/plangate/hooks/hooks.json` 新設 / `plugin.json` の `hooks` 宣言 / README 更新 | AI-owned |
| `scripts/sync-plugin-plangate.sh` / `install.sh` / `scripts/check-settings-wiring.sh` | AI-owned（**`.sh` の新規作成・編集には `PLANGATE_HOOK_TASK` セッションが必要**） |
| G-1 / G-2 / G-3 を「先に閉じる」か「既知ギャップとして配る」かの判断 | **Human-owned**（C-3） |
| Mode 判定 | **critical**（配布構成の変更 + HO 対象への patch。`lite_eligible=false`・同期 C-3 固定） |
