---
task_id: TASK-1044
artifact_type: review-external
schema_version: 1
status: reflected
verdict: REJECT
created_by: claude
---

# TASK-1044 外部レビュー結果（C-2 / 追記専用集約）

> レビュー日: 2026-08-12 / **対象 base: `6089e23`（origin/main）** / branch: `docs/1044-c2-reflect`
> 対象 plan_hash（レビュー時点）: `sha256:64337b7f45dbb069c0f91bb7706cff661a6c521ca00d517511bc9e04cadc025f`
> 実施根拠: Mode = **high-risk** のため C-2 は必須（`.claude/rules/mode-classification.md`
> フェーズ適用マトリクス）。本 PBI は plan 作成〜C-1 まで進んだ時点で C-2 が未実施
> だったため、**本ファイルが C-2 の初回記録**である（以後は追記専用）。
> レーン定義: `.claude/rules/review-principles.md` §7-bis（2 レーン責務契約）。
>
> **本記録はマージ後の追補である**: TASK-1044 の plan パッケージは PR #1049
> （旧 branch `docs/1044-plan`・レビュー時 base `48f6971`）として **既に main へマージ済み**
> だが、その時点で `review-external.md` は存在せず **C-2 未実施のまま**であった。
> 本ファイルと 1 回確定反映は `6089e23` を base とする新 branch `docs/1044-c2-reflect`
> で行う。**`approvals/c3.json` は未発行**であり、plan 編集可能期間内であるため
> EH-3 mismatch は発生しない（`bin/plangate validate TASK-1044` は C-2 不在で FAIL していた）。
> **本反映の完了前に `approve TASK-1044` を打つと、C-2 REJECT の plan が承認された
> 状態になる**ため、承認は本反映の反映後に行うこと。

## 判定

| レーン | verdict | critical | major | minor | info |
|---|---|---|---|---|---|
| 設計妥当性レーン（plan / todo / test-cases / pbi-input） | **REJECT** | 0 | 4 | 3 | 1 |
| コードベース整合レーン（`tests/extras/` 実体） | **REJECT** | 0 | 3 | 2 | 0 |
| **統合** | **REJECT** | **0** | **7** | **5** | **1** |

`.claude/rules/review-principles.md` §4「Human review required / 判定」に照らし、
major ≥ 1 のため **修正必須**。C-3 は本ファイルの確定反映後に人間が判断する。

---

## 指摘一覧（R-NNN）

### R-001 [major / コードベース整合レーン] 本 PBI の修正が「静かに通るテスト」を 4 本作る

**対象**: `tests/extras/ta-61-extra-contract.sh:383-437`（tc01.sh / tc01b.sh）,
`:581-604`（tc21.sh）, `:621-644`（tc26-runner.sh + tc26-file1.sh） /
`test-cases.md` エッジケース末尾

これらの fixture は **`tc01.sh` 等の非 `ta-*.sh` 名**で `sh "$fx"` 実行され、
**bootstrap を持たず helper を直接 source** する。plan の変数消費形では
`_pg_extra_direct` 未設定 → 既定 `1` = direct → **3 env の値に関わらず standalone**
へ落ちる。

plan は「TC-01 等は更新必要」と気づいている（「帰結（exec で必ず対応）」）が、
**落ち方が「赤くなる」ではなく「静かに PASS」である**点を扱っていない。

レビュアーが提案パッチを適用した複製で実測:

| fixture / TC | 提案パッチ適用後の挙動 | 判定 |
|---|---|---|
| TC-01（harness 非侵襲） | standalone finalize が exit 0 → 後続 counters 検証行に到達せず rc=0 | **PASS（空振り）** |
| TC-01b（2 env 漏出） | rc=0 | **PASS（空振り）** |
| TC-01c（HR-4 = 空 EXTRAS_DIR） | rc=0 | **PASS（空振り）** |
| TC-21（harness register_cleanup） | `harness-def:probe-path` 出力 + rc=0 | **PASS（空振り）** |
| TC-26（set -eu 非切断） | rc=1・`mini-marker: file2` 消失 | FAIL（唯一 loud に落ちる） |

**決定打**: helper の 3 env 述語を `PG_HARNESS_SOURCED` 単独へ退行させる変異を
注入しても **TC-01c は rc=0 で生存**することを実測。**HR-4 回帰テストの検出力が
完全に失われる**。

さらに `test-cases.md` エッジケース末尾の
「2 env のみ漏出（部分汚染）: 既存 TC-01b/01c が standalone 解決を検証済み → **不変**」
は **本 plan 適用後は成立しない**（不変どころか空振り化する）。

**是正要求**:

- fixture 更新を「harness 模擬は `_pg_extra_direct=0`」だけでなく、
  **「standalone 期待 fixture も `_pg_extra_direct=0` を明示し、env 述語を唯一の
  判別子として残す」**と規定する（`tc01b.sh` に `_pg_extra_direct=0` を入れて初めて
  TC-01b/01c は元の意味を回復する）
- **AC-8 を追加**: 「ta-61 の全 helper 直接 source fixture が `_pg_extra_direct` を
  明示設定しており、**未設定の fixture が 0 件**」を**静的検査 TC** 化
