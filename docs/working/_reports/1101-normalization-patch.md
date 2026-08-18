# #1101 patch 設計 — Hardening Override のパス正規化（**Human 適用**）

> 対象: `scripts/hooks/check-plan-hash.sh`（**Hardening Override 対象パス**）
> 測定基点: `origin/main` = `01c8946` / 2026-08-18 / macOS 25.6.0（APFS case-insensitive）/ `/bin/sh` = bash 3.2 / BSD sed・BSD tr
> 責務: **設計・差分・検証設計は AI-owned（本書）/ 適用は Human-owned**
> 位置づけ: **#1144 で hook を配布する前に閉じるべき筆頭**。#1135 patch の「差分 0」と同形の traversal ガードを含む
> 版: **rev3**

## 版の履歴（撤回した主張を明示する）

| 版 | 何を変えたか | 撤回した主張 |
|---|---|---|
| rev1 | 初版 | — |
| rev2 | 末尾 `/` 除去に `case` ガード / 空キー fail-closed / 順序事故の回帰 TC | **「入力長に線形なので上限ガード不要」**（無ガードの `${var%/}` が bash 3.2 で O(n²)） |
| **rev3** | **`LC_ALL=C` を正規化パイプラインへ内側固定** / TC を OS・環境非依存へ作り直し | **「5 シェルで同一挙動＝可搬」**（**シェル可搬性であって OS 可搬性ではない**）/ **「15 変異すべてが最低 1 つの TC で kill される」**（**測定環境の REPO_ROOT に大文字があることに依存していた**）/ **`badutf` TC の有効性**（macOS 専用） |

## 結論先行

**承認境界のパス集合（HO 9 カテゴリ）は変更しません。** 変えるのは **「HO 判定が何をキーに glob 照合するか」1 箇所**だけです。

- **block する側（HO 判定）**にだけ HO 専用キー `_ho_key` を導出する
- **通す側（doc-light / maintenance / c3 判定）が使う `_norm_target` は一切変更しない**
- `..` は **解決せず fail-closed で弾く**（`realpath` / `readlink -f` に依存しない）
- **パラメータ展開による除去は必ず `case` で前置ガードする**（無ガードの `${var%/}` は bash 3.2 で O(n²)。§2.4）
- **`sed` / `tr` は `LC_ALL=C` を内側固定する**（固定しないと非 UTF-8 ロケールで `CLAUDE.md` すら HO 判定から外れる。§2.6）
- **正規化パイプラインが空キーを返したら block する**（§2.5）

### 現状の穴の規模

| 文脈 | 現 main の穴 |
|---|---|
| **no-task** セッション | HO 9 カテゴリのうち **`.md` を含む 4 カテゴリ**が `DOC_LIGHT_SKIP`（rc=0）で**素通り** |
| **TASK 文脈あり**（`PLANGATE_HOOK_TASK` 設定） | **9 カテゴリ × 9 変換クラス = 81 中 52 組合せが rc=0 で完全通過**（実測・§5.1） |

`ta-65` TC-07 が固定している 4 ケースは、この 52 組合せの**部分集合**です。

---

## 1. 現状の実測（`origin/main` = `01c8946`）

### 1.1 検証方法（**rc で判定しない / env を unset する / ロケールを固定する**）

```sh
env -u PLANGATE_HOOK_TASK -u PLANGATE_SKIP_REASON -u PLANGATE_HOOK_FILE \
    -u PLANGATE_HOOK_STRICT -u PLANGATE_BYPASS_HOOK LC_ALL=C LANG=C \
    sh "<hook>" "" "<target>" </dev/null
```

- **`rc` ではなく標準出力/標準エラーの `HARDENING_OVERRIDE` 文字列で判定**する。
  非 `.md` は doc-light に落ちず `SKIP 拒否` で rc=2 を返すため、**HO を壊しても rc は 2 のまま**変わらない。
- `target_file=${PLANGATE_HOOK_FILE:-${2:-}}` により **env が位置引数に優先**するため、`PLANGATE_HOOK_FILE` が残った端末では全ケースが同一ファイルを測る。**必ず unset する**。
- **`LC_ALL` / `LANG` も測定条件に含める**（§2.6 のとおり判定結果がロケールに依存しうるため）。ロケールを書かない測定結果は再現性がない。
- 検証はすべて **サンドボックス複製**で実施（`base/` = 現 main、`pat/` = rev3、`rev2/` = 比較用、UPPERCASE root の変異体サンドボックス）。**リポジトリ本体の hook は編集も実行もしていない**（執筆に伴う `Write` の PreToolUse 発火は §8 参照）。

### 1.2 渡された前提の再確認結果

| 前提として渡された実測 | 本書の再測定 | 判定 |
|---|---|---|
| `rc=2 CLAUDE.md → HARDENING_OVERRIDE` | 一致 | OK |
| `rc=0 docs/working/templates/../../../CLAUDE.md → DOC_LIGHT_SKIP` | 一致 | OK |
| `rc=0 Claude.md → DOC_LIGHT_SKIP` | 一致 | OK |
| `rc=0 .claude/Rules/x.md → DOC_LIGHT_SKIP` | 一致 | OK |
| `rc=2 bin/../bin/plangate` は「HO は発火せず別理由で止まっているだけ」 | **no-task では一致。TASK 文脈では rc=0 で完全通過** | **補強が必要** |
| `Claude.md` で `CLAUDE.md` が読める（FS 到達可能） | `head -1 Claude.md` → `# CLAUDE.md`。一致 | OK |

### 1.3 追加で検出した変換クラス（issue 本文に未記載）

| クラス | 例 | 現 main（TASK 文脈） | FS 到達可能性 |
|---|---|---|---|
| **`/./` 中間** | `bin/./plangate` | **rc=0 通過** | **到達可能** |
| **`.//` 先頭** | `.//CLAUDE.md` | **rc=0 通過** | **到達可能**（APFS で実ファイル） |
| **`../<repo 名>/` 往復** | `../plangate/CLAUDE.md` | **rc=0 通過** | **到達可能** |
| **末尾 `/`** | `CLAUDE.md/` | **rc=0 通過** | 到達不可（`ENOTDIR`）。block 側の hardening として塞ぐ |
| **前後空白** | `"\tCLAUDE.md"` / `"CLAUDE.md "` | rc=0 通過 | 到達不可（別名ファイル）。同上 |
| **repo root 前置部の大小文字** | `/USERS/.../CLAUDE.md` | 現 main は `_norm_target` を小文字化しないため root 除去も case-sensitive | 到達可能（case-insensitive FS） |

