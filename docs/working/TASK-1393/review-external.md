# EXTERNAL / FALLBACK REVIEW — TASK-1393 PLAN

Status: C-2 R1 未実施（下記 R-001〜R-006 は PR #1407 の独立レビュー（2026-09-24）と、その是正時の正本照合で出た指摘。C-2 の 2 ラウンドは別途必要）

Questions:
1. Is decision priority fail-closed and non-ambiguous?
2. Is mapping inconclusive -> HUMAN_ESCALATED/VERIFIER_UNAVAILABLE too coarse for current taxonomy?
3. Does repairability have a stable enough value contract?
4. Is PR convergence input too much authority for the Decision Engine?
5. Is freshness checking sufficient without head/source binding in every first-slice case?
6. Can model PASS influence any deterministic-failure branch?
7. Can the API accidentally accept Worker self-report or precomputed Outcome?
8. Does the EventDraft adapter stay pure and storage-free?

## 指摘（追記専用）

出典: PR #1407 コメント「独立レビュー（2026-09-24 / head `874f4fb2` / origin/main `d6a2216f`）」。R-005 / R-006 は是正時に `docs/ai/ai-loop-v2/taxonomy.md` と照合して追加。

| ID | severity | 指摘 | 是正 |
|---|---|---|---|
| R-001 | major | DENIED / HUMAN_REQUIRED を受けたときの結果が、「Decision order」1 では fail closed、「Policy scope」では `DecisionInputError` / unsupported-policy result と 2 通りに書かれていた | Human 裁定（2026-09-25「正本準拠」）: `DENIED` → step 4 で stop / BLOCKED / [POLICY_DENIED] の Decision を返す。`HUMAN_REQUIRED` と未知値 → step 0 で `DecisionInputError`。Policy scope は表 1 つに統一 |
| R-002 | minor | Freshness が PASS にしか掛かっておらず、古い artifact の FAIL で repair が再発火しうる | PASS と FAIL の両方を `current_artifact_ref` に拘束。stale FAIL は無視し、current artifact に結果が無ければ step 3（VERIFIER_UNAVAILABLE） |
| R-003 | minor | 「deterministic FAIL だが FailureRecord が無い」の期待値が Decision order に無かった | step 0 で `DecisionInputError`（呼び出し元の契約違反）。FailureRecord に `verification_ref` を追加して対応付けを判定可能にした |
| R-004 | minor | INDEX.md / current-state.md / decision-log.jsonl が無い | 生成 |
| R-005 | major | plan の Policy 語彙 `ALLOW` が正本（taxonomy §5: `AUTO_APPROVED` / `HUMAN_REQUIRED` / `DENIED`）に存在しない | `AUTO_APPROVED` に統一。`ALLOW` は未知値として `DecisionInputError`（DC-20e） |
| R-006 | major | Policy を判定順の先頭に置いていたが、正本 §5 は「Verdict は Verifier evidence の後に評価され、deterministic FAIL を上書きできない」 | Policy（DENIED）を step 4 へ移動。DENIED + fresh deterministic FAIL は repair/replan（DC-20c） |

### 是正差分への敵対レビュー（2026-09-25 / 独立エージェント / R-001〜R-006 是正後の作業ツリー）

§7-quater の 2 ラウンド目の観点（是正が効いているか・是正で生じた穴）。判定: 要是正。#1392 の遷移 allowlist は #1406 head `c48843ab` で実物照合済み。

