# PBI INPUT PACKAGE — TASK-1009

> 対象 issue: [#1009](https://github.com/s977043/plangate/issues/1009)（P1 / bug）
> 由来: PR #986（`0ebb8fe`）の **V-2 / V-3 事後補完**。TASK-0914 は Mode=high-risk のため V-2 / V-3 が必須だったが、実施前にマージされた（`docs/working/TASK-0914/handoff.md` §5 に事実として記録済み）。
> 本 PBI の根拠となる V-2 / V-3 の生出力・実測は `docs/working/TASK-0914/review-external.md` の **R-401〜R-409** に追記済み（`.claude/rules/working-context.md`「C-2 指摘の差分管理」に準拠）。

## Context / Why

`scripts/sync-plugin-plangate.sh` の経路2（ai-loop references）は、期待集合 `_ai_loop_expected_refs` を**スペース区切りの単一文字列**として保持している。この表現が原因で、正本ファイル名にスペースが 1 つでも含まれると **mass-delete guard が 2 系統とも同時に壊れる**。

### 欠陥 1: base 算出の未 quote 展開（アンカー `set -- $_ai_loop_expected_refs`）

```sh
set -- $_ai_loop_expected_refs
_ai_loop_ref_base_count=$#
```

word splitting は IFS 依存、pathname 展開は CWD 依存で、いずれも要素数を実体から乖離させる。

### 欠陥 2: メンバシップ判定の部分一致（アンカー `case " $_ai_loop_expected_refs " in`）

```sh
case " $_ai_loop_expected_refs " in
  *" $_base "*) : ;;
  *) _ai_loop_ref_stale_count=$((_ai_loop_ref_stale_count + 1)) ;;
esac
```

期待集合にスペース入り名が 1 つ入ると、その**部分文字列と一致する dst ファイルが「期待済み」と誤判定**され、stale が過小になる。同じ判定が削除ループにもあるため、削除自体もスキップされる。

```console
$ sh -c 'exp=" foo bar.md 00_concept.md"; for b in bar.md foo nope.md; do
    case " $exp " in *" $b "*) echo "HIT : $b";; *) echo "miss: $b";; esac; done'
HIT : bar.md      ← 期待集合に無いのに「期待済み」扱い
HIT : foo         ← 同上
miss: nope.md
```

**この 2 つは同一の根本原因（文字列表現）から生じる。** 片方だけ直しても guard は fail-open のまま残る（後述 AC-1〜AC-3）。

`stale > base` は本スクリプト**唯一の安全判定**（`_mass_delete_blocked()`）であり、その入力が両側とも壊れている。

### 過去の判定を撤回する

本箇所は #914 の River Review で **F-5「info / 対処不要（対象が repo 管理下 docs ファイル名のため実害窓は無視できる）」** と判定され、`docs/working/TASK-0914/handoff.md` §2 にもその判定で記録された。

**この判定は誤りだった。** F-5 は glob メタ文字だけを見ていたが、**glob は CWD 依存である一方スペースは CWD に依存せず常に効く**。さらに F-5 は base 算出しか見ておらず、同じ原因で壊れるメンバシップ判定を射程に入れていなかった。

### なぜ 3 件を 1 PBI に統合するか

V-2 / V-3 が独立に出した以下は**すべて期待集合の表現と base 算出の作法に帰着する**。別 PBI に割ると同じ箇所を 2 回別方針で触ることになり、後から入った方が前を壊す。

| 出自 | 内容 |
|------|------|
| **V3-01（major / #1009）** | 未 quote 展開による base 過大化 → fail-open |
| **本 pbi-input で追加検出** | メンバシップ判定の部分一致 → stale 過小 → fail-open |
| **V-2 H-3** | `set --` による**位置パラメータ破壊**の除去 |
| **V-2 H-2** | 経路1 の base 集計をコピーループへ統合し 2 重走査を排除 |

H-2 を含める論拠は「**#1009 が触る base 算出と同一の作法問題であり、経路1 側の 2 重走査は copy↔base ペアのフィルタ一致をコメントでしか担保していない**」ことに限定する。
なお `sync_dir`（第3経路）にも同型の 2 重走査があるが、**本 PBI では対象化しない**（#1009 と同一箇所ではないため。境界は Out of scope に明記）。

## What (Scope)

### In scope

1. **期待集合の表現を、空白を含む名前でも壊れない形にする**（#1009 の本体）
   - 候補（plan で確定）:
     - (a) `set -f; set -- $var; set +f` → glob のみ封じる。**スペースは残るので不十分**
     - (b) 経路1 と同じカウントループで数える → **base は直るがメンバシップは直らない**
     - (c) 関数スコープのカウンタへ委譲（`_count_words() { _words_n=$#; }`）→ **同上**
     - (d) **`_ai_loop_expected_refs` を単一文字列でなくファイルリスト／改行区切り等の安全な表現へ変える** → base とメンバシップの**両方**を閉じられる唯一の案
   - **(b)(c) は AC-3 を満たせないため単独では採用不可**。plan で (d) を第一候補として検討する
2. **経路1 の base 集計をコピーループへ統合**（H-2）
3. **スペース / glob メタ文字を含む正本ファイル名の TC を追加**し、変異注入で検出力を実証する
4. `docs/working/TASK-0914/handoff.md` §2 の F-5 判定を、**追記型 addendum** で撤回する（行内書き換えで当時の判定履歴を消さない）

### Out of scope

| 項目 | 追跡先 |
|------|--------|
| 経路1 の dst 側 symlink 非対称（fail-open） | **#970** |
| 経路1 の src 側 symlink 逆非対称・`_mass_delete_blocked` の入力不正 fail-open・override の blast radius・TC-13 連鎖 FAIL | **#1011** |
| `nolink` / `basewiden` 変異が 30 TC を通り抜ける | **#1010**（※ AC-4 の最小変異 TC のみ本 PBI に取り込む。全面対応は #1010） |
| **経路2 guard が合算 base のため片側正本の全損を検出しない** | **#991**（※ 案 (d) はディレクトリ走査由来の表現になるため #991 の territory に構造的に接近する。**base の合算方式そのものは本 PBI で変更しない**） |
| TC-33 検査(1) の空振り | **#994** |
| 規約 8 の例示と検査器の不整合 | **#1004** |
| extras standalone の exit code 伝播 | **#921** |
| **V-2 H-1（TC-13 の子で #914 TC 群をスキップ）** | **#1012** |
| `sync_dir`（第3経路）の 2 重走査 | 未起票（本 PBI の対象外。必要なら exec 後に別 issue 化） |
| `test_run_evidence.py::test_tc45` が dirty tree で誤 FAIL | **#997** |

## 受入基準

- [ ] **AC-1**: 正本ファイル名に**スペース**が含まれても base が実体と一致する。下記シナリオで guard が発火し `rc=3`・stale が保全される
- [ ] **AC-2**: 正本ファイル名に**glob メタ文字**（例 `*.md` というファイル名）が含まれても base が実体と一致する
- [ ] **AC-3**: **期待集合メンバシップ判定が空白を含む名前で誤らない。** 具体的には「期待集合に `foo bar.md` が含まれるとき、dst の `bar.md` / `foo` が期待済みと誤判定されない」＝ **stale 件数と実削除件数が一致する**
- [ ] **AC-4**: 経路1 の base 算出が**コピーと同一走査**になる。検証は (i) base 集計ループが 1 本に統合されていることの静的検査、かつ (ii) **base ループから `[ -L ]` 除外を落とす変異で少なくとも 1 TC が FAIL する**こと
- [ ] **AC-5**: 経路2 の要素数算出が**トップレベルの位置パラメータを破壊しない**（性質記述。案 (b)(c)(d) のいずれでも同じ意味を持つ）。検証は「呼び出し前後で `$@` が保存されることを TC 化」または「`set --` がトップレベルに存在しないことの静的検査」
- [ ] **AC-6**: AC-1 / AC-2 / AC-3 に対応する TC を `tests/extras/ta-26-plugin-sync.sh` へ追加し、**修正前の実装に対して FAIL する**ことを変異注入で実証する（空振り fixture を作らない）
- [ ] **AC-7**: 動作不変を次の 3 点で証明する。**実リポジトリで `sync-plugin-plangate.sh` を素実行しない**（Notes 第1項）
  - (i) sandbox 2 面（before tree / after tree）で `--dry-run` の全出力が一致
  - (ii) 正常系 fixture（空白なし）で guard 判定（発火有無・rc・残存件数）が変更前と一致
  - (iii) スペース fixture で判定が変わる（＝修正が効いていることの対偶）
- [ ] **AC-8**: 既存 TC が **0 failed**（総数は基点の実測に従う。契約値として固定しない）
- [ ] **AC-9**: フルスイート `sh tests/run-tests.sh` が **0 failed**（同上）
- [ ] **AC-10**: `docs/working/TASK-0914/handoff.md` §2 に **追記型 addendum**（日付 + #1009 参照 + 撤回理由）を加え、F-5 の当時の判定行は残したまま撤回を明示する

## Notes from Refinement

- **`scripts/sync-plugin-plangate.sh` の素実行は禁止**。検証は必ず sandbox 経由（`mktemp -d` + `git archive`）。TASK-0914 `handoff.md:129` の既存規約
- `--dry-run` は**無副作用ではない**。`mkdir -p "$_dst_refs"` と `mkdir -p "$PLUGIN_AI_LOOP_REFS"` は `DRY_RUN` 判定の外にあり、dry-run でも実ディレクトリを作る。既存 TC-04 が保証するのは「**ファイル**を変更しない」まで
- **guard 3 経路の等価性は V-3 で実証済み**（argswap / staleoff1 / stale0 変異がすべて kill。証跡 = `review-external.md` R-403）。共通関数 `_mass_delete_blocked()` の**引数順・戻り値規約は変更しない**
- `stale == base` の非発火は**意図した仕様**（TC-34 で境界固定・変異 M-6b で実証済み）。本 PBI で境界を動かさない
- extras 11 本の standalone preamble の重複は**意図的な設計**（TC-33 が各ファイル内の `unset` 行を静的走査するため、共通化すると TC-33 が FAIL する。`tests/extras/README.md` L165-174）。触らない
- 参照は**記号アンカー**で行う（行番号は stale 化する）。主要アンカー: `set -- $_ai_loop_expected_refs` / `case " $_ai_loop_expected_refs " in` / `_refs_base_count=0` / `_mass_delete_blocked()`

## Estimation Evidence

### Risks

| リスク | 内容 | 緩和 |
|-------|------|------|
| **高** | guard の安全判定に触るため、誤ると mass-delete 事故が再発する（#877 の実害と同型） | 動作不変を AC-7 の 3 点で証明。変異注入で検出力を実証 |
| **高** | 案 (b)(c) を採ると **AC-1/AC-2 は PASS するのに AC-3 が満たされず、guard は fail-open のまま**という誤った完了になる | AC-3 を独立の受入基準として立て、対応 TC を AC-6 で必須化 |
| **中** | 案 (d) は期待集合の表現を変えるため、生成箇所（アンカー `_ai_loop_expected_refs=`）と全消費箇所の同時変更が要る | 消費箇所を plan の Work Breakdown で全列挙し、各段にチェックポイントを置く |
| **中** | 案 (d) がディレクトリ走査由来の表現になると **#991（合算 base）の territory に接近**する | **base の合算方式そのものは変更しない**ことを Non-goal として plan の Constraints に明記 |
| **中** | H-2（経路1）と #1009（経路2）の同時変更で切り分けが難しくなる | Work Breakdown を経路2（AC-1/2/3/5）→ 経路1（AC-4）の順に分け、各段でチェックポイント |
| **低** | 経路1 の統合で `_refs_base_count` が未設定になる経路を作りうる | コピーループが先に `mkdir -p "$_dst_refs"` する（`DRY_RUN` gate の外）ため `[ -d "$_src_refs" ]` が真なら guard ブロックにも入る、という含意を TC で固定 |

### Unknowns

- **案 (a)〜(d) のどれを採るか。plan 段階で確定する。** ただし AC-3 を満たせるのは現時点で **(d) のみ**と評価しており、(b)(c) は単独採用不可
- 案 (d) を採る場合の表現（改行区切り + IFS 制御 / 一時ファイル / 位置パラメータの保持）と、`sh` / `dash` / `bash` 間の可搬性
- 期待集合の消費箇所が base 算出・stale 集計・削除ループの 3 箇所で網羅されているか（plan で全列挙して確定する）

### Assumptions

- 現行 main の正本 2 ディレクトリにスペース / glob 文字を含む名前は**存在しない**（実測済み）。したがって**本 PBI は潜在バグの是正であり、進行中のデータ損失を止めるものではない**
- `scripts/sync-plugin-plangate.sh` は Hardening Override 対象パス**外**（`scripts/hooks/check-plan-hash.sh` の 9 カテゴリに `scripts/*.sh` は含まれない — 実コードで確認済み）。ただし **guard の安全判定に触るため Mode は high-risk 相当**とし、`lite_eligible=false` / 同期 C-3 を前提とする

## Mode 判定（暫定・plan で確定）

判定結果: **high-risk**

| 判定軸 | 値 | 根拠 |
|-------|---|------|
| 変更ファイル数 | **10 前後** | 実装 2（`sync-plugin-plangate.sh` / `ta-26-plugin-sync.sh`）+ TASK-0914 handoff 1 + working context 一式（plan / todo / test-cases / INDEX / current-state / status / decision-log / handoff） |
| 受入基準数 | **10** | AC-1〜AC-10 |
| 変更種別 | **code**（実行系スクリプト + テスト） | doc-light 不適用 |
| リスク | **高** | mass-delete guard の安全判定そのもの |
| ロールバック | 計画的に必要 | `git revert` 1 手で戻せるが、戻すと fail-open が復活する |

定量（ファイル数 6-15・AC 10 件 → 高）× 定性（リスク高）の最大値で **high-risk**。承認境界パス**外**のため例外ルールによる引き上げは不要。

**autonomous APPROVE 不可 / 人間 C-3 必須**（`.claude/rules/working-context.md` の判定マトリクス: Mode=high-risk → ❌ 不可）。

## 参照

- issue: [#1009](https://github.com/s977043/plangate/issues/1009)（本体）/ [#1010](https://github.com/s977043/plangate/issues/1010) / [#1011](https://github.com/s977043/plangate/issues/1011) / [#1012](https://github.com/s977043/plangate/issues/1012)（V-2 H-1）
- 先行 PBI: `docs/working/TASK-0914/`（plan / handoff / status / test-cases / **review-external.md R-401〜R-409**）
- 先行 PR: [#986](https://github.com/s977043/plangate/pull/986)（`0ebb8fe`）/ [#996](https://github.com/s977043/plangate/pull/996) / [#999](https://github.com/s977043/plangate/pull/999) / [#1001](https://github.com/s977043/plangate/pull/1001)
- 前段: [#877](https://github.com/s977043/plangate/issues/877)（mass-delete guard の fail-closed 化）
