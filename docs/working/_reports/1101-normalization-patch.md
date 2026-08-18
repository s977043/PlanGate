# #1101 patch 設計 — Hardening Override のパス正規化（**Human 適用**）

> 対象: `scripts/hooks/check-plan-hash.sh`（**Hardening Override 対象パス**）
> 測定基点: `origin/main` = `01c8946` / 2026-08-18 / macOS 25.6.0（APFS case-insensitive）/ `/bin/sh` = bash 3.2 / BSD sed・BSD tr
> 責務: **設計・差分・検証設計は AI-owned（本書）/ 適用は Human-owned**
> 位置づけ: **#1144 で hook を配布する前に閉じるべき筆頭**。#1135 patch の「差分 0」と同形の traversal ガードを含む
> 版: **rev5**

## 版の履歴（撤回した主張を明示する）

| 版 | 何を変えたか | 撤回した主張 |
|---|---|---|
| rev1 | 初版 | — |
| rev2 | 末尾 `/` 除去に `case` ガード / 空キー fail-closed / 順序事故の回帰 TC | **「入力長に線形なので上限ガード不要」**（無ガードの `${var%/}` が bash 3.2 で O(n²)） |
| rev3 | **`LC_ALL=C` を内側固定** / TC を OS・環境非依存へ | **「5 シェルで同一挙動＝可搬」**（シェル可搬性であって OS 可搬性ではない）/ **「15 変異すべて kill」**（測定環境の REPO_ROOT に大文字があることに依存）/ **`badutf` TC の有効性**（macOS 専用） |
| rev4 | コマンド置換代入に `\|\|` フォールバックを付与 / M1 変異の定義修正 / `.` `*/.` クラスの明記 | **「`sed`/`tr` が実行不能 → 空キー → rc=2」**（パイプライン最終段が失敗する場合は偽） |
| **rev5** | **`_ho_root` のフォールバックを fail-closed へ**（生 `REPO_ROOT` は誤り）/ **`_tf_lc` に `\|\|` + 空 guard + `LC_ALL=C`**（rev4 が露出させた plan.md guard の穴）/ `notr2abs` `notr3` TC 追加 | **「`\|\| _ho_root="$REPO_ROOT"` は block を減らさない側」**（**部分故障で絶対パスの HO 9 カテゴリ全部が rc=0 で素通り**）/ **§7 R-7 の「本 patch で悪化しないが解消もしない」**（**rev4 は `notr2` 故障パターンで main より弱い**）/ §5.3 の M1 注記（`set -e` 即死であって空キー guard 発火ではない） |

## 結論先行

**承認境界のパス集合（HO 9 カテゴリ）は変更しません。** 変えるのは **「HO 判定が何をキーに glob 照合するか」** と、**その正規化が失敗したときに block 側へ倒すこと**です。

- **block する側（HO 判定）**にだけ HO 専用キー `_ho_key` を導出する
- **通す側（doc-light / maintenance / c3 判定）が使う `_norm_target` は一切変更しない**
- `..` は **解決せず fail-closed で弾く**（`realpath` / `readlink -f` に依存しない）
- **パラメータ展開による除去は必ず `case` で前置ガードする**（無ガードの `${var%/}` は bash 3.2 で O(n²)。§2.4）
- **`sed` / `tr` は `LC_ALL=C` を内側固定する**（§2.6）
- **コマンド置換のみの代入には `|| <既定値>` を付ける。既定値は必ず block 側へ倒す値にする**（§2.7）
- **正規化に失敗したら block する**（キー・root・plan.md 判定の 3 箇所すべて。§2.5 / §2.7 / §2.8）

### 現状の穴の規模

| 文脈 | 現 main の穴 |
|---|---|
| **no-task** セッション | HO 9 カテゴリのうち **`.md` を含む 4 カテゴリ**が `DOC_LIGHT_SKIP`（rc=0）で**素通り** |
| **TASK 文脈あり** | **9 カテゴリ × 9 変換クラス = 81 中 52 組合せが rc=0 で完全通過**（実測・§5.1） |

---

## 1. 現状の実測（`origin/main` = `01c8946`）

### 1.1 検証方法（**rc で判定しない / env を unset する / ロケールを固定する**）

```sh
env -u PLANGATE_HOOK_TASK -u PLANGATE_SKIP_REASON -u PLANGATE_HOOK_FILE \
    -u PLANGATE_HOOK_STRICT -u PLANGATE_BYPASS_HOOK LC_ALL=C LANG=C \
    sh "<hook>" "" "<target>" </dev/null
```

- **`rc` ではなく出力の `HARDENING_OVERRIDE` 文字列で判定**する。非 `.md` は doc-light に落ちず `SKIP 拒否` で rc=2 を返すため、**HO を壊しても rc は 2 のまま**。
- `target_file=${PLANGATE_HOOK_FILE:-${2:-}}` により **env が位置引数に優先**するため `PLANGATE_HOOK_FILE` は**必ず unset**。
- **`LC_ALL` / `LANG` も測定条件**（§2.6）。
- **絶対パスを測るときは「そのサンドボックス自身の REPO_ROOT」を使うこと。** 別サンドボックスの root を渡すと root 除去が効かず、**patch の欠陥ではなく測定の誤りで noHO になります**（本作業中に一度踏み、`rm -f` されるカウンタファイルの不在で検出しました）。
- 検証はすべて **サンドボックス複製**（`base/` = 現 main、`rev4/`、`rev5/`、変異体、PATH shim）。**リポジトリ本体の hook は編集も実行もしていない**（§8）。

### 1.2 渡された前提の再確認結果

| 前提 | 再測定 | 判定 |
|---|---|---|
| `rc=2 CLAUDE.md → HARDENING_OVERRIDE` | 一致 | OK |
| `rc=0 docs/working/templates/../../../CLAUDE.md → DOC_LIGHT_SKIP` | 一致 | OK |
| `rc=0 Claude.md` / `rc=0 .claude/Rules/x.md` | 一致 | OK |
| `rc=2 bin/../bin/plangate` は「HO は発火せず別理由」 | **no-task では一致。TASK 文脈では rc=0 で完全通過** | 補強 |
| `Claude.md` で `CLAUDE.md` が読める | `head -1 Claude.md` → `# CLAUDE.md`。一致 | OK |

### 1.3 追加で検出した変換クラス（issue 本文に未記載）

| クラス | 例 | 現 main（TASK 文脈） | FS 到達可能性 |
|---|---|---|---|
| **`/./` 中間** | `bin/./plangate` | rc=0 通過 | **到達可能** |
| **`.//` 先頭** | `.//CLAUDE.md` | rc=0 通過 | **到達可能** |
| **`../<repo 名>/` 往復** | `../plangate/CLAUDE.md` | rc=0 通過 | **到達可能** |
| **末尾 `/.` / `.` 単体** | `bin/plangate/.` / `.` | rc=0 通過 | **到達可能**（ディレクトリの場合） |
| **末尾 `/`** | `CLAUDE.md/` | rc=0 通過 | 到達不可（`ENOTDIR`）。block 側の hardening |
| **前後空白** | `"\tCLAUDE.md"` / `"CLAUDE.md "` | rc=0 通過 | 到達不可。同上 |
| **repo root 前置部の大小文字** | `/USERS/.../CLAUDE.md` | 現 main は `_norm_target` を小文字化しない | 到達可能 |

### 1.4 パターン形状依存

