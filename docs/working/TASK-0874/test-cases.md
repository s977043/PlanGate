# TEST CASES — TASK-0874

> plan: [`plan.md`](./plan.md) / todo: [`todo.md`](./todo.md)
> Mode: **critical**（V-1 は全 TC を機械実行して突合する。目視 PASS を認めない）
> 実行系: `python3 scripts/ai-loop/test_run_evidence.py` / `python3 scripts/ai-loop/test_run_evidence_verify.py` / `sh tests/run-tests.sh </dev/null`（ta-58 経由）
> **TC 総数: 56**（TC-01 〜 TC-56・欠番なし）。AC は **16 件**（issue verbatim 13 + In scope 対応 3）。
> **C-1 FAIL 是正（2026-08-02）**: ①`required` の件数矛盾（TC-04 = 20 と TC-05 / T-5 = 21 が同時に PASS しない）を **21 に統一** ②TC-43 の恒等式を `metrics.py` 実装に合わせて是正し `run_count` の assert を **TC-54 に分離** ③受理器 exit code の `10` / `11` を**姉妹受理器 `c3prime_verify.py` の意味論に整合**（`10`=legacy / `11`=partial）④fixture の期待 exit を **一意化**（「1 または 10」を廃止）⑤AC 本文のカバレッジ穴に **TC-50 〜 TC-53 / TC-55 / TC-56** を追加。

## 用語と前提（実測に基づく固定値）

| 記号 | 意味 | 実測根拠 |
|------|------|---------|
| `EV` | RunEvidence record（`.json`・`json.dumps(ensure_ascii=False, indent=2, sort_keys=True) + "\n"`） | `plan_package.serialize_c3_prime()` L343 の形式 |
| `REC` | `docs/working/TASK-XXXX/delivery/record.jsonl`（append-only） | `delivery.record_path()` L441-442 |
| `C3` | `docs/working/TASK-XXXX/approvals/c3.json`（`approval_kind=c3-prime`） | `c3_contract.RECORD_REQUIRED_KEYS` = 14 キー |
| `ARB` | `docs/working/ai-loop-runs/*.json`（arbiter 裁定 record・**28 件**） | 9 キー 25 件 / 14 キー 3 件（実測） |
| 禁止キー 14 | `file_path` / `file_paths` / `stack_trace` / `stacktrace` / `command_output` / `stdout` / `stderr` / `raw_response` / `raw_request` / `api_key` / `user_prompt` / `system_prompt` / `prompt_text` / `absolute_path` | `scripts/hooks/check-metrics-privacy.sh` L37 |
| exit 契約 | `0`=complete / `1`=NG / **`10`=legacy** / **`11`=partial** | plan.md 論点 D6（`10`=legacy は `scripts/ai-loop/c3prime_verify.py` L67 と同一意味。`10` を legacy として消費する呼び出し側が `delivery.py` L530 / `bin/plangate` L1010 に実在） |
| known-unavailable 3 | `routing_decisions` / `replan_count` / `cost_metrics` | plan.md 論点 D7。**Phase 1 の producer 出力は必ずこの 3 つを `unavailable` として含む** → 受理器は必ず `11`（partial）。**Phase 1 で exit 0 は構造的に発生しない** |

> **注**: TC 番号は AC グループごとに連続していない箇所がある（TC-32 / TC-52 / TC-53 / TC-56 は AC-4、TC-33 は AC-7、TC-50 は AC-3、TC-51 は AC-6、TC-54 は AC-15、TC-55 は AC-13 に属する追加 TC）。`plan.md` の AC↔Step↔test-case 対応表と本ファイルの割当は一致している（機械照合で欠落・重複 0）。

---

## AC-1: RunEvidence schema と versioning policy がある

