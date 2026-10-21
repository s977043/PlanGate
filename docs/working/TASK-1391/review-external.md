# EXTERNAL / INDEPENDENT REVIEW — TASK-1391 PLAN

## Status

PENDING.

This file is intentionally present because the Plan Package requires the review artifact, but no I1+ verdict is claimed.

## Required review questions

1. Does separating event semantics (#1391) from durable persistence (#1392) create a missing responsibility or correctly remove half-commit risk?
2. Is RunEvidence still purely reconstructable from the accepted event stream?
3. Are event_seq and RunState revision correctly independent, and is #1392 the correct authority for sequence allocation?
4. Does EventDraft -> bound Accepted RunEvent -> canonical event_ref avoid concurrent producer identity races?
5. Can generic payload become a privacy/schema bypass?
6. Does the proposed first-slice event vocabulary overfit #1387 fixtures?
7. Does deferring formal JSON Schema weaken machine interoperability too far?
8. Does any proposed file or rule prematurely change canon / Human-owned authority?
9. Are mutation tests capable of killing the intended invariant rather than failing for unrelated reasons?
10. Is the parse-failure / invalid / partial / ready four-way result boundary coherent with canon?
11. Must #1392 validate `current_stream + candidate` before durable commit, or is a different boundary safer?
12. Is contiguous event_seq sufficient for the first slice, or is a hash-chain/previous-event binding required now?

## Expected output

- reviewed_at_sha
- Independence Level
- blocking / non-blocking findings
- counterexample or mutation evidence for major findings
- PASS / CONDITIONAL / REJECT

## C-3 準備: 指摘集約（追記専用 / 2026-10-22）

照合 base: `origin/main` `b2d12b0b`。実装照合対象: #1402 `3331e5c4` の
`scripts/ai-loop-v2/run_event.py` / `run_evidence.py`。先行の read-only 調査が
挙げた G1〜G13 を本ワーカーが実ファイルと照合したうえで採番した。本節以前に
`R-NNN` 形式の採番は無い（`review-self.md` の `R-1` / `R-2` は I0 自己レビューの
別系統ラベル）ため `R-001` から始める。

| R-NNN | 由来 | severity | 指摘（照合結果） |
|---|---|---|---|
| R-001 | G1 | major | Replan rebinding: `validate_stream`（`run_event.py` L284-292）は binding を先頭イベントに固定し、2 本目以降の `plan_contract_bound` が plan_hash / source_sha を変えると `binding drift` になる。2 本目以降の bound はセグメント境界として受理し、無効なのは `harness_manifest_ref` の変化だけとする。#1391 が検査するのは `contract_bound_seq == 直前の bound の event_seq` のみで、Replan の意味は #1393 が所有する |
| R-002 | G2 | major | plan 旧 L81「exact retry は #1392 idempotency で吸収」は失効。#1392 は idempotency を第 1 スライスから撤去し、revision + `position` の CAS で再送を拒否する（TASK-1392 R-046 / R-049 / R-054） |
| R-003 | G3 | major | binding 値は `bound_context` からのみ供給し、トップレベルのみに置く。draft（payload を含む）が binding キーを持てば reject（TASK-1392 R-047）。現行は `plan_contract_bound` payload に `plan_hash` / `source_sha` を許している（L37） |
| R-004 | G4 | major | B-6: `plan_contract_bound` payload に `loop_contract_ref` と `required_verifiers` 集合が無い（L37） |
| R-005 | G5 | major | B-12 / PF-2: `failure_recorded` に `verification_ref` が無い（L120-123） |
| R-006 | G6 | major | B-8 / PF-3: `pr_convergence_recorded` に `observed_artifact_ref` と 5 フィールドの値域検査が無い（L157-163 はキー集合のみ） |
| R-007 | G7 | major | B-8: policy イベントが無く、`run_evidence.py` の `policy_verdicts` は常に `[]`（L21 / L74） |
| R-008 | G8 | major | B-13: blocker 観測イベントが無い |
| R-009 | G9 | critical | non-vacuity: `outcome` が非 null なら `ready`（`run_evidence.py` L78）。先行 `plan_contract_bound` も `inputs` の中身も検査しないため、`decision_made` 1 件（inputs:[]）だけの stream が `ready` になりうる。静的読解による指摘で、実行再現は未実施 |
| R-010 | G10 | major | PF-5 / I-11: `decision_made` のキーが `{action,inputs,outcome,stop_reasons}` 固定（L166）。`input_last_event_seq` / `contract_bound_seq` / `decided_in_state` 等と件数・バイト上限が無い |
| R-011 | G11 | major | `state_transitioned` / `state_conflict` 型が未登録（現行は `state_conflict_recorded` のみ、L51）。payload の所有者は #1392 |
| R-012 | G12 | minor | 使用不能入力（空 / 非 list）で `validate_stream` が raise し、`project_run_evidence` が `invalid` を返す。plan の 4 層境界（parse failure は reject・RunEvidence を作らない）と不一致 |
| R-013 | G13 | major | RED 不足: duplicate ref（registered ref 単体）/ binding drift 単体 / Outcome 矛盾 / producer 自己申告 ready / replay / duplicate seq。#1329 preflight と `reviewed_at_sha` が未記録 |
| R-014 | Q11 | info | 「#1392 が commit 前に `current_stream + candidate` を検証する」境界の妥当性 — **deferred**（I1 レビューへ） |
| R-015 | Q12 | info | hash-chain / prev_event_ref の要否 — **deferred**（`review-self.md` の判断を維持し、I1 で脅威モデルが不足と出たら replan） |
| R-016 | Human D-1 | decision | 下記 verbatim |
| R-017 | Human D-2 | decision | 下記 verbatim |
| R-018 | Human D-3 | decision | 下記 verbatim |
| R-019 | Human D-4 | decision | 下記 verbatim |

### Human 決定（2026-10-22 / verbatim）

- **D-1**: Rewrite as a differential plan (Phase 1B) against the already-merged implementation (#1402, 3331e5c4); fix plan:8 "Production implementation: BLOCKED".
- **D-2**: Freeze in one slice: R-9 add `policy_verdict_recorded` {verdict ∈ AUTO_APPROVED|HUMAN_REQUIRED|DENIED, observed_artifact_ref, evidence_refs}, projection derives policy_verdicts[] from events; R-10 extend pr_convergence_recorded with observed_artifact_ref + 5-field value-domain checks, NO freshness/wall-clock field (freshness via observed_seq vs latest+current head in #1393); R-11 blocker snapshot event (observed_artifact_ref, blockers[], evidence_refs), not delta; plus G4, G5, G10, G11.
- **D-3**: #1391 checks only segment acceptance + harness_manifest_ref invariance; state conditions to #1392. MAX_INPUT_REFS / MAX_DECISION_EVENT_BYTES owned by #1393; #1391 imports and re-checks at append.
- **D-4**: ready requires preceding bound AND all required_verifiers results present; formal JSON Schema stays deferred.

（D-2 中の「R-9 / R-10 / R-11」は決定時のラベルで、本表の R-007 / R-006 / R-008 に対応する。）

### 監査表

| R-NNN | status | reflected_in | notes |
|---|---|---|---|
| R-001 | reflected | plan §B-2 / EV-11〜13 | D-3 |
| R-002 | reflected | plan §Rules / EV-02 | |
| R-003 | reflected | plan §B-3 / EV-14〜15 | |
| R-004 | reflected | plan §B-6 / EV-16 | D-2 |
| R-005 | reflected | plan §B-12 / EV-17 | D-2 |
| R-006 | reflected | plan §B-8 / EV-18〜19 | D-2 |
| R-007 | reflected | plan §B-8 / PJ-11 | D-2 |
| R-008 | reflected | plan §B-13 / EV-20 | D-2 |
| R-009 | reflected | plan §B-9 / PJ-12〜14 | D-4・RED で再現を先に取る |
| R-010 | reflected | plan §B-10 / EV-21〜23 | D-2 / D-3 |
| R-011 | reflected | plan §B-11 / EV-24 | D-2 |
| R-012 | reflected | plan §B-14 / PJ-04b | |
| R-013 | reflected | test-cases / todo | |
| R-014 | deferred | — | I1 で裁定 |
| R-015 | deferred | — | I1 で裁定 |
| R-016〜R-019 | recorded | plan §Decisions | Human 決定 |

reflected_in の commit は本 PR の単一 commit（`Refs: R-001..R-019`）。
