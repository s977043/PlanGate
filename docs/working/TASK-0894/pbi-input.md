# PBI INPUT PACKAGE — TASK-0894

> Issue: [#894](https://github.com/s977043/plangate/issues/894)（P1 / enhancement / area:workflow / governance / area:eval / area:metrics）
> Parent EPIC: [#870](https://github.com/s977043/plangate/issues/870)
> 作成: 2026-07-22（調査・worktree 現物裏取り済み。AC / Scope / fixture / DoD は issue verbatim）
> **鮮度是正: 2026-08-04（main `7bf5f5c` 基点・#873/#905・#917/#941 実装後）** — 作成時点で未実装だった #873（`delivery.py`・PR #905・2026-07-23 マージ）と #917（Collector / Executor / Reconciler・PR #941・2026-07-31 マージ）が main へ入ったため、実測・AC 対応・C-3 論点・Risks を実装後の実体へ是正。**実装・実走済みの `delivery.py` 語彙（state / terminal decision / priority / action ID / intent・receipt / round limit）は本 PBI で再定義しない**（契約はそれらを正として参照する。詳細は「実装済み ↔ 本 PBI 新規追加の分離」節）

## Context / Why

参照投稿（issue 記載の一次ソース）は、AI 活用の中心が単発 Prompt から
`Discover → Plan → Execute → Verify → Iterate` を外部状態・客観的検証・停止条件で制御する
Loop へ移ると整理している。PlanGate ai-loop vNext には #872（Plan-first / C-3' binding）・
issue #873（PR convergence / `MERGE_READY` 状態機械）・#874（RunEvidence）・#869（Evolution Loop）が
並ぶが、これらを横断する **共通の Loop 制御契約（Verifier 階層・停止予算・進捗判定・採用コスト
metrics）** はまだ定義されていない。各 Workflow が個別に停止条件・成功判定を持つと、同じ Run 内で
語彙・境界・fail-closed 方針がずれる。本 PBI は共通 `LoopControlContract` を定義する。

実測（2026-07-22 初回 → **2026-08-04 再実測・main `7bf5f5c`**。#873/#905・#917/#941 実装後の現物）:

- **Verifier 実体は 6 層に分散実装済みだが、層間順序と結果語彙の共通契約が無い**（#905/#941 で 6 層目が追加。共通契約の不在は不変。**issue の Verifier 階層 5 層〔deterministic / specification / independent model reviewer / policy gate / loop decision〕とは別軸** — issue 側は契約が定めるべき論理階層、本項は現行コードの実装分布）:
  1. LoopSpec 決定論検証（`docs/workflows/ai-loop/loopspec.md` 必須フィールド + I-4 安全側差し戻し）
  2. Plan Package + C-1/breakdown マーカー（`arbiter.py` priority 1.6/1.65/1.7 の `gates.c1 == "PASS"` / `plan_package` 整合）
  3. W チェック + rubric（LLM 判断 Model A/B/C/D。`arbiter.py` L16 が「L2 は決定論のみ・LLM 判断は W チェック」と分離を明記）
  4. arbiter 決定論裁定（`decision-table.md` priority 0〜6 + 1.5/1.6/1.65/1.7/1.9/1.95 の機械実装）
  5. terminal 3 値（`AUTO_APPROVED` / `HUMAN_ESCALATED` / `BLOCKED`・exit 0/2/3）+ `MERGE_READY`（DoD 状態・`00_concept.md` §2.3 で語彙区別済み）
  6. **PR 収束段の決定論状態機械 + 実 PR 供給/実行/突合（#905・#941 で追加実装・実走済み）**: `delivery.py` `assess()` 純関数＝state 7 種 + exits 2 種（`STATES`/`EXITS` L36-46）・`PRIORITY_ORDER` 15 段（L48-64）・terminal `MERGE_READY`（遷移なし L74・NO MERGE BY AI）、および `collector.py`（snapshot 供給・head SHA 束縛）/ `executor.py`（唯一の外部書き込み層）/ `reconciler.py`（intent↔receipt 突合）+ `check_exec_boundary.py`（AST 機械強制）+ `gh_exec.py`（gh/git allowlist）
- **issue が要求する 4 値 verifier status（`pass|fail|unavailable|inconclusive`）の schema は依然不存在**:
  `inconclusive` は `scripts/ai-loop/` および `docs/workflows/ai-loop/` で **0 件**（2026-08-04 再実測）。
  `unavailable` は #941 で **escalation flag 理由コードとして部分実装**された（`collector.py` L125
  `changed_files_unavailable` / L131 `findings_unavailable`・いずれも fail-closed で AC-4 の方向と整合）が、
  **verifier 単位の 4 値 status enum・schema としては未定義のまま**（2026-07-22 時点の「0 件」はこの限りで stale）
- **停止予算は round 系のみ（不変）だが、enforcement 実装は 2 箇所に増えた**:
  (1) `cost_cap` は run 予算＝**round 数単位**（`arbiter.py` L697-707 検証 / L992-1009 priority 1.95 判定・
  シンボル `_cost_cap_reason`・#840。2026-07-22 時点の L713〜/L1008〜 から行番号ドリフト）
  (2) **`delivery.py` `ROUND_LIMIT = 3`（L77・#905 で追加）**＝repair round 上限の機械 enforcement
  （`PRIORITY_ORDER` の `round_limit`・超過は `HUMAN_ESCALATED`。数値 3 は runbook §2-(7) 正本の参照実装）。
  time / token / cost_usd / 連続失敗上限は**依然不存在**。`loopspec.md` **L125** が「cost cap フィールドは
  設けない — enforcement 不在の宣言フィールドを作らない（#749 で enforcement 設計と同時に検討する）」
  と明記しており（現存・再確認済み）、本 PBI はこの注記を解除する enforcement 側の位置づけ
- **no-progress detector は明示された follow-up（不変）だが、入力源と近縁機構が #905/#941 で先行整備済み**:
  `loopspec.md` **L281** の「独立した detector 化は follow-up 候補（効果測定後に判断）」は現存。
  `fingerprint` / `oscillation` の語は `scripts/ai-loop/` および `docs/workflows/ai-loop/` で依然 **0 件**
  （2026-08-04 再実測・test 除く）。ただし
  (1) **同型再発検知は `same_type_recurrence` として部分実装済み**（`delivery.py`
  `_past_repair_finding_types()` L229-231 / `assess()` L331-342・finding_type 単位の粗粒度・
  `feedback_loop_referral` action 付き。issue の正規化 fingerprint〔stage + verifier_id +
  normalized_error_code + affected_path + plan_hash〕とは粒度が異なり、置換でなく共存させる）
  (2) `collector.py` L29-30 が「`record.jsonl` に state entry が残らないと **#894 の no-progress 検知**と
  接続できない」と明記＝**#941 が #894 detector の入力源（state entry の append-only 蓄積）を先行整備済み**
- **採用コスト metrics は不存在（不変・2026-08-04 再実測）**: `scripts/ai-loop/metrics.py` はレート系のみ
  （first-pass rate＝`first_pass` 導出 / `escalate_rate` / `human_intervention_rate` 等）。
  `cost` / `token` / `human_minutes` / `accepted_change` フィールドは **0 件**
- **最重要リスク＝正本断片化（不変・機械検証の正本が 1 つ増えた）**: `loop-safety-gates.md` **§6**（L198「既存正本との不整合防止（再定義しない
  事項の一覧）」）と `stop-rollback.md` **§0**（「本書は既存正本の再定義ではない」）が、ラウンド上限 3 /
  CB-1〜3 / escalate 予算等の**数値再定義を禁止**している。既存の機械検証は
  **`delivery-state-machine.md`（#873 正本）§8 の contract emit byte 一致**（`python3 scripts/ai-loop/delivery.py contract`）
  のみで、**その検査対象は当該 doc 1 本に固定されている**（`tests/extras/ta-56-delivery.sh` L139-149:
  `_t56_doc="$PG_T56_ROOT/docs/workflows/ai-loop/delivery-state-machine.md"` の contract ブロックだけを `cmp`）。
  したがって **#894 が新設する契約 doc に state / priority を再宣言しても現行 ta-56 は PASS のまま**であり、
  再宣言を検出する guard は**現時点で存在しない**（作れるようにするのが本 PBI の作業 — Risks 表参照）。
  本契約が数値・語彙を再宣言すると正本を増やして断片化する →
  「数値は既存正本への参照固定・enum / reason code は additive 正規化層」を設計原則にする（下記 C-3 論点 1）

## What（Scope）

### In scope（issue Scope verbatim・8 項目）

1. 共通の Loop decision enum / reason code / schema を定義する
2. Verifier 実行順序と blocking 規則を定義する
3. budget / stop / no-progress / repeated-failure / oscillation 判定を共通化する
4. #872 / #873 / #874 / #869 から利用する adapter 境界を定義する
5. terminal decision と全 Verifier 結果を RunEvidence へ渡す
6. risk / task profile 別の既定 budget を定義する
7. CLI / workflow が同じ reason code を返せるようにする
8. 既存の停止条件を棚卸しし、重複・矛盾・責務漏れを整理する

### Out of scope（issue Non-goals verbatim・7 項目）

- #873 の PR 状態機械を再実装すること
- #869 の candidate 生成・実験 policy を再実装すること
- model 自身の重み更新
- hidden CoT / raw session transcript の保存
- 全タスクへ同一 budget・同一 KPI を強制すること
- AI への merge 権限付与
- Human-owned policy / C-4 / first principles の自動変更

### 再定義禁止の対象（2026-08-04 鮮度是正・Non-goals 1 項目目の具体化）

issue Non-goals「#873 の PR 状態機械を再実装すること」の具体化。以下は #905/#941 で**実装・実走済み**の語彙であり、本 PBI で**再定義しない**（契約は参照・変換表の右辺として固定するのみ）:

- `delivery.py` の **state 7 種・terminal `MERGE_READY`・exits 2 種（`EXEC_RETURN` / `HUMAN_ESCALATED`）**（`STATES`/`TERMINAL`/`EXITS`＝`delivery.py` L36-46）
- **`PRIORITY_ORDER` 15 段**（invalid_snapshot → merge_ready・`delivery.py` L48-64。`delivery-state-machine.md` §3 と同順）
- **action ID**（canonical payload の sha256＝`c3_contract.canonical_hash`・`delivery.py` `action_id()` L176-177 / `c3_contract.py` L71）と **action_kind 6 種**（`repair_ci` / `resolve_conflict` / `repair_review` / `record_disposition` / `feedback_loop_referral` / `dod_reevaluate`＝`executor.py` docstring L12-14）
- **intent / receipt の 2 段記録**（一度だけ実行への収束・`delivery.py` L402-424 / L568-600・`delivery-state-machine.md` §6）
- **round limit = 3**（`delivery.py` `ROUND_LIMIT` L77。数値の正本は runbook §2-(7) / `00_concept.md` — `loop-safety-gates.md` §6 と同じ参照固定の扱い）
- `delivery-state-machine.md` **§8 contract emit**（`delivery.py contract` と byte 一致であることを ta-56 が CI 機械検証。ただし検査対象は当該 doc 1 本に固定〔`tests/extras/ta-56-delivery.sh` L139-149〕であり、**新設契約 doc での再宣言は現行 guard では検出されない** — 検出**できるようにする**のが本 PBI の作業）

### 実装済み ↔ 本 PBI 新規追加の分離（2026-08-04 鮮度是正）

「contract が固定するだけ（実装済み）」と「本 PBI で新規追加」の分界:

| 区分 | 領域 | 実体参照（main `7bf5f5c`） |
|------|------|---------------------------|
| 実装済み（固定のみ） | Delivery state / terminal / exits / priority 15 段 | `delivery.py` L36-64・`delivery-state-machine.md` §2-§3 |
| 実装済み（固定のみ） | action ID・action_kind 6 種・intent / receipt 2 段記録 | `delivery.py` L176-188 / L402-424 / L568-600・`executor.py` L12-14 |
| 実装済み（固定のみ） | round 系予算（`ROUND_LIMIT=3` / `cost_cap`＝round 単位） | `delivery.py` L77・`arbiter.py` L697-707 / L992-1009（priority 1.95） |
| 実装済み（固定のみ） | 同型再発検知（finding_type 単位・`same_type_recurrence`） | `delivery.py` L229-231 / L331-342 |
| 実装済み（**現行は opaque な暫定コード。正規化語彙の定義は本 PBI**） | escalation flag / deny 理由コード群。命名は **3 体系**（`executor.py` = `executor_*`・`reconciler.py` = `reconciler_*` の `<layer>_<reason>` / `collector.py` = 無接頭辞〔`pull_fetch_failed` 等〕/ `gh_exec.py` = 大文字 `REASON_*`〔`EMPTY_ARGV` 等〕） | `collector.py` L110-143（L110「opaque な文字列 / AC-6 の接続点」）・`executor.py` L132-141（L132「**#894 が語彙を決める** / AC-6 接続点」）・`reconciler.py` L66-67・`gh_exec.py` L63-71 |
| 実装済み（固定のみ） | 供給 / 実行 / 突合の 3 層分離 + 実行境界の機械強制 | `collector.py` / `executor.py` / `reconciler.py` / `check_exec_boundary.py` / `gh_exec.py` |
| **本 PBI 新規** | **budget**（time / token / cost_usd / 連続失敗の各予算 + enforcement 同時実装） | なし（`loopspec.md` L125 注記の解除側） |
| **本 PBI 新規** | **no-progress**（evidence delta + blocker 差分の独立 detector） | なし（入力源＝state entry 蓄積は #941 整備済み・`collector.py` L29-30） |
| **本 PBI 新規** | **repeated-failure**（正規化 fingerprint による同一失敗検出） | なし（`same_type_recurrence` は粗粒度の近縁機構・置換しない） |
| **本 PBI 新規** | **oscillation**（resolved → reintroduced 反復・修正 A/B 往復の検知） | なし（語の出現 0 件・2026-08-04 再実測） |
| **本 PBI 新規** | **verifier 階層**（4 値 status schema + 層間順序・blocking 規則の契約化） | なし（`inconclusive` 0 件・4 値 enum 未定義） |
| **本 PBI 新規** | **metrics**（`cost_usd` / `tokens` / `human_minutes` / `accepted_change` の additive 拡張） | なし（`metrics.py` はレート系のみ） |
| **本 PBI 新規** | **RunEvidence adapter**（#874 への budgets / verifier results / termination / metrics 保存境界） | なし |

新規に定義する**制御領域**は上記 7 つ。schema / decision enum / reason code / 停止条件棚卸し文書は、この 7 領域を表現する成果物として issue Scope 1・7・8 のとおり実施する（`delivery.py` 語彙の**再定義**のみを禁止する）。すなわち AC-1（decision / termination reason / verifier result schema）・AC-13（task profile 別既定値と override policy）・DoD Close 条件 1（既存停止条件の棚卸し + gap 分析）は本 PBI の範囲内であり、禁止対象は「実装済み `delivery.py` 語彙の再定義」と「新しい Loop 実装の追加」に限る（issue 目的「新しい Loop 実装を増やすのではなく、#872 / #873 / #874 / #869 が共有する制御語彙・schema・判定順序・metrics を固定する」と一致）。

## 受入基準（issue #894 verbatim・14 項目）

- AC-1: Loop decision / termination reason / verifier result の schema が一意に定義されている
- AC-2: Worker の自己申告だけでは `success` にならない
- AC-3: deterministic failure を model reviewer の PASS で上書きできない
- AC-4: verifier unavailable / inconclusive 時に fail-open しない
- AC-5: stage ごとに iteration / time / token / cost / repair budget を設定できる
- AC-6: `no_progress` を evidence delta と blocker 差分で判定できる
- AC-7: 同一失敗を fingerprint で検出し、指定回数で停止できる
- AC-8: oscillation 検知時に同一修正戦略を継続せず replan または Human escalation になる
- AC-9: terminal decision が artifact hash / source SHA / head SHA へ束縛される
- AC-10: #873 の `MERGE_READY` 条件と矛盾せず、共通 decision へ変換できる
- AC-11: #874 の RunEvidence へ budgets / verifier results / termination / metrics を保存できる
- AC-12: active run 中に policy / budget / harness version が暗黙変更されない
- AC-13: task profile 別の既定値と override policy がある
- AC-14: auto-merge / Human-owned C-4 境界を変更しない

### AC ↔ 実装済み実体の対応（2026-08-04 鮮度是正・実体参照付き）

issue verbatim の AC 14 項目は不変。#905/#941 実装により「PR 収束段で既に成立している AC」と「本 PBI が新規に一般化・追加する AC」を実体参照付きで区別する（前者を contract は再定義せず参照する）:

| AC | 2026-08-04 時点の実装状況 | 実体参照 |
|----|--------------------------|---------|
| AC-2（自己申告で success 不可） | PR 収束段で先行成立: `delivery.py` は receipt の **intent 突合のみ**を担い（記録なき実行は受理しない）、`dod_reevaluate` receipt に intent 突合 + `evidence:<ref>` の両方を要求して `dod_evaluated=true` を導出するのは**供給側 = Collector / Executor**（§4 追補 8 が「`delivery.py` は不変」と明記） | `delivery.py` L579-585（intent 突合）・`collector.py` `derive_dod_evaluated()` L780-812（受理条件 3 = `result_ref` の `evidence:<ref>`）・`executor.py` L389（`dod_reevaluate` は `evidence_ref` 必須）・`delivery-state-machine.md` §4 追補 8 |
| AC-3（deterministic failure を reviewer PASS で上書き不可） | PR 収束段で先行成立: `ci_failed`（優先度 4）は review 判定より先に評価される固定順序 | `delivery.py` `PRIORITY_ORDER` L48-64 / `assess()` L344-351 |
| AC-4（unavailable / inconclusive で fail-open しない） | 部分先行: 供給不能系は escalation flag → `HUMAN_ESCALATED`（`findings_unavailable` 等）。verifier status enum としての 4 値は未定義（本 PBI 新規） | `collector.py` L125 / L131・`delivery.py` `assess()` L271-280 |
| AC-6（`no_progress` を evidence delta と blocker 差分で判定） | 未実装（本 PBI 新規）。ただし入力源＝state entry の append-only 蓄積は #941 が先行整備済み | `collector.py` docstring L29-30 |
| AC-7（同一失敗 fingerprint） | 部分先行: finding_type 単位の `same_type_recurrence`（粗粒度）。正規化 fingerprint は未実装（本 PBI 新規・置換しない） | `delivery.py` L229-231 / L331-342 |
| AC-9（terminal decision の hash / SHA 束縛） | 部分先行: `MERGE_READY` record は `head_sha` / `plan_hash` を保持し snapshot は head SHA 束縛（Collector AC-1）だが、**`source_sha` は record に未収納**（§6 の 6 フィールドに無い）。束縛は `source_sha_ancestry` の真偽値と assess 入口の `expected-sha` 照合のみ。RunEvidence 側での `source_sha` 保持は本 PBI 新規 | `delivery.py` L389-400（record 6 フィールド）/ L140・L277（ancestry 真偽値）/ L522-529（`--expected-sha` 必須）・`delivery-state-machine.md` §6・`collector.py` docstring L6 |
| AC-10（`MERGE_READY` と矛盾せず共通 decision へ変換） | **変換元が機械可読で確定済み**: `delivery.py contract` emit が正。変換表は「実装済み語彙 → 共通 decision」の一方向で定義する（作成時想定の「#873 実装前に変換表を先行確定し #873 が consume」は失効） | `delivery.py` `contract_dict()` L99-106・`delivery-state-machine.md` §8 |
| AC-12（active run 中の暗黙変更なし） | 部分先行: record.jsonl は append-only + entry_id 改竄検知（fail-closed）。policy / budget / harness version の束縛は本 PBI 新規 | `delivery.py` `load_entries()` L449-473 |

上記以外の AC-1 / AC-5 / AC-8 / AC-11 / AC-13 / AC-14 は先行実装なし（本 PBI の新規領域。AC-14 は境界不変の制約 AC）。

### 必須 fixture（issue verbatim・12 件）

1. deterministic PASS + spec PASS + reviewer PASS → success
2. tests FAIL + reviewer PASS → continue または blocked、success 不可
3. reviewer unavailable → human_escalated または blocked
4. max iteration 到達 → budget_exhausted
5. artifact 未変更・同一 failure 反復 → repeated_failure
6. finding 数・evidence に変化なし → no_progress
7. resolved finding 再出現 → oscillation / replan
8. source SHA 変更 → stale verifier result 無効化
9. low-risk task profile 正常系
10. high-risk path で Human-owned policy gate 発火
11. accepted change の cost / human minutes 集計
12. RunEvidence 再生成時に同じ terminal decision となる

### DoD / Close 条件（issue verbatim 要点）

既存 workflow の停止条件棚卸し + gap 分析文書化 / schema・validator・decision engine 相当の機械検証が
main へ merge / #872・#873・#874 の最低 1 経路ずつの共通契約消費統合 test / 12 fixture CI PASS /
representative TASK での continue → repair → verify → terminal decision E2E evidence /
no-progress・repeated-failure・budget-exhausted の停止理由が RunEvidence に残る /
cost per accepted change を 1 件以上の実 Run または再現 fixture で算出 /
EPIC #870 DoD へ PR・test・E2E evidence link 反映。
**設計文書のみ、stage 固有の ad-hoc 判定のみ、Worker の完了宣言のみでは close しない**。

## Notes from Refinement（調査で確定した設計方針と C-3 論点）

### 設計方針

- **数値は既存正本への参照固定・enum は additive 正規化層**: `loop-safety-gates.md` §6 /
  `stop-rollback.md` §0 の「再定義しない」契約を継承する。本契約は
  (1) ラウンド上限 3・CB-1〜3・escalate 予算等の**数値を再宣言しない**（`round_limit_ref` 型の
  参照フィールドを踏襲）、(2) decision enum / reason code / verifier status の**語彙正規化**と
  **層間順序**（決定論 → 仕様 → 独立 reviewer → policy → loop decision）のみを新規定義する
- **loopspec L125 注記の正式解除**: 「cost cap フィールドは設けない（#749 で enforcement 同時実装）」
  の条件を本 PBI が enforcement 側で満たす。time / token / cost_usd / 連続失敗の各予算は
  enforcement と宣言フィールドを**同一 PR 内で対にする**（宣言だけ先行させない＝同注記の原則維持）
- **loopspec L281 follow-up の履行**: no-progress detector を「同型指摘の再発 → Optimize 送り +
  ラウンド上限 3」の現行実体から独立 detector（evidence delta + blocker 差分 + fingerprint）へ昇格
- **4 値 status は既存裁定・状態機械の語彙と別レイヤ（2026-08-04 是正: 3 者 → 4 層）**: verifier result の
  `pass|fail|unavailable|inconclusive` は **verifier 単位**の語彙、`AUTO_APPROVED|HUMAN_ESCALATED|BLOCKED` は
  **run 裁定（terminal）**の語彙、issue の decision 8 値（continue / success / blocked / human_escalated /
  budget_exhausted / no_progress / repeated_failure / policy_denied）は **loop decision** の語彙、
  そして **`delivery.py` の state 7 種 + exits 2 種 + terminal `MERGE_READY`（`STATES`/`EXITS` L36-46・
  実装済み）は PR 収束段の状態機械**の語彙。4 層の変換表を契約に含め（delivery 側は
  `delivery.py contract` emit を変換元の正とし再定義しない）、`unavailable` / `inconclusive` は
  fail-open 禁止（AC-4）で `review-principles.md` §7-ter（実行不可の明示記録）と整合させる
- **決定論パターン先例の転写**: `plan_package.py`（決定論・fail-closed・冪等）/ `c3prime_verify.py`
  （exit code 契約）/ `metrics.py`（fail-silent 禁止の明示区分）/ `arbiter.py` priority 1.95
  （cost_cap 境界値=通過・超過のみ escalate）に加え、**`delivery.py`（#905）を最有力の先例として踏襲**
  （2026-08-04 追記: snapshot + record のみ依存の純判定器・`--now` 注入・stable action ID +
  intent / receipt 2 段記録・entry_id 冪等 append・contract emit の byte 一致 CI 検証）
- **metrics 拡張は additive**: `metrics.py` に `cost_usd` / `tokens` / `human_minutes` /
  `accepted_change` を追加する際、既存レート系集計（first-pass rate＝`first_pass` 導出 /
  `escalate_rate` 等）と record 世代区分を壊さない（additive フィールド + 欠落時は集計分母から明示除外）

### C-3 論点一覧（人間判断が必要な事項）

1. **正本断片化の回避方針の承認**（最重要）: 上記「数値は参照・enum は additive 正規化層」で
   `loop-safety-gates.md` §6 / `stop-rollback.md` §0 と矛盾しない設計とするか。
   数値を本契約へ集約し直す（既存正本の版上げを伴う大工事）代替案は非推奨
2. **2 分割の採否（2026-08-04 是正: (a) の「#873 実装前に先行確定」は失効）**: #873/#905・#917/#941 の
   マージにより「実装前に変換表を先行確定し #873 が consume する」方向は取れなくなった。**方向は逆転**:
   契約は実装・実走済みの `delivery.py` 語彙（`delivery.py contract` emit）を正とし、`MERGE_READY` →
   共通 decision の変換表を**実装済み語彙 → 契約側の一方向**で定義する（additive 正規化層・AC-10）。
   残る分割論点は (a) **契約 doc + enum / reason code / 変換表（実装参照ベース）**と
   (b) **decision engine + fingerprint / no-progress detector + metrics 拡張（#874 と並行）**を
   別 PBI に分割するか、本 PBI 内の PR 分割（PR-1=契約 / PR-2=engine）に留めるか
3. **schema 配置の HO 分岐**: `schemas/**` は HO（`docs/ai/ai-loop/ho-paths.md` L28「AI 直接編集不可」）。
   `schemas/` なら HO patch（Human 適用）+ Hardening Override 発火、`docs/schemas/`（非 HO・前例
   `child-pbi.yaml`）なら AI 完結 + 機械検証は非 HO validator。**#874 の C-3 決定と同一の配置に揃える**
4. **terminal 3 値 vs decision 8 値の関係確定**: `MERGE_READY`（DoD 状態）を decision enum に
   含めるか、変換表の右辺（#873 側の状態）に留めるか。#874 の `terminal_state`
   （`MERGE_READY|HUMAN_ESCALATED|BLOCKED`）との語彙合わせを #874 実装前に先行確定する。
   **2026-08-04 追記（実装済み実体からの材料）**: `delivery-state-machine.md` §1 は「`HUMAN_ESCALATED` は
   裁定語彙の借用であり Delivery terminal ではない」と語彙群区別を既に固定し、`delivery.py` も
   `MERGE_READY` を唯一の終端（`TRANSITIONS["MERGE_READY"] = []`・L74）として実装済み。実装は
   「変換表右辺に留める」案と整合的（decision enum への取り込みは二重定義リスク）— 最終確定は C-3
5. **task profile の粒度**: risk class（既存 5 mode / LoopSpec risk）と task profile
   （探索的 / 定型修正）のどちらを既定 budget のキーにするか
6. **#869 adapter の検証非対称**: In scope 4（adapter 境界）は #869 を含むが、issue の
   AC 14 項目・fixture 12 件・DoD 統合テスト（#872/#873/#874 の最低 1 経路ずつ）には
   #869 検証が無い（issue 自体の非対称）。#869 adapter の検証を**追加 AC 化する**か、
   **#869 側 PBI へ後続分離する**か（issue 合意要・issue コメントでの提起を推奨）

> **✅ schema 配置論点の裁定（2026-07-31・Human。本ブロックは schema 配置のみに係る — 他の C-3 論点は未裁定のまま）**: **案 2 段階方式**を採用。Phase 1（shadow）は
> `docs/schemas/`（非 HO）で 4 PBI（#894/#874/#869/#908）同側に統一し、本番接続
> （promotion gate / Gate 接続）の C-3 で `schemas/` へ **1 回の HO patch で昇格**
> （前例 `3ec2e24`）。昇格判定は Gate 接続 PR の Human C-3 チェックリストで行う。
> 裁定の正本: [`docs/working/discussions/2026-07-31-schema-placement-ho-arbitration.md`](../discussions/2026-07-31-schema-placement-ho-arbitration.md) §7

## Estimation Evidence

### Risks

| リスク | 検証手段 | Fallback |
|--------|---------|----------|
| 正本断片化（§6 / §0 の再定義禁止契約と衝突） | 契約 doc に「参照固定フィールド一覧」を持たせ、CI で数値リテラルの再宣言を検出 | 数値を含む節を既存正本への参照のみに縮退 |
| ~~#873 未実装のまま AC-10 が検証不能~~ →（2026-08-04 是正・#873/#917 実装済みで方向逆転）契約が実装済み `delivery.py` 語彙を再定義・再宣言してしまう | **現行 guard は存在しない**（ta-56 TC-12 の検査対象は `delivery-state-machine.md` 1 本に固定・`tests/extras/ta-56-delivery.sh` L139-149）。**本 PBI の作業として**、新契約 doc を ta-56 の byte 一致対象へ**追加する**、または新契約 doc に state / priority literal が現れないことを走査する test を**新設する** | 変換表は `delivery.py contract` emit 出力を右辺に固定し、契約側 enum は additive のみに縮退 |
| schema HO 分岐で承認境界の強度が割れる | C-3 論点 3 で #874 と同一配置に確定 | docs/schemas/ + 非 HO validator で AI 完結 |
| 4 値 status 導入が既存 3 値裁定（exit 0/2/3 契約）を壊す | 変換表 + `test_arbiter.py` 回帰で既存 exit code 不変を機械検証 | verifier status は新規レイヤのみに閉じ、arbiter 裁定語彙に触れない |
| budget 宣言フィールドだけ先行し enforcement が置き去り（L125 注記の再発） | 宣言 + enforcement + fixture を同一 PR で対にする | enforcement 未了の budget 軸は契約に載せない（additive に後追い） |
| fingerprint 正規化（timestamp / line number / request ID 除去）の偽陰性・偽陽性 | fixture 5（同一 failure 反復）+ 正規化 unit test | 初版は保守的（完全一致寄り）にし、正規化規則を additive に拡張 |

### Unknowns

- schema 配置先（`schemas/` HO vs `docs/schemas/` 非 HO）→ ~~C-3 で確定（#874 と同一決定に揃える）~~ → **✅ 裁定済み（2026-07-31）: 案 2 = `docs/schemas/`（非 HO）で確定**（上記裁定ブロック参照）
- 2 分割 (a)/(b) の PBI 分割 vs PR 分割 → **C-3 で確定**
- `MERGE_READY` を decision enum に含めるか変換表右辺に留めるか → **C-3 で確定（論点 4。2026-08-04: 実装済み実体は変換表右辺案と整合的 — 論点 4 追記参照）**
- task profile 別既定 budget の初期値（実測データ不足。Run-001〜 の arbiter record に加え、**#941 実 PR 1 周の実走証跡**〔`docs/working/TASK-0917/evidence/e2e/run-log.md`・実 PR #940・2026-07-31〕から導出可能かは plan で確認）
- #868（model routing）未実装のため independent reviewer 選択の粒度は暫定・後日整合

### Assumptions

- 新設想定: 契約 doc（`docs/workflows/ai-loop/` 配下）+ schema（配置先 C-3）+ decision engine /
  validator（`scripts/ai-loop/`・非 HO）+ fingerprint / no-progress detector + `metrics.py` additive
  拡張 + 12 fixture + 既存停止条件の棚卸し文書
- `scripts/ai-loop/**` は PoC 隔離（本番から呼ばれない）で AI 実装可能（#874 と同前提）。
  **2026-08-04 是正: 隔離前提は一律には成立しない** — `c3prime_verify.py` は #889/#895 以降
  `bin/plangate` から呼ばれる**判定基盤**（`bin/plangate` L887-894 `_plangate_c3_dispatch`）。
  さらに rollout-policy §2 の**判定基盤 carve-out は glob**（`docs/workflows/ai-loop/rollout-policy.md`
  L52-57: ①`scripts/ai-loop/**` ②`docs/workflows/ai-loop/**`・`docs/ai/ai-loop/**`）であるため、
  本 PBI の成果物（契約 doc・decision engine / detector＝上記「新設想定」）は**接続の有無に関わらず
  初日から carve-out ①②に該当し、ai-loop auto-approve 対象外（escalate 固定）**。ただし L57 が明記する
  とおり arbiter の `boundary_check` は ho-paths.md 由来のため機械層では boundary=clean と判定され、
  本 carve-out は**規範層**（実行者が escalate する責務を負う）。**HO 化の要否のみ** plan で再判定する
- **Mode: critical で確定**（`mode-classification.md` 定量基準: **受入基準数 11+ → 超高（critical）が
  決定論的**。本 PBI は issue AC が **14 項目**で 11+ 確定。変更ファイル数も契約 doc + schema +
  engine + validator + detector + metrics 拡張 + 12 fixture + 棚卸し文書で 16+（超高）。
  「各軸の最大値を採用」で critical 確定）。加えて停止・escalate 契約は**承認境界周辺**
  （「承認境界周辺の変更 → 最低でも高」の趣旨に該当・安全側で該当扱い）。
  **autonomous APPROVE 不可・人間 C-3 必須・V-4 リリース前チェック要**。
  schema を `schemas/` に置く場合は **Hardening Override 発火**（lite_eligible 無効化・
  Standard 同期 C-3 強制）が追加で確定。2 分割 (a)（契約 doc + enum のみ）を独立 PBI に
  切り出す場合でも、AC は issue verbatim 14 項目を分割先へ按分するまで critical 判定を維持する
