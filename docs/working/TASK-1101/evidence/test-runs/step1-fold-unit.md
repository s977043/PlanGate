# Step 1 — `_pg_fold_path()` 単体評価（T-03 の🚩 / 本体組み込み前）

> 実施: 2026-08-15（exec） / branch `feat/1101-ho-normalization` / base `73ac1db`
> OS: Darwin 25.6.0 (macOS 26.6.1 / arm64)
> 対象: `tests/fixtures/pg-fold-path.sh`（正規化関数の**正本ソース**）
> 方法: 4 シェルで**関数を直接評価**（`ta-65` 経由にしない — hook は常に `sh` で起動されるため false green になる / R-003）

## シェル実体

| shell | path |
|---|---|
| `sh` | `/bin/sh`（bash 3.2 系） |
| `dash` | `/bin/dash` |
| `bash` | `/bin/bash` |
| `zsh` | `/bin/zsh` |

## 実行

```sh
for s in sh dash bash zsh; do
  $s fold-drive.sh tests/fixtures/pg-fold-path.sh "$REPO_ROOT" > out-$s.txt
done
diff out-sh.txt out-dash.txt   # 差分なし
diff out-sh.txt out-bash.txt   # 差分なし
diff out-sh.txt out-zsh.txt    # 差分なし
```

**4 シェルすべて rc=0・出力は byte 一致**（`diff` 3 本とも差分ゼロ）。
`LANG=ja_JP.UTF-8 LC_ALL=ja_JP.UTF-8` を付けた再実行も **4 シェルとも locale 非依存**
（各シェルで C locale 実行と byte 一致）。

> R-002 の再発（zsh で単語分割に依存した実装が no-op になる）を、
> **本体へ組み込む前に**塞いだことの実測。

## 入出力表（`$3=1`＝小文字化あり。`sh` の出力、他 3 シェルも同一）

| 入力 | 出力 | rc | 変換クラス |
|---|---|---|---|
| `docs/../CLAUDE.md` | `claude.md` | 0 | `..` |
| `bin/../bin/plangate` | `bin/plangate` | 0 | `..` |
| `a/b/../../c` | `c` | 0 | `..` 多段 |
| `bin//plangate` | `bin/plangate` | 0 | `//` |
| **`.//CLAUDE.md`** | **`claude.md`** | 0 | **`//` + `./`（RiverReview critical）** |
| `bin/./plangate` | `bin/plangate` | 0 | `/./` |
| **`Bin/PlanGate`** | **`bin/plangate`** | 0 | **大小文字** |
| **`"CLAUDE.MD "`** | **`claude.md`** | 0 | **大小文字 + 末尾空白** |
| **`$REPO_ROOT/./BIN/plangate`** | **`bin/plangate`** | 0 | **repo root 跨ぎ + 大小文字** |
| `./CLAUDE.md` | `claude.md` | 0 | `./` 前置 |
| `./bin/../bin/plangate` | `bin/plangate` | 0 | 2 種複合 |
| `.//BIN/plangate` | `bin/plangate` | 0 | 3 種複合 |
| `$REPO_ROOT/../<repo>/CLAUDE.md` | `claude.md` | 0 | repo root 跨ぎ |
| `docs/x/../AGENTS.md` | `docs/agents.md` | 0 | 非 HO のまま（正しい） |
| `x/../AGENTS.md` | `agents.md` | 0 | HO へ変化（仕様どおり） |
| `.claude//skills/x/SKILL.md` | `.claude/skills/x/skill.md` | 0 | 非 HO のまま |
| `/private/tmp/x/note.md` | `/private/tmp/x/note.md` | 0 | **絶対パスは不変**（skip 側 / TC-11b） |
| `/CLAUDE.md` | `/claude.md` | 0 | FS root は不変 → 非 HO |
| `CLAUDE.md/` | `claude.md/` | 0 | 末尾 `/` を保持 → 非 HO（ENOTDIR で到達不能） |
| `" CLAUDE.md"` | `" claude.md"` | 0 | 先頭空白は残す → 非 HO |
| `bin\plangate` | `bin\plangate` | 0 | Windows 風は不変 → 非 HO |
| `""` | `""` | 0 | 空文字列 → 非 HO |
| `/` | `/` | 0 | FS root → 非 HO |
| **`..`** | `..` | **1** | **fail-closed（先頭 `..`）** |
| **`../plangate/CLAUDE.md`** | `../plangate/CLAUDE.md` | **1** | **fail-closed** |
| **`../../CLAUDE.md`** | `../../CLAUDE.md` | **1** | **fail-closed（多段）** |
| **`a/b/../../../CLAUDE.md`** | `../CLAUDE.md` | **1** | **fail-closed（畳み込み"後"に先頭 `..` へ転じる）** |
| **`x/`×257 + `CLAUDE.md`** | （入力そのまま） | **1** | **fail-closed（セグメント上限 256 超過）** |
| `ドキュメント/CLAUDE.md` | `ドキュメント/claude.md` | 0 | マルチバイトは素通し（locale 非依存 / plan Q3） |
| `Ａ/CLAUDE.MD`（全角 A） | `Ａ/claude.md` | 0 | 全角は写像対象外＝素通し |

