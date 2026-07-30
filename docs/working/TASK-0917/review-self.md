---
task_id: TASK-0917
artifact_type: review-self
schema_version: 1
status: final
verdict: PASS
created_by: c1-self-review
---

# TASK-0917 セルフレビュー結果（C-1）

> **対象**: [`plan.md`](./plan.md)（399 行）/ [`todo.md`](./todo.md)（102 行）/ [`test-cases.md`](./test-cases.md)（366 行）
> **入力**: [`pbi-input.md`](./pbi-input.md)（262 行・AC-1〜AC-9）/ [`review-external.md`](./review-external.md)（`R-001`〜`R-033` 全 33 件・1 回確定反映済み）
> **基点**: `origin/main` = `b45ab17` / ブランチ `task-0917-plan`
> **実施日**: 2026-07-31
> **Mode**: **critical** → **全項目実施**（core 17 項目 + テンプレート追加 8 項目 = 25 項目）
> **チェック項目の正本**: [`docs/working/templates/review-self.md`](../templates/review-self.md)（`C1-PLAN-01`〜`C1-B1B2-17` = core 17 / `C1-PLAN-08/09-AEE`・`C1-SUP-PLAN-01/02`・`C1-TODO-RB`・`C1-SEC-01`・`C1-SCOPE-DISC-01`・`C1-UI-01` = 追加 8）
> **判定方針**: 「書いてあるか」ではなく **「機械検証できるか」**。数値の主張はすべて数え直した。PASS は evidence 省略可 / WARN は evidence 推奨 / **FAIL は evidence 必須**（[`working-context.md`](../../../.claude/rules/working-context.md)）。

## 判定: **FAIL** — critical=0, **major=1**, minor=5, info=2

