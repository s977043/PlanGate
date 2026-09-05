# #1234 EH-3 repo 外パスの SKIP — `git apply` 可能形 patch（**Human 適用**）

> 状態: **確定版（sandbox 実測済）**。前版（`~/.claude/state/plangate-salvage/` の DRAFT / 基点 `9f7bac9`・未検証）を、
> 現 `origin/main` に対して **patch を作り直し**、`git apply --check` / before・after rc 表 / 変異注入 / python3 不在 を実測した。
>
> 対象: `scripts/hooks/check-plan-hash.sh`（**Hardening Override 対象パス** — AI は適用しない。本書は patch 文書まで）
> 測定基点: **`origin/main` = `f23d31d`**（2026-09-06。#1101 正規化 `_pg_fold_path` / `_ho_key` と #1104 `BASH_LANE_NOOP` 適用済み）。
> 行番号アンカーは `cat -n scripts/hooks/check-plan-hash.sh` の実測値（§2）。
> 関連: #1101（適用済 / PR #1271）/ #1104（`BASH_LANE_NOOP` 適用済・Bash コマンド解析は open）/ **#1277（worktree 配下 HO 未判定・open。本 patch は解決せず、悪化させないことだけを実測 §4）**
> 形式の先例: [`1104-bash-lane-noop-patch-applicable.md`](./1104-bash-lane-noop-patch-applicable.md) / [`1101-normalization-patch-applicable.md`](./1101-normalization-patch-applicable.md)

---

## 0. 結論先行

| 項目 | 結論 |
|---|---|
| 欠陥 | no-task 経路が **REPO_ROOT の外**のパス（`/tmp/**`、ハーネスのスクラッチパッド、`$HOME` 配下）を `SKIP_BLOCKED` で rc=2 にする（§1 before 表 B1〜B3・B21）。守るべき対象ではない |
| 是正方針 | **repo containment を独立に判定**（issue 最終コメントの「block / skip の 2 値ではなく repo 内 / 外を分類」）。判定は **物理解決（`os.path.realpath`）**。`OUTSIDE`（物理）**かつ**字句正規化 `_ho_key` も repo 外 **かつ** no-task **かつ** `STRICT≠1` のときだけ `OUTSIDE_REPO_SKIP` (rc=0) |
| 弱めないもの | HO 9 カテゴリ / `plan.md` no-task block / repo 内 `.py` `.sh` の `SKIP_BLOCKED` / TASK 文脈の plan_hash 突合 / `PLANGATE_HOOK_STRICT=1` の一律 block / #1101 の字句 fail-closed。**repo 内の判定入力（`_norm_target` / `_ho_key`）は無改変**。§3 after 表で rc=2 の行は 1 行も rc=0 に転んでいない |
| 逆方向迂回（AC-3） | symlink 経由で repo 内を指すパスは `INSIDE` に分類され、**物理解決後の repo 相対パス（`_phys_key`）を HO / plan.md 判定へ union で追加**。従来より**強くなる方向のみ**（`outside/link/CLAUDE.md` / `outside/x.md -> CLAUDE.md`: before rc=0 `DOC_LIGHT_SKIP` → after rc=2 `HARDENING_OVERRIDE`。B8 / B9 / B24） |
| `..` 往復 | **#1101 が既に字句で block している**（B7 / B15 は before から rc=2）。本 patch は物理 OUTSIDE でも字句 `_ho_key` が repo 内に畳み込まれる表記を **SKIP しない**（AND 条件。緩めない。M-LEX 変異で実証 §5） |
| worktree（#1277） | 解決先が同一 repo の linked worktree（`.git` ファイル → `commondir` 一致）なら **`WORKTREE` = 従来判定のまま**。root 配下 worktree / root 外 worktree ともに **before と同じ rc**（B11〜B14。M-WT 変異で「この判定を外すと B13 が rc=0 へ悪化する」ことを実証） |
| 縮退 | python3 不在 / 失敗 / 未存在セグメントに `.` `..` を含む（`UNSURE`）→ **現行判定そのまま**（degrade-to-base。§6 実測） |
| 監査 | `OUTSIDE_REPO_SKIP` は `hook-events.log` にのみ記録。**`skip-decision-log.jsonl` には書かない**（人間追認を要求しない。実測: 22 行 matrix で before 6 行 → after 3 行、増分なし） |
| 検証 | `git apply --check` **rc=0** / `1 file changed, 134 insertions(+)` / 変異 8 種すべて対応 TC が転ぶ（§5） |
| 回帰網 | `tests/extras/ta-80-eh3-outside-repo.sh` + `tests/fixtures/eh3-outside-repo-pending-1234.flag` — **仕様のみ §8**（本セッションは `.md` 以外を作れない） |

### issue 最終コメントの false negative（repo 外 `CLAUDE.md` が ALLOW）について

