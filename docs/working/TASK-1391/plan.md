# EXECUTION PLAN — TASK-1391 / #1391（Revision 2.3 / Phase 1B 差分計画）

## Current verdict

```text
Planning: GO (Revision 2.3, C-3 待ち。C-2 R1 反映済み: R-020〜R-041 / C-2 R2 反映済み: R-042〜R-048 / C-2 R3 反映済み: R-049〜R-055)
Phase 1A (initial implementation): MERGED via #1402 (3331e5c4)
Phase 1B (this plan): differential changes against 3331e5c4; exec after Human C-3
Exec: BLOCKED until #1393 PF-5 agreement fixes MAX_* values + the module that defines them (D-6)
Exec preconditions: #1329 preflight recorded + reviewed_at_sha recorded
Durable persistence: OUT OF SCOPE -> #1392
state_conflict_recorded -> state_conflict rename: lands with #1392 exec (D-7)
Formal JSON Schema: DEFERRED (D-4)
```

旧 Revision の「Production implementation: BLOCKED」は実態と不一致だったため撤回する
（D-1）。初期実装は #1402 で main に入っている。本 plan はその実装に対する差分だけを定める。
上記の「Exec: BLOCKED」は D-6 による別の理由（定数の合意待ち）であり、D-1 で撤回したものとは別。

## Decisions（Human / 2026-10-22。原文は `review-external.md` R-016〜R-019 / R-039〜R-041 / R-047〜R-048 / R-053〜R-055）

- D-1: 既 merge 実装（#1402 / `3331e5c4`）に対する差分計画（Phase 1B）として書き直す
- D-2: 次を 1 スライスで凍結する — `policy_verdict_recorded` 追加、`pr_convergence_recorded` 拡張、blocker snapshot event、R-004 / R-005 / R-010 / R-011
- D-3: #1391 が検査するのはセグメント受理と `harness_manifest_ref` 不変だけ。state 条件は #1392。`MAX_INPUT_REFS` / `MAX_DECISION_EVENT_BYTES` は #1393 が所有し、#1391 は import して append 時に再検査する
- D-4: `ready` には先行する bound と、全 `required_verifiers` の結果が要る。formal JSON Schema は引き続き deferred
- D-5: `ready` 条件を欠いて invalid になるのは `MERGE_READY` だけ。他の terminal（`BLOCKED` / `HUMAN_ESCALATED` 等）は invalid でも ready でもない。GREEN の対照テストを足す
- D-6: D-3 を維持する。exec は #1393 PF-5 の合意と定数の module 位置が確定するまで BLOCKED。バイト上限の適用範囲を 1 つに決める作業は #1393 に返す
- D-7: `state_conflict_recorded` → `state_conflict` の改名と payload は #1392 の exec と同時に入れる。#1391 は今は unknown type の fail-closed と旧名の扱いの RED だけを足す
- D-8: ready 条件を満たさない terminal stream（`BLOCKED` / `HUMAN_ESCALATED` 等）には新しい `evidence_status` 値 `terminal_unready` を与え、未完了の `partial` と区別する。ta-87 L117 と `test_delivery_v2.py` を Files / AC に含め、PJ-16 / PJ-17 は `evidence_status` の完全一致で assert する
- D-9: policy / blockers の語彙と検査は #1391 に残すが、`MERGE_READY` に対する「不在 ⇒ invalid」は #1395 の producer ができるまで無効のままにする。残存脅威として記録し、それまで `MERGE_READY` は既存条件だけを使う
- D-10: #1391 が producer も更新する。`delivery_runtime.py`（L65 / L238）と fixture が convergence の `observed_artifact_ref` と decision の `artifact_ref` を出す。両フィールドは必須で、どちらかを欠く `MERGE_READY` は invalid（RED を足す）。どちらも #1391 のイベント語彙なので #1395 の責務には入らない。EV-28h は fixture 更新後の状態で固定する
- D-11: ratchet は `terminal_unready` を evolution input として受理する。ratchet fixture を `terminal_unready` に更新し GREEN を足す。`artifact-responsibilities.md` L57 / L63、`test_ratchet.py`、`no-progress-stop.json` L44 を Files に含める
- D-12: D-9 で無効化した要件（EV-28b / EV-28f）の有効化は、#1395 の producer ができた後に #1391 の plan 改訂 + 再 C-3 で行う（skip marker による自動有効化はしない）

