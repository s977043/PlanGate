# Delivery State Machine（正本 / TASK-0873・#873）

> **Status**: v1（TASK-0873 で確定）
> 位置づけ: `PR_CREATED → MERGE_READY` 間の**内部サブステート**と遷移規則・record 契約の正本。
> 実装: [`scripts/ai-loop/delivery.py`](../../../scripts/ai-loop/delivery.py)（決定論・fail-closed・冪等の判定エンジン）
> 関連正本: [`00_concept.md`](./00_concept.md) §2.2（Delivery 3 状態 — **不変**）/ [`execution-runbook.md`](./execution-runbook.md) §2-(7) Scheduling 判断表（**不変**）/ [`c3-prime-contract.md`](./c3-prime-contract.md) §7（読み取りフィールド + trust boundary）

## 1. 既存正本との関係（additive・再定義しない）

- 00_concept §2.2 の Delivery 3 状態（`PR_CREATED` / `MERGE_READY` / `MERGED`)は**不変**。本正本はその `PR_CREATED → MERGE_READY` 区間を機械実装するための**内部サブステート**を additive に定義する
- **`HUMAN_ESCALATED` は裁定語彙（decision-table 3 値）の借用であり、Delivery terminal（§2.2 の 3 状態）ではない**。本状態機械では「run を人間へ返す exit」として扱い、§2.3 の語彙群区別（同列の terminal state として列挙しない）を維持する。round limit exceeded も §2.3 どおり「`HUMAN_ESCALATED` への遷移理由」であり独立 state ではない
- `MERGED` への遷移は**存在しない**（NO MERGE BY AI）。`MERGE_READY` が本状態機械の唯一の正常終端で、以降は C-4（Human merge）待ち

## 2. サブステートと exit

| 種別 | 名前 | 意味 |
|------|------|------|
| 中間 | `WAITING_FOR_CHECKS` | 最新 head SHA の CI が pending / stale |
| 中間 | `WAITING_FOR_REVIEW` | CI green・required review が最新 head で未着弾 |
| 中間 | `CHECKS_FAILED` | 最新 head の CI failure（taxonomy 分類済み）→ repair 要求 |
| 中間 | `REVIEW_REPAIR` | 未解決の review finding あり → 修正 or evidence 付き不採用の要求 |
| 中間 | `CONFLICT` | mergeable=CONFLICTING → 解消 + 三点照合の要求 |
| 中間 | `MERGE_READY_CANDIDATE` | minor/info のみ・disposition 記録済み・**DoD 未判定**（非終端。直接 `MERGE_READY` に短絡しない） |
| 終端 | `MERGE_READY` | DoD 充足（§5）。C-4 待ちで停止 |
| exit | `HUMAN_ESCALATED` | 人間へ返す（理由 record 付き。裁定語彙の借用 — §1） |
| exit | `EXEC_RETURN` | Plan 逸脱 → exec 差し戻し / C-3' 再裁定（AC-6） |

## 3. Scheduling 判断表（優先度 1〜8）との正規化マッピング

判定は以下の優先度順（上が勝つ）。runbook §2-(7) の 8 行を全行カバーする。

**`assess` は stateless（各回 snapshot + record 履歴駆動で前状態に依存しない）**。本表は「どの入力でどの状態に入るか」の意味論を定める。§8 の `transitions`（到達可能性グラフ）は「非終端状態からは次回 assess で任意の状態・exit へ到達し得る（唯一の不変量 = `MERGE_READY` は終端）」を表し、両者は役割が異なる（前者 = 入力→状態、後者 = 状態→到達可能状態集合）。

