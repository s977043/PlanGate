# #1101 patch 設計 — Hardening Override のパス正規化（**Human 適用**）

> 対象: `scripts/hooks/check-plan-hash.sh`（**Hardening Override 対象パス**）
> 測定基点: `origin/main` = `6def020` / 2026-08-18 / macOS 25.6.0（APFS case-insensitive）/ `/bin/sh` = bash 3.2 / BSD sed・BSD tr
> （`check-plan-hash.sh` と `ta-65` は `01c8946`〜`6def020` で差分ゼロを実測）
> 責務: **設計・差分・検証設計は AI-owned（本書）/ 適用は Human-owned**
> 位置づけ: **#1144 で hook を配布する前に閉じるべき筆頭**
> 版: **rev7**

## 版の履歴（撤回した主張を明示する）

| 版 | 何を変えたか | 撤回した主張 |
|---|---|---|
| rev1 | 初版 | — |
| rev2 | 末尾 `/` 除去に `case` ガード / 空キー fail-closed / 順序事故の回帰 TC | 「入力長に線形なので上限ガード不要」（無ガード `${var%/}` が bash 3.2 で O(n²)） |
| rev3 | `LC_ALL=C` を内側固定 / TC を OS・環境非依存へ | 「5 シェルで同一挙動＝可搬」/「15 変異すべて kill」/ `badutf` TC の有効性 |
| rev4 | コマンド置換代入に `\|\|` フォールバック / `.` `*/.` クラス明記 | 「`sed`/`tr` が実行不能 → 空キー → rc=2」 |
| rev5 | `_ho_root` を fail-closed へ / `_tf_lc` に `\|\|` + guard + `LC_ALL=C` | 「`\|\| _ho_root="$REPO_ROOT"` は block を減らさない側」/ R-7 の「悪化しない」 |
| rev6 | 監査ログの改行注入を遮断（MJ-1）/ `log_event` 失敗で block が消えるのを解消（MJ-2）/ infra 失敗を fail-closed から「base 相当へ縮退」へ（MJ-3）/ traversal の marker を分離（MN-1） | 「3 箇所すべて fail-closed」/ B-12・R-10 の「可用性より承認境界を優先」/ rev5 の reason 設計 |
| **rev7** | **traversal 判定を `_ho_key` と生 `target_file` の union へ**（MJ-A）/ **`_esc_dl` / `_esc_c3` にも `\|\|` + 空チェック**（MJ-B）/ **構造検査を適用手順の step 化**（MJ-C）/ **タブ切り詰め + `[truncated]` マーカー + 監査書込失敗の in-band 警告**（MN-1）/ **`_PG_CR` / `_PG_TAB` が空でも壊れない形へ**（MN-2）/ §2.9 の論拠を不変条件ベースへ | **「traversal は縮退させない」**（**縮退キーは `_norm_target` で `./` 除去済みのため `.//` の証拠が消え、`notr` / `nosed` で `.//CLAUDE.md` が素通りしていた**）/ **§2.9「C でも失われないもの」表**（**`docs/../` クラスだけを根拠にし `.//` クラスを故障注入下で測っていなかった**）/ **§2.9 の「攻撃者は誘発できない」という能力主張**（証明不能。**不変条件による論証へ差し替え**）/ **R-7 の残存列挙**（**`_dl_ext` は挙げたが index shift の影響を実際に受ける `_esc_dl` を挙げていなかった**） |

## 結論先行

**承認境界のパス集合（HO 9 カテゴリ）は変更しません。** 変えるのは **「HO 判定が何をキーに glob 照合するか」** と、**その正規化が壊れたときにどう振る舞うか**です。

- **block する側（HO 判定）**にだけ HO 専用キー `_ho_key` を導出する。**通す側（`_norm_target`）は不変**
- `..` / `//` / `/./` / `.` は **解決せず fail-closed で弾く**（`realpath` 非依存）。判定は **`_ho_key` と生 `target_file` の union**（縮退キーでは `.//` の証拠が消えるため。§2.3）
- **パラメータ展開による除去・切り詰めは必ず `case` で前置ガードする**（無ガードの `${var%%pat}` は bash 3.2 で O(n²)。§2.4）
- **`sed` / `tr` は `LC_ALL=C` を内側固定する**（§2.6）
- **コマンド置換のみの代入には `|| <既定値>` を付ける**（§2.7）
- **インフラ失敗（`sed`/`tr` が壊れている）は block ではなく「base 相当の判定へ縮退」する**（§2.9）
- **`log_event` は「失敗しない」「1 レコード 1 行・5 フィールドを保証する」「切り詰めたことを記録に残す」「書けなかったら in-band で警告する」**（§2.10 / §2.11）
- **`||` を足す対象は HO 判定系だけでなく、index shift の下流も含める**（§2.13）

**設計原則を 1 行で**: **policy による拒否は fail-closed、infrastructure の故障は degrade-to-base。** 前者は攻撃者が誘発できる（だから止める）、後者は誘発できず可用性だけを壊す（だから止めない）。

### 現状の穴の規模

| 文脈 | 現 main |
|---|---|
| **no-task** | HO 9 カテゴリのうち `.md` を含む 4 カテゴリが `DOC_LIGHT_SKIP`（rc=0）で素通り |
| **TASK 文脈あり** | **9 カテゴリ × 9 変換クラス = 81 中 52 組合せが rc=0 で完全通過**（実測・§5.1） |

---

## 1. 現状の実測（`origin/main` = `6def020`）

### 1.1 検証方法（**rc で判定しない / env を unset / ロケール固定 / 自分の ROOT を使う**）

```sh
env -u PLANGATE_HOOK_TASK -u PLANGATE_SKIP_REASON -u PLANGATE_HOOK_FILE \
    -u PLANGATE_HOOK_STRICT -u PLANGATE_BYPASS_HOOK LC_ALL=C LANG=C \
    sh "<hook>" "" "<target>" </dev/null
```

- **`rc` ではなく出力の marker 文字列で判定**する（非 `.md` は `SKIP 拒否` で rc=2 を返すため、HO を壊しても rc は 2 のまま）。
- `target_file=${PLANGATE_HOOK_FILE:-${2:-}}` により **env が位置引数に優先**するため `PLANGATE_HOOK_FILE` は**必ず unset**。
- **`LC_ALL` / `LANG` も測定条件**（§2.6）。
- **絶対パス TC は「そのサンドボックス自身の REPO_ROOT」を使う**。別 root を渡すと patch の欠陥ではなく測定の誤りで noHO になる（本作業中に一度踏んだ）。
- **fault injection の shim が実際に起動したかを確認する**（カウンタファイルの有無等）。**shim ディレクトリ名の取り違えで「shim 無しの測定」を「shim ありの測定」と誤認した実例が本作業中にある**。
- 検証はすべて **サンドボックス複製**。**リポジトリ本体の hook は編集も実行もしていない**（§8）。

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

`schemas//x.schema.json` と `schemas/./x.schema.json` は **現 main でも既に rc=2 HO**（`case` glob の `*` が `/` を跨ぐため `schemas/*.schema.json` が偶然拾う）。**防御が偶然に依存している**状態を正規化で決定論化します。

---

## 2. 設計

### 2.0 設計判断の代償を先に書く

**現 main はこの位置でパラメータ展開と `case` しか使っておらず、fork ゼロ・ロケール非依存・失敗経路なしです。** 本 patch は `sed` / `tr` を持ち込みます。代償は **6 つ**あり、**6 つとも実測で穴として顕在化しました**:

| # | 代償 | 顕在化した版 | 対処 |
|---|---|---|---|
| 1 | **ロケール依存** | rev2 | `LC_ALL=C` 内側固定（§2.6） |
| 2 | **失敗の伝播（`set -e` 即死）** | rev1〜rev3 | `\|\|` フォールバック（§2.7） |
| 3 | **フォールバック値の選択ミス** | rev4 | 縮退先を `_norm_target` に（§2.7(b) / §2.9） |
| 4 | **呼び出しインデックスの移動**（`_tf_lc` が 3 回目に） | rev4 | `_tf_lc` にも同じ 3 点セット（§2.8） |
| 5 | **block 経路が増えた分だけ監査ログ注入面が広がる** | rev5 | `log_event` で 1 行に切り詰め（§2.10） |
| 6 | **`log_event` 自体が失敗経路**（`_audit/` 書込不可で block が消える） | rev1 以前から / rev5 の主張が誤り | `log_event` を絶対に失敗させない（§2.11） |
| 7 | **縮退キーが証拠を落とす**（`_norm_target` は `./` 除去済みなので `.//` が消える） | **rev6** | traversal を **union 判定**へ（§2.3 / MJ-A） |
| 8 | **index shift の下流がもう 1 つあった**（`_esc_dl` が 4 番目の `tr` に） | **rev6**（§2.8 と同一クラスの 3 度目） | 下流の該当箇所にも `\|\|` + 空チェック（§2.13） |

**「防御を足すと別の穴が開く」ことが 5 巡にわたり実際に起きたので、追加した各行がどの失敗モードを持つかを §2.5〜§2.11 に個別に書きます。** rev6 でも **MJ-1 の是正（改行切り詰め）が O(n²) を再導入し、性能スイートの再実行だけで検出しました**（§2.10）。**「同じ失敗クラスを別の構文でやり直す」ことが繰り返し起きる**ため、§2.4 のガード規則は**新しく足すパラメータ展開すべてに適用**します。

### 2.1 `..` / `//` の扱い — **解決せず fail-closed（採用）**

1. **可搬性**: `realpath` は macOS 標準に無く、`readlink -f` は BSD/GNU で挙動が違う。
2. **FS へ触れない**: HO 判定は**字句のみ**で決まるべき。
3. **前例が repo 内にある**: `scripts/ai-loop/arbiter.py::_normalize_path`（`:344-355`）。
4. **#1135 patch の「差分 0」と同形**。
5. **`..` を畳む実装は事故った**: `8b604fe:tests/fixtures/pg-fold-path.sh` に O(n²)。

