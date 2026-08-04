# TEST CASES — TASK-0874

> plan: [`plan.md`](./plan.md) / todo: [`todo.md`](./todo.md)
> Mode: **critical**（V-1 は全 TC を機械実行して突合する。目視 PASS を認めない）
> 実行系: `python3 scripts/ai-loop/test_run_evidence.py` / `python3 scripts/ai-loop/test_run_evidence_verify.py` / `sh tests/run-tests.sh </dev/null`（ta-59 経由）
> **TC 総数: 65**（TC-01 〜 TC-65・欠番なし）。AC は **16 件**（issue verbatim 13 + In scope 対応 3）。
> **C-1 FAIL 是正（2026-08-02）**: ①`required` の件数矛盾（TC-04 = 20 と TC-05 / T-5 = 21 が同時に PASS しない）を **21 に統一** ②TC-43 の恒等式を `metrics.py` 実装に合わせて是正し `run_count` の assert を **TC-54 に分離** ③受理器 exit code の `10` / `11` を**姉妹受理器 `c3prime_verify.py` の意味論に整合**（`10`=legacy / `11`=partial）④fixture の期待 exit を **一意化**（「1 または 10」を廃止）⑤AC 本文のカバレッジ穴に **TC-50 〜 TC-53 / TC-55 / TC-56** を追加。
> **C-2 反映（2026-08-02 / `review-external.md` R-001 〜 R-C10）**: ①**D3 正規化マッピングの負側 TC を新設**（**TC-57**（`MERGE_READY`）/ **TC-58**（`BLOCKED` + delivery 層 4 フィールド `unavailable`）/ **TC-59**（非終端 7 状態を parametrized で発行拒否）= R-001 / R-003。当初 `terminal_state` を assert する TC は TC-16 / TC-41（どちらも `HUMAN_ESCALATED`）のみだった）②**TC-60**（`quality_metrics` の run 単位限定 = R-005）③**TC-61 / TC-62**（schema ↔ 受理器 ↔ producer の機械束縛 = R-008）④**TC-63**（producer の入力ソース allowlist = AC-6 の「要求しない」側 / R-010）⑤**TC-64**（`pr_number` 未解決 → `repair_rounds` は `unavailable` / R-C04）⑥**TC-65**（全フィールド値の絶対パス検査 / R-C09(a)）⑦**TC-08 / TC-09 の前提を是正**（受理器署名 `<ev.json> <task_dir>` / `^_` positive は合成 complete EV 限定 = R-004 / R-006）⑧**TC-03 の assert を `patternProperties["^_"]["type"] == "string"` まで深化**（R-C05）⑨**TC-22 を `PLANGATE_HOOK_FILES` 実走へ是正**（privacy CI が `tests/fixtures/` を除外 = R-C03）⑩**ta-58 → ta-59**（main に `ta-58-git-destructive-guard.sh` が実在・#968）⑪Edge cases の「非終端 run」割当を **TC-16 → TC-59** へ付け替え。**TC 総数 56 → 65**。

## 用語と前提（実測に基づく固定値）

| 記号 | 意味 | 実測根拠 |
|------|------|---------|
| `EV` | RunEvidence record（`.json`・`json.dumps(ensure_ascii=False, indent=2, sort_keys=True) + "\n"`） | `plan_package.serialize_c3_prime()` L343 の形式 |
| `REC` | `docs/working/TASK-XXXX/delivery/record.jsonl`（append-only） | **記号アンカー = `delivery.record_path()`**（実測 L441-442。⚠️ C-2 R-C06 の「実際は L439-440」は**実測と一致せず本表の記述が正しい**。行番号は stale 化するため以後は関数名で参照する） |
| `C3` | `docs/working/TASK-XXXX/approvals/c3.json`（`approval_kind=c3-prime`） | `c3_contract.RECORD_REQUIRED_KEYS` = 14 キー |
| `ARB` | `docs/working/ai-loop-runs/*.json`（arbiter 裁定 record・**28 件**） | 9 キー 25 件 / 14 キー 3 件（実測） |
| 禁止キー 14 | `file_path` / `file_paths` / `stack_trace` / `stacktrace` / `command_output` / `stdout` / `stderr` / `raw_response` / `raw_request` / `api_key` / `user_prompt` / `system_prompt` / `prompt_text` / `absolute_path` | `scripts/hooks/check-metrics-privacy.sh` L37 |
| exit 契約 | `0`=complete / `1`=NG / **`10`=legacy** / **`11`=partial** | plan.md 論点 D6（`10`=legacy は `scripts/ai-loop/c3prime_verify.py` の `return 10  # legacy` と同一意味。消費側は `delivery.py` の `rc == 10`〔厳密比較〕と `bin/plangate` の `_plangate_c3_dispatch` 後段〔**0/1 以外を legacy にする catch-all** = C-2 R-C07〕） |
| 受理器 署名 | `run_evidence_verify.py <ev.json> <task_dir>` | plan.md 論点 D6（C-2 R-004。**EV 単体入力では tampered を検出できない**ため `task_dir` を必須にする） |
| 注入値 | `--now` / `--started-at` / `--repository` / `--run-id`（未注入はエラー）/ **`--pr-number`**（未解決は `unavailable`） | plan.md 論点 D2（C-2 R-C04） |
| known-unavailable (a) | `routing_decisions` / `replan_count` / `cost_metrics`（**Phase 1 固定 3**） | plan.md 論点 D7。**Phase 1 の producer 出力は必ずこの 3 つを `unavailable` として含む** → 受理器は必ず `11`（partial）。**Phase 1 で exit 0 は構造的に発生しない** |
| known-unavailable (b) | `final_head_sha` / `ci_outcomes` / `review_findings` / `repair_rounds`（**`terminal_state` 依存・最大 4**） | plan.md 論点 D7 のマトリクス（C-2 R-003）。**`terminal_state=BLOCKED` は `record.jsonl` 自体が存在しない**ため delivery 層の 4 フィールドが構造的に取得不能。`MERGE_READY` / `HUMAN_ESCALATED` では必須 |

