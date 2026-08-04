# RunEvidence Artifact Contract（正本 / TASK-0874）

> **Status**: v1 Phase 1（契約層のみ。TASK-0874 で確定）
> 位置づけ: 1 回の ai-loop run が終端に達したときに発行する **run 単位の証跡 artifact**（RunEvidence / 以下 `EV`）の**フィールド契約正本**。
> 関連正本: [`c3-prime-contract.md`](./c3-prime-contract.md)（C-3' 出力 artifact・本契約の供給元）/ [`delivery-state-machine.md`](./delivery-state-machine.md)（delivery 層の状態語彙）/ [`decision-table.md`](./decision-table.md)（3 値 terminal state）/ [`rollout-policy.md`](./rollout-policy.md)（判定基盤 carve-out）
> schema: [`run-evidence.schema.json`](../../schemas/run-evidence.schema.json)
> 生成者: `scripts/ai-loop/run_evidence.py`（決定論 producer）/ 受理者: `scripts/ai-loop/run_evidence_verify.py`
> 消費者（**いずれも未実装**）: #869 shadow mode（`to_shadow_candidate_input()`）/ #811 promotion provenance（`to_promotion_provenance()`）

## 0. Phase 1 のスコープと「見直し前提」

本契約 v1 は **Phase 1 = 契約層のみ**である。以下は **Phase 1 の既定**であり、
下流 PBI（#869 shadow mode / #811 promotion provenance）の plan 確定時に**見直す前提**で置いている。
見直しは §9 versioning policy の手続きに従う。

| ID | Phase 1 の既定 | 見直しの契機 |
|----|--------------|------------|
| U-4 | **非終端 run は `EV` を発行しない**（4 値目 `IN_PROGRESS` を作らない） | #869 が「失敗パターンも学習源」として非終端 run を要求した場合 |
| U-8 | adapter IF は `source_run_ids` + `baseline_version` の**最小 2 フィールドから開始**し、それ以外は下流が埋める（§8） | #869 が候補契約フィールドを確定した時点 |
| U-10 | **Phase 1 の producer 出力は全件 `partial`**（known-unavailable allowlist を置かない） | 下流が「`complete` な run のみ学習・promotion 対象」を採り、Phase 1 の全 run が使えないと判明した場合 |
| U-12 | `blocked_by[]` は **fail-closed**（キー欠落 = 判定不能 → `BLOCKED`。明示 `[]` のときのみ非 `BLOCKED`） | #811 が `blocked_by[]` の供給元を確定した時点 |
| U-9 | fixture 9 / 10（paired replay / canary rollback）は **#874 の最小定義**。`routing_decisions[]` の item schema は**定義しない** | #869 / #811 / #868 が別定義を採った場合は追従する |

> **本 PBI の完了は issue #874 の close 条件充足を意味しない**。#874 の DoD は
> 「#869 shadow mode の統合 test」「#811 promotion provenance test」「効果測定」を要求しており、
> いずれも本契約の下流にある。**#874 は本 PBI 完了後も OPEN のまま残す**。

## 1. `EV` の位置づけと不変条件

- `EV` は **arbiter record（`docs/working/ai-loop-runs/*.json`）の後継ではなく上位 artifact** である。arbiter record は**入力ソースの 1 つとして参照するだけ**で、置き換えも移行も行わない。
- `EV` は **1 run 1 ファイル**・**拡張子は `.json` 固定**。`.jsonl` にしてはならない（§7 privacy 参照）。
- serialization は `json.dumps(record, ensure_ascii=False, indent=2, sort_keys=True) + "\n"`（`plan_package.serialize_c3_prime()` と byte 互換）。
- producer は**決定論**である。同一入力 + 同一注入値から**必ず byte 一致する `EV`** を生成する（§3）。

## 2. フィールド定義（producer 出力キーの全集合 = 24）

本表が **producer が出力するキーの全集合**であり、schema の `properties` と **1:1 で対応する**。
本表に無いキーを producer が出力してはならず、schema の `properties` に本表に無いキーを登録してもならない。

`required` は本表の **1〜20（issue #874 verbatim の 20 フィールド）+ 21 `schema_version` = 21 件**。
22〜24 は optional（`additionalProperties: false` の下で **`properties` への登録は必須**）。

> **`escalation` を登録し忘れたときの実害**: `additionalProperties: false` の下で `escalation` が
> `properties` 未登録だと、**privacy 違反や未知 `kind` を検知した `EV` — 最も検証が必要な `EV` — だけが reject される**。