| ID | severity | 指摘 | クラス | 是正 |
|---|---|---|---|---|
| R-007 | critical | 「required verifier に fresh な結果が無ければ step 3」としたが、`decide()` に required の集合が無い。required な verifier Y が stale FAIL のみ・別の X が fresh PASS のとき、FAIL が無視され MERGE_READY になる（是正前は repair）。どの step にも当たらないときの既定値も無かった | 新（R-002 の是正で発生） | `required_verifiers` を必須入力に追加（空は step 0）。step 3 を required 単位で定義。step 7 = 既定は stop / HUMAN_ESCALATED / [VERIFIER_UNAVAILABLE]。DC-03c / DC-04e と変異を追加 |
| R-008 | major | VERIFYING で観測したばかりの FAIL には FailureRecord が無いのが正常なのに、step 0 で例外にしていた。Decision の action と #1392 の遷移 allowlist が噛み合わない | 新（R-003 の是正で発生） | state ごとの表（受理する state / 必須入力 / Decision）を追加し、Decision に `next_state` を追加。VERIFYING の FAIL → continue / DIAGNOSING。FailureRecord 必須は DIAGNOSING / PR_CONVERGING のみ。PR_CONVERGING の replan_required は allowlist に辺が無く `DecisionInputError` |
| R-009 | major | HUMAN_REQUIRED を step 0（Verifier より前）で raise しており、§5 と Human 裁定「Verifier の後」に反する | R-006 と同型の是正漏れ | step 3a へ移動。DC-20f / DC-20g を追加 |
| R-010 | major | WAITING_* が step 1〜6 に進み、AI が Human 待ちを自律で抜けうる。「terminal lifecycle_state」が未定義 | 既出（state rule の曖昧さ）の是正漏れ | 受理する state を 4 つに限定し、それ以外（WAITING_* / PLANNING / EXECUTING / REPAIRING / REPLANNING / Outcome 名）は step 0。DC-01b〜01d |
| R-011 | major | fresh FAIL が複数あるとき（repairability の混在、同じ verifier の PASS と FAIL の同時存在）の規則が無い | 新 | replan_required が 1 件でもあれば replan。同じ verifier の PASS と FAIL は `DecisionInputError`。DC-04b / DC-04d |
| R-012 | minor | step 1 / 3 の停止に DENIED が隠れ、POLICY_DENIED が stop_reasons から消える | 新 | DENIED があれば outcome を BLOCKED にし、POLICY_DENIED を追加。DC-20h / DC-20i |
| R-013 | minor | test-cases の期待値が「not X」の形のままで、結果が 1 つに決まらない | 既出（R-003 と同型）の是正漏れ | 全 DC の期待値を action / next_state、outcome / stop_reasons、または例外まで固定 |
| R-014 | minor | repair のたびに artifact が変わるので NO_PROGRESS が発火せず、budget 系の Stop Reason も範囲外の宣言が無い | 新 | plan「Out of scope: budget and repetition」に所有者と残存リスクを明記。[P1 / Human] budget 無しで出してよいか |

収束判定: R2 で新クラスが 5 件（R-007 / R-008 / R-011 / R-012 / R-014）出たため未収束。R3 を実施する。

### 敵対レビュー R3（2026-09-25 / 独立エージェント / R-007〜R-014 是正後の作業ツリー）

判定: 要是正（未収束）。R-007〜R-014 は書かれた範囲では効いている（next_state は全件が #1392 allowlist `c48843ab` の辺。DC と plan の食い違いなし）。ただし R2 の是正から新クラスが 2 件出た。