**却下**: `realpath` / `readlink -f`（可搬性）/ `python3` の `posixpath.normpath`（HO 判定を Python 依存にできない）/ セグメント走査。

### 2.2 大小文字 — **非対称に入れる**

```
HO 判定（block する側）  : 小文字化する      → 過剰検出しても block が増えるだけ = 安全側
doc-light 判定（通す側） : 小文字化しない    → 通す範囲が広がると穴になる = 危険
```

`_norm_target` は **doc-light / maintenance / c3 判定**の 3 経路で共有されているため書き換えず、**HO 専用キー `_ho_key` を新設**します。

**HO の `case` パターンは小文字リテラルと元表記の両方を持たせます**（`AGENTS.md|CLAUDE.md|agents.md|claude.md`）。§2.9 の縮退時に `_ho_key` が `_norm_target`（小文字化されていない）になるため、**1 つの `case` で両モードを受けるための必須条件**です。他 8 カテゴリのパターンは元から小文字リテラルなので追加不要。

### 2.3 適用順（**順序に依存する事故を実測で 2 件検出**）

```
(1) 前後空白の除去 + 小文字化（LC_ALL=C / || フォールバック）→ 失敗時は _norm_target へ縮退
(2) traversal fail-closed 判定           ← ★ (3) より前 / ★ _ho_key と生 target_file の union
(3) 先頭 `./` 除去 / 末尾 `/` 除去       ← ★ どちらも case で前置ガード
(4) root の小文字化 → repo root 除去     ← ★ (1) より後 / 失敗時は _norm_target へ縮退
```

- **★ traversal は `_ho_key` だけを見てはいけません（MJ-A）。** `_ho_key` は (1) で `_norm_target` へ縮退しうるところ、**`_norm_target` は base 側で既に先頭 `./` を除去済み**（`.//CLAUDE.md` → `/CLAUDE.md`）なので **`//` の証拠が消えます**。これは §2.3 が「(2) を (3) より後ろに置くと `.//CLAUDE.md` が素通り」と書いた事故そのものが、**縮退経路で再現**したものです。実測（no-task）:

  | target | mode | base | **rev6** | **rev7** |
  |---|---|---|---|---|
  | `.//CLAUDE.md` | healthy | DL/0 | TRAV/2 | TRAV/2 |
  | `.//CLAUDE.md` | `notr` | pass/127 | **pass/127** | **TRAV/2** |
  | `.//CLAUDE.md` | `nosed` | pass/127 | **pass/127** | **TRAV/2** |
  | `.//bin/plangate` | `notr` | pass/127 | **SR/2**（TRAV ではない） | **TRAV/2** |

  **是正**: `for _ho_cand in "$_ho_key" "${target_file:-}"` で **union** を取る。**回帰 = 変異 MA / 入力 `dotdbl_notr` `dotdbl_nosed`**。

- **★ (2) を (3) より後ろに置くと `.//CLAUDE.md` が素通り**（**回帰 = MX1 / 入力 `dotdbl`**）。
- **★ (4) を (1) より前に置くと `<REPO_ROOT を大文字化>/CLAUDE.md` が素通り**（**回帰 = MX2b / 入力 `absup`**）。
- traversal の `..` アームは **`..|../*` と `*/..|*/../*` の両方が必要**（**回帰 = MX3 / 入力 `parent`**）。

### 2.4 性能ガード規則（**新しいパラメータ展開すべてに適用**）

`/bin/sh`（bash 3.2）では **パターンに一致しないときの `${var%pat}` / `${var%%pat}` が入力長に対して二次**です（5 回ループ）:

| len | `${k%/}`（無ガード） | `case "$k" in */) ... esac` |
|---:|---:|---:|
| 25,000 | **822 ms** | 62 ms |
| 100,000 | **12,093 ms** | 74 ms |
| 200,000 | **48,207 ms** | 92 ms |

**rev6 でも同じ罠を踏みました。** MJ-1 の是正として入れた `msg=${2%%"$_PG_NL"*}` が無ガードだったため:

| len | rev5 | **rev6（無ガード版）** | **rev6（`case` ガード版・採用）** |
|---:|---:|---:|---:|
| 100,000 | 214.6 ms | **732.4 ms** | **218.3 ms** |
| 200,000 | 408.4 ms | **2,367.0 ms** | **265.5 ms** |

→ **規則**: `${var%…}` / `${var%%…}` / `${var#…}` を新規に足すときは、**必ず `case` で「一致する場合だけ」に入る**こと。本 patch 内の 6 箇所すべてがガード下です。

#### この規則には**検出器**が要る（MJ-C）

**rev2 と rev6 で同じ罠を 2 回踏み、rev6 では「機能 TC は 1 件も落ちず、性能スイートの再実行だけで検出」しました。** §5.5 の測定はサンドボックス内の使い捨てで repo に残らないため、**このままでは 3 回目が起きます**。wall-clock より決定論的な**構造検査**を `ta-65` に入れます:

```sh
# 未ガードの ${var%…} / ${var#…} を検出（bash 3.2 の O(n^2) 罠）
grep -nE '\$\{[A-Za-z_][A-Za-z_0-9]*(%%?|##?)' scripts/hooks/check-plan-hash.sh \
  | grep -vE '^[0-9]+:[[:space:]]*[^|()]*\)[[:space:]]' \
  | grep -vE 'dirname|:-|:=' 
# → 出力ゼロであること
```

**実測**: base **hits=0** / rev7 採用版 **hits=0**（false positive なし）/ **無ガード版 hits=1（kill）**。**同じ無ガード版は機能 TC では検出できません**（改行注入テストはログ 1 行のまま合格する）。**§6 step 4 に入れます。**

### 2.5 空キー（`_ho_key`）の扱い

パイプラインの終了ステータスは最後の `tr` のものなので、**中間段の `sed` が落ちても `set -eu` は発火せず `_ho_key` が空**になります。空キーは HO の `case` のどのアームにも一致せず **HO 判定が丸ごとスキップ**されます（**Claude Code の PreToolUse は exit 2 のみ block**）。

| 失敗の位置 | `set -e` の挙動 | rev6 の扱い |
|---|---|---|
| **`sed`（中間段）が失敗** | status は `tr` のもの＝0 なので**発火しない** | **`_ho_key` が空 → `_norm_target` へ縮退**（§2.9） |
| **`tr`（最終段）が失敗** | **代入文の status が非 0 → 即死** | `\|\| _ho_key=''` → 同上 |
| **空白のみの target**（`"   "`） | 正常終了・出力が空 | `_norm_target`（= `"   "`）で判定 → base と同じ |
| **不正 UTF-8 を含む target** | `LC_ALL=C` により失敗しない | 通常経路。**正しい**（別名ファイルであり HO 対象ではない） |

### 2.6 ロケール依存 — **`LC_ALL=C` を内側固定する**

**BSD `tr 'A-Z' 'a-z'` はロケールの照合順で範囲を解釈するため、非 UTF-8 ロケールで ASCII を破壊します。**

| `LC_ALL` | `CLAUDE.md` → | `BIN/PLANGATE` → |
|---|---|---|
| `C` / `en_US.UTF-8` | `claude.md` | `bin/plangate` |
| **`en_US.ISO8859-1` / `ISO8859-15`** | **`BKaT..l.`（破壊）** | **`.HM/.KaMFa..`（破壊）** |
| **`en_US.US-ASCII`** | **`claude.LC`（部分破壊）** | `bin/plangate` |

未固定（rev2）では TASK 文脈で `CLAUDE.md` / `bin/plangate` / `.claude/settings.json` / `schemas/x.schema.json` がいずれも **PASS rc=0**（base は HO rc=2）＝**現 main より弱い退行**でした。

**是正**: 各コマンドに `LC_ALL=C` を**内側で**付ける。副次効果として BSD sed と GNU sed の不正バイト時の挙動も一致します（§5.6）。**日本語パス等への影響はゼロ**（0x41-0x5A のバイト置換で 0x80 以上を変更しない）。

### 2.7 `set -e` 下のコマンド置換代入 — **`||` は必須**

#### (a) `_ho_key`

PATH 先頭に `exit 127` する `tr` を置いた実測（target = `CLAUDE.md` / `LC_ALL=C`）:

| shim | shell | **base** | **rev3** | **rev4〜rev6** |
|---|---|---|---|---|
| **`tr` 常時失敗** | sh / bash / zsh / dash / ksh | HO / rc=2 | **なし / rc=127** | **HO / rc=2** |

**rc=127 は両ハーネスで「通す」側**です。Claude Code の PreToolUse は exit 2 のみ block、**`.codex/hooks/eh-bridge.sh:87-88` は未知 rc を明示的に `allow` へ変換**します。

> **注意（MN-2）: この規則を機械的に全箇所へ適用してはいけません。** `_PG_CR=$(printf '\r') || _PG_CR=''` のように**既定値が空文字**だと、後段の `case "$msg" in *"$_PG_CR"*)` が**全文字列に一致してメッセージ全体が消えます**（実測: 長さ 0 になる）。**`||` の既定値は「その変数の意味として安全な値」でなければならず、空文字が安全とは限りません。** rev7 は (1) 空なら別表記で再取得、(2) それでも空なら**その `case` 自体をスキップ**（`[ -z "$_PG_CR" ] || case …`）の二段で閉じています。

#### (b) `_ho_root` — **既定を生 `REPO_ROOT` にした rev4 は誤り**

`_ho_key` は**小文字化済み**なので、生の `REPO_ROOT`（大文字を含む）とは prefix が一致せず **root 除去が失敗し、キーが絶対パスのまま HO の `case` に当たりません**。

実測（大文字を含む ROOT / 各版が**自分の** root / 2 回目以降の `tr` だけ失敗する shim / TASK 文脈）:

| target | **base** | **rev4** | **rev5 / rev6** |
|---|---|---|---|
| `<ROOT>/CLAUDE.md` | HO / rc=2 | **noHO / rc=0** | **HO / rc=2** |
| `<ROOT>/bin/plangate` | HO / rc=2 | **noHO / rc=0** | **HO / rc=2** |
| `<ROOT>/CLAUDE.md`（no-task） | HO / rc=2 | **noHO / rc=127** | **HO / rc=2** |

