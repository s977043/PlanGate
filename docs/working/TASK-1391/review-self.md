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

## 簡易 C-1（Revision 2.2 / C-2 R2 反映後 / 2026-10-22）

| 項目 | 判定 | 根拠 |
|---|---|---|
| C1-PLAN-01 受入基準網羅 | PASS | R-042〜R-046 が plan §P1B-6 / §P1B-8 / §#1392 引き継ぎ / test-cases Rev 2.2 に対応（review-external C-2 R2 監査表） |
| C1-PLAN-02 Unknowns 処理 | WARN | D-9 により policy / blockers 不在の `MERGE_READY` が ready になりうる。残存脅威として plan §P1B-6 に明記、有効化は #1395 |
| C1-PLAN-03 スコープ制御 | PASS | current-head 判定は #1393 / #1395、旧名廃止は #1392、上限の版管理は #1393 |
| C1-PLAN-04 テスト戦略 | PASS | PJ-16 / 17 / 21 / 22 は完全一致 assert、EV-28h で D-9 下の現状挙動を固定、mutation 23〜26 |
| C1-PLAN-05 Work Breakdown Output | PASS | T1〜T6（変更なし） |
| C1-PLAN-06 依存関係 | WARN | #1392 不変条件（validate_append 経由のみ）に依存。replan trigger に追加 |
| C1-PLAN-07 動作検証自動化 | PASS | ta-87 L117 と test_delivery_v2 を Files に追加 |

```text
簡易 C-1（Rev 2.2）: PASS（WARN 2 件。D-9 の残存脅威と #1392 不変条件依存の明示）
```

## 簡易 C-1（Revision 2.3 / C-2 R3 反映後 / 2026-10-22）

| 項目 | 判定 | 根拠 |
|---|---|---|
| C1-PLAN-01 受入基準網羅 | PASS | R-049〜R-052 が plan §Decisions D-10〜D-12 / §P1B-5〜7 / §Files / test-cases Rev 2.3 / todo Rev 2.2〜2.3 に対応（review-external C-2 R3 監査表） |
| C1-PLAN-02 Unknowns 処理 | WARN | D-9 の残存脅威は継続。有効化手続きは D-12（plan 改訂 + 再 C-3）で明示 |
| C1-PLAN-03 スコープ制御 | PASS | D-10 の producer 更新は #1391 語彙内（#1395 責務に入らない）。`docs/ai/` / `scripts/` / fixtures は exec 時の Files として列挙のみ |
| C1-PLAN-04 テスト戦略 | PASS | EV-28i〜k、PJ-23〜24、EV-28h は fixture 更新後で固定、mutation 27〜28 |
| C1-PLAN-05 Work Breakdown Output | PASS | todo に Rev 2.2 / 2.3 タスクと rollback を追加（R-051） |
| C1-PLAN-06 依存関係 | WARN | #1393 PF-5（D-6）と #1395 producer（D-12）に依存。replan trigger に追加 |
| C1-PLAN-07 動作検証自動化 | PASS | ratchet / test_ratchet / no-progress-stop / artifact-responsibilities を Files に追加（D-11） |

```text
簡易 C-1（Rev 2.3）: PASS（WARN 2 件。D-9 残存脅威と #1393 / #1395 依存の明示）
```

## 簡易 C-1（Revision 2.4 / R3 後スコープ検証 反映後 / 2026-10-22）

| 項目 | 判定 | 根拠 |
|---|---|---|
| C1-PLAN-01 受入基準網羅 | PASS | R-056〜R-059 が plan §Decisions D-13 / D-14・§P1B-5〜7・§Files / test-cases Rev 2.4 / todo Rev 2.4 に対応（review-external 監査表） |
| C1-PLAN-02 Unknowns 処理 | WARN | D-9 残存脅威は継続。decision の任意キー名は #1393 PF-5 待ち（D-6） |
| C1-PLAN-03 スコープ制御 | PASS | D-13 は #1391 語彙内、D-14 の ratchet 受理検査は値域の消費側のみ（ratchet の判定ロジックは変えない） |
| C1-PLAN-04 テスト戦略 | PASS | 各ケースに A / L タグと完全一致 assert。PJ-23a は `origin/main` で FAIL を先に実測、mutation は対象コードの存在確認を前置（R-057） |
| C1-PLAN-05 Work Breakdown Output | PASS | todo Rev 2.4 に rollback 付きタスク |
| C1-PLAN-06 依存関係 | WARN | #1393 PF-5（D-6）と #1395 producer（D-12）に依存（変更なし） |
| C1-PLAN-07 動作検証自動化 | PASS | `ratchet.py` / `verification-skipped.json` / `delivery_runtime.py` L118 / L162 / ta-87 L107 / L197 を Files に追加 |

```text
簡易 C-1（Rev 2.4）: PASS（WARN 2 件。D-9 残存脅威と #1393 / #1395 依存の明示）
```

## 簡易 C-1（R3 後スコープ検証 2 / R-062〜R-063 反映後 / 2026-10-22）

| 項目 | 判定 | 根拠 |
|---|---|---|
| C1-PLAN-01 受入基準網羅 | PASS | R-062 → §P1B-5 / §Files / EV-18b、R-063 → §Files / PJ-23b / todo |
| C1-PLAN-04 テスト戦略 | PASS | EV-18b（A+L GREEN）と EV-18a（内側配置 reject）が対。PJ-23b に digest 不一致の対照 |
| C1-PLAN-05 Work Breakdown Output | PASS | todo に rollback 付きで 2 タスク追加 |
| その他 | 変更なし | Rev 2.4 判定のまま |

```text
簡易 C-1（R-062〜R-063）: PASS（WARN は Rev 2.4 の 2 件のまま）
```