### 1.4 パターン形状依存

`schemas//x.schema.json` と `schemas/./x.schema.json` は **現 main でも既に rc=2 HO** です。POSIX の `case` glob では `*` が `/` を跨いで一致するため、`schemas/*.schema.json` が偶然これらを拾います。**防御が偶然に依存している**状態であり、正規化で決定論化します。

---

## 2. 設計

### 2.0 設計判断の代償を先に書く

**現 main はこの位置でパラメータ展開と `case` しか使っておらず、fork ゼロ・ロケール非依存です。** 本 patch は「小文字化と空白除去を 1 パスで済ませる」ために **`sed` / `tr` という外部バイナリ 2 本を持ち込みます**。その代償は 2 つあり、**どちらも実測で穴として顕在化しました**:

| 代償 | 顕在化 | 対処 |
|---|---|---|
| **ロケール依存**（BSD `tr` は照合順で解釈する） | **非 UTF-8 ロケールで `CLAUDE.md` が HO 判定から外れる**（rev2 の退行） | `LC_ALL=C` を内側固定（§2.6） |
| **実装差 / 失敗の伝播**（BSD sed と GNU sed で不正バイトの扱いが違う。パイプライン終了ステータスは最後の `tr` のもの） | 空キー fail-open / TC の OS 依存 | 空キー fail-closed（§2.5）+ `LC_ALL=C` で両実装の挙動を揃える（§2.6） |

外部コマンドを使わない代替（1 文字シェルループ）は **O(n²) で不採用**（§2.4）。**「fork を避ける」と「外部コマンドを使う」のどちらにも代償があり、本 patch は後者を選んだうえで代償を明示的に閉じる方針**です。

### 2.1 `..` / `//` の扱い — **解決せず fail-closed（採用）**

1. **可搬性**: `realpath` は macOS 標準では存在せず、`readlink -f` は BSD/GNU で挙動が違う。
2. **FS へ触れない**: HO 判定は**字句のみ**で決まるべき。
3. **前例が repo 内にある**: `scripts/ai-loop/arbiter.py::_normalize_path`（`arbiter.py:344-355`）は既に `..` / `//` / 絶対パス / バックスラッシュを拒否している。
4. **#1135 patch の「差分 0」と同形**: `_trav` をそのまま流用でき、判定が二重化しない。
5. **`..` を畳む実装は事故った**: `8b604fe:tests/fixtures/pg-fold-path.sh` のセグメント走査に O(n²) が紛れ込んだ。**畳まなければ走査自体が不要**。

**却下した案**: `realpath` / `readlink -f`（可搬性）/ `python3` の `posixpath.normpath`（HO 判定を Python 依存にできない）/ セグメント走査（`8b604fe` の前例）。

### 2.2 大小文字 — **非対称に入れる**

```
HO 判定（block する側）  : 小文字化する      → 過剰検出しても block が増えるだけ = 安全側
doc-light 判定（通す側） : 小文字化しない    → 通す範囲が広がると穴になる = 危険
```

`_norm_target` は **doc-light（`_dl_ext`）/ maintenance（`allowed_paths` の `fnmatchcase`）/ c3.json conversation 判定**の 3 経路で共有されているため書き換えず、**HO 専用キー `_ho_key` を新設**します。`check-plan-hash.sh` には既に `_tf_lc` があるのに **`plan.md` 判定にしか使われていない**という非対称を解消するものです。

HO の `case` パターンは小文字側に書き換えます（`AGENTS.md|CLAUDE.md` → `agents.md|claude.md`）。

### 2.3 適用順（**順序に依存する事故を実測で 2 件検出**）

```
(1) 前後空白の除去 + 小文字化（LC_ALL=C 固定）
(2) 空キー fail-closed                   ← §2.5
(3) traversal fail-closed 判定           ← ★ (4) より前
(4) 先頭 `./` 除去 / 末尾 `/` 除去       ← ★ どちらも case で前置ガード（§2.4）
(5) repo root 除去（小文字化済み同士）    ← ★ (1) より後
```

- **★ (3) を (4) より後ろに置くと `.//CLAUDE.md` が素通りします。** 先に `./` を剥がすと `/CLAUDE.md`（絶対パス形）になり `//` 検知に一致しない。**回帰テスト = 変異 MX1 / 入力 `dotdbl`**。
- **★ (5) を (1) より前に置くと `<REPO_ROOT を大文字化>/CLAUDE.md` が素通りします。** **回帰テスト = 変異 MX2b / 入力 `absup`**。
- traversal の `..` アームは **`..|../*` と `*/..|*/../*` の両方が必要**。前者だけ外すと `../<repo 名>/CLAUDE.md` が素通りする。**回帰テスト = 変異 MX3 / 入力 `parent`**。

### 2.4 性能 — rev1 の「線形だから上限不要」を撤回する

`/bin/sh`（bash 3.2）で **パターンに一致しないときの `${var%pat}` は入力長に対して二次**です（5 回ループ / 末尾スラッシュ無しの文字列）:

| len | `${k%/}`（無ガード = rev1） | `case "$k" in */) ... esac`（rev2 以降） |
|---:|---:|---:|
| 25,000 | **822 ms** | 62 ms |
| 50,000 | **3,083 ms** | 65 ms |
| 100,000 | **12,093 ms** | 74 ms |
| 200,000 | **48,207 ms** | 92 ms |

**倍化ごとに約 4 倍 = O(n²)。**

**なぜ rev1 は誤ったか**: 3,009 と 20,010 の **2 点しか測っておらず、その帯域は fork が支配的**でした。二次の項は全体の 1 割にも満たず、2 点を結ぶと直線に見えます。**「2 点が直線に乗る」ことは線形性の証拠になりません。**

**是正**: `case "$_ho_key" in */) _ho_key="${_ho_key%/}" ;; esac`。先頭 `./` 除去と repo root 除去は元から `case` の中にあるため、**patch 内の 3 箇所すべてがガード下**です。

