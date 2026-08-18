# C-1 再実行（簡易・第 2 回）— TASK-1087 (#1087)

> 実施日: 2026-08-18 / 契機: PR #1149 の CI FAIL（`plangate CLI tests` / run `32101748327`）
> 初回 `review-self.md` / 第 1 回 `review-self-2.md` は**書き換えず保持**。本ファイルは差分レビュー。

## 総合判定: **PASS**（WARN 2 / FAIL 0）

ただし **FAIL-1 を新規に記録**する。#1087 が塞ごうとしている
「検査が緑を出すが実際には何も測っていない」状態を、**本 PBI の TC 自身が持っていた**。

---

## 根本原因（実測で特定）

### 症状

CI で 7 件 FAIL。**rc=1 を期待する TC が全滅、rc=0 を期待する TC は全通過。**
ローカル standalone は 19 passed / 0 failed。

### 決め手になった観測

CI ログに **ta-61 が ta-69 を standalone 実行して PASS させている**行があった:

```
[PASS] TC-12(a)/TC-13: ta-69-distribution-checks clean standalone run rc=0 with no [FAIL]
```

→ **OS 差ではなく「standalone か harness か」の差**だと確定。
`run-tests.sh` は `set -eu` で extras を **source** する。

### 機構（最小再現で確定）

`ta-69` は rc を次のイディオムで捕捉していた:

```sh
( cd "$D" && python3 x.py >/dev/null 2>&1; echo $? )
```

`set -e` 下では **`cd && python3` は AND-list の最終コマンドなので免除されない**。
`python3` が rc=1 を返すと AND-list が失敗 → `set -e` が
**`echo $?` に到達する前にサブシェルを終了** → 捕捉値が **空文字**になる。

最小再現（`scratchpad/mech.sh`）:

```
set -e = off
  rc=1 のコマンド -> 捕捉値 [1]
  rc=0 のコマンド -> 捕捉値 [0]
set -e = on
  （1 行目でスクリプトごと異常終了。捕捉値は出力されない）
```

したがって:

| 期待 | 比較 | 結果 |
|------|------|------|
| rc=1 | `[ "" = "1" ]` | **偽 → 全 FAIL** |
| rc=0 | `[ "0" = "0" ]` | 真 → 全 PASS（**空のサンドボックスでも通る**） |

さらに **素の代入**で使った箇所（TC-S9）では `set -e` が
**ハーネス全体を中断**していた。CI ログが TC-S8 の直後で止まり
TC-S9 / TC-S1 / TC-R1 が実行されていないのはこのため。

### ローカルで再現できた

`scratchpad/harness_sim.sh`（`set -eu` + `pass`/`fail` + `PG_HARNESS_SOURCED=1` で
**ta-69 のみ** source。フルスイートは走らせない）で **CI と同じ 7 FAIL を再現**した。

---

## 是正内容

**目的は「CI を緑にすること」ではなく「真の違反を注入したら、どの環境でも rc=1 になること」。**

| # | 是正 | 内容 |
|---|------|------|
| 1 | **rc 捕捉を `set -e` 安全化** | `_t69_rc_of` を新設し `( ... ) \|\| rc=$?`（OR-list = set -e 免除）に統一。stdout 捕捉も `_t69_out_of` に集約 |
| 2 | **注入の前提条件を明示検証** | `_t69_assert_defs` / `_t69_assert_probe`。注入が成立していなければ **その TC を実行せず明示 FAIL** |
| 3 | **git sandbox の成立を検証** | `TC-G3`。`git init` / `.gitignore` の失敗を握り潰さない（TC-S7/S8 の前提が崩れたまま緑にしない） |
| 4 | **ガード自体の検出力を TC 化** | `TC-G1`（空サンドボックスを 0 と数える）/ `TC-G2`（注入失敗時にガードが発火する） |
| 5 | **ta-52 にも同じガード** | 実測で同じ性質を確認したため（下記 FAIL-1） |

---

## 環境非依存であることの実証

| 対象 | standalone | harness（`set -eu` + source） |
|------|-----------|------------------------------|
| `ta-69` | **22 passed / 0 failed** | **22 passed / 0 failed** |
| `ta-52` | **6 passed / 0 failed** | **6 passed / 0 failed** |

是正前は harness で ta-69 が **7 FAIL + 途中中断**だった。**両モードで一致**するようになった。

---

## sandbox 構築失敗が [FAIL] として現れることの実証

`_t69_skill`（注入本体）の **call site を no-op に壊す変異**を適用して実走:

