# Step 5 — 変異注入による検出力の実証（T-14 / AC-5）

> 実施: 2026-08-15（exec） / branch `feat/1101-ho-normalization` / base `73ac1db`
> OS: Darwin 25.6.0 (macOS 26.6.1 / arm64) / `/bin/sh` = bash 3.2 系
> 変異ドライバ: `mutate.py`（scratchpad・9 変異の exact-string 置換）
> 変異対象: **`_pg_fold_path` 関数内の各正規化ステップを 1 つずつ**（**call site は壊さない** — 壊すと全変異が同じ FAIL に潰れて検出力を実証できない）

## 実行環境

`scripts/hooks/check-plan-hash.sh` は Hardening Override 対象パスで AI は編集できない。
そこで **使い捨てのローカル clone**（`/tmp/pg1101-mut-repo`、`git clone --local` で
`73ac1db` を取得）に、

1. 本 PBI で変更した `tests/extras/ta-65-*.sh` / `tests/fixtures/pg-fold-path.sh` /
   `scripts/apply-1101-ho-normalization.sh` を複製
2. `sh scripts/apply-1101-ho-normalization.sh --emit`（**書き込みなし**）で得た
   patch 済み hook を clone 側の `scripts/hooks/check-plan-hash.sh` として配置
3. その内容に 1 変異ずつ注入

という手順で実施した。**本リポジトリの `scripts/hooks/check-plan-hash.sh` は一切変更していない。**

## control（変異なし）

| 対象 | rc | 結果 |
|---|---|---|
| `tests/extras/ta-65-eh3-ho-task-context.sh` | **0** | 16 passed, 0 failed |
| `tests/extras/ta-45-c3-mode-config.sh` | **0** | 6 passed, 0 failed |

## 変異と kill 結果（実測）

| # | 変異 | 壊した正規化ステップ | ta-65 rc | **FAIL した TC（実測）** |
|---|---|---|---|---|
| M1 | `M1-trailing-space` | (1) 末尾空白の除去 | **1** | TC-07 (1/9), **TC-08 (15/165)**, TC-12 |
| M2 | `M2-leading-dot-slash` | (2) 先頭 `./` の畳み込みのみ | **1** | TC-07 (3/9), **TC-08 (64/165)**, TC-12 |
| M3 | `M3-mid-dot-segment` | (2) 中間 `/./` の畳み込みのみ | **1** | TC-07 (1/9), **TC-08 (27/165)**, TC-12 |
| M4 | `M4-double-slash` | (2) 連続スラッシュ `//` の畳み込み | **1** | TC-07 (1/9), **TC-08 (12/165)**, TC-12 |
| M5 | `M5-dotdot-fold` | (2) `..` の字句的畳み込み | **1** | TC-07 (3/9), **TC-08 (30/165)**, TC-09 (1), TC-11 (3), TC-12 |
| M6 | `M6-repo-root` | (4) repo root の除去 | **1** | **TC-08 (15/165)**, TC-12 |
| M7 | `M7-lowercase` | (5) 小文字化 | **1** | TC-01b (2/14), TC-02, TC-07 (5/9), **TC-08 (30/165)**, TC-12 |
| **M8** | `M8-norm-target-overwritten`（**第 8 変異 / v1 設計の注入**） | `_norm_target` 自体を正規化値で上書き | **1** | **TC-10 (3 件)** |
| M9 | `M9-v3-order`（**RiverReview critical の回帰検出**） | v3 の順序（先頭 `./` 除去 → 畳み込み） | **1** | TC-07 (2/9), **TC-08 (32/165)**, TC-12 |

**9 変異すべてが kill された**（ta-65 rc=1）。ログ: `/tmp/pg1101-mut-logs/<MID>.log`

> ⚠️ **上表は AC-1 是正（PR 前レビュー）前の測定値**（直積 165 件時点）。
> 是正後（直積 **195** 件）の再測定と **M10 の追加**は下記「再測定」節を参照。

### 注記 1: TC-12（正本との byte 一致）が M1〜M7・M9 で共通 FAIL する

TC-12 は「`tests/fixtures/pg-fold-path.sh`（正本）と hook 内 inline ブロックの
byte 一致」を検査する。M1〜M7・M9 は hook 側だけを書き換えるので必ず FAIL する。
**これは drift 検出が効いている証拠**だが、変異ごとの識別力は持たない。
**変異の識別は TC-07 / TC-08 / TC-09 / TC-10 / TC-11 の内訳で行う**（上表の件数）。

### 注記 2: M8 は「fold ブロックを書き換えない」ので TC-12 を FAIL させない

M8 は call site 側（`_ho_key=$_PG_FOLD_OUT` の直後に `_norm_target=$_PG_FOLD_OUT`
を追加）の変異であり、fold ブロックは無傷。よって **TC-10 のみが FAIL** する。
これは狙いどおりで、**AC-2 の回帰網が空振り fixture ではない**ことの実証になっている。

## ⚠️ plan / test-cases の記述と実測が食い違った点（**未達ではなく事実訂正**）