上限ガードは置きません。`8b604fe` のセグメント数上限は総文字数を制限せず防御にならないため、**二次の構文を使わない**方法で解決します（§5.5 の 5 点測定で裏付け）。

### 2.5 空キー fail-closed

パイプラインの終了ステータスは最後の `tr` のものなので、`sed` が落ちても `set -eu` は発火せず **`_ho_key` が空**になります。空キーは HO の `case` のどのアームにも一致せず、**HO 判定が丸ごとスキップ**されます。**Claude Code の PreToolUse は exit 2 のみを block とする**ため、rc=0 も rc=1 も「通す」側です。

```sh
if [ -z "$_ho_key" ] && [ -n "${target_file:-}" ]; then
  reason="HARDENING_OVERRIDE: ${target_file:-} の正規化に失敗 (fail-closed: empty normalization key)"
  ... exit 2
fi
```

#### rev3 で守備範囲が変わりました（**rev2 の TC は無効**）

`LC_ALL=C` を入れると **BSD sed も GNU sed も不正 UTF-8 で失敗しなくなる**ため（§2.6 の実測）、rev2 が使っていた `badutf` 入力は**空キー経路を通らなくなりました**。

**rev3 でこの guard が実際に守るのは以下です**:

| ケース | 空キーになるか | rev3 の挙動 |
|---|---|---|
| **空白のみの target**（`"   "`） | **なる**（前後空白除去で全消し） | **rc=2 `HARDENING_OVERRIDE`**（OS・ロケール非依存。**これが回帰 TC `wsonly`**） |
| `sed` / `tr` が PATH に無い・実行不能 | なる | rc=2（同上） |
| 不正 UTF-8 を含む target | **`LC_ALL=C` により、ならない** | 非空キー（`claude.md` + 生バイト）→ HO 一致せず → 通常経路。**これは正しい**（別名ファイルであり HO 対象ではない） |

**rev2 が `badutf` で HO を出していたのは検出ではなく、`sed` が壊れた副作用**でした。rev3 ではその副作用が消え、代わりに `wsonly` という**決定論的な**入力で guard を検証します。

### 2.6 ロケール依存 — **`LC_ALL=C` を内側固定する（rev3 の是正）**

**BSD `tr 'A-Z' 'a-z'` はロケールの照合順で範囲を解釈するため、非 UTF-8 ロケールで ASCII を破壊します。** 実測（同一マシン / BSD tr）:

| `LC_ALL` | `CLAUDE.md` → | `BIN/PLANGATE` → |
|---|---|---|
| `C` | `claude.md` | `bin/plangate` |
| `en_US.UTF-8` | `claude.md` | `bin/plangate` |
| **`en_US.ISO8859-1`** | **`BKaT..l.`（壊れる）** | **`.HM/.KaMFa..`（壊れる）** |
| **`en_US.ISO8859-15`** | **`BKaT..l.`（壊れる）** | **`.HM/.KaMFa..`（壊れる）** |
| **`en_US.US-ASCII`** | **`claude.LC`（部分的に壊れる）** | `bin/plangate` |

**end-to-end の影響（rev2 = `LC_ALL` 未固定 / TASK 文脈）**:

| target | `LC_ALL` | base（現 main） | **rev2** | **rev3** |
|---|---|---|---|---|
| `CLAUDE.md` | `en_US.ISO8859-1` | HO / rc=2 | **PASS / rc=0** | HO / rc=2 |
| `bin/plangate` | `en_US.ISO8859-1` | HO / rc=2 | **PASS / rc=0** | HO / rc=2 |
| `.claude/settings.json` | `en_US.US-ASCII` | HO / rc=2 | **PASS / rc=0** | HO / rc=2 |
| `schemas/x.schema.json` | `en_US.ISO8859-1` | HO / rc=2 | **PASS / rc=0** | HO / rc=2 |

**最も基本的な入力（無変換の `CLAUDE.md`）で HO が丸ごと無効化される退行**であり、**現 main より弱くなっています**。空キー fail-closed（§2.5）は**キーが非空なので発火しません** — guard が構造的に届いていませんでした。

**是正**: パイプラインの各コマンドに `LC_ALL=C` を**内側で**付ける。

```sh
_ho_key=$(printf '%s' "${target_file:-}" | LC_ALL=C sed '...' | LC_ALL=C tr 'A-Z' 'a-z')
_ho_root=$(printf '%s' "$REPO_ROOT" | LC_ALL=C tr 'A-Z' 'a-z')
```

**外側のロケールがどうであれ内側が `C` に固定される**ため、呼び出し元（Claude Code / Codex bridge / CI）の環境に依存しません。**回帰テスト = 変異 M13 / 入力 `nonutf`（`CLAUDE.md` を `LC_ALL=en_US.ISO8859-1` で実行）**。

**副次効果**: `LC_ALL=C` は **BSD sed と GNU sed の不正バイト時の挙動も一致させます**（両方 rc=0・バイト透過。§5.6）。これが §2.5 の守備範囲変更と N2（TC の OS 依存）の解消につながります。

---

## 3. 差分（`scripts/hooks/check-plan-hash.sh`）

> **AI は本差分を適用しません**（HO 対象パス）。適用は Human-owned。
> アンカー: `# (ii) Hardening Override 物理先頭判定（R-003/R-015、maintenance より上）` から
> 直後の `if [ "$_override" = "1" ]; then … fi` まで（現 main で **1 箇所のみ**）。