`schemas//x.schema.json` と `schemas/./x.schema.json` は **現 main でも既に rc=2 HO**。`case` glob の `*` が `/` を跨ぐため `schemas/*.schema.json` が偶然拾います。**防御が偶然に依存している**状態を正規化で決定論化します。

---

## 2. 設計

### 2.0 設計判断の代償を先に書く

**現 main はこの位置でパラメータ展開と `case` しか使っておらず、fork ゼロ・ロケール非依存・失敗経路なしです。** 本 patch は小文字化と空白除去のために **`sed` / `tr` という外部バイナリを持ち込みます**。代償は 4 つあり、**4 つとも実測で穴として顕在化しました**:

| 代償 | 顕在化 | 対処 |
|---|---|---|
| **ロケール依存** | 非 UTF-8 ロケールで `CLAUDE.md` が HO 判定から外れる（rev2） | `LC_ALL=C` 内側固定（§2.6） |
| **失敗の伝播（`set -e`）** | `tr` が実行不能だと代入文で即死し guard に到達しない（rev1〜rev3） | `\|\|` フォールバック（§2.7） |
| **フォールバック値の選択ミス** | **`_ho_root` の既定を生 `REPO_ROOT` にすると、部分故障で絶対パスの HO が全部素通り**（rev4） | **fail-closed へ**（§2.7） |
| **呼び出しインデックスの移動** | **HO 判定が `tr` を 2 回消費したことで、既存の無ガード `_tf_lc` が 3 回目に押し出され plan.md guard が消える**（rev4） | `_tf_lc` にも同じ 3 点セット（§2.8） |

外部コマンドを使わない代替（1 文字シェルループ）は **O(n²) で不採用**（§2.4）。**「防御を足すと別の穴が開く」ことが 4 巡にわたり実際に起きたので、追加した各行がどの失敗モードを持つかを §2.5〜§2.8 に個別に書きます。**

### 2.1 `..` / `//` の扱い — **解決せず fail-closed（採用）**

1. **可搬性**: `realpath` は macOS 標準に無く、`readlink -f` は BSD/GNU で挙動が違う。
2. **FS へ触れない**: HO 判定は**字句のみ**で決まるべき。
3. **前例が repo 内にある**: `scripts/ai-loop/arbiter.py::_normalize_path`（`arbiter.py:344-355`）は既に `..` / `//` / 絶対パス / バックスラッシュを拒否。
4. **#1135 patch の「差分 0」と同形**。
5. **`..` を畳む実装は事故った**: `8b604fe:tests/fixtures/pg-fold-path.sh` に O(n²) が紛れ込んだ。

**却下**: `realpath` / `readlink -f`（可搬性）/ `python3` の `posixpath.normpath`（HO 判定を Python 依存にできない）/ セグメント走査。

### 2.2 大小文字 — **非対称に入れる**

```
HO 判定（block する側）  : 小文字化する      → 過剰検出しても block が増えるだけ = 安全側
doc-light 判定（通す側） : 小文字化しない    → 通す範囲が広がると穴になる = 危険
```

`_norm_target` は **doc-light（`_dl_ext`）/ maintenance（`allowed_paths` の `fnmatchcase`）/ c3.json conversation 判定**の 3 経路で共有されているため書き換えず、**HO 専用キー `_ho_key` を新設**します。HO の `case` パターンは小文字側に書き換えます。

### 2.3 適用順（**順序に依存する事故を実測で 2 件検出**）

```
(1) 前後空白の除去 + 小文字化（LC_ALL=C 固定 / || フォールバック付き）
(2) 空キー fail-closed                   ← §2.5
(3) traversal fail-closed 判定           ← ★ (4) より前
(4) 先頭 `./` 除去 / 末尾 `/` 除去       ← ★ どちらも case で前置ガード（§2.4）
(5) root の小文字化（|| fail-closed）→ repo root 除去   ← ★ (1) より後・§2.7
```

- **★ (3) を (4) より後ろに置くと `.//CLAUDE.md` が素通り**（**回帰 = MX1 / 入力 `dotdbl`**）。
- **★ (5) を (1) より前に置くと `<REPO_ROOT を大文字化>/CLAUDE.md` が素通り**（**回帰 = MX2b / 入力 `absup`**）。
- traversal の `..` アームは **`..|../*` と `*/..|*/../*` の両方が必要**（**回帰 = MX3 / 入力 `parent`**）。

### 2.4 性能 — rev1 の「線形だから上限不要」を撤回する

`/bin/sh`（bash 3.2）で **パターンに一致しないときの `${var%pat}` は入力長に対して二次**です（5 回ループ）:

| len | `${k%/}`（無ガード = rev1） | `case "$k" in */) ... esac` |
|---:|---:|---:|
| 25,000 | **822 ms** | 62 ms |
| 50,000 | **3,083 ms** | 65 ms |
| 100,000 | **12,093 ms** | 74 ms |
| 200,000 | **48,207 ms** | 92 ms |

**倍化ごとに約 4 倍 = O(n²)。** rev1 は 3,009 と 20,010 の **2 点しか測っておらず fork が支配的**な帯域でした。**「2 点が直線に乗る」ことは線形性の証拠になりません。**

**是正**: `case "$_ho_key" in */) _ho_key="${_ho_key%/}" ;; esac`。patch 内のパラメータ展開 3 箇所すべてが `case` ガード下です。

### 2.5 空キー fail-closed（`_ho_key`）

パイプラインの終了ステータスは最後の `tr` のものなので、**中間段の `sed` が落ちても `set -eu` は発火せず `_ho_key` が空**になります。空キーは HO の `case` のどのアームにも一致せず **HO 判定が丸ごとスキップ**されます。**Claude Code の PreToolUse は exit 2 のみ block** なので rc=0 も rc=1 も「通す」側です。

| 失敗の位置 | `set -e` の挙動 | guard に到達するか | rev5 の結果 |
|---|---|---|---|
| **`sed`（中間段）が失敗** | パイプライン status は `tr` のもの＝0 なので**発火しない** | **到達する** | **rc=2 `HARDENING_OVERRIDE`** |
| **`tr`（最終段）が失敗** | **代入文の status が非 0 → `set -e` が即死** | **到達しない** | `\|\| _ho_key=''` が**必須**（§2.7） |
| **空白のみの target**（`"   "`） | 正常終了・出力が空 | 到達する | **rc=2**（**回帰 TC `wsonly`**） |
| **不正 UTF-8 を含む target** | `LC_ALL=C` により失敗しない | 到達しない（キーは非空） | 通常経路。**正しい**（別名ファイルであり HO 対象ではない） |

### 2.6 ロケール依存 — **`LC_ALL=C` を内側固定する**

**BSD `tr 'A-Z' 'a-z'` はロケールの照合順で範囲を解釈するため、非 UTF-8 ロケールで ASCII を破壊します。**

| `LC_ALL` | `CLAUDE.md` → | `BIN/PLANGATE` → |
|---|---|---|
| `C` / `en_US.UTF-8` | `claude.md` | `bin/plangate` |
| **`en_US.ISO8859-1` / `ISO8859-15`** | **`BKaT..l.`（破壊）** | **`.HM/.KaMFa..`（破壊）** |
| **`en_US.US-ASCII`** | **`claude.LC`（部分破壊）** | `bin/plangate` |