| # | field | 型 | required | 供給元 | 取得不能時 |
|---|-------|----|---------|-------|----------|
| 1 | `run_id` | string（非空） | ✅ | arbiter record 14 キー世代の `run.run_id` / 無ければ `--run-id` 注入 | **fail-closed** |
| 2 | `task_id` | string `^TASK-[0-9]{4}$` | ✅ | `approvals/c3.json` の `task_id`。**`task_dir` 名に束縛** | fail-closed |
| 3 | `started_at` | string（ISO 8601 UTC） | ✅ | `--started-at` 注入 | fail-closed |
| 4 | `completed_at` | string（ISO 8601 UTC） | ✅ | `--now` 注入 | fail-closed |
| 5 | `repository` | string（**owner 除去済み repo 名**） | ✅ | `--repository` 注入。producer は `git remote` を呼ばない | fail-closed |
| 6 | `source_sha` | string `^[0-9a-f]{7,40}$` | ✅ | `approvals/c3.json` の `source_sha` | fail-closed |
| 7 | `final_head_sha` | string `^[0-9a-f]{7,40}$` \| `"unavailable"` | ✅ | `record.jsonl` の `kind=merge_ready` entry の `record.head_sha` / 無ければ最終 `kind=state` entry の `head_sha` | §5 マトリクス |
| 8 | `plan_hash` | string `^sha256:[0-9a-f]{64}$` | ✅ | `approvals/c3.json` の `plan_hash` | fail-closed |
| 9 | `c3_prime_decision_ref` | object `{path, plan_package_hash}` | ✅ | `approvals/c3.json` への **repo 相対参照** + `plan_package_hash`。**§4 全規則の再検証を通過した場合のみ**（§6） | fail-closed |
| 10 | `harness_version` | object `{plugin_version, cli_version, corpus_hash}` | ✅ | 注入（3 値すべて）。§4 参照 | fail-closed |
| 11 | `routing_decisions` | array \| `"unavailable"` | ✅ | **#868 未実装**（供給元なし） | **Phase 1 固定 `"unavailable"`** |
| 12 | `ci_outcomes` | array \| `"unavailable"` | ✅ | `record.jsonl` の `kind=merge_ready` の `record.check_summary` のみ（`kind=state` の `reasons` は `observation` へ回す — 件数照合を壊さないため混ぜない） | §5 マトリクス |
| 13 | `review_findings` | array \| `"unavailable"` | ✅ | `record.jsonl` の `record.review_disposition` + `kind=receipt` かつ `action_kind=repair_review` の `finding_type` | §5 マトリクス |
| 14 | `repair_rounds` | integer（`>= 0`）\| `"unavailable"` | ✅ | `delivery._completed_rounds(entries, pr)` の戻り値（**再実装せず import**） | **PR 番号が解決できなければ `"unavailable"`**（§3 の警告） |
| 15 | `replan_count` | integer \| `"unavailable"` | ✅ | 供給元が main に存在しない | **Phase 1 固定 `"unavailable"`** |
| 16 | `human_interventions` | array \| `"unavailable"` | ✅ | arbiter record の `decision=HUMAN_ESCALATED` + `record.jsonl` の `kind=state` かつ `state=HUMAN_ESCALATED` + `kind=notice` entry | `"unavailable"` |
| 17 | `terminal_state` | string enum（3 値） | ✅ | **§4 の正規化マッピング** | 非終端は**発行しない** |
| 18 | `quality_metrics` | object \| `"unavailable"` | ✅ | **当該 run の events だけで閉じる指標のみ**（§3 の許可指標） | `"unavailable"` |
| 19 | `cost_metrics` | object \| `"unavailable"` | ✅ | `docs/working/_metrics/events.ndjson` は `.gitignore` 対象で参照不能 | **Phase 1 固定 `"unavailable"`** |
| 20 | `evidence_refs` | array of string（**repo 相対パスのみ**） | ✅ | **注入値または `record.jsonl` 由来のみ**（ディスク走査で列挙しない） | 空配列可 |
| 21 | `schema_version` | string | ✅ | 本契約の版（§9） | fail-closed |
| 22 | `observation` | string | — | **観測事実**（何が起きたか） | 空文字可 |
| 23 | `cause_hypothesis` | string \| null | — | **推定**（なぜ起きたか）。**注入されたときのみ**格納する | `null` |
| 24 | `escalation` | array of object `{kind, detail}` | — | 握り潰さずに記録すべき異常（未知 `kind` entry / privacy 違反入力 / 分類不能 record） | 空配列 |

### 2-1. `evidence_status` は `EV` に格納しない

`evidence_status`（`complete` / `partial`）は **受理器が導出する判定語彙**であり、**record に格納しない**。
根拠は trust boundary（[`c3-prime-contract.md`](./c3-prime-contract.md) §7「decision 値を無検証で信頼してはならない」の転写）
— **生成側が自分の証跡の完全性を自己申告できる構造にしない**。これにより `required` は 21 に閉じる。

### 2-2. `terminal_state` と `evidence_status` は直交する

`terminal_state=MERGE_READY` かつ `evidence_status=partial` は**正常な状態**であり、
「run は終端に達した / だが証跡の一部が Phase 1 では取得不能」を意味する。
`evidence_status` を `terminal_state` の緩和・強化に使ってはならない。

### 2-3. `observation` と `cause_hypothesis` の分離（AC-5）

- `observation` = **観測事実のみ**。events から機械的に導出できる範囲に限る。
- `cause_hypothesis` = **推定**。producer は**自動生成しない**。注入されなければ `null` を出力する。
- 両者を 1 フィールドに混ぜてはならない（推定が観測として下流に流れると #869 の学習母集団が汚染される）。

## 3. producer の入力契約

### 3-1. 入力ソース allowlist（4 種・これ以外を open しない）

1. `docs/working/TASK-XXXX/approvals/c3.json`
2. `docs/working/TASK-XXXX/delivery/record.jsonl`
3. `docs/working/ai-loop-runs/*.json`（arbiter record）
4. 呼び出し側注入値（§3-2）