## 設計上の確定事項（実装時に決めた細部）

1. **末尾 `/` を保持する**。`CLAUDE.md/` を `CLAUDE.md` に畳むと
   test-cases のエッジケース表（「`CLAUDE.md/` は skip」）と矛盾する偽陽性になる。
2. **絶対パスの `..` は root で clamp し、fail-closed にしない**。
   `/a/../../x` のような入力は cwd に依存せず repo 内 HO に到達しないため、
   fail-closed 条件 (a)「畳み込み後に先頭 `..` が残る」は**相対パスにのみ適用**する。
   これにより TC-11b（絶対パスを block しない）と両立する。
3. **小文字化は `A`〜`Z` のみを 1 文字ずつ `case` で写像**し、マルチバイトは素通し。
   `${v,,}` は `sh`(bash 3.2)/`dash` で `bad substitution`、`tr`/`sed` は fork 増になるため使わない。
   さらに **大文字を含まない入力は写像ループ自体を回さない**（`case *[A-Z]*`）。

## ⚠️ 是正（PR 前レビュー / AC-1 未達）— (4) と (5) の順序入れ替え

上表は**是正前**の測定値。PR 前レビューで
**「repo root 除去が大小文字を区別するため、root 前置部だけ大文字にした絶対パスで
HO を素通りできる」**欠陥が確定し、**(4) repo root 除去 → (5) 小文字化**を
**(4) 小文字化（`_pf_final` と `_pf_root` の両方）→ (5) repo root 除去**へ入れ替えた。

詳細と実測: [`prereview-ac1-root-case.md`](./prereview-ac1-root-case.md)

### 是正後の 4 シェル直接評価（**root 大文字入力を追加**）

`sh` / `dash` / `bash` / `zsh` すべて rc=0・`diff` 3 本とも差分ゼロ・
`LANG=ja_JP.UTF-8` でも byte 一致（**是正前と同じ可搬性を維持**）。

| 入力 | 出力 | rc |
|---|---|---|
| `$REPO_ROOT_UPPER/CLAUDE.md` | `claude.md` | 0 |
| `$REPO_ROOT_UPPER/CLAUDE.MD` | `claude.md` | 0 |
| `$REPO_ROOT_UPPER/./bin/plangate` | `bin/plangate` | 0 |
| `$REPO_ROOT_UPPER/BIN/PLANGATE` | `bin/plangate` | 0 |
| `$REPO_ROOT_UPPER//CLAUDE.md` | `claude.md` | 0 |
| `$REPO_ROOT_UPPER/x/../CLAUDE.md` | `claude.md` | 0 |
| **`$REPO_ROOT_UPPER/CLAUDE.md`（`$3=0`＝小文字化なし）** | **入力そのまま**（root を剥がさない） | 0 |
| `/PRIVATE/TMP/x/NOTE.md` | `/private/tmp/x/note.md`（**絶対のまま**＝非 HO） | 0 |

> `$3=0` で root 比較が従来どおり大小文字厳密であることが、
> **`_norm_target` 側の意味論を変えていない**ことの裏付けになる。