> **注**: TC 番号は AC グループごとに連続していない箇所がある（TC-32 / TC-52 / TC-53 / TC-56 は AC-4、TC-33 は AC-7、TC-50 は AC-3、TC-51 は AC-6、TC-54 は AC-15、TC-55 は AC-13 に属する追加 TC）。`plan.md` の AC↔Step↔test-case 対応表と本ファイルの割当は一致している（機械照合で欠落・重複 0）。

---

## AC-1: RunEvidence schema と versioning policy がある

| TC | 前提条件 | 入力 | 期待出力 | 種別 |
|----|---------|------|---------|------|
| **TC-01** | `docs/schemas/run-evidence.schema.json` が存在する | ファイルを `json.load()` | 例外なくパースでき、`$schema` == `https://json-schema.org/draft/2020-12/schema` | Unit |
| **TC-02** | 同上 | schema の `$id` | **`https://github.com/s977043/plangate/schemas/run-evidence.schema.json`**（= 昇格後の URL。`schemas/` 配下 28 本の慣例に一致させ、HO patch を `git mv` 1 手に収める） | Unit |
| **TC-03** | 同上 | schema トップレベル | `additionalProperties == false`（`schemas/` の 78 箇所中 72 が false の既定スタイル）**かつ `patternProperties` のキー集合が `["^_"]`**。理由: 受理器は `^_` 注釈キーを許容する（TC-09）ため、`patternProperties` が無いと **schema が `_note` を拒否し受理器が許容する**食い違いになる。さらに **`patternProperties["^_"]["type"] == "string"`** を assert する（実測の前例値は `{"^_": {"type": "string", "description": …}}` であり、受理器 `c3prime_verify.py` も `if k.startswith("_") and not isinstance(v, str): return _fail(...)` で**型を検査**する。`{}` にすると `{"_note": {"a": 1}}` が **schema を通り受理器が reject する**逆向きの食い違いになる = C-2 R-C05） | Unit |
| **TC-04** | 同上 | schema の `required` | issue 本文の **20 フィールド**をすべて含む（`run_id, task_id, started_at, completed_at, repository, source_sha, final_head_sha, plan_hash, c3_prime_decision_ref, harness_version, routing_decisions, ci_outcomes, review_findings, repair_rounds, replan_count, human_interventions, terminal_state, quality_metrics, cost_metrics, evidence_refs`）**かつ `schema_version` を含む**。件数を `len()` で数えて **21** を assert する（目視で数えない）。⚠️ **`evidence_status` は含まない**（受理器が導出する語彙であり record に格納しない = plan D7-2） | Unit |
| **TC-05** | 契約 doc が存在する | `docs/workflows/ai-loop/run-evidence-contract.md` | versioning policy 節があり「破壊的変更（required 追加・型変更・正規化マッピング変更）は #872 / #873 / #874 の 3 issue 合意 + plan Replan を要する」と規定（c3-prime-contract §8 と同一規則）。`schema_version` フィールドが schema の `required` に含まれる（**TC-04 の 21 件と整合**。version 不明の record を受理すると versioning policy が機械的に無効化されるため optional にしない。実測の前例: `schemas/*.schema.json` 28 本中 9 本が `schema_version` を required に持ち、properties にありながら required から外している schema は 0 本。⚠️ **構造前例の `schemas/c3-prime.schema.json` は `schema_version` を properties にも required にも持たない**（実測）— この非対称を契約 doc に書かないと `schemas/` 昇格レビューで「c3-prime に合わせて落とす」是正が入りうる = C-2 R-C10 ②） | Unit |
| **TC-61** | schema + 受理器 | `schema["required"]` の集合 と 受理器が要求する必須キー集合 | **完全一致**（受理器は schema を**唯一の正**として読み `required` を導出する。ハードコードしない）。⚠️ 当初計画では TC-01〜05 が schema 単体、TC-06〜09 が受理器のハードコード実装を検査するだけで、**両者が一致する保証がどこにも無かった**。乖離しても 56 TC は全緑のまま Phase 2 の HO patch 昇格時に既存 EV が一斉 reject され、裁定の「1 回の HO patch で昇格」が破綻する（C-2 R-008） | Unit |
| **TC-62** | schema + producer | producer 出力の全キー（required 21 + `observation` / `cause_hypothesis` / `escalation`） | **全キー ⊆ `schema["properties"]` ∪ `^_` パターン**。⚠️ `additionalProperties: false` の下で **`escalation` が properties 未登録だと、privacy 違反や未知 `kind` を検知した EV — 最も検証が必要な EV — だけが reject される**（C-2 R-008）。Risks の当初 Fallback「schema と producer の乖離は golden byte 比較で検出」は**成立しない**（golden 比較は producer 出力同士の比較で schema を参照しない）ため撤回済み | Unit |

