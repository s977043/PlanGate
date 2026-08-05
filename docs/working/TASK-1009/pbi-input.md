# PBI INPUT PACKAGE — TASK-1009

> 対象 issue: [#1009](https://github.com/s977043/PlanGate/issues/1009)（P1 / bug）
> 由来: PR #986（`0ebb8fe`）の **V-2 / V-3 事後補完**。TASK-0914 は Mode=high-risk のため V-2 / V-3 が必須だったが、実施前にマージされていた（`docs/working/TASK-0914/handoff.md` §5 に事実として記録済み）。

## Context / Why

`scripts/sync-plugin-plangate.sh` の経路2（ai-loop references）の base 算出が **未 quote 展開**のため、正本ファイル名にスペースが 1 つでも含まれると base が過大化し、**mass-delete guard が静かに fail-open する**（WARN なし・exit 0 で削除が通る）。

```sh
# scripts/sync-plugin-plangate.sh:370-376
# 要素数の算出は意図的な未 quote 展開（スペース区切りのワード分割）。後段に
# 位置パラメータの使用（$@ / shift / set --）が無いことは確認済み（U-2。
# $1 の --dry-run 判定は冒頭で消費済み）。
set -- $_ai_loop_expected_refs
_ai_loop_ref_base_count=$#
```

`stale > base` は本スクリプト**唯一の安全判定**であり、その入力が壊れている。

### 過去の判定を撤回する

本箇所は #914 の River Review で **F-5「info / 対処不要（対象が repo 管理下 docs ファイル名のため実害窓は無視できる）」** と判定され、`docs/working/TASK-0914/handoff.md` §2 にもその判定で記録された。

**この判定は誤りだった。** F-5 は glob メタ文字だけを見ていたが、**glob は CWD 依存である一方スペースは CWD に依存せず常に効く**。実害窓は当時の評価より広い。

### なぜ 3 件を 1 PBI に統合するか

V-2 / V-3 が独立に出した以下 3 件は**すべて同じ base 算出箇所（L370-376 とその周辺）に帰着する**。別 PBI に割ると同じ行を 2 回別方針で触ることになり、後から入った方が前を壊す。

| 出自 | 内容 |
|------|------|
| **V3-01（major / #1009）** | 未 quote 展開による fail-open |
| **V-2 H-3** | `set --` による**位置パラメータ破壊**の除去（現行は「以降で `$@` を使わない」という不可視の前提を 3 行のコメントで守っている） |
| **V-2 H-2** | 経路1 の base 集計をコピーループへ統合し、**2 重走査と「コメントで整合を約束する構造」を排除** |

H-2 を含めるのは、経路1 と経路2 で **base 算出の作法を揃える**ため。片方だけカウントループ化すると非対称が残り、次の変更者がどちらに倣うか判断できない。

## What (Scope)

### In scope

1. **経路2 の base 算出を CWD / IFS 非依存にする**（#1009 の本体）
   - 採用案の候補（plan で確定）:
     - (a) `set -f; set -- $var; set +f` → glob のみ封じる。**スペースは残るので不十分**
     - (b) **経路1 と同じカウントループで数える**（推奨。位置パラメータ破壊も同時に解消 = H-3 を包含）
     - (c) 関数スコープのカウンタへ委譲（`_count_words() { _words_n=$#; }`。POSIX sh の関数は位置パラメータが関数内スコープ）
2. **経路1 の base 集計をコピーループへ統合**（H-2）
   - 現行はコピーループ（L175-）と base 集計ループ（L197-202）が同じフィルタ（`*.md` glob + `[ -f ]` + `[ -L ]` 除外）で 2 回走る。**その一致はコメントによる約束でしか担保されていない**
3. **スペース / glob メタ文字を含む正本ファイル名の TC を追加**し、変異注入で検出力を実証する
4. `docs/working/TASK-0914/handoff.md` §2 の **F-5 判定（info / 対処不要）を撤回**し、本 PBI / #1009 を参照する

### Out of scope

| 項目 | 追跡先 |
|------|--------|
| 経路1 の dst 側 symlink 非対称（fail-open） | **#970** |
| 経路1 の src 側 symlink 逆非対称（fail-closed）・`_mass_delete_blocked` の入力不正 fail-open・override の blast radius・TC-13 連鎖 FAIL | **#1011** |
| `nolink` / `basewiden` 変異が 30 TC を通り抜ける | **#1010** |
| TC-33 検査(1) の空振り | **#994** |
| 規約 8 の例示と検査器の不整合 | **#1004** |
| extras standalone の exit code 伝播 | **#921** |
| **V-2 H-1（TC-13 の子で #914 TC 群をスキップ）** | **本 PBI 対象外**。テスト意味論の変更（子のカバレッジが狭まる）を伴い、production code に触らないため別 PBI が適切 |

## 受入基準

- [ ] **AC-1**: 正本ファイル名にスペースが含まれても base が実体と一致する。下記 A/B の「スペース入り」ケースで guard が発火し `rc=3`・stale が保全される
- [ ] **AC-2**: 正本ファイル名に glob メタ文字（例 `*.md` というファイル名）が含まれても同様に base が実体と一致する
- [ ] **AC-3**: 経路1 の base 算出が**コピーと同一走査**になり、フィルタ条件の乖離が構造的に起きない
- [ ] **AC-4**: `set --` による位置パラメータ破壊が経路2 から除去される（呼び出し側の `$@` が保存される）
- [ ] **AC-5**: 上記 AC-1 / AC-2 に対応する TC を `tests/extras/ta-26-plugin-sync.sh` へ追加し、**修正前の実装に対して FAIL する**ことを変異注入で実証する（空振り fixture を作らない）
- [ ] **AC-6**: 既存 30 TC がすべて PASS を維持し、実リポジトリの `--dry-run` 出力が変更前と**完全一致**する（動作不変の証明）
- [ ] **AC-7**: `docs/working/TASK-0914/handoff.md` §2 の F-5 判定を撤回し、本 PBI / #1009 を参照する
- [ ] **AC-8**: フルスイート `sh tests/run-tests.sh` が **0 failed**（総数は基点依存のため契約値にしない — TASK-0914 handoff §2 鮮度の運用に従う）

## Notes from Refinement

- **`scripts/sync-plugin-plangate.sh` の素実行は禁止**。検証は必ず sandbox 経由（`mktemp -d` + `git archive`）。TASK-0914 handoff §5「触れないでほしいファイル / アンチパターン」に明記された既存規約
- **guard 3 経路の等価性は V-3 で実証済み**（argswap / staleoff1 / stale0 変異がすべて kill された）。本 PBI で共通関数 `_mass_delete_blocked()` の**引数順・戻り値規約は変更しない**
- `stale == base` の非発火は**意図した仕様**（TC-34 で境界固定・変異 M-6b で実証済み）。本 PBI で境界を動かさない
- extras 11 本の standalone preamble の重複は**意図的な設計**（TC-33 が各ファイル内の `unset` 行を静的走査するため、共通化すると TC-33 が FAIL する）。触らない

## Estimation Evidence

### Risks

| リスク | 内容 | 緩和 |
|-------|------|------|
| **高** | guard の安全判定に触るため、誤ると mass-delete 事故が再発する（#877 の実害と同型） | 動作不変を dry-run 出力の完全一致で証明。変異注入で検出力を実証 |
| **中** | 経路1 の base 算出をコピーループへ統合する際、`_refs_base_count` が未設定になる経路を作りうる | コピーループが先に `mkdir -p "$_dst_refs"` するため `[ -d "$_src_refs" ]` が真なら guard ブロックにも入る、という含意を TC で固定 |
| **中** | H-2 / H-3 の同時変更で、どちらが原因かの切り分けが難しくなる | Work Breakdown を経路2（AC-1/2/4）→ 経路1（AC-3）の順に分け、各段でチェックポイントを置く |
| **低** | `_count_words` 方式を採る場合、shell 実装差で挙動が変わる | V-2 が `/bin/sh`（bash 3.2）/ `/bin/dash` / `/bin/bash` の 3 実装で位置パラメータ保存を実測済み |

### Unknowns

- 案 (b)（カウントループ）と (c)（関数スコープ）のどちらを採るか。**plan 段階で確定する**
  - (b) は経路1 と作法が揃うが、期待集合が「文字列」でなく「ディレクトリ走査」由来になるため `_ai_loop_expected_refs` の生成箇所（L286-307）との整合を確認する必要がある
  - (c) は既存構造を最小変更で守れるが、「スペース区切り文字列を要素数に変換する」という設計自体は残る
- `_ai_loop_expected_refs` を**文字列でなくファイルリストとして持つ**設計変更まで踏み込むか（踏み込むと scope が広がるため、原則 Non-goal）

### Assumptions

- 現行 main の正本 2 ディレクトリにスペース / glob 文字を含む名前は**存在しない**（実測済み）。したがって**本 PBI は潜在バグの是正であり、進行中のデータ損失を止めるものではない**
- `scripts/sync-plugin-plangate.sh` は Hardening Override 対象パス**外**（`scripts/hooks/*.sh` に該当しない）。ただし **guard の安全判定に触るため Mode は high-risk 相当**とし、`lite_eligible=false` / 同期 C-3 を前提とする

## Mode 判定（暫定・plan で確定）

判定結果: **high-risk**

| 判定軸 | 値 | 根拠 |
|-------|---|------|
| 変更ファイル数 | 3〜4 | `sync-plugin-plangate.sh` / `ta-26-plugin-sync.sh` / TASK-0914 handoff / 本 PBI の status 等 |
| 受入基準数 | 8 | AC-1〜AC-8 |
| 変更種別 | **code**（実行系スクリプト + テスト） | doc-light 不適用 |
| リスク | **高** | mass-delete guard の安全判定そのもの |
| ロールバック | 計画的に必要 | `git revert` 1 手で戻せるが、戻すと fail-open が復活する |

**autonomous APPROVE 不可 / 人間 C-3 必須**（`.claude/rules/working-context.md` の判定マトリクス: Mode=high-risk → ❌ 不可）。

## 参照

- issue: [#1009](https://github.com/s977043/PlanGate/issues/1009)（本体）/ [#1010](https://github.com/s977043/PlanGate/issues/1010) / [#1011](https://github.com/s977043/PlanGate/issues/1011)（同時に起票した V-3 の残り）
- 先行 PBI: `docs/working/TASK-0914/`（plan / handoff / status / test-cases）
- 先行 PR: [#986](https://github.com/s977043/PlanGate/pull/986)（`0ebb8fe`）/ [#996](https://github.com/s977043/PlanGate/pull/996) / [#999](https://github.com/s977043/PlanGate/pull/999) / [#1001](https://github.com/s977043/PlanGate/pull/1001)
- 前段: [#877](https://github.com/s977043/PlanGate/issues/877)（mass-delete guard の fail-closed 化）