- **変異 M-4 を追加**: helper の 3 env 述語を 1 条件へ退行させる変異で
  **TC-01b/01c が FAIL（kill）すること**を実証。これがないと AC-7（既存 TC 無回帰）は
  「空振りでも PASS」を許容する
- `test-cases.md` エッジケース末尾の「不変」記述を**訂正**

> 本 PBI は「静かに通る失敗を塞ぐ」PBI である。その修正自体が「静かに通るテスト」を
> 4 本作るのは目的と正面衝突する。

### R-002 [major / コードベース整合レーン] 更新対象 fixture の列挙が不完全

**対象**: `plan.md` S5 / `test-cases.md` TC-36

両者とも「tc01.sh / tc01b.sh **等**」としか書いていないが、実物で harness 前提の
fixture は **3 群**存在する:

- `tc01.sh`（`:383`）/ `tc01b.sh`（`:410`）
- **`tc21.sh`（`:582`）** ← 空振り PASS
- **`tc26-runner.sh`（`:631`）+ `tc26-file1.sh`（`:621`）** ← loud に FAIL
  （rc=1・`mini-marker: file2` 消失）

**AC-4 の機械照合は bootstrap 14 箇所 + helper のみが対象で、fixture は照合網の外**である。

**是正要求**: **`tc01.sh` / `tc01b.sh` / `tc21.sh` / `tc26-runner.sh`（または
`tc26-file1.sh`）の完全列挙**を plan / test-cases に書く。導出根拠
（`grep -l 'PG_HARNESS_SOURCED=1'` の fixture heredoc）も併記し、将来の fixture
追加漏れは **AC-8 の静的 TC** で担保する。

### R-003 [major / コードベース整合レーン] TASK-0921 の変異 evidence 18 本の HEAD 整合失効が plan で扱われていない

**対象**: `docs/working/TASK-0921/handoff.md`（既知課題 2-bis）/ `plan.md` 正本管理節 / AC-5

TASK-0921 handoff 2-bis は明文で「**helper を変更すると変異 evidence 18 本の HEAD
整合が失効するため本 PR では修正しない**」と述べ、これを理由に F-3 を見送っている
（carry-over も同旨）。

**本 plan は S3 で helper を、S4 で 14 ファイルを変更する**ため、
**evidence commit 〜 head の `tests/` 差分ゼロという 18 本の有効性根拠がその瞬間に
失効**する。plan の AC-5 は新ガード用の M-1〜M-3 のみで、**18 本の扱い
（再測定 / 上書き / 「superseded」宣言）に触れていない**。

**是正要求**: plan の「正本管理」表に **evidence 継承行**を追加し、いずれかを明示決定する:

- **(a)** S7 で 18 本を再走して HEAD 整合を張り直す（コスト大）
- **(b)** 「TASK-0921 の 18 本は #1044 で HEAD 整合失効。本 PBI の M-1〜M-4 が後継」と
  宣言し、**TASK-0921 handoff 既知課題 2-bis に解消注記**を入れる

併せて **AC-9 を追加**: 「TASK-0921 handoff 既知課題 2 / 2-bis に本 PR の解消・
および evidence 継承の扱いが 1 行で追記されている」。

### R-004 [major / 設計妥当性レーン] AC-2 が 4 つの消費箇所を 1 行に束ね、TC-31 は 2 つしか検証しない

**対象**: `pbi-input.md:71`（AC-2）/ `test-cases.md` TC-31

AC-2 は「**7 env unset・カウンタ初期化・summary 出力・rc 0/1/3 契約**」の 4 つを
1 行に畳んでいるのに、TC-31 の期待出力は「summary 行が出る」「rc が 0/1/3」の
**2 つだけ**。

**7 env unset とカウンタ初期化は誰も検証しない**。とくに 7 env unset は
「3 env 漏出環境で直接実行」という本 PBI のシナリオと同じ土俵にあり、
**漏出 env が子プロセスへ伝播したままでも TC-31 は緑**になる。

**是正要求**: AC-2 を **AC-2a（rc 契約）/ AC-2b（summary 書式）/ AC-2c（7 env unset の
実測 — 子プロセスで `env | grep -c '^PLANGATE_\|^PG_HARNESS_SOURCED'` が 0）/
AC-2d（カウンタ初期化）**へ分割し、TC-31 の期待出力を 4 点すべてへ拡張する。

### R-005 [major / 設計妥当性レーン] AC-4 が「14 箇所」という絶対件数を契約値にしており TC-35 と矛盾

**対象**: `pbi-input.md:73`（AC-4）/ `test-cases.md` TC-35 / `plan.md` DoD

TC-35 は正しく「**絶対件数を契約値にせず、対象リストとの同値で判定**」と書いている
のに、上位契約の AC-4 は「**14 箇所**」を固定している。

`tests/extras/` は成長ディレクトリであり、**Slice 2 が層 B/C を bootstrap へ移行した
瞬間に 14 は嘘**になる。さらに「対象リスト」の定義自体が plan に無く、
**固定リストか marker 由来の動的導出か未確定**である。固定リストなら Slice 2 が
旧述語で新ファイルを足しても緑（偽陰性）、件数固定なら無関係 PR が層 A に 1 本
足しただけで CI が落ちる（偽陽性）。

