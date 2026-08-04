# PBI INPUT PACKAGE — TASK-0981

> Issue: [#981](https://github.com/s977043/plangate/issues/981)「Plan Contract を定義し、Planner と Executor の分離実行を安全にする」
> スコープ: **本 PBI は issue コメント（2026-08-04 / Human 確定の実行方針）の PR1 のみ**を対象とする。PR2〜PR4 は後続スライスとして In scope 外（順序依存を明記）
> 作成: 2026-08-04（**作成時点 main = `a667c0dbc2298a4d347775ab72ac4c7b36e4d186`（`a667c0d`）で実測**。裏取り結果は下表）
> 関連: [#980](https://github.com/s977043/plangate/issues/980)（Agent Identity / 署名付きイベント — 主体モデルの正本。本 PBI では先取りしない）/ [#872](https://github.com/s977043/plangate/issues/872)・[#889](https://github.com/s977043/plangate/issues/889)・[#895](https://github.com/s977043/plangate/issues/895)（c3-prime 受理器 + Plan-first 束縛）/ [#873](https://github.com/s977043/plangate/issues/873)・[#905](https://github.com/s977043/plangate/issues/905)（`delivery.py`）/ [#917](https://github.com/s977043/plangate/issues/917)・[#941](https://github.com/s977043/plangate/issues/941)（Collector / Executor / Reconciler）

## Context / Why

PlanGate では Plan を作成する Agent と、その Plan を実行する Agent が同一とは限らない（issue 本文の例: Hermes = Plan 作成 / Claude = レビュー / System = C-3' 判定 / Codex = 実装 / Gemini = 検証 / Human = C-4 merge）。この構成で安全に走らせるには、Executor が「**どの Plan を・どの版で・どの承認に基づいて**実行したか」を機械的に検証できる必要がある。

**ただし本 PBI は新しい Plan Contract 基盤をゼロから作らない**。issue の最新コメント（Human 確定の実行方針）が正であり、現行リポジトリには既に Plan Contract 相当の実体が存在する:

| 既存資産 | 役割 |
|---|---|
| [`docs/workflows/ai-loop/c3-prime-contract.md`](../../workflows/ai-loop/c3-prime-contract.md) | Plan Package 6 要素 / `plan_hash` / `plan_package_hash` / `artifact_hashes` / C-1・C-2 evidence の plan hash 束縛 / C-3' approval record / exec preflight の stale・source SHA 検証（フィールド契約正本） |
| [`scripts/ai-loop/plan_package.py`](../../../scripts/ai-loop/plan_package.py) | presence / integrity 検証・Plan Package hash 算出・evidence stale 検証・`allowed_paths` 抽出・maker / checker 分離・c3-prime record 生成 |
| [`scripts/ai-loop/c3prime_verify.py`](../../../scripts/ai-loop/c3prime_verify.py) | 受理側 strict verifier（`bin/plangate` の exec preflight / `delivery.py` が共有） |
| [`scripts/hooks/check-plan-hash.sh`](../../../scripts/hooks/check-plan-hash.sh) | EH-3: `approvals/c3.json.plan_hash` と現 `plan.md` の突合（**補助防衛**） |

したがって #981 の役割は次のとおり再定義される（issue コメント verbatim）:

> 既存の Plan Package / c3-prime 契約を Plan Contract の正本として棚卸し・整理し、Planner と Executor が異なる場合に不足する実行主体、実行参照、revision / resume 契約を additive に補完する。

**PR1（本 PBI）は「棚卸し・ADR・正本整理」まで**であり、コード実装（preflight 拡張 / execution record 追加 / revision・resume）は PR2 以降に置く。

---

## 裏取り結果 1: ギャップ分析 12 項目（作成時点 main = `a667c0d`・すべて実コードで確認）

判定は **既存で満たす / 一部満たす / 未対応** の 3 値。根拠はファイル:行。**推測で「実装済み」と書いていない**（関数名が issue コメントの想定と異なる場合は実在名を記載した）。

| # | 要件 | 判定 | 根拠（ファイル:行） |
|---|---|---|---|
| 1 | Plan 本文の hash 固定 | **既存で満たす** | `scripts/ai-loop/plan_package.py:135-146`（`compute_hashes()`。`plan_hash = artifact_hashes["plan.md"]`）/ `scripts/ai-loop/c3_contract.py:118-121`（`sha256_of_file()` = 単一実装）/ 受理側 `scripts/ai-loop/c3prime_verify.py:124-128`（現 `plan.md` と突合・不一致は stale で fail）/ exec 入口 `bin/plangate:2078-2106`（legacy 経路の plan_hash 突合）/ 補助防衛 `scripts/hooks/check-plan-hash.sh:325-372`（recorded vs current・STRICT で exit 1）/ 契約 `docs/workflows/ai-loop/c3-prime-contract.md:45` |
| 2 | Plan Package 全体の hash 固定 | **既存で満たす** | `scripts/ai-loop/c3_contract.py:73-76`（`canonical_hash()` = `sort_keys` + 最小区切りの正規化 JSON の sha256）/ `plan_package.py:141-146`（`artifact_hashes` 6 要素 → `plan_package_hash`）/ 受理側再計算照合 `c3prime_verify.py:131-143`（`artifact_hashes` 全数 + `plan_package_hash` 再計算一致）/ 契約 §2 `c3-prime-contract.md:46-47` |
| 3 | C-1 / C-2 の Plan version 束縛 | **既存で満たす**（version 番号ではなく **hash 束縛**として成立） | marker 正規定義 `plan_package.py:67-74`（`^C1-VERDICT: <verdict> plan=sha256:<64hex>$` / プレフィックス行数一致で文法外行を fail-closed）/ `plan_package.py:100-129`（**`check_evidence()`** — issue コメントの想定名と一致。marker 内 plan hash と現 `plan.md` sha256 の照合のみで stale 判定・mtime 不使用）/ 受理側でも再実行 `c3prime_verify.py:100-102` / 契約 §1 `c3-prime-contract.md:21-32` |
| 4 | C-3' approval との束縛 | **既存で満たす** | 生成側 **`build_c3_prime()`** `plan_package.py:262-336`（presence / evidence / task_id / `source_sha == target_sha` / decision 3 値 / decision↔verdicts 整合が不成立なら record を組ませない）/ record 契約 `schemas/c3-prime.schema.json`（required 14 キー・`additionalProperties: false`）/ 受理側全数再検証 `c3prime_verify.py:69-165` / `approvals/c3.json` は legacy と同一パス・`approval_kind` で判別（契約 §2 `c3-prime-contract.md:36-41`） |
| 5 | Executor 実行直前の再検証 | **既存で満たす**（ただし「Executor が誰か」は検証対象外 → #8/#9 参照） | `bin/plangate:2047-2066`（exec 時に `git rev-parse HEAD` を解決 → 解決不能かつ c3-prime なら即 BLOCK → `_plangate_c3_dispatch "$work_dir" "$_exec_head"`）/ 共有ヘルパ `bin/plangate:885-912`（検証器不在時も `approval_kind` 有りなら NG=fail-closed）/ `c3prime_verify.py:46-166`（構造 allowlist・task_id↔task_dir 束縛・evidence 再検証・decision・source_sha・plan_hash・artifact_hashes・plan_package_hash・reviewer 三つ組・evidence_ref 独立性）/ ai-loop Delivery 側も同じ verifier を通す `scripts/ai-loop/delivery.py:498-506`（`verify_c3()`）+ `delivery.py:521-529`（`--expected-sha` を**必須化**） |
| 6 | `allowed_paths` 抽出・検証 | **既存で満たす** | 抽出の単一実装 **`extract_allowed_paths()`** `plan_package.py:170-185`（`## Files / Components to Touch` 節 + `` `path/like` `` 正規表現。0 件は例外でなく空リスト）/ Collector は再実装せず再利用 `collector.py:821-827`、0 件は `escalation_flags` へ `allowed_paths_empty` を積む `collector.py:132`・`collector.py:1057-1059`・`collector.py:1075` / LoopSpec 派生側は 0 件を fail-closed `plan_package.py:211-214` / 逸脱判定 `delivery.py:263-269`（`allowed_paths` 外の変更 → `EXEC_RETURN`）/ arbiter 側 glob 照合 `arbiter.py:362-374` |
| 7 | maker / checker 分離 | **一部満たす** | **`derive_loopspec()`** `plan_package.py:188-199`（`maker` / `checker` 必須・同一値は `PlanPackageError` = I-2）/ 契約 `c3-prime-contract.md:117` / LoopSpec 正本 `docs/workflows/ai-loop/loopspec.md:69-70,111-112,247-249`。**ただし `arbiter.py` に `actors` / `maker` / `checker` の検証は存在しない**（`grep -n "actors\|maker\|checker" scripts/ai-loop/arbiter.py` → **0 件**）。すなわち分離は LoopSpec 派生時のみ強制され、**c3-prime record にも exec 経路にも maker/checker は刻まれない**（record 必須キー 14 に actor 系フィールドなし: `c3_contract.py:44-49`） |
| 8 | Planner / Executor 分離 | **未対応**（暗黙ですらない） | exec が記録する唯一の主体情報は `bin/plangate:2037`（`agent="${PLANGATE_IMPL_AGENT:-codex}"`）→ `bin/plangate:2110-2113`（`session_started` の `detail":"agent=$agent"`）。これは**ツール種別**（`codex` / `opencode` / `cursor`）であり、session ID でも Principal でもない。`run-event.schema.json` は `additionalProperties: false` で `session_id` / `actor` 系プロパティを持たない（`schemas/run-event.schema.json:6-75`）。Plan を作った主体を記録するフィールドも record 側に無い（`c3_contract.py:44-49` の必須キー一覧に不在） |
| 9 | `ExecutionStarted` から approval への参照 | **未対応** | `session_started` イベントは `ts` / `task_id` / `phase` / `event` / `detail` のみ（`bin/plangate:2110-2113`）。`run-event.schema.json` には `plan_hash` プロパティが**存在する**が（`schemas/run-event.schema.json:56-60`、説明は「gate event 時の plan.md hash」）、exec の `session_started` 書き込みでは**使われていない**。`approval_ref` / `approval_event_id` 相当のプロパティは schema に存在しない。したがって「実行開始 → どの承認に基づくか」の因果は record から追跡できない |
| 10 | Plan revision / approval revoke | **未対応** | `plan_version` / `plan_revision` を持つ実装・schema は**存在しない**（`grep -rn "plan_version\|plan_revision" scripts/ schemas/ bin/` → **0 件**。`schema_version` は artifact schema のメタで別概念: `schemas/plan.schema.json:7,17` 等）。承認後の Plan 変更は「hash 不一致で**拒否**」されるだけで（`c3prime_verify.py:127-128`）、旧 approval を **revoke 済みとして記録する経路が無い**。`PlanApprovalRevoked` / `PlanRevisionCreated` 相当のイベントも `run-event.schema.json:31-51` の enum に不在 |
| 11 | Resume / Retry 時の再検証 | **一部満たす**（ai-loop Delivery 段のみ / exec 再開は非対応） | **満たす側**: `delivery.py:521-536` は毎回 `verify_c3(task_dir, --expected-sha)` を通してから assess するため、Delivery ループの再実行では Plan Package・approval・HEAD が再検証される。二重作用の抑止は intent / receipt の 2 段書き込み（`docs/workflows/ai-loop/delivery-state-machine.md:89`、`delivery.py:404-420`）と `executor.py:26-45` の pre-check。**未対応側**: `bin/plangate resume`（`bin/plangate:1343-1364`）は `current-state.md` を `cat` して `cmd_status` の 2 行を grep するだけで、**plan hash / approval / HEAD の再検証を一切行わない**。exec セッションの再開に契約上の再検証点が無い |
| 12 | plan version 番号 | **hash で代替済み**（新設不要 — 詳細は「Notes from Refinement / `plan_version` 要否の結論」） | #1〜#5 のとおり、実行同一性は `plan_hash`（`plan.md` 単体）と `plan_package_hash`（6 要素の正規化集合）の 2 段で既に閉じている。承認との束縛・stale 検出・受理側再検証がすべて hash を正としており（`c3prime_verify.py:124-143`）、番号は同一性判定に一切使われていない。番号を追加すると「番号は同じだが内容が違う」状態を作れてしまい**二重正本**になる |

### 12 項目の集計

| 判定 | 件数 | 項目 |
|---|---|---|
| 既存で満たす | **6** | #1 Plan 本文 hash / #2 Plan Package hash / #3 C-1・C-2 束縛 / #4 C-3' approval 束縛 / #5 実行直前再検証 / #6 `allowed_paths` |
| 一部満たす | **2** | #7 maker/checker 分離（LoopSpec 派生時のみ・record 未刻印）/ #11 Resume 再検証（Delivery のみ・exec 再開なし） |
| 未対応 | **3** | #8 Planner/Executor 分離 / #9 `ExecutionStarted` → approval 参照 / #10 revision・revoke |
| （判定枠外）hash で代替済み | **1** | #12 plan version 番号 — 新設不要と結論。未対応にはカウントしない |

> **したがって PR2 以降の追加実装対象は #7・#8・#9・#10・#11 の 5 点に限定される**（#1〜#6 は再実装しない = 二重正本の回避）。

---

## 裏取り結果 2: `ExecutionStarted` 成立条件 10 項目の充足状況

issue コメント §3.3 の 10 条件について、現行実装で「実行開始前に機械検証されているか」を実コードで確認した。

| # | 条件（issue コメント §3.3） | 充足 | 根拠と注記 |
|---|---|---|---|
| 1 | Plan Package 6 要素が存在し非空 | **部分** | 存在（`is_file`）は受理側で検証 `c3prime_verify.py:134-137`。**0 byte 非空の明示検査は生成側のみ**（`plan_package.py:50-60` `check_presence()`）。受理側で 0 byte が通らないのは「hash 一致 + 生成時に presence を通っている」ことの帰結であり、受理側単独の不変条件としては書かれていない（PR1 の ADR で「受理側 presence の意味範囲」を明記すべき点） |
| 2 | C-1 / C-2 evidence が現行 `plan.md` の hash と一致 | **充足** | `c3prime_verify.py:100-102` が受理側で `plan_package.check_evidence()` を再実行（`plan_package.py:100-129`）。marker 内 plan hash と現 `plan.md` sha256 の照合のみ・mtime 不使用 |
| 3 | c3-prime decision が `AUTO_APPROVED` | **充足** | `c3prime_verify.py:104-109`（3 値 allowlist → `AUTO_APPROVED` 以外は fail） |
| 4 | c3-prime の `plan_hash` が現行 `plan.md` と一致 | **充足** | `c3prime_verify.py:124-128` |
| 5 | `artifact_hashes` と現行 6 artifact が一致 | **充足** | `c3prime_verify.py:131-139`（キー集合一致 + 全数 sha256 照合・不一致名を明示） |
| 6 | `plan_package_hash` が再計算値と一致 | **充足** | `c3prime_verify.py:142-143`（`c3_contract.canonical_hash(ah)` と突合） |
| 7 | `source_sha` が実行時 HEAD と一致 | **充足**（exec 経路のみ） | `bin/plangate:2051-2066`（HEAD 解決 → 不能かつ c3-prime なら BLOCK → verifier へ `expected_sha` 注入）+ `c3prime_verify.py:111-121`。**静的 `validate` は `expected_sha` を渡さないため形式チェックのみ**（契約 §4 `c3-prime-contract.md:84` の明記どおり）。SHA 一致の強制点は exec |
| 8 | Executor が参照する Plan hash が approval の Plan hash と一致 | **未対応** | Executor 側に「参照した Plan」を宣言するフィールドが存在しない。同一性は「同じ `task_dir` を見ている」という**暗黙の前提**に依存する。`task_id` の task_dir 束縛（`c3prime_verify.py:82-84`）は別 TASK の record 流用は防ぐが、**Executor の参照宣言と approval の照合**は行っていない |
| 9 | Executor session が空でない | **未対応** | 記録されるのは tool 種別のみ（`bin/plangate:2037,2110-2113`）。session ID の概念・非空検証ともに不在。`run-event.schema.json` は `additionalProperties: false` のため、現状では session ID を書き込むこと自体が schema 違反になる |
| 10 | prohibited action に merge が含まれ、AI merge authority が付与されていない | **部分（実質は強い / 宣言は不在）** | **実質**: `gh_exec.py:29-46`（`gh pr merge` は allowlist の補集合として自動的に禁止・`graphql` は allowlist に載せない・`NO MERGE BY AI` 明記）+ `check_exec_boundary.py:1-55`（実行系トークンを AST で機械強制・`gh_exec.py` 以外は `subprocess` 不可）+ `executor.py:59-60`（merge / approve / close を組み立てない）。**不在**: record 側に `prohibited_actions` / `allowed_actions` の**宣言フィールドが無い**（`c3_contract.py:44-49`）。また `gh_exec.py:39-46` が自認するとおり in-process allowlist は**別プロセスからの `gh pr merge` を塞がない** |

### 10 条件の集計

| 判定 | 件数 | 条件 |
|---|---|---|
| 充足 | **6** | #2 evidence 束縛 / #3 decision / #4 plan_hash / #5 artifact_hashes / #6 plan_package_hash / #7 source_sha（exec 経路） |
| 部分 | **2** | #1 presence（0 byte 検査は生成側のみ）/ #10 merge 禁止（実装は強いが宣言フィールド不在・別プロセス経路は塞がらない） |
| 未対応 | **2** | #8 Executor の Plan 参照照合 / #9 Executor session |

> すなわち `ExecutionStarted` の 10 条件のうち **Plan 同一性に関する 6 条件は既に exec preflight で機械強制されており、不足しているのは「実行主体（#8・#9）」と「宣言の明文化（#1 の受理側 presence 範囲・#10 の prohibited action 宣言）」の 4 点**である。

---

## What（Scope）

### In scope（PR1 のみ）

issue コメント §4「PR 1: 棚卸し・ADR・契約差分」の作業項目に 1:1 対応する。

| # | 作業 | 成果物（想定） |
|---|---|---|
| S-1 | `docs/working/TASK-0981/` の標準 artifact 作成 | `plan.md` / `todo.md` / `test-cases.md` / `review-self.md` / `review-external.md` / `handoff.md`（本 `pbi-input.md` を含め Plan Package 6 要素） |
| S-2 | 現行契約・実装・テストの棚卸し（本 pbi-input の 2 表を plan で確定版に昇格） | plan 内の要件対応表 |
| S-3 | **要件対応表**の作成（#981 受け入れ条件 14 項目 × 現行実装 × PR 割当） | ADR または plan の付表 |
| S-4 | **ADR の作成**（Plan Contract の正本配置の確定） | `docs/decisions/adr-002-<slug>.md`（既存慣行 = `docs/decisions/adr-001-approve-out-of-band.md` の 1 件のみ実在。採番・slug は U-1 で確定） |
| S-5 | `c3-prime-contract.md` との関係を明記（Plan Contract = 既存契約の別名であり並行正本を作らないこと） | ADR + `c3-prime-contract.md` への追記可否の判断 |
| S-6 | `plan_version` と hash の役割を**決定**（下記「結論」を plan / ADR で確定） | ADR の決定事項 |
| S-7 | #980 との責務境界を記録（ActorSession ID は PR1 では **opaque string** の参照フィールド定義まで） | ADR の境界節 |

### Out of scope（後続スライス / 順序依存あり）

issue コメント §8「実行順の最終判断」に従い、以下の順序を厳守する。**PR1 の ADR で正本が決まるまで PR2 以降に着手しない**。

```text
#981 PR1: 棚卸し・ADR・正本整理      ← 本 PBI
  ↓
#981 PR2: Executor handoff / exec preflight 拡張（ギャップ #7・#8・#9）
  ↓
#981 PR3: revision / revoke / resume / retry（ギャップ #10・#11）
  ↓
#980 Phase 0〜2: ActorSession / Audit Event
  ↓
#981 PR4: #980 との監査統合
```

| 対象 | 理由 |
|---|---|
| PR2: exec preflight への Executor session / execution reference 検証追加、`ExecutionRequested` / `ExecutionStarted` 相当 record の追加 | PR1 の ADR で「正本を `c3-prime-contract.md` 拡張にするか sidecar にするか」が決まらないと実装先が定まらない |
| PR3: Plan revision / 旧 approval の stale 化 / resume 時の再検証 / stale reason taxonomy | PR2 の execution reference が前提 |
| PR4: #980 の Principal / ActorSession / Audit Event との統合 | #980 の実装完了が前提 |

### Non-goals

- **新規 Plan Contract 基盤の新設**（既存の Plan Package / c3-prime と並行する第 2 の正本を作らない）
- **`plan_version` を実行許可の判定に使うこと**（判定は常に hash を正とする。番号だけで実行可否を決めない）
- **#980 の Principal / ActorSession / Delegation の実装**（PR1 では参照用 ID のフィールドと境界の定義まで。主体モデルの正本は #980 に残す）
- **`check-plan-hash.sh` への責務集中**（EH-3 は補助防衛のまま。実行許可の正本は exec preflight の strict verifier = `c3prime_verify.py` / `bin/plangate` preflight）
- **AI による merge**（`NO MERGE BY AI` / Human C-4 のみが `MERGED` へ到達、は不変）
- `PR_CREATED` / `MERGE_READY` / `MERGED` の既存責務境界の変更
- 既存 Markdown artifact の即時廃止 / 破壊的 migration / 新規外部依存の追加

---

## 受入基準

> **起案である旨の明示**: issue #981 本文の「受け入れ条件」14 項目は **#981 全体（PR1〜PR4）** の AC であり、**PR1 単独の AC ではない**。以下 AC-1〜AC-3 は issue コメント §4「PR 1 / 完了条件」の 3 点を 1:1 で保持したもので、AC-4〜AC-6 は本 pbi-input が**起案**として追加した検証可能性・非退行の担保である（plan で最終確定する）。

| AC | 内容（AC-1〜3 は issue コメント PR1 完了条件 verbatim 由来） | 検証方法 |
|---|---|---|
| **AC-1** | 追加実装対象が「未対応差分」だけに限定されている | 要件対応表（S-3）で 12 項目それぞれに「既存で満たす / 一部満たす / 未対応」と根拠ファイル:行が付き、**「既存で満たす」6 項目に PR2 以降の作業が 1 件も割り当てられていない**ことを表上で確認できる |
| **AC-2** | 正本が 1 つに決まっている | ADR（S-4）に Plan Contract の正本が単一パスで明記され、`c3-prime-contract.md` / `approvals/c3.json` / LoopSpec / run record の**どこに何を置き、どこは参照に留めるか**が表で確定している。同一情報の**コピーが 2 箇所以上に存在しない**ことを ADR 内で宣言し、根拠を示す |
| **AC-3** | 新規 schema 追加の必要性が説明されている | ADR に「既存 schema（`c3-prime.schema.json` / `run-event.schema.json`）の additive 拡張で足りるか、sidecar schema が要るか」の評価が残り、**要る場合はその理由**（既存 schema の `additionalProperties: false` 制約・HO 対象パスであること等）と**要らない場合の代替**が併記されている |
| **AC-4**（起案） | `plan_version` と hash の役割が決定され、二重正本にならない根拠が記録されている | ADR に「実行同一性の正本 = `plan_hash` / `plan_package_hash`」「`plan_revision` は任意・監査表示用の連番であり実行許可判定に使わない」が明記され、**番号だけで実行許可を判定する経路が設計上存在しない**ことが確認できる |
| **AC-5**（起案） | #980 との責務境界が記録されている | ADR に「#981 が担当するもの / #980 が担当するもの」の分界表があり、**#980 未実装期間の ActorSession ID の扱い（opaque string・完全検証は #980 へ委譲）**が明記されている |
| **AC-6**（起案） | 既存挙動が不変であることが確認できる | PR1 は文書のみの変更であることを `git diff origin/main --stat` で示す。加えて回帰確認として `python3 -m pytest scripts/ai-loop/` 相当（実コマンドは plan で確定）と `bin/plangate validate` 既存ケースが PR1 前後で同一結果であることを記録 |

### #981 全体 AC 14 項目と PR1 の関係（起案・plan で確定）

| #981 全体 AC | PR1 で扱う範囲 |
|---|---|
| 1 Run に複数 ActorSession / Planner・Executor が別 Principal でも継続 | 境界定義まで（実装は PR2 + #980） |
| Plan Artifact を `plan_id` / `plan_version` / `content_digest` で一意参照 | **役割決定まで**（本 PBI の結論: `plan_id` = task_id 再利用 / 同一性は hash / 番号は任意監査用） |
| Executor が承認済み Plan の ID・version・digest を参照して実行 | 契約定義まで（実装は PR2） |
| 承認後の Plan 変更を検知 | **既に満たす**（ギャップ #1・#4。棚卸しで確認済み） |
| Plan 変更時に新 version + 再レビュー・再承認 | 契約定義まで（実装は PR3） |
| `ExecutionStarted` → `PlanApproved` の因果追跡 | 契約定義まで（実装は PR2） |
| Planner / Reviewer / Arbiter / Executor / Verifier の Session 区別 | 境界定義まで（正本は #980） |
| `allowed_paths` / `prohibited_actions` / `stop_conditions` の実行前検証 | `allowed_paths` は**既に満たす**（ギャップ #6）。`prohibited_actions` / `stop_conditions` は宣言フィールドの要否を ADR で判断 |
| Agent 切替・Resume・Retry の再検証 | 契約定義まで（実装は PR3） |
| Planner = Executor 時の Reviewer / Arbiter との職務分離 policy | 現行の maker/checker（ギャップ #7）との関係を ADR に記録。policy 実装は #980 |
| `PR_CREATED` / `MERGE_READY` / `MERGED` の責務境界不変 | **PR1 で変更しないことを宣言**（Non-goals） |
| `NO MERGE BY AI` の維持 | **PR1 で変更しないことを宣言**（Non-goals） |
| 既存 artifact・CLI・record の後方互換 | AC-6 で担保 |

---

## Notes from Refinement

### `plan_version` 要否の結論（AC-4 の起案根拠）

**結論: `plan_version` を実行許可の判定要素として新設しない。** 推奨は issue コメントの推奨判断と一致する:

```text
plan_id           = task_id（既存 run/task 識別子）を再利用する（新規採番しない）
plan_hash         = 実行同一性を保証する正本（plan.md 単体の sha256）
plan_package_hash = Plan Package 全体の同一性を保証する正本（6 要素の正規化集合）
plan_revision     = 任意・表示/監査用の連番（実行許可判定には一切使わない）
```

根拠（すべて裏取り済み）:

1. **現行 hash で目的を既に満たしている**: 「承認後の Plan 変更の検知」は `c3prime_verify.py:124-128`（plan_hash）と `c3prime_verify.py:131-143`（artifact_hashes / plan_package_hash）で成立しており、番号を追加しても検知能力は 1 ミリも増えない
2. **番号は改竄耐性がない**: 番号は「同じ番号のまま中身を変える」ことができる。hash はそれができない。番号を判定に使うと**弱い方が正本になる**
3. **二重正本の実害**: 番号と hash が食い違ったときの優先順位を定義する必要が生じ、その定義自体が新しい失敗モードになる
4. **`plan_id` の新規採番は不要**: `task_id` は既に `^TASK-[0-9]{4}$` で形式検証され（`plan_package.py:23,43-47`）、`c3prime_verify.py:82-84` で task_dir に束縛されている。別 ID を導入すると同期対象が増える

`plan_revision` を**任意で**導入する場合の条件（plan で確定）: (a) `approvals/c3.json` の必須キーにしない、(b) 受理器 `c3prime_verify.py` の判定分岐に一切使わない、(c) 人間が「これは 3 回目の計画版だ」と読むための表示専用であることを ADR に明記する。

### 正本配置の推奨（AC-2 の起案根拠）

issue コメント §3.1 の優先順位に従い、**① `c3-prime-contract.md` の拡張を第一候補**とする。

| 候補 | 評価 | 判断 |
|---|---|---|
| ① `c3-prime-contract.md` を Plan Contract の承認・実行束縛正本として拡張 | 既に Plan Package 定義・hash 契約・受理規則・trust boundary を保持しており、Plan Contract の実体そのもの。§2 の任意フィールド追加は「本ファイルの改版のみでよい」と §8 が明記（`c3-prime-contract.md:135-137`） | **推奨**。契約文書の拡張は additive で破壊的変更にならない |
| ② `approvals/c3.json` へ additive な参照追加 | **要注意**。`schemas/c3-prime.schema.json` は `additionalProperties: false`、受理器も `RECORD_ALLOWED_KEYS`（`c3_contract.py:44-49`）の allowlist で未知キーを reject（`c3prime_verify.py:73-75`）。したがって「additive」であっても **schema と受理器の同時変更が必須**であり、`schemas/*.schema.json` は **Hardening Override 対象**（AI 直接編集不可）| **条件付き**。execution 側の情報（executor session 等）は承認 record ではなく**実行 record** に属するため、そもそも c3.json に載せるべきでない可能性が高い |
| ③ sidecar `docs/working/TASK-XXXX/execution/plan-contract.json` | 実行主体・実行参照は「承認の属性」ではなく「実行の属性」であり、承認 record と生存期間が異なる（1 承認に対し複数 execution / resume がありうる）。sidecar なら approvals を不変に保てる | **execution 情報については有力**。ただし `approvals/c3.json` / LoopSpec / run record に**重複する情報をコピーせず参照で接続**すること（`plan_hash` は sidecar に**書かず**、c3.json を参照する形が望ましい）|

**推奨の骨子（ADR で確定）**: 契約の正本は ① に一本化し、execution reference の**物理的な置き場**は ③（sidecar）または `run.ndjson` の additive イベントとする。②（`approvals/c3.json` への実行情報の追加）は「承認 record は承認時点の不変スナップショット」という現行設計を壊すため**採らない方向**を第一候補とする。

### `run.ndjson` / `run-event.schema.json` を使う場合の制約（実測）

`ExecutionStarted` 相当を `run.ndjson` に載せる案は自然に見えるが、以下が判明している:

- `schemas/run-event.schema.json:75` は `additionalProperties: false`。`session_id` / `approval_ref` を書くと **schema 違反**になる
- 同 schema `:31-51` の `event` enum に `ExecutionRequested` / `ExecutionStarted` / `PlanApprovalRevoked` 等は不在（`session_started` / `exec_started` は存在）
- `plan_hash` プロパティは**既に存在する**（`:56-60`）が、exec の `session_started` 書き込みで使われていない（`bin/plangate:2110-2113`）→ **schema 変更なしで plan_hash を刻める余地がある**（PR2 の最小差分候補）
- `schemas/*.schema.json` と `bin/plangate` はいずれも **Hardening Override 対象パス**（`scripts/hooks/check-plan-hash.sh:124-134` の `_override` case 文が正本）

### Mode 判定案（plan で確定）

**PR1（本 PBI）は文書のみの変更**を想定する（ADR + working context artifact）。それでも以下の 2 つの制約が働く:

| 制約 | 適用 |
|---|---|
| **rollout-policy §2 判定基盤 carve-out** | PR2 以降で `scripts/ai-loop/**` / `docs/workflows/ai-loop/**` に触れる場合、[`rollout-policy.md`](../../workflows/ai-loop/rollout-policy.md) §2 の判定基盤 carve-out（glob: `scripts/ai-loop/**`・`docs/workflows/ai-loop/**`・`.claude/skills/ai-loop-cycle/**` 等）に該当し **escalate 固定**。**これは規範層**であり、`arbiter.py` の `boundary_check` は `ho-paths.md` の HO 表からのみ touches-HO を導出するため当該パスは **`boundary=clean` と機械判定される** → **実行者が escalate する責務を負う**（W チェック 2 体が併せて担保）。PR1 で `c3-prime-contract.md` を編集する場合も同じ扱い |
| **Hardening Override** | `schemas/*.schema.json` / `bin/plangate` / `scripts/hooks/*.sh` に触れる場合は HO 対象 → **`lite_eligible=false` 強制 + Standard・同期 C-3 固定**（[`mode-classification.md`](../../../.claude/rules/mode-classification.md) 「承認境界周辺の変更 → 最低でも高」）。AI は **patch 提示まで・適用は Human-owned**（EH-3 が maintenance 窓内でも常時 block） |

- 定量（PR1 想定）: 変更ファイル数 = ADR 1 + working context 6〜7 + `c3-prime-contract.md` 追記 0〜1 → **3〜9 ファイル** → standard〜high-risk 帯 / AC 6 個 → high-risk 帯
- 定性: 新規設計は「正本配置の確定」と「`plan_version` の役割決定」＝**承認境界に接する設計判断**
- **安全側の初期値: `high-risk`**（承認境界周辺の設計を確定する PBI であり、`doc-light` は適用しない）。`c3-prime-contract.md` に追記する場合は rollout-policy carve-out により **escalate 固定 = 同期 C-3**

---

## Estimation Evidence

### Risks

| Risk | 影響 | 一次緩和 |
|---|---|---|
| **既存契約の拡張で足りるか、sidecar が要るかの判断を先送りしたまま PR2 に進む** | PR2 で実装先が定まらず、`approvals/c3.json` と sidecar の両方に情報が散る = 二重正本の実害化 | AC-2 を PR1 の**ブロッキング完了条件**とし、ADR で正本が単一に決まるまで PR2 を開始しない（issue コメント §8 の順序制約を plan の依存関係に明記） |
| **`plan_revision` を「せっかくだから」実行許可判定に混ぜてしまう** | 番号と hash の二重正本 → 番号を偽って承認済み Plan を騙る経路が生まれる（hash より弱い方が正本になる） | AC-4 で「番号を判定分岐に使わない」を明文の受入基準にし、PR2 のテストで「`plan_revision` を書き換えても判定結果が変わらない」ことを回帰検査に入れる（test-cases で確定） |
| **#980 未実装期間の ActorSession ID の扱いが曖昧** | opaque string を「検証済み主体」と誤読し、実質の職務分離が担保されていないのに担保されたと report する | ADR に「PR1〜PR3 の ActorSession ID は**非検証の opaque string**であり、主体の真正性は #980 まで保証されない」を明記。`ExecutionStarted` 相当 record の説明文にも同旨を残す |
| `schemas/*.schema.json` / `bin/plangate` が **HO 対象**のため PR2 以降で AI が直接変更できない | 実装が Human 適用待ちで停滞し、PR2 が「patch 提示のみ」で終わる | PR1 の ADR 段階で **HO 接触の有無を設計選択の評価軸に含める**（sidecar なら HO を回避できる可能性がある点を明示比較）。HO 接触が不可避なら適用順序と Human タスクを PR1 の handoff に BLOCKED として先出しする |
| **`check-plan-hash.sh` に責務を寄せたくなる**（EH-3 は既に plan_hash を見ているため「ついでに」の誘因がある） | hook は PreToolUse の補助防衛であり、環境変数（`PLANGATE_BYPASS_HOOK` / `PLANGATE_HOOK_STRICT`）で挙動が変わる（`check-plan-hash.sh:42-47`）。実行許可の正本を置くと**バイパス可能な承認**になる | Non-goals に明記済み。ADR で「実行許可の正本 = exec preflight strict verifier / EH-3 = 補助防衛」を層として固定し、PR2/PR3 の変更対象から `scripts/hooks/` を外す |
| ギャップ表の行番号が PR 進行中に stale 化する | 「対象 / 対象外」の判定が反転し、PR2 で誤った箇所を触る | 行番号だけでなく**関数名・記号アンカー**を併記済み（`check_evidence()` / `build_c3_prime()` / `extract_allowed_paths()` / `_plangate_c3_dispatch` 等）。plan では exec 直前に現 main 基点で再走査する |
| Plan Contract という**新語**の導入自体が並行正本の印象を生む | 後続の実装者が「Plan Contract という新ファイルを作るのだ」と誤読する | ADR の冒頭に「**Plan Contract は既存の Plan Package + c3-prime 契約の別名であり、新しい artifact ではない**」を最初の 1 文として置くことを plan の完了条件に含める |

### Unknowns

- **U-1**: **ADR の配置と採番**。実測: ADR の既存慣行は `docs/decisions/` 配下で、現存は **`docs/decisions/adr-001-approve-out-of-band.md` の 1 件のみ**（`docs/adr/` は存在しない。`docs/rfc/` は RFC で別系統）。よって本 PBI の ADR は `docs/decisions/adr-002-<slug>.md` が第一候補だが、**slug と、RFC（`docs/rfc/`）ではなく ADR とすることの妥当性**を plan で確定する
- **U-2**: **execution reference の物理的な置き場**。sidecar（`docs/working/TASK-XXXX/execution/plan-contract.json`）/ `run.ndjson` の additive イベント / 両者の併用のいずれか。判断軸は (a) HO 接触の有無、(b) 承認 record の不変性を壊さないか、(c) 1 承認 : N 実行の関係を表現できるか
- **U-3**: **`prohibited_actions` / `stop_conditions` を宣言フィールドとして持つべきか**。現行は `gh_exec.py` の allowlist 補集合 + `check_exec_boundary.py` の AST 検査で**実質的に**強制されており（裏取り 2 の #10）、宣言を足すと「宣言と実装のどちらが正か」が新たな論点になる。**宣言なし（実装が正）** / **宣言あり（実装と CI で突合）** のどちらを採るか
- **U-4**: **`ExecutionRequested` と `ExecutionStarted` を分けるか**。issue は分離を要求するが（requester / decision maker の分離は #980 の責務）、PR2 段階で 2 イベントに分けるか 1 イベント + フィールドで表すか
- **U-5**: **`plangate resume` の扱い**（ギャップ #11）。現行は表示専用（`bin/plangate:1343-1364`）。再検証を足すと `bin/plangate` = **HO 対象**への変更になるため、(a) `resume` を拡張する / (b) 再検証は `exec` 側に閉じて `resume` は現状維持 + 文書で「resume 後は exec を再実行する」と規定する、のどちらを採るか
- **U-6**: **受理側 presence の意味範囲**（裏取り 2 の #1）。0 byte 非空検査を受理側にも足すか、「生成側で保証済み + hash 一致で十分」と ADR で明記して現状維持にするか
- **U-7**: **`derive_loopspec()` の maker/checker を record に刻むか**（ギャップ #7）。刻むと `c3-prime.schema.json`（HO 対象・`additionalProperties: false`）の変更が必要。`derived_loopspec_hash` という任意フィールドが既にある（`c3-prime-contract.md:54`）ため、LoopSpec 側に閉じる案も成立しうる

### Assumptions

- issue コメント（2026-08-04・s977043）が **Human 確定の実行方針**であり、issue 本文の「実装フェーズ Phase 0〜4」よりコメントの「PR1〜PR4」が優先されること（コメント冒頭「本 Issue は新しい Plan Contract 基盤をゼロから作らないでください」を最上位の制約として扱う）
- 上記 2 表の実測が現 main（`a667c0d`）で有効であること（exec 時に再走査して確定する）
- PR1 はコードを 1 行も変更しない（文書のみ）。したがって既存テスト・CLI・record の後方互換は自明に維持される（AC-6 は形式的確認）
- #980 は本 PBI 期間中に実装されない前提（ActorSession ID は opaque string として扱う）
- `NO MERGE BY AI` / Human C-4 のみが `MERGED` へ到達、は本 PBI のいかなる成果物によっても変更されない
- Plan Package 6 要素の定義（`c3_contract.py:26-33`）は本 PBI で変更しない（`plan-contract.json` 等の sidecar を足しても 6 要素の集合は不変）
