# EXECUTION TODO — TASK-0921

> Plan: [`plan.md`](./plan.md) / Tests: [`test-cases.md`](./test-cases.md)
> C-2: [`review-external.md`](./review-external.md)（`Refs: R-001`〜`R-020` を本版で確定反映）
> Mode: **high-risk（Slice 1）**（全extrasの実行制御とexit contractを変更するためC-3必須）
> **Slice 2 は本 PBI スコープ内の後続スライス。着手時に Mode を再判定する**（plan `## Mode判定`）

## スライス

| Slice | 対象 | ファイル数 | 対応 Task |
|---|---|---:|---|
| **Slice 1** | 層 A 12 本 + helper + contract TA + README | **15** | T-01, T-02, T-03, T-05, T-06, T-07（README 部分）, T-08 |
| **Slice 2** | 層 B 36 + 層 C 5 = 41 本 + `TASK-0914/handoff.md` writeback | **42** | T-04, T-07（writeback 部分） |

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
H-04 Slice 2 の Mode 再判定 → T-04 + T-07 writeback
```

> **案 D 採用により削除**: 旧 `T-01 → conflict → REPLAN (explicit finalizer)` 分岐は
> 不要になった（最初から案 D）。旧 H-03（trap 競合時の replan 判断）も消滅。

## Human Tasks

- [ ] **H-01**: 案 D（末尾 explicit finalize）+ 共有 helper `_extra-contract.sh`（#914 E-1 反転）+
      スライス分割の C-3
- [ ] **H-02**: Slice 1 PR の C-4 / merge
- [ ] **H-04**: **Slice 2 着手時の Mode 再判定**（42 ファイル = 定量 critical 帯）と、
      別 PBI へ切り出すか否かの判断

## Agent Tasks

### Preparation

- [ ] **T-01: Runtime inventory**
  - `ta-*.sh` 全件をsortしてevidence保存
  - capability候補、fallback、counter、top-level exit/return、cleanup、stdin readを表にする
  - **層 0 の 4 本（`ta-26` / `ta-58` / `ta-59` / `ta-60`）と層 A の 12 本（`ta-40` 含む）を再確認**（R-003）
  - **basename ベース test-id の一覧を作り重複 0 を確認**（R-016）
  - exact countはstatusへ記録するがtest期待値に埋め込まない
  - unclassifiedが1件でもあれば停止
  - `rollback:` **不要**（読取・分類のみ。ファイルを変更しない）

### TDD: Shared Contract

- [ ] **T-02: RED tests**
  - harness mode no-op（**probe env を読まない**ことを含む）
  - harness-only direct → exit2 before body
  - standalone pass → 0 / fail → 1
  - **prerequisite missing → 3**（R-002）
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
  - POSIX `sh -n`
  - synthetic tests GREEN
  - checkpoint commit
  - `rollback:` helper 追加 commit と（残す場合の）runner source 行 commit を `git revert <sha>`
    （未 push なら `git reset --hard`）。**T-04 / T-05 を戻す場合は本 Task の revert が最後**（依存順）

### Migration

- [ ] **T-04: harness-only migration（Slice 2）**
  - 対象は層 B 36 + **層 C 5**（D-2 (c) 採用 / R-007）= 41 本
  - exactly one capability marker
  - helper bootstrap/initをbody side effect前へ配置
  - direct execution loop: all rc2 + standard error（**basename test-id** を名乗る）
  - tmp/audit side effectがないこと
  - 10〜15 files単位のreviewable commits
  - `rollback:` batch 単位 commit を `git revert <sha>`（未 push なら `git reset --hard`）。
    **helper 導入前まで戻す場合は T-03 の revert が前提**（helper 不在で marker/init だけ残ると
    全 harness-only ファイルが起動時に落ちる）。revert 順序は **T-04 → T-03**

- [ ] **T-05: standalone-capable migration（Slice 1 中核）**
  - marker + init + **末尾 explicit finalize**（案 D）
  - file固有root fallbackを保持
  - **legacy footer の 2 系統を helper へ吸収**（R-003）:
    `ta-26` の `[ "$fail" != "0" ]` 形 / `ta-59` `ta-60` の `[ "$fail" -eq 0 ] || exit 1` 形
  - **`ta-39` / `ta-43` / `ta-44` の prerequisite 経路を rc=3 へ**（R-002）
  - **`ta-26` TC-33 の検査対象を helper 側へ差し替える**（R-013 / AC-8）。空振り化させない
  - **summary 書式 `TA-<NN> standalone: N passed, M failed` を維持**（R-015a）
  - ta-26は最後に移行
  - 各batch後full suite
  - `rollback:` batch 単位 commit を `git revert <sha>`（未 push なら `git reset --hard`）。
    **helper 導入前まで戻す場合は T-03 の revert が前提**。`ta-26` は最終 batch なので単独 revert 可。
    revert 順序は **T-05 → T-03**

### Regression / Evidence

- [ ] **T-06: contract TA**
  - marker exactly-one / marker・init 一致（**basename test-id**）
  - **test-id 一意性**（R-016 / TC-20）
  - harness-only dynamic all-files（rc2）
  - standalone dynamic all-files: **probe なし rc0 と probe あり rc1 の差分**（裁定 ②）
  - **prerequisite 未充足 → rc3**（R-002 / TC-17）
  - source path full suite completion marker（**`ls tests/extras/ta-*.sh | tail -1` を runtime 解決。
    ファイル名をハードコードしない** / R-006）
  - **README grep 検査**（rc 0/1/2/3・marker・probe・rc2 名前空間 / R-009 / R-020 / TC-19）
  - self-recursion prevention（**probe env 再帰ガードを含む** / R-015b / TC-23）
  - helper mutation M-01〜M-12
  - `rollback:` contract TA ファイル追加 commit を `git revert <sha>`（単独 revert 可。
    ただし revert すると回帰検出力を失うため、revert する場合は理由を status に記録）

- [ ] **T-07: docs/writeback**
  - README **rc table 0/1/2/3**
  - capability selection checklist / **basename test-id 規約**
  - **案 D（trap を張らない）であり README 規約 1–2 に例外を作らないこと**を明記
  - **共有ファイル `_extra-contract.sh` は exit 契約 helper 限定の例外**であることを明記
  - **probe を test section 限定で公開**（必須 5 項目: test-only / 失敗を増やすだけ /
    CI・開発シェル・`.env` に設定しない / harness mode では無視 / 通常 `[FAIL]` と区別可能）
  - **rc=2 は harness-only 誤実行専用であり hook BLOCK とは別名前空間**（R-020）
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
3. `fix(tests): propagate standalone-capable failures`（Slice 1・複数reviewable commits可）
4. `test: enforce extras capability inventory`
5. `docs: define extras execution contract`
6. `fix(tests): reject direct execution of harness-only extras`（**Slice 2**・複数reviewable commits可）

各commitは単独でfull suiteを壊さない順序にする。helper導入後、file migration中は未移行fileをcontract TA対象外にする暫定allowlistを置かず、contract TAは全移行と同commitまたは最後に追加する。中間commitをPR上でcheckout可能にする必要がある場合、migration status markerを明示し最終commitで0件を要求する。

**revert 依存順**: T-04 / T-05 の batch commit → T-03（helper）の順で戻す。
helper だけ先に revert すると marker/init が残った extras が起動時に落ちる。

## Stop / Escalation

- [ ] C-3前は実装しない
- [ ] source経路でexitが発火したら停止
- [ ] standalone正常実行がhangしたらprocessを止め、stdin/外部dependencyを分類
- [ ] cleanupがrepo内pathを対象にしたら停止
- [ ] ta-26 regression（rc / summary 書式 / TC-33 検出力）がhelperで解消できなければreplan
- [ ] broad migration中にmainのextras変更と競合したらrebase後inventory再実測
- [ ] **Slice 2 を Mode 再判定なしに着手しようとしたら停止**
- [ ] **`TASK-0914/handoff.md` §3 の writeback 対象行が消失していたら停止**

## Completion

- [ ] test-cases TC-01〜TC-23 PASS
- [ ] mutation M-01〜M-12が期待どおりFAIL
- [ ] pre-fix HEAD で contract TA が FAIL する evidence
- [ ] all files classified dynamically / test-id 重複 0
- [ ] harness suite 0 failed
- [ ] Issue / handoff writeback（append-only）
- [ ] Human C-4