repo 外の `CLAUDE.md`（B4 `/tmp/CLAUDE.md`）は before `DOC_LIGHT_SKIP` rc=0 → after `OUTSIDE_REPO_SKIP` rc=0（理由が変わるだけ）。「他 repo の HO 名を守る」のは issue Non-goals（repo 外への別ガード新設）であり本 patch の射程外。コメントが懸念する「片側だけ緩めると false negative が悪化する」ケースは **repo 内を指すのに repo 外に見えるパス**（symlink）であり、これは union で塞ぐ（B8 / B9 / B24）。

---

## 1. before（`f23d31d` の hook を sandbox 複製、no-task / `PLANGATE_SKIP_REASON` 未設定 / maintenance なし）

sandbox: `<SB>/root/`（hook 複製 + `CLAUDE.md` / `bin/plangate` / `docs/working/TASK-9999/plan.md` / `.claude/worktrees/x/CLAUDE.md` / `.git/worktrees/wt/commondir`）、`<SB>/outside/link -> root`、`<SB>/outside/x.md -> root/CLAUDE.md`、`<SB>/outside/y.md -> root/docs/working/TASK-9999/plan.md`、`<SB>/wt-ext/`（`.git` ファイル `gitdir: <root>/.git/worktrees/wt` を持つ root 外 linked worktree の手組み）、`<SB>/home/Desktop/`。hook の `REPO_ROOT` は `$0` 由来なので実 repo は汚れない。実行は `PLANGATE_HOOK_FILE=<target> sh <hook> </dev/null`。

| # | target | 形状 | rc | 1 行目 |
|---|---|---|---|---|
| B1 | `/private/tmp/x/scratch.html` | repo 外（scratchpad） | **2** | `SKIP 拒否: SKIP_REASON 未設定` |
| B2 | `/tmp/foo.html` | repo 外 | **2** | 同上 |
| B3 | `<SB>/home/Desktop/x.html` | repo 外（$HOME 相当） | **2** | 同上 |
| B4 | `/tmp/CLAUDE.md` | repo 外 `.md` | 0 | `DOC_LIGHT_SKIP`（skip-decision-log に記録） |
| B5 | `<root>/CLAUDE.md` | repo 内 HO | 2 | `HARDENING_OVERRIDE` |
| B6 | `<root>/bin/plangate` | repo 内 HO | 2 | `HARDENING_OVERRIDE` |
| B7 | `/tmp/../<root>/CLAUDE.md` | `..` で repo 内に戻る（字句） | 2 | `HARDENING_OVERRIDE`（#1101 の字句畳み込み） |
| B8 | `<SB>/outside/link/CLAUDE.md` | dir symlink → HO | **0** | `DOC_LIGHT_SKIP`（**false negative**） |
| B9 | `<SB>/outside/x.md` | file symlink → `CLAUDE.md` | **0** | `DOC_LIGHT_SKIP`（**false negative**） |
| B10 | `<SB>/outside/link/docs/working/TASK-9999/plan.md` | dir symlink → plan.md | 2 | `plan.md edited without TASK context`（字句 `*/plan.md`） |
| B24 | `<SB>/outside/y.md` | file symlink → plan.md | **0** | `DOC_LIGHT_SKIP`（**false negative**） |
| B11 | `<root>/.claude/worktrees/x/CLAUDE.md` | root 配下 worktree HO（#1277） | 0 | `DOC_LIGHT_SKIP` |
| B12 | `<SB>/wt-ext/CLAUDE.md` | root 外 worktree HO（#1277） | 0 | `DOC_LIGHT_SKIP` |
| B13 | `<SB>/wt-ext/bin/plangate` | root 外 worktree HO（#1277） | 2 | `SKIP 拒否`（理由は HO でない） |
| B14 | `<SB>/wt-ext/x.html` | root 外 worktree 非 HO | 2 | `SKIP 拒否` |
| B15 | `<root>/nonexist/../CLAUDE.md` | 未存在 dir 経由の `..` | 2 | `HARDENING_OVERRIDE`（#1101 字句） |
| B16 | `<root>/scripts/foo.py` | repo 内 `.py` | 2 | `SKIP 拒否` |
| B17 | `docs/working/_reports/x.md` | repo 内相対 `.md` | 0 | `DOC_LIGHT_SKIP` |
| B18 | `<root>/docs/working/TASK-9999/plan.md` | repo 内 plan.md | 2 | `plan.md edited without TASK context` |
| B19 | `/tmp/foo.html` + `STRICT=1` | repo 外 / STRICT | 2 | `Usage:` |
| B20 | `/tmp/foo.html` + `HOOK_TASK=TASK-9999` | repo 外 / TASK 文脈 | 0 | `c3.json not found`（plan_hash 経路） |
| B21 | `/private/tmp/newdir/nonexist/x.html` | repo 外・未存在 dir | **2** | `SKIP 拒否` |
| B22 | `<SB>/outside/link/bin/plangate` | dir symlink → HO（非 .md） | 2 | `SKIP 拒否`（理由は HO でない） |
| B23 | `/tmp/newdir/../x.html` | 未存在 dir 経由 `..`（UNSURE 相当） | 2 | `SKIP 拒否` |