> ⚠️ **1 に含まれる範囲の明確化（producer 実装で顕在化）**: producer は §6 の
> fail-closed 再検証で `c3prime_verify.main()` を経由するため、同関数が読む
> **同一 `task_dir` 配下の Plan Package 6 artifact**（`pbi-input.md` / `plan.md` /
> `todo.md` / `test-cases.md` / `review-self.md` / `review-external.md`）も
> 実際には open される。これは「c3-prime 束縛の再検証に必要な読み取り」であり
> ソース 1 の一部として扱う（**`task_dir` の外へは出ない**）。
> 入力ソース allowlist の本質は「`task_dir` と `runs_dir` の外を読まない」ことにある。

**transcript / session log / hidden CoT / 環境変数 / ネットワーク / 外部プロセスは読まない**
（`delivery.py` の「純判定器: ネットワーク・外部プロセスを一切呼ばない」原則の転写）。
これは AC-6 の「**要求しない**」側の担保であり、出力側の禁止キー検査（§7）とは別の防御線である。

### 3-2. 注入値と欠落時の既定

**run コンテキストの注入値 5 つ**（当初の「5 つで全数」はこの 5 つを指す）:

| 注入値 | 用途 | 未注入時の既定 |
|-------|------|--------------|
| `--now` | `completed_at` | **エラー**（fail-closed） |
| `--started-at` | `started_at` | **エラー**（fail-closed） |
| `--repository` | `repository` | **エラー**（fail-closed） |
| `--run-id` | `run_id` | **エラー**（fail-closed） |
| `--pr-number` | `record` から解決した PR 番号との **cross-check 専用** | **cross-check を行わない**（`repair_rounds` の値は変えない） |

**harness / 任意フィールドの注入値**（§2 の供給元「注入」に対応。producer 実装で追補）:

| 注入値 | 用途 | 未注入時の既定 |
|-------|------|--------------|
| `--harness-version` | `harness_version`（object 3 値） | **エラー**（fail-closed。§2 #10 と一致） |
| `--harness-version-end` | run 終了時の harness を開始時と byte 比較（AC-12） | drift 検査を行わない |
| `--routing-decisions` | `routing_decisions` の**明示供給**（`[]` を含む） | `"unavailable"`（§5-1 (a)） |
| `--observation` | `observation` の上書き | events から機械導出 |
| `--cause-hypothesis` | `cause_hypothesis` | `null`（**自動生成しない** / AC-5） |
| `--evidence-ref`（repeat 可） | `evidence_refs[]` への追加 | `c3.json` / `record.jsonl` の 2 参照のみ |

> ⚠️ **`--pr-number` は「解決経路」ではなく「cross-check」である**（producer 実装で確定）:
> 受理器は `kind=merge_ready` entry の `record.pr_number` **からしか** PR を再解決できない
> （§6-2 の再計算照合）。注入値だけを根拠に `repair_rounds` を実値化すると
> **受理側が再計算で照合できず**、「生成側の自己申告を信頼する」構造になる（§2-1 の trust boundary と矛盾）。
> したがって producer は **PR 番号を `kind=merge_ready` entry からのみ解決**し、
> `--pr-number` は record 由来の値との不一致検出（fail-closed）にのみ使う。
> 解決できない場合は `repair_rounds` / `ci_outcomes` / `review_findings` を `"unavailable"` に倒す。
>
> ⚠️ **`--pr-number` を `0` に倒してはならない（fail-open 経路）**: 実測で
> `delivery._pr_receipts(entries, pr)` は `e.get("pr_number") == pr` で絞るため、
> `pr=None` では `pr_number` を持たない entry だけが残り、`_completed_rounds()` は
> `max(rounds, default=0)` により **例外ではなく `0`（= 修理 0 回）を黙って返す**。
> 実在の一次証跡（TASK-0917 の e2e `record.jsonl`）で
> `_completed_rounds(entries, 940) = 1` / **`_completed_rounds(entries, None) = 0`** を実測確認した。
> PR 番号は `kind=merge_ready` entry の `record.pr_number` から解決し、
> 解決できなければ `"unavailable"` に倒す（`--pr-number` の役割は上表の cross-check）。

### 3-3. 決定論を壊さないための制約

- **`now()` を直接参照しない**。すべての timestamp は注入。producer のソースに `datetime.now` / `time.time` / `utcnow` が **0 件**であること。
- **hash は `c3_contract.canonical_hash()` を import 再利用**する（独自 hash 実装を作らない）。
- **`quality_metrics{}` は当該 run の events だけで閉じる指標のみ**。Phase 1 の許可指標は次の 2 つに限る。
  - `first_pass`: 当該 run の `round_index == 1` の record の `decision` が `AUTO_APPROVED` か
  - `rounds`: 当該 run の round 数
  - **corpus 集計値（`decision_counts` / `round_distribution` / `hotl_health` / `first_pass_rate`）を格納してはならない**。これらは `metrics.py` の `collect(runs_dir)` が **runs_dir 配下の全 record を横断集計**した値であり、`EV` に載せると **arbiter record が 1 件増えるだけで過去 run の `EV` の byte が変わる**（AC-2 と golden byte 比較が後日 CI で原因不明に赤くなる）。
  - `metrics.py` は **import しない**（不変対象への依存を増やさない）。上記 2 指標の**導出規則のみ転写**する。