| TC | 前提条件 | 入力 | 期待出力 | 種別 |
|----|---------|------|---------|------|
| **TC-01** | `docs/schemas/run-evidence.schema.json` が存在する | ファイルを `json.load()` | 例外なくパースでき、`$schema` == `https://json-schema.org/draft/2020-12/schema` | Unit |
| **TC-02** | 同上 | schema の `$id` | **`https://github.com/s977043/plangate/schemas/run-evidence.schema.json`**（= 昇格後の URL。`schemas/` 配下 28 本の慣例に一致させ、HO patch を `git mv` 1 手に収める） | Unit |
| **TC-03** | 同上 | schema トップレベル | `additionalProperties == false`（`schemas/` の 78 箇所中 72 が false の既定スタイル）**かつ `patternProperties` のキー集合が `["^_"]`**。理由: 受理器は `^_` 注釈キーを許容する（TC-09）ため、`patternProperties` が無いと **schema が `_note` を拒否し受理器が許容する**食い違いになる。前例 `schemas/c3-prime.schema.json` は両方を持つ（実測: `additionalProperties=False` / `patternProperties=['^_']`） | Unit |
| **TC-04** | 同上 | schema の `required` | issue 本文の **20 フィールド**をすべて含む（`run_id, task_id, started_at, completed_at, repository, source_sha, final_head_sha, plan_hash, c3_prime_decision_ref, harness_version, routing_decisions, ci_outcomes, review_findings, repair_rounds, replan_count, human_interventions, terminal_state, quality_metrics, cost_metrics, evidence_refs`）**かつ `schema_version` を含む**。件数を `len()` で数えて **21** を assert する（目視で数えない）。⚠️ **`evidence_status` は含まない**（受理器が導出する語彙であり record に格納しない = plan D7-2） | Unit |
| **TC-05** | 契約 doc が存在する | `docs/workflows/ai-loop/run-evidence-contract.md` | versioning policy 節があり「破壊的変更（required 追加・型変更・正規化マッピング変更）は #872 / #873 / #874 の 3 issue 合意 + plan Replan を要する」と規定（c3-prime-contract §8 L137 と同一規則）。`schema_version` フィールドが schema の `required` に含まれる（**TC-04 の 21 件と整合**。version 不明の record を受理すると versioning policy が機械的に無効化されるため optional にしない。実測の前例: `schemas/*.schema.json` 28 本中 9 本が `schema_version` を required に持ち、properties にありながら required から外している schema は 0 本） | Unit |

## AC-4: missing / partial / tampered evidence を ready 扱いしない

| TC | 前提条件 | 入力 | 期待出力 | 種別 |
|----|---------|------|---------|------|
| **TC-06** | 受理器が存在する | 必須フィールド 1 個を削除した `EV` | **exit 1**（NG）。stderr に**欠落キー名**を含む | Unit（negative） |
| **TC-07** | 同上 | `routing_decisions` が `"unavailable"` の `EV`（他は完備） | **exit 11**（partial）。**exit 0 を返さない**。stderr に `unavailable` のフィールド名を列挙 | Unit（negative） |
| **TC-08** | 同上 | `plan_hash` を 1 文字書き換えた `EV`（tampered） | **exit 1**。stderr に「hash 不一致」と対象キー名 | Unit（negative） |
| **TC-09** | 同上 | 未知トップレベルキー `foo` を足した `EV` | **exit 1**（allowlist・`c3prime_verify.py` L73-75 の転写）。ただし `^_` 始まりの注釈キーは**許容**され exit 0 | Unit（negative + positive） |
| **TC-32** | 同上 | `approval_kind` キーを持たない legacy record / 9 キー ARB record | **exit 10**（legacy 委譲）。**exit 0 でも 1 でもない**（呼び出し側が legacy 経路を選べる）。`c3prime_verify.py` L62-67 の分岐と**同一の値・同一の意味**（当初案の `11` は姉妹受理器と意味が逆転していたため是正） | Unit（negative） |
| **TC-52** | producer | `routing_decisions` を**未供給**にした入力 / `routing_decisions: []` を**明示供給**した入力 の 2 本 | 前者の出力は `"unavailable"`、後者は `[]`。**両者が同じ値にならない**（`unavailable` を空配列で埋めると「routing 無し」と誤読され fail-open する）。producer 側の区別を固定する | Unit（negative + positive） |
| **TC-53** | producer | `delivery.assess()` が生成しない未知 `kind`（実在例: `kind=notice`・`executor.py` 由来）を含む `REC` | 未知 `kind` を**握り潰さない**。`escalation` に「未知 kind」と該当 `kind` 値を記録する。**黙って無視して正常終了しない** | Unit（negative） |
| **TC-56** | 受理器 | **全フィールドが available な合成 `EV`**（unit test 内で構築。known-unavailable 3 フィールドにも実値を入れる） | **exit 0**（complete）。理由: plan D7-1 により **Phase 1 の producer 出力からは exit 0 に到達しない**ため、fixture では `0` の経路を一度も通らない。受理器の `0` 判定が死にコード化していないことを合成入力で担保する | Unit（positive） |

