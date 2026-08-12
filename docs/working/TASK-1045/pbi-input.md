# TASK-1045 PBI INPUT PACKAGE

> Issue: [#1045](https://github.com/s977043/plangate/issues/1045)
> Title: fix(hooks): EH-13 token-guard が stderr リダイレクト（`2>/dev/null` / `2>&1`）を書き込みと誤判定し、読み取り専用コマンドを block する
> Labels: `bug` / `priority:P2` / Milestone: `v8.19.0`
> 由来: **#1042 の後続**（EH-13 導入直後に検出） / 関連: **#1023**（EH-13 実装元、AC-09 の監査作業が本件の影響を受ける）

## 記法について（本ドキュメントの安全な可読性）

本 PBI が扱う不具合の性質上、**承認トークンのパス文字列そのものを本文に書くと、この
ファイルを `2>/dev/null` 付きで grep する操作まで巻き添えで block されうる**（それ自体が本件の
症状）。したがって本ドキュメントでは以下の記法を用いる。

- `<TOKEN>` … `scripts/check-approval-token-write.sh` の `_is_token_path()` が一致と判定する
  パス（承認 artifact / maintenance artifact / 親 PBI 承認 artifact の JSON 群）。
- 実文字列が必要な箇所は plan / test-cases 側でフィクスチャとして扱い、本ドキュメントには置かない。

---

## Context / Why

### 何が起きているか

issue #1042（`15b0c16` / 2026-08-10）で導入された **EH-13 token-guard**
（`scripts/check-approval-token-write.sh`。**`scripts/hooks/` ではなく `scripts/` 直下**）の
`_has_write_intent()` は、判定の**先頭で**次を実行する。

```sh
# リダイレクト > / >>
printf '%s' "$_wc" | grep -q '>' && return 0
```

`>` が**コマンド文字列のどこかに 1 文字でも含まれれば無条件に「書き込み意図あり」**と判定する。
しかし `2>&1` / `2>/dev/null` / `>&2` は **fd 複製・破棄**であってファイルへの書き込みではない。
結果、`<TOKEN>` の名前を含む**純粋な読み取りコマンド**が block される。

### 実測（base `48f6971` / guard 実体は `15b0c16` 由来。本 PBI 起票時に再現済み）

`PreToolUse` payload を stdin に与えて guard を直接起動した結果（`tool_name=Bash`）。

| # | コマンド（`<TOKEN>` は承認 artifact パス） | exit | 判定 |
|---|---|---|---|
| A | `grep -c '<TOKEN>' .gitignore` | 0 | 通る（正） |
| B | `grep -c '<TOKEN>' .gitignore 2>/dev/null` | **2** | 🔴 誤 block |
| C | `grep -c '<TOKEN>' .gitignore 2>&1` | **2** | 🔴 誤 block |
| D | `grep -c '<TOKEN>' .gitignore >&2` | **2** | 🔴 誤 block |
| E | `cat <TOKEN>` | 0 | 通る（正） |
| F | `cat <TOKEN> 2>/dev/null` | **2** | 🔴 誤 block |
| K | `jq -r .c3_status <TOKEN> 2>/dev/null` | **2** | 🔴 誤 block |
| G | `echo x > <TOKEN>` | 2 | block（正・維持すべき） |
| H | `echo x >> <TOKEN>` | 2 | block（正・維持すべき） |

block 時の stderr（B の例。**「writes token path」と表示されるが 1 バイトも書いていない**）:

```text
[EH-13 token-guard] BLOCK: 承認トークン系ファイルへの AI 直接書き込みは禁止されています。
  検出: Bash command writes token path: grep -c '<TOKEN>' .gitignore 2>/dev/null
  正規操作: bin/plangate approve <TASK>（Human TTY / TASK-0128）または bin/plangate maintenance start
```

### なぜ実害があるか

1. **`2>/dev/null` は本リポジトリで極めて一般的なイディオム**である。実際に
   `tests/extras/ta-25-approval-token-guard.sh` 自身が多数の `2>/dev/null` を含む。
   承認境界まわりの**調査・監査・レビュー作業が広範に阻害**される。
2. **循環が起きる**: **#1023 の AC-09 が要求する「承認 artifact の read-only 監査」**
   （母集団全体を read-only で列挙し provenance を記録する）を実行しようとすると、
   **監査対象の名前を含むコマンドが block される**。ガードが自分自身の要求する監査を止める。
3. **検出理由の文言（`writes token path`）と実挙動（読み取りのみ）が乖離**しているため、
   遭遇した実行者が「自分は書き込もうとしていない」ことを説明できず、原因究明に時間を要する。
4. 暫定回避策は `2>/dev/null` / `2>&1` を**外す**ことだが、stderr が混ざり調査の質が落ちる。

### 「仕様どおり」か「仕様の穴」か（本 PBI の立脚点）

**仕様の穴（実装欠陥）と判断する。** 根拠:

- #1023 の pbi-input **AC-04** は「token artifact の **read-only command** … は誤 block しない」を
  要求しており、`docs/working/TASK-1023/test-cases.md` の **T1023-TC-08**
  （「token path を read-only `cat` する parsed Bash payload → rc=0」）で固定されている。
  **read-only を通すことは設計意図**である。
- AC-04 が保守的 block と明示したのは **「token path と別 write を混在させた command」**
  （T1023-TC-09 のフィクスチャは `cat <TOKEN> && echo hi > /tmp/other.txt`。**実ファイルへの
  書き込みが実在する**ケース）。`2>/dev/null` / `2>&1` は**どこにも書き込みが存在しない**ため、
  この「混在の保守的 block」条項には該当しない。
- したがって本件は「保守的 block 仕様の想定内の副作用」ではなく、
  **`>` の粗い検査が設計意図（read-only は通す）を貫通してしまっている実装欠陥**である。

---

## What (Scope)

### In scope

1. `scripts/check-approval-token-write.sh` の `_has_write_intent()` における `>` 検査を、
   **ファイルへの出力リダイレクトのみ**を捉える形へ限定する。
   - 少なくとも **fd 複製（`N>&M` / `>&N`）** と **`/dev/null` への破棄** を write intent から除外する。
2. block 時のメッセージが、**実際に一致したルールの識別子**（どの検査で block したか）を示すようにする。
3. `tests/extras/ta-25-approval-token-guard.sh` に以下を追加する。
   - 誤検知が塞がれたこと（read-only + stderr リダイレクトが rc=0）の TC
   - 真の write が引き続き block されること（退行防止）の TC
   - 上記が **修正前の実装では期待どおりにならない**ことを、既存の `_t25_mutate` 機構
     （unique anchor + 「実 TC の FAIL で kill を判定」）で実証する変異
4. 併記による回避（`cmd >/dev/null; cp <TOKEN> <dest>` 等）が**成立しない**ことの実測確認。

### Out of scope

- **EH-13 の採番・配線そのもの**（#1042 で確定済み）
- **`_is_token_path()` の判定範囲の変更**（どのパスをトークンと見なすか）
- 他の write intent ルール（`cp` / `mv` / `ln` / `install` / `dd` / `tee` / `truncate` /
  `patch` / `apply_patch` / `ed` / `ex` / `git checkout|restore|checkout-index|update-index` /
  `sed -i` / `perl -i` / python・node・ruby の書き込み API 等）の見直し
- **コマンド文字列の完全なシェル構文解析**（後述 Non-goals）
- `Edit` / `Write` / `MultiEdit` レーン（`file_path` 判定）の変更
- `parse-unknown` fail-closed 方針・`exit 2` 契約・`PLANGATE_SKIP_TOKEN_GUARD` の変更
- `.claude/settings*.json` への配線変更（Human-owned。本 PBI では触らない）

### Non-goals（明示）

- **ガードを弱めること。** 本 PBI の目的は **「判定を正確にする」**ことであり、
  防御範囲を狭めることではない。除外を追加した結果として
  **書き込み可能な記法が 1 つでも通るようになってはならない**。
- **コマンド文字列の完全なシェル構文解析。** クォート・変数展開・`eval`・ヒアドキュメント・
  プロセス置換まで正確に解釈するのはコストに見合わず、パーサ自体が新たな bypass 面になる。
  **保守的側（fail-closed）に倒したまま、「明らかに書き込みではない記法」だけを除外する**
  方針で十分とする。
  - 具体的に「取りこぼしを許容する」例: `echo 'a > b'` のような**文字列リテラル中の `>`**。
    これは引き続き保守的に block されてよい（現状も block する）。誤検知として扱わない。

---

## 受入基準

> 全 AC は `scripts/check-approval-token-write.sh` を `PreToolUse` payload（stdin JSON）で
> 起動した**実コマンドの exit code**で判定する。`0` = 通過 / `2` = block。

| ID | 受入基準（テスト可能な条件） |
|----|--------------------------|
| **AC-01** | `<TOKEN>` の名前を含む**読み取り専用コマンド**に `2>/dev/null` を付けた payload で guard を起動すると **exit 0**（block されない）。TC として `tests/extras/ta-25-approval-token-guard.sh` に存在する |
| **AC-02** | 同上を `2>&1` で行うと **exit 0**。TC として存在する |
| **AC-03** | 同上を `>&2`（fd 複製）で行うと **exit 0**。TC として存在する |
| **AC-04** | **退行防止**: `echo x > <TOKEN>` は **exit 2**（block）。TC として存在する |
| **AC-05** | **退行防止**: `echo x >> <TOKEN>` は **exit 2**（block）。TC として存在する |
| **AC-06** | **退行防止**: `printf x 1> <TOKEN>`（fd 番号付きファイルリダイレクト）は **exit 2** |
| **AC-07** | **併記による回避が成立しない**: `ls > /dev/null ; cp <TOKEN> /tmp/x` は **exit 2**。さらに `>` 検査を通さない形（`cp <TOKEN> /tmp/x` 単独、`tee <TOKEN>` 単独、`mv /tmp/x <TOKEN>` 単独）も **各 exit 2** であることを実測し、`>` 以外のルールが単独で当該回避を捕捉していることを示す |
| **AC-08** | **変異注入による検出力の実証**: `_has_write_intent()` の新しいリダイレクト検査を、**修正前の実装（`grep -q '>'` 相当）へ戻す変異**を注入すると、**AC-01〜AC-03 に対応する TC が実際に FAIL する**（既存 `_t25_mutate` の「実 TC の FAIL で kill を判定」方式に従い、`[FAIL] <TC ラベル>` が出て子プロセスの rc が非 0）。変異アンカーは guard 内で**一意**であること（`_t25_mutate` の anchor 一意チェックを満たす） |
| **AC-09** | **変異アンカーの逆方向も殺せる**: 除外条件を過剰に広げる変異（例: ファイルリダイレクト検査を常に false にする）を注入すると、**AC-04 / AC-05 に対応する TC が FAIL する**（ガードを弱める変更が検出される） |
| **AC-10** | **block メッセージが根拠を示す**: block 時の stderr に、**一致したルールの識別子**（例: `rule=file-redirect` / `rule=copy-like` のような機械可読な短いタグ）が含まれる。読み取りコマンドが誤って `writes token path` とだけ表示される状態が解消されている（AC-01〜03 の TC は通過するため、メッセージ検証は AC-04〜07 の block ケースで assert する） |
| **AC-11** | **既存 TC 全 PASS**: `sh tests/extras/ta-25-approval-token-guard.sh` が、追加分を除く**既存の全 TC を PASS のまま**維持する。特に **T1023-TC-08**（read-only `cat` → rc=0）、**T1023-TC-09**（`cat <TOKEN> && echo hi > /tmp/other.txt` → 保守的 rc=2）、**T1023-TC-12 / TC-25 / TC-26 / TC-27**、および既存 mutation 7 種（TC-15〜17e）と baseline / restore（TC-15pre / TC-17post）が PASS |
| **AC-12** | **本 PBI の起点そのものが解消される**: `<TOKEN>` を対象とする **read-only 監査コマンド**（#1023 AC-09 相当。例: `find` / `grep` / `jq` による列挙で `2>/dev/null` を伴うもの）が guard を通過する。実測ログを evidence に残す |
| **AC-13** | **guard の syntax・実行可能属性が維持**（既存 TC-01 / TC-02 相当）され、`sh -n` が通る |

### 受入基準の件数

**13 件**（AC-01 〜 AC-13）。

---

## Notes from Refinement

### N-1: 実装対象ファイルの位置

`scripts/check-approval-token-write.sh` は **`scripts/` 直下**であり、Hardening Override の
9 カテゴリ（`scripts/hooks/*.sh` 等）には**該当しない**（guard 冒頭コメントにも
「配置: `scripts/` ルート（HO 外）」と明記されている）。

### N-2: Mode は plan で判定する（本 PBI では想定に留める）

`mode-classification.md` の「**承認境界周辺の変更 → 最低でも「高」**」は HO 9 カテゴリの
パスを対象とするが、本ファイルは **承認境界そのものを守るガード**であるため、
同ルールの趣旨（および「自動推定の安全側」条項）から **`high-risk` 相当が適用される可能性が高い**
と想定する。**最終判定は plan.md の Mode 判定で行う**。
plan では少なくとも次を明示すること:

- HO パス該当有無（機械判定: `scripts/hooks/*.sh` ではない → 非該当）
- それでも「承認境界周辺」として引き上げるか（安全側判断）
- `lite_eligible` の可否（安全側では `false`）

### N-3: 既存テスト機構への接続（実装制約）

`tests/extras/ta-25-approval-token-guard.sh` の mutation 機構（`_t25_mutate`）は以下の制約を持つ。
新規 TC はこれに適合させる必要がある。

1. 変異は **guard 内のアンカーコメントに対する `sed`** で行い、アンカーは**ファイル内で一意**
   （`grep -c` == 1）でなければならない。→ 新しいリダイレクト検査行に
   `# t1045-...` のような一意アンカーを付ける。
2. kill 判定は **mutation 子プロセスで「focused kill TC 群」だけを実行**し、
   指定した TC ラベルの `[FAIL]` が出ることで行う。→ **AC-01〜05 に対応する新 TC は
   focused 群（`PG_T25_MUTATION_CHILD=1` でも走る領域）に置く**必要がある。
3. `PG_T25_GUARD` env で guard 実体を差し替える方式のため、新 TC も `t25_guard` 系ヘルパ経由で
   起動し、guard パスをハードコードしないこと。
4. **stdin を redirect しない guard 起動を残さない**（T1023-TC-24 が検査。端末ハング防止 / R-027）。

### N-4: T1023-TC-09 が設計を拘束する

既存 T1023-TC-09 のフィクスチャは `cat <TOKEN> && echo hi > /tmp/other.txt` であり、
**`>` 検査だけが唯一の捕捉経路**である（`cp`/`tee` 等は含まれない）。
したがって修正方針は
「**`>` を token path 宛のときだけ block する**」であってはならない（TC-09 が FAIL する）。
正しい方向は **「任意のファイル宛リダイレクトは引き続き block、fd 複製と `/dev/null` 破棄のみ除外」**。

### N-5: 併記回避に対する多重防御は実測済み

`>` 除外を入れた場合に懸念される `cmd >/dev/null; cp <TOKEN> <dest>` 型の回避について、
起票時に **`>` を含まない形**（`cp <TOKEN> /tmp/x` 単独 / `tee <TOKEN>` 単独 /
`mv /tmp/x <TOKEN>` 単独）が **いずれも exit 2** であることを実測済み。
`>` 以外のルールが単独で機能しているため、`/dev/null` 除外を入れても当該回避は成立しない見込み。
ただし **AC-07 として本 PBI 内で再実測する**（起票時実測を根拠にしない）。

### N-6: 現状のメッセージ文言の問題

現行 `_block()` は `Bash command writes token path: <cmd>` を常に出す。読み取りコマンドで
これが出ることが原因究明を阻害している。AC-10 は「文言を柔らかくする」ことではなく
**「どのルールで一致したかを機械可読に出す」**ことを要求する。

### N-7: 本 PBI では触らない安全性契約

`exit 2`（PreToolUse block 契約）/ stdin 常時独立評価 / `parse-unknown` fail-closed /
TTY 即 fail-closed / `PLANGATE_SKIP_TOKEN_GUARD`（Human-owned escape hatch）は
**#1023 で確定した契約**であり、本 PBI では**一切変更しない**。

### N-8: ドキュメント記法の伝播

本 PBI 由来の plan / test-cases / handoff でも、**トークンパス literal を地の文に書かない**
（フィクスチャ変数として扱う）方針を踏襲する。修正完了後は不要になるが、
**修正がマージされるまでは本 PBI 自身の文書が誤 block の対象になりうる**ため。

---

## Estimation Evidence

### Risks

| ID | リスク | 影響 | 緩和 |
|----|-------|------|------|
| **R-1** | 除外条件を広げすぎ、**実際に書き込める記法が通る**（ガードの弱体化） | critical（承認境界の突破） | AC-04〜07 の退行 TC + AC-09 の「弱める側の変異」で機械検出。除外は fd 複製と `/dev/null` に限定 |
| **R-2** | `>` を「token path 宛のみ」に絞る誤った実装 → **T1023-TC-09 が FAIL** | major | N-4 を plan の Constraints に明記。AC-11 で既存 TC 全 PASS を要求 |
| **R-3** | `/dev/null` 除外を悪用した経路（例: `>/dev/null/../<TOKEN>` のようなパス細工、`>/dev/nullX`） | major | 除外パターンを `>` の直後に厳密一致する `/dev/null` **かつ後続が語境界**に限定。細工パターンを edge case TC 化 |
| **R-4** | `2>&1` 除外が `2>&1` と紛らわしい実書き込み（`2>file` / `&>file` / `>&file`）を巻き込む | major | `>&` の後続がファイル名（`/dev/null` 以外）なら block を維持。`&>` / `&>>` は書き込みとして扱う edge case TC を追加 |
| **R-5** | POSIX `sh` + BSD/GNU `grep` 双方での ERE 差異により、CI（Linux）とローカル（macOS）で挙動が割れる | major | `grep -E` の POSIX 範囲に留める。CI 実行結果を evidence に残す |
| **R-6** | mutation アンカーの一意性が壊れ、`_t25_mutate` が「anchor not unique」で FAIL | minor | アンカー文字列を `t1045-` prefix で新規採番し、guard 内 `grep -c` == 1 を実装時に確認 |
| **R-7** | 新 TC を focused 群の外に置き、mutation 子プロセスで実行されず **kill が実証されない**（#874 既往と同型） | major | N-3 の 2 を plan の Work Breakdown に明示。`[FAIL] <ラベル>` が出ることを実際に確認 |
| **R-8** | 承認境界に触る変更のため、Mode 判定を軽く見積もると C-3 ゲートが不適切に緩む | major | N-2。安全側で `high-risk` / `lite_eligible=false` を既定とし plan で確定 |
| **R-9** | 本 PBI の作業自体が誤 block に阻害される（自己参照） | minor | 記法規約（冒頭）+ トークン literal を含む調査は分割実行。必要時は `PLANGATE_SKIP_TOKEN_GUARD=1`（Human-owned）を人間に依頼 |

### Unknowns

| ID | 未確定事項 | 解消方法 |
|----|-----------|---------|
| **U-1** | 除外を「`/dev/null` のみ」に限るか、`/dev/stdout` `/dev/stderr` `/dev/fd/N` 等の擬似デバイスも含めるか | plan で決定。安全側の既定は **`/dev/null` のみ**（`/dev/stdout` はファイル宛になりうるため除外しない） |
| **U-2** | `&>` / `&>>`（bash 拡張の全出力リダイレクト）の扱い | plan で決定。**書き込みとして block 維持**が既定 |
| **U-3** | AC-10 のルール識別子の具体フォーマット（`rule=<id>` か、既存メッセージへの追記か） | plan で確定。既存 TC がメッセージ本文を assert していないことは確認済みだが、実装時に再確認する |
| **U-4** | 最終 Mode（`standard` か `high-risk` か）と `lite_eligible` | plan の Mode 判定で確定（N-2） |
| **U-5** | `.claude/settings*.json` 経由で実際に稼働している配線（Human-owned）に本修正が即時反映されるか、再適用が要るか | plan で `docs/ai/settings-wiring-contract.md` / `bin/plangate doctor --check-settings` を参照して確認。設定変更は本 PBI 範囲外（Human-owned） |
| **U-6** | 同種の粗い `>` 判定が他のガードスクリプトにも存在するか | plan の調査ステップで `scripts/` 配下を横断確認。存在した場合も**本 PBI の scope には入れず**、follow-up issue として起票する |

### Assumptions

| ID | 前提 |
|----|------|
| **A-1** | base は `origin/main` = `48f6971`。guard 実体は #1042（`15b0c16`）で入った版。 |
| **A-2** | `tests/extras/ta-25-approval-token-guard.sh` は base で **47 passed / 0 failed**（TC-06 は HO patch 未適用のため SKIP 扱いで pass 計上）。これを退行判定の baseline とする。**実測済み**。 |
| **A-3** | guard は POSIX `sh`（`set -eu`）で書かれており、`jq` を前提とする。実装も POSIX `sh` の範囲に留める。 |
| **A-4** | 変更対象ファイルは **`scripts/check-approval-token-write.sh` と `tests/extras/ta-25-approval-token-guard.sh` の 2 本**を基本とする（+ 本 PBI の working context ドキュメント）。`.claude/` 配下・`bin/plangate`・`.github/workflows/` は触らない。 |
| **A-5** | `_is_token_path()` の一致パターンは変更しない前提で AC を書いている。 |
| **A-6** | C-3 / C-4 は Human-owned。承認 artifact（`approvals/*.json`）は **AI が作成しない**。 |
| **A-7** | 本 PBI は #1023 / #1042 の契約（`exit 2` / fail-closed / stdin 常時評価）を維持したうえでの**判定精度の修正**であり、承認境界の緩和ではない。 |