skip-decision-log 追記: 6 行（B4 / B8 / B9 / B11 / B12 / B17 の `DOC_LIGHT_SKIP`）。

**DRAFT §1 からの訂正**: DRAFT は「`<repo>/docs/../CLAUDE.md` → rc=0（false negative）」と書いていたが、現 main では #1101 により **rc=2**。`..` 経路は本 patch の主題ではない。

---

## 2. アンカー（`cat -n` 実測 / `f23d31d`）

| アンカー | 行 |
|---|---|
| `_pg_fold_path "${target_file:-}" "$REPO_ROOT" 1` / `_ho_key=$_PG_FOLD_OUT` | 345–346 |
| fail-closed 判定の `fi`（hunk 1 の挿入直後） | 360 |
| `# (ii) Hardening Override 物理先頭判定` / `_override=0` / `case "$_ho_key" in` | 362 / 366 / 367 |
| 9 カテゴリ case の `esac`（hunk 2 の挿入直後） | 377 |
| `if [ "$_override" = "1" ]; then` | 378 |
| no-task plan.md guard の `esac`（hunk 3 の挿入直後） | 406 |
| `if [ "${PLANGATE_HOOK_STRICT:-0}" = "1" ]; then` | 407 |

hunk ヘッダは `diff -u`（python `difflib`, context 3）の出力そのもの（手計算なし）: `@@ -358,6 +358,103 @@` / `@@ -375,6 +472,30 @@` / `@@ -404,6 +525,19 @@`。

---

## 3. 設計と after 実測

```text
bypass → target 抽出 → BASH_LANE_NOOP(#1104) → (i) _norm_target
→ (i-b) _pg_fold_path → _ho_key / fail-closed(#1101)                 ← 不変
→ (i-c) repo containment（本 patch）
      python3: 存在する最長プレフィクスを realpath → 残りに . / .. / 空 があれば UNSURE
      INSIDE   → _phys_target = repo 相対の物理パス
      WORKTREE → 同一 repo の linked worktree（commondir 一致）= 何もしない（#1277 に委ねる）
      OUTSIDE  かつ _ho_key が絶対パスのまま（字句でも repo 外）かつ task_id 空 かつ STRICT≠1
               → OUTSIDE_REPO_SKIP exit 0
      UNSURE / 失敗 / 空 → 何もしない
→ (ii)  HO 9 カテゴリ case（_ho_key）                                  ← 不変（正本）
→ (ii-b) HO 9 カテゴリ case（_phys_key = _pg_fold_path(_phys_target, "", 1)）← union
no-task:
→ plan.md guard（target_file 字句）                                    ← 不変
→ plan.md guard（_phys_key）                                           ← union
→ STRICT / c3 conversation / doc-light / maintenance / SKIP_REASON   ← 不変
```

- 位置は **fail-closed より後、HO 判定より前**。相対 `..` の fail-closed（#1101 (a)）を緩めない。
- 相対パスは REPO_ROOT 相対として物理解決（従来の接頭辞除去と同じ意味論）。
- `os.path.lexists` で存在判定するため最終セグメントが symlink なら**リンク先**で判定（B9 / B24）。
- 9 カテゴリを (ii-b) に**複製**。正本は (ii)（`mode-classification.md` の「`_override=0` 直後の case」アンカーを壊さない）。両ブロックの 9 行は**バイト一致を実測済**（§7 TC-06 の照合ロジックで `True`）。
- 外部コマンドは python3 のみ（既存依存。maintenance / c3 抽出で既出）。`tr` / `sed` の追加 fork なし。

### after（patch 済み sandbox / 同 matrix）