```diff
--- a/scripts/hooks/check-plan-hash.sh
+++ b/scripts/hooks/check-plan-hash.sh
@@ -90,9 +90,46 @@
   "$REPO_ROOT"/*) _norm_target="${_norm_target#$REPO_ROOT/}" ;;
 esac
 
+# (i-b) HO 判定専用キー _ho_key の導出（#1101 / TASK-1101）
+#   前後空白の除去 + 小文字化を外部コマンド 1 パイプラインで行う。1 文字ずつ回す
+#   シェルループは O(n^2) になり、EH-3 に timeout が無いため暴走が block ではなく
+#   ハングになる（8b604fe の実測）。
+#   **LC_ALL=C を内側固定する**: BSD tr はロケールの照合順で範囲を解釈するため、
+#   en_US.ISO8859-1 等では 'A-Z' が ASCII 大文字と一致せず CLAUDE.md すら
+#   小文字化に失敗して HO 判定から外れる（#1101 N1 / 実測）。外側の LC_ALL に
+#   依存しないよう各コマンドへ付ける。GNU sed と BSD sed の不正バイト時の挙動も
+#   C ロケールで一致する。
+#   **_norm_target は書き換えない**: doc-light / maintenance / c3 判定（= 通す側）は
+#   大小文字に感応したまま残し、小文字化は block 側にだけ入れる（非対称設計）。
+_ho_key=$(printf '%s' "${target_file:-}" | LC_ALL=C sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | LC_ALL=C tr 'A-Z' 'a-z')
+
+# (i-b2) 正規化の失敗を fail-open にしない（#1101 / F3）
+#   パイプラインの終了ステータスは最後の tr のものなので、sed が落ちても set -eu は
+#   発火せず _ho_key が空になる。空キーは HO の case のどのアームにも一致せず HO
+#   判定が丸ごとスキップされる＝失敗が「通す」側に倒れる。
+#   実際に空キーになるのは「空白のみの target」「sed/tr が実行不能」のケース。
+if [ -z "$_ho_key" ] && [ -n "${target_file:-}" ]; then
+  reason="HARDENING_OVERRIDE: ${target_file:-} の正規化に失敗 (fail-closed: empty normalization key)"
+  log_event "HARDENING_OVERRIDE" "$reason"
+  printf '[Hook EH-3] %s\n' "$reason" >&2
+  exit 2
+fi
+
+# (i-c) traversal fail-closed（#1101 / #1135 の _trav と同形）
+#   `..` / `//` / `/./` を含むパスは字句解決せず一律 block する。
+#   realpath / readlink -f は GNU/BSD 差があり POSIX sh で可搬性に難がある。
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
+#   **除去は必ず case で前置ガードする**: bash 3.2 / ksh の ${var%pat} は一致
+#   しないときの走査が入力長に対して二次で、100000 文字 x5 で 12 秒かかる
+#   （#1101 F1 / 実測）。case は同条件で 74ms と平坦。
+#   連続スラッシュ (`x//`) は上の `*//*` で既に block 済みなので 1 回で足りる。
+case "$_ho_key" in
+  ./*) _ho_key="${_ho_key#./}" ;;
+esac
+case "$_ho_key" in
+  */) _ho_key="${_ho_key%/}" ;;
+esac
+_ho_root=$(printf '%s' "$REPO_ROOT" | LC_ALL=C tr 'A-Z' 'a-z')
+case "$_ho_key" in
+  "$_ho_root"/*) _ho_key="${_ho_key#"$_ho_root"/}" ;;
+esac
+
 # (ii) Hardening Override 物理先頭判定（R-003/R-015、maintenance より上）
+# 判定対象は _ho_key（前後空白除去 + 小文字化済み）。よって case も小文字側で受ける。
+# 9 カテゴリの正本は .claude/rules/mode-classification.md（内容は不変）。
 _override=0
-case "$_norm_target" in
+case "$_ho_key" in
   .claude/rules/*.md) _override=1 ;;
   .claude/settings.json|.claude/settings.local.json|.claude/settings.example.json) _override=1 ;;
   .claude/commands/*.md|.claude/commands/*/*.md) _override=1 ;;
@@ -101,10 +159,11 @@
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

監査ログに正規化後の値を書くと、**攻撃の原文（`bin/../bin/plangate`）が記録から消えます**。判定に使うのは `_ho_key`、記録に残すのは `target_file` という分離です。

### 3.2 既存の apply スクリプトとの整合

`scripts/apply-eh3-ho-always.sh` は適用済み判定を `hook_applied = i_override < i_branch` というインデックス比較で行うため、本 patch 適用後も "already applied" を返し破壊されません。**ただし 9 カテゴリ `case` の第 2 コピーを `:135-143` / `:174-183` に埋め込んでおり正本と乖離します**（§6 step 6）。

---

## 4. 既存挙動の変更（**全件**）

| # | 条件 | 変更前 | 変更後 | 備考 |
|---|---|---|---|---|
| **B-1** | **HO 9 カテゴリ × `..` / `//` / `/./` / 大小文字 / 前後空白 / 末尾 `/`** | rc=0 通過（TASK 文脈）/ `DOC_LIGHT_SKIP` or `SKIP 拒否`（no-task） | **rc=2 `HARDENING_OVERRIDE`** | 是正そのもの |
| **B-1b** | **小文字形**（`claude.md` / `.claude/Rules/x.md` 等）も新規に block | rc=0 通過 | **rc=2** | **case-sensitive FS（Linux CI）では別ファイルへの意図的な過剰 block**。block 側なので安全側。誤検出時のコストは Human 承認フローに回ること |
| **B-2** | **非 HO の `.md` で `..` / `//` / `/./` を含むパス**（例 `docs/x/../y.md`） | rc=0 `DOC_LIGHT_SKIP` | **rc=2** | **唯一の「通っていたものが止まる」変更** |
| **B-3** | 非 HO の**非 `.md`** で `..` 等を含むパス | rc=2 `SKIP 拒否`（no-task）/ rc=0（TASK 文脈） | rc=2 | 実害小 |
| **B-6** | **空白のみの target**（`"   "` / `"\t"`） | `SKIP 拒否` rc=2（no-task）/ **rc=0（TASK 文脈）** | **rc=2 `HARDENING_OVERRIDE`** | §2.5 の guard。**実測: base(C)=SKIP_REFUSED/2, base(UTF-8)=SKIP_REFUSED/2 → rev3 は両方 HO/2** |
| **B-7** | **非 UTF-8 ロケールでの全 HO 判定** | HO（ロケール非依存） | HO（**`LC_ALL=C` 固定により維持**） | **rev2 では退行していた**（§2.6）。rev3 は base と同じ |
| **B-8** | HO パスを **`./` 前置 / 絶対パス**で渡したときの `reason` 文字列 | 正規化後の値 | **生値** | ログ表記のみ。文字列 assert するテストは repo 内に無し（`git grep 'maintenance 窓内でも常時 block' -- tests` → 0 件） |

### 4.1 変わらないもの（実測）