## AC-4: missing / partial / tampered evidence を ready 扱いしない

| TC | 前提条件 | 入力 | 期待出力 | 種別 |
|----|---------|------|---------|------|
| **TC-06** | 受理器が存在する（署名 `run_evidence_verify.py <ev.json> <task_dir>`） | 必須フィールド 1 個を削除した `EV` | **exit 1**（NG）。stderr に**欠落キー名**を含む | Unit（negative） |
| **TC-07** | 同上 | `routing_decisions` が `"unavailable"` の `EV`（他は完備） | **exit 11**（partial）。**exit 0 を返さない**。stderr に `unavailable` のフィールド名を**全数列挙**する（partial の理由が 2 分類〔(a) Phase 1 固定 / (b) `terminal_state` 依存〕にまたがるため、**曖昧化しない担保は「理由が 1 種類であること」ではなく「理由が機械可読に列挙されること」に置く** = C-2 R-003） | Unit（negative） |
| **TC-08** | 同上。**`<task_dir>` に整合する `C3` / `REC` が実在する** | `plan_hash` を 1 文字書き換えた `EV`（tampered） | **exit 1**。stderr に「hash 不一致」と対象キー名。⚠️ **受理器が `<task_dir>/approvals/c3.json` を再読込して照合する構造でなければ本 TC は実装不能**（`sha256:`+64hex 形式を保った 1 文字改変は形式上正当であり、EV 単体入力では検出できず **known-unavailable により exit 11 で通過し、改竄された provenance が promotion まで到達しうる** = C-2 R-004）。`entry_id` 不一致は `<task_dir>/delivery/record.jsonl` の再計算照合で検出する | Unit（negative） |
| **TC-09** | 同上 | ①未知トップレベルキー `foo` を足した `EV` ②`^_` 注釈キー（string 値）を足した**合成 complete `EV`** ③`^_` 注釈キーに**非 string 値**を入れた `EV` | ① **exit 1**（allowlist・**記号アンカー = `c3prime_verify.py` の `unknown = [k for k in data if k not in ALLOWED_KEYS and not k.startswith("_")]`** の転写）② **exit 0**（許容）⚠️ **合成 complete EV でない限り D7-1 により `11` になる**ため、positive 側の入力は TC-56 と同じ合成 EV を使う（C-2 R-006）③ **exit 1**（`^_` の値は string のみ = C-2 R-C05） | Unit（negative + positive） |
| **TC-32** | 同上 | `approval_kind` キーを持たない legacy record / 9 キー ARB record | **exit 10**（legacy 委譲）。**exit 0 でも 1 でもない**（呼び出し側が legacy 経路を選べる）。**記号アンカー = `c3prime_verify.py` の `return 10  # legacy` 分岐**と**同一の値・同一の意味**（当初案の `11` は姉妹受理器と意味が逆転していたため是正） | Unit（negative） |
| **TC-52** | producer | `routing_decisions` を**未供給**にした入力 / `routing_decisions: []` を**明示供給**した入力 の 2 本 | 前者の出力は `"unavailable"`、後者は `[]`。**両者が同じ値にならない**（`unavailable` を空配列で埋めると「routing 無し」と誤読され fail-open する）。producer 側の区別を固定する | Unit（negative + positive） |
| **TC-53** | producer | `delivery.assess()` が生成しない未知 `kind`（実在例: `kind=notice`・`executor.py` 由来）を含む `REC` | 未知 `kind` を**握り潰さない**。`escalation` に「未知 kind」と該当 `kind` 値を記録する。**黙って無視して正常終了しない** | Unit（negative） |
| **TC-56** | 受理器 | **全フィールドが available な合成 `EV`**（unit test 内で構築。known-unavailable 3 フィールドにも実値を入れる） | **exit 0**（complete）。理由: plan D7-1 により **Phase 1 の producer 出力からは exit 0 に到達しない**ため、fixture では `0` の経路を一度も通らない。受理器の `0` 判定が死にコード化していないことを合成入力で担保する | Unit（positive） |

## AC-2: 同一入力 events から同一 RunEvidence を再生成できる

| TC | 前提条件 | 入力 | 期待出力 | 種別 |
|----|---------|------|---------|------|
| **TC-10** | producer が存在する | 同一の `C3` + `REC` + `ARB` + 同一注入値（`--now` / `--started-at` / `--repository` / `--run-id`）で **2 回**生成 | 2 つの出力が **byte 完全一致**（`cmp -s` 相当）。改行・キー順・インデントまで一致 | Unit |
| **TC-11** | 同上 | 入力 dict のキー挿入順序を入れ替えて生成 | 出力は TC-10 と **byte 一致**（`sort_keys=True` により順序非依存） | Unit |
| **TC-12** | 同上 | `--now` を渡さずに生成 | **エラー**（`now()` を内部で呼ばない = 決定論の担保）。producer のソースに `datetime.now` / `time.time` / `utcnow` が **0 件**であることをソース走査でも固定（`delivery.py` の純判定器ソース走査 TC と同型） | Unit（negative + ソース走査） |
| **TC-60** | producer | 同一 run の入力に対し、**`docs/working/ai-loop-runs/` に record を 1 件追加した前後**で生成 | 出力 `EV` が **byte 一致**（`quality_metrics{}` が **当該 run の events だけで閉じる指標**〔`first_pass` / `rounds`〕のみを持ち、corpus 集計値〔`decision_counts` / `round_distribution` / `hotl_health` / `first_pass_rate`〕を**含まない**ことを合わせて assert）。⚠️ 実測で `metrics.py` の当該 4 指標は `collect(runs_dir)` が **全 record を横断集計**した値（`hotl_health = _compute_hotl_health(decision_counts, grouped)` / `first_pass_numerator / first_pass_denominator` はいずれも全 run が分母）。EV に格納すると **arbiter record が 1 件増えるだけで過去 run の EV の byte が変わり**、AC-2 と TC-48 が**後日 CI で原因不明に赤くなる**（C-2 R-005） | Unit |

