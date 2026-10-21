# TEST CASES — TASK-1391 / #1391

## Event envelope

| ID | Condition | Expected |
|---|---|---|
| EV-01 | valid minimum event | accepted |
| EV-02 | accepted stream contains duplicate event_ref / same content | invalid stream; idempotent retry must have been absorbed by #1392 before append |
| EV-03 | duplicate event_ref / different content | invalid / reject tamper |
| EV-04 | event_seq decreases | reject |
| EV-04a | event_seq jumps from N to N+2 | invalid gap |
| EV-04b | first accepted event_seq is not 1 | invalid |
| EV-05 | event_seq duplicate for different event | invalid |
| EV-05a | producer draft tries to supply authoritative event_seq/event_ref | reject draft |
| EV-05b | #1392 assigns next event_seq then #1391 finalizes | accepted |
| EV-05c | recomputed canonical event_ref differs from stored ref | invalid |
| EV-06 | revision differs while event_seq advances | allowed when event type permits |
| EV-07 | harness_manifest_ref changes mid-run | reject |
| EV-08 | unknown terminal/state taxonomy value | reject |
| EV-09 | raw transcript / secret field | reject |
| EV-10 | unknown critical payload field | reject/fail closed |

## Reference integrity

| ID | Condition | Expected |
|---|---|---|
| RF-01 | decision input refers to earlier evidence | accept |
| RF-02 | future ref in candidate append | reject before commit |
| RF-02a | #1392 attempts commit without validate_append | boundary/static failure |
| RF-03 | missing ref | reject |
| RF-04 | same ref registered twice by different artifacts | reject |

## Projection

| ID | Condition | Expected |
|---|---|---|
| PJ-01 | same stream twice | same semantic projection |
| PJ-02 | unfinished stream | evidence_status=partial |
| PJ-03 | valid terminal stream | evidence_status=ready |
| PJ-04 | readable binding mismatch | evidence_status=invalid |
| PJ-04a | malformed JSON / unusable envelope | reject; no RunEvidence fabricated |
| PJ-05 | multiple terminal outcomes | invalid |
| PJ-06 | event after terminal outcome | invalid |
| PJ-07 | MERGE_READY + Stop Reason | invalid |
| PJ-08 | HUMAN_ESCALATED without Stop Reason | invalid |
| PJ-09 | BLOCKED without Stop Reason | invalid |
| PJ-10 | producer includes evidence_status=ready | cannot override receiver |

## Privacy / trust

| ID | Condition | Expected |
|---|---|---|
| PV-01 | hidden CoT/raw transcript | reject |
| PV-02 | credential/secret value | reject |
| PV-03 | evidence uses refs instead of raw log body | accept |
| PV-04 | unsupported field only exists to bypass validator | reject |

## Boundary tests

| ID | Condition | Expected |
|---|---|---|
| BD-01 | #1391 writes persistent runtime JSONL itself | design violation |
| BD-02 | projection reads current Git/environment/time | design violation |
| BD-03 | RunState CAS logic appears in #1391 | design violation |
| BD-04 | Decision logic appears in #1391 | design violation |
| BD-05 | Legacy run-evidence schema modified | reject scope |

## Mutation targets

At minimum:
1. allow duplicate ref with different content
2. event_seq == revision assumption
3. accept harness drift
4. accept post-terminal event
5. accept HUMAN_ESCALATED without reason
6. accept MERGE_READY with reason
7. trust producer evidence_status
8. allow unknown payload keys
9. drop reference-integrity check
10. make projection depend on wall clock

## Revision 2 / Phase 1B 追加（RED。`3331e5c4` で FAIL することを確認してから GREEN）

`EV-02` の期待値は R-002 により「#1392 は CAS で再送を拒否する。stream に同一内容が現れたら invalid」と読み替える。

### Event