- **`evidence_refs[]` をディスク走査で列挙しない**。列挙は**注入値または `record.jsonl` 由来の参照のみ**。ディスク走査すると**ファイルの増減で同一 events から異なる `EV`** が出る。
- 出力先: 既定は **stdout へ 1 record**。`--out <path>` を指定した場合のみファイルへ書き、**拡張子が `.json` でなければ reject** する。

### 3-4. 未知 `kind` entry の扱い

`delivery.assess()` が生成しない `kind`（実在例: `kind=notice`・`executor.py` 由来）を **握り潰さない**。
`escalation` に「未知 kind」と該当 `kind` 値を記録したうえで処理を続ける。黙って無視して正常終了してはならない。

## 4. `terminal_state` 正規化マッピング（D3）

issue #874 の 3 値は **2 つの状態機械の和集合**であり、この 3 値をそのまま出す層は main に存在しない（実測）。

| 層 | 実測語彙 |
|----|---------|
| `delivery.py` | `STATES` = **7 値**（`CHECKS_FAILED` / `CONFLICT` / `MERGE_READY` / `MERGE_READY_CANDIDATE` / `REVIEW_REPAIR` / `WAITING_FOR_CHECKS` / `WAITING_FOR_REVIEW`）+ `EXITS` = **2 値**（`EXEC_RETURN` / `HUMAN_ESCALATED`）。`TERMINAL = "MERGE_READY"` のみが終端 |
| `c3_contract.py` | `VALID_DECISIONS` = **3 値**（`AUTO_APPROVED` / `HUMAN_ESCALATED` / `BLOCKED`） |
| issue #874 | `MERGE_READY` / `HUMAN_ESCALATED` / `BLOCKED` |

⇒ `BLOCKED` は delivery 層に存在せず、`MERGE_READY` は c3-prime 層に存在しない。

**採用する正規化マッピング**（本表を契約 doc / schema / producer が同一表として持つ）:

| `terminal_state` | 由来 | 条件 |
|-----------------|------|------|
| `BLOCKED` | c3-prime 層 | `c3.json` の `decision == "BLOCKED"`（= exec に到達していない） |
| `HUMAN_ESCALATED` | 両層 | `c3.json.decision == "HUMAN_ESCALATED"` **または** `record.jsonl` の最終 `kind=state` の `state == "HUMAN_ESCALATED"` |
| `MERGE_READY` | delivery 層 | `record.jsonl` に **`kind=merge_ready` entry が物理的に存在する**（`delivery.assess()` が `state = "MERGE_READY"` を刻む唯一の経路） |
| **（発行しない）** | — | 上記いずれにも該当しない = **非終端 7 状態**（`WAITING_FOR_CHECKS` / `WAITING_FOR_REVIEW` / `CHECKS_FAILED` / `CONFLICT` / `REVIEW_REPAIR` / `MERGE_READY_CANDIDATE` / `EXEC_RETURN`） |

> ⚠️ **`MERGE_READY_CANDIDATE` を `MERGE_READY` に丸めてはならない**。
> 最終 `kind=state` を見て判定すると未収束 run が #869 の学習母集団と #811 の promotion 入力に混入する。
> 判定条件は **`kind=merge_ready` entry の物理存在のみ**である。

### 4-1. `harness_version`（AC-12）

`harness_version` は**単一文字列にしない**。実測で候補が 3 つあり値が一致しないため（`bin/plangate` = `0.2.0` /
plugin = `8.18.0` / LoopSpec 派生 hash = run ごとに変動）、**object 3 値**とする。

| key | 内容 |
|-----|------|
| `plugin_version` | plugin / release 版 |
| `cli_version` | `bin/plangate` の版 |
| `corpus_hash` | 判定基盤 corpus（§10 の carve-out ①②③）のファイル内容 hash を `canonical_hash()` で束ねた値 |

**AC-12（active run 中に harness version が変化しない）は 3 値すべてについて**、run 開始時注入値と
終了時の値の **byte 一致**で検証する。1 つでも不一致なら **fail-closed**（警告に降格しない）。

## 5. `terminal_state` × フィールドの必須 / `unavailable` マトリクス

| field | `MERGE_READY` | `HUMAN_ESCALATED` | `BLOCKED` |
|-------|--------------|-------------------|-----------|
| `final_head_sha` | **必須**（欠落 = fail-closed） | **必須** | **`unavailable`** |
| `ci_outcomes` | **必須** | 取得できれば必須 / 無ければ `unavailable` | **`unavailable`** |
| `review_findings` | **必須** | 取得できれば必須 / 無ければ `unavailable` | **`unavailable`** |
| `repair_rounds` | **必須**（PR 番号解決不能なら `unavailable`） | 同左 | **`unavailable`** |
| `quality_metrics` | **必須** | `repair_rounds` に従属（不能なら `unavailable`） | **`unavailable`** |
| `routing_decisions` / `replan_count` / `cost_metrics` | `unavailable` | `unavailable` | `unavailable` |