**正解の先例が既にある** — `ta-26` TC-33 は件数をハードコードしない grep ベース検査。

**是正要求**: AC-4 を「**bootstrap marker（`# ---- extras execution contract bootstrap`）
を含む extras 全ファイル**で判定 2 行がバイト一致（**現時点の実測母数は 14 で、
件数は契約値ではない**）」へ書き換え、TC-35 の対象リストを **marker 由来の動的導出**
と明記する。

### R-006 [major / 設計妥当性レーン] 同一クラスの脆弱述語が残る 5 本が plan のどこにも書かれていない

**対象**: `pbi-input.md` Out of scope / handoff 素材（plan S8）

オーガナイザーが実測で裏取り済み（本ワーカーも独立に再確認 — 下記「反証・独立検証」参照）:

| 対象 | 述語 |
|---|---|
| `ta-25` / `ta-26` / `ta-58` / `ta-59` / `ta-60` | **2 env AND**（`PG_HARNESS_SOURCED` + `FIXTURES_DIR`） |
| 層 A（#1046 で移行済み） | 3 env AND |

これは #1044 の根本原因（「実際に source されているかを見ていない代理指標」）と
**同一クラスで、条件が 1 つ少ないぶん更に破りやすい**。plan の Out of Scope は
「層 B / C の**移行作業**（Slice 2）」という言い方で、
「**この脆弱性が 5 本に残る**」という残存エクスポージャの明示ではない。

**issue #1044 のタイトル・AC はどれも「塞ぐ」と読める**ため、マージ後に
「extras 全体で塞がった」と誤読される。

**是正要求**: pbi-input の Out of Scope に「**残存エクスポージャ**」節を新設し、
**5 本を明示列挙 + 各々が 2 env 判定である旨**を記す。handoff の TASK-0921 対応表
（S8）に「#1044 で塞いだ範囲 = bootstrap 系 13 本、**未塞ぎ = 5 本（Slice 2 へ）**」の
行を必須要素として追加する。**AC 追加までは不要**（scope 外の是正は求めない）が、
**記録は AC 化しないと落ちる**。

### R-007 [major / 設計妥当性レーン] Constraints「harness source 経路で exit しない（R-024）」と AC-6（exit 4）が正面衝突し未調停

**対象**: `plan.md:17`（Constraints）/ `pbi-input.md:75`（AC-6）/ `plan.md` Q-1

Constraint は「**harness source 経路で非 0 return / exit しない**（R-024 継承）」を
**無条件**の制約として掲げているのに、AC-6 は init 前 finalize で **`exit 4`** を
**無条件**に要求する。

F-3 節は散文でトレードオフを論じているが、**Constraints 側に例外の注記がなく、
AC-6 側にも「R-024 の carve-out」の記載がない**。exec 実装者が Constraints を
優先すれば AC-6 が FAIL、AC-6 を優先すれば Constraint 違反になる。

**Q-1（C-3 裁定）は「どちらの方式か」を問うており、「制約に穴を開けてよいか」という
別レイヤの論点を含んでいない。**

**是正要求**: Constraints に「ただし `pg_extra_contract_finalize` の init 前呼出
（契約違反の mis-wire）に限り例外 — Q-1 裁定に従う」を追記し、AC-6 に
「**R-024 の明示 carve-out**」と併記。**Q-1 の設問文にも「R-024 に carve-out を
設けることの可否」を含める**。

### R-008 [minor / 設計妥当性レーン] `_pg_extra_direct` 自体が新たな env 漏出面

bootstrap は無条件代入するので層 A は安全だが、**bootstrap を持たず helper を直接
source する consumer は `_pg_extra_direct=0` を明示設定する**方針＝
「`_pg_extra_direct=0` が環境から漏れていれば harness と誤判定」という
**#1044 と同型の窓**が新設される。将来 bootstrap の代入が
`: ${_pg_extra_direct:=…}` へ「最適化」されると即座に回帰する。

**是正要求**: **TC-30 のバリアント**として「`_pg_extra_direct=0` を export した状態で
層 A を直接実行 → それでも standalone」を追加し、**無条件代入を pin** する。

### R-009 [minor / 設計妥当性レーン] 「4 シェル」の同一性が evidence 契約に落ちていない

pre-fix 表で `sh` が bash と同じ rc=1・dash のみ rc=0 という分布は、
**測定ホストの `/bin/sh` が bash 3.2（macOS）**であることを示唆＝実質 3 実装。
**CI 実体（dash）と `sh` の対応が evidence から復元できない**。

**是正要求**: EV-1 / EV-2 の記録項目に「**各シェルの実体**
（`ls -l /bin/sh` / `$BASH_VERSION` / `dash --version`）とホスト」を必須化する。

### R-010 [minor / 設計妥当性レーン] Mode 判定の分母に docs 成果物が含まれていない

