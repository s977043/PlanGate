# EXECUTION TODO — TASK-0921

> Plan: [`plan.md`](./plan.md) / Tests: [`test-cases.md`](./test-cases.md)
> C-2: [`review-external.md`](./review-external.md)（`Refs: R-001`〜`R-020` +
> **別系統 C-2（4 レーン）由来の `R-021`〜`R-037`** を確定反映。
> **R-032 は `resolved-by-design` につき反映せず**。未確定 4 件は plan の
> `## Human C-3 の判断事項`＝**HJ-1 / HJ-2 / HJ-3 / HJ-4**）
> Mode: **high-risk（Slice 1）**（全extrasの実行制御とexit contractを変更するためC-3必須）
> **Slice 2 は本 PBI スコープ内の後続スライス。着手時に Mode を再判定する**（plan `## Mode判定`）

## スライス

| Slice | 対象 | ファイル数 | 対応 Task |
|---|---|---:|---|
| **Slice 1** | 層 A 12 本 + helper + contract TA + README | **15** | T-01, T-02, T-03, T-05, T-06, T-07（README 部分）, T-08 |
| **Slice 2** | 層 B 36 + 層 C 5 = 41 本 + **層 0 の 4 本** + `TASK-0914/handoff.md` writeback | **46** | T-04, **T-04b**, T-07（writeback 部分） |

> **層 0（`ta-26` / `ta-58` / `ta-59` / `ta-60`）は Human 決定 3 により Slice 2 へ繰り延べ**。
> Slice 1 に含めると 19 ファイル = critical 帯に入るため。**`ta-*.sh` 57 本の内訳は
> 12（層 A / Slice 1）+ 4 + 36 + 5（Slice 2）で過不足なし**（plan の「57 本のスライス帰属」節）。
>
> **DoD の正本は [`test-cases.md`](./test-cases.md) の `## Exit Criteria`**（Slice 1 / Slice 2 に
> 分離済み）。**Slice 1 PR の V-1 は Slice 1 節のみを突合する**。

## Dependency Graph

```text
H-01 Human C-3
  ↓
T-01 runtime inventory + capability/test-id audit
  ↓
T-02 helper RED tests
  ↓
T-03 helper (+ runner loading 要否の比較検証 / R-010)
  ↓
T-05 standalone migration（Slice 1 中核）
  ↓
T-06 inventory/dynamic contract TA
  ↓
T-07 docs（README）
  ↓
T-08 verification（pre-fix HEAD FAIL 実証を含む）
  ↓
H-02 Human C-4 / merge（Slice 1）
  ↓
H-04 Slice 2 の Mode 再判定 → T-04 + T-04b + T-07 writeback
```

> **案 D 採用により削除**: 旧 `T-01 → conflict → REPLAN (explicit finalizer)` 分岐は
> 不要になった（最初から案 D）。旧 H-03（trap 競合時の replan 判断）も消滅。

## Human Tasks

- [ ] **H-01**: 案 D（末尾 explicit finalize）+ 共有 helper `_extra-contract.sh`（#914 E-1 反転）+
      スライス分割の C-3
- [ ] **H-02**: Slice 1 PR の C-4 / merge。
      **判定対象は [`test-cases.md`](./test-cases.md) `## Exit Criteria` の Slice 1 節のみ**
- [ ] **H-04**: **Slice 2 着手時の Mode 再判定**（46 ファイル = 定量 critical 帯）と、
      別 PBI へ切り出すか否かの判断
- [ ] **H-05**: **AC-8 を pbi-input の受入基準へ追記するか否かの裁定**（Slice 2 着手時 / C-1 MN-5）。
      AC-8 は C-2（R-013）由来の派生 AC で pbi-input 正本には存在しない
- [ ] **H-06**: **HJ-1〜HJ-4 の裁定**（C-3 時 / plan `## Human C-3 の判断事項`）
  - **HJ-1**: CI の `sh` 実体固定（R-022）。**`.github/workflows/**` は HO 対象のため
    AI は適用せず patch 提示のみ**。案 (a) dash 明示 / 案 (b) dash + bash matrix
  - **HJ-2**: 層 C の ROOT sentinel を **Slice 1 へ前倒しするか / Slice 2 の D-2 (c) に委ねるか**（R-023）
  - **HJ-3**: `timeout-minutes: 10` の再見積り（R-026）。**HO 対象・patch 提示のみ**
  - **HJ-4**: 案 D における `original rc` の捕捉規約（R-030）。
    **(a) 2 値化を採ると TC-06 の再定義を伴う** / (b) 保持 + 「finalize 直前に他コマンドを
    挟まない」規約化。**Task 5 の置換テンプレートと README 規約が変わるため C-3 で確定する**

