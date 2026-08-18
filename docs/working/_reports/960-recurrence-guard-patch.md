# #960 再発防止 patch — 「17 項目」表記の再導入を機械検出する（**Human 適用**）

> 対象: `tests/extras/`（新規 1 ファイル）— **AI が到達できないパス**
> 測定基点: `origin/main` = `3812e19` / 2026-08-18

## なぜ必要か — **是正は 16 分後に退行しました**

```
88145a3e  2026-08-18 09:13:37  #1118  非 HO 24 ファイルを是正 — 測定時点で 0 件
6640cdd   2026-08-18 09:29:26  #1122  新節を追加 → 同ファイルに「17 項目」が復活
```

`git show 6640cdd -- .agents/skills/plan-review-gate/SKILL.md` の追加行に実在します。PR #1138 で再度是正しましたが、**検査が無いので同じことがまた起きます**。

### 検査が存在しないことの実測

```sh
$ grep -rn '17.*項目' .github/workflows/ tests/extras/ scripts/
（出力なし）
```

---

## ⚠️ 最初に設計した検査は、防ぐはずの退行を検出できませんでした

**本 patch の設計過程で 1 度失敗しています。記録として残します。**

当初、「正本以外に C-1 の項目数が複写されていないこと」という**方針そのもの**を検査しようとしました:

```sh
git grep -nE 'C-?1[^0-9]{0,40}[0-9]+[[:space:]]*項目|[0-9]+[[:space:]]*項目[^0-9]{0,40}C-?1'
```

**変異注入（`6640cdd` の再導入を再現）したところ、検出できませんでした。**

```
対象行: 1. **C-1 / C-2 の判定基準は変えない** — 17 項目・5 観点・…
                    ^^^ ここに C-2 の数字があるため [^0-9]{0,40} が成立しない
```

**「C-1 の近くに数字＋項目」という素朴な近接判定は、同じ行に別のゲート名（C-2 / C-3）が並ぶという実際の文体で壊れます。**

さらにこの設計は**同時に過剰でもありました** — 37 件を検出し、その中には `light` モードの「Plan 7 項目」のような**正当な記述**が多数含まれていました。**弱すぎて目的を外し、かつ広すぎて実用にならない**という二重の失敗です。

> これは #984（検査は書いたが `checks` に無い）/ #990（`--dry-run` が該当関数に到達しない）/ #1087（スクリプトは rc=1 だが CI が呼んでいない）と**同じクラス**です。**検査を書いた側が「測っているつもりのもの」と「実際に測っているもの」を確認しないと、緑が意味を失います。**

---

## 採用する設計（**変異注入で検出を実証済み**）

**方針の一般化を諦め、実際に起きた退行の値リテラルを許可リスト方式で検査します。**

```sh
git grep -nE '17[[:space:]]*項目' \
 | grep -vE '^docs/working/(TASK-|PBI-|discussions/|_)' \
 | grep -vE '^docs/(archive|plangate-v6-roadmap)' \
 | grep -vE '^(CHANGELOG\.md|docs/changelog\.md|docs/release-notes)' \
 | grep -vE '^docs/working/retrospective-' \
 | grep -vE '^docs/working/templates/review-self\.md:'
```

### 実証

| 検証 | 結果 |
|---|---|
| **変異注入**（`6640cdd` の再導入を再現） | **✅ 検出**（`.agents/skills/plan-review-gate/SKILL.md:79`） |
| 現ツリーでの検出 | **21 件 / 11 ファイル** |
| その 11 ファイルの正体 | **`#1119` patch（HO 分）の対象集合と完全一致** |

つまり **#1119 が適用された時点で検査は 0 件＝緑になります。** 追加の是正は不要です。

```
.claude/agents/workflow-conductor.md          .claude/commands/README.md
.claude/commands/ai-dev-workflow.md           .claude/rules/mode-classification.md
.claude/rules/working-context.md              schemas/review-result.schema.json
+ plugin/plangate/ ミラー 5 件
```

### この設計が引き受けている弱さ（**明示**）

- **`17` という特定の値しか見ません。** 「全 25 項目」を他所へ複写する drift は検出しません。
- **方針（「総数を複写しない」）そのものは検査していません。** 検査しているのは「既知の stale 値が戻っていないこと」だけです。

**これは妥協です。** ただし、**弱い検査を「方針を守っている」と誤認させないことのほうが重要**なので、名前とコメントに「値リテラル検査である」と明記します。

---

## 差分

### `tests/extras/ta-XX-c1-stale-item-count.sh`（新規）