exec PR には status / current-state / handoff / evidence が加わり **16+（critical 帯）**に
届きうる。実害は小（差分は V-4 のみ）だが、
**「working context 成果物は分母に含めない」という前提を明記していないこと自体が曖昧**。

**是正要求**: plan の Mode 節に 1 行明記する。

### R-011 [minor / コードベース整合レーン] F-3 スニペットの挿入位置が `_PG_EXTRA_ORIGINAL_RC=$?` に対して固定されていない

**対象**: `tests/extras/_extra-contract.sh:116`（`_PG_EXTRA_ORIGINAL_RC=$?`）/ `plan.md` F-3 節

`pg_extra_contract_finalize` は L116 で `$?` を捕捉する契約（HJ-4 = (b)・直前に
コマンドを挟まない）。**前に入れると `[ -z … ]` が `$?` を潰し rc 伝播（TC-06）が
壊れる**。

**是正要求**: 「必ず `_PG_EXTRA_ORIGINAL_RC=$?` の**直後**」と 1 行明記する。

### R-012 [minor / コードベース整合レーン] `_pg_extra_direct` の非 export グローバル継承が規約化されていない

`_pg_extra_direct` は**非 export のグローバル**で、`run-tests.sh` は同一シェルで
extras を順次 source するため、**bootstrap を持たないファイルは直前ファイルの値を
継承**しうる。非 export のため子へ漏れない点は設計として正しいが、
**「トップレベル設定必須」が規約化されていない**。

**是正要求**: `tests/extras/README.md` 規約 8 への 1 行 + AC-8 の静的 TC で担保する。

### R-013 [info / 設計妥当性レーン] AC-5 の変異が単数形で M-1 だけが必須に読める

変異は AC-5 に載っており「関数でなく call site を壊す」も明記済みで良好。ただし
AC-5 本文が「ガードの call site を壊す変異」**単数形**なので、文言上 M-1 だけが
必須に読める。

**是正要求**: AC-5(b) を「**M-1 / M-2 / M-3 / M-4 の全変異で kill を実証**」と列挙する。

---

## 両レーンが「問題なし」と確認した項目（再検証不要）

| # | 確認事項 | 確認者 |
|---|---|---|
| OK-1 | **AC ↔ TC の orphan は 0 件** | 設計レーン（自ら計数） |
| OK-2 | **zsh `FUNCTION_ARGZERO` の主張は正しい**（`/bin/zsh` にスクリプトを渡して再現。関数内 `$0` = 関数名） | 整合レーン |
| OK-3 | **変数消費形ガードの機構自体は 4 シェルで実測 green**（helper 存在 + 3 env 漏出 + 直接実行 → 全シェル rc=0 / helper 欠落 → 全シェル rc=1） | 整合レーン |
| OK-4 | **AC-4 の「14 箇所」は実測と一致**（層 A 12 + ta-61 ×2 + helper 1 = 15 出現、helper 分離で bootstrap 14）※ 件数を契約値にする点は R-005 で別途指摘 | 整合レーン |
| OK-5 | **HO 境界は非該当**（`check-plan-hash.sh:124-134` の 9 カテゴリ literal のいずれにも不一致） | 設計レーン |
| OK-6 | **`ta-26` TC-33 との整合は問題なし**（件数ハードコードなし・新 bootstrap は `PG_HARNESS_SOURCED` を保持し unset 行を増減しない） | 整合レーン |
| OK-7 | **`ta-61` の実行時契約 5 点は影響を受けない**（per-file ループは直接実行なので常に direct=1 → 従来と同じ standalone 経路） | 整合レーン |
| OK-8 | **`$0` アンカー禁止規約（TASK-0921）との非矛盾**（「helper のディレクトリ解決に使うな」であり「直接実行検知に使うな」ではない） | 設計レーン |
| OK-9 | **AC-3 の回帰リスクは低い**（`run-tests.sh:169` が `. "$extra"` で source するため harness 経路の `$0` は `run-tests.sh` のまま） | 整合レーン |

---

## 反証・独立検証（反映担当ワーカーによる一次確認）

指摘をそのまま受け入れず、反映前に本 worktree（`tests/extras/` 実体 = `6089e23`。
`tests/` は #1049 のマージで変化していないため `48f6971` と同一）で読み取り
検証した結果。**反証に至った指摘は 0 件**（全 13 件を採用）。