**rev6 は `_ho_root` が空なら `_ho_key=$_norm_target` へ縮退**します（`_norm_target` は既に base と同じ case-sensitive な root 除去済み）。**回帰 = 変異 M20 / 入力 `notr2abs`**。

##### 代案「1 本のパイプラインで target と REPO_ROOT を同時に正規化」を却下した理由

fork を減らせますが、**改行を含む target_file で root スロットに任意文字列を注入できます**。実測:

```
target = "CLAUDE.md\n/evil/root"
  key          = claude.md
  derived root = /evil/root␊/private/tmp/.../rev6      ← 攻撃者が root 側を制御
```

**HO 判定の入力に攻撃者制御の分離子を持ち込む設計は fork 1 個の節約と釣り合いません。**

### 2.8 `_tf_lc`（plan.md guard）— rev4 が露出させた穴

**HO 判定が `tr` を 2 回消費するため、no-task 経路の既存行 `_tf_lc=$(… | tr …)`（`||` なし）が 3 回目の呼び出しに押し出され**、「3 回目以降失敗」パターンで `set -e` 即死します。

実測（no-task / `docs/working/TASK-X/plan.md`）:

| shim | **base** | **rev4** | **rev5** | **rev6** |
|---|---|---|---|---|
| `notr3`（3 回目以降失敗） | BLOCK / rc=2 | **なし / rc=127** | BLOCK（fail-closed）/ rc=2 | **BLOCK / rc=2** |
| `notr2` | BLOCK / rc=2 | **なし / rc=127** | HO / rc=2 | **BLOCK / rc=2** |
| `notr`（常時失敗） | **なし / rc=127**（base 自身の穴） | HO / rc=2 | HO / rc=2 | **BLOCK / rc=2** |

**rev6 は 3 パターンすべてで base 以上**です（`notr` では base の穴も塞ぐ）。縮退先は `_tf_lc=$_norm_target`。**回帰 = 変異 M21 / 入力 `notr3`**。

**`LC_ALL=C` も付けます。** 未付与だと **`LC_ALL=en_US.ISO8859-1` では plan.md guard が丸ごと無効**になります（`PLAN.md` だけでなく**小文字の `plan.md` すら** base で `DOC_LIGHT_SKIP` rc=0）。pre-existing な穴ですが同じ 1 行で閉じられるため分離しません（B-11）。

#### 同一 patch で是正する判断（別 issue にしない）

穴自体は rev1 以前からですが、**rev4 が `tr` の呼び出しインデックスを 1→3 へずらし、より起きやすい部分故障で発火するようにした**＝rev4 が作った退行です。分離すると**既知の退行を抱えたまま出荷**することになり、「#1144 で配布する前に閉じる」という位置づけと矛盾します。

### 2.9 インフラ故障は **fail-closed ではなく degrade-to-base**（rev6 で方針転換）

rev5 は `_ho_key` / `_ho_root` の導出失敗を **block（exit 2）** にしていました。**その帰結を実測すると、`.md` に限らず全ファイルの編集が止まります**（`tr` 常時失敗 / TASK 文脈）:

| target | **base** | **rev5** | **rev6** |
|---|---|---|---|
| `src/app.ts` | pass / rc=0 | **HO / rc=2（block）** | pass / rc=0 |
| `README.md` | pass / rc=0 | **HO / rc=2（block）** | pass / rc=0 |
| `docs/ai/x.md` | pass / rc=0 | **HO / rc=2（block）** | pass / rc=0 |

#### 3 案の比較

| 案 | HO 検出力（infra 故障時） | 可用性 | 判定 |
|---|---|---|---|
| **A: fail-open**（キーが空なら HO 判定をスキップ） | **base 未満**（`CLAUDE.md` すら通る） | 影響なし | **却下**（現 main より弱い） |
| **B: fail-closed**（rev5） | base 超（表記揺れも止まる） | **全ファイル編集が停止** | **却下**（下記） |
| **C: degrade-to-base**（rev6 で採用 / rev7 の union 判定で完成） | **常に base 以上**（表記揺れだけ取り逃す） | 影響なし | **採用** |

**C を採る根拠（不変条件・実測済み）**:

> **縮退キー ≡ base キー**（`_ho_key := _norm_target`）である。したがって **縮退時の HO 判定は base の HO 判定と同一関数**になり、**検出力は入力に依らず常に base 以上**。
> **81 セル × 4 モード（healthy / `notr` / `nosed` / `notr2`）= 324 セルで、base が block して rev6/rev7 が通すセルは 0 件**。

**B を却下した理由**:

1. **B のコストは実在する**（`.md` に限らず全ファイルの編集停止）。#1079 の EH-13 fail-closed 化と同型の可用性の崖。
2. **B が守る差分は `CLAUDE.MD` 等の表記揺れだけ**で、C はその 1 点以外を base 以上で維持する（下表）。
3. **B は「壊れた環境で止める」という目的すら完全には果たさない**。`ulimit -u` によるプロセス枯渇では **hook プロセスごと落ちて rc≠2（= allow）** になり、B でも防げない。**「止める側に倒せば安全」という一般化が成立しない**。

> **rev6 は「攻撃者は `tr` 故障を誘発できない」を主な根拠にしていましたが、これは証明不能な能力主張なので撤回します。** 結論（C 採用）は上の不変条件だけで支持され、能力主張が崩れても崩れません。

**C でも失われないもの（実測 / `tr` 常時失敗）**:

| target | base | rev6 | **rev7** |
|---|---|---|---|
| `CLAUDE.md` | HO / rc=2 | HO / rc=2 | **HO / rc=2**（維持） |
| `docs/../CLAUDE.md` | pass / rc=127 | TRAV / rc=2 | **TRAV / rc=2**（base より強い） |
| **`.//CLAUDE.md`** | pass / rc=127 | **pass / rc=127** | **TRAV / rc=2** |
| **`.//bin/plangate`** | pass / rc=127 | **SR / rc=2**（TRAV ではない） | **TRAV / rc=2** |
| `CLAUDE.MD` | pass / rc=0 | pass / rc=0 | pass / rc=0（**これが C の唯一の劣化点**。base と同じ） |

**traversal は policy 判定なので縮退させません**（攻撃者が誘発できる入力だから）。**ただし rev6 はそれを実装で達成できていませんでした**（`.//` 行）。**union 判定（§2.3）を入れて初めて成立します。**

> **rev6 の「C でも失われないもの」表は `docs/../` クラスだけを根拠にしており、`.//` クラスを故障注入下で測っていませんでした。** 表に載せるクラスの選び方そのものが結論を作っていた例として記録します。

**回帰 = 変異 M19（キー縮退を削除）/ 入力 `nosed`**、**変異 M20（root 縮退を削除）/ 入力 `notr2abs`**、**変異 M22（`case` から元表記リテラルを削除）/ 入力 `notr` `nosed` `notr2abs`**。

### 2.10 監査ログへの改行注入（MJ-1）

rev5 は **block 経路を 3 つ増やし、`reason` に生の `target_file` を載せた**ため、**任意の target で監査ログに偽レコードを append できるようになりました**。実測（`hook-events.log` は TSV）:

```
target = 'docs/../x.md\n2026-01-01T00:00:00Z\tBYPASS\tcheck-plan-hash\t-\tFORGED ENTRY'

base : ログ 1 行（rc=0 で通過するため該当行なし）
rev5 : ログ 2 行 —— 2 行目が丸ごと偽の BYPASS レコード
       2026-01-01T00:00:00Z  BYPASS  check-plan-hash  -  FORGED ENTRY は正規化できないパス表記 …
rev6 : ログ 1 行・偽レコード 0 件
```

base で同型注入が成立するのは「HO glob に一致し、かつ `.md` で終わる改行入りパス」だけですが、**rev5 の新経路は非 HO ファイルでも発火するため任意タイミングで `BYPASS` 偽レコードを差し込めます**。しかも **§4.2 でログ grep を判定手段にしているのは本 patch 自身**であり、**同じコードベースは `_esc_c3` / `_esc_dl` でこのクラスを既に認識している**のに HO 経路だけ素通しでした。

**是正**: `log_event` 側で **改行・CR より後ろを捨てて 1 レコード 1 行を保証**する。**`tr` を足すと「外部コマンド失敗」クラスを再導入する**ため、パラメータ展開で行う（**かつ §2.4 のとおり `case` で前置ガード**）。**回帰 = 変異 MJ1a / 入力 `inject`**。

#### rev7 で追加した 3 点（MN-1）

**rev6 の「タブは除去にループが要るので残す」という理由は成立しません。** rev6 が改行に採ったのは**除去ではなく切り詰め**であり、**タブにも同じ `case` ガード 1 行で足ります**。

| 入力 | base | **rev6** | **rev7** |
|---|---|---|---|
| タブ入り target（`docs/../x.md\tINJECTED\tCOL`） | 5 フィールド | **7 フィールド**（列注入成立） | **5 フィールド** |
| 先頭が改行の target | 5 フィールド | field5 = `EH3_PATH_REJECTED: `（**パスが消えたことが分からない**） | field5 に **`[truncated]`** が付き**欠落が自明** |
| 通常の traversal target | — | `[truncated]` なし | **`[truncated]` なし**（false positive なし） |

1. **タブでも切り詰める**（`_PG_TAB`）→ フィールド数が常に 5。
2. **切り詰めたら `[truncated]` を付ける**→「監査から消えた」ことが in-band で分かる。
3. **`_PG_CR` / `_PG_TAB` が空でも壊れない形にする**（MN-2 / §2.7 の注記）。

**回帰 = 変異 MN1 / 入力 `tabinj`**。

### 2.11 `log_event` の失敗が block を消す（MJ-2）

**新 guard は 3 箇所とも `log_event` → `exit 2` の順**です。`log_event` は `mkdir -p` + `date` + `>>` で構成され、**`set -eu` 下ではどれが失敗してもそこでシェルが rc=1 で落ちます**。**rc=1 は PreToolUse では block になりません**（§2.7 が rc=127 について論じたのと同型）。

