# \#1277 — worktree 配下の Hardening Override が block されない欠陥の HO patch

> **種別**: HO patch 文書（`scripts/hooks/**` は Hardening Override 対象のため実ファイルを
> 直接編集していない）。適用は Human-owned。
> **対象**: `scripts/hooks/check-plan-hash.sh`（EH-3）
> **base**: `756aa254bd5c266cd2e8730216ee31c83d873d8c`（`main` / `origin/main`）
> **関連**: #1277（本体）/ #1234（`OUTSIDE_REPO_SKIP`）/ #1101（字句正規化）/ #1226（PATCH-C の
> `_ho_key` ↔ `_phys_key` 非対称）

## 1. 欠陥

linked worktree 配下の HO 対象ファイルが **block されず素通り**する。

`(i-c) repo containment 判定`（#1234 導入）は 4 値 `INSIDE| / OUTSIDE| / UNSURE| / WORKTREE|`
を返すが、シェル側の `case "$_pg_contain"` に **`WORKTREE|*` の枝が無い**。したがって
`_phys_target` が空のまま HO 判定へ入り、`_ho_key`（字句）は repo root を除去できない
絶対パスのままなので HO 12 カテゴリのどれにも一致せず、`.md` は `DOC_LIGHT_SKIP`、
それ以外は `SKIP` で **rc=0** になる。

さらに実運用上より重い第 2 のクラスがある。本 repo の worktree は
**`.claude/worktrees/<name>/` = REPO_ROOT の内側**に置かれる（実測 60 本以上）。この場合
containment 判定は `WORKTREE|` ではなく **`INSIDE|.claude/worktrees/<name>/…`** を返すため、
`_phys_key` は `.claude/worktrees/` 前置のまま HO パターンに一致しない。**`WORKTREE|*` の
枝を足すだけでは実運用形態は塞がらない**。

| クラス | 例 | 修正前 |
| --- | --- | --- |
| A: REPO_ROOT **外** の linked worktree | `/tmp/wtprobe/.claude/rules/x.md` | `WORKTREE\|` → 枝が無く素通り (rc=0) |
| B: REPO_ROOT **内** の linked worktree（実運用） | `<root>/.claude/worktrees/agent-X/.claude/rules/x.md` | `INSIDE\|.claude/worktrees/…` → HO 非一致 (rc=0) |

## 2. 設計

**採用**: containment 判定の python で、`full` を含む **最も内側の git 作業ツリー root**
（`.git` が dir または file として存在する最初の祖先）を求め、その `.git` の
`gitdir → commondir` が REPO_ROOT の common dir と **一致し、かつ REPO_ROOT 自身でない**
ときだけ `WORKTREE|<worktree root からの相対パス>` を返す。判定は **INSIDE / OUTSIDE の前**
に置く（クラス B を拾うため）。シェル側は `WORKTREE|*` を `INSIDE|*` と同じく
`_phys_target` に載せ、既存の `_phys_key` union（HO 12 カテゴリ / `plan.md`）へ流す。

- **`_ho_key` と `_phys_key` の両方**を直す必要は無い。`_ho_key` は字句専用（FS に触れない
  = Non-goal）であり、worktree は FS 構造でしか判別できない。#1226 PATCH-C の非対称は
  「片方の case ブロックだけ更新した」ことに起因するもので、本 patch は **12 カテゴリの
  正本 case ブロックを一切変更しない**（`_phys_key` 経路に載せるだけ）ため再発しない。
- **`OUTSIDE_REPO_SKIP` を壊さない**: WORKTREE は `OUTSIDE|` に到達する前に確定するので、
  repo 外スクラッチパッド（#1234 の意図的機能）の判定経路は不変。WORKTREE は rc を
  **締める方向にしか動かさない**（SKIP へは倒さない）。
- **他人の worktree / 別 repo を誤って repo 内扱いしない**: `common_dir` の一致を要求する
  ため、別 repo の clone・submodule・vendored `.git`・`.git` を持たない
  `.claude/worktrees/x/` は従来どおり INSIDE / OUTSIDE に倒れる（TC-05a が対照）。
- **コスト**: containment 判定の python3 は **既に毎回起動している**。本 patch は同一
  プロセス内の lexists ループを 1 本足すだけで、**外部プロセス起動回数は増えない**。

**棄却した設計**:

| 案 | 棄却理由 |
| --- | --- |
| `git rev-parse --git-common-dir` を呼ぶ | Edit/Write/Bash ごとに `git` プロセスが増える。hook に timeout が無く（#1101 Step 7）、fork 増は暴走ではなくハングの側に効く |
| `git worktree list` を呼んで前方一致 | 同上に加え、worktree 60 本の列挙を毎回行う。REPO_ROOT 側の `.git` に依存し、worktree 内から起動されたときの共有 common dir 解決が別問題になる |
| `_ho_key` の case に `.claude/worktrees/*/` 前置パターンを足す | クラス A（root 外 worktree）を塞げない。かつ 12 カテゴリ正本の case ブロックを増殖させ #1226 の非対称を再生産する |
| `.claude/worktrees/` をパス名で worktree とみなす | `.git` を持たない同名ディレクトリを誤 block する（TC-05a が反証） |

## 3. 実測（外部 clone / `git clone --no-hardlinks --no-local`）

sandbox: `/tmp/pg1277/src`（clone, HEAD `756aa254`）+ `git worktree add --detach`
で `/tmp/pg1277/wt`（root 外）と `/tmp/pg1277/src/.claude/worktrees/nested`（root 内）。

| # | ケース | 修正前 | 修正後 |
| --- | --- | --- | --- |
| 1 | 実 repo `.claude/rules/mode-classification.md` | rc=2 HARDENING_OVERRIDE | **rc=2（不変）** |
| 2 | root 外 worktree `.claude/rules/mode-classification.md` | rc=0 DOC_LIGHT_SKIP | **rc=2 HARDENING_OVERRIDE** |
| 2b | root 外 worktree `scripts/hooks/check-plan-hash.sh` | rc=0 SKIP | **rc=2 HARDENING_OVERRIDE** |
| 3 | repo 外 `/tmp/…/foo.txt` | rc=0 OUTSIDE_REPO_SKIP | **rc=0 OUTSIDE_REPO_SKIP（不変）** |
| 4 | symlink → repo 内 HO | rc=2 HARDENING_OVERRIDE | **rc=2（不変）** |
| 4b | symlink → root 外 worktree HO | rc=0 DOC_LIGHT_SKIP | **rc=2 HARDENING_OVERRIDE** |
| 5a | 実 repo 非 HO `.md`（`docs/plangate.md`） | rc=0 DOC_LIGHT_SKIP | **rc=0（不変）** |
| 5b | root 外 worktree 非 HO `.md` | rc=0 DOC_LIGHT_SKIP | **rc=0（不変）** |
| 6a | 実 repo 非 HO 非 `.md`（`package.json`） | rc=0 SKIP | **rc=0（不変）** |
| 6b | root 外 worktree 非 HO 非 `.md` | rc=0 SKIP | **rc=0（不変）** |
| 7 | 実 repo `plan.md`（no-task） | rc=2 | **rc=2（不変）** |
| 8 | worktree `plan.md`（no-task） | rc=2 | **rc=2（不変）** |
| 9 | repo 外の HO 同名 `.claude/rules/x.md` | rc=0 OUTSIDE_REPO_SKIP | **rc=0（不変）** |
| N1 | **root 内 worktree** `.claude/rules/mode-classification.md` | rc=0 DOC_LIGHT_SKIP | **rc=2 HARDENING_OVERRIDE** |
| N2 | root 内 worktree `scripts/hooks/check-plan-hash.sh` | rc=0 SKIP | **rc=2 HARDENING_OVERRIDE** |
| N3 | root 内 worktree `CLAUDE.md` | rc=0 DOC_LIGHT_SKIP | **rc=2 HARDENING_OVERRIDE** |
| N4 | root 内 worktree 非 HO `.md` | rc=0 DOC_LIGHT_SKIP | **rc=0（不変）** |
| N5 | root 内 worktree 非 HO 非 `.md` | rc=0 SKIP | **rc=0（不変）** |
| N6 | root 内 worktree `plan.md`（no-task） | rc=2 | **rc=2（不変）** |

### 変異注入（検出力の実証）

| 変異 | 無効化した箇所 | 結果 |
| --- | --- | --- |
| MUT-1 | シェルの `WORKTREE\|*) _phys_target=…` 枝を削除 | ケース 2 / 2b / 4b / N1 / N2 / N3 がすべて **rc=0 に復帰**（1 / 3 / 4 / 5 / 6 は不変） |
| MUT-2 | `_inside` 判定を deferred にせず INSIDE を先に返す | N1 / N2 / N3 が **rc=0 に復帰**（クラス A のケース 2 は rc=2 のまま = 2 つの穴が独立であることの実証） |

### 既存テスト