```
[PASS] TC-G2: a failed injection surfaces as an explicit [FAIL], not a silent rc=0
[FAIL] TC-C9: sandbox injection failed (SKILL.md want=1 got=0)
[FAIL] TC-C3: sandbox injection failed (SKILL.md want=2 got=0)
[FAIL] TC-C2: expected mirrors to be printed as INFO
[FAIL] TC-C8: sandbox injection failed (SKILL.md want=2 got=0)
[FAIL] TC-C4: sandbox injection failed (SKILL.md want=3 got=0)
[FAIL] TC-C5: sandbox injection failed (SKILL.md want=2 got=0)
[FAIL] TC-C6: sandbox injection failed (SKILL.md want=2 got=0)
[FAIL] TC-C7: sandbox injection failed (SKILL.md want=2 got=0)
HARNESS-SIM RESULT: pass=14 fail=8
```

### 是正前との対比（同じ変異・同じ壊れ方）

**是正前の ta-69** に同じ変異を当てると:

```
[PASS] TC-C9: single definition -> rc=0
[PASS] TC-C3: repo-local <-> plugin mirror -> rc=0 (accepted)
[PASS] TC-C8: mirror with description drift -> rc=0
TA-69 standalone: 14 passed, 5 failed
```

**サンドボックスに 1 ファイルも無いのに 3 TC が緑だった。**
是正後はこれらが「injection failed」で落ちる。

---

## 他 TC への同種性質の確認（コーディネータ指摘 4）

| ファイル | `set -e` 安全性 | 空サンドボックスでの silent green |
|---------|---------------|-------------------------------|
| `ta-69` | ❌ → ✅ 是正 | ❌ → ✅ 是正 |
| `ta-52` | ✅ 元から安全（`_t52_out=$(_t52_run) \|\| true`） | ❌ **あった** → ✅ 是正 |

**ta-52 の実測**: repo-local skill の注入を無効化しても **6 TC 全てが PASS** した。
`ok=true` を期待する TC（TC-02 / TC-03）は空サンドボックスでも通り、
TC-03b は「plugin 同士の衝突」という**別の理由**で偶然通っていた。

→ `_t52_assert_defs` を追加し、TC 本体を `if` でガードした。
是正後に同じ変異を当てると TC-02 / TC-03 / TC-03b が
`sandbox injection failed (want=N got=M)` で落ちる（実測済み）。

---

## 差分に対する C-1 チェック

| ID | 項目 | 判定 | 根拠 |
|----|------|------|------|
| C1-TC-03 | 自動化可否 | PASS | 追加 TC はすべて自動 |
| C1-TC-04 | 負側 TC の本番経路 | PASS | 既定経路は不変。**加えて harness / standalone の両実行文脈で同一結果**であることを実測 |
| C1-TC-05 | 件数 assert の不在 | PASS | `_t69_assert_defs` / `_t52_assert_defs` が数えるのは **一時ディレクトリ内で自分が今作ったファイル**。成長するディレクトリへの件数契約ではない |
| C1-TODO-04 | Iron Law 遵守 | PASS | `.github/workflows/` 未編集 / `c3.json` 未発行 / 他ワーカー領域（`ta-25-*` と承認トークン検査スクリプト）未変更 |
| C1-PLAN-03 | スコープ制御 | PASS | 是正は TC 2 ファイルに限定。検査器本体（`scripts/check-*.py`）は無変更 |

---

## 指摘事項

### FAIL-1（新規・本 PBI 自身の欠陥）: 検知器 PBI の TC が false green を持っていた

「配布物の検知器を立てる」PBI の TC が、
**注入が失敗しても緑を返す**構造だった。しかも私は同じ PBI の中で
「stale の判定が環境依存だったのは検知器として不適格」と指摘している。
**自分が正しく批判した性質を、自分の TC が持っていた。**

- **構造原因 1**: `set -e` 下での rc 捕捉イディオムの誤り
- **構造原因 2**: 「注入が成立したか」を検証していなかった。
  検査器は「違反なし = rc=0」を返すため、**注入失敗と正常が区別できない**
- **見落とした理由**: ローカルで standalone しか実行していなかった
  （フルスイート実行禁止の制約下で、harness 文脈を再現する手段を用意していなかった）
- **再発防止**: 「**単一 extra を harness 文脈（`set -eu` + source）で走らせる**」
  検証手段を、以後 extras を追加・変更するときの標準手順として handoff に記載する

**教訓**: 検査器の TC は「検査器が緑を返した」だけでなく
「**測る対象が本当にそこにあった**」を検証しないと、#1109 と同型になる。

### WARN-1 / WARN-2（継続）

`--strict` 未配線 / skill レーンの parity 未担保。いずれも別 PBI 送り（`status.md` 参照）。

---

## exec 可否

**C-1 PASS（第 2 回再実行）。** Mode = `high-risk` のため **C-3 は人間必須**。
`c3.json` は発行しない。