## AC-2: 同一入力 events から同一 RunEvidence を再生成できる

| TC | 前提条件 | 入力 | 期待出力 | 種別 |
|----|---------|------|---------|------|
| **TC-10** | producer が存在する | 同一の `C3` + `REC` + `ARB` + 同一注入値（`--now` / `--started-at` / `--repository` / `--run-id`）で **2 回**生成 | 2 つの出力が **byte 完全一致**（`cmp -s` 相当）。改行・キー順・インデントまで一致 | Unit |
| **TC-11** | 同上 | 入力 dict のキー挿入順序を入れ替えて生成 | 出力は TC-10 と **byte 一致**（`sort_keys=True` により順序非依存） | Unit |
| **TC-12** | 同上 | `--now` を渡さずに生成 | **エラー**（`now()` を内部で呼ばない = 決定論の担保）。producer のソースに `datetime.now` / `time.time` / `utcnow` が **0 件**であることをソース走査でも固定（`delivery.py` の純判定器ソース走査 TC と同型） | Unit（negative + ソース走査） |

## AC-3: Plan hash / C-3' / final head SHA / CI / review / routing / terminal state が同一 run へ結合される

| TC | 前提条件 | 入力 | 期待出力 | 種別 |
|----|---------|------|---------|------|
| **TC-13** | `C3`（`approval_kind=c3-prime`・`decision=AUTO_APPROVED`）+ `REC`（`kind=merge_ready` を含む） | producer 実行 | 出力 `EV` の `plan_hash` == `C3.plan_hash` / `source_sha` == `C3.source_sha` / `c3_prime_decision_ref` が `C3` への **repo 相対パス**を含む | Integration |
| **TC-14** | 同上 | 同上 | `final_head_sha` == `REC` の `kind=merge_ready` entry の `record.head_sha`。`ci_outcomes` が `record.check_summary` の全 check 名を含む（件数を `len()` で照合） | Integration |
| **TC-15** | 同上 | 同上 | `review_findings` が `record.review_disposition` の全 finding id を含む。`repair_rounds` == `delivery._completed_rounds(entries, pr)` の戻り値と**一致**（producer 側で再実装せず import して照合） | Integration |
| **TC-16** | `REC` の最終 `kind=state` が `HUMAN_ESCALATED` | producer 実行 | `terminal_state == "HUMAN_ESCALATED"` かつ `human_interventions[]` が非空。**`MERGE_READY` にならない** | Integration |
| **TC-50** | 同 TC-13 の前提 | producer 実行 | 出力 `EV` に `routing_decisions` キーが**存在し**、Phase 1 では値が `"unavailable"`（#868 OPEN のため供給元が無い）。かつ **同一 `EV` 内で `plan_hash` / `final_head_sha` / `terminal_state` と同じ `run_id` に結合されている**（AC-3 の「routing が同一 run へ結合される」を Phase 1 で機械検証できる唯一の形）。⚠️ 当初 AC-3 の割当 TC（TC-13〜16）には **routing を検査する TC が 1 件も無かった**（C1-TEST-13 ① 是正） | Integration |

## AC-5: observation と cause hypothesis が分離される

| TC | 前提条件 | 入力 | 期待出力 | 種別 |
|----|---------|------|---------|------|
| **TC-17** | schema | schema の `properties` | `observation` と `cause_hypothesis` が**別フィールド**として定義され、型・description が異なる（`observation` = 観測事実 / `cause_hypothesis` = 推定） | Unit |
| **TC-18** | producer | `cause_hypothesis` を注入せずに生成 | 出力の `cause_hypothesis` が **`null` または `unavailable`**。producer が観測値から**推定を自動生成しない**（生成すると FAIL）。同じ入力で `observation` は非空 | Unit（negative） |

## AC-6: hidden CoT / raw transcript / secret を要求・保存しない

