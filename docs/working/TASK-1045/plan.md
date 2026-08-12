# EXECUTION PLAN — TASK-1045

> Issue: [#1045](https://github.com/s977043/plangate/issues/1045)
> 入力: [`pbi-input.md`](./pbi-input.md)（266 行 / 受入基準 13 件）
> base: `origin/main` = `6089e23`
> 由来: **#1042 の後続**（EH-13 導入直後に検出） / 関連: **#1023**（EH-13 実装元）

## 記法規約（pbi-input N-8 の踏襲）

本 PBI の修正がマージされるまでは、**本ドキュメント自身が誤 block の対象になりうる**。
したがって以下を用いる。

- `<TOKEN>` … `scripts/check-approval-token-write.sh` の `_is_token_path()` が一致と判定する
  パス（承認 artifact / maintenance artifact / 親 PBI 承認 artifact の JSON 群）。
- トークンパスの **literal は地の文に書かない**。test-cases 側で **フィクスチャ変数**として扱う。
- 調査コマンドは「トークンパス literal」と「`2>/dev/null` 等」を**同一コマンドに書かない**
  （書くと調査コマンド自体が block される＝本件の症状）。

---

## Goal

`scripts/check-approval-token-write.sh` の `_has_write_intent()` が
**「コマンド文字列に `>` が 1 文字でも含まれれば書き込み意図あり」**と判定している欠陥を修正し、
**fd 複製（`N>&M` / `>&N` / `N>&-`）と `/dev/null` への破棄** を write intent から除外する。
その結果として `<TOKEN>` を対象とする **読み取り専用コマンド（`2>/dev/null` / `2>&1` / `>&2` 付き）が
guard を通過**し、かつ **ファイル宛リダイレクトを含む真の書き込みは引き続き block される**状態にする。
併せて block メッセージに **一致したルールの識別子**を機械可読な形で載せる。

---

## Global Constraints（最上位制約）

> 本節は Work Breakdown / test-cases より**上位**であり、いずれの Step もこれに反してはならない。

### GC-1: ガードを弱めるのではなく「判定を正確にする」

本 PBI の目的は **判定精度の是正**であり、**防御範囲の縮小ではない**。
**除外を追加した結果として、書き込み可能な記法が 1 つでも通るようになってはならない。**
これは pbi-input の Non-goals と一致し、R-1（ガード弱体化 = critical）に対する最上位の歯止めである。
機械的な担保は AC-04〜07 の退行 TC と **AC-09 の「弱める側の変異」**（§Testing Strategy）で行う。

### GC-2: 完全なシェル構文解析は行わない（保守的側に倒したまま除外する）

クォート・変数展開・`eval`・ヒアドキュメント・プロセス置換まで正確に解釈するのは
**コストに見合わず、パーサ自体が新たな bypass 面になる**。
したがって本 PBI は **fail-closed（保守的側）に倒したまま、
「明らかに書き込みではない記法」だけを列挙的に除外する**方針を採る。

**取りこぼし（block されたままでよい＝誤検知として扱わない）**:

- 文字列リテラル中の `>`（例: `echo 'a > b'`）
- ヒアドキュメント本文中の `>`
- 変数展開の結果として現れる `>`

**除外の設計原則**: 「除外リストへの追加は列挙的（allowlist）であり、
判定の緩和（`>` の一般的な無効化）ではない」。

### GC-3: T1023-TC-09 が設計方向を拘束する（pbi-input N-4）

既存 `T1023-TC-09` のフィクスチャは `cat <TOKEN> && echo hi > /tmp/other.txt` であり、
**`cp` / `tee` / `mv` を含まないため `>` 検査だけが唯一の捕捉経路**である
（実測: `tests/extras/ta-25-approval-token-guard.sh:83`, `375-381`）。

したがって、

- ❌ **禁止方針**: 「`>` を token path 宛のときだけ block する」→ **TC-09 が退行 FAIL する**
- ✅ **採る方針**: 「**任意のファイル宛リダイレクトは block 維持**、
  **fd 複製と `/dev/null` 破棄のみ除外**」

### GC-4: `_t25_mutate` の 2 つの機構制約（pbi-input N-3 / #874 と同型の失敗回避）

`tests/extras/ta-25-approval-token-guard.sh` の `_t25_mutate`（`629-660` 行）は次を要求する。

| 制約 | 内容 | 破ったときの症状 |
|---|---|---|
| **(a) アンカー一意** | 変異対象アンカーの `grep -c` が **ちょうど 1**（`634` / `639-642` 行） | `[FAIL] ... mutation anchor not unique` |
| **(b) focused 群配置** | kill 判定は `PG_T25_MUTATION_CHILD=1` の子プロセスで **focused kill TC 群のみ**を実行する（`47` 行 / focused 群 = `102-221` 行 / 通常群 = **`222` 行 `if [ "$PG_T25_FOCUSED" = "0" ]` 〜 `687` 行 `fi`**）。**focused 群の外に置いた TC は子プロセスで実行されず kill が実証されない** | `mutant NOT killed by <label>`（= 検出力の空振り。#874 既往と同型） |
| **(c) ラベル prefix ハードコード** | `_t25_mutate` は出力ラベルを **`T1023-$_t25_mid` とハードコード**している（`640` / `644` / `648` / `656` / `658` 行 = **5 箇所**。呼び出しは **7 箇所**） | `mid="TC-09"` を渡すと出力が `T1023-TC-09` になり **既存の `T1023-TC-09`（mixed command）とラベル衝突**する → §W-4 対応 |

### GC-4-A: focused 群へ置く TC 集合（**単一の正**）

> **本節が focused 群配置の唯一の正本**。plan / test-cases / todo の他の記述は本節を参照し、
> 独自に別集合を書かない（4 箇所の不一致を防ぐ）。

**focused 群（`ta-25:222` より前）に置く TC = `T1045-TC-01`, `TC-02`, `TC-03`, `TC-04`,
`TC-05`, `TC-06`, `TC-20` の 7 件。**

**根拠**: 変異の kill 対象になる TC はすべて focused 群に必要であり、
この 7 件は **本 PBI が変更する唯一のコードパス（正規化 + 残存 `>` 判定）を直接叩く TC 集合**
＝変異 (a)(b) の kill 対象（`TC-01` / `TC-04`）と、**同一コードパスを共有し変異で連鎖 FAIL する
ことを実測確認する対象**（`TC-02` / `TC-03` / `TC-05` / `TC-06` / `TC-20`）である。

**通常群に置く TC = `T1045-TC-07`〜`TC-19` + `TC-21` + `TC-22` の 15 件**（変異の kill 対象ではない）。
とくに `TC-07`（併記回避）は変異 (b) 適用下でも `copy-like` ルールで block され続けるため
**kill 対象になり得ず、focused 群に置く必要がない**。

**副作用の確認（安全性）**: focused 群の TC は既存 mutation 7 種の子プロセスでも実行される。
うち **変異 1（`TC-15`: block を `exit 2`→`exit 1`）では `T1045-TC-04`〜`06` も併せて FAIL する**が、
`_t25_mutate` の kill 判定は **`grep -q "[FAIL] $_t25_kill"`（特定ラベルの存在）**であり
「当該ラベルのみが FAIL」を要求しないため（`ta-25:655`）、**既存 mutation 7 種の判定は壊れない**。
この点は Step 2 のチェックポイントで実測確認する。

### GC-4-C: RED ウィンドウの期待 FAIL 集合（**R-001 / C-2 両レーン一致**）

> **C-2 の重要な訂正**: 筆者は当初「壊れるのは既存 mutation 7 種」を警戒していたが、
> **RED 中に実際に FAIL するのは `T1023-TC-15pre` / `T1023-TC-17post` の 2 件**である。
> 整合レーンが実走で再現した（`45 passed, 3 failed` / EXIT=1）。

**機構**: `ta-25:621-627`（baseline）と `ta-25:676-684`（restore）は
**原本 guard で focused 群を子実行し「rc==0 かつ `[FAIL]` 0 件」を要求**する。
RED ウィンドウでは focused 群に FAIL する TC が存在するため、**この 2 件が必ず FAIL する**。

#### RED ウィンドウ（Step 2 完了〜Step 3 完了の間）の**期待 FAIL 集合 = 6 件**

| ラベル | RED 中の期待 | 根拠 |
|---|---|---|
| `T1045-TC-01` | FAIL | 誤検知解消 TC（未実装のため落ちるのが正しい） |
| `T1045-TC-02` | FAIL | 同上 |
| `T1045-TC-03` | FAIL | 同上 |
| `T1045-TC-20` | FAIL | 同上 |
| **`T1023-TC-15pre`** | **FAIL** | baseline が focused 群の `[FAIL]` を検出するため（`ta-25:623`） |
| **`T1023-TC-17post`** | **FAIL** | restore が同様に検出するため（`ta-25:680`） |

**この 6 件は RED ウィンドウにおいて `SC-1` / `SC-4` の対象外**とする（誤発火防止）。
**それ以外のラベルが FAIL したら `SC-1` を発火**させる。

#### 設計制約の言語化

**「focused 群には、無変異 guard 下で恒久的に FAIL する TC を置けない」。**
`ta-25:621-627` / `676-684` が focused 群の全 PASS を前提にしているため。
**本 PBI は Step 3（GREEN）完了後に focused 群が全 PASS へ戻るので設計自体は成立している**が、
将来 focused 群へ TC を追加する際はこの制約を満たすこと。

#### 判定方式（`A-4` / Step 2）

**suite 全体の rc / `0 failed` で判定してはならない**（RED 中は必ず exit 1 になる）。
**`grep -q "[FAIL] <ラベル>"` のラベル単位判定**へ置き換える
（ハーネスの kill 契約 `ta-25:655` と同じ土俵に乗せる）。

補足制約（同 N-3 の 3 / 4）:

- 新 TC も `t25_guard` ヘルパ経由で起動し、guard パスをハードコードしない（`PG_T25_GUARD` override 方式を壊さない）
- **stdin を redirect しない guard 起動を残さない**（`T1023-TC-24` が静的検査する / R-027）

### GC-5: #1023 / #1042 で確定した契約を変更しない（pbi-input N-7）

`exit 2`（PreToolUse block 契約）/ stdin 常時独立評価 / `parse-unknown` fail-closed /
TTY 即 fail-closed / `PLANGATE_SKIP_TOKEN_GUARD`（Human-owned escape hatch）/
`_is_token_path()` の一致範囲 / `Edit`・`Write`・`MultiEdit` レーン
は **本 PBI では一切変更しない**。

### GC-6: POSIX `sh` + BSD/GNU 双方で同一挙動（R-5）

guard は `#!/bin/sh` + `set -eu`。実装は **POSIX BRE / ERE の範囲に留める**。
GNU 拡張（`sed` の `\|` / `\+` / `\b`、`grep -P`）は**使用禁止**。
ローカル（macOS / BSD）と CI（Linux / GNU）の双方で実行結果を evidence に残す。

**locale も固定する（R-007 / C-2 整合レーン）**: 方言だけでなく **locale も挙動を変える**。
BSD `sed` は UTF-8 locale 下で不正バイト列に対し
`RE error: illegal byte sequence` を返して**失敗する**（**実測 rc=1**）。
一方 `LC_ALL=C` では**同入力で rc=0**（実測）。
したがって **正規化パイプラインは `LC_ALL=C` 固定で実行する**。
これは GC-8 の fail-closed 要件を**発火させにくくする緩和**でもある
（ただし `LC_ALL=C` は緩和であって代替ではない。**GC-8 の 3 要件はすべて必須**）。
Step 1b の方言比較実験も **`LC_ALL=C` を実験条件に含める**。

### GC-8: 正規化ヘルパは **fail-closed** で持ち込む（**R-002 / C-2 整合レーン・実走再現**）

> **GC-1（弱体化禁止）の具体化**。本節に反する実装は critical 相当として扱う。

**問題**: 現行 `_has_write_intent()` は全ルールが
`printf … | grep -q … && return 0` の **AND-list** で、`grep` の非 0 は「不一致」という
**正しい意味**を持つ。一方、plan の正規化方式は
`_wc_n=$(printf … | sed …)` という**コマンド置換の代入**であり、意味論が異なる。

呼び出し側は `check-approval-token-write.sh:136` の
`if _is_token_path "$_cmd" && _has_write_intent "$_cmd"; then` であるため、
**`if` 条件内では `set -e` が無効**。したがって
**`sed` の失敗は「異常終了」ではなく「書き込み意図なし」として静かに扱われ、ALLOW になる**。

**実測（本 plan 反映時に筆者が独立再現。scratchpad のみ・`scripts/` 未変更）**:

| 条件 | 結果 |
|---|---|
| `sed` 相当が失敗する状態で `printf x > <TOKEN>` を判定 | **ALLOW（rc=0）/ stderr 出力なし**。`set -e` でも中断しない |
| `LC_ALL=en_US.UTF-8` + 不正バイト列を BSD `sed` へ | **rc=1** `sed: RE error: illegal byte sequence` |
| `LC_ALL=C` + 同入力 | **rc=0**（成功） |

**この repo の確立パターンからの逸脱**: 外部依存はすべて `command -v` で守られ、
不在は明示処理される（`check-approval-token-write.sh:97` の `jq` /
`check-plan-hash.sh:35` / `check-delegation-commit-boundary.sh:114`）。
**`sed` にだけこの守りが無い状態は、#1023 が塞いだ「parse fail-open」と同一クラス**であり、
**GC-5（#1023 契約を変更しない）にも抵触**する。

**到達経路について**: stdin レーンからの誘発は **未実証**
（`jq -r` が不正 UTF-8 を U+FFFD へサニタイズするため。整合レーンが追試）。
**しかし守るべきは「到達経路が今は無い」ではなく「弱める側へ倒れる形をそもそも作らない」**
であり、これは GC-1 が最上位制約として掲げている内容である。

#### 必須実装事項（Step 3 / A-5a・A-5b で満たすこと）

1. **正規化の失敗は元文字列へフォールバック（fail-closed）**:
   `_wc_n=$(…) || _wc_n="$_wc"` の形にし、
   **正規化できなければ元文字列で判定する = block 維持**とする
2. **`sed` の存在検査を `jq` と同じ契約に揃える**:
   guard 起動時に `command -v sed >/dev/null 2>&1 || _parse_unknown "sed not available"` を追加
3. **正規化パイプラインは `LC_ALL=C` 固定で実行する**（R-007。locale 依存の失敗を除去）

**変異では検出されない点に注意**: 変異 (b) は `# t1045-file-redirect` の判定行しか壊さず、
`SC-6` も境界 TC の rc=0 しか見ていない。**したがって専用の TC（`T1045-TC-22`）が必要**。

### GC-7: 変更対象の限定

変更は **`scripts/check-approval-token-write.sh`** と
**`tests/extras/ta-25-approval-token-guard.sh`** の 2 本 + 本 PBI の working context に限る。
`.claude/` 配下（settings 含む・Human-owned）/ `bin/plangate` / `.github/workflows/` / `schemas/`
は触らない。

---

## Non-goals

- ガードを弱めること（GC-1）
- コマンド文字列の完全なシェル構文解析（GC-2）
- `_is_token_path()` の判定範囲の変更
- 他の write intent ルール（`cp` / `mv` / `ln` / `install` / `dd` / `tee` / `truncate` /
  `patch` / `apply_patch` / `ed` / `ex` / `git checkout|restore|checkout-index|update-index` /
  `sed -i` / `perl -i` / python・node・ruby の書き込み API）の見直し
- EH-13 の採番・配線そのもの（#1042 で確定済み）
- `.claude/settings*.json` への配線変更（Human-owned）

---

## Approach Overview

`_has_write_intent()` の先頭にある

```text
printf '%s' "$_wc" | grep -q '>' && return 0
```

を、**「非書き込みリダイレクト記法を除去してから残った `>` を見る」**2 段構成へ置き換える。

1. **正規化**（新規ヘルパ `_strip_nonwrite_redirects()`）
   - (1) **fd 複製 / fd クローズ**を除去: `N>&M`（`2>&1`）/ `>&M`（`>&2`）/ `N>&-`（`3>&-`）
     - **`>&` の直後が「数字列」または `-` の場合のみ**除去する。
       `>&<ファイル名>`（例: `>& /tmp/x`）は **除去しない = block 維持**（R-4）
   - (2) **`/dev/null` への破棄**を除去: `N>` / `N>>` の直後（空白許容）が `/dev/null` で、
     **かつ後続が語境界**（空白 / `;` / `&` / `|` / `)` / 文字列末尾）のとき
     - `>/dev/nullX` / `>/dev/null/../<TOKEN>` は語境界を満たさず **除去されない = block 維持**（R-3）
     - **直前の文字が `&` のときは除去しない**（`&>` / `&>>` は U-2 の決定により block 維持）
2. **判定**: 正規化後の文字列に `>` が残っていれば **ファイル宛リダイレクト**とみなし write intent。

**この方向は GC-3 を満たす**: `cat <TOKEN> && echo hi > /tmp/other.txt` は
`> /tmp/other.txt` が `/dev/null` でも fd 複製でもないため `>` が残り、**block が維持される**。

### 実現可能性の実測（plan 段階の feasibility 検証 / `scripts/` は未変更）

正規化ロジックだけをスクラッチパッドの独立スクリプトへ切り出し、
**macOS / BSD `sed` + POSIX BRE のみ**で 26 ケースを実行した結果、
**期待どおりの分類 26/26**（誤検知 10 件がすべて `nowrite`、退行防止 16 件がすべて `write`）。
`/dev/nullX` / `/dev/null/../<TOKEN>` / `&>` / `>&<file>` / `/dev/stdout` / `/dev/stderr` /
`/dev/fd/3` / 文字列リテラル中の `>` はすべて `write`（block 維持）側に落ちた。
実装は exec で改めて TDD で行い、本結果は**方向の妥当性の裏付け**として扱う（実装確定ではない）。

### GC-4-B: `_t25_mutate` のラベル衝突とその解消（**採用案 = (a)**）

`_t25_mutate` は出力ラベルを **`T1023-$_t25_mid` とハードコード**している（`ta-25` の
`640` / `644` / `648` / `656` / `658` = **5 箇所**。**実測確認済み**）。
したがって `mid="TC-09"` を渡すと出力は `T1023-TC-09` となり、
**既存の `T1023-TC-09`（mixed command / `ta-25:375-381`）とラベルが衝突する。**

> **kill 判定そのものは壊れない**。`_t25_mutate` は `grep -q "[FAIL] $_t25_kill"` で判定し、
> `_t25_kill` には `T1045-TC-01` / `T1045-TC-04` を渡すため一意である（`ta-25:655`）。
> **問題は出力ラベルの一意性**（人間 / CI がログを読むときの同定不能）である。

| 案 | 内容 | 採否 | 理由 |
|---|---|:--:|---|
| **(a)** | `_t25_mutate` に **label prefix 引数を追加**（`_t25_mutate <tc-id> <sed> <anchor> <kill-label> [prefix]`、`prefix=${5:-T1023}`） | **✅ 採用** | **既存 7 箇所の呼び出しは 4 引数のまま無変更で動く**（デフォルト `T1023` にフォールバック）。**変異ドライバが 1 本のまま**なので、anchor 一意 / sed miss / syntax / kill 判定の 4 安全チェックが新旧で共有される |
| (b) | 独自の変異ドライバを別途書く | ❌ 不採用 | 上記 **4 つの安全チェックを複製**することになり、新ドライバだけが弱くなる / 将来ドリフトする риск が高い。検出力の担保機構を二重化してはならない |
| (c) | `mid="1045-TC-09"` を渡す（出力 `T1023-1045-TC-09`） | ❌ 不採用 | コード変更ゼロだが、**`T1023-` を冠したまま `1045` を名乗る**ため provenance が誤り。ログ読解時にどの PBI の変異か判断できない |

**(a) の実装制約**:

- 呼び出しは **7 箇所**（`ta-25:662, 664, 666, 668, 670, 672, 674`。**実測確認済み**。
  なお `T1023-$_t25_mid` の**ラベル出現は 5 箇所**であり、両者の件数は異なる）
- 既存 7 箇所は **4 引数のまま変更しない**（互換維持を Step 5 のチェックポイントで実測）
- 新規 2 件は第 5 引数に `T1045` を渡し、出力ラベルを **`T1045-TC-09` / `T1045-TC-10`** にする
- `_t25_mutate` 自体の変更は `tests/extras/ta-25-approval-token-guard.sh` 内に閉じる（GC-7 を満たす）

### block メッセージのルール識別子（AC-10 / U-3）

`_has_write_intent()` を **「真偽を返す」から「一致したルール ID を副作用変数に置いて真偽を返す」**へ拡張し、
`_block()` の detail に `rule=<id>` を付与する。ID は以下の**短い機械可読タグ**とする。

| rule ID | 対応ルール |
|---|---|
| `file-redirect` | 正規化後に残ったファイル宛 `>` / `>>` |
| `copy-like` | `cp` / `mv` / `ln` / `install` / `dd` / `tee` / `truncate` / `patch` / `apply_patch` |
| `line-editor` | `ed` / `ex` |
| `git-restore` | `git checkout` / `restore` / `checkout-index` / `update-index` |
| `inplace-edit` | `sed -i` / `perl -i` |
| `lang-write` | python / ruby / node の書き込み API |

detail 文字列は `Bash command writes token path (rule=<id>): <cmd>` の形とする
（`writes token path` を**残す**ことで既存の読解性を保ちつつ根拠を追加。
読み取りコマンドは AC-01〜03 により **そもそも block されなくなる**ため N-6 の問題は解消する）。

---

## AC の適用範囲宣言（**R-006 / `pbi-input.md` は確定物のため編集しない**）

C-2 設計レーンの指摘: **Goal と Approach は `N>&-`（fd クローズ）を除外対象に含むが、
`pbi-input.md` の AC-03 の文面は「`>&2`（fd 複製）」止まり**である。
**除外面（＝危険な方向）が AC の外側で拡張**されており、
このままでは **C-4 レビュアーが「何を承認したのか」を判別できない**。

`pbi-input.md` は main に確定済みで編集しないため、**plan 側で適用範囲を宣言する**:

> **AC-03 の適用範囲を「fd 複製（`N>&M` / `>&N`）**および**fd クローズ（`N>&-`）」と読む。**
> 対応 TC は `T1045-TC-03`（fd 複製）と **`T1045-TC-20`（fd クローズ）**の 2 件。

**この宣言は AC を緩めるものではなく、除外面を AC の内側へ引き戻して
承認範囲を可視化するもの**である（緩和ではなく明示化）。
C-3 で人間がこの範囲を承認したことをもって、`N>&-` の除外が承認範囲に入る。

## 未決事項の確定（pbi-input Unknowns の処理）

| ID | 未確定事項 | **plan での確定** | 根拠 / 備考 |
|---|---|---|---|
| **U-1** | `/dev/stdout` / `/dev/stderr` / `/dev/fd/N` を除外に含めるか | **含めない（block 維持）。除外は `/dev/null` のみ** | `/dev/stdout` 等はリダイレクト文脈によっては実ファイルを指しうる。GC-1（弱体化禁止）の安全側。TC-1045-11 で固定 |
| **U-2** | `&>` / `&>>`（bash 拡張の全出力リダイレクト）の扱い | **書き込みとして block 維持**（宛先が `/dev/null` でも除外しない） | pbi-input の既定を採用。除外面を最小化し bypass 面を増やさない。**残存誤検知（`&>/dev/null` 付き読み取り）は既知の制約として handoff に明記**し、必要なら follow-up issue |
| **U-3** | ルール識別子の具体フォーマット | **`rule=<id>` を既存 detail に追記**（上表の 6 ID） | **実測確認済み**: `grep -rn "writes token path" tests/ docs/ scripts/` の結果、`tests/` にヒットは **0 件**（メッセージ本文を assert している既存 TC は存在しない）。既存の assert は `BLOCK` / `target=` / `file_path=` / `parse-unknown` / `bypass` のみ。よって detail 文字列の変更は既存 TC を壊さない |
| **U-4** | 最終 Mode / `lite_eligible` | **`critical` / `lite_eligible=false`**（§Mode 判定） | 定量軸（受入基準 13 件）+ 安全側 |
| **U-5** | settings 配線への反映に再適用が要るか | **不要**。`.claude/settings.example.json:72,81` は `sh ${CLAUDE_PROJECT_DIR}/scripts/check-approval-token-write.sh` と**スクリプトパスを呼ぶ**配線のため、スクリプト本体の修正は**再適用なしで即時反映**される。settings 自体は変更しない（Human-owned / GC-7） | 実測: `grep -n "check-approval-token-write" .claude/settings.example.json docs/ai/settings-wiring-contract.md` |
| **U-6** | 同種の粗い `>` 判定が他の `scripts/` に存在するか | **存在しない（実測 1 件のみ）**。`scripts/` / `bin/` 横断で `grep -q '>'` 相当は `scripts/check-approval-token-write.sh:48` の **1 箇所のみ**。`tool_input.command` を解析する他の 3 本（`scripts/check-git-destructive.sh` / `scripts/hooks/check-delegation-commit-boundary.sh` / `.codex/hooks/eh-bridge.sh`）に `>` ベースの write-intent ヒューリスティクスは **無い** | Step 1 で **base 更新時に再実行**して確定させる（横断調査は Work Breakdown の Step 1 に配置）。**万一検出された場合も本 PBI の scope には入れず follow-up issue として起票**する |

---

## Work Breakdown

> 各 Step の `rollback:` は **high-risk / critical の実装タスクで必須**（working-context.md）。
> Mode = `critical` のため **全実装タスクに記載**する。

### Step 1: 現状固定と横断調査（RED の前提整備）

- **Output**: `evidence/verification/baseline.md`（`ta-25` の pass/fail・誤検知再現表・U-6 横断調査結果）
- **Owner**: agent
- **Risk**: low
- **内容**:
  1. `sh tests/extras/ta-25-approval-token-guard.sh` を実行し **baseline を実測記録**
     （起票時実測は **47 passed / 0 failed**。**絶対件数は契約値にせず**、
     「**0 failed かつ pass 数が baseline 以上**」を退行判定条件とする）
  2. `PreToolUse` payload で guard を直接起動し、pbi-input の A〜K 表を **本 PBI 内で再現**
     （payload 生成は「トークン literal を含むが `>` を含まない」スクリプト経由。
     literal とリダイレクトを同一コマンドに書かない）
  3. **U-6 横断調査**: `scripts/` / `bin/` / `.codex/` を対象に、
     コマンド文字列に対する粗い `>` 判定・write-intent ヒューリスティクスを列挙する。
     検出時は **scope に入れず follow-up issue を起票**して plan には記録のみ
  4. **U-3 再確認**: `grep -rn "writes token path" tests/` が 0 件
  5. **RT-2 の (a)(b) を実測**: (a) 他ガードが本ガードを invoke / source していないか、
     (b) 本ガードの複製が `.claude/settings*.json` に実配線されていないか（R-003）
  6. **稼働 settings の実測（i-1）**: `.claude/settings.json`（**Human-owned・gitignore 対象で
     worktree には存在しない**）が `scripts/` 直下を直接呼んでいること、
     および `scripts/hooks/` 側の複製が存在しないことを、**メイン checkout 側で実測**して
     A-1 の調査ログへ 1 行残す（U-5「再適用不要」の根拠を example だけでなく稼働側でも固める）
  7. **R-008 の複製導線を確認**: `scripts/apply-task-0123-patches.sh`（`67-88` 行）が
     `scripts/check-approval-token-write.sh` → `scripts/hooks/…` へ `cp` し
     **既存時はスキップして更新しない**ことを記録（**`GC-7` は維持し本 PBI では触らない**。
     handoff の既知課題 + follow-up issue 起票へ回す）であることを再実測
- **🚩チェックポイント**: baseline が 0 failed であること。0 failed でなければ **exec を止めて人間へ**
- `rollback:` 不要（読み取り・記録のみ。ファイル変更なし）

### Step 1b: GNU `sed` 等価性の**先行**検証（実装前 / W-2 対応で Step 8 から前倒し）

- **Output**: `evidence/verification/sed-dialect-parity.md`
- **Owner**: agent
- **Risk**: medium（ここで割れると設計方針そのものが変わる）
- **内容**: 正規化ロジックの **26 ケースのプロトタイプ**を、
  **BSD `sed`（macOS ローカル）と GNU `sed`（Linux コンテナまたは CI）の双方**で実行し、
  **26 ケースすべての分類が一致する**ことを確認する。`scripts/` は変更せずスクラッチで行う。
  **実験条件に `LC_ALL=C` 固定を含める**（R-007。locale 差を実験の交絡から外す）。
  併せて **`LC_ALL` 未固定時に不正バイト列で `sed` が rc≠0 になること**も観測し、
  GC-8 の fail-closed が必要な根拠として evidence に残す
- **🚩チェックポイント**: **26/26 が両方言で一致**。
  1 件でも異なれば **RT-1 を発火させて exec を停止し C-3 へ差し戻す**（§Stop Conditions）
- **前倒しの理由**: plan 段階の feasibility 検証は **BSD `sed` のみ**で行っており
  （§実現可能性の実測）、GNU 側は未実測。R-5 を**実装前に**退役させないと、
  Step 3 以降の作業がすべて手戻りになる
- `rollback:` 不要（スクラッチのみ。リポジトリ変更なし）

### Step 2: RED — 新規 TC を focused 群へ追加（実装前に FAIL することを確認）

- **Output**: `tests/extras/ta-25-approval-token-guard.sh` に
  **`T1045-TC-01`〜`TC-06` + `TC-20` の 7 件**（**GC-4-A の集合**）を
  **`222` 行の `if [ "$PG_T25_FOCUSED" = "0" ]` より前（focused 群）** に追加
- **Owner**: agent
- **Risk**: medium（GC-4(b) を破ると検出力が空振りする）
- **内容**:
  - 誤検知解消 TC（`T1045-TC-01`〜`03` + `TC-20`）と
    退行防止 TC（`T1045-TC-04`〜`06`）を **focused 群**へ追加
  - **`T1045-TC-07`〜`TC-19` + `TC-21` + `TC-22` は通常群**へ追加（GC-4-A。kill 対象ではない）
  - 全 TC を `t25_guard` ヘルパ経由で起動（guard パスをハードコードしない / GC-4）
  - `T1023-TC-24`（stdin 未 redirect の静的検査）に**新たな違反を作らない**
- **🚩チェックポイント**（**判定は `grep -q "[FAIL] <ラベル>"` のラベル単位**で行う。
  **suite 全体の rc / `0 failed` で判定してはならない** — RED 中は必ず exit 1 になる / GC-4-C）:
  - **RED ウィンドウの期待 FAIL 集合が下記 6 件と完全一致**すること（GC-4-C）:
    `T1045-TC-01` / `T1045-TC-02` / `T1045-TC-03` / `T1045-TC-20` /
    **`T1023-TC-15pre`** / **`T1023-TC-17post`**
    → **この 6 件は `SC-1` / `SC-4` の対象外**。**6 件以外のラベルが FAIL したら `SC-1` を発火**
  - **`T1045-TC-04`〜`06` が PASS** すること（退行防止の基準線）
  - **focused 子プロセス**（`PG_T25_MUTATION_CHILD=1`）で
    **GC-4-A の 7 件すべてのラベルが出力に現れる**ことを目視確認する
    （GC-4(b) の空振り防止 / #874 同型の失敗回避）
  - **既存 mutation 7 種が引き続き PASS** すること
    （**`SC-4` の 7 ラベル列挙**で判定。`TC-15pre` / `TC-17post` は除外）。
    変異 1 の子プロセスで `T1045-TC-04`〜`06` が併せて FAIL しても
    `T1023-TC-15` の kill 判定は成立する（`ta-25:655` はラベル存在判定）
- `rollback:` `git checkout -- tests/extras/ta-25-approval-token-guard.sh`

### Step 3: GREEN — `_has_write_intent()` のリダイレクト検査を置換

- **Output**: `scripts/check-approval-token-write.sh` の `_has_write_intent()` を修正
- **Owner**: agent
- **Risk**: **high**（GC-1 に直結。誤ると承認境界が突破されうる）
- **内容**:
  1. ヘルパ `_strip_nonwrite_redirects()` を追加（fd 複製 → `/dev/null` 破棄 の順に除去）
  2. 正規化呼び出し行に **一意アンカー `# t1045-redirect-normalize`** を付す
  3. 残存 `>` 判定行に **一意アンカー `# t1045-file-redirect`** を付す
  4. POSIX BRE のみを使用（GC-6）。`sh -n` が通ること
  5. **GC-8 の必須実装 3 件**（**省略不可** / R-002）:
     (i) `_wc_n=$(…) || _wc_n="$_wc"` の **fail-closed フォールバック**、
     (ii) 起動時の **`command -v sed` 検査**（`jq` と同契約 = `_parse_unknown`）、
     (iii) 正規化パイプラインの **`LC_ALL=C` 固定**（R-007）
- **🚩チェックポイント**:
  - **アンカー 2 種が `grep -c` == 1 であることを実測**（GC-4(a) / R-6）
  - **`T1045-TC-01`〜`06` + `TC-20`（GC-4-A の 7 件）が全 PASS へ転じる**（GREEN）
  - **`T1023-TC-08` / `TC-09` / `TC-12` / `TC-25` / `TC-26` / `TC-27` が PASS を維持**（GC-3 / AC-11）
  - **`T1023-TC-15pre` / `T1023-TC-17post` が PASS へ戻る**（GC-4-C。
    **RED ウィンドウが閉じたことの機械的確認**。戻らなければ focused 群に
    恒久 FAIL の TC が残っている＝設計制約違反として即停止）
  - **`T1045-TC-22`（`sed` 不在 PATH → `rc=2`）が PASS**（GC-8。
    fail-open が残っていれば `rc=0` で落ちる → **`SC-9` を発火**）
- `rollback:` `git checkout -- scripts/check-approval-token-write.sh`
  （guard は他ファイルに依存を持たない単体スクリプトのため、単独 revert で完全に復元可能）

### Step 4: block メッセージへルール識別子を付与（AC-10）

- **Output**: `_has_write_intent()` がルール ID を返し、`_block()` detail に `rule=<id>` が載る
- **Owner**: agent
- **Risk**: medium（既存 assert への影響 → U-3 で 0 件確認済み）
- **内容**: `rule=` 6 ID の付与 + `T1045-TC-08`（block ケースでの `rule=` assert）を追加
- **🚩チェックポイント**: 既存 TC（`BLOCK` / `target=` / `file_path=` / `parse-unknown` / `bypass` を
  assert する群）が **すべて PASS を維持**
- `rollback:` `git checkout -- scripts/check-approval-token-write.sh tests/extras/ta-25-approval-token-guard.sh`

### Step 5: 変異注入 2 方向の追加（AC-08 / AC-09 — 検出力の実証）

- **Output**: `_t25_mutate` 呼び出しを 2 件追加（`T1045-TC-09` / `T1045-TC-10`）
- **Owner**: agent
- **Risk**: **high**（ここが空振りすると「テストがあるのに検出力ゼロ」になる / #874 同型）
- **内容**:
  1. **`_t25_mutate` に label prefix 引数を追加**（GC-4-B の採用案 (a)）。
     シグネチャを `_t25_mutate <tc-id> <sed> <anchor> <kill-label> [prefix]` とし、
     内部の 5 箇所のラベルを `T1023-` ハードコードから **`${5:-T1023}`** 由来へ置換する
  2. **(a) 修正前へ戻す変異**（`# t1045-redirect-normalize` を no-op 化 / prefix=`T1045`）
     → kill 対象 = `T1045-TC-01`（誤検知解消 TC）
  3. **(b) 弱める側の変異**（`# t1045-file-redirect` の残存 `>` 判定を常に false 化 / prefix=`T1045`）
     → kill 対象 = `T1045-TC-04`（退行防止 TC）
  4. `_t25_mutate` の sed 式も **POSIX BRE のみ**（GC-6）
- **🚩チェックポイント**:
  - 各変異で **`[FAIL] <kill 対象ラベル>` が実際に出力され、子プロセス rc が非 0** であることを
    出力で確認する（「kill した」の申告ではなく **実出力を evidence に残す**）
  - **新変異の出力ラベルが `T1045-TC-09` / `T1045-TC-10` になっている**
    （`T1023-TC-09` と衝突していない = GC-4-B の解消確認）
  - **既存 7 箇所の `_t25_mutate` 呼び出しを変更していない**こと（`git diff` で実測）。
    かつ既存 mutation 7 種の出力ラベルが `T1023-` のままであること（互換維持）
  - `T1023-TC-15pre`（baseline）/ `T1023-TC-17post`（復元）が PASS を維持
- `rollback:` `git checkout -- tests/extras/ta-25-approval-token-guard.sh`

### Step 6: 併記回避の多重防御を再実測（AC-07 / pbi-input N-5）

- **Output**: `evidence/verification/multi-defense.md`
- **Owner**: agent
- **Risk**: medium
- **内容**: `ls > /dev/null ; cp <TOKEN> /tmp/x` に加え、**`>` を含まない単独形**
  （`cp <TOKEN> /tmp/x` / `tee <TOKEN>` / `mv /tmp/x <TOKEN>`）が**各 exit 2** であることを
  **本 PBI 内で再実測**する（起票時実測を根拠にしない）
- **🚩チェックポイント**: 4 形すべて exit 2
- `rollback:` 不要（読み取り・記録のみ）

### Step 7: AC-12 — 起点そのものの解消を実測

- **Output**: `evidence/verification/ac12-readonly-audit.md`
- **Owner**: agent
- **Risk**: low
- **内容**: `<TOKEN>` を対象とする **read-only 監査コマンド**（#1023 AC-09 相当。
  `find` / `grep` / `jq` による列挙で `2>/dev/null` を伴うもの）が guard を通過することを
  実測ログとして残す
- **🚩チェックポイント**: 監査コマンド群が exit 0
- `rollback:` 不要（読み取り・記録のみ）

### Step 8: 全体検証（AC-11 / AC-13）と evidence 整理

- **Output**: `evidence/test-runs/` に full suite 実行ログ（ローカル + CI）
- **Owner**: agent
- **Risk**: medium
- **内容**:
  1. `sh -n scripts/check-approval-token-write.sh`（AC-13）
  2. `sh tests/extras/ta-25-approval-token-guard.sh`（standalone / 0 failed）
  3. `sh tests/run-tests.sh`（source 経路 / 0 failed）
  4. **CI（Linux / GNU）実行結果を evidence に残す**（GC-6 / R-5）
- **🚩チェックポイント**: すべて 0 failed。**pass 数が baseline 以上**（絶対件数は契約にしない）
- `rollback:` 不要（検証のみ）

---

## Files / Components to Touch

| パス | 変更内容 | 責務 |
|---|---|---|
| `scripts/check-approval-token-write.sh` | `_has_write_intent()` のリダイレクト検査置換 + `_strip_nonwrite_redirects()` 追加 + `rule=<id>` 付与 + 一意アンカー 2 種 | AI-owned |
| `tests/extras/ta-25-approval-token-guard.sh` | **`T1045-TC-01`〜`06` + `TC-20` を focused 群へ**（GC-4-A・7 件）/ **`TC-07`〜`TC-19` + `TC-21` + `TC-22` を通常群へ**（15 件）追加 + **`_t25_mutate` に label prefix 引数を追加**（GC-4-B (a)。既存 7 呼び出しは無変更）+ `_t25_mutate` 呼び出し 2 件追加 | AI-owned |
| `docs/working/TASK-1045/plan.md` | 本ファイル | AI-owned |
| `docs/working/TASK-1045/todo.md` | 実行 ToDo | AI-owned |
| `docs/working/TASK-1045/test-cases.md` | テストケース定義 | AI-owned |
| `docs/working/TASK-1045/status.md` | フェーズ履歴 | AI-owned |
| `docs/working/TASK-1045/handoff.md` | 完了時引き継ぎ（WF-05 / Rule 5） | AI-owned |

---

## Files NOT to Touch（禁止 / GC-7）

> **注意**: 本節は `## Files / Components to Touch` の**外**に置く。
> 同節内に禁止パスを書くと `extract_allowed_paths()`（`scripts/ai-loop/plan_package.py:170-185`、
> 抽出正規表現 `` `([^`\s]+/[^`\s]+)` ``）が**禁止パスまで allowed_paths として抽出してしまう**ため
> （plan 作成時に実測して検出・是正済み）。

以下は本 PBI で **変更しない**:

- .claude/settings.json / .claude/settings.example.json / .claude/settings.local.json
  （**Human-owned**。U-5 により **本修正の反映に再適用は不要**）
- .claude/rules/ 配下（HO 対象）
- bin/plangate（HO 対象）
- schemas/ 配下（HO 対象）
- .github/workflows/ 配下（HO 対象）
- scripts/hooks/ 配下（HO 対象）
- docs/working/TASK-1045/pbi-input.md（確定物・編集しない）

---

## Testing Strategy

### Unit（guard の挙動 = `PreToolUse` payload に対する exit code）

全 AC は `scripts/check-approval-token-write.sh` を `PreToolUse` payload（stdin JSON）で
起動した**実コマンドの exit code** で判定する（`0` = 通過 / `2` = block）。
テストケース本体は [`test-cases.md`](./test-cases.md)。

### Integration（既存スイートとの共存）

- `tests/extras/ta-25-approval-token-guard.sh` を **standalone** と
  **`tests/run-tests.sh` からの source** の両経路で実行する
- 退行判定の契約は **「0 failed」かつ「pass 数が baseline 以上」**。
  **`ta-25` の TC 総数（起票時 47）は増減するため絶対件数を契約値にしない**

### Mutation（検出力の実証 / AC-08 / AC-09）

`_t25_mutate` の既存機構（アンカー一意 + focused 群での実 TC FAIL）に**適合させて** 2 方向を注入する。
出力ラベルは **GC-4-B の採用案 (a)**（label prefix 引数）により `T1045-` を冠する。

| 変異 | 変異内容 | kill 対象 TC | 意味 |
|---|---|---|---|
| **(a) 修正前へ戻す** | `# t1045-redirect-normalize` の正規化を no-op 化（= 旧 `grep -q '>'` 相当） | `T1045-TC-01` | 誤検知解消の TC が **本当に修正を検出している**ことの証明 |
| **(b) 弱める側** | `# t1045-file-redirect` の残存 `>` 判定を常に false 化 | `T1045-TC-04` | **ガードを弱める変更が機械検出される**ことの証明（GC-1 の担保） |

**kill は「実 TC の `[FAIL]` 出力 + 子プロセス rc 非 0」で判定する**（インライン assert の FAIL は kill と認めない。
`ta-25` の `655` 行の既存契約に従う）。**kill した旨の申告ではなく実出力を evidence に残す。**

### E2E

本 PBI の scope 外。実 Claude Code セッションでの hook 発火は **#1023 で確定済み**の契約であり、
本 PBI は判定精度のみを変更する（GC-5）。

### Verification Automation: `sh -n scripts/check-approval-token-write.sh && sh tests/extras/ta-25-approval-token-guard.sh && sh tests/run-tests.sh`

---

## Risks & Mitigations

| ID | リスク | 影響 | 緩和 | 対応 Step |
|---|---|---|---|---|
| **R-1** | 除外を広げすぎ、実際に書き込める記法が通る（ガード弱体化） | **critical** | GC-1 を最上位制約化。除外は fd 複製 + `/dev/null` の**列挙的 allowlist に限定**。AC-04〜07 の退行 TC + **AC-09 の弱める側変異**で機械検出 | Step 3 / 5 |
| **R-2** | 「`>` を token path 宛のみ」に絞る誤実装 → `T1023-TC-09` が FAIL | major | **GC-3 として plan の Constraints に明記**。AC-11 で既存 TC 全 PASS を要求 | GC-3 / Step 3 |
| **R-3** | `/dev/null` 除外を悪用（`>/dev/nullX` / `>/dev/null/../<TOKEN>`） | major | 除外を **`/dev/null` の直後が語境界**である場合に限定。細工パターンを edge case TC 化（`T1045-TC-12`/`13`） | Step 2 / 3 |
| **R-4** | `>&` 除外が実書き込み（`>&<file>` / `&>file`）を巻き込む | major | `>&` の直後が **数字列 or `-` のときのみ**除去。`&>` / `&>>` は U-2 で **block 維持**。edge case TC 化（`T1045-TC-14`/`15`） | Step 3 |
| **R-5** | POSIX `sh` + BSD/GNU `grep`/`sed` 差異でローカルと CI が割れる | major | GC-6（POSIX 範囲厳守・GNU 拡張禁止）。**CI 実行結果を evidence に残す** | GC-6 / Step 8 |
| **R-6** | 変異アンカーの一意性が壊れ `_t25_mutate` が anchor-not-unique で FAIL | minor | アンカーを `t1045-` prefix で新規採番。**Step 3 のチェックポイントで `grep -c` == 1 を実測** | Step 3 |
| **R-7** | 新 TC を focused 群の外に置き kill が実証されない（#874 同型） | **major** | **GC-4(b) を制約化**し、Step 2 のチェックポイントで**子プロセス出力に新 TC が現れることを目視確認** | GC-4 / Step 2 / 5 |
| **R-8** | Mode を軽く見積もり C-3 が不適切に緩む | major | §Mode 判定で **`critical` / `lite_eligible=false`** を確定。autonomous APPROVE 不可 | Mode 判定 |
| **R-9** | 本 PBI の作業自体が誤 block に阻害される（自己参照） | minor | 記法規約（冒頭）+ トークン literal を含む調査を分割実行。必要時は `PLANGATE_SKIP_TOKEN_GUARD=1`（**Human-owned**）を人間へ依頼（SC-8） | 全 Step |
| **R-9a** | **同上の実地再現（本 PBI 進行中に発生）**: C-1 レビュアーの最初の commit が EH-13 に block された。**コミットメッセージに承認トークンのパス名と、`Co-Authored-By:` 行の `<...>` に含まれる `>` が同居した**ため `_has_write_intent()` が発火した。**1 バイトも書き込まないコミット操作が止まった実例**であり、本 PBI が修正しようとしている誤検知そのもの | minor（実害は作業遅延だが**説得力の高い実例**） | 修正までの回避として、**コミットメッセージにトークンパス literal と `>` を同居させない**（本 PBI の記法規約をコミットメッセージにも適用）。修正後は解消される見込みで、AC-12 の実測対象に含める | 全 Step / handoff |
| **R-10** | `rule=<id>` 付与が既存 assert を壊す | minor | **U-3 で実測確認済み**（`tests/` に `writes token path` のヒット 0 件）。Step 4 のチェックポイントで再確認 | Step 4 |
| **R-11** | 残存誤検知（`&>/dev/null` 付き読み取り）が運用で問題化する | minor | U-2 の意図的な判断。**既知の制約として handoff に明記**し、実害が出たら follow-up issue | handoff |
| **R-12** | **正規化ヘルパの失敗が fail-open（ALLOW）になる**（`sed` 不在 / locale 起因の失敗 / `if` 条件内で `set -e` 無効） | **critical**（真の token 書き込みが無言で通過。**実走再現済み**） | **GC-8 の必須実装 3 件**（fail-closed フォールバック / `command -v sed` / `LC_ALL=C`）+ **`T1045-TC-22`**（`sed` 不在 PATH → `rc=2`）+ **`SC-9`**。変異 (b) では検出できないため**専用 TC が必須** | GC-8 / Step 3 / A-5a |
| **R-13** | **RED ウィンドウで `T1023-TC-15pre` / `TC-17post` が FAIL することを「無視してよい」と学習し、本物の baseline 破壊を見逃す**（#874 同型の感度低下） | **major** | **GC-4-C で期待 FAIL 集合を 6 件に固定**し、それ以外の FAIL は `SC-1` 発火。`SC-4` を 7 ラベル列挙にして誤発火を除去。Step 3 で **PASS へ戻ることを別チェックポイント化** | GC-4-C / Step 2 / Step 3 |
| **R-14** | **`apply-task-0123-patches.sh` が過去に適用された環境に、修正が伝播しない guard の古い複製が残る**（`67-88` 行が `scripts/hooks/` へ `cp` し既存時はスキップ） | minor（`origin/main` に当該ファイルは**不在**＝実害ゼロ） | **`GC-7` は維持**し本 PBI では触らない。**handoff の既知課題へ 1 行 + follow-up issue 起票**（A-1 で確認・A-14 で記載） | A-1 / A-14 / handoff |

---

## Stop Conditions（**即時停止**して人間判断を仰ぐ条件）

> すべて **機械判定可能**な形で書く。該当したら **その場で exec を停止**し、
> `status.md` と `decision-log.jsonl` に記録して人間へエスカレーションする。
> 「様子を見る」「回避策を探す」は禁止（AI 運用 4 原則 第 2: 迂回禁止）。

| ID | 発火条件（機械判定） | 停止時の行動 |
|---|---|---|
| **SC-1** | **Step 1 の baseline が `0 failed` でない**（`ta-25` に既存 FAIL がある） | 退行判定の基準線が成立しないため即停止。base の健全性を人間へ報告 |
| **SC-2** | **アンカー `t1045-redirect-normalize` / `t1045-file-redirect` の `grep -c` が 1 でない**（Step 3 / A-6b） | `_t25_mutate` が anchor-not-unique で FAIL するため即停止。アンカー設計をやり直す前に人間へ報告 |
| **SC-3** | **変異 (a) または (b) が kill されない**（`[FAIL] <kill 対象>` が出ない、または子プロセス rc = 0） | **検出力ゼロのまま先へ進まない**（#874 同型）。GC-1 の機械的担保が不成立のため即停止 |
| **SC-4** | **既存 mutation 7 種のいずれかが kill されなくなる**。対象は**次の 7 ラベルの列挙**（範囲表現ではない / R-001）: `T1023-TC-15` / `T1023-TC-16` / `T1023-TC-17` / `T1023-TC-17b` / `T1023-TC-17c` / `T1023-TC-17d` / `T1023-TC-17e`。**`T1023-TC-15pre` と `T1023-TC-17post` は明示的に対象外**（RED ウィンドウでは FAIL するのが正常 / GC-4-C） | 既存の検出力を壊した可能性。即停止して原因特定を人間へ報告 |
| **SC-5** | **`T1023-TC-09` が FAIL する** | GC-3 違反（`>` を token path 宛に限定する誤実装に陥っている）。即停止 |
| **SC-6** | **`>` 除外を入れた結果、`T1045-TC-11`〜`15` / `TC-19` / **`T1045-TC-07 (1)`**（`ls > /dev/null ; cp <TOKEN> /tmp/x`）のいずれかが `rc=0` になる** | **ガードが弱体化した**（GC-1 違反 = critical）。即停止し、除外条件を C-3 へ差し戻す。**`TC-07 (1)` は `/dev/null` 除外を入れる本 PBI で最も直接的な弱体化シナリオ**（AC-07 の中核 / R-005） |
| **SC-9** | **`sed` 不在 / 失敗時に guard が `rc=0`（ALLOW）を返す**（`T1045-TC-22` が FAIL） | **fail-open**（GC-8 / GC-1 違反 = critical）。即停止 |
| **SC-7** | **変更が `scripts/check-approval-token-write.sh` / `tests/extras/ta-25-approval-token-guard.sh` / `docs/working/TASK-1045/` の外へ及ぶ**（`git status --porcelain` で実測） | GC-7 違反。即停止 |
| **SC-8** | **`PLANGATE_SKIP_TOKEN_GUARD=1` が必要になる場面に遭遇** | **Human-owned**。AI は自分で設定せず、人間へ依頼して停止（R-9） |

## Replan Triggers（**C-3 へ差し戻す**条件）

> Stop Condition が「一旦止めて相談」なのに対し、Replan Trigger は
> **plan の前提が崩れたため計画そのものを作り直す**条件。発火時は
> `status.md` に記録し **C-3 へ差し戻す**（exec を継続しない）。

| ID | 発火条件（機械判定） | 差し戻す理由 |
|---|---|---|
| **RT-1** | **Step 1b で、正規化プロトタイプ 26 ケースのいずれかが BSD `sed` と GNU `sed` で異なる分類になる** | 「POSIX 範囲で単一実装が両方言で等価に動く」という **plan の中核前提（GC-6）が崩れる**。方言差の吸収方法（実装分岐 / 別アプローチ）は設計判断であり C-3 の再承認を要する |
| **RT-2** | **次のいずれかが成立する**（R-003 で判定可能化）: **(a)** 他の稼働ガードが本ガードを **invoke / source** している / **(b)** 本ガードの**複製が `.claude/settings*.json` に実配線**されている | scope（1 ファイル修正）の前提が崩れ、修正が一部経路へ伝播しない。**実測では (a)(b) とも該当なし**（`scripts/hooks/check-approval-token-write.sh` は `origin/main` に**不在**＝ `git ls-tree` で 0 件を確認）→ **現時点では発火しない**。旧文言「同一の判定コードを共有」は POSIX `sh` の独立スクリプト群では構造上ほぼ常に偽で**実質判定不能**だったため差し替えた |
| **RT-3** | **U-3 の再確認で、既存 TC がメッセージ本文（`writes token path`）を assert していると判明** | AC-10 の実装方針（detail 文字列の変更）が既存 TC を壊す前提になるため、メッセージ設計を C-3 で再確定する |
| **RT-4** | **GC-4-B の採用案 (a) が実装できない**（`_t25_mutate` への引数追加が既存 7 呼び出しの互換を壊す） | 変異ドライバの設計前提が崩れる。案 (b)(c) への切替は設計判断のため C-3 の再承認を要する |
| **RT-5** | **除外条件を「fd 複製 + `/dev/null`」の列挙に収めたまま AC-01〜03 を満たせない**と判明 | GC-2（列挙的 allowlist で足りる）という方針前提が崩れる。構文解析寄りの設計へ移るなら C-3 の再承認が必須（bypass 面が増えるため） |

**共通規約**: Stop Condition / Replan Trigger のいずれも、
**発火した事実・判定に使った実出力・停止時点の HEAD SHA** を
`decision-log.jsonl`（append-only）と `status.md` に記録してから停止する。

## Questions / Unknowns（C-3 での人間判断事項）

すべての Unknowns は §未決事項の確定 で **plan 側の既定を確定済み**。
そのうえで **C-3 で人間の明示判断を仰ぐ**のは次の 2 点。

| # | 論点 | plan の既定 | 人間へ問う理由 |
|---|---|---|---|
| **Q-1** | **Mode を `critical` とするか `high-risk` へ引き下げるか** | `critical` | `mode-classification.md` の判定ロジック（定量各軸の最大値）を literal に適用すると **受入基準 13 件 → 超高** となる一方、実際の変更規模は **コード 2 ファイル**。「AC 件数は粒度細分化の産物であり規模実態ではない」と人間が判断するなら `high-risk` への引き下げが妥当。**引き下げで「実施しなくなる」フェーズは V-4（リリース前チェック）のみ**（`mode-classification.md` §フェーズ適用マトリクスを 13 行照合し、`○ → -` になる行は V-4 の 1 行だけ。他の差は強度表現のみ＝詳細 plan / C-2 複数観点 / exec 段階的 / C-4 複数レビュアー推奨で、実施有無は変わらない）。**承認境界に関わる `lite_eligible=false` / 同期 C-3 / autonomous APPROVE 不可 / V-2 / V-3 はいずれも不変**（R-004） |
| **Q-2** | **U-2（`&>` / `&>>`）を block 維持でよいか** | block 維持 | `&>/dev/null` 付きの読み取りコマンドは**引き続き誤 block される**（残存誤検知）。除外面を増やさない安全側を採ったが、運用上の頻度によっては除外に含める判断もありうる |

---

## 未検証事項（C-3 時点で残る Unknowns / plan・C-1 双方で確認不能）

> **plan 作成者・C-1 レビュアーのいずれも macOS ローカル環境**であり、以下は
> **C-3 承認時点では未実測**である。**「検証済み」と誤読されないよう明示する。**

| ID | 未検証事項 | なぜ今確認できないか | いつ・どう解消するか |
|---|---|---|---|
| **UV-1** | **CI（ubuntu / GNU `sed`・GNU `grep`）での `ta-25` 実行結果** | plan / C-1 の実行環境がいずれも macOS（BSD）。CI は PR 作成後にしか回らない | **Step 1b で GNU `sed` 等価性を先行検証**（Linux コンテナまたは CI）。full suite は Step 8。**割れたら RT-1 で C-3 へ差し戻す** |
| **UV-2** | `_strip_nonwrite_redirects()` の**実装可否**（POSIX 範囲で書き切れるか） | 未実装。plan 段階の検証は**ロジックのプロトタイプのみ**で、guard 本体への統合は未実施 | Step 3（A-5a / A-5b）。書き切れなければ **RT-5 で C-3 へ差し戻す** |
| **UV-3** | **新規 TC が実際に focused 子プロセスで走るか** | TC 未実装のため実測不能。GC-4-A は `ta-25:222`/`687` の実測に基づく**設計上の配置指示**であり、走行実測ではない | Step 2 のチェックポイント（`PG_T25_MUTATION_CHILD=1` で 7 件のラベル出現を目視）。走らなければ **SC-3 で即停止** |
| **UV-4** | `_t25_mutate` への引数追加が**既存 7 呼び出しの互換を本当に壊さないか** | 未実装。`${5:-T1023}` フォールバックは設計上互換だが未実測 | Step 5 のチェックポイント。壊れれば **RT-4 で C-3 へ差し戻す** |

**これらはいずれも Stop Condition / Replan Trigger に接続済み**であり、
「未検証のまま素通りする」経路は無い。

## Mode 判定

**モード**: `critical`
**`lite_eligible`**: `false`
**C-3**: **人間 C-3 必須・同期**（autonomous APPROVE **不可**）

### Hardening Override（HO）9 カテゴリ該当性 — 機械判定

`.claude/rules/mode-classification.md` の「承認境界周辺の変更 → 最低でも「高」」節が
参照する正本 = `scripts/hooks/check-plan-hash.sh` の `case` 文（**L124-134**）を literal で確認した。

| 変更対象 | HO パターン | 判定 |
|---|---|---|
| `scripts/check-approval-token-write.sh` | `scripts/hooks/*.sh` | **非該当**（`scripts/` 直下であり `scripts/hooks/` ではない） |
| `tests/extras/ta-25-approval-token-guard.sh` | （`tests/` は 9 カテゴリに無い） | **非該当** |
| `docs/working/TASK-1045/*.md` | （`docs/` は 9 カテゴリに無い） | **非該当** |

→ **HO 9 カテゴリには該当しない**（pbi-input N-1 と一致。guard 冒頭コメントの
「配置: `scripts/` ルート（HO 外）」とも一致）。
したがって **HO 由来の「最低でも高」の強制適用は発生しない**。

### それでも引き上げる根拠（安全側判断）

`mode-classification.md`「自動推定の安全側」:
> 上記例外条件のいずれかが該当不確実な場合は **該当扱い**（Mode を引き上げる側）にする

- 変更対象は **承認境界そのものを守るガード**であり、HO パスの literal には落ちないが
  **保護対象は承認境界（C-3 / maintenance トークン）**である
- 同節の例外ルール「**セキュリティ関連の変更 → 最低でも「中」**」に該当する
- 誤ると `review-principles.md` §3 の **critical**（「本番障害・データ不整合・脆弱性」＝承認境界の突破）に至る

### 定量基準（`mode-classification.md` §定量基準 を引用）

| 判定軸 | 実測値 | 基準行 | 判定 |
|---|---|---|---|
| 変更ファイル数 | **7**（コード 2 + working context 5） | 「6-15 → 高」 | **高** |
| （参考）コードのみ | 2 | 「1-2 → 低」 | 低 |
| **受入基準数** | **13**（AC-01〜13） | 「**11+ → 超高**」 | **超高** |
| タスク数（見込み） | **8 Step / 実タスク 14** | 「11-20 → 高」 | **高** |

→ **定量の最大値 = 超高（`critical`）**（受入基準 13 件が支配）

### 定性基準（`mode-classification.md` §定性基準 を引用）

| 判定軸 | 実態 | 基準行 | 判定 |
|---|---|---|---|
| 変更種別 | 承認境界ガードの判定ロジック置換（バグ修正だが判定コアの書き換え） | 「機能追加/リファクタ → 高」 | **高** |
| リスク | 誤ると承認境界突破（R-1 = critical） | 「高 → 高」 | **高** |
| 影響範囲 | guard 1 本だが、**全 `Bash` tool call の PreToolUse で発火**する（Edit/Write/MultiEdit レーンと共有） | 「複数レイヤーに波及 → 高」 | **高** |
| ロールバック | 単体スクリプトの revert で復元可（Step 3 `rollback:`） | 「計画的に必要 → 高」 | **高** |

→ **定性の最大値 = 高（`high-risk`）**

### 最終判定

`mode-classification.md` §判定ロジック:

> 1. 定量基準の各軸でモードを判定（最大値を採用）
> 2. 定性基準の各軸でモードを判定（最大値を採用）
> 3. **定量と定性の高い方を最終モードとする**

定量 = 超高 / 定性 = 高 → **高い方 = 超高（`critical`）**。

**最終判定: `critical`**（pbi-input の想定 `high-risk` から**安全側へ引き上げ**）。

**補足（Q-1 として C-3 へ提示）**: 引き上げの支配要因は **受入基準 13 件**という単一軸であり、
これは AC を細粒度に分解した結果でもある。**人間が「規模実態は `high-risk`」と判断するなら
Q-1 で引き下げてよい。** ただしその場合も以下は**維持する**（緩和しない）:

- `lite_eligible = false`
- **同期 C-3（人間必須）**
- V-2 / V-3 の実施

### `lite_eligible` 判定（`mode-classification.md` §lite_eligible）

| 軸 | 実態 | 判定 |
|---|---|---|
| 変更ファイル数 | コード 2 + docs 5 | 候補外（light 相当を超える） |
| 新規設計の有無 | **あり**（`_strip_nonwrite_redirects()` は新規の正規化ロジック） | 候補外 |
| 既存パターン踏襲 | 部分的（`_t25_mutate` 機構は踏襲、正規化は新規） | 候補外 |

- **AC-11（`mode-classification.md`）**: 「`critical` mode は原則 `lite_eligible=false`」
- **AC-8 安全側不変条件**: 新規設計ありのため必ず `false`

→ **`lite_eligible = false`**

### autonomous APPROVE 可否（`working-context.md` §C-3 Autonomous APPROVE）

| 条件 | 該当 | 可否 |
|---|---|---|
| Mode = high-risk / critical | **該当** | **❌ 不可（人間 C-3 必須）** |
| セキュリティ関連 | **該当** | **❌ 不可** |

→ **autonomous APPROVE 不可。人間 C-3 必須。**

### フェーズ適用（`critical`）

| フェーズ | 適用 |
|---|---|
| C-1 セルフレビュー | ○（17 項目） |
| C-2 外部 AI レビュー | ○（複数観点） |
| C-3 人間レビュー | ○（詳細レビュー・**同期**） |
| exec | TDD + 段階的 |
| L-0 / V-1 | ○ |
| V-2 コード最適化 | ○ |
| V-3 外部レビュー | ○ |
| V-4 リリース前チェック | ○ |
| PR / C-4 | ○（複数レビュアー推奨） |

---

## 責務分界（`.claude/rules/responsibility-classes.md`）

| 操作 | 責務 |
|---|---|
| guard / テストの実装・検証・evidence 作成 | **AI-owned** |
| C-3 / C-4 の承認判断、`approvals/c3.json` の発行 | **Human-owned**（AI は承認トークンを作成しない / A-6） |
| `.claude/settings*.json` の適用 | **Human-owned**（本 PBI では変更なし / U-5 により再適用も不要） |
| `PLANGATE_SKIP_TOKEN_GUARD=1` の使用 | **Human-owned**（R-9） |
| merge | **Human-owned 固定** |
