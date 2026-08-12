# TEST CASES — TASK-1045

> 入力: [`pbi-input.md`](./pbi-input.md)（AC-01〜13） / 計画: [`plan.md`](./plan.md)
> 対象: `scripts/check-approval-token-write.sh`（EH-13 token-guard）
> 実装先: `tests/extras/ta-25-approval-token-guard.sh`

## 記法規約

`<TOKEN>` は `_is_token_path()` が一致と判定するパス。
**テスト実装では `T25_TOKEN` / `T25_MAINT` の既存フィクスチャ変数**
（`ta-25` の `72-73` 行。テスト専用の架空 path。実 approvals には一切触れない）を用い、
**トークンパス literal を地の文に書かない**。

## Contract

| rc | 意味 |
|---:|---|
| 0 | 許可（通過） |
| 2 | PreToolUse block |
| その他 | 本 PBI の token guard 正常系では使用しない |

全 TC は `scripts/check-approval-token-write.sh` を `PreToolUse` payload（stdin JSON /
`tool_name=Bash`）で起動した**実コマンドの exit code** で判定する。
起動は `t25_guard` ヘルパ経由（`PG_T25_GUARD` override 方式を壊さない / plan GC-4）。

## 配置制約（plan GC-4 / #874 同型の空振り回避）

> **正本は [`plan.md`](./plan.md) §GC-4-A**。本表はその写しであり、独自の集合を定義しない。

`ta-25` の **focused 群 = `102-221` 行** / **通常群 = `222` 行
`if [ "$PG_T25_FOCUSED" = "0" ]` 〜 `687` 行 `fi`**（実測確認済み）。
**mutation の kill 対象になる TC は focused 群に置かなければならない。**

| TC | 配置 | 理由 |
|---|---|---|
| `T1045-TC-01`, `TC-02`, `TC-03`, `TC-04`, `TC-05`, `TC-06`, **`TC-20`**（**7 件**） | **focused 群（必須）** | 変異 (a)(b) の kill 対象（`TC-01` / `TC-04`）と、**同一コードパスを共有し変異で連鎖 FAIL することを実測確認する対象**（`TC-02` / `TC-03` / `TC-05` / `TC-06` / `TC-20`） |
| `T1045-TC-07`〜`TC-19` + `TC-21` + `TC-22` + `TC-22b`（**16 件**） | 通常群 | mutation kill 対象ではない。とくに `TC-07` は変異 (b) 適用下でも `copy-like` ルールで block され続けるため **kill 対象になり得ない** |

**根拠（1 行）**: **変異の kill 対象になる TC はすべて focused 群に必要**であり、
上記 7 件は本 PBI が変更する唯一のコードパス（正規化 + 残存 `>` 判定）を直接叩く集合である。

---

## Test Cases

### 誤検知の解消（focused 群）

| ID | 対応 AC | 入力 / 前提 | 期待結果 |
|---|---|---|---|
| **T1045-TC-01** | AC-01 | `command` = `<TOKEN>` を含む読み取り専用コマンド + **`2>/dev/null`**（例: `grep -c '<TOKEN>' .gitignore 2>/dev/null`） | **rc=0**（block されない）。**mutation (a) の唯一の kill 対象** |
| **T1045-TC-02** | AC-02 | 同上を **`2>&1`** で | **rc=0** |
| **T1045-TC-03** | AC-03 | 同上を **`>&2`**（fd 複製）で | **rc=0** |
| **T1045-TC-20** | AC-03 | `<TOKEN>` を読む + **`3>&-`**（fd クローズ） | **rc=0**（fd クローズも書き込みではない） |

### 退行防止 — 真の書き込みは block 維持（focused 群）

| ID | 対応 AC | 入力 / 前提 | 期待結果 |
|---|---|---|---|
| **T1045-TC-04** | AC-04 | `echo x > <TOKEN>` | **rc=2**。**mutation (b) の唯一の kill 対象** |
| **T1045-TC-05** | AC-05 | `echo x >> <TOKEN>` | **rc=2** |
| **T1045-TC-06** | AC-06 | `printf x 1> <TOKEN>`（fd 番号付きファイルリダイレクト） | **rc=2** |

### 退行防止 — 除外条件の細工・境界（通常群 / plan R-3・R-4・U-1・U-2・GC-2）

