# EXECUTION PLAN — TASK-1044

> Issue: [#1044](https://github.com/s977043/plangate/issues/1044) / 入力: `pbi-input.md`
> 系譜: TASK-0921 handoff 既知課題 2（HR-4 残存）・2-bis（F-3）

## Goal

tests/extras の bootstrap / helper の harness 判定に**直接実行検知**を加え、
「3 env 漏出 + 直接実行」で harness と誤判定して失敗が rc に伝播しない経路
（helper 欠落時: dash/zsh rc=0、helper 存在時: 4 シェル rc=0）を 4 シェルすべてで塞ぐ。
併せて F-3（finalize 既定値非対称）を fail-closed 化する。

## Constraints / Non-goals

- **POSIX sh のみ**（R-033-1 継承。`local` 禁止・`${0##*/}` は POSIX パラメータ展開）
- **`return 0 2>/dev/null || …` イディオムは型を問わず禁止**（TASK-0921 R-021 継承）
- **harness source 経路で非 0 return / exit しない**（R-024 継承。runner は `set -eu`）
  — **ただし `pg_extra_contract_finalize` の init 前呼出（契約違反の mis-wire）に限り
  例外とする（明示 carve-out / R-007）**。AC-6 が要求する `exit 4` は本 carve-out に
  基づく。carve-out を設けること自体の可否は **Q-1 で C-3 裁定**を仰ぐ
  （裁定が「carve-out を認めない」であれば AC-6 を harness 保護案へ差し替え、
  TC-32 の期待値も同時に確定反映する）。**exec 実装者は Constraints と AC-6 の
  どちらを優先するか迷ってはならない — 本注記が調停結果である**
- summary 書式 `TA-<NN> standalone: N passed, M failed` 不変（R-015a。ta-26 TC-13 が literal grep）
- mode は init 毎に解決・キャッシュしない（R-033-2 継承）
- bootstrap と helper の mode 判定は**分裂させない**（TASK-0921 plan L676-678 継承。
  本 PBI では「helper が bootstrap の確定した `_pg_extra_direct` を消費し、残り 3 条件は
  同一述語」の形で実現 — helper 関数内での `$0` 再評価は zsh で分裂を生むため禁止 / F-1）
- `tests/run-tests.sh` は変更しない（Non-goal。bootstrap / helper 側で完結）
- runner の起動シェルは sh（dash/bash 系）前提を維持。zsh runner のサポートは Non-goal
  （zsh は FUNCTION_ARGZERO により source 先で `$0` が変わるため、本ガードの前提外）
- 層 B / 層 C / Slice 2 範囲に触れない

## Approach Overview

### 根本原因と修正点

harness 判定述語（3 env AND）は「runner に source されている」ことの**代理指標**でしかなく、
env 漏出で偽装可能。POSIX 範囲で「実際に source されているか」は **`$0` の basename** で
判別できる: source 時の `$0` は runner（`run-tests.sh`）、直接実行時は自ファイル
（`ta-*.sh`）になる。よって述語に「`$0` が `ta-*.sh` に一致するなら直接実行 = standalone
強制」を AND する。

issue #1044 の修正案（ファイル名 literal の case）は採らず、**`ta-*.sh` glob 照合**とする:

- literal 埋め込みはファイルごとに 1 トークン異なり、TASK-0921 が確立した
  「全出現バイト一致」の機械照合 DoD を人手判断つき検査へ退化させる
- glob 照合なら bootstrap の**照合対象すべて**が同一バイト列のまま（AC-4 = marker 由来の
  動的導出。現時点の実測母数 14 は契約値ではない。helper は
  変数消費形の分離定義 — 後掲 Mode resolution v2）
- 修正位置も issue 案（helper 欠落 FAIL 分岐のみ）でなく **mode 判定そのもの**とする。
  実測 2（helper 存在でも 4 シェル rc=0）が示すとおり、FAIL 分岐だけ直しても
  harness 誤判定による standalone 契約の無効化（rc=3 消失・env unset 不発）が残るため

### Mode resolution v2（新正本）

> **本節が bootstrap / helper harness 判定述語の唯一の正本である**。
> TASK-0921 plan「### Mode resolution」（3 条件 AND）を**置換**する（同 plan は承認済み
> 歴史文書として編集しない。照合先の切替は本節 + ta-61 の機械照合 TC（TC-35 **新設** —
> base の ta-61 に述語バイト一致 TC は存在しない）+ helper ヘッダ参照更新で行う）。
> 他箇所は本節を名前で参照し、条件式を literal 複製しない（TASK-0921 の複製禁止規約を継承）。

harness 判定 = **直接実行でない AND 3 env AND**（4 条件）。ただし **`$0` の評価は
bootstrap トップレベルの 1 回のみ**とし、helper は評価済み変数を消費する（F-1）:

- **bootstrap（トップレベル / marker 由来の照合対象すべてでバイト一致・実測母数 14）**: `$0` を case で評価し
  `_pg_extra_direct` を確定してから 4 条件で分岐

  ```sh
  case "${0##*/}" in ta-*.sh) _pg_extra_direct=1 ;; *) _pg_extra_direct=0 ;; esac
  if [ "$_pg_extra_direct" = "0" ] && [ "${PG_HARNESS_SOURCED:-0}" = "1" ] && [ -n "${FIXTURES_DIR:-}" ] && [ -n "${EXTRAS_DIR:-}" ]; then
  ```

- **helper `_pg_extra_resolve_mode`（変数消費形 / 照合対象から分離定義）**:
  **関数内で `$0` を再評価しない**。zsh は FUNCTION_ARGZERO（既定 ON）により
  **関数内の `$0` = 関数名**となり、関数内評価のガードは zsh 直接実行で不発になる
  （river-review F-1 実測: 関数内評価形は dash/bash/sh が rc=3 + summary、
  **zsh のみ rc=0・summary 無し = mode 分裂の再発**）。未設定は安全側 = direct 扱い:

  ```sh
  if [ "${_pg_extra_direct:-1}" = "0" ] && [ "${PG_HARNESS_SOURCED:-0}" = "1" ] && [ -n "${FIXTURES_DIR:-}" ] && [ -n "${EXTRAS_DIR:-}" ]; then
    _PG_EXTRA_STANDALONE=0
  else
    _PG_EXTRA_STANDALONE=1
  fi
  ```

**DoD（AC-4 の照合規約 / R-005 反映）**: (1) bootstrap の判定 2 行（case 行 + if 行）が
**bootstrap marker（`# ---- extras execution contract bootstrap`）を含む `tests/extras/`
全ファイル**で**行頭空白を除去した上でバイト一致**。**対象は marker 由来で動的に導出し、
絶対件数を契約値にしない** — `tests/extras/` は成長ディレクトリであり、Slice 2 が
層 B/C を bootstrap へ移行した瞬間に固定件数は嘘になる。固定リストにすると Slice 2 が
旧述語で新ファイルを足しても緑（偽陰性）、件数固定にすると無関係 PR が層 A に 1 本
足しただけで CI が落ちる（偽陽性）。**現時点の実測母数は 14**（層 A 12 + ta-61 本体 +
ta-61 fixture 複製）だが、これは**実測値であって契約値ではない**。
先例: `ta-26` TC-33 は件数をハードコードしない grep ベース検査である。
(2) helper は照合対象から**分離定義**とし、上掲の変数消費形 literal と
一致することを別途照合する。

**帰結（exec で必ず対応 / R-001・R-002 反映）**: bootstrap を持たず helper を直接
source する ta-61 fixture は、`_pg_extra_direct` 未設定 → 既定 direct=1 → **3 env の
値に関わらず standalone** へ落ちる。**問題は「赤くなること」ではなく「静かに PASS
すること」である**。レビュアーが提案パッチ適用後の複製で実測した落ち方:

| fixture / TC | 未対応時の挙動 | 検出可否 |
|---|---|---|
| TC-01（harness 非侵襲） | standalone finalize が exit 0 → 後続 counters 検証行に到達せず rc=0 | **空振り PASS** |
| TC-01b（2 env 漏出） | rc=0（期待値 `pass=0` が standalone 側と同値のため区別不能） | **空振り PASS** |
| TC-01c（HR-4 = 空 `EXTRAS_DIR`） | rc=0 | **空振り PASS** |
| TC-21（harness `register_cleanup`） | `harness-def:probe-path` 出力 + rc=0 | **空振り PASS** |
| TC-26（`set -eu` 非切断） | rc=1・`mini-marker: file2` 消失 | FAIL（唯一 loud） |

決定打: helper の 3 env 述語を `PG_HARNESS_SOURCED` 単独へ退行させる変異を注入しても
**TC-01c は rc=0 で生存**する＝ **HR-4 回帰テストの検出力が完全に失われる**。

したがって fixture 更新規約を以下に固定する:

1. **harness 模擬 fixture は `_pg_extra_direct=0` を明示設定**する
2. **standalone 期待の fixture も `_pg_extra_direct=0` を明示設定**し、
   **env 述語を唯一の判別子として残す**（`tc01b.sh` に `_pg_extra_direct=0` を
   入れて初めて TC-01b / TC-01c は元の意味を回復する）
3. **挙動が変わる fixture（部分集合）の完全列挙**（`grep -n 'PG_HARNESS_SOURCED=1'
   tests/extras/ta-61-extra-contract.sh` の fixture heredoc から導出。本 plan 反映時の
   実測: `:384` / `:584` / `:638` の 3 群 + `tc01b.sh` の可変形）。
   **これは「`PG_HARNESS_SOURCED` を明示設定するため挙動が変わる」部分集合であって、
   AC-8 / TC-37 の走査母数ではない**（R-014）:

   | fixture | 行 | 未対応時 |
   |---|---|---|
   | `tc01.sh` | `:383` | 空振り PASS |
   | `tc01b.sh`（TC-01b / TC-01c 兼用） | `:410` | 空振り PASS |
   | `tc21.sh` | `:582` | 空振り PASS |
   | `tc26-runner.sh`（`tc26-file1.sh` を source） | `:631`（`:621`） | loud FAIL |

4. 将来の fixture 追加漏れは **AC-8 の静的検査 TC**（`_pg_extra_direct` 未設定の
   fixture が 0 件）で担保する。**AC-4 の機械照合は bootstrap + helper が対象であり
   fixture は照合網の外**であるため、AC-8 が無いと網が開く
5. 検出力の維持は **変異 M-4**（helper の 3 env 述語を `PG_HARNESS_SOURCED` 単独へ退行
   → **TC-01c が kill**）で実証する。これが無いと AC-7（既存 TC 無回帰）は
   「空振りでも PASS」を許容してしまう。
   **期待値の訂正（R-018 / レビュアー実測）**: M-4 で kill されるのは **TC-01c（rc=65）**
   のみで、**TC-01b は rc=0 で生存**する — TC-01b の判別子は `PG_HARNESS_SOURCED=0`
   であり、M-4 は同条件を保持するため **原理的に検出できない**。
   TC-01b の検出力も証明するには **M-4b**（`PG_HARNESS_SOURCED` 条件を落とし
   `FIXTURES_DIR && EXTRAS_DIR` のみへ退行）を対称に追加し、**TC-01b が kill される**
   ことを実証する

**規約 3-bis（R-014）**: **`_pg_extra_direct` の明示設定は helper を直接 source する
   全 fixture（本 PR 時点の実測 12 本）に適用する。件数は契約値でなく
   `. "$T61_HELPER"` 由来で動的導出する**（AC-4 と同じ規約に揃える）。本 PR 時点の実測内訳:
   `tc01` / `tc01b` / `tc02` / `tc03` / `tc04` / `tc06` / `tc07` / `tc08` / `tcskip` /
   `tc21` / `tc23` / `tc26-file1`（`grep -c '\. "\$T61_HELPER"'` = **12**・
   行 `:391` `:416` `:440` `:454` `:468` `:494` `:512` `:530` `:553` `:590` `:606` `:623`）。
   **上記 3 の 4 本（`tc26` は runner 側）は挙動が変わる部分集合、12 本は走査母数**であり、
   「完全列挙 = 4」を TC-37 の母数と読むと **残り 8 本が未設定として TC-37 が FAIL** する。
   逆に TC-37 の走査対象を 4 本の固定リストへ狭めると **AC-8 が謳う「将来の追加漏れに
   対する唯一の機械検出点」が手書きリストへ退化**し R-001 / R-002 が実質復活する。

**規約 3-ter（R-014）**: **`tc26` の 2 ファイル構造に対する TC-37 フィルタの精度**:
   TC-37 の literal フィルタ（`. "$T61_HELPER"` を含む fixture）にマッチするのは
   **`tc26-file1.sh` であって `tc26-runner.sh` ではない**（runner は
   `. "$T61_FXDIR/tc26-file1.sh"` を source するだけで helper を直接読まない）。
   `_pg_extra_direct=0` はどちらに置いても機能する（runner → file1 は同一シェルで
   非 export グローバルを継承するため）が、**TC-37 が検査する側（`tc26-file1.sh`）に
   置く**こと。runner 側だけに置くと「置いたのに未設定と言われる」齟齬が出る。

反映先: S5 / S7 / T-06 / T-08 / TC-36 / TC-37 / EV-4。

bootstrap 全体（marker 由来の照合対象すべてで全体バイト一致・実測母数 14）:

```sh
# ---- extras execution contract bootstrap (#921 / #1044) --------------------
case "${0##*/}" in ta-*.sh) _pg_extra_direct=1 ;; *) _pg_extra_direct=0 ;; esac
if [ "$_pg_extra_direct" = "0" ] && [ "${PG_HARNESS_SOURCED:-0}" = "1" ] && [ -n "${FIXTURES_DIR:-}" ] && [ -n "${EXTRAS_DIR:-}" ]; then
  _pg_extra_mode=harness
  _pg_extra_dir="$EXTRAS_DIR"
else
  _pg_extra_mode=standalone
  _pg_extra_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
fi
_pg_extra_helper="$_pg_extra_dir/_extra-contract.sh"
if [ ! -r "$_pg_extra_helper" ]; then
  printf '  [FAIL] helper unresolved: %s\n' "$_pg_extra_helper" >&2
  if [ "$_pg_extra_mode" = harness ]; then
    fail=$((fail + 1))
    return 0
  fi
  exit 1
fi
. "$_pg_extra_helper"
```

**整合確認（TASK-0921 plan「`$0` をアンカーにしない」規約との関係）**: 同規約は
helper の**ディレクトリ解決**に `$0` を使うと harness 経路で `tests/_extra-contract.sh`
（不在）を指す問題への禁止。本ガードは逆に「harness 経路の `$0` は run-tests.sh であり
`ta-*.sh` に一致しない」ことを判定に使うもので、ディレクトリ解決には従来どおり
mode 分岐（harness=`$EXTRAS_DIR`）を用いる。矛盾しない。

**挙動マトリクス（変数消費形ガード / sandbox 4 シェル実測済み 2026-08-12）**:

| 経路 | `$0` basename | 3 env | mode / 実測 rc |
|---|---|---|---|
| runner source（正規 harness / sh 系） | run-tests.sh | set | harness（不変。runner 型 fixture で dash/bash/sh とも非 exit・counters 維持を実測） |
| 直接実行・清浄 env | ta-XX-*.sh | unset | standalone（不変。dash/zsh/bash/sh とも rc=3 実測） |
| 直接実行・3 env 漏出 + helper 欠落 | ta-XX-*.sh | set | **standalone → exit 1**（実測 1 是正。**dash=1 / zsh=1 / bash=1 / sh=1 実測**） |
| 直接実行・3 env 漏出 + helper 存在 | ta-XX-*.sh | set | **standalone**（実測 2 是正。**dash=3 / zsh=3 / bash=3 / sh=3 + summary 出力を 4 シェルで実測**） |
| **zsh 直接実行（F-1 対象経路）** | ta-XX-*.sh | set | **standalone rc=3 + summary（変数消費形で是正済み実測）**。関数内 `$0` 評価形では FUNCTION_ARGZERO により rc=0・summary 無し = 不発だった |
| ta-61 fixture（tc01.sh 等 非 ta-* 名・bootstrap 無し） | tc01.sh | 任意 | 既定 direct=1 → standalone。**harness 模擬 fixture は `_pg_extra_direct=0` 明示設定へ更新**（前掲「帰結」） |
| ta-61 sandbox probe（ta-97〜99） | ta-9X-*.sh | unset | standalone（不変） |

### F-3 是正（finalize 既定値非対称の fail-closed 化）

現状: `pg_extra_contract_is_standalone` は `${_PG_EXTRA_STANDALONE:-1}`（既定 standalone）、
`pg_extra_contract_finalize` は `${_PG_EXTRA_STANDALONE:-0}`（既定 harness）で非対称。
init 前に finalize を呼ぶ契約違反ファイルは harness 側へ**静かに**落ちる。

是正案は既定値の反転（`:-0`→`:-1`）**ではなく** finalize 冒頭の明示検査とする:

```sh
if [ -z "${_PG_EXTRA_STANDALONE:-}" ]; then
  printf '  [FAIL] pg_extra_contract_finalize called before init (mis-wired test)\n' >&2
  exit 4
fi
```

**挿入位置は固定（R-011）**: 上記ブロックは **必ず `_PG_EXTRA_ORIGINAL_RC=$?` の
直後**（現 `_extra-contract.sh:116` の次行）に置く。`pg_extra_contract_finalize` は
関数本体 1 行目で `$?` を捕捉する契約（HJ-4 = (b)・直前にコマンドを挟まない）であり、
**`$?` 捕捉より前に挿入すると `[ -z … ]` が `$?` を潰し、rc 伝播（TC-06）が壊れる**。
exec 実装者は「冒頭」を「関数の 1 行目」と読み違えてはならない。

- 既定値を `:-1` に反転すると、init 前 finalize が source 経路で **runner のカウンタを
  流用した standalone summary + `exit 0`（fail=0 時）を出し得る** — runner が途中で
  静かに正常終了し、後続 extras が走らないまま緑に見える（suite の silent truncation）。
  `exit 4` 案も source 経路で exit する点は同じだが、**診断つき fail-closed**（非 0 rc +
  stderr で原因を指す）であり「静かに緑」にはならない。明示検査 + `exit 4` は
  「probe 配線ミス」と同じ fail-closed チャネル（TASK-0921 裁定 ② と同型）
- init 前 finalize は TC-10（top-level init 必須の静的検査）が CI で block 済み。
  runtime で到達する時点で既に異常であり、runner 巻き添え（source 経路で exit 4）は
  「静かに緑」より安全側 — **この取り扱いは C-3 で人間裁定を求める設計判断**（Q-1）
- L34 の `:-1` は不変（is_standalone は query であり standalone 既定が安全側）。
  L117 の `:-0` は明示検査の後段では到達時に必ず設定済みとなるため実質デッドだが、
  防御的既定として残す

### 正本管理（TASK-0921 plan 固定スニペットの変更手続き）

| 項目 | 決定 |
|---|---|
| 新正本 | **本 plan「### Mode resolution v2」**（bootstrap 全体 + 判定 2 行） |
| 旧正本 | TASK-0921 plan「### Mode resolution」— 承認後 plan のため**編集しない**（歴史文書化） |
| 参照の切替 | **TC-35 新設**（base の ta-61 に述語バイト一致 TC は存在しないため「更新」ではなく新設。AC-4 の bootstrap marker 由来リストでの一致 + helper 分離照合）+ `_extra-contract.sh` ヘッダコメントの正本参照を本 plan へ更新 |
| handoff 連鎖 | TASK-0921 handoff 既知課題 2 / 2-bis は本 PBI の handoff で「解消（PR #）」を追記参照できるよう、本 PBI handoff に対応表を持つ |
| **evidence 継承（R-003 / R-017 で精密化）** | **(b) superseded 宣言を基本とするが、全 18 本一律ではない**。**14 本 = superseded**（失効の原因が「helper の意図的な設計変更」であって回帰ではなく、再走しても同じ evidence を別 HEAD で作り直すだけ）。**ただし detector が本 PBI の書換対象そのものである 4 本 — M-01（detector = standalone 側 TC-04 + harness 経路。TC-04 fixture も helper 直接 source 対象）/ M-02（detector = **TC-01**）/ M-03（detector = **TC-01b**）/ M-16（detector = **TC-26** 単独）— は「同じ evidence を作り直すだけ」が成立しない**（新 M-1〜M-4b は 3 env 述語に特化しており、旧 18 本の marker / rc レイヤ / allowlist / dual-shell を包含しない）ため、**新 HEAD で再走し kill を再確認する**（既存ドライバ `PG_T61_SKIP_SUITE=1 sh tests/extras/ta-61-extra-contract.sh` がそのまま使える）。追記先 = `docs/working/TASK-0921/handoff.md` 既知課題 2 / 2-bis（**AC-9** で義務化・S8 / T-10 / T-11 で実施）。**あわせて同 handoff の L43（AC-7 PASS 根拠）/ L119（テスト結果サマリ）の「18/18 KILL」行から superseded 注記への参照を張る** — 既知課題への追記だけでは根拠行が古い主張のまま残るため |
| 残存エクスポージャ | 本 PBI で塞ぐのは **bootstrap 系 13 本 + helper**。`ta-25` / `ta-26` / `ta-58` / `ta-59` / `ta-60` の **5 本は 2 env AND のまま残る**（`pbi-input.md`「残存エクスポージャ」節が正本。S8 の handoff 対応表に必須行として載せる / R-006） |

## Work Breakdown

| Step | 内容 | Output | Owner | Risk | 🚩 |
|---|---|---|---|---|---|
| S1 | pre-fix evidence 採取: 現 HEAD で実測 1 / 実測 2 の 4 シェルマトリクスをログ化（AC-5 (a) の前段） | `evidence/test-runs/pre-fix-*.log` | agent | 低 | 🚩 |
| S2 | 新 TC を ta-61 へ追加（TC-30: env 漏出 + helper 欠落 直接実行 dash → rc=1 / TC-31: env 漏出 + helper 存在 直接実行 dash → standalone 契約有効）。**この時点で走らせ FAIL を確認**（TDD red / AC-5 (a)） | ta-61 差分 + red ログ | agent | 中 | 🚩 |
| S3 | helper `_pg_extra_resolve_mode` を**変数消費形**（`${_pg_extra_direct:-1}` を読む・関数内で `$0` を再評価しない / F-1）へ変更 + F-3 明示検査追加。ヘッダコメントの正本参照を本 plan へ更新。rollback: 当該 2 hunk revert | `_extra-contract.sh` 差分 | agent | 中 | 🚩 |
| S4 | bootstrap の全対象（**本 PR 時点の実測母数 14** = 層 A 12 + ta-61 本体 + ta-61 fixture 複製。件数は契約値でなく AC-4 は marker 由来で導出）を Mode resolution v2 ブロックへ同型置換。rollback: `git checkout origin/main -- tests/extras/`（S3 と同一 PR 内で原子的に） | 14 ファイル差分 | agent | 中 | 🚩 |
| S5 | 述語機械照合 TC-35 を**新設**（base の ta-61 に述語バイト一致 TC は存在しない。bootstrap 2 行 × **marker 由来の動的導出**リスト + helper 変数消費形の分離照合 / R-005）+ F-3 用 TC-32（init 前 finalize → exit 4 + 診断）+ **helper を直接 source する全 fixture（本 PR 時点の実測 12 本・`. "$T61_HELPER"` 由来で動的導出）へ `_pg_extra_direct=0` を明示設定**（うち挙動が変わるのは `tc01.sh` / `tc01b.sh` / `tc21.sh` / `tc26`（file1 側）の部分集合。harness 模擬・standalone 期待の双方 / R-001・R-002・R-014）+ **AC-8 静的検査 TC-37 を新設**（`_pg_extra_direct` 未設定 fixture = 0 件）+ TC-30b（`_pg_extra_direct=0` を export しても層 A は standalone / R-008）+ `tests/extras/README.md` 規約 8 へ 1 行追記（トップレベル設定必須 / R-012。Q-2 を「追記する」で確定） | ta-61 差分 + README 差分 | agent | 低 | |
| S6 | green 確認: 新 TC + ta-61 全 TC + フルスイート `sh tests/run-tests.sh` rc=0 + 層 A 12 本の清浄 env standalone 実行 | `evidence/test-runs/post-fix-*.log` | agent | 低 | 🚩 |
| S7 | 変異注入（AC-5 (b)）: **M-1**（bootstrap の case 行 = ガードの call site 除去）→ TC-30/31 が dash で FAIL / **M-2**（helper を変数消費から独自判定へ退行）→ TC-31 が zsh を含めて FAIL / **M-3**（F-3 検査除去）→ TC-32 が FAIL / **M-4（新規 / R-001）**（helper の 3 env 述語を `PG_HARNESS_SOURCED` 単独へ退行）→ **TC-01c が FAIL（kill・rc=65）**。**TC-01b は M-4 の設計上ヒットしない**（判別子が `PG_HARNESS_SOURCED=0` で M-4 は同条件を保持 / R-018）ため、**M-4b**（`PG_HARNESS_SOURCED` 条件を落とし `FIXTURES_DIR && EXTRAS_DIR` のみへ退行）→ **TC-01b が FAIL（kill）** を対称に追加する。M-4 / M-4b は fixture 更新後にのみ kill されるため、AC-8 と対で検出力を保証する | `evidence/test-runs/mutation-*.log` | agent | 低 | 🚩 |
| S8 | 4 シェルマトリクス最終実測（dash/zsh/bash/sh × 実測 1/2 シナリオ。**各シェルの実体と測定ホストを併記** — `ls -l /bin/sh` / `$BASH_VERSION` / `dash --version` / `zsh --version` / `uname -a`。CI 実体（dash）と `sh` の対応が evidence から復元できるようにする / R-009）+ handoff 対応表（(1) **TASK-0921 handoff の「14 箇所」と本 plan の分母差** — 旧 14 = 層 A 12 + ta-61 本体 + helper、新 = bootstrap 14（fixture 複製を含む）+ helper 別枠 — を 1 行注記 / (2) **「#1044 で塞いだ範囲 = bootstrap 系 13 本 + helper、未塞ぎ = 5 本（`ta-25`/`ta-26`/`ta-58`/`ta-59`/`ta-60`・2 env AND・Slice 2 へ）」を必須行として記載**（R-006） / (3) **TASK-0921 handoff 既知課題 2 / 2-bis へ「本 PR で解消 + 変異 evidence 18 本のうち 14 本は superseded（後継 = M-1〜M-4b）/ 4 本（M-01 / M-02 / M-03 / M-16）は新 HEAD で再走し kill 再確認」を追記** + 同 handoff **L43 / L119 の「18/18 KILL」行から superseded 注記への参照**を張る（AC-9 / R-003・R-017） / (4) **本 PBI handoff に「未塞ぎ = 5 本」の行**（AC-9 後段 / R-016。上記 (2) と同一内容を本 PBI handoff 側にも必須行として置く）） | evidence + handoff 素材 + TASK-0921 handoff 追記 | agent | 低 | 🚩 |

依存: S1→S2→S3→S4→S5→S6→S7→S8（S3/S4 は同一 commit 推奨 — 述語分裂の中間状態を作らない。
TASK-0921 R-025-2 の原子性要求と同型）。

## Files / Components to Touch

- `tests/extras/_extra-contract.sh`（resolve_mode ガード + F-3 検査 + ヘッダ正本参照）
- 層 A 12 本: `ta-39` `ta-40` `ta-43` `ta-44` `ta-45` `ta-46` `ta-47` `ta-49` `ta-50`
  `ta-51` `ta-52` `ta-53`（bootstrap ブロック同型置換のみ）
- `tests/extras/ta-61-extra-contract.sh`（本体 bootstrap + fixture 複製 + TC-30/30b/31/32
  追加 + TC-35 / TC-37 新設 + **fixture 4 本への `_pg_extra_direct=0` 明示**）
- `tests/extras/README.md`（規約 8 へ 1 行: bootstrap を持たず helper を直接 source する
  ファイルは `_pg_extra_direct` を**トップレベルで明示設定**すること。非 export の
  グローバルであり直前 source ファイルの値を継承しうるため / R-012。**Q-2 を「追記する」で確定**。
  **追記のみ・既存文言を編集しない** — `ta-26` TC-30（`:750-758`）が README に対し
  `PG_HARNESS_SOURCED` / `非 export` / `AND` / `standalone 側（安全側）` の **4 語を静的 grep**
  しており、既存文言の書き換えは TC-30 を落とす / R-020）
- `docs/working/TASK-1044/*`（本パッケージ）
- `docs/working/TASK-0921/handoff.md`（**既知課題 2 / 2-bis への追記 + L43 / L119 の
  「18/18 KILL」行への superseded 注記参照の付加**。本 PR での解消 + 変異 evidence
  18 本のうち 14 本 superseded / 4 本再走 / AC-9・R-003・R-017。
  TASK-0921 の **plan.md は承認済み歴史文書として編集しない**。追記のみで既存文言は
  書き換えない）
- 触れない: `tests/run-tests.sh`（Non-goal）

## Testing Strategy

- **Unit（contract TA）**: ta-61 に TC-30 / TC-30b / TC-31 / TC-32 追加。既存 TC-01〜29
  全走で fixture 回帰検出。**ただし「空振り PASS」を無回帰と誤認しないため、
  TC-37（AC-8 静的検査）と変異 M-4 を併置する**（R-001）
- **Integration**: `sh tests/run-tests.sh` フルスイート rc=0 / fail=0（source 経路の無回帰）
- **シェルマトリクス**: dash / zsh / bash / sh × {helper 欠落, helper 存在} × 3 env 漏出
  直接実行（AC-1 / AC-2a〜2d。TC 本体は dash 固定、マトリクスは evidence 実測）。
  **evidence には各シェルの実体（`ls -l /bin/sh` / `$BASH_VERSION` / `dash --version` /
  `zsh --version`）と測定ホスト（`uname -a`）を必ず記録する** — pre-fix 表で `sh` が
  bash と同じ rc=1・dash のみ rc=0 という分布は測定ホストの `/bin/sh` が bash 3.2
  （macOS）であること＝実質 3 実装であることを示唆し、**CI 実体（dash）と `sh` の対応が
  evidence から復元できない**ため（R-009）
- **7 env unset の実測（AC-2c）**: standalone 契約下で起動した子プロセスで
  `env | grep -c '^PLANGATE_\|^PG_HARNESS_SOURCED'` が 0 であることを TC-31 で検証する。
  これが無いと**漏出 env が子へ伝播したままでも TC-31 が緑**になる（R-004）
- **変異注入**: (a) pre-fix HEAD で新 TC red（検出力の事前実証）。
  (b) **M-1 / M-2 / M-3 / M-4 / M-4b の全変異**で kill 実証（AC-5(b) / R-013・R-018）
  — 変異は関数でなく call site を壊す（#874 教訓）
- **機械照合（TC-35 新設）**: bootstrap 判定 2 行のバイト一致を、
  **bootstrap marker を含む extras 全ファイル（marker 由来の動的導出）**に対して行う
  （**行頭空白を除去して比較** — fixture 複製はインデント差がありうるため正規化規約を固定）
  さらに helper 変数消費形の**分離照合**を grep ベースで TC 化（AC-4。**絶対件数を契約値に
  しない**。現時点の実測母数 14 はログに残すが assert しない。先例 = `ta-26` TC-33 / R-005）
- **静的検査（TC-37 新設 / AC-8）**: ta-61 内で bootstrap を持たず helper を直接 source
  する全 fixture heredoc が `_pg_extra_direct` を明示設定していること（未設定 = 0 件）。
  **走査母数は `. "$T61_HELPER"` 由来で動的導出**し、**件数（本 PR 時点の実測 12）を
  契約値にしない**（R-014。固定 4 本リストへ狭めると AC-8 が手書きリストへ退化する）。
  `tc26-file2.sh` は helper を source しないため自動除外される。
  **AC-4 の照合網は bootstrap + helper のみで fixture を含まない**ため、本 TC が
  将来の fixture 追加漏れに対する唯一の機械検出点になる（R-001・R-012）
- **変異 M-2 の恒久的役割（F-1）**: helper 側述語のみを壊す M-2 変異は、F-1 是正後は
  「helper が bootstrap の確定値を消費せず独自判定へ退行する」クラス
  （= zsh FUNCTION_ARGZERO 問題の再発形）を恒久検出する

## Risks & Mitigations

| リスク | 影響 | 緩和 |
|---|---|---|
| ta-61 sandbox 系 TC（TC-14〜17/29）が旧 bootstrap 前提で fixture を照合しており、置換で赤くなる | 中 | S2 前に ta-61 全走 baseline。fixture 複製も同時置換（S4 に含む） |
| zsh が runner として使われた場合、FUNCTION_ARGZERO により source 先ファイルのトップレベル `$0` = ファイル名となり、bootstrap が direct=1 → standalone へ落ちて runner のカウンタを流用初期化しうる | 低（runner は sh 前提。CI 実体 dash） | Constraints に「runner は sh 系必須」を明記 + README 規約に 1 行追記検討。失敗方向は「suite が赤くなる / 打ち切られる」であり silent pass 側ではない |
| `ta-*.sh` 命名規約外の将来ファイルにはガードが効かない | 低 | 規約は ta-61 の marker 検査が既に強制。README 規約に依存を明記 |
| 述語変更の中間 commit で bootstrap / helper が分裂 | 中 | S3/S4 同一 commit（原子性、R-025-2 同型） |
| exit 4（init 前 finalize）が harness source 経路で runner を止める | 低（TC-10 が CI で静的 block 済） | Q-1 として C-3 裁定に明示。代替案（return 0 + fail 加算）との比較を提示済み。Constraints に R-024 carve-out を明記済（R-007） |
| **fixture 更新漏れで既存 TC が「空振り PASS」化し、HR-4 回帰テストの検出力が消える** | **高**（本 PBI の目的と正面衝突） | fixture 4 本の完全列挙（帰結節）+ **AC-8 静的 TC**（未設定 0 件）+ **変異 M-4**（3 env → 1 条件退行で TC-01b/01c が kill）の 3 点セット（R-001） |
| `_pg_extra_direct=0` の env 漏出で harness と誤判定される（#1044 と同型の新窓） | 中 | bootstrap は**無条件代入**（`: ${…:=}` 形にしない）。**TC-30b でこれを pin**（R-008） |
| 直前 source ファイルの `_pg_extra_direct` を継承して誤判定 | 低（非 export のため子へは漏れない） | README 規約 8 で「トップレベル設定必須」を規約化 + AC-8 の静的 TC（R-012） |
| TASK-0921 の変異 evidence 18 本の HEAD 整合が本 PR で失効 | 中（監査の連続性） | **(b) superseded 宣言**（正本管理表）+ AC-9 で TASK-0921 handoff への追記を義務化（R-003） |
| マージ後に「extras 全体で塞がった」と誤読される | 中 | `pbi-input.md`「残存エクスポージャ」節に 5 本を明示列挙 + S8 handoff 必須行（R-006） |

## Questions / Unknowns

- **Q-1（要 C-3 裁定 / 2 段の設問 — R-007 で第 2 問を追加）**:
  1. **方式**: F-3 の init 前 finalize を「exit 4 fail-closed（runner 巻き添え許容）」と
     するか「harness では fail 加算 + return 0（runner 保護優先・ただし standalone
     直接実行では依然 rc=0 で漏れる）」とするか。plan は前者を推奨（本 PBI の主題 =
     「静かに通さない」と整合、かつ TC-10 静的検査が通常運用での到達を防ぐ）
  2. **制約レイヤ**: 上記が前者の場合、**Constraints「harness source 経路で非 0 return /
     exit しない（R-024 継承）」に carve-out を設けること自体を許容するか**。
     これは「どちらの方式か」とは別レイヤの論点であり、carve-out を認めない裁定なら
     方式 1 は選べない（AC-6 と TC-32 の期待値を harness 保護案へ差し替える）。
     plan は「init 前 finalize = 契約違反の mis-wire に限定した carve-out」を推奨
- **Q-2（決着済 / R-012）**: README 規約 8 への追記は **「追記する」で確定**
  （`_pg_extra_direct` の非 export グローバル継承を規約化するため。S5 / T-06 に含む）
- **Q-3（要 C-3 追認 / 2 軸 — R-004 の副作用 + R-015 で第 2 軸を追加）**:
  **critical 帯に触れる定量軸は 2 本ある。どちらも AI の解釈で high-risk 側に
  留めているため、両方を C-3 が裁定する**（片方だけ escalate すると、
  同じ節の隣の軸を AI が独自に下げたまま通ることになる / R-015）:

  1. **AC 行数 12**（`mode-classification.md` 定量表で **11+ = critical 帯**）。
     plan は「分割は 1 要件を検証可能単位へ割ったものであり要件総量は不変（実質 9）」
     と読み替えて **high-risk を維持**している。
     → **「high-risk 維持」を追認するか critical へ引き上げるかを裁定**されたい
  2. **変更ファイル数の分母定義（15 か 16 か）**（`15 → high-risk（6-15）` /
     `16 → critical（16+）`）。plan は「working context 成果物および他 PBI の完了資産
     （`TASK-0921/handoff.md`）は規模軸に算入しない」と定義して **15 = high-risk** と
     している。→ **この分母定義を追認するか、`TASK-0921/handoff.md` を算入して
     16 = critical とするかを裁定**されたい

  **安全側の向きに関する両論（R-019 / C-2 Round 2 でレーン間不一致）**:

  | 立場 | 主張 |
  |---|---|
  | **整合レーン**（既定を critical に置くべき） | `mode-classification.md`「判定不能／該当不確実なら**引き上げる側**」・`working-context.md` AC-8「判定不能なら安全側」に照らせば、規定どおりの向きは **既定 critical → 人間が根拠を確認して high-risk へ引き下げ**。現状は plan の最終判定に high-risk を書き、人間に**引き上げ**を求めており向きが逆。ただし **C-3 が明示裁定する限りガバナンス上の穴にはならない**ため REJECT 理由には数えない |
  | **設計レーン**（high-risk 維持を支持） | 上記 1・2 はいずれも「解釈の余地」であって「判定不能」ではない（AC 分割は要件総量を増やしていない / working context を分母に入れると規模軸が影響範囲を表さなくなる）。substance としては **high-risk 維持が妥当** |

  → plan は **暫定的に high-risk（両論併記のうえ Q-3 で確定）** としている。
  C-3 が「既定 critical」の向きを採る場合は、最終判定を critical へ書き換えたうえで
  V-4 追加・複数レビュアーを適用すること

## Mode 判定

**モード**: high-risk

**判定根拠**（`.claude/rules/mode-classification.md` 準拠）:

- 変更ファイル数: 15（helper 1 + 層 A 12 + ta-61 + `tests/extras/README.md`）→ **high-risk**（6-15）
  - **分母の定義（R-010 / R-015 で確定）**: **working context 成果物
    （`docs/working/**` の plan / status / current-state / handoff / evidence 等）は
    Mode 判定の分母に含めない**。含めると exec PR が常に 16+（critical 帯）へ届き、
    規模軸が「実装の影響範囲」を表さなくなるため。
    **他 PBI の完了資産への追記（`docs/working/TASK-0921/handoff.md`）も規模軸には
    算入せず、Files 節での可視化と AC-9 での検証に委ねる**（＝ **例外規定を作らない**。
    旧記述は「例外は他 PBI の完了資産への追記」としつつ「該当するが判定を動かさない」
    と続き、分母 15 と 16 のどちらとも読める自己矛盾だった / R-015）。
    したがって**分母は 15 で確定**する。**この分母定義自体が AI の解釈である**ため、
    **Q-3 の第 2 軸として C-3 の追認を求める**（AC 行数 12 と同じ扱いにし、
    「AI が独自に下げた mode 軸」を 1 つも残さない）
- 受入基準数: 12（AC-1 / AC-2a〜2d / AC-3〜AC-9）→ 形式上 **critical 帯（11+）**だが、
  AC-2a〜2d は**元 AC-2 の 1 要件を検証可能単位へ分割**したもの（R-004）であり、
  要件の総量は増えていない。**分割前の実質要件数は 9**（AC-1 / AC-2 / AC-3〜AC-9）→
  **high-risk**（6-10）。この読み替えは「分割で mode が上がるのは不合理」という
  一点のみに基づき、他の判定軸は据え置く
- タスク数（見込み）: 8 Step ≒ 10-14 タスク → high-risk 帯
- 変更種別: テスト検証基盤（失敗検出力）の修正。機械的な同型置換が主体だが、
  誤ると「テストが静かに通る」方向へ壊れる → 定性 **high**
- 影響範囲: tests/extras 全体（複数ファイル・runner との契約面）→ high
- Hardening Override 対象パス: **非該当**（`tests/extras/` / `docs/working/` のみ。
  9 カテゴリのいずれにも一致しない）
- セキュリティ / スキーマ / 破壊的変更: 非該当
- **最終判定**: **high-risk（暫定 / Q-3 で確定）**。定量・定性とも high-risk で
  オーバーライドなし。ただし **critical 帯に触れる 2 軸（AC 行数 12 / 変更ファイル数の
  分母定義 15 か 16 か）はいずれも AI の解釈**であり、**Q-3 として C-3 の追認**を求める
  （安全側の向きについてはレーン間で両論あり — Q-3 の表を参照 / R-015・R-019）。
  C-3 が critical を採る場合は本行を critical へ書き換え、V-4 追加・複数レビュアーを適用する

high-risk のため: C-2 外部レビュー必須・**人間 C-3 必須（autonomous APPROVE 不可）**・
V-2 / V-3 実行・todo の実装タスクに rollback 必須。
