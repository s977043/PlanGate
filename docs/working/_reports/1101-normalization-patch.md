# #1101 patch 設計 — Hardening Override のパス正規化（**Human 適用**）

> 対象: `scripts/hooks/check-plan-hash.sh`（**Hardening Override 対象パス**）
> 測定基点: `origin/main` = `01c8946` / 2026-08-18 / macOS 25.6.0（APFS case-insensitive）
> 責務: **設計・差分・検証設計は AI-owned（本書）/ 適用は Human-owned**
> 位置づけ: **#1144 で hook を配布する前に閉じるべき筆頭**。#1135 patch の「差分 0」と同形の traversal ガードを含む

## 結論先行

**承認境界のパス集合（HO 9 カテゴリ）は変更しません。** 変えるのは **「HO 判定が何をキーに glob 照合するか」1 箇所**だけです。

- **block する側（HO 判定）**にだけ `前後空白除去 → 小文字化 → traversal fail-closed → 先頭 ./ ・末尾 / 除去 → repo root 除去` を入れる
- **通す側（doc-light / maintenance / c3 判定）が使う `_norm_target` は一切変更しない**
- `..` は **解決せず fail-closed で弾く**（`realpath` / `readlink -f` に依存しない）
- 正規化は **外部コマンド 2 fork（`sed` | `tr`）+ `tr` 1 fork**で完結。**1 文字ループは使わない**

### 現状の穴の規模は、前提として渡された 4 ケースより大きい

| 文脈 | 現 main の穴 |
|---|---|
| **no-task** セッション | HO 9 カテゴリのうち **`.md` を含む 4 カテゴリ**が `DOC_LIGHT_SKIP`（rc=0）で**素通り** |
| **TASK 文脈あり**（`PLANGATE_HOOK_TASK` 設定） | **9 カテゴリ × 6 変換クラス = 81 中 52 組合せが rc=0 で完全通過**（実測・後掲） |

`ta-65` TC-07 が固定している 4 ケースは、この 52 組合せの**部分集合**です。

---

## 1. 現状の実測（`origin/main` = `01c8946`）

### 1.1 検証方法（**rc で判定しない / env を unset する**）

```sh
env -u PLANGATE_HOOK_TASK -u PLANGATE_SKIP_REASON -u PLANGATE_HOOK_FILE \
    -u PLANGATE_HOOK_STRICT -u PLANGATE_BYPASS_HOOK \
    sh "<hook>" "" "<target>" </dev/null
```

- **`rc` ではなく標準出力/標準エラーの `HARDENING_OVERRIDE` 文字列で判定**する。
  非 `.md` は doc-light に落ちず `SKIP 拒否` で rc=2 を返すため、**HO を壊しても rc は 2 のまま**変わらない（#1101 コメントの false green 指摘を本書でも再現確認）。
- `target_file=${PLANGATE_HOOK_FILE:-${2:-}}` により **env が位置引数に優先**するため、`PLANGATE_HOOK_FILE` が残った端末では全ケースが同一ファイルを測る。**必ず unset する**。
- 検証はすべて **サンドボックス複製**（`base/` = 現 main、`pat/` = patch 適用後）で実施。リポジトリ本体の hook は**一切編集していない**。

### 1.2 渡された前提の再確認結果

| 前提として渡された実測 | 本書の再測定 | 判定 |
|---|---|---|
| `rc=2 CLAUDE.md → HARDENING_OVERRIDE` | 一致 | OK |
| `rc=0 docs/working/templates/../../../CLAUDE.md → DOC_LIGHT_SKIP` | 一致（`docs/../CLAUDE.md` でも同じ） | OK |
| `rc=0 Claude.md → DOC_LIGHT_SKIP` | 一致 | OK |
| `rc=0 .claude/Rules/x.md → DOC_LIGHT_SKIP` | 一致 | OK |
| `rc=2 bin/../bin/plangate` は「HO は発火せず別理由で止まっているだけ」 | **no-task では一致。ただし TASK 文脈では rc=0 で完全通過** | **補強が必要** |
| `Claude.md` で `CLAUDE.md` が読める（FS 到達可能） | `head -1 Claude.md` → `# CLAUDE.md`。**一致** | OK |

**食い違いはありませんでしたが、1 点が過小評価でした**: `bin/../bin/plangate` は no-task では確かに「別理由で rc=2」ですが、**`PLANGATE_HOOK_TASK` を設定した通常の exec セッションでは rc=0（何の block も無し）で通過**します。issue 本文の元の再現手順（`PLANGATE_HOOK_TASK=TASK-9999`）どおりです。

### 1.3 追加で検出した変換クラス（issue 本文に未記載）