| ID | 由来 | Condition | Expected |
|---|---|---|---|
| EV-11 | R-001 | 2 本目の `plan_contract_bound` で plan_hash / source_sha が変わる | accepted（新セグメント） |
| EV-12 | R-001 | 2 本目の bound で `harness_manifest_ref` が変わる | invalid |
| EV-13 | R-001 | `contract_bound_seq` が直前の bound の seq と異なる | invalid |
| EV-13a | R-001 / R-013 | bound 無しで binding（plan_hash）だけが途中で変わる | invalid（binding drift 単体） |
| EV-14 | R-003 | draft の payload（ネスト含む）に binding キー | reject draft |
| EV-15 | R-003 | `bound_context` 以外から binding 値を渡す | reject |
| EV-16 | R-004 | bound に `loop_contract_ref` / `required_verifiers` 欠落・空・重複 | reject |
| EV-17 | R-005 | `failure.verification_ref` 欠落 / future / missing | reject |
| EV-18 | R-006 | convergence に `observed_artifact_ref` 欠落 | reject |
| EV-19 | R-006 | 5 フィールドのいずれかが値域外 / freshness フィールドを持つ | reject |
| EV-20 | R-008 | blocker snapshot の `blockers` 重複 / 非 list / ref 欠落 | reject |
| EV-21 | R-010 | decision に `input_last_event_seq` / `contract_bound_seq` / `decided_in_state` 欠落 | reject |
| EV-22 | R-010 / R-034 | `inputs` 件数 > `MAX_INPUT_REFS` / #1393 PF-5 で確定した範囲のバイト数 > `MAX_DECISION_EVENT_BYTES`（#1393 から import） | reject at append。load では再適用しない（EV-34） |
| EV-23 | R-010 | `inputs` が latest prior decision より前の ref だけ | reject |
| EV-24 | R-011 / R-036 | `state_transitioned` / `state_conflict` が #1392 定義と不一致 | reject。**#1392 exec と同時に入れる（D-7）。今回は EV-35 / EV-36 のみ** |
| EV-25 | R-013 | 2 イベントが同じ registered ref（verification id 等）を登録 | invalid |
| EV-26 | R-013 | 同一 event_seq が 2 件 | invalid |
| EV-27 | R-013 | 既存 stream の 1 件をそのまま再 append（replay） | invalid |
| EV-28 | R-013 / R-020 | `outcome=MERGE_READY` かつ Outcome 矛盾。組合せは plan P1B-6 の 4 種（policy `DENIED`/`HUMAN_REQUIRED` / policy 無し / convergence 非 pass / blockers 非空）を各 1 ケース（EV-28a〜d） | invalid（append と load の両方） |

### Projection

| ID | 由来 | Condition | Expected |
|---|---|---|---|
| PJ-04b | R-012 | 空 list / 非 list / 非 object 要素 | 例外で reject、RunEvidence を返さない |
| PJ-11 | R-007 | `policy_verdict_recorded` を含む stream | `policy_verdicts[]` がイベントから導出される |
| PJ-12 | R-009 / R-023 | bound 無しで `MERGE_READY` の terminal decision（inputs:[]） | invalid（`ready` にならない）。旧実装で `ready` になることを実行再現 |
| PJ-13 | R-009 | `required_verifiers` の一部に結果が無い `MERGE_READY` | invalid |
| PJ-14 | R-009 / R-023 | `MERGE_READY` で最新セグメントの bound 前の verification しか無い | invalid |
| PJ-15 | R-013 | producer が payload に `evidence_status=ready` を入れる | reject（未知キー）、receiver 判定のみ |

### Mutation targets（追加）

11. 2 本目の bound を binding drift として扱う（EV-11 で検出）
12. 2 本目の bound で manifest 変化を許す（EV-12）
13. draft の binding キーを許す（EV-14）
14. `policy_verdicts` を `[]` に戻す（PJ-11）
15. `ready` 判定から bound 先行条件を外す（PJ-12）
16. `ready` 判定から required_verifiers 充足を外す（PJ-13）
17. MAX_* の append 時再検査を外す（EV-22）
18. 使用不能入力を `invalid` で返す（PJ-04b）

## Revision 2.1 追加（C-2 R1 / R-020〜R-041）

ID 体系は plan の `P1B-n`（#1422 B-n とは別系統、plan「ID 対応表」）。

### 検査層タグ（R-024）