## AC-3: Plan hash / C-3' / final head SHA / CI / review / routing / terminal state が同一 run へ結合される

| TC | 前提条件 | 入力 | 期待出力 | 種別 |
|----|---------|------|---------|------|
| **TC-13** | `C3`（`approval_kind=c3-prime`・`decision=AUTO_APPROVED`）+ `REC`（`kind=merge_ready` を含む） | producer 実行 | 出力 `EV` の `plan_hash` == `C3.plan_hash` / `source_sha` == `C3.source_sha` / `c3_prime_decision_ref` が `C3` への **repo 相対パス**を含む | Integration |
| **TC-14** | 同上 | 同上 | `final_head_sha` == `REC` の `kind=merge_ready` entry の `record.head_sha`。`ci_outcomes` が `record.check_summary` の全 check 名を含む（件数を `len()` で照合） | Integration |
| **TC-15** | 同上 | 同上 | `review_findings` が `record.review_disposition` の全 finding id を含む。`repair_rounds` == `delivery._completed_rounds(entries, pr)` の戻り値と**一致**（producer 側で再実装せず import して照合） | Integration |
| **TC-16** | `REC` の最終 `kind=state` が `HUMAN_ESCALATED` | producer 実行 | `terminal_state == "HUMAN_ESCALATED"` かつ `human_interventions[]` が非空。**`MERGE_READY` にならない**。⚠️ **本 TC は非終端 run を扱わない**（Edge cases の「非終端 run」割当は **TC-59** へ付け替え済み = C-2 R-001） | Integration |
| **TC-50** | 同 TC-13 の前提 | producer 実行 | 出力 `EV` に `routing_decisions` キーが**存在し**、Phase 1 では値が `"unavailable"`（#868 OPEN のため供給元が無い）。かつ **同一 `EV` 内で `plan_hash` / `final_head_sha` / `terminal_state` と同じ `run_id` に結合されている**（AC-3 の「routing が同一 run へ結合される」を Phase 1 で機械検証できる唯一の形）。⚠️ 当初 AC-3 の割当 TC（TC-13〜16）には **routing を検査する TC が 1 件も無かった**（C1-TEST-13 ① 是正）。⚠️ **Phase 1 では routing の値そのものは検証できない**（#868 OPEN・fixture 6 も `routing_decisions` が `"unavailable"` のため routing 値のカバレッジは 0 = C-2 R-002） | Integration |
| **TC-57** | `C3`（`decision=AUTO_APPROVED`）+ `REC` に **`kind=merge_ready` entry が物理的に存在する** | producer 実行 | `terminal_state == "MERGE_READY"`。**`kind=merge_ready` の物理存在のみが唯一の条件**（記号アンカー = `delivery.assess()` の `state = "MERGE_READY"` 分岐が刻む唯一の経路）。**最終 `kind=state` が `MERGE_READY_CANDIDATE` の `REC` を与えたときに `MERGE_READY` へ丸めない**ことを対で assert する。⚠️ **当初 `MERGE_READY` の導出を検査する TC は 0 件**であり、producer が最終 `kind=state` を見て丸めても 56 TC のどれも落ちなかった（C-2 R-001） | Integration |
| **TC-58** | `C3.decision == "BLOCKED"`（= exec に到達していない）。**`<task_dir>/delivery/record.jsonl` が存在しない** | producer 実行（fixture 5 相当） | `terminal_state == "BLOCKED"` で **RunEvidence が発行される**。かつ **delivery 層 4 フィールド（`final_head_sha` / `ci_outcomes` / `review_findings` / `repair_rounds`）がすべて `"unavailable"`**（**空文字・ダミー sha・`0` で埋めない**）。受理器は **exit 11**（`unavailable` の内訳が (a) Phase 1 固定 3 + (b) `terminal_state` 依存 **5**〔`quality_metrics` を含む〕の計 **8** であることを stderr で確認 = R2 MN-2 是正）。⚠️ **当初 D7 は known-unavailable を 3 件と断定しており、`BLOCKED` で `record.jsonl` 不在になる経路が未定義だった**（実装者がダミー値で埋めるか exit 1 に倒すかで、どちらに転んでも plan と矛盾した）= C-2 R-003 | Integration |
| **TC-59** | 非終端 7 状態を **parametrized で全数**（`WAITING_FOR_CHECKS` / `WAITING_FOR_REVIEW` / `CHECKS_FAILED` / `CONFLICT` / `REVIEW_REPAIR` / `MERGE_READY_CANDIDATE` / `EXEC_RETURN`） | 各状態を最終 `kind=state` に持つ `REC` で producer 実行 | **7 件すべてで RunEvidence を発行しない**（発行拒否をエラーとして返す）。**1 件でも `MERGE_READY` / `HUMAN_ESCALATED` / `BLOCKED` を返したら FAIL**。⚠️ plan Risks が「7 状態すべての負側 TC」と書きながら **対応 TC が 1 件も存在しなかった**（C-2 R-001）。**U-4 が `IN_PROGRESS` 採用に決まった場合は本 TC を改訂** | Integration（negative） |
| **TC-64** | `REC` に `kind=merge_ready` が無く `--pr-number` も未注入 | producer 実行 | `repair_rounds == "unavailable"`。**`0` にならない**。⚠️ 実測で `delivery._pr_receipts(entries, pr)` は `e.get("pr_number") == pr` で絞るため `pr=None` では `pr_number` を持たない entry だけが残り、`_completed_rounds()` は `max(rounds, default=0)` により **例外ではなく `0`（= 修理 0 回）を黙って返す**（実在の一次証跡で `(entries, 940) = 1` / `(entries, None) = 0` を実測）。`0` に倒すと **#869 の first-pass 判定が汚染される**（C-2 R-C04）。`ci_outcomes` / `review_findings` も同様に `unavailable` | Unit（negative） |

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
| **TC-51** | producer | `account` / `login` / `github_user` 等の **account 識別子**を含む events を入力 | 出力 `EV` に account 識別子が **0 件**（キー名・値の両方を走査）。⚠️ EH-8 の禁止キー 14 個に account 系は**含まれない**（実測: `scripts/hooks/check-metrics-privacy.sh` L37）ため、**hook 層では素通りする**。したがって producer 側の検査が唯一の防御線になる（C1-TEST-13 ② 是正）。⚠️ **判定基準は U-5 の C-3 結論に従って確定する**（C-2 B→A-5）: 実在の一次証跡 `TASK-0917/evidence/e2e/run/delivery/record.jsonl` の `notice` は `comment_url`（`https://github.com/s977043/PlanGate/pull/940#issuecomment-…`）を、`receipt` は同 URL を含む `result_ref` を保持しており、**「値の中の account 識別子 0 件」を厳格適用すると実 record 由来の PR / コメント参照がすべて落ち、AC-11 の `improvement_refs[]` と両立しない** | Unit（negative） |
| **TC-63** | producer のソース + monkeypatch | producer 実行時に open される全ファイルパス | **入力ソース allowlist 4 種のみ**（`approvals/c3.json` / `delivery/record.jsonl` / `docs/working/ai-loop-runs/*.json` / 注入値）。**transcript / session log / CoT / 環境変数 / ネットワーク / 外部プロセスを読まない**ことをソース走査 + monkeypatch で固定（TC-24 と同型の走査を producer にも置く）。⚠️ AC-6 verbatim は「**要求も保存もしない**」だが、当初の TC-19〜22 / TC-51 は**すべて出力側**であり、「producer の**入力契約**が transcript を要求しない」ことを固定する TC が無かった（C-2 R-010） | Unit（ソース走査 + monkeypatch） |
| **TC-65** | producer | 絶対パスを含む値（`/Users/foo/x.json` / `/var/folders/…`）を任意のフィールド（`evidence_refs` **以外**も含む。例: 転写した `skipped[].file`）に持つ入力 | 出力 `EV` の**全フィールドの値**に絶対パス（`^/` または `/Users/` を含む文字列）が **0 件**。⚠️ EH-8 は **禁止キー名（ダブルクォート込み）に `:` が後続する形を `grep -E` で走査する**だけであり **値を一切見ない**（実測: `{"file": "/var/folders/xx/tmpABC/foo.json"}` は `PLANGATE_HOOK_STRICT=1` でも **PASS**）。当初の絶対パス検査は `evidence_refs` **限定**だったため、別キーに絶対パスが載ると `metrics-privacy.md` §4/§5 違反のまま commit される（C-2 R-C09(a)） | Unit（negative） |
| **TC-22** | 10 fixture が生成済み | **ta-59 の中から** `PLANGATE_HOOK_STRICT=1 PLANGATE_HOOK_FILES="<10 fixture のパス>" sh scripts/hooks/check-metrics-privacy.sh` を実行 | **PASS**（BLOCK されない）。自主規制ではなく **hook で証明**する。⚠️ **`git add` + staged 検出に頼ってはいけない**: `.github/workflows/metrics-privacy.yml` の scan 対象決定は `git diff --name-only … \| grep -E '\.(json\|ndjson)$' \| grep -v '^tests/fixtures/'` で **`tests/fixtures/` を明示除外**しており（実測）、`.claude/settings.example.json` の hooks にも EH-8 は**存在しない**。⇒ **本 PBI が commit する 10 ファイルに対してだけ CI の自動強制が効かない**ため、ta-59（`tests/run-tests.sh` の glob source で CI job `plangate CLI tests` に必ず乗る）に内蔵して回帰保護を持たせる（C-2 R-C03）。TASK-0917 では同 hook が実際に `stdout`/`stderr` を BLOCK した実績がある（`docs/working/TASK-0917/evidence/e2e/RAW-EXCLUDED.md`） | E2E |

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

