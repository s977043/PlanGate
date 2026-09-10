# #1326 — EH-12 の判定を同一コマンドのトークン列へ限定する HO patch

> **対象**: `scripts/check-git-destructive.sh`（Hardening Override。**AI は適用できない**）
> **適用**: Human。適用スクリプト `/tmp/apply-1326-eh12.sh`（`ho-apply-script` の型）
> **issue**: #1326

## 1. 何が壊れているか

`main` にいるとき、**`git push` のトークン列に属さない `--force` / `+` を拾って block する**。

現行の判定は `after`（最初の `git` 以降の**コマンド文字列全体**）に対して `" push "` と
`" --force"` / `" +"` を**独立に**探している。`after` には `&&` / `;` / `|` で区切られた
後続コマンドも、クォートを除去された文字列リテラルも含まれるため、次が誤って block される。

## 2. 実測（現行 hook を実 PreToolUse payload で起動 / `origin/main` = `9f1b9f63` / branch = `main`）

| 期待 | 現行 | コマンド |
| --- | --- | --- |
| allow | **BLOCK** | `git push -q origin docs/x && git worktree remove --force /tmp/w` |
| allow | **BLOCK** | `git push origin HEAD && echo a + b` |
| allow | **BLOCK** | `echo "use git push --force only on branches"` |
| allow | **BLOCK** | `git log --oneline && echo '未 push commit' && echo 'a + b'` |
| allow | **BLOCK** | `git commit -m "do not push --force to main"` |
| allow | **BLOCK** | `git worktree add -f /tmp/w main && git push origin w` |

**positive control**（現行でも正しく BLOCK される。是正後も BLOCK のままでなければならない）:

`git push --force origin main` / `--force-with-lease` / `--force-with-lease=<ref>` /
`--force-if-includes` / `-f` / `git push origin +HEAD:main` / `git reset --hard origin/main` /
`git -C /path push --force` / `git -c user.name=x push --force` / `sh -c "git push --force"` /
`GIT_DIR=/x git push --force` / `command git push --force` / `/usr/bin/git push --force` /
`git status && git push --force origin main` / 連続空白 / 改行区切り。

## 3. 是正の設計

判定を 3 段にする。**block 対象は一切緩めない。**

1. **セグメント分割** — `;` `&&` `||` `|` で分け、git サブコマンドとフラグが
   **同一コマンドのトークン列に属する**ことを要求する
2. **コマンド語の判定** — セグメントの**先頭語**（env 代入 / `command` / `builtin` /
   `exec` / パスを除去後）が `git` のときだけ git 起動と見なす。`norm` はクォートを
   除去済みなので、**文字列リテラルは先頭語でしか実コマンドと見分けられない**
3. **間接起動は fail-closed** — 先頭語が `sh` / `bash` / `zsh` / `env` / `xargs` 等なら
   解釈しきれないので**従来と同じ部分文字列判定へ落とす**（`sh -c "git push --force"`
   の保護を落とさないため）

> **設計上の注意**: 先頭語から env 代入を剥がす処理は「**先頭語が `NAME=...` の形**」に
> 限定すること。緩いパターン（`[A-Za-z_]*=*\ *`）にすると
> `git -c user.name=x push --force` を env 代入と誤認し、**本物の force push を
> 取りこぼす**（実装中に踏んだ。positive control で検出した）。

## 4. patch

以下の marker 間を **awk で抽出**して適用する（`sed -e '1d' -e '$d'` は formatter の
fence 正規化で行数がずれるため使わない）。

<!-- PG-PATCH-BEGIN -->

