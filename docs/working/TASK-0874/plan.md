# EXECUTION PLAN — TASK-0874

> Issue: [#874](https://github.com/s977043/plangate/issues/874)（P1 / enhancement / area:workflow / area:eval / area:metrics）
> Parent EPIC: [#870](https://github.com/s977043/plangate/issues/870)（OPEN・実測 2026-08-02）
> 入力: [`pbi-input.md`](./pbi-input.md)（main 実在・本 plan では**編集しない**）
> 生成: 2026-08-02（base = `origin/main` = `a4afacb`）
> Mode: **critical**（下記 `## Mode判定` 参照。**autonomous APPROVE 不可 / 人間 C-3 必須 / C-2 複数観点 / V-4 実行対象**）

## 確認事項（B-1）

本 plan の生成にあたり Human への追加質問は行わず、pbi-input と main 実測で確定できる範囲に閉じた。
**確定できなかった論点は勝手に決めず `## Questions / Unknowns` に 9 件残す**（C-3 で人間が判断）。

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
| **D1-A（採用）** | `docs/schemas/run-evidence.schema.json` = **JSON Schema draft 2020-12**。`schemas/*.schema.json` の書式をそのまま踏襲 | `schemas/*.schema.json` は **28 本**（実測）。`$schema` は 2020-12 が 23 本 / draft-07 が 5 本、`$id` は 28/28 全ファイルに存在、`additionalProperties` 出現 78 箇所中 **72 が `false`** | **昇格時の diff が最小**（`schemas/` への `git mv` + `$id` 1 行変更で済む）。裁定の「1 回の HO patch で昇格」を実現できる唯一の形式 |
| D1-B | `docs/schemas/run-evidence.yaml` = コメント付き代表 YAML | `docs/schemas/child-pbi.yaml`（**`docs/schemas/` 唯一の実在ファイル**・298 行）は L1-9 で「本書は schema を『コメント付きの代表 YAML』として記述する / JSON Schema 等への変換は実装 PBI で行う」と自己宣言 | 昇格時に **形式変換が必要**（`schemas/` は JSON Schema 前提）。機械検証も別途必要。裁定の「1 回の HO patch」に反する |

**採用: D1-A**。ただし `docs/schemas/` は **CI 検証経路を持たない**ため（下記）、機械検証は自作する。

> **実測: `docs/schemas/` の検証経路**
>
> - `.github/workflows/schema-validate.yml` の trigger paths は `docs/working/**/*.json` / `schemas/**/*.json` / `scripts/validate-schemas.py` / `scripts/schema_mapping.py` / 自ファイル。**`docs/schemas/**` は含まれない**
> - `tests/extras/ta-05-validate-schemas.sh` は固定 fixture 2 件（`$FIXTURES_DIR/schema-validate/{valid,invalid}/c3.json`）のみ検証。**`schemas/` を glob 走査しない**
> - `tests/extras/ta-35-yaml-schema.sh` の対象は `scripts/validate-yaml-schemas.py` の `KNOWN_PAIRS` **ハードコード 3 組**のみ
> - `grep -rn 'docs/schemas' scripts/ tests/ .github/` = **5 件**。全て `scripts/check-orchestrator-docs.sh`（`child-pbi.yaml` の YAML parse + 必須キー grep）で、**この script はどこからも呼ばれていない**（`grep -rn 'check-orchestrator-docs' .github/ tests/ bin/ scripts/` の自己参照除外 = **0 件**）
>
> ⇒ **`docs/schemas/` に置いたものは現状 CI で一切検証されない**。本 PBI は `run_evidence_verify.py`（非 HO）+ `tests/extras/ta-58-*.sh` で検証経路を**自作**する（`tests/run-tests.sh` は `for extra in "$EXTRAS_DIR"/ta-*.sh` で glob source するため、ファイルを置くだけで CI job `plangate CLI tests` に乗る）

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
- **hash は `c3_contract.canonical_hash()` を import 再利用**（`json.dumps(sort_keys=True, separators=(",",":"))` の sha256 / `sha256:` prefix）。**独自実装を作らない**（`delivery.action_id()` L176-177 が同じ再利用をしている）

#### RunEvidence 20 フィールド × 供給元（実測ベース）

| # | field | 供給元（実測） | 取得不能時の扱い |
|---|-------|--------------|----------------|
| 1 | `run_id` | arbiter record 14 キー世代の `run.run_id`（**3/28 件のみ保有**・実測） / 無ければ呼び出し側注入 | **必須**・欠落は fail-closed |
| 2 | `task_id` | `approvals/c3.json` の `task_id`（`c3_contract.RECORD_REQUIRED_KEYS`）。**`task_dir` 名に束縛**（`c3prime_verify.py` L83-84 の転写） | fail-closed |
| 3 | `started_at` | 呼び出し側注入（`--started-at`） | fail-closed |
| 4 | `completed_at` | 呼び出し側注入（`--now`） | fail-closed |
| 5 | `repository` | 呼び出し側注入（`--repository`）。producer は `git remote` を呼ばない | fail-closed |
| 6 | `source_sha` | `approvals/c3.json` の `source_sha`（形式 `[0-9a-f]{7,40}`） | fail-closed |
| 7 | `final_head_sha` | `record.jsonl` の `kind=merge_ready` entry の `record.head_sha` / 無ければ最終 `kind=state` entry の `head_sha` | **非終端 run では missing** → `evidence_status=partial` |
| 8 | `plan_hash` | `approvals/c3.json` の `plan_hash`（`sha256:` prefix 付き） | fail-closed |
| 9 | `c3_prime_decision_ref` | `approvals/c3.json` への repo 相対参照 + `plan_package_hash`。**§4 全規則の再検証を通過した場合のみ**（AC-14） | fail-closed |
| 10 | `harness_version` | **供給元が main に存在しない（実測 0 件）** → **論点 D4 / Unknowns U-1** | — |
| 11 | `routing_decisions[]` | **#868 未実装**（`requested`/`resolved` routing の producer が無い） | **空配列で埋めない**。`unavailable` として明示（metrics.py の skip パターン転写） |
| 12 | `ci_outcomes[]` | `record.jsonl` の `kind=merge_ready` の `record.check_summary`（`{check_name: conclusion}`）+ `kind=state` entry の `reasons` | 未取得は `unavailable` |
| 13 | `review_findings[]` | `record.jsonl` の `record.review_disposition`（`{finding_id: disposition}`）+ `kind=receipt` かつ `action_kind=repair_review` の `finding_type` | 未取得は `unavailable` |
| 14 | `repair_rounds` | `record.jsonl` の当該 PR の receipt の `round` 最大値（**`delivery._completed_rounds()` L213-218 と同一定義**を再実装せず import） | 0 は「0 回」・未取得は `unavailable`（**区別する**） |
| 15 | `replan_count` | **供給元が main に存在しない** → **Unknowns U-2** | — |
| 16 | `human_interventions[]` | arbiter record の `decision=HUMAN_ESCALATED` + `record.jsonl` の `kind=state` かつ `state=HUMAN_ESCALATED` + `kind=notice` entry | 未取得は `unavailable` |
| 17 | `terminal_state` | **論点 D3 の正規化マッピング** | 非終端は `partial`（発行しない） |
| 18 | `quality_metrics{}` | `metrics.py collect()` の run 単位指標（`first_pass` / `decision_counts` / `round_distribution` / `hotl_health`）から当該 run 分を抽出 | 未取得は `unavailable` |
| 19 | `cost_metrics{}` | **供給元が実質存在しない**（`docs/working/_metrics/events.ndjson` は `.gitignore` L53 で除外・実測） → **Unknowns U-3** | — |
| 20 | `evidence_refs[]` | **repo 相対パスの参照のみ**（本文は保存しない）。絶対パス禁止（AC-6） | 空配列可 |

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
- 受理器を分けることで **trust boundary**（c3-prime-contract §7 L133「decision 値を無検証で信頼してはならない」）を構造として表現できる。生成側の検証を信頼せず受理側が再検証する

**exit code 契約（`c3prime_verify.py` L13-15 の転写・値は本 PBI で新規に定義）**:

| exit | 意味 |
|------|------|
| `0` | RunEvidence として受理（`evidence_status=complete`・全束縛整合） |
| `1` | 検証 NG（fail-closed。理由を stderr に出力） |
| `10` | **partial**（必須フィールドは揃うが `unavailable` を含む = ready 扱いしない・呼び出し側が明示処理） |
| `11` | **legacy**（RunEvidence ではなく 9 キー / 14 キー arbiter record を渡された。呼び出し側が legacy 経路へ委譲） |

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
   - 内容: 20 フィールド定義 + `evidence_status`（`complete` / `partial`）+ D3 正規化マッピング表 + versioning policy（破壊的変更は #872/#873/#874 の 3 issue 合意 = c3-prime-contract §8 L137 と同一規則を採る）+ **`observation` と `cause_hypothesis` のフィールド分離**（AC-5）+ EH-3 実効パターン（`schemas/*.schema.json`）と `ho-paths.md` L28（`schemas/**`）の**範囲差**の明記
   - 🚩 チェックポイント: schema が `$schema` = draft 2020-12 / `$id` = `https://github.com/s977043/plangate/schemas/run-evidence.schema.json`（**昇格後の URL で先に固定** = HO patch を `git mv` 1 手に収める）/ `additionalProperties: false`（既存 28 本中 72/78 箇所が `false`）/ `task_id` パターン `^TASK-[0-9]{4}$` / hash パターン `^sha256:[0-9a-f]{64}$`（`run-event.schema.json` L58 の実測形式）を満たすこと
2. **Step 2: 受理器 TDD（AC-4 / AC-1）— negative first**
   - Output: `scripts/ai-loop/run_evidence_verify.py` / `scripts/ai-loop/test_run_evidence_verify.py`
   - Owner: agent / Risk: **高**（AC-4 の中核）
   - 🚩 チェックポイント: **exit code 4 値（0 / 1 / 10 / 11）が契約どおり**。`missing`（必須キー欠落）/ `partial`（`unavailable` を含む）/ `tampered`（hash 不一致・`entry_id` 不一致）を **1 つも `0` に倒さない**。未知トップレベルキーは reject（`c3prime_verify.py` L73-75 の allowlist 転写。`^_` 注釈キーのみ許容）
3. **Step 3: 決定論 producer TDD（AC-2 / AC-3 / AC-5 / AC-12）**
   - Output: `scripts/ai-loop/run_evidence.py` / `scripts/ai-loop/test_run_evidence.py`
   - Owner: agent / Risk: **高**
   - 転写する具体パターン（**推測でなく実ファイルから**）:
     - `plan_package.serialize_c3_prime()` L343 の `json.dumps(record, ensure_ascii=False, indent=2, sort_keys=True) + "\n"`
     - `c3_contract.canonical_hash()` L71-74 を **import 再利用**（`json.dumps(sort_keys=True, separators=(",",":"))` の sha256 + `sha256:` prefix）
     - `plan_package.PlanPackageError` L35-40 型の **errors リスト保持例外**（`RunEvidenceError(errors)`）。エラーは 1 件目で止めず**全件収集して返す**（`plan_package.build_c3_prime()` L269-300 と同型）
     - `delivery.py` docstring L15-16 の「timestamp は `--now` 注入・`now()` を直接参照しない」
   - 🚩 チェックポイント: 同一入力で **2 回生成して byte 一致**（`cmp -s`）。`harness_version` を run 開始時注入値と終了時で照合し不一致なら fail-closed（AC-12）。`observation`（何が起きたか）と `cause_hypothesis`（なぜ起きたか）が**別フィールド**で、producer は `cause_hypothesis` を**自動生成しない**（推定を観測に混ぜない / AC-5）
4. **Step 4: legacy record 互換層（AC-15）**
   - Output: `scripts/ai-loop/run_evidence.py`（分類関数）/ `test_run_evidence.py`
   - Owner: agent / Risk: 中
   - 転写する具体パターン: `metrics.py` の 4 分類（実測）— `legacy`（`"run" not in record`）/ `invalid run meta`（`_has_valid_run_id()` が False）/ `skipped`（破損 JSON / 非 dict / `decision` 欠落・**理由文字列を必ず記録**、L75-96）/ `run record`。恒等式 `total_records = legacy + invalid + run`（L235-237）で全件がどれかに帰属する構造も転写する
   - 🚩 チェックポイント: **実データ 28 件**（9 キー 25 / 14 キー 3）を入力にして `legacy_count=25` / `run_count=3` / `skipped_count=0` が**再現**すること（`python3 scripts/ai-loop/metrics.py --format json` の現行出力と一致）。RunEvidence が arbiter record を**置き換えない**（既存 28 件を 1 バイトも変更しない）ことを差分ゼロで確認
5. **Step 5: privacy 強制（AC-6）**
   - Output: `scripts/ai-loop/run_evidence.py`（出力フィルタ）/ `test_run_evidence.py`
   - Owner: agent / Risk: **高**（違反が commit されると不可逆）
   - 🚩 チェックポイント: 出力 record に EH-8 の**禁止キー 14 個が 1 つも現れない**（producer 側で機械検査）/ `evidence_refs[]` が **repo 相対パスのみ**（`/` 始まりを reject）/ 保存形式が `.json`（`.jsonl` にしない = EH-8 の走査対象に載せる）/ **10 fixture すべてを `git add` した状態で EH-8 を実走させ PASS を確認**（自主規制でなく hook で証明する）
6. **Step 6: c3-prime-contract §7 追記 + §4 全規則の fail-closed 再検証（AC-14）**
   - Output: `docs/workflows/ai-loop/c3-prime-contract.md`（§7 に #874 consumer 節を **additive 追記**・§6 は触らない）/ `run_evidence.py`
   - Owner: agent / Risk: 中
   - 内容: 読むフィールド（`task_id` / `decision` / `source_sha` / `plan_hash` / `plan_package_hash` — §7 L131 が #873 向けに列挙した 5 つと同一）+ **trust boundary の明示**（§7 L133「decision 値を無検証で信頼してはならない」を #874 にも適用）
   - 実装: producer は `c3prime_verify.main([_, task_dir, expected_sha])` を **呼び出して rc==0 を要求**する（`delivery.verify_c3()` L498-509 が `redirect_stderr` で同じことをしている。**この関数の実装形をそのまま転写し、検証ロジックを再実装しない**）
   - 🚩 チェックポイント: §8（バージョニング）に #874 が既に含まれている（L137 実測「#872 / #873 / #874 の 3 issue 合意」）ことを確認し**重複追記しない** / §6 の LoopSpec 派生表を変更していない（`git diff` で §6 の行数不変）
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
   - 🚩 チェックポイント: adapter が **RunEvidence 以外を読まない**（AC-7「#869 が RunEvidence のみから shadow candidate を生成できる」の構造保証）。`blocked_by[]` 非空 → `BLOCKED` の負側 TC が通ること
8. **Step 8: 10 fixture 実装（AC-16 / AC-9 / AC-10）**
   - Output: `tests/fixtures/run-evidence/`（golden 10 件）/ `scripts/ai-loop/test_run_evidence.py`
   - Owner: agent / Risk: 中
   - 各 fixture の入力 events は **test 内で構築**（`test_delivery.py` / ta-56 / ta-57 の方式。committed するのは golden 出力のみ）。golden と再生成結果を **byte 比較**することで AC-2 の回帰を固定する
   - **実在の一次証跡を 1 件使う**: `docs/working/TASK-0917/evidence/e2e/run/delivery/record.jsonl`（**実測 3 行** = `intent` 1 / `notice` 1 / `receipt` 1。TASK-0917 の実 PR 1 周の実走証跡）を fixture 2（CI repair あり）の**入力形状の一次根拠**として参照する。手書き fixture だけだと実 record との乖離が隠れる（TASK-0917 Risks の「fixture は手書きのため乖離が隠れる」教訓）
     - ⚠️ この record.jsonl には `delivery.assess()` が生成しない `kind=notice` entry が含まれる（`executor.py` 由来・実測）。**producer は未知の `kind` を無視せず `unavailable` 側に倒す**か明示的に受理するかを設計で決める（Step 3 の fail-closed 方針に従い、未知 kind は `escalation` として記録し握り潰さない）
   - 🚩 チェックポイント: fixture 7（partial/tampered）が **`exit 0` を返さない**こと / fixture 8 が **3 件以上の同型 Run** を入力にしていること（issue verbatim「3 件以上」）/ fixture 10 が **failed canary → rollback** の再現であること（DoD の「実走または再現 fixture」の後者を満たす）
9. **Step 9: `ta-58-run-evidence.sh` + 新規 unit test の実行導線（AC-16）**
   - Output: `tests/extras/ta-58-run-evidence.sh`
   - Owner: agent / Risk: 中
   - **新規 ta 番号 = 58**（実測: 既存 `tests/extras/ta-*.sh` は **54 ファイル**・最大番号 **57**。`ta-14` のみ 2 ファイル重複）
   - **登録方法 = ファイルを置くだけ**（実測: `tests/run-tests.sh` L165 相当の `for extra in "$EXTRAS_DIR"/ta-*.sh` が glob source。`tests/extras/README.md` L35「`tests/run-tests.sh` の本体には触れない」）。CI は `.github/workflows/test.yml` の job `plangate CLI tests` が `sh tests/run-tests.sh` を実行するため**自動で乗る**
   - ⚠️ **glob source は `ta-*.sh` を拾うだけで python unit test は起動しない**（TASK-0917 R-020 の教訓）。したがって ta-58 に **`python3 <root>/scripts/ai-loop/test_run_evidence.py` と `test_run_evidence_verify.py` の 2 本**を **1 モジュール 1 PASS 行**で明示追加する（ta-56 L27-32 の形を転写）
   - 規約遵守（`tests/extras/README.md` 実測）: `pass` / `fail` を直接更新 / `trap` を使わない / `register_cleanup` + 末尾明示 `rm -rf` の二重 / 変数は `_t58_` プレフィクス / `rc=0` 初期化してから `out="$(cmd)" || rc=$?`
   - 🚩 チェックポイント: `sh tests/run-tests.sh </dev/null` が exit 0（**stdin を閉じないと `precompact-memory-guard.sh` でハングする**）/ 2 本の PASS 行が出力に現れる（目視でなく grep）
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
12. **Step 12: AC-1〜AC-16 突合**
    - Output: `docs/working/TASK-0874/`（V-1 入力）
    - Owner: agent / Risk: 低
    - 🚩 チェックポイント: `test-cases.md` の全 TC を機械実行して PASS。**AC↔fixture 対応表**（AC-16 が要求）を handoff に残す
13. **Step 13: 👤 C-3 / 👤 C-4**
    - Output: `docs/working/TASK-0874/approvals/c3.json`（Human 発行）
    - Owner: human / Risk: —
    - 🚩 チェックポイント: 下記 Questions / Unknowns の **9 件**を明示判断

## Files / Components to Touch

| # | ファイル | 種別 |
|---|---------|------|
| 1 | `docs/schemas/run-evidence.schema.json` | 新設（JSON Schema 2020-12・非 HO・Phase 1） |
| 2 | `docs/workflows/ai-loop/run-evidence-contract.md` | 新設（契約正本・carve-out ② で保護・plugin へ glob 自動同期） |
| 3 | `scripts/ai-loop/run_evidence.py` | 新設（決定論 producer + adapter IF） |
| 4 | `scripts/ai-loop/test_run_evidence.py` | 新設 |
| 5 | `scripts/ai-loop/run_evidence_verify.py` | 新設（受理器・exit code 0/1/10/11） |
| 6 | `scripts/ai-loop/test_run_evidence_verify.py` | 新設 |
| 7 | `tests/extras/ta-58-run-evidence.sh` | 新設（**新規 ta 番号 = 58**・glob 自動収集） |
| 8 | `tests/fixtures/run-evidence/` | 新設（golden fixture **10 件**・`.json` 固定で EH-8 走査対象） |
| 9 | `docs/workflows/ai-loop/c3-prime-contract.md` | 改変（**§7 に #874 consumer 節を additive 追記のみ**。§6 は不変） |
| 10 | `scripts/sync-plugin-plangate.sh` | 改変（**2 箇所** = for ループ / case 許可判定。各 24 → 28 エントリ） |
| 11 | `plugin/plangate/` | sync 自動再生成 |
| 12 | `docs/working/TASK-0874/` | 本 PBI の作業成果物（plan / todo / test-cases / status / handoff / evidence） |

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
| `docs/schemas/` の CI 検証経路 | **0 本**。`grep -rn 'docs/schemas' scripts/ tests/ .github/` = **5 件**だが全て `scripts/check-orchestrator-docs.sh` 内で、同 script の被参照は **0 件**（`grep -rn 'check-orchestrator-docs' .github/ tests/ bin/ scripts/` の自己参照除外） | — | — | **検証経路を自作する必要がある**根拠（Step 2 / Step 9） |
| 新規 ta 番号 | **58**（既存 `tests/extras/ta-*.sh` = **54 ファイル**・最大番号 **57**） | — | — | 採番の実測根拠 |
| `tests/run-tests.sh` への登録作業 | **不要**（`for extra in "$EXTRAS_DIR"/ta-*.sh` の glob source。`tests/extras/README.md` L35「本体には触れない」） | 1 ファイル改変 | 0 | Files から `tests/run-tests.sh` を除外 |
| `scripts/ai-loop/*.py` | **26 本** | — | — | 新規 4 本追加で 30 本 |
| sync whitelist のエントリ数 | **for ループ 24 / case 24**（`sed -n '348p'` / `'360p'` を実測集計）。**両者一致** | — | — | 新規 4 本を両方へ足して各 28。片方漏れ = drift |
| `docs/workflows/ai-loop/*.md` | **15 本**（新規 1 本で 16） | — | — | sync は glob なので whitelist 追加不要 |
| EH-8 の禁止キー | **14 個**（`scripts/hooks/check-metrics-privacy.sh` L37 を `tr '\|' '\n' \| wc -l` で集計）。走査対象は `*.json` / `*.ndjson` のみ（**`*.jsonl` は素通り**を case glob で実測） | — | — | AC-6 の機械強制点。保存形式を `.json` に固定する根拠 |
| `delivery.py` の状態語彙 | **`STATES` 7 + `EXITS` 2**（`python3 -c "import delivery; ..."`）。`PRIORITY_ORDER` は 15 | — | — | D3 正規化マッピングの根拠（issue の 3 値と一致しない） |
| `c3_contract.VALID_DECISIONS` | **3 値**（`AUTO_APPROVED` / `HUMAN_ESCALATED` / `BLOCKED`）。`ARTIFACTS` 6 / `RECORD_REQUIRED_KEYS` 14 | — | — | 同上 |
| `harness_version` 候補値 | `bin/plangate` L7 = **`0.2.0`** / plugin = **`8.18.0`** / `git describe --tags --abbrev=0` = **`v8.18.0`** | — | — | **値が一致しない**。D4 / U-1 の根拠 |
| `sh tests/run-tests.sh` の baseline | **未取得**（本 plan 生成では実行していない）。件数は環境で変動する（プライマリ+main / プライマリ+トピック / worktree で異なる） | — | — | **固定値を baseline にしない**。exec 開始時に**同一 checkout・同一ブランチ**で 1 回取得し、それを Stop Condition の基準にする（下記 Stop Condition） |

## Testing Strategy

- **Unit**
  - `test_run_evidence.py`: 決定論（同一入力 2 回 → byte 一致）/ 20 フィールドの供給元マッピング / `unavailable` と `0`・空配列の区別 / legacy 4 分類（`metrics.py` 転写）/ privacy フィルタ / adapter IF の橋渡し / 未知 `kind` entry の fail-closed
  - `test_run_evidence_verify.py`: exit code 4 値（0 / 1 / 10 / 11）/ missing / partial / tampered の negative 群 / 未知トップレベルキー reject / `task_dir` 束縛
- **Integration**: `approvals/c3.json` + `delivery/record.jsonl` + arbiter record を fixture 上で合成し、producer → 受理器 → adapter の 1 周を通す。**`c3prime_verify.py` / `delivery.py` は実物を呼ぶ**（再実装しない）
- **E2E**: `tests/extras/ta-58-run-evidence.sh`（10 fixture の golden 再生成 + byte 比較 + 受理器 exit code + EH-8 相当の禁止キー走査）
- **Edge cases**: `record.jsonl` 破損行 / `entry_id` 改竄（`delivery.load_entries()` L465-471 の再計算照合と同型）/ `c3.json` が legacy（`approval_kind` なし → exit 11）/ 非終端 run（`partial`）/ arbiter record 0 件 / `evidence_refs` に絶対パス / `harness_version` の run 中変化
- **Lint（実測した CI 適用範囲）**: `.github/workflows/ci.yml` の markdownlint globs には **`docs/workflows/**/*.md` が含まれる**（`docs/working/**` は**含まれない**）。したがって新設する `run-evidence-contract.md` と `c3-prime-contract.md` の §7 追記は **CI で markdownlint が走る**。ローカル設定は `.markdownlint-cli2.jsonc`（`MD013` / `MD060` 無効・`MD024` は siblings_only）。exec 中に `npx markdownlint-cli2 "docs/workflows/ai-loop/*.md"` で先に潰す
- **Verification Automation**: `python3 scripts/ai-loop/test_run_evidence.py && python3 scripts/ai-loop/test_run_evidence_verify.py && sh tests/run-tests.sh`

## Loop Scope

単一 PBI（TASK-0874）の exec 内における「テスト失敗 → 自己修正」の反復のみ。RunEvidence が記述する **run 収束ループはプロダクト仕様**であり本 plan の Loop ではない。

## Stop Condition

変更が Files / Components to Touch 内 / Verification Automation が全成功（exit 0）/ AC-1〜AC-16 の全 TC が PASS / 敵対レビュー critical・major ゼロ収束 / 残課題は handoff に明示。

> **テスト件数の数え方（TASK-0917 R-020 の教訓の適用）**: `sh tests/run-tests.sh` の PASS 件数は**環境で変動する**（プライマリ checkout / トピックブランチ / worktree で値が違う）。したがって**固定値を baseline に置かない**。exec 開始時（T-2）に **同一 checkout・同一ブランチで 1 回実測**した値を `status.md` に記録し、完了時は「その値 + ta-58 が追加する PASS 行数（**python unit 2 本 + fixture 検証行**）を下回らない」ことを条件にする。「開始時の値を下回らない」だけでは新規 test が 1 本も実行されなくても通るため、**下限は必ず引き上げる**。

## Resume Condition

stop 後の再開は、原因・修正方針・検証手順を本 plan に追記し Replan 判定を通す。producer は決定論なので再開時の副作用は無い（外部作用層を持たない）。

## Replan Triggers

- 変更ファイル数 > **24**（= 想定 19 + 5）
- 同一検証コマンドの連続失敗 3 回 / 同一ファイルへの修正反復 3 回
- **`schemas/` / `bin/plangate` / `.github/workflows/` / `.claude/**` / `scripts/hooks/**` を触る必要が判明した時点で即停止**（いずれも HO 該当。EH-3 の 9 カテゴリ = `check-plan-hash.sh` L125-133）
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
| **`unavailable` を空配列 / 0 で埋めて fail-open**（#868 未実装の `routing_decisions[]` が「routing 無し」と誤読される） | `metrics.py` の 4 分類転写 + 「空配列の明示供給」と「未供給」を区別する負側 TC（`delivery.py` の `findings_unavailable` と同型） | `unavailable` を含む record は受理器 exit **10（partial）**で ready 扱いしない |
| **非終端 run を `MERGE_READY` として発行**（D3 のマッピング誤り） | `record.jsonl` に `kind=merge_ready` entry が**物理的に存在する**ことのみを MERGE_READY の条件にする（`delivery.assess()` L391-400 が刻む唯一の経路）+ 7 状態すべての負側 TC | 判定不能は発行しない（安全側） |
| **`harness_version` の定義が未確定のまま実装が進む** | D4 / U-1 を C-3 の明示判断事項に上げる。AC-12 の TC は「注入値と終了時値の byte 一致」で**意味論と独立に**書く | 定義が決まらない場合は `harness_version` を必須から外し `unavailable` 許容にする（AC-12 は不成立 → C-3 で scope 縮小の判断） |
| **privacy 違反（raw transcript / secret）が commit される**（不可逆） | producer 側の禁止キー 14 個検査 + **10 fixture を staged にして EH-8 を実走**（自主規制でなく hook で証明）+ `evidence_refs` の絶対パス reject | 保存形式を `.json` に固定して EH-8 の走査対象に必ず載せる（`.jsonl` にしない） |
| **`docs/schemas/` に置いた schema が誰にも検証されない**（実測: CI 経路 0 本） | `run_evidence_verify.py` + ta-58 で検証経路を自作。ta-58 は glob で CI job `plangate CLI tests` に自動で乗る | schema と producer の乖離は golden byte 比較で検出 |
| **手書き fixture が実 record と乖離**（TASK-0917 で顕在化した型） | fixture 2 の入力形状を **実在の `docs/working/TASK-0917/evidence/e2e/run/delivery/record.jsonl`（実測 3 行）** に照らして作る。未知 `kind`（`notice`）を握り潰さない TC | 乖離検出時は fixture を実 record 側に寄せる（producer を緩めない） |
| **上流未実装（#811 / #869 / #868）の契約が後で変わる** | adapter IF は**フィールド契約まで**に限定し実接続しない。綴りは issue 本文の実測綴り（`source_run_ids` / `baseline_version`）に合わせる | 変更時は adapter 関数 1 箇所の差し替えで済む構造にする（producer 本体に下流語彙を持ち込まない） |
| **`baseline_harness_version` という存在しない綴りを使ってしまう** | 実測: repo にも issue にも **0 件**。実在するのは `baseline_version`（#869 issue 本文）と `harness_version`（#874）のみ | 橋渡し名を契約 doc に明記し、test で綴りを固定する |
| **AC-13 の fail-closed を issue 番号ハードコードで実装して stale 化** | #862 は既に **CLOSED**・#866 は **OPEN**（実測）。番号ではなく `blocked_by[]` 非空という汎用条件で実装 | 番号参照が必要なら契約 doc 側に列挙し、コードは doc を参照しない（stale 化を doc 更新で解消できる形にする） |
| **sync 2 箇所の片方漏れ**（各 24 エントリ・実測） | 2 箇所の basename 集合を diff して差分 0 を確認する専用タスク（T-32）+ sync 2 回目 no-op | 漏れ検知時は両方へ追加し `git diff --quiet plugin/` を再確認 |
| **fixture 10 件の粒度が大きすぎて実装が膨らむ**（ratio 1.19 だが fixture が実数の過半） | Replan Trigger（> 24 ファイル）+ golden は出力のみ commit（入力は test 内構築）でファイル数を抑える | fixture 8/9/10（下流接続系）を最小 record に縮小する判断を C-3 で相談 |
| **`schemas/` への昇格を将来忘れる** | 裁定（§7）どおり **昇格判定は Gate 接続 PR の Human C-3 チェックリスト**。本 PBI の handoff に「昇格 PBI の予約起票」を V2 候補として明記（裁定 §8-3 が plan 段階の判断事項と指定） | U-6 として C-3 判断に上げる |
| **`sh tests/run-tests.sh` を stdin 開放で実行してハング** | 常に `sh tests/run-tests.sh </dev/null` の形で実行（`precompact-memory-guard.sh` が stdin を待つ） | ハング時は中断して `</dev/null` 付きで再実行 |

## Questions / Unknowns（→ C-3 論点・9 件）

1. **U-1: `harness_version` の定義**（D4）。実測で `bin/plangate` = `0.2.0` / plugin = `8.18.0` / `git describe` = `v8.18.0` と**値が一致しない**。提案は `{plugin_version, cli_version, corpus_hash}` の object だが、単一文字列にするか / どれを正とするかは Human 判断。**pbi L80 の「§6 `derived_loopspec_hash` が供給元」は実測と整合しない**ことの追認も含む
2. **U-2: `replan_count` の供給元**。main に producer が存在しない（実測）。`plan.md` の Loop Attempts 追記回数を数えるのか / `record.jsonl` に新 entry kind を足すのか（後者は `delivery.py` 改変 = Out of scope 抵触）/ 本 PBI では `unavailable` 固定にするのか
3. **U-3: `cost_metrics{}` の供給元**。`docs/working/_metrics/events.ndjson` は `.gitignore` L53 で除外されており（実測）、RunEvidence が commit される artifact である以上そのまま埋められない。privacy §3 は token 数 / `model_id` を Allowed とするため**集計値なら可**だが、収集経路が無い。`unavailable` 固定でよいか
4. **U-4: 非終端 run の扱い**（D3）。「RunEvidence を発行しない」（安全側・plan 既定）か「4 値目 `IN_PROGRESS` を作る」か。前者だと `EXEC_RETURN` で終わった run の証跡が残らず、#869 の学習源が失われる可能性がある
5. **U-5: `repository` フィールドと privacy §4 の関係**。issue の 20 フィールドに `repository` が含まれるが、`metrics-privacy.md` §4 は「プロジェクト固有名・社名・人名 → 完全除外」とする。EH-8 の禁止キー 14 個には含まれないため機械的には通る（実測）が、**規範として `s977043/plangate` を record に書いてよいか**は Human 判断
6. **U-6: `schemas/` 昇格 PBI の予約起票**。裁定 §8-3 が「段階方式の場合、昇格 PBI（HO patch）を #870 の後続タスクとして予約起票するかを **plan 段階で判断**」と指定している。本 plan では起票していない（起票は C-3 後の判断とした）。**起票するか / いつか**
7. **U-7: schema / fixture の plugin 配布**。`sync-plugin-plangate.sh` の同期先は `skills/ai-loop-cycle/references` と `.../scripts` のみ（実測）で、`docs/schemas/` も `tests/fixtures/` も**対象外**。下流リポジトリが RunEvidence を生成する必要があるなら配布設計が要るが、Phase 1（shadow・dogfooding 域）では不要とも言える
8. **U-8: adapter IF の最小フィールド**（pbi L106 の未決事項）。`source_run_ids` / `baseline_version` 以外に何を必須にするか。#869 の候補契約は 20 フィールド、#811 の Trust Ledger は 12 フィールドあり（実測）、**どこまでを #874 が供給し、どこからを下流が埋めるか**の境界が未確定
9. **U-9: fixture 9（paired replay）/ 10（canary rollback）の実質**。実測で **canary の機械契約は ai-loop 正本に存在しない**（`docs/workflows/ai-loop/` の 15 本に canary の定義なし。`stop-rollback.md` に `rollback_action` enum 5 値があるのみ）。#869 の `canary_plan` / #811 の `canary_scope` はいずれも未実装。したがって fixture 9/10 は「**#874 が定義した最小の形**」になり、下流が別定義を採ると乖離する。この乖離を許容するか、#869/#811 の plan 確定まで fixture 9/10 を Deferred にするか

## Mode判定

**モード**: **critical**

**判定根拠**（`.claude/rules/mode-classification.md` の定量・定性の**最大値**を採用）:

- **受入基準数: 16 件**（issue verbatim **13** + In scope 対応 **3**（AC-14 / AC-15 / AC-16）= 16）→ **超高（11+）が決定論的に確定**
- **変更ファイル数: 19**（手作業。`plugin/` 自動生成と `docs/working/TASK-0874/` を除く実数。内訳 = 新設 7 + fixture 10 + 改変 2）→ **超高（16+）**
- タスク数（見込み）: **38**（`todo.md` 実数。T-1〜T-38・欠番なし）→ **超高（21+）**
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

**HO 該当性**: **非該当**（実測）。`scripts/hooks/check-plan-hash.sh` L125-133 の 9 カテゴリに対し、`docs/schemas/*.json` / `scripts/ai-loop/*.py` / `tests/extras/*.sh` / `tests/fixtures/**` / `docs/workflows/ai-loop/*.md` / `scripts/sync-plugin-plangate.sh` / `plugin/**` はいずれもマッチしない（`schemas/*.schema.json` は先頭が `schemas/` である必要があり `docs/schemas/` は不一致）。**`schemas/` 直下を触る必要が生じた時点で HO 該当 → 即停止**（Replan Trigger）。

**carve-out**: 本 PBI の成果物は **rollout-policy §2 判定基盤 carve-out ①（`scripts/ai-loop/**`）②（`docs/workflows/ai-loop/**`）に該当**するため、**ai-loop で自走させる場合は escalate 固定**（auto-approve 対象になり得ない）。#916 の機械強制が入るまでは規範層（実行者が escalate する責務）で担保する。なお `docs/schemas/**` は carve-out の glob **①②③のいずれにも含まれない**（実測）ため、schema だけが carve-out 外になる — この非対称は契約 doc に明記する（Step 1）。

## AC ↔ Step ↔ test-case 対応表（16 件・全数）

| AC | 内容（要約） | Step | test-case |
|----|-------------|------|-----------|
| AC-1 | RunEvidence schema と versioning policy がある | Step 1 | TC-01 〜 TC-05 |
| AC-2 | 同一入力 events から同一 RunEvidence を再生成できる | Step 3 | TC-10 〜 TC-12 |
| AC-3 | Plan hash / C-3' / final head SHA / CI / review / routing / terminal state が同一 run へ結合 | Step 3 | TC-13 〜 TC-16 |
| AC-4 | missing / partial / tampered を ready 扱いしない | Step 2 | TC-06 〜 TC-09、TC-32 |
| AC-5 | observation と cause hypothesis が分離される | Step 1・Step 3 | TC-17、TC-18 |
| AC-6 | hidden CoT / raw transcript / secret を要求・保存しない | Step 5 | TC-19 〜 TC-22 |
| AC-7 | #869 が RunEvidence のみから shadow candidate を生成できる | Step 7・Step 8 | TC-23、TC-24、TC-33 |
| AC-8 | candidate が `source_run_ids` と baseline harness version を保持 | Step 7 | TC-25、TC-26 |
| AC-9 | improvement TASK が通常の Plan-first / C-3' / PR 収束を通る | Step 8 | TC-27 |
| AC-10 | paired replay / 独立 grader / activation check / rollback を source candidate へ戻せる | Step 8 | TC-34、TC-35 |
| AC-11 | #811 promotion decision と改善 PR/commit を追跡できる | Step 7 | TC-28、TC-29 |
| AC-12 | active run の harness version が途中で変化しない | Step 3 | TC-30、TC-31 |
| AC-13 | 未解決の正本へ自動 promotion しない fail-closed 条件がある | Step 7 | TC-36、TC-37 |
| AC-14 | c3-prime-contract §7 に #874 consumer が追記され §4 全規則を fail-closed 再検証 | Step 6 | TC-38 〜 TC-41 |
| AC-15 | legacy 9 キー / run メタ 14 キー record との関係が機械検証可能 | Step 4 | TC-42 〜 TC-45 |
| AC-16 | 10 fixture が `tests/extras/ta-58` で CI 実行され AC↔fixture 対応表が残る | Step 8・Step 9 | TC-46 〜 TC-49、および fixture 対応表（test-cases.md 末尾） |

> **fixture ↔ AC 対応表**は `test-cases.md` の `## 必須 fixture（10 件）↔ AC 対応表` に置く（AC-16 が要求する成果物）。