| 指摘 | 独立確認の内容 | 結果 |
|---|---|---|
| R-001 / R-002 | `grep -n 'PG_HARNESS_SOURCED=1' tests/extras/ta-61-extra-contract.sh` → `384`（tc01.sh）/ `584`（tc21.sh）/ `638`（tc26-runner.sh）の **3 群**。tc01b.sh は `PG_HARNESS_SOURCED="${T61_PHS:-0}"`（TC-01c で `T61_PHS=1`）。いずれも `sh "$_T61_FX/tcNN.sh"` 実行で **bootstrap を持たず `. "$T61_HELPER"` で helper を直接 source** | 指摘どおり（4 fixture） |
| R-001（空振り方向） | TC-01 は `pg_extra_contract_finalize` の**後**に counters 検証行を置く構造（`:390-397`）。standalone finalize は exit するため後続行に到達しない → rc=0 で PASS。TC-01b/01c は期待値が `pass=0`/`fail=0` ＝ standalone 側と同値のため区別不能 | 指摘どおり |
| R-001（TC-26 が loud） | `tc26-runner.sh` が `. "$T61_FXDIR/tc26-file1.sh"` → `. "$T61_FXDIR/tc26-file2.sh"` の順で source し、file2 の marker と `Results:` 行の**両方**を grep する（`:645-650`）ため standalone 化で必ず落ちる | 指摘どおり |
| R-003 | `docs/working/TASK-0921/handoff.md` 既知課題 2-bis に「**helper を変更すると変異 evidence 18 本の HEAD 整合が失効するため本 PR では修正しない**」の文言を実在確認 | 指摘どおり |
| R-006 | `grep -n 'PG_HARNESS_SOURCED' tests/extras/ta-{25,26,58,59,60}*.sh` → 5 本すべて `[ "${PG_HARNESS_SOURCED:-0}" != "1" ] \|\| [ -z "${FIXTURES_DIR:-}" ]`（ta-58 は肯定形）＝ **2 env AND**。層 A の 3 env AND と異なる | 指摘どおり（5 本） |
| R-011 | `tests/extras/_extra-contract.sh:116` が `_PG_EXTRA_ORIGINAL_RC=$?`、`:117` が `[ "${_PG_EXTRA_STANDALONE:-0}" = "0" ]`。関数本体の 1 行目が `$?` 捕捉であることを確認 | 指摘どおり |

---

## 監査表（追記専用 / squash・rebase 耐性）

| R-NNN | severity | lane | status | reflected_in(commit) | notes |
|---|---|---|---|---|---|
| R-001 | major | 整合 | reflected | `46416aa` | AC-8 新設 + fixture 規約 + M-4 + エッジケース訂正 |
| R-002 | major | 整合 | reflected | `46416aa` | 4 fixture 完全列挙（plan S5 / TC-36） |
| R-003 | major | 整合 | reflected | `46416aa` | **(b) superseded 宣言**を採用 + AC-9 新設 |
| R-004 | major | 設計 | reflected | `46416aa` | AC-2 → AC-2a/2b/2c/2d、TC-31 を 4 点へ拡張 |
| R-005 | major | 設計 | reflected | `46416aa` | AC-4 を marker 由来の動的導出へ、14 は実測母数 |
| R-006 | major | 設計 | reflected | `46416aa` | Out of scope に「残存エクスポージャ」節 + S8 handoff 行 |
| R-007 | major | 設計 | reflected | `46416aa` | Constraints に carve-out、AC-6 併記、Q-1 設問拡張 |
| R-008 | minor | 設計 | reflected | `46416aa` | TC-30b（`_pg_extra_direct=0` export でも standalone） |
| R-009 | minor | 設計 | reflected | `46416aa` | EV-1 / EV-2 にシェル実体 + ホスト記録を必須化 |
| R-010 | minor | 設計 | reflected | `46416aa` | Mode 節に「working context 成果物は分母外」1 行 |
| R-011 | minor | 整合 | reflected | `46416aa` | F-3 挿入位置を `_PG_EXTRA_ORIGINAL_RC=$?` 直後に固定 |
| R-012 | minor | 整合 | reflected | `46416aa` | README 規約 8 追記を Q-2 から確定化 + AC-8 で担保 |
| R-013 | info | 設計 | reflected | `46416aa` | AC-5(b) を M-1〜M-4 の列挙形へ |

> `46416aa`: 本ファイル作成と 1 回確定反映を同一 commit で行った（監査表の SHA は
> 同 commit を直後に追記して確定。rebase / squash で SHA が変わった場合は
> commit message 末尾の `Refs: R-001 … R-013` が対応関係の二次証跡になる）。
> 以後の追記は別 commit で行い、本表へ行を追加する（既存行は編集しない）。

## 反映順序（`.claude/rules/working-context.md` C-2 差分管理）

1. 本ファイルへ R-001〜R-013 を集約（本 commit）
2. plan / pbi-input / test-cases / todo へ **1 回確定反映**（`Refs: R-001 … R-013`・本 commit）
3. 簡易 C-1 再実行 → `review-self.md` へ追記し `C1-VERDICT` を新 plan_hash で更新（本 commit）
4. 人間が最終 `approvals/c3.json`（`c3_status=APPROVED`・確定後 plan_hash）を発行
5. exec 開始

**c3.json は未発行**であり、本反映は plan 編集可能期間内に行われた（EH-3 mismatch なし）。

---

## C-2 Round 2（追記専用 / R-014 以降）

> レビュー日: 2026-08-12 / 対象 branch: `docs/1044-c2-reflect`（head `853a443`・base `6089e23`）
> 対象 plan_hash（レビュー時点）: `sha256:9c93cbf9268cfe4f6665b2b5a5baf47db91ac6482a64dad925c427608982e920`
> **上記 Round 1（R-001〜R-013）の記述は一切編集していない**（追記専用規約）。

## Round 2 判定

