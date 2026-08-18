# #1011 V3-04 patch — `_mass_delete_blocked` が数値不正で fail-open する（**Human 適用**）

> 対象: `scripts/sync-plugin-plangate.sh`
> **AI は `.sh` を編集できない**（EH-3 の no-task 経路が `SKIP_REASON` を要求）ため、差分と適用手順を文書として提示する。
> 測定基点: `origin/main` = `1e33b57` / 2026-08-18

## 問題

`_mass_delete_blocked()` は **mass-delete guard（データ損失防止）の判定関数**ですが、**引数が数値でないとき削除を続行**します。

```sh
_mass_delete_blocked() {
  [ "$3" -gt "$2" ] || return 1     # ← 数値でないと [ が失敗し return 1 = proceed
  ...
}
```

戻り値の意味:

| 戻り値 | 意味 |
|---|---|
| `0` | **削除を保留せよ（blocked）** |
| `1` | 削除を続行してよい（proceed） |

**`[ "abc" -gt "" ]` は「比較失敗」で非ゼロを返すため `|| return 1` が発火し、`proceed` になります。** データ損失を防ぐガードが、**入力が壊れたときに最も危険な側へ倒れます**。

### 再現（実測）

```sh
$ sh -c '_f(){ [ "$3" -gt "$2" ] || return 1; echo BLOCKED; }; _f L "" abc; echo rc=$?'
sh: line 0: [: abc: integer expression expected
rc=1                                    ← proceed（削除続行）= fail-open
```

`/bin/sh` / `dash` の両方で再現します。

## 現状の到達可能性 — **今は到達不能（defense-in-depth）**

3 つの呼び出し元すべてが `$((...))` で件数を作るため、**現時点で非数値が渡ることはありません**。

```
:127  if _mass_delete_blocked "$_label" "$_src_count" "$_stale_count"
:218  if ! _mass_delete_blocked "skills/$_skill_name/references" "$_refs_base_count" "$_refs_stale_count"
:395  if ! _mass_delete_blocked "skills/ai-loop-cycle/references" "$_ai_loop_ref_base_count" "$_ai_loop_ref_stale_count"
```

いずれも直前で `_x=$((_x + 1))` により算術評価された値です。

**したがって本 patch は挙動不変で、CI が赤くなるリスクはありません。**

## それでも今直すべき理由

**#991 が同じ関数の呼び出し元（base 算出式）を書き換えます。**

- #991 は `_ai_loop_map_file` を使って**正本ディレクトリごとに base/stale を分離集計**する設計です
- 新しい算出経路が入るとき、**「数値であることの保証」が現在の `$((...))` に依存している**ことは自明ではありません
- **後続がこの関数の契約に依存する**ため、**Phase 3 の最初に契約を固めるべき**です（#1092 の推奨着手順でも `[1]` に置いています）

## 差分

`scripts/sync-plugin-plangate.sh` の `_mass_delete_blocked()` 冒頭に数値検証を追加します。

```diff
 _mass_delete_blocked() {
+  # 数値検証（#1011 V3-04）: 引数が数値でない場合は **削除を保留する側（blocked）**
+  # へ倒す。従来は [ が比較失敗して `|| return 1` = proceed に落ち、データ損失を
+  # 防ぐガードが入力破損時に最も危険な側へ倒れていた（fail-open）。
+  # 到達したときは呼び出し元の集計が壊れているため、guard_fired で CI へ露出させる。
+  case "${2:-}" in
+    ''|*[!0-9]*)
+      _warn "ERROR: $1 — base 件数が数値ではありません (base='${2:-}')。削除を保留します（#1011 V3-04）"
+      guard_fired=1
+      return 0
+      ;;
+  esac
+  case "${3:-}" in
+    ''|*[!0-9]*)
+      _warn "ERROR: $1 — stale 件数が数値ではありません (stale='${3:-}')。削除を保留します（#1011 V3-04）"
+      guard_fired=1
+      return 0
+      ;;
+  esac
   [ "$3" -gt "$2" ] || return 1
```