**end-to-end**: `LC_ALL` 未固定（rev2）では TASK 文脈で `CLAUDE.md` / `bin/plangate` / `.claude/settings.json` / `schemas/x.schema.json` がいずれも **PASS rc=0**。base は **HO rc=2** なので**現 main より弱い退行**でした。空キー guard は**キーが非空なので発火しません**。

**是正**: 各コマンドに `LC_ALL=C` を**内側で**付ける。**回帰 = M13 / 入力 `nonutf`**。副次効果として BSD sed と GNU sed の不正バイト時の挙動も一致します（§5.6）。**日本語パス等への影響はゼロ**（`LC_ALL=C` の `tr 'A-Z' 'a-z'` は 0x41-0x5A のバイト置換で 0x80 以上を変更しない）。

### 2.7 `set -e` 下のコマンド置換代入 — **`||` は必須、かつ既定値は block 側へ倒す**

```sh
_ho_key=$(... | LC_ALL=C tr 'A-Z' 'a-z')
```

は **「コマンド置換のみを持つ代入」なので、置換の終了ステータスがそのまま代入文の終了ステータス**になり、**最終段の `tr` が失敗すると `set -eu` が guard に到達する前にシェルを落とします**。

#### (a) `_ho_key` — 既定は空文字（§2.5 の guard へ流す）

PATH 先頭に `exit 127` する `tr` を置いた実測（target = `CLAUDE.md` / `LC_ALL=C`）:

| shim | shell | **base（現 main）** | **rev3** | **rev4 / rev5** |
|---|---|---|---|---|
| **`tr` 常時失敗** | sh / bash / zsh / dash / ksh | HO / rc=2 | **なし / rc=127** | **HO / rc=2** |
| `sed` 常時失敗 | 5 シェルすべて | HO / rc=2 | HO / rc=2 | HO / rc=2 |

**rc=127 は両ハーネスで「通す」側**です。Claude Code の PreToolUse は exit 2 のみ block、**`.codex/hooks/eh-bridge.sh:87-88` は未知 rc を明示的に `allow` へ変換**します:

```sh
# Unknown exit code: allow but flag in reason for debugging
printf '{"hookSpecificOutput":{... "permissionDecision":"allow", ...}}\n' "$HOOK_NAME" "$rc"
```

#### (b) `_ho_root` — **既定を生 `REPO_ROOT` にした rev4 は誤り（rev5 で撤回）**

rev4 は `|| _ho_root="$REPO_ROOT"` とし「root 除去が効かなくなるだけで block を減らさない」と書きましたが、**誤りです**。`_ho_key` は**小文字化済み**なので、**生の `REPO_ROOT`（大文字を含む）とは prefix が一致せず root 除去が失敗し、キーが絶対パスのまま HO の `case` に当たらなくなります**。

**実測**（`ROOT` に大文字セグメントを含むサンドボックス / 各版が**自分の** root を使う / 2 回目以降の `tr` 呼び出しだけ失敗する shim `notr2` / TASK 文脈）:

| target | shell | **base** | **rev4** | **rev5** |
|---|---|---|---|---|
| `<ROOT>/CLAUDE.md` | sh / bash / zsh / dash / ksh | **HO / rc=2** | **noHO / rc=0** | **HO / rc=2** |
| `<ROOT>/bin/plangate` | sh | **HO / rc=2** | **noHO / rc=0** | **HO / rc=2** |
| `<ROOT>/.claude/settings.json` | sh | **HO / rc=2** | **noHO / rc=0** | **HO / rc=2** |
| `<ROOT>/CLAUDE.md`（no-task） | sh | **HO / rc=2** | **noHO / rc=127** | **HO / rc=2** |
| `CLAUDE.md`（相対・対照） | sh | HO / rc=2 | HO / rc=2 | HO / rc=2 |
| `<ROOT>/CLAUDE.md`（shim 無し・対照） | sh | HO / rc=2 | HO / rc=2 | HO / rc=2 |

**部分故障で絶対パスの HO 9 カテゴリが全部 rc=0 で素通りします。** §4 B-9 の「rev4 は base と同じ」は**部分故障では偽**でした。

**是正（採用）— fail-closed**:

```sh
_ho_root=$(printf '%s' "$REPO_ROOT" | LC_ALL=C tr 'A-Z' 'a-z') || _ho_root=''
if [ -z "$_ho_root" ]; then
  reason="HARDENING_OVERRIDE: ${target_file:-} root 正規化に失敗 (fail-closed: empty root key)"
  ... exit 2
fi
```

**回帰 = 変異 M16（fail-closed を rev4 の生 `REPO_ROOT` へ戻す）/ 入力 `notr2abs`**。

##### 代案「1 本のパイプラインで target と REPO_ROOT を同時に正規化」を却下した理由

fork を 2→1 に減らし `_ho_root` 専用の失敗モードを消せますが、**改行を含む target_file で root スロットに任意文字列を注入できます**。実測:

```
target = "CLAUDE.md\n/evil/root"
  key         = claude.md
  derived root = /evil/root␊/private/tmp/.../rev5      ← 攻撃者が root 側を制御
```

**HO 判定の入力に攻撃者制御の分離子を持ち込む設計は、fork 1 個の節約と釣り合いません。** パス中の改行は POSIX で合法であり、`target_file` は stdin JSON 由来でもあります。よって **2 本の独立した正規化 + それぞれ fail-closed** を採ります。

### 2.8 `_tf_lc`（plan.md guard）— rev4 が露出させた穴（rev5 で同時是正）

**rev4 の HO 判定は `tr` を 2 回消費します。** その結果、no-task 経路の既存行

```sh
_tf_lc=$(printf '%s' "$target_file" | sed 's/[[:space:]]*$//' | tr 'A-Z' 'a-z')   # || を持たない
```

が **3 回目の `tr` 呼び出し**に押し出され、「3 回目以降失敗」パターンで `set -e` 即死します。

**実測**（no-task / target = `docs/working/TASK-X/plan.md`）:

| shim | **base** | **rev4** | **rev5** | **rev5 から `_tf_lc` guard を外した変異 M17** |
|---|---|---|---|---|
| `notr3`（3 回目以降失敗） | **BLOCK plan.md / rc=2** | **なし / rc=127** | **BLOCK（fail-closed）/ rc=2** | **なし / rc=127** |
| `notr2`（2 回目以降失敗） | BLOCK plan.md / rc=2 | **なし / rc=127** | HO / rc=2（§2.7(b) の root guard が先に発火） | — |
| `notr`（常時失敗） | **なし / rc=127**（base 自身の穴） | HO / rc=2 | HO / rc=2 | — |

**`plan.md` bypass guard（EH-3 の中核 block）が rev4 では無効化されます。**

#### 同一 patch で是正する判断（別 issue にしない）

| 論点 | 判断 |
|---|---|
| 穴の起源 | **`_tf_lc` に `\|\|` が無いこと自体は rev1 以前から**（`notr` 常時失敗では base も rc=127） |
| ただし | **rev4 は `tr` の呼び出しインデックスを 1→3 へずらし、`notr2` / `notr3` という「より起きやすい部分故障」で発火するようにした**＝**rev4 が作った退行** |
| 分離した場合 | **既知の退行を抱えたまま出荷**することになる。#1144 で配布する前に閉じる、という本 PBI の位置づけと矛盾する |
| 是正コスト | **同一ファイル・同一失敗クラス・3 行** |