> ⚠️ **Phase 1 は契約層のみ（C-2 R-007）**: TC-27 は「本 PBI が定義した記述子のキー集合を本 PBI が検査する」構造であり、
> **実フロー（improvement TASK が実際に Plan-first / C-3' / PR 収束を通ること）は #869 / #811 実装後**に検証される。
> issue #874 の DoD は「#869 shadow mode がfixture から candidate を生成する統合 test」を要求しており、
> **本 PBI 完了時点で AC-9 の DoD は充足不能**。この限定を明記しないと C-3 の読み手には充足済みに見える。

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

> **追加検証（TC 番号外 / R2 MJ-3 由来）**: TC-30 / TC-31 はいずれも `--harness-version-end` が
> **注入されている**前提であり、**未注入時に drift 検査が走らないこと**を 65 TC のどれも検査していなかった。
> caller が渡し忘れた run は「検査して同一だった `EV`」と受理側で区別できないため、契約 §4-1 に
> `escalation.harness_drift_unchecked` を追加し、以下 4 件を追加した（TC 番号は増やさない）:
>
> | 追加テスト | 位置 | 期待 |
> |-----------|------|------|
> | `test_unchecked_drift_is_recorded_in_escalation` | `test_run_evidence.py` | `--harness-version-end` 未注入 → `escalation` に `harness_drift_unchecked` |
> | `test_checked_drift_leaves_no_unchecked_escalation` | 同上 | 注入時は積まない（常時付与では情報量 0） |
> | `test_unchecked_harness_drift_is_partial_not_complete` | `test_run_evidence_verify.py` | 全 available でも `exit 11`（`complete` にしない） |
> | `test_other_escalation_kinds_do_not_block_complete` | 同上 | `unknown_record_kind` 等は `complete` を妨げない |

