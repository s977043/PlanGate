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
- summary 書式 `TA-<NN> standalone: N passed, M failed` 不変（R-015a。ta-26 TC-13 が literal grep）
- mode は init 毎に解決・キャッシュしない（R-033-2 継承）
- bootstrap と helper の判定述語は**常に同一**（TASK-0921 plan L676-678 の mode 分裂禁止を継承）
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
- glob 照合なら 15 出現すべてが同一バイト列のまま（AC-4）
- 修正位置も issue 案（helper 欠落 FAIL 分岐のみ）でなく **mode 判定そのもの**とする。
  実測 2（helper 存在でも 4 シェル rc=0）が示すとおり、FAIL 分岐だけ直しても
  harness 誤判定による standalone 契約の無効化（rc=3 消失・env unset 不発）が残るため

### Mode resolution v2（新正本）

> **本節が bootstrap / helper harness 判定述語の唯一の正本である**。
> TASK-0921 plan「### Mode resolution」（3 条件 AND）を**置換**する（同 plan は承認済み
> 歴史文書として編集しない。照合先の切替は本節 + ta-61 の機械照合 TC で行う）。
> 他箇所は本節を名前で参照し、条件式を literal 複製しない（TASK-0921 の複製禁止規約を継承）。

harness 判定 = **直接実行でない AND 3 env AND**（4 条件）:

```sh
case "${0##*/}" in ta-*.sh) _pg_extra_direct=1 ;; *) _pg_extra_direct=0 ;; esac
if [ "$_pg_extra_direct" = "0" ] && [ "${PG_HARNESS_SOURCED:-0}" = "1" ] && [ -n "${FIXTURES_DIR:-}" ] && [ -n "${EXTRAS_DIR:-}" ]; then
```

bootstrap 全体（15 出現の照合単位は上記 2 行。ブロックは層 A 12 + ta-61 本体 +
ta-61 fixture 複製の 14 箇所で全体バイト一致、helper は `_pg_extra_resolve_mode`
関数内に同 2 行を持つ）:

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

**挙動マトリクス（ガード後）**:

| 経路 | `$0` basename | 3 env | mode |
|---|---|---|---|
| runner source（正規 harness） | run-tests.sh | set | harness（不変） |
| 直接実行・清浄 env | ta-XX-*.sh | unset | standalone（不変） |
| 直接実行・3 env 漏出 + helper 欠落 | ta-XX-*.sh | set | **standalone → exit 1**（実測 1 是正） |
| 直接実行・3 env 漏出 + helper 存在 | ta-XX-*.sh | set | **standalone**（7 env unset・rc 契約有効。実測 2 是正） |
| ta-61 fixture（tc01.sh 等 非 ta-* 名） | tc01.sh | 任意 | env どおり（既存 TC 不変） |
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

- 既定値を `:-1` に反転すると、init 前 finalize が harness source 経路で `exit` し
  runner を殺す（R-024 違反）。明示検査 + `exit 4` は「probe 配線ミス」と同じ
  fail-closed チャネル（TASK-0921 裁定 ② と同型）で、契約違反を静かに通さない
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
| 参照の切替 | ta-61 の機械照合（AC-4 の 15 出現一致 TC）と `_extra-contract.sh` ヘッダコメントの正本参照を本 plan へ向ける |
| handoff 連鎖 | TASK-0921 handoff 既知課題 2 / 2-bis は本 PBI の handoff で「解消（PR #）」を追記参照できるよう、本 PBI handoff に対応表を持つ |

## Work Breakdown

| Step | 内容 | Output | Owner | Risk | 🚩 |
|---|---|---|---|---|---|
| S1 | pre-fix evidence 採取: 現 HEAD で実測 1 / 実測 2 の 4 シェルマトリクスをログ化（AC-5 (a) の前段） | `evidence/test-runs/pre-fix-*.log` | agent | 低 | 🚩 |
| S2 | 新 TC を ta-61 へ追加（TC-30: env 漏出 + helper 欠落 直接実行 dash → rc=1 / TC-31: env 漏出 + helper 存在 直接実行 dash → standalone 契約有効）。**この時点で走らせ FAIL を確認**（TDD red / AC-5 (a)） | ta-61 差分 + red ログ | agent | 中 | 🚩 |
| S3 | helper `_pg_extra_resolve_mode` へ direct-exec ガード追加 + F-3 明示検査追加。ヘッダコメントの正本参照を本 plan へ更新。rollback: 当該 2 hunk revert | `_extra-contract.sh` 差分 | agent | 中 | 🚩 |
| S4 | bootstrap 14 箇所（層 A 12 + ta-61 本体 + ta-61 fixture 複製）を Mode resolution v2 ブロックへ同型置換。rollback: `git checkout origin/main -- tests/extras/`（S3 と同一 PR 内で原子的に） | 14 ファイル差分 | agent | 中 | 🚩 |
| S5 | 機械照合 TC 更新（ta-61 の述語一致検査を 15 出現 / 新述語へ）+ F-3 用 TC-32（init 前 finalize → exit 4 + 診断） | ta-61 差分 | agent | 低 | |
| S6 | green 確認: 新 TC + ta-61 全 TC + フルスイート `sh tests/run-tests.sh` rc=0 + 層 A 12 本の清浄 env standalone 実行 | `evidence/test-runs/post-fix-*.log` | agent | 低 | 🚩 |
| S7 | 変異注入（AC-5 (b)）: ガードの call site（case 行）を除去した変異体で TC-30/31 が dash で FAIL することを実証。F-3 検査除去変異で TC-32 FAIL を実証 | `evidence/test-runs/mutation-*.log` | agent | 低 | 🚩 |
| S8 | 4 シェルマトリクス最終実測（dash/zsh/bash/sh × 実測 1/2 シナリオ）+ handoff 対応表 | evidence + handoff 素材 | agent | 低 | |