実測（`docs/working/_audit/` を 555 にした複製 / target = `CLAUDE.md` / TASK 文脈）:

| `_audit/` | **base** | **rev5** | **rev6** |
|---|---|---|---|
| **書込不可** | **rc=1 / block されない** | **rc=1 / block されない** | **rc=2 `HARDENING_OVERRIDE`** |
| 書込可 | rc=2 HO | rc=2 HO | rc=2 HO |

**本書は §2.5〜§2.8 で「追加した各行がどの失敗モードを持つか」を網羅したと宣言していましたが、3 箇所とも `log_event` 経由で fail-open に化けていました。** pre-existing（base も同じ）ですが、**本 patch の中心的主張が成立しない条件なので scope 内**として是正します。

**是正**: `log_event` を**絶対に失敗させない**。`mkdir` / append は `2>/dev/null`、`ts=$(date …) || ts='-'`（**これもコマンド置換のみの代入なので §2.7 と同型**）、末尾に `return 0`。**回帰 = 変異 MJ2 / 入力 `auditro`**。

**rev7 では append 失敗時に in-band の警告を出します**（`|| true` ではなく `|| printf '[Hook EH-3] WARN: audit log write failed …' >&2`）。rev6 は **block は成立するがレコードが黙って消え、「書けなかった」を知る手段が in-band にゼロ**でした。実測:

| `_audit/` 書込不可 | base | rev6 | **rev7** |
|---|---|---|---|
| block | rc=1（**されない**） | rc=2 HO | **rc=2 HO** |
| 痕跡 | なし | **なし** | **`WARN: audit log write failed` を stderr へ** |

> **ハーネス非対称（R-11）**: `.codex/hooks/eh-bridge.sh` は **rc=1 を `deny`** に写像します。したがって同じ rc=1 が **Claude Code では通し / Codex では止める**。本 patch は両ハーネスで rc=2 に揃えるので非対称は解消しますが、**「rc=1 なら安全側」と考えてはいけない**ことは記録に残します。

### 2.13 index shift の下流（MJ-B / §2.8 と同一クラスの 3 度目）

§2.8 で「rev4 が `tr` の index を 1→3 へずらした」ことを是正しましたが、**同じ shift の影響を受ける下流がもう 1 つありました**。

**`tr` 呼び出し回数: base = 2 回 / rev6 = 4 回。** 4 番目が **`_esc_dl=$(printf '%s' … | tr -d '\n\r\t')`（`||` 無し）**です。

実測（no-task / `docs/ai/x.md` = 非 HO の `.md` → doc-light）:

| shim | base | **rev6** | **rev7** |
|---|---|---|---|
| `notr3`（3 回目以降失敗） | DL / rc=0 / **記録 1 行** | **rc=127 / 記録 0 行** | **DL / rc=0 / 記録 1 行** |
| `notr2` | rc=127 / 記録 0 行 | rc=127 / 記録 0 行 | **DL / rc=0 / 記録 1 行**（base より強い） |
| healthy | DL / rc=0 / 記録 1 行 | DL / rc=0 / 記録 1 行 | DL / rc=0 / 記録 1 行 |

**壊れるのは `skip-decision-log.jsonl` の doc-light 記録**で、これは **§4.2 の判定手段であり `bin/plangate metrics --collect` の入力源**です。

**是正**: `_esc_dl` と `_esc_c3` に `|| + 空チェック`（縮退先は生の `_norm_target`）。**回帰 = 変異 MB / 入力 `dl_notr3`**。

**残る下流は R-7 に全数列挙**します。

### 2.12 marker の分離（MN-1）

rev5 は traversal / 空キー / root 失敗をすべて `HARDENING_OVERRIDE` として記録・出力していました。**これらは非 HO ファイルでも発火する**ため、**`ta-65:327,347` の「no-task で `HARDENING_OVERRIDE` が出たら false positive」という assert と将来衝突**します。

**是正**: **traversal 拒否は `EH3_PATH_REJECTED`** という別 marker にする（縮退方式の採用により、空キー / root 失敗はそもそも block しなくなった）。**`HARDENING_OVERRIDE` は「9 カテゴリに実際に一致した」場合だけ**を意味するようになります。

**検証時の期待値は marker の union**（`HARDENING_OVERRIDE` または `EH3_PATH_REJECTED`）で書くこと。

---

## 3. 差分（`scripts/hooks/check-plan-hash.sh`）

> **AI は本差分を適用しません**（HO 対象パス）。適用は Human-owned。
> **hunk は 3 箇所**: (A) `log_event`、(B) Hardening Override ブロック、(C) no-task 分岐の `_tf_lc`。
> **3 つを 1 回の適用に束ねてください。** 分割すると rev4→rev5 と同じ「既知の退行を抱えたまま出荷」になります。

### (A) `log_event`（MJ-1 / MJ-2）

```diff
@@
 WORKING_DIR="$REPO_ROOT/docs/working"
 AUDIT_LOG="$WORKING_DIR/_audit/hook-events.log"
 
+_PG_NL='
+'
+_PG_CR=$(printf '\r') || _PG_CR=''
+[ -n "$_PG_CR" ] || _PG_CR=$(printf '\015')
+_PG_TAB=$(printf '\t') || _PG_TAB=''
+[ -n "$_PG_TAB" ] || _PG_TAB=$(printf '\011')
 log_event() {
   level=$1
+  # 監査ログへの改行注入を防ぐ（#1101 MJ-1）: reason に生の target_file を載せる
+  # 経路が増えたため、改行/CR より後ろを捨てて 1 レコード 1 行を保証する。
+  # tr を足すと「外部コマンド失敗」クラスを再導入するのでパラメータ展開で行う。
+  # **case で前置ガードする**: 一致しない ${var%%pat} は bash 3.2 で入力長に対して
+  # 二次（#1101 F1 と同型）。無ガード版は 200000 文字で 2.4 秒かかる（実測）。
   msg=$2
-  mkdir -p "$(dirname "$AUDIT_LOG")"
-  ts=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
-  printf '%s\t%s\tcheck-plan-hash\t%s\t%s\n' "$ts" "$level" "${task_id:-${PLANGATE_HOOK_TASK:--}}" "$msg" >>"$AUDIT_LOG"
+  # 改行 / CR / タブより後ろを捨てて 1 レコード 1 行・5 フィールドを保証する（MJ-1 / MN-1）。
+  # 切り詰めたら [truncated] を付ける（監査から欠落したことを in-band で示す）。
+  # _PG_CR / _PG_TAB が空でも壊れないよう case 自体を [ -z … ] || でガードする（MN-2）。
+  _pg_trunc=0
+  case "$msg" in *"$_PG_NL"*)  msg=${msg%%"$_PG_NL"*};  _pg_trunc=1 ;; esac
+  [ -z "$_PG_CR" ]  || case "$msg" in *"$_PG_CR"*)  msg=${msg%%"$_PG_CR"*};  _pg_trunc=1 ;; esac
+  [ -z "$_PG_TAB" ] || case "$msg" in *"$_PG_TAB"*) msg=${msg%%"$_PG_TAB"*}; _pg_trunc=1 ;; esac
+  [ "$_pg_trunc" = "0" ] || msg="$msg [truncated]"
+  # 監査ログが書けない環境でも block を成立させる（#1101 MJ-2）。
+  # set -eu 下では mkdir / date / >> の失敗がそのままシェルを rc=1 で落とし、
+  # PreToolUse は exit 2 のみ block なので fail-open に化ける。
+  # 書けなかったこと自体は in-band で警告する（黙って消さない / MN-1）。
+  mkdir -p "$(dirname "$AUDIT_LOG")" 2>/dev/null || true
+  ts=$(date -u '+%Y-%m-%dT%H:%M:%SZ') || ts='-'
+  printf '%s\t%s\tcheck-plan-hash\t%s\t%s\n' "$ts" "$level" "${task_id:-${PLANGATE_HOOK_TASK:--}}" "$msg" >>"$AUDIT_LOG" 2>/dev/null \
+    || printf '[Hook EH-3] WARN: audit log write failed (%s)\n' "$level" >&2
+  return 0
 }
```

### (B) Hardening Override ブロック

> アンカー: `# (ii) Hardening Override 物理先頭判定（R-003/R-015、maintenance より上）` から
> 直後の `if [ "$_override" = "1" ]; then … fi` まで（現 main で **1 箇所のみ**）。