| TC | 前提条件 | 入力 | 期待出力 | 種別 |
|----|---------|------|---------|------|
| **TC-19** | producer | 禁止キー 14 個を含む events を入力 | 出力 `EV` に禁止キーが **0 件**（producer 側の機械検査。握り潰さず入力側の異常として `escalation` に記録） | Unit |
| **TC-20** | producer | `evidence_refs` に絶対パス `/Users/foo/bar.json` を注入 | **エラー**（reject）。`metrics-privacy.md` §5「絶対パス `/Users/.../` は FORBIDDEN」 | Unit（negative） |
| **TC-21** | 出力形式 | producer が書き出すファイル名 | 拡張子が **`.json`**（`.jsonl` でない）。理由: EH-8 の走査対象 `case "$f" in *.json\|*.ndjson)` に `.jsonl` は**マッチしない**（実測）ため、`.jsonl` だと privacy 検査を素通りする | Unit |
| **TC-51** | producer | `account` / `login` / `github_user` 等の **account 識別子**を含む events を入力 | 出力 `EV` に account 識別子が **0 件**（キー名・値の両方を走査）。⚠️ EH-8 の禁止キー 14 個に account 系は**含まれない**（実測: `scripts/hooks/check-metrics-privacy.sh` L37）ため、**hook 層では素通りする**。したがって producer 側の検査が唯一の防御線になる（C1-TEST-13 ② 是正） | Unit（negative） |
| **TC-22** | 10 fixture が生成済み | `git add tests/fixtures/run-evidence/` した状態で `scripts/hooks/check-metrics-privacy.sh` を実行 | **PASS**（BLOCK されない）。自主規制ではなく **hook で証明**する。TASK-0917 では同 hook が実際に `stdout`/`stderr` を BLOCK した実績がある（`docs/working/TASK-0917/evidence/e2e/RAW-EXCLUDED.md`） | E2E |

## AC-7: #869 が RunEvidence のみから shadow candidate を生成できる

| TC | 前提条件 | 入力 | 期待出力 | 種別 |
|----|---------|------|---------|------|
| **TC-23** | adapter が存在する | `to_shadow_candidate_input([EV, EV, EV])`（同型 3 件） | candidate input dict が返る。`source_run_ids` の要素数 == 3、各要素が入力 `EV` の `run_id` と一致 | Unit |
| **TC-24** | 同上 | adapter のソース | adapter 関数が **`EV` 以外のファイルを読まない**（引数以外の I/O が無いことをソース走査 + monkeypatch で固定。`open` / `pathlib.Path.read_*` が呼ばれない） | Unit（ソース走査） |
| **TC-33** | 同上 | 2 件だけの `EV` リスト | **candidate を生成しない**（issue の必須 fixture 8 は「**3 件以上**の同型 Run から」と指定）。閾値未満は明示的に `insufficient_evidence` を返す | Unit（negative） |

## AC-8: candidate が source_run_ids と baseline harness version を保持する

| TC | 前提条件 | 入力 | 期待出力 | 種別 |
|----|---------|------|---------|------|
| **TC-25** | adapter | `to_shadow_candidate_input()` の出力 | キー **`source_run_ids`** と **`baseline_version`** が存在する。⚠️ **`baseline_harness_version` という綴りを使わない**（実測: repo にも issue にも 0 件。#869 issue 本文の実在綴りは `baseline_version`） | Unit |
| **TC-26** | 同上 | 入力 `EV` 群の `harness_version` が**全件同一** | `baseline_version` がその値と一致。入力 `EV` 群の `harness_version` が**混在**する場合は candidate を生成せず `mixed_baseline` で reject（baseline が定義できない run 群から候補を作らない） | Unit（positive + negative） |

## AC-9: improvement TASK が通常の Plan-first / C-3' / PR 収束を通る

| TC | 前提条件 | 入力 | 期待出力 | 種別 |
|----|---------|------|---------|------|
| **TC-27** | adapter | candidate から派生した improvement TASK の記述子 | `plan_package_required == True` かつ `c3_prime_required == True` かつ `merge_by_ai == False`。**通常ゲートを迂回するフラグが存在しない**ことを、記述子のキー集合 allowlist で固定（`skip_c3` / `auto_merge` 等のキーが現れたら FAIL） | Unit（契約レベル） |

## AC-11: #811 promotion decision と改善 PR/commit を追跡できる