````diff
diff --git a/scripts/check-git-destructive.sh b/tmp/eh12-new-file.sh
old mode 100755
new mode 100644
index dd052b90..71707596
--- a/scripts/check-git-destructive.sh
+++ b/scripts/check-git-destructive.sh
@@ -139,31 +139,120 @@ norm=$(printf '%s' "$cmd" \
 # --- 破壊的操作の検出（決定論。git サブコマンド + フラグの同時成立を要求）---
 # 誤検出を避けるため「git トークンが存在」かつ「reset+--hard」または
 # 「push+force 系」の**両方**が揃ったときだけ destructive と見なす。
-destructive=""
-case " $norm " in
-  *" git "*|*"/git "*)
-    after=" ${norm#*git } "
-    case "$after" in
-      *" reset "*)
-        case "$after" in
-          *" --hard"*) destructive="git-reset-hard" ;;
-        esac
-        ;;
-    esac
-    if [ -z "$destructive" ]; then
-      case "$after" in
-        *" push "*)
-          case "$after" in
-            # --force / --force-with-lease / --force-if-includes / -f
-            *" --force"*|*" -f "*) destructive="git-push-force" ;;
-            # refspec 先頭 `+` による強制更新（例: git push origin +HEAD:main）
-            *" +"*) destructive="git-push-force-refspec" ;;
+#
+# (#1326) 「両方が揃った」の判定を **同一コマンドのトークン列**に限定する。
+# 以前は最初の `git` 以降の文字列全体を 1 塊として見ていたため、
+#   - `&&` / `;` / `|` で区切られた **後続コマンド**の `--force`
+#   - `echo "... git push --force ..."` のような **データとして現れる文字列**
+#     （`norm` はクォートを除去済みなので、実コマンドと見分けがつかない）
+#   - refspec ではない ` +`（例: `echo a + b`）
+# を拾って、破壊的でないコマンドを block していた（実測 6 クラス）。
+#
+# 判定は 3 段。
+#   1. `;` `&&` `||` `|` でセグメントへ分割する
+#   2. セグメントの**先頭語**（env 代入 / command / builtin / exec / パスを除去後）が
+#      `git` のときだけ git 起動と見なし、グローバルオプションを読み飛ばして
+#      サブコマンドを取り、**そのセグメントのフラグだけ**を検査する
+#   3. 先頭語が `sh` / `bash` / `env` / `xargs` 等の**間接起動**なら、解釈しきれない
+#      ので **従来と同じ部分文字列判定へ落とす**（fail-closed。`sh -c "git push
+#      --force"` の保護を落とさない）
+#
+# block 対象は一切緩めない（--force / --force-with-lease[=<ref>] /
+# --force-if-includes / -f / refspec 先頭 `+` / reset --hard）。
+_eh12_classify() {
+  _n=" $1 "
+  _segs=$(printf '%s' "$_n" \
+    | sed -e 's/||/\n/g' -e 's/&&/\n/g' -e 's/;/\n/g' -e 's/|/\n/g')
+
+  printf '%s\n' "$_segs" | while IFS= read -r _s; do
+    [ -n "$_s" ] || continue
+    _seg=" $_s "
+
+    # 先頭語を取る。`git -c user.name=x push` の `-c user.name=x` を env 代入と
+    # 誤認しないよう、代入の剥がしは「先頭語が NAME=... の形」に限定する。
+    _rest=$_s
+    while :; do
+      _rest=$(printf '%s' "$_rest" | sed -e 's/^[[:space:]]*//')
+      _w0=${_rest%% *}
+      case "$_w0" in
+        command)  _rest=${_rest#command } ; continue ;;
+        builtin)  _rest=${_rest#builtin } ; continue ;;
+        exec)     _rest=${_rest#exec } ; continue ;;
+      esac
+      case "$_w0" in
+        *=*)
+          case "$_w0" in
+            [A-Za-z_]*)
+              case "${_w0%%=*}" in
+                *[!A-Za-z0-9_]*) break ;;
+                *) _rest=${_rest#* } ; continue ;;
+              esac
+              ;;
+            *) break ;;
           esac
           ;;
       esac