| クラス | 例 | 現 main（TASK 文脈） | FS 到達可能性 |
|---|---|---|---|
| **`/./` 中間** | `bin/./plangate` | **rc=0 通過** | **到達可能**（`open("bin/./plangate")` は成功） |
| **末尾 `/`** | `CLAUDE.md/` | **rc=0 通過** | **到達不可**（`ENOTDIR`）。block 側の hardening として塞ぐ |
| **先頭空白** | `"\tCLAUDE.md"` | rc=0 通過 | 到達不可（別名ファイル）。同上 |
| **repo root 前置部の大小文字** | `/USERS/.../CLAUDE.md` | 現 main は `_norm_target` を小文字化しないため root 除去も case-sensitive | 到達可能（case-insensitive FS） |

`/./` は **`..` と同じく実在ファイルに到達する**ため、`..` と同格で塞ぐ必要があります。

### 1.4 パターン形状依存（issue 本文の観察の裏付け）

`schemas//x.schema.json` と `schemas/./x.schema.json` は **現 main でも既に rc=2 HO** です。POSIX の `case` glob では `*` が `/` を跨いで一致するため、`schemas/*.schema.json` が偶然これらを拾います。**「穴はパターン形状に依存する」= 防御が偶然に依存している**状態であり、これも正規化で決定論化します。

---

## 2. 設計

### 2.1 `..` / `//` の扱い — **解決せず fail-closed（採用）**

**採用理由**:

1. **可搬性**: `realpath` は macOS 標準では存在せず（coreutils 依存）、`readlink -f` は BSD/GNU で挙動が違う。POSIX sh で書ける保証がない（issue 本文の懸念）。
2. **FS へ触れない**: `realpath` は**存在しないパスの扱いが実装依存**で、かつ symlink を解決するため hook が FS 状態に依存する。HO 判定は**字句のみ**で決まるべき。
3. **前例が repo 内にある**: `scripts/ai-loop/arbiter.py::_normalize_path` は既に `..` / `//` / 絶対パス / バックスラッシュを**拒否**している（`arbiter.py:344-355`）。fail-closed は本 repo の既定の作法。
4. **#1135 patch の「差分 0」と同形**: `docs/working/_reports/1135-ai-owned-lane-patch.md` の `_trav` をそのまま流用でき、両 PBI で判定が二重化しない。
5. **`..` を畳む実装は事故った**: 未マージ `8b604fe` の `_pg_fold_path` はセグメント走査で `..` を畳んでいたが、その過程で導入された `_pg_fold_tolower`（1 文字ループ）が O(n²) を招いた。**畳まなければ走査自体が不要**になる。

**却下した案**:

| 案 | 却下理由 |
|---|---|
| `realpath` / `readlink -f` で解決 | 可搬性（AC-4 の 4 シェル / macOS 既定環境で成立しない） |
| `python3` で `posixpath.normpath` | hook が Python 依存になる（現 hook の maintenance 判定は `python3` を使うが `\|\| true` でフォールバックしており、**HO 判定を Python 依存にはできない**） |
| セグメント走査で字句的に畳む（`8b604fe` 方式） | 実装が長く、`..` の root 越え・絶対/相対・末尾スラッシュの分岐が増え、そこに O(n²) が紛れ込んだ実績がある |

**副作用は「block が増える」方向のみ**です（§4 に一覧）。

### 2.2 大小文字 — **非対称に入れる**

```
HO 判定（block する側）  : 小文字化する      → 過剰検出しても block が増えるだけ = 安全側
doc-light 判定（通す側） : 小文字化しない    → 通す範囲が広がると穴になる = 危険
```

**具体的には `_norm_target` を書き換えず、HO 専用キー `_ho_key` を新設**します。理由:

- `_norm_target` は **doc-light（`_dl_ext`）/ maintenance（`allowed_paths` の `fnmatchcase`）/ c3.json conversation 判定**の 3 経路で共有されている。小文字化すると **`fnmatchcase` の意味が変わり、maintenance の許可範囲が広がりうる**（= 通す側の拡大）。
- `check-plan-hash.sh` には既に `_tf_lc`（末尾空白除去 + 小文字化）があるが、**`plan.md` 判定にしか使われていない**。コメントには「macOS は既定で大文字小文字非区別 → `PLAN.md` で OS 上は `plan.md` 改変可能」と**危険性が明記されている**のに、**同じ理由が HO に適用されていない**。本 patch はその非対称を解消する。
- Linux（case-sensitive FS）では `Claude.md` は別ファイルなので**誤検出になりうる**が、**block 側なので安全側**。誤検出時のコストは「Human 承認フローに回る」だけ。

**HO の `case` パターンを小文字側に書き換える**必要があります（`AGENTS.md|CLAUDE.md` → `agents.md|claude.md`）。他 8 カテゴリは元から小文字なので変更不要。