| TC | 前提条件 | 入力 | 期待出力 | 種別 |
|----|---------|------|---------|------|
| **TC-28** | adapter | `to_promotion_provenance(candidate, decision)` | #811 Trust Ledger の実測綴り（`candidate_id` / `decision` / `promoted_to` / `evidence_count` / `canary_scope` / `rollback_count`）を含む dict が返る。`evidence_count` == `len(source_run_ids)` | Unit |
| **TC-29** | 同上 | 改善 PR / commit を与える | `improvement_refs[]` に PR 番号と commit SHA（`[0-9a-f]{7,40}`）が入り、`source_run_ids` から**双方向に辿れる**（candidate_id → improvement_refs / improvement_refs → source_run_ids） | Unit |

## AC-12: active run の harness version が途中で変化しない

| TC | 前提条件 | 入力 | 期待出力 | 種別 |
|----|---------|------|---------|------|
| **TC-30** | producer | run 開始時注入 `harness_version = X`、終了時注入も `X` | 出力 `EV.harness_version == X`・exit 0 | Unit |
| **TC-31** | 同上 | 開始時 `X` / 終了時 `Y`（≠ X） | **エラー**（fail-closed）。stderr に「harness_version が run 中に変化」と両値を出力。**警告に降格しない** | Unit（negative） |

> **注（U-1 依存）**: 本 2 TC は `harness_version` の**値の意味論に依存しない**（注入値の byte 一致のみを見る）。したがって U-1（定義）が C-3 で未確定でも実装・検証できる。定義が確定したら `harness_version` の**構造**を検証する TC を追加する（V2 候補）。

## AC-10: paired replay / 独立 grader / activation check / rollback を source candidate へ戻せる

| TC | 前提条件 | 入力 | 期待出力 | 種別 |
|----|---------|------|---------|------|
| **TC-34** | adapter | baseline 側 `EV` 群 + candidate 側 `EV` 群（fixture 9） | `paired_replay` 結果 dict が `candidate_id` を保持し、`baseline_run_ids` / `candidate_run_ids` が**互いに素**（同一 run を両側に数えない）。`grader_ref` と `activation_check` が独立キーとして存在 | Unit |
| **TC-35** | adapter | failed canary の結果（fixture 10） | `rollback` 結果が source candidate へ戻り、`candidate.status` が `rolled_back` に遷移する。`rollback_count` が **+1** される。**`status` が `approved` のままにならない** | Unit（negative 起点） |

## AC-13: 未解決の正本へ自動 promotion しない fail-closed 条件がある

| TC | 前提条件 | 入力 | 期待出力 | 種別 |
|----|---------|------|---------|------|
| **TC-36** | adapter | `blocked_by = ["#866"]` を持つ candidate | `to_promotion_provenance()` が **`BLOCKED`** を返す。`approve` / `approve_with_conditions` を返さない | Unit（negative） |
| **TC-55** | adapter | `blocked_by` キーを**持たない** candidate（未注入） | `to_promotion_provenance()` が **`BLOCKED`** を返す（判定不能は安全側へ倒す）。⚠️ 「非空なら BLOCKED」だけを実装すると、**`blocked_by` を誰も埋めない限り常に非 BLOCKED** となり AC-13 が fail-open する。「未解決なし」と解釈するのは **明示的に `blocked_by: []` を注入した場合のみ**（`unavailable` と空配列を区別する本 PBI の原則と同型 = TC-52）。供給元自体は U-12 で C-3 判断 | Unit（negative） |
| **TC-37** | 同上 | adapter のソース | **issue 番号がハードコードされていない**（`grep -c '#86[0-9]' run_evidence.py` == 0）。判定は `blocked_by[]` 非空という汎用条件。理由: 実測で **#862 は CLOSED / #866 は OPEN** であり、番号ハードコードは CLOSE 時に stale 化する | Unit（ソース走査） |

## AC-14: c3-prime-contract §7 への #874 consumer 追記 + §4 全規則の fail-closed 再検証