| 優先度 | 条件 | 次サブステート / exit | 要求アクション |
|--------|------|---------------------|---------------|
| 0a | snapshot 構造不正（必須キー欠落・型不一致・空） | （判定不能 = エラー終了。対象キー名を明示） | — |
| 0b | Plan 逸脱（changed_files ⊄ allowed_paths） | `EXEC_RETURN` | —（逸脱パスを reasons / state entry に列挙・intent なし） |
| 1 | escalation_flags 非空（touches-HO / policy 変更 / irreversible） | `HUMAN_ESCALATED` | —（理由を reasons / state entry に記録・intent なし） |
| 1' | `source_sha_ancestry` が true 以外（検証不能/不成立 — fail-closed） | `HUMAN_ESCALATED` | 同上 |
| 2 | repair round が 4 に達する（上限 3 超過） | `HUMAN_ESCALATED` | 同上 |
| 3 | 同型指摘の再発（finding_type が過去 disposition と一致） | `REVIEW_REPAIR` | `feedback_loop_referral`（review-feedback-loop.md への還元要求）+ `repair_review`。recurse は独立 state にしない |
| 4 | 最新 head の CI failed（taxonomy = code/flaky/environment） | `CHECKS_FAILED` | `repair_ci` |
| 4' | taxonomy = permission/unknown/分類不能（AC-9） | `HUMAN_ESCALATED` | —（成功扱いにしない・intent なし） |
| 5 | mergeable = CONFLICTING | `CONFLICT` | `resolve_conflict`（base/head/result 三点照合フィールド必須。欠落は解消と認めない） |
| 6 | 未解決の critical/major finding あり | `REVIEW_REPAIR` | finding ごとの `repair_review` |
| 6' | 未解決の minor/info finding あり（fail-closed 拡張） | `REVIEW_REPAIR` | finding ごとの `record_disposition`（採用/不採用理由の記録要求） |
| — | CI pending / 最新 head の checks なし（stale 含む） | `WAITING_FOR_CHECKS` | —（待機・intent なし） |
| — | required review が最新 head で未着弾 | `WAITING_FOR_REVIEW` | —（待機・intent なし） |
| 7 | minor/info のみ・全 disposition 記録済み・DoD 未判定 | `MERGE_READY_CANDIDATE` | `dod_reevaluate`（DoD 判定へ進む。終端に短絡しない） |
| 8 | DoD 充足（§5）= CI green + review 全件対応 + DoD 判定済み | `MERGE_READY` | `merge_ready` record を刻む（§6） |

## 4. snapshot 契約（入力・信頼境界）

delivery.py は PR 状態を **snapshot JSON** として受け取る判定エンジンであり、ネットワーク・外部プロセス実行を持たない（純判定器契約）。

**信頼境界（Phase 1）**: snapshot は信頼済みローカル呼び出し側（runbook 手順の実行者 / ta-56 sandbox）が供給する。c3-prime-contract §4 の脅威モデル境界と同型で、悪意ある snapshot 供給者は Phase 1 の scope 外（raw check evidence への束縛は V2 候補）。ただし**独立検証不能な値は常に fail-closed**: 未知 taxonomy → `HUMAN_ESCALATED` / ancestry 根拠欠落（`source_sha_ancestry` が true 以外）→ `HUMAN_ESCALATED` / checks と head の SHA 不整合 → stale として `WAITING_FOR_CHECKS`（成功扱いにしない）。

主要フィールド（詳細は `delivery.py contract` の emit と test-cases が契約）:
`task_id` / `pr_number` / `head_sha` / `source_sha_ancestry`（head が c3-prime `source_sha` の子孫か。供給値・sandbox では git 実測）/ `mergeable` / `checks[]`（`name`/`sha`/`conclusion`）/ `review`（`state`/`sha`）/ `ci_failure_taxonomy` / `findings[]`（`id`/`finding_type`/`severity`/`disposition`）/ `changed_files[]` / `allowed_paths[]` / `escalation_flags[]` / `conflict_resolution`（`base_sha`/`head_sha`/`result_sha`）/ `dod_evaluated`

## 5. DoD（MERGE_READY 到達条件）