| # | target | before | **after** | after 1 行目 | 判定 |
|---|---|---|---|---|---|
| B1 | `/private/tmp/x/scratch.html` | 2 | **0** | `OUTSIDE_REPO_SKIP` | 是正 |
| B2 | `/tmp/foo.html` | 2 | **0** | `OUTSIDE_REPO_SKIP` | 是正 |
| B3 | `<SB>/home/Desktop/x.html` | 2 | **0** | `OUTSIDE_REPO_SKIP` | 是正 |
| B4 | `/tmp/CLAUDE.md` | 0 | 0 | `OUTSIDE_REPO_SKIP`（skip-decision-log 非記録に変化） | 不変(rc) |
| B5 | `<root>/CLAUDE.md` | 2 | 2 | `HARDENING_OVERRIDE` | 不変 |
| B6 | `<root>/bin/plangate` | 2 | 2 | `HARDENING_OVERRIDE` | 不変 |
| B7 | `/tmp/../<root>/CLAUDE.md` | 2 | 2 | `HARDENING_OVERRIDE`（字句 AND 条件により SKIP しない） | 不変 |
| B8 | `<SB>/outside/link/CLAUDE.md` | 0 | **2** | `HARDENING_OVERRIDE` | 強化 |
| B9 | `<SB>/outside/x.md` | 0 | **2** | `HARDENING_OVERRIDE` | 強化 |
| B10 | `<SB>/outside/link/.../plan.md` | 2 | 2 | `plan.md edited without TASK context` | 不変 |
| B24 | `<SB>/outside/y.md` | 0 | **2** | `plan.md edited without TASK context`（`resolves to`） | 強化 |
| B11 | `<root>/.claude/worktrees/x/CLAUDE.md` | 0 | 0 | `DOC_LIGHT_SKIP` | 不変（#1277） |
| B12 | `<SB>/wt-ext/CLAUDE.md` | 0 | 0 | `DOC_LIGHT_SKIP` | 不変（#1277） |
| B13 | `<SB>/wt-ext/bin/plangate` | 2 | 2 | `SKIP 拒否` | 不変（#1277） |
| B14 | `<SB>/wt-ext/x.html` | 2 | 2 | `SKIP 拒否` | 不変（WORKTREE 縮退） |
| B15 | `<root>/nonexist/../CLAUDE.md` | 2 | 2 | `HARDENING_OVERRIDE` | 不変 |
| B16 | `<root>/scripts/foo.py` | 2 | 2 | `SKIP 拒否` | 不変 |
| B17 | `docs/working/_reports/x.md` | 0 | 0 | `DOC_LIGHT_SKIP` | 不変 |
| B18 | `<root>/docs/working/TASK-9999/plan.md` | 2 | 2 | `plan.md edited without TASK context` | 不変 |
| B19 | `/tmp/foo.html` + `STRICT=1` | 2 | 2 | `Usage:` | 不変 |
| B20 | `/tmp/foo.html` + `HOOK_TASK` | 0 | 0 | `c3.json not found` | 不変 |
| B21 | `/private/tmp/newdir/nonexist/x.html` | 2 | **0** | `OUTSIDE_REPO_SKIP`（未存在セグメントは prefix 解決） | 是正 |
| B22 | `<SB>/outside/link/bin/plangate` | 2 | 2 | `HARDENING_OVERRIDE`（理由が正しくなる） | 不変(rc) |
| B23 | `/tmp/newdir/../x.html` | 2 | 2 | `SKIP 拒否`（UNSURE → 縮退） | 不変 |

skip-decision-log 追記: 3 行（B11 / B12 / B17）。`OUTSIDE_REPO_SKIP` は `hook-events.log` のみ。**before で rc=2 の行が after で rc=0 になったのは repo 外 4 行（B1〜B3・B21）だけ。**

### 弱めていないことの根拠（表）

| 経路 | patch 前 | patch 後 |
|---|---|---|
| repo 外 / no-task / STRICT=0（字句・物理とも外） | rc=2 `SKIP_BLOCKED` | **rc=0 `OUTSIDE_REPO_SKIP`** |
| repo 外 / no-task / STRICT=1 | rc=2 | rc=2（B19） |
| repo 外 / TASK 文脈あり | plan_hash 突合 | 不変（B20） |
| 物理 OUTSIDE だが字句で repo 内に畳める（`/tmp/../<repo>/…`） | #1101 字句 block | 不変（B7。SKIP しない） |
| repo 内 / 全経路（表記そのまま） | — | 不変（B5 / B6 / B15〜B18） |
| symlink → repo 内 HO / plan.md | rc=0（false negative） | **rc=2**（B8 / B9 / B24） |
| 同一 repo worktree（root 配下 / root 外） | #1277 のギャップ | 不変（B11〜B14） |
| python3 不在 / 失敗 / UNSURE | — | 現行判定そのまま（§6 / B23） |

---

## 4. #1277 との関係（悪化させないことの実測）

#1277 は「`_ho_key` が `REPO_ROOT` 前置き固定で worktree 配下 HO が判定できない」。本 patch は同じ root 解決の問題に触れるため、次を実測した:

| 形状 | before | after | M-WT（worktree 検出を外した変異） |
|---|---|---|---|
| root 配下 worktree HO `.md`（B11） | 0 | 0 | 0（INSIDE 判定で `_phys_key=.claude/worktrees/x/claude.md` → 9 パターン不一致 = #1277 のまま） |
| root 外 worktree HO `.md`（B12） | 0 | 0 | 0 |
| root 外 worktree HO 非 `.md`（B13） | 2 | 2 | **0（悪化）** |
| root 外 worktree 非 HO（B14） | 2 | 2 | 0 |

`WORKTREE` 分類（`.git` ファイルの `gitdir:` → `commondir` を辿り REPO_ROOT の common dir と一致するか）が無いと、root 外 worktree は単なる OUTSIDE となり B13 が rc=0 へ転ぶ。本 patch はこれを **縮退（従来判定）** に倒し、#1277 を**解決も悪化もさせない**。#1277 の是正（worktree 相対の HO 比較）は本 patch の `_pg_contain` の `WORKTREE|<full>` 出力を入力に使える（設計上の接続点。実装は #1277 側）。

---

## 5. 変異注入（AC-4 / 患部を壊すと after 表のどこが転ぶか）

patch 済み複製に対し call site を壊し、§3 after と比較（差分行のみ）:

| 変異 | 内容 | 転んだ行（after → 変異） | 検出 TC |
|---|---|---|---|
| M-OUT | containment が常に `OUTSIDE`（INSIDE / WORKTREE 分岐を殺す） | B8: 2→0 / B9: 2→0 / B10: 2→0 / **B13: 2→0** | TC-03a/b/c, TC-05 |
| M-IN | containment が常に `INSIDE` | B1: 0→2 / B4: `OUTSIDE_REPO_SKIP`→`DOC_LIGHT_SKIP` | TC-01a |
| M1 | (i-c) ブロック全削除 | B1: 0→2 / B8: 2→0 / B9: 2→0 | TC-01a, TC-03a/b |
| M3 | `[ -z "$task_id" ] &&` を除去 | B20: `c3.json not found`→`OUTSIDE_REPO_SKIP`（TASK 文脈で plan_hash 経路が消える） | TC-01e |
| M4 | (ii-b) ブロック削除 | B8: 2→0 / B9: 2→0 | TC-03a/b |
| M5 | plan.md union 削除 | **B24: 2→0**（B10 は字句 `*/plan.md` で残る） | TC-03c |
| M-LEX | 字句 AND 条件（`_pg_lex_outside`）を除去 | **B7: 2→0**（`/tmp/../<repo>/CLAUDE.md` が SKIP される） | TC-04a |
| M-WT | WORKTREE 分類を除去 | **B13: 2→0**（#1277 悪化） | TC-05b |

8 変異すべてで少なくとも 1 行が転ぶ（空振り fixture なし）。M0（未適用 main 版）は §1 before 表そのもの。

---

## 6. python3 不在（degrade-to-base）

`PATH` を python3 を含まない bin 集合（`sh env sed tr awk head cut cat printf date mkdir dirname basename grep jq wc cp rm shasum uname` の symlink dir）に差し替えて patch 済み hook を実行:

| # | rc | 1 行目 |
|---|---|---|
| B1 | 2 | `SKIP 拒否`（= before） |
| B4 | 0 | `DOC_LIGHT_SKIP`（= before） |
| B6 / B7 | 2 | `HARDENING_OVERRIDE` |
| B8 / B9 | 0 | `DOC_LIGHT_SKIP`（= before の false negative。**union も発火しない**） |
| B10 / B18 | 2 | plan.md guard |
| B13 / B16 / B23 | 2 | `SKIP 拒否` |
| B20 | 0 | `c3.json not found` |

python3 不在では `_pg_contain` が空になり SKIP も union も発火せず、**全行が before と一致**。緩める側には倒れない。

---

## 7. patch（`git apply` 用 / **検証済**）

抽出は marker 基準（#1104 と同じ規則）:

````sh
sed -n '/^<!-- PG-PATCH-BEGIN -->$/,/^<!-- PG-PATCH-END -->$/p' \
  docs/working/_reports/1234-eh3-outside-repo-patch-applicable.md \
  | sed -e '1d' -e '$d' | sed -e '1d' -e '$d' > /tmp/1234-outside-repo.patch
git apply --check /tmp/1234-outside-repo.patch   # f23d31d で rc=0 実測
git apply --stat  /tmp/1234-outside-repo.patch   # scripts/hooks/check-plan-hash.sh | 134 +  (1 file changed, 134 insertions(+))
````