| テスト | base（未適用） | 適用後 |
| --- | --- | --- |
| `tests/extras/ta-65-eh3-ho-task-context.sh` | 17 passed / 0 failed | **17 passed / 0 failed** |
| `tests/extras/ta-79-eh3-bash-lane.sh` | 50 passed / 0 failed | **50 passed / 0 failed** |
| `tests/extras/ta-80-eh3-outside-repo.sh`（現行） | 40 passed / 0 failed | 38 passed / **2 failed**（TC-05b / TC-08 M-WT が **旧仕様＝縮退**を assert しているため） |
| `tests/extras/ta-80-eh3-outside-repo.sh`（本 PR で更新後） | 40 passed / **5 failed** | **45 passed / 0 failed** |

`ta-80` の更新（`tests/**` は HO 対象外のため本 PR で実ファイルを更新済み）:

- fixture に **root 配下の linked worktree**（`.git` file + `commondir`）を追加
- `TC-05a` は「`.git` を持たない `worktrees/x` は worktree ではない」対照として維持
- `TC-05b` を「root 外 worktree の HO → block」に是正
- `TC-05c/d/e/f` を追加（root 内 worktree HO / HO `.md` / 非 HO `.md` / root 外 worktree 非 HO）
- 変異 `M-WT` を新しい述語に retarget、`M-WT2`（シェル枝の削除）を追加

**未適用状態で `ta-80` が 5 failed になる**＝この patch が入るまでテストが赤で残る（適用漏れを
機械検出できる）。

## 4. この是正が作りうる新しい穴

| リスク | 評価 |
| --- | --- |
| repo 外スクラッチパッドが書けなくなる（#1234 の退行） | **無し**。WORKTREE は git 管理下の worktree にしか成立せず、`/tmp` のスクラッチは OUTSIDE のまま（ケース 3 / 9 実測） |
| 別 repo・submodule を誤って本 repo 扱い | **無し**。`common_dir` 一致を要求（TC-05a が `.git` 無しの対照） |
| worktree 内での正当な非 HO 編集が止まる | **無し**。ケース 5b / 6b / N4 / N5 実測で不変 |
| `d = full if os.path.isdir(full)` により、**worktree root 自体**を対象にした操作の分類が変わる | 変わるのは「worktree root ディレクトリそのもの」を `file_path` に渡した場合のみで、rc は締まる側。実運用の Edit/Write はファイルを指す |
| 実行時間 | 追加は同一 python プロセス内の `lexists` ループ（パス深さぶん）のみ。**プロセス起動は増えない** |

**残存（塞いでいない）**:

- `PLANGATE_BYPASS_HOOK=1` / `python3` 不在時の degrade-to-base は不変（`_pg_contain` が空 →
  union 不発火 → 従来判定）。python3 が無い環境では worktree HO は **依然素通り**する。
- worktree 内から hook を起動した場合（REPO_ROOT = worktree）に main checkout 側の HO を
  指すケースは、逆向きに WORKTREE 判定が効いて block される（意図どおり）。ただし本 patch
  では**実測していない**。
- #1104（Bash レーンのコマンド文字列からの書き込み先抽出）は本 patch の範囲外で **open のまま**。
  `sh -c 'cat > .claude/rules/x.md'` 相当は EH-3 では止まらない（多層防御の別層に依存）。

## 5. 適用（Human-owned）

```sh
awk 'BEGIN{q=sprintf("%c",96)} /^<!-- PG-PATCH-BEGIN -->$/{b=1;next} /^<!-- PG-PATCH-END -->$/{exit} b && substr($0,1,1)==q{f=!f;next} f' \
  docs/working/_reports/1277-worktree-ho-bypass-patch.md \
  > /tmp/1277-worktree-ho.patch
git apply --check /tmp/1277-worktree-ho.patch      # rc=0
git apply --numstat /tmp/1277-worktree-ho.patch    # 25  9  scripts/hooks/check-plan-hash.sh
git apply /tmp/1277-worktree-ho.patch
sh tests/extras/ta-80-eh3-outside-repo.sh          # 45 passed, 0 failed
```

| コマンド | 実測 rc | 意味 |
| --- | --- | --- |
| `git apply --check /tmp/1277-worktree-ho.patch` | **0** | 当たる |
| `git apply --check -R /tmp/1277-worktree-ho.patch` | **1** | まだ入っていない |

<!-- PG-PATCH-BEGIN -->