> **`quality_metrics` が `repair_rounds` に従属する理由**（producer 実装で確定）:
> Phase 1 の許可指標 `first_pass` / `rounds` はいずれも当該 run の round 数から導出する。
> `repair_rounds` が `unavailable` の run では round 数が取得不能であり、
> `{"first_pass": false, "rounds": 0}` と埋めると **`unavailable` を `0` で埋める**ことになる
> （本契約が最も避ける fail-open）。したがって `quality_metrics` 全体を `"unavailable"` に倒す。
>
> **`BLOCKED` が特別な理由**: `BLOCKED` は `c3.json.decision == "BLOCKED"`（= exec に到達していない）で
> 発行される終端であり、**`delivery/record.jsonl` 自体が存在しない**。したがって delivery 層由来の
> 4 フィールドが**構造的に取得不能**になる。
> **空文字・ダミー sha・`0` で埋めてはならない**（`EV` には自己 hash が無いため tampered 検出も効かない）。
> 逆に missing 扱いで reject してもならない（`BLOCKED` run の証跡が一切残らなくなる）。

### 5-1. known-unavailable の 2 分類

| 分類 | 対象 | 件数 |
|------|------|------|
| **(a) Phase 1 固定** | `routing_decisions` / `replan_count` / `cost_metrics` | **3**（`terminal_state` に依存しない） |
| **(b) `terminal_state` 依存** | `final_head_sha` / `ci_outcomes` / `review_findings` / `repair_rounds` / `quality_metrics` | **最大 5**（`BLOCKED` で 5 件・他は 0〜5 件） |

⇒ `BLOCKED` run の `unavailable` は **(a)3 + (b)5 = 8 件**（producer 実装で確定。
当初の「7 件」は `quality_metrics` の従属を数えていなかった）。
`HUMAN_ESCALATED` で `kind=merge_ready` entry が無い run は
`ci_outcomes` / `review_findings` / `repair_rounds` / `quality_metrics` が `unavailable` で **3 + 4 = 7 件**。

⇒ **Phase 1 の producer 出力は必ず `unavailable` を含み、受理器は必ず `partial` を返す。
Phase 1 で `evidence_status=complete`（exit 0）は構造的に発生しない**。

`partial` の理由は上記 2 分類にまたがるため、**曖昧化しない担保は「理由が 1 種類であること」ではなく
「`unavailable` フィールド名が stderr に全数列挙されること」に置く**。

受理器の exit 0 経路が死にコード化しないことは、**unit test が合成した「全フィールド available な `EV`」**
で担保する（fixture では 0 の経路を一度も通らないため）。

## 6. 受理器の入力契約と exit code

### 6-1. 署名

```text
run_evidence_verify.py <ev.json> <task_dir>
```

姉妹受理器 `c3prime_verify.py <task_dir> [expected_sha]` と同型の **task_dir 束縛**にする。

> ⚠️ **`EV` 単体入力にしてはならない**。`sha256:` + 64 hex の形式を保った `plan_hash` の 1 文字改変は
> **形式上は正当**であり（`EV` に自己 hash が無い）検出できず、known-unavailable により **exit 11（partial）**
> で返る。partial は「ready 扱いしない」だけで拒否ではないため、**改竄された provenance が promotion まで到達しうる**。

### 6-2. 受理器が再検証する対象（生成側の申告を信頼しない）

| `EV` フィールド | 照合先 |
|--------------|-------|
| `task_id` | `task_dir` のディレクトリ名（`c3prime_verify.py` の `task_dir.name != task_id` 束縛と同型） |
| `plan_hash` / `source_sha` | `<task_dir>/approvals/c3.json` の同名フィールド |
| `c3_prime_decision_ref` | `<task_dir>/approvals/c3.json` への repo 相対参照として解決可能か |
| `final_head_sha` / `repair_rounds` | `<task_dir>/delivery/record.jsonl` の**再計算値**（`delivery.load_entries()` の `entry_id` 再計算照合と同型） |

> **`evidence_hash` を `EV` 自身に持たせる自己完結型は採らない**。`required` が 21 → 22 になり
> §9 versioning policy に波及するうえ、「生成側が自分の証跡の完全性を自己申告する」構造となり
> §2-1 の trust boundary 方針と矛盾するため。

### 6-3. 受理器は schema を唯一の正として読む

受理器は [`run-evidence.schema.json`](../../schemas/run-evidence.schema.json) を読み、
**`required` と許可キー集合を schema から導出する**（ハードコードしない）。

- 未知トップレベルキーは reject（`c3prime_verify.py` の `unknown = [k for k in data if k not in ALLOWED_KEYS and not k.startswith("_")]` の転写）
- `^_` 注釈キーのみ許容。ただし**値が string でなければ reject**（`if k.startswith("_") and not isinstance(v, str): return _fail(...)` と同型）

これを怠ると schema と受理器が乖離したまま全 TC が緑になり、Phase 2 で `schemas/` へ昇格した瞬間に
**既存 `EV` が一斉 reject される**（§10 の「1 回の HO patch で昇格」が破綻する）。

### 6-4. 両受理器の rc 対応表