| TC | 前提条件 | 入力 | 期待出力 | 種別 |
|----|---------|------|---------|------|
| **TC-38** | 契約 doc | `docs/workflows/ai-loop/c3-prime-contract.md` §7 | **#874 consumer 節**が存在し、読むフィールドとして `task_id` / `decision` / `source_sha` / `plan_hash` / `plan_package_hash` の **5 つ**を列挙（§7 L131 が #873 向けに列挙した 5 つと同一集合） | Unit |
| **TC-39** | 同上 | `git diff origin/main -- docs/workflows/ai-loop/c3-prime-contract.md` | **§1〜§6 と §8 の行が変更されていない**（追記は §7 のみの additive）。§8 は既に「#872 / #873 / #874 の 3 issue 合意」を含む（L137 実測）ため**重複追記しない** | Unit |
| **TC-40** | producer | `C3` の `plan_hash` を現 `plan.md` と不一致にした状態で producer 実行 | **エラー**（fail-closed）。producer が `c3prime_verify.main()` を呼び出して rc==0 を要求する構造（`delivery.verify_c3()` L498-509 と同型）であることを monkeypatch で固定 | Integration（negative） |
| **TC-41** | producer | `C3.decision == "HUMAN_ESCALATED"` | producer は record を生成するが `terminal_state == "HUMAN_ESCALATED"`。**`decision` を無検証で信頼して `MERGE_READY` に倒さない**（§7 L133 の trust boundary） | Integration |

## AC-15: legacy record との migration / compatibility が機械検証可能

| TC | 前提条件 | 入力 | 期待出力 | 種別 |
|----|---------|------|---------|------|
| **TC-42** | 分類関数 | `docs/working/ai-loop-runs/` の**実データ 28 件** | `legacy_count == 25` / `run_count == 3` / `invalid_run_meta_count == 0` / `skipped_count == 0`。**`metrics.py --format json` の現行出力と一致**（`metrics.py` の 4 分類ロジックを転写した結果の同値性） | Integration |
| **TC-43** | 同上 | 同上 | 恒等式 **`total_records == len(legacy_records) + len(invalid_meta_records) + len(run_records)`** が成立（`metrics.py` L235-238 の構造転写。全件がどれかに帰属し、無言で消えるレコードが 0）。⚠️ **右辺に `run_count` を置かない**（C1-TEST-14 ② 是正）: 実測で `run_count = len(grouped)`（L240）は `_group_by_run()` 後の **distinct `run_id` 数**であり、1 run が複数 record を持つ入力では `len(run_records)` と一致しない。現データ 28 件では**偶然一致するため回帰では検出できない**（`run_count=3` かつ run record も 3 件）。**1 run に 2 record を持つ合成入力**で恒等式を検証すること | Unit |
| **TC-54** | 同上 | 1 つの `run_id` に **2 件**の run record を持つ合成入力（+ 実データ 28 件） | `run_count == len(set(run_id))`（distinct 数）であり、**`len(run_records)` とは別物**であることを assert。合成入力では `len(run_records)=2` に対し `run_count=1` になる（TC-43 から分離した片割れ） | Unit |
| **TC-44** | 同上 | 破損 JSON 1 行 / 非 dict / `decision` 欠落 の 3 パターン | いずれも `skipped` に**理由文字列付き**で入る（fail-silent 禁止。`metrics.py` L75-96 の 3 分岐転写）。例外で落ちない | Unit（negative） |
| **TC-45** | 位置づけ | producer 実行後の `docs/working/ai-loop-runs/` | 既存 **28 件が 1 バイトも変更されていない**（`git diff --stat docs/working/ai-loop-runs/` が空）。RunEvidence は arbiter record の**後継ではなく上位 artifact**であり、置き換えも移行も行わない | E2E |

## AC-16: 10 fixture が ta-58 で CI 実行され、AC↔fixture 対応表が残る

| TC | 前提条件 | 入力 | 期待出力 | 種別 |
|----|---------|------|---------|------|
| **TC-46** | `tests/extras/ta-58-run-evidence.sh` が存在 | `sh tests/run-tests.sh </dev/null` | exit 0。**ta-58 のブロックが出力に現れる**（glob source で拾われている）。`</dev/null` を付けないと `precompact-memory-guard.sh` でハングするため必須 | E2E |
| **TC-47** | 同上 | 同上の出力 | `test_run_evidence.py` と `test_run_evidence_verify.py` の **2 本**が PASS 行として現れる（1 モジュール 1 PASS 行）。**目視でなく grep で確認**。理由: `run-tests.sh` は python を一切呼ばず `ta-*.sh` を glob source するだけなので、導線が無いと新規 unit test が**一度も実行されない**（TASK-0917 R-020 の実害型） | E2E |
| **TC-48** | golden fixture 10 件 | 各 fixture を producer で再生成し committed golden と比較 | **10/10 が byte 一致**。件数を `len(glob)` で数えて **10** を assert する（「10 件ある」と書くだけにしない） | E2E |
| **TC-49** | `tests/run-tests.sh` | `git diff origin/main -- tests/run-tests.sh` | **差分 0 行**（`tests/extras/README.md` L35「`tests/run-tests.sh` の本体には触れない」の遵守。glob loader が自動発見するため改変不要） | Unit |