| レーン | verdict | critical | major | minor | info |
|---|---|---|---|---|---|
| 設計妥当性レーン | **REJECT** | 0 | 1 | 1 | 1 |
| コードベース整合レーン | **REJECT** | 0 | 1 | 3 | 0 |
| **統合** | **REJECT** | **0** | **2** | **4** | **1** |

**Round 1 の major 7 件（R-001〜R-007）はすべて実質解消**と両レーンが確認
（後掲「Round 2 で実質解消を確認した項目」）。Round 2 の新規指摘は
**major 2 / minor 4 / info 1** で、いずれも 1 文〜1 行の是正。

## Round 2 指摘一覧（R-014〜R-020）

### R-014 [major / コードベース整合レーン] 「完全列挙 = 4 本」と AC-8 / TC-37 の走査母数（12 本）が矛盾

**対象**: `plan.md`「帰結」節 規約 3 / `test-cases.md` TC-36・TC-37 / `todo.md` T-06

実測（オーガナイザー裏取り済み・反映担当も再実行）:
`grep -c '\. "\$T61_HELPER"' tests/extras/ta-61-extra-contract.sh` → **12**。
内訳（行番号）: `:391` / `:416` / `:440` / `:454` / `:468` / `:494` / `:512` / `:530` /
`:553` / `:590` / `:606` / `:623`
（= `tc01` / `tc01b` / `tc02` / `tc03` / `tc04` / `tc06` / `tc07` / `tc08` / `tcskip` /
`tc21` / `tc23` / `tc26-file1`）。

plan の 4 本（`tc01` / `tc01b` / `tc21` / `tc26-runner`）は
**「`PG_HARNESS_SOURCED` を明示設定する部分集合」**であって **TC-37 の走査母数ではない**。

**失敗シナリオ**:

- exec が「完全列挙 = 4」に従うと **TC-37 が残り 8 本を未設定として FAIL**
- 逆に TC-37 を green にするため走査対象を 4 本の固定リストへ狭めると、
  **AC-8 が謳う「将来の追加漏れに対する唯一の機械検出点」が手書きリストへ退化**し
  **R-001 / R-002 が実質復活**する

**AC-4 で「絶対件数を契約値にしない」を徹底した本 plan が、AC-8 側で「4 本」という
件数契約を残しているのは自己矛盾である。**

**是正要求**:

1. 規約 3 の見出しを「**挙動が変わる fixture（部分集合）**」へ改める
2. 「**`_pg_extra_direct` の明示設定は helper を直接 source する全 fixture
   （本 PR 時点の実測 12 本）に適用する。件数は契約値でなく `. "$T61_HELPER"` 由来で
   動的導出**」を 1 行追加（AC-4 と同じ規約に揃える）
3. **`tc26` の 2 ファイル構造に対する TC-37 フィルタの精度**を併記: literal フィルタに
   マッチするのは **`tc26-file1.sh` であって `tc26-runner.sh` ではない**。
   `_pg_extra_direct=0` はどちらに置いても機能するが、**TC-37 が検査する側に置く**ことを
   明記しないと「置いたのに未設定と言われる」齟齬が出る

### R-015 [major / 設計妥当性レーン] Mode 節の分母定義が自己矛盾し、critical 帯に触れる 2 本目の軸が Q-3 に載っていない

**対象**: `plan.md:336-343`（Mode 判定）/ `plan.md` Q-3 / `todo.md` H-01

実測（オーガナイザー裏取り済み）— 旧記述:

> 変更ファイル数: **15**（helper 1 + 層 A 12 + ta-61 + `tests/extras/README.md`）→ high-risk（6-15）
> **例外は「他 PBI の完了資産への追記」**で、本 PBI では `docs/working/TASK-0921/handoff.md`
> （AC-9）が**該当する**が、1 ファイル・追記 1 行のため**判定を動かさない**

「例外」＝除外規定の例外＝**分母に含める** → **15 + 1 = 16 → critical 帯（16+）**。
「該当する」と「判定を動かさない」は**両立しない**。

より重大なのは構造である:

| 定量軸 | 状態 | 扱い |
|---|---|---|
| AC 行数 12 | critical 帯（11+）に触れる | **Q-3 として escalate** ✅ |
| **変更ファイル数 16** | critical 帯（16+）に触れる | **AI が独自に下げている** 🔴 |

**Q-3 を立てた判断基準（「AI の解釈だから人間が裁定する」）が、同じ節の隣の軸に
適用されていない。**

**是正要求**（いずれも 1〜2 行。AC / TC / 実装には影響しない）:

1. 分母定義を「**working context 成果物は分母外。他 PBI の完了資産への追記
   （`TASK-0921/handoff.md`）も規模軸には算入せず、Files 節での可視化と AC-9 での
   検証に委ねる**」と**書き切る**（＝ 15 のまま、**例外規定を作らない**）。
   **設計レーンはこちらを substance として推奨**
2. **Q-3 の設問を「AC 行数 12」+「変更ファイル数の分母定義（15 か 16 か）」の 2 軸へ拡張**し、
   todo H-01 へ反映。**「AI が独自に下げた mode 軸が 1 つも残っていない」状態にすることが眼目**