**注（U-1 依存）**: 本 2 TC は `harness_version` の**値の意味論に依存しない**（注入値の byte 一致のみを見る）。したがって U-1（定義）が C-3 で未確定でも実装・検証できる。定義が確定したら `harness_version` の**構造**を検証する TC を追加する（V2 候補）。

## AC-10: paired replay / 独立 grader / activation check / rollback を source candidate へ戻せる

> ⚠️ **Phase 1 は契約層のみ（C-2 R-007 / U-9）**: TC-34 は `grader_ref` / `activation_check` の**キー存在**を見るだけであり、
> **独立 grader も activation check も本 PBI では実装しない**（実測で canary の機械契約は ai-loop 正本に存在せず、
> #869 の `canary_plan` / #811 の `canary_scope` はいずれも未実装）。**実フローの検証は #811 実装後**。

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
| **TC-38** | 契約 doc | `docs/workflows/ai-loop/c3-prime-contract.md` §7 | **#874 consumer 節**が存在し、読むフィールドとして `task_id` / `decision` / `source_sha` / `plan_hash` / `plan_package_hash` の **5 つ**を列挙（§7 が #873 向けに列挙した 5 つと同一集合） | Unit |
| **TC-39** | 同上 | `git diff origin/main -- docs/workflows/ai-loop/c3-prime-contract.md` | **§1〜§6 と §8 の行が変更されていない**（追記は §7 のみの additive）。§8 は既に「#872 / #873 / #874 の 3 issue 合意」を含む（実測）ため**重複追記しない** | Unit |
| **TC-40** | producer | `C3` の `plan_hash` を現 `plan.md` と不一致にした状態で producer 実行 | **エラー**（fail-closed）。producer が `c3prime_verify.main()` を呼び出して rc==0 を要求する構造（**記号アンカー = `delivery.verify_c3()`**。実測 L498-505 で当初記載の L498-509 は範囲過大 = C-2 R-C06）であることを monkeypatch で固定 | Integration（negative） |
| **TC-41** | producer | `C3.decision == "HUMAN_ESCALATED"` | producer は record を生成するが `terminal_state == "HUMAN_ESCALATED"`。**`decision` を無検証で信頼して `MERGE_READY` に倒さない**（§7 の trust boundary） | Integration |

## AC-15: legacy record との migration / compatibility が機械検証可能

| TC | 前提条件 | 入力 | 期待出力 | 種別 |
|----|---------|------|---------|------|
| **TC-42** | 分類関数 | `docs/working/ai-loop-runs/` の**実データ**（T-2 baseline 時点 28 件） | **`metrics.py --format json` の現行出力と一致**（`legacy_count` / `invalid_run_meta_count` / `run_count` / `skipped_count` / `total_records` の 5 キーを同値照合。`metrics.py` の 4 分類ロジックを転写した結果の同値性）。⚠️ **絶対件数を assert しない**（R2 MJ-5 是正）: `docs/working/ai-loop-runs/` は gitignore 対象外で ai-loop の実運用ごとに record が commit されるため（実測: run-021 / run-023 / run-025 の追加履歴）、`== 25` と書くと次の run 記録が main に入った瞬間に**無関係な PR の CI が赤くなる**。非空振り担保は下限（`legacy_count >= 25` / `run_count >= 3`・T-2 baseline 実測値）で置く | Integration |
| **TC-43** | 同上 | 同上 | 恒等式 **`total_records == len(legacy_records) + len(invalid_meta_records) + len(run_records)`** が成立（**記号アンカー = `metrics.py` の `collect()` 末尾の集計ブロック**の構造転写。全件がどれかに帰属し、無言で消えるレコードが 0）。⚠️ **右辺に `run_count` を置かない**（C1-TEST-14 ② 是正）: 実測で `run_count = len(grouped)` は `_group_by_run()` 後の **distinct `run_id` 数**であり、1 run が複数 record を持つ入力では `len(run_records)` と一致しない。現データ 28 件では**偶然一致するため回帰では検出できない**（`run_count=3` かつ run record も 3 件）。**1 run に 2 record を持つ合成入力**で恒等式を検証すること。⚠️ 恒等式以外に**件数の絶対値を assert しない**（R2 MJ-5・TC-42 と同じ理由。非空振り担保は `loaded_records > 0`） | Unit |
| **TC-54** | 同上 | 1 つの `run_id` に **2 件**の run record を持つ合成入力（+ 実データ 28 件） | `run_count == len(set(run_id))`（distinct 数）であり、**`len(run_records)` とは別物**であることを assert。合成入力では `len(run_records)=2` に対し `run_count=1` になる（TC-43 から分離した片割れ） | Unit |
| **TC-44** | 同上 | 破損 JSON 1 行 / 非 dict / `decision` 欠落 の 3 パターン | いずれも `skipped` に**理由文字列付き**で入る（fail-silent 禁止。**記号アンカー = `metrics.py` の `_load_records()` 内 `skipped.append({"file": …, "reason": …})` 3 分岐**の転写。⚠️ `file` の値は絶対パスになりうるため EV へ転記する際は repo 相対へ正規化する = C-2 R-C09(a)）。例外で落ちない | Unit（negative） |
| **TC-45** | 位置づけ | producer 実行後の `docs/working/ai-loop-runs/` | 既存 record が **1 バイトも変更されていない**（件数に依存しない検査）（`git diff --stat docs/working/ai-loop-runs/` が空）。RunEvidence は arbiter record の**後継ではなく上位 artifact**であり、置き換えも移行も行わない | E2E |