→ **同一 patch で是正**します。あわせて **`LC_ALL=C` も付けます**。付けない場合、`_tf_lc` は §2.6 と同一のロケール穴を持ったままです（実測: `PLAN.md` を `LC_ALL=en_US.ISO8859-1` で渡すと **base / rev4 は `DOC_LIGHT_SKIP` rc=0 で plan.md guard を素通り**、rev5 は `BLOCK plan.md` rc=2）。**これは pre-existing な穴の是正であり、本 patch の scope 拡大にあたるが、同じ 1 行の中で閉じられるため分離しません。**

**回帰 = 変異 M17 / 入力 `notr3`**、および `PLAN.md` × `nonutf` ロケール。

---

## 3. 差分（`scripts/hooks/check-plan-hash.sh`）

> **AI は本差分を適用しません**（HO 対象パス）。適用は Human-owned。
> **hunk は 2 箇所**: (A) Hardening Override ブロック、(B) no-task 分岐の `_tf_lc`。

### (A) Hardening Override ブロック

> アンカー: `# (ii) Hardening Override 物理先頭判定（R-003/R-015、maintenance より上）` から
> 直後の `if [ "$_override" = "1" ]; then … fi` まで（現 main で **1 箇所のみ**）。

```diff
@@
   "$REPO_ROOT"/*) _norm_target="${_norm_target#$REPO_ROOT/}" ;;
 esac
 
+# (i-b) HO 判定専用キー _ho_key の導出（#1101 / TASK-1101）
+#   前後空白の除去 + 小文字化を外部コマンド 1 パイプラインで行う。1 文字ずつ回す
+#   シェルループは O(n^2) になり、EH-3 に timeout が無いため暴走が block ではなく
+#   ハングになる（8b604fe の実測）。
+#   LC_ALL=C を内側固定する: BSD tr はロケールの照合順で範囲を解釈するため、
+#   en_US.ISO8859-1 等では 'A-Z' が ASCII 大文字と一致せず CLAUDE.md すら
+#   小文字化に失敗して HO 判定から外れる（#1101 N1 / 実測）。
+#   || _ho_key='' は必須: コマンド置換のみの代入は置換の終了ステータスが代入文の
+#   ステータスになるため、最終段 tr が失敗すると set -eu が下の guard に到達する
+#   前にシェルを落とす（rc=127 は PreToolUse では block にならず、
+#   .codex/hooks/eh-bridge.sh は未知 rc を allow へ変換する）（#1101 NEW-1 / 実測）。
+#   _norm_target は書き換えない: doc-light / maintenance / c3 判定（= 通す側）は
+#   大小文字に感応したまま残し、小文字化は block 側にだけ入れる（非対称設計）。
+_ho_key=$(printf '%s' "${target_file:-}" | LC_ALL=C sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | LC_ALL=C tr 'A-Z' 'a-z') || _ho_key=''
+
+# (i-b2) 正規化の失敗を fail-open にしない（#1101 / F3）
+#   中間段 sed の失敗はパイプラインのステータスに現れないため _ho_key が空になる。
+#   空キーは HO の case のどのアームにも一致せず HO 判定が丸ごとスキップされる。
+if [ -z "$_ho_key" ] && [ -n "${target_file:-}" ]; then
+  reason="HARDENING_OVERRIDE: ${target_file:-} の正規化に失敗 (fail-closed: empty normalization key)"
+  log_event "HARDENING_OVERRIDE" "$reason"
+  printf '[Hook EH-3] %s\n' "$reason" >&2
+  exit 2
+fi
+
+# (i-c) traversal fail-closed（#1101 / #1135 の _trav と同形）
+#   `..` / `//` / `/./` / 末尾 `/.` / `.` 単体 を含むパスは字句解決せず一律 block。
+#   realpath / readlink -f は GNU/BSD 差があり POSIX sh で可搬性に難がある。
+#   **先頭 `./` 除去より前**に判定する：先に `./` を取ると `.//CLAUDE.md` が
+#   `/CLAUDE.md`（絶対パス形）になり `//` 検知をすり抜ける（実測で検出）。
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
+#   **除去は必ず case で前置ガードする**: bash 3.2 / ksh の ${var%pat} は一致
+#   しないときの走査が入力長に対して二次で、100000 文字 x5 で 12 秒かかる
+#   （#1101 F1 / 実測）。case は同条件で 74ms と平坦。
+case "$_ho_key" in
+  ./*) _ho_key="${_ho_key#./}" ;;
+esac
+case "$_ho_key" in
+  */) _ho_key="${_ho_key%/}" ;;
+esac
+#   root 側も同じ写像を通してから比較する（root 除去を大小文字非依存にする）。
+#   **フォールバックは fail-closed**: 生の REPO_ROOT を既定にすると、_ho_key は
+#   小文字化済みで prefix が一致せず root 除去が失敗し、絶対パスの HO 9 カテゴリが
+#   まるごと素通りする（#1101 NEW-4 / 実測: 部分故障で rc=0）。
+_ho_root=$(printf '%s' "$REPO_ROOT" | LC_ALL=C tr 'A-Z' 'a-z') || _ho_root=''
+if [ -z "$_ho_root" ]; then
+  reason="HARDENING_OVERRIDE: ${target_file:-} root 正規化に失敗 (fail-closed: empty root key)"
+  log_event "HARDENING_OVERRIDE" "$reason"
+  printf '[Hook EH-3] %s\n' "$reason" >&2
+  exit 2
+fi
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
@@
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

### (B) no-task 分岐の `_tf_lc`（plan.md guard / §2.8）

```diff
@@ no-task 分岐
-  _tf_lc=$(printf '%s' "$target_file" | sed 's/[[:space:]]*$//' | tr 'A-Z' 'a-z')
+  # LC_ALL=C: 非 UTF-8 ロケールでは tr が ASCII を壊し PLAN.md が guard を素通りする
+  #   （実測: LC_ALL=en_US.ISO8859-1 で base は DOC_LIGHT_SKIP rc=0）。
+  # || + 空 guard: HO 判定が tr を 2 回消費するため本行は 3 回目の呼び出しになり、
+  #   部分故障（3 回目以降が失敗）で set -e が即死して plan.md guard が消える
+  #   （#1101 NEW-5 / 実測: rc=127 は block にならない）。
+  _tf_lc=$(printf '%s' "$target_file" | LC_ALL=C sed 's/[[:space:]]*$//' | LC_ALL=C tr 'A-Z' 'a-z') || _tf_lc=''
+  if [ -z "$_tf_lc" ] && [ -n "$target_file" ]; then
+    reason="plan.md guard: target 正規化に失敗 (fail-closed): $target_file"
+    log_event "VIOLATION" "$reason"
+    printf '[Hook EH-3] BLOCK: target normalization failed (plan.md guard, fail-closed).\n' >&2
+    printf '  target: %s\n' "$target_file" >&2
+    exit 2
+  fi
   case "$_tf_lc" in
     */plan.md|plan.md)
```

### 3.1 `reason` を生の `target_file` にする理由

正規化後の値を書くと **攻撃の原文（`bin/../bin/plangate`）が記録から消えます**。判定は `_ho_key`、記録は `target_file`。

### 3.2 既存の apply スクリプトとの整合

`scripts/apply-eh3-ho-always.sh` は適用済み判定を `hook_applied = i_override < i_branch` というインデックス比較で行うため本 patch 適用後も "already applied" を返します。**ただし 9 カテゴリ `case` の第 2 コピーを `:135-143` / `:174-183` に埋め込んでおり正本と乖離します**（§6 step 6）。

---

## 4. 既存挙動の変更（**全件**）