<!-- PG-PATCH-BEGIN -->
```diff
diff --git a/scripts/hooks/check-plan-hash.sh b/scripts/hooks/check-plan-hash.sh
--- a/scripts/hooks/check-plan-hash.sh
+++ b/scripts/hooks/check-plan-hash.sh
@@ -358,6 +358,103 @@
   printf '[Hook EH-3] %s\n' "$reason" >&2
   exit 2
 fi
+# ===== (i-c) repo containment 判定（#1234）=====
+# no-task 経路が repo 外のパス（/tmp、ハーネスのスクラッチパッド、$HOME 配下）まで
+# SKIP_BLOCKED (rc=2) にしていた欠陥の是正。判定は「物理解決した先が REPO_ROOT
+# 配下か」で行う（_pg_fold_path は字句のみで symlink を解決しない = Non-goal）:
+#   - 存在する最長プレフィクスを realpath で解決（symlink / .. を物理的に潰す）し、
+#     残りの未存在セグメントに . / .. / 空 が含まれるなら UNSURE（縮退 = 従来判定）
+#   - OUTSIDE（物理）かつ字句正規化 _ho_key も repo 外 かつ no-task かつ STRICT=0 の
+#     ときだけ OUTSIDE_REPO_SKIP (rc=0)。TASK 文脈 / STRICT=1 は不変
+#   - INSIDE なら repo 相対の物理パスを _phys_target に置き、HO / plan.md 判定は
+#     _ho_key との union で評価する（symlink 経由の逆方向迂回を塞ぐ）
+#   - 解決先が REPO_ROOT 外でも **同一 repo の linked worktree**（.git ファイルの
+#     gitdir → commondir が REPO_ROOT の common dir と一致）なら WORKTREE = 縮退
+#     （従来判定のまま）。worktree 配下 HO の判定は #1277 の領域であり、本判定で
+#     rc を緩めない（OUTSIDE 扱いにすると #1277 が悪化する）
+# 位置: _pg_fold_path の fail-closed 判定より **後**（相対 .. の fail-closed を
+# 緩めない）、HO 9 カテゴリ判定より **前**（OUTSIDE でも HO 一致は無い）。
+# python3 不在 / 失敗時は _pg_contain が空になり、SKIP も union も発火しない
+# （degrade-to-base: 現行判定そのまま。緩める側には倒れない）。
+_pg_contain=""
+_phys_target=""
+if [ -n "${target_file:-}" ] && command -v python3 >/dev/null 2>&1; then
+  _pg_contain=$(PG_ROOT="$REPO_ROOT" PG_TARGET="$target_file" python3 - <<'PYCT' 2>/dev/null || true
+import os, sys
+root = os.path.realpath(os.environ["PG_ROOT"])
+t = os.environ["PG_TARGET"]
+if not os.path.isabs(t):
+    t = os.path.join(root, t)
+p = t
+rest = []
+while not os.path.lexists(p):
+    head, tail = os.path.split(p)
+    if head == p:
+        break
+    rest.insert(0, tail)
+    p = head
+if any(s in ("", ".", "..") for s in rest):
+    print("UNSURE|unresolved segment"); sys.exit(0)
+full = os.path.realpath(p)
+if rest:
+    full = os.path.join(full, *rest)
+if full == root or full.startswith(root + os.sep):
+    print("INSIDE|" + os.path.relpath(full, root)); sys.exit(0)
+
+def common_dir(d):
+    # d/.git が dir ならそれ自体、file なら gitdir → commondir を辿る
+    g = os.path.join(d, ".git")
+    try:
+        if os.path.isdir(g):
+            return os.path.realpath(g)
+        with open(g, "r", encoding="utf-8") as f:
+            line = f.readline().strip()
+        if not line.startswith("gitdir:"):
+            return None
+        gd = line[len("gitdir:"):].strip()
+        if not os.path.isabs(gd):
+            gd = os.path.join(d, gd)
+        cd = os.path.join(gd, "commondir")
+        if os.path.isfile(cd):
+            with open(cd, "r", encoding="utf-8") as f:
+                rel = f.readline().strip()
+            return os.path.realpath(os.path.join(gd, rel))
+        return os.path.realpath(gd)
+    except OSError:
+        return None
+
+root_common = common_dir(root)
+d = os.path.dirname(full)
+while True:
+    if os.path.lexists(os.path.join(d, ".git")):
+        if root_common is not None and common_dir(d) == root_common:
+            print("WORKTREE|" + full); sys.exit(0)
+        break
+    nd = os.path.dirname(d)
+    if nd == d:
+        break
+    d = nd
+print("OUTSIDE|" + full)
+PYCT
+)
+fi
+case "$_pg_contain" in
+  INSIDE\|*) _phys_target="${_pg_contain#INSIDE|}" ;;
+  OUTSIDE\|*)
+    # 字句正規化（_ho_key）の側で repo 内に畳み込まれるパス（例: /tmp/../<repo>/x）は
+    # 物理的には別の場所へ到達するが、#1101 が block していた表記を本判定で緩めない
+    # ＝物理 OUTSIDE **かつ** 字句でも repo 外（root 除去後も絶対パスのまま）のときだけ SKIP。
+    _pg_lex_outside=0
+    case "$_ho_key" in /*) _pg_lex_outside=1 ;; esac
+    if [ "$_pg_lex_outside" = "1" ] && [ -z "$task_id" ] && [ "${PLANGATE_HOOK_STRICT:-0}" != "1" ]; then
+      reason="OUTSIDE_REPO_SKIP: target outside REPO_ROOT (${target_file}) -- not a PlanGate artifact, skipped (#1234)"
+      log_event "OUTSIDE_REPO_SKIP" "$reason"
+      printf '[Hook EH-3 OUTSIDE_REPO_SKIP] %s\n' "$reason"
+      exit 0
+    fi
+    ;;
+esac
+
 
 # (ii) Hardening Override 物理先頭判定（R-003/R-015、maintenance より上）
 # 判定対象は _ho_key（小文字化済み）。したがって case は**小文字側で受ける**。
@@ -375,6 +472,30 @@
   .github/workflows/*.yml|.github/workflows/*.yaml) _override=1 ;;
   agents.md|claude.md) _override=1 ;;
 esac
+# (ii-b) #1234: 物理解決後の repo 相対パス（_phys_target を _pg_fold_path で小文字化
+# した _phys_key）にも同じ 9 カテゴリを当てる。_ho_key との union（どちらか一致で
+# block）。9 カテゴリの正本は上の case ブロック（_override=0 直後）であり、本ブロックの
+# 一覧は正本と同一に保つこと（ta-80 TC-06 が照合）。
+_phys_key=""
+if [ "$_override" = "0" ] && [ -n "${_phys_target:-}" ]; then
+  _pg_fold_path "$_phys_target" "" 1
+  if [ "$_PG_FOLD_RC" = "0" ]; then
+    _phys_key=$_PG_FOLD_OUT
+  fi
+fi
+if [ -n "$_phys_key" ] && [ "$_phys_key" != "$_ho_key" ]; then
+  case "$_phys_key" in
+    .claude/rules/*.md) _override=1 ;;
+    .claude/settings.json|.claude/settings.local.json|.claude/settings.example.json) _override=1 ;;
+    .claude/commands/*.md|.claude/commands/*/*.md) _override=1 ;;
+    .claude/agents/*.md|.claude/agents/*/*.md) _override=1 ;;
+    scripts/hooks/*.sh) _override=1 ;;
+    bin/plangate) _override=1 ;;
+    schemas/*.schema.json) _override=1 ;;
+    .github/workflows/*.yml|.github/workflows/*.yaml) _override=1 ;;
+    agents.md|claude.md) _override=1 ;;
+  esac
+fi
 if [ "$_override" = "1" ]; then
   # AC-9: 監査ログと reason には**生の要求パス**を残す（正規化後の値ではない）。
   reason="HARDENING_OVERRIDE: ${target_file:-} は maintenance 窓内でも常時 block (R-003/R-015)"
@@ -404,6 +525,19 @@
       exit 2
       ;;
   esac
+  # #1234: symlink 経由で repo 内 plan.md を指すパスも同じ判定に掛ける（union）
+  if [ -n "${_phys_key:-}" ]; then
+    case "$_phys_key" in
+      */plan.md|plan.md)
+        reason="plan.md edited without TASK context via symlink (EH-3 bypass guard): $target_file -> $_phys_target"
+        log_event "VIOLATION" "$reason"
+        printf '[Hook EH-3] BLOCK: plan.md edited without TASK context.\n' >&2
+        printf '  target: %s (resolves to %s)\n' "$target_file" "$_phys_target" >&2
+        printf '  Set PLANGATE_HOOK_TASK=TASK-XXXX to allow plan.md edits.\n' >&2
+        exit 2
+        ;;
+    esac
+  fi
   if [ "${PLANGATE_HOOK_STRICT:-0}" = "1" ]; then
     printf 'Usage: %s <TASK-XXXX>  (or set PLANGATE_HOOK_TASK)\n' "$0" >&2
     exit 2
```
<!-- PG-PATCH-END -->