---

## 必須 fixture（10 件）↔ AC 対応表（AC-16 が要求する成果物）

issue #874 本文の fixture 定義を verbatim で保持し、各 fixture が検証する AC と golden ファイル名を対応させる。

| # | fixture（issue verbatim） | golden ファイル | 主に検証する AC | 期待 `terminal_state` / 受理器 exit |
|---|--------------------------|----------------|----------------|-----------------------------------|
| 1 | first-pass MERGE_READY | `tests/fixtures/run-evidence/fx-01-first-pass.json` | AC-2 / AC-3 / AC-12 | `MERGE_READY` / **11** |
| 2 | CI repair あり MERGE_READY | `fx-02-ci-repair.json` | AC-3（`ci_outcomes` / `repair_rounds`） | `MERGE_READY` / **11** |
| 3 | review repair あり MERGE_READY | `fx-03-review-repair.json` | AC-3（`review_findings`） | `MERGE_READY` / **11** |
| 4 | HUMAN_ESCALATED | `fx-04-human-escalated.json` | AC-3 / AC-14（trust boundary） | `HUMAN_ESCALATED` / **11** |
| 5 | BLOCKED | `fx-05-blocked.json` | AC-3（c3-prime 層由来の terminal） | `BLOCKED` / **11** |
| 6 | routing escalation あり | `fx-06-routing-escalation.json` | AC-3（`routing_decisions[]`）**#868 未実装のため粒度は暫定** | `HUMAN_ESCALATED` / **11** |
| 7 | partial / tampered evidence | `fx-07-tampered-expected-errors.json`（**期待エラー列**を格納。受理された record ではない） | AC-4 | — / **ケースごとに一意**: `tampered` → **1** / `partial` → **11**（**いずれも 0 を返さない**） |
| 8 | 3 件以上の同型 Run から shadow candidate 生成 | `fx-08-shadow-candidate-input.json` | AC-7 / AC-8 | — |
| 9 | baseline / candidate paired replay | `fx-09-paired-replay.json` | AC-10 | — |
| 10 | failed canary から rollback | `fx-10-canary-rollback.json` | AC-10 / AC-13 | — |

> **fixture 1〜6 の期待受理器 exit がすべて `11`（partial）である理由**（C1-PLAN-04 の是正 / plan D7）:
> Phase 1 では **known-unavailable 3 フィールド**（`routing_decisions` = #868 OPEN / `replan_count` = 供給元不在 / `cost_metrics` = `events.ndjson` が gitignore）が
> **構造的に `unavailable` にしかならない**ため、producer が出力する RunEvidence は必ず `unavailable` を含み、受理器は必ず partial を返す。
> 当初表は fixture 1〜5 に **exit 0** を期待していたが、**その `0` に到達する経路は存在しない**（fixture 側で routing を捏造すれば到達するが、
> 「空配列で埋めない」「手書き fixture を実 record と乖離させない」という本 plan 自身の方針に反する）。
> **`terminal_state` の期待値は不変**（`terminal_state` と `evidence_status` は直交する）。
> 受理器の exit 0 は **合成 complete EV**（TC-56）で別途検証する。
> ⚠️ **U-10 が「known-unavailable allowlist を設ける」に決まった場合、本表の 1〜6 は `0` に戻し TC-56 を fixture 側へ移す**。
>
> **fixture 7 の期待値を一意にした理由**（C1-TEST-14 ③ の是正）: 決定論 producer の golden で「1 または 10」のような二値の期待値は検証にならない。
> ただし **fixture を 11 件に増やさない**（issue #874 が必須 fixture を 10 件と verbatim 指定し TC-48 が `len(glob) == 10` を assert するため）。
> したがって 1 ファイル内で `tampered` / `partial` の 2 ケースを保持し、**ケースごとに期待 exit を一意に固定**する。
>
> **fixture 2 の入力形状の一次根拠**: `docs/working/TASK-0917/evidence/e2e/run/delivery/record.jsonl`（**実測 3 行** = `kind=intent` 1 / `kind=notice` 1 / `kind=receipt` 1）。TASK-0917 の実 PR 1 周の実走証跡であり、手書き fixture が実 record と乖離することを防ぐ照合先として使う。
> ⚠️ この実 record には `delivery.assess()` が生成しない **`kind=notice`**（`executor.py` 由来）が含まれる。producer は未知 `kind` を**無視せず** `escalation` として記録する（TC-19 と同じ「握り潰さない」方針）。