runbook §2-(7)-6 と同一（再定義しない）: **最新 head SHA の CI 全 job green かつ AI レビュー指摘ゼロまたは全件対応完了（採用 = repair commit / 不採用 = 実測 evidence_ref の記録あり）**。加えて機械判定として: `source_sha_ancestry == true` / conflict なし / `dod_evaluated == true`（優先度 7 → 8 の 2 段階を強制）。

**disposition の内容真正性は C-4 の責務（R2 B2-11・責務分界）**: delivery.py は「各 finding に `adopted(repair_commit)` または `rejected(evidence_ref)` の**記録が存在すること**」を機械保証するが、`evidence_ref` が指す不採用根拠の**内容の妥当性**（実測ログが本当に false positive を示すか）は検証しない（snapshot 入力のみで内容実在を確認できないため）。この最終確認は **C-4（Human merge レビュー）** が担う。`MERGE_READY` は「機械ゲートを全通過し人間の最終判断に載せてよい」状態であって「merge してよい」ではない（NO MERGE BY AI）。全 disposition は MERGE_READY record の `review_disposition` に残り C-4 で追跡可能。Phase 1 trust boundary（信頼済みローカル供給）下でこの分界を採り、evidence 内容の機械検証は V2 候補。

## 6. record 契約（`docs/working/TASK-XXXX/delivery/record.jsonl`）

append-only の JSONL。**delivery.py が自己 append する**のは既存 ai-loop scripts（stdout emit）からの意図的逸脱 — 冪等判定が既存 record 読取を要するため（decision-log.jsonl の append-only 前例と整合）。

- **entry 種別**: `intent`（アクション要求）/ `receipt`（外部作用の完了記録）/ `state`（遷移記録）/ `merge_ready`（終端 record）
- **stable action ID**: `action_id = sha256(canonical action payload)`。payload は `pr_number` / `head_sha` / `round` / `action_kind` / `finding_id`（該当時）等を含む正規化 JSON（`json.dumps(sort_keys, separators)`）。同一 head/round でも finding が異なれば別 ID（誤抑止しない）
- **intent / receipt の 2 段書き込み**: 実行主体（runbook 手順 / sandbox スタブ）はアクション実行後に `delivery.py receipt` で完了を記録する。resume 時: 「intent あり・receipt なし」= 未完了として**再要求**（実行ゼロ回に終わらない）/ 「receipt あり」= 実行済みとして**抑止**（二重実行しない）— 外部作用の前後どちらの中断でも一度だけ実行に収束
- **冪等 append**: 各 entry は `entry_id = sha256(canonical entry〔timestamp 除外〕)` を持ち、既存 entry_id は再 append しない（同一 snapshot での再 assess は record 差分ゼロ）
- **timestamp は注入**（`--now` 引数必須。`datetime.now()` 直参照禁止 — 決定論）
- **raw log 本文を含めない**: check summary は `name → conclusion` の対応のみ。ログ・診断本文は `evidence_ref` 参照のみ（`.jsonl` は EH-8 走査対象外のため契約側で禁止）
- **round**: repair 系 receipt の最大 round + 1 を次 repair round とする。round 4 に達する要求は発行せず `HUMAN_ESCALATED`

### MERGE_READY record（AC-11 の 6 フィールド）

`pr_number` / `head_sha` / `check_summary`（name→conclusion のみ）/ `review_disposition`（finding_id→disposition）/ `round` / `plan_hash`（c3-prime record の値）

## 7. c3-prime 入口検証（trust boundary / 契約 §7）

`delivery.py assess` は入口で `c3prime_verify.main([_, task_dir, expected_sha?])` を import 実行し再検証する（decision を無検証で信頼しない）:

- exit 1（検証 NG）→ BLOCK / exit 0 以外の decision 系 NG も BLOCK
- **exit 10（legacy c3.json）→ BLOCK**（ai-loop Delivery は c3-prime 必須。legacy は ai-dev 経路）
- 失敗理由は stderr 捕捉（`contextlib.redirect_stderr`）で診断出力に含める（record には evidence_ref 経由）