### R-016 [minor / 設計妥当性レーン] 残存エクスポージャの handoff 記録が AC-9 本文に落ちていない

**対象**: `pbi-input.md` 残存エクスポージャ節 / AC-9 / `test-cases.md` TC-38

`pbi-input.md` の残存エクスポージャ節は「**handoff に記録することを AC-9 で義務化する**」と
締めているが、**AC-9 の本文は「TASK-0921 handoff 既知課題 2 / 2-bis への解消 +
evidence superseded 宣言」しか要求しておらず、残存 5 本の記録に触れていない**。TC-38 も同範囲。
実際に載っているのは S8(2) / T-10(2) という **Work Breakdown 側**であり、
**V-1 が突合する AC ではない**。

**是正要求**: **AC-9 に 1 句追加** — 「**および本 PBI handoff に『未塞ぎ = 5 本
（`ta-25`/`ta-26`/`ta-58`/`ta-59`/`ta-60`・2 env AND・Slice 2 へ）』の行が存在すること**」。
TC-38 の確認対象も 2 点へ。

### R-017 [minor / コードベース整合レーン] (b) superseded の理由づけが過大 — 4 本は再走が要る

**対象**: `plan.md` 正本管理表 evidence 継承行 / AC-9 / `docs/working/TASK-0921/handoff.md` L43・L119

「再走は同じ evidence を別 HEAD で作り直すだけ」は、**detector が本 PBI の書換対象
そのものである 4 本には当てはまらない**:

| 旧変異 | detector | 備考 |
|---|---|---|
| **M-01** | standalone 側 TC-04 + harness 経路 | helper / TC-04 fixture とも書換対象 |
| **M-02** | **TC-01** | 書換対象 |
| **M-03** | **TC-01b** | 書換対象 |
| **M-16** | **TC-26 単独** | 書換対象 |

（反映担当が `docs/working/TASK-0921/evidence/mutations/mutation-summary.log` で
detector 行を一次確認。M-01 のみレビュー原文の「harness 経路 / helper」に加え
**standalone 側 detector が TC-04** であることを追加確認した — 指摘の趣旨を強める方向）

カバレッジの包含関係も成立していない（新 4 本は 3 env 述語に特化、旧 18 本は
marker / rc レイヤ / allowlist / dual-shell まで及ぶ）。

**是正要求**: **全 18 本でも 0 本でもなく、M-01 / M-02 / M-03 / M-16 の 4 本のみ
新 HEAD で再走**（既存ドライバ `PG_T61_SKIP_SUITE=1 sh tests/extras/ta-61-extra-contract.sh`
がそのまま使える）。**AC-9 の文言を「18 本のうち 14 本は superseded / 4 本は新 HEAD で
再走し kill を再確認」へ精密化**。あわせて **`docs/working/TASK-0921/handoff.md` の
L43 / L119 の「18/18 KILL」行**（AC-7 PASS の根拠として引用されている 2 箇所）
**から superseded 注記への参照を張る**（既知課題への追記だけでは根拠行が古い主張のまま残る）。

### R-018 [minor / コードベース整合レーン] M-4 の期待値「TC-01b / TC-01c が FAIL」は半分外れ

**対象**: `pbi-input.md` AC-5 / `plan.md` S7・帰結節 5 / `test-cases.md` EV-4 / `todo.md` T-08

レビュアー実測: **TC-01c → rc=65 で KILL** / **TC-01b → rc=0 で生存**。
TC-01b の判別子は `PG_HARNESS_SOURCED=0` であり、M-4（3 env 述語を
`PG_HARNESS_SOURCED` 単独へ退行）は**同条件を保持するため原理的に検出できない**。

**是正要求**: 期待値を「**TC-01c が kill（TC-01b は M-4 の設計上ヒットしない）**」へ訂正。
TC-01b の検出力も証明するなら **M-4b**（`PG_HARNESS_SOURCED` 条件を落として
`FIXTURES_DIR && EXTRAS_DIR` のみ）を追加するのが対称的。

### R-019 [minor / コードベース整合レーン] Q-3 の「安全側の向き」が逆（ただしレーン間で両論）

**対象**: `plan.md` Q-3 / Mode 最終判定

`mode-classification.md`「判定不能／該当不確実なら**引き上げる側**」・
`working-context.md` AC-8「判定不能なら安全側」に照らすと、
**既定を critical に置き、人間が根拠を確認して high-risk へ引き下げる**のが規定どおりの向き。
現状は plan の最終判定に high-risk を書き**人間に引き上げを求める**形。

※ **整合レーンは「現状のままでも C-3 が明示裁定する限りガバナンス上の穴にはならない」として
REJECT 理由には数えていない**。**設計レーンは high-risk 維持を substance として支持**している。

**是正要求**: **両論を Q-3 に併記**する。

### R-020 [info / 設計妥当性レーン] README 追記は「追記のみ・既存文言を編集しない」

**対象**: `todo.md` T-06 / `plan.md` Files 節