-    fi
-    ;;
-esac
+      break
+    done
+    _word=${_rest%% *}
+    _base=${_word##*/}
+
+    case "$_base" in
+      git)
+        _args=${_rest#"$_word"}
+        _sub=""
+        # shellcheck disable=SC2086  # 意図的な word splitting（トークン列を得る）
+        set -- $_args
+        while [ $# -gt 0 ]; do
+          case "$1" in
+            -C|-c) shift 2; continue ;;
+            --git-dir=*|--work-tree=*|--namespace=*|-c*|--no-pager|--paginate|-P|--literal-pathspecs|--exec-path=*)
+              shift; continue ;;
+            --git-dir|--work-tree|--namespace|--exec-path) shift 2; continue ;;
+            -*) shift; continue ;;
+            *) _sub=$1; shift; break ;;
+          esac
+        done
+        _flags=" $* "
+        case "$_sub" in
+          reset)
+            case "$_flags" in *" --hard"*) printf 'git-reset-hard\n'; return 0 ;; esac
+            ;;
+          push)
+            case "$_flags" in
+              *" --force"*|*" -f "*) printf 'git-push-force\n'; return 0 ;;
+            esac
+            case "$_flags" in
+              *" +"*) printf 'git-push-force-refspec\n'; return 0 ;;
+            esac
+            ;;
+        esac
+        ;;
+      sh|bash|zsh|ksh|dash|env|xargs|eval|nohup|timeout|sudo|ssh)
+        case "$_seg" in
+          *" git "*|*"/git "*)
+            _after=" ${_seg#*git} "
+            case "$_after" in
+              *" reset "*)
+                case "$_after" in *" --hard"*) printf 'git-reset-hard\n'; return 0 ;; esac
+                ;;
+            esac
+            case "$_after" in
+              *" push "*)
+                case "$_after" in
+                  *" --force"*|*" -f "*) printf 'git-push-force\n'; return 0 ;;
+                  *" +"*) printf 'git-push-force-refspec\n'; return 0 ;;
+                esac
+                ;;
+            esac
+            ;;
+        esac
+        ;;
+    esac
+  done | head -1
+}
+
+destructive=$(_eh12_classify "$norm")
 
 if [ -z "$destructive" ]; then
   emit_judgment "allow"
````

<!-- PG-PATCH-END -->

## 5. Human 適用手順

```sh
sh /tmp/apply-1326-eh12.sh              # 適用 + 検証
sh /tmp/apply-1326-eh12.sh --verify     # 検証のみ
sh /tmp/apply-1326-eh12.sh --rollback   # 戻す
```

適用後は `tests/fixtures/eh12-token-scope-pending-1326.flag` を**同じ commit で削除**する
（残すと `ta-86` の stale flag 検査が FAIL する）。

**適用スクリプトは commit も push もしない。**

## 6. 検証済み事項

| 検証 | 結果 |
| --- | --- |
| `git apply --check`（fwd） | rc=0 |
| `git apply --check -R`（未適用ツリー） | rc=1（未適用の確認） |
| `git diff --numstat` | `+111 -22` / 1 ファイル |
| `sh -n`（是正後ファイル） | rc=0 |
| **実 hook での end-to-end 対照（29 ケース）** | **現行 = 6 件誤 BLOCK / 是正後 = 0 件** |
| 本物の破壊的操作 16 ケース | **現行・是正後とも 16/16 BLOCK**（緩めていない） |
| `ta-86` | 適用前 / 適用後のどちらでも緑（2 レーン方式） |

## 7. スコープ外

- **protected branch の判定ロジック**は変更しない
- EH-9（`check-delegation-commit-boundary.sh`）と pre-push hook は変更しない
- 間接起動（`sh -c` 等）の**中身の解釈**は行わない。従来どおり部分文字列判定へ落とす
  ため、`sh -c "git push -q origin x && git worktree remove --force /tmp/w"` のような
  **間接起動の中の誤検知は残る**（fail-closed 側なので安全側の残存）