| exit | `c3prime_verify.py`（既存） | `run_evidence_verify.py`（本 PBI） |
|------|---------------------------|----------------------------------|
| `0` | c3-prime として受理 | `EV` として受理（`evidence_status=complete`・全束縛整合） |
| `1` | 検証 NG（fail-closed・理由を stderr） | 同左 |
| `10` | **legacy**（`approval_kind` キーが物理的に無い） | **legacy**（`EV` ではなく 9 キー / 14 キー arbiter record を渡された） |
| `11` | （未使用） | **partial**（必須フィールドは揃うが `unavailable` を含む = ready 扱いしない） |

`10` の意味は**両受理器で同一**にする。同一ディレクトリの 2 受理器で `10` の意味が割れると、
将来 rc を共通ハンドラで扱った時点で **legacy を partial と誤読**する経路が生まれる。

> ⚠️ **消費側の強度は 2 箇所で異なる（実測）**: `delivery.py` は `if rc == 10:` の**厳密比較**だが、
> `bin/plangate` の `_plangate_c3_dispatch` 後段は `if [ "$_c3_rc" = "0" ] … elif [ "$_c3_rc" = "1" ] … else`
> という **catch-all**（値を判定せず 0/1 以外をすべて legacy にフォールバック）である。
> ⇒ **本受理器の rc を `_plangate_c3_dispatch` 経路へ流してはならない**（`11` を流すと catch-all が legacy と誤読する）。

### 6-5. 「`c3prime_verify` rc==0 を要求する」と §4 マッピングの矛盾（**確定済み**）

**内部矛盾**（TASK-0874 exec 前半で実測により顕在化・**producer 実装で下記のとおり確定**）。

- plan Step 6 は producer に「`c3prime_verify.main([_, task_dir, expected_sha])` を呼び **rc==0 を要求**する」と規定している。
- 一方 §4 のマッピングは `BLOCKED` を `c3.json.decision == "BLOCKED"` から、`HUMAN_ESCALATED` を `c3.json.decision == "HUMAN_ESCALATED"` から導出すると規定している。

**この 2 つは同時に成立しない**。実測（静的に決定的）:
`c3prime_verify.py` の唯一の `return 0` は関数末尾（L166）にあり、その手前の
`if decision != "AUTO_APPROVED": return _fail(...)`（L108・`_fail` は必ず `1` を返す）は**無条件**である。
⇒ **`rc == 0` は `decision == "AUTO_APPROVED"` を含意する**。
したがって「rc==0 を要求」を文字どおり実装すると、`terminal_state` が `BLOCKED` / `HUMAN_ESCALATED` の
`EV` は**構造的に 1 件も発行できず**、fixture 4 / 5 と TC-58 が実装不能になる。

**本契約の解釈（producer 実装時に確定させる方針）**: producer が要求するのは
**§4 の構造・束縛規則（`task_id` 束縛 / `plan_hash` / `artifact_hashes` / `plan_package_hash` /
reviewer snapshot 整合）の再検証が通ること**であり、**`decision` の値そのものは検証結果ではなく
`terminal_state` の供給元**として扱う。すなわち:

- `rc == 0` → `decision == "AUTO_APPROVED"`（delivery 層の判定へ進む）
- `rc == 1` かつ理由が **`decision` 値のみ**に起因する場合 → `decision` を §4 マッピングの入力として採用する
- `rc == 1` かつ理由が **束縛不整合**（hash / artifact / reviewer）→ **fail-closed**（`EV` を発行しない）
- `rc == 10`（legacy） → `EV` を発行しない

**`decision` を無検証で信頼しない**という §7 trust boundary は維持される（束縛検証は全数実施し、
`decision` の値だけを別扱いする）。

> ⚠️ **この解釈だけでは束縛検証に穴が空く（実装で顕在化・是正済み）**:
> `c3prime_verify` は `decision != "AUTO_APPROVED"` の時点で `return` するため、
> **その後段の検証（`source_sha` 形式 / `plan_hash` / `artifact_hashes` /
> `plan_package_hash` / reviewer snapshot 三つ組）が一度も実行されない**。
> 「decision-only NG は続行」とだけ実装すると、**`decision=BLOCKED` の `c3.json` 経由で
> 改竄された `plan_hash` が素通りする**。
> ⇒ producer は decision-only NG のとき、`c3_contract` の**同一プリミティブを import して**
> （`sha256_of_file` / `canonical_hash` / `check_snapshot_trio` / `ARTIFACTS`）
> 後段の束縛を再検証する。**検証ロジックを再実装せず、検証の総量も減らさない**。
> 本経路は変異注入（後段再検証の削除）で kill されることを unit test で実証している。

## 7. privacy（AC-6）

### 7-1. 禁止キー 14 個

`EV` の出力に以下のキーが **1 つも現れてはならない**（producer 側で機械検査する）。

`file_path` / `file_paths` / `stack_trace` / `stacktrace` / `command_output` / `stdout` / `stderr` /
`raw_response` / `raw_request` / `api_key` / `user_prompt` / `system_prompt` / `prompt_text` / `absolute_path`

