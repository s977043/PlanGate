# EXECUTION PLAN — TASK-1012

> issue: [#1012](https://github.com/s977043/plangate/issues/1012)
> 入力: `docs/working/TASK-1012/pbi-input.md`
> 由来: PR #986 の V-2 事後補完 H-1（証跡 = `docs/working/TASK-0914/review-external.md` R-407）
> **改訂 10**: C-1 を 9 ラウンド実施し、計 55 件の指摘を反映。C-2 の指摘を 1 回確定反映（`Refs: R-001 R-002 R-004 R-005 R-006 R-007 R-008 R-009`）。さらに保留していた **R-003 を Human C-3 の決定（2026-08-10）に従って 1 回確定反映**（`Refs: R-003`）＝ **Mode を high-risk へ引き上げ / AC-6 を独立 AC へ復帰 / `lite_eligible=false` / V-2・V-3 を必須化**。ゲート戦略は **不変**（C-3' は非 production の裁定記録・承認は Human C-3）。

## Goal

`tests/extras/ta-26-plugin-sync.sh` の TC-13 が起動する再帰防止モードの子プロセス（`PG_T26_NO_RECURSE=1`）で、**sandbox 実行を伴う重い TC 群**をスキップし、`ta-26` の実行時間を短縮する。**親プロセスのカバレッジは変えない。**

## C-1 指摘の反映（ラウンド 1〜3 の台帳。**R4 以降は各節の脚注に記載**）

> 本表は R1〜R3 の 16 件のみを収載する。R4〜R8 の 33 件は、該当する記述の直近に脚注（「C-1 R◯ 指摘 ◯ の是正」）として置いた（C-1 R9 指摘 N-6）。

### ラウンド 1（major 4 件）

| 指摘 | 実測 | 反映 |
|------|------|------|
| ゲート内定義の関数をゲート外が参照 | `_t26_mk_refs_guard_sandbox` は **L527 定義**、**L683（TC-35）/ L713（TC-36）が参照**。`set -e` 無しのため子は `command not found` で継続 FAIL → TC-13 の `0 failed` 判定を壊す | **ゲートを 2 組に分割**し、ヘルパー定義を**両方ゲート外**に残す（コード移動なし） |
| 「#914 TC 群 = TC-20〜34」が誤り | #914 の **TC-30 / TC-33 は範囲外**の静的検査 | スコープを「**sandbox 実行を伴う TC**」で定義し直す |
| TC-A1b の判定式が両解釈とも不成立 | `\|` が literal pipe で常に 0 / 意図した ERE では TC-30・TC-33 を拾う | ゲート対象へ限定して是正 |
| Unknowns「なし」の根拠が失効 | R-407 のプロトタイプは **TC-35/36 追加前**の tree で検証 | 現 tree 基準へ書き直し |
| 「触らないファイル」が Files 節に同居 | `extract_allowed_paths()` が禁止パスを allowed_paths へ取り込む | Constraints へ移動 |

### ラウンド 2（major 3 + minor 2）

| 指摘 | 反映 |
|------|------|
| **AC 数 6 は「高」の帯**（`6-10`）で Mode が high-risk になり lite / C-3' の前提が崩れる | 当時は AC-6 を **AC-1 の静的前提へ畳んで 5 件**に戻した。**改訂 10 で撤回**（帯回避を動機とする畳み込みだったため。C-2 R-003 / Human C-3 決定 → AC-6 を独立 AC へ復帰し Mode = high-risk） |
| `derive_loopspec()` が要求する **V-A 行**（検証コマンドを宣言する行）が無い | 追加（下記 Testing Strategy）。**本表では当該ラベルを literal で書かない** — 理由は C-1 R4 指摘 A |
| `docs/working/TASK-1012/*` がセグメント境界で止まり `evidence/` に一致しない | `**` へ修正 |
| TC-A6b の AC 紐付け誤り + 「TC-35/36 が外に残る」は誤記 | AC-1 へ訂正・「TC-36 のみ」へ是正 |
| TC-A1a を `[SKIP]` 総数で判定すると誤 FAIL（既存 2 本 → 適用後 4 本） | 新規 2 本を名指しする判定式に固定 |

### ラウンド 3（major 4 + minor 5）

| 指摘 | 実測 | 反映 |
|------|------|------|
| **タスク数 11 は「高」の帯**（`11-20`）。Mode 判定でこの軸を欠落しており、ラウンド 2 と同一クラスの再発 | todo Agent タスク 11 / Work Breakdown 11 | **6 タスクへ統合**（検証 3 つを 1 つ、変異 3 つを 1 つに） |
| **変異③が構造的に空振り** | `_t26_mk_refs_guard_sandbox` の参照は **562〜713 とすべてゲート B（558-731）の内側** → 定義を中へ移しても越境 0 件のまま | **ゲート外からゲート A 内変数 `_t26_t20` を参照する 1 行を注入**する形へ変更 |
| `git checkout --` が変異復元と実装取り消しを兼ねて両立しない | staged なら index へ、未 staged なら HEAD へ戻る | **T-02 で `git add` を必須化**し、復元セマンティクスを todo に明記 |
| pbi-input が改訂前のまま plan と矛盾 | In scope / Unknowns が旧記述 | 同期 |
| 変異①の適用範囲が未指定（ゲートは計 4 箇所） | 一括置換すると TC-13 が孫を無限 spawn | **新規 2 箇所限定**を todo に明記 |
| 行番号 stale / extras 本数 14 | `derive_loopspec` は L188 / extras は 57 本 | 是正・絶対件数を撤去 |

## C-2 指摘の反映（改訂 9 で `Refs: R-001 R-002 R-004 R-005 R-006 R-007 R-008 R-009` / 改訂 10 で `Refs: R-003`）

> 集約元は `docs/working/TASK-1012/review-external.md`（**追記専用**。本節は反映側の台帳であり、あちらを編集しない）。
> **R-003 は改訂 9 の時点では保留**していた（standard 継続 / high-risk 引き上げの判断が承認境界に関わるため Human C-3 の判断事項とした）。**2026-08-10 に Human が「B. Mode を high-risk へ引き上げる」を決定**したため、改訂 10 で **1 回だけ確定反映**した。

| ID | severity | 反映内容（1 行） |
|----|----------|----------------|
| **R-003** | major | **改訂 10 で反映**（Human C-3 決定）。(a) Mode を **high-risk** へ引き上げ（「Mode 判定」節を全面改訂）/ (b) **計数規約を「PR の実差分に載る全ファイル」へ統一**し、plan 内で逆向きの計数を採っていた矛盾（指摘 2）を解消。arbiter の `size_ok` が `changed_files` 実数で機械検証する別レイヤであることを注記 / (c) **帯回避を動機とする AC の畳み込みを撤回**し **AC-6 を独立の受入基準へ復帰**（指摘 1）/ (d) `lite_eligible=false` / (e) high-risk で必須の **V-2・V-3** を Testing Strategy・完了条件・todo へ追加 |
| **R-001** | major | TC-A6a に**そのまま `sh` で実行できる 1 本のスクリプト**をフェンスで固定（範囲導出 → 内包 assert → 識別子収集 → 範囲外参照の全数照合 → 件数出力）。本 plan 側は「範囲導出 + 内包 assert」のみを持ち、**全数照合の正本は test-cases の TC-A6a フェンス**とする（二重管理を作らない） |
| **R-002** | major | (a) 範囲導出 awk の **fail-open**（桁 0 の `fi` で範囲が黙って打ち切られる）に対し、下記「範囲の内包アサーション」を追加。**導出件数 4 のチェックだけでは検出できない**ことを明記 / (b) **変異③の注入対象を `_t26_t20`（ゲート A 先頭付近 L423）から `_t26_tgt36`（ゲート B 終端付近 L721）へ変更**。切り詰められた範囲では検出されない位置に置き、範囲全体が検査されていることを実証する |
| **R-004** | major | AC-5 が **WARN 継続のまま自動受理されない**よう、todo「完了条件」と TC-A5 の判定表に **「カバレッジ縮小を受け入れるか」の Human C-4 明示判断**を必須ゲートとして追加 |
| **R-005** | minor | 記法規約の兄弟取りこぼし是正。**TC-A1c / TC-A2a に判定式のフェンス**を追加（いずれも実ログに対して実行し期待値を確認済み） |
| **R-006** | minor | 識別子収集パターンを **行頭でない代入（`;` / `\|\|` / `&&` 区切り）も拾う形へ拡張**し、`\s` / `\w`（POSIX ERE 外・非可搬）を **POSIX 文字クラス**へ書き直し。パターン本体は下記「識別子収集と全数照合」および TC-A6a のフェンスに置く（表セルに書かない = 記法規約）。**現時点では false negative 0 件**である旨も注記 |
| **R-007** | minor | todo「完了条件」に **「PR 前に clean tree で CI 相当（python テスト側を含む）を 1 回通す」** を追加。追加調査で**具体的な誤 FAIL 経路を実測特定**した: python unit test は `tests/extras/ta-60-run-evidence.sh` L134（TC-47）経由でのみ走り、その `test_run_evidence.py::test_tc45` は `git status --porcelain -- docs/working/ai-loop-runs/` が空であることを assert する。**C-3' の裁定記録が同ディレクトリに未 commit で残ると AC-4 が本 PBI と無関係に落ちる**（untracked 1 件で FAIL することを実測確認） |
| **R-008** | info | 判定用ログの生成先を repo ルートから **`docs/working/TASK-1012/evidence/test-runs/` へ固定**（#1021 と同クラスの repo 汚染を作らない） |
| **R-009** | info | TC-A2a を件数一致から **`grep -oE '\[PASS\] TC-[0-9]+' \| sort` の集合同一性比較**へ格上げ（件数一致より強い検査） |

## Constraints / Non-goals

### Constraints

- **実装変更は `tests/extras/ta-26-plugin-sync.sh` の 1 ファイルのみ**（+ working context 文書）
- **ヘルパー関数の定義を移動しない**。ゲートを 2 組に分けて定義を外に残す
- 新規イディオムを導入しない。**L62-68 の既存ゲートと同一形**（説明コメント + `if` / `printf` / `else` / `fi`）で書く
- extras の standalone preamble・判別式には**触らない**（TC-33 が静的走査するため）
- `scripts/sync-plugin-plangate.sh` の**素実行禁止**（TASK-0914 `handoff.md:129`）。検証は sandbox 経由
- 総数を契約値にしない（`0 failed` で判定）

### Non-goals

- production code（`scripts/sync-plugin-plangate.sh`）の変更
- **静的検査 TC（TC-30 / TC-33）のゲート化**（軽量でありスキップしても時間短縮に寄与しない）
- TC-13 の連鎖 FAIL 構造の是正（**#1011**）
- TC-03/04 の `md5sum` 4 回実行・sync 内の `python3` 多重起動の最適化（**#914 diff 外**・#771 / #790 由来）
- guard 本体の欠陥（**#1009** / **#1010** / **#970** / **#991**）

### 触らないファイル

`scripts/sync-plugin-plangate.sh` / `tests/extras/` の他のスクリプト全て / `tests/extras/README.md` / `tests/run-tests.sh`

> ⚠️ 本項を Files 節に置くと `extract_allowed_paths()` が**禁止パスを allowed_paths に取り込み**、C-3' の scope 逸脱検査（priority 1.5）が無効化される（C-1 R1 が実測で検出）。そのため Constraints 側に置く。
>
> ただし **本 run（非 production）ではこの hazard は発火しない**（C-1 R9 指摘 N-4）。`extract_allowed_paths()` の呼び出し元は `derive_loopspec()` のみで、非 production では呼ばれず `allowed_paths` は手入力する。配置方針は**将来 production 化したときの予防**として維持する。

## Approach Overview

既存の TC-03/04 ゲート（L62-68）と**同型**の分岐を **2 組**適用する。ヘルパー関数の定義（`_t26_mk_ai_loop_guard_sandbox` L394 / `_t26_mk_refs_guard_sandbox` L527）と `_T26_AI_LOOP_REFS_REL`（L388）は**いずれもゲート外に残す**。

```text
L388  _T26_AI_LOOP_REFS_REL=...          ← ゲート外
L394  _t26_mk_ai_loop_guard_sandbox()    ← ゲート外
      ┌─ ゲート A ─────────────────────┐
L421  │ TC-20 / 21 / 22 / 23 / 24 / 25 │  ← 経路2（sandbox 実行）
      └────────────────────────────────┘
L527  _t26_mk_refs_guard_sandbox()       ← ゲート外（TC-35/36 が参照するため）
      ┌─ ゲート B ─────────────────────┐
L558  │ TC-26 / 27 / 28 / 29 / 32 / 34 │  ← 経路1（sandbox 実行）
L673  │ TC-35 / 36                     │  ← #970（同じく sandbox 実行）
      └────────────────────────────────┘
L732  TC-30 / TC-33                      ← ゲート外（静的検査・軽量）
```

各ゲートは次の形（SKIP 文言は**ゲート外の TC-30/33 を含意しない**表記にする）:

```sh
if [ "${PG_T26_NO_RECURSE:-0}" = "1" ]; then
  printf '  [SKIP] TC-20〜TC-25（再帰防止の子プロセスでは省略・親で実行済み）\n'
  # ゲート B 側の文言は '  [SKIP] TC-26〜29/32/34〜36（…）'
else
  ...（既存ブロックそのまま・インデントのみ調整）...
fi
```

**論拠**（既存コメント L62-68 の踏襲）: TC-13 の判定は「子が `TA-26 standalone: … 0 failed` を出すこと」＝ standalone fallback がサマリ行を出すことの証明に限られ、これらの TC は必ず親プロセス側で実行されるためカバレッジは変わらない。

**TC-35/36 を含める理由**: #970 由来だが、`_t26_mk_refs_guard_sandbox` を使う**同じ重さの sandbox 実行 TC** であり、ゲート B の連続領域に位置する。除外すると (a) ヘルパー定義の移動が必要になり (b) 時間短縮効果が減る。

## Work Breakdown

| Step | 内容 | Output | Owner | Risk | 🚩 |
|------|------|--------|-------|------|----|
| **T-01** | baseline 実測（TC 総数 / PASS 数 / rc + 実行時間 2 回）+ ゲート A / B の範囲確定 + **シンボル越境検査（AC-6）**（実装は下記「T-01 のシンボル越境検査の実装」）+ **V-A 行の抽出検証** | `evidence/test-runs/t01-baseline.log` / `evidence/verification/t01-symbol-scope.log` | agent | **高** | 🚩 越境 **0 件**を機械確認（行境界の一致だけでは不十分）+ V-A 行の抽出結果が実コマンドと一致（**参考** — 非 production では消費されない。将来 production へ切り替えたときの回帰検知として実施） |
| **T-02** | ゲート A / B を適用（L62-68 と同型）。ヘルパー定義は移動しない。**適用後に `git add` して index に載せる**（T-04 の変異復元が実装を消さないため） | 差分 | agent | 中 | 🚩 `sh -n` rc=0 + **`git diff -w HEAD -- <file>`** の変化がゲート追加分のみ（**`HEAD` 必須** — `git add` 後は `HEAD` 無しだと常に空になり fail-open。C-1 R6 指摘 M-1）+ `git diff --cached --stat` に当該ファイルが載る |
| **T-03** | **受入検証**: AC-1（子で `[SKIP]` 2 本 + ゲート対象 TC の非実行 + ゲート外 TC-30/33 は実行）/ AC-2（親のカバレッジが baseline と完全一致）/ AC-3・AC-4（ta-26 standalone・フルスイートとも 0 failed）/ **AC-6（適用後の tree に対して TC-A6a を再実行 — 範囲は動的導出 + 内包アサーション）** | `evidence/test-runs/t03-acceptance.log` | agent | 中 | 🚩 AC-1〜AC-4 + AC-6 すべて PASS |
| **T-04** | **変異検証 4 種**（1 つずつ入れて戻す）。①条件反転（**新規 2 ゲート限定**）→ AC-2 が FAIL ②ゲート B 終端を TC-36 手前へ → AC-1 が FAIL ③**ゲート外に、ゲート B 終端付近で定義される変数 `_t26_tgt36` を参照する 1 行を注入** → T-01 の越境検査（**AC-6**）が ≥1 件（C-2 R-002b） ④**範囲入力を広げて TC-30 のヘッダを飲み込ませる**（ファイル無改変・call site の変異）→ 排他アサーションが `IN-RANGE` を報告（**AC-6** / river-review major。TC-A6d） | `evidence/test-runs/t04-mutations.log` | agent | **高** | 🚩 4 変異すべてで期待 FAIL + 各復元後に再 PASS（④は無改変のため復元不要・正しい範囲での再実行が復元確認） |
| **T-05** | **AC-5**: 交互 A/B（BASE / OPT を交互に各 2 回以上）で実行時間を実測。**BASE/OPT の切替は退避コピー方式**（下記）。**T-04 の後に直列で実行**する | `evidence/test-runs/t05-ab-timing.log` | agent | 中 | 🚩 交互測定であること + 測定後に OPT が index と一致していること |
| **T-06** | handoff / status / current-state / INDEX を整備。handoff に「**ゲート境界の直後に TC を足すときは越境検査を再実行する**」旨を明記 | 各文書 | agent | 低 | 🚩 handoff 6 要素 + 再発防止の申し送り |

## Files / Components to Touch

| ファイル | 変更 |
|---------|------|
| `tests/extras/ta-26-plugin-sync.sh` | sandbox 実行 TC 群を `PG_T26_NO_RECURSE` ゲート 2 組で包む（**唯一の実装変更**） |
| `docs/working/TASK-1012/**` | working context 一式 + evidence 配下（**`*` ではなく `**`**。`*` はセグメント境界で止まり evidence 配下に一致しない） |

## Testing Strategy

| 種別 | 内容 |
|------|------|
| **Integration** | 親（`PG_T26_NO_RECURSE` 未設定）と子相当（`=1`）の 2 系統 |
| **Regression** | フルスイート `sh tests/run-tests.sh` で 0 failed |
| **静的検査** | T-01 のシンボル越境検査 / TC-INV（**`git diff -w HEAD --`** でゲート以外の内容変化 0） |
| **検出力の実証** | **変異 4 系統**（T-04）。**④は範囲入力（call site）を広げる変異**で、範囲導出の**広がる側**の fail-open に対する検出力を実証する（ファイル無改変。詳細は TC-A6d と上記「範囲の内包アサーション」の経緯）。①条件反転 → AC-2 が FAIL ②ゲート B 終端の縮小 → AC-1 が FAIL ③**ゲート外から、ゲート B 終端付近で定義される変数 `_t26_tgt36` を参照する 1 行を注入** → 越境検査が ≥1 件。③は当初「ヘルパー定義をゲート内へ移す」としていたが、**同関数の参照はすべてゲート B の内側（562-713）にあるため越境が発生せず空振り**だった（C-1 R3 が実測で検出）。人工的な外部参照の注入に変更し、検査そのものの検出力を直接実証する。**さらに注入対象を `_t26_t20`（ゲート A 先頭付近 L423）から `_t26_tgt36`（ゲート B 終端付近 L721）へ変更した**（C-2 R-002b）: 前者は範囲導出 awk が fail-open で範囲を打ち切っても切り詰め後の範囲に残るため、**「範囲全体が検査されていること」を一切実証しない**。後者は打ち切られた範囲では定義が拾われず変異が検出されなくなるため、fail-open が起きたときに変異③が空振りする＝異常を露出させる |

- Verification Automation: `sh tests/extras/ta-26-plugin-sync.sh </dev/null && PG_T26_NO_RECURSE=1 sh tests/extras/ta-26-plugin-sync.sh </dev/null && sh tests/run-tests.sh`

### high-risk で必須になる V 系フェーズ（改訂 10 / C-2 R-003）

Mode を high-risk へ引き上げたことで、`.claude/rules/mode-classification.md` L149-163 の**フェーズ適用マトリクス**上の適用が変わる。中 → 高 で変わるのは **4 行**（`brainstorm` / `C-2` / `exec` / `V-2`）である。V-3 は standard でも `○` で既に必須、V-4 は `critical` のみなので依然として適用外。

> ⚠️ 改訂 10 の初版は「実質差分は V-2 の 1 点」と要約していたが、**自分の表が C-2 を `-`→`○` と書いているのに要約から落としており誤り**だった（river-review minor）。**本 PR の最重要 Human 判断事項は「C-2 不足の許否」**であり、要約から C-2 が落ちると承認者が「追加作業は V-2 のみ」と誤読する。

| フェーズ | standard（改訂 9 まで） | **high-risk（改訂 10）** | 本 PBI での実施内容 |
|---------|----------------------|------------------------|-------------------|
| **brainstorm** | `△`（任意） | **○** | **実施済み扱いとしない / 該当なし**: 本 PBI は PR #986 の **V-2 事後補完 H-1**（`docs/working/TASK-0914/review-external.md` R-407）で**対象・方式・プロトタイプ検証まで確定済み**の派生 PBI であり、`pbi-input.md`「既存パターンのミラーである」のとおり**新規設計を持ち込まない**。探索すべき設計選択肢が無いため brainstorm フェーズは**該当なし**とする。この判断の妥当性は **Human C-3 の確認事項**とする（AI が単独で「不要」と確定しない） |
| **C-2 外部 AI レビュー** | `-` | **○** | 下記「C-2 の充足判定」を参照（**現時点では不足**） |
| **exec (TDD)** | `TDD` | **`TDD + 並列`** | **並列化しない**（意図的な逸脱）。A-1〜A-6 は**全て直列依存**であり、とくに **A-5 は A-4 の後に直列**と明示している（変異の index 復元と A/B の `cp` 上書きが同一ファイルを奪い合うため）。同一ファイルへの単一系列の変更であり並列化の余地が無い。この逸脱も **Human C-3 の確認事項**とする |
| **V-2 コード最適化** | `-` | **○（新規に必須）** | 追加したゲート 2 組を対象に、**動作を変えずに**可読性を確認する。⚠️ **TC-INV（`git diff -w HEAD --` がゲート追加分のみ）を壊す変更は行わない**ため改変余地は極小。**「最適化なし」で終わる場合もその判定と根拠を evidence に残す**（実施しないことと、実施して変更なしと判断することを区別する）。変更した場合は AC-1〜AC-4 を再実行して回帰なしを確認する |
| **V-3 外部モデルレビュー** | `○` | **○（不変）** | 実装後の外部レビュー。指摘は `review-external.md` へ追記専用で集約（`R-NNN` 採番） |
| **V-4 リリース前チェック** | `-` | `-`（`critical` のみ） | 適用外 |

- **exec 完了条件に V-2 / V-3 を含める**（todo「完了条件」に反映済み）
- V-2 / V-3 / L-0 / V-1 / PR 作成の**進行制御は workflow-conductor** が担うため、todo の Agent タスク（A-1〜A-6）には工程として並べない（`working-context.md` の todo 規約）

#### C-2 の充足判定（**勝手に「充足」としない**）

| 観点 | 実施状況 | 判定 |
|------|---------|------|
| フェーズ適用マトリクス（high-risk の C-2 = `○`） | 1 本実施済み（`review-external.md`・critical 0 / major 4 / minor 3 / info 2 → 全件反映済み） | 形式上は `○` を満たす |
| 実施の**根拠づけ** | 実施時の根拠は **Lite ゲートの AC-12（1 本・観点固定）**。改訂 10 で `lite_eligible=false` としたため、この根拠は**失効**した | ❌ |
| `review-principles.md` §7-bis の **2 レーン**（設計妥当性 / コードベース整合） | **設計妥当性レーンのみ実施**。コードベース整合レーンは「設計妥当性レーンに内包された」として**未実施**（`review-external.md` メタ表） | ❌ |

→ **判定: 不足している**。high-risk では Lite の 1 本枠ではなく Standard 枠（複数観点）で読むべきであり、§7-bis の**コードベース整合レーンが未実施**のまま残る。

- **AI はこれを「充足」と書き換えない**。追加 1 本（コードベース整合レーン）を exec 前に実施するか、この不足を許容して C-3 を APPROVE するかは **Human C-3 の判断事項**として提示する
- 既出の C-2 指摘（R-001〜R-009）は**全件が反映済みまたは本改訂で反映**であり、未反映の指摘は残っていない

> ⚠️ **本 run（非 production）では V-A 行は消費されない**（C-1 R8 指摘 P-2）。`derive_loopspec()` は `production: true` の
> Plan Package 経路でしか呼ばれず、その本番呼び出し元は repo 内に存在しない（テスト fixture のみ）。**将来 production で回す
> 場合に備えた宣言として残す**。以下は当該行を書く際の注意で、記述自体は正しい。
>
> **上の V-A 行について**（C-1 R4 指摘 A の是正）: `derive_loopspec()`（`scripts/ai-loop/plan_package.py` の L188）は当該ラベルを `re.search`＝**最初の一致**で抽出する。ラベル文字列をバッククォートで囲んで本文中に書くと、**閉じバッククォートが抽出の開始デリミタとして消費され、以降の本文がコマンドとして黙って採用される**（例外が出ないので **fail-open**）。改訂 2 まで実際にこの状態で、抽出結果は `' + バッククォート囲みの行が無い | 追加（下記 Testing Strategy） |'` だった（実測）。
>
> したがって本 plan では **V-A 行より前でラベルを literal 表記しない**。ラベルを話題にする箇所はすべて「V-A 行」と呼ぶ。検証は下記フェンスのコマンド（出力が V-A 行の実コマンド列と一致すること）で行う（T-01 のチェックポイント）。

```sh
python3 - <<'EOF'
import re
t = open('docs/working/TASK-1012/plan.md').read()
print(re.search(r'Verification Automation:\s*`([^`]+)`', t).group(1))
EOF
```

## Risks & Mitigations

| リスク | 緩和 |
|-------|------|
| **ゲート内定義のシンボルをゲート外が参照して子が壊れる**（初版で実際に踏んだ） | T-01 で**シンボル越境 0 件**を機械確認し、T-04 変異③でその検査の検出力を実証 |
| ゲート範囲を誤り、親でも対象 TC がスキップされる | T-03（親のカバレッジ不変）+ T-04 変異① |
| ゲート範囲が狭すぎて子で重い TC が残る | T-03（子で非実行）+ T-04 変異② |
| **変異の復元が実装ごと消す** | T-02 で `git add` を必須化し、復元は `git checkout -- <file>`（index 経由）に固定。手順は todo に明記 |
| **A/B 計測の BASE 化が index ごと OPT を破壊し復帰不能になる**（C-1 R4 指摘 D） | T-05 を **T-04 の後に直列化**し、BASE/OPT の切替を **退避コピー方式**で行う（`git checkout HEAD --` を使わない）。手順は下記 |
| **変異①の一括置換が TC-13 のゲートまで反転させ孫プロセスを無限 spawn する** | 適用を**新規 2 ゲートに限定**（todo に明記） |
| 子のカバレッジが狭まることで将来の退行を見逃す | TC-13 の判定目的が standalone fallback の証明に限られることを根拠とし、handoff に**既知の妥協点**として明記 |
| 実行時間の改善が測定ノイズに埋もれる | T-05 で**交互 A/B**（連続測定にしない） |
| インデント調整で意図せず中身が変わる | T-02 の 🚩 で **`git diff -w HEAD -- <file>`** の変化がゲート追加分のみであることを機械確認 |
| **今後 TC が追加され、またゲート範囲と依存が食い違う** | handoff の申し送りに、**ゲート境界の直後に TC を足すときは越境検査を再実行する**旨を明記 |

### T-01 のシンボル越境検査の実装（C-1 R4 指摘 G）

> ⚠️ **適用前と適用後で入力の取り方が違う**（C-1 R5 指摘 N-3 の是正）。改訂 3 まで「ゲート構文から動的に導出」を**両方に適用**すると書いていたが、**T-01 の時点でゲート A / B はまだ存在しない**。実測すると awk は既存 2 ゲート（`67-92` / `293-321`）しか返さず、T-01 の 🚩「越境 0 件」は**ゲート A / B を一度も検査せずに PASS する** = fail-open だった。

| フェーズ | 範囲の入力 | 備考 |
|---------|-----------|------|
| **T-01（適用前）** | **Approach Overview の図が示す予定行範囲を明示入力**する（ゲート A = TC-20 開始行〜TC-25 終端 / ゲート B = TC-26 開始行〜TC-36 終端） | 動的導出は使えない。範囲は plan の図と `grep -nE '^# TC-'` の実測で確定する |
| **T-02 適用後（TC-A6a / 変異③）** | **ゲート構文から動的に導出**（下記 awk） | 適用でインデントと行が入り行番号が動くため |

適用後の動的導出:

```sh
F=tests/extras/ta-26-plugin-sync.sh
awk '
  /^if \[ "\$\{PG_T26_NO_RECURSE:-0\}" = "1" \]; then/ { depth++; if (depth==1) gs=NR }
  /^fi$/ { if (depth==1) { print gs"-"NR } ; if (depth>0) depth-- }
' "$F"
# → 各ゲートの [開始行-終了行]。
# ⚠️ この出力は **そのまま信用してはならない**。必ず下記「範囲の内包アサーション」を通すこと。
```

> ⚠️ **既存ゲート（TC-03/04 の L67・TC-13 の L293）も同じ構文**なので、適用後の上記 awk は **4 ゲート**を返す。**新規 2 ゲートの特定は SKIP 文言で行う**（`TC-20〜TC-25` / `TC-26〜29/32/34〜36` を含むブロックが新規）。T-01 / TC-A6a の 🚩 には「**導出件数が 4 であること**」と「**うち新規 2 件を文言で特定した根拠**」を含める（2 件しか返らなければ適用漏れ、4 件を超えれば想定外のゲート追加）。

#### 範囲の内包アサーション（**必須** / C-2 R-002a）

> ⚠️ **上の awk は fail-open である**。終端判定 `/^fi$/` は**桁 0 の `fi` に一致する**ため、ゲート内に未インデントの `fi` が 1 行でも混ざると **範囲が黙って打ち切られる**（C-2 のオーガナイザーが再現: 本来 1-10 の入力に対し `1-5` を返す）。しかも **エラーも警告も出ない**。
>
> **既存の 🚩「導出件数が 4」では検出できない**。件数は 4 のまま、範囲だけが縮む。`sh -n` は通り、TC-INV は `git diff -w` で空白差を無視する。したがって**導出した範囲そのものを検証する**アサーションを必須とする。

```sh
# 導出した範囲に、期待 TC ヘッダ集合が内包されることを assert する
# 使い方: sh assert-gate-range.sh "<ゲートA範囲>" "<ゲートB範囲>"   例: "421-521" "558-730"
F=tests/extras/ta-26-plugin-sync.sh
A="$1"; B="$2"
_in() { lo=${1%-*}; hi=${1#*-}; [ "$2" -ge "$lo" ] && [ "$2" -le "$hi" ]; }
miss=0
for pair in "A:$A:20 21 22 23 24 25" "B:$B:26 27 28 29 32 34 35 36"; do
  g=${pair%%:*}; rest=${pair#*:}; rng=${rest%%:*}; tcs=${rest#*:}
  for n in $tcs; do
    ln=$(grep -nE "^[[:space:]]*# TC-$n:" "$F" | head -1 | cut -d: -f1)
    if [ -z "$ln" ]; then echo "MISSING header TC-$n"; miss=$((miss + 1)); continue; fi
    _in "$rng" "$ln" || { echo "OUT-OF-RANGE gate $g: TC-$n at L$ln not in $rng"; miss=$((miss + 1)); }
  done
done

# (1b) 排他アサーション: ゲート外に残すべき TC-30 / TC-33 を飲み込んでいないこと
# （**広がる側**の fail-open。閉じ `fi` のインデント誤りで範囲が次の桁 0 `fi` まで延びる）
for n in 30 33; do
  ln=$(grep -nE "^[[:space:]]*# TC-$n:" "$F" | head -1 | cut -d: -f1)
  if [ -z "$ln" ]; then echo "MISSING header TC-$n"; miss=$((miss + 1)); continue; fi
  for pair in "A:$A" "B:$B"; do
    g=${pair%%:*}; rng=${pair#*:}
    ! _in "$rng" "$ln" || { echo "IN-RANGE gate $g: TC-$n at L$ln is inside $rng"; miss=$((miss + 1)); }
  done
done

echo "containment_violations=$miss"   # → 0 が期待値
[ "$miss" -eq 0 ]
```

**実測**（適用前 tree・`origin/main` の実ファイルに対して 4 通りの範囲入力で実行。ゲート A は `421-521` 固定）:

| ゲート B の入力 | 出力 | rc |
|---|---|---|
| `558-730`（正常） | `containment_violations=0` / `identifiers=77 crossings=0` | 0 |
| `558-700`（**狭める**） | `OUT-OF-RANGE gate B: TC-36 at L707 not in 558-700` | 1 |
| `558-741`（**広げる**・現実的な誤り） | `IN-RANGE gate B: TC-30 at L732 is inside 558-741` | 1 |
| `558-791`（**広げる**・さらに拡大） | `IN-RANGE` が TC-30 / TC-33 の 2 件 | 1 |

**両方向の fail-open を実際に検出することを確認済み**。

> ⚠️ **(1b) を追加した経緯（river-review major）**: 改訂 10 の初版は (1) しか持たず、**広げる側は `containment_violations=0` / `identifiers=83 crossings=0` / rc=0 で PASS** していた（`558-791` で実測）。**変異③を重ねても `crossings=1` を返すため変異③でも検出できない**。
>
> 失敗シナリオ: 適用時にゲート B の閉じ `fi` を誤ってインデントすると、上の awk（`/^fi$/` = 桁 0 のみ一致）は次の桁 0 `fi` まで範囲を延ばす。すると **AC-6 の唯一の静的検査が TC-30/33 領域を「ゲート内」と誤認**し、そこからゲート B へのシンボル参照を越境として数えない。しかも `sh -n` は通り、TC-INV は `git diff -w` が空白差（= インデント）を無視し、🚩「導出件数が 4」も 4 のまま、ランタイム TC はゲートが実際には正しく閉じているので全 PASS する。**他のどの検査でも見えない**経路だった。検出力の実証は **TC-A6d（変異④）**。

#### 識別子収集と全数照合

**正本は test-cases.md の TC-A6a のフェンス**（そのまま `sh` で実行できる 1 本のスクリプト。C-2 R-001）。本節では収集パターンの規約だけを定める:

- 変数定義: `(^|;|\|\||&&)[[:space:]]*[A-Za-z_][A-Za-z0-9_]*=` — **行頭でない代入も拾う**。改訂 8 までの `^\s*(\w+)=` は行頭代入しか拾えず、かつ `\s` / `\w` は **POSIX ERE 外**で `grep -E` / `awk` 実装により非可搬だった（C-2 R-006）
- 関数定義: `^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*\(\)`
- 参照照合: 変数は `\$[{]?名`、関数は語境界付きの裸呼び出しを、**範囲外の全行**に対して照合する

> **過大評価しない**: 範囲内の行頭でない代入は実測 **26 行**（すべて `… || 名=$?` 形式。C-2 R-006 が名指しした `_t26_stale24` / `_t26_stale29` / `_t26_stale34` / `_t26_kept34` / `_t26_tgt35` / `_t26_tgt36` を含む）だが、**この 26 変数はいずれも同一ファイル内に行頭代入も併存する**ため、旧パターンでも **false negative は 0 件**だった（実測: 26/26 が `^[[:space:]]*名=` にヒット）。本是正は将来の追加行に対する予防であり、現時点の検査結果を変えない。

### T-05 の BASE/OPT 切替手順（退避コピー方式）

`git checkout HEAD -- <file>` は **index と working tree の両方**を HEAD へ戻すため、1 度使うと OPT（ゲート適用済み）が復帰不能になる。したがって A/B 計測では使わない。

```sh
F=tests/extras/ta-26-plugin-sync.sh
cp "$F" /tmp/ta26.opt                 # OPT を退避
git show HEAD:"$F" > /tmp/ta26.base   # BASE を取得（index には触れない）

# ⚠️ BASE 健全性アサーション（C-1 R9 指摘 N-2）
# 実装を commit 済みだと HEAD がゲート適用後になり BASE == OPT で AC-5 が無言で無意味化する
# （OPT/BASE ≈ 1.0 → WARN 受理となり、誤った実測値が handoff に残る）
if grep -q 'TC-20〜TC-25' /tmp/ta26.base; then
  echo "FAIL: BASE にゲートが含まれる（実装が commit 済み）。A-5 完了まで commit しないこと"
  return 1 2>/dev/null || exit 1
fi

# 以降、cp で入れ替えて交互に計測する
cp /tmp/ta26.base "$F"; time sh "$F" </dev/null    # BASE 1
cp /tmp/ta26.opt  "$F"; time sh "$F" </dev/null    # OPT 1
cp /tmp/ta26.base "$F"; time sh "$F" </dev/null    # BASE 2
cp /tmp/ta26.opt  "$F"; time sh "$F" </dev/null    # OPT 2

# 終了時は必ず OPT へ戻し、index と一致することを確認する
cp /tmp/ta26.opt "$F"
git diff --quiet -- "$F" && echo "OPT restored (index と一致)" || { echo "FAIL: OPT が index と一致しない"; exit 1; }
```

**T-05 は T-04（変異検証）の後に直列で実行する**。並行させると、変異の index 復元と A/B の cp 上書きが同一ファイルを奪い合う。

## Questions / Unknowns

| # | 内容 | 解消方法 |
|---|------|---------|
| U-1 | ゲート境界と、後から追加された TC（TC-35/36 = #970 / PR #1014）およびヘルパー定義の相互作用。**R-407 のプロトタイプは TC-35/36 追加前の tree で検証されており現 tree に対して有効でない** | **T-01 で解消**（シンボル越境 0 件の機械確認）。設計上はゲート 2 分割で回避済みだが実測で確定させる |
| U-2 | ゲート B に TC-35/36 を含めることが #970 の意図（symlink 集計の厳密一致検証）を損なわないか | 親では従来どおり実行されるため損なわない。T-03（親カバレッジ不変）で確定 |

## Mode 判定

判定結果: **high-risk**（**Human C-3 決定 2026-08-10 / C-2 R-003 の決着**）

### 計数規約（何を母数に数えるか / C-2 R-003 指摘 2 の解消）

改訂 9 まで本 plan は **同一の「変更ファイル数」に 2 つの母数**を用いていた（Mode 判定では「実装 1 ファイル」、arbiter 向けの `size_ok` 論では「実差分は 2 を超える」）。**逆向きの計数を 1 つの plan が併用していた**のが R-003 指摘 2 の実体である。本改訂で母数を **1 つに統一**する。

| 規約 | 内容 |
|------|------|
| **Mode 判定の母数** | **PR の実差分に載る全ファイル**（実装 + working context 文書 + evidence）。「実装ファイルのみ」では数えない |
| **安全側** | 母数の解釈が割れる場合は**大きい方**を採る（`mode-classification.md`「自動推定の安全側」）。リポジトリ内の先例が割れている（TASK-0970 = 実装のみ / TASK-0981 = working context を母数に含めて高）ため、本 PBI は**後者に揃える** |
| **arbiter `size_ok` との関係** | `size_ok` は `scripts/ai-loop/arbiter.py` が **`changed_files` の実数**（`SIZE_OK_MAX_FILES`=2）で機械検証する**別レイヤ**であり、本 Mode 判定とは独立に評価される。**両者の母数は本改訂で一致した**（どちらも実差分）ので、以後 plan 内に逆向きの計数は存在しない |

**実測（測定時点 = 本改訂コミット）**: `git diff --stat origin/main...HEAD -- docs/working/TASK-1012/` = **5 ファイル**。exec 後は実装 1 + `review-self.md` / `status.md` / `current-state.md` / `INDEX.md` / `handoff.md` / `decision-log.jsonl` / `evidence/**` が加わり **6 を確実に超える**。したがって本軸は **6-15 帯 = 高**（総数は契約値にしない。増える方向にしか動かない）。

### 判定表（定量 3 + 定性 4 = 7 軸）

| 区分 | 判定軸 | 実測値 | 帯 |
|------|-------|-------|----|
| 定量 1 | 変更ファイル数（上記規約の母数） | **≥ 6**（測定時点 5・完了時点で 6 超） | **高** |
| 定量 2 | 受入基準数 | **6**（AC-1〜AC-6） | **高** |
| 定量 3 | タスク数（見込み） | **6**（T-01〜T-06） | 中 |
| 定性 1 | 変更種別 | 小機能追加相当（既存イディオムの適用） | 中 |
| 定性 2 | リスク | 中（テスト意味論の変更を伴う） | 中 |
| 定性 3 | 影響範囲 | 当該ファイルのみ | 超低 |
| 定性 4 | **ロールバック** | 容易（`git revert` 1 手） | 低 |

定量の最大 = **高** / 定性の最大 = 中 → **高い方を採り high-risk**（`mode-classification.md`「判定ロジック」3）。承認境界パス外のため**例外ルールによる引き上げは無い**が、**例外ルールに拠らずとも定量軸で high-risk に到達する**。

### 帯回避の記述を撤回した理由（C-2 R-003 指摘 1）

改訂 2〜9 は **AC-6 を AC-1 の静的前提へ畳んで受入基準数を 5 に戻し**、その動機として「6 は high-risk 帯（6-10）に入り Mode 判定が変わる」と **帯回避を plan 自身に明記**していた。判定基準の側を目的に合わせて操作しており、`mode-classification.md` の趣旨に反する。

**Human C-3 が high-risk への引き上げを選んだ**ことで帯回避の動機そのものが消えたため、本改訂で:

- **AC-6 を独立した受入基準へ戻す**（下記「AC-6 の復帰」）
- 「AC 数が 6 になると帯が変わる」という**帯回避の記述を plan / test-cases から除去**した

> **軸の取り違えについて**（C-1 R4 指摘 C）: 改訂 2 までの表は 6 行で `ロールバック` を欠き、かつ「変更種別」欄に #496 の doc/config/code 軸（5 段階 mode とは**直交する補助軸**）を代入していた。影響範囲も「当該ファイルのみ」= 規則上 **超低**なのに「低」と書いていた。**軸を数えずに埋めていた**ことの証拠なので記録する。

### AC-6 の復帰（C-2 R-003）

改訂 9 まで「AC-1 が成立するための静的前提」として AC-1 配下に畳んでいた **シンボル越境 0 件**を、**AC-6 として独立の受入基準へ戻す**。

- 畳み込みの動機は**帯回避**であり（上記）、high-risk を受け入れた時点で失効した
- 越境 0 件は **固有の failure mode（`set -e` 無しで子が `command not found` のまま継続 FAIL）と固有の検証手段（TC-A6a / TC-A6c）と固有の申し送り**（ゲート境界の直後に TC を足すときの再実行）を持つ。AC としての独立性は満たす
- 反映範囲: `pbi-input.md` の受入基準 / `test-cases.md` の AC↔TC マッピング / `todo.md` の完了条件 / T-03（A-3）で**適用後の再実行**を明示。**TC-A6a / A6b / A6c の判定式は改訂 9 から 1 文字も変えていない**（変更したのは AC 参照の見出し・コメント文言のみ）
- **TC-A6b は AC-1 側に残す**（名称は `A6` 系だが、変異②で実際に落ちるのは TC-A1b＝AC-1。C-1 再レビュー B-4 の訂正を維持）

### lite_eligible 判定

| 軸 | 値 | 根拠 |
|----|---|------|
| 変更ファイル数 | ❌ **≥ 6**（上記計数規約の母数） | 「少（≤ light 相当）」を満たさない |
| 新規設計の有無 | ✅ なし | L62-68 の既存ゲートと同一形を 2 箇所に適用するのみ。**ヘルパー関数を移動しないため「定義をどこへ置くか」の設計判断が発生しない** |
| 既存パターン踏襲 | ✅ あり | 同一ファイル内の同一イディオム・同一論拠 |
| 可逆性 | ✅ あり | `git revert` 1 手 |

→ **`lite_eligible=false`**

- 変更ファイル数軸が**上記の統一母数では成立しない**（改訂 9 は「実装 1 ファイル」という別母数で `true` としていた＝R-003 指摘 2 と同根）
- Mode = **high-risk** であり、`mode-classification.md`「Lite ゲート構成 vs Standard」の **Standard 側**（C-2 = 複数観点）を採る
- `mode-classification.md` AC-8 安全側とも整合（判定が割れるなら `false`）

> **arbiter への申告**: `lite=false` を申告するため、C-3' 裁定で発火するのは **priority 2（lite=false）**。`size_ok` は実差分が `SIZE_OK_MAX_FILES`=2 を超えるため **`false` を申告する**（虚偽申告禁止）。priority 1.9 は「申告 true ∧ 実測超過」でのみ発火するため該当しない（`_declared_size_ok()` の実装で確認。C-1 R5 指摘 N-5）。終端状態は `HUMAN_ESCALATED` で、**これは想定どおり**（下記「ゲート運用」節）。

### 境界チェック

| 項目 | 判定 |
|------|------|
| Hardening Override 9 カテゴリ | **非該当**（`tests/extras/` は `scripts/hooks/check-plan-hash.sh` L124-134 のいずれにも含まれない） |
| ai-loop 判定基盤 carve-out | **非接触**（`scripts/ai-loop/**` / `docs/workflows/ai-loop/**` / `docs/ai/ai-loop/**` / `*/skills/ai-loop-cycle/**` のいずれでもない） |
| rollout-policy #780 slice C 前提 | **充足**。`scripts/ai-loop/arbiter.py` に `SIZE_OK_MAX_FILES = 2` の機械検証が実装済み。加えて**本変更は test のみで「実機能」ではない** |

## ゲート運用（**改訂 6 で戦略変更** — C-1 R7 の実測を受けて）

**承認は Human C-3。C-3' は「裁定記録」として回すが、承認トークンの発行元にはしない。**

改訂 5 まで「Human C-3 の代わりに C-3' 裁定を用いる」としていたが、C-1 ラウンド 7 の実測で **その戦略は成立しない**ことが確定した（Human 判断で戦略変更）。

### なぜ C-3' を承認経路にできないか（実測）

| # | 事実 | 実測 |
|---|------|------|
| 1 | **`AUTO_APPROVED` は誠実には到達できない** | `changed_files` を Plan Package の実 doc 6 件で渡すと `HUMAN_ESCALATED / priority 1.9`「size_ok 申告=true だが実ファイル数 6 が閾値 2 を超過（**申告と blast-radius 不一致**）」。glob `docs/working/TASK-1012/**` を「1 ファイル」と数えれば `AUTO_APPROVED` になるが、それは arbiter が防ごうとしている不一致そのもので **`size_ok` の虚偽申告**にあたる（SKILL.md 禁止事項）。安全側に `size_ok=false` を申告すると `priority 2`（lite=false）で escalate |
| 2 | **AI は `approvals/c3.json` を書けない** | `scripts/check-approval-token-write.sh` が `*/approvals/*.json` / `*c3.json*` への書込を block。`.claude/settings.json` の **Edit\|Write と Bash の両方に配線済み**（L102 / L111）。`AUTO_APPROVED` が返っても AI は承認トークンを発行できない |
| 3 | **c3-prime の発行 CLI が存在しない** | `build_c3_prime` / `serialize_c3_prime` の呼び出し元は**テスト fixture のみ**。`plan_package.main()` は read-only 検証しか持たない。リポジトリ内の c3-prime 形式 `c3.json` は **0 件**（初回経路） |

> ⚠️ 改訂 5 の記述「`bin/plangate` は `c3_status` を読む」は **c3-prime に対しては誤り**だった。`_plangate_c3_dispatch()` は `approval_kind` キーが**無い場合のみ** legacy（`c3_status` grep）経路へ落ちる。c3-prime record に `c3_status` を入れると `plan_package.py:341` と `c3prime_verify.py:71-72` が**契約 §5 違反として拒否**する（C-1 R7 指摘 N-2）。

### 採用する運用

| 工程 | 担当 | 成果物 |
|------|------|--------|
| Step 0: `breakdown-gate` で粒度判定 | AI | `gates.breakdown` |
| plan / todo / test-cases の**確定** | AI | 以降 plan を編集しない（`feedback_no_plan_edit_after_c3_approval`） |
| **C-1** | AI | `review-self.md`。この結果を `gates.c1` へ |
| **C-2**（high-risk = `○` 必須。**現状 1 本で不足**・上記「C-2 の充足判定」） | AI | `review-external.md` に `R-NNN` 集約（追記専用） |
| **C-3'（裁定記録）** | AI | `docs/working/ai-loop-runs/<ts>-<sha>.json`。**`HUMAN_ESCALATED` が返るのが想定どおり**であり、これは失敗ではない。W チェック 2 体の verdict と `boundary_check` / `scope_check` を記録として残すことが目的 |
| **C-3（承認）** | **Human** | `bin/plangate approve TASK-1012` で **legacy 形式**の `approvals/c3.json` を発行（`c3_status=APPROVED` + `plan_hash`）。AI は実行できない（②のガード + presence gate） |
| exec | AI | — |

- **`C1-VERDICT` / `C2-VERDICT` マーカーは付けなくてよい**。あれは c3-prime（Plan Package 束縛）経路の要求であり、legacy 承認では `bin/plangate` が `c3_status` + `plan_hash` を見る。ただし C-1 / C-2 の結果は `review-self.md` / `review-external.md` に**通常どおり記録する**（`working-context.md` の要求）
- **C-2 は Mode=high-risk のフェーズ適用マトリクスで `○`（必須）**（改訂 9 まで「standard では `-` だが自主的に 1 本実施する」としていた記述を改訂 10 で更新）。**現時点の 1 本では要求水準に対して不足**している — 判定と理由は上記「C-2 の充足判定」を参照
- C-3' が `HUMAN_ESCALATED` を返したら、`w_check` / `boundary_check` / `lite_check` を人間へ提示する。**AI が自己解決しない**
- **C-3' run は「非 production」で回す**（C-1 R8 指摘 P-2）。`production` / `plan_package` フィールドは**入力に含めない**。
  - 理由: 承認は Human C-3（legacy `c3.json`）で行うため Plan Package 束縛が不要。`production: true` にすると `plan_package.check_evidence()` が `C1-VERDICT` / `C2-VERDICT` マーカーを**完全文法でちょうど 1 回**要求し（fail-closed）、「マーカーは付けなくてよい」という本節の方針と**二律背反**になる
  - 帰結: `derive_loopspec()` は**呼ばれない**。したがって Testing Strategy の **V-A 行は本 run では消費されない**（**上記** Testing Strategy の注記を参照）
  - 入力に含めるもの: `changed_files` / `allowed_paths` / `lite` 4 軸 / `class` / `verdicts` / `target_sha` / `gates` / **`run`（`run_id` = 既存連番の続き・`round_index`=1・`task_id`=TASK-1012）**。`run` を省略すると metrics 集計対象外になる（C-1 R8 指摘 P-4）