`A` = append 時（`validate_append`）、`L` = 既受理 stream の load/audit（`validate_stream` / `project_run_evidence` に stream を直接渡す）。`A+L` は両方で RED を書く。

| ID | 層 |
|---|---|
| EV-11 / EV-12 / EV-13 / EV-13a | A+L |
| EV-14 / EV-15 | A（draft 段階） |
| EV-16 / EV-17 / EV-18 / EV-19 / EV-20 / EV-21 / EV-23 / EV-25〜28 | A+L |
| EV-22 | A のみ（L は EV-34 で非適用を確認） |
| PJ-11〜15 | L（append 経由の stream でも同じ結果になることを併記） |

### Event

| ID | 由来 | 層 | Condition | Expected |
|---|---|---|---|---|
| EV-29 | R-022 | A+L | `input_last_event_seq == decision.event_seq − 2`（以下だが隣接しない） | invalid |
| EV-30 | R-022 | A+L | `input_last_event_seq == decision.event_seq − 1` | accepted（GREEN 対照） |
| EV-31 | R-020 | A+L | convergence の各フィールドが値域内の全 pass 値・`blocking_threads=0`・`conflict=false` | accepted（GREEN 対照） |
| EV-31a | R-020 | A+L | `blocking_threads=true` / `conflict=0` / `ci="passed"` | reject（bool と int、語彙の取り違え） |
| EV-32 | R-020 | A+L | decision キーが閉集合（plan P1B-7 の 10 キー）から 1 つ欠ける / 1 つ多い | reject |
| EV-32a | R-020 | A+L | `decided_in_state="EXECUTING"` / `verdicts` 値 `"ok"` | reject |
| EV-33 | R-020 / R-028 | A+L | `blockers_observed` の `blockers=[]`（空 snapshot） | accepted |
| EV-33a | R-028 | A+L | `blockers` 要素が非文字列 / payload に `cause_hypothesis` 等の追加キー | reject |
| EV-34 | R-037 | L | 既受理 stream（受理時は上限内）を、上限値を下げたモジュールで load | invalid にならない（append-only 検査を再適用しない） |
| EV-35 | R-036 / D-7 | A+L | 未登録 event type（例: `state_conflict_v2`） | reject（fail-closed） |
| EV-36 | R-036 / D-7 | A+L | 旧名 `state_conflict_recorded` を現行 payload で記録（`run_state.py` L189 の経路） | accepted（`test_delivery_v2.py` L188 を維持） |
| EV-37 | R-020 | A+L | 同じ `observed_artifact_ref` で同 seq の convergence / policy が 2 件 | invalid |
| EV-38 | R-026 | A+L | `inputs` が latest prior decision 以降の ref を含むが、#1395 が別の decision を選んだと仮定した入力 | #1391 は stream 上の latest のみで検証（選択ロジックを持たない。BD-04 と同じく静的確認） |

### Projection

| ID | 由来 | 層 | Condition | Expected |
|---|---|---|---|---|
| PJ-16 | R-023 / D-5 | L | bound 無しで terminal `BLOCKED` + Stop Reason | invalid でも ready でもない（GREEN 対照） |
| PJ-17 | R-023 / D-5 | L | `required_verifiers` が一部欠けた `HUMAN_ESCALATED` + Stop Reason | invalid でも ready でもない（GREEN 対照） |
| PJ-18 | R-023 / D-5 | L | 条件をすべて満たした `MERGE_READY` | ready（GREEN 対照） |
| PJ-19 | R-024 | L | `failure.verification_ref` が missing の stream を append を経ずに load | invalid |
| PJ-20 | R-033 | — | `delivery_runtime` 経由で使用不能入力 | delivery 失敗、RunEvidence を作らない |

### 既存資産の再実行（R-032 / R-037）

- `tests/fixtures/ai-loop-v2/delivery/*.json`、ta-87、ta-93、`test_delivery_v2.py`、`test_ratchet.py` を新 ready 条件で再実行。期待が変わるものは変更理由を status に記録

### Mutation targets（追加）