> ⚠️ **本一覧は契約 doc（`.md`）側に置く**。schema の `properties` に禁止キー名を**登録してはならない**。
> 実測で EH-8（`scripts/hooks/check-metrics-privacy.sh`）は `grep -E '("file_path"|…)[[:space:]]*:'` であり、
> **`"file_path":` の形（JSON キー）だけが BLOCK 対象**である（配列要素 `{"forbidden": ["file_path"]}` は BLOCK されない）。
> 正しい制約は「JSON に書けば必ず BLOCK」ではなく **「`properties` のキーとして書くと BLOCK」**。

### 7-2. 値レベルの検査（EH-8 が見ない領域）

EH-8 は**キー名の grep のみで値を一切見ない**（実測: `{"file": "/var/folders/xx/tmpABC/foo.json"}` は
`PLANGATE_HOOK_STRICT=1` でも **PASS**）。したがって producer 側で以下を検査する。

- **全フィールドの値**に絶対パス（`^/` または `/Users/` を含む文字列）が **0 件**であること（`evidence_refs` 限定にしない）
- `evidence_refs[]` は **repo 相対パスのみ**（`/` 始まりは reject）
- **account 識別子**（GitHub username 等）が出力に現れないこと。EH-8 の禁止キー 14 個に account 系は**含まれない**ため、producer 側の検査が唯一の防御線になる

`metrics.py` の `skipped` は `{"file": str(path), "reason": …}` を記録し `file` は**絶対パスになりうる**が、
キー名が `file`（`file_path` ではない）ため **EH-8 では捕捉できず素通りする**。
転写先では **repo 相対パスへ正規化するか `EV` に載せない**。

### 7-3. `repository` と PR / コメント参照の還元（U-5）

| 対象 | 保存する形 | 保存しない形 |
|------|-----------|------------|
| `repository` | **owner 除去済み repo 名**（例: `plangate`） | `s977043/plangate` |
| PR 参照 | **PR 番号**（例: `940`） | `https://github.com/s977043/PlanGate/pull/940` |
| コメント参照 | **コメント ID**（例: `5140067809`） | `…/pull/940#issuecomment-5140067809` |

⇒ **値レベルで `github.com` を含む URL・owner 名を保存しない**。下流は番号から URL を再構成する。
これにより「account 識別子 0 件」と AC-11 の `improvement_refs[]`（PR / commit の追跡）が両立する。

### 7-4. 保存形式を `.json` に固定する理由

EH-8 の走査対象は `case "$f" in *.json|*.ndjson)` であり、**`*.jsonl` と `*.md` は素通りする**（実測）。
`.json` に固定することで禁止キー検査が hook 層で自動的に効く。

> ⚠️ **ただし `tests/fixtures/` 配下だけは CI の自動強制が効かない**（実測）:
> `.github/workflows/metrics-privacy.yml` の scan 対象決定は
> `git diff --name-only … | grep -E '\.(json|ndjson)$' | grep -v '^tests/fixtures/'` で
> **`tests/fixtures/` を明示除外**しており、`.claude/settings.example.json` の hooks にも EH-8 は**存在しない**。
> ⇒ 本 PBI が commit する golden fixture に対しては、
> `tests/extras/` の ta スクリプトの中から `PLANGATE_HOOK_STRICT=1 PLANGATE_HOOK_FILES="<fixture パス>" sh scripts/hooks/check-metrics-privacy.sh`
> を**実走**させて回帰保護を持たせる（ta スクリプトは `tests/run-tests.sh` の glob source 経由で CI job に必ず乗る）。

## 8. 下流 adapter IF（Phase 1 は最小 2 フィールドから開始）

**再実装しない**。#869 の clustering も #811 の promotion decision table も本契約では作らず、
**provenance の橋渡しのみ**を担う。

### 8-1. `to_shadow_candidate_input()`（#869 / AC-7 / AC-8）

| `EV` 側 | candidate 側 | 備考 |
|--------|-------------|------|
| `run_id[]` | **`source_run_ids`** | #869 issue 本文の実測綴り |
| `harness_version` | **`baseline_version`** | ⚠️ **`baseline_harness_version` という綴りは repo にも issue にも 0 件**のため使わない |
| `observation` | `observed_pattern` | — |
| `cause_hypothesis` | `cause_hypothesis` | — |

- **3 件以上の同型 run**が必須。2 件以下は candidate を生成せず `insufficient_evidence` を返す。
- 入力 `EV` 群の `harness_version` が**混在**する場合は candidate を生成せず `mixed_baseline` で reject する（baseline が定義できない run 群から候補を作らない）。
- adapter は **`EV` 以外の I/O を持たない**（AC-7「#869 が RunEvidence のみから shadow candidate を生成できる」の構造保証）。
- **上記 2 フィールド（`source_run_ids` / `baseline_version`）が Phase 1 の最小契約**であり、それ以外のフィールドは下流（#869）が確定・追加する境界とする（§0 U-8）。

### 8-2. `to_promotion_provenance()`（#811 / AC-11 / AC-13）

返す dict のキー（#811 Trust Ledger の実測綴り）:
`candidate_id` / `decision` / `promoted_to` / `evidence_count` / `canary_scope` / `rollback_count` / `improvement_refs`

- `evidence_count == len(source_run_ids)`
- `improvement_refs[]` は **PR 番号と commit SHA**（`[0-9a-f]{7,40}`）を保持し、`source_run_ids` と**双方向に辿れる**こと（§7-3 の還元形で保持する）