| ID | 対応 AC | 入力 / 前提 | 期待結果 |
|---|---|---|---|
| **T1045-TC-11** | AC-06（U-1） | `cat <TOKEN> > /dev/stdout` / `> /dev/stderr` / `> /dev/fd/3` の 3 形 | **各 rc=2**（除外は `/dev/null` のみ。擬似デバイスは block 維持） |
| **T1045-TC-12** | AC-04（R-3） | `cat <TOKEN> 2>/dev/nullX`（語境界を満たさない類似名） | **rc=2**（`/dev/null` の直後が語境界でないため除外されない） |
| **T1045-TC-13** | AC-04（R-3） | `cat <TOKEN> > /dev/null/../<TOKEN>`（パス細工） | **rc=2** |
| **T1045-TC-14** | AC-04（U-2） | `cat <TOKEN> &> /tmp/o` / `&>> /tmp/o` / **`&> /dev/null`** の 3 形 | **各 rc=2**（`&>` / `&>>` は block 維持。`/dev/null` 宛でも除外しない = U-2 の確定） |
| **T1045-TC-15** | AC-04（R-4） | `cat <TOKEN> >& /tmp/o`（`>&` の直後がファイル名） | **rc=2**（fd 複製の除外は直後が数字列 or `-` のときのみ） |
| **T1045-TC-19** | AC-04（GC-2） | `echo 'a > b' <TOKEN>`（文字列リテラル中の `>`） | **rc=2**（保守的 block を維持。**誤検知として扱わない**＝取りこぼし許容の明示固定） |

### 併記による回避の非成立（通常群 / plan N-5 再実測）

| ID | 対応 AC | 入力 / 前提 | 期待結果 |
|---|---|---|---|
| **T1045-TC-07** | AC-07 | 4 形を**本 PBI 内で再実測**: (1) `ls > /dev/null ; cp <TOKEN> /tmp/x` / (2) `cp <TOKEN> /tmp/x` 単独 / (3) `printf x \| tee <TOKEN>` 単独 / (4) `mv /tmp/x <TOKEN>` 単独 | **各 rc=2**。(2)(3)(4) は **`>` を含まない**ため、`>` 以外のルール（`copy-like`）が単独で当該回避を捕捉していることを示す |

### block メッセージのルール識別子（通常群）

| ID | 対応 AC | 入力 / 前提 | 期待結果 |
|---|---|---|---|
| **T1045-TC-08** | AC-10 | AC-04〜07 の **block ケース**の stderr を検査（読み取りコマンドは AC-01〜03 で通過するため block ケースで assert する） | stderr に **`rule=file-redirect`**（TC-04）/ **`rule=copy-like`**（TC-07 (2)(3)(4)）が含まれる。`BLOCK` 行も維持 |

### 変異注入 2 方向 — 検出力の実証（通常群）

| ID | 対応 AC | 入力 / 前提 | 期待結果 |
|---|---|---|---|
| **T1045-TC-09** | AC-08 | **(a) 修正前へ戻す変異**: tmp 複製の guard で `# t1045-redirect-normalize` の正規化を **no-op 化**（= 旧 `grep -q '>'` 相当）。`PG_T25_GUARD` を mutant へ override して `ta-25` を focused 再実行。**`_t25_mutate` の第 5 引数に `T1045` を渡す**（plan GC-4-B） | アンカー `grep -c` == **1**、`sh -n` PASS、**`[FAIL] T1045-TC-01` が実出力に現れ子プロセス rc が非 0**、**出力ラベルが `T1045-TC-09`**（`T1023-TC-09` と衝突しない）、復元後 PASS |
| **T1045-TC-10** | AC-09 | **(b) 弱める側の変異**: tmp 複製の guard で `# t1045-file-redirect` の残存 `>` 判定を **常に false 化**。同 override + 第 5 引数 `T1045` | アンカー `grep -c` == **1**、`sh -n` PASS、**`[FAIL] T1045-TC-04` が実出力に現れ子プロセス rc が非 0**、**出力ラベルが `T1045-TC-10`**、復元後 PASS |
| **T1045-TC-21** | AC-11 | **`_t25_mutate` の後方互換**: 既存 7 箇所の呼び出し（`ta-25:662, 664, 666, 668, 670, 672, 674`）を**4 引数のまま変更しない** | 既存 mutation 7 種が **すべて PASS**、かつ出力ラベルが **`T1023-` のまま**（`${5:-T1023}` フォールバックが効いている） |