| # | 条件 | 変更前 | 変更後 | 備考 |
|---|---|---|---|---|
| **B-1** | **HO 9 カテゴリ × `..` / `//` / `/./` / 大小文字 / 前後空白 / 末尾 `/`** | rc=0 通過（TASK 文脈）/ `DOC_LIGHT_SKIP` or `SKIP 拒否`（no-task） | **rc=2 `HARDENING_OVERRIDE`** | 是正そのもの |
| **B-1b** | **小文字形**（`claude.md` / `.claude/Rules/x.md` 等）も新規に block | rc=0 通過 | **rc=2** | case-sensitive FS では別ファイルへの**意図的な過剰 block**。block 側なので安全側 |
| **B-2** | **非 HO の `.md` で `..` / `//` / `/./` を含むパス** | rc=0 `DOC_LIGHT_SKIP` | **rc=2** | **唯一の「通っていたものが止まる」変更**（通常運用下） |
| **B-3** | 非 HO の**非 `.md`** で `..` 等を含むパス | rc=2 `SKIP 拒否`（no-task）/ rc=0（TASK 文脈） | rc=2 | 実害小 |
| **B-4** | **`.` 単体 / 末尾 `/.`** | TASK 文脈で rc=0 通過 | **rc=2** | traversal アームの `.\|*/.` に該当。B-2/B-3 とは独立クラス |
| **B-6** | **空白のみの target** | `SKIP 拒否` rc=2（no-task）/ rc=0（TASK 文脈） | **rc=2** | §2.5。**回帰 TC `wsonly`** |
| **B-7** | **非 UTF-8 ロケールでの HO 判定** | HO（ロケール非依存） | HO（**`LC_ALL=C` 固定により維持**） | **rev2 では退行していた** |
| **B-9** | **`sed` / `tr` が失敗する環境での HO 判定** | HO（外部コマンドを使わない） | **HO（`\|\|` + 空キー guard + root fail-closed により維持）** | **rev3 は全故障で rc=127 / rev4 は部分故障 + 絶対パスで rc=0**（§2.7）。**rev5 で base と同等** |
| **B-10** | **`sed` / `tr` が失敗する環境での plan.md guard** | `notr`（全故障）では base も rc=127 / `notr2` `notr3` では BLOCK 維持 | **全故障・部分故障とも rc=2 で block** | §2.8。**rev4 は `notr2` / `notr3` で BLOCK 消失**（rev4 が作った退行） |
| **B-11** | **非 UTF-8 ロケールでの plan.md guard** | **`PLAN.md` が `DOC_LIGHT_SKIP` rc=0 で素通り**（pre-existing） | **`BLOCK: plan.md` rc=2** | §2.8。**pre-existing な穴の是正**（scope 拡大だが同じ 1 行で閉じる） |
| **B-12** | **`sed` / `tr` が失敗する環境での非 HO ファイル** | rc=127（= 通す） | **rc=2（block）** | fail-closed の帰結。**インフラ故障時は一律止める**という設計判断（§2.1 と一貫） |
| **B-8** | HO パスを `./` 前置 / 絶対パスで渡したときの `reason` 文字列 | 正規化後の値 | **生値** | ログ表記のみ。文字列 assert するテストは repo 内に無し |

### 4.1 変わらないもの（実測 / 故障注入なし・`LC_ALL=C`）

| 対象 | 変更前 → 変更後 |
|---|---|
| `docs/ai/x.md` / `docs/ai/hook-enforcement.MD` | `DOC_LIGHT_SKIP` rc=0 → 同 |
| `evil/CLAUDE.md` / `docs/.claude/rules/x.md` / `.claudex/rules/x.md` | `DOC_LIGHT_SKIP` → 同 |
| `docs/working/templates/plan.md` | `BLOCK: plan.md` rc=2 → 同 |
| `docs/working/TASK-X/PLAN.md`（C / UTF-8） | `BLOCK: plan.md` → 同 |
| `/tmp/foo.md`（repo 外の絶対パス） | `DOC_LIGHT_SKIP` → 同 |
| `<ROOT>/docs/ai/x.md`（repo 内の絶対非 HO） | `DOC_LIGHT_SKIP` rc=0 → 同 |
| `tests/extras/ta-09.sh` / `scripts/lib/foo.sh` / `notes/claude.mdx` | `SKIP 拒否` → 同 |
| `docs/x.md/`（非 HO + 末尾 `/`） | `SKIP 拒否` → 同 |
| **`ta-65` TC-06 の非 HO 10 件**（両文脈 20 件） | HO 判定に拾われない → 同 |
| `.claude/worktrees/<id>/CLAUDE.md` | `DOC_LIGHT_SKIP` → 同（**§7 R-6 の残存**） |

### 4.2 「正当な用途で `..` を含むパスを渡している経路」の調査 → **観測範囲では無し**

| 調査 | 方法 | 結果 |
|---|---|---|
| EH-3 の全呼び出し元 | `git grep -l 'check-plan-hash'`（非 docs） | target を渡すのは `.claude/settings.example.json` / `.codex/hooks/eh-bridge.sh` / `scripts/hooks/cursor-adapter.sh` の 3 経路。いずれも**受け取った file_path を素通しするだけで `..` を構築しない** |
| repo 内の `..` 文字列リテラル | `git grep '"[^"]*\.\./[^"]*"' -- tests scripts .claude .codex` | markdown リンク / `cd -- "$(dirname $0)/../.."` / `test_arbiter.py`（`..` を**拒否する**テスト）/ `ta-65:344`（**KNOWN-GAP TC-07 そのもの**）のみ |
| doc-light テストの期待値 | `git grep -l DOC_LIGHT -- tests` | `..` を `DOC_LIGHT` 期待で渡す TC は無し |
| repo 内の前例 | `scripts/ai-loop/arbiter.py:344-355` | 既に `..` / `//` / 絶対パス / バックスラッシュを拒否 |

#### 実運用ログの確認は **件数ではなく条件式で残す**

`docs/working/_audit/skip-decision-log.jsonl` は **append-only** なので絶対件数は劣化します。**契約値にしないでください。**

```sh
grep -c '\.\./' docs/working/_audit/skip-decision-log.jsonl
grep '\.\./'    docs/working/_audit/skip-decision-log.jsonl   # 中身を見て個別判断
```

**判定条件**: 該当行が **(a) 0 件、または (b) 全件が本 issue の測定・KNOWN-GAP TC 由来**であれば B-2 の実運用影響は無いと判断してよい。

**測定基点のスナップショット（参考値）**: `01c8946` の追跡版 0 件 / 作業ツリー版 1 件（`2026-08-18T09:59:30Z` の `docs/working/templates/../../../CLAUDE.md` = #1101 コメントの測定由来）。

---

## 5. 検証結果

### 5.1 直積マトリクス — **生成規則（独立再現用）**

**カテゴリ代表 C1〜C9**（repo root 相対）:

```
C1 .claude/rules/x.md        C2 .claude/settings.json     C3 .claude/commands/x.md
C4 .claude/agents/x.md       C5 scripts/hooks/x.sh        C6 bin/plangate
C7 schemas/x.schema.json     C8 .github/workflows/x.yml   C9 CLAUDE.md
```

**変換 T0〜T8**。`p` = 代表 / `ROOT` = **そのサンドボックス自身の** REPO_ROOT。
**規約: `/` を含まない `p`（= C9 の `CLAUDE.md`）は、T2 / T8 を適用する前に `"./" + p` に前置きする。** `q` を前置き後の文字列、`i` を `q` の最初の `/` の位置とする:

| 変換 | 規則 | `CLAUDE.md` の場合 |
|---|---|---|
| T0 plain | `p` | `CLAUDE.md` |
| T1 `..` | `"docs/../" + p` | `docs/../CLAUDE.md` |
| T2 `//` | `q[:i] + "//" + q[i+1:]` | `.//CLAUDE.md` |
| T8 `/./` | `q[:i] + "/./" + q[i+1:]` | `././CLAUDE.md` |
| T3 UPPER | `p.upper()` | `CLAUDE.MD` |
| T4 末尾空白 | `p + " "` | `CLAUDE.md ` |
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

#### 結果（`LC_ALL=C` / 大文字セグメントを含む ROOT / 故障注入なし）

| 文脈 | base の HO | base の PASS/非 HO | **rev5 の HO** |
|---|---:|---:|---:|
| TASK 文脈 | 29 / 81 | **52 / 81**（すべて rc=0 の完全通過） | **81 / 81** |

**base で HO になる 29 件の内訳**: T0（9）+ T6（9）+ T7（9）= 27、+ C7 の T2 / T8（`schemas/*.schema.json` の `*` が `/` を跨ぐため偶然一致）= **29**。`81 − 29 = 52`。

対照 14 件のうち変わるのは **`docs/../docs/ai/hook-enforcement.md`（B-2）の 1 件のみ**。

### 5.2 `ta-65` TC-07（issue の 4 ケース）+ 追加

```
                                base(TASK)   rev5(TASK)
docs/../CLAUDE.md               rc=0 PASS    rc=2 HARDENING_OVERRIDE
CLAUDE.MD                       rc=0 PASS    rc=2 HARDENING_OVERRIDE
"CLAUDE.md "                    rc=0 PASS    rc=2 HARDENING_OVERRIDE
bin/../bin/plangate             rc=0 PASS    rc=2 HARDENING_OVERRIDE
CLAUDE.md/           (追加)      rc=0 PASS    rc=2 HARDENING_OVERRIDE
bin/plangate/.       (追加)      rc=0 PASS    rc=2 HARDENING_OVERRIDE
docs/ai/hook-enforcement.md     rc=0         rc=0            <- 非 HO は不変
docs/working/TASK-9999/plan.md  rc=0         rc=0            <- plan_hash 経路は不変
```

**→ `ta-65` TC-07 は fixed 期待へ反転が必要。**

### 5.3 変異注入

#### 測定環境の前提（**TC 側で作ること**）

- **サンドボックスの REPO_ROOT に大文字セグメントを含めること。** **root に関わる変異（M8 / M16 / MX2b / 将来同種のもの）はすべて uppercase root を前提に初めて検出できます。** 全小文字 root では `abs` / `absup` が HO のままで検出力ゼロ（実測）。**GitHub Actions の checkout パス `/home/runner/work/plangate/plangate` は全小文字**。

  | REPO_ROOT | 変異なし `abs`/`absup` | **M8** `abs`/`absup` |
  |---|---|---|
  | `.../**UPPER**/sb` | HO / HO | **noHO / noHO（kill 成功）** |
  | `.../lower/sb` | HO / HO | **HO / HO（生存）** |

- **絶対パス TC は「そのサンドボックス自身の ROOT」を使うこと。** 別の root を渡すと patch の欠陥ではなく測定の誤りで noHO になります。
- 各 TC のロケールを固定すること（`nonutf` のみ `en_US.ISO8859-1`、他は `LC_ALL=C`）。
- **`notr` / `notr2` / `notr3` は PATH 先頭に失敗する `tr` を置く fault injection**（詳細は §6 step 3）。

#### TC 入力 19 件

```
ws       'CLAUDE.md '                    wsL      ' CLAUDE.md'
case     'CLAUDE.MD'                     casedir  '.CLAUDE/RULES/X.MD'
dotdot   'docs/../CLAUDE.md'             dbl      '.claude//rules/x.md'
dotmid   '.claude/./rules/x.md'          abs      '<ROOT>/CLAUDE.md'            (*)
trail    'CLAUDE.md/'                    plain    'CLAUDE.md'
dotdbl   './/CLAUDE.md'                  absup    '<ROOT を大文字化>/CLAUDE.md'  (*)
parent   '../<ROOT の basename>/CLAUDE.md'
dotend   'bin/plangate/.'                wsonly   '   '
nonutf   'CLAUDE.md'                      @ LC_ALL=en_US.ISO8859-1
notr     'CLAUDE.md'                      @ PATH に常時失敗する tr
notr2abs '<ROOT>/CLAUDE.md'               @ PATH に 2 回目以降失敗する tr   (*) ★NEW-4 用
notr3    'docs/working/TASK-X/plan.md'    @ PATH に 3 回目以降失敗する tr  ★NEW-5 用（期待値は plan.md block）
nonutfplan 'docs/working/TASK-X/PLAN.md'  @ LC_ALL=en_US.ISO8859-1        ★B-11 用（期待値は plan.md block）
                                          (*) ROOT は大文字セグメントを含むこと
```

期待値は **`notr3` / `nonutfplan` を除き `HARDENING_OVERRIDE` を出すこと**、`notr3` / `nonutfplan` は **plan.md guard が block すること**（いずれも rc ではなく出力文字列で判定）。

> **旧 `notr2`（相対パス target）は NEW-4 に対する検出力がゼロ**です（root 除去が no-op のため）。**`notr2abs` に置き換えてください。**

#### 結果（`.` = 期待どおり block / `X` = **変異を kill**）

主要な変異と kill する入力（19 TC 全件の表は rev4 版と同一のため差分のみ記載）:

| 変異 | 壊した箇所 | kill する入力 |
|---|---|---|
| M1 | `sed` 段を丸ごと除去 | `ws` / `wsL` / `wsonly` |
| M1b | 末尾 trim だけ除去 | `ws` |
| M10 | 先頭 trim だけ除去 | `wsL` |
| M2 | 小文字化（`tr`）を除去 | `ws` `wsL` `case` `casedir` `abs` `trail` `plain` `absup` `nonutf` `notr` `notr2abs` |
| M3 | traversal の `..` アーム除去 | `dotdot` / `parent` |
| M4 | traversal の `//` アーム除去 | `dbl` / `dotdbl` |
| M5 | traversal の `/./` アーム除去 | `dotmid` / `dotend` |
| M6 | HO case を `AGENTS.md\|CLAUDE.md` に戻す | `ws` `wsL` `case` `abs` `trail` `plain` `absup` `nonutf` |
| M7 | HO case を `_norm_target` に戻す | 同上 + `casedir` |
| M8 | root 除去を case-sensitive に | `abs` / `absup` |
| M9 | 末尾 `/` 除去を除去 | `trail` |
| M11 | `_ho_key` 空 guard を除去 | `wsonly` / `notr` |
| M13 | `tr` の `LC_ALL=C` を除去 | `nonutf` |
| M14 | `_ho_key` の `\|\|` を除去 | `notr` |
| **M16** | **`_ho_root` を fail-closed から rev4 の生 `REPO_ROOT` へ戻す** | **`notr2abs`（他 18 TC はすべて生存）** |
| **M17** | **`_tf_lc` の `\|\|` + 空 guard を除去** | **`notr3`（他 18 TC はすべて生存）** |
| MX1 | traversal 判定を `./` 除去の後ろへ | `dotdbl` |
| MX2b | root 除去を小文字化より前へ | `absup` |
| MX3 | traversal から `..\|../*` だけ除去 | `parent` |

