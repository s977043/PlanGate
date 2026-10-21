# EXECUTION PLAN — TASK-1391 / #1391（Revision 2 / Phase 1B 差分計画）

## Current verdict

```text
Planning: GO (Revision 2, C-3 待ち)
Phase 1A (initial implementation): MERGED via #1402 (3331e5c4)
Phase 1B (this plan): differential changes against 3331e5c4; exec after Human C-3
Exec preconditions: #1329 preflight recorded + reviewed_at_sha recorded
Durable persistence: OUT OF SCOPE -> #1392
Formal JSON Schema: DEFERRED (D-4)
```

旧 Revision の「Production implementation: BLOCKED」は実態と不一致だったため撤回する
（D-1）。初期実装は #1402 で main に入っている。本 plan はその実装に対する差分だけを定める。

## Decisions（Human / 2026-10-22。原文は `review-external.md` R-016〜R-019）

- D-1: 既 merge 実装（#1402 / `3331e5c4`）に対する差分計画（Phase 1B）として書き直す
- D-2: 次を 1 スライスで凍結する — `policy_verdict_recorded` 追加、`pr_convergence_recorded` 拡張、blocker snapshot event、R-004 / R-005 / R-010 / R-011
- D-3: #1391 が検査するのはセグメント受理と `harness_manifest_ref` 不変だけ。state 条件は #1392。`MAX_INPUT_REFS` / `MAX_DECISION_EVENT_BYTES` は #1393 が所有し、#1391 は import して append 時に再検査する
- D-4: `ready` には先行する bound と、全 `required_verifiers` の結果が要る。formal JSON Schema は引き続き deferred

## Mode判定

**モード**: high-risk

**判定根拠**:
- 変更ファイル数: 5（run_event.py / run_evidence.py / 2 test / TA）→ standard
- 受入基準数（B-2〜B-14 の差分項目）: 11 → high-risk
- 変更種別: 既存契約の拡張（イベント語彙・projection 判定）→ high-risk
- リスク: projection の `ready` 判定は下流の completion claim に直結 → high-risk
- HO 対象パス: なし（`scripts/ai-loop-v2/` は 12 カテゴリ外）
- **最終判定**: high-risk（review-principles §7-quater により敵対レビュー 2 ラウンド以上）

## Architecture（不変）

```text
Producer
  -> EventDraft (no authoritative seq/ref, no binding keys)
  -> #1391 validate draft payload semantics
  -> #1392 durable sink / lock
       assign event_seq
       bind run/revision/manifest/source context (bound_context only)
  -> #1391 finalize accepted RunEvent + canonical event_ref
  -> #1391 validate_append(current_stream, candidate_event)
  -> #1392 commit (CAS on revision + position)
  -> accepted stream
  -> #1391 validate stream + deterministic projection
  -> RunEvidence
```

## Rules（Revision 2 で改めたもの）

- first accepted event_seq is 1、以後 exactly previous + 1（変更なし）
- **exact retry**: #1392 は idempotency を持たない（TASK-1392 R-046）。再送は revision + `position` の CAS で拒否される（R-049 / R-054）。#1391 側の stream に同一内容の重複が現れたら invalid（R-002）
- event type determines allowed payload keys; unknown critical fields do not fail open（変更なし）

## Phase 1B 差分（実装 `3331e5c4` 基準。行番号は同 SHA の `run_event.py` / `run_evidence.py`）

### B-2 Replan rebinding（R-001 / D-3）

- 現状: `validate_stream` L284-292 が全イベントの `run_id` / `harness_manifest_ref` / `plan_hash` / `source_sha` を先頭イベントと比較する
- 変更: 2 本目以降の `plan_contract_bound` をセグメント境界として受理する。各セグメント内は `plan_hash` / `source_sha` が当該 bound と一致すること。`run_id` と `harness_manifest_ref` は stream 全体で不変（変化は invalid）
- 各イベントは `contract_bound_seq`（直前の bound の event_seq）を持ち、#1391 は `contract_bound_seq == 直前の bound の event_seq` だけを検査する。Replan を許すかどうかの state 条件は #1392、Replan の意味は #1393 が所有する

### B-3 binding の供給経路（R-003）

- binding 値（`run_id` / `harness_manifest_ref` / `plan_hash` / `source_sha` / `revision`）は `bound_context` からのみ、accepted event のトップレベルにだけ置く
- draft が payload の任意の深さに binding キーを持てば reject（TASK-1392 R-047）。現行の `plan_contract_bound` payload の `plan_hash` / `source_sha` は削除する

### B-6 plan_contract_bound の payload（R-004 / D-2）