> **kill の判定規約**（`ta-25` の `655` 行の既存契約に従う）:
> kill は **「実 TC の `[FAIL]` 出力」+「子プロセス rc 非 0」**の両方で判定する。
> mutation スクリプト内のインライン assert の FAIL は kill と認めない。
> **「kill した」という申告ではなく実出力を evidence に残す。**

### 既存スイート・静的検査（通常群）

| ID | 対応 AC | 入力 / 前提 | 期待結果 |
|---|---|---|---|
| **T1045-TC-16** | AC-11 | `sh tests/extras/ta-25-approval-token-guard.sh`（standalone）+ `sh tests/run-tests.sh`（source 経路） | **0 failed**、かつ **pass 数 ≥ baseline**。特に **`T1023-TC-08`**（read-only `cat` → rc=0）/ **`T1023-TC-09`**（`cat <TOKEN> && echo hi > /tmp/other.txt` → 保守的 rc=2）/ **`T1023-TC-12` / `TC-25` / `TC-26` / `TC-27`** / 既存 mutation 7 種（`TC-15`〜`17e`）/ baseline・復元（`TC-15pre` / `TC-17post`）が PASS |
| **T1045-TC-17** | AC-12 | `<TOKEN>` を対象とする **read-only 監査コマンド**（#1023 AC-09 相当。`find` / `grep` / `jq` による列挙で **`2>/dev/null` を伴う**もの）を payload 化 | **各 rc=0**。実測ログを `evidence/verification/ac12-readonly-audit.md` に残す |
| **T1045-TC-18** | AC-13 | `sh -n scripts/check-approval-token-write.sh` + 実行可能属性（既存 `TC-01` / `TC-02` 相当） | syntax PASS / `-x` あり |

### 正規化ヘルパの fail-closed（通常群 / plan GC-8 / R-002）

> **1 要件 1 TC**（R-009）: `GC-8` の 3 要件のうち **(i) と (ii) は別々の TC でしか撃てない**。
> **`TC-22` は (ii) だけを撃ち、(i) が欠けた実装では `rc=2` で PASS してしまう**（実測）。
> したがって **`TC-22b` が (i) の検出力を担う唯一の TC**である。

| ID | 対応 AC | 撃つ要件 | 入力 / 前提 | 期待結果 |
|---|---|---|---|---|
| **T1045-TC-22** | AC-04（GC-8） | **(ii) `command -v sed`** | **`T1023-TC-05`（jq 不在 PATH）と同型**: **`sed` を含まない**一時 PATH（`cat` / `grep` / `sh` / `jq` のみを symlink）で guard を起動し、payload = `printf x > <TOKEN>` | **`rc==2`** **かつ** stderr に **`sed not available`** を含む（実測経路 = **`route=parse-unknown`**）。**rc だけを assert すると、別要因の `parse-unknown` でも `rc=2` になり偽 PASS になる** |
| **T1045-TC-22b** | AC-04（GC-8） | **(i) fail-closed フォールバック** | 一時 PATH に `cat` / `grep` / `sh` / `jq` を symlink し、そこへ **`#!/bin/sh` + `exit 1` の `sed` シム**を置く（**`sed` は存在するが必ず失敗する**）。payload = `printf x > <TOKEN>` | **`rc==2`** **かつ** stderr に **`Bash command writes token path`** を含み、**かつ `parse-unknown` を含まない**（実測経路 = **`route=normal-block`**。要件 (i) のフォールバックは**設計上サイレント**なので `sed` 起因の reason は出ない / R-013）。**(i) が無ければ `rc=0`（FAIL-OPEN）で落ちる** → **これで初めて (i) の検出力が実証される** |

**実測による裏付け**（C-2 整合レーンが実走 / **筆者も独立に再現**）:

| build | `sed` 不在（TC-22） | `sed` 存在するが失敗（TC-22b） |
|---|---|---|
| (i)+(ii)+(iii) 全部 | rc=2 | **rc=2** |
| **(ii)+(iii) のみ（(i) 欠落）** | **rc=2 → TC-22 は PASS（穴を検出できない）** | **rc=0 ＝ FAIL-OPEN → TC-22b が検出** |
| どちらも無し（反映前の形） | rc=0 | rc=0 |