## Mode判定

**モード**: high-risk

**判定根拠**:
- 変更ファイル数: run_event.py / run_evidence.py / delivery_runtime.py / test_delivery_v2.py / test_ratchet.py / ta-87 / ta-93 / adapter 文書 → high-risk（6-15）
- 受入基準数（P1B-1〜P1B-13 の差分項目）: 13 → critical 寄りの high-risk（11+ は定量では critical。定性はアーキ変更でないため high-risk を維持し、敵対レビュー 2 ラウンド以上で補う）
- 変更種別: 既存契約の拡張（イベント語彙・projection 判定）→ high-risk
- リスク: projection の `ready` 判定は下流の completion claim に直結 → high-risk
- HO 対象パス: なし（`scripts/ai-loop-v2/` / `tests/extras/` / `docs/` は 12 カテゴリ外）
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
  -> #1391 validate stream (load/audit) + deterministic projection
  -> RunEvidence
```

### append 検査と load 検査の分離（R-037）

現行 `validate_append`（`run_event.py` `def validate_append`、`3331e5c4` L315-318）は
`validate_stream([*current, candidate])` に委譲している。Phase 1B ではこれを 2 層に分ける。

| 層 | 関数 | 検査 | 既受理 stream に再適用するか |
|---|---|---|---|
| append-only | `validate_append` の candidate 検査 | MAX_*（D-3）/ `input_last_event_seq == candidate.event_seq − 1` / draft の binding キー | しない |
| whole-stream | `validate_stream`（append と load/audit の両方で呼ぶ） | seq 連続 / ref 一意 / セグメント / manifest 不変 / P1B-6・P1B-8・P1B-9・P1B-10 の参照整合 / terminal 規則 | する |

append-only 検査を load 時に再適用しないのは、上限値の変更で過去の accepted stream が後から
invalid になるのを避けるため。`input_last_event_seq` の隣接性は whole-stream 側でも
`decision.event_seq − 1` と照合する（P1B-2、#1422 B-3 の semantic audit）。

## Rules（Revision 2 で改めたもの）

- first accepted event_seq is 1、以後 exactly previous + 1（変更なし）
- **exact retry**: #1392 は idempotency を持たない（TASK-1392 R-046）。再送は revision + `position` の CAS で拒否される（R-049 / R-054）。#1391 側の stream に同一内容の重複が現れたら invalid（R-002）。#1391 reopen AC の「同 ref 同 payload は冪等」はこの規則に置き換える（R-030）
- event type determines allowed payload keys; unknown critical fields and unknown event types do not fail open（変更なし。旧名 `state_conflict_recorded` は D-7 まで既知型として残す）

## ID 対応表（R-021）

本 plan の差分 ID は `P1B-n`。#1422 の凍結 B 番号とは別系統である。

| P1B | 内容 | #1422 B-n | #1422 上の #1391 の役割 |
|---|---|---|---|
| P1B-1 | Replan rebinding / セグメント | B-2 | load/audit + append |
| P1B-2 | seq adjacency（`input_last_event_seq`） | B-3 | semantic audit（commit/load は #1392） |
| P1B-3 | binding 供給経路 | —（TASK-1392 R-047） | — |
| P1B-4 | `plan_contract_bound` payload | B-6 | vocabulary + append/load |
| P1B-5 | policy / convergence 語彙 | B-8 | vocabulary と latest-current-head binding（構築は #1395） |
| P1B-6 | non-vacuity | B-9 | load/audit |
| P1B-7 | `decision_made` キー | B-10（の検査部分） | verifies（選択は #1395） |
| P1B-8 | state イベント | B-4 / B-5 の入力 | payload 所有は #1392 |
| P1B-9 | `failure_recorded.verification_ref` | B-12 | append/load/audit |
| P1B-10 | blocker snapshot | B-13 | name/shape（observer は #1395） |
| P1B-11 | 使用不能入力 | — | — |
| P1B-12 | replay audit 用 event の提供 | B-11 | owns events（実行は #1395、意味は #1393） |
| P1B-13 | TA-87 adapter 境界の文書化 | — | #1391 reopen AC |

## Phase 1B 差分（実装 `3331e5c4` 基準。行番号は同 SHA の `run_event.py` / `run_evidence.py`。記号アンカーを併記）

### P1B-1 Replan rebinding（R-001 / R-038 / D-3 / #1422 B-2）

- 現状: `validate_stream` の `binding drift`（L288-292。L284-287 は seq 連続検査）が全イベントの `run_id` / `harness_manifest_ref` / `plan_hash` / `source_sha` を先頭イベントと比較する
- 変更: 2 本目以降の `plan_contract_bound` をセグメント境界として受理する。各セグメント内は `plan_hash` / `source_sha` が当該 bound と一致すること。`run_id` と `harness_manifest_ref` は stream 全体で不変（変化は invalid）
- 各イベントは `contract_bound_seq`（直前の bound の event_seq）を持ち、#1391 は `contract_bound_seq == 直前の bound の event_seq` だけを検査する。Replan を許すかどうかの state 条件は #1392、Replan の意味は #1393 が所有する
- 検査層: whole-stream（append と load の両方）

### P1B-2 seq adjacency（R-022 / #1422 B-3）

- `decision_made.input_last_event_seq == decision.event_seq − 1`（等号）。旧 Revision の「直前 event_seq 以下」は誤りで撤回
- append 時は candidate に対して、load/audit 時は stream 中の全 `decision_made` に対して検査する。commit/load の CAS 側の隣接は #1392

### P1B-3 binding の供給経路（R-003）

- binding 値（`run_id` / `harness_manifest_ref` / `plan_hash` / `source_sha` / `revision`）は `bound_context` からのみ、accepted event のトップレベルにだけ置く
- draft が payload の任意の深さに binding キーを持てば reject（TASK-1392 R-047）。現行の `plan_contract_bound` payload の `plan_hash` / `source_sha` は削除する
- 影響（R-035）: `tests/extras/ta-87-ai-loop-v2-delivery-e2e.sh` L260-263 の `bound.get("plan_hash")` はトップレベル参照へ書き換える。`ratchet.py` L17 は `validate_event` を import しているため、改めた `validate_event` で ratchet の既存テストが通ることを確認する

### P1B-4 plan_contract_bound の payload（R-004 / D-2 / #1422 B-6）

- `{loop_contract_ref, required_verifiers, evidence_ref}`。`loop_contract_ref` は sha256 ref、`required_verifiers` は重複なしの verifier_id 集合（非空、上限は `MAX_REQUIRED_VERIFIERS`。値は #1393 PF-5 で合意待ち — D-6 / R-034）
- 検査層: append と load の両方

### P1B-5 policy / convergence（R-006 / R-007 / R-020 / D-2 / #1422 B-8）

- 新規 `policy_verdict_recorded`: `{verdict, observed_artifact_ref, evidence_refs}`。`verdict ∈ {AUTO_APPROVED, HUMAN_REQUIRED, DENIED}`、`observed_artifact_ref` は sha256 ref、`evidence_refs` は非空の重複なし ref list
- projection の `policy_verdicts[]` はこのイベントから導出する（固定 `[]` を廃止）
- `pr_convergence_recorded` に `observed_artifact_ref`（sha256 ref）を追加し、`convergence` の 5 フィールドの値域を次で固定する（TASK-1393 plan「pr_convergence」表 / R-074 と同一の語彙）

| Field | Domain |
|---|---|
| `ci` | `pass` / `fail` / `pending` |
| `required_reviews` | `pass` / `fail` |
| `blocking_threads` | 整数 `>= 0`（bool は不可） |
| `conflict` | 厳密に bool（0 / 1 は不可） |
| `scope` | `pass` / `fail` |

- `observed_artifact_ref` は**必須**（D-10 / R-049）。欠落は reject。今日の producer（`delivery_runtime.py` L65 の payload 構築と L238 の受信側）と `tests/fixtures/ai-loop-v2/delivery/*.json`（`repair-convergence.json` L197 など）はこのフィールドを持たないため、同じ変更で producer と fixture を更新する
- freshness / wall-clock フィールドは **持たない**
- **latest-current-head binding**（#1422 B-8 で #1391 plan が決めるとされたもの）: #1391 が提供するのは「同じ `observed_artifact_ref` を持つ当該種別イベントのうち event_seq 最大のもの」を一意に引ける stream 上の事実だけ（同 head・同 seq の重複は invalid）。それが current head かどうかの判定（`observed_artifact_ref == current_artifact_ref` かつ `observed_seq > contract_bound_seq`）は #1393 P-2、選択は #1395 が行う。policy verdict も同じ規則に従う
- 検査層: append と load の両方

### P1B-6 non-vacuity（R-009 / R-023 / R-024 / D-4 / D-5 / #1422 B-9）

- `ready` の条件: terminal outcome が `MERGE_READY` AND 最新セグメントの `plan_contract_bound` が terminal より前にある AND その `required_verifiers` 全件について同セグメント内に `verification_recorded` がある
- `MERGE_READY` でこの条件を満たさない stream は `invalid`（D-5）
- `BLOCKED` / `HUMAN_ESCALATED` 等の他の terminal は、この条件の成否で invalid にはならず、`ready` にもならない（既存の Stop Reason 規則 PJ-08 / PJ-09 は維持）。この場合の `evidence_status` は `terminal_unready`（D-8 / R-042）。`partial` は terminal 未到達（outcome が null）に限る
  - 現状の `run_evidence.py` L78 と ta-87 L117 の複製 oracle はどちらも `"ready" if outcome is not None else "partial"` で、`no-progress-stop.json`（`HUMAN_ESCALATED`）は今日 `ready` になる。両方を同じ変更で改める
  - 値域の正本と下流消費者も同じ変更で改める（D-11 / R-050）: `docs/ai/ai-loop-v2/artifact-responsibilities.md` L57 の値域を `ready | partial | invalid | terminal_unready` に、L63 に `terminal_unready`（ready 条件を満たさない非 MERGE_READY terminal）の定義を足す。`no-progress-stop.json` L44 の期待値を `terminal_unready` に、ratchet fixture `evolution-input-non-success.json` の `HUMAN_ESCALATED` / `BLOCKED` 入力を `terminal_unready` に改め、ratchet がそれを evolution input として受理する GREEN を `test_ratchet.py` に足す
- Outcome 矛盾（R-020 / R-043 / R-044 / D-9）: 次の組合せは invalid とする
  - `MERGE_READY` かつ同セグメントの最新 policy verdict が `DENIED` または `HUMAN_REQUIRED`（policy イベントが存在するとき）
  - `MERGE_READY` かつ最終 terminal 直前の `pr_convergence_recorded` のいずれかのフィールドが非 pass 値（`ci≠pass` / `required_reviews≠pass` / `blocking_threads≠0` / `conflict=true` / `scope≠pass`）
  - `MERGE_READY` かつ同セグメントに `pr_convergence_recorded` が 1 件も無い（EV-28e。delivery runtime は今日 convergence を出しており `repair-convergence.json` に含まれることを確認済み）
  - `MERGE_READY` かつ同セグメントの最新 `blockers_observed.blockers` が非空（blockers イベントが存在するとき）
  - `MERGE_READY` かつ、存在する convergence / policy / blockers の `observed_artifact_ref` が decision の `artifact_ref` と不一致（EV-28g。stream 内の ref 一致だけを見る。current head かどうかは #1393 / #1395）
  - `MERGE_READY` かつ convergence の `observed_artifact_ref` または decision の `artifact_ref` が欠落（EV-28i / EV-28j。D-10。欠落で EV-28g を迂回させない）
- **D-9 による無効化（残存脅威）**: 「`MERGE_READY` かつ policy verdict が 1 件も無い」（旧 EV-28b）と「blockers snapshot が 1 件も無い」（EV-28f）は invalid に**しない**。producer（#1395）が無く、`repair-convergence.json` / `test_repair_converges_to_merge_ready`（`test_delivery_v2.py` L296）/ ta-87 L346-357 の MERGE_READY 経路が赤になるため。#1395 の producer が入るまで、policy / blockers の不在のまま `MERGE_READY` が `ready` になりうる。有効化は #1395 の producer ができた後に **#1391 の plan 改訂 + 再 C-3** で行い、そのとき EV-28b / EV-28f を RED → GREEN にする（D-12 / R-052。skip marker 等による自動有効化はしない。#1395 側の変更だけでは有効化しない）
- まず RED で「bound なし / inputs:[] の `decision_made` 1 件が `ready` になる」ことを実行再現し、静的指摘を実測に置き換える
- 検査層: load/audit（projection）。append 時にも whole-stream 検査として走る

### P1B-7 decision_made（R-010 / R-020 / D-3 / D-6 / #1422 B-10）

- payload `decision` のキー集合（閉集合）: `action` / `inputs` / `outcome` / `stop_reasons` / `input_last_event_seq` / `contract_bound_seq` / `decided_in_state` / `artifact_ref` / `failure_fingerprints` / `verdicts`
  - 後ろ 3 つは TASK-1393 plan L85 / L184 が「payload から取る」とする値（`previous_artifact_ref` / fingerprint set / `previous_verdicts`）の受け皿。名前は本 plan で提案し、#1393 PF-5 の key mapping 合意で確定する（合意で名前が変われば exec 前に本節を改める。D-6 で exec はそれまで BLOCKED）
  - `artifact_ref` は**必須**（sha256 ref。D-10 / R-049）。今日の `decision_made`（`repair-convergence.json` L214 等）と `delivery_runtime.py` は持たないため、producer と fixture を同じ変更で更新する
  - `decided_in_state ∈ {VERIFYING, DIAGNOSING, PR_CONVERGING}`、`verdicts` の値 `∈ {pass, fail, unavailable}`、`failure_fingerprints` は重複なし list
- `input_last_event_seq` は P1B-2
- `inputs` は直前の `decision_made` 以降の ref を含むこと。**latest prior decision の選択は #1395、#1391 は stream 上でその一致を検証するだけ**（R-026）
- 件数・バイト上限: `MAX_INPUT_REFS` / `MAX_DECISION_EVENT_BYTES` を #1393 から import し、`validate_append` の append-only 層で再検査する。#1391 は値を定義しない
  - 現状どれも未定義（コードに無い）。バイト上限の適用範囲は TASK-1393 L172（input-derived part + `DECISION_FIXED_OVERHEAD`）/ TASK-1392 L293（event 全体の canonical size）/ 旧 EV-22（payload）で食い違う。1 つに決めるのは #1393（D-6）。#1391 は決まった範囲をそのまま検査する

### P1B-8 state イベント（R-011 / R-036 / D-7）

- 今回: unknown event type が fail-closed であること、旧名 `state_conflict_recorded` が現行 payload `{expected_revision, actual_revision, evidence_ref}` のまま既知型として受理され続けること（`run_state.py` L189 / `test_delivery_v2.py` L188 を壊さない）を RED/GREEN で固定する
- `state_transitioned` / `state_conflict` の登録と payload（TASK-1392 plan L216 の `expected_revision` / `actual_revision` / `expected_position` / `actual_position`）、および旧名の廃止は #1392 の exec と同じ変更で入れる。payload の所有は #1392
- #1392 への引き継ぎ必須項目（R-046）: (1) 旧名 `state_conflict_recorded` を既知型から削除すること、(2) 同一 stream に旧名と新名が混在したら invalid とする RED を置くこと

### #1392 への引き継ぎ不変条件（R-045 / EV-34 の層分離の前提）

- 「accepted stream は `validate_append` を経由してのみ作られる」を #1392 の不変条件とし、#1392 の検証項目に渡す（durable writer や手書き fixture が `validate_append` を迂回すると、上限超えの stream が load で受理される）
- 棄却 / 先送りした代替: load 時の上限を定数の版（constants version）に束ねて再検査する案。定数の版管理と所有は #1393 にあり、#1391 で版 ID を導入すると D-3 / D-6 の所有境界を越えるため先送り。#1392 の不変条件が保てないと分かったら replan する

### P1B-9 failure_recorded（R-005 / R-024 / D-2 / #1422 B-12）

- `failure` に `verification_ref` を追加し、先行する `verification_recorded` の id を指すこと（future / missing は reject）
- 検査層: append と load/audit の両方（既受理 stream を load したときにも同じ違反を invalid にする）

### P1B-10 blocker snapshot（R-008 / R-020 / D-2 / #1422 B-13）

- イベント名を `blockers_observed` に確定する
- payload: `{observed_artifact_ref, blockers, evidence_refs}`。delta ではなく snapshot。`blockers` は重複なしの文字列 list（空 list 可 = 観測した結果 blocker 無し）、`evidence_refs` は非空
- `blockers` の各要素は**観測された事実の識別子**（例: check 名 / thread id）に限り、原因仮説や自由文を入れない（R-028。#1047 の観測/仮説分離に合わせる）
- 検査層: append と load の両方

### P1B-11 使用不能入力（R-012 / R-033）

- 空 / 非 list / 非 object 要素は `project_run_evidence` が例外で reject し、RunEvidence を作らない（4 層境界の 1 層目）。readable だが契約違反の stream だけが `invalid`
- 影響: `run_evidence.py` L30-33 は `EventContractError` を捕捉して `_invalid` を返している。使用不能入力だけを別の例外として捕捉対象から外す
- 呼び出し側 `delivery_runtime.py` L255（`project_run_evidence(`）は新しい例外を捕捉し、delivery を失敗として扱う（RunEvidence を作らない）
- 書き換える既存テスト: `test_delivery_v2.py` L134 / L140 付近（partial / invalid の期待）

### P1B-12 replay audit の入力（R-027 / #1422 B-11）

- replay audit は #1395 が実行し、意味の正本は #1393。#1391 は、replay に必要な先行 accepted 事実（bound / verification / failure / policy / convergence / blockers / decision）をすべて accepted event として提供し、その event の構造と参照整合を保証する。replay 自体は持たない

### P1B-13 TA-87 adapter 境界の文書化（R-025）

- #1391 reopen AC「TA-87 adapter boundary documented」（現状: PR 本文のみ）に対し、`delivery_runtime.py` の adapter 境界（どの event を誰が作り、#1391 が何を検査し何を検査しないか）を `docs/ai/ai-loop-v2-delivery-adapter.md` に書く（新規。配置は exec 開始時に既存 `docs/ai/` の ai-loop V2 文書を再実測し、既存文書があればそこへ追記）

## Files / Components to Touch（R-031 / R-033 / R-035）

- `scripts/ai-loop-v2/run_event.py`
- `scripts/ai-loop-v2/run_evidence.py`
- `scripts/ai-loop-v2/delivery_runtime.py`（P1B-11 の例外処理、P1B-3 の binding 参照、L65 / L238 で convergence `observed_artifact_ref` と decision `artifact_ref` を出す — D-10）
- `scripts/ai-loop-v2/test_delivery_v2.py`（既存テストの更新と RED 追加。`terminal_unready` の期待値 — D-8。`test_run_event.py` / `test_run_evidence.py` は存在しないため作らない）
- `scripts/ai-loop-v2/test_ratchet.py`（`ratchet.py` の `validate_event` 依存の回帰確認、`terminal_unready` 受理の GREEN — D-11。現行 L468 付近が非成功 terminal を `ready` で扱う箇所）
- `tests/fixtures/ai-loop-v2/ratchet/evolution-input-non-success.json`（`HUMAN_ESCALATED` / `BLOCKED` の `evidence_status` を `terminal_unready` に — D-11）
- `docs/ai/ai-loop-v2/artifact-responsibilities.md`（L57 値域 / L63 定義に `terminal_unready` — D-11）
- `tests/extras/ta-87-ai-loop-v2-delivery-e2e.sh`（L260-263 の binding 参照、L117 の複製 oracle の `evidence_status` 判定 — D-8）
- `tests/extras/ta-93-ai-loop-v2-owner-backed-delivery.sh`（新 ready 条件での再実行。必要なら fixture 更新）
- `tests/fixtures/ai-loop-v2/delivery/*.json`（新 ready 条件で再実行。期待値が変わるなら更新。`no-progress-stop.json` L44 は `terminal_unready` — D-11。convergence / decision に必須 ref を追加 — D-10。EV-28h はこの更新後の状態で固定）
- `docs/ai/ai-loop-v2-delivery-adapter.md`（P1B-13）
- 新規 TA は作らない（既存 ta-87 / ta-93 を更新する）

## Work breakdown

### T1 — Preconditions

- `reviewed_at_sha` と base SHA を記録
- #1329 preflight（M-1 / M-2 / M-3 before）を記録
- **#1393 PF-5 合意（MAX_* の値・定義 module・バイト上限の適用範囲・decision_made key mapping）を確認。未合意なら exec に入らない（D-6）**
- #1392 / #1393 の現行 plan と照合（binding 引数、state イベント payload、convergence 語彙）
- 新語彙 `blockers_observed` / `policy_verdict_recorded` が #1047 の incident event 語彙と衝突しないこと、観測事実と原因仮説を分けていることを確認（R-028）

### T2 — RED（`test-cases.md` の Revision 2 / 2.1 追加分）

- P1B-1〜P1B-11 の各差分に RED を先に書き、`3331e5c4` で FAIL することを確認。各ケースに検査層（append / load）を付ける
- R-009 は実行再現を取る
- 既存 fixture `tests/fixtures/ai-loop-v2/delivery/*.json` と ta-87 / ta-93 を新 ready 条件で再実行し、期待が変わるものを列挙する（R-032）

### T3 — GREEN

- P1B-1〜P1B-11 を最小差分で実装。durable writer は持たない
- `validate_append` を append-only 層と whole-stream 層に分ける（R-037）

### T4 — Mutation / integration

- `test-cases.md` Mutation targets（11〜28）で検出力を確認
- `run_state` / `delivery_runtime` / `ratchet` / `test_delivery_v2` / `test_ratchet` / ta-87 / ta-93 が Phase 1B 後に緑（R-037）
- full `tests/run-tests.sh` と TA standalone

### T5 — Docs

- P1B-13 の adapter 境界文書

### T6 — Review

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
- #1393 PF-5 で decision_made の key 名が本 plan の提案と変わる（P1B-7 を改めて再 C-3）
- #1392 が「accepted stream は `validate_append` 経由のみ」を不変条件として保てない（R-045）
- #1395 の policy / blockers producer が入った（EV-28b / EV-28f の有効化は #1391 plan 改訂 + 再 C-3 — D-12）
