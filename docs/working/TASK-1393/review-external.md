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
| 内容による同一性が過去の区切りの観測を復活させる | Replan 前の D PASS が revert で同じ tree に戻り bound → 未実行のまま MERGE_READY | Rev2-R4 | 未是正（R-042） | SHA 同一性では revert も新 SHA で、同じ artifact に戻れなかった。R-037 の tree 化で初めて成立 |
| 解除条件の同一性が内容でなく名前 | 空 commit で artifact が「変わり」sticky FAIL と NO_PROGRESS が解除 | Rev2-R3 | 未是正（R-037） | R-036 で初めて SHA と定義され、sticky 化で解除条件が突破口になった |
| state の前提が state 内の後続観測で失効する | DIAGNOSING 入り後の CI 再実行 PASS で前提の FAIL が消え、DI-18 で張り付く | Rev2-R2 | R-030（artifact 単位の sticky FAIL） | R-022 の是正で同じ artifact 上の上書きが初めて生まれた |
| 後勝ちで FAIL を消す | flaky な verifier の FAIL→PASS で MERGE_READY | Rev2-R2 | R-031（同上） | R-022 以前は FAIL が常に勝っていた |
| revision の CAS が遷移を伴わない event を覆わない | 入力構築後の FAIL 記録が commit を止めない | Rev2-R2 | R-032（input_last_event_seq の CAS を #1392 に依頼） | 最新判定が無いうちは後続 event が判定を覆す構図が表に出なかった |
| fresh に時間順が無い | repair で artifact が変わらず同じ artifact に FAIL が 2 件 → I-5 で例外（NO_PROGRESS に届かない）。または呼び出し側が古い PASS だけ渡して MERGE_READY | Rev2-R1 | R-022（observed_seq と verifier ごとの最新） | R1〜R3 は「artifact が変わった後」だけを想定していた。同じ artifact の再検証は Rev2 の I-5 で初めて規則の対象になった |

### Revision 2 と敵対レビュー Rev2-R1（2026-09-25）

Human 設計判断（PR コメント 2026-09-25）に沿って plan / test-cases を作り直した（Revision 2）。R-015〜R-021 は設計変更で扱った（下の監査表）。その Revision 2 に対する独立エージェントの敵対レビュー:

判定: 要是正（未収束）。3 state × 入力の総当たりで結果は一意、step 8 は到達不能、遷移表は #1392 allowlist（`2f64beb0`）と一致。新クラス 1 件（R-022）、既出クラスの是正漏れ 4 件。

| ID | severity | 指摘 | クラス | 是正 |
|---|---|---|---|---|
| R-022 | major | fresh を artifact の一致だけで決めており時間順が無い。同じ artifact の再検証（repair で artifact が変わらない、CI 再実行）で I-5 が発火するか、呼び出し側が古い PASS を選べる | 新 | VerificationResult に `observed_seq`（#1391 の event 連番）。fresh =「束縛済みかつ verifier ごとの最新」。I-5 は同じ seq の重複のみ拒否。DV-16 / DV-17 / DD-10 / DP-13 / DI-28 |
| R-023 | major | `decided_in_state` と snapshot の state の照合が #1406 への依頼に無い。lifecycle_state を偽ると FR 必須・NO_PROGRESS を迂回できる | 既出（Decision と遷移の結びつき）の是正漏れ | #1406 に追加依頼（issuecomment-5826447020）。plan「Transition ownership」「Trust boundary」、IT-01 |
| R-024 | major | pr_convergence が current artifact に束縛されていない | 既出（R-002）の是正漏れ | `observed_artifact_ref` を必須にし P-2 で一致を検査。DI-27 |
| R-025 | major | required_verifiers の中身が LoopContract と照合されない | 既出（R-015）の是正漏れ | `loop_contract_ref` を必須（I-8）にして payload に記録。照合は #1395 / #1391（Trust boundary、IT-03） |
| R-026 | major | FIRST_ITERATION の真偽を誰も検査しない。ProgressAssessment を直接作れるかが未定義。payload に progress が残らない | 既出（R-017）の是正漏れ | ProgressAssessment は assess_progress からのみ。payload に progress 種別と fingerprint 集合。初回判定は #1395 / #1391（IT-05） |
| R-027 | minor | DI-09 の期待値が I-4 と食い違う | 既出（R-013） | I-4 を required_verifiers と results を合わせた検査に拡張 |
| R-028 | minor | VERIFYING の repair を repair round として数えると水増しになる | 新（軽微） | plan に語義を明記。repair round は DIAGNOSING / PR_CONVERGING の repair のみ |
| R-029 | info | PLAN_VERIFYING 後続化で Initial Plan Verification を判定する主体が第一リリースに無い | 既出（R-021） | Known limitations に残存リスクとして明記 |

共通の構造: R-023 / R-025 / R-026 と R-015 は「純関数の #1393 には検証できない、呼び出し側申告値の真偽」。個別の検査を #1393 に足すのではなく、plan に「Trust boundary」節を設け、値ごとに検証主体（#1392 / #1395 / #1391）と検査を割り当て、payload に記録して検査可能にした。これらの検査の実装は第一リリースの完了条件。

