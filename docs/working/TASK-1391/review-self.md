# SELF REVIEW — TASK-1391 PLAN

> Review type: I0
> Scope: Plan-only
> Base: `b2234bd1097f7b741d372e3353d1877932401731`

## Perspectives

### Architecture

PASS after refinement.

The initial decomposition risked giving #1391 an independently persisted event writer while #1392 persisted RunState. That would recreate state/event half-commit.

Refinement:
- #1391 = event semantics + pure projection
- #1392 = durable transaction/persistence
- #1393 = decision semantics

### Responsibility / SSoT

PASS.

- authoritative logical source = accepted RunEvent stream
- RunEvidence = rebuildable projection/cache
- durable storage transaction is not duplicated here
- WAL remains #1392 internal storage mechanism, not a new domain SSoT

### Testability

PASS.

Negative and mutation targets cover identity, ordering, taxonomy, reference provenance, terminality, privacy, deterministic projection, and responsibility leakage.

### Governance

PASS for plan-only.

No runtime/schema/canon files are changed. Production implementation remains subject to #1329 and must not self-preserve the I1 exception.

## Review round 2 findings — resolved

### R-3 — event_seq / event_ref authority was ambiguous

Severity: major.

Initial plan let the producer present a RunEvent candidate already containing authoritative sequence/ref while #1392 owned durable concurrency. Two concurrent producers could therefore pre-choose conflicting sequence identity.

Resolution:
- producer emits EventDraft without authoritative seq/ref
- #1392 assigns event_seq and binding under its lock
- #1391 finalizes canonical accepted event and computes event_ref

### R-4 — duplicate retry vs duplicate accepted event was mixed

Severity: major.

Initial EV-02 allowed vague "duplicate handling" inside the accepted stream.

Resolution:
- accepted stream must contain unique event_ref
- exact transaction retry is absorbed by #1392 before append
- duplicate already present in stream is invalid

### R-5 — reject vs evidence_status=invalid was ambiguous

Severity: major.

Resolution:
- structurally unusable input: reject, no fabricated RunEvidence
- readable but contract-invalid stream: RunEvidence invalid
- valid unfinished: partial
- valid terminal: ready

### R-6 — per-event validation was insufficient for safe commit

Severity: major.

An individually valid Decision/Failure event can still reference future/missing evidence or follow a terminal Outcome.

Resolution:
- #1392 reads current accepted stream under lock
- #1391 finalizes candidate event
- #1391 validates `current_stream + candidate` before commit
- only a valid append may enter #1392 durable transaction

### R-7 — strictly increasing sequence allowed silent gaps

Severity: major.

`1, 2, 4` is strictly increasing but can represent a missing event.

Resolution:
- first event_seq = 1
- next seq must be exactly previous + 1
- gap/duplicate/out-of-order all fail closed

### R-8 — event hash-chain is not added in #1391

Severity: info / deliberate.

Contiguous sequence + canonical event_ref detect accidental gaps/reordering and inconsistent refs, but do not claim protection from an actor that can rewrite the entire repository history.

The durable trust anchor belongs to #1392 transaction storage:
- stream count
- tail/ref
- digest / transaction binding
- recovery manifest

Adding a second `prev_event_ref` chain in #1391 would duplicate persistence integrity responsibility without creating an external trust anchor.

Replan if I1 shows #1392 manifest binding is insufficient for the required threat model.

## Remaining findings

### R-1 — Storage location intentionally unresolved

Severity: minor / intentional.

The plan does not choose a Production runtime path because #1391 must not own persistence. #1392 decides the durable store layout.

### R-2 — Formal JSON Schema deferred

Severity: minor / deliberate scope reduction.

First vertical slice uses strict runtime validators/fixtures. If cross-language/external consumers require a formal schema before safe integration, this becomes a replan trigger rather than silently expanding scope.

## I0 verdict

```text
Plan responsibility: GO
Plan test strategy: GO
Production code: BLOCKED
Independent review: REQUIRED
```

## 簡易 C-1（Revision 2 / 2026-10-22）

対象: R-001〜R-019 の 1 回確定反映後の plan / todo / test-cases（Plan 項目 C1-PLAN-01〜07）。

| 項目 | 判定 | 根拠 |
|---|---|---|
| C1-PLAN-01 受入基準網羅 | PASS | R-001〜R-013 の各指摘が plan §B-2〜B-14 と test-cases の ID に 1 対 1 以上で対応（review-external 監査表） |
| C1-PLAN-02 Unknowns 処理 | WARN | R-014 / R-015 は deferred。R-009 は静的指摘で、PJ-12 の実行再現を RED の最初に置いた |
| C1-PLAN-03 スコープ制御 | PASS | state 条件は #1392、MAX_* と Replan 意味は #1393（D-3）。freshness を持たない（D-2） |
| C1-PLAN-04 テスト戦略 | PASS | RED → GREEN → mutation 11〜18 |
| C1-PLAN-05 Work Breakdown Output | PASS | T1〜T5 |
| C1-PLAN-06 依存関係 | WARN | B-10 / B-11 / EV-22 は #1392 / #1393 の定義に依存。定義が動けば replan trigger |
| C1-PLAN-07 動作検証自動化 | PASS | TA + full suite |

Mode: high-risk（plan §Mode判定）。

```text
簡易 C-1: PASS（WARN 2 件。いずれも依存・deferred の明示で、C-3 で Human 判断）
```

## 簡易 C-1（Revision 2.1 / C-2 R1 反映後 / 2026-10-22）

失効注記（R-029）: 本ファイル L62 の「exact transaction retry is absorbed by #1392 before append」（および pbi-input L60 の「exact replay returns the already accepted event」）は R-002 により失効。再送は #1392 の CAS で拒否され、accepted stream 上の同一内容は invalid。

| 項目 | 判定 | 根拠 |
|---|---|---|
| C1-PLAN-01 受入基準網羅 | PASS | R-020〜R-038 が plan §P1B-n / test-cases の ID に対応（review-external C-2 R1 監査表）。#1422 B-n との対応は plan「ID 対応表」 |
| C1-PLAN-02 Unknowns 処理 | WARN | decision の後ろ 3 キー名と MAX_* の値・範囲は #1393 PF-5 待ち。exec BLOCKED として明示（D-6） |
| C1-PLAN-03 スコープ制御 | PASS | 改名は #1392 exec へ（D-7）、latest 選択は #1395、replay は #1395 / #1393 |
| C1-PLAN-04 テスト戦略 | PASS | 各ケースに A / L 層タグ、D-5 の GREEN 対照、mutation 11〜22 |
| C1-PLAN-05 Work Breakdown Output | PASS | T1〜T6 |
| C1-PLAN-06 依存関係 | WARN | #1393 PF-5 / #1392 exec に依存。replan trigger に PF-5 の key 名変更を追加 |
| C1-PLAN-07 動作検証自動化 | PASS | 既存 test_delivery_v2 / test_ratchet / ta-87 / ta-93 / fixtures の再実行 + full suite |

```text
簡易 C-1（Rev 2.1）: PASS（WARN 2 件。いずれも PF-5 依存の明示で、C-3 で Human 判断）
```