```diff
diff --git a/scripts/hooks/check-plan-hash.sh b/scripts/hooks/check-plan-hash.sh
index 10df81d7..dcdc88d0 100755
--- a/scripts/hooks/check-plan-hash.sh
+++ b/scripts/hooks/check-plan-hash.sh
@@ -377,10 +377,14 @@ fi
 #     ときだけ OUTSIDE_REPO_SKIP (rc=0)。TASK 文脈 / STRICT=1 は不変
 #   - INSIDE なら repo 相対の物理パスを _phys_target に置き、HO / plan.md 判定は
 #     _ho_key との union で評価する（symlink 経由の逆方向迂回を塞ぐ）
-#   - 解決先が REPO_ROOT 外でも **同一 repo の linked worktree**（.git ファイルの
-#     gitdir → commondir が REPO_ROOT の common dir と一致）なら WORKTREE = 縮退
-#     （従来判定のまま）。worktree 配下 HO の判定は #1277 の領域であり、本判定で
-#     rc を緩めない（OUTSIDE 扱いにすると #1277 が悪化する）
+#   - **同一 repo の linked worktree**（.git ファイルの gitdir → commondir が
+#     REPO_ROOT の common dir と一致）配下なら WORKTREE = その **worktree root からの
+#     相対パス** を _phys_target に置く（#1277）。worktree は REPO_ROOT の外
+#     （/tmp/wt 等）にも **内**（.claude/worktrees/<name>/ = 本 repo の実運用形態）にも
+#     置かれるため、判定は INSIDE / OUTSIDE の**前**に行う。これをしないと
+#     `.claude/worktrees/x/.claude/rules/a.md` は INSIDE 扱いのまま HO 12 カテゴリの
+#     どれにも一致せず（先頭が `.claude/worktrees/`）、承認境界が丸ごと外れる。
+#     WORKTREE は rc を**緩めない**（SKIP へは倒さない / 締める方向のみ）。
 # 位置: _pg_fold_path の fail-closed 判定より **後**（相対 .. の fail-closed を
 # 緩めない）、HO 9 カテゴリ判定より **前**（OUTSIDE でも HO 一致は無い）。
 # python3 不在 / 失敗時は _pg_contain が空になり、SKIP も union も発火しない
@@ -407,8 +411,10 @@ if any(s in ("", ".", "..") for s in rest):
 full = os.path.realpath(p)
 if rest:
     full = os.path.join(full, *rest)
-if full == root or full.startswith(root + os.sep):
-    print("INSIDE|" + os.path.relpath(full, root)); sys.exit(0)
+# INSIDE 判定は保留する（#1277）。REPO_ROOT 配下でも、その実体が **別の linked
+# worktree**（.claude/worktrees/<name>/ 等）であれば repo 相対キーは worktree root
+# からの相対でなければならない。
+_inside = (full == root or full.startswith(root + os.sep))
 
 def common_dir(d):
     # d/.git が dir ならそれ自体、file なら gitdir → commondir を辿る
@@ -433,22 +439,32 @@ def common_dir(d):
         return None
 
 root_common = common_dir(root)
-d = os.path.dirname(full)
+# full を含む **最も内側の** git 作業ツリー root を探す。最初に見つかった .git が
+# REPO_ROOT と同じ common dir を指す（= 同一 repo の linked worktree）で、かつ
+# REPO_ROOT 自身でないときだけ WORKTREE。それ以外（別 repo の clone / submodule /
+# git 管理外）は従来どおり INSIDE / OUTSIDE に倒す（#1277）。
+d = full if os.path.isdir(full) else os.path.dirname(full)
 while True:
     if os.path.lexists(os.path.join(d, ".git")):
-        if root_common is not None and common_dir(d) == root_common:
-            print("WORKTREE|" + full); sys.exit(0)
+        if d != root and root_common is not None and common_dir(d) == root_common:
+            print("WORKTREE|" + os.path.relpath(full, d)); sys.exit(0)
         break
     nd = os.path.dirname(d)
     if nd == d:
         break
     d = nd
+if _inside:
+    print("INSIDE|" + os.path.relpath(full, root)); sys.exit(0)
 print("OUTSIDE|" + full)
 PYCT
 )
 fi
 case "$_pg_contain" in
   INSIDE\|*) _phys_target="${_pg_contain#INSIDE|}" ;;
+  # (#1277) 同一 repo の linked worktree 配下。値は **worktree root からの相対パス**
+  # なので、INSIDE と同じく _phys_key 経由で HO 12 カテゴリ / plan.md 判定に載る。
+  # OUTSIDE_REPO_SKIP へは倒さない（rc を緩めない）。
+  WORKTREE\|*) _phys_target="${_pg_contain#WORKTREE|}" ;;
   OUTSIDE\|*)
     # 字句正規化（_ho_key）の側で repo 内に畳み込まれるパス（例: /tmp/../<repo>/x）は
     # 物理的には別の場所へ到達するが、#1101 が block していた表記を本判定で緩めない
```

<!-- PG-PATCH-END -->