### 敵対レビュー Rev2-R2（2026-09-25）

判定: 要是正（未収束）。R-023 / R-024 / R-027 / R-028 / R-029 は閉じた。R-022 の是正（observed_seq と「verifier ごとの最新」）から新クラス 3 件。#1391 の `event_seq` は plan に存在（1 から +1、#1392 がロック内で採番、revision とは独立）。

| ID | severity | 指摘 | クラス | 是正 |
|---|---|---|---|---|
| R-030 | major | 最新だけが有効なため、DIAGNOSING に入った後の CI 再実行（PASS / unavailable）で前提の FAIL が消え、DI-18 で毎回例外 → DIAGNOSING に張り付く | 新「state の前提が state 内の後続観測で失効する」。前ラウンドは artifact だけで freshness が決まり、同じ artifact 上の上書きが無かった | 最新ではなく artifact 単位の verdict（FAIL は artifact が変わるまで固定）。DD-11 / DD-12 |
| R-031 | major | 後勝ちで FAIL が消え、flaky な verifier の「緑になるまで再実行」が MERGE_READY への正規経路になる | 新「後勝ちで FAIL を消す」。R-022 以前は FAIL が常に勝っていた | 同上（FAIL は sticky）。DV-17 の期待値を repair に変更 |
| R-032 | major | `verification_recorded` は revision を変えないため、入力構築後に記録された FAIL を revision の CAS が覆わない（TOCTOU） | 新「revision の CAS が遷移を伴わない event を覆わない」。最新判定が無いうちは後続 event が判定を覆す構図が無かった | `input_last_event_seq` を入力と payload に。#1392 に「stream 末尾の event_seq が超えていれば reject」を依頼。IT-04 |
| R-033 | major | payload が結果の中身を束縛していない。VerificationResult と event の対応が未定義 | 既出（契約値を無検証で信頼） | VerificationResult は受理済み `verification_recorded` event からのみ構築（`event_ref` / `observed_seq`）。payload に全 bound 結果の `event_ref` |
| R-034 | major | LoopContract を Run に束縛する event が無く、required_verifiers の照合元が存在しない | 既出（R-015 / R-025） | 「第一スライスでは未所有」と明記し、#1391 `plan_contract_bound` への束縛を Dependency / リリース条件に |
| R-035 | minor | verification_ref の一意性が無い | 既出（I-7） | I-5 に追加。DI-29 |
| R-036 | minor | artifact_ref と head SHA の名前空間が未定義 | 既出（R-024） | 第一スライスでは artifact ref = 候補の head commit SHA と定義 |

Trust boundary の脅威モデルも明記した: DecisionInput を組み立てる #1395 は Worker ではなく stream を読む決定的コードであり、防ぐ対象は Worker / fixture の自己申告と、構築から commit までの stream の変化。#1395 自体の欠陥は監査（stream から Decision を再計算して比較）で検出する。

### 敵対レビュー Rev2-R3（2026-09-25 / 上限ラウンド）

判定: 要是正（未収束）。R-030 / R-031 / R-033〜R-036 は閉じた（artifact 単位の verdict で順序非依存・結果一意、step 8 到達不能）。freshness モデル自体は安定し、新クラスは「解除条件と束縛の境界」に出た。**上限 3 ラウンドに達したため是正を止め、Human 判断へ返す**（以下は open）。

| ID | severity | 指摘 | クラス | 状態 |
|---|---|---|---|---|
| R-037 | major | artifact の同一性が commit SHA なので、空 commit / amend / rebase で「artifact が変わった」ことになり、sticky FAIL と NO_PROGRESS が同時に解除される → flaky な D の再実行で MERGE_READY | 新「解除条件の同一性が内容でなく名前」。R-036 で初めて SHA と定義され、sticky 化で解除条件が突破口として意味を持った | open（是正案: 同一性を tree hash に。SHA は head_sha として別に持つ） |
| R-038 | major | CAS の `expected_last_event_seq` と payload の `input_last_event_seq` の結びつきが無い。同じ transaction 内で decision_made より前に置いた FAIL は CAS も監査もすり抜ける | 既出（R-032 / R-016）の是正漏れ | open（是正案: #1391 の stream 検証に「decision_made の直前の event_seq == input_last_event_seq」。#1392 は decision_made を含む transaction で expected を必須化し payload と一致を要求） |
| R-039 | major | FailureRecord に event 束縛が無く、Trust boundary 表にも行が無い。repairability の取り違えを監査で検出できない | 既出（R-033）の是正漏れ（FR 側） | open（是正案: FR は受理済み `failure_recorded` event からのみ構築し、payload に event_ref と repairability） |
| R-040 | minor | 後続の FAIL で「latest FAIL」が動き、既存 FR が I-7 違反になる。「後続観測は前提を失効させない」は言い過ぎ | 既出（R-030） | open（是正案: 再診断を要すると明記し主体を #1395 に。または FR を入り口の FAIL に固定） |
| R-041 | minor | verdict を変えない同じ artifact 上の結果が evidence_delta に入るか未定義。入れば無限 repair、入れなければ NO_PROGRESS | 新（軽微）。sticky 導入で verdict と progress が同じ観測を別解釈 | open（是正案: evidence_delta から除外と定義） |