### 2.3 適用順（**順序に依存する事故を実測で 2 件検出**）

```
(1) 前後空白の除去 + 小文字化           ← 外部コマンド 1 パイプライン
(2) traversal fail-closed 判定           ← (3) より前
(3) 先頭 `./` 除去 / 末尾 `/` 除去
(4) repo root 除去（小文字化済み同士）    ← (1) より後
```

- **(2) を (3) より後ろに置くと `.//CLAUDE.md` が素通りします。** 先に `./` を剥がすと `/CLAUDE.md`（絶対パス形）になり、`//` 検知に一致しなくなる。**本作業中に実測で検出**（初版の設計はこの順序で穴が残っていた）。
- **(4) を (1) より前に置くと `/USERS/.../CLAUDE.md` が素通りします。** repo root 前置部だけ大文字にした絶対パスは case-insensitive FS で同一実体に到達する。root 側も同じ写像を通してから比較する。（この知見は `8b604fe` の PR 前レビューで既に検出済み。本 patch でも維持）
- 末尾 `/` 除去は **1 回だけ**（`${_ho_key%/}`）。連続スラッシュ `x//` は (2) で既に block 済みなのでループ不要 = **入力長に対して線形**。

### 2.4 性能設計 — **1 文字ループを採らない**

| 方式 | fork | 計算量 | 判定 |
|---|---|---|---|
| `8b604fe` の `_pg_fold_tolower`（1 文字シェルループ） | 0 | **ほぼ O(n²)** | **却下**（3,009 文字で 13,135ms / 20,000 文字で 10 分未完） |
| **`printf \| sed \| tr` の 1 パイプライン**（本案） | **2**（+ root 用に `tr` 1） | **O(n)**（`sed`/`tr` はストリーム 1 パス） | **採用** |
| `awk` 1 回 | 1 | O(n) | 可。ただし **同ファイルの `_tf_lc` が既に `sed \| tr`** を使っており、書式を揃える方を優先 |

**「fork を増やさない」という制約が O(n²) を招きました。** `check-plan-hash.sh` は既に `_tf_lc` / `_dl_ext` / `sha256_of` / `date` で fork しており、**fork 3 個の追加は計測可能なほど小さい**（§5.5）。**EH-3 に timeout が無い以上、暴走は block ではなくハングになる**ため、定数コストより計算量を優先します。

セグメント数の上限（`8b604fe` の `_PG_FOLD_MAXSEG=256`）は **総文字数を制限しないので防御になりません**（1 セグメント × 20,000 文字は上限を通過する）。本案は**上限を持たず、そもそも入力長に線形**であることで解決します。

---

## 3. 差分（`scripts/hooks/check-plan-hash.sh`）

> **AI は本差分を適用しません**（HO 対象パス）。適用は Human-owned。
> アンカー: `# (ii) Hardening Override 物理先頭判定（R-003/R-015、maintenance より上）` から
> 直後の `if [ "$_override" = "1" ]; then … fi` まで（現 main で **1 箇所のみ**）。