| 対象 | 変更前 → 変更後 |
|---|---|
| `docs/ai/hook-enforcement.md` / `.MD` | `DOC_LIGHT_SKIP` → 同 |
| `evil/CLAUDE.md` / `docs/.claude/rules/x.md` / `.claudex/rules/x.md` | `DOC_LIGHT_SKIP` → 同 |
| `docs/working/templates/plan.md` | `BLOCK: plan.md` → 同 |
| `/tmp/foo.md`（repo 外の絶対パス） | `DOC_LIGHT_SKIP` → 同 |
| `tests/extras/ta-09-metrics.sh` / `scripts/lib/foo.sh` / `notes/claude.mdx` | `SKIP 拒否` → 同 |
| **`ta-65` TC-06 の非 HO 10 件**（両文脈 20 件） | HO 判定に拾われない → 同 |
| `.claude/worktrees/<id>/CLAUDE.md` | `DOC_LIGHT_SKIP` → 同（**§7 R-6 の残存**） |

### 4.2 「正当な用途で `..` を含むパスを渡している経路」の調査 → **観測範囲では無し**

| 調査 | 方法 | 結果 |
|---|---|---|
| EH-3 の全呼び出し元 | `git grep -l 'check-plan-hash'`（非 docs） | target を渡すのは `.claude/settings.example.json` / `.codex/hooks/eh-bridge.sh` / `scripts/hooks/cursor-adapter.sh` の 3 経路。いずれも**受け取った file_path を素通しするだけで `..` を構築しない** |
| repo 内の `..` 文字列リテラル | `git grep '"[^"]*\.\./[^"]*"' -- tests scripts .claude .codex` | markdown リンク / `cd -- "$(dirname $0)/../.."`（解決済み・target に渡らない）/ `test_arbiter.py`（`..` を**拒否する**テスト）/ `ta-65:344`（**KNOWN-GAP TC-07 そのもの**）のみ |
| doc-light テストの期待値 | `git grep -l DOC_LIGHT -- tests` → `ta-39` / `ta-61` | `..` を `DOC_LIGHT` 期待で渡す TC は無し |
| repo 内の前例 | `scripts/ai-loop/arbiter.py:344-355` | 既に `..` / `//` / 絶対パス / バックスラッシュを拒否 |

#### 実運用ログの確認は **件数ではなく条件式で残す**

`docs/working/_audit/skip-decision-log.jsonl` は **append-only** なので絶対件数は測った瞬間から劣化します。**契約値にしないでください。**

```sh
grep -c '\.\./' docs/working/_audit/skip-decision-log.jsonl
grep '\.\./'    docs/working/_audit/skip-decision-log.jsonl   # 中身を見て個別判断
```

**判定条件**: 該当行が **(a) 0 件、または (b) 全件が本 issue の測定・KNOWN-GAP TC 由来**であれば B-2 の実運用影響は無いと判断してよい。

**測定基点でのスナップショット（参考値・契約値ではない）**: `01c8946` の追跡版は 0 件 / 作業ツリー版は 1 件（`2026-08-18T09:59:30Z` の `docs/working/templates/../../../CLAUDE.md` = **#1101 コメントの実測時に記録されたもの**）。

---

## 5. 検証結果

### 5.1 直積マトリクス — **生成規則（独立再現用）**

**カテゴリ代表 C1〜C9**（repo root 相対）:

```
C1 .claude/rules/x.md        C2 .claude/settings.json     C3 .claude/commands/x.md
C4 .claude/agents/x.md       C5 scripts/hooks/x.sh        C6 bin/plangate
C7 schemas/x.schema.json     C8 .github/workflows/x.yml   C9 CLAUDE.md
```

**変換 T0〜T8**（`p` = 代表 / `i` = `p` の**最初の** `/` の位置 / `ROOT` = サンドボックスの REPO_ROOT）:

| 変換 | 規則 | `CLAUDE.md`（`/` 無し）の場合 |
|---|---|---|
| T0 plain | `p` | `CLAUDE.md` |
| T1 `..` | `"docs/../" + p` | `docs/../CLAUDE.md` |
| T2 `//` | `p[:i] + "//" + p[i+1:]` | `.//CLAUDE.md` |
| T8 `/./` | `p[:i] + "/./" + p[i+1:]` | `././CLAUDE.md` |
| T3 UPPER | `p.upper()` | `CLAUDE.MD` |
| T4 末尾空白 | `p + " "`（半角空白 1 個） | `CLAUDE.md ` |
| T5 末尾 `/` | `p + "/"` | `CLAUDE.md/` |
| T6 絶対 | `ROOT + "/" + p` | `<ROOT>/CLAUDE.md` |
| T7 `./` | `"./" + p` | `./CLAUDE.md` |

**9 カテゴリ × 9 変換 = 81 件** + 対照 14 件 = 95 件。

**対照 14 件**:

```
docs/ai/hook-enforcement.md          docs/ai/hook-enforcement.MD
docs/../docs/ai/hook-enforcement.md  docs/working/templates/plan.md
tests/extras/ta-09-metrics.sh        scripts/lib/foo.sh
docs/README.md                       /tmp/foo.md
/tmp/foo.txt                         .claudex/rules/x.md
docs/.claude/rules/x.md              evil/CLAUDE.md
notes/claude.mdx                     <ROOT>/docs/ai/hook-enforcement.md
```

#### 結果（`LC_ALL=C`）

| 文脈 | base の HO | base の PASS/非 HO | **rev3 の HO** |
|---|---:|---:|---:|
| TASK 文脈 | **29 / 81** | **52 / 81**（すべて rc=0 の完全通過） | **81 / 81** |
| no-task | 29 / 81 | 52 / 81（`DOC_LIGHT_SKIP` 20 件 + `SKIP 拒否` 32 件） | **81 / 81** |

**base で HO になる 29 件の内訳**: T0（9）+ T6（9）+ T7（9）= 27、+ C7 の T2 / T8（`schemas/*.schema.json` の `*` が `/` を跨ぐため偶然一致）= **29**。`81 − 29 = 52`。

> **レビュアの再現値は 51/81 でした。** 差は **`/` を含まない `CLAUDE.md` に対する T2 / T8 の定義**にあると考えられます（本書は `.//CLAUDE.md` / `././CLAUDE.md` を採用）。**上の生成規則で 52 になります。**

対照 14 件のうち変わるのは **`docs/../docs/ai/hook-enforcement.md`（B-2）の 1 件のみ**。