## Edge cases（TC への割当）

| Edge case | 割当 TC | 期待 |
|-----------|--------|------|
| `record.jsonl` の破損行 | TC-44 | 理由付きで `skipped`・例外で落ちない |
| `entry_id` の改竄（保存値と再計算値が不一致） | TC-08 | fail-closed（`delivery.load_entries()` L465-471 の再計算照合と同型） |
| `c3.json` が legacy（`approval_kind` キーなし） | TC-32 | **exit 10**（legacy 委譲。`c3prime_verify.py` L62-67 が `return 10` を返すのと**同一の値・同一の意味**。当初記載の「exit 11」は同 L62-67 と非同型だった = C1-B1B2-17 是正） |
| 非終端 run（`WAITING_FOR_CHECKS` 等 6 状態 + `EXEC_RETURN`） | TC-16 | **RunEvidence を発行しない**（plan D3 の安全側既定。発行拒否をエラーとして返す）。**U-4 が C-3 で `IN_PROGRESS` 採用に決まった場合は本行と TC-16 を改訂** |
| known-unavailable フィールドを含む `EV`（Phase 1 の全 run） | TC-07 / TC-56 | **exit 11**（partial）。`partial` の理由は **known-unavailable のみ**（非終端 run はそもそも発行しないため、`partial` が 2 つの事象を指して曖昧化しない） |
| 未知 `kind` entry（`kind=notice` 等） | TC-53 | `escalation` に記録して握り潰さない |
| `blocked_by` キーが未注入 | TC-55 | **`BLOCKED`**（判定不能は安全側） |
| account 識別子を含む events | TC-51 | 出力に 0 件（EH-8 の禁止キー 14 個では捕捉できないため producer 側で検査） |
| arbiter record 0 件（`docs/working/ai-loop-runs/` が空） | TC-42 | `legacy_count=0` / `run_count=0` で例外なく完了（分母 0 は `None` + `N/A`。`metrics.py` L226-230 の転写） |
| `evidence_refs` に絶対パス | TC-20 | reject |
| `harness_version` が run 中に変化 | TC-31 | fail-closed |
| 入力 `EV` 群の `harness_version` が混在 | TC-26 | `mixed_baseline` で candidate 生成を拒否 |
| 同型 Run が 2 件しかない | TC-33 | `insufficient_evidence`（3 件以上が issue 指定） |
| 出力を `.jsonl` にしてしまう | TC-21 | 拡張子検査で FAIL（EH-8 の走査対象から外れるため） |

## V-1 実行時の突合手順

1. `python3 scripts/ai-loop/test_run_evidence.py` → exit 0
2. `python3 scripts/ai-loop/test_run_evidence_verify.py` → exit 0
3. `sh tests/run-tests.sh </dev/null` → exit 0 かつ **exec 開始時（T-2）に記録した baseline + ta-58 の新規 PASS 行数**を下回らない
4. `git add tests/fixtures/run-evidence/` の状態で `sh scripts/hooks/check-metrics-privacy.sh` → PASS（TC-22）
5. `git diff --stat origin/main -- scripts/ai-loop/delivery.py scripts/ai-loop/c3_contract.py scripts/ai-loop/c3prime_verify.py scripts/ai-loop/arbiter.py scripts/ai-loop/metrics.py docs/working/ai-loop-runs/ tests/run-tests.sh` → **0 行**（不変対象）
6. 上記 56 TC のうち **未実行 / SKIP が 0 件**であることを確認（SKIP は環境依存を理由に許容せず、理由を handoff に記録）