### 設計判断 2 点（**適用前に確認してください**）

**1. 不正値を `blocked`（`return 0`）に倒す**

「判定不能なら安全側」という本リポジトリの既存規範（`working-context.md` AC-8 / `mode-classification.md` の安全側推定）と一貫させています。**削除を続行するより保留するほうが回復可能**です。

**2. `guard_fired=1` を立てる**

非数値が渡る＝**呼び出し元の集計が壊れている**ため、**沈黙させず CI に出す**べきと判断しました。`guard_fired` は最終的に exit 3 につながり、ワークフローが赤くなります。

> **これを望まない場合**（内部エラーで CI を赤くしたくない）は、`guard_fired=1` を落として `return 0` のみにしてください。その場合**削除は保留されますが誰も気づきません**。**私は立てる側を推奨**します。

## 検証（4 シェルで実測済み）

```
入力:      (base=5,stale=3)  (3,5)  ('',abc)  (3,'')  (3,x9)
期待:       1=proceed          0      0        0       0

sh          1                  0      0        0       0
bash        1                  0      0        0       0
dash        1                  0      0        0       0
zsh         1                  0      0        0       0
```

**正常系（`1` / `0`）の挙動は変わらず、不正値のみ `0`（blocked）へ倒れます。**

## 適用手順

```sh
# 1. 上記 diff を適用

# 2. 挙動不変の確認（正常系）
sh scripts/sync-plugin-plangate.sh --dry-run    # rc=0 / "Sync complete — no changes"

# 3. 不正値での fail-closed 確認（関数を抽出して直接呼ぶ）
awk '/^_mass_delete_blocked\(\)/,/^}/' scripts/sync-plugin-plangate.sh > /tmp/_f.sh
for s in sh bash dash zsh; do
  "$s" -c '_warn(){ :; }; guard_fired=0; . /tmp/_f.sh; _mass_delete_blocked L "" abc; echo "$s rc=$?"'
done
# 期待: 4 シェルとも rc=0（blocked）

# 4. 全体
sh tests/run-tests.sh   # 単独で実行すること（並行実行は ta-42 / ta-61 で壊れます）
```

## 回帰テストの提案（本 patch には含めない）

**現状 `ta-26` には非数値入力の TC がありません**（#1011 の V3-04 が起票されている理由そのもの）。以下を `ta-26-plugin-sync.sh` に追加すべきです:

| 入力 | 期待 |
|---|---|
| `("", "abc")` | rc=0（blocked） |
| `("3", "")` | rc=0 |
| `("3", "x9")` | rc=0 |
| `("5", "3")` | rc=1（proceed・**正常系が壊れていないこと**） |
| `("3", "5")` | rc=0（blocked・正常系） |

> **変異注入で検出力を実証すること**: 追加した `case` を 1 つずつ外して、対応する TC が FAIL することを確認してください。**両方同時に外すと 1 つの変異で全 TC が落ち、個別の検出力が測れません**（本リポジトリの既存教訓）。

## Phase 3 の着手順における位置づけ

#1092 の推奨着手順で **`[1]` = 最初**に置いています。理由:

- **独立**（他の設計判断に依存しない）
- **挙動不変**（CI RED リスクなし）
- **後続がこの関数の契約に依存する**（#991 / V3-05 / V3-02 がすべて同じ guard 周辺を触る）

## 責務

| 作業 | 担当 |
|---|---|
| patch の作成・再現手順・4 シェル検証 | **AI-owned**（本書） |
| **`scripts/sync-plugin-plangate.sh` への適用** | **Human-owned**（EH-3 が AI の `.sh` 編集を block） |
| 設計判断 2 点の確定 | **Human**（とくに `guard_fired` の扱い） |

Refs #1011 / #1092 / #991