**plan Step 5 / test-cases TC-08 は「第 8 変異で TC-02/03/04 と `ta-45` が FAIL する」と
記載しているが、`ta-45` は FAIL しなかった（rc=0 / 6 passed）。**

原因（一次実測）: `ta-45` の TC-01 は **`PLANGATE_HOOK_TASK` を設定した TASK 文脈**で
EH-3 を起動している（`tests/extras/ta-45-c3-mode-config.sh` の
`_t45_eh3_out=$(PLANGATE_HOOK_TASK="$_T45_TASK" ... )`）。C-3 conversation 分岐は
**no-task 経路の内側**にあるため、`ta-45` はその分岐に到達しない。さらに判定は
`grep -qiE 'SKIP|PASS'` と緩く、`_norm_target` を小文字化しても
「`c3.json not found` → SKIP」で通ってしまう。

→ **`ta-45` は AC-2 の回帰網としては機能しない**（plan の想定が誤り）。
実際に M8 を kill したのは **本 PBI で新設した `ta-65` TC-10**（no-task 文脈で
maintenance `allowed_paths` / doc-light / c3 conversation の 3 経路を直接叩く）。
AC-2 の担保は TC-10 に置く。`ta-45` は回帰確認の対象としては維持するが、
**「`ta-45` が PASS することが AC-2 の実質的な担保」という todo T-17 の🚩は成立しない**。

## 未適用 hook に対する検出力（plan Step 4 🚩）

`tests/fixtures/eh3-normalization-pending-1101.flag` が存在する状態（= real hook 未適用）
では ta-65 TC-07 が PENDING-APPLY として受理する。**flag を外すと TC-07 は FAIL する**
（= 未適用を検出できる）。実測は `evidence/test-runs/step4-detection.md` を参照。

---

## 再測定（AC-1 是正後 / 直積 195 件 / **M10 を追加**）

> 実施: 2026-08-15（PR 前レビュー指摘の是正後） / 同一環境・同一手順
> control（変異なし）: `ta-65` rc=0 / **16 passed, 0 failed**

| # | 変異 | 壊した正規化ステップ | ta-65 rc | **FAIL した TC（実測）** |
|---|---|---|---|---|
| M1 | `M1-trailing-space` | (1) 末尾空白の除去 | **1** | TC-07 (1/9), **TC-08 (15/195)**, TC-12 |
| M2 | `M2-leading-dot-slash` | (2) 先頭 `./` の畳み込みのみ | **1** | TC-07 (3/9), **TC-08 (64/195)**, TC-12 |
| M3 | `M3-mid-dot-segment` | (2) 中間 `/./` の畳み込みのみ | **1** | TC-07 (1/9), **TC-08 (27/195)**, TC-12 |
| M4 | `M4-double-slash` | (2) `//` の畳み込み | **1** | TC-07 (1/9), **TC-08 (12/195)**, TC-12 |
| M5 | `M5-dotdot-fold` | (2) `..` の字句的畳み込み | **1** | TC-07 (3/9), **TC-08 (30/195)**, TC-09 (1), TC-11 (3), TC-12 |
| M6 | `M6-repo-root` | (5) repo root の除去 | **1** | **TC-08 (45/195)**, TC-12 |
| M7 | `M7-lowercase` | (4) 小文字化（root 側も含む） | **1** | TC-01b (2/14), TC-02, TC-07 (5/9), **TC-08 (60/195)**, TC-12 |
| **M8** | `M8-norm-target-overwritten`（第 8 変異 / v1 設計の注入） | `_norm_target` を正規化値で上書き | **1** | **TC-10 (3 件)** |
| M9 | `M9-v3-order`（RiverReview critical の回帰検出） | v3 の順序 | **1** | TC-07 (2/9), **TC-08 (32/195)**, TC-12 |
| **M10** | `M10-root-case-sensitive`（**PR 前レビュー由来 / 新規**） | (4) で **root 側に写像を当てない** = root 比較が大小文字厳密に戻る | **1** | **TC-08 (45/195、うち 30 件が今回追加した root 大文字 2 形)**, TC-12 |

**10 変異すべてが kill された。**

### M7 のアンカー更新について

是正で小文字化ブロックに root 側の写像が加わったため、M7 の置換アンカーが
一致しなくなり 1 回目の再測定で `anchor count=0 (expected 1)` となった
（**変異が当たっていないのに緑に見える状態**）。アンカーを新ブロックへ更新して
再実行し、上表の結果を得た。**「MUTATE FAILED を kill と数えない」**ことを明記しておく。

### M6 と M10 の違い

- **M6** は root 除去そのものを削除 → root 形 3 種（正しい大小文字 / root 大文字 /
  root+パターン大文字）計 45 件が漏れる
- **M10** は root 側の写像だけを外す → 是正後は `_pf_final` が先に小文字化されるため、
  mktemp パスに含まれる大文字（`/T/tmp.Ck2M2oTIZ5`）で **root 形 3 種すべてが不一致**になり
  同じく 45 件。**うち 30 件が今回追加した root 大文字 2 形**であることを
  `grep -c 'product miss: \[/VAR/FOLDERS'` = 30 で確認した