### 5.2 `ta-65` TC-07（issue の 4 ケース）+ 追加

```
                                base(TASK)   rev3(TASK)
docs/../CLAUDE.md               rc=0 PASS    rc=2 HARDENING_OVERRIDE
CLAUDE.MD                       rc=0 PASS    rc=2 HARDENING_OVERRIDE
"CLAUDE.md "                    rc=0 PASS    rc=2 HARDENING_OVERRIDE
bin/../bin/plangate             rc=0 PASS    rc=2 HARDENING_OVERRIDE
CLAUDE.md/           (追加)      rc=0 PASS    rc=2 HARDENING_OVERRIDE
bin/plangate/        (追加)      rc=0 PASS    rc=2 HARDENING_OVERRIDE
docs/ai/hook-enforcement.md     rc=0         rc=0            <- 非 HO は不変
docs/working/TASK-9999/plan.md  rc=0         rc=0            <- plan_hash 経路は不変
```

**→ `ta-65` TC-07 は fixed 期待へ反転が必要。**

### 5.3 変異注入

#### 測定環境の前提（**TC 側で作ること**）

- **サンドボックスの REPO_ROOT に大文字セグメントを含めること。** 全小文字の root では **M8 が `abs` / `absup` の両方を生き延びます**（実測・下表）。**GitHub Actions の checkout パス `/home/runner/work/plangate/plangate` は全小文字**なので、root を TC が用意しない限り M8 の検出力は CI でゼロになります。
- 各 TC のロケールを固定すること（`nonutf` のみ `en_US.ISO8859-1`、他は `LC_ALL=C`）。

**M8 の kill が root の大小文字に依存することの実測**（rev3 / `LC_ALL=C`）:

| REPO_ROOT | 変異なし `abs` / `absup` | **M8** `abs` / `absup` |
|---|---|---|
| `/private/tmp/pg1101n3/**UPPER**/sb` | HO / HO | **noHO / noHO（kill 成功）** |
| `/private/tmp/pg1101n3/lower/sb` | HO / HO | **HO / HO（kill 失敗 = 生存）** |

#### TC 入力 15 件

```
ws       'CLAUDE.md '                    wsL      ' CLAUDE.md'
case     'CLAUDE.MD'                     casedir  '.CLAUDE/RULES/X.MD'
dotdot   'docs/../CLAUDE.md'             dbl      '.claude//rules/x.md'
dotmid   '.claude/./rules/x.md'          abs      '<ROOT>/CLAUDE.md'          (*)
trail    'CLAUDE.md/'                    plain    'CLAUDE.md'
dotdbl   './/CLAUDE.md'                  absup    '<ROOT を大文字化>/CLAUDE.md' (*)
parent   '../<ROOT の basename>/CLAUDE.md'
wsonly   '   '（半角空白 3 個）
nonutf   'CLAUDE.md' を LC_ALL=en_US.ISO8859-1 で実行
                                          (*) ROOT は大文字セグメントを含むこと
```

期待値は**全件 `HARDENING_OVERRIDE` を出すこと**（rc ではなく出力文字列で判定）。

#### 結果（`.` = HO を出す = TC PASS / `X` = 出さない = **変異を kill**）

| 変異 | 壊した箇所 | ws | wsL | case | casedir | dotdot | dbl | dotmid | abs | trail | plain | dotdbl | absup | parent | wsonly | nonutf |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| （なし） | — | . | . | . | . | . | . | . | . | . | . | . | . | . | . | . |
| M1 | 前後空白除去を削除 | X | X | X | X | X | X | X | X | X | X | X | X | X | X | X |
| M10 | **先頭**空白除去だけ削除 | . | X | . | . | . | . | . | . | . | . | . | . | . | . | . |
| M2 | 小文字化を削除 | X | X | X | X | . | . | . | X | X | X | . | X | . | . | X |
| M3 | traversal の `..` アーム削除 | . | . | . | . | X | . | . | . | . | . | . | . | X | . | . |
| M4 | traversal の `//` アーム削除 | . | . | . | . | . | X | . | . | . | . | X | . | . | . | . |
| M5 | traversal の `/./` アーム削除 | . | . | . | . | . | . | X | . | . | . | . | . | . | . | . |
| M6 | HO case を `AGENTS.md\|CLAUDE.md` に戻す | X | X | X | . | . | . | . | X | X | X | . | X | . | . | X |
| M7 | HO case を `_norm_target` に戻す | X | X | X | X | . | . | . | X | X | X | . | X | . | . | X |
| M8 | repo root 除去を case-sensitive に | . | . | . | . | . | . | . | **X** | . | . | . | **X** | . | . | . |
| M9 | 末尾 `/` 除去を削除 | . | . | . | . | . | . | . | . | X | . | . | . | . | . | . |
| M11 | **空キー fail-closed を削除** | . | . | . | . | . | . | . | . | . | . | . | . | . | **X** | . |
| M13 | **`tr` の `LC_ALL=C` を削除** | . | . | . | . | . | . | . | . | . | . | . | . | . | . | **X** |
| MX1 | traversal 判定を `./` 除去の後ろへ | . | . | . | . | . | . | . | . | . | . | **X** | . | . | . | . |
| MX2b | repo root 除去を小文字化より前へ | . | . | . | . | . | . | . | . | . | . | . | **X** | . | . | . |
| MX3 | traversal から `..\|../*` だけ削除 | . | . | . | . | . | . | . | . | . | . | . | . | **X** | . | . |

**16 変異中 15 変異が kill されます。**

#### 唯一 kill されない変異 M12 の扱い（**等価または厳格側の変異**）

**M12 = `sed` からだけ `LC_ALL=C` を外す** は 15 TC すべてを生き延びます。**これは検出力の欠落ではなく、変異が HO 判定を弱めないためです。** 実測で全差分を特定しました:

| ロケール | `CLAUDE.md` 変異なし / M12 | 不正 UTF-8 target 変異なし / M12 |
|---|---|---|
| `C` | HO/2 / HO/2 | noHO/2 / noHO/2 |
| **`en_US.UTF-8`** | HO/2 / HO/2 | **noHO/1 / HO/2** |
| `en_US.ISO8859-1` | HO/2 / HO/2 | noHO/2 / noHO/2 |
| `en_US.US-ASCII` | HO/2 / HO/2 | noHO/2 / noHO/2 |