## 8. 機械可読契約（contract emit）

状態集合・遷移は `delivery.py` 内 `TRANSITIONS` が単一定義で、`python3 scripts/ai-loop/delivery.py contract` が決定論 JSON を emit する。以下のブロックは emit と**byte 一致**であることを ta-56 が機械検証する（doc drift の CI 検出）:

<!-- contract:begin -->
```json
{
  "exits": [
    "EXEC_RETURN",
    "HUMAN_ESCALATED"
  ],
  "priority_order": [
    "invalid_snapshot",
    "plan_deviation",
    "escalation_flags",
    "ancestry_fail",
    "round_limit",
    "same_type_recurrence",
    "ci_failed",
    "conflict",
    "review_findings",
    "waiting_checks",
    "waiting_review",
    "merge_ready_candidate",
    "merge_ready"
  ],
  "states": [
    "CHECKS_FAILED",
    "CONFLICT",
    "MERGE_READY",
    "MERGE_READY_CANDIDATE",
    "REVIEW_REPAIR",
    "WAITING_FOR_CHECKS",
    "WAITING_FOR_REVIEW"
  ],
  "terminal": "MERGE_READY",
  "transitions": {
    "CHECKS_FAILED": [
      "CHECKS_FAILED",
      "CONFLICT",
      "EXEC_RETURN",
      "HUMAN_ESCALATED",
      "MERGE_READY",
      "MERGE_READY_CANDIDATE",
      "REVIEW_REPAIR",
      "WAITING_FOR_CHECKS",
      "WAITING_FOR_REVIEW"
    ],
    "CONFLICT": [
      "CHECKS_FAILED",
      "CONFLICT",
      "EXEC_RETURN",
      "HUMAN_ESCALATED",
      "MERGE_READY",
      "MERGE_READY_CANDIDATE",
      "REVIEW_REPAIR",
      "WAITING_FOR_CHECKS",
      "WAITING_FOR_REVIEW"
    ],
    "MERGE_READY": [],
    "MERGE_READY_CANDIDATE": [
      "CHECKS_FAILED",
      "CONFLICT",
      "EXEC_RETURN",
      "HUMAN_ESCALATED",
      "MERGE_READY",
      "MERGE_READY_CANDIDATE",
      "REVIEW_REPAIR",
      "WAITING_FOR_CHECKS",
      "WAITING_FOR_REVIEW"
    ],
    "REVIEW_REPAIR": [
      "CHECKS_FAILED",
      "CONFLICT",
      "EXEC_RETURN",
      "HUMAN_ESCALATED",
      "MERGE_READY",
      "MERGE_READY_CANDIDATE",
      "REVIEW_REPAIR",
      "WAITING_FOR_CHECKS",
      "WAITING_FOR_REVIEW"
    ],
    "WAITING_FOR_CHECKS": [
      "CHECKS_FAILED",
      "CONFLICT",
      "EXEC_RETURN",
      "HUMAN_ESCALATED",
      "MERGE_READY",
      "MERGE_READY_CANDIDATE",
      "REVIEW_REPAIR",
      "WAITING_FOR_CHECKS",
      "WAITING_FOR_REVIEW"
    ],
    "WAITING_FOR_REVIEW": [
      "CHECKS_FAILED",
      "CONFLICT",
      "EXEC_RETURN",
      "HUMAN_ESCALATED",
      "MERGE_READY",
      "MERGE_READY_CANDIDATE",
      "REVIEW_REPAIR",
      "WAITING_FOR_CHECKS",
      "WAITING_FOR_REVIEW"
    ]
  }
}
```
<!-- contract:end -->

`MERGED` は states / transitions のどこにも現れない（AC-12。ta-56 のソース走査と二重ガード）。