- `{loop_contract_ref, required_verifiers, evidence_ref}`。`loop_contract_ref` は sha256 ref、`required_verifiers` は重複なしの verifier_id 集合（非空、上限は #1393 の `MAX_REQUIRED_VERIFIERS`）

### B-8 policy / convergence（R-006 / R-007 / D-2）

- 新規 `policy_verdict_recorded`: `{verdict, observed_artifact_ref, evidence_refs}`。`verdict ∈ {AUTO_APPROVED, HUMAN_REQUIRED, DENIED}`、`observed_artifact_ref` は sha256 ref、`evidence_refs` は非空
- projection の `policy_verdicts[]` はこのイベントから導出する（固定 `[]` を廃止）
- `pr_convergence_recorded` に `observed_artifact_ref` を追加し、`ci` / `required_reviews` / `blocking_threads` / `conflict` / `scope` の 5 フィールドに値域検査を入れる（値域は RED fixture で凍結）
- freshness / wall-clock フィールドは **持たない**。鮮度は #1393 が observed_seq と最新 event・current head の比較で判定する

### B-9 non-vacuity（R-009 / D-4）

- `ready` の条件: terminal outcome がある AND 最新セグメントの `plan_contract_bound` が terminal より前にある AND その `required_verifiers` 全件について同セグメント内に `verification_recorded` がある
- 満たさない terminal stream は `invalid`（`ready` にしない）。まず RED で「bound なし / inputs:[] の `decision_made` 1 件が `ready` になる」ことを実行再現し、静的指摘を実測に置き換える

### B-10 decision_made（R-010 / D-3）

- payload キー: `action` / `inputs` / `outcome` / `stop_reasons` / `input_last_event_seq` / `contract_bound_seq` / `decided_in_state`（最終キー集合は #1393 PF-5 と合わせて RED で凍結）
- `input_last_event_seq` は append 時点の直前 event_seq 以下、`inputs` は直前の decision 以降の ref を含むこと（latest prior decision 基準）
- 件数・バイト上限: #1393 の `MAX_INPUT_REFS` / `MAX_DECISION_EVENT_BYTES` を import し、`validate_append` で再検査する。#1391 は値を定義しない

### B-11 state イベント（R-011 / D-2）

- `state_transitioned` と `state_conflict` を登録する（`state_conflict_recorded` は置き換え）。payload のキーと意味は #1392 が所有し、#1391 は #1392 の定義をそのまま検査するだけ

### B-12 failure_recorded（R-005 / D-2）

- `failure` に `verification_ref` を追加し、先行する `verification_recorded` の id を指すこと（future / missing は reject）

### B-13 blocker snapshot（R-008 / D-2）

- 新規 `blockers_observed`（名称は RED で凍結）: `{observed_artifact_ref, blockers, evidence_refs}`。delta ではなく snapshot。`blockers` は重複なし list

### B-14 使用不能入力（R-012）

- 空 / 非 list / 非 object 要素は `project_run_evidence` が例外で reject し、RunEvidence を作らない（4 層境界の 1 層目）。readable だが契約違反の stream だけが `invalid`

## Files / Components to Touch

- `scripts/ai-loop-v2/run_event.py`
- `scripts/ai-loop-v2/run_evidence.py`
- `scripts/ai-loop-v2/test_run_event.py`
- `scripts/ai-loop-v2/test_run_evidence.py`
- `tests/extras/ta-XX-ai-loop-v2-event-evidence.sh`（既存 TA があればそれを更新。番号は exec 開始時に再実測）

## Work breakdown

### T1 — Preconditions

- `reviewed_at_sha` と base SHA を記録
- #1329 preflight（M-1 / M-2 / M-3 before）を記録
- #1392 / #1393 の現行 plan と照合（binding 引数、MAX_* の定義位置、state イベント payload）

### T2 — RED（`test-cases.md` の Revision 2 追加分）

- B-2〜B-14 の各差分に RED を先に書き、`3331e5c4` で FAIL することを確認
- R-009 は実行再現を取る

### T3 — GREEN

- B-2〜B-14 を最小差分で実装。durable writer は持たない

### T4 — Mutation / integration

- `test-cases.md` Mutation targets（11〜18 を追加）で検出力を確認
- full `tests/run-tests.sh` と TA standalone

### T5 — Review

- I0 self-review
- 敵対レビュー 2 ラウンド以上（§7-quater）、I1+ at exact SHA
- R-014 / R-015 の裁定
- no C-4 / merge by AI

## Replan triggers

- #1392 requires persistence semantics inside #1391
- #1393 requires Decision logic inside event validation
- a formal schema is required before code can be safely consumed
- event_seq must equal RunState revision
- projection requires live external state（freshness 判定を含む）
- Legacy schema must change
- #1392 / #1393 が binding 引数・MAX_*・state payload の所有を引き取れない