```diff
@@
   "$REPO_ROOT"/*) _norm_target="${_norm_target#$REPO_ROOT/}" ;;
 esac
 
+# (i-b) HO 判定専用キー _ho_key の導出（#1101 / TASK-1101）
+#   前後空白の除去 + 小文字化を外部コマンド 1 パイプラインで行う（1 文字ループは
+#   O(n^2) で EH-3 に timeout が無く暴走がハングになる / 8b604fe の実測）。
+#   LC_ALL=C を内側固定する: BSD tr はロケールの照合順で範囲を解釈するため
+#   en_US.ISO8859-1 等では CLAUDE.md すら小文字化に失敗する（実測）。
+#   || _ho_key='' は必須: コマンド置換のみの代入は置換の終了ステータスが代入文の
+#   ステータスになるため、最終段 tr の失敗で set -eu が即死する（rc=127 は
+#   PreToolUse では block にならず eh-bridge は未知 rc を allow へ変換する）。
+#   **導出できなかったときは block ではなく _norm_target（= base 相当のキー）へ
+#   縮退する**: sed/tr の故障は攻撃者が誘発できず、block にすると全ファイルの
+#   編集が停止する一方、縮退なら検出力は常に base 以上（#1101 MJ-3 / 実測）。
+#   _norm_target 自体は書き換えない（doc-light / maintenance / c3 は通す側）。
+_ho_key=$(printf '%s' "${target_file:-}" | LC_ALL=C sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | LC_ALL=C tr 'A-Z' 'a-z') || _ho_key=''
+if [ -z "$_ho_key" ] && [ -n "${target_file:-}" ]; then
+  _ho_key=$_norm_target
+fi
+
+# (i-c) traversal fail-closed（#1101 / #1135 の _trav と同形）
+#   `..` / `//` / `/./` / 末尾 `/.` / `.` 単体 を含むパスは字句解決せず一律 block。
+#   これは policy による拒否なので縮退させない（攻撃者が誘発できる入力）。
+#   **先頭 `./` 除去より前**に判定する：先に `./` を取ると `.//CLAUDE.md` が
+#   `/CLAUDE.md`（絶対パス形）になり `//` 検知をすり抜ける（実測で検出）。
+#   marker は HARDENING_OVERRIDE と分ける（非 HO でも発火するため / MN-1）。
+#   **_ho_key と生 target_file の union で判定する**: _ho_key は (i-b) で
+#   _norm_target へ縮退しうるが、_norm_target は base 側で先頭 ./ を除去済みで
+#   `.//CLAUDE.md` -> `/CLAUDE.md` となり `//` の証拠が消える（#1101 MJ-A / 実測）。
+_ho_trav=0
+for _ho_cand in "$_ho_key" "${target_file:-}"; do
+case "$_ho_cand" in
+  ..|../*|*/..|*/../*) _ho_trav=1 ;;
+  *//*)                _ho_trav=1 ;;
+  .|*/.|*/./*)         _ho_trav=1 ;;
+esac
+done
+if [ "$_ho_trav" = "1" ]; then
+  reason="EH3_PATH_REJECTED: ${target_file:-} は正規化できないパス表記 (fail-closed: path traversal)"
+  log_event "EH3_PATH_REJECTED" "$reason"
+  printf '[Hook EH-3] %s\n' "$reason" >&2
+  exit 2
+fi
+
+# (i-d) 先頭 `./` 除去と末尾 `/` 除去
+#   **除去は必ず case で前置ガードする**: bash 3.2 / ksh の ${var%pat} は一致
+#   しないときの走査が入力長に対して二次で、100000 文字 x5 で 12 秒かかる（実測）。
+case "$_ho_key" in
+  ./*) _ho_key="${_ho_key#./}" ;;
+esac
+case "$_ho_key" in
+  */) _ho_key="${_ho_key%/}" ;;
+esac
+#   root 側も同じ写像を通してから比較する（root 除去を大小文字非依存にする）。
+#   **失敗時は生の REPO_ROOT を使わない**: _ho_key は小文字化済みで prefix が
+#   一致せず root 除去が失敗し、絶対パスの HO 9 カテゴリがまるごと素通りする
+#   （#1101 NEW-4 / 実測）。_norm_target は base と同じ root 除去済みなので
+#   そちらへ縮退する。
+_ho_root=$(printf '%s' "$REPO_ROOT" | LC_ALL=C tr 'A-Z' 'a-z') || _ho_root=''
+if [ -z "$_ho_root" ]; then
+  _ho_key=$_norm_target
+else
+  case "$_ho_key" in
+    "$_ho_root"/*) _ho_key="${_ho_key#"$_ho_root"/}" ;;
+  esac
+fi
+
 # (ii) Hardening Override 物理先頭判定（R-003/R-015、maintenance より上）
+# 判定対象は _ho_key。通常時は小文字化済み、縮退時は _norm_target（元表記）なので
+# **case は小文字リテラルと元表記の両方を持つ**（9 カテゴリの集合は不変）。
+# 正本は .claude/rules/mode-classification.md。
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
+  AGENTS.md|CLAUDE.md|agents.md|claude.md) _override=1 ;;
 esac
 if [ "$_override" = "1" ]; then
-  reason="HARDENING_OVERRIDE: ${_norm_target} は maintenance 窓内でも常時 block (R-003/R-015)"
+  # 監査ログ / reason には**生の要求パス**を残す（正規化後の値ではない）。
+  # 改行の切り詰めは log_event 側で行う（MJ-1）。
+  reason="HARDENING_OVERRIDE: ${target_file:-} は maintenance 窓内でも常時 block (R-003/R-015)"
   log_event "HARDENING_OVERRIDE" "$reason"
   printf '[Hook EH-3] %s\n' "$reason" >&2
   exit 2
```

### (C) no-task 分岐の `_tf_lc`（plan.md guard / §2.8）

```diff
@@ no-task 分岐
-  _tf_lc=$(printf '%s' "$target_file" | sed 's/[[:space:]]*$//' | tr 'A-Z' 'a-z')
+  # LC_ALL=C: 非 UTF-8 ロケールでは tr が ASCII を壊し、plan.md guard が丸ごと
+  #   無効になる（実測: LC_ALL=en_US.ISO8859-1 で base は plan.md すら
+  #   DOC_LIGHT_SKIP rc=0）。
+  # || + 縮退: HO 判定が tr を 2 回消費するため本行は 3 回目の呼び出しになり、
+  #   部分故障で set -e が即死して plan.md guard が消える（#1101 NEW-5 / 実測）。
+  #   縮退先は _norm_target（base 相当）。
+  _tf_lc=$(printf '%s' "$target_file" | LC_ALL=C sed 's/[[:space:]]*$//' | LC_ALL=C tr 'A-Z' 'a-z') || _tf_lc=''
+  if [ -z "$_tf_lc" ] && [ -n "$target_file" ]; then
+    _tf_lc=$_norm_target
+  fi
   case "$_tf_lc" in
     */plan.md|plan.md)
```

### (D) `_esc_dl` / `_esc_c3`（skip-decision-log / §2.13）

```diff
@@ c3 conversation 記録
-        _esc_c3=$(printf '%s' "${_norm_target:-unknown}" | tr -d $'\n\r\t')
+        # HO 判定が tr を 2 回消費するため本行は下流にずれる。|| + 空チェックが無いと
+        # 部分故障で set -e が即死し、記録どころか SKIP 判定ごと消える（#1101 MJ-B）。
+        _esc_c3=$(printf '%s' "${_norm_target:-unknown}" | LC_ALL=C tr -d '\n\r\t') || _esc_c3=''
+        [ -n "$_esc_c3" ] || _esc_c3="${_norm_target:-unknown}"
@@ doc-light 記録
-      _esc_dl=$(printf '%s' "${_norm_target:-unknown}" | tr -d '\n\r\t')
+      _esc_dl=$(printf '%s' "${_norm_target:-unknown}" | LC_ALL=C tr -d '\n\r\t') || _esc_dl=''
+      [ -n "$_esc_dl" ] || _esc_dl="${_norm_target:-unknown}"
```

> **ついでに `$'\n\r\t'`（bash の ANSI-C quoting）も `'\n\r\t'` へ揃えます。** `dash` は ANSI-C quoting を解釈せず、**削除対象に `$` が混入**します。実測（target = `x$y-nrt.md`）: `sh` / `bash` / `zsh` / `ksh` は `x$y-nrt.md`、**`dash` だけ `xy-nrt.md`**（`$` が消える）。記録される target が壊れるだけで承認境界には影響しませんが、**同じ行を触るので同時に直します**。

### 3.1 既存の apply スクリプトとの整合

`scripts/apply-eh3-ho-always.sh` は適用済み判定を `hook_applied = i_override < i_branch` というインデックス比較で行うため本 patch 適用後も "already applied" を返します。**ただし 9 カテゴリ `case` の第 2 コピーを `:135-143` / `:174-183` に埋め込んでおり正本と乖離します**（§6 step 6）。

---

## 4. 既存挙動の変更（**全件**）

| # | 条件 | 変更前 | 変更後 | 備考 |
|---|---|---|---|---|
| **B-1** | **HO 9 カテゴリ × 大小文字 / 前後空白 / 末尾 `/`** | rc=0 通過（TASK 文脈） | **rc=2 `HARDENING_OVERRIDE`** | 是正そのもの |
| **B-1b** | **小文字形**（`claude.md` / `.claude/Rules/x.md` 等） | rc=0 通過 | **rc=2** | case-sensitive FS では別ファイルへの**意図的な過剰 block**（安全側） |
| **B-2** | **HO / 非 HO を問わず `..` / `//` / `/./` を含むパス** | rc=0（TASK 文脈）/ `DOC_LIGHT_SKIP`（no-task） | **rc=2 `EH3_PATH_REJECTED`** | **「通っていたものが止まる」変更**（通常運用下で唯一） |
| **B-4** | **`.` 単体 / 末尾 `/.`** | rc=0 通過 | **rc=2 `EH3_PATH_REJECTED`** | 独立クラス |
| **B-6** | **空白のみの target** | base 相当 | **base 相当（縮退）** | **rev5 では block していたが rev6 で base へ戻した** |
| **B-7** | **非 UTF-8 ロケールでの HO 判定** | HO（ロケール非依存） | HO（維持） | rev2 では退行していた |
| **B-9** | **`sed` / `tr` が失敗する環境での HO 判定** | base 相当 | **base 相当（縮退）+ traversal は block** | **rev3 は rc=127 / rev4 は部分故障で rc=0 / rev5 は全ファイル block**（§2.9） |
| **B-10** | **`sed` / `tr` が失敗する環境での plan.md guard** | `notr` では base も rc=127 | **全故障・部分故障とも rc=2 で block** | §2.8。**base より強い** |
| **B-11** | **非 UTF-8 ロケールでの plan.md guard** | **guard が丸ごと無効**（`plan.md` すら rc=0） | **rc=2 で block** | §2.8。**pre-existing な穴の是正** |
| **B-13** | **`_audit/` が書けない環境での全 block 経路** | **rc=1 で block されない** | **rc=2 で block** | §2.11。**pre-existing な穴の是正** |
| **B-14** | **改行を含む target を渡したときの監査ログ** | 該当行なし（rc=0 通過） | **1 レコード 1 行に切り詰め** | §2.10。**rev5 は偽レコードを append できた** |
| **B-15** | **traversal 拒否の marker** | （経路なし） | **`EH3_PATH_REJECTED`**（`HARDENING_OVERRIDE` ではない） | §2.12 |
| **B-16** | **`REPO_ROOT` に glob 文字（`[` `]` `*` `?`）を含む環境での絶対パス HO** | **`DOC_LIGHT_SKIP` rc=0（既存バグ）** | **rc=2 `HARDENING_OVERRIDE`** | base の `${_norm_target#$REPO_ROOT/}` は**非引用**なので root が glob として解釈され prefix 除去に失敗する。rev6/rev7 の `case "$_ho_key" in "$_ho_root"/*)` は**引用済み**なので healthy 経路で**副産物として解消**。実測: root = `ro[o]t` で **base DL/0 → rev7 HO/2** |
| **B-17** | **タブを含む target の監査レコード** | 5 フィールド | **5 フィールド + `[truncated]`** | rev6 は 7 フィールドになっていた（§2.10） |
| **B-18** | **部分故障下の doc-light 記録**（`skip-decision-log.jsonl`） | `notr3` では記録あり / `notr2` では rc=127 | **どちらも記録あり** | §2.13。**rev6 は `notr3` で記録が消えていた** |
| **B-19** | **`_audit/` 書込失敗時の in-band 痕跡** | なし | **stderr に `WARN: audit log write failed`** | §2.11 |
| **B-8** | HO パスの `reason` 文字列 | 正規化後の値 | **生値**（改行/CR/タブ切り詰め済み） | ログ表記のみ。文字列 assert するテストは repo 内に無し |

