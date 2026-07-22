# EXECUTION PLAN — TASK-0873

> Issue: [#873](https://github.com/s977043/plangate/issues/873)（P0 / enhancement / area:workflow）
> Parent EPIC: [#870](https://github.com/s977043/plangate/issues/870)
> 入力: [`pbi-input.md`](./pbi-input.md)（2026-07-20 作成・調査裏取り済み）
> 作成: 2026-07-22（B-1 確認 2 問 → 事前メトリクス検証 → B-2 比較 → B-3 生成）

## 確認事項（B-1 / Human 回答済み 2026-07-22）

| # | 質問 | Human 回答 |
|---|------|-----------|
| Q1 | 新状態語彙（`WAITING_FOR_CHECKS`/`WAITING_FOR_REVIEW`/`CHECKS_FAILED`）の導入粒度（pbi-input Unknown 2） | **サブステート導入**: 既存 3 状態（`PR_CREATED`/`MERGE_READY`/`MERGED`・00_concept §2.2）は不変。新語彙は `PR_CREATED`→`MERGE_READY` 間の内部サブステートとして新正本 doc に定義し、Scheduling 判断表（execution-runbook §2-(7)）と正規化マッピング表で接続 |
| Q2 | #896（検証ロジック共通契約層化）との順序 | **並行**: delivery.py は現行 main の `c3prime_verify.py` を import 再利用。#896 merge 後の `c3_contract` 置換は #896 側 rebase で吸収（触るファイル重複は c3prime_verify.py のみ・両立可） |

## Goal

`ai-loop run` の C-3'（c3-prime）AUTO_APPROVED 後、`PR_CREATED → CI/レビュー対応反復 → MERGE_READY` を**決定論・fail-closed・冪等**の状態機械 `scripts/ai-loop/delivery.py` として実装し、AC-1〜12 + 必須 fixture 10 件を CI で機械検証可能にする。`MERGED` への遷移経路を持たない（NO MERGE BY AI）。

## Constraints / Non-goals

- **NO MERGE BY AI（Iron Law）**: 遷移表に `MERGED` を持たせない。merge API シンボル（`gh pr merge` / `merge_pull_request`）の不在をソース走査テストで固定
- **既存正本の不変**: 00_concept §2.2 の Delivery 3 状態・§2.3 語彙群区別・Scheduling 判断表（execution-runbook §2-(7)）は改版しない（サブステートは additive）
- **HO 非接触**: touch は `scripts/ai-loop/**`・`tests/extras/**`・`docs/workflows/ai-loop/**`・`scripts/sync-plugin-plangate.sh` のみ（全て非 HO）。`bin/plangate` / `schemas/` / `.github/workflows/` は触らない（extras は設置のみで CI 自動 source — 実測済み）
- **c3-prime trust boundary（契約 §7）**: `decision` を無検証で信頼せず `c3prime_verify.py` を import 再利用して再検証（再実装しない）
- **純判定器契約（Refs: R-007）**: delivery.py はネットワーク・外部プロセス実行を一切持たない（`subprocess` / `os.system` / `urllib` / `socket` / `http` / gh 呼び出しの import・シンボル不在をソース走査テストで固定）。merge 経路の literal 走査（`gh pr merge` / `merge_pull_request`）はその上の二重ガード
- Non-goals: C-4/merge 自動化・Evolution Loop 接続（#874/#869）・ai-dev plan/exec/verify の再実装・実 GitHub API を叩く自動反復ループ常駐（V1 は snapshot 入力の判定エンジン — 下記 Approach）

## アプローチ比較（B-2）

### 論点 A: delivery.py の実行モデル

| 案 | 内容 | 長所 | 短所 |
|----|------|------|------|
| **A-1（採用）** | **snapshot 入力の判定エンジン**: PR 状態（checks/reviews/mergeable/head SHA/changed files）を JSON snapshot として受け取り、`(現在 record, snapshot) → (次サブステート, 要求アクション列, record 更新)` を決定論的に返す。repair の実行（修正 commit・push・コメント）は呼び出し側（runbook 手順 / 将来の実行層）の責務 | arbiter/plan_package と同型（決定論・stdin/引数入力・fixture 駆動）。10 fixture が実 GitHub なしで CI 実走可能。冪等性を record の実行済みアクションキーで機械担保 | 「反復ループの実行」自体は runbook 手順に残る（判定と記録が機械化・実行は V2） |
| A-2 | gh API を直接叩く常駐ループ（poll → 判定 → repair 実行） | 一気通貫の自動化 | 非決定論（API 応答・時間依存）で 10 fixture の CI 実走が困難。permission/レート・環境依存が fail-closed 設計と衝突。Phase 1（隔離 PoC）の範囲超過 |

A-1 でも AC-4（修正・push・再評価へ**遷移できる**）は「要求アクション列 + 再評価入力の受理 + round 記録」で充足する（遷移の機械化が AC。実行主体は問わない — issue DoD は sandbox 実走で検証）。

### 論点 B: 状態機械契約（AC-1）の機械可読形

| 案 | 内容 | 長所 | 短所 |
|----|------|------|------|
| **B-1（採用・C-3 論点）** | 遷移表を delivery.py 内 `TRANSITIONS` 定数で単一定義し、`delivery.py contract` サブコマンドで JSON emit。正本 doc の遷移表と emit の**整合をテストで機械検証**（doc 表 drift を CI 検出） | 単一 source（drift 構造排除）。HO 非接触。bundled 自立（ta-30 系）で外部ファイル依存なし | 「schema ファイル」としては存在しない（emit が契約） |
| B-2 | `docs/schemas/delivery-state-machine.json` を正とし delivery.py が読み込む | schema ファイルの実在 | 二重管理（code↔JSON）または実行時ファイル依存（bundled 自立・sync 列挙が増える）。stdlib に YAML なし |
| B-3 | `schemas/*.schema.json` に配置 | 既存 schema-validate に乗る | **HO**（Human 適用待ちの窓で fail-closed 化が必要 = #872 PR-2 と同じ 2 段構成になり P0 が重くなる） |

### 論点 C: サブステート集合（Q1 回答の具体化・C-3 論点）

`PR_CREATED` → { `WAITING_FOR_CHECKS` / `WAITING_FOR_REVIEW` / `CHECKS_FAILED` / `REVIEW_REPAIR` / `CONFLICT` } → `MERGE_READY`（+ 逸脱系 exit `HUMAN_ESCALATED` / `EXEC_RETURN`）。Scheduling 判断表（優先度 1〜8）**全 8 行**の正規化マッピングを正本 doc に固定（Refs: R-002/R-003）:

| 優先度 | 次サブステート / exit |
|--------|---------------------|
| 1（HO/policy/irreversible）・2（round 上限超過） | `HUMAN_ESCALATED` |
| 3（同型指摘の再発） | `REVIEW_REPAIR` に復帰 + record に `feedback_loop_referral` アクション（review-feedback-loop.md への還元要求）を刻む。recurse は独立 state にしない |
| 4（CI failed） | `CHECKS_FAILED` |
| 5（merge conflict） | `CONFLICT` |
| 6（critical/major review 指摘） | `REVIEW_REPAIR` |
| CI pending / required review pending | `WAITING_FOR_CHECKS` / `WAITING_FOR_REVIEW` |
| 7（minor/info のみ） | **`MERGE_READY` candidate（非終端）** — 記録アクション + DoD 再評価へ進む。7 から直接 `MERGE_READY` に短絡しない |
| 8（CI green + review 全件対応済み = DoD 充足） | `MERGE_READY`（唯一の到達経路） |

`EXEC_RETURN`（Plan 逸脱の exec 差し戻し・AC-6）と `HUMAN_ESCALATED` は「run をどこへ返すか」の別 exit として区別する。**`HUMAN_ESCALATED` は裁定語彙（decision-table 3 値）の借用であり Delivery terminal（00_concept §2.2 の 3 状態）ではない** — 正本 doc に §2.3 整合注記を必須で置く（Refs: R-010）。

## Approach Overview

1. **正本 doc 新設** `docs/workflows/ai-loop/delivery-state-machine.md`: サブステート定義・Scheduling 判断表との正規化マッピング・MERGE_READY record 契約・冪等キー規約。00_concept / execution-runbook / c3-prime-contract §7 からは additive リンクのみ
2. **`scripts/ai-loop/delivery.py` 新設**（arbiter/plan_package 同型: 決定論・fail-closed・冪等・timestamp 注入・stdlib のみ）:
   - 入口で c3-prime record を `c3prime_verify.py` import で再検証（`main(argv)→int` を呼ぶ。decision != AUTO_APPROVED / 検証 FAIL → BLOCK。**exit 10 = legacy c3.json も BLOCK**（ai-loop Delivery は c3-prime 必須 / Refs: R-009）。失敗理由は `contextlib.redirect_stderr` で捕捉し record に残す）
   - **snapshot 信頼境界（Phase 1 / Refs: R-006）**: snapshot は信頼済みローカル呼び出し側（runbook 手順実行者）が供給する前提を正本 doc に明文化（c3-prime-contract §4 の脅威モデル境界と同型）。独立検証不能な値（未知 taxonomy・ancestry 根拠欠落・checks と head の不整合）は**常に fail-closed で escalate**。raw check evidence への束縛は V2（C-3 論点 7）
   - `assess`: snapshot JSON + 現 record → 次サブステート + 要求アクション列 + record 追記（append 型・重複抑止は下記「冪等設計」の stable action ID + intent/receipt による）
   - head SHA 束縛: checks/reviews が snapshot head と不一致 → stale として MERGE_READY 拒否（AC-2/AC-3）。head が `source_sha` の子孫でない → fail-closed（契約 §7。ancestry は snapshot 供給 + sandbox では git 実測）
   - CI failure taxonomy（code/flaky/environment/permission/unknown）: snapshot の分類入力を検証して遷移。permission/unknown → `HUMAN_ESCALATED`（AC-9・成功扱いにしない）
   - review disposition: 全 finding が `adopted(repair_commit)` か `rejected(evidence_ref)` になるまで MERGE_READY 不可（AC-5）
   - Plan 逸脱（changed_files ⊄ plan の Files to Touch）→ `EXEC_RETURN` or C-3' 再裁定要求（AC-6）
   - conflict: base/head/result 三点照合フィールド必須 + 解消後 CI/review 再評価を強制（AC-7）
   - round 上限 3（round 4 遷移なし → `HUMAN_ESCALATED`・AC-8）
   - record 永続の出力先 = `docs/working/TASK-XXXX/delivery/record.jsonl`（append 型。evidence として repo 保管 — ai-loop-runs の run record とは別系で、相互参照 ID のみ持つ。**delivery.py が自己 append するのは既存 ai-loop scripts の stdout-emit 同型からの意図的逸脱**: 冪等判定が既存 record 読取を要するため。decision-log.jsonl の append-only 前例と整合 / Refs: R-013。**record に raw log 本文は含めない — evidence_ref 参照のみ**。`.jsonl` は EH-8 走査対象外のため契約側で禁止する / Refs: R-014）
   - **冪等設計（Refs: R-005）**: 要求アクションの同一性は **stable action ID = canonical action payload（PR 番号・head SHA・round・action_kind・finding_id 等を含む正規化 JSON）の sha256** で判定（`head_sha+round+action_kind` の 3 要素キーでは同種複数アクションを誤抑止するため不採用）。record は **intent（要求記録）と receipt（外部作用の完了記録）を分離**した 2 段書き込みとし、resume 時は「intent あり・receipt なし」を未完了として再要求可能・「receipt あり」を実行済みとして抑止（外部作用前後どちらの中断でも一度だけ実行に収束）
   - `MERGE_READY` record: PR 番号 / head SHA / check summary / review disposition / round / plan hash（AC-11）
   - `contract` サブコマンド: TRANSITIONS を JSON emit（AC-1）
3. **テスト**: `test_delivery.py`（unit・手 mutate の偽造/欠落系含む）+ `tests/extras/ta-56-delivery.sh`（ta-55 様式 sandbox で必須 fixture 10 件 + unittest 本体実行 + 禁止 import/merge シンボル走査 + doc↔contract 整合）。**doc↔contract 整合テストは ta-56 側のみに置く**（test_delivery.py に置くと bundled 自立で doc 相対パスが破綻 / Refs: R-012）。**ta-56 sandbox には最小アクション実行スタブ**（delivery.py の要求アクションを読んで sandbox 内 git commit 生成 + snapshot 更新 + 再投入を行うシェル関数）を含め、`CHECKS_FAILED → repair → 再評価 → MERGE_READY` の反復を実走で証明する（record 手渡しのみにしない / Refs: R-004。実 PR/gh を叩く consumer は V2 = C-3 論点 6）
4. **sync 列挙**: `sync-plugin-plangate.sh` の copy/delete 保護 2 箇所へ delivery.py / test_delivery.py 追加（R-008 教訓）

## Work Breakdown (Steps)

1. Step 1: 正本 doc（delivery-state-machine.md）でサブステート・マッピング・record 契約を固定
   - Output: `docs/workflows/ai-loop/delivery-state-machine.md`（遷移表 = contract emit と同一内容）
   - Owner: agent / Risk: 中
   - 🚩 チェックポイント: 既存正本（00_concept §2.2/§2.3・Scheduling 判断表）と矛盾ゼロ・additive のみ
2. Step 2: TDD — test_delivery.py の RED（fixture 10 対応 unit + 偽造/欠落 edge）
   - Output: `scripts/ai-loop/test_delivery.py`（producer 非依存の手 mutate 系を含む）
   - Owner: agent / Risk: 中
   - 🚩 チェックポイント: 必須 fixture 10 件が TC にすべて対応（test-cases.md マッピング）
3. Step 3: delivery.py 実装（GREEN）— 契約 emit → 判定エンジン → record 永続の順
   - Output: `scripts/ai-loop/delivery.py`
   - Owner: agent / Risk: 高（承認境界の消費側・fail-closed 設計）
   - 🚩 チェックポイント: c3prime_verify import 再検証が通ること（再実装ゼロ）/ `MERGED` 遷移・merge シンボル不在
4. Step 4: ta-56 E2E（sandbox 実走: PR_CREATED → CI fail/repair → MERGE_READY + resume 冪等 2 回実行）
   - Output: `tests/extras/ta-56-delivery.sh`（HO 未適用環境は既存様式どおり graceful）
   - Owner: agent / Risk: 中
   - 🚩 チェックポイント: `sh tests/run-tests.sh` クリーン 1 回実行 exit 0（既知の TC-05 偽陽性パターンに注意）
5. Step 5: sync 列挙 + plugin 再生成 + drift 0 確認
   - Output: `scripts/sync-plugin-plangate.sh` 差分 + plugin 側再生成物
   - Owner: agent / Risk: 低
   - 🚩 チェックポイント: sync 2 回目 no-op / `git diff --quiet plugin/`
6. Step 6: 敵対レビュー（複数エージェント・2 ラウンド以上）+ disposition 記録
   - Output: evidence/（レビュー記録・是正 commit）
   - Owner: agent / Risk: 中
   - 🚩 チェックポイント: **承認境界の消費側は 1 ラウンドでは表層しか出ない**（#889 教訓）— critical/major ゼロ収束まで
7. Step 7: 👤 C-3（本 plan 承認・critical 詳細レビュー）/ 👤 C-4（PR レビュー）
   - Output: `approvals/c3.json`（Human 発行）
   - Owner: human / Risk: —
   - 🚩 チェックポイント: C-3 論点 5 件（下記 Questions）の明示判断

## Files / Components to Touch

| # | ファイル | 種別 |
|---|---------|------|
| 1 | `scripts/ai-loop/delivery.py` | 新設 |
| 2 | `scripts/ai-loop/test_delivery.py` | 新設 |
| 3 | `tests/extras/ta-56-delivery.sh` | 新設 |
| 4 | `docs/workflows/ai-loop/delivery-state-machine.md` | 新設（正本） |
| 5 | `docs/workflows/ai-loop/c3-prime-contract.md` | additive（§7 に正本リンク 1 行） |
| 6 | `scripts/sync-plugin-plangate.sh` | 列挙 +2 |
| 7-8 | `plugin/plangate/`（delivery.py / test_delivery.py） | sync 自動再生成 |
| 9 | `plugin/plangate/skills/ai-loop-cycle/references/delivery-state-machine.md` | sync 自動再生成（workflows/ai-loop glob / Refs: R-012） |

## Metrics Evidence（事前メトリクス検証 / mandatory gate）

| 対象 | 実数（実測） | AI 見積もり | ratio | 判定 |
|------|-------------|------------|-------|------|
| 必須 fixture 数 | 10（issue verbatim・固定） | 10 | 1.0 | 採用 |
| touch ファイル数 | 8（上表列挙。extras は設置のみで CI 自動 source・`grep -n extras tests/run-tests.sh` 実測 / sync 列挙 L306-318 実測） | 8 | 1.0 | 採用 |
| 参照実装規模 | ta-55=109 行・test_c3prime_verify=194 行・test_plan_package=437 行（`wc -l` 実測） | 同規模±2 倍 | — | 採用（Risks に記録） |

## Testing Strategy

- Unit: `test_delivery.py` — 遷移全パス・fixture 10 対応・偽造 record/欠落キー/stale head の手 mutate 系・冪等（同 snapshot 2 回 → アクション重複ゼロ）
- Integration: c3prime_verify import 再検証経路（AUTO_APPROVED 以外・検証 FAIL・record 欠落 → BLOCK）
- E2E: `ta-56-delivery.sh` — sandbox で PR_CREATED → CHECKS_FAILED → repair → MERGE_READY 実走 + resume 2 回冪等 + merge シンボルソース走査 + contract↔doc 整合
- Edge cases: round=3 境界（3 は継続・4 で HUMAN_ESCALATED）/ 旧 head SHA の green checks / disposition 未解決 1 件残し / 空 snapshot / 非 git 環境
- Verification Automation: `python3 scripts/ai-loop/test_delivery.py && sh tests/run-tests.sh`

## Loop Scope

単一 PBI（TASK-0873）の exec 内における「テスト失敗 → 自己修正」の反復のみを対象とする（delivery.py が扱う run 反復はプロダクト仕様であり本 plan の Loop ではない）。

## Stop Condition

変更が Files to Touch 内 / Verification Automation 成功（run-tests クリーン exit 0）/ fixture 10 全対応 / 敵対レビュー critical・major ゼロ収束 / 残課題は handoff に明示。

## Resume Condition

stop 後の再開は、原因・修正方針・検証手順を本 plan に追記し Replan 判定を通す。

## Replan Triggers

- 変更ファイル数 > 13（= 想定 8 + 5）
- 同一検証コマンドの連続失敗 3 回
- 同一ファイルへの修正反復 3 回
- plan 外ディレクトリへの波及 1 件（特に `bin/plangate` / `schemas/` / `.github/workflows/` への必要性が判明した時点で即停止）
- AC / Verification コマンドの変更検知時
- #896 が先に merge され import 前提が変わった場合（c3_contract 置換の要否を Replan で判断）

## Revert Policy

停止時、Scope 外へ波及した変更のみ対象パス限定で `git restore -- <path>`。ブランケットな `git stash` は使わない。

Loop Attempts:（exec 中に追記）

- attempt: / changed: / verification: / result: / next decision:

## Risks & Mitigations

| リスク | 検証手段 | Fallback |
|--------|---------|----------|
| サブステートが既存正本（3 状態・判断表）と二重管理化 | 正規化マッピング表を正本 doc に固定 + contract emit↔doc 整合テスト | 新語彙を doc 記載のみに縮小し、code は判断表優先度で駆動 |
| resume 冪等の greenfield 設計が漏れる | fixture 10（中断→resume）+ 同 snapshot 2 回実行テスト | 冪等キー（head SHA + round + action_kind）による実行済み抑止へ最小化（V2 送りしない — AC-10 は V1 必須） |
| c3-prime 再検証の誤実装 | c3prime_verify.py import 再利用（再実装しない）+ 統合テスト | §4 全規則の再実装 + 敵対レビュー |
| snapshot 入力の偽造（taxonomy 偽装で escalate 回避等） | 手 mutate の偽造系テスト + 分類不能値は unknown → HUMAN_ESCALATED（fail-closed） | 分類の根拠フィールド必須化 |
| 実装規模が参照実装の 2 倍超過 | Metrics Evidence の参照規模と exec 中の実測比較 | Replan Trigger 発動（ファイル数/反復） |
| #896 並行の rebase 衝突 | 実重複 = `sync-plugin-plangate.sh` の列挙 2 箇所（copy for リスト / delete 保護 case — 機械的 conflict・解消容易）。c3prime_verify.py は #873 が読取のみで非改変（Refs: R-011） | 後着側が列挙 2 箇所を rebase 解消。c3_contract merge 後は import 先のみ差し替え |

## Questions / Unknowns（→ C-3 論点・8 件 / Refs: R-008）

1. 契約の機械可読形 = **B-1 案（code 単一定義 + contract emit + doc 整合テスト）** の採否（B-2 の docs/schemas JSON 配置を選ぶ場合は sync/bundled 設計が変わる）
2. サブステート集合（論点 C の 5 中間 + candidate + 2 exit）と **優先度 3（recurse）= REVIEW_REPAIR 復帰 + feedback_loop_referral アクション** / **優先度 7 = candidate 非終端・8 のみ MERGE_READY** の正規化表の最終確定（Refs: R-002/R-003）
3. #896 並行の正式承認（B-1 Q2 で並行回答済み — c3.json で確定）
4. delivery.py の副作用境界 = **判定エンジン（A-1）**の採否（repair 実行の機械化は V2）
5. CI failure taxonomy の分類根拠を snapshot 供給とすること（gh API 実叩きは V2）の採否
6. **V1 の repair 実行範囲**（Refs: R-004）: ta-56 sandbox の最小アクション実行スタブまでを V1 とし、実 PR/gh に対する action consumer を V2 とするスコープ裁定
7. **snapshot 信頼境界**（Refs: R-006）: Phase 1 = 信頼済みローカル供給宣言 + fail-closed escalate で足りるか、raw check evidence 束縛（V2 候補）を前倒しするか
8. **resume 原子性**（Refs: R-005）: stable action ID + intent/receipt 2 段書き込み設計の採否

## Mode判定

**モード**: critical

**判定根拠**:

- 受入基準数: 12 → **超高（11+ で決定論）** ← pbi-input の「high-risk 見込み」は hedge であり定量基準を優先（#874/#894 と同じ機械判定）
- 変更ファイル数: 8 → 高（6-15）
- タスク数（見込み）: 21+（todo.md 実数 22） → 超高
- 変更種別: 状態機械新設 + 承認境界（c3-prime）消費側 → 高〜超高
- **最終判定**: critical（定量・定性の最大値）。V-4 実行対象・人間 C-3 詳細レビュー必須

**lite_eligible**: false（critical は原則 false — AC-11。autonomous APPROVE 不可、Human C-3 必須）