```sh
#!/bin/sh
# TC: C-1 の stale な項目数表記「17 項目」が正本外へ再導入されていないこと（#960 再発防止）
#
# ⚠️ これは「値リテラル検査」であり、方針検査ではない。
#    正本 docs/working/templates/review-self.md は「総数を契約値として他所へ
#    複写しない」と定めるが、本検査はその方針全体ではなく、既知の stale 値
#    「17」が戻っていないことだけを見る。「25」の複写は検出しない。
#
# 背景: #1118 が是正した 16 分後に #1122 が同一ファイルへ再導入した（6640cdd）。
#       近接判定（C-1 の近くに <数字> 項目）は同一行に C-2 が並ぶ文体で壊れるため
#       採用しない（設計検討の記録: docs/working/_reports/960-recurrence-guard-patch.md）。

set -eu

_t_root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$_t_root"

_canon='docs/working/templates/review-self.md'
_actual="$(grep -c '^### C1-' "$_canon")"

_hits="$(
  git grep -nE '17[[:space:]]*項目' \
  | grep -vE '^docs/working/(TASK-|PBI-|discussions/|_)' \
  | grep -vE '^docs/(archive|plangate-v6-roadmap)' \
  | grep -vE '^(CHANGELOG\.md|docs/changelog\.md|docs/release-notes)' \
  | grep -vE '^docs/working/retrospective-' \
  | grep -vE "^${_canon}:" \
  || true
)"

if [ -n "$_hits" ]; then
  echo "FAIL: stale な C-1 項目数表記「17 項目」が残存しています（正本の実測値: ${_actual} 項目）" >&2
  echo "$_hits" >&2
  echo "" >&2
  echo "  正本: ${_canon}" >&2
  echo "  「17」は歴史的なコア番号帯の通称であり総数ではありません。" >&2
  echo "  数値を落として正本を参照させてください。" >&2
  exit 1
fi

echo "PASS: stale な「17 項目」表記なし（正本の実測値: ${_actual} 項目）"
exit 0
```

> ⚠️ **`git grep` の ERE では `\s` が空白クラスとして機能しません**（「文字 s の 0 回以上」と解釈されます）。**必ず `[[:space:]]` を使ってください。** #1118 でこれにより scope を約半分に見誤りました。

### CI への配線

**単独の workflow を新設せず、既存の `tests/extras/` 実行経路に載せてください**（`tests/run-tests.sh` 経由なら追加配線は不要）。

**配線後、検査を消すと CI が赤くなることを確認してください。**（#984 の「検査は書いたが `checks` に無い」と同型を避けるため）

---

## 適用順序（**重要**）

```
1. #1119 patch（HO 11 ファイル）を適用   ← 先
2. 本検査を tests/extras/ へ配置          ← 後
```

**逆順にすると CI が最初から赤くなり、検査が無視される常態化を招きます。** #1119 の適用時点で検査対象は 0 件になることを実測済みです。

## 受入基準（案）

- [ ] **AC-1**: #1119 適用後の main に対して検査が **PASS** する
- [ ] **AC-2**（**検出力**）: `6640cdd` の変更を再現すると **FAIL** する — **変異注入で実証**すること（本書では実証済み）
- [ ] **AC-3**: 完了済みアーカイブ（`docs/working/TASK-*` / `discussions/` / `retrospective-*`）と歴史記録（`CHANGELOG.md` / `docs/changelog.md`）と旧版設計（`docs/archive/`）では FAIL しない
- [ ] **AC-4**: 正本 `docs/working/templates/review-self.md` の用語説明（「17」がコア番号帯の通称である旨）では FAIL しない
- [ ] **AC-5**: 検査を CI から外すと**赤くなる**ことを確認する
- [ ] **AC-6**: `sh tests/run-tests.sh` に新規 FAIL がない（baseline は着手時に現 main で再測定。**絶対件数を契約値にしない**）

## 責務

| 作業 | 担当 |
|---|---|
| 検査の設計・除外条件の洗い出し・**変異注入による検出力の実証** | **AI-owned**（本書） |
| `tests/extras/` への配置・CI 配線 | **Human-owned**（AI は `.sh` に到達不可） |
| **#1119 patch の適用**（本検査の前提） | **Human-owned**（HO） |

## この検査で解決しないこと

- **「25 項目」の複写**は検出しません（値リテラル検査のため）
- **他の正本の「複写するな」方針**は守りません。汎用化は別 issue で扱うべきですが、本 patch では扱いません（scope を広げると入らなくなるため）

Refs #960
Refs #1092