### 敵対レビュー Rev2-R4（2026-09-25 / Human 承認の追加 1 ラウンド）

判定: 要是正（未収束）。R-037 / R-038 / R-040 は閉じた（`+1` 規則は #1392 の手順 8 / 9 と合わせ、終端 `[decision_made]` と遷移 `[decision_made(n+1), state_transitioned(n+2)]` の 2 形で成立し正常系を壊さない。ただし #1392 head `2f64beb0` には依頼 4 件とも未反映）。R-039 は部分的、R-041 は定義上閉じた。新クラス 1 件。**追加ラウンドも収束しなかったため是正を止め、Human 判断へ返す**（以下は open）。

| ID | severity | 指摘 | クラス | 状態 |
|---|---|---|---|---|
| R-042 | major | 同一性を tree だけにしたため、revert で tree が戻ると、前の iteration や Replan 前の契約で記録した結果が再び bound になる。v2 で一度も実行していない D の旧 PASS で MERGE_READY | 新「内容による同一性が過去の区切りの観測を復活させる」。SHA のときは revert も新 SHA で、同じ artifact に戻ることが構造上なかった | open（是正案: bound に「observed_seq > 最新の plan_contract_bound の seq」を追加、または結果に loop_contract_ref を持たせる） |
| R-043 | major | 同じ FAIL に複数の failure_recorded があると #1395 が選べる。repairability の反転を監査で検出できない | 既出（R-022 / R-039）の是正漏れ | open（是正案: verification_ref ごとに FR 1 件を #1391 validate_append で強制、または最大 seq の FR を規則に） |
| R-044 | minor | evidence_delta の定義は結果集合から機械的に決まるのに入力値のまま。PR-10 は変異を殺せない（素通り） | 既出（R-026） | open（是正案: 純関数 `derive_evidence_delta` を #1393 に置き基準時点を定義） |
| R-045 | minor | 再診断は decision を生まないため、budget の単位（decision 回数）では数えられない | 今回の是正で発生（軽微） | open（是正案: budget に「failure_recorded 件数」を追加） |
| R-046 | minor | `+1` の load 時検査を #1392 だけに依頼しており、#1391 の stream 検証（監査経路）では掛からない。1 transaction に decision_made 2 件でも `+1` を満たせる | 既出（R-016 / R-038） | open（是正案: 規則を #1391 validate_append / validate_stream の所有に。「1 transaction に decision_made は 1 件」を依頼に追加） |

補足（残存脅威として明記を推奨）: tree 同一性でも 1 バイトの意味のない変更で tree は変わるため、sticky FAIL が保証するのは「同じ内容の再実行では緑にならない」ことだけで、変更後の flaky PASS を抑えるのは budget だけ。`+1` 規則を満たすには #1395 が入力の event を Decision より前の transaction で commit しておく必要がある。

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
| R-015 | reflected（Revision 2） | `492b85f7` | I-3 で kind を限定。中身の照合は R-025 |
| R-016 | reflected（Revision 2） | `492b85f7` | next_state を廃止し #1392 が導出（#1406 へ依頼）。decided_in_state 照合は R-023 |
| R-017 | reflected（Revision 2） | `492b85f7` | FIRST_ITERATION / P-1。初回判定の真偽は R-026 |
| R-018 | reflected（Revision 2） | `492b85f7` | step 4 DENIED → step 5 HUMAN_REQUIRED |
| R-019 | reflected（Revision 2） | `492b85f7` | DIAGNOSING は required FAIL 必須（state 別表）。DI-18 |
| R-020 | reflected（Revision 2） | `492b85f7` | I-7 |
| R-021 | reflected（範囲外を宣言） | `492b85f7` | #1395 の budget 4 経路をリリース条件に |
| R-022〜R-029 | reflected | `492b85f7` | Rev2-R1 節。R-022 の方式（verifier ごとの最新）は R-030 / R-031 で置き換え |
| R-030〜R-036 | reflected | `492b85f7` | Rev2-R2 節。R-032 は #1406 への依頼、R-034 は #1391 への Dependency |
| R-037〜R-041 | open | — | Rev2-R3 節。上限ラウンド到達で Human 判断待ち |
| R-037〜R-041 | reflected（Human 承認の追加ラウンドで是正） | （push 後に記入） | R-037 / R-038 / R-040 は Rev2-R4 で閉鎖確認。R-039 は R-043、R-041 は R-044 が残る |
| R-042〜R-046 | open | — | Rev2-R4 節。追加ラウンドも未収束で Human 判断待ち |