---

## 8. 回帰網の仕様（`tests/extras/ta-80-eh3-outside-repo.sh` — 仕様のみ・未作成）

採番: `ls tests/extras | sort` の最大は `ta-79` → **ta-80**（`f23d31d` 実測）。bootstrap / exit 契約 / helper 命名（`_t80_*`）/ trap 不使用 / `register_cleanup` は `ta-79` と同型。patch 抽出は本書 §7 の marker から（marker が壊れると本 TC が FAIL する）。期待値は `tests/fixtures/eh3-outside-repo-pending-1234.flag` の有無で fixed / gap を切り替え、flag が残っているのに実装が fixed（`OUTSIDE_REPO_SKIP` を含む）なら **stale として FAIL**（TC-00b）。`PG_T80_EXPECT=fixed|gap` で pin 可（失敗を増やす方向のみ）。

sandbox: `mktemp -d` 配下に §1 と同じレイアウト（`root/` + `outside/link` + `outside/x.md` + `outside/y.md` + `wt-ext/`（`.git` ファイル + `root/.git/worktrees/wt/commondir` の手組み。`git worktree add` は使わない = git 不要）+ `home/`）。末尾 `rm -rf` で残骸なし。python3 不在 TC は `PATH` を mktemp 内の symlink dir へ差し替えて実行。