### 4.1 変わらないもの（実測 / 故障注入なし・`LC_ALL=C`）

24 件の対照（14 controls + `ta-65` TC-06 の 10 件）のうち **変わるのは `docs/../docs/ai/hook-enforcement.md`（B-2）の 1 件のみ**。

| 対象 | 変更前 → 変更後 |
|---|---|
| `docs/ai/hook-enforcement.md` / `.MD` / `docs/README.md` | `DOC_LIGHT_SKIP` rc=0 → 同 |
| `evil/CLAUDE.md` / `docs/.claude/rules/x.md` / `.claudex/rules/x.md` | `DOC_LIGHT_SKIP` → 同 |
| `docs/working/templates/plan.md` | `BLOCK: plan.md` rc=2 → 同 |
| `/tmp/foo.md` / `<ROOT>/docs/ai/hook-enforcement.md` | `DOC_LIGHT_SKIP` → 同 |
| `tests/extras/ta-09-metrics.sh` / `scripts/lib/foo.sh` / `notes/claude.mdx` / `/tmp/foo.txt` | `SKIP 拒否` → 同 |
| **`ta-65` TC-06 の非 HO 10 件**（`.claude/rules/x.txt` / `.claude/skills/x/SKILL.md` / `scripts/hooks/x.py` / `scripts/_helper.py` / `scripts/x.sh` / `bin/other` / `schemas/x.json` / `.github/workflows/x.json` / `docs/AGENTS.md` / `docs/working/TASK-T65/CLAUDE.md.bak`） | HO 判定に拾われない → 同（`HARDENING_OVERRIDE` も `EH3_PATH_REJECTED` も出ない） |
| `.claude/worktrees/<id>/CLAUDE.md` | `DOC_LIGHT_SKIP` → 同（**§7 R-6 の残存**） |

### 4.2 「正当な用途で `..` を含むパスを渡している経路」の調査 → **観測範囲では無し**

| 調査 | 方法 | 結果 |
|---|---|---|
| EH-3 の全呼び出し元 | `git grep -l 'check-plan-hash'`（非 docs） | target を渡すのは `.claude/settings.example.json` / `.codex/hooks/eh-bridge.sh` / `scripts/hooks/cursor-adapter.sh` の 3 経路。いずれも**受け取った file_path を素通しするだけで `..` を構築しない** |
| repo 内の `..` 文字列リテラル | `git grep '"[^"]*\.\./[^"]*"' -- tests scripts .claude .codex` | markdown リンク / `cd -- "$(dirname $0)/../.."` / `test_arbiter.py`（`..` を**拒否する**テスト）/ `ta-65:344`（**KNOWN-GAP TC-07 そのもの**）のみ |
| doc-light テストの期待値 | `git grep -l DOC_LIGHT -- tests` | `..` を `DOC_LIGHT` 期待で渡す TC は無し |
| repo 内の前例 | `scripts/ai-loop/arbiter.py:344-355` | 既に `..` / `//` / 絶対パス / バックスラッシュを拒否 |

#### 実運用ログの確認は **件数ではなく条件式で残す**

`skip-decision-log.jsonl` は **append-only** なので絶対件数は劣化します。**契約値にしないでください。**

```sh
grep -c '\.\./' docs/working/_audit/skip-decision-log.jsonl
grep '\.\./'    docs/working/_audit/skip-decision-log.jsonl   # 中身を見て個別判断
```

**判定条件**: 該当行が **(a) 0 件、または (b) 全件が本 issue の測定・KNOWN-GAP TC 由来**であれば B-2 の実運用影響は無いと判断してよい。

---

## 5. 検証結果

### 5.1 直積マトリクス — **生成規則（独立再現用）**

**カテゴリ代表 C1〜C9**:

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

**9 × 9 = 81 件** + 対照 24 件（controls 14 + TC-06 10）= 105 件。

#### 結果（`LC_ALL=C` / 大文字を含む ROOT / 故障注入なし / TASK 文脈）

| | base | **rev7** |
|---|---:|---:|
| 81 セル中 **rc=0 で完全通過** | **52** | **0** |
| 81 セル中 block | 29（すべて `HARDENING_OVERRIDE`） | **81**（`HARDENING_OVERRIDE` **54** + `EH3_PATH_REJECTED` **27**） |

**さらに 81 セル × 4 モード（healthy / `notr` / `nosed` / `notr2`）= 324 セルで、base が block して rev6/rev7 が通すセルは 0 件**（§2.9 の不変条件の実測）。

**base の 29 件の内訳**: T0（9）+ T6（9）+ T7（9）= 27、+ C7 の T2 / T8（`*` が `/` を跨ぐ偶然）= **29**。`81 − 29 = 52`。
**rev6 の 27 件の `EH3_PATH_REJECTED`** = T1 / T2 / T8 × 9 カテゴリ。

対照 24 件のうち変わるのは **`docs/../docs/ai/hook-enforcement.md`（B-2）の 1 件のみ**。

### 5.2 `ta-65` TC-07（issue の 4 ケース）+ 追加

```
                                base(TASK)   rev7(TASK)
docs/../CLAUDE.md               rc=0 PASS    rc=2 EH3_PATH_REJECTED
CLAUDE.MD                       rc=0 PASS    rc=2 HARDENING_OVERRIDE
"CLAUDE.md "                    rc=0 PASS    rc=2 HARDENING_OVERRIDE
bin/../bin/plangate             rc=0 PASS    rc=2 EH3_PATH_REJECTED
CLAUDE.md/           (追加)      rc=0 PASS    rc=2 HARDENING_OVERRIDE
bin/plangate/.       (追加)      rc=0 PASS    rc=2 EH3_PATH_REJECTED
docs/ai/hook-enforcement.md     rc=0         rc=0            <- 非 HO は不変
docs/working/TASK-9999/plan.md  rc=0         rc=0            <- plan_hash 経路は不変
```

**→ `ta-65` TC-07 は fixed 期待へ反転が必要。期待値は marker の union で書くこと。**

### 5.3 変異注入

#### 測定環境の前提（**TC 側で作ること**）

- **サンドボックスの REPO_ROOT に大文字セグメントを含めること。** **root に関わる変異はすべて uppercase root を前提に初めて検出できます**（全小文字 root では `abs` / `absup` が block のままで検出力ゼロ）。**GitHub Actions の checkout パスは全小文字**。
- **絶対パス TC は「そのサンドボックス自身の ROOT」を使うこと。**
- **fault injection の shim が起動したことを確認すること**（カウンタファイル等）。
- ロケールを固定すること。

#### 故障注入 × 入力クラスの**直積が必須**（MJ-A / MJ-B が示したこと）

**rev6 までの TC は「故障注入入力（`notr` / `nosed` / `notr2abs` / `notr3`）」と「traversal 入力・doc-light 入力」の交差が 1 セルもありませんでした。** その結果 **MJ-A（`.//` × 故障）も MJ-B（doc-light × 故障）も検出できませんでした**。

→ **§5.3 の故障注入モードを、traversal 入力（`dotdbl` = `.//CLAUDE.md` / `dotmid`）と doc-light 入力（`docs/ai/x.md`）と直積で回すこと。**

#### rev7 で新規に加わった行に対する変異と kill 入力

| 変異 | 壊した箇所 | notr | nosed | notr2abs | notr3 | inject | auditro |
|---|---|---|---|---|---|---|---|
| （なし） | — | . | . | . | . | . | . |
| **M19** | **`_ho_key` の縮退を削除** | . | **X** | . | . | . | . |
| **M20** | **`_ho_root` の縮退を削除** | . | . | **X** | . | . | . |
| **M21** | **`_tf_lc` の `\|\|` + 縮退を削除** | . | . | . | **X** | . | . |
| **M22** | **HO case から元表記リテラルを削除** | **X** | **X** | **X** | . | . | . |
| **MJ1a** | **改行切り詰めを削除** | . | . | . | . | **X** | . |
| **MJ2** | **append の `\|\| true` を削除** | . | . | . | . | . | **X** |

**6 変異すべてが kill されます。**

#### rev7 で追加した行に対する変異（**直積 TC で kill**）

| 変異 | 壊した箇所 | `dotdbl`×`notr` | `dotdbl`×`nosed` | `docs/ai/x.md`×`notr3` | `tabinj` |
|---|---|---|---|---|---|
| （なし） | — | . | . | . | . |
| **MA** | **traversal の union を `_ho_key` 単独へ戻す** | **X** | **X** | . | . |
| **MB** | **`_esc_dl` の `\|\|` + 空チェックを削除** | . | . | **X** | . |
| **MN1** | **タブ切り詰めを削除** | . | . | . | **X** |
| MN2 | `[ -z "$_PG_CR" ] \|\|` ガードを削除 | . | . | . | . |

