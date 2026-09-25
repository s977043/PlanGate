# SELF REVIEW — TASK-1393 PLAN

## Findings

### R-1 — no_progress must not be a fixture input

PASS after design.

It is derived from failure/artifact/evidence/blocker observations.

### R-2 — Decision Engine must not execute verifiers

PASS.

VerificationResult is an observed immutable input. The engine is pure.

### R-3 — model PASS must not cancel deterministic FAIL

PASS.

Decision order checks deterministic FAIL before success/convergence.

### R-4 — freshness is part of completion

PASS.

Completion evidence must bind current_artifact_ref.

### R-5 — scope observation stays outside Decision core

PASS.

PR convergence may carry a scope verdict from deterministic observer, but #1393 does not calculate changed paths or trust Worker scope_ok.

### R-6 — repairability free text would make Decision non-deterministic

Resolved by first-slice enum:
- repairable
- replan_required

Unknown values reject.

### R-7 — Policy Verdict mapping was under-specified

Resolved by not inventing it. First slice only accepts empty/ALLOW for automatic decision. Other policy values fail closed and cannot reach success.

### R-8 — Decision without RunState position was context-blind

Resolved by adding `lifecycle_state` as a pure snapshot input. MERGE_READY is considered only in PR_CONVERGING; Initial Plan Verification advance only in PLAN_VERIFYING.

## Verdict

PASS for plan. Production code gated by event contract and #1329 preflight.

## C-1 再実行（2026-09-25 / review-external R-001〜R-006 の確定反映後）

R-7 の「empty/ALLOW のみ受理・他は fail closed」は、R-001（出力形が 2 通り）と R-005（`ALLOW` は正本に無い語）の是正で置き換わった。

| 観点 | 判定 | 根拠 |
|---|---|---|
| 判定順の一意性（R-001） | PASS | step 0〜6 の各段が「最初の一致を返す」と明記。DENIED は Decision、HUMAN_REQUIRED / 未知値は `DecisionInputError` の 1 通りずつ |
| 正本語彙との一致（R-005） | PASS | Policy は taxonomy §5 の 3 語のみ。`ALLOW` は DC-20e で reject |
| 正本の評価順（R-006） | PASS | Policy（step 4）は Verifier evidence（step 1〜3）の後。DC-20c が deterministic FAIL の優先を固定 |
| Freshness（R-002） | PASS | PASS / FAIL の両方を拘束。DC-03a / DC-03b と変異（FAIL 側）を追加 |
| FailureRecord 欠落（R-003） | PASS | `verification_ref` で対応付け、DC-03 で `DecisionInputError` を固定 |
| 受入基準網羅 | PASS | pbi-input の First-slice decisions 6 件はすべて DC に対応（DC-01 / 02 / 16 / 08 / 05・06、model PASS は DC-02） |
| Unknowns | WARN | [P1 / Human] HUMAN_REQUIRED → WAITING_HUMAN の遷移と記録の所有（後続スライス）。#1395 が `DecisionInputError` を証跡化する責務も未確定 |
| Mode | high-risk | plan「Mode判定」。C-2 は §7-quater により 2 ラウンド以上、C-3 は Human 同期 |

判定: **PASS（Unknowns 1 件 WARN）**。C-2 R1 / R2 と Human の C-3 が残る。

### 追記（2026-09-25 11:40 / 敵対レビュー R2・R3 の後）

上の PASS は R-001〜R-006 の時点の判定。その後、敵対レビュー R2 で R-007〜R-014 が出て反映し、R3 で R-015〜R-021 が出た（未是正）。

- 判定: **FAIL（設計未収束）**。R3 で新クラスが出続けており、step 0 が state 別の必須入力を強制していない（R-015 / R-017）、Decision と実際の遷移の対応を検査する主体が無い（R-016）。
- 次: Human の設計判断（review-external「R3 の設計提案」）→ plan の再構成 → C-1 再実行 → C-2 R1 からやり直す。

