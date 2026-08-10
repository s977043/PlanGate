# PBI INPUT PACKAGE — TASK-0921

> Issue: [#921](https://github.com/s977043/plangate/issues/921)（bug / **priority:P1**）
> 由来: [#914](https://github.com/s977043/plangate/issues/914) の受入基準 AC-8（案 C のスコープ切り出し）
> **鮮度是正: 2026-08-05**。初版は 2026-07-31 / main `b45ab17`（#914 exec **前**）に作成されており、**#914 完遂・extras 増加により多数の前提が stale 化していた**ため全面差し替え（差分は「初版からの是正」節）
> **計測基点**: `tests/` の全数実測は main `646c9a4`。本ブランチの base は `a952872`（`646c9a4..a952872` は **docs 差分のみで `tests/` と `.github/` は無変更**を `git diff --stat` で実測済み）→ 実測値はそのまま有効
> 前段: #877（mass-delete guard fail-closed）→ **#914（R-204 判別統一）= CLOSED / [PR #986](https://github.com/s977043/plangate/pull/986) MERGED（`0ebb8fe`）** → **本 PBI**
> **River Review 反映（2026-08-05・major 6 / minor 4 / info 1 を全件反映）**: 帰属 PR の是正（MJ-1）/ カウンタ未初期化（MJ-2）/ 判定コマンド B の適用範囲（MJ-3）/ 早期 `exit 0`（MJ-4）/ 層 C の可解性（MJ-5）/ 層判別述語（MJ-6）ほか。**指摘の行番号・コミットはすべて本ブランチで独立に再実測して採用した**
> **本 PBI に残るのは exit code 伝播のみ**（判別式の AND 統一・standalone 7 env unset は #914 で完了済み）

## Context / Why

`tests/extras/` の各テストは `run-tests.sh` から `. "$extra"` で **source される前提**で書かれており、`pass` / `fail` の集計と exit code 化は harness 側が担う。一方 **standalone 実行**（`sh tests/extras/ta-XX-....sh`）にはその防御が無く、**内部で `[FAIL]` を何件出しても rc=0 で終了する**。

**#914** で「外部 env 汚染により harness 実行と誤判定し、1 件も検査せず exit 0 で素通りする」問題（判別式）は解消された。しかし **exit code 伝播は未着手**であり、`sh <file>` の終了コードだけでは以下を一切区別できない:

1. 全 PASS
2. **内部 FAIL あり**（本 PBI の主対象）
3. **fixtures 未解決のまま誤動作**して FAIL を量産
4. **1 件も実行していない / 実行したが検査対象が存在せず空振り PASS**（新規に実測で判明 — 層 C）

さらに issue 本文が指摘するとおり、「standalone 実行が exit 0」という形の受入基準は **伝播が無い限り無条件に成立する**ため、その AC を書いた PBI の検証がまるごと形骸化する。#914 は実際にこれを避けるため AC-6 を代理判定（`[FAIL]` 文字列不在 + `[PASS]` 件数 baseline 一致）へ退避し、`TASK-0914/handoff.md` の **§3「V2 候補」表**に **優先度 High** で記録している（行番号は PR #999 / #1001 で変動するため記号アンカーで参照 — F-7）。

### 実測による裏取り（main `646c9a4`・2026-08-05）

実行条件はすべて clean env + stdin 遮断（`ta-50` は stdin でハングする既知事象 — #914 plan RV-F2）:

```sh
env -u PLANGATE_HOOK_TASK -u PLANGATE_HOOK_FILE -u PG_HARNESS_SOURCED \
    -u FIXTURES_DIR -u PLANGATE_ALLOW_MASS_DELETE sh <file> </dev/null
```

| # | 論点 | 実測方法 | 結果 |
|---|------|---------|------|
| 1 | extras の全数 | `ls tests/extras/ta-*.sh \| wc -l` | **57**（初版の「53」から増加。`tests/extras/` 直下は他に `README.md` のみ） |
| 2 | **伝播を持つファイル**（静的判定） | 判定コマンド A（下記） | **4 件**: `ta-26-plugin-sync.sh` / `ta-58-git-destructive-guard.sh` / `ta-59-apply-settings-merge.sh` / `ta-60-run-evidence.sh`（初版の「ta-26 の 1 本だけ」から変化） |
| 2b | **各ファイルに伝播が入ったコミット**（帰属） | `git log -S'[ "$fail" -eq 0 ] \|\| exit 1' -- <file>` ほか | `ta-58` = **`0ebb8fe` / [PR #986](https://github.com/s977043/plangate/pull/986)**（#914 本体。squash 前 `7dad6dd`）/ `ta-59` = **`a667c0d` / [PR #976](https://github.com/s977043/plangate/pull/976)**（新規追加時点から保有）/ `ta-60` = **`73e6a15` / [PR #989](https://github.com/s977043/plangate/pull/989)**（同）。**PR #988（`7680145`）が入れたのは AND 判別 + 7 env unset のみで伝播ではない**（`git show 7680145` に当該行 0 件。`origin/main` の `TASK-0914/handoff.md`「本コミット（`7dad6dd`）が実際に直したもの」節が「ta-58 の standalone fallback …これは #988 の積み残し」と明記しており整合） |
| 3 | 同（動的判定・強制 fail 注入） | 判定コマンド B（下記） | **4 件が `rc=1`**。ただし **B が実際に注入できるのは `STANDALONE` マーカーを持つこの 4 本だけ**（#3b）。残り 53 本では注入が成立せず**判定不能**であり、A と B の一致はこの 4 本の範囲でのみ確認した |
| 3b | **判定コマンド B の適用可能範囲** | `grep -l 'STANDALONE' tests/extras/ta-*.sh` | **層 0 の 4 本のみ**。他 53 本では注入行番号 `n` が空になり生成コピーが原本と**バイト同一**になる（＝無改変で再実行しただけ）。**現状の B は修正前の層 A / B / C を一件も判別できない** → In scope 3 の fail-closed 規律に従い「**判定不能 = 検査 FAIL**」として扱い、注入位置の汎用化は plan で設計する（U-5） |
| 4 | harness 側の集計 / exit code | `tests/run-tests.sh:15-20` / `:163-181` を読解 + 実行 | **正常**。`PG_HARNESS_SOURCED=1`（**非 export**）を立てて source → `Results:` → `[ "$fail" -gt 0 ] && exit 1`。実測 **538 passed / 0 failed / rc=0**。**穴は standalone 側のみ** |
| 5 | **CI での実行経路** | `grep -rn 'tests/' .github/workflows/` | **`.github/workflows/test.yml:28` の `sh tests/run-tests.sh` のみ**。**CI から standalone 実行される extras は 0 件** → **CI が失敗を見逃す経路は現存しない**（実害は Human / AI の手元検証に限定 — 下記「実害経路」） |
| 6 | `ta-39` の現状（#914 T-10 で「汚染 env 下 7 FAIL / exit 0」と実測された事例） | `tail -6 tests/extras/ta-39-eh3-doc-light.sh` + 判定コマンド B | 判別式 AND 化と 7 env unset は **完了済み**（clean env で 8 PASS / 0 FAIL）。**末尾は `rm -rf "$_T39_TMP"` で終わり、サマリ / exit ブロックが無い**。fail 注入でも **rc=0** → **層 A（主対象）** |
| 7 | `ta-58-git-destructive-guard.sh` | `tail -15` + `git log -S` による帰属特定（#2b） | **issue コメント（2026-08-04）の「サマリ／exit code ブロックを持たない」は現 main では stale**。**`0ebb8fe`（PR #986 = #914 本体）** で standalone fallback（`pass`/`fail`/`register_cleanup` + 末尾 drain・サマリ・exit code）が追加済み。fail 注入で **rc=1** → **対象外（是正済み）**。**PR #988 への帰属は誤り**（#2b） |
| 8 | **TC-33 の行継続（`\`）false positive** | `sed -n '686,724p' tests/extras/ta-26-plugin-sync.sh` | **解決済み**。`_t26_unset_envs33()` は awk で `\` 継続行を 1 論理行へ畳んでから `grep -E '^[[:space:]]*unset '` を掛ける（`ta-26-plugin-sync.sh:700-711`。コメントに「旧実装は …false positive を出していた（#914 / PR #986 CI 実害。ta-60 が該当）」と明記） → **In scope から除外** |
| 9 | `tests/extras/README.md` の規約 | `sed -n '16,26p;125,195p' tests/extras/README.md` | **連番 1〜8 は `## 隔離・後始末の規約`（`:125-186`）の連番**（8 = 判別式 AND + 7 env unset、#914 で追記）。`## 規約`（`:16-26`）は**番号なし箇条書き**で別物（F-11）。**exit code 伝播の規約は不在** → AC-6 で「隔離・後始末の規約」の **8 の次に規約 9** を追記 |
| 10 | `sh tests/run-tests.sh` baseline | clean env で実行 | **538 passed / 0 failed / rc=0**（初版の「430」/「444 見込み」は失効。**絶対値をハードコードせず exec 開始時に再実測すること**） |
| 11 | **全 57 本の standalone 実行結果**（rc / `[PASS]` / `[FAIL]` を harness 実行と突合） | 全数走査（判定コマンド C） | **全 57 本が rc=0**。層別の結果は次節「問題の 4 層構造」 |

### 判定コマンド A（静的・伝播の有無）

```sh
grep -lE '(\$\{?fail[^ ]*"? *(-eq|-ne|-gt|!=) *"?0|\bfail\b.*\|\| *exit)' tests/extras/ta-*.sh
```

作成時点の出力は 4 件（#2）。**件数はハードコードせず、`ls tests/extras/ta-*.sh` との差集合を対象候補の定義とする**。
初版が「文字列 grep では確定できない」（`ta-09` の `exit 1` がコメント内の期待値記述で誤検出）と記録した問題は、**`fail` との共起を条件にすることで解消**した（本コマンドは `ta-09` を拾わない — 実測確認済み）。
**現時点で全 57 本を判別できる述語は A のみ**（B は 4 本にしか適用できない — #3b）。したがって **修正前の対象抽出は A + 下記「層判別の述語」で行い、B は修正後の検証に使う**（#914 plan RV-F4a と同じ規律）。

### 判定コマンド B（動的・強制 fail 注入 / AC-1・AC-5 検査器の原型）

**対象と同一ディレクトリ**に一時コピーを作り（`$0` 相対のパス解決を壊さないため）、standalone サマリブロックの直前へ `fail=$((fail + 1))` を注入して rc を見る:

```sh
n=$(grep -n 'STANDALONE' tests/extras/"$b" | tail -1 | cut -d: -f1)
awk -v ln="$n" 'NR==ln{print "fail=$((fail + 1))"} {print}' tests/extras/"$b" > tests/extras/_inject-"$b"
env -u PLANGATE_HOOK_TASK -u PLANGATE_HOOK_FILE -u PG_HARNESS_SOURCED \
    -u FIXTURES_DIR -u PLANGATE_ALLOW_MASS_DELETE sh tests/extras/_inject-"$b" </dev/null
# rc != 0 なら伝播あり / rc = 0 なら伝播なし
rm -f tests/extras/_inject-"$b"
```

**⚠️ 現状の B の適用範囲は層 0 の 4 本のみ**（裏取り #3b）。`grep -n 'STANDALONE'` が空を返すファイル（残り 53 本）では `awk -v ln=""` の条件が真にならず、生成コピーが原本とバイト同一になる＝**何も注入していない**。実測できたのは `ta-26` / `ta-58` / `ta-59` / `ta-60` = **rc=1**（伝播あり）のみで、**注入不成立の 53 本は「rc=0 = 伝播なし」ではなく判定不能（fail-closed 扱い）**である。
接頭辞 `_` により `ta-*.sh` glob と衝突しない（harness に拾われない）。**実行後の明示削除は必須**。

**plan で汎用化が必要**（U-5）: 層 A / B / C は standalone ブロックを持たないため、注入位置を「`STANDALONE` マーカー直前」に依存させられない。修正後は全対象が末尾ブロックを持つため B が全数に適用可能になる（＝**B は AC-2 / AC-3 の事後検証器としては成立し、AC-1 の事前分類器としては成立しない**）。

### 判定コマンド C（層分類）

**「harness と standalone の `[PASS]` 件数一致」は層判別に使えない**（層 C の `ta-11` / `ta-38` も一致するため層 A と誤分類する — 実測）。層判別は**構造述語**で行う:

| 述語 | 対象時点 | 現状の出力 | 限界 |
|------|---------|-----------|------|
| `grep -l 'FIXTURES_DIR:-' tests/extras/ta-*.sh` | 修正前 | **15 本**（層 0 の 4 + 層 A の 11） | **`ta-40` を落とす**（`ta-40:7-10` の root 自己補正は別書式） |
| `grep -lE '^[[:space:]]*(pass\|fail)=0' tests/extras/ta-*.sh` | 修正前 | **4 本**（層 0 のみ。層 A は 0/12） | 修正前は層 A を判別できない |
| **同上（修正後）** | **修正後** | 層 0 + 層 A = **16 本**（規約 9 の必須要件にする） | — |

→ **正規述語は「standalone 分岐で `pass` / `fail` を自前初期化しているか」とし、これを規約 9 の必須要件にする**（＝**修正後の状態**を述語にする）。**修正前の分類は allowlist + fail-closed で明示的に持ち、修正後は述語で自動判定に切り替える**（MJ-6 / D-4）。allowlist を恒久化しないことが AC-5 の要件。

---

## 問題の 4 層構造（本 PBI の中心整理 / 初版の 2 層を実測で 4 層へ精緻化）

| 層 | 定義 | 件数 | 該当ファイル | 症状 | 対処の方向 |
|----|------|------|------------|------|-----------|
| **層 0** | **伝播済み**（対象外）。standalone 分岐 + `pass`/`fail` 初期化 + 末尾ブロックを完備 | **4** | `ta-26` / `ta-58` / `ta-59` / `ta-60` | — | 変更しない。**層 A の複製元**（ta-26 が雛形） |
| **層 A** | ROOT / FIXTURES 解決の fallback を持ち、**standalone でもテスト本体が走る**（構造述語で判別 — 判定コマンド C） | **12** | #914 移行の 11 本（`ta-39` / `ta-43` / `ta-44` / `ta-45` / `ta-46` / `ta-47` / `ta-49` / `ta-50` / `ta-51` / `ta-52` / `ta-53`）+ **`ta-40`**（初版になし。`ta-40:7-10` が `schemas/c3-approval.schema.json` の不在を見て root を 1 段上げる自己補正 fallback を持つ） | 正しく実行され FAIL を数えるが **exit 0**。**加えて 12 本全数が `pass`/`fail` を初期化していない**（下記 A-1'）。**うち 7 本は早期脱出経路を持つ**（`\|\| exit 0` 型 3 + `\|\| true` 型 4。**2026-08-10 Human C-3 裁定 HJ-5 により 3 本 → 7 本へ是正**。下記 A-2'） | **`ta-26` パターンの複製 = フラグ + カウンタ初期化 + 末尾ブロックの 3 点を 12 本全数へ**。source 経路では exit しない。早期 exit 経路は別途 rc 設計（MJ-4） |
| **層 B** | fallback を持たず standalone で **誤動作した上で `[FAIL]` を出す** | **36** | `ta-04` / `ta-05` / `ta-07` / `ta-09` / `ta-10` / `ta-12` / `ta-13` / `ta-14-codex-guarded` / `ta-14-skip-acknowledge` / `ta-15`〜`ta-25` / `ta-27`〜`ta-31` / `ta-33`〜`ta-37` / `ta-41` / `ta-42` / `ta-54`〜`ta-57` | 誤動作 + **exit 0**（例: `ta-09` = 2 PASS / **21 FAIL** / rc=0、`ta-12` = 1 PASS / 13 FAIL / rc=0。`ta-04` は `$0` 相対解決が harness と異なり `tests/scripts/...` を見に行く） | **fail-fast ガード**（standalone 検知 → 明示メッセージ → **exit 2**）。完全 standalone 対応は大改修になるため原則やらない（U-1） |
| **層 C** | fallback を持たず、かつ検査対象が「存在しない」ため **`[FAIL]` を 1 件も出さずに空振り PASS / SKIP する** | **5** | `ta-11`（4 PASS。**python module 未解決で shell も python も空出力 → `shell≡python (<empty>)` が成立する偽 PASS**）/ `ta-38`（1 PASS。root が `tests/` になり glob が 0 件マッチ → 「違反なし」で PASS）/ `ta-32`（harness 2 → standalone 1。`sh: //scripts/… No such file`）/ `ta-06`（harness 1 → **0**。`[SKIP]` のみ）/ `ta-08`（harness 3 → **0**。`[SKIP]` のみ） | **`[FAIL]`=0 / rc=0** で完全に成功を装う | **In scope 1（伝播）では解けないが、In scope 2（fail-fast）では解ける**。5 本とも `PG_HARNESS_SOURCED` / `FIXTURES_DIR:-` が **0 ヒット**（実測）＝**層 B と同一の「fallback 非保持」クラス**で機械判別でき、fail-fast は `fail` カウンタに依存しないためそのまま適用できる（MJ-5 / D-2） |

> 合計 4 + 12 + 36 + 5 = **57**（#1 と一致）。**層 B + 層 C = 41 本は「fallback 非保持」という単一クラス**で、初版が「層 B = 41 本」と呼んだ集合と同一（初版の集合定義は正しく、症状で 2 分したのが本版の追加）。
>
> **層 B / 層 C に「fail 伝播（exit 1）」だけを足すのは誤り**: 誤動作した FAIL を非ゼロで返しても「テストが壊れている」と「対象が壊れている」を区別できない。層 C に至っては `fail` が増えないので伝播が効かない。**standalone 実行自体を拒否する fail-fast（exit 2）が両者に共通の正しい対処**。

### A-1'（MJ-2）: 層 A 12 本は **全数がカウンタ未初期化**

実測: `grep -lE '^[[:space:]]*(pass|fail)=0' tests/extras/ta-*.sh` → **層 0 の 4 本のみ**。`: "${pass:=0}"` 等の別形も 0 件。**層 A の 11 本（#914 移行分）+ `ta-40` = 12 本すべてが未初期化**で、standalone 分岐が持つのは 7 env unset と ROOT 解決のみ。集計は `pass=$((pass + 1))`（`ta-39:40-41`）＝**sh の未定義変数の算術展開に依存**した状態のまま（初版が R-102 として正しく記録していた事実）。

**帰結（見積りに直結）**:

- **「`ta-40` だけ 3 点必要・他 11 本は末尾ブロックのみ」は誤り**。**12 本すべてでフラグ + カウンタ初期化 + 末尾ブロックの 3 点**が要る
- **初期化なしで `[ "$fail" -eq 0 ] || exit 1` を足すと `[ "" -eq 0 ]` の評価になり、dash では `illegal number` で偽の非ゼロ終了**を生む（`ta-59` / `ta-60` 形式をそのまま複製する場合の落とし穴）。`ta-26` 形式（`[ "$fail" != "0" ]`）なら空文字は `!= "0"` が真になり**やはり偽の exit 1**。**初期化は伝播の前提条件**であって任意の追加作業ではない

### A-2'（MJ-4 / **2026-08-10 Human C-3 裁定 HJ-5 により 3 本 → 7 本へ是正**）: 層 A の 7 本は**末尾ブロック追加だけでは実害経路が塞がらない**

`ta-39:53-63` は doc-light 未適用時に `[SKIP] TC-01〜06` を出して早期終了する（standalone 側は `ta-39:61` の `exit 0`）。同型は `ta-43:56` / `ta-44:49`（`return 0 2>/dev/null || exit 0`。standalone では `return` が関数外でエラーとなり `exit 0` へ落ちる）。

**初版が 3 本としていたのは誤りであり、実際は 2 型 7 件である**（R-021 の実測。起点 grep を `exit 0` ではなく `return 0 2>/dev/null` に取ると取りこぼさない）:

| 型 | 対象 | シェル依存 | 区分 / 期待 rc |
|---|---|---|---|
| `return 0 2>/dev/null \|\| exit 0` | `ta-39` / `ta-43` / `ta-44` | dash / sh / zsh とも終了 | ファイル全体ガード → **rc=3** |
| `return 0 2>/dev/null \|\| true` | `ta-45` / `ta-46` / `ta-47` | **dash = 終了 / sh(bash) = 本体が継続** | ファイル全体ガード → **rc=3** |
| 同上 | **`ta-49`** | 同上 | **節スキップ** → 先行 TC の結果に従う（0 or 1）+ SKIP 診断 |

**うち `fail` を握り潰す実例は `ta-43` / `ta-44` の 2 本**（SKIP 分岐内で `tXX_fail` を呼びうるまま早期脱出するため `fail>0` かつ rc=0）。

**Impact**: 本 pbi が最優先と位置づける実害経路（`apply-eh3-doc-light.sh:68` → `ta-39`）は、**apply が失敗して doc-light が入っていないときこそ**この SKIP 分岐に入る。末尾ブロックを足しても**到達前に exit 0 する**ため、「適用が失敗していても rc=0」という症状は **In scope 1 だけでは解消しない**。層モデルが「ファイル単位」であって「実行経路単位」でないことによる盲点。

**Fix 方針**: 早期 exit 経路に **rc 設計**を与える（例: 前提未充足 SKIP は **exit 3** = 「検査していない」を rc で表明。exit 1 = テスト失敗 / exit 2 = 実行方法エラー と分離）。**AC-2 に「前提未充足 SKIP 状態での rc」を検査項目として追加**する。

### 実害経路（CI ではなく Human-owned 検証で顕在化する）

CI は harness 経由のみ（裏取り #5）だが、**`apply-*.sh` 系（Human-owned 適用スクリプト）が standalone 実行を検証手順として案内している**:

| 案内元 | 案内している standalone 実行 | 層 | 伝播 |
|--------|---------------------------|----|------|
| `scripts/apply-eh-git-destructive-guard.sh:31,174` | `sh tests/extras/ta-58-git-destructive-guard.sh` | 層 0 | あり（**`0ebb8fe` / PR #986** で是正済み） |
| `scripts/apply-precompact-guard.sh:21,131` | `sh tests/extras/ta-50-precompact-guard.sh` | 層 A | **なし** |
| **`docs/ai/precompact-memory-guard.md:129`** | `sh tests/extras/ta-50-precompact-guard.sh` | 層 A | **なし**（F-9。正本ドキュメント側からも同じ検証手順が案内されている） |
| `scripts/apply-eh3-doc-light.sh:68` | `sh tests/extras/ta-39-eh3-doc-light.sh` | 層 A | **なし**（かつ **A-2' の早期 `exit 0` 経路に該当** — 最優先） |

すなわち **Human が settings wiring を適用したあとの検証で、適用が失敗していても rc=0 が返る**。Shadow Configuration 防止（`.claude/rules/working-context.md` の settings タスクロック）と同型のリスクであり、**層 A の中でも `ta-39` / `ta-50` は優先度が高い**。特に `ta-39` は **A-2' の早期 exit により In scope 1 単独では塞がらない**点に注意。

---

## What（Scope）

### In scope

1. **層 A（12 本）**: `ta-26` パターンを全数へ適用 = **standalone フラグ + `pass`/`fail` の自前初期化 + 末尾サマリ + `fail != 0 → exit 1` の 3 点**（A-1' により **12 本全数で初期化が必要**）。加えて **早期脱出経路を持つ 7 本は rc 設計**（ファイル全体ガード 6 本 = `ta-39` / `ta-43` / `ta-44` / `ta-45` / `ta-46` / `ta-47` は前提未充足 = exit 3 / **`ta-49` は節スキップのため先行 TC の結果に従う**）（A-2' / HJ-5 裁定）
2. **層 B + 層 C（41 本）**: standalone 実行の **fail-fast ガード**（検知 → 明示メッセージ → **exit 2**）を適用。両層とも `PG_HARNESS_SOURCED` / `FIXTURES_DIR:-` を持たない単一クラスとして機械判別できる。※方針自体は plan 冒頭で確定（U-1 / D-1・D-2）
3. **対象の全数分類と検査の機械化**: **件数をハードコードしない**検査として固定する
   - 各起動は **`sh "$f" </dev/null` を必須**（未リダイレクトだと `ta-50` が無限ハング — #914 plan RV-F2）
   - **pre-fix の層判別は rc では不能**（修正前は層 A も B も C も rc=0 で同値）。判別は **fallback 構造の有無**（判定コマンド C の構造述語）で行い、rc 検査（判定コマンド B）は**適用後の検証**に使う（RV-F4a）
   - **判定コマンド B は現状 4 本にしか適用できない**（裏取り #3b）。注入位置の汎用化を plan で設計し、**注入が適用できないファイルは検査 FAIL（fail-closed）**として silently skip を禁止する（RV-F4b）
   - **修正後の正規述語**（規約 9 の必須要件）へ移行し、修正前の allowlist を恒久化しない（MJ-6 / D-4）
4. **回帰テスト**: 意図的に fail させた状態で「層 A = exit 1」「層 B = exit 2」「harness 経由 = `run-tests.sh` が完走して集計（exit しない）」を**負側テスト**で固定
5. **`tests/extras/README.md` に規約 9 を追記**: 「standalone 実行では fail を exit code へ伝播する（層 A）/ harness 専用は fail-fast する（層 B）」
6. **`TASK-0914/handoff.md` §3「V2 候補」表の『#921 完了時に AC-6 の判定を exit code ベースへ戻す』行をクローズ**（代理判定の解消。行番号でなく記号アンカーで指す — F-7）

### Out of scope / Non-goals

| 項目 | 理由 |
|------|------|
| **判別式の AND 統一**（`PG_HARNESS_SOURCED` × `FIXTURES_DIR`）と standalone 側 7 env unset | **#914 / PR #986 で 11 本 + `ta-26` すべて完了済み**（裏取り #6）。本 PBI は触らない |
| **TC-33 の行継続（`\`）false positive** | **main で解決済み**（`ta-26-plugin-sync.sh:700-711` の awk 実装 — 裏取り #8） |
| `ta-58-git-destructive-guard.sh` の伝播追加 | **`0ebb8fe`（PR #986 = #914 本体）で是正済み**（裏取り #2b / #7）。issue コメントの記述は現 main では stale。**PR #988 は AND 判別 + 7 env unset のみで伝播は入れていない**（MJ-1 で是正） |
| `tests/run-tests.sh`（harness 側集計）の変更 | 正常動作を実測済み（裏取り #4）。source 経路の挙動は不変とする |
| **各 extras の検査内容そのものの見直し** | 伝播は「結果の返し方」の是正であり、テスト内容は不変 |
| 層 B の完全 standalone 対応（fallback 追加による 36 本の大改修） | fail-fast で足りる前提。必要なら別 issue |
| `tests/extras/README.md`「現行テスト一覧」表のドリフト是正（57 本中 12 本のみ掲載） | issue 本文が Out of scope と明記。別の文書負債 |
| テストフレームワークの導入・置き換え | issue Non-goals |

### 順序依存（初版の懸念は解消済み）

初版は「層 A の対象が #914 T-07 の 11 本と同一のため **#914 exec 完了後に着手**」と記していた。**#914 は PR #986（`0ebb8fe`）でマージ済み**のため、この待ちは解消。ただし `tests/extras/` は直近も動いている（**`ta-58` = `0ebb8fe`（#986）/ `ta-59` = `97c2e2d`（#996）が最終変更**）ため、**exec 直前に `git log --oneline -- tests/extras/` で直近変更を確認する**こと。

---

## 受入基準

> issue #921 の AC-1〜AC-6 を継承し、4 層構造の実測を反映して精緻化。plan で最終確定する。

- **AC-1**: `tests/extras/ta-*.sh` のうち「standalone 実行時に `fail > 0`（層 A）または未定義前提での誤動作（層 B）でも exit 0 を返す」ものが **0 件**。判定は**文字列 grep でなく実行ベース**（fail 注入 → rc 検査 = 判定コマンド B）で行い、**件数をハードコードしない**
- **AC-2**: **層 A 12 本の各ファイル**について、以下を負側テストで固定する:
  - (a) 意図的に 1 件 fail させた standalone 実行が **exit 1** になる
  - (b) **同じ fail 注入状態のまま** source 経路（`sh tests/run-tests.sh`）で実行しても **`run-tests.sh` が完走して当該 fail を集計する**（= source 中に exit しない。通常グリーン実行での代用は不可 — #914 plan RV-F5）
  - (c) **【MJ-4 で追加 / 2026-08-10 Human C-3 裁定 HJ-5 により 3 本 → 7 本へ更新】前提未充足 SKIP 状態での rc** — **早期脱出 2 型 7 件**について、**前提（apply 未実行）を満たさない状態で standalone 実行したときの rc が「検査していない」を表明する**。対象と期待 rc は以下のとおり（**7 本は同質ではない**）:
    - **`|| exit 0` 型 3 件**: `ta-39` / `ta-43` / `ta-44`
    - **`|| true` 型 4 件**: `ta-45` / `ta-46` / `ta-47` / `ta-49`（R-021 の実測により追加。`|| true` 型は dash では終了・bash では本体が継続するというシェル依存を持つ）
    - **rc=3（＝検査していない）の対象は「ファイル全体ガード」6 本**: `ta-39` / `ta-43` / `ta-44` / `ta-45` / `ta-46` / `ta-47`。**rc=0 は不可**
    - **`ta-49` は「節スキップ」のため rc=3 を要求しない**: ガード到達前に層 A の先行 TC が実走・集計済みであるため、rc は**先行 TC の結果に従う**（0 または 1）+ SKIP 診断。rc=3 にすると「検査していない」の誤表明になり、`fail>0` を rc=3 へ丸めない precedence とも矛盾する
    - **早期脱出イディオムの除去は 7 本すべてで行う**（分岐するのは「rc の意味」だけ）
    - これを満たさない限り実害経路（`apply-eh3-doc-light.sh:68` → `ta-39`）は塞がらない
  - (d) **カウンタ初期化の存在**（A-1'）— 初期化なしで末尾ブロックだけを足すと `[ "" -eq 0 ]` / `[ "" != "0" ]` の評価となり **偽の非ゼロ終了**を生むため、初期化を AC の一部として固定する
- **AC-3**: **層 B + 層 C 41 本の各ファイル**について、standalone 実行が**明示メッセージ付き exit 2** で即終了する（誤動作も空振り PASS もしない）。※既存 extras の `exit 2` 参照（`ta-39` / `ta-42` / `ta-50`）はいずれも**サブプロセス戻り値の比較**でありトップレベル終了コードではないため機能衝突しない（実測）。ただし「`ta-*.sh` 自身の exit 2 = standalone 誤用検知」という新しい意味を導入するため、test-cases で意味レイヤー（exit 1 = テスト失敗 / exit 2 = 実行方法エラー / exit 3 = 前提未充足）を明記する
- **AC-4**: `sh tests/run-tests.sh` が回帰しない。**baseline は exec 開始時に再実測した値を正とする**（作成時点 **538 passed / 0 failed / rc=0**。**絶対値をハードコードしない**）。加えて **`ls tests/extras/ta-*.sh | tail -1` が出力する最終ファイルの `[PASS]` が harness ログに現れる**ことを確認し、source 経路の途中終了を検出する（**ファイル名をハードコードしない** — F-8）
- **AC-5**: AC-1 の検査が**回帰テストとして `tests/extras/` に追加**され、**新規スクリプト追加時の伝播漏れを将来も検出できる**。**修正後は「standalone 分岐で `pass`/`fail` を自前初期化しているか」を正規述語として自動判定する**（判定コマンド C）。**修正前の allowlist は移行期間のみ保持し恒久化しない**。除外集合を残す場合は allowlist を明示し、将来の追加ファイルが黙って除外されない構造にする（MJ-6 / D-4）
- **AC-6**: `tests/extras/README.md` の**「隔離・後始末の規約」の連番 8 の次に規約 9** として層 A / 層 B+C の規約が明記され、**TASK-0914 の AC-6 代理判定を exit code ベースへ戻せる状態にする**（`TASK-0914/handoff.md` の **§3「V2 候補」表の『#921 完了時に AC-6 の判定を exit code ベースへ戻す』行**をクローズ）。U-3 の分岐別充足条件（#914 plan RV-F3）: **含める場合** = #914 検証手順の exit code 化まで本 PBI で完了 / **含めない場合** = 戻せることの実証（層 A 全数の rc 検査 PASS）+ follow-up 起票 + handoff 記録をもって充足
- **AC-7（本 PBI で追加起案 — issue には無い）**: 追加した検査が **修正前実装で FAIL する**ことを実証する（変異注入 / 旧実装での空振り確認）。`.claude` メモリ「新規テストは変異注入で検出力を実証」に従い、修正前 HEAD 版で新 TC が FAIL する evidence を残す

---

## 決めるべきこと（plan 決定事項）

| ID | 論点 | 選択肢 |
|----|------|-------|
| **D-1** | **層 B（36 本）の対処**（= U-1） | (i) fail-fast exit 2（**初版からの推奨**） / (ii) 伝播（exit 1）を足すだけ（**非推奨** — 誤動作と本物の失敗が区別できない） / (iii) 本 PBI の対象外にし別 issue へ切り出す（#914 の案 C と同型。**代償: 同じファイル群を再度触る**） |
| **D-2** | **層 C（5 本）の扱い**（= U-2） | (a) 「検査件数 0 / harness baseline 未満なら非ゼロ終了」ガードを入れる / (b) 別 issue へ分離 / **(c)【MJ-5 で追加・推奨】層 C を層 B と同一の fail-fast 対象に含める** — 層 C の 5 本は `PG_HARNESS_SOURCED` / `FIXTURES_DIR:-` がいずれも 0 ヒットで**層 B と機械的に同一クラス**であり、fail-fast は `fail` カウンタに依存しないため**空振り PASS を完全に塞げる**。この場合 In scope 2 の対象は **36 → 41 本**（初版の「層 B = 41 本」と同一集合） |
| **D-3** | 実装形態（= U-4） | (a) 各ファイルへ雛形ブロックをインライン複製（`ta-26` と同形・自己完結・冗長。#914 は「extras 自己完結の慣習」を理由に E-2 = インラインを採用） / (b) 共通 preamble（`tests/extras/_standalone.sh`）を source（重複排除。**53 本規模なら損益分岐が変わる可能性** — plan で再比較。`ta-*.sh` glob と衝突しない `_` 接頭辞が前提）。**A-1' により層 A も「末尾ブロックだけ」では済まず 3 点セットになるため、(b) の相対優位が初版想定より上がる** |
| **D-4** | AC-1 / AC-5 の分類・除外集合の表現（= MJ-6） | (a) 修正前 allowlist のみ（**恒久化すると件数ハードコードの再導入**） / (b) **修正後の正規述語（`pass`/`fail` 初期化の有無）を規約 9 の必須要件にし、allowlist は移行期間限定**（推奨） / (c) 両方を併記して移行完了時に allowlist を削除する DoD を置く |
| **D-5** | スライス分割（Mode に直結） | 層 A 12 + 検査基盤 + README ≈ **15 本**（high-risk 帯の上限）を Slice 1、**層 B + 層 C = 41 本**を Slice 2 以降へ。**41 本は単独でも 16+ = critical 帯**のため ≤15 本のサブスライス **3 本**に割るか critical 受容で一括するかを確定。**D-2 (c) 採用時は Slice 2 以降の総量が 36 → 41 本**（サブスライス 3 分割なら 1 本あたり 13-14 本で high-risk 帯に収まる） |

---

## Mode 判定案

**判定案: Slice 1（層 A 先行）= `high-risk` / 一括 = `critical`**。**plan で D-5 と連動して確定**し、判定不能な間は**安全側 = `critical`**。

| 軸 | 実測 / 想定 | モード |
|----|-----------|-------|
| 変更ファイル数（定量） | Slice 1 = 層 A 12 + 回帰テスト 1 + README 1 = **14** / 一括 = 層 A 12 + 層 B+C 41 + 2 = **55**（D-2 (c) 採用時。非採用なら 50） | **high-risk**（6-15） / **critical**（16+） |
| 受入基準数（定量） | **7**（AC-1〜AC-7。うち AC-2 は 4 サブ項目 a-d） | high-risk（6-10） |
| タスク数（見込み・定量） | **16-24**（初版想定 12-20 から **+4**）。内訳の増分: **① 層 A 12 本のカウンタ初期化**（A-1' — 「末尾ブロックのみ」ではなくなった）/ **② 早期脱出 7 本の rc 設計 + AC-2 (c) の負側テスト**（A-2'。**HJ-5 裁定により 3 本 → 7 本**）/ **③ 判定コマンド B の注入位置汎用化**（MJ-3 — 現状 4 本にしか効かない）/ **④ 正規述語への移行と allowlist 廃棄 DoD**（MJ-6） | **high-risk 上限〜critical**（一括なら 21+ = critical 確定） |
| 変更種別（定性） | 既存パターンのミラー適用（**新規設計なし** = `ta-26` 複製）。ただし **A-2' の rc 設計（exit 3 の意味レイヤー導入）は新規設計に該当**し、定性を standard → high-risk 側へ押し上げる | **high-risk**（初版は standard 相当としていた） |
| リスク（定性） | **高**。source 経路に `exit` が漏れると `run-tests.sh` が途中終了し **以降の extras が一切実行されないまま少ない件数で 0 failed を返す**（= **CI が静かに緑になる**最悪ケース） | high-risk |
| 影響範囲（定性） | `tests/` に閉じる。プロダクトコード・hooks・CI 定義には波及しない | standard |
| ロールバック（定性） | 容易（`tests/extras/` の revert のみ。生成物・状態を持たない） | light |

> mode-classification の「定量と定性の高い方を採用」により、**層 B+C を一括で扱うと定量 16+ で critical 固定**になる（初版 R-104 の指摘を維持）。
>
> **River Review 反映による見積り変化（MJ-2 / MJ-4）**: タスク数は **12-20 → 16-24**、定性「変更種別」は **standard 相当 → high-risk**（exit 3 の意味レイヤーが新規設計）、Slice 2 以降の総量は **36 → 41 本**（D-2 (c) 採用時）。**Slice 1 の 14 本という規模は変わらないが、1 本あたりの変更量が「末尾ブロック追加」から「フラグ + 初期化 + 末尾ブロック（+ 7 本は rc 設計 — HJ-5 裁定により 3 本 → 7 本）」へ増える**。判定案自体（Slice 1 = high-risk / 一括 = critical）は維持。

**Hardening Override**: **非該当**。変更対象 `tests/extras/**` / `tests/extras/README.md` は `scripts/hooks/check-plan-hash.sh` の override 9 カテゴリ（`.claude/rules/` / `.claude/settings*.json` / `.claude/commands/` / `.claude/agents/` / `scripts/hooks/` / `bin/plangate` / `schemas/` / `.github/workflows/` / `AGENTS.md`・`CLAUDE.md`）の**いずれにも該当しない** → `lite_eligible` 強制 false や Standard 同期 C-3 の強制は**発生しない**。ただし **`high-risk` 以上のため C-3 は人間必須**（autonomous APPROVE 不可）であり、実質 `lite_eligible=false`。

---

## Notes from Refinement

### `ta-26` 雛形（層 A の複製元・実測）

`tests/extras/ta-26-plugin-sync.sh` の 2 ブロックが雛形。**standalone 側の unset は判別ブロック内、exit は末尾ブロック**という配置が要点。

冒頭（`ta-26-plugin-sync.sh:18-37`）— **#914 で完了済み。本 PBI は変更しない**:

```sh
if [ "${PG_HARNESS_SOURCED:-0}" != "1" ] || [ -z "${FIXTURES_DIR:-}" ]; then
  PG_T26_STANDALONE=1
  unset PLANGATE_SKIP_REASON PLANGATE_HOOK_TASK PLANGATE_HOOK_FILE \
    PLANGATE_BYPASS_HOOK PLANGATE_HOOK_STRICT PG_HARNESS_SOURCED \
    PLANGATE_ALLOW_MASS_DELETE 2>/dev/null || true
  FIXTURES_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/../fixtures" && pwd)"
  pass=0
  fail=0
  _PG_T26_CLEANUP_PATHS=""
  register_cleanup() {
    for _pg_cp in "$@"; do
      if [ -n "$_pg_cp" ]; then
        _PG_T26_CLEANUP_PATHS="${_PG_T26_CLEANUP_PATHS}${_pg_cp}
"
      fi
    done
  }
else
  PG_T26_STANDALONE=0
fi
```

> **F-10**: `register_cleanup` は **no-op ではなく `_PG_T26_CLEANUP_PATHS` へ蓄積する実装**（`ta-26:26-35`）で、末尾ブロックの drain（`:737-741`）と**対で機能する**。no-op 版（`register_cleanup() { :; }`）を 12 本へ複製すると drain と噛み合わず**一時ディレクトリが残る**。上記は実体の verbatim 引用（正は `ta-26:18-37`）。

末尾（`ta-26-plugin-sync.sh:736-746`）— **本 PBI が層 A 全数へ展開する部分**:

```sh
# 単体実行時のみ: cleanup drain + サマリ + exit code（source 時は run-tests.sh が担う）
if [ "$PG_T26_STANDALONE" = "1" ]; then
  printf '%s' "$_PG_T26_CLEANUP_PATHS" | while IFS= read -r _pg_cp; do
    if [ -n "$_pg_cp" ]; then
      rm -rf "$_pg_cp" 2>/dev/null || true
    fi
  done
  printf '\nTA-26 standalone: %s passed, %s failed\n' "$pass" "$fail"
  if [ "$fail" != "0" ]; then
    exit 1
  fi
fi
```

`ta-59-apply-settings-merge.sh:506-507` / `ta-60-run-evidence.sh` は同構造をより簡潔に書いた版（`[ "$fail" -eq 0 ] || exit 1`）。**どちらの書き方も機能等価だが、判定コマンド A（静的 grep）を安定させるため plan で 1 つに寄せることを推奨**（D-3 / D-4 と連動）。**ただし `-eq` 形は空文字（未初期化）で dash が `illegal number` を返すため、A-1' のカウンタ初期化とセットでなければどちらの形も使えない**。

### 層 A のカウンタ初期化について（初版 R-102 を復元 / MJ-2）

初版が正しく記録していた事実を鮮度是正で退行させていたため復元する。実測（`grep -lE '^[[:space:]]*(pass|fail)=0' tests/extras/ta-*.sh`）:

| 集合 | `pass`/`fail` 初期化 |
|------|--------------------|
| 層 0（`ta-26` / `ta-58` / `ta-59` / `ta-60`） | **あり**（4/4） |
| 層 A（#914 移行 11 本） | **なし**（**0/11**。`: "${pass:=0}"` 等の別形も 0 件） |
| 層 A（`ta-40`） | **なし**（判別ブロック自体を持たない） |

つまり **層 A 12 本すべてが `pass=$((pass + 1))`（`ta-39:40-41`）の未定義変数算術に依存**した状態。**「`ta-40` だけ 3 点必要」ではなく 12 本全数で 3 点（フラグ + 初期化 + 末尾ブロック）が必要**。
**対象特定に `pass=0` の grep を使わないこと**（修正前は層 A を 1 本も拾えない）。**逆に修正後はこの述語が層判別の正規述語になる**（判定コマンド C / MJ-6）。

### 早期 `exit 0` 経路について（MJ-4）

| ファイル | 早期 exit の位置 | 形 |
|---------|----------------|---|
| `ta-39-eh3-doc-light.sh` | `:53-63`（standalone 側は `:61`） | doc-light 未適用時に `[SKIP] TC-01〜06` を出し、harness なら `return 0`、standalone なら `exit 0` |
| `ta-43-eh2-strict-json.sh` | `:56` | `return 0 2>/dev/null \|\| exit 0`（standalone では `return` が関数外エラーとなり `exit 0` へ落ちる） |
| `ta-44-eh457-cli-wiring.sh` | `:49` | 同上 |

いずれも **`fail` を増やさずに rc=0 で終わる**ため、末尾ブロックを足しても到達せず症状が残る。AC-2 (c) で rc 設計（exit 3）を固定する。

### 層 B + 層 C の fail-fast 検知条件

`PG_HARNESS_SOURCED` 非設定（#914 完了により全 extras で使える統一シグナル）を第一候補とする。`FIXTURES_DIR` 単独判定は #914 が明示的に廃した方式なので使わない。
**層 B と層 C はこの検知条件に対して同一の振る舞いをする**（両層とも `PG_HARNESS_SOURCED` / `FIXTURES_DIR:-` の記述を 1 件も持たない — 実測）ため、**同じガードを 41 本へ一様に適用できる**（MJ-5）。

---

## Estimation Evidence

### Risks

| ID | リスク | 影響 | 一次緩和 |
|----|-------|------|---------|
| **R-1** | **source 経路（harness）で誤って exit する** | **`run-tests.sh` が途中で死に、以降の extras が実行されないまま少ない件数で 0 failed / rc=0 を返す**（最重大・CI が静かに緑） | `ta-26` と同じく standalone フラグの内側でのみ exit。AC-2 の「harness では exit しない」負側テスト + AC-4 の総 PASS 件数突合 + 最終 extras（`ta-60`）の PASS 出現確認で三重に固定 |
| **R-2** | 層 B / 層 C に fail 伝播（exit 1）だけを足す | 「テストが壊れた」と「対象が壊れた」を区別できず調査コストが増える。層 C では `fail` が増えないので伝播自体が無効 | 層 B + C は fail-fast（exit 2）。exit 1（テスト失敗）/ exit 2（実行方法エラー）/ **exit 3（前提未充足 SKIP）** を意味的に分離（AC-2 (c) / AC-3） |
| **R-3** | **層 C を「解決した」と誤認する** | 空振り PASS（`ta-11` の `<empty>` 一致 PASS 等）が残ったまま AC-1 が PASS し、**issue の Why（3 状態を区別できない）が未解決のまま閉じる** | **D-2 (c)（層 C を fail-fast 対象に含める）で構造的に解消できる**（MJ-5）。含めない場合は **handoff に「AC-1 は層 C を充足しない」と明記**し follow-up を起票 |
| **R-4** | **意図的に exit 0 を返している extras を壊す** | 環境差による `[SKIP]` 設計（README 規約 6。`ta-35` / `ta-36` / `ta-06` / `ta-08`）が FAIL 化して落ちる | **SKIP は `fail` を増やさない**設計が既存（実測: `ta-06` / `ta-08` は `[SKIP]` のみで `[FAIL]` 0）。伝播は `fail` カウンタのみを見るため SKIP は無影響。ただし層 C（SKIP による静かな縮退）は別問題（D-2） |
| **R-5** | 判定コマンド B の一時ファイル（`_inject-*`）が残る / glob に拾われる | harness が誤って実行 / 作業ツリー汚染 | `_` 接頭辞で `ta-*` glob と衝突させない。**実行後の明示削除必須**。回帰テスト側は `register_cleanup` + 末尾明示 `rm` の二重（README「隔離・後始末の規約」） |
| **R-6** | **層 B の standalone 実行が実ファイルへ副作用を出す** | 誤 root 解決による artifact 誤配置 | **本 PBI の調査中に実際に発生**（`tests/docs/working/_audit/hook-events.log` が生成された — 調査者が削除済み）。分類・検証の実行は**使い捨て worktree / 隔離 cwd** で行う（#914 plan RV-F6） |
| **R-7** | `ta-50` が stdin でハングする | 回帰テストがブロックする | すべての standalone 実行に **`</dev/null`** を付ける（本 PBI の全実測でも適用済み） |
| **R-8** | 50 本超の一括編集でコンフリクト | 他の進行中 PBI（`tests/extras/` を触るもの）と衝突 | D-5 のスライス分割。exec 直前に `git log --oneline -- tests/extras/` を確認。**直近の実変更は `ta-58` = `0ebb8fe`（#986）/ `ta-59` = `97c2e2d`（#996）**（PR #988 = `7680145` はその前段） |

### Unknowns

| ID | 不明点 | 解消方法 |
|----|-------|---------|
| **U-1** | **層 B（36 本）+ 層 C（5 本）の対処方針の最終確定** | D-1 / D-2。fail-fast（exit 2・推奨）か、選択的に standalone 対応を足すか。検知条件は `PG_HARNESS_SOURCED` 非設定を第一候補 |
| **U-2** | **層 C（5 本）を本 PBI で扱うか** | D-2。**In scope 1（exit code 伝播）では解けないが In scope 2（fail-fast）では解ける**ことが実測で確定済み（5 本とも fallback シグナル 0 ヒット = 層 B と同一クラス）。issue 本文 Why の「3 状態を区別できない」はこの層に対応する |
| **U-3** | AC-6 の「#914 検証手順の exit code 化」を本 PBI に含めるか follow-up にするか | AC-6 に分岐別の充足条件を明記済み。plan で選択 |
| **U-4** | 共通 preamble 化（`_standalone.sh` 共有）の是非 | D-3。#914 は「extras 自己完結の慣習」でインラインを採用したが、48 本規模で損益分岐が変わる可能性 |
| **U-5** | **fail 注入の汎用手段**（AC-1 / AC-5 の検査基盤） | 57 本の実装形状はヘルパー関数形式（`tXX_pass()` / `tXX_fail()`）と直書き `fail=$((fail+1))` に分かれ、README が案内する `assert_pass` / `assert_fail` は **`ta-*.sh` 内では未使用**（`run-tests.sh` 本体埋め込み専用）。判定コマンド B は**行注入方式でこれを回避している**（実装形状に非依存）が、**standalone ブロックを持たないファイル（層 B / 層 C）への注入位置**は plan で設計する |

### Assumptions

| ID | 前提 | 根拠 |
|----|------|------|
| **A-1** | **#914 は完了済み**（層 A の判別式が `PG_HARNESS_SOURCED` AND 方式に統一済み） | PR #986 MERGED（`0ebb8fe`）/ issue #914 CLOSED。**初版の「#914 は C-3 待ち」は失効** |
| **A-2** | **CI は harness 経由のみ**で extras を実行する | `grep -rn 'tests/' .github/workflows/` → `test.yml:28` のみ（裏取り #5）。**本 PBI に CI 破壊のリスクは原則ない**（R-1 の source 漏れを除く） |
| **A-3** | `sh tests/run-tests.sh` baseline は **exec 開始時に再実測**する | 作成時点 538 passed / 0 failed は参考値。**ハードコード禁止**（初版の「430 / 444」は既に失効しており、同じ失効を繰り返さない） |
| **A-4** | 層 0 の 4 本の standalone exit パターンが引き続き正 | 4 本とも同一構造で、それぞれ **`ta-26`（#914 以前から）/ `ta-58` = `0ebb8fe`（#986）/ `ta-59` = `a667c0d`（#976）/ `ta-60` = `73e6a15`（#989）** のレビューを通過済み（**#988 ではない** — MJ-1） |
| **A-5** | SKIP は `fail` を増やさない | README 規約 6 の実パターン（`ta-35` / `ta-36`）と `ta-06` / `ta-08` の実測で確認 |

---

## 初版（2026-07-31 / main `b45ab17`）からの是正

| 初版の記述 | 現 main（`646c9a4`）での実測 | 是正理由 |
|-----------|---------------------------|---------|
| extras は **53 本** | **57 本** | `ta-54`〜`ta-60` の追加 |
| 伝播を持つのは **`ta-26` の 1 本だけ** | **4 本**（`ta-26` / `ta-58` / `ta-59` / `ta-60`） | `ta-58` = `0ebb8fe`（**#986**）/ `ta-59` = `a667c0d`（#976）/ `ta-60` = `73e6a15`（#989）。**#988 は AND 判別 + 7 env unset のみ**（MJ-1 で是正） |
| #914 は **C-3 待ち**。本 PBI の exec は #914 完了後 | **#914 CLOSED / PR #986 MERGED** | 順序依存は解消済み |
| baseline = **430**（#914 マージ後は 444） | **538 passed / 0 failed** | 実測。**以後ハードコードしない**（A-3） |
| **層 A = 11 本**（#914 T-07 対象と同一） | **層 A = 12 本**（`ta-40` を追加） | `ta-40-task-0129-review-gate.sh:7-10` の root 自己補正 fallback を実測で確認 |
| **層 B = 41 本** | **層 B = 36 本 + 層 C = 5 本** | 全数実測で「誤動作 + FAIL」と「空振り PASS / SKIP」を分離 |
| 2 層構造（層 A / 層 B） | **4 層構造**（層 0 / A / B / C） | 伝播済み（層 0）と空振り（層 C）を独立の層として明示 |
| 「確実な判定は実行ベース検査のみ」（`ta-09` の `exit 1` 誤検出） | 静的判定も **`fail` との共起条件**で誤検出を排除できる（判定コマンド A）。ただし**判定の正は実行ベース（B）** | 静的検査を対象抽出の一次フィルタとして使えるようにした |
| （記載なし） | **TC-33 の行継続バグは解決済み**（`ta-26-plugin-sync.sh:700-711`） | issue コメント（2026-08-04）の追加論点。**In scope から除外** |
| （記載なし） | **CI からの standalone 実行は 0 件**（`test.yml:28` のみ） | 実害範囲を Human-owned 検証に限定できることを確定 |
| （記載なし） | **`apply-*.sh` が standalone 実行を検証手順として案内**（`ta-39` / `ta-50` は伝播なし） | 具体的な実害経路を特定 |

---

## 参照

- issue: [#921](https://github.com/s977043/plangate/issues/921)（本文 + コメント 2 件。うち 2026-08-04 コメントの `ta-58` 記述は現 main では stale — 裏取り #7）
- 前提 PBI: `docs/working/TASK-0914/handoff.md` — **記号アンカーで参照**（行番号は PR #999 / #1001 で変動するため使わない）: §2「既知課題」表の『extras standalone の exit code 伝播欠落』行 / §3「V2 候補」表の『#921 完了時に AC-6 の判定を exit code ベースへ戻す』行 / §4「妥協点」表の『案 C』『AC-6 を代理判定で検証』2 行 / 「本コミット（`7dad6dd`）が実際に直したもの」節（MJ-1 の根拠）
- 雛形: `tests/extras/ta-26-plugin-sync.sh:18-37,736-746` / `tests/extras/ta-59-apply-settings-merge.sh:506-507` / `tests/extras/ta-60-run-evidence.sh`
- 層 A の追加分: `tests/extras/ta-40-task-0129-review-gate.sh:7-10`（root 自己補正 fallback）
- 層 C の代表例: `tests/extras/ta-11-plan-hash-contract.sh:15-17`（fallback 無し・`<empty>` 一致で偽 PASS）/ `tests/extras/ta-38-agent-tools.sh:8-13`（glob 0 件マッチで偽 PASS）
- 規約: `tests/extras/README.md` — **連番 1〜8 は `## 隔離・後始末の規約`（`:125-186`）の連番**であり、`## 規約`（`:16-26`）は番号なし箇条書き（F-11）。**規約 9 は「隔離・後始末の規約」の 8 の次に追記**する。ほかに `## set -e 互換書法`（`:57-`）
- harness: `tests/run-tests.sh:15-20`（7 env unset）/ `:163-181`（source ループ + 集計 + exit）
- CI: `.github/workflows/test.yml:28`
- Human-owned 適用スクリプト（standalone 実行を案内）: `scripts/apply-eh3-doc-light.sh:68` / `scripts/apply-precompact-guard.sh:21,131` / `scripts/apply-eh-git-destructive-guard.sh:31,174`