```diff
--- a/scripts/hooks/check-plan-hash.sh
+++ b/scripts/hooks/check-plan-hash.sh
@@ -88,11 +88,54 @@
 esac
 case "$_norm_target" in
   "$REPO_ROOT"/*) _norm_target="${_norm_target#$REPO_ROOT/}" ;;
+esac
+
+# (i-b) HO 判定専用キー _ho_key の導出（#1101 / TASK-1101）
+#   前後空白の除去 + 小文字化を **外部コマンド 1 パイプライン**で行う。
+#   1 文字ずつ回すシェルループは入力長に対して O(n^2) となり、EH-3 に timeout が
+#   無いため暴走が block ではなく**ハング**になる（8b604fe の実測: 3009 文字で 13s、
+#   20000 文字で 10 分未完）。同じ 2 段パイプは同ファイルの _tf_lc が既に使用。
+#   **_norm_target は書き換えない**: doc-light / maintenance / c3 判定（= 通す側）は
+#   大小文字に感応したまま残し、小文字化は block 側にだけ入れる（非対称設計）。
+_ho_key=$(printf '%s' "${target_file:-}" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | tr 'A-Z' 'a-z')
+
+# (i-c) traversal fail-closed（#1101 / #1135 の _trav と同形）
+#   `..` / `//` / `/./` を含むパスは**字句解決せず一律 block** する。
+#   realpath / readlink -f は GNU/BSD 差があり POSIX sh で可搬性に難がある(#1101 本文)。
+#   **先頭 `./` 除去より前**に判定する：先に `./` を取ると `.//CLAUDE.md` が
+#   `/CLAUDE.md`（絶対パス形）になり `//` 検知をすり抜ける（実測で検出）。
+#   先頭 `/`（絶対パス）と単独の先頭 `./` は traversal ではないので除外する。
+_ho_trav=0
+case "$_ho_key" in
+  ..|../*|*/..|*/../*) _ho_trav=1 ;;
+  *//*)                _ho_trav=1 ;;
+  .|*/.|*/./*)         _ho_trav=1 ;;
+esac
+if [ "$_ho_trav" = "1" ]; then
+  reason="HARDENING_OVERRIDE: ${target_file:-} は正規化できないパス表記 (fail-closed: path traversal)"
+  log_event "HARDENING_OVERRIDE" "$reason"
+  printf '[Hook EH-3] %s\n' "$reason" >&2
+  exit 2
+fi
+
+# (i-d) 先頭 `./` 除去と末尾 `/` 除去（traversal 判定を通った後）
+#   末尾 `/` を残すと `CLAUDE.md/` が HO に一致せず、TASK 文脈ありで rc=0 になる。
+#   連続スラッシュ (`x//`) は上の `*//*` で既に block 済みなので 1 回で足りる
+#   （ループを回さない = 入力長に対して線形）。
+case "$_ho_key" in
+  ./*) _ho_key="${_ho_key#./}" ;;
+esac
+_ho_key="${_ho_key%/}"
+_ho_root=$(printf '%s' "$REPO_ROOT" | tr 'A-Z' 'a-z')
+case "$_ho_key" in
+  "$_ho_root"/*) _ho_key="${_ho_key#"$_ho_root"/}" ;;
 esac
 
 # (ii) Hardening Override 物理先頭判定（R-003/R-015、maintenance より上）
+# 判定対象は _ho_key（前後空白除去 + 小文字化済み）。よって case も小文字側で受ける。
+# 9 カテゴリの正本は .claude/rules/mode-classification.md（内容は不変）。
 _override=0
-case "$_norm_target" in
+case "$_ho_key" in
   .claude/rules/*.md) _override=1 ;;
   .claude/settings.json|.claude/settings.local.json|.claude/settings.example.json) _override=1 ;;
   .claude/commands/*.md|.claude/commands/*/*.md) _override=1 ;;