**差は 1 セルだけで、方向は「より block する」側**（`sed` が失敗 → 空キー → §2.5 の fail-closed が発火）。**HO を弱める入力は存在しない**ため、`sed` 側の `LC_ALL=C` は**堅牢性のための冗長**であり kill TC を要求しません。「期待値 = HO」の TC 群では原理的に検出できない（変異体のほうが多く block するため）ことを明記します。

> **rev2 の「15 変異すべてが最低 1 つの TC で kill される」は撤回します。** あの主張は (a) 測定環境の REPO_ROOT に大文字があること、(b) `badutf` が macOS の BSD sed で失敗すること、の 2 つに依存していました。

### 5.4 可搬性 — **シェル可搬性であって OS 可搬性ではない**

`/bin/sh` / `/bin/bash` / `/bin/zsh` / `/bin/dash` / `/bin/ksh` の **5 シェル × 12 ケースで同一判定・同一 rc**（`LC_ALL=C`）:

```
order:  plain UPPER dotdot dbl dotmid ws trail dotprefix dotdbl | nonHO tmp evil
sh      HO/2 HO/2 HO/2 HO/2 HO/2 HO/2 HO/2 HO/2 HO/2 | DL/0 DL/0 DL/0
bash / zsh / dash / ksh  すべて同一
```

**ただしこれは 1 OS（macOS / BSD sed・BSD tr）上の 5 シェルであり、OS 可搬性の主張ではありません。** OS 差に関して実測したのは §5.6 の sed 挙動のみです。**Linux / GNU coreutils 上での全 TC 実行は未実施**であり、`ta-65` 追加時に CI（`ubuntu-latest`）で初めて確認されます（§6 step 3）。

### 5.5 性能

#### (a) 構文レベル（`/bin/sh` = bash 3.2 / 5 回ループ）

§2.4 の表を参照（無ガード `${k%/}` は O(n²)、`case` ガード版は平坦）。

#### (b) hook 全体（5 回平均 / `LC_ALL=C`）

| 入力長 | base | rev3 から `LC_ALL=C` を外したもの | **rev3** |
|---:|---:|---:|---:|
| 9 | 35.8 ms | 46.0 ms | **45.2 ms** |
| 3,009 | 73.7 ms | 89.9 ms | **89.3 ms** |
| 20,010 | 130.8 ms | 148.7 ms | **145.7 ms** |
| 100,000 | 188.7 ms | 221.3 ms | **220.2 ms** |
| 200,000 | 228.8 ms | 272.4 ms | **275.2 ms** |

**`LC_ALL=C` の追加コストは測定誤差の範囲**（差 ±3ms）。**base 比 +9〜46ms で線形**。

参考: **rev1（無ガード `${k%/}`）は同条件で 100,000 文字 2,728ms / 200,000 文字 10,109ms** でした。

#### (c) `8b604fe`（却下案）との比較 — **引用であり本書では未再現**

`8b604fe` の commit message の数値（3,009 文字で 13,135ms / 20,000 文字で 10 分未完）を引用。**測定対象は `8b604fe:tests/fixtures/pg-fold-path.sh` の `_pg_fold_tolower`**。再現するには `git show 8b604fe:tests/fixtures/pg-fold-path.sh` を取り出して単体評価すること。

### 5.6 sed 実装差（不正 UTF-8 / `[[:space:]]` トリム）

| 実装 | `LC_ALL=C` | `LC_ALL=en_US.UTF-8` |
|---|---|---|
| **BSD sed**（macOS） | rc=0 / バイト透過 | **rc=1 `RE error: illegal byte sequence` / 出力なし** |
| **GNU sed**（`gsed` / Linux CI 相当） | rc=0 / バイト透過 | **rc=0 / バイト透過** |

**`LC_ALL=C` を固定すれば両実装が一致します。** これにより「不正 UTF-8 で HO 判定が OS ごとに変わる」問題が消え、§2.5 の guard は `wsonly` という決定論的入力で検証できるようになります。

---

## 6. 適用手順（Human-owned）

1. §3 の差分を `scripts/hooks/check-plan-hash.sh` へ適用する（アンカーは現 main で 1 箇所のみ）。
2. `tests/extras/ta-65-eh3-ho-task-context.sh` の **TC-07 を fixed 期待へ反転**する。TC-06（非 HO 10 件）は**変更不要**（実測で PASS 維持）。
3. **`ta-65` に §5.3 の TC 入力 15 件を追加する**（**追加するのは TC 入力だけ。変異体は検出力を実証するためのメタ手段であり repo にコミットしない**）。実装上の必須事項:
   - **`_T65_TMP` 配下に大文字セグメントを含む root を作り、そこへ hook を複製して実行する**（`abs` / `absup` が M8 を kill するために必要。全小文字 root では検出力ゼロ）。
   - **`nonutf` は `LC_ALL=en_US.ISO8859-1` で実行**する。**当該ロケールが存在しない環境ではスキップし、スキップしたことを出力に残す**（`locale -a` で確認可能。Linux では `en_US.ISO-8859-1` 等、名称が異なる場合がある）。
   - 他 14 件は `LC_ALL=C` を明示して実行する。
   - **`badutf`（不正 UTF-8）は TC にしない**。`LC_ALL=C` 固定後は OS を問わず「非 HO」が正しい期待値であり、rev2 が観測した HO は `sed` 失敗の副作用だった（§2.5 / §5.6）。
4. §4.2 の再測定手順を実行し、`..` を含む監査記録が「0 件 または 本 issue 由来のみ」であることを確認する（**件数を契約値にしない**）。
5. `sh tests/run-tests.sh` を **macOS と `ubuntu-latest` の両方**で rc=0 になることを確認する（§5.4 のとおり本書の測定は 1 OS のみ）。baseline は適用時点の main で再測定する。
6. **`scripts/apply-eh3-ho-always.sh` の 9 カテゴリ第 2 コピー（`:135-143` / `:174-183`）を同期するか retire するか決める。** 同スクリプトは #1089 の一回性 applier で既に適用済み・`tests/fixtures/eh3-known-gap-1089.flag` も存在しないため、**retire（削除、または「適用済み・参照専用」と明記）が最小コスト**。
7. **`.claude/rules/mode-classification.md` の Hardening Override 節に 1 行足す**: 実装側の `case` が**小文字キーで照合する**ことを明記する。現在の正本は `AGENTS.md` / `CLAUDE.md` と大文字で書かれており、本 patch 適用後は**実装の文字列と grep 一致しなくなる**ため、正本↔実装の drift を文字列一致で検出する手段が失われる。追記例:

   > 実装（`scripts/hooks/check-plan-hash.sh` の `_override=0` 直後の `case`）は、
   > 表記揺れ迂回を防ぐため**小文字化したキー `_ho_key`** で照合する（#1101）。
   > 本表のパス名は正本表記であり、実装側パターンは小文字で書かれる。