## AC-16: 10 fixture が ta-59 で CI 実行され、AC↔fixture 対応表が残る

| TC | 前提条件 | 入力 | 期待出力 | 種別 |
|----|---------|------|---------|------|
| **TC-46** | `tests/extras/ta-59-run-evidence.sh` が存在（⚠️ **番号は exec 開始時に `git ls-tree origin/main --name-only tests/extras/` で再実測**。`ta-58` は #968 で使用済み） | `sh tests/run-tests.sh </dev/null` | exit 0。**ta-59 のブロックが出力に現れる**（glob source で拾われている）。`</dev/null` を付けないと `precompact-memory-guard.sh` でハングするため必須 | E2E |
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
| 5 | BLOCKED | `fx-05-blocked.json` | AC-3（c3-prime 層由来の terminal）**+ TC-58**（delivery 層 4 フィールドが `unavailable`） | `BLOCKED` / **11**（`unavailable` は **(a)3 + (b)5 = 8 件**。**(b) は 5** — `final_head_sha` / `ci_outcomes` / `review_findings` / `repair_rounds` に加え `quality_metrics` が従属する。当初記載の「(b)4 = 7 件」は `quality_metrics` の従属を計上していなかった〔実装・契約 §5-1・`test_tc58_blocked_fixture_has_eight_unavailable_fields` はいずれも 8〕= R2 MN-2 是正） |
| 6 | routing escalation あり | `fx-06-routing-escalation.json` | AC-3（`routing_decisions[]`）⚠️ **Phase 1 では `routing_decisions` の値カバレッジが 0**（下記） | `HUMAN_ESCALATED` / **11** |
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
>
> **一次証跡で裏が取れる範囲 / 手書きに留まる範囲（C-2 レーン B → 設計妥当性 返送論点 4）**
>
> | 区分 | 対象 |
> |------|------|
> | **実 record で裏が取れる** | entry の共通キー形状（`action_id` / `action_kind` / `at` / `entry_id` / `kind`）・`pr_number` / `round` の実在と型・`repair_ci` の `taxonomy` / `failed_checks` / `head_sha`・`comment_url` / `result_ref` / `repair_commit_sha` の実在 |
> | **手書きに留まる**（実 record に存在しない） | **`kind=state`** / **`kind=merge_ready`** / `record.check_summary` / `record.review_disposition` / `record.plan_hash` |
>
> ⇒ **D3 正規化マッピングの中核（`MERGE_READY` / `HUMAN_ESCALATED` / `BLOCKED` の導出）について、この一次証跡は根拠を与えない**。
> したがって TC-57 / TC-58 / TC-59 は合成入力で構築し、**「実走証跡があるから大丈夫」と読み替えない**。
>
> **fixture 6 が Phase 1 で vacuous であること（C-2 R-002・plan 既定は (b) = 明示して進む）**
>
> `routing_decisions[]` は Phase 1 で常に `"unavailable"`（#868 OPEN）であるため、
> `fx-06-routing-escalation` の `routing_decisions` は `fx-04-human-escalated` と同じ `"unavailable"` であり、
> **routing 次元の値カバレッジは 0** である。
> ⚠️ **「fixture 4 と区別不能（実質 9 fixture）」は誤り**（R2 MN-1 是正・実測で反証）: 両 golden を diff すると
> `escalation`（fixture 6 のみ `privacy_url_reduced` / `unknown_record_kind` を持つ）・`human_interventions`・
> `observation`（`unknown_record_kinds=notice`）・`run_id` が異なる。fixture 6 は **`kind=notice` を含む入力**の
> escalation 経路を実際にカバーしており、fixture 数を割り引く必要はない。**欠けているのは routing の値カバレッジだけ**である。
> In scope 4 の verbatim 要求「#868 の requested/resolved routing と outcome を区別して記録」に対応する **item schema は本 PBI では定義しない**。
> ⇒ **「10 fixture PASS」を AC-16 / DoD の充足として報告する際に、routing が実質未検証であることを必ず併記する**（T-32 / T-42）。
> **代替案 (a)**（item schema を暫定定義し fixture 6 を注入値で構成）は **U-9 の C-3 判断**へ上げてある。