| TC | 入力（`PLANGATE_HOOK_FILE`） | 期待（patched） | token |
|---|---|---|---|
| TC-00 | root 解決 / hook・report 存在 / python3 存在（無ければ `pg_extra_contract_skip`） | — | — |
| TC-00b | flag 有 かつ 実 hook に `OUTSIDE_REPO_SKIP` → stale FAIL | — | — |
| TC-01a/b/c | `<mktemp>/outside/x.html` / `<mktemp>/home/x.html` / `<mktemp>/outside/newdir/nonexist/x.html` | rc=0 | `OUTSIDE_REPO_SKIP` |
| TC-01d | repo 外 + `STRICT=1` | rc=2 | `Usage:` |
| TC-01e | repo 外 + `PLANGATE_HOOK_TASK=TASK-9999`（plan.md のみ・c3 なし） | rc=0 | `c3.json not found` |
| TC-01f | repo 外 `.md`（`<mktemp>/outside/CLAUDE.md`） | rc=0 | `OUTSIDE_REPO_SKIP` |
| TC-02a | `<root>/bin/plangate` / `<root>/CLAUDE.md` | rc=2 | `HARDENING_OVERRIDE` |
| TC-02b | `<root>/scripts/foo.py` | rc=2 | `SKIP 拒否` |
| TC-02c | `docs/working/_reports/x.md`（相対） | rc=0 | `DOC_LIGHT_SKIP` |
| TC-02d | `<root>/docs/working/TASK-9999/plan.md` | rc=2 | `plan.md edited without TASK context` |
| TC-03a | `<mktemp>/outside/link/bin/plangate`（dir symlink → HO） | rc=2 | `HARDENING_OVERRIDE` |
| TC-03b | `<mktemp>/outside/x.md`（file symlink → `CLAUDE.md`） | rc=2 | `HARDENING_OVERRIDE` |
| TC-03c | `<mktemp>/outside/y.md`（file symlink → plan.md） | rc=2 | `resolves to` |
| TC-04a | `<mktemp>/outside/../<basename root>/CLAUDE.md`（字句で repo 内・物理でも repo 内） | rc=2 | `HARDENING_OVERRIDE` |
| TC-04b | `<root>/nonexist/../CLAUDE.md` | rc=2 | `HARDENING_OVERRIDE`（#1101） |
| TC-04c | `<mktemp>/outside/newdir/../x.html`（UNSURE → 縮退） | rc=2 | `SKIP 拒否` |
| TC-05a | `<root>/.claude/worktrees/x/CLAUDE.md` | rc=0 | `DOC_LIGHT_SKIP`（#1277 と同値。是正時に期待値を更新） |
| TC-05b | `<mktemp>/wt-ext/bin/plangate`（root 外 linked worktree） | rc=2 | `SKIP 拒否`（WORKTREE 縮退。#1277 是正時に `HARDENING_OVERRIDE` へ更新） |
| TC-06 | (ii) と (ii-b) の 9 カテゴリ行がバイト一致（`case "$_ho_key" in` / `case "$_phys_key" in` の直後〜`esac` を抽出し `cmp`） | PASS | — |
| TC-07 | TC-01a〜f の後に `skip-decision-log.jsonl` が存在しない / 行数不変 | PASS | — |
| TC-08 | 変異 M-OUT / M-IN / M1 / M3 / M4 / M5 / M-LEX / M-WT（§5 の表どおり対応 TC が FAIL する） | 各 1 行以上転ぶ | — |
| TC-09 | python3 不在 PATH で TC-01a が rc=2 / TC-03b が rc=0（= before） | degrade | — |
| TC-R* | 実 hook（flag 有 → gap 期待: TC-01a rc=2 / TC-03b rc=0） | flag 準拠 | — |

---

## 9. 残存脅威モデル（完全性を主張しない）

**守るもの**: §3 after 表の rc=2 行 + repo 外 4 形状の rc=0。
**守らないもの**:
- repo 外パス全般（他 repo の `CLAUDE.md` 含む）。issue Non-goals。
- 同一 repo の worktree 配下 HO（root 配下 / root 外）— **#1277 のまま**（本 patch は縮退で据え置き）。
- 未存在ディレクトリ配下で `..` を使う表記（`UNSURE`）— 現行判定。#1101 の字句 fail-closed が repo 内相対では効く。
- Bash レーン（#1104 open）。本 patch は `Edit|Write` レーン（`file_path` が得られる payload）の判定のみ。
- python3 不在環境では symlink union が効かない（before と同じ false negative。degrade-to-base の代償）。
- firmlink 等 FS エイリアス（#1264）は `realpath` が解決する範囲でのみ INSIDE 化される（未実測）。
- `_audit/` 書込不能時の挙動は現行どおり。

**この層以外の保証主体**: C-4 Human レビュー / branch protection / `mode-classification.md` 承認境界節。

**測っていないもの**: 実 Claude Code セッション 1 周（hook 配線後の PreToolUse payload での発火）/ Linux での `realpath` 挙動（macOS のみ実測。`/tmp -> /private/tmp` の symlink 差が B7 の AND 条件の動機）。

---

## 10. 適用チェックリスト（実測結果）

| # | 項目 | 結果 |
|---|---|---|
| 1 | `git apply --check` を `f23d31d` の hook に対して実行 | **rc=0** / `1 file changed, 134 insertions(+)` |
| 2 | patch 済み sandbox で rc 表を実測 | §3（23 行） |
| 3 | 変異注入 | §5（8 変異すべて検出） |
| 4 | python3 不在 | §6（全行 before 一致） |
| 5 | #1101 / #1104 との併用順 | **不要**（両方 `f23d31d` に適用済み。本 patch はその上で生成） |
| 6 | `ta-80` 作成 / flag 作成 | **未**（`.sh` / flag は本セッションで作成不可。§8 仕様のみ） |
| 7 | `docs/ai/hook-enforcement.md` 残存脅威モデルへ追記 | 同 PR で実施 |
| 8 | DRAFT 表示を外し測定基点を更新 | 本書 |

適用後（Human）: patch 適用 → `ta-80` 作成・flag 削除 → `ta-80` 全 PASS → `sh scripts/apply-claude-settings.sh` は不要（settings 変更なし）。