8. `docs/ai/hook-enforcement.md` の「既知の残存」から本項目を削除する。ただし **#1104（`Bash` 経路には HO 判定が存在しない）は未解決**なので、**「`Edit|Write` 経路では常時 block / `Bash` 経路は #1104 で追跡中」と matcher 別に書く**こと。

---

## 7. 残存リスク（本 patch で閉じないもの）

| # | 残存 | 理由 / 追跡 |
|---|---|---|
| **R-1** | **`Bash` 経路には HO 判定自体が存在しない** | HO を持つ hook は `check-plan-hash.sh` 1 本のみで `Edit\|Write` matcher にしか配線されていない。**#1104** |
| **R-2** | symlink 経由の到達 | 本 patch は字句のみで判定し FS に触れない（意図的） |
| **R-3** | バックスラッシュ（`a\b/CLAUDE.md`） | macOS / Linux では別ファイルであり FS 到達不能。Windows / WSL 前提なら `arbiter.py` 同様に拒否すべき。**スコープ外** |
| **R-4** | Unicode の大小文字（トルコ語 `İ` / 全角） | `tr 'A-Z' 'a-z'` は ASCII のみ。既存 `_tf_lc` と同じ制約であり本 patch で悪化しない |
| **R-5** | `#1135` patch との適用順 | 本 patch を先に入れれば `#1135` 側の「差分 0」は冗長になる。**どちらを先に入れるかは Human 判断**。本 patch を先に入れる場合、`#1135` patch は差分 0 を落として再測定すること |
| **R-6** | **worktree 越し / REPO_ROOT 外の target で HO が発火しない**（**本 patch で閉じない・現 main も同様**） | HO 9 カテゴリは **repo root 起点の完全一致**なので `.claude/worktrees/<id>/CLAUDE.md` や別 clone の絶対パスは HO にならない（実測: base / rev3 とも同一）。**本リポジトリは agent worktree を常用**しており監査ログの target の多くがこの形。**別 issue 化を推奨** |
| **R-7** | **`_ho_key` 以外の経路のロケール依存は残る** | 本 patch が固定したのは HO 判定の 3 コマンドのみ。**`_tf_lc`（plan.md 判定）と `_dl_ext`（doc-light 判定）は依然として外側ロケールに依存**する。実測: 不正 UTF-8 target を `en_US.UTF-8` で渡すと `_dl_ext` の `sed` が失敗し `set -e` で rc=1 になる（base も同じ）。**本 patch で悪化しないが解消もしない** |
| **R-8** | **Linux / GNU coreutils での全 TC 実行が未実施** | 本書の測定は macOS 1 OS。§5.6 で sed 挙動のみ OS 差を確認した。**CI（`ubuntu-latest`）での初回実行が実質的な OS 検証**になる（§6 step 5） |

---

## 8. 検証の再現手順とサンドボックス境界

すべて `origin/main` = `01c8946` のサンドボックス複製で実施。**リポジトリ本体の `scripts/hooks/check-plan-hash.sh` は編集も実行もしていません。**

> **本書の執筆自体（`Write` ツール）は本体 hook を PreToolUse として発火させ、`docs/working/_audit/skip-decision-log.jsonl` に `EH-3_DOC_LIGHT_SKIP` を追記します。** これは測定ではなく執筆の副作用ですが §4.2 の絶対件数を劣化させるため、同節は件数ではなく条件式で判定します。

```sh
# 1) サンドボックスを作る（root に大文字セグメントを含めること）
mkdir -p sb/UPPER/base/scripts/hooks sb/UPPER/base/docs/working/_audit
mkdir -p sb/UPPER/pat/scripts/hooks  sb/UPPER/pat/docs/working/_audit
cp scripts/hooks/check-plan-hash.sh sb/UPPER/base/scripts/hooks/
cp scripts/hooks/check-plan-hash.sh sb/UPPER/pat/scripts/hooks/
# 2) sb/UPPER/pat 側へ §3 の差分を適用する
# 3) env を unset し、ロケールを明示し、rc ではなく出力文字列で判定する
env -u PLANGATE_HOOK_TASK -u PLANGATE_SKIP_REASON -u PLANGATE_HOOK_FILE \
    -u PLANGATE_HOOK_STRICT -u PLANGATE_BYPASS_HOOK LC_ALL=C LANG=C \
    sh sb/UPPER/pat/scripts/hooks/check-plan-hash.sh "" "<target>" </dev/null
```

`REPO_ROOT` は `$(dirname "$0")/../..` で解決されるため、サンドボックス側の hook はサンドボックスを root と見なします。

## 9. 関連

- **#1101**（本 issue）/ **#1089**（PR #1097 で是正済の隣接欠陥）/ **#1104**（`Bash` 経路に HO 判定が無い）/ **#1135**（AI-owned レーン。traversal ガードを共有）/ **#1144**（hook 配布。本 patch を前提とする）
- [`1135-ai-owned-lane-patch.md`](./1135-ai-owned-lane-patch.md) §差分 0
- `tests/extras/ta-65-eh3-ho-task-context.sh` TC-06 / TC-07
- `scripts/ai-loop/arbiter.py::_normalize_path`（fail-closed の前例）
- `scripts/apply-eh3-ho-always.sh:135-143` / `:174-183`（9 カテゴリの第 2 コピー。§6 step 6）
- `.claude/rules/mode-classification.md`（HO 9 カテゴリの正本。§6 step 7 で 1 行追記を提案）
- `8b604fe:tests/fixtures/pg-fold-path.sh`（却下した O(n²) 実装。数値は commit message からの引用で未再現）