## Edge cases（TC への割当）

| Edge case | 割当 TC | 期待 |
|-----------|--------|------|
| `record.jsonl` の破損行 | TC-44 | 理由付きで `skipped`・例外で落ちない |
| `entry_id` の改竄（保存値と再計算値が不一致） | TC-08 | fail-closed（**記号アンカー = `delivery.load_entries()` の「保存 entry_id を信用せず再計算照合」ブロック**と同型。受理器は `<task_dir>/delivery/record.jsonl` を再読込して照合する = C-2 R-004） |
| `c3.json` が legacy（`approval_kind` キーなし） | TC-32 | **exit 10**（legacy 委譲。**記号アンカー = `c3prime_verify.py` の `return 10  # legacy` 分岐**と**同一の値・同一の意味**。当初記載の「exit 11」は非同型だった = C1-B1B2-17 是正） |
| 非終端 run（`WAITING_FOR_CHECKS` 等 6 状態 + `EXEC_RETURN`） | **TC-59**（C-2 R-001 で TC-16 から付け替え。TC-16 は非終端を扱わない） | **RunEvidence を発行しない**（plan D3 の安全側既定。7 状態を parametrized で全数検査し、発行拒否をエラーとして返す）。**U-4 が C-3 で `IN_PROGRESS` 採用に決まった場合は本行と TC-59 を改訂** |
| `terminal_state=MERGE_READY` の導出 | TC-57 | `kind=merge_ready` entry の**物理存在のみ**が条件。`MERGE_READY_CANDIDATE` を丸めない |
| `terminal_state=BLOCKED`（`record.jsonl` 不在） | TC-58 | delivery 層 4 フィールドが `unavailable`（ダミー sha / 空文字 / `0` で埋めない） |
| `pr_number` が解決できない | TC-64 | `repair_rounds` が `unavailable`（`0` にしない） |
| corpus に record が 1 件追加された | TC-60 | 既存 run の `EV` が **byte 不変**（`quality_metrics` に corpus 集計値を入れない） |
| 任意フィールドの**値**に絶対パス | TC-65 | 出力に 0 件（EH-8 は値を見ないため producer 側で検査） |
| producer が transcript / session log を読もうとする | TC-63 | 入力ソース allowlist 4 種以外を open しない |
| known-unavailable フィールドを含む `EV`（Phase 1 の全 run） | TC-07 / TC-56 / TC-58 | **exit 11**（partial）。`partial` の理由は **(a) Phase 1 固定 3** と **(b) `terminal_state` 依存 最大 4** の 2 分類にまたがる（C-2 R-003）。曖昧化しない担保は「理由が 1 種類であること」ではなく **「`unavailable` フィールド名が stderr に全数列挙されること」** に置く |
| 未知 `kind` entry（`kind=notice` 等） | TC-53 | `escalation` に記録して握り潰さない |
| `blocked_by` キーが未注入 | TC-55 | **`BLOCKED`**（判定不能は安全側） |
| account 識別子を含む events | TC-51 | 出力に 0 件（EH-8 の禁止キー 14 個では捕捉できないため producer 側で検査） |
| arbiter record 0 件（`docs/working/ai-loop-runs/` が空） | TC-42 | `legacy_count=0` / `run_count=0` で例外なく完了（分母 0 は `None` + `N/A`。**記号アンカー = `metrics.py` の first_pass 分母 0 分岐**の転写） |
| `evidence_refs` に絶対パス | TC-20 | reject |
| `harness_version` が run 中に変化 | TC-31 | fail-closed |
| 入力 `EV` 群の `harness_version` が混在 | TC-26 | `mixed_baseline` で candidate 生成を拒否 |
| 同型 Run が 2 件しかない | TC-33 | `insufficient_evidence`（3 件以上が issue 指定） |
| 出力を `.jsonl` にしてしまう | TC-21 | 拡張子検査で FAIL（EH-8 の走査対象から外れるため） |

## V-1 実行時の突合手順

1. `python3 scripts/ai-loop/test_run_evidence.py` → exit 0
2. `python3 scripts/ai-loop/test_run_evidence_verify.py` → exit 0
3. `sh tests/run-tests.sh </dev/null` → exit 0 かつ **exec 開始時（T-2）に記録した baseline + ta-59 の新規 PASS 行数**を下回らない
4. `PLANGATE_HOOK_STRICT=1 PLANGATE_HOOK_FILES="<10 fixture のパス>" sh scripts/hooks/check-metrics-privacy.sh` → PASS（TC-22。**`tests/fixtures/` は privacy CI から除外されるため `git add` 依存にしない** = C-2 R-C03）
5. `git diff --stat origin/main -- scripts/ai-loop/delivery.py scripts/ai-loop/c3_contract.py scripts/ai-loop/c3prime_verify.py scripts/ai-loop/arbiter.py scripts/ai-loop/metrics.py docs/working/ai-loop-runs/ tests/run-tests.sh` → **0 行**（不変対象）
6. 上記 65 TC のうち **未実行 / SKIP が 0 件**であることを確認（SKIP は環境依存を理由に許容せず、理由を handoff に記録）