> ⚠️ **この見出しと以下の 25 項目判定表・指摘一覧・evidence は「C-1 実施時点」の記録であり、追記以外の変更をしていない**。F-1〜F-5 の是正後の判定（**PASS** / major=0）は本ファイル末尾 [「C-1 指摘の是正記録（2026-07-31）」](#c-1-指摘の是正記録2026-07-31) を参照。frontmatter の `verdict` は**是正後の値（PASS）**を持つ。

## サマリー

| result | 件数 | 内訳 |
|--------|------|------|
| **PASS** | **19** | C1-PLAN-01/02/03/04/06/07/08-AEE, C1-SUP-PLAN-01, C1-TODO-09/10/11/12/RB, C1-TEST-13/15, C1-B1B2-16/17, C1-SEC-01, C1-SCOPE-DISC-01 |
| **WARN** | **4** | C1-PLAN-09-AEE, C1-SUP-PLAN-02, C1-TODO-08, C1-TEST-14 |
| **FAIL** | **1** | **C1-PLAN-05**（Work Breakdown Output） |
| N/A | 1 | C1-UI-01（non-UI タスク） |
| 合計 | 25 | — |

**core 17 項目のみ**: PASS=14 / WARN=2（C1-TODO-08, C1-TEST-14）/ FAIL=1（C1-PLAN-05）

---

## 実行した機械検証（全コマンドと exit code）

すべて `cwd = /Users/user/Documents/GitHub/plangate`、読み取り専用。

| # | コマンド（要旨） | 結果 | exit |
|---|-----------------|------|------|
| V-01 | `git diff --stat origin/main -- scripts/ai-loop/delivery.py scripts/ai-loop/c3_contract.py scripts/ai-loop/c3prime_verify.py` | **出力 0 行** | **0** |
| V-02 | `python3 scripts/ai-loop/test_delivery.py` | **`Ran 57 tests in 0.141s` / `OK`** | **0** |
| V-03 | `sh tests/run-tests.sh` | **`Results: 430 passed, 0 failed`** | **0** |
| V-04 | `grep -oE '\bT-[0-9]+' todo.md \| sort -u -V \| wc -l` | **50**（T-1〜T-50・欠番なし） | 0 |
| V-05 | AWK で `- [ ]` 行の `Owner:` / `depends_on:` / `files:` / `rollback:` を全数検査 | **T-* 50 件すべて 4 フィールド充足**（欠落 0）。4 件の非充足行は 👤 Human タスク（`Owner:` のみ・仕様どおり） | 0 |
| V-06 | `grep -nE 'L-0\|V-1\|V-2\|V-3\|V-4\|PR 作成' todo.md` | HIT 2 行のみ = **L4 の除外宣言**と **L100 の依存関係注記**。**Agent タスクとしては 0 件** | 0 |
| V-07 | `plan_package._extract_section(plan, "Files / Components to Touch")` + `_PATH_RE` を import して再現 | **21 パス抽出** | 0 |
| V-08 | 上記 21 と todo の `[files: ...]` 実パス集合（`-` / `同上` を除く）を set 差分 | **`todo - allowed = []` / `allowed - todo = []`（完全一致・21 = 21）** | 0 |
| V-09 | `delivery._path_allowed()` に 21 集合を与えて代表 4 パスを判定 | `docs/working/TASK-0917/status.md`=True / `plugin/plangate/skills/x.md`=True / `scripts/ai-loop/collector.py`=True / `README.md`=**False** | 0 |
| V-10 | `### TC-` 見出しの全列挙・重複・欠番検査 | **見出し 48 件**（TC-01〜TC-39 の 39 連番 + TC-09b + TC-E1〜E8）。**重複 0 / 01〜39 に欠番 0** | 0 |
| V-11 | 48 TC ブロックの `- 入力:` / `- 期待出力:` / `- 種別:` 有無を Python で全数検査 | **48/48 が 3 項目すべて充足**。`- 前提条件:` は **10/48 のみ**（38 件欠落） | 0 |
| V-12 | `grep -nE 'python\|py3' tests/run-tests.sh` | **HIT 0**（run-tests.sh は python を一切呼ばない） | **1**（=非HIT） |
| V-13 | `grep -rn "test_plan_package" tests/ scripts/` | 起動は **0 件**。ta-55 L39/L93・ta-56 L41 の `import plan_package, test_plan_package as tpp`（fixture helper）と test_delivery.py L21 / test_c3prime_verify.py L23 の import のみ | 0 |
| V-14 | `grep -n "PRIORITY_ORDER" -A 12 scripts/ai-loop/delivery.py` | L48-51 = `invalid_snapshot`(1) / `plan_deviation`(2) / **`escalation_flags`(3)** | 0 |
| V-15 | `grep -n "CHECK_PENDING" scripts/ai-loop/delivery.py` | L88 `("pending","queued","in_progress")` / L285 で **`c["conclusion"]`** と比較 | 0 |
| V-16 | `validate_snapshot()` 本体の `need(` 出現数 | **12**（+ `conflict_resolution` は `snap.get()` の任意キー）。**未知キーを拒否する分岐は無い** | 0 |
| V-17 | `grep -n 'review_ok' scripts/ai-loop/delivery.py` | L290 `review["state"] == "approved"`（**小文字**） | 0 |
| V-18 | `grep -n 'cr_incomplete\|conflict_need\|deviated' scripts/ai-loop/delivery.py` | L298 / L302 / L265 に実在 | 0 |
| V-19 | AST で `scripts/ai-loop/*.py`（14 本）の実行系トークンを全数抽出 | **非 test の 12 本は clean**。HIT は `test_c3prime_verify.py` / `test_discovery.py` / `test_metrics.py` の 3 本のみ | 0 |
| V-20 | AST で `test_*.py` 内 `subprocess.*` 呼び出しの **argv 先頭要素**を全数抽出 | **21 箇所中 18 箇所が `sys.executable`、3 箇所が違反**（→ **F-1**） | 0 |
| V-21 | `sed -n '26,32p' tests/extras/ta-56-delivery.sh` | L29 に **`（51 テスト・R1/R2 回帰含む）`** = stale 実在（T-43 の是正対象が実在することを確認） | 0 |
| V-22 | `sed -n '338,358p' scripts/sync-plugin-plangate.sh` | **L345 = コピー元 for ループ** / **L355 = case 許可判定** の 2 箇所を実測確認 | 0 |
| V-23 | `## Questions / Unknowns` 節の番号付き項目数 | **10 件**（1.〜10. 欠番なし）→ plan 本文・todo C-3 行の「10 件」と一致 | 0 |
| V-24 | Work Breakdown の `**Step` 行数 / Risks 表の行数 | **Step 14 件** / Risks 19 行 | 0 |
| V-25 | `grep -nE 'TBD\|TODO\|後で実装\|必要に応じて\|適切に\|いい感じに\|要検討\|未定'` を 3 ファイルに実行 | HIT は **todo.md L1 の見出し `EXECUTION TODO` のみ**（誤検出） | 0 |
| V-26 | `npx markdownlint-cli2 "docs/working/TASK-0917/*.md"` | **`Summary: 0 issues in 0 files`**（6 ファイル） | **0** |
| V-27 | todo の `depends_on` チェーンを Python で全数検査 | **T-1(`-`)→T-2→…→T-50 の完全直列。dangling 参照 0 / 循環 0** | 0 |
| V-28 | `grep -oE '\bR-[0-9]{3}\b' review-external.md \| sort -u \| wc -l` | **33**（R-001〜R-033 欠番なし） | 0 |
| V-29 | AC-1〜AC-9 の 3 ファイル別 mention 数 | **9 AC すべてが plan / todo / test-cases の 3 ファイルに出現**（下記マトリクス） | 0 |
| V-30 | `grep -nE '\.env\|api[_-]?key\|token\|secret\|PAT\b'` を plan/todo に実行 | HIT 1 行のみ = plan L52 の設計議論（`pull_requests:write` スコープ）。**秘密値・実トークン 0 件** | 0 |

---

## AC-1〜AC-9 × (plan Step / todo タスク / TC) 網羅マトリクス

> 「todo」欄は **AC 文字列が直接現れるタスク**を太字、**節見出し経由で担当が確定するタスク**を括弧で示す（例: todo L21 `### gh 実行ラッパフェーズ（AC-5 の中核）` は T-7〜T-18 を束ねる）。

| AC | 要旨 | plan Step | todo タスク | test-cases TC | 判定 |
|----|------|----------|------------|--------------|------|
| **AC-1** | snapshot の head SHA 束縛 | Step 5 | **T-1 / T-23 / T-48**（+ T-25 実装） | TC-01（+01a/01b/01c）, TC-02, TC-03 | ✅ カバー |
| **AC-2** | `required_checks[]` ⊇ 照合 | Step 5 | **T-23**（+ T-25 実装 / T-48 突合） | TC-04, TC-05, TC-06 | ✅ カバー |
| **AC-3** | intent→実行→receipt→reconcile の冪等 | Step 6 / Step 7 | **T-29**（+ T-27 / T-28 / T-30 / T-31） | TC-07, TC-08, TC-09, TC-09b | ✅ カバー |
| **AC-4** | 実 PR repair E2E 1 周 | Step 8 / Step 9 | **T-35**（+ T-33 / T-34 / T-36） | TC-10, TC-11, TC-39 | ✅ カバー |
| **AC-5** | 破壊的操作の経路が存在しない | Step 1 / Step 2 | **T-5 / T-41**（+ 節見出し経由 T-4, T-6, T-7〜T-18） | TC-20〜TC-31（12 件） | ⚠️ カバー（**F-1** で Step 1 のチェックポイントが破綻） |
| **AC-6** | #894 Loop Control Contract 接続点 | Step 7 | **T-32 / T-48** | TC-12, TC-13 | ✅ カバー（R-023 の是正が効いている） |
| **AC-7** | delivery.py 系 3 ファイル不変 | Step 8 | **T-2 / T-33 / T-47** | TC-14, TC-15, TC-16 | ✅ カバー |
| **AC-8** | `ci_failure_taxonomy` の供給元特定 | Step 4 | **T-22 / T-41**（+ T-21 RED） | TC-17, TC-18, TC-19 | ✅ カバー |
| **AC-9** | raw check evidence の同梱と導出照合 | Step 5 | **T-24 / T-41 / T-48** | TC-32, TC-33, TC-34 | ✅ カバー |

**未カバーの AC: 0 件**（9/9 が plan Step・todo タスク・TC の三層すべてに写像されている）。
横断 TC-35〜TC-39（`changed_files` / `conflict_resolution` / `status→conclusion` 写像）も T-25 が担当し、実装タスクが 0 件の TC は存在しない。

---

## Plan チェック（7 項目 + AEE 2 項目）

### C1-PLAN-01: 受入基準網羅性

- **result**: **PASS**
- **category**: plan
- **finding**: AC-1〜AC-9 の 9 件が plan Step / todo タスク / TC の三層すべてに写像されている（V-29 + 上記マトリクス）。TC 側マッピング表（test-cases L8-19）とも一致。**AC に対して TC はあるが実装タスクが 0 件**という R-023 型の穴は AC-6（T-32 新設）で解消済みであることを実測確認した。
- **evidence_ref**: —
- **impacted_files**: []

### C1-PLAN-02: Unknowns 処理

- **result**: **PASS**
- **category**: plan
- **finding**: `## Questions / Unknowns` は **10 件**（V-23・plan 本文と todo C-3 行の「10 件」と一致）。10 件すべてが「AI が推奨案を提示 → C-3 で人間が明示判断」の形に整理されており未解決の宙吊りが無い。唯一の純粋な未確認事項（Q8: `rules/branches/{ref}` に repo admin 権限が要るかを非 admin トークンで反証していない）は **fail-closed に倒れる設計 + Replan Trigger** の二重の受け皿があり、「未確認」と明記されている。
- **evidence_ref**: —
- **impacted_files**: []

### C1-PLAN-03: スコープ制御

- **result**: **PASS**
- **category**: plan
- **finding**: `Constraints / Non-goals` に NO MERGE BY AI / 判定エンジン不変 / HO 非接触 / stdlib only が明記。Non-goals に merge 実行・判定規則変更・`evidence_ref` 真正性検証・#874/#869 接続を列挙。`Files / Components to Touch` の 21 パスと todo の `files:` が**完全一致**（V-08）なので、exec 中の逸脱は `_path_allowed()` → `plan_deviation` → `EXEC_RETURN` で機械検知される（V-09 で `README.md` が False になることを実測）。Replan Trigger に「plan 外ディレクトリへの波及 1 件で即停止」あり。
- **evidence_ref**: —
- **impacted_files**: []

### C1-PLAN-04: テスト戦略

- **result**: **PASS**
- **category**: plan
- **finding**: Unit（6 モジュール分の観点を個別列挙）/ Integration（Collector→assess→Executor→receipt→Reconciler の 1 周、`delivery.py` は実物）/ E2E（ta-57 fixture）/ 手動 E2E（実 PR 1 周・1 回）/ Edge cases（6 種）/ Verification Automation（4 群）が具体的に分離されている。fixture と実 API の乖離という D4-A 固有のリスクも Risks 表に明記済み。
- **evidence_ref**: —
- **impacted_files**: []

### C1-PLAN-05: Work Breakdown Output

- **result**: **FAIL**
- **category**: plan
- **finding**: Step 1〜14 すべてに Output / Owner / Risk / 🚩 チェックポイントは揃っている（V-24）。しかし **Step 1 の 🚩 チェックポイント「現行 `scripts/ai-loop/*.py` に対し AST 版が clean」と、plan L70 が同時に課す追加不変条件「`test_*.py` 内の `subprocess.run` / `check_output` の argv 先頭要素は `sys.executable` に限る」が、現行ツリーで両立しない**。現行ツリーには当該不変条件の違反が **3 箇所**実在し、いずれも `Files / Components to Touch` の 21 パスに**含まれていない**ファイルにある。したがって Step 1 は「達成不能な完了条件」を持ち、exec は (a) allowed_paths 外のファイルを編集して `plan_deviation` → `EXEC_RETURN` を踏む か (b) C-3 承認済みの不変条件を実装時に無断で弱める か のどちらかに追い込まれる。→ **F-1**
- **evidence_ref**: 本ファイル「### F-1 evidence（再現コマンドと出力全文）」（`evidence/` への保存は本 C-1 の担当スコープ外のため、再現コマンドと生出力を本ファイル内に全文記載）
- **impacted_files**: `docs/working/TASK-0917/plan.md`（L70 / Step 1 チェックポイント）, `docs/working/TASK-0917/test-cases.md`（TC-31 ①③）, `docs/working/TASK-0917/todo.md`（T-4 / T-5 / T-6）
- **suggested_action**: plan L70 / TC-31 / Step 1 チェックポイント の 3 箇所に「**既存 3 箇所（`test_c3prime_verify.py` L39 の `args[0] = "python3"` 文字列リテラル / `test_discovery.py` L530・L559 の `["git", "status", "--porcelain"]`）は grandfather 対象として明示除外し、新規追加分にのみ課す**」旨を 1 文追記して整合させる。あるいは「argv[0] は `sys.executable` **または読み取り専用 git サブコマンド**に限る」へ不変条件を精緻化する。**いずれも plan 本体の修正であり、C-3 承認前の確定反映としてオーガナイザーが判断すべき事項**（本 C-1 では修正しない）
- **owner**: agent（修正案作成）/ human（C-3 で採否判断）
- **resolved**: false

### C1-PLAN-06: 依存関係

- **result**: **PASS**
- **category**: plan
- **finding**: Step 1〜14 の順序が「守り（境界検査器 → gh_exec）→ 供給 → Collector → Executor/Reconciler → E2E → 配布/doc → 検証」で矛盾なく並ぶ。todo の `depends_on` は **T-1→T-2→…→T-50 の完全直列**で dangling 参照 0 / 循環 0（V-27）。Human 依存（C-3 前に exec 開始しない / T-35 は C-3 での D4-A 承認が前提 / C-4 後にマージ）も `## ⚠️ 依存関係` に明示。
- **evidence_ref**: —
- **impacted_files**: []

### C1-PLAN-07: 動作検証自動化

- **result**: **PASS**
- **category**: plan
- **finding**: **R-020 の是正は「検証手順を書いた」で終わっておらず、実効性がある**ことを実測で確認した。(1) `tests/run-tests.sh` は **python を一切呼ばない**（V-12 で HIT 0）。(2) `test_plan_package.py` は ta-55 L39/L93・ta-56 L41 から `import ... as tpp` の **fixture helper としてのみ** import され、リポジトリ内に**起動経路が 1 件も存在しない**（V-13）。この 2 点は plan / todo の主張どおり。(3) 是正として ta-57 に `python3 <root>/scripts/ai-loop/test_*.py` を **7 本**（新規 6 + `test_plan_package.py`）追加する設計になっており（Step 8 / T-33）、これは ta-56 L28 の既存前例（`python3 test_delivery.py` → `t56_pass "..."` = 1 モジュール 1 PASS 行）と同一様式で、実現可能。(4) 「行数 437 以上」だけでは 7 本中 5 本しか走らなくても閾値を通過しうるが、**Step 8 チェックポイントと T-34 が「7 本すべてが PASS 行として出力に現れることを目視ではなく grep で確認」を別途課しており、この抜け穴は塞がれている**。
- **evidence_ref**: —
- **impacted_files**: []

### C1-PLAN-08-AEE: Stop Condition 記入（#544 Phase1）

- **result**: **PASS**
- **category**: plan
- **finding**: `## Stop Condition` 実在。**下限 437 の算出根拠は plan 内で完全に追跡可能**: `## Metrics Evidence` 表が baseline = **430**（本セッションで実測）を、Stop Condition 直下の注記が「新規 PASS 行数 = 1 モジュール 1 PASS 行 × **7 本** + ta-57 fixture の PASS 行」を明示し、**437 = 430 + 7** を「下限」として定義している。**430 は本 C-1 でも独立に再実測して一致**（V-03: `Results: 430 passed, 0 failed` / exit 0）。7 本の内訳も Verification Automation 節でファイル名まで列挙されている。「430 を下回らないだけでは新規 6 本が 1 本も走らなくても通る」という下限引き上げの理由も明記済み。
- **evidence_ref**: —
- **impacted_files**: []

### C1-PLAN-09-AEE: Replan Triggers 機械値（#544 Phase1）

- **result**: **WARN**
- **category**: plan
- **finding**: 機械値は 6 件記入済み（変更ファイル数 > **24** / 同一検証コマンドの連続失敗 3 回 / 同一ファイルへの修正反復 3 回 / plan 外ディレクトリ波及 1 件 / 3 ファイルへの変更判明で即停止 / required checks 取得に admin 必須と判明）で、**AEE 記入要件は満たす**。ただし **Risks 表の最終行が旧値のまま残っており、同一 plan 内で機械値が矛盾している**（→ **F-2**）: L318 `> 24（= 想定 19 + 5）` / L273 `19` / `ratio 1.58` に対し、L363 は `（18 本 / ratio 1.5）| Replan Trigger（> 23 本）`。R-024 で `execution-runbook.md` を追加した際の追従漏れ。**exec 中に 24 本目で止めるべきか 23 本目で止めるべきかが plan から一意に読めない**。
- **evidence_ref**: 本ファイル「### F-2 evidence」
- **impacted_files**: `docs/working/TASK-0917/plan.md`（L363）
- **suggested_action**: L363 の Risks 行を `19 本 / ratio 1.58` / `> 24 本` に揃える（1 行の静的是正）
- **owner**: agent（修正案）/ human（確定反映の可否）
- **resolved**: false

---

## Plan 品質追加チェック（Superpowers 由来 / #581）

### C1-SUP-PLAN-01: No Placeholders Rule

- **result**: **PASS**
- **category**: plan
- **finding**: 3 ファイルに `TBD` / `TODO` / `後で実装` / `必要に応じて` / `適切に` / `いい感じに` / `要検討` / `未定` を全走査し、**実質 HIT 0**（V-25 の唯一の HIT は todo.md L1 の見出し文字列 `EXECUTION TODO`）。ファイルパス・関数シグネチャ（`push_pr_head(*, repo, branch, expected_parent_sha, cwd)` / `extract_allowed_paths(plan_text)`）・endpoint・検証コマンドがすべて具体名で書かれている。plan が参照する `delivery.py` の内部事実（`PRIORITY_ORDER` 3 位・`CHECK_PENDING` の比較対象・必須 12 キー・L290 小文字比較・`cr_incomplete`）は**すべて本 C-1 で原典に当たって裏取り済み**（V-14〜V-18）で、想像で書かれた記述は検出されなかった。
- **evidence_ref**: —
- **impacted_files**: []

### C1-SUP-PLAN-02: Task Sizing Rules

- **result**: **WARN**
- **category**: plan
- **finding**: 大半のタスクは「変更対象ファイル / 検証コマンド / 期待結果 / 依存」が具体的で Task 単位 approve/reject が可能。ただし 2 点で reviewer が Task 単位に判定できない: (1) **T-25（`collector.py` 実装）が突出して大きい** — REST GET 4 本 + `git diff --name-only` + `status→conclusion` 写像 + `review` 縮約規則 6 点 + 必須 12 キーの組み立て + `conflict_resolution` 条件付き出力 + pre-check の `escalation_flags` 化 + `changed_files` の fail-closed を 1 タスクに内包しており、部分承認できない（同様に T-16 / T-33 も複合）。(2) **T-4 / T-5 / T-6 の完了条件が F-1 により判定不能**（現行ツリー clean を要求しつつ、その clean 判定が現行ツリーで成立しない）。
- **evidence_ref**: 本ファイル「### F-1 evidence」
- **impacted_files**: `docs/working/TASK-0917/todo.md`（T-4/T-5/T-6/T-16/T-25/T-33）
- **suggested_action**: T-25 を「REST GET 層」「写像・縮約規則」「snapshot 組み立て + pre-check」の 3 タスクへ分割する案を C-3 論点に加える（分割は plan の Files を変えないため低コスト）
- **owner**: human（C-3 判断）
- **resolved**: false

---

## ToDo チェック（6 項目）

### C1-TODO-08: タスク粒度

- **result**: **WARN**
- **category**: todo
- **finding**: 全 **50** タスク（T-1〜T-50 欠番なし・V-04）。RED/GREEN が別タスクに割れており TDD 粒度としては良好で、大半は数分〜十数分規模。ただしテンプレートの基準「各タスクが 2〜5 分で完了できる粒度か」に対し、**T-16（`gh_exec.py` 実装）/ T-25（`collector.py` 実装）/ T-33（ta-57 の 4 要素）は明らかに超過**する複合タスク。critical モードの実装タスクとしては許容範囲だが、粒度基準に照らすと WARN。
- **evidence_ref**: `todo.md` L32（T-16）/ L47（T-25）/ L61（T-33）
- **impacted_files**: `docs/working/TASK-0917/todo.md`
- **suggested_action**: C1-SUP-PLAN-02 と同じ（T-25 の 3 分割）
- **owner**: human
- **resolved**: false

### C1-TODO-09: depends_on 設定

- **result**: **PASS**
- **category**: todo
- **finding**: **50/50 に `depends_on:` 記載**（V-05・欠落 0）。Python で全数検査した結果、**T-1(`-`) → T-2 → … → T-50 の完全直列**で、dangling 参照 0・循環 0（V-27）。なお完全直列＝並行実行の余地を宣言していないため、critical / 50 タスクの規模に対して所要時間が線形になる点は **F-7（info）**として記録するが、依存の正しさ自体には問題なし。
- **evidence_ref**: —
- **impacted_files**: []

### C1-TODO-10: チェックポイント設定

- **result**: **PASS**
- **category**: todo
- **finding**: todo に 🚩 が **16 箇所**、plan の Step に `🚩 チェックポイント` が **14 箇所**。todo の 🚩 は各フェーズの先頭・高リスクタスク（T-1/T-4/T-7/T-16/T-20/T-23/T-25/T-27/T-30/T-32/T-33/T-35/T-37/T-38/T-45/T-46）に配置され、plan の Step チェックポイントと対応している。
- **evidence_ref**: —
- **impacted_files**: []

### C1-TODO-11: Iron Law 遵守

- **result**: **PASS**
- **category**: todo
- **finding**: (1) **L-0 / V-1〜V-4 / PR 作成が Agent タスクに 0 件**（V-06。HIT は L4 の除外宣言と L100 の依存注記のみ = workflow-conductor 担当という正しい記述）。(2) `## ⚠️ 依存関係` L98 に「T-4 以降 → **Human C-3 APPROVED（`approvals/c3.json`）後に exec 開始**」を明記。(3) 外部作用を伴う T-35 は「C-3 で D4-A と検証用 PR の選定が承認されていること」を前提に置く。(4) merge は Human タスクにのみ存在し、Agent タスクに merge 系は 0 件（NO MERGE BY AI）。(5) carve-out ①② 該当のため ai-loop 自走時は escalate 固定を明記。
- **evidence_ref**: —
- **impacted_files**: []

### C1-TODO-12: 完了条件

- **result**: **PASS**
- **category**: todo
- **finding**: 各タスクが「何が出力されれば終わりか」を動詞レベルで持つ（RED = FAIL 確認 / GREEN = PASS 確認 / 検証系 = 実測コマンドと期待値）。とくに検証タスクは機械判定可能: T-2（`0 行` / `57 OK` / `430 passed`）、T-34（`exit 0` かつ `437` 以上 + 7 本の PASS 行を grep）、T-39（2 集合の差分 0）、T-40（2 回目 no-op + `git diff --quiet plugin/`）、T-44（`cmp -s` 一致）、T-47（AC-7 の 3 点）。T-1 / T-3 のような準備タスクは完了条件が暗黙だが、`files: -` / `rollback:不要` で読み取り専用と明示されており実害はない。
- **evidence_ref**: —
- **impacted_files**: []

### C1-TODO-RB: rollback（戻し手順）

- **result**: **PASS**
- **category**: todo
- **finding**: **50/50 に `rollback:` 記載**（V-05・欠落 0）。読取専用タスクは `rollback:不要`、新規ファイル作成は `ファイル削除`、既存改変は `git restore` / `git restore -- <path>` と使い分けられている。**外部作用を伴う T-35 のみ `rollback: L3（revert commit + 訂正コメント。force push / 削除は禁止のまま）`** と plan の Revert Policy L1〜L5 へ接続しており、critical モードで最も重要な「不可逆な外部作用の戻し方」が具体化されている。
- **evidence_ref**: —
- **impacted_files**: []

---

## テストケースチェック（3 項目）

### C1-TEST-13: 受入基準 → テストケース網羅性

- **result**: **PASS**
- **category**: test
- **finding**: AC-1〜AC-9 の 9 件すべてに最低 3 TC が割り当てられ（マッピング表 test-cases L8-19）、**未カバー AC = 0**。TC 番号は **TC-01〜TC-39 の 39 連番（欠番 0 / 重複 0）+ TC-09b + TC-E1〜E8 = 見出し 48 件**（V-10）。AC 横断の TC-35〜TC-39 も C-2 指摘（R-017/018/019/026）に 1:1 対応している。
- **evidence_ref**: —
- **impacted_files**: []

### C1-TEST-14: テストケースの具体性

- **result**: **WARN**
- **category**: test
- **finding**: **48/48 の TC ブロックに `入力` / `期待出力` / `種別` が揃う**（V-11）。期待値は値レベルで具体的（`review.state = "approved"` / `conclusion = "in_progress"` / `escalation_flags` の理由コード文字列 / `Ran 57 tests` / `exit 0` / `437`）で、「正しく動作する」型の曖昧記述は無い。TC-39 は変異注入（写像を外すと `invalid_snapshot` に落ちる）まで要求しており検出力の実証も設計されている。WARN の理由は 2 点: (1) **TC-31 の期待出力が F-1 により自己矛盾**（①「現行ツリーが clean」と ③「`test_*.py` の argv[0] が `sys.executable` でなければ FAIL」が現行ツリーで同時に成立しない）。(2) **`前提条件` を持つのは 48 件中 10 件のみ（38 件欠落）**（V-11）。多くは入力欄が状態を内包しており実害は限定的だが、TC-07（「intent + receipt が記録済み」）のように前提が結果を左右する種類の TC もあるため、fixture 前提の明示が薄い。→ **F-1 / F-4**
- **evidence_ref**: 本ファイル「### F-1 evidence」
- **impacted_files**: `docs/working/TASK-0917/test-cases.md`（TC-31）
- **owner**: human（C-3 判断）
- **resolved**: false

### C1-TEST-15: エッジケースの考慮

- **result**: **PASS**
- **category**: test
- **finding**: 専用節 `## エッジケース` に **TC-E1〜TC-E8**（rate limit / timeout / shallow clone の ancestry 解決不能 / `allowed_paths` 抽出 0 件 / `record.jsonl` 破損 / 通知コメント投稿失敗 / `dod_evaluated` の旧 head 束縛 / sync 列挙の片方漏れ）。加えて本編にも fail-open 封じの負側が厚く配置されている（TC-36 空 `changed_files` / TC-38 恒久 `CONFLICT` / TC-01c 旧 head approve / TC-06 取得失敗 / TC-34 raw 欠落）。**「取得失敗を空値で埋めない」型の負側が体系的に押さえられている**点は critical モードとして十分。
- **evidence_ref**: —
- **impacted_files**: []

---

## B-1 / B-2 チェック（2 項目）+ 追加項目

### C1-B1B2-16: B-1 確認質問

- **result**: **PASS**
- **category**: plan
- **finding**: plan 冒頭に `## 確認事項（B-1 / Human 回答済み 2026-07-31）` として Q1（AC-9 の去就）/ Q2（AC-4 の E2E 実現方式）/ Q3（repo 設定の穴 3 件の扱い）の 3 問と **Human 回答・帰結**が表で残っている。3 問とも pbi-input が名指しした曖昧点（U-1 / In scope 5 / 実測で判明した穴）に対応しており、回答が plan 本体の設計（AC-9 縮小・D4-A 採用・repo 設定非依存）へ実際に反映されている。
- **evidence_ref**: —
- **impacted_files**: []

### C1-B1B2-17: B-2 アプローチ比較

- **result**: **PASS**
- **category**: plan
- **finding**: 論点 **D1〜D5 の 5 論点**で比較。D1（3 案 A/B/C）/ D2（3 案 A/B/C）/ D4（3 案 A/B/C）/ D5（3 案 a/b/c）はいずれも 2 案以上で長短を表化し採用理由を明記。D3 は 7 キーそれぞれに 2〜3 案を並べた表で、採用案に「なぜ他案が不可か」（例: c3 record には値でなく `derived_loopspec_hash` しかない / #874 は下流なので委譲不可）を実測根拠付きで記載。不採用案の副作用（D1-B は AC-7 と正面衝突 / D2-B は 3 重に不成立 / D2-C は分離不可）も明示されている。
- **evidence_ref**: —
- **impacted_files**: []

### C1-SEC-01: 秘密情報 非接触（#578）

- **result**: **PASS**
- **category**: plan
- **finding**: plan / todo に秘密値・実トークン・ローカル絶対パスの記載 **0 件**（V-30 の唯一の HIT は `pull_requests:write` スコープに関する設計議論）。`.env` 参照なし。認証は T-35 の `gh auth status`（**状態確認のみ**・値を読まない）に限定され、Executor の外部作用は `gh` CLI の既存認証に委ねる設計。`gh_exec.py` の allowlist が `--input` / `--field` / `--raw-field` を一律 deny するため、秘密値が argv に混入する経路自体を狭めている。
- **evidence_ref**: —
- **impacted_files**: []

### C1-SCOPE-DISC-01: 発見事項の予防的分離（#578）

- **result**: **PASS**
- **category**: plan
- **finding**: 分離方針が 3 層で明示されている: (1) Q3 の repo 設定の穴 3 件は **別 issue 起票**とし「本 PBI の完了条件には含めない」と明記。(2) V2 候補（required checks の config キャッシュ / プロセス外の物理ガード / 実 API drift 検出 / `ta-56` テスト件数ラベルの動的抽出 R-033）を handoff へ記録する **T-50** が実在。(3) Replan Trigger が「plan 外ディレクトリへの波及 1 件で即停止」「`delivery.py` 系への変更が必要と判明した時点で即停止」を課しており、発見事項をその場で直す誘因を構造的に断っている。
- **evidence_ref**: —
- **impacted_files**: []

### C1-UI-01: UI デザインシステム準拠（#579）

- **result**: **N/A**
- **category**: plan
- **finding**: `is_ui_task = false`。成果物は Python モジュール / shell テスト / ドキュメントのみで UI 要素を含まない。
- **evidence_ref**: —
- **impacted_files**: []

---

## 検出した指摘一覧

| ID | severity | 対象 | 内容 | 関連チェック |
|----|----------|------|------|-------------|
| **F-1** | **major** | `plan.md` L70 / Step 1 / `test-cases.md` TC-31 / `todo.md` T-4〜T-6 | subprocess 境界検査器の追加不変条件（`test_*.py` の argv[0] は `sys.executable` 限定）に対し、**現行ツリーに違反が 3 箇所実在**。「現行ツリーが clean」というチェックポイント / TC 期待値と両立しない。違反 3 箇所はいずれも `Files / Components to Touch` の 21 パス**外**のファイル | C1-PLAN-05（FAIL）/ C1-SUP-PLAN-02 / C1-TEST-14 |
| **F-2** | minor | `plan.md` L363 | Risks 表最終行が旧値のまま（`18 本 / ratio 1.5` / `> 23 本`）。L273 の `19` / `1.58`、L318 の `> 24` と矛盾。R-024 の追従漏れ | C1-PLAN-09-AEE（WARN） |
| **F-3** | minor | `plan.md` L356-363 | Risks 表の途中（L357）に `> **V2 候補（handoff へ記録）**: …` の blockquote が挿入され、**表が 2 分割**されている。L358 以降の 6 行はヘッダ行を持たないため多くの Markdown レンダラで表として描画されない（markdownlint は 0 issues のため機械検出されない・V-26） | — |
| **F-4** | minor | `test-cases.md` 全体 | **48 TC ブロック中 38 件に `前提条件` が無い**（`入力` / `期待出力` / `種別` は 48/48 充足）。TC-07 のように前提が結果を決める TC でも fixture 前提の明示が薄い | C1-TEST-14（WARN） |
| **F-5** | minor | `todo.md` | `[files: 同上]` が **12 件**。直前タスクを人間が辿らないと解決できず、`files:` の**機械照合が 12 タスク分できない**（今回は手で辿って 21 集合と一致を確認したが、自動化時に落ちる） | C1-TODO-09 |
| **F-6** | info | `todo.md` | todo が TC ID を参照するのは **TC-12 / TC-13 の 2 件のみ**。他の 46 TC は「どのタスクで書かれるか」が節見出しと文脈依存で、T-48 の一括突合に委ねられている | C1-TEST-13 |
| **F-7** | info | `todo.md` | `depends_on` が **T-1→T-50 の完全直列**で、critical / 50 タスクに対して並行実行の余地が宣言されていない。plan にも `parallelization` の言及なし | C1-TODO-09 |

> **正の確認（誤りが無いことを実測した項目）**: `pbi-input.md` の「必須 13 キー」が誤りで **plan の「必須 12 + 任意 `conflict_resolution` 1」が正しい**ことを `validate_snapshot()` の `need(` 全数カウント（=12）で確認（V-16）。同様に `PRIORITY_ORDER` 3 位（V-14）、`CHECK_PENDING` が `conclusion` と比較されること（V-15）、L290 の小文字比較（V-17）、`cr_incomplete` / `deviated` の実在（V-18）、baseline 430（V-03）、57 テスト（V-02）、AC-7 差分 0 行（V-01）、ta-56 L29 の「51 テスト」stale（V-21）、sync の L345 / L355 2 箇所（V-22）、R-020 の主張（V-12 / V-13）は **すべて plan の記述どおり**だった。

---

### F-1 evidence（再現コマンドと出力全文）

**再現コマンド 1** — plan L70 の追加不変条件を AST で現行ツリーに適用（`scripts/ai-loop/test_*.py` 内の `subprocess.*` 呼び出しの argv 先頭要素を全数抽出）:

```python
# python3 - <<'EOF'  (cwd = repo root)
import ast, pathlib
for p in sorted(pathlib.Path('scripts/ai-loop').glob('test_*.py')):
    tree = ast.parse(p.read_text())
    for n in ast.walk(tree):
        if (isinstance(n, ast.Call) and isinstance(n.func, ast.Attribute)
                and n.func.attr in ('run','check_output','Popen','call','check_call')
                and isinstance(n.func.value, ast.Name) and n.func.value.id == 'subprocess'):
            a0 = n.args[0] if n.args else None
            first = (ast.unparse(a0.elts[0]) if isinstance(a0, (ast.List, ast.Tuple)) and a0.elts
                     else ast.unparse(a0)[:60] if a0 is not None else 'NOARGS')
            print(f"{p.name}:{n.lineno} argv0={first}")
# EOF
```

出力（exit 0・21 箇所中の**違反 3 箇所を抜粋**、残り 18 箇所はすべて `argv0=sys.executable`）:

```text
test_c3prime_verify.py:42 argv0=args        ← 違反 (1)
test_discovery.py:530 argv0='git'           ← 違反 (2)
test_discovery.py:559 argv0='git'           ← 違反 (3)
test_discovery.py:475 argv0=sys.executable
...（以下 18 箇所は sys.executable）
```

**再現コマンド 2** — 違反箇所の実ソース:

```sh
sed -n '36,46p' scripts/ai-loop/test_c3prime_verify.py
sed -n '526,534p;555,562p' scripts/ai-loop/test_discovery.py
```

出力:

```python
# scripts/ai-loop/test_c3prime_verify.py L38-42
def _run(task_dir, expected_sha=None):
    args = ["python3", str(VERIFY), str(task_dir)]     # ← argv[0] は文字列 "python3"（sys.executable でない）
    if expected_sha is not None:
        args.append(expected_sha)
    return subprocess.run(args, capture_output=True, text=True).returncode
                          # ↑ argv が変数のため AST では中身を追えず、静的に sys.executable と証明できない

# scripts/ai-loop/test_discovery.py L530 / L559（TestReadOnlyInvariant 内）
        before = subprocess.check_output(
            ["git", "status", "--porcelain"], cwd=REPO_ROOT, text=True   # ← argv[0] = "git"
        )
        after = subprocess.check_output(
            ["git", "status", "--porcelain"], cwd=REPO_ROOT, text=True   # ← argv[0] = "git"
        )
```

**再現コマンド 3** — 違反ファイルが `allowed_paths` に含まれないことの確認（plan の抽出経路を実物で再現）:

```python
import sys; sys.path.insert(0, 'scripts/ai-loop')
import plan_package as pp
sec = pp._extract_section(open('docs/working/TASK-0917/plan.md').read(), 'Files / Components to Touch')
allowed = sorted({m.group(1) for m in pp._PATH_RE.finditer(sec)})   # → 21 件
'scripts/ai-loop/test_c3prime_verify.py' in allowed   # False
'scripts/ai-loop/test_discovery.py'      in allowed   # False
```

**なお本 C-1 で確認した「plan が正しい」側**: 追加不変条件を除いた本体ルール（`gh_exec.py` 以外は実行系トークン禁止）は、**現行ツリーの非 test 12 本に対して AST で clean**（V-19）。plan が指摘した「substring 走査だと `discovery.py` L41 / L340 の docstring 禁止宣言文に HIT して偽陽性になる」という実測も再現できた（`grep -rn subprocess scripts/ai-loop/*.py` は `discovery.py` の docstring 2 行に HIT する）。**破綻しているのは追加不変条件と「現行ツリー clean」の両立のみ**であり、設計思想そのものは有効。

### F-2 evidence

```sh
grep -nE '18 本|19 本|> 23|> \*\*24\*\*|ratio 1\.5|1\.58' docs/working/TASK-0917/plan.md
```

```text
273:| 触るファイル数（…） | **19**（上表 #1〜#19。R-024 で `execution-runbook.md` を追加） | 12 | **1.58** | …
318:- 変更ファイル数 > **24**（= 想定 19 + 5。R-024 で `execution-runbook.md` を追加したことに伴う再計算）
363:| 実装規模が見積り超過（18 本 / ratio 1.5） | Replan Trigger（> 23 本） | モジュール統合（…）を C-3 で相談 |
```

---

## C-3（Human）へ持ち上げる論点

> plan `## Questions / Unknowns` は **10 件**と記載されており、**実数も 10 件**（V-23: 番号 1.〜10. 欠番なし）。**記載と実数は一致**している。以下に 10 件を再掲し、C-1 の実測結果を各件に紐づける。加えて C-1 で新たに検出した論点を **A / B** として追加する。

| # | plan Questions の論点 | C-1 実測からの補足 |
|---|---------------------|-------------------|
| 1 | **D1-A の採否**（⊇ 照合を Collector pre-check + `escalation_flags` に限定） | `PRIORITY_ORDER` の `escalation_flags` = **3 位**（`invalid_snapshot` / `plan_deviation` の次）を実測確認（V-14）。D1-A は AC-7（差分 0 行・V-01 で baseline 確認済み）と両立する |
| 2 | **D2-A の採否と AC-5 の scope 限定**（in-process allowlist は Executor 経路のみ） | 現行ツリーの非 test 12 本は AST で clean（V-19）＝境界検査器の本体ルールは導入可能。**ただし追加不変条件は F-1 の是正が前提** |
| 3 | **R-005 案②（明示通知コメント）+ 外部作用の実行順序**（コメント → pre-check → push） | 「不可逆な外部作用の順序」は本 C-1 では机上検証のみ。TC-09b / TC-E6 で相互整合が設計されていることは確認したが、**実挙動の裏取りは T-35 の実 PR 実走まで未確認** |
| 4 | **AC-9 の縮小実施の追認**（手作り snapshot の直接投入は塞がない） | `validate_snapshot()` に**未知キー拒否の分岐が無い**ことを実測（V-16）＝ raw 同梱による snapshot 拡張は `delivery.py` を変えずに成立する。限界の記載先 3 箇所（doc §4 / handoff / docstring）が plan・todo T-41・test-cases で一致していることも確認 |
| 5 | **D5（AC-6 の I/F 先行固定）の採否** | R-023 の是正（T-32 新設）により **AC-6 に実装タスクが 0 件だった状態は解消**（マトリクス参照）。TC-12 / TC-13 は todo から ID で参照される唯一の TC でもある |
| 6 | **D3 の `findings[]` 供給（receipt `result_ref` の convention 利用）の採否** | `delivery.py` 側に `result_ref` の型制約が無い前提の設計。**convention（`adopted:<sha>` / `rejected:<path>`）は機械契約でなく文字列規約**である点が C-3 の判断ポイント |
| 7 | **D4-A の採否と実 PR の選定**（本リポジトリの検証用 PR を 1 本使う / 後片付けは Human-owned） | 後片付け（close / branch 削除）が Executor で原理的に不可能なことは allowlist 設計と整合。**PR 選定そのものは未確定** |
| 8 | **未確認事項の受容**（`rules/branches/{ref}` の取得に repo admin 権限が必須かを非 admin トークンで反証していない） | 本 C-1 でも**反証していない**（GET API を叩いていないため未確認のまま）。取得失敗は fail-closed に倒れる設計であることは TC-06 で固定済み |
| 9 | **Executor の実行主体を手元環境（人間起動）に固定 / CI 実行は scope 外** | `gh auth status` 前提が T-35 に明記されていることを確認。plan の Files に `scripts/gh-s977043.sh` 等が含まれないことも V-07 の 21 集合で確認 |
| 10 | **外部書き込み層の plugin 配布同梱の可否**（新規 12 本を whitelist へ足すか） | sync の **L345 for ループ / L355 case の 2 箇所**を実測確認（V-22）。同梱すると `executor.py` / `gh_exec.py` が下流へ渡る。**drift-check CI は whitelist 未追加でも通る**＝配布は必須でなく選択、という plan の主張は構造上そのとおり |
| **A（C-1 新規）** | **F-1: subprocess 境界の追加不変条件と「現行ツリー clean」の両立方針** | 既存 3 箇所を grandfather 除外するか、不変条件を「`sys.executable` **または読み取り専用 git**」へ精緻化するか、`test_c3prime_verify.py` / `test_discovery.py` を Files に追加して修正するか。**3 案目は `allowed_paths` の変更 = plan 本体修正**を伴う |
| **B（C-1 新規）** | **F-2 / F-3 の静的是正の可否**（Risks 表の旧値 1 行 / 表を割る blockquote 1 行） | いずれも 1〜2 行の記述是正。**C-3 承認前の確定反映に含めるか、C-3 で「軽微として承認」するか**の判断 |

> ⚠️ **plan 編集は本 C-1 の担当外**。F-1〜F-7 の是正可否・反映タイミング（C-3 承認前の確定反映に含めるか）はオーガナイザーおよび C-3 の判断事項。`plan_hash` 無効化を避けるため、本 C-1 では 3 ファイルを **1 バイトも変更していない**。

---

## 未確認事項（本 C-1 で確かめていないこと）

- **GitHub API の実レスポンス**: `gh api` を一度も実行していない。`rules/branches/{ref}` の権限要件・`check-runs` / `reviews` の実形状（plan が実測として記載する内容）は **plan の記述を追検証していない**。
- **`gh_exec.py` の allowlist が実際に既知禁止 9 種を deny するか**: 実装が存在しない（V: `scripts/ai-loop/gh_exec.py` / `collector.py` / `check_exec_boundary.py` / `tests/extras/ta-57-pr-convergence.sh` はいずれも**未作成 = exec 後に成立**）。TC-20〜TC-31 は設計レビューのみ。
- **ta-57 が実際に 7 本を起動して 437 以上になるか**: ta-57 未作成のため未検証。ただし **ta-56 L28 に同一様式の前例が実在**することは確認済み（V-21 の周辺）。
- **敵対レビュー R1 / R2（T-45 / T-46）の観点**: 本 C-1 は C-1 チェックリストに限定しており、外部作用層の迂回路探索は行っていない。

---

## C-1 指摘の是正記録（2026-07-31）

> 上記の 25 項目判定表・検出した指摘一覧・F-1 evidence は **C-1 実施時点の記録として一切変更していない**。本節は、その後にオーガナイザー裁定に基づき `plan.md` / `todo.md` / `test-cases.md` へ加えた**是正の記録**（追記専用）。

### F-1〜F-7 の対応表

| ID | severity | status | 裁定 / 判断 | 反映箇所 |
|----|----------|--------|------------|---------|
| **F-1** | major | **fixed** | 不変条件を**精緻化**（`sys.executable` **または**読み取り専用 git サブコマンド allowlist = `status` / `rev-parse` / `diff` / `log` / `merge-base` / `ls-remote` / `show`）+ `test_c3prime_verify.py` の `_run()` を**ファイル + 関数名で特定する grandfather 例外 1 件として凍結**（例外リストが増えないことをテストで固定）+ **静的追跡不能な argv は例外リスト外なら violation（fail-closed）**。`test_c3prime_verify.py` の `sys.executable` 化は **V2 候補**として本 PBI では触らない（`allowed_paths` を増やさない） | `plan.md`: D2-A 設計詳細の AST 検査 bullet + 新設小節「`test_*.py` の argv 先頭要素 不変条件（精緻化 / C-1 F-1 の裁定）」（4 項目）/ Step 1 🚩 チェックポイント / Testing Strategy の `test_check_exec_boundary.py` 行 / Risks 表下の V2 候補 2. ・ `todo.md`: T-4 / T-5 / T-6 ・ `test-cases.md`: TC-31 期待出力（①③に allowlist と例外リストを反映・⑤ fail-closed を追加）+ 新設 **TC-31b**（例外リスト 1 件固定の負側 TC・変異注入で検出力実証）+ AC-5 マッピング行 |
| **F-2** | minor | **fixed** | Risks 表の旧値を Metrics Evidence / Replan Triggers と統一（`18 本 / ratio 1.5` → `19 本 / ratio 1.58`、`> 23 本` → `> 24 本`）。plan 全体を grep して**他に旧値の残存が無い**ことを確認（HIT はこの 1 行のみだった） | `plan.md` Risks 表 最終行 |
| **F-3** | minor | **fixed** | Risks 表を分断していた `> **V2 候補（handoff へ記録）**: …` の blockquote を**表の全行が終わった後**へ移動。あわせて F-1 由来の V2 候補を 2 番目の項目として同 blockquote に追加。**plan / todo / test-cases の全 Markdown 表を機械走査**し、分断は **0 件**であることを確認 | `plan.md` Risks 表直下 |
| **F-4** | minor | **fixed** | `前提条件` が欠けていた **38 TC すべてに簡潔な 1 行の前提条件を追加**（既存 10 件は変更なし）。追加後は **49/49 の TC が `前提条件` / `入力` / `期待出力` / `種別` の 4 項目を充足**（欠落 0） | `test-cases.md` 全体（TC-03 / 05 / 06 / 08 / 12〜34 / 36〜38 / E1〜E8） |
| **F-5** | minor | **fixed** | `[files: 同上]` **12 件**を実パスへ展開（T-8〜T-14 = `scripts/ai-loop/test_gh_exec.py` / T-17 = `scripts/ai-loop/gh_exec.py` / T-24 = `scripts/ai-loop/test_collector.py` / T-26 = `scripts/ai-loop/collector.py` / T-38 = `scripts/sync-plugin-plangate.sh` / T-46 = `docs/working/TASK-0917/`）。展開後の `files:` 集合が **`## Files / Components to Touch` 抽出 21 パスと完全一致**（両方向差分 0）であることを実測 | `todo.md` T-8〜T-14 / T-17 / T-24 / T-26 / T-38 / T-46 |
| **F-6** | info | **部分対応** | 全 TC への ID 付与は見送り。理由 = TC↔タスクの突合は **T-48（`test-cases.md` 全 TC の機械実行）と AC 網羅マトリクスで既に担保**されており、46 タスクへの ID 転記は stale 化リスク（行番号アンカーと同型）を新たに作る割に便益が薄い。ただし **F-1 是正で新設した TC-31b の担当タスクが不明確になることは避ける**ため、T-4 にのみ「対応 TC: TC-31 / TC-31b」を明記した | `todo.md` T-4 |
| **F-7** | info | **対応不要** | `depends_on` の完全直列は critical モードでは**安全側**（外部作用層の実装順序を固定したい / RED→GREEN の TDD 順序が本質的に直列）。並行化は exec 中の実行時判断で行えばよく、plan 段階で並行宣言する必要がない。所要時間の線形性は既知トレードオフとして受容 | 変更なし |

### 是正後の再検証（全コマンド実測）

| # | 検証 | 結果 |
|---|------|------|
| 1 | `plan_package._extract_section` + `_PATH_RE` による `allowed_paths` 抽出 | **21 件**（不変）。不変 3 ファイル（`delivery.py` / `c3_contract.py` / `c3prime_verify.py`）の混入 **0**。`execution-runbook.md` を含む |
| 2 | todo の全 `files:`（`同上` 展開後）⊆ 抽出 21 集合 | **`todo - allowed = []` / `allowed - todo = []`**（完全一致・`同上` 残存 0） |
| 3 | `grep -oE 'T-[0-9]+' todo.md \| sort -u \| wc -l` | **50**（plan Mode判定「実数 50」と一致） |
| 4 | plan / todo / test-cases の Markdown 表 分断走査 | **SPLIT COUNT = 0** |
| 5 | 49 TC の `前提条件` / `入力` / `期待出力` / `種別` 充足 | **欠落 0**（4 項目 × 49 件） |
| 6 | TC 番号の重複・欠番 | **重複 0**。数値 TC-01〜TC-39 に**欠番 0**。加えて TC-09b / TC-31b / TC-E1〜E8 |
| 7 | `npx markdownlint-cli2 "docs/working/TASK-0917/*.md"` | **0 issues** |
| 8 | `decision-log.jsonl` の JSON 妥当性 | 全行 parse 成功 |
| 9 | `git status --short` | 担当 5 ファイル以外の変更なし |
| 10 | `git diff --stat origin/main -- <AC-7 の 3 ファイル>` | **0 行** |

### 是正後の総合判定: **PASS**

- **critical = 0 / major = 0**（F-1 fixed により C1-PLAN-05 の FAIL 要因が解消）/ minor = 0（F-2〜F-5 fixed）/ info = 2（F-6 部分対応・F-7 対応不要 — いずれも判定に影響しない）
- 影響を受けるチェック項目の是正後の見立て: **C1-PLAN-05 = FAIL → PASS**（Step 1 の完了条件が現行ツリーで達成可能になった）/ **C1-PLAN-09-AEE = WARN → PASS**（Replan Trigger の機械値が plan 内で一意）/ **C1-TEST-14 = WARN → PASS**（TC-31 の自己矛盾解消 + `前提条件` 欠落 0）。**C1-SUP-PLAN-02 / C1-TODO-08 は WARN のまま**（T-25 / T-16 / T-33 の複合タスク粒度は本是正の対象外 = C-3 の分割判断に委ねる。ただし WARN は FAIL 要因ではない）
- 上記 25 項目判定表そのものは C-1 実施時点の記録として保存し、本節の見立てで**上書きしていない**（append-only）