**M16 / M17 はそれぞれ 1 入力でしか kill できません。`notr2abs` と `notr3` を落とすと、この 2 つの是正は無検出のまま退行できます。**

#### rev4 の M1 注記を訂正（F-3）

rev4 は「構文エラー → 空出力 → **空キー guard が発火** → 全件 HO」と書きましたが、**これは rev4 実装（`|| _ho_key=''` あり）でのみ成立する説明**です。**rev3 の実データ（M1 が全件 `X` = HO を出さない）を再現するのは「構文エラー → `set -e` 即死 → 出力なし → 全件 `X`」のほう**です。**「guard に到達する」と誤記することを是正対象にしておきながら、同型の誤りを注記でしていました。** 訂正します。

#### kill されない変異 M12（**等価または厳格側**）

**M12 = `sed` からだけ `LC_ALL=C` を外す** は全 TC を生き延びます。**HO 判定を弱めないため**です。構造論証:

1. この `sed` の役割は**先頭・末尾 2 アンカーの trim のみ**。
2. 非 C ロケールの `[[:space:]]` は **C ロケールの上位集合**なので trim 量は**増えこそすれ減らない**。
3. HO 対象パスの**先頭バイトは `.` / `b` / `s` / `/`、末尾バイトは `d` / `h` / `n` / `l` / `e` / `/`** であり、**ASCII 英数字・`.`・`/` を space に分類するロケールは存在しない**。

→ trim が余分に働いても HO 対象パスの先頭・末尾は削られず判定は変わらない。実測の差も 1 セル（不正 UTF-8 × UTF-8 ロケール）のみで、方向は **`sed` 失敗 → 空キー → fail-closed → より block する側**。

### 5.4 可搬性 — **シェル可搬性であって OS 可搬性ではない**

`/bin/sh` / `/bin/bash` / `/bin/zsh` / `/bin/dash` / `/bin/ksh` の **5 シェルで同一判定・同一 rc**（`LC_ALL=C`）:

| ケース | 5 シェルすべて |
|---|---|
| 通常系 13 ケース（plain / UPPER / dotdot / dbl / dotmid / ws / trail / dotprefix / dotdbl / dotend / 非 HO / `/tmp` / `evil/`） | HO/2 ×10、DL/0 ×3（一致） |
| **`<ROOT>/CLAUDE.md` × `notr2`（部分故障）** | **base HO/2 / rev4 noHO/0 / rev5 HO/2** |
| **`<ROOT>/CLAUDE.md` × `notr3`** | base HO/2 / rev4 HO/2 / rev5 HO/2 |
| `CLAUDE.md` × `notr`（全故障） | base HO/2 / rev3 なし/127 / rev5 HO/2 |

**ただしこれは 1 OS（macOS / BSD sed・BSD tr）上の 5 シェルであり、OS 可搬性の主張ではありません。** OS 差について実測したのは §5.6 の sed 挙動のみで、**Linux / GNU coreutils 上での全 TC 実行は未実施**です（§6 step 5・§7 R-8）。

### 5.5 性能

#### (a) 構文レベル

§2.4 の表を参照。

#### (b) hook 全体（5 回平均 / `LC_ALL=C` / 同一マシン・同一セッション）

| 入力長 | base | rev4 | **rev5** |
|---:|---:|---:|---:|
| 9 | 24.6 ms | 29.2 ms | **27.9 ms** |
| 3,009 | 49.3 ms | 55.7 ms | **51.4 ms** |
| 20,010 | 73.1 ms | 79.6 ms | **82.1 ms** |
| 100,000 | 103.5 ms | 117.7 ms | **116.6 ms** |
| 200,000 | 131.8 ms | 150.3 ms | **146.1 ms** |

**rev5 は rev4 と同等（差 ±3ms）。base 比 +3〜14ms で線形。** 参考: **rev1（無ガード `${k%/}`）は 100,000 文字 2,728ms / 200,000 文字 10,109ms**。

### 5.6 sed 実装差（不正 UTF-8）

| 実装 | `LC_ALL=C` | `LC_ALL=en_US.UTF-8` |
|---|---|---|
| **BSD sed**（macOS） | rc=0 / バイト透過 | **rc=1 `RE error: illegal byte sequence`** |
| **GNU sed**（`gsed` / Linux CI 相当） | rc=0 / バイト透過 | rc=0 / バイト透過 |

**`LC_ALL=C` を固定すれば両実装が一致します。**

---

## 6. 適用手順（Human-owned）

1. §3 の差分 **(A) と (B) の 2 hunk** を `scripts/hooks/check-plan-hash.sh` へ適用する。
2. `tests/extras/ta-65-eh3-ho-task-context.sh` の **TC-07 を fixed 期待へ反転**する。TC-06（非 HO 10 件）は**変更不要**（実測で PASS 維持）。
3. **`ta-65` に §5.3 の TC 入力 19 件を追加する**（**追加するのは TC 入力だけ。変異体は検出力を実証するメタ手段であり repo にコミットしない**）。実装上の必須事項:
   - **`_T65_TMP` 配下に大文字セグメントを含む root を作り、そこへ hook を複製して実行する**（root に関わる変異はすべてこれを前提に検出される）。
   - **絶対パス TC（`abs` / `absup` / `notr2abs`）は、その複製自身の root を使う**。
   - **`notr` / `notr2abs` / `notr3` のスタブ `tr` は `_T65_TMP` 配下に置く**。カウンタファイルも **`"$_T65_TMP/trcount"` に固定**する（`ta-65:76-81` に既存の `_T65_TMP` を使う。固定パスや repo 内に置かないこと。`mktemp -d` 配下なら並列実行時の衝突も構造的にゼロ。現状 `run-tests.sh` は逐次 source で `&` / `wait` / `xargs -P` を使っていないため実害は無いが、将来の並列化に備える）。
   - **スタブは実体を絶対パスで呼ぶこと**（例: `exec /usr/bin/tr "$@"`）。PATH 経由で `tr` を呼ぶと**自分自身に無限再帰**する。
   - カウンタは**各実行の前にリセット**する。
   - **`nonutf` / `nonutfplan` は `LC_ALL=en_US.ISO8859-1` で実行**。**当該ロケールが無い環境ではスキップし、スキップした旨を出力に残す**（Linux では `en_US.ISO-8859-1` 等、名称が異なる場合がある）。
   - **`badutf`（不正 UTF-8）は TC にしない**。`LC_ALL=C` 固定後は OS を問わず「非 HO」が正しい期待値。
4. §4.2 の再測定手順を実行し、`..` を含む監査記録が「0 件 または 本 issue 由来のみ」であることを確認する（**件数を契約値にしない**）。
5. `sh tests/run-tests.sh` を **macOS と `ubuntu-latest` の両方**で rc=0 になることを確認する（本書の測定は 1 OS のみ）。baseline は適用時点の main で再測定する。
6. **`scripts/apply-eh3-ho-always.sh` の 9 カテゴリ第 2 コピー（`:135-143` / `:174-183`）を同期するか retire するか決める。** 既に適用済みの一回性 applier で `tests/fixtures/eh3-known-gap-1089.flag` も存在しないため、**retire が最小コスト**。
7. **`.claude/rules/mode-classification.md` の Hardening Override 節に 1 行足す**（正本↔実装の drift を文字列一致で検出する手段を維持するため）:

   > 実装（`scripts/hooks/check-plan-hash.sh` の `_override=0` 直後の `case`）は、
   > 表記揺れ迂回を防ぐため**小文字化したキー `_ho_key`** で照合する（#1101）。
   > 本表のパス名は正本表記であり、実装側パターンは小文字で書かれる。