`ta-26` TC-30（`tests/extras/ta-26-plugin-sync.sh:750-758`）が `tests/extras/README.md` に対し
`PG_HARNESS_SOURCED` / `非 export` / `AND` / `standalone 側（安全側）` の **4 語を静的 grep**
している（反映担当が実測確認）。

**是正要求**: T-06 のメモに「**追記のみ・既存文言を編集しない**」を 1 語添える。

---

## Round 2 で実質解消を確認した項目（再検証不要）

- **MJ-1〜4 / MAJOR-1〜3 / MINOR-1〜2 / mn-1〜3 / info-1（= Round 1 の R-001〜R-013 系）は
  すべて実質解消**
- とくに **R-001 系は整合レーンが自分の複製で実測**し、**fixture 修正で
  TC-01/01b/01c/21/26 が全復旧**、**M-4 が TC-01c を rc=65 で kill**
  （Round 1 では同変異が rc=0 で生存）することを確認。**AC-8 + M-4 の設計は機能する**
- **TC-37 の静的検査は ta-61 の heredoc 構造で成立する**（実ファイル走査が単純で堅い。
  `tc26-file2.sh` は helper を source しないため自動除外）
- **`14` の全 9 箇所を個別確認し、契約値として書かれた箇所は 0 件**
- **scope +2 ファイルは妥当**（`TASK-0921/handoff.md` は追記しないと誤った前提を主張し続ける
  stale な正本になる。放置のほうが監査上有害）
- 監査表・反映順序・HO 判定・R-011 の挿入位置はいずれも実物と一致

## Round 2 反証・独立検証（反映担当ワーカーによる一次確認）

| 指摘 | 独立確認の内容 | 結果 |
|---|---|---|
| R-014 | `grep -c '\. "\$T61_HELPER"' tests/extras/ta-61-extra-contract.sh` → **12**、行番号もオーガナイザー提示と完全一致。`tc26-runner.sh` は `. "$T61_FXDIR/tc26-file1.sh"` を source するのみで helper を直接読まないことを heredoc（`:634-645`）で確認 | 指摘どおり |
| R-015 | `plan.md:336-343` の旧文言を逐語確認（「例外は…該当する」「判定を動かさない」の併存） | 指摘どおり |
| R-017 | `mutation-summary.log` の detector 行を確認 — `M-01 KILLED (dual-channel) standalone: … [FAIL] TC-04` / `M-02 … [FAIL] TC-01` / `M-03 … [FAIL] TC-01b` / `M-16 … [FAIL] TC-26`。`handoff.md` の「18/18 KILL」は **L43 / L119 の 2 箇所**で実在 | 指摘どおり（M-01 の standalone detector = TC-04 を追加特定） |
| R-020 | `ta-26-plugin-sync.sh:752-755` で README に対する 4 語の `grep -q` を確認 | 指摘どおり |

**反証に至った指摘は 0 件**（R-014〜R-020 の 7 件すべてを採用）。

## Round 2 監査表（追記専用）

| R-NNN | severity | lane | status | reflected_in(commit) | notes |
|---|---|---|---|---|---|
| R-014 | major | 整合 | reflected | `8e861af` | 規約 3 を「部分集合」へ + 走査母数 12 の動的導出 + `tc26-file1` 側へ置く注記 |
| R-015 | major | 設計 | reflected | `8e861af` | 分母定義を 15 で書き切る（例外規定を作らない）+ Q-3 を 2 軸へ拡張 |
| R-016 | minor | 設計 | reflected | `8e861af` | AC-9 に「本 PBI handoff の未塞ぎ 5 本の行」を追加 + TC-38 を 2 点へ |
| R-017 | minor | 整合 | reflected | `8e861af` | superseded を 14 本 / 再走 4 本へ精密化 + L43・L119 参照 + T-11b 新設 |
| R-018 | minor | 整合 | reflected | `8e861af` | M-4 期待値を TC-01c のみへ訂正 + **M-4b 新設**（TC-01b kill） |
| R-019 | minor | 整合 | reflected | `8e861af` | Q-3 に安全側の向きの両論を併記（最終判定は暫定 high-risk のまま） |
| R-020 | info | 設計 | reflected | `8e861af` | T-06 / Files 節に「追記のみ・既存文言を編集しない」（ta-26 TC-30 の 4 語 grep） |

> `reflected_in` は本 Round 2 反映 commit。squash / rebase で SHA が変わった場合は
> commit message 末尾の `Refs: R-014 … R-020` が二次証跡になる。
> Round 1 の監査表（R-001〜R-013）は**編集していない**。

## Round 2 反映順序

1. 本ファイルへ R-014〜R-020 を追記集約（本 commit）
2. plan / pbi-input / test-cases / todo へ **1 回確定反映**（`Refs: R-014 … R-020`・本 commit）
3. 簡易 C-1 再実行 #3 → `review-self.md` へ追記し `C1-VERDICT-4` を新 plan_hash で更新（本 commit）
4. 人間が最終 `approvals/c3.json`（`c3_status=APPROVED`・確定後 plan_hash）を発行
5. exec 開始

**`approvals/c3.json` は依然未発行**であり、本反映も plan 編集可能期間内（EH-3 mismatch なし）。