## Agent Tasks

### Preparation

- [ ] **T-01: Runtime inventory**
  - `ta-*.sh` 全件をsortしてevidence保存
  - capability候補、fallback、counter、top-level exit/return、cleanup、stdin readを表にする
  - **層 0 の 4 本（`ta-26` / `ta-58` / `ta-59` / `ta-60`）と層 A の 12 本（`ta-40` 含む）を再確認**（R-003）
  - **basename ベース test-id の一覧を作り重複 0 を確認**（R-016）
  - **移行期間 allowlist の内容を inventory から機械生成**
    （「inventory 全件 − 層 A」の basename を 1 行 1 件。手書きしない / MJ-E）。
    **別ファイルは作らず T-06 で contract TA 本体の `_pending_migration` heredoc へ転記**し、
    生成物と転記結果を `diff` で照合する（Human 決定 4 / MJ-F / MJ-G）。
    evidence: `evidence/test-runs/pending-migration-gen.log`
  - exact countはstatusへ記録するがtest期待値に埋め込まない
  - unclassifiedが1件でもあれば停止
  - `rollback:` **不要**（読取・分類のみ。ファイルを変更しない）

### TDD: Shared Contract

- [ ] **T-02: RED tests**
  - harness mode no-op（**probe env を読まない**ことを含む）
  - harness-only direct → exit2 before body
  - standalone pass → 0 / fail → 1
  - **prerequisite missing → 3**（R-002）。**`pg_extra_contract_skip` が唯一の表明経路**であり、
    skip を経ずに rc3 が出ないこと（C-1 MN-4）
  - **prerequisite missing かつ `fail > 0` → 1**（rc3 へ丸めない / C-1 第 2 ラウンド MN-2）。
    診断に「既に立っている fail」が出ること
  - **harness mode の finalize は必ず明示 `return 0`**（R-024）。合成 harness を source して
    **後続ファイルのマーカー行と `Results:` 行が両方出る**ことを RED で固定（TC-26）
  - **helper に `local` を使わない / mode を source 時にキャッシュしない**（R-033-1 / R-033-2）
  - **probe message が `PG_EXTRA_CONTRACT_PROBE_FIRED:<basename-id>` を含む**（R-029-1）
  - original nonzero rc preservation
  - 末尾 finalize 未呼出の検出（案 D の弱点補償）
  - cleanup drain / **`register_cleanup` 非再定義**（R-019b）
  - force-fail target match/mismatch/**TARGET 未設定は fail-closed**（裁定 ②）
  - **probe env の子伝播なし**（R-015b）
  - invalid capability fail-closed
  - `rollback:` 未 push なら `git reset --hard`、push 済みなら該当 commit を `git revert <sha>`。
    テスト追加のみで実装への依存はなく、単独 revert 可

- [ ] **T-03: helper implementation**
  - create `_extra-contract.sh`（`set -eu` 下で source-safe / R-019a）
  - **R-010 比較検証**: defensive bootstrap 単独で全経路 helper 解決が成立するかを実測。
    成立するなら `tests/run-tests.sh` の変更を落とし Files 表と Human Approval Boundary から除去。
    落とせない場合は「なぜ bootstrap だけでは不足か」を根拠付きで記載
  - runner を残す場合、runner diffはhelper sourceに限定
  - **bootstrap のアンカーは `${EXTRAS_DIR:-<script dir>}`。`$0` にしない**（R-025-1）。
    harness 経路の `$0` は `tests/run-tests.sh` を指すため `tests/_extra-contract.sh`（不在）へ
    解決し、`set -eu` 下の `.` 失敗で **suite 全滅**する
  - **runner を残す場合、「helper source」と「各 extras の bootstrap 追加」は同一 commit /
    同一 PR**（forward 側の原子性 / R-025-2）
  - **`local` 不使用を機械確認**（`grep -n '\blocal\b' tests/extras/_extra-contract.sh` = 0 件 / R-033-1）
  - POSIX `sh -n`
  - synthetic tests GREEN
  - checkpoint commit
  - `rollback:` helper 追加 commit と（残す場合の）runner source 行 commit を `git revert <sha>`
    （未 push なら `git reset --hard`）。**T-04 / T-04b / T-05 / T-06 を戻す場合は本 Task の
    revert が最後**（依存順。contract TA（T-06）も helper API を参照する / C-1 MN-3）

### Migration

- [ ] **T-04: harness-only migration（Slice 2）**
  - 対象は層 B 36 + **層 C 5**（D-2 (c) 採用 / R-007）= 41 本
  - exactly one capability marker
  - helper bootstrap/initをbody side effect前へ配置
  - direct execution loop: all rc2 + standard error（**basename test-id** を名乗る）
  - tmp/audit side effectがないこと
  - **`ta-31-codex-plugin-status.sh` の分岐内 `return 0 2>/dev/null || true` 4 箇所を除去**
    （R-021 の残余。`mktemp` 失敗時にだけ通る経路だが同じシェル依存を持つ）
  - 10〜15 files単位のreviewable commits（**batch を risk 単位で切る案は R-037-1 の
    Slice 2 判断材料。plan `#### Slice 2 着手時の判断材料` 参照**）
  - `rollback:` batch 単位 commit を `git revert <sha>`（未 push なら `git reset --hard`）。
    **helper 導入前まで戻す場合は T-03 の revert が前提**（helper 不在で marker/init だけ残ると
    全 harness-only ファイルが起動時に落ちる）。revert 順序は **T-04 → T-03**

- [ ] **T-04b: 層 0 migration（Slice 2）**
  - 対象は層 0 の 4 本（`ta-26` / `ta-58` / `ta-59` / `ta-60`）。
    **Human 決定 3 により Slice 1 から繰り延べ**
  - marker + init + **末尾 explicit finalize**（案 D）
  - **legacy footer の 2 系統を helper へ吸収**（R-003）:
    `ta-26` の `[ "$fail" != "0" ]` 形 / `ta-59` `ta-60` の `[ "$fail" -eq 0 ] || exit 1` 形
  - **`ta-26` TC-33 の検査対象を helper 側へ差し替える**（R-013 / AC-8 / TC-22 / M-09）。
    空振り化させない。**着手前に plan の `### ta-26 TC-33 の扱い` を再読する**
  - **summary 書式 `TA-<NN> standalone: N passed, M failed` の等価性を前後比較**（R-015a / TC-18）
  - **`ta-58` / `ta-59` / `ta-60` の現行 summary 書式を grep する消費者が存在しないことを
    移行前に実測確認**（C-1 第 2 ラウンド MN-6）。実測では R-015a の書式に一致するのは
    `ta-26` のみで、`ta-58` / `ta-59` は `Results: %d passed, %d failed`、`ta-60` は
    `TA-60 standalone: pass=%s fail=%s`。TC-18 は `ta-26` のパリティしか要求していない
  - `ta-26` は Slice 2 の最後に移行し、既存 heavy tests を前後比較
  - **移行完了で contract TA の `_pending_migration` が 0 行になることを確認し、関数ごと削除**（TC-24 / AC-5）
  - `rollback:` batch 単位 commit を `git revert <sha>`（未 push なら `git reset --hard`）。
    **helper 導入前まで戻す場合は T-03 の revert が前提**。`ta-26` は最終 batch なので単独 revert 可。
    revert 順序は **T-04b → T-03**

- [ ] **T-05: 層 A migration（Slice 1 中核）**
  - 対象は**層 A 12 本のみ**。**層 0 の 4 本は対象外**（T-04b / Slice 2）
  - marker + init + **末尾 explicit finalize**（案 D）
  - file固有root fallbackを保持
  - **層 A 12 本は全数がカウンタ未初期化**（pbi-input A-1'）→ helper の `pass=0` / `fail=0` に載せる
  - **早期脱出 7 本の prerequisite 経路を `pg_extra_contract_skip` 経由の rc=3 へ**
    （R-002 / **R-021 により 3 本 → 7 本へ拡大**）:
    - `|| exit 0` 型 **3 本**: `ta-39` / `ta-43` / `ta-44`（`ta-39` は裸の `exit 0` も除去）
    - **`|| true` 型 4 本**: `ta-45` / `ta-46` / `ta-47` / `ta-49`
    **7 本とも層 A で本 Slice の対象**（ファイル集合は不変＝Mode 判定に影響しない）。
    **特定は `grep -rn 'return 0 2>/dev/null' tests/extras/` を起点にする**
    （`exit 0` 起点では `|| true` 型を取りこぼす）。
    **`ta-31` の 4 箇所は分岐内かつ層 B のため Slice 1 の対象外**
  - **移行後に `grep -rn 'return 0 2>/dev/null' tests/extras/` が層 A について 0 件**（R-021）
  - **dash と bash の双方で 7 本を standalone 実走**し rc が一致することを確認（TC-29 / R-021）。
    evidence: `evidence/test-runs/dual-shell-skip.log`
  - **移行前に `ta-43` の SKIP 分岐で `fail>0` かつ rc=0 になる現状を実測記録**
    （C-1 第 2 ラウンド MN-1 / AC-1 の実害の一次証跡）。sandbox 構成は plan の
    `#### TC-17 / M-10 の sandbox 構成手順`。**`[FAIL]` は `>&2`（stderr）へ出る**ため
    記録は `... </dev/null > <log> 2>&1` とする（MN-B。`ta-39` / `ta-44` も同一形と実測）。
    evidence: `evidence/verification/pre-migration-fail-swallow.log`
  - helper の summary 書式を `TA-<NN> standalone: N passed, M failed` に確定（R-015a）。
    **`<NN>` は test-id から `^ta-([0-9]+)` を抽出して導出**（C-1 MN-2）。
    `ta-26`（層 0 / Slice 2）の TC-13 が将来この literal を grep するため Slice 1 で確定させる
  - 各batch後full suite
  - `rollback:` batch 単位 commit を `git revert <sha>`（未 push なら `git reset --hard`）。
    **helper 導入前まで戻す場合は T-03 の revert が前提**。revert 順序は **T-05 → T-03**

### Regression / Evidence

- [ ] **T-06: contract TA**
  - **検査対象は移行済み集合＝移行期間 allowlist（contract TA 本体に内蔵した
    `_pending_migration`）が返さないファイル**（Slice 1 は層 A 12 本）。allowlist は
    **base commit 時点の未移行ファイルを列挙した明示リスト**であり、**述語で解決しない**
    （述語にすると marker/init を持たない新規追加ファイルが黙って除外され
    TC-16 / M-06 が空振りする / MJ-E）。内容は Task 1 の runtime inventory から生成した
    結果を **contract TA の heredoc へ転記**し、移行のたびに行を削除する。
    **Slice 2 完了時に 0 行**になり `_pending_migration` 関数ごと削除する（TC-24 / AC-5）
  - **`_pending_migration` の各行の健全性を検査**（TC-25 / M-14 / MN-E）:
    各行が `tests/extras/` に**実在**し、helper bootstrap / init を**持たない**こと。
    加えて次の 3 点を assert し、allowlist 過大化による 0 件ループの黙認 PASS を塞ぐ:
    **① 検査対象集合（discovered − pending）から contract TA 自身を除いた集合が非空**
    （**自己を除外しないと恒真で発火しない** / MJ-I）**② `pending ⊊ discovered`（真部分集合）**
    **③ TC-12 / TC-13 を駆動する per-file 実走ループが 1 件以上を実行した**
    （期待件数は置かない。件数は**ループ進入時ではなく、ループ本体のフィルタを通過して
    段 1 の実行（`sh "$file" </dev/null` の 1 回）を開始した時点**で数える。
    **前提未充足（rc=3）に落ちる分も計数に含める**＝TC-17 が rc=3 で正しく扱う正当な状態を
    確定 FAIL にしないため）
  - **TC-17 / M-10 を sandbox で Slice 1 のうちに実走**（Human 決定 5）。
    手順は plan の `#### TC-17 / M-10 の sandbox 構成手順`（repo 実コピー → 述語文字列除去 →
    コピー側 standalone 実行）。**`FIXTURES_DIR` でルート差し替え不可**のため実コピーが必須。
    **destructive な操作は `mktemp` fixture 内のみ**で行い repo 本体を書き換えない。
    evidence: `evidence/test-runs/prereq-rc3.log`
  - **contract TA 自身の集合帰属**: inventory に含める / allowlist には載せない /
    marker・init 検査の対象に含める。自己再帰の回避は per-file 実走ループで自分の
    test-id を skip することで行う（集合から外さない）
  - marker exactly-one / marker・init 一致（**basename test-id**）
  - **test-id 一意性**（R-016 / TC-20。移行状態に依存しないため **allowlist 対象外で
    runtime discovery した全件を検査**）
  - harness-only dynamic all-files（rc2 / TC-11）。**ループは Slice 1 から回す**が
    Slice 1 の対象は 0 件（vacuous PASS）。**対象 0 件であることを evidence に明示記録**し、
    Slice 1 中に追加された harness-only ファイルを捕捉する（INFO-1）。**実効は Slice 2**
  - standalone dynamic: **段 1 で probe なし 1 回実行し前提充足 / 未充足へ分類**（rc0 / rc3。
    それ以外は分類不能 = 即 FAIL）→ **前提充足クラスのみ** probe なし rc0 と probe あり rc1 の
    差分を要求（裁定 ② / C-1 MN-4）
  - **prerequisite 未充足 → rc3**（R-002 / TC-17）。**rc=3 は `pg_extra_contract_skip` 由来で
    あることを併せて assert**（テスト本体の直接 `exit 3` を許さない）
  - source path full suite completion marker（**`ls tests/extras/ta-*.sh | tail -1` を runtime 解決。
    ファイル名をハードコードしない** / R-006）
  - **README grep 検査**（rc 0/1/2/3・marker・probe・rc2 名前空間 / R-009 / R-020 / TC-19）
  - **marker 検出は plan の `#### marker 検出の正規表現仕様`（ERE + 先頭 20 行限定）に従う**
    （R-027 / M-17。1 行 2 marker / 行末スペース / heredoc 内 / 自己マッチ の 4 空振りを塞ぐ）
  - **per-file timeout**（R-026）: **最低 180s**（`ta-26` 実測 54〜58s）/
    `command -v timeout` があれば `timeout(1)`・無ければ `perl -e 'alarm …; exec @ARGV'` へ
    フォールバック（**macOS 開発機には `timeout(1)` が無い / CI にはある**）/
    **timeout 発火は SKIP でなく FAIL**
  - **discovery 集合 == runner の source 集合を assert**（R-035 / TC-28 / M-19）。
    両者が同じ glob 定義を参照する構造にする
  - **TC-16 は sandbox（repo 実コピー）で行い実 `tests/extras/` へ書き込まない**（R-028）
  - **TC-11 の合格条件を `rc == 2` AND `[ERROR] <basename-id> is harness-only` の
    id 込み照合にする**（R-029-2）。**TC-12 の (b) は `rc == 1` AND
    `PG_EXTRA_CONTRACT_PROBE_FIRED:<basename-id>` の AND**（R-029-1）
  - **`sh -n` を独立 TC 化**（TC-27 / R-029-3）。構文破壊の rc=2 が harness-only 誤用と
    紛れないようにする
  - self-recursion prevention（**probe env 再帰ガードを含む** / R-015b / TC-23）
  - helper mutation M-01〜M-19（各 M の Slice は `test-cases.md` の Mutation Matrix に従う）
  - `rollback:` contract TA ファイル追加 commit を `git revert <sha>`。
    **helper 導入前まで戻す場合は T-03 の revert が前提**（contract TA も helper API
    （`pg_extra_contract_init` / `pg_extra_contract_skip` / probe env）を参照するため）。
    revert 順序は **T-06 → T-03**（C-1 MN-3）。
    revert すると回帰検出力を失うため、revert する場合は理由を status に記録

- [ ] **T-07: docs/writeback**
  - README **rc table 0/1/2/3**
  - capability selection checklist / **basename test-id 規約**
  - **案 D（trap を張らない）であり README 規約 1–2 に例外を作らないこと**を明記
  - **共有ファイル `_extra-contract.sh` は exit 契約 helper 限定の例外**であることを明記
  - **probe を test section 限定で公開**（必須 5 項目: test-only / 失敗を増やすだけ /
    CI・開発シェル・`.env` に設定しない / harness mode では無視 / 通常 `[FAIL]` と区別可能）
  - **rc=2 は harness-only 誤実行専用であり hook BLOCK とは別名前空間**（R-020）
  - **`return 0 2>/dev/null || …` を型を問わず使わない**／**skip は `pg_extra_contract_skip` 経由**
    （R-021。理由として **dash は終了・bash は継続**という 2 型のシェル依存を併記）
  - **helper を対話シェルへ source しない**（R-033-3。standalone finalize の `exit` が
    ユーザのシェルを落とす）
  - **`ta-` プレフィクスを持つファイルのみが test として収集される**（R-032 の残余の任意項目）
  - `</dev/null` rule
  - **`TASK-0914/handoff.md` §3 の 2 行を append-only で CLOSED マーク**（Slice 2 / R-008）:
    `**#921 完了時に AC-6 の判定を exit code ベースへ戻す**` 行と
    `standalone preamble の共通化（7 env unset のインライン 12 ファイル重複の解消）` 行。
    **行を削除せず status を `CLOSED（#921 / PR #NNN, YYYY-MM-DD）` へ更新。記号アンカーで指し行番号を書かない**
  - #921 AC evidence and actual inventory
  - `rollback:` docs commit を `git revert <sha>`（実装への依存なし・単独 revert 可）

- [ ] **T-08: final verification**
  - `sh -n`
  - **contract TA を含むフルスイート 1 回 + contract TA 単独 2 回**（R-017 の CI 時間裁定）
  - **CI 実行時間を計測し baseline 231s との差分を evidence 化**（R-017）
  - dirty environment run（probe env を含む）
  - interrupted standalone cleanup check
  - **pre-fix HEAD（helper 導入前）で contract TA が FAIL する evidence**（AC-7 / R-011）
  - C-2 shell/test/workflow lanes
  - PR scope audit
  - `rollback:` **不要**（検証・読取のみ）

## Commit Strategy

1. `test: add RED tests for extras execution contract`
2. `feat(tests): add shared extras standalone contract`
3. `fix(tests): propagate 層 A standalone failures`（Slice 1・複数reviewable commits可）
4. `test: enforce extras capability inventory`（**移行期間 allowlist `_pending_migration` を内蔵**）
5. `docs: define extras execution contract`
6. `fix(tests): reject direct execution of harness-only extras`（**Slice 2**・複数reviewable commits可）
7. `fix(tests): fold 層 0 standalone footers into the shared contract`（**Slice 2** / T-04b）

各commitは単独でfull suiteを壊さない順序にする。中間commitをPR上でcheckout可能にする必要がある場合、migration status markerを明示する。

**移行期間 allowlist の扱い（スライス分割に伴う変更 / C-1 MJ-C）**: Slice 1 は
**単独 PR として merge される**ため、「contract TA は全移行と同 commit または最後に追加する」
方針は成立しない（Slice 1 merge 時点で 45 本が未移行）。したがって contract TA は
**移行期間 allowlist を持った状態で Slice 1 に載せる**。allowlist は
**contract TA 本体に内蔵した `_pending_migration`（明示リスト）**（base commit 時点の
未移行ファイルを列挙。T-01 が inventory から機械生成した内容を heredoc へ転記）であり、
**述語で解決しない**。**別ファイルを作らないため Slice 1 = 15 ファイルが維持される**
（Human 決定 4）。移行のたびに行を削除して縮める。
**Slice 2 完了時に 0 行になることを TC-24 / AC-5 で機械検証**し、恒久化を防ぐ
（0 行になった時点で `_pending_migration` 関数ごと削除する）。
これは pbi-input AC-5 の「修正前の allowlist は移行期間のみ保持し恒久化しない」が
**明示的に許容する形態**であり、同 AC 後半の「allowlist を明示し、将来の追加ファイルが
黙って除外されない構造にする」も同時に満たす（新規追加ファイルは `_pending_migration` に無い＝検査対象）。

**revert 依存順**: T-04 / T-04b / T-05 / T-06 の commit → T-03（helper）の順で戻す。
helper だけ先に revert すると marker/init が残った extras が起動時に落ち、
contract TA（T-06）も helper API を解決できなくなる（C-1 MN-3）。

## Stop / Escalation

- [ ] C-3前は実装しない
- [ ] source経路でexitが発火したら停止
- [ ] standalone正常実行がhangしたらprocessを止め、stdin/外部dependencyを分類
- [ ] cleanupがrepo内pathを対象にしたら停止
- [ ] ta-26 regression（rc / summary 書式 / TC-33 検出力）がhelperで解消できなければreplan（Slice 2）
- [ ] broad migration中にmainのextras変更と競合したらrebase後inventory再実測
- [ ] **Slice 2 を Mode 再判定なしに着手しようとしたら停止**
- [ ] **Slice 1 の exec 中に層 0（`ta-26` / `ta-58` / `ta-59` / `ta-60`）へ触る必要が生じたら停止**
      （15 ファイル / high-risk 判定の前提が崩れる → Mode 再判定 → 人間へエスカレーション）
- [ ] **段 1 の分類で rc 0 / 3 のいずれでもない値を返す層 A ファイルがあれば停止**（MN-4）
- [ ] **HJ-1〜HJ-4 が未確定のまま exec へ入ろうとしたら停止**（とくに **HJ-4 = `original rc` の
      捕捉規約**は Task 5 の置換テンプレートと README 規約を決めるため / R-030）
- [ ] **CI が `timeout-minutes: 10` 超過で落ちたら停止**（R-026。**HO 対象のため AI は適用せず
      Human へ patch 適用を依頼**）
- [ ] **`|| true` 型の早期脱出が dash / bash で異なる rc を返す状態のまま T-06 の検証へ
      入ろうとしたら停止**（R-021 / issue #1026）
- [ ] **フルスイートで flaky が観測されたら「フルスイート 1 回」への緩和を撤回**（MN-6）
- [ ] **`TASK-0914/handoff.md` §3 の writeback 対象行が消失していたら停止**

## Completion

> **DoD の正本は [`test-cases.md`](./test-cases.md) の `## Exit Criteria`**（Slice 1 / Slice 2 に
> 分離済み）。本節は要約であり、判定は正本側で行う。

### Slice 1（本 PR の完了条件）

- [ ] test-cases `## Exit Criteria` の **Slice 1 節**を全項目充足
- [ ] pre-fix HEAD で contract TA が FAIL する evidence（AC-7）
- [ ] 層 A 12 本が dynamic に分類され、test-id（basename）重複 0（TC-20 は runtime discovery した全件）
- [ ] harness suite 0 failed
- [ ] 移行期間 allowlist が contract TA 本体の `_pending_migration`（明示リスト）で解決され、述語解決になっていない
- [ ] `_pending_migration` の各行が実在かつ未移行であり、**自己を除いた**検査対象集合が非空・`pending ⊊ discovered`・TC-12 / TC-13 の実行件数が 0 でない（TC-25 / M-14）
- [ ] TC-17 / M-10 が sandbox 実走済み（Slice 2 へ繰り延べていない）
- [ ] **TC-26 / TC-27 / TC-28 / TC-29 PASS**（R-024 / R-029-3 / R-035 / R-021）
- [ ] **M-15〜M-19 が期待どおり FAIL**（R-021 / R-024 / R-027 / R-029 / R-035）
- [ ] **早期脱出 7 本が移行済みで `grep -rn 'return 0 2>/dev/null' tests/extras/` が
      層 A について 0 件**（R-021）
- [ ] **HJ-1〜HJ-4 が C-3 で裁定済み**（plan `## Human C-3 の判断事項`）
- [ ] TC-11 を Slice 1 でも実行済み（対象 0 件なら「対象 0 件」を evidence に明示記録 / INFO-1）
- [ ] Human C-4（H-02）

### Slice 2

- [ ] test-cases `## Exit Criteria` の **Slice 2 節**を全項目充足
- [ ] TC-01〜TC-29 を通しで再実行して PASS（Slice 1 DoD の非退行）
- [ ] **`ta-31` の分岐内 `return 0 2>/dev/null || true` 4 箇所が解消され、
      `grep -rn 'return 0 2>/dev/null' tests/extras/` が全件 0 件**（R-021 の残余 / 層 B）
- [ ] `_pending_migration` が 0 行になり関数ごと削除されている（TC-24 / AC-5）
- [ ] Issue / `TASK-0914/handoff.md` writeback（append-only / AC-6）
- [ ] Human C-4