19. `input_last_event_seq` の等号を `<=` に戻す（EV-29）
20. append-only 検査を load にも適用する（EV-34）
21. `MERGE_READY` 以外の terminal も ready 条件不足で invalid にする（PJ-16 / PJ-17）
22. load 経路で `verification_ref` 検査を外す（PJ-19）

## Revision 2.2 追加（C-2 R2 / R-042〜R-048）

PJ-16 / PJ-17 の Expected は本節で置き換える（D-8）: `evidence_status == "terminal_unready"` の**完全一致**で assert する（「invalid でも ready でもない」の否定形 assert にしない）。

EV-28b（policy 無しの `MERGE_READY` が invalid）は D-9 により**無効化**する。#1395 の producer が入るまで実装も RED も置かない（下記 EV-28h が現状の挙動を固定する）。

| ID | 由来 | 層 | Condition | Expected |
|---|---|---|---|---|
| PJ-21 | R-042 / D-8 | L | terminal 未到達（outcome null）の stream | `evidence_status == "partial"`（完全一致） |
| PJ-22 | R-042 / D-8 | L | `no-progress-stop.json`（`HUMAN_ESCALATED`）を `project_run_evidence` と ta-87 L117 の oracle の両方で投影 | どちらも `terminal_unready`（両者一致） |
| EV-28e | R-044 | A+L | `MERGE_READY` かつ同セグメントに `pr_convergence_recorded` が無い | invalid |
| EV-28f | R-044 / D-9 | A+L | `MERGE_READY` かつ `blockers_observed` が無い | **D-9 で無効化**（#1395 producer 後に RED） |
| EV-28g | R-044 | A+L | 存在する convergence / policy / blockers の `observed_artifact_ref` ≠ decision `artifact_ref` | invalid |
| EV-28h | R-043 / D-9 | L | `repair-convergence.json`（policy / blockers 無し、convergence あり）を投影 | `ready`（`test_repair_converges_to_merge_ready` / ta-87 L346-357 / ta-93 が緑のまま） |
| EV-39 | R-046 | — | （#1392 引き継ぎ）同一 stream に `state_conflict_recorded` と `state_conflict` が混在 | invalid。**#1392 exec で置く** |

### Mutation targets（追加）

23. `terminal_unready` を `partial` に戻す（PJ-16 / PJ-17 / PJ-22）
24. ta-87 L117 の oracle だけ旧判定のまま残す（PJ-22）
25. convergence 不在の検査を外す（EV-28e）
26. `observed_artifact_ref` 照合を外す（EV-28g）

## Revision 2.3 追加（C-2 R3 / R-049〜R-055）

EV-28h の Expected は本節で置き換える（D-10）: 入力は **fixture 更新後**の `repair-convergence.json`（convergence に `observed_artifact_ref`、decision に `artifact_ref` を持つ。値は一致）。更新前の fixture では EV-28i / EV-28j により invalid になることを RED で確認する。

EV-28b / EV-28f は引き続き無効（D-9）。有効化は #1395 producer 後の #1391 plan 改訂 + 再 C-3 で RED を追加する（D-12。skip marker で置いて自動で有効になる形にはしない）。

| ID | 由来 | 層 | Input | Expected |
|---|---|---|---|---|
| EV-28i | R-049 / D-10 | A+L | `MERGE_READY` stream で `pr_convergence_recorded` に `observed_artifact_ref` が無い | invalid（append では reject） |
| EV-28j | R-049 / D-10 | A+L | `MERGE_READY` stream で `decision_made.decision` に `artifact_ref` が無い | invalid（append では reject） |
| EV-28k | R-049 / D-10 | — | `delivery_runtime` の repair 経路を実行 | 出力 stream の convergence / decision が両 ref を持ち一致、`ready` |
| PJ-23 | R-050 / D-11 | — | 更新後 `evolution-input-non-success.json`（`terminal_unready`）を ratchet に入力 | evolution input として受理（GREEN、`test_ratchet.py`） |
| PJ-24 | R-050 / D-11 | L | 更新後 `no-progress-stop.json` を投影 | L44 の期待値 `terminal_unready` と完全一致 |

### Mutation targets（追加）