**MN2 は black-box TC では kill できません**（`_PG_CR=$(printf '\r')` は 5 シェルすべてで成功するため、ガードが働く条件に到達しない）。**M12 と同じく「防御的だが到達不能」な行**です。**削除してよいわけではありません** — 到達したときの挙動は実測済みで、**空セパレータは `case *""*` が全一致してメッセージ全体を消します**（§2.7 の注記）。 M19 が `notr`（`tr` 常時失敗）では kill されないのは、その場合 `_ho_root` 側の縮退が先に効くためで、**`nosed`（`sed` 常時失敗 / `tr` は成功）が唯一の kill 入力**です。

**既存 15 変異（M1 / M1b / M2〜M14 / MX1 / MX2b / MX3）は rev5 までに実証済み**で、kill 入力は `ws` / `wsL` / `case` / `casedir` / `dotdot` / `dbl` / `dotmid` / `abs` / `trail` / `plain` / `dotdbl` / `absup` / `parent` / `dotend` / `nonutf`。**M12（`sed` からだけ `LC_ALL=C` を外す）のみ等価または厳格側**で kill されません（構造論証: この `sed` は先頭・末尾 2 アンカーの trim のみ / 非 C ロケールの `[[:space:]]` は C の上位集合 / HO 対象パスの先頭・末尾バイトを space に分類するロケールは存在しない）。

#### TC 入力 21 件（`ta-65` 追加分）

```
ws wsL case casedir dotdot dbl dotmid abs(*) trail plain dotdbl absup(*) parent dotend
wsonly     '   '
nonutf     'CLAUDE.md'                    @ 非 UTF-8 ロケール
nonutfplan 'docs/working/TASK-X/plan.md'  @ 非 UTF-8 ロケール（plan.md guard）
notr       'CLAUDE.md'                    @ tr 常時失敗
nosed      'CLAUDE.md'                    @ sed 常時失敗
notr2abs   '<ROOT>/CLAUDE.md'  (*)        @ tr 2 回目以降失敗
notr3      'docs/working/TASK-X/plan.md'  @ tr 3 回目以降失敗（期待 = plan.md block）
inject     改行入り target                 @ ログが 1 行に収まること
auditro    'CLAUDE.md'                    @ _audit/ を書込不可にして rc=2 になること
                                          (*) ROOT は大文字セグメントを含むこと
```

### 5.4 可搬性 — **シェル可搬性であって OS 可搬性ではない**

`/bin/sh` / `bash` / `zsh` / `dash` / `ksh` の **5 シェルで同一判定・同一 rc**（`LC_ALL=C`）:

```
order:  plain UPPER dotdot dbl ws trail dotdbl 非HO /tmp | inject
sh      HO/2 HO/2  TR/2   TR/2 HO/2 HO/2 TR/2 DL/0 DL/0 | lines=1 forged=0
bash / zsh / dash / ksh  すべて同一
```

`${var%%"$_PG_NL"*}` の改行切り詰めも **5 シェルで同一**（注入 target でログ 1 行・偽レコード 0）。
**故障注入下の traversal も 5 シェルで同一**: `.//CLAUDE.md` × `notr` → **5 シェルすべて `EH3_PATH_REJECTED` / rc=2**（rev6 は 5 シェルすべて rc=127）。

**ただしこれは 1 OS（macOS / BSD sed・BSD tr）上の 5 シェルであり、OS 可搬性の主張ではありません。**

### 5.5 性能（5 回平均 / `LC_ALL=C`）

| 入力長 | base | rev6 | **rev7** |
|---:|---:|---:|---:|
| 9 | 40.3 ms | 51.4 ms | **48.5 ms** |
| 3,009 | 72.3 ms | 87.2 ms | **89.9 ms** |
| 20,010 | 130.8 ms | 147.7 ms | **146.8 ms** |
| 100,000 | 191.6 ms | 218.5 ms | **223.2 ms** |
| 200,000 | 222.7 ms | 279.6 ms | **282.0 ms** |

**rev7 = rev6 と同等（base 比 +8〜59ms、線形）。** traversal の union（ループ 2 回）とタブ切り詰めの追加コストは測定誤差の範囲。
**参考**: `case` ガードを入れる前の rev6 は 100,000 で 732ms / 200,000 で 2,367ms（§2.4）。**この退行は性能スイートの再実行だけで検出しており、機能 TC は 1 件も落ちませんでした。だから §2.4 の構造検査を §6 の step に入れます。**

### 5.6 sed 実装差（不正 UTF-8）

| 実装 | `LC_ALL=C` | `LC_ALL=en_US.UTF-8` |
|---|---|---|
| **BSD sed**（macOS） | rc=0 / バイト透過 | **rc=1 `RE error: illegal byte sequence`** |
| **GNU sed**（Linux CI 相当） | rc=0 / バイト透過 | rc=0 / バイト透過 |

**`LC_ALL=C` を固定すれば両実装が一致します。**

---

## 6. 適用手順（Human-owned）

1. §3 の **(A) (B) (C) (D) 4 hunk を 1 回の適用で束ねて** `scripts/hooks/check-plan-hash.sh` へ適用する。**分割しないこと**（分割は rev4→rev5 と同じ「既知の退行を抱えたまま出荷」になる）。
2. `ta-65` の **TC-07 を fixed 期待へ反転**する（**期待値は `HARDENING_OVERRIDE` と `EH3_PATH_REJECTED` の union**）。TC-06 は**変更不要**（実測で PASS 維持）。
3. **`ta-65` に §5.3 の TC 入力 21 件を追加する**（**追加するのは TC 入力だけ。変異体は repo にコミットしない**）。実装上の必須事項:
   - **`_T65_TMP` 配下に大文字セグメントを含む root を作り、そこへ hook を複製して実行する**。
   - **絶対パス TC はその複製自身の root を使う**。
   - **スタブ `tr` / `sed` は `_T65_TMP` 配下に置き、カウンタも `"$_T65_TMP/trcount"` に固定**する（`ta-65:76-81` の既存 `_T65_TMP` を使う。`mktemp -d` 配下なら並列衝突は構造的にゼロ）。**スタブは実体を絶対パスで呼ぶこと**（例: `exec /usr/bin/tr "$@"`。PATH 経由だと自分自身に無限再帰）。カウンタは**各実行前にリセット**。
   - **`auditro` TC は `_audit/` を 555 にする前にログファイルを削除**すること（既存ファイルが残っていると dir 権限に関係なく追記できてしまい、TC が空振りする）。
   - **`nonutf` / `nonutfplan` はロケール依存 TC なので、次のいずれかを選ぶ**（§6-A）。
   - **故障注入モードと入力クラスを直積で回すこと**（§5.3）。最低限 **`dotdbl`（`.//CLAUDE.md`）× {`notr`, `nosed`}**、**`docs/ai/x.md` × `notr3`（`skip-decision-log.jsonl` に記録が残ること）**、**`tabinj`（フィールド数 5）**、**`auditro`（rc=2）** を含めること。**この 4 種を落とすと MA / MB / MN1 / MJ2 が無検出のまま退行できます。**
4. **§2.4 の構造検査を `ta-65` に 1 本追加し、ここでも実行する**（未ガードのパラメータ展開の検出 / **wall-clock より決定論的**）。**hits が 0 でなければ適用しない。**

   ```sh
   grep -nE '\$\{[A-Za-z_][A-Za-z_0-9]*(%%?|##?)' scripts/hooks/check-plan-hash.sh \
     | grep -vE '^[0-9]+:[[:space:]]*[^|()]*\)[[:space:]]' \
     | grep -vE 'dirname|:-|:='
   ```

5. §4.2 の再測定手順で `..` を含む監査記録を確認する（**件数を契約値にしない**）。
6. `sh tests/run-tests.sh` を **macOS と `ubuntu-latest` の両方**で rc=0 にする。baseline は適用時点の main で再測定。
7. **`scripts/apply-eh3-ho-always.sh` の 9 カテゴリ第 2 コピー（`:135-143` / `:174-183`）を同期するか retire するか決める**（retire が最小コスト）。
8. **`.claude/rules/mode-classification.md` の Hardening Override 節に 1 行足す**（正本↔実装の drift を文字列一致で検出する手段を維持するため）:

   > 実装（`scripts/hooks/check-plan-hash.sh` の `_override=0` 直後の `case`）は、
   > 表記揺れ迂回を防ぐため**小文字化したキー `_ho_key`** で照合し、正規化が
   > 失敗したときは元表記へ縮退する。よって `case` は小文字リテラルと元表記の
   > 両方を持つ（#1101）。本表のパス名は正本表記である。

9. `docs/ai/hook-enforcement.md` の「既知の残存」から本項目を削除する。ただし **#1104 は未解決**なので **「`Edit|Write` 経路では常時 block / `Bash` 経路は #1104 で追跡中」と matcher 別に書く**こと。

### 6-A. ロケール TC の扱い（**空振り fixture を作らないこと**）

`nonutf` は **M13 を kill する唯一の入力**、`nonutfplan` は **`_tf_lc` の `LC_ALL=C` を外す変異を kill する唯一の入力**です。ところが **`ubuntu-latest` には通常 `C` / `C.UTF-8` / `en_US.utf8` しか生成されておらず**、「無ければスキップ」にすると **CI では検出力ゼロの空振り fixture** になります。次のどちらかを選んでください:

| 案 | 内容 | 評価 |
|---|---|---|
| **A-1（推奨）: ロケール非依存の等価に置き換える** | **PATH 先頭に「ASCII を壊す `tr`」スタブ**を置く（例: `exec /usr/bin/tr 'A-Z' 'q-z' ` 相当で写像を狂わせる、あるいは入力をそのまま返す）。`LC_ALL=C` が**効いていること**を「壊れた写像でも判定が変わらない」ではなく「**内側固定を外した変異が kill される**」形で確認できる | OS 非依存・CI で確実に走る。既に `notr` 系スタブの仕組みがあるので追加コストが小さい |
| **A-2: CI で locale 生成を必須化** | workflow に `sudo locale-gen en_US.ISO-8859-1` 等を追加し、**生成失敗を CI エラーにする** | 実ロケールで測れるが、CI イメージ変更に弱く、名称差（`ISO8859-1` / `ISO-8859-1`）の分岐が要る |