| ID | severity | 指摘 | クラス | 状態 |
|---|---|---|---|---|
| R-015 | major | `required_verifiers` を無検証で信頼している。required={(M, independent_model)} だと、deterministic の結果が 0 件のまま MERGE_READY になる。Decision / EventDraft にも残らない。照合キーも `verifier_id` と `(verifier_id, kind)` が混在 | 新（R-007 の是正で発生） | open |
| R-016 | major | Decision に from_state が無く、`next_state` と #1392 が commit する実際の遷移を突き合わせる主体がどこにも無い。Decision は continue / DIAGNOSING なのに VERIFYING→PR_CONVERGING が commit されても、allowlist 上は正しい辺なので通る | 新（R-008 の是正で発生） | open（#1391 / #1392 と所有者を決める P1） |
| R-017 | major | 表の「Required inputs」のうち step 0 が強制するのは FailureRecord だけ。`progress=None` を渡せば NO_PROGRESS を無効化できる。`pr_convergence=None` も通る。ProgressAssessment は単数形で、複数 FR にも freshness にも対応していない | 既出（R-007 と同型: 入力の不在を有利な側に読む）の是正漏れ | open |
| R-018 | major | HUMAN_REQUIRED と DENIED が同時にあると、step 3a の raise が step 4 の BLOCKED より先に出る。denied された Run が非終端のまま残る | 既出（R-012 と同型）の是正漏れ | open |
| R-019 | minor | DIAGNOSING で fresh FAIL が無いと step 7 に落ち、事実と違う VERIFIER_UNAVAILABLE を出す | 新（step 7 の既定値で発生） | open |
| R-020 | minor | step 2 の replan_required 判定が、stale な FAIL を指す FR まで拾う | 既出（R-002 と同型）の是正漏れ | open |
| R-021 | minor | 上限の無い経路が他に 3 つある（PR_CONVERGING の continue / null、PLAN_VERIFYING ⇄ REPLANNING、HUMAN_REQUIRED 下での repair の継続）が、残存リスクに書かれていない | 既出（R-014 と同型）の是正漏れ | open |

収束判定: **未収束**。R1→R2→R3 と毎ラウンド新クラスが出ており（R2: 5 件、R3: 2 件）、R3 の新クラスはどちらも前ラウンドの是正で入れた入力・フィールドから生じた。§7-quater により、打ち切りではなく **設計モデルを疑う** 段階と判定し、継ぎ当ての是正を止めて Human に返す。

R3 の設計提案（未採否）: state 別の DecisionInput 契約（必須入力・許される kind・FailureRecord と fresh FAIL の対応・progress の「初回」と「省略」の区別）を 1 つの値にまとめ、step 0 で一括検査する。Decision には from_state と required_verifiers（または LoopContract ref）を記録し、Decision と実際の遷移の一致をどこで検査するかを #1391 / #1392 と決める。

#### 回避クラス台帳（追記専用）

| クラス | 代表例（最小再現） | 検出ラウンド | 是正 | 前ラウンドが見つけられなかった理由 |
|---|---|---|---|---|
| 入力の不在を有利な側に読む | required の verifier に stale 結果しか無い → 別 verifier の PASS で MERGE_READY | R2 | R-007（required_verifiers と step 7） | R1 の是正（stale FAIL を無視）で初めて「結果が無い」状態が生まれた |
| state と遷移の対応が無い | VERIFYING の FAIL を例外にし、DIAGNOSING への遷移が記録されない | R2 | R-008（state 表と next_state） | R1 は Decision を state から独立した値として見ていた |
| 呼び出し側が渡す契約値を無検証で信頼する | required={model だけ} で MERGE_READY | R3 | 未是正（R-015） | R2 の是正で新たに入った入力 |
| Decision と実際の遷移の結びつきが無い | Decision は DIAGNOSING、commit は PR_CONVERGING | R3 | 未是正（R-016） | R2 の是正で新たに入ったフィールド |

## 監査表（追記専用）

| R-ID | status | reflected_in(commit) | notes |
|---|---|---|---|
| R-001 | reflected | `6991816a` | [P1 / Human] HUMAN_REQUIRED → WAITING_HUMAN の遷移と記録は後続スライス |
| R-002 | reflected | `6991816a` | |
| R-003 | reflected | `6991816a` | |
| R-004 | reflected | `6991816a` | |
| R-005 | reflected | `6991816a` | |
| R-006 | reflected | `6991816a` | |
| R-007 | reflected | `6991816a` | |
| R-008 | reflected | `6991816a` | allowlist は #1406 `c48843ab` 準拠。#1392 の変更に追従が要る |
| R-009 | reflected | `6991816a` | |
| R-010 | reflected | `6991816a` | |
| R-011 | reflected | `6991816a` | |
| R-012 | reflected | `6991816a` | |
| R-013 | reflected | `6991816a` | |
| R-014 | reflected（範囲外を宣言） | `6991816a` | [P1 / Human] |
| R-015〜R-021 | open | — | 設計判断待ち（R3 節） |