### 追記（2026-09-25 13:xx / Revision 2 と敵対レビュー Rev2-R1〜R3 の後）

| 観点 | 判定 | 根拠 |
|---|---|---|
| Human 設計判断の反映 | PASS | DecisionInput 一括検査（I-1〜I-9 / P-1 / P-2 / state 別表）、受理 state 3 つ、next_state 廃止と #1392 導出（#1406 へ依頼 3 件）、HUMAN_REQUIRED 後続、budget を #1395 のリリース条件に |
| 受入基準網羅 | PASS | pbi-input Required 5 件（Human 承認済みの後続化 1 件を除く）はすべて DV / DD / DP に対応 |
| 判定の一意性 | PASS | Rev2-R3 で 3 state × 履歴つき入力の総当たり一意、step 8 到達不能を確認 |
| 収束（§7-quater） | **FAIL** | Rev2-R1 / R2 / R3 で新クラスが 1 / 3 / 1。freshness モデルは Rev2-R3 で安定したが、解除条件（artifact 同一性）と束縛（CAS と payload、FR の event 束縛）に R-037〜R-041 が open |

判定: **FAIL（未収束・上限ラウンド到達）**。Human の判断（打ち切り / 追加ラウンド）待ち。

追記（Rev2-R4 後）: Human 承認の追加 1 ラウンドで R-037〜R-041 を局所是正し、R-037 / R-038 / R-040 の閉鎖を確認。新クラス 1 件（R-042）ほか R-043〜R-046 が open。判定は **FAIL（未収束）** のまま。Rev2 の新クラス数は R1〜R4 で 1 / 3 / 1 / 1 件で、どれも「前ラウンドの是正が同一性・束縛の境界を動かしたこと」から生じている。

### 追記（2026-09-25 17:xx / Revision 2.2 = Rev2-R5 の R-047〜R-054 是正後）

Human 裁定（2026-09-25）: Rev2-R5 の R-047 を R-037 と同型とみなし、Rev2-R5 を**収束（是正漏れのみ）**と扱う。R-047〜R-054 を是正して C-2 へ進む。

| 観点 | 判定 | 根拠 |
|---|---|---|
| 受入基準網羅 | PASS | pbi-input Required 5 件: repair = DD-01 / DD-16、model PASS = DV-03 / DP-09、NO_PROGRESS = DD-04 / DD-10 / DD-13、MERGE_READY = DP-01、unavailable / inconclusive = DV-04 / DV-05 / DP-05。Deferred 1 件は Human 承認済み |
| 是正の反映（R-047〜R-054） | PASS | R-047 = 非対称な区切り（DV-22 / DP-15 / AV-03）、R-048 = PolicyVerdict / pr_convergence の event 構築（DI-40〜42）、R-049 = B-1〜B-11 表とリリース条件、R-050 / R-051 = I-10 `>= 1` と I-5 一括一意（DI-34 / 38 / 39）、R-052 = previous_decision（PR-09 / 12 / 14 / 15）、R-053 = input_last_event_seq 明示、R-054 = 有効 FR（DD-14 / DD-15）と B-2 の照合 |
| 整合（plan ↔ test-cases） | PASS | 旧表現（exactly one FR / previous_records / 入力としての evidence_delta / B-1〜B-7 のみ）の残存を grep で確認し 0 件。テスト ID の重複 0 件 |
| スコープ | PASS | #1393 は純関数のまま。stream 側の不変条件は B-1〜B-11 として #1422 に列挙 |
| Unknowns | WARN | B-8〜B-11 は #1422 への追加提案で未反映（Human 承認待ち）/ #1391 の第一スライス語彙に policy event が無い / #1406 への依頼（B-3〜B-5）が未反映 / `decision_made` payload キーの #1391 との合意 |
| Mode | high-risk | C-2 は §7-quater により 2 ラウンド以上、C-3 は Human 同期 |

判定: **PASS（Unknowns WARN）**。次は C-2 R1（外部レビュー、設計妥当性レーン + コードベース整合レーン）→ C-2 R2 → Human の C-3。
