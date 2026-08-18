# #990 patch — `$var` の直後に全角文字が続くと `set -u` で落ちる（**Human 適用**）

> 対象: `scripts/apply-ui-v1-crossref.sh` / `scripts/ai-dev-workflow`
> **AI は `.sh` / 拡張子なしスクリプトを編集できない**（EH-3 の no-task 経路が `SKIP_REASON` を要求）ため、差分と適用手順を文書として提示する。
> 測定基点: `origin/main` = `1e33b57` / 2026-08-18

## ⚠️ issue 記載より影響が広い — **`bin/plangate gate` / `exec` が実行時に落ちます**

#990 は `scripts/apply-ui-v1-crossref.sh:41` の 1 箇所として起票されていますが、**同じ欠陥が `scripts/ai-dev-workflow` に 2 箇所あり、そちらは PlanGate 本番フローの実行経路**です。

```
scripts/ai-dev-workflow:102   ai_dev_prompt_gate()  内
scripts/ai-dev-workflow:129   ai_dev_prompt_exec()  内
```

呼び出し経路（実測）:

```
:243  printf '%s\n' "$(ai_dev_prompt_gate)" | codex-local.sh ...   ← bin/plangate gate
:261  ai_dev_launch_codex_exec "$(ai_dev_prompt_exec)" ...          ← bin/plangate exec
```

**`scripts/ai-dev-workflow` は冒頭で `set -eu`（`:3`）を宣言**しているため、これらの関数が呼ばれた時点で **`unbound variable` で異常終了**します。

## 原因

**変数名の直後に ASCII 外の文字が続くと、シェルはそのバイトを識別子の一部として解釈します。**

```
"TASK ID は $AI_DEV_TASK。"
             ^^^^^^^^^^^^^ + 。 のバイト列 → 変数名 `AI_DEV_TASK<0xE3>` として解決を試みる
                                          → 未定義 → set -u で abort
```

実測:

```sh
$ sh -c 'set -eu; AI_DEV_TASK=TASK-X; printf "%s\n" "TASK ID は $AI_DEV_TASK。"'
sh: AI_DEV_TASK<0xef>: unbound variable

$ sh -c 'set -eu; _n=3; echo "（count=$_n）"'
sh: _n<0xef>: unbound variable
```

**発火するシェル**: macOS の `/bin/sh`（bash 3.2）/ `bash`。`dash` / `zsh` では発火しません（`#1092` 台帳の記載どおり）。

## なぜ今まで気づかれなかったか

**`--dry-run` が該当関数に到達しません。**

```
$ bin/plangate gate TASK-TEST-990 --dry-run
Would run plan-review-gate for: TASK-TEST-990
rc=0                                          ← 正常終了に見える
```

`--dry-run` は `ai_dev_prompt_gate()` を呼ばずに早期 return するため、**dry-run では健全に見え、実走で初めて落ちます**。

関数を直接呼ぶと再現します:

```sh
$ awk '/^ai_dev_prompt_gate\(\)/,/^}/' scripts/ai-dev-workflow > /tmp/_g.sh
$ sh -c 'set -eu; AI_DEV_TASK=TASK-X; . /tmp/_g.sh; ai_dev_prompt_gate'
/tmp/_g.sh: line 2: AI_DEV_TASK<0xef>: unbound variable
```

## 正しい書き方（**リポジトリ内に正本あり**）

`scripts/check-git-destructive.sh:202-203` が既にこの危険を明文化しています:

```sh
# 注: 変数の直後に全角文字が続くと識別子の一部として解釈されるため
# （`$destructive）` は unbound variable になる）、必ず ${...} で囲む。
```

→ **`${...}` で囲む**のが確立された対処です。

---

## 差分

### 1. `scripts/ai-dev-workflow`（**最優先** / 2 箇所）

**L102**（`ai_dev_prompt_gate()` 内）

```diff
-    "TASK ID は $AI_DEV_TASK。" \
+    "TASK ID は ${AI_DEV_TASK}。" \
```

**L129**（`ai_dev_prompt_exec()` 内）

```diff
-    "TASK ID は $AI_DEV_TASK。" \
+    "TASK ID は ${AI_DEV_TASK}。" \
```

### 2. `scripts/apply-ui-v1-crossref.sh`（issue の元記載 / 1 箇所）

**L41**

```diff
-  echo "[apply] ERROR: アンカー行が一意に見つかりません（count=$_n）: $ANCHOR" >&2
+  echo "[apply] ERROR: アンカー行が一意に見つかりません（count=${_n}）: $ANCHOR" >&2
```

> このファイルの発火経路は「アンカーが一意に見つからない」エラー時のみです。**エラー処理そのものが落ちる**ため、本来出るはずの診断メッセージが出ません。

---

## 適用手順

```sh
# 1. 上記 3 箇所を編集

# 2. 検証: 該当パターンの残存が 0 件になること
grep -rnP '\$[A-Za-z_][A-Za-z0-9_]*[^\x00-\x7F]' scripts/ tests/ bin/
#    期待: scripts/check-git-destructive.sh:203（注記そのもの）と
#          tests/extras/ta-25-approval-token-guard.sh:56（コメント）のみ

# 3. 再現テスト（修正後は出力されること）
awk '/^ai_dev_prompt_gate\(\)/,/^}/' scripts/ai-dev-workflow > /tmp/_g.sh
sh -c 'set -eu; AI_DEV_TASK=TASK-X; AI_DEV_WORK_DIR=/tmp; ai_dev_repo_root=/tmp; . /tmp/_g.sh; ai_dev_prompt_gate | head -2'

# 4. 全体
sh tests/run-tests.sh   # 単独で実行すること（並行実行は ta-42 / ta-61 で壊れます）
```

## 対象外（触らない）

| ファイル | 理由 |
|---|---|
| `scripts/check-git-destructive.sh:203` | **この危険を注記しているコメント本文**。バッククォート内の例示であり実行されない |
| `tests/extras/ta-25-approval-token-guard.sh:56` | コメント内の変数名表記（`_t25_rc（exit code）`）。実行されない |

## 回帰テストの提案（本 patch には含めない）

**`--dry-run` が該当経路を通らないため、この欠陥は既存テストで検出できません。** 以下のいずれかを別途追加すべきです:

- `ai_dev_prompt_gate` / `ai_dev_prompt_exec` を **`sh` で直接呼ぶ** TC（出力が空でないこと）
- **`grep -P '\$[A-Za-z_][A-Za-z0-9_]*[^\x00-\x7F]'` が実行行に対して 0 件**であることの静的検査

後者は **`scripts/` 全体に効く**ので費用対効果が高いと考えます。**ただし `--warn-only` にすると意味がありません**（本セッションで `.codex` の drift が `--warn-only` のまま蓄積した実例があります / #956）。

## 責務

| 作業 | 担当 |
|---|---|
| patch の作成・再現手順・検証手順の提示 | **AI-owned**（本書） |
| **`scripts/` への適用** | **Human-owned**（EH-3 が AI の `.sh` 編集を block） |
| 適用後の検証 | Human（または `PLANGATE_HOOK_TASK` 付きセッションの AI） |

Refs #990 / #1092