@@ -101,10 +144,11 @@
   bin/plangate) _override=1 ;;
   schemas/*.schema.json) _override=1 ;;
   .github/workflows/*.yml|.github/workflows/*.yaml) _override=1 ;;
-  AGENTS.md|CLAUDE.md) _override=1 ;;
+  agents.md|claude.md) _override=1 ;;
 esac
 if [ "$_override" = "1" ]; then
-  reason="HARDENING_OVERRIDE: ${_norm_target} は maintenance 窓内でも常時 block (R-003/R-015)"
+  # 監査ログ / reason には**生の要求パス**を残す（正規化後の値ではない）
+  reason="HARDENING_OVERRIDE: ${target_file:-} は maintenance 窓内でも常時 block (R-003/R-015)"
   log_event "HARDENING_OVERRIDE" "$reason"
   printf '[Hook EH-3] %s\n' "$reason" >&2
   exit 2
```

### 3.1 `reason` を生の `target_file` にする理由

監査ログに正規化後の値（`_ho_key`）を書くと、**攻撃の原文（`bin/../bin/plangate`）が記録から消えます**。「何が要求されたか」を残すため、`reason` は生値にします。判定に使うのは `_ho_key`、記録に残すのは `target_file` という分離です。

### 3.2 既存の apply スクリプトとの整合

`scripts/apply-eh3-ho-always.sh`（#1089 の apply スクリプト）は適用済み判定を **`hook_applied = i_override < i_branch`**（`_override` が no-task 分岐より前にあるか）というインデックス比較で行っています。本 patch は `_override` を分岐より前に置いたままなので、**同スクリプトは引き続き "already applied" を返し、破壊されません**（実装確認済み）。

---

## 4. 既存挙動の変更（**全件**）

### 4.1 変わるもの

| # | 条件 | 変更前 | 変更後 | 危険度 |
|---|---|---|---|---|
| **B-1** | **HO 9 カテゴリ × `..` / `//` / `/./` / 大小文字 / 前後空白 / 末尾 `/`** | rc=0 通過（TASK 文脈）/ `DOC_LIGHT_SKIP` or `SKIP 拒否`（no-task） | **rc=2 `HARDENING_OVERRIDE`** | 是正そのもの |
| **B-2** | **非 HO の `.md` で `..` / `//` / `/./` を含むパス**（例 `docs/x/../y.md`） | rc=0 `DOC_LIGHT_SKIP` | **rc=2 `HARDENING_OVERRIDE`（fail-closed）** | **唯一の「通っていたものが止まる」変更** |
| **B-3** | 非 HO の**非 `.md`** で `..` 等を含むパス | rc=2 `SKIP 拒否`（no-task）/ rc=0（TASK 文脈） | rc=2 `HARDENING_OVERRIDE` | 実害小（no-task は元から rc=2） |
| **B-4** | HO パスを **`./` 前置 / 絶対パス**で渡したときの `reason` 文字列 | 正規化後の値（`CLAUDE.md`） | **生値（`./CLAUDE.md`）** | ログ表記のみ。文字列 assert するテストは repo 内に**無し**（`git grep 'maintenance 窓内でも常時 block' -- tests` → 0 件） |

**B-2 が「変わる挙動」の本体**です。#1135 patch の注記どおり `docs/x/../y.md` が rc=0 → rc=2 になります。

### 4.2 変わらないもの（実測で確認）

| 対象 | 変更前 | 変更後 |
|---|---|---|
| `docs/ai/hook-enforcement.md` | `DOC_LIGHT_SKIP` | 同 |
| `docs/ai/hook-enforcement.MD`（**非 HO の大文字 `.md`**） | `DOC_LIGHT_SKIP` | 同（`_dl_ext` は元から小文字化済み） |
| `evil/CLAUDE.md`（HO の**近傍**） | `DOC_LIGHT_SKIP` | 同（HO は repo root 起点の完全一致） |
| `docs/.claude/rules/x.md` / `.claudex/rules/x.md` | `DOC_LIGHT_SKIP` | 同 |
| `docs/working/templates/plan.md` | `BLOCK: plan.md` | 同 |
| `/tmp/foo.md`（repo 外の絶対パス） | `DOC_LIGHT_SKIP` | 同（絶対パスを traversal 扱いしない） |
| `tests/extras/ta-09-metrics.sh` / `scripts/lib/foo.sh` | `SKIP 拒否` | 同 |
| **`ta-65` TC-06 の非 HO 10 件**（両文脈） | HO 判定に**拾われない** | 同（**実測: 20 件すべて `HARDENING_OVERRIDE` を出さない**） |

### 4.3 「正当な用途で `..` を含むパスを渡している経路」の調査 → **無し**

| 調査 | 方法 | 結果 |
|---|---|---|
| EH-3 の全呼び出し元 | `git grep -l 'check-plan-hash'`（非 docs）→ 37 ファイルを確認 | 実際に target を渡すのは **`.claude/settings.example.json`（`${PLANGATE_HOOK_FILE:-}`）/ `.codex/hooks/eh-bridge.sh` / `scripts/hooks/cursor-adapter.sh`** の 3 経路。いずれも**ツールから受け取った file_path をそのまま渡すだけで `..` を構築しない** |
| repo 内の `..` を含む文字列リテラル | `git grep '"[^"]*\.\./[^"]*"' -- tests scripts .claude .codex` | 該当は (a) markdown リンク相対パス / (b) `cd -- "$(dirname $0)/../.."`（`cd`+`pwd` で解決済み・target には渡らない）/ (c) `scripts/ai-loop/test_arbiter.py`（`..` を**拒否する**ことのテスト）/ (d) `tests/extras/ta-65-eh3-ho-task-context.sh:344`（**本 issue の KNOWN-GAP TC-07 そのもの**）のみ |
| 実運用の観測 | `docs/working/_audit/skip-decision-log.jsonl`（**193 レコード**）を `grep -c '\.\./'` / `grep -c '//'` | **いずれも 0 件**。EH-3 に `..` / `//` を含む target が到達した記録は**一度も無い** |
| doc-light テストの期待値 | `git grep -l DOC_LIGHT -- tests` → `ta-39` / `ta-61` を確認 | `..` を含む target を `DOC_LIGHT` 期待で渡している TC は**無し** |
| repo 内の前例 | `scripts/ai-loop/arbiter.py:344-355` | **`..` / `//` / 絶対パス / バックスラッシュを既に拒否**。fail-closed は本 repo の既定 |

**結論: `..` を正当に渡している経路は観測範囲に存在しません**（全数保証ではなく、上記 5 系統の実測に基づく）。

---

## 5. 検証結果

### 5.1 直積マトリクス（HO 9 カテゴリ × 変換 9 クラス = 81 件 + 対照 14 件）

**no-task セッション**（`base → patched`、変化のみ太字）:

| カテゴリ | T0 plain | T1 `..` | T2 `//` | T8 `/./` | T3 UPPER | T4 末尾空白 | T5 末尾 `/` | T6 絶対 | T7 `./` |
|---|---|---|---|---|---|---|---|---|---|
| C1 `.claude/rules/*.md` | HO | **DOC_LIGHT→HO** | **DOC_LIGHT→HO** | **DOC_LIGHT→HO** | **DOC_LIGHT→HO** | **SKIP_REFUSED→HO** | **SKIP_REFUSED→HO** | HO | HO |
| C2 `.claude/settings*.json` | HO | **SKIP_REFUSED→HO** | **SKIP_REFUSED→HO** | **SKIP_REFUSED→HO** | **SKIP_REFUSED→HO** | **SKIP_REFUSED→HO** | **SKIP_REFUSED→HO** | HO | HO |
| C3 `.claude/commands/*.md` | HO | **DOC_LIGHT→HO** | **DOC_LIGHT→HO** | **DOC_LIGHT→HO** | **DOC_LIGHT→HO** | **SKIP_REFUSED→HO** | **SKIP_REFUSED→HO** | HO | HO |
| C4 `.claude/agents/*.md` | HO | **DOC_LIGHT→HO** | **DOC_LIGHT→HO** | **DOC_LIGHT→HO** | **DOC_LIGHT→HO** | **SKIP_REFUSED→HO** | **SKIP_REFUSED→HO** | HO | HO |
| C5 `scripts/hooks/*.sh` | HO | **SKIP_REFUSED→HO** | **SKIP_REFUSED→HO** | **SKIP_REFUSED→HO** | **SKIP_REFUSED→HO** | **SKIP_REFUSED→HO** | **SKIP_REFUSED→HO** | HO | HO |
| C6 `bin/plangate` | HO | **SKIP_REFUSED→HO** | **SKIP_REFUSED→HO** | **SKIP_REFUSED→HO** | **SKIP_REFUSED→HO** | **SKIP_REFUSED→HO** | **SKIP_REFUSED→HO** | HO | HO |
| C7 `schemas/*.schema.json` | HO | **SKIP_REFUSED→HO** | HO | HO | **SKIP_REFUSED→HO** | **SKIP_REFUSED→HO** | **SKIP_REFUSED→HO** | HO | HO |
| C8 `.github/workflows/*.yml` | HO | **SKIP_REFUSED→HO** | **SKIP_REFUSED→HO** | **SKIP_REFUSED→HO** | **SKIP_REFUSED→HO** | **SKIP_REFUSED→HO** | **SKIP_REFUSED→HO** | HO | HO |
| C9 `CLAUDE.md` / `AGENTS.md` | HO | **DOC_LIGHT→HO** | **DOC_LIGHT→HO** | **DOC_LIGHT→HO** | **DOC_LIGHT→HO** | **SKIP_REFUSED→HO** | **SKIP_REFUSED→HO** | HO | HO |

**TASK 文脈あり**（`PLANGATE_HOOK_TASK=TASK-9999`。`PASS` = rc=0・何の block も無し）:

| カテゴリ | T0 | T1 `..` | T2 `//` | T8 `/./` | T3 UPPER | T4 末尾空白 | T5 末尾 `/` | T6 絶対 | T7 `./` |
|---|---|---|---|---|---|---|---|---|---|
| C1〜C6・C8・C9（8 カテゴリ） | HO | **PASS→HO** | **PASS→HO** | **PASS→HO** | **PASS→HO** | **PASS→HO** | **PASS→HO** | HO | HO |
| C7 `schemas/*.schema.json` | HO | **PASS→HO** | HO | HO | **PASS→HO** | **PASS→HO** | **PASS→HO** | HO | HO |

**現 main の穴 = 52 / 81 組合せ（TASK 文脈）**。patch 後は **81/81 が `HARDENING_OVERRIDE`**。

対照 14 件のうち挙動が変わったのは **`docs/../docs/ai/hook-enforcement.md`（B-2）の 1 件のみ**。残り 13 件は完全一致。

### 5.2 `ta-65` TC-07（issue の 4 ケース）+ 追加 2 ケース

```
                               base(TASK)   patched(TASK)
docs/../CLAUDE.md              rc=0 PASS    rc=2 HARDENING_OVERRIDE
CLAUDE.MD                      rc=0 PASS    rc=2 HARDENING_OVERRIDE
"CLAUDE.md "                   rc=0 PASS    rc=2 HARDENING_OVERRIDE
bin/../bin/plangate            rc=0 PASS    rc=2 HARDENING_OVERRIDE
CLAUDE.md/          (追加)      rc=0 PASS    rc=2 HARDENING_OVERRIDE
bin/plangate/       (追加)      rc=0 PASS    rc=2 HARDENING_OVERRIDE
docs/ai/hook-enforcement.md    rc=0         rc=0            <- 非 HO は不変
docs/working/TASK-9999/plan.md rc=0         rc=0            <- plan_hash 経路は不変
```

**→ `ta-65` TC-07 は fixed 期待へ反転が必要**（現在は「4 件すべてが HO を出さないこと」を PASS 条件にしているため、patch 適用で RED になる。設計どおり）。

### 5.3 変異注入（**正規化関数内の各分岐を壊す / call site は壊さない**）

`.` = そのケースが `HARDENING_OVERRIDE` を出す（TC PASS）/ `X` = 出さない（**TC FAIL = 変異を kill**）

| 変異 | 壊した箇所 | TCws | TCwsL | TCcase | TCcasedir | TCdotdot | TCdbl | TCdotmid | TCabs | TCtrail | TCplain |
|---|---|---|---|---|---|---|---|---|---|---|---|
| （なし） | — | . | . | . | . | . | . | . | . | . | . |
| **M1** | 前後空白除去を丸ごと削除 | **X** | **X** | . | . | . | . | . | . | . | . |
| **M10** | **先頭**空白除去だけ削除 | . | **X** | . | . | . | . | . | . | . | . |
| **M2** | 小文字化を削除 | **X** | **X** | **X** | **X** | . | . | . | **X** | **X** | **X** |
| **M3** | traversal の `..` アームを削除 | . | . | . | . | **X** | . | . | . | . | . |
| **M4** | traversal の `//` アームを削除 | . | . | . | . | . | **X** | . | . | . | . |
| **M5** | traversal の `/./` アームを削除 | . | . | . | . | . | . | **X** | . | . | . |
| **M6** | HO case を `AGENTS.md\|CLAUDE.md` に戻す | **X** | **X** | **X** | . | . | . | . | **X** | **X** | **X** |
| **M7** | HO case を `_norm_target` に戻す | **X** | **X** | **X** | **X** | . | . | . | **X** | **X** | **X** |
| **M8** | repo root 除去を case-sensitive に戻す | . | . | . | . | . | . | . | **X** | . | . |
| **M9** | 末尾 `/` 除去を削除 | . | . | . | . | . | . | . | . | **X** | . |

**10 変異すべてが最低 1 つの TC で kill され、各変異に固有の kill パターンが存在します**（M1↔M10 は TCws / TCwsL で分離、M2↔M6↔M7 は TCcasedir / TCplain の組合せで分離）。

TC の入力:

```
TCws       'CLAUDE.md '            TCwsL      ' CLAUDE.md'
TCcase     'CLAUDE.MD'             TCcasedir  '.CLAUDE/RULES/X.MD'
TCdotdot   'docs/../CLAUDE.md'     TCdbl      '.claude//rules/x.md'
TCdotmid   '.claude/./rules/x.md'  TCabs      '<REPO_ROOT>/CLAUDE.md'
TCtrail    'CLAUDE.md/'            TCplain    'CLAUDE.md'
```

### 5.4 可搬性（AC-4）

`/bin/sh` / `/bin/bash` / `/bin/zsh` / `/bin/dash` / `/bin/ksh` の **5 シェルで 11 ケース全件が同一判定・同一 rc**:

```
order:  plain UPPER dotdot dbl dotmid ws trailslash dotprefix | nonHO abs-tmp evil
sh      HO/2 HO/2 HO/2 HO/2 HO/2 HO/2 HO/2 HO/2 | DL/0 DL/0 DL/0
bash    (同上)   zsh (同上)   dash (同上)   ksh (同上)
```

`realpath` / `readlink -f` を使わないため GNU/BSD 差は発生しません。

### 5.5 性能（**過去の O(n²) 事故を再現しないことの実証**）

20 回実行の平均（同一マシン / 同一サンドボックス）:

| 入力 | 現 main | **本 patch** | delta | `8b604fe`（却下案） |
|---|---:|---:|---:|---:|
| `CLAUDE.md`（len=9） | 37.5 ms | **50.5 ms** | +13.0 ms | +5 ms 相当（88 vs 83） |
| 250 セグメント大文字（len=3,009） | 85.1 ms | **104.2 ms** | +19.1 ms | **+13,054 ms** |
| **1 セグメント × 20,000 文字 大文字**（len=20,010） | 147.0 ms | **284.6 ms** | +137.6 ms | **10 分枠内で未完** |
| 末尾空白 20,000（len=20,009） | 122.4 ms | **111.7 ms** | −10.7 ms | 未測定 |
| `..` × 250（len=759） | 75.9 ms | **44.7 ms** | −31.2 ms | 未測定 |

- **入力長に対して線形**（3,009 → 20,010 文字で delta が 19 → 138 ms、約 7 倍 ≒ 長さ比 6.6 倍）。
- **一部ケースでは patch 後の方が速い**（traversal / 大文字を即 block して以降の処理へ進まないため）。
- **`8b604fe` 比で 3,009 文字時点で約 690 倍高速**。
- **上限ガードは置いていません。** 上限はセグメント数しか縛れず（1 セグメント × 20,000 文字は通過する）、線形なら不要だからです。

---

## 6. 適用手順（Human-owned）

1. §3 の差分を `scripts/hooks/check-plan-hash.sh` へ適用する（アンカーは現 main で 1 箇所のみ）。
2. `tests/extras/ta-65-eh3-ho-task-context.sh` の **TC-07 を fixed 期待へ反転**する（現在の PASS 条件は「4 件が HO を出さないこと」= patch 後は必ず RED）。TC-06（非 HO 10 件）は**変更不要**（実測で PASS 維持）。
3. §5.3 の 10 変異 × 10 TC を回帰テストとして `ta-65` に追加する。
4. `sh tests/run-tests.sh` を実行し rc=0 を確認する（**baseline は適用時点の main で再測定すること。絶対件数を契約値にしない**）。
5. `docs/ai/hook-enforcement.md` の「既知の残存」から本項目を削除する。ただし **#1104（`Bash` 経路には HO 判定が存在しない）は未解決**なので、**「`Edit|Write` 経路では常時 block / `Bash` 経路は #1104 で追跡中」と matcher 別に書く**こと（#1101 コメントの AC-7 追記提案どおり）。

---

## 7. 残存リスク（本 patch で閉じないもの）

| # | 残存 | 理由 / 追跡 |
|---|---|---|
| **R-1** | **`Bash` 経路には HO 判定自体が存在しない** | HO を持つ hook は `check-plan-hash.sh` 1 本のみで `Edit\|Write` matcher にしか配線されていない。**#1104** |
| **R-2** | symlink 経由の到達 | 本 patch は字句のみで判定し FS に触れない（意図的）。`ln -s CLAUDE.md x.md` 経由は塞がらない |
| **R-3** | バックスラッシュ（`a\b/CLAUDE.md` → `DOC_LIGHT_SKIP`） | macOS / Linux では別ファイルであり **FS 到達不能**。Windows / WSL 前提を採るなら `arbiter.py` と同様に拒否すべき。**本 patch のスコープ外** |
| **R-4** | Unicode の大小文字（トルコ語 `İ` / 全角） | `tr 'A-Z' 'a-z'` は ASCII のみ。既存 `_tf_lc` と同じ制約であり本 patch で悪化しない |
| **R-5** | `#1135` patch との適用順 | 本 patch の traversal ガードは `_ho_key` に対して **HO 判定の直前**で効く。`#1135` の AI-owned レーンは**その後段**にあるため、本 patch を先に入れれば `#1135` 側の「差分 0」は**冗長になる**（残しても害はないが二重定義になる）。**どちらを先に入れるかは Human 判断**。本 patch を先に入れる場合、`#1135` patch は差分 0 を落として再測定すること |

---

## 8. 検証の再現手順

すべて `origin/main` = `01c8946` のサンドボックス複製（`base/` と `pat/`）で実施。**リポジトリ本体の `scripts/hooks/check-plan-hash.sh` は編集していない**（`git status` で確認済み）。

```sh
# 1) サンドボックス 2 面を作る
mkdir -p sb/base/scripts/hooks sb/base/docs/working/_audit
mkdir -p sb/pat/scripts/hooks  sb/pat/docs/working/_audit
cp scripts/hooks/check-plan-hash.sh sb/base/scripts/hooks/
cp scripts/hooks/check-plan-hash.sh sb/pat/scripts/hooks/
# 2) sb/pat 側へ §3 の差分を適用する
# 3) 各 target を env unset で実行し、rc ではなく出力文字列で判定する
env -u PLANGATE_HOOK_TASK -u PLANGATE_SKIP_REASON -u PLANGATE_HOOK_FILE \
    -u PLANGATE_HOOK_STRICT -u PLANGATE_BYPASS_HOOK \
    sh sb/pat/scripts/hooks/check-plan-hash.sh "" "<target>" </dev/null
```

`REPO_ROOT` は `$(dirname "$0")/../..` で解決されるため、サンドボックス側の hook はサンドボックスを root と見なします（絶対パス TC はこの root を使って生成する）。

## 9. 関連

- **#1101**（本 issue）/ **#1089**（PR #1097 で是正済の隣接欠陥）/ **#1104**（`Bash` 経路に HO 判定が無い）/ **#1135**（AI-owned レーン。traversal ガードを共有）/ **#1144**（hook 配布。本 patch を前提とする）
- [`1135-ai-owned-lane-patch.md`](./1135-ai-owned-lane-patch.md) §差分 0
- `tests/extras/ta-65-eh3-ho-task-context.sh` TC-06 / TC-07
- `scripts/ai-loop/arbiter.py::_normalize_path`（fail-closed の前例）
- 未マージ `feat/1101-ho-normalization` = `8b604fe`（**却下した O(n²) 実装の一次記録**）