27. convergence `observed_artifact_ref` / decision `artifact_ref` の必須検査を外す（EV-28i / EV-28j）
28. ratchet の evolution input 許容値から `terminal_unready` を外す（PJ-23）

## Revision 2.4 追加（R3 後スコープ検証 / R-056〜R-061）

EV-28j の Expected は本節で置き換える（D-13）: 対象は **`outcome == MERGE_READY` の decision** だけ。PJ-23 / mutation 28 は D-14 の受理検査が入って初めて有効になる（R-057。それまでは検出力ゼロ）。

| ID | 由来 | 層 | Input | Expected（assert） |
|---|---|---|---|---|
| EV-28j | R-049 / D-13 | A+L | `MERGE_READY` stream で terminal decision の `decision` に `artifact_ref` が無い | A: `validate_append` が `EventContractError` を raise。L: `project_run_evidence(stream)["evidence_status"] == "invalid"` |
| EV-28l | R-056 / D-13 | A+L | 非 MERGE_READY の decision（`action=continue`, `outcome=None`）に `artifact_ref` が無い（`delivery_runtime.py` L162 の形、`no-progress-stop.json` L76 / L135 / L217） | A: 例外なく受理。L: 同 stream が `invalid` にならない（`no-progress-stop.json` は `== "terminal_unready"`） |
| EV-28m | R-056 / D-13 | A+L | 非 MERGE_READY の decision に `artifact_ref="not-a-ref"` | A: `EventContractError`。L: `== "invalid"` |
| EV-28n | R-056 / D-13 | A+L | EV-28g の比較対象: convergence `observed_artifact_ref = X`、先行の `continue` decision `artifact_ref = Y`、`MERGE_READY` decision `artifact_ref = X` | A: 受理。L: `== "ready"`（非 MERGE_READY decision の ref は比較に使わない） |
| EV-28o | R-056 | — | `delivery_runtime` の plan-gate 経路（L159-170）と repair 経路（L213 / L225 / L249）を実行 | plan-gate `continue` decision は `"artifact_ref" not in decision`、`MERGE_READY` decision は `decision["artifact_ref"] == convergence["observed_artifact_ref"]` |
| EV-28p | R-056 | — | ta-87 L107 / L197 の複製 oracle を EV-28o と同じ stream に適用 | oracle の decision 判定が `project_run_evidence` と一致（不一致で ta-87 FAIL） |
| EV-18a | R-058 | A+L | `observed_artifact_ref` を `convergence` の内側（6 キー目）に置いた `pr_convergence_recorded` | A: `EventContractError("convergence keys")`。L: `== "invalid"`（トップレベルのみ受理） |
| PJ-23 | R-050 / D-11 / D-14 | — | 更新後 `evolution-input-non-success.json`（`terminal_unready`）を ratchet に入力 | `result["experiment_result"]["result"] == "PASS"`（`test_ratchet.py` 既存 L458-475 を維持） |
| PJ-23a | R-057 / D-14 | — | 同 fixture の `evidence_status` を `"invalid"` / `"done"` / 欠落にして ratchet に入力 | `result["experiment_result"]["result"] != "PASS"` かつ reject 理由に `evidence_status` を含む。**`ratchet.py` 変更前（`origin/main`）で FAIL（= 今は PASS が返る）ことを先に実測** |
| PJ-23b | R-059 / D-8 | — | 更新後 `verification-skipped.json`（L133 `terminal_unready`）を ratchet に入力 | 既存期待（当該 fixture を使うテストの結果）が不変 |

### Mutation targets（追加・改訂）

28.（改訂）`ratchet.py` の受理集合から `terminal_unready` を外す（PJ-23 で検出）。対象コードは D-14 で新設するもの。**変異の前に対象行が存在することを確認する**
29. `ratchet.py` の受理検査自体を外す（PJ-23a で検出）
30. decision `artifact_ref` の必須条件を `MERGE_READY` 限定から全 decision に広げる（EV-28l で検出）/ 任意キーの形式検査を外す（EV-28m で検出）
31. EV-28g の比較対象を「最新の decision」に変える（EV-28n で検出）
