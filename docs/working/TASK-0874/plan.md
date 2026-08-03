# EXECUTION PLAN — TASK-0874

> Issue: [#874](https://github.com/s977043/plangate/issues/874)（P1 / enhancement / area:workflow / area:eval / area:metrics）
> Parent EPIC: [#870](https://github.com/s977043/plangate/issues/870)（OPEN・実測 2026-08-02）
> 入力: [`pbi-input.md`](./pbi-input.md)（main 実在・本 plan では**編集しない**）
> 生成: 2026-08-02（base = `origin/main` = `a4afacb`）
> Mode: **critical**（下記 `## Mode判定` 参照。**autonomous APPROVE 不可 / 人間 C-3 必須 / C-2 複数観点 / V-4 実行対象**）

## 確認事項（B-1）

本 plan の生成にあたり Human への追加質問は行わず、pbi-input と main 実測で確定できる範囲に閉じた。
**確定できなかった論点は勝手に決めず `## Questions / Unknowns` に残す**（C-3 で人間が判断）。

> **C-1 FAIL 是正（2026-08-02・`review-self.md` 反映後）**: 論点 ID は **U-1 〜 U-12**。
> うち **U-2 / U-3 / U-6 は plan 段階で確定**（Unknowns から降格・§Questions の「確定済み」表に移動）、
> **U-10 / U-11 / U-12 を C-1 指摘から新規追加**した。
>
> **C-2 反映（2026-08-02・`review-external.md` の R-001 〜 R-C10 / 計 22 件）**: 2 レーン外部レビュー
> （設計妥当性 / コードベース整合）の major 13 件・minor 7 件・info 2 件を **1 回で確定反映**した。
> **U-7 を plan 段階の確定へ降格**（R-009）したため **C-3 で判断を要する未決は 8 件**
> （U-1 / U-4 / U-5 / U-8 / U-9 / U-10 / U-11 / U-12）。指摘の集約・監査表・反映 disposition は
> [`review-external.md`](./review-external.md) が正本（**追記専用**）。

pbi-input に既に裁定・確定として記載され、本 plan で**再オープンしない**もの:

1. **schema 配置 = `docs/schemas/`（非 HO・Phase 1 shadow）**。本番接続（promotion gate / Gate 接続）の C-3 で `schemas/` へ 1 回の HO patch 昇格。裁定正本: [`../discussions/2026-07-31-schema-placement-ho-arbitration.md`](../discussions/2026-07-31-schema-placement-ho-arbitration.md) §7（裁定日 2026-07-31 / s977043）
2. **producer / validator は `scripts/ai-loop/`（非 HO）** — AI 実装可能
3. **Mode = critical 確定**

### ⚠️ pbi-input の記述で main 実測と乖離していた点（本 plan の記述を正とする）

pbi-input.md は main マージ済みのため**訂正せず**、以下は本 plan を正とする（`Refs:` で追跡）:

| # | pbi-input の記述 | main 実測（2026-08-02） | 本 plan の扱い |
|---|-----------------|------------------------|--------------|
| A | 「**#873（delivery.py）**/ #811: 未実装・OPEN → fixture 先行で実装」（pbi L112） | **#873 は CLOSED**（`gh issue view 873` → CLOSED）。`scripts/ai-loop/delivery.py`（27139 B）は **main に merge 済み**で `STATES` 7 + `EXITS` 2 を提供している | **#873 は実装済み前提に更新**。terminal_state / ci_outcomes / repair_rounds の供給元は fixture ではなく**実在の `delivery.py` 契約**から取る。fixture 先行が必要なのは **#811 / #869 / #868 のみ** |
| B | 「§6 `derived_loopspec_hash`/`plan_hash` が `harness_version`/`plan_hash` の供給元」（pbi L80） | `derived_loopspec_hash` は **LoopSpec 派生結果の正規化 hash**（c3-prime-contract §6 L127）であり、**ハーネス自身のバージョンではない**。`harness_version` の供給元は main に**存在しない**（`grep -rn 'harness_version' scripts/ bin/` = **0 件**） | `plan_hash` の供給元が c3-prime である点のみ採用。**`harness_version` は供給元未確定 → 論点 D4 + Unknowns U-1** |
| C | 「近縁は arbiter 裁定 record 28 件」 | **28 件で一致**（`ls docs/working/ai-loop-runs/*.json \| wc -l` = 28）。内訳も **9 キー 25 件 / 14 キー 3 件**で一致 | そのまま採用（AC-15 の対象） |
| D | 「`schemas/**` は HO」 | 一致。ただし **EH-3 hook の実効パターンは `schemas/*.schema.json`**（`scripts/hooks/check-plan-hash.sh` L131）で、`ho-paths.md` L28 の `schemas/**` より**狭い** | 昇格 PBI 設計時に効くため契約 doc に明記（Step 1） |

## Goal

ai-loop の完了 run から **RunEvidence**（正規化 run 証跡）を **決定論的に生成・fail-closed に検証**できる契約と実装を Phase 1（shadow・非 HO）で確立し、Evolution Loop（#869）と Promotion Gate（#811）が **RunEvidence だけを入力として** 先行実装できる fixture 一式を供給する。

## Constraints / Non-goals

- **AI による merge は行わない**（NO MERGE BY AI・C-4 は Human-owned）。producer は判定も merge も行わない **read-only 生成器**
- **#869 の clustering / experiment policy を再定義しない**。**#811 の promotion decision table を再定義しない**（issue Non-goals verbatim）。本 PBI が提供するのは **provenance 橋渡しのフィールド契約と fixture** まで
- **active run への hot patch を行わない**（AC-12 の裏返し）
- **SaaS / 外部 memory service を必須化しない**
- **`schemas/` を触らない**（HO。Phase 1 は `docs/schemas/` 固定。触る必要が生じたら即停止 = Replan Trigger）
- **`delivery.py` / `c3_contract.py` / `c3prime_verify.py` / `arbiter.py` / `metrics.py` を改変しない**（本 PBI は上位 artifact であり既存判定器の consumer。改変が必要と判明した時点で即停止）
- **hidden CoT / raw transcript / secret / account 識別子を要求も保存もしない**（AC-6）

## アプローチ比較（B-2）

### 論点 D1: schema の表現形式（`docs/schemas/` 内で JSON Schema か 代表 YAML か）

配置先は裁定済みだが**表現形式は未確定**。実測した 2 つの前例が食い違う:

| 案 | 内容 | 実測根拠 | 評価 |
|----|------|---------|------|
| **D1-A（採用）** | `docs/schemas/run-evidence.schema.json` = **JSON Schema draft 2020-12**。`schemas/*.schema.json` の書式をそのまま踏襲 | `schemas/*.schema.json` は **28 本**（実測）。`$schema` は 2020-12 が 23 本 / draft-07 が 5 本、`$id` は 28/28 全ファイルに存在、うち **27 本**が `https://github.com/s977043/plangate/schemas/<name>` 形式（例外 1 本 = `maintenance.schema.json` の `https://plangate/schemas/…`）。`additionalProperties` 出現 78 箇所中 **72 が `false`** | **昇格時の diff が最小**（`$id` を最初から昇格後 URL で固定するため、`schemas/` への **`git mv` 1 手**のみ・`$id` の変更も不要）。裁定の「1 回の HO patch で昇格」を実現できる唯一の形式 |
| D1-B | `docs/schemas/run-evidence.yaml` = コメント付き代表 YAML | `docs/schemas/child-pbi.yaml`（**`docs/schemas/` 唯一の実在ファイル**・298 行）は L1-9 で「本書は schema を『コメント付きの代表 YAML』として記述する / JSON Schema 等への変換は実装 PBI で行う」と自己宣言 | 昇格時に **形式変換が必要**（`schemas/` は JSON Schema 前提）。機械検証も別途必要。裁定の「1 回の HO patch」に反する |

**採用: D1-A**。ただし `docs/schemas/` は **CI 検証経路を持たない**ため（下記）、機械検証は自作する。

> **実測: `docs/schemas/` の検証経路**
>
> - `.github/workflows/schema-validate.yml` の trigger paths は `docs/working/**/*.json` / `schemas/**/*.json` / `scripts/validate-schemas.py` / `scripts/schema_mapping.py` / 自ファイル。**`docs/schemas/**` は含まれない**
> - `tests/extras/ta-05-validate-schemas.sh` は固定 fixture 2 件（`$FIXTURES_DIR/schema-validate/{valid,invalid}/c3.json`）のみ検証。**`schemas/` を glob 走査しない**
> - `tests/extras/ta-35-yaml-schema.sh` の対象は `scripts/validate-yaml-schemas.py` の `KNOWN_PAIRS` **ハードコード 3 組**のみ
> - `grep -rn 'docs/schemas' scripts/ tests/ .github/` = **5 件**。全て `scripts/check-orchestrator-docs.sh`（`child-pbi.yaml` の YAML parse + 必須キー grep）で、**この script はどこからも呼ばれていない**（`grep -rn 'check-orchestrator-docs' .github/ tests/ bin/ scripts/` の自己参照除外 = **0 件**）
>
> ⇒ **`docs/schemas/` に置いたものは現状 CI で「schema としては」一切検証されない**。本 PBI は `run_evidence_verify.py`（非 HO）+ `tests/extras/ta-59-*.sh` で検証経路を**自作**する（`tests/run-tests.sh` は `for extra in "$EXTRAS_DIR"/ta-*.sh` で glob source するため、ファイルを置くだけで CI job `plangate CLI tests` に乗る）
>
> ⚠️ **「schema 検証経路が 0 本」と「一切の CI に触れない」は別**（C-2 レーン B → 設計妥当性 返送論点 6 / R-C09(b)）。`.github/workflows/metrics-privacy.yml` の `on.pull_request.paths` は `**/*.json` を含み、scan 対象の除外は `grep -v '^tests/fixtures/'` **のみ**（実測）。したがって `docs/schemas/run-evidence.schema.json` は **EH-8 privacy CI の走査対象に入る**。契約 doc にこの書き分けを明記する（Step 1）。

### 論点 D2: producer の入力（「events」の定義）

issue AC-2 は「同一入力 events から同一 RunEvidence を再生成できる」と言うが、**「events」の実体は main に存在しない**。実測で 20 フィールドの供給元は 4 レイヤに分散している。

| 案 | 内容 | 評価 |
|----|------|------|
| D2-A | `delivery/record.jsonl` 単独を events とみなす | terminal_state / ci_outcomes / repair_rounds は取れるが、**plan_hash / c3_prime_decision_ref / source_sha が取れない**（AC-3 の「同一 run へ結合」が成立しない） |
| **D2-B（採用）** | **複数ソースの明示合成**: `approvals/c3.json` + `delivery/record.jsonl` + `docs/working/ai-loop-runs/*.json`（arbiter record）+ 呼び出し側注入値 | AC-3 を満たす唯一の構成。各ソースの**有無を明示状態にする**ことで AC-4（missing / partial）と両立 |

**採用: D2-B**。producer は **純関数 + 明示注入**（`plan_package.py` / `delivery.py` の設計原則を転写）:

- **`now()` を直接参照しない** — `started_at` / `completed_at` / `issued_at` はすべて引数注入（`delivery.append_entries(path, entries, now)` / `plan_package.build_c3_prime(..., issued_at, ...)` と同型）
- **ネットワーク・外部プロセスを呼ばない** — `repository` も `git remote` から取らず注入（`delivery.py` docstring「純判定器: ネットワーク・外部プロセスを一切呼ばない」の転写）
- **serialization は `json.dumps(ensure_ascii=False, indent=2, sort_keys=True) + "\n"`** — `plan_package.serialize_c3_prime()` L343 と byte 互換
- **hash は `c3_contract.canonical_hash()` を import 再利用**（`json.dumps(sort_keys=True, separators=(",",":"))` の sha256 / `sha256:` prefix）。**独自実装を作らない**（`delivery.action_id()` が同じ再利用をしている）

#### 注入値の全数と欠落時の既定（**C-2 R-C04 / B→A-1 の是正**）

producer が受け取る注入値は以下の **5 つで全数**とする。**注入値の一覧と、各値が欠落したときの
既定を plan で閉じる**（当初案は `--pr-number` が全数から漏れており、下流の
`delivery._completed_rounds()` が **例外ではなく `0` を返す**ため fail-open していた）。

| 注入値 | 用途 | 未注入時の既定 |
|-------|------|--------------|
| `--now` | `completed_at` | **エラー**（fail-closed。TC-12） |
| `--started-at` | `started_at` | **エラー**（fail-closed） |
| `--repository` | `repository` | **エラー**（fail-closed） |
| `--run-id` | `run_id`（arbiter record 14 キー世代から取れない場合） | **エラー**（fail-closed） |
| **`--pr-number`**（**C-2 で追加**） | `repair_rounds` / `ci_outcomes` / `review_findings` の PR 絞り込み | **`unavailable`**（`0` にしない） |

> **実測根拠（R-C04）**: `delivery._pr_receipts(entries, pr)` は `e.get("pr_number") == pr` で
> 絞るため、`pr=None` を渡すと `pr_number` を持たない entry だけが残り、
> `_completed_rounds()` は `max(rounds, default=0)` により **例外ではなく `0`** を返す。
> 実在の一次証跡（`docs/working/TASK-0917/evidence/e2e/run/delivery/record.jsonl`）で
> `_completed_rounds(entries, 940) = 1` / **`_completed_rounds(entries, None) = 0`** を実測確認した。
> `0`（= 修理 0 回）を黙って出力すると、本 plan が最重要リスクに挙げた
> 「`unavailable` を `0` で埋めて fail-open」を**転写先の関数仕様が実現してしまう**。
> したがって `pr_number` は **`kind=merge_ready` entry の `record.pr_number`**（実測で保持）から
> 解決し、解決不能なら `--pr-number` の明示注入を要求、いずれも無ければ
> 当該 3 フィールドを **`unavailable`** に倒す（TC-64）。

#### producer の入力ソース allowlist（**C-2 R-010 の是正 / AC-6 の「要求しない」側**）

AC-6 verbatim は「hidden CoT / raw transcript / secret / account 識別子を**要求も保存も**しない」だが、
当初の TC（TC-19 〜 TC-22 / TC-51）は**すべて出力側**の検査であり、
「producer の**入力契約**が transcript を要求しない」ことを固定する TC が無かった。

**producer が読んでよい入力ソースは以下の 4 つのみ**（契約 doc に明記・TC-63 でソース走査固定）:

1. `docs/working/TASK-XXXX/approvals/c3.json`
2. `docs/working/TASK-XXXX/delivery/record.jsonl`
3. `docs/working/ai-loop-runs/*.json`（arbiter record）
4. 呼び出し側注入値（上表 5 つ）

**transcript / session log / CoT / 環境変数 / ネットワーク / 外部プロセスは読まない**
（`delivery.py` の「純判定器」原則の転写）。

#### RunEvidence 20 フィールド × 供給元（実測ベース）

| # | field | 供給元（実測） | 取得不能時の扱い |
|---|-------|--------------|----------------|
| 1 | `run_id` | arbiter record 14 キー世代の `run.run_id`（**3/28 件のみ保有**・実測） / 無ければ呼び出し側注入 | **必須**・欠落は fail-closed |
| 2 | `task_id` | `approvals/c3.json` の `task_id`（`c3_contract.RECORD_REQUIRED_KEYS`）。**`task_dir` 名に束縛**（`c3prime_verify.py` L83-84 の転写） | fail-closed |
| 3 | `started_at` | 呼び出し側注入（`--started-at`） | fail-closed |
| 4 | `completed_at` | 呼び出し側注入（`--now`） | fail-closed |
| 5 | `repository` | 呼び出し側注入（`--repository`）。producer は `git remote` を呼ばない | fail-closed |
| 6 | `source_sha` | `approvals/c3.json` の `source_sha`（形式 `[0-9a-f]{7,40}`） | fail-closed |
| 7 | `final_head_sha` | `record.jsonl` の `kind=merge_ready` entry の `record.head_sha` / 無ければ最終 `kind=state` entry の `head_sha` | **`terminal_state` 依存**（D7 の必須/`unavailable` マトリクス参照）。`MERGE_READY` / `HUMAN_ESCALATED` は必須（欠落は fail-closed）だが、**`BLOCKED` は `record.jsonl` 自体が存在しないため構造的に `unavailable`**（C-2 R-003 の是正。当初の「非終端は発行しないので missing は起きない」は **delivery 層を通過した終端しか想定していなかった**） |
| 8 | `plan_hash` | `approvals/c3.json` の `plan_hash`（`sha256:` prefix 付き） | fail-closed |
| 9 | `c3_prime_decision_ref` | `approvals/c3.json` への repo 相対参照 + `plan_package_hash`。**§4 全規則の再検証を通過した場合のみ**（AC-14） | fail-closed |
| 10 | `harness_version` | **供給元が main に存在しない（実測 0 件）** → **論点 D4 / Unknowns U-1** | — |
| 11 | `routing_decisions[]` | **#868 未実装**（`requested`/`resolved` routing の producer が無い） | **空配列で埋めない**。`unavailable` として明示（metrics.py の skip パターン転写）。**Phase 1 では常に `unavailable`**（D7 の known-unavailable 3 フィールドの 1 つ） |
| 12 | `ci_outcomes[]` | `record.jsonl` の `kind=merge_ready` の `record.check_summary`（`{check_name: conclusion}`）+ `kind=state` entry の `reasons` | 未取得は `unavailable`（**`terminal_state=BLOCKED` では構造的に `unavailable`**） |
| 13 | `review_findings[]` | `record.jsonl` の `record.review_disposition`（`{finding_id: disposition}`）+ `kind=receipt` かつ `action_kind=repair_review` の `finding_type` | 未取得は `unavailable`（**`terminal_state=BLOCKED` では構造的に `unavailable`**） |
| 14 | `repair_rounds` | `record.jsonl` の当該 PR の receipt の `round` 最大値（**`delivery._completed_rounds()` と同一定義**を再実装せず import）。**PR 番号は `kind=merge_ready` entry の `record.pr_number` または `--pr-number` 注入から解決する** | `0` は「0 回」・**PR 番号が解決できない場合は `unavailable`**（**`0` にしない**。実測で `_completed_rounds(entries, None)` は例外にならず `0` を返す = C-2 R-C04）。`terminal_state=BLOCKED` では構造的に `unavailable` |
| 15 | `replan_count` | **供給元が main に存在しない**（実測） | **plan 確定（U-2 = 解決）: Phase 1 は `unavailable` 固定**。理由は下記 §Questions 「確定済み」参照。D7 の known-unavailable 3 フィールドの 1 つ |
| 16 | `human_interventions[]` | arbiter record の `decision=HUMAN_ESCALATED` + `record.jsonl` の `kind=state` かつ `state=HUMAN_ESCALATED` + `kind=notice` entry | 未取得は `unavailable` |
| 17 | `terminal_state` | **論点 D3 の正規化マッピング** | 非終端は `partial`（発行しない） |
| 18 | `quality_metrics{}` | **当該 run の events のみから計算できる指標に限定**（C-2 R-005 の是正）。Phase 1 の許可指標は **`first_pass`**（当該 run の `round_index == 1` の record の `decision == "AUTO_APPROVED"` か）と **`rounds`**（当該 run の round 数）の **2 つ**。`metrics.py` は **import しない**（不変対象への依存を増やさない）— 上記 2 指標の**導出規則のみ転写**する | 未取得は `unavailable`。⚠️ **corpus 集計値（`decision_counts` / `round_distribution` / `hotl_health` / `first_pass_rate`）は格納しない** |
| 19 | `cost_metrics{}` | **供給元が存在しない**（`docs/working/_metrics/events.ndjson` は `.gitignore` L53 で除外・実測 = commit される artifact から参照できない） | **plan 確定（U-3 = 解決）: Phase 1 は `unavailable` 固定**。D7 の known-unavailable 3 フィールドの 1 つ |
| 20 | `evidence_refs[]` | **repo 相対パスの参照のみ**（本文は保存しない）。絶対パス禁止（AC-6）。**列挙方法は「注入値または record 由来のみ」**（C-2 R-012） | 空配列可 |

> **`quality_metrics{}` を corpus 集計値にしない理由（C-2 R-005・実測）**: `metrics.py` の
> `decision_counts` / `round_distribution` / `hotl_health` / `first_pass_rate` は
> `collect(runs_dir)` が **runs_dir 配下の全 record を横断集計**した値である
> （`hotl_health = _compute_hotl_health(decision_counts, grouped)` / `first_pass_numerator /
> first_pass_denominator` はいずれも全 run が分母。実測）。これを 1 run の EV に格納すると
> **arbiter record が 1 件増えるだけで過去 run の EV の byte が変わり**、AC-2（同一入力 →
> 同一出力）と TC-48（golden byte 比較）が**後日 CI で原因不明に赤くなる**。
> 決定論を守るため、EV に載せるのは **当該 run の events だけで閉じる指標**に限定する。
>
> **`evidence_refs[]` をディスク走査で列挙しない理由（C-2 R-012）**: producer が
> `docs/working/TASK-XXXX/evidence/` を走査して列挙する実装にすると、**ファイルの増減で
> 同一 events から異なる EV が出る**（AC-2 が壊れる）。列挙は
> **注入値または `record.jsonl` 由来の参照のみ**とし、producer 側でのディスク走査を禁止する
> （Step 3 のチェックポイントで固定）。

### 論点 D3: `terminal_state` 語彙の正規化（**最重要の設計論点**）

issue は `terminal_state(MERGE_READY|HUMAN_ESCALATED|BLOCKED)` の 3 値を指定するが、**main の実測ではこの 3 値をそのまま出す層が存在しない**。語彙は 3 系統に分裂している:

| 層 | 実測値 | 実測コマンド |
|----|-------|------------|
| `delivery.py` | `STATES` = **7 値**（`CHECKS_FAILED` / `CONFLICT` / `MERGE_READY` / `MERGE_READY_CANDIDATE` / `REVIEW_REPAIR` / `WAITING_FOR_CHECKS` / `WAITING_FOR_REVIEW`）+ `EXITS` = **2 値**（`EXEC_RETURN` / `HUMAN_ESCALATED`）。`TERMINAL = "MERGE_READY"` のみが終端 | `python3 -c "import delivery; print(len(delivery.STATES), len(delivery.EXITS))"` → `7 2` |
| `c3_contract.py` | `VALID_DECISIONS` = **3 値**（`AUTO_APPROVED` / `HUMAN_ESCALATED` / `BLOCKED`） | 同上 → `('AUTO_APPROVED','HUMAN_ESCALATED','BLOCKED')` |
| issue #874 | `MERGE_READY` / `HUMAN_ESCALATED` / `BLOCKED` | issue 本文 |

⇒ issue の 3 値は **2 つの状態機械の和集合**であり、`BLOCKED` は delivery 層に存在せず、`MERGE_READY` は c3-prime 層に存在しない。

**採用する正規化マッピング（契約 doc と schema と producer に同一表として持たせる）**:

| RunEvidence `terminal_state` | 由来 | 条件 |
|-----------------------------|------|------|
| `BLOCKED` | c3-prime 層 | `c3.json` の `decision == "BLOCKED"`（= exec に到達していない） |
| `HUMAN_ESCALATED` | 両層 | `c3.json.decision == "HUMAN_ESCALATED"` **または** `record.jsonl` の最終 `kind=state` の `state == "HUMAN_ESCALATED"` |
| `MERGE_READY` | delivery 層 | `record.jsonl` に `kind=merge_ready` entry が存在する（`delivery.assess()` L391-400 が刻む唯一の経路） |
| **（発行しない）** | — | 上記いずれにも該当しない = 非終端（`WAITING_FOR_*` / `CHECKS_FAILED` / `CONFLICT` / `REVIEW_REPAIR` / `MERGE_READY_CANDIDATE` / `EXEC_RETURN`）。**RunEvidence を完了 run として出力せず `evidence_status=partial` を返す**（AC-4） |

> **本マッピングの負側検証（C-2 R-001 の是正 / plan 自身が「最重要の設計論点」と位置づけた層）**:
> 当初の TC で `terminal_state` を assert していたのは **TC-16 / TC-41（どちらも `HUMAN_ESCALATED`）だけ**であり、
> **`MERGE_READY` の導出を検査する TC = 0 / `BLOCKED` の導出 = 0 / 非終端 7 状態で発行しないことの検査 = 0** だった。
> この状態では **producer が最終 `kind=state` を見て `MERGE_READY_CANDIDATE` を `MERGE_READY` に丸めても
> 1 件も TC が落ちず**、未収束 run が #869 の学習母集団と #811 の promotion 入力に混入する。
> 以下 3 本を必須 TC として追加する（D3 の実装タスク **T-16 にも「対応 TC」を付す**）:
>
> | 追加 TC | 検査内容 |
> |---------|---------|
> | **TC-57** | `MERGE_READY` 正側 — `record.jsonl` に `kind=merge_ready` entry が**物理的に存在する**ときのみ `MERGE_READY` |
> | **TC-58** | `BLOCKED` 正側 — `c3.json.decision == "BLOCKED"` で発行され、delivery 層 4 フィールドが `unavailable` になる（D7 のマトリクス） |
> | **TC-59** | **非終端 7 状態を parametrized で全数**（`WAITING_FOR_CHECKS` / `WAITING_FOR_REVIEW` / `CHECKS_FAILED` / `CONFLICT` / `REVIEW_REPAIR` / `MERGE_READY_CANDIDATE` / `EXEC_RETURN`）→ **発行拒否** |
>
> ⚠️ `test-cases.md` の Edge cases 表で「非終端 run」に割り当てていた **TC-16 は非終端を扱わない**ため、
> 割当を **TC-59** へ付け替える。
>
> **C-3 論点（U-4）**: 「非終端は発行しない」か「4 値目 `IN_PROGRESS` を作る」か。前者を採ると `EXEC_RETURN` で終わった run（= plan 逸脱で exec に差し戻された run）の証跡が RunEvidence として残らない。#869 は「3 件以上の同型 Run」から candidate を作るため、**失敗パターンこそ学習源**である可能性がある。**勝手に決めず C-3 判断とする**。plan では安全側（発行しない = ready 扱いしない）を既定にする。

### 論点 D4: `harness_version` の定義（AC-12 の対象）

実測で候補が 3 つあり、**値が一致しない**:

| 候補 | 実測値 | 実測箇所 |
|------|-------|---------|
| CLI 版 | `0.2.0` | `bin/plangate` L7 `PLANGATE_VERSION="0.2.0"` |
| plugin / release 版 | `8.18.0` | `plugin/plangate/.claude-plugin/plugin.json` L3 / `.claude-plugin/marketplace.json` L9・L15。`git describe --tags --abbrev=0` = `v8.18.0` |
| LoopSpec 派生 hash | run ごとに変動 | c3-prime-contract §6 L127 `derived_loopspec_hash` |

**`bin/plangate` の `0.2.0` と plugin の `8.18.0` は同一 repo 内で 40 倍以上乖離している**（実測）。どちらを「ハーネスのバージョン」と呼ぶかは本 PBI 単独で決められない。

**本 plan の提案（C-3 で確定 / U-1）**: `harness_version` を **単一文字列ではなく object** にし、`{"plugin_version", "cli_version", "corpus_hash"}` の 3 要素を持たせる。`corpus_hash` = 判定基盤 corpus（rollout-policy §2 carve-out ①②③ = `scripts/ai-loop/**` / `docs/workflows/ai-loop/**` / `docs/ai/ai-loop/**` / `.agents/skills/ai-loop-cycle/**` / `.claude/skills/ai-loop-cycle/**`）のファイル内容 hash を `canonical_hash()` で束ねた値。**AC-12（active run 中に変化しない）は「run 開始時に注入した値と終了時の値の byte 一致」で機械検証でき、値の意味論とは独立に成立する**ため、意味論が未確定でも AC-12 の TC は書ける。

### 論点 D5: privacy（AC-6）の強制層

実測: **EH-8（`scripts/hooks/check-metrics-privacy.sh`）は実際に BLOCK した実績がある**。TASK-0917 の実 PR 実走で raw REST レスポンス（`stdout` / `stderr` を含む）を保存したところ CI で BLOCK され、`docs/working/TASK-0917/evidence/e2e/RAW-EXCLUDED.md` として除外理由が残っている。

EH-8 の実効範囲（実測）:

- **禁止キー 14 個**（L37）: `file_path` / `file_paths` / `stack_trace` / `stacktrace` / `command_output` / `stdout` / `stderr` / `raw_response` / `raw_request` / `api_key` / `user_prompt` / `system_prompt` / `prompt_text` / `absolute_path`
- **走査対象は staged の `*.json` / `*.ndjson` のみ**（L88-91 の `case "$f" in *.json|*.ndjson)`）。**`*.jsonl` と `*.md` は素通りする**（`case` glob で実測確認済み: `a.jsonl` → skipped）

⇒ **設計判断: RunEvidence の保存形式を `.json`（1 run 1 ファイル）に固定し、`.jsonl` にしない**。これにより AC-6 の禁止キー検査が **hook 層で自動的に強制される**（producer 側の自主規制に依存しない）。`docs/working/ai-loop-runs/*.json` が既に `.json` である前例とも一貫。

> 追加の privacy 制約（`docs/ai/metrics-privacy.md` §5 実測）: 絶対パス（`/Users/...`）は FORBIDDEN。`evidence_refs[]` は **repo 相対パスのみ**とし、キー名も `file_path` を避ける（EH-8 の禁止キーと衝突するため）。

### 論点 D6: producer / validator を 1 モジュールにするか 2 つに割るか

**採用: 2 モジュール**（`run_evidence.py` = producer / `run_evidence_verify.py` = 受理器）。理由は既存の同型分割をそのまま転写できるため:

- `plan_package.py`（producer・`build_c3_prime()` / `serialize_c3_prime()`）と `c3prime_verify.py`（受理器・**exit code 契約 0 / 1 / 10**）が既にこの形
- 受理器を分けることで **trust boundary**（c3-prime-contract §7「decision 値を無検証で信頼してはならない」）を構造として表現できる。生成側の検証を信頼せず受理側が再検証する

#### 受理器の入力契約（**C-2 R-004 の是正・plan で確定**）

当初 plan は producer の入力・CLI だけを定義し、**受理器の入力を定義していなかった**。
このままだと **AC-4 の tampered 検出（TC-08）が実装不能**になる:
入力が **EV 単体**なら、`sha256:` + 64 hex の形式を保った `plan_hash` の 1 文字改変は
**形式上は正当**であり（EV に自己 hash が無い）検出できず、known-unavailable により
**exit 11（partial）** で返る。partial は「ready 扱いしない」だけで拒否ではないため、
**改竄された provenance が promotion まで到達しうる**。

**確定する署名**（姉妹受理器 `c3prime_verify.py <task_dir> [expected_sha]` と同型の task_dir 束縛）:

```text
run_evidence_verify.py <ev.json> <task_dir>
```

**受理器が再検証する対象（生成側の申告を信頼しない）**:

| EV フィールド | 照合先 |
|--------------|-------|
| `task_id` | `task_dir` のディレクトリ名（`c3prime_verify.py` の `task_dir.name != task_id` 束縛と同型） |
| `plan_hash` / `source_sha` | `<task_dir>/approvals/c3.json` の同名フィールド |
| `c3_prime_decision_ref` | `<task_dir>/approvals/c3.json` への repo 相対参照として解決可能か |
| `final_head_sha` / `repair_rounds` | `<task_dir>/delivery/record.jsonl` の**再計算値**（`delivery.load_entries()` の `entry_id` 再計算照合と同型） |

> **EV 自己完結型（`evidence_hash` を EV 自身に持たせる案）は採らない**。理由: `required` が
> **21 → 22** になり D8 の確定と versioning policy（破壊的変更 = 3 issue 合意）に波及するうえ、
> 「生成側が自分の証跡の完全性を自己申告する」構造となり **D7-2 の trust boundary 方針と矛盾する**。
> task_dir 再検証型なら required は 21 のまま・trust boundary も保たれる。

**exit code 契約（`c3prime_verify.py` docstring の意味論に揃える）**:

| exit | 意味 | 前例との関係 |
|------|------|------------|
| `0` | RunEvidence として受理（`evidence_status=complete`・全束縛整合） | `c3prime_verify.py` docstring `exit 0` と**同一** |
| `1` | 検証 NG（fail-closed。理由を stderr に出力） | 同 `exit 1` と**同一** |
| `10` | **legacy**（RunEvidence ではなく 9 キー / 14 キー arbiter record を渡された。呼び出し側が legacy 経路へ委譲） | 同 `exit 10` と**同一**（当初案から是正） |
| `11` | **partial**（必須フィールドは揃うが `unavailable` を含む = ready 扱いしない・呼び出し側が明示処理） | 本 PBI で**新規に追加**する値（前例に衝突しない空き番） |

> **C-1 是正（C1-B1B2-17）**: 当初案は `10`=partial / `11`=legacy だったが、これは
> **姉妹受理器と `10` の意味が逆転**していた。実測で `scripts/ai-loop/c3prime_verify.py` の
> legacy 分岐は `return 10  # legacy → 呼び出し側 shell へ委譲` であり、**その `10` を legacy として
> 消費している呼び出し側が 2 箇所実在する**（`scripts/ai-loop/delivery.py` の `if rc == 10:`
> / `bin/plangate` の `_plangate_c3_dispatch` 後段のコメント `# _c3_rc == 10: legacy 経路`）。
> 同一ディレクトリの 2 受理器で `10` の意味が割れると、将来 rc を共通ハンドラで扱った時点で
> **legacy を partial と誤読**する経路が生まれる。したがって **前例に合わせる**（`10`=legacy）を
> plan の既定とし、partial は未使用の `11` に置く。**契約 doc（Step 1）に両受理器の rc 対応表を必ず載せる**。
> 値割当の最終確定は **U-11 として C-3 判断に上げる**（本 plan は安全側の既定を置くだけ）。
>
> ⚠️ **消費側の強度は 2 箇所で異なる（C-2 R-C07・実測）**: `delivery.py` は `if rc == 10:` の
> **厳密比較**だが、`bin/plangate` は `if [ "$_c3_rc" = "0" ] … elif [ "$_c3_rc" = "1" ] … else`
> という **catch-all**（値を判定せず 0/1 以外をすべて legacy にフォールバック）である。
> plan の結論（`10`=legacy / `11`=partial）自体は妥当だが**根拠の強度が違う**ため、契約 doc の
> rc 対応表にこの事実を明記し、**新受理器の rc を `_plangate_c3_dispatch` 経路へ流さない**
> ことを制約として書く（`11` を流すと catch-all が legacy と誤読する）。

### 論点 D7: Phase 1 で `evidence_status=complete`（exit 0）に到達できるか

**C-1 FAIL（C1-PLAN-04）の是正論点**。D2 の供給元表のとおり、**Phase 1 では 3 フィールドが
構造的に `unavailable` にしかならない**:

**(a) Phase 1 固定の known-unavailable（`terminal_state` に依存しない・3 件）**:

| field | 構造的に unavailable な理由（実測） |
|-------|--------------------------------|
| `routing_decisions[]` | #868 **OPEN**（`gh issue view 868` = OPEN）。routing producer が main に存在しない |
| `replan_count` | 供給元不在（`grep -rn 'replan' scripts/ bin/` に producer なし）。U-2 で `unavailable` 固定に確定 |
| `cost_metrics{}` | `docs/working/_metrics/events.ndjson` が `.gitignore` L53 で除外。commit される artifact から参照不能。U-3 で `unavailable` 固定に確定 |

**(b) `terminal_state` 依存の known-unavailable（**C-2 R-003 で新規に判明**・最大 4 件）**:

当初 D7 は「known-unavailable は 3 フィールド」と書いていたが、これは
**終端 = delivery 層を通過した run** しか想定していなかった。
**`BLOCKED` は `c3.json.decision == "BLOCKED"`（= exec に到達していない）で発行される終端**であり、
**`delivery/record.jsonl` が存在しない**。したがって delivery 層由来の 4 フィールドが
**構造的に取得不能**になる。この非対称を契約 doc（Step 1）に **`terminal_state` ×
フィールドの必須/`unavailable` マトリクス**として置く:

| field | `MERGE_READY` | `HUMAN_ESCALATED` | `BLOCKED` |
|-------|--------------|-------------------|-----------|
| `final_head_sha` | **必須**（欠落 = fail-closed） | **必須** | **`unavailable`** |
| `ci_outcomes[]` | **必須** | 取得できれば必須 / 無ければ `unavailable` | **`unavailable`** |
| `review_findings[]` | **必須** | 取得できれば必須 / 無ければ `unavailable` | **`unavailable`** |
| `repair_rounds` | **必須**（PR 番号解決不能なら `unavailable`） | 同左 | **`unavailable`** |
| `terminal_state` | `MERGE_READY` | `HUMAN_ESCALATED` | `BLOCKED` |
| 上記 (a) の 3 件 | `unavailable` | `unavailable` | `unavailable` |

> **この明確化が無いと何が壊れるか（C-2 R-003）**: 実装者が required を満たすために
> `final_head_sha` に**空文字やダミー sha を入れる**（EV に自己 hash が無いため tampered 検出も
> 効かない）。逆に missing 扱いで exit 1 に倒すと fixture 表の「fx-05 → exit 11」と矛盾して
> **T-32 が止まる**。**どちらに転んでも plan と矛盾する**ため、plan 段階でマトリクスを確定する。
> fx-05（`BLOCKED`）用の TC を **TC-58** として追加する。

したがって **Phase 1 の producer が出力する RunEvidence は必ず `unavailable` を含み、
受理器は必ず partial（`11`）を返す**。当初案は fixture 1〜5 の期待受理器 exit を `0` と
していたが、**その `0` に到達する経路は存在しない**（fixture 側で routing を捏造すれば
到達するが、それは「空配列で埋めない」「手書き fixture を実 record と乖離させない」という
本 plan 自身の方針に反する）。

**plan の既定（安全側）— 2 点を確定する**:

1. **Phase 1 の producer 出力は常に `evidence_status=partial`**（受理器 exit `11`）。
   契約 doc に「**Phase 1 では exit 0 は構造的に発生しない**」と明記し、
   known-unavailable を **(a) Phase 1 固定 3 件**と **(b) `terminal_state` 依存 最大 4 件**に
   **分けて**列挙する（C-2 R-003）。
   fixture 1〜6 の期待受理器 exit は **`11`** に統一する（`terminal_state` の期待値は不変）。
2. **`evidence_status` は record に格納せず、受理器が導出する判定語彙とする**。
   理由は trust boundary（c3-prime-contract §7 L133「decision 値を無検証で信頼してはならない」の転写）
   — **生成側が自分の証跡の完全性を自己申告できる構造にしない**。これにより schema の
   `required` は「issue の 20 フィールド + `schema_version`」の **21** に閉じる（D8）。

> **`terminal_state` と `evidence_status` は直交する**（契約 doc に明記）。
> `terminal_state=MERGE_READY` かつ `evidence_status=partial` は**正常な状態**であり、
> 「run は終端に達した / だが証跡の一部が Phase 1 では取得不能」を意味する。
> **partial の理由は必ず stderr に `unavailable` フィールド名として全数列挙される**
> （C-2 R-003 の是正。当初の「partial の理由は known-unavailable のみなので曖昧化しない」は
> **`terminal_state` 依存の unavailable を見落としていたため誤り**。理由が複数種類になりうる以上、
> 「曖昧化しない」の担保は *理由が 1 種類であること* ではなく *理由が機械可読に列挙されること* に置く）。
>
> **受理器の exit 0 経路が死にコードにならないこと**: 受理器の `0` は
> **unit test が合成した「全フィールド available な EV」**で検証する（TC-56）。
> ⚠️ **TC-09 の positive 側（`^_` 注釈キーは許容され exit 0）も、合成 complete EV を入力にした
> 場合に限る**（C-2 R-006）。producer 出力に `^_` を足しただけの EV は D7-1 により `11` になる。
> 「Phase 1 の producer から出ない」ことと「受理器が 0 を返す条件が実装・検証される」ことは別問題であり、
> 後者は fixture ではなく合成入力で担保する。
>
> **C-3 論点（U-10）**: 上記 1 の代替案として「**known-unavailable allowlist を設け、
> その 3 フィールドのみの `unavailable` は `complete` を妨げない**」（= Phase 1 でも exit 0 を出す）
> という設計があり得る。下流（#869 / #811）が「complete な run のみを学習・promotion 対象にする」
> 設計を採る場合、**Phase 1 の全 run が partial だと下流が 1 件も動かせない**。
> これは #874 単独では決められない（下流 2 PBI の受理条件に依存する）ため **C-3 判断とする**。
> plan は安全側（1 = 全 partial）を既定に置く。

### 論点 D8: schema `required` の件数（**21**）と注釈キーの扱い

**C-1 FAIL（C1-TEST-14 ①）の是正論点**。当初は `required` を 20 と書く箇所（TC-04 / T-6）と
21 と書く箇所（TC-05 / T-5）が混在し、**同時に PASS しない**状態だった。

**確定: `required` = 21 = issue 本文の 20 フィールド + `schema_version`**。根拠:

- **AC-1 が versioning policy を要求する**。`schema_version` が optional だと、受理器は
  「version 不明の record」を受け取り得る。version 不明の record に対して
  「破壊的変更（required 追加・型変更・正規化マッピング変更）」の判定ができず、
  **versioning policy が機械的に無効化される**。
- **repo の前例と一致**: `schemas/*.schema.json` 28 本のうち **`schema_version` を `required` に
  持つものが 9 本**（実測: `handoff` / `pbi-input` / `plan` / `plangate-event` / `review-external` /
  `review-self` / `status` / `test-cases` / `todo`）。`schema_version` を properties に持ちながら
  required から外している schema は **0 本**。
- `evidence_status` は D7-2 のとおり **record に持たせない**ため required に入らない（20+1 で閉じる）。

- **前例との非対称も契約 doc に書く（C-2 R-C10 ②）**: 構造前例として参照する
  `schemas/c3-prime.schema.json` は **`schema_version` を properties にも required にも持たない**（実測）。
  上記 9 本は doc 系 schema である。**この非対称を契約 doc に明記しない**と、
  `schemas/` への昇格レビューで「c3-prime に合わせて `schema_version` を落とす」是正が入り、
  versioning policy が事後的に無効化されうる。

**注釈キー**: schema に `additionalProperties: false` **かつ** `patternProperties: {"^_": {"type": "string"}}` を置く。
根拠は実測の前例 `schemas/c3-prime.schema.json` の**実値**
（`additionalProperties=False` / `patternProperties = {"^_": {"type": "string", "description": …}}`）と、
受理器側 allowlist（`c3prime_verify.py` の `not k.startswith("_")` による未知キー除外 **かつ**
`if k.startswith("_") and not isinstance(v, str): return _fail(...)` による**型検査**）との**整合**。
`patternProperties` を省くと **schema が `_note` を拒否し受理器が許容する**という食い違いが生じる（C1-SUP-PLAN-01 ②）。

> **C-2 R-C05 の是正**: 当初案の `{"^_": {}}` は**任意の型を許す**ため、`{"_note": {"a": 1}}` が
> **schema を通り、姉妹受理器と同型に作った受理器は reject する** — plan が D8 で指摘した食い違いを
> **逆向きに作る**ことになっていた。前例の実値に合わせて **`{"^_": {"type": "string"}}`** に是正し、
> TC-03 の assert を `patternProperties["^_"]["type"] == "string"` まで深くする。

#### schema を producer / 受理器に**機械束縛**する（**C-2 R-008 の是正**）

当初計画では TC-01 〜 TC-05 が **schema ファイル単体の形式検査**、TC-06 〜 TC-09 が
**受理器のハードコード実装の検査**であり、**両者が一致する保証がどこにも無かった**
（受理器が schema を読むとは書かれていない）。Risks の「schema と producer の乖離は
golden byte 比較で検出」も**成立しない**（golden 比較は producer 出力同士の比較であり
schema を参照しない）。

**確定する構造**:

1. **受理器は `docs/schemas/run-evidence.schema.json` を読み、`required` と許可キー集合を
   schema から導出する**（ハードコードしない）。schema が**唯一の正**。
2. 上記が重い場合の最低ライン（本 plan は 1 を既定とし、2 の TC も両方置く）:
   - **TC-61**: `schema["required"]` の集合 == 受理器が要求する必須キー集合
   - **TC-62**: producer 出力の全キー ⊆ `schema["properties"]` ∪ `^_` パターン
3. **producer が出力するキーの全集合を 1 箇所で列挙する**（Step 1 の契約 doc）。
   required 21 に加えて **`observation` / `cause_hypothesis` / `escalation`** を
   **必ず `properties` に登録する**。

> **登録漏れの実害（C-2 R-008）**: `additionalProperties: false` の下で `escalation` が
> properties 未登録だと、**privacy 違反や未知 `kind` を検知した EV — 最も検証が必要な EV — だけが
> reject される**。また schema の required と受理器の必須キー集合が乖離しても既存 TC は全緑のまま
> であり、Phase 2 で `schemas/` へ HO patch 昇格した瞬間に既存 EV が一斉 reject され、
> 裁定が想定する「**1 回の HO patch で昇格**」が破綻する。

## Approach Overview

```text
[入力: 既存 artifact]                    [本 PBI 新設]                     [下流]
approvals/c3.json ──┐
delivery/record.jsonl ─┼─→ run_evidence.py ──→ RunEvidence(.json) ──→ run_evidence_verify.py
ai-loop-runs/*.json ─┤    (決定論 producer)      ↑ docs/schemas/          (受理器 / exit 0,1,10,11)
注入値(now/repo/...) ─┘                          run-evidence.schema.json          │
                                                                                   ├→ to_shadow_candidate_input()  → #869
                                                                                   └→ to_promotion_provenance()    → #811
```

- **RunEvidence は arbiter record の後継ではなく上位 artifact**（pbi In scope 9）。arbiter record（9 キー 25 件 / 14 キー 3 件）は **1 入力ソースとして参照するだけ**で、置き換えも移行も行わない（AC-15）
- **上流未実装（#811 / #869 / #868）に依存する部分は fixture 先行**。実接続はフィールド契約まで（pbi Risks 表と一致）
- **#873 は実装済み**なので delivery 層は fixture ではなく実物（`delivery.py`）の契約から取る（上記 乖離点 A）

## Work Breakdown (Steps)

1. **Step 1: 契約正本 doc + schema（AC-1 / AC-5）**
   - Output: `docs/workflows/ai-loop/run-evidence-contract.md`（正本）/ `docs/schemas/run-evidence.schema.json`
   - Owner: agent / Risk: 中
   - 内容: 20 フィールド定義 + **`evidence_status`（`complete` / `partial`）は受理器が導出する語彙**（record に格納しない・D7-2）+ D3 正規化マッピング表 + **`terminal_state` と `evidence_status` が直交すること**（D7）+ **known-unavailable の 2 分類**（(a) Phase 1 固定 3 / (b) `terminal_state` 依存 最大 4）と **`terminal_state` × フィールドの必須/`unavailable` マトリクス**（`MERGE_READY` / `HUMAN_ESCALATED` / `BLOCKED` の 3 行・D7・**C-2 R-003**）+ 「Phase 1 で exit 0 は構造的に発生しない」+ **両受理器の rc 対応表**（`c3prime_verify.py` 0/1/10 と本受理器 0/1/10/11・D6。**`bin/plangate` が 0/1 以外を catch-all で legacy にフォールバックする事実と、本受理器の rc を `_plangate_c3_dispatch` 経路へ流さない制約**を併記 = **C-2 R-C07**）+ **受理器の署名 `run_evidence_verify.py <ev.json> <task_dir>` と再検証対象表**（D6・**C-2 R-004**）+ **producer の入力ソース allowlist 4 種**（D2・**C-2 R-010**）+ **producer 出力キーの全集合**（required 21 + `observation` / `cause_hypothesis` / `escalation`。`properties` の全キーと 1:1 対応・**C-2 R-008**）+ versioning policy（破壊的変更は #872/#873/#874 の 3 issue 合意 = c3-prime-contract §8 と同一規則を採る）+ **`schemas/c3-prime.schema.json` が `schema_version` を持たない非対称の明記**（**C-2 R-C10 ②**）+ **`observation` と `cause_hypothesis` のフィールド分離**（AC-5）+ **`quality_metrics{}` の許可指標列挙**（当該 run で閉じる `first_pass` / `rounds` のみ・corpus 集計値を禁止 = **C-2 R-005**）+ EH-3 実効パターン（`schemas/*.schema.json`）と `ho-paths.md`（`schemas/**`）の**範囲差**の明記 + **「`docs/schemas/` は schema 検証 CI が 0 本」と「privacy CI（`**/*.json`）の走査対象には入る」の書き分け**（**C-2 R-C09(b) / B→A-6**）
   - 🚩 チェックポイント: schema が `$schema` = draft 2020-12 / `$id` = `https://github.com/s977043/plangate/schemas/run-evidence.schema.json`（**昇格後の URL で先に固定** = HO patch を **`git mv` 1 手**に収める。`$id` の変更も不要。実測: `schemas/*.schema.json` 28 本中 **27 本**が同形式）/ `additionalProperties: false`（既存 28 本中 72/78 箇所が `false`）**かつ `patternProperties: {"^_": {"type": "string"}}`**（前例 `schemas/c3-prime.schema.json` の**実値**と同型・D8・**C-2 R-C05**）/ `required` を `len()` で数えて **21**（20 + `schema_version`・D8）/ **`properties` の全キーが契約 doc の「producer 出力キー全集合」表と 1:1 対応**（`escalation` の登録漏れで「最も検証が必要な EV だけが reject される」経路を塞ぐ・**C-2 R-008**）/ `task_id` パターン `^TASK-[0-9]{4}$` / hash パターン `^sha256:[0-9a-f]{64}$`（`schemas/run-event.schema.json` の実測形式）を満たすこと
   - 🚩 チェックポイント（**C-2 R-C08**）: 契約 doc の markdown リンクは **インライン記法 `[text](path)` のみ**を使う（**参照定義 `[text]: ../path` と autolink `<../path>` を使わない**）。実測: `docs/workflows/ai-loop/*.md` は `sync-plugin-plangate.sh` で glob 同期され、変換器 `scripts/_ai_loop_link_rewrite.py` の `_LINK_RE = r"(?<!!)\[([^\]]*)\]\(([^)\s][^)]*)\)"` は**インラインリンクのみ**を書き換える。一方 `tests/extras/ta-54-ai-loop-link-selfcontained.sh` TC-01 は sync 後の `references/*.md` に対し `](\.\./` / `]:[[:space:]]*\.\./` / `<\.\./` の **3 形式すべて**を grep し、`](../SKILL.md` 以外が 1 件でもあれば FAIL する。参照定義・autolink を使うと **変換されないまま ta-54 が FAIL し Stop Condition に到達できない**
   - 🚩 チェックポイント（**C-2 R-C09(b)**）: 禁止キー 14 個の一覧は**契約 doc（`.md`）側**に置き、`docs/schemas/run-evidence.schema.json` の `properties` に**禁止キー名を登録しない**。実測で EH-8 は `grep -E '("file_path"|…)[[:space:]]*:'` であり、**`"file_path":` の形（JSON キー）だけが BLOCK 対象**（`PLANGATE_HOOK_STRICT=1` で rc=1 を実測）。**配列要素 `{"forbidden": ["file_path"]}` は BLOCK されない**（実測 PASS）ため、「JSON に書けば必ず BLOCK」ではなく **「properties のキーとして書くと BLOCK」** が正しい制約
2. **Step 2: 受理器 TDD（AC-4 / AC-1）— negative first**
   - Output: `scripts/ai-loop/run_evidence_verify.py` / `scripts/ai-loop/test_run_evidence_verify.py`
   - Owner: agent / Risk: **高**（AC-4 の中核）
   - **入力契約（C-2 R-004・D6 で確定）**: 署名は **`run_evidence_verify.py <ev.json> <task_dir>`**。`task_id` を `task_dir` 名に束縛し、`plan_hash` / `source_sha` / `c3_prime_decision_ref` は `<task_dir>/approvals/c3.json` と、`final_head_sha` / `repair_rounds` は `<task_dir>/delivery/record.jsonl` の**再計算値**と照合する。**EV 単体入力にしない**（`sha256:`+64hex 形式を保った 1 文字改変が形式検査を通過し、known-unavailable により **exit 11 で返って promotion まで到達しうる**）
   - **schema 束縛（C-2 R-008・D8 で確定）**: 受理器は `docs/schemas/run-evidence.schema.json` を読み、**`required` と許可キー集合を schema から導出する**（ハードコードしない）。TC-61 / TC-62 で schema ↔ 受理器 ↔ producer の三者一致を機械固定する
   - 🚩 チェックポイント: **exit code 4 値（`0` complete / `1` NG / `10` legacy / `11` partial）が D6 の契約どおり**（`10` の意味を姉妹受理器と一致させる）。`missing`（必須キー欠落）/ `partial`（`unavailable` を含む）/ `tampered`（hash 不一致・`entry_id` 不一致）を **1 つも `0` に倒さない**。**partial 時は `unavailable` フィールド名を stderr に全数列挙する**（D7・**C-2 R-003**）。未知トップレベルキーは reject（`c3prime_verify.py` の allowlist 転写。`^_` 注釈キーのみ許容し、**値が string でなければ reject** = 前例の実装と同型・**C-2 R-C05**）。**`0` を返す経路は合成 complete EV で必ず 1 件検証する**（D7・TC-56。Phase 1 の producer 出力からは到達しないため死にコード化を防ぐ）
3. **Step 3: 決定論 producer TDD（AC-2 / AC-3 / AC-5 / AC-12）**
   - Output: `scripts/ai-loop/run_evidence.py` / `scripts/ai-loop/test_run_evidence.py`
   - Owner: agent / Risk: **高**
   - 転写する具体パターン（**推測でなく実ファイルから**。⚠️ **行番号は stale 化するため記号アンカーで特定する** — C-2 R-C06 で 2026-08-02 時点の実測と 4 件のドリフトが判明した）:
     - `plan_package.serialize_c3_prime()` の `json.dumps(record, ensure_ascii=False, indent=2, sort_keys=True) + "\n"`
     - `c3_contract.canonical_hash()` を **import 再利用**（`json.dumps(sort_keys=True, separators=(",",":"))` の sha256 + `sha256:` prefix）
     - `plan_package.PlanPackageError` 型の **errors リスト保持例外**（`RunEvidenceError(errors)`）。エラーは 1 件目で止めず**全件収集して返す**（`plan_package.build_c3_prime()` と同型）
     - `delivery.py` の **module docstring 冒頭の「決定論」箇条**（`- 決定論: 判定は snapshot + record entries のみに依存。timestamp は --now 注入 / （now() を直接参照しない）`）。⚠️ **C-2 R-C06**: 当初 plan は「docstring **L15-16**」と書いていたが、実測で L15-16 は **「純判定器: ネットワーク・外部プロセスを一切呼ばない」の行**であり内容が違う（`--now` 注入の記述は **L9-10**）。行番号に従って転写すると **決定論の根拠ではなく純判定器の記述を転写し `--now` 必須化（TC-12）が落ちる**ため、**箇条の先頭語「決定論:」を記号アンカーとする**
   - **出力先の契約（C1-SUP-PLAN-01 ① の是正・plan で確定）**: producer は既定で **stdout へ 1 record を返す**（保存先は呼び出し側が決める）。`--out <path>` を指定した場合のみファイルへ書き、**拡張子が `.json` でなければ reject**（`.jsonl` は EH-8 の走査対象 `case "$f" in *.json|*.ndjson)` に**マッチしない**ため privacy 検査を素通りする・D5）。**Phase 1 で repo に commit するのは golden fixture のみ**であり、実運用の既定保存先は Phase 2（Gate 接続）で決める（本 PBI では決めない）
     - 参考実測: `.github/workflows/schema-validate.yml` の trigger paths には `docs/working/**/*.json` が**含まれる**。将来 `docs/working/` 配下を保存先にすると CI trigger 対象になる（`schema_mapping.FILENAME_TO_SCHEMA` 未登録 basename は skip されるため CI は壊れないが、Phase 2 の設計で扱う）
   - **決定論を壊さないための追加制約（C-2 R-005 / R-012 / R-C04）**:
     - `quality_metrics{}` は **当該 run の events だけで閉じる指標のみ**（`first_pass` / `rounds`）。**corpus 集計値を格納しない**（arbiter record が 1 件増えるだけで過去 run の EV の byte が変わり、AC-2 と TC-48 が後日 CI で赤くなる）
     - `evidence_refs[]` は **注入値または `record.jsonl` 由来のみ**。**producer 側でディスク走査して列挙しない**（ファイル増減で同一 events から異なる EV が出る）
     - `repair_rounds` の PR 番号は `kind=merge_ready` entry の `record.pr_number` または `--pr-number` 注入から解決し、**解決不能なら `unavailable`**（`delivery._completed_rounds(entries, None)` が**例外にならず `0` を返す**ため、`0` に倒すと fail-open する）
   - 🚩 チェックポイント: 同一入力で **2 回生成して byte 一致**（`cmp -s`）。`harness_version` を run 開始時注入値と終了時で照合し不一致なら fail-closed（AC-12）。`observation`（何が起きたか）と `cause_hypothesis`（なぜ起きたか）が**別フィールド**で、producer は `cause_hypothesis` を**自動生成しない**（推定を観測に混ぜない / AC-5）。**producer が読むファイルが D2 の入力ソース allowlist 4 種に閉じる**（ソース走査 + monkeypatch で固定 = TC-63・AC-6 の「要求しない」側）
4. **Step 4: legacy record 互換層（AC-15）**
   - Output: `scripts/ai-loop/run_evidence.py`（分類関数）/ `test_run_evidence.py`
   - Owner: agent / Risk: 中
   - 転写する具体パターン: `metrics.py` の 4 分類（実測。**記号アンカー = `_load_records()` と `collect()`**）— `legacy`（`"run" not in record`）/ `invalid run meta`（`_has_valid_run_id()` が False）/ `skipped`（破損 JSON / 非 dict / `decision` 欠落・**理由文字列を必ず記録**）/ `run record`。恒等式 `total_records = legacy + invalid + run` で全件がどれかに帰属する構造も転写する
   - ⚠️ **`metrics.py` の `skipped` は `{"file": file_path, "reason": …}` を記録し、`file_path = str(path)` は絶対パスになりうる**（実測。ta / unit test は mktemp の絶対パスを渡す）。キー名が `file`（`file_path` **ではない**）ため **EH-8 の禁止キー 14 個では捕捉できず素通りする**（実測 PASS）。転写先では **`skipped` の `file` を repo 相対パスへ正規化する**か、EV に載せない（**C-2 R-C09(a)**）
   - 🚩 チェックポイント: **実データ 28 件**（9 キー 25 / 14 キー 3）を入力にして `legacy_count=25` / `run_count=3` / `skipped_count=0` が**再現**すること（`python3 scripts/ai-loop/metrics.py --format json` の現行出力と一致）。RunEvidence が arbiter record を**置き換えない**（既存 28 件を 1 バイトも変更しない）ことを差分ゼロで確認
5. **Step 5: privacy 強制（AC-6）**
   - Output: `scripts/ai-loop/run_evidence.py`（出力フィルタ）/ `test_run_evidence.py`
   - Owner: agent / Risk: **高**（違反が commit されると不可逆）
   - **値レベルの絶対パス検査（C-2 R-C09(a) の是正）**: EH-8 は `grep -E '("file_path"|…)[[:space:]]*:'` = **キー名の文字列 grep** であり、**値は一切見ない**（実測: `{"file": "/var/folders/xx/tmpABC/foo.json"}` は `PLANGATE_HOOK_STRICT=1` でも PASS）。当初計画の絶対パス検査は `evidence_refs` **限定**だったため、`skipped[].file` のような別キーに絶対パスが載ると **`metrics-privacy.md` §4/§5 違反のまま commit される**。したがって producer 側の privacy フィルタを **全フィールドの値に対する絶対パス検査（`^/` / `/Users/` を含む）** まで広げる（TC-65）
   - 🚩 チェックポイント: 出力 record に EH-8 の**禁止キー 14 個が 1 つも現れない**（producer 側で機械検査）/ **全フィールドの値に絶対パスが 0 件**（TC-65）/ `evidence_refs[]` が **repo 相対パスのみ**（`/` 始まりを reject）/ 保存形式が `.json`（`.jsonl` にしない = EH-8 の走査対象に載せる）/ **10 fixture に対し ta-59 の中から EH-8 を実走させ PASS を確認**（自主規制でなく hook で証明する。実行形は下記の CI 除外の事実に基づき `PLANGATE_HOOK_FILES` 明示 = **C-2 R-C03**）
   - ⚠️ **`tests/fixtures/` は privacy CI の走査対象から除外されている（C-2 R-C03・実測）**: `.github/workflows/metrics-privacy.yml` の scan 対象決定は `git diff --name-only … | grep -E '\.(json\|ndjson)$' | grep -v '^tests/fixtures/'`。また `.claude/settings.example.json` の hooks に `check-metrics-privacy.sh` は**存在しない**（実効強制点は ① この CI〔fixtures 除外〕② `scripts/codex-guarded.sh`〔Codex セッションのみ〕③ `tests/hooks/run-tests.sh` の固定 fixture）。⇒ **D5 の「`.json` に固定したから hook で自動強制される」は、本 PBI が commit する 10 fixture に対してだけ効かない**。したがって **ta-59 の中で `PLANGATE_HOOK_STRICT=1 PLANGATE_HOOK_FILES="<10 fixture のパス>" sh scripts/hooks/check-metrics-privacy.sh` を実行する**（ta スクリプトは `tests/run-tests.sh` の glob source 経由で CI job `plangate CLI tests` に必ず乗るため除外の影響を受けない）。これにより将来 fixture に `"stdout"` を足す PR も CI で捕捉できる
6. **Step 6: c3-prime-contract §7 追記 + §4 全規則の fail-closed 再検証（AC-14）**
   - Output: `docs/workflows/ai-loop/c3-prime-contract.md`（§7 に #874 consumer 節を **additive 追記**・§6 は触らない）/ `run_evidence.py`
   - Owner: agent / Risk: 中
   - 内容: 読むフィールド（`task_id` / `decision` / `source_sha` / `plan_hash` / `plan_package_hash` — §7 が #873 向けに列挙した 5 つと同一）+ **trust boundary の明示**（§7 の「decision 値を無検証で信頼してはならない」を #874 にも適用）
   - 実装: producer は `c3prime_verify.main([_, task_dir, expected_sha])` を **呼び出して rc==0 を要求**する（**記号アンカー = `delivery.verify_c3()`**。同関数が `redirect_stderr(buf)` で同じことをしている。**この関数の実装形をそのまま転写し、検証ロジックを再実装しない**）
   - 🚩 チェックポイント: §8（バージョニング）に #874 が既に含まれている（実測「#872 / #873 / #874 の 3 issue 合意」）ことを確認し**重複追記しない** / §6 の LoopSpec 派生表を変更していない（`git diff` で §6 の行数不変）
7. **Step 7: consumer adapter IF（AC-7 / AC-8 / AC-11 / AC-13）**
   - Output: `scripts/ai-loop/run_evidence.py`（`to_shadow_candidate_input()` / `to_promotion_provenance()`）/ `test_run_evidence.py`
   - Owner: agent / Risk: **高**（下流 2 PBI の前提になる）
   - **再実装しない**（pbi In scope 8 verbatim「再実装せず provenance 橋渡しのみ」）: clustering も promotion decision table も本 PBI では作らない
   - フィールド橋渡し（実測に基づく綴りの確定）:
     - `RunEvidence.run_id[]` → **`source_run_ids`**（#869 issue 本文の候補契約フィールド・実測綴り）
     - `RunEvidence.harness_version` → **`baseline_version`**（#869 issue 本文の実測綴り）。⚠️ **`baseline_harness_version` という綴りは issue にも repo にも 1 件も存在しない**（実測）ため使わない
     - `RunEvidence.observation` → `observed_pattern` / `RunEvidence.cause_hypothesis` → `cause_hypothesis`（#869 の綴りと一致）
     - #811 向け: `{candidate_id, decision, promoted_to, evidence_count, canary_scope, rollback_count}`（#811 issue の Trust Ledger 記録例の実測綴り）+ 改善 PR/commit 追跡用の `improvement_refs[]`
   - **AC-13 の fail-closed**: `to_promotion_provenance()` は **#862/#866 相当の未解決正本を参照する候補を `BLOCKED` に倒す**。実測: **#862 は CLOSED / #866 は OPEN**（`gh issue view` 実測）。したがって現時点で有効なのは #866 に対してのみ。unresolved 判定は **ハードコードした issue 番号ではなく、入力 candidate の `blocked_by[]` が非空なら BLOCKED** という汎用条件で実装する（issue 番号のハードコードは CLOSE 時に stale 化するため）
   - **`blocked_by[]` の供給元と欠落時の既定（C1-PLAN-01 ① の是正）**: 供給元は **呼び出し側注入**（producer は判定材料を作らない）。当初案は「非空なら BLOCKED」だけを定義していたが、**誰も埋めなければ常に空 → 常に非 BLOCKED** となり AC-13 が **fail-open** する。したがって以下を **plan で確定**する:
     - `blocked_by` キーが **物理的に存在しない**（未注入）→ **判定不能として `BLOCKED`**（fail-closed。`unavailable` と空配列を区別する本 PBI の原則と同型）
     - `blocked_by == []` を **明示注入**した場合のみ「未解決なし」と解釈して promotion 判定へ進む
     - **誰が `blocked_by[]` を埋めるか**（#811 側か契約 doc 側の未解決正本リストか）は本 PBI 単独で決められない → **U-12 として C-3 判断**
   - 🚩 チェックポイント: adapter が **RunEvidence 以外を読まない**（AC-7「#869 が RunEvidence のみから shadow candidate を生成できる」の構造保証）。`blocked_by[]` 非空 → `BLOCKED` / `blocked_by` キー欠落 → `BLOCKED` の負側 TC が 2 本とも通ること
8. **Step 8: 10 fixture 実装（AC-16 / AC-9 / AC-10）**
   - Output: `tests/fixtures/run-evidence/`（golden 10 件）/ `scripts/ai-loop/test_run_evidence.py`
   - Owner: agent / Risk: 中
   - 各 fixture の入力 events は **test 内で構築**（`test_delivery.py` / ta-56 / ta-57 の方式。committed するのは golden 出力のみ）。golden と再生成結果を **byte 比較**することで AC-2 の回帰を固定する
   - **実在の一次証跡を 1 件使う**: `docs/working/TASK-0917/evidence/e2e/run/delivery/record.jsonl`（**実測 3 行** = `intent` 1 / `notice` 1 / `receipt` 1。TASK-0917 の実 PR 1 周の実走証跡）を fixture 2（CI repair あり）の**入力形状の一次根拠**として参照する。手書き fixture だけだと実 record との乖離が隠れる（TASK-0917 Risks の「fixture は手書きのため乖離が隠れる」教訓）
     - ⚠️ この record.jsonl には `delivery.assess()` が生成しない `kind=notice` entry が含まれる（`executor.py` 由来・実測）。**producer は未知の `kind` を無視せず `unavailable` 側に倒す**か明示的に受理するかを設計で決める（Step 3 の fail-closed 方針に従い、未知 kind は `escalation` として記録し握り潰さない）
     - ⚠️ **この一次証跡が裏を取れる範囲は限定的（C-2 レーン B → 設計妥当性 返送論点 4）**: 実測 3 行は `intent` / `notice` / `receipt` のみで **`kind=state` も `kind=merge_ready` も含まない**。したがって **D3 正規化マッピングの中核（`MERGE_READY` / `HUMAN_ESCALATED` / `BLOCKED` の導出）についてこの証跡は根拠を与えない**。`test-cases.md` の fixture 表に「**実 record で裏が取れる範囲**（entry の共通キー形状・`pr_number` / `round` / `action_kind` の実在）」と「**手書きに留まる範囲**（`kind=state` / `kind=merge_ready` / `check_summary` / `review_disposition`）」を明示的に書き分ける
   - **fixture 6 が Phase 1 で vacuous であることの明示（C-2 R-002・(b) を採用）**: `routing_decisions[]` は Phase 1 で常に `unavailable`（#868 OPEN）であるため、**`fx-06-routing-escalation` は `terminal_state=HUMAN_ESCALATED` / exit 11 で `fx-04-human-escalated` と実質的に区別できない**（routing 次元の実カバレッジは 0）。したがって「10 fixture PASS」を AC-16 / DoD の充足として報告する際に **routing が実質未検証であることを必ず併記する**（fixture 表 / T-32 / T-42 のコメント文面要件）。
     - **代替案 (a)**「`routing_decisions[]` の item schema（`{requested, resolved, outcome}` 暫定粒度）を Step 1 で定義し、値を注入可能にして fixture 6 を注入値で構成する」は **#868 の設計に踏み込む**ため plan では確定せず、**U-9 の代替案として C-3 判断へ上げる**（本 plan の既定は (b) = vacuity の明示）
     - **放置した場合のリスク**: #868 実装時に item 形を後付けすると、versioning policy が要求する「**3 issue 合意**」を伴う**破壊的変更**になる
   - **期待 exit の確定（C1-PLAN-04 / C1-TEST-14 ③ の是正）**: fixture 1〜6 の期待受理器 exit は **すべて `11`（partial）**（D7-1: Phase 1 は known-unavailable により必ず partial）。**fixture 5（`BLOCKED`）は `record.jsonl` 自体が存在しない**ため、(a) Phase 1 固定 3 件に加えて **delivery 層 4 フィールドも `unavailable`** になる（D7 のマトリクス。**exit は同じ `11` だが `unavailable` の内訳が違う** = C-2 R-003。TC-58 で内訳まで assert する）。fixture 7 は**期待エラー列**を格納する fixture であり、**ケースごとに期待 exit を一意に固定**する（`tampered` → `1` / `partial` → `11`）。**「1 または 10」のような二値の期待値を golden に残さない**（決定論 producer の golden として期待値が一意でないため）
     - ⚠️ **fixture を 11 件に増やさない**: issue #874 は必須 fixture を **10 件**と verbatim で指定しており、TC-48 が `len(glob) == 10` を assert する。したがって partial / tampered を 2 ファイルに割らず、**1 ファイル内で複数ケースを持ち各ケースの期待 exit を一意にする**
   - 🚩 チェックポイント: fixture 7 の各ケースが **`exit 0` を返さない**こと / fixture 8 が **3 件以上の同型 Run** を入力にしていること（issue verbatim「3 件以上」）/ fixture 10 が **failed canary → rollback** の再現であること（DoD の「実走または再現 fixture」の後者を満たす）
9. **Step 9: `ta-59-run-evidence.sh` + 新規 unit test の実行導線（AC-16）**
   - Output: `tests/extras/ta-59-run-evidence.sh`
   - Owner: agent / Risk: 中
   - **新規 ta 番号 = 59**（⚠️ **C-2 反映時の再実測で 58 は使用済みと判明**: `git ls-tree origin/main --name-only tests/extras/` に **`ta-58-git-destructive-guard.sh` が既に実在**する〔#968 由来〕。plan 生成時（base `a4afacb`）には無く、その後 main が進んだ。**exec 開始時（T-2）に `git ls-tree origin/main --name-only tests/extras/ \| grep -oE 'ta-[0-9]+' \| sort -u \| tail` で最大番号を再確認し、空き番号を採る**こと。本 plan の `59` も鵜呑みにしない）
   - **登録方法 = ファイルを置くだけ**（実測: `tests/run-tests.sh` の `for extra in "$EXTRAS_DIR"/ta-*.sh` が glob source。`tests/extras/README.md`「`tests/run-tests.sh` の本体には触れない」）。CI は `.github/workflows/test.yml` の job `plangate CLI tests` が `sh tests/run-tests.sh` を実行するため**自動で乗る**
   - ⚠️ **glob source は `ta-*.sh` を拾うだけで python unit test は起動しない**（TASK-0917 R-020 の教訓）。したがって ta-59 に **`python3 <root>/scripts/ai-loop/test_run_evidence.py` と `test_run_evidence_verify.py` の 2 本**を **1 モジュール 1 PASS 行**で明示追加する（**記号アンカー = `ta-56-delivery.sh` の python 実行ブロック**の形を転写）
   - **EH-8 実走を ta-59 に内蔵する（C-2 R-C03）**: `PLANGATE_HOOK_STRICT=1 PLANGATE_HOOK_FILES="<10 fixture のパス>" sh "$PG_ROOT/scripts/hooks/check-metrics-privacy.sh"` を 1 ケースとして持つ。理由は privacy CI が `tests/fixtures/` を除外しているため（Step 5 の ⚠️）
   - 規約遵守（`tests/extras/README.md` 実測）: `pass` / `fail` を直接更新 / `trap` を使わない / `register_cleanup` + 末尾明示 `rm -rf` の二重 / 変数は `_t59_` プレフィクス / `rc=0` 初期化してから `out="$(cmd)" || rc=$?`
   - 🚩 チェックポイント: `sh tests/run-tests.sh </dev/null` が exit 0（**stdin を閉じないと `precompact-memory-guard.sh` でハングする**）/ 2 本の PASS 行が出力に現れる（目視でなく grep）/ **採番した ta 番号が `origin/main` に存在しない**ことを `git ls-tree` で確認済み
10. **Step 10: 配布同期（sync 2 箇所）**
    - Output: `scripts/sync-plugin-plangate.sh`（**2 箇所**）+ `plugin/plangate/` 再生成
    - Owner: agent / Risk: 中（片方漏れ = sync drift）
    - **記号アンカーで位置特定**（行番号は 2026-08-02 時点の目安・stale 化する）: ①`for _f in "$AI_LOOP_SCRIPTS_DIR/arbiter.py" …`（現行 L348・**24 エントリ**を実測）②`arbiter.py|test_arbiter.py|…) : ;;`（現行 L360・**24 エントリ**を実測）。新規 4 本（`run_evidence.py` / `test_run_evidence.py` / `run_evidence_verify.py` / `test_run_evidence_verify.py`）を**両方に**追加 → 各 28 エントリ
    - `docs/workflows/ai-loop/*.md` は **glob 同期**（実測 L287-292 の `for _f in "$AI_LOOP_WORKFLOWS_DIR"/*.md`）なので新規 `run-evidence-contract.md` は**自動で同期される**（whitelist 追加不要）
    - ⚠️ `docs/schemas/run-evidence.schema.json` と `tests/fixtures/run-evidence/` は **sync 対象外**（同期先は `skills/ai-loop-cycle/references` と `.../scripts` のみ・実測）。下流が schema を必要とするなら別途配布設計が要る → **Unknowns U-7**
    - 🚩 チェックポイント: 2 箇所の basename 集合を diff して**差分 0** / sync 2 回目 no-op / `git diff --quiet plugin/`
11. **Step 11: 敵対レビュー R1 / R2**
    - Output: `docs/working/TASK-0874/evidence/`
    - Owner: agent / Risk: 中
    - 🚩 チェックポイント: **契約層は 1 ラウンドでは表層しか出ない**（#889 / TASK-0917 の教訓）— critical / major ゼロ収束まで。特に「fail-open していないか」「`unavailable` と `0`/空配列を混同していないか」を重点
12. **Step 12: AC-1〜AC-16 突合 + DoD 証跡の外部反映**
    - Output: `docs/working/TASK-0874/`（V-1 入力）/ issue #874 コメント / issue #870 Evolution DoD の evidence link
    - Owner: agent / Risk: 低
    - **issue DoD の未カバー 2 項目を明示的に担う（C1-PLAN-01 ② の是正）**: issue #874 本文 DoD の「Issue コメントに schema・test command・sample record・integration log への link がある」「#870 の Evolution DoD へ evidence link が反映されている」は、当初 plan の Step / T のどこにも対応が無かった。**本 Step の Output に含める**（T-42 / T-43）
    - **⚠️ 本 PBI 完了時点で issue #874 の close 条件は充足できない（C-2 R-007・plan で明記）**: issue 本文 DoD は「**#869 shadow mode がfixture から candidate を生成する統合 test がある**」「**#811 promotion decision までの provenance test がある**」を要求し、末尾で「schema 文書のみ、candidate の手動作成のみ、**効果測定なしでは close しない**」と明示している（実測・verbatim）。**#869 / #811 は未実装**であるため、本 PBI が供給できるのは**契約層と fixture まで**。したがって:
      - **本 PBI 完了後も #874 は OPEN のまま**とし、close 条件の充足は **#869 / #811 完了後**とする
      - **T-42 のコメント文面に「Phase 1 契約層のみ充足・close 条件未達」を必ず含める**（4 link を投稿して DoD が形式上埋まったように見え、issue 本文が明示的に禁じている「効果測定なしの close」に加担することを防ぐ）
      - **C-3 判断事項に「#874 を OPEN のまま残すことの追認」を追加**する
    - **U-6 の帰結**: `schemas/` 昇格 PBI（HO patch）を #870 の後続として **予約起票する**（T-44。判断根拠は §Questions の「確定済み」参照）
    - 🚩 チェックポイント: `test-cases.md` の全 TC（**65 件**）を機械実行して PASS（未実行 / SKIP 0 件）。**AC↔fixture 対応表**（AC-16 が要求）を handoff に残す。issue #874 / #870 の該当コメントの URL を handoff に記録する
13. **Step 13: 👤 C-3 / 👤 C-4**
    - Output: `docs/working/TASK-0874/approvals/c3.json`（Human 発行）
    - Owner: human / Risk: —
    - 🚩 チェックポイント: 下記 Questions / Unknowns の **未決 8 件（U-1 / U-4 / U-5 / U-8 / U-9 / U-10 / U-11 / U-12）** を明示判断（U-2 / U-3 / U-6 / **U-7** は plan 段階で確定済み・追認のみ）+ **「本 PBI 完了後も #874 は OPEN のまま」の追認**（C-2 R-007）

## Files / Components to Touch

| # | ファイル | 種別 |
|---|---------|------|
| 1 | `docs/schemas/run-evidence.schema.json` | 新設（JSON Schema 2020-12・非 HO・Phase 1） |
| 2 | `docs/workflows/ai-loop/run-evidence-contract.md` | 新設（契約正本・carve-out ② で保護・plugin へ glob 自動同期） |
| 3 | `scripts/ai-loop/run_evidence.py` | 新設（決定論 producer + adapter IF） |
| 4 | `scripts/ai-loop/test_run_evidence.py` | 新設 |
| 5 | `scripts/ai-loop/run_evidence_verify.py` | 新設（受理器・exit code 0/1/10/11） |
| 6 | `scripts/ai-loop/test_run_evidence_verify.py` | 新設 |
| 7 | `tests/extras/ta-59-run-evidence.sh` | 新設（**新規 ta 番号 = 59**・exec 開始時に再確認・glob 自動収集） |
| 8 | `tests/fixtures/run-evidence/` / `tests/fixtures/run-evidence/**` | 新設（golden fixture **10 件**・`.json` 固定。**2 記法併記は下記 ⚠️ 参照**） |
| 9 | `docs/workflows/ai-loop/c3-prime-contract.md` | 改変（**§7 に #874 consumer 節を additive 追記のみ**。§6 は不変） |
| 10 | `scripts/sync-plugin-plangate.sh` | 改変（**2 箇所** = for ループ / case 許可判定。各 24 → 28 エントリ） |
| 11 | `plugin/plangate/` / `plugin/plangate/**` | sync 自動再生成（**2 記法併記**） |
| 12 | `docs/working/TASK-0874/` / `docs/working/TASK-0874/**` | 本 PBI の作業成果物（plan / todo / test-cases / status / handoff / evidence）（**2 記法併記**） |

> ⚠️ **ディレクトリ行を 2 記法（末尾 `/` と `**`）併記する理由（C-2 R-C02・実測）**
>
> 本節のバッククォート囲みのパスは `plan_package.extract_allowed_paths()` で機械抽出され、
> `collector.py` が snapshot した同一配列を **`arbiter.check_allowed_paths()` と
> `delivery._path_allowed()` の両方が消費する**。ところがこの 2 つの matcher は**非対称**である:
>
> | matcher | 実装 | 末尾スラッシュ記法 | ダブルアスタリスク記法 |
> |---------|------|------------------|----------------------|
> | `arbiter.check_allowed_paths()` → `_ho_pattern_to_regex()` | **セグメント境界 regex** | ❌ 空セグメントを要求し配下にマッチしない | ✅ |
> | `delivery._path_allowed()` | **prefix 一致**（endswith 分岐） | ✅ | ❌ glob 非対応で完全一致のみ |
>
> **実測（本 plan の allowed\_paths を両 matcher に通した結果）**:
>
> - 末尾スラッシュのみの場合 → delivery は 3/3 True だが **arbiter は 3 件すべて violation**
>   （fixture の golden 1 件 / plugin 同期先の references 配下 1 件 / working context の status 1 件）。
>   arbiter が **priority 1.5 の `scope_violation`** を出し、
>   fixture 10 件・plugin 再生成・working context 更新という**正常な変更がすべて scope 逸脱扱い**になる
> - ダブルアスタリスクのみに変えると今度は **`delivery._path_allowed()` が False** → `assess()` の `plan_deviation` →
>   **`EXEC_RETURN`** に落ちる
> - **片方の記法だけでは両 matcher を同時に満たせない**。2 行併記した場合のみ
>   `arbiter.check_allowed_paths(...) == (True, [])` かつ `delivery._path_allowed(...) == True` を実測確認した
>
> ⚠️ **本注記では例示パスをバッククォートで囲まない**（囲むと `extract_allowed_paths()` が
> 例示パスまで `allowed_paths` として拾い、scope が意図せず広がる）。
> `extract_allowed_paths()` はバッククォート内のスラッシュを含むトークンを全部拾うため、
> **表のセルに 2 記法を並べれば両方が `allowed_paths` に入る**。
> **記法規約そのものの統一**（TASK-0917 は末尾 `/`・TASK-0914 は `**` と実装が割れている）は
> 本 PBI の scope 外 → **handoff の V2 候補**（C-2 レーン B → 設計妥当性 返送論点 2）。
>
> ⚠️ **本節はバッククォート囲みのパスが `plan_package.extract_allowed_paths()` で機械抽出され `allowed_paths` を駆動する**。以下の「触ってはいけない」注記では、許可対象に混入させないため意図的にバッククォートを使わない。
>
> **不変（触ってはいけない）**: scripts/ai-loop/delivery.py ・ scripts/ai-loop/c3\_contract.py ・ scripts/ai-loop/c3prime\_verify.py ・ scripts/ai-loop/arbiter.py ・ scripts/ai-loop/metrics.py ・ schemas/ 配下すべて（HO）・docs/working/ai-loop-runs/ の既存 28 件 ・ tests/run-tests.sh
>
> **手作業ファイル数 = 19**（#1〜#10 のうち #8 を fixture 10 件に展開して数えた実数。#11 plugin は自動生成 / #12 は working context のため除外）。内訳: 新設 7 + fixture 10 + 改変 2。

## Metrics Evidence（事前メトリクス検証 / mandatory gate）

すべて 2026-08-02 に `feat/task-0874-plan`（base = `origin/main` = `a4afacb`）で実測。

| 対象 | 実数（実測コマンド） | AI 見積もり | ratio | 判定 |
|------|---------------------|------------|-------|------|
| RunEvidence の既存実装 | **0 件**（`grep -rn 'run_evidence\|RunEvidence\|harness_version' scripts/ bin/ \| wc -l`） | — | — | greenfield。pbi L13 の記述を再現確認 |
| 手作業で触るファイル数 | **19**（上表の脚注） | 16（pbi Assumptions の「16+」） | **1.19** | 採用（1〜3 倍）。Risks に fixture 10 件の粒度リスクを記録 |
| arbiter record（AC-15 の対象） | **28 件**（`ls docs/working/ai-loop-runs/*.json \| wc -l`）。世代内訳 **9 キー 25 件 / 14 キー 3 件**。`.md` は別途 **21 件** | 28 | 1.00 | pbi と一致。`metrics.py --format json` の現行出力（`legacy_count=25` / `run_count=3` / `skipped_count=0`）を Step 4 の回帰基準にする |
| `schemas/`（HO・昇格先） | **28 本**（`ls schemas/*.schema.json \| wc -l`）+ `README.md` = 29 エントリ | — | — | 昇格時の書式基準。`additionalProperties` 出現 78 箇所中 **72 が `false`** |
| `docs/schemas/`（Phase 1 配置先） | **1 ファイル**（`child-pbi.yaml` のみ） | — | — | 前例が 1 件しかない。かつ**形式が JSON Schema でない**ため D1 で形式を決める必要があった |
| `docs/schemas/` の **schema 検証** CI 経路 | **0 本**。`grep -rn 'docs/schemas' scripts/ tests/ .github/` = **5 件**だが全て `scripts/check-orchestrator-docs.sh` 内で、同 script の被参照は **0 件**（`grep -rn 'check-orchestrator-docs' .github/ tests/ bin/ scripts/` の自己参照除外） | — | — | **検証経路を自作する必要がある**根拠（Step 2 / Step 9）。⚠️ **privacy CI（`**/*.json`）の走査対象には入る**（C-2 R-C09(b)） |
| 新規 ta 番号 | **59**（⚠️ **C-2 反映時の再実測**: `git ls-tree origin/main --name-only tests/extras/` の最大番号は **58**（`ta-58-git-destructive-guard.sh` が #968 で追加済み）。plan 生成時 base `a4afacb` には存在しなかった） | — | — | 採番の実測根拠。**exec 開始時（T-2）に再確認する**（C-2 追加是正） |
| `tests/run-tests.sh` への登録作業 | **不要**（`for extra in "$EXTRAS_DIR"/ta-*.sh` の glob source。`tests/extras/README.md`「本体には触れない」） | 1 ファイル改変 | 0 | Files から `tests/run-tests.sh` を除外 |
| `scripts/ai-loop/*.py` | **26 本** | — | — | 新規 4 本追加で 30 本 |
| sync whitelist のエントリ数 | **for ループ 24 / case 24**（実測集計。記号アンカーで位置特定）。**両者一致** | — | — | 新規 4 本を両方へ足して各 28。片方漏れ = drift |
| `allowed_paths` の 2 matcher 適合（**C-2 R-C02**） | 末尾 `/` のみ → `arbiter.check_allowed_paths()` が **3 件 violation** / `delivery._path_allowed()` は 3/3 True。**2 記法併記で両方 in-scope**（実測） | — | — | Files 表のディレクトリ行を 2 記法併記にする根拠 |
| `delivery._completed_rounds(entries, None)`（**C-2 R-C04**） | **`0`（例外にならない）**。実 record（`TASK-0917/evidence/e2e/run/delivery/record.jsonl`）で `(entries, 940) = 1` / `(entries, None) = 0` を実測 | — | — | `--pr-number` 注入と `unavailable` fallback の根拠 |
| EH-8 の値検査（**C-2 R-C09(a)**） | **無し**（キー名の grep のみ）。`{"file": "/var/folders/…"}` は `PLANGATE_HOOK_STRICT=1` でも **PASS**（実測） | — | — | producer 側で全フィールド値の絶対パス検査を行う根拠（TC-65） |
| `docs/workflows/ai-loop/*.md` | **15 本**（新規 1 本で 16） | — | — | sync は glob なので whitelist 追加不要 |
| EH-8 の禁止キー | **14 個**（`scripts/hooks/check-metrics-privacy.sh` L37 を `tr '\|' '\n' \| wc -l` で集計）。走査対象は `*.json` / `*.ndjson` のみ（**`*.jsonl` は素通り**を case glob で実測） | — | — | AC-6 の機械強制点。保存形式を `.json` に固定する根拠 |
| `delivery.py` の状態語彙 | **`STATES` 7 + `EXITS` 2**（`python3 -c "import delivery; ..."`）。`PRIORITY_ORDER` は 15 | — | — | D3 正規化マッピングの根拠（issue の 3 値と一致しない） |
| `c3_contract.VALID_DECISIONS` | **3 値**（`AUTO_APPROVED` / `HUMAN_ESCALATED` / `BLOCKED`）。`ARTIFACTS` 6 / `RECORD_REQUIRED_KEYS` 14 | — | — | 同上 |
| `harness_version` 候補値 | `bin/plangate` L7 = **`0.2.0`** / plugin = **`8.18.0`** / `git describe --tags --abbrev=0` = **`v8.18.0`** | — | — | **値が一致しない**。D4 / U-1 の根拠 |
| `sh tests/run-tests.sh` の baseline | **未取得**（本 plan 生成では実行していない）。件数は環境で変動する（プライマリ+main / プライマリ+トピック / worktree で異なる） | — | — | **固定値を baseline にしない**。exec 開始時に**同一 checkout・同一ブランチ**で 1 回取得し、それを Stop Condition の基準にする（下記 Stop Condition） |

## Testing Strategy

- **Unit**
  - `test_run_evidence.py`: 決定論（同一入力 2 回 → byte 一致）/ 20 フィールドの供給元マッピング / `unavailable` と `0`・空配列の区別 / **D3 正規化マッピングの負側（`MERGE_READY` / `BLOCKED` / 非終端 7 状態）** / legacy 4 分類（`metrics.py` 転写）/ privacy フィルタ（**禁止キー + 全フィールド値の絶対パス**）/ **入力ソース allowlist（ソース走査）** / **`quality_metrics{}` が run 単位指標のみ** / **`pr_number` 未解決時の `unavailable`** / adapter IF の橋渡し / 未知 `kind` entry の fail-closed
  - `test_run_evidence_verify.py`: exit code 4 値（0 / 1 / 10 / 11）/ missing / partial / tampered の negative 群 / 未知トップレベルキー reject / **`^_` 注釈キーの型検査（非 string を reject）** / `task_dir` 束縛 / **schema の `required` == 受理器の必須キー集合**
- **Integration**: `approvals/c3.json` + `delivery/record.jsonl` + arbiter record を fixture 上で合成し、producer → 受理器 → adapter の 1 周を通す。**`c3prime_verify.py` / `delivery.py` は実物を呼ぶ**（再実装しない）
- **E2E**: `tests/extras/ta-59-run-evidence.sh`（10 fixture の golden 再生成 + byte 比較 + 受理器 exit code + **EH-8 本体を `PLANGATE_HOOK_FILES` で実走**）
- **Edge cases**: `record.jsonl` 破損行 / `entry_id` 改竄（**記号アンカー = `delivery.load_entries()` の「保存 entry_id を信用せず再計算照合」**と同型）/ `c3.json` が legacy（`approval_kind` なし → **exit 10**・D6）/ 非終端 run 7 状態（発行しない = D3・**TC-59**）/ `terminal_state=BLOCKED`（delivery 層 4 フィールドが `unavailable`・**TC-58**）/ known-unavailable による partial（**exit 11**）/ arbiter record 0 件 / `evidence_refs` に絶対パス / **任意フィールド値に絶対パス** / `harness_version` の run 中変化 / **`pr_number` 未解決**
- **Lint（実測した CI 適用範囲）**: `.github/workflows/ci.yml` の markdownlint globs には **`docs/workflows/**/*.md` が含まれる**（`docs/working/**` は**含まれない**）。したがって新設する `run-evidence-contract.md` と `c3-prime-contract.md` の §7 追記は **CI で markdownlint が走る**。ローカル設定は `.markdownlint-cli2.jsonc`（`MD013` / `MD060` 無効・`MD024` は siblings_only）。exec 中に `npx markdownlint-cli2 "docs/workflows/ai-loop/*.md"` で先に潰す
- Verification Automation: `python3 scripts/ai-loop/test_run_evidence.py && python3 scripts/ai-loop/test_run_evidence_verify.py && sh tests/run-tests.sh`

> ⚠️ **上の行を bold にしてはいけない（C-2 R-C01・実測）**: `scripts/ai-loop/plan_package.py` の
> `derive_loopspec()` は「`Verification Automation:` の直後にバッククォート囲みのコマンド列が続く」
> 正規表現で抽出し、失敗時に `PlanPackageError`（`derive: Verification Automation: 行が抽出できない`）で
> **fail-closed** する。ラベルを bold にすると抽出対象文字列が `Verification Automation**:` になり
> **NOMATCH**（実測で確認）。ai-loop 系譜の TASK-0872 / 0873 / 0877 / 0896 の plan はいずれも
> **bold なし**で MATCH する。本 plan の carve-out 節は ai-loop 自走を前提にしているため、
> bold のままだと**自走時に確実に停止する**。

## Loop Scope

単一 PBI（TASK-0874）の exec 内における「テスト失敗 → 自己修正」の反復のみ。RunEvidence が記述する **run 収束ループはプロダクト仕様**であり本 plan の Loop ではない。

## Stop Condition

変更が Files / Components to Touch 内 / Verification Automation が全成功（exit 0）/ AC-1〜AC-16 の全 TC（**65 件**）が PASS（未実行 / SKIP 0 件）/ 敵対レビュー critical・major ゼロ収束 / issue DoD の外部反映（#874 コメント・#870 evidence link）完了 / 残課題は handoff に明示。

> ⚠️ **本 PBI の Stop Condition 充足は issue #874 の close 条件充足を意味しない**（C-2 R-007）。
> DoD の「#869 shadow mode 統合 test」「#811 promotion provenance test」「効果測定」は
> **#869 / #811 実装後**に充足される。**#874 は本 PBI 完了後も OPEN**。
>
> **テスト件数の数え方（TASK-0917 R-020 の教訓の適用）**: `sh tests/run-tests.sh` の PASS 件数は**環境で変動する**（プライマリ checkout / トピックブランチ / worktree で値が違う）。したがって**固定値を baseline に置かない**。exec 開始時（T-2）に **同一 checkout・同一ブランチで 1 回実測**した値を `status.md` に記録し、完了時は「その値 + ta-59 が追加する PASS 行数（**python unit 2 本 + fixture 検証行**）を下回らない」ことを条件にする。「開始時の値を下回らない」だけでは新規 test が 1 本も実行されなくても通るため、**下限は必ず引き上げる**。

## Resume Condition

stop 後の再開は、原因・修正方針・検証手順を本 plan に追記し Replan 判定を通す。producer は決定論なので再開時の副作用は無い（外部作用層を持たない）。

## Replan Triggers

- **変更ファイル数 > 24**（= 想定 19 + 5）。**計測はコマンドで固定する**（C1-PLAN-09-AEE の是正）:
  `git diff --name-only origin/main -- ':!plugin/' ':!docs/working/' | wc -l` **> 24**。
  `plugin/`（T-37 の sync が 5 ファイル自動生成）と `docs/working/`（本 PBI の working context 7〜9 ファイル）を
  除外しないと、**正常進行でも 30 前後に達して閾値が即誤発火する**（想定 19 は「手作業ファイル数」の定義であり
  `git diff --name-only` の生件数ではない）
- 同一検証コマンドの連続失敗 3 回 / 同一ファイルへの修正反復 3 回
- **`schemas/` / `bin/plangate` / `.github/workflows/` / `.claude/**` / `scripts/hooks/**` を触る必要が判明した時点で即停止**（いずれも HO 該当。EH-3 の 9 カテゴリ = `check-plan-hash.sh` の HO パターン case 文（9 カテゴリ））
- `delivery.py` / `c3_contract.py` / `c3prime_verify.py` / `arbiter.py` / `metrics.py` への変更が必要と判明した時点で**即停止**（Out of scope の改訂は C-3 再承認事項）
- `docs/working/ai-loop-runs/` の既存 28 件を変更する必要が判明した時点で即停止（AC-15 は「置き換えない」が前提）
- #869 / #811 / #894 / #908 が先に merge され接続前提が変わった場合
- `harness_version` の定義（U-1）が C-3 で決まらず AC-12 が検証不能になった場合

## Revert Policy（critical / 段階的ロールバック）

| Level | 対象 | 手順 | 判断者 |
|-------|------|------|--------|
| **L1** | Scope 内の単一ファイルの誤変更 | `git restore -- <path>`（ブランケットな `git stash` は使わない） | agent |
| **L2** | 新規 fixture / golden の作り直し | `tests/fixtures/run-evidence/` を削除して再生成（producer が決定論なので完全復元可能） | agent |
| **L3** | c3-prime-contract §7 追記の撤回 | 当該 commit を `git revert`（additive 追記のみのため §4/§6/§8 に影響しない） | agent |
| **L4** | sync 反映の撤回 | `git restore -- scripts/sync-plugin-plangate.sh plugin/` → sync 再実行で no-op を確認 | agent |
| **L5** | PBI 全体の撤回 | feature branch を破棄し `docs/working/TASK-0874/` に無効化を明記。**PR の close は Human-owned** | human |

Loop Attempts:（exec 中に追記）

- attempt: / changed: / verification: / result: / next decision:

## Risks & Mitigations

| リスク | 検証手段 | Fallback |
|--------|---------|---------|
| **`unavailable` を空配列 / 0 で埋めて fail-open**（#868 未実装の `routing_decisions[]` が「routing 無し」と誤読される） | `metrics.py` の 4 分類転写 + 「空配列の明示供給」と「未供給」を区別する負側 TC（`delivery.py` の `findings_unavailable` と同型） | `unavailable` を含む record は受理器 exit **11（partial）**で ready 扱いしない |
| **非終端 run を `MERGE_READY` として発行**（D3 のマッピング誤り） | `record.jsonl` に `kind=merge_ready` entry が**物理的に存在する**ことのみを MERGE_READY の条件にする（**記号アンカー = `delivery.assess()` の `state = "MERGE_READY"` 分岐**が刻む唯一の経路）+ **7 状態すべての負側 TC を TC-59 で parametrized に実装**（C-2 R-001。当初は「7 状態すべての負側 TC」と書きながら対応 TC が 1 件も存在しなかった） | 判定不能は発行しない（安全側） |
| **`harness_version` の定義が未確定のまま実装が進む** | D4 / U-1 を C-3 の明示判断事項に上げる。AC-12 の TC は「注入値と終了時値の byte 一致」で**意味論と独立に**書く | 定義が決まらない場合は `harness_version` を必須から外し `unavailable` 許容にする（AC-12 は不成立 → C-3 で scope 縮小の判断） |
| **privacy 違反（raw transcript / secret / 絶対パス）が commit される**（不可逆） | producer 側の禁止キー 14 個検査 + **全フィールド値の絶対パス検査**（TC-65。EH-8 は値を見ないため = C-2 R-C09(a)）+ **10 fixture に対し ta-59 の中から `PLANGATE_HOOK_FILES` 指定で EH-8 を実走**（`tests/fixtures/` は privacy CI から除外されているため CI 任せにしない = C-2 R-C03） | 保存形式を `.json` に固定して EH-8 の走査対象に必ず載せる（`.jsonl` にしない）+ 禁止キー一覧は `.md` 側に置き schema の `properties` に書かない |
| **`docs/schemas/` に置いた schema が誰にも検証されない**（実測: schema 検証 CI 経路 0 本） | `run_evidence_verify.py` + ta-59 で検証経路を自作。ta-59 は glob で CI job `plangate CLI tests` に自動で乗る | — |
| **schema と producer / 受理器が機械束縛されず、schema が飾りになる**（C-2 R-008） | **受理器が schema を唯一の正として読む**（required / allowlist を導出）+ **TC-61**（`schema["required"]` == 受理器の必須キー集合）+ **TC-62**（producer 出力の全キー ⊆ `properties` ∪ `^_`）。⚠️ 当初 Fallback の「golden byte 比較で検出」は**成立しない**（golden 比較は producer 出力同士の比較で schema を参照しない）ため撤回した | 乖離検出時は schema を正として producer / 受理器を寄せる（schema を緩めない） |
| **`escalation` が schema の `properties` 未登録で、最も検証が必要な EV だけが reject される**（`additionalProperties: false` 下） | Step 1 で **producer 出力キーの全集合**（required 21 + `observation` / `cause_hypothesis` / `escalation`）を契約 doc に列挙し `properties` と 1:1 対応させる（TC-62） | 登録漏れ検出時は schema に追加（`additionalProperties` を緩めない） |
| **手書き fixture が実 record と乖離**（TASK-0917 で顕在化した型） | fixture 2 の入力形状を **実在の `docs/working/TASK-0917/evidence/e2e/run/delivery/record.jsonl`（実測 3 行）** に照らして作る。未知 `kind`（`notice`）を握り潰さない TC | 乖離検出時は fixture を実 record 側に寄せる（producer を緩めない） |
| **上流未実装（#811 / #869 / #868）の契約が後で変わる** | adapter IF は**フィールド契約まで**に限定し実接続しない。綴りは issue 本文の実測綴り（`source_run_ids` / `baseline_version`）に合わせる | 変更時は adapter 関数 1 箇所の差し替えで済む構造にする（producer 本体に下流語彙を持ち込まない） |
| **`baseline_harness_version` という存在しない綴りを使ってしまう** | 実測: repo にも issue にも **0 件**。実在するのは `baseline_version`（#869 issue 本文）と `harness_version`（#874）のみ | 橋渡し名を契約 doc に明記し、test で綴りを固定する |
| **AC-13 の fail-closed を issue 番号ハードコードで実装して stale 化** | #862 は既に **CLOSED**・#866 は **OPEN**（実測）。番号ではなく `blocked_by[]` 非空という汎用条件で実装 | 番号参照が必要なら契約 doc 側に列挙し、コードは doc を参照しない（stale 化を doc 更新で解消できる形にする） |
| **受理器 rc の意味が姉妹受理器と衝突し legacy を partial と誤読**（当初案 `10`=partial が `c3prime_verify.py` の `10`=legacy と逆転） | D6 で前例準拠（`10`=legacy / `11`=partial）に是正。契約 doc に**両受理器の rc 対応表**を置く。実測で `10` を legacy として消費する呼び出し側が 2 箇所実在（`delivery.py` の `if rc == 10:` = 厳密比較 / `bin/plangate` の `_plangate_c3_dispatch` 後段 = **0/1 以外を legacy にする catch-all** = C-2 R-C07） | 独自割当を通す場合は U-11 の C-3 判断を経て、契約 doc に「前例と逆にする理由」を明文化する |
| **Phase 1 で受理器 exit 0 の経路が死にコード化**（D7-1 で producer 出力が全件 partial になるため） | 受理器の `0` は**合成 complete EV**（unit test 内構築）で必ず検証する（TC-56）。fixture では検証しない | U-10 が known-unavailable allowlist 採用に決まった場合、fixture 1〜6 の期待 exit を `0` に戻し TC-56 を fixture 側へ移す |
| **T-18 の完了条件が到達不能で、実装者が fail-open で回避する**（C-2 R-006） | T-18 を「**exit 11（partial）で受理し `unavailable` フィールド名が stderr に列挙される**」へ是正。到達不能な exit 0 を完了条件に残すと、実装者が最短の是正として **`routing_decisions` を `[]` で埋める**（= 本 plan が TC-52 / Risks 第 1 行で最も避けようとしている fail-open）へ誘導される | U-10 が allowlist 採用に決まった場合のみ exit 0 に戻す |
| **`repair_rounds` が `unavailable` ではなく `0` で埋まって fail-open**（C-2 R-C04） | `--pr-number` を注入値の全数に追加し、`kind=merge_ready` の `record.pr_number` からも解決を試み、**いずれも不能なら `unavailable`**（TC-64）。実測で `delivery._completed_rounds(entries, None)` は**例外にならず `0` を返す** | PR 番号が恒常的に解決不能なら `repair_rounds` を known-unavailable に加える判断を C-3 で相談 |
| **`quality_metrics{}` に corpus 集計値を入れて AC-2 が後日壊れる**（C-2 R-005） | 許可指標を **当該 run で閉じる `first_pass` / `rounds`** に限定し契約 doc に列挙（TC-60）。`metrics.py` の `decision_counts` / `round_distribution` / `hotl_health` / `first_pass_rate` は**全 run が分母**（実測） | 限定できない場合は Phase 1 の `quality_metrics` を `unavailable` 固定にし known-unavailable を 4 にする |
| **`allowed_paths` が arbiter / delivery の非対称 matcher で片側 violation になる**（C-2 R-C02） | Files 表のディレクトリ行を **末尾 `/` と `**` の 2 記法併記**にし、両 matcher に通して in-scope を実測確認（Files 節の ⚠️） | 記法規約の統一は別 PBI（handoff の V2 候補） |
| **plan の `Verification Automation` 行が bold で ai-loop 自走が起動直後に停止**（C-2 R-C01） | ラベルを **bold なし**にし、`plan_package.derive_loopspec()` の抽出が MATCH することを実測で確認 | NOMATCH 検出時は他 4 plan（TASK-0872 / 0873 / 0877 / 0896）と同一書式へ戻す |
| **`ta-58` が main で使用済みだったため番号衝突**（C-2 反映時に判明 / #968） | 採番は **`git ls-tree origin/main --name-only tests/extras/` で最大番号を実測**してから決める。exec 開始時（T-2）に再確認する | 衝突検出時は空き番号へ付け替え（plan / todo / test-cases の全参照を同時更新） |
| **sync 2 箇所の片方漏れ**（各 24 エントリ・実測） | 2 箇所の basename 集合を diff して差分 0 を確認する専用タスク（**T-36**）+ sync 2 回目 no-op | 漏れ検知時は両方へ追加し `git diff --quiet plugin/` を再確認 |
| **fixture 10 件の粒度が大きすぎて実装が膨らむ**（ratio 1.19 だが fixture が実数の過半） | Replan Trigger（> 24 ファイル）+ golden は出力のみ commit（入力は test 内構築）でファイル数を抑える | fixture 8/9/10（下流接続系）を最小 record に縮小する判断を C-3 で相談 |
| **`schemas/` への昇格を将来忘れる** | 裁定（§7）どおり **昇格判定は Gate 接続 PR の Human C-3 チェックリスト**。本 PBI の handoff に「昇格 PBI の予約起票」を V2 候補として明記（裁定 §8-3 が plan 段階の判断事項と指定） | U-6 として C-3 判断に上げる |
| **`sh tests/run-tests.sh` を stdin 開放で実行してハング** | 常に `sh tests/run-tests.sh </dev/null` の形で実行（`precompact-memory-guard.sh` が stdin を待つ） | ハング時は中断して `</dev/null` 付きで再実行 |

## Questions / Unknowns（→ C-3 論点）

> ID は **U-1 〜 U-12** で固定（他ファイルから参照されるため**欠番でも振り直さない**）。
> **未決 = 8 件**（C-3 で人間が判断）/ **plan 段階で確定 = 4 件**（U-2 / U-3 / U-6 / **U-7**・追認のみ）。
> **C-2 反映（R-009）で U-7 を確定へ降格した**（9 → 8 件）。

### 未決（C-3 判断が必要・8 件）

- **U-1: `harness_version` の定義**（D4）。実測で `bin/plangate` = `0.2.0` / plugin = `8.18.0` / `git describe` = `v8.18.0` と**値が一致しない**。提案は `{plugin_version, cli_version, corpus_hash}` の object だが、単一文字列にするか / どれを正とするかは Human 判断。**pbi L80 の「§6 `derived_loopspec_hash` が供給元」は実測と整合しない**ことの追認も含む
- **U-4: 非終端 run の扱い**（D3）。「RunEvidence を発行しない」（安全側・plan 既定）か「4 値目 `IN_PROGRESS` を作る」か。前者だと `EXEC_RETURN` で終わった run の証跡が残らず、#869 の学習源が失われる可能性がある
- **U-5: `repository` / PR 参照と privacy §4 の関係**（**C-2 R-011 / B→A-5 で選択肢と射程を追加**）。issue の 20 フィールドに `repository` が含まれるが、`metrics-privacy.md` §4 は「プロジェクト固有名・社名・人名 → 完全除外」とする。EH-8 の禁止キー 14 個には含まれないため機械的には通る（実測）。**選択肢と各案の帰結**:

  | 案 | 内容 | 帰結 |
  |----|------|------|
  | (a) | issue verbatim のまま `s977043/plangate` を格納 | 公開 repo なので実害は小さく下流が読みやすい。privacy §4 の文言とは緊張が残る |
  | (b) | owner を除去し `plangate` のみ格納 | §4 に寄るが、下流が複数 repo を扱うとき一意性が落ちる |
  | (c) | `canonical_hash()` でハッシュ化 | privacy 最強。ただし **#811 の追跡性（どの repo の PR か）が落ちる** |
  | (d) | フィールドを省略 | issue の **20 フィールド verbatim から外れる** = versioning policy 上の破壊的変更 |

  **⚠️ 衝突面は `repository` だけではない（C-2 レーン B 返送論点 5・実測）**: 実在の一次証跡
  `docs/working/TASK-0917/evidence/e2e/run/delivery/record.jsonl` の `notice` entry は
  `"comment_url": "https://github.com/s977043/PlanGate/pull/940#issuecomment-…"` を、
  `receipt` entry は `"result_ref": "adopted:7b229223…|comment:https://github.com/…"` を保持する。
  **TC-51「account 識別子がキー名・値の両方で 0 件」を厳格適用すると、実 record 由来の
  PR / コメント参照がすべて落ち、AC-11 の `improvement_refs[]`（改善 PR/commit の追跡）と両立しない**。
  したがって U-5 は「`repository` を書いてよいか」ではなく「**PR / コメント URL を含む値レベルの
  account 識別子をどこまで許すか**」として判断する。**TC-51 の判定基準は C-3 の結論に従って確定する**
  （plan は既定を置かず、AC-6 と AC-11 のどちらも壊さない案を C-3 で選ぶ）
- **U-8: adapter IF の最小フィールド**（pbi L106 の未決事項）。`source_run_ids` / `baseline_version` 以外に何を必須にするか。#869 の候補契約は 20 フィールド、#811 の Trust Ledger は 12 フィールドあり（実測）、**どこまでを #874 が供給し、どこからを下流が埋めるか**の境界が未確定
- **U-9: fixture 9（paired replay）/ 10（canary rollback）の実質**。実測で **canary の機械契約は ai-loop 正本に存在しない**（`docs/workflows/ai-loop/` の 15 本に canary の定義なし。`stop-rollback.md` に `rollback_action` enum 5 値があるのみ）。#869 の `canary_plan` / #811 の `canary_scope` はいずれも未実装。したがって fixture 9/10 は「**#874 が定義した最小の形**」になり、下流が別定義を採ると乖離する。この乖離を許容するか、#869/#811 の plan 確定まで fixture 9/10 を Deferred にするか。
  **⚠️ C-2 R-002 で fixture 6 の実質も本論点に含めた**: `routing_decisions[]` は Phase 1 で常に `unavailable`
  （#868 OPEN）であり、**`fx-06-routing-escalation` は `terminal_state=HUMAN_ESCALATED` / exit 11 で
  `fx-04-human-escalated` と区別不能**（routing 実カバレッジ 0 = 実質 9 fixture）。
  **plan 既定は (b) vacuity を明示して進む**。**代替案 (a)**: `routing_decisions[]` の item schema
  （`{requested, resolved, outcome}` 暫定粒度）を Step 1 で定義し、値を注入可能にして
  （未注入時のみ `unavailable`）fixture 6 を注入値で構成する。**(a) を採ると #868 の設計に踏み込む**が、
  **(b) のまま #868 実装時に item 形を後付けすると versioning policy の「3 issue 合意」を伴う
  破壊的変更になる**。どちらを採るかは Human 判断
- **U-10: Phase 1 で `evidence_status=complete`（受理器 exit 0）に到達可能にするか**（D7 / C-1 FAIL C1-PLAN-04 由来）。**plan 既定は「到達させない = Phase 1 の producer 出力は全件 partial」**（安全側）。代替案は **known-unavailable allowlist**（`routing_decisions` / `replan_count` / `cost_metrics` のみの `unavailable` は `complete` を妨げない）または第 3 の status（`complete_phase1`）。**判断材料**: 下流（#869 / #811）が「complete な run だけを学習・promotion 対象にする」設計を採ると、**Phase 1 の全 run が partial では下流が 1 件も動かせない**。逆に allowlist を置くと「証跡が欠けたまま ready 扱い」の経路を自分で作ることになる。#874 単独では決められない
- **U-11: 受理器 exit code の値割当**（D6 / C-1 WARN C1-B1B2-17 由来）。**plan 既定は前例準拠**（`0`=complete / `1`=NG / **`10`=legacy** / **`11`=partial**）。代替案は本 PBI 独自割当（`10`=partial / `11`=legacy）。**判断材料**: `10`=legacy は `scripts/ai-loop/c3prime_verify.py` L67 の実装であり、**その値を legacy として消費する呼び出し側が実在する**（`delivery.py` L530 / `bin/plangate` L1010）。独自割当を通すなら、契約 doc に両受理器の rc 対応表を置いたうえで「なぜ前例と逆にするか」を明文化する必要がある。
  ⚠️ **C-2 R-009 の所見: 本項は「追認想定」**（対立案に利点が 1 つも提示されておらず、実質的に選択肢が 1 つ）。
  ただし exit code は契約層の値割当であり、決定を plan 側で閉じずに **C-3 の明示追認を残す**（判断コストは低い）。
  ⚠️ **C-2 R-C07 の追加事実**: 消費側の強度は 2 箇所で異なる — `delivery.py` は `rc == 10` の厳密比較だが、
  `bin/plangate` は **0/1 以外を legacy にする catch-all**。したがって新受理器の `11` を
  `_plangate_c3_dispatch` 経路へ流すと **catch-all が legacy と誤読する**（契約 doc に制約として明記）
- **U-12: `blocked_by[]` の供給元**（AC-13 / C-1 WARN C1-PLAN-01 由来）。**誰が「未解決の正本」を candidate に注入するか**が未定義。**plan 既定は fail-closed**（キー欠落 = 判定不能 → `BLOCKED` / 明示 `[]` のときのみ非 BLOCKED）だが、**恒常的に誰も埋めないなら全候補が BLOCKED になり promotion 経路が動かない**。供給責任を #811 側に置くか、契約 doc 側に未解決正本リストを持たせるかは Human 判断

### plan 段階で確定（Unknowns から降格・4 件）

| ID | 確定内容 | 根拠 |
|----|---------|------|
| **U-2: `replan_count` の供給元** | **Phase 1 は `unavailable` 固定**。定義は V2（`replan` を刻む層が実装された時点）へ送る | 提示された 3 択のうち「`record.jsonl` に新 entry kind を足す」は **plan 自身の Constraints（`delivery.py` 不変）で既に排除済み**。残る「plan の Loop Attempts を数える」は *plan ドキュメントの編集回数*であって run の事実ではなく、決定論 producer の入力にできない（同一 events から同一出力にならない）。よって Phase 1 の選択肢は `unavailable` 一択 |
| **U-3: `cost_metrics{}` の供給元** | **Phase 1 は `unavailable` 固定** | `docs/working/_metrics/events.ndjson` が `.gitignore` L53 で除外されている（実測）ため、**commit される artifact から参照できる収集経路が存在しない**。privacy §3 が集計値を Allowed としても、集計元が無い。調べれば決まる事項であり Human 判断を要さない |
| **U-7: schema / fixture の plugin 配布**（**C-2 R-009 で降格**） | **Phase 1 では配布しない**。配布の要否判断は **Phase 2（Gate 接続）** で行う | `sync-plugin-plangate.sh` の同期先は `skills/ai-loop-cycle/references` と `.../scripts` **のみ**（実測）で `docs/schemas/` も `tests/fixtures/` も対象外。かつ **Phase 1 = shadow / dogfooding 域**は裁定で確定済み（下流リポジトリが RunEvidence を生成する要件が Phase 1 に存在しない）。⇒ **調べれば決まる事項**であり Human 判断を要さない。配布が必要になるのは Gate 接続以降であり、その時点の設計に委ねる（handoff の V2 候補に記録） |
| **U-6: `schemas/` 昇格 PBI の予約起票** | **予約起票する**（#870 の後続として。実施タイミング = 本 PBI の handoff 発行時 / T-44） | 裁定正本 §8-3 が「予約起票するかを **plan 段階で判断**」と**明示的に plan へ割り当てた判断**であり、C-3 へ先送りするのは裁定の未消化。かつ本 plan の Risks に「`schemas/` への昇格を将来忘れる」が挙がっており、予約 issue はその最小コストの緩和策（起票は AI-owned。**昇格 patch の適用自体は HO = Human-owned で不変**） |

## Mode判定

**モード**: **critical**

**判定根拠**（`.claude/rules/mode-classification.md` の定量・定性の**最大値**を採用）:

- **受入基準数: 16 件**（issue verbatim **13** + In scope 対応 **3**（AC-14 / AC-15 / AC-16）= 16）→ **超高（11+）が決定論的に確定**
- **変更ファイル数: 19**（手作業。`plugin/` 自動生成と `docs/working/TASK-0874/` を除く実数。内訳 = 新設 7 + fixture 10 + 改変 2）→ **超高（16+）**
- タスク数（見込み）: **44**（`todo.md` 実数。T-1〜T-44・欠番なし。C-1 是正で旧 T-38 を 4 分割 + DoD 反映 2 件 + 昇格 PBI 予約起票 1 件を追加）→ **超高（21+）**
- 変更種別（定性）:
  - **新しい契約層（RunEvidence）をリポジトリに導入する**。上流 3 層（c3-prime / delivery / arbiter）の出力を横断結合する上位 artifact であり、影響はシステム全体に及ぶ
  - **下流 2 PBI（#869 / #811）の実装前提になる**。契約を誤ると 2 PBI が作り直しになる（ロールバックが段階的に必要）
  - **schema の配置が承認境界に隣接**（Phase 1 は非 HO だが、昇格先 `schemas/**` は HO）
  - privacy 違反が **commit されると不可逆**（EH-8 で block される設計だが、設計を誤ると block をすり抜ける経路がある = `.jsonl` 拡張子）
- **前例との一貫性**: 接続先を作った **TASK-0873（delivery.py）は Mode=critical**、外部作用を足した **TASK-0917 も Mode=critical**。本 PBI はその両方を入力として横断結合する上位 artifact であり、critical を下回らない
- **最終判定**: **critical**（定量 3 軸すべてが超高 + 定性も超高）

**帰結（`mode-classification.md` フェーズ適用マトリクス）**:

- **C-1 = 17 項目 / C-2 = 複数観点 / C-3 = 人間による詳細レビュー（必須）/ V-2 実行 / V-3 実行 / V-4 リリース前チェック実行**
- **autonomous APPROVE 不可**（`working-context.md` の判定マトリクス「Mode = high-risk / critical → ❌ 不可（人間 C-3 必須）」）
- **`lite_eligible`: false**（`mode-classification.md` AC-11「critical は原則 false」。事前の C-3 明示承認が無いため C-3 非同期降格の対象にもならない）

**HO 該当性**: **非該当**（実測）。`scripts/hooks/check-plan-hash.sh` の HO パターン case 文（9 カテゴリ）に対し、`docs/schemas/*.json` / `scripts/ai-loop/*.py` / `tests/extras/*.sh` / `tests/fixtures/**` / `docs/workflows/ai-loop/*.md` / `scripts/sync-plugin-plangate.sh` / `plugin/**` はいずれもマッチしない（`schemas/*.schema.json` は先頭が `schemas/` である必要があり `docs/schemas/` は不一致）。**`schemas/` 直下を触る必要が生じた時点で HO 該当 → 即停止**（Replan Trigger）。

**carve-out**: 本 PBI の成果物は **rollout-policy §2 判定基盤 carve-out ①（`scripts/ai-loop/**`）②（`docs/workflows/ai-loop/**`）に該当**するため、**ai-loop で自走させる場合は escalate 固定**（auto-approve 対象になり得ない）。#916 の機械強制が入るまでは規範層（実行者が escalate する責務）で担保する。なお `docs/schemas/**` は carve-out の glob **①②③のいずれにも含まれない**（実測）ため、schema だけが carve-out 外になる — この非対称は契約 doc に明記する（Step 1）。

## AC ↔ Step ↔ test-case 対応表（16 件・全数 / TC 65 件）

| AC | 内容（要約） | Step | test-case |
|----|-------------|------|-----------|
| AC-1 | RunEvidence schema と versioning policy がある | Step 1・Step 2 | TC-01 〜 TC-05、**TC-61**（schema `required` == 受理器の必須キー集合）、**TC-62**（producer 出力キー ⊆ `properties` ∪ `^_`） |
| AC-2 | 同一入力 events から同一 RunEvidence を再生成できる | Step 3 | TC-10 〜 TC-12、**TC-60**（`quality_metrics` が run 単位指標のみ = corpus 集計で byte が変わらない） |
| AC-3 | Plan hash / C-3' / final head SHA / CI / review / routing / terminal state が同一 run へ結合 | Step 3 | TC-13 〜 TC-16、**TC-50**（routing 結合）、**TC-57**（`MERGE_READY` 導出）、**TC-58**（`BLOCKED` 導出 + delivery 層 4 フィールド `unavailable`）、**TC-59**（非終端 7 状態は発行しない）、**TC-64**（`pr_number` 未解決 → `repair_rounds` は `unavailable`） |
| AC-4 | missing / partial / tampered を ready 扱いしない | Step 2・Step 3 | TC-06 〜 TC-09、TC-32、**TC-52**（producer 側 `unavailable` ≠ 空配列）、**TC-53**（未知 `kind` → escalation）、**TC-56**（合成 complete EV で exit 0） |
| AC-5 | observation と cause hypothesis が分離される | Step 1・Step 3 | TC-17、TC-18 |
| AC-6 | hidden CoT / raw transcript / secret を要求・保存しない | Step 1・Step 3・Step 5 | TC-19 〜 TC-22、**TC-51**（account 識別子非保存・判定基準は U-5 の C-3 結論に従う）、**TC-63**（producer の入力ソース allowlist = 「**要求しない**」側）、**TC-65**（全フィールド値の絶対パス 0 件） |
| AC-7 | #869 が RunEvidence のみから shadow candidate を生成できる | Step 7・Step 8 | TC-23、TC-24、TC-33 |
| AC-8 | candidate が `source_run_ids` と baseline harness version を保持 | Step 7 | TC-25、TC-26 |
| AC-9 | improvement TASK が通常の Plan-first / C-3' / PR 収束を通る | **Step 7・Step 8** | TC-27 ⚠️ **Phase 1 は契約層のみ**（記述子のキー集合 allowlist の固定まで）。**実フローの検証は #869 / #811 実装後**（C-2 R-007） |
| AC-10 | paired replay / 独立 grader / activation check / rollback を source candidate へ戻せる | **Step 7・Step 8** | TC-34、TC-35 ⚠️ **Phase 1 は契約層のみ**（`grader_ref` / `activation_check` の**キー存在**の固定まで。独立 grader も activation check も本 PBI では実装しない）。**実フローの検証は #869 / #811 実装後**（C-2 R-007 / U-9） |
| AC-11 | #811 promotion decision と改善 PR/commit を追跡できる | Step 7 | TC-28、TC-29 |
| AC-12 | active run の harness version が途中で変化しない | Step 3 | TC-30、TC-31 |
| AC-13 | 未解決の正本へ自動 promotion しない fail-closed 条件がある | Step 7 | TC-36、TC-37、**TC-55**（`blocked_by` キー欠落 → BLOCKED） |
| AC-14 | c3-prime-contract §7 に #874 consumer が追記され §4 全規則を fail-closed 再検証 | Step 6 | TC-38 〜 TC-41 |
| AC-15 | legacy 9 キー / run メタ 14 キー record との関係が機械検証可能 | Step 4 | TC-42 〜 TC-45、**TC-54**（`run_count` = distinct `run_id` 数） |
| AC-16 | 10 fixture が `tests/extras/ta-59` で CI 実行され AC↔fixture 対応表が残る | Step 8・Step 9 | TC-46 〜 TC-49、および fixture 対応表（test-cases.md 末尾）⚠️ **fixture 6 は Phase 1 で routing 実カバレッジ 0**（C-2 R-002・fixture 表に明示） |

> **AC-9 / AC-10 の Step 割当の是正（C1-PLAN-06）**: 当初表は AC-9 / AC-10 を Step 8（fixture）
> のみに割り当てていたが、対応 TC（TC-27 / TC-34 / TC-35）を**実装するのは adapter = Step 7**
> であり、Step 8 は fixture 供給に過ぎない。V-1 で突合先を取り違えないよう **Step 7・Step 8 の併記**に是正した。
>
> **C-1 是正で追加した TC（7 件）**: TC-50 / TC-51 / TC-52 / TC-53（C1-TEST-13 の AC 本文カバレッジ穴）、
> TC-54（C1-TEST-14 ② の恒等式分離）、TC-55（C1-PLAN-01 ① の fail-closed 既定）、
> TC-56（D7 で exit 0 が producer 経路から到達しなくなったことへの補償）。**TC 総数 49 → 56**。
>
> **C-2 是正で追加した TC（9 件）**: TC-57 / TC-58 / TC-59（R-001 / R-003 = D3 正規化マッピングの負側）、
> TC-60（R-005 = `quality_metrics` の run 単位限定）、TC-61 / TC-62（R-008 = schema ↔ 受理器 ↔ producer の機械束縛）、
> TC-63（R-010 = AC-6 の「要求しない」側 / 入力ソース allowlist）、TC-64（R-C04 = `pr_number` 未解決 → `unavailable`）、
> TC-65（R-C09(a) = 全フィールド値の絶対パス検査）。**TC 総数 56 → 65**。
>
> **AC-9 / AC-10 の限定（C-2 R-007）**: 両 AC は Phase 1 では**契約層の充足のみ**であり、
> issue #874 の DoD（「#869 shadow mode の統合 test」「#811 promotion provenance test」「効果測定」）は
> **#869 / #811 実装後**に充足される。**本 PBI 完了後も #874 は OPEN**（Stop Condition の ⚠️ 参照）。
>
> **fixture ↔ AC 対応表**は `test-cases.md` の `## 必須 fixture（10 件）↔ AC 対応表` に置く（AC-16 が要求する成果物）。