**AC-13 fail-closed（`blocked_by[]`）**:

| 入力の状態 | 判定 |
|-----------|------|
| `blocked_by` が**非空** | **`BLOCKED`** |
| `blocked_by` キーが**物理的に存在しない**（未注入） | **`BLOCKED`**（判定不能は安全側へ倒す） |
| `blocked_by == []` を**明示注入** | 非 `BLOCKED`（promotion 判定へ進む） |

> **「非空なら BLOCKED」だけを実装すると fail-open する**: 誰も `blocked_by` を埋めない限り常に非 `BLOCKED` になる。
> 「未解決なし」と解釈するのは **明示的に `[]` を注入した場合のみ**（`unavailable` と空配列を区別する本契約の原則と同型）。
> **issue 番号をハードコードしてはならない**（実測で #862 は CLOSED / #866 は OPEN であり、番号は CLOSE 時に stale 化する）。
> 誰が `blocked_by[]` を埋めるかは #811 の plan 確定時に見直す（§0 U-12）。

### 8-3. improvement TASK は通常ゲートを通る（AC-9）

candidate から派生した improvement TASK の記述子は
`plan_package_required == True` / `c3_prime_required == True` / `merge_by_ai == False` を持ち、
**通常ゲートを迂回するフラグ（`skip_c3` / `auto_merge` 等）を持ってはならない**。

## 9. versioning policy

- `EV` は `schema_version` を **`required` に持つ**（optional にしない）。version 不明の record を受理すると **versioning policy が機械的に無効化される**ため。
- **破壊的変更**（`required` の追加 / 型変更 / §4 正規化マッピングの変更 / exit code 意味論の変更）は
  **#872 / #873 / #874 の 3 issue 合意 + plan Replan** を要する（[`c3-prime-contract.md`](./c3-prime-contract.md) §8 と同一規則）。
- 非破壊的変更（optional フィールドの追加 / description の補強）は本契約の minor 改訂として扱う。

> ⚠️ **前例との非対称を明記する**: 構造前例として参照する `schemas/c3-prime.schema.json` は
> **`schema_version` を `properties` にも `required` にも持たない**（実測）。
> 一方 `schemas/*.schema.json` 28 本のうち **9 本が `schema_version` を `required` に持ち**、
> `properties` に持ちながら `required` から外している schema は **0 本**である。
> **この非対称を明記しないと**、`schemas/` への昇格レビューで「c3-prime に合わせて `schema_version` を落とす」
> 是正が入り、versioning policy が事後的に無効化されうる。

## 10. schema の配置と昇格（`docs/schemas/` → `schemas/`）

Phase 1 では schema を `docs/schemas/run-evidence.schema.json` に置く。
`$id` は**昇格後の URL** `https://github.com/s977043/plangate/schemas/run-evidence.schema.json` で
**先に固定**しておき、昇格を **`git mv` 1 手**に収める（`$id` の変更も不要）。

### 10-1. 配置に伴う 3 つの非対称（いずれも実測）

| 観点 | `schemas/` | `docs/schemas/` |
|------|-----------|----------------|
| EH-3 の Hardening Override | **対象**。ただし実効パターンは `schemas/*.schema.json`（**1 階層・`.schema.json` 拡張子のみ**） | 対象外 |
| `ho-paths.md` の HO 表 | `schemas/**`（**全階層・全ファイル**）と記載 ⇒ **EH-3 の実効パターンより広い** | 対象外 |
| `rollout-policy.md` §2 判定基盤 carve-out ①②③ | 対象外 | **対象外**（①`scripts/ai-loop/**` ②`docs/workflows/ai-loop/**`・`docs/ai/ai-loop/**` ③`.agents/skills/ai-loop-cycle/**`・`.claude/skills/ai-loop-cycle/**` の**いずれにも含まれない**） |

> **本契約 doc 自身は carve-out ② に含まれる**（`docs/workflows/ai-loop/**`）。
> したがって本 doc を変更する ai-loop 自走は **escalate 固定**（auto-approve 不可）である。
> 一方 **schema 本体（`docs/schemas/`）は carve-out に含まれない**。この非対称は昇格時に解消される。

### 10-2. CI 経路の非対称（実測）

- **schema 検証 CI は 0 本**: `.github/workflows/schema-validate.yml` の trigger paths は `docs/working/**/*.json` と `schemas/**/*.json` であり、**`docs/schemas/**` を含まない**。
- **privacy CI の走査対象には入る**: `.github/workflows/metrics-privacy.yml` の trigger paths は `**/*.json` であり `docs/schemas/` も走査される（`tests/fixtures/` のみが scan から除外される）。

⇒ 「`docs/schemas/` は CI に一切乗らない」と読むのは**誤り**。乗らないのは **schema 検証 CI だけ**である。

## 11. 関連

- issue: #874（本契約）/ #870（親 EPIC）/ #869（shadow mode・未実装）/ #811（promotion provenance・未実装）/ #868（routing・未実装）
- 契約正本: [`c3-prime-contract.md`](./c3-prime-contract.md) §4 / §7 / §8
- 状態語彙: [`delivery-state-machine.md`](./delivery-state-machine.md)
- carve-out: [`rollout-policy.md`](./rollout-policy.md) §2