依存: S1→S2→S3→S4→S5→S6→S7→S8（S3/S4 は同一 commit 推奨 — 述語分裂の中間状態を作らない。
TASK-0921 R-025-2 の原子性要求と同型）。

## Files / Components to Touch

- `tests/extras/_extra-contract.sh`（resolve_mode ガード + F-3 検査 + ヘッダ正本参照）
- 層 A 12 本: `ta-39` `ta-40` `ta-43` `ta-44` `ta-45` `ta-46` `ta-47` `ta-49` `ta-50`
  `ta-51` `ta-52` `ta-53`（bootstrap ブロック同型置換のみ）
- `tests/extras/ta-61-extra-contract.sh`（本体 bootstrap + fixture 複製 + TC-30/31/32 追加 + 述語照合 TC 更新）
- `docs/working/TASK-1044/*`（本パッケージ）
- 触れない: `tests/run-tests.sh` / `tests/extras/README.md` は必要最小の追記のみ検討
  （規約 8 に direct-exec ガードの 1 行言及。exec 時に要否判断）

## Testing Strategy

- **Unit（contract TA）**: ta-61 に TC-30/31/32 追加。既存 TC-01〜29 全走で fixture 回帰検出
- **Integration**: `sh tests/run-tests.sh` フルスイート rc=0 / fail=0（source 経路の無回帰）
- **シェルマトリクス**: dash / zsh / bash / sh × {helper 欠落, helper 存在} × 3 env 漏出
  直接実行（AC-1 / AC-2。TC 本体は dash 固定、マトリクスは evidence 実測）
- **変異注入**: (a) pre-fix HEAD で新 TC red（検出力の事前実証）。
  (b) call site 破壊変異（case 行除去 / F-3 検査除去）を dash で走らせ kill 実証
  — 変異は関数でなく call site を壊す（#874 教訓）
- **機械照合**: 新述語 2 行の 15 出現バイト一致を grep ベースで TC 化（AC-4。
  絶対件数でなく「照合対象リストとの同値」で書き、成長ディレクトリの件数固定を避ける）

## Risks & Mitigations

| リスク | 影響 | 緩和 |
|---|---|---|
| ta-61 sandbox 系 TC（TC-14〜17/29）が旧 bootstrap 前提で fixture を照合しており、置換で赤くなる | 中 | S2 前に ta-61 全走 baseline。fixture 複製も同時置換（S4 に含む） |
| zsh が runner として使われた場合 FUNCTION_ARGZERO で source 先 `$0` が変わり harness 判定が standalone へ落ちる | 低（runner は sh 前提） | Constraints に明記 + README 規約に 1 行追記検討。挙動は「余計に standalone に倒れる」= fail-safe 方向 |
| `ta-*.sh` 命名規約外の将来ファイルにはガードが効かない | 低 | 規約は ta-61 の marker 検査が既に強制。README 規約に依存を明記 |
| 述語変更の中間 commit で bootstrap / helper が分裂 | 中 | S3/S4 同一 commit（原子性、R-025-2 同型） |
| exit 4（init 前 finalize）が harness source 経路で runner を止める | 低（TC-10 が CI で静的 block 済） | Q-1 として C-3 裁定に明示。代替案（return 0 + fail 加算）との比較を提示済み |

## Questions / Unknowns

- **Q-1（要 C-3 裁定）**: F-3 の init 前 finalize を「exit 4 fail-closed（runner 巻き添え許容）」
  とするか「harness では fail 加算 + return 0（runner 保護優先・ただし standalone 直接実行では
  依然 rc=0 で漏れる）」とするか。plan は前者を推奨（本 PBI の主題 =「静かに通さない」と整合、
  かつ TC-10 静的検査が通常運用での到達を防ぐ）
- **Q-2**: README 規約 8 への追記要否（exec 時に判断、どちらでも AC 影響なし）

## Mode 判定

**モード**: high-risk

**判定根拠**（`.claude/rules/mode-classification.md` 準拠）:

- 変更ファイル数: 14（helper 1 + 層 A 12 + ta-61）→ **high-risk**（6-15）
- 受入基準数: 7 → **high-risk**（6-10）
- タスク数（見込み）: 8 Step ≒ 10-14 タスク → high-risk 帯
- 変更種別: テスト検証基盤（失敗検出力）の修正。機械的な同型置換が主体だが、
  誤ると「テストが静かに通る」方向へ壊れる → 定性 **high**
- 影響範囲: tests/extras 全体（複数ファイル・runner との契約面）→ high
- Hardening Override 対象パス: **非該当**（`tests/extras/` / `docs/working/` のみ。
  9 カテゴリのいずれにも一致しない）
- セキュリティ / スキーマ / 破壊的変更: 非該当
- **最終判定**: **high-risk**（定量・定性とも high-risk。オーバーライドなし）

high-risk のため: C-2 外部レビュー必須・**人間 C-3 必須（autonomous APPROVE 不可）**・
V-2 / V-3 実行・todo の実装タスクに rollback 必須。