8. `docs/ai/hook-enforcement.md` の「既知の残存」から本項目を削除する。ただし **#1104（`Bash` 経路には HO 判定が存在しない）は未解決**なので、**「`Edit|Write` 経路では常時 block / `Bash` 経路は #1104 で追跡中」と matcher 別に書く**こと。

---

## 7. 残存リスク（本 patch で閉じないもの）

| # | 残存 | 理由 / 追跡 |
|---|---|---|
| **R-1** | **`Bash` 経路には HO 判定自体が存在しない** | HO を持つ hook は `check-plan-hash.sh` 1 本のみで `Edit\|Write` matcher にしか配線されていない。**#1104** |
| **R-2** | symlink 経由の到達 | 字句のみで判定し FS に触れない（意図的） |
| **R-3** | バックスラッシュ（`a\b/CLAUDE.md`） | macOS / Linux では別ファイルであり FS 到達不能。**スコープ外** |
| **R-4** | Unicode の大小文字（トルコ語 `İ` / 全角） | `tr 'A-Z' 'a-z'` は ASCII のみ。本 patch で悪化しない |
| **R-5** | `#1135` patch との適用順 | 本 patch を先に入れれば `#1135` 側の「差分 0」は冗長になる。**Human 判断** |
| **R-6** | **worktree 越し / REPO_ROOT 外の target で HO が発火しない**（現 main も同様） | HO 9 カテゴリは **repo root 起点の完全一致**。`.claude/worktrees/<id>/CLAUDE.md` や別 clone の絶対パスは HO にならない。**本リポジトリは agent worktree を常用**。**別 issue 化を推奨** |
| **R-7** | **`_dl_ext`（doc-light 判定）の失敗経路・ロケール依存は残る** | 本 patch が固定したのは HO 判定 3 コマンド + `_tf_lc` 2 コマンド。**`_dl_ext=$(printf \| sed …)` は `\|\|` を持たず、失敗すると `set -e` で rc=1 になる**。**ただし `_dl_ext` は「非 HO の `.md` を自動 skip する」判定であり、失敗しても block 側には倒れない（承認境界を弱めない）**。**rev4 までの「悪化しないが解消もしない」という記述は `_tf_lc` について誤りだったので §2.8 で是正済み。`_dl_ext` については残存として明示する** |
| **R-8** | **Linux / GNU coreutils での全 TC 実行が未実施** | 本書の測定は macOS 1 OS。**CI（`ubuntu-latest`）での初回実行が実質的な OS 検証**（§6 step 5） |
| **R-9** | **Unicode 空白（U+00A0 / U+3000）は trim されない** | `LC_ALL=C` の帰結。base・rev5 とも非 HO で**退行ではない**が、ASCII 空白版を塞いでいるのに対し**非対称**が残る |
| **R-10** | **インフラ故障時に非 HO ファイルまで block される**（B-12） | fail-closed の意図的な帰結。`sed` / `tr` が壊れた環境では**すべての Edit/Write が止まる**。復旧は PATH の修復。**「壊れた環境では止める」という設計判断であり、可用性より承認境界を優先している** |

---

## 8. 検証の再現手順とサンドボックス境界

すべて `origin/main` = `01c8946` のサンドボックス複製で実施。**リポジトリ本体の `scripts/hooks/check-plan-hash.sh` は編集も実行もしていません。**

> **本書の執筆自体（`Write` ツール）は本体 hook を PreToolUse として発火させ、`docs/working/_audit/skip-decision-log.jsonl` に `EH-3_DOC_LIGHT_SKIP` を追記します。** 測定ではなく執筆の副作用ですが §4.2 の絶対件数を劣化させるため、同節は件数ではなく条件式で判定します。

```sh
# 1) 大文字セグメントを含む root にサンドボックスを作る
R=/private/tmp/pg1101/UPPER_Root
mkdir -p "$R/base/scripts/hooks" "$R/base/docs/working/_audit"
mkdir -p "$R/pat/scripts/hooks"  "$R/pat/docs/working/_audit"
cp scripts/hooks/check-plan-hash.sh "$R/base/scripts/hooks/"
cp scripts/hooks/check-plan-hash.sh "$R/pat/scripts/hooks/"
# 2) $R/pat 側へ §3 の 2 hunk を適用する
# 3) env を unset し、ロケールを明示し、rc ではなく出力文字列で判定する
#    絶対パス TC は「その複製自身の root」を使うこと
env -u PLANGATE_HOOK_TASK -u PLANGATE_SKIP_REASON -u PLANGATE_HOOK_FILE \
    -u PLANGATE_HOOK_STRICT -u PLANGATE_BYPASS_HOOK LC_ALL=C LANG=C \
    sh "$R/pat/scripts/hooks/check-plan-hash.sh" "" "$R/pat/CLAUDE.md" </dev/null
# 4) tr 故障の fault injection（§2.7 / §2.8）
S=$R/shim; C=$R/trcount
mkdir -p "$S"
cat > "$S/tr" <<'SH'
#!/bin/sh
n=$(cat "$PG_TR_COUNTER" 2>/dev/null || echo 0); n=$((n+1))
printf %s "$n" > "$PG_TR_COUNTER"
[ "$n" -ge 2 ] && exit 127          # notr2: 2 回目以降失敗（notr3 なら -ge 3）
exec /usr/bin/tr "$@"               # 実体は絶対パスで呼ぶ（PATH 経由だと無限再帰）
SH
chmod +x "$S/tr"
rm -f "$C"
env ... PATH="$S:$PATH" PG_TR_COUNTER="$C" \
    sh "$R/pat/scripts/hooks/check-plan-hash.sh" "" "$R/pat/CLAUDE.md" </dev/null
```

`REPO_ROOT` は `$(dirname "$0")/../..` で解決されるため、サンドボックス側の hook はサンドボックスを root と見なします。

## 9. 関連

- **#1101**（本 issue）/ **#1089**（PR #1097 で是正済の隣接欠陥）/ **#1104**（`Bash` 経路に HO 判定が無い）/ **#1135**（AI-owned レーン。traversal ガードを共有）/ **#1144**（hook 配布。本 patch を前提とする）
- [`1135-ai-owned-lane-patch.md`](./1135-ai-owned-lane-patch.md) §差分 0
- `tests/extras/ta-65-eh3-ho-task-context.sh` TC-06 / TC-07 / `_T65_TMP`（`:76-81`）
- `scripts/ai-loop/arbiter.py::_normalize_path`（fail-closed の前例）
- `.codex/hooks/eh-bridge.sh:87-88`（未知 rc を `allow` へ変換する箇所。§2.7）
- `scripts/apply-eh3-ho-always.sh:135-143` / `:174-183`（9 カテゴリの第 2 コピー。§6 step 6）
- `.claude/rules/mode-classification.md`（HO 9 カテゴリの正本。§6 step 7 で 1 行追記を提案）
- `8b604fe:tests/fixtures/pg-fold-path.sh`（却下した O(n²) 実装。数値は commit message からの引用で未再現）