**`TC-22` を stub 方式へ寄せない理由**: C-2 設計レーンは Round 2 で「TC-22 も stub 方式へ
寄せてよい」と補足したが、**stub を置くと `sed` が存在してしまい `command -v sed` が成功するため、
要件 (ii) を撃てなくなる**。(ii) を撃つには **`sed` が実際に不在の PATH が必須**。
よって **TC-22 は「不在」方式を維持**し、**TC-22b で「存在するが失敗」を撃つ**という 2 本立てにする。
**Round 3 で設計レーンがこの棄却を受理**（「**maker の棄却理由が正しく、私の補足が誤りでした**」）し、
整合レーンも「シム PATH では FULL build と NO-(ii) build が出力レベルで区別不能」と実走で裏付けた。

**reason 文字列の assert は両 TC に採用するが、期待する reason は TC ごとに異なる**（R-013）。
**「両 TC 共通で `sed` 起因の reason を assert する」のは誤り**で、そう実装すると
**正しい実装で `TC-22b` が FAIL し、`SC-9`（critical / 即停止）を誤発火させる**。

| 入力 | rc | 実測経路 | `sed not available` | `writes token path` | `parse-unknown` |
|---|---|---|---|---|---|
| `TC-22`（`sed` 不在） | 2 | `route=parse-unknown` | **YES** | no | **YES** |
| `TC-22b`（`sed` 存在するが失敗） | 2 | **`route=normal-block`** | no | **YES** | **no** |

**`TC-22b` の「`parse-unknown` を含まない」は必須**（これが無いと、外部依存の列挙漏れ等で
別経路の `parse-unknown` に落ちても `rc=2` + 文字列一致で**偽 PASS** になり、
**(i) の検出力という `TC-22b` 唯一の存在理由が失われる**）。
**二重条件は `ta-25:118` の既存パターン**
（`[ rc = 2 ] && grep -q 'file_path=' && ! grep -q 'parse-unknown'`）**を踏襲する**。

---

## Traceability（AC ↔ TC）

| AC | 対応 TC | 件数 |
|---|---|---:|
| AC-01（`2>/dev/null` 付き read-only が通る） | T1045-TC-01 | 1 |
| AC-02（`2>&1`） | T1045-TC-02 | 1 |
| AC-03（`>&2` fd 複製 **および fd クローズ `N>&-`** / plan §AC の適用範囲宣言・R-006） | T1045-TC-03（fd 複製）, T1045-TC-20（fd クローズ） | 2 |
| AC-04（退行: `> <TOKEN>`） | T1045-TC-04, T1045-TC-12, T1045-TC-13, T1045-TC-14, T1045-TC-15, T1045-TC-19, **T1045-TC-22**, **T1045-TC-22b** | 8 |
| AC-05（退行: `>> <TOKEN>`） | T1045-TC-05 | 1 |
| AC-06（退行: `1> <TOKEN>`） | T1045-TC-06, T1045-TC-11 | 2 |
| AC-07（併記回避の非成立） | T1045-TC-07 | 1 |
| AC-08（修正前へ戻す変異で誤検知解消 TC が FAIL） | T1045-TC-09 | 1 |
| AC-09（弱める側の変異で退行防止 TC が FAIL） | T1045-TC-10 | 1 |
| AC-10（block メッセージのルール識別子） | T1045-TC-08 | 1 |
| AC-11（既存 TC 全 PASS） | T1045-TC-16, T1045-TC-21 | 2 |
| AC-12（起点の read-only 監査が通る） | T1045-TC-17 | 1 |
| AC-13（syntax / 実行可能属性） | T1045-TC-18 | 1 |

- **AC 総数 13 / TC を持たない AC = 0（orphan 0）**
- **TC 総数 23 / 対応 AC を持たない TC = 0（逆向き orphan も 0）**
  （内訳: focused 群 **7 件**（`TC-01`〜`06`, `TC-20`）+ 通常群 **16 件**（`TC-07`〜`TC-19`, `TC-21`, `TC-22`, `TC-22b`））
  **`TC-22b` は `TC-22` と同じ `AC-04` に紐付くため orphan は増えない**（R-009）

### 変異 ↔ TC の対応（検出力の網羅）

| 変異 | kill 対象 TC | 未対応の新規 TC |
|---|---|---|
| (a) 修正前へ戻す（`t1045-redirect-normalize` no-op） | T1045-TC-01 | — |
| (b) 弱める側（`t1045-file-redirect` 常時 false） | T1045-TC-04 | — |