**どちらを採るにせよ「無ければ skip」だけは選ばないこと**（本 patch が是正した false green と同じ構造になる）。

---

## 7. 残存リスク（本 patch で閉じないもの）

| # | 残存 | 理由 / 追跡 |
|---|---|---|
| **R-1** | **`Bash` 経路には HO 判定自体が存在しない** | HO を持つ hook は `check-plan-hash.sh` 1 本のみで `Edit\|Write` matcher にしか配線されていない。**#1104** |
| **R-2** | symlink 経由の到達 | 字句のみで判定し FS に触れない（意図的） |
| **R-3** | バックスラッシュ（`a\b/CLAUDE.md`） | macOS / Linux では別ファイルであり FS 到達不能。**スコープ外** |
| **R-4** | Unicode の大小文字 | `tr 'A-Z' 'a-z'` は ASCII のみ。本 patch で悪化しない |
| **R-5** | `#1135` patch との適用順 | 本 patch を先に入れれば `#1135` 側の「差分 0」は冗長。**Human 判断** |
| **R-6** | **`REPO_ROOT` 由来の root 解決全般で HO が発火しない**（現 main も同様） | HO 9 カテゴリは **repo root 起点の完全一致**で、`REPO_ROOT` は `$(dirname "$0")/../..` から求まる。したがって **(a) worktree 越しの `.claude/worktrees/<id>/…`（本リポジトリは常用）**、**(b) 別 clone の絶対パス**、**(c) run-from-plugin（#1144）で hook を plugin cache から実行した場合の利用者リポジトリのパス** がいずれも root-strip されず HO にならない。**(c) は #1144 の設計書が「利用者リポジトリの `scripts/hooks/` 前提が崩れる」と明記している論点と同根**であり、**`CLAUDE_PROJECT_DIR` 等への切り替えを #1144 側の前提条件**として引き継ぐこと。**別 issue 化を推奨** |
| **R-7** | **`\|\|` を持たないコマンド置換代入が残る（全数 8 箇所）** | rev7 適用後に `\|\|` を持たない代入は **`_esc_c3` / `_dl_ext` / `_ts_dl` / `_esc_dl` / `_skipr` / `_ts` / `_esc_r` / `_esc_f` の 8 箇所**（うち `_esc_c3` / `_esc_dl` は rev7 で是正済 → 実質 6 箇所）。**いずれも HO 判定より下流**なので承認境界を弱めないが、**部分故障で rc=1 になり `skip-decision-log.jsonl` の記録が落ちる**。**`.codex/hooks/eh-bridge.sh` は rc=1 を `deny` に写像するため Codex 側では block**（ハーネス非対称 / R-11）。**index shift のたびに「何番目の `tr`/`sed` が落ちるか」が変わるため、下流を触る変更では毎回この一覧を数え直すこと**（§2.13 が §2.8 と同一クラスの 3 度目だった理由） |
| **R-8** | **Linux / GNU coreutils での全 TC 実行が未実施** | 本書の測定は macOS 1 OS。**CI での初回実行が実質的な OS 検証**（§6 step 5） |
| **R-9** | **Unicode 空白（U+00A0 / U+3000）は trim されない** | `LC_ALL=C` の帰結。base・rev7 とも非 HO で**退行ではない**が非対称が残る |
| **R-11** | **rc の解釈がハーネス間で非対称** | Claude Code の PreToolUse は **exit 2 のみ block**（0/1/127 は通す）。`.codex/hooks/eh-bridge.sh` は **`2\|1) deny` / 未知 rc は `allow`**。**同じ rc=1 が Claude では通り Codex では止まる。** 本 patch は block を rc=2 に揃えるので非対称は解消するが、**将来「rc=1 なら安全側」と仮定してはいけない** |
| **R-12** | ~~監査ログへのタブ注入~~ → **rev7 で閉じた**（§2.10）。**残るのは「切り詰めにより target の一部が監査から失われる」こと** | 改行 / CR / タブのいずれかを含む target は **最初の 1 個までしか記録されない**。`[truncated]` マーカーで欠落は自明になるが、**原文の全体は残らない**。原文が必要なら stderr 側（block メッセージ）を併せて収集すること |
| **R-13** | **`_PG_CR` / `_PG_TAB` が取得できない環境の挙動は理論値** | `printf '\r'` は 5 シェルすべてで builtin として成功するため、**フォールバック（別表記での再取得 / `case` 自体のスキップ）は black-box TC で到達できない**（変異 MN2 が kill されない理由）。**空セパレータがメッセージ全体を消すことは単体で実測済み**（§2.7 注記） |

---

## 8. 検証の再現手順とサンドボックス境界

すべて `origin/main` = `6def020` のサンドボックス複製で実施。**リポジトリ本体の `scripts/hooks/check-plan-hash.sh` は編集も実行もしていません。**

> **本書の執筆自体（`Write` ツール）は本体 hook を PreToolUse として発火させ、`skip-decision-log.jsonl` に `EH-3_DOC_LIGHT_SKIP` を追記します。** 測定ではなく執筆の副作用ですが §4.2 の絶対件数を劣化させるため、同節は件数ではなく条件式で判定します。

```sh
# 1) 大文字セグメントを含む root にサンドボックスを作る
R=/private/tmp/pg1101/UPPER_Root
for v in base pat; do
  mkdir -p "$R/$v/scripts/hooks" "$R/$v/docs/working/_audit"
  cp scripts/hooks/check-plan-hash.sh "$R/$v/scripts/hooks/"
done
# 2) $R/pat 側へ §3 の 3 hunk を適用する
# 3) env を unset し、ロケールを明示し、rc ではなく marker で判定する
env -u PLANGATE_HOOK_TASK -u PLANGATE_SKIP_REASON -u PLANGATE_HOOK_FILE \
    -u PLANGATE_HOOK_STRICT -u PLANGATE_BYPASS_HOOK LC_ALL=C LANG=C \
    sh "$R/pat/scripts/hooks/check-plan-hash.sh" "" "$R/pat/CLAUDE.md" </dev/null
# 4) tr / sed 故障の fault injection
S=$R/shim; C=$R/trcount; mkdir -p "$S"
cat > "$S/tr" <<'SH'
#!/bin/sh
n=$(cat "$PG_TR_COUNTER" 2>/dev/null || echo 0); n=$((n+1))
printf %s "$n" > "$PG_TR_COUNTER"
[ "$n" -ge 2 ] && exit 127          # notr2: 2 回目以降失敗（notr3 なら -ge 3）
exec /usr/bin/tr "$@"               # 実体は絶対パスで呼ぶ（PATH 経由だと無限再帰）
SH
chmod +x "$S/tr"; rm -f "$C"
env ... PATH="$S:$PATH" PG_TR_COUNTER="$C" sh "$R/pat/scripts/hooks/check-plan-hash.sh" "" "$R/pat/CLAUDE.md" </dev/null
# 5) 監査ログ書込不可（先にログファイルを消してから chmod する）
rm -f "$R/pat/docs/working/_audit/hook-events.log"; chmod 555 "$R/pat/docs/working/_audit"
env ... sh "$R/pat/scripts/hooks/check-plan-hash.sh" "" "CLAUDE.md" </dev/null; chmod 755 "$R/pat/docs/working/_audit"
# 6) 改行注入
T=$(printf 'docs/../x.md\n2026-01-01T00:00:00Z\tBYPASS\tcheck-plan-hash\t-\tFORGED')
rm -f "$R/pat/docs/working/_audit/hook-events.log"
env ... sh "$R/pat/scripts/hooks/check-plan-hash.sh" "" "$T" </dev/null
wc -l "$R/pat/docs/working/_audit/hook-events.log"   # 1 行であること
```

`REPO_ROOT` は `$(dirname "$0")/../..` で解決されるため、サンドボックス側の hook はサンドボックスを root と見なします。

**壊れた環境からの脱出口**: `PLANGATE_BYPASS_HOOK=1` は HO 判定より前に評価されるため、**`tr` が壊れた環境でも rc=0 で通ります**（実測）。縮退方式（§2.9）を採ったので停止自体が起きませんが、**唯一のインバンド脱出口として記録**します。

**故障注入 TC を書くときの落とし穴（本作業中に踏んだもの）**:

- **shim ディレクトリ名を取り違えると、shim 無しの測定を shim ありと誤認します。** カウンタファイルが生成されないことで検出できます。**「注入が効いたこと」を毎回確認してください。**
- **`auditro` TC は `_audit/` を 555 にする前にログファイルを削除**すること。既存ファイルが残っていると **dir 権限に関係なく追記できてしまい TC が空振り**します。
- **絶対パス TC は「その複製自身の ROOT」を使う**こと。

## 9. 関連

- **#1101**（本 issue）/ **#1089**（PR #1097 で是正済）/ **#1104**（`Bash` 経路に HO 判定が無い）/ **#1135**（AI-owned レーン）/ **#1144**（hook 配布。本 patch を前提とし、R-6(c) を引き継ぐ）/ **#1079**（EH-13 fail-closed 化。§2.9 の同型事例）
- [`1135-ai-owned-lane-patch.md`](./1135-ai-owned-lane-patch.md) §差分 0
- `tests/extras/ta-65-eh3-ho-task-context.sh` TC-06 / TC-07 / `_T65_TMP`（`:76-81`）/ `:327,347`（TC-06 の assert）
- `scripts/ai-loop/arbiter.py::_normalize_path`（fail-closed の前例）
- `.codex/hooks/eh-bridge.sh:87-88`（未知 rc を `allow`、`2|1` を `deny` へ写像。§2.7 / R-11）
- `scripts/apply-eh3-ho-always.sh:135-143` / `:174-183`（9 カテゴリの第 2 コピー。§6 step 6）
- `.claude/rules/mode-classification.md`（HO 9 カテゴリの正本。§6 step 7）
- `8b604fe:tests/fixtures/pg-fold-path.sh`（却下した O(n²) 実装。数値は commit message からの引用で未再現）