> **AC-01〜06 のうち mutation の直接 kill 対象は TC-01 / TC-04 の 2 件**。
> 残る TC-02 / TC-03 / TC-05 / TC-06 / TC-20 は**同一コードパス（正規化 + 残存 `>` 判定）を
> 共有する**ため、2 変異のいずれかで同時に FAIL する。
> **これは実行時に「focused 子プロセスの出力に当該ラベルが現れるか」で実測確認する**
> （出力に現れない = focused 群外に置かれた＝ plan GC-4(b) 違反の検出）。

---

## Edge Cases（明示的に block 維持＝誤検知として扱わない）

| ケース | 扱い | 固定 TC |
|---|---|---|
| 文字列リテラル中の `>`（`echo 'a > b'`） | block 維持（plan GC-2） | T1045-TC-19 |
| ヒアドキュメント本文中の `>` | block 維持（plan GC-2） | 明示 TC なし（GC-2 で宣言。完全構文解析を行わない帰結） |
| 変数展開で現れる `>` | block 維持（plan GC-2） | 同上 |
| `&>/dev/null` 付きの読み取り | **block 維持 = 残存誤検知**（U-2 の意図的判断） | T1045-TC-14 (3)。**handoff の既知課題に明記** |
| `/dev/stdout` / `/dev/stderr` / `/dev/fd/N` 宛 | block 維持（U-1） | T1045-TC-11 |

---

## Exit Criteria

- **AC-01〜13 に未検証がない**（Traceability の orphan 0）
- **focused 群の TC 集合が plan §GC-4-A と一致している**（7 件: `TC-01`〜`06`, `TC-20`）
- **新変異の出力ラベルが `T1045-TC-09` / `T1045-TC-10`** であり、既存 `T1023-TC-09` と衝突しない
- **`_t25_mutate` の既存 7 呼び出しが無変更**で、既存 mutation 7 種の出力ラベルが `T1023-` のまま（`TC-21`）
- **変異 2 方向がともに kill される**。kill は **`PG_T25_GUARD` override 下で実 TC が `[FAIL]` する**
  ことで示す（インライン assert の FAIL は kill と認めない）
- **新規 TC が focused 子プロセスで実際に実行されている**ことを出力で確認済み（plan GC-4(b) / #874 同型の空振り防止）
- **変異アンカー `t1045-redirect-normalize` / `t1045-file-redirect` が guard 内で各 `grep -c` == 1**
- **既存 TC が 0 failed、pass 数が baseline 以上**
  （**`ta-25` の TC 総数は増減するため絶対件数を契約値にしない**。起票時実測 47 passed / 0 failed は
  **測定環境・base SHA `6089e23` とセットの参考値**であり契約ではない）
- **`T1023-TC-09` が PASS を維持**（plan GC-3。`>` を token path 宛に限定する誤実装の検出）
- **`T1023-TC-24` に新たな違反がない**（stdin 未 redirect の guard 起動を残さない / R-027）
- **ローカル（BSD / macOS）と CI（GNU / Linux）双方の実行結果が evidence に残っている**（plan GC-6 / R-5）
- **ガードを弱める変更が 1 つも入っていない**（plan GC-1。AC-04〜07 + AC-09 + **`T1045-TC-22` / `TC-22b`** で機械担保）
- **正規化ヘルパが fail-closed である**（plan GC-8）。**要件ごとに撃つ TC を分けて確認する**:
  - **`sed` 不在** → `rc=2`（要件 (ii)）: **`T1045-TC-22`**
  - **`sed` 存在するが失敗** → `rc=2`（要件 (i)）: **`T1045-TC-22b`**
  - **reason 文字列まで assert 済み。ただし期待 reason は TC ごとに異なる**（R-013）:
    **`TC-22` は `sed not available`** / **`TC-22b` は `Bash command writes token path`
    かつ `parse-unknown` を含まない**。
    **`TC-22b` に `sed` 起因の reason を期待してはならない**（フォールバックはサイレント）
- **RED ウィンドウの期待 FAIL 集合が GC-4-C の 6 件と一致**し、
  **Step 3 完了後に `T1023-TC-15pre` / `T1023-TC-17post` が PASS へ戻っている**
