# HANDOFF — TASK-0874（RunEvidence 契約 / issue #874）

> **Status**: exec 後半まで完了（T-1 〜 T-36）。**T-37 〜 T-44 は未了**のため本 handoff は
> **中間版**である。PR 作成前に T-37（plugin 同期）と T-38 / T-39（敵対レビュー）を通すこと。

## 1. 要件適合確認結果（AC ごと）

| AC | 内容 | 判定 | 根拠 |
|----|------|------|------|
| AC-1 | RunEvidence schema と versioning policy | **PASS** | `docs/schemas/run-evidence.schema.json`（draft 2020-12・`required` 21）+ 契約 §9。TC-01 〜 TC-05 / TC-61 / TC-62 |
| AC-2 | 同一入力から同一 EV を再生成できる | **PASS** | TC-10 / TC-11 / TC-12 / TC-60。fixture 10 件の byte 一致（TC-48） |
| AC-3 | plan hash / C-3' / head SHA / CI / review / routing / terminal state の結合 | **PASS** | TC-13 〜 TC-16 / TC-50 / TC-57 〜 TC-59 / TC-64 |
| AC-4 | missing / partial / tampered を ready 扱いしない | **PASS** | 受理器 exit 0/1/10/11。TC-06 〜 TC-09 / TC-32 / TC-52 / TC-53 / TC-56 |
| AC-5 | observation と cause_hypothesis の分離 | **PASS** | TC-17 / TC-18（producer は推定を自動生成しない） |
| AC-6 | hidden CoT / raw transcript / secret を要求も保存もしない | **PASS** | TC-19 〜 TC-21 / TC-51 / TC-63 / TC-65 + EH-8 実走（TC-22） |
| AC-7 | #869 が RunEvidence のみから candidate を生成できる | **PASS（契約層のみ）** | TC-23 / TC-24 / TC-33。**実フロー検証は #869 実装後** |
| AC-8 | candidate が source_run_ids と baseline version を保持 | **PASS** | TC-25 / TC-26 |
| AC-9 | improvement TASK が通常ゲートを通る | **PASS（記述子レベル）** | TC-27。実フローは #869 実装後 |
| AC-10 | paired replay / grader / activation check / rollback | **PASS（キー存在レベル）** | TC-34 / TC-35。独立 grader も activation check も本 PBI では実装しない |
| AC-11 | promotion decision と改善 PR/commit の追跡 | **PASS** | TC-28 / TC-29（PR 番号 + commit SHA へ還元し双方向に辿れる） |
| AC-12 | active run 中に harness version が変化しない | **PASS** | TC-30 / TC-31（3 値すべての drift で fail-closed） |
| AC-13 | 未解決の正本へ自動 promotion しない fail-closed | **PASS** | TC-36 / TC-37 / TC-55（キー未注入も BLOCKED） |
| AC-14 | c3-prime-contract §7 追記 + §4 全規則の再検証 | **PASS** | TC-38 〜 TC-41。§7 以外の節が不変であることを機械照合 |
| AC-15 | legacy record の migration / compatibility | **PASS** | TC-42 〜 TC-45 / TC-54（実データ 28 件で `metrics.py` と同値） |
| AC-16 | 10 fixture が ta-60 で CI 実行され対応表が残る | **PASS** | TC-46 〜 TC-49 + 下記 §5 の対応表 |

> ⚠️ **本 PBI の完了は issue #874 の close 条件充足を意味しない**。#874 の DoD は
> 「#869 shadow mode の統合 test」「#811 promotion provenance test」「効果測定」を要求しており、
> いずれも未実装。**#874 は OPEN のまま残す**（T-42 のコメント文面要件）。

## 2. 既知課題一覧

| # | 課題 | 影響 | 対応 |
|---|------|------|------|
| K-1 | **T-37（plugin 同期）が未実施** | CI `sync-plugin-plangate.yml` が PR 段階で drift を検出して FAIL する | PR 作成前に `sh scripts/sync-plugin-plangate.sh` を 1 回実行し `plugin/` を commit |
| K-2 | **T-38 / T-39（敵対レビュー R1 / R2）が未実施** | critical のため PR 前に必須 | 複数エージェントで実施し `evidence/` に格納 |
| K-3 | fixture 6（routing escalation）は Phase 1 で fixture 4 と**区別不能** | routing の実カバレッジ 0（実質 9 fixture） | #868 実装後に item schema を注入して差分を作る |
| K-4 | golden fixture は `test_plan_package.py` の sandbox 生成物に依存 | 同ファイルの `PLAN_BODY` を変えると 10 件すべてが byte 不一致になる | `regenerate_fixtures()` で再生成し commit（TC-48 が検出する） |
| K-5 | `--pr-number` は cross-check 専用に降格 | plan の記述（PR 番号の解決経路）と食い違う | 契約 §3-2 に確定として明記済み。受理器の再計算可能性が制約 |
| K-6 | `tests/fixtures/` は privacy CI の scan 対象外 | golden fixture の privacy 回帰を CI が自動検出しない | `ta-60` ④ で EH-8 を実走させて代替（本 PBI で解消済み） |
| K-7 | `sh tests/run-tests.sh` は `ta-54` 経由で**実 repo root に対し sync を実行する** | テスト実行が `plugin/` を一時的に書き換える | 本 PBI の範囲外。テスト実行後は `git status` で `plugin/` を確認すること |
| K-8 | `jsonschema` 依存の fixture 検証 1 件は未導入環境で skip する | CI で skip される可能性 | 65 TC には含まれない追加検証。必要なら CI に依存を追加 |

## 3. V2 候補（今回の scope 外）

- `harness_version` の**構造**を検証する TC（現状は注入値の byte 一致のみ・U-1 の帰結）
- `cost_metrics` の収集経路（`events.ndjson` が gitignore のため Phase 1 では取得不能）
- `replan_count` の供給元（main に存在しない）
- `routing_decisions[]` の item schema（#868 実装後）
- schema / fixture の plugin 配布（U-7 で Phase 1 は配布しない）
- U-10 が known-unavailable allowlist 採用に転じた場合の fixture 期待 exit の差し戻し（11 → 0）
- `docs/schemas/run-evidence.schema.json` → `schemas/` への昇格（HO patch・T-44 で予約起票）

## 4. 妥協点（採用しなかった選択肢と理由）

| 論点 | 採用 | 不採用の選択肢と理由 |
|------|------|-------------------|
| `--pr-number` の扱い | record 由来の PR とだけ照合する cross-check | **注入値で `repair_rounds` を実値化**: 受理器が再計算照合できず、生成側の自己申告を信頼する構造になる |
| `BLOCKED` の delivery 層 4 フィールド | `unavailable` | **ダミー sha / 0 で埋める**: EV に自己 hash が無いため tampered 検出も効かない。**reject する**: BLOCKED run の証跡が一切残らない |
| `quality_metrics` が導出不能なとき | 全体を `"unavailable"` | **`{"first_pass": false, "rounds": 0}`**: `unavailable` を 0 で埋める fail-open |
| `decision != AUTO_APPROVED` の c3-prime | 束縛は producer 側で再検証し `decision` 値のみ供給元扱い | **rc==0 を文字どおり要求**: `BLOCKED` / `HUMAN_ESCALATED` の EV が構造的に発行できない |
| 絶対パス / URL / @handle を含む入力 | 還元 + `escalation` 記録 | **fail-closed で EV を発行しない**: 実 record（`comment_url` を持つ）で常に発行不能になる |
| `metrics.py` の 4 分類 | 導出規則を転写 | **import**: 不変対象への依存を増やす |
| `OUTPUT_KEYS` | producer に列挙し TC-62 で schema と束縛 | **schema から導出**: 入力ソース allowlist に schema ファイルが増える |

## 5. AC ↔ fixture 対応表（AC-16 の要求成果物）

| # | fixture | 主に検証する AC | `terminal_state` | 受理器 exit | `unavailable` 件数 |
|---|---------|----------------|-----------------|------------|------------------|
| 1 | `fx-01-first-pass.json` | AC-2 / AC-3 / AC-12 | `MERGE_READY` | 11 | 3 |
| 2 | `fx-02-ci-repair.json` | AC-3（`ci_outcomes` / `repair_rounds`） | `MERGE_READY` | 11 | 3 |
| 3 | `fx-03-review-repair.json` | AC-3（`review_findings`） | `MERGE_READY` | 11 | 3 |
| 4 | `fx-04-human-escalated.json` | AC-3 / AC-14 | `HUMAN_ESCALATED` | 11 | 7 |
| 5 | `fx-05-blocked.json` | AC-3 / TC-58 | `BLOCKED` | 11 | **8**（(a)3 + (b)5） |
| 6 | `fx-06-routing-escalation.json` | AC-3（routing）⚠️ Phase 1 は fixture 4 と区別不能 | `HUMAN_ESCALATED` | 11 | 7 |
| 7 | `fx-07-tampered-expected-errors.json` | AC-4（期待エラー列。受理された record ではない） | — | ケースごとに 1 / 1 / 11 | — |
| 8 | `fx-08-shadow-candidate-input.json` | AC-7 / AC-8 | — | — | — |
| 9 | `fx-09-paired-replay.json` | AC-10 | — | — | — |
| 10 | `fx-10-canary-rollback.json` | AC-10 / AC-11 / AC-13 | — | — | — |

> **一次証跡で裏が取れる範囲 / 手書きに留まる範囲**（C-2 レーン B 返送論点 4）:
> fixture 2 の entry 共通キー形状（`action_id` / `action_kind` / `at` / `entry_id` / `kind`）・
> `pr_number` / `round` の型・`repair_ci` の `taxonomy` / `failed_checks` / `head_sha`・
> `comment_url` は実在の `docs/working/TASK-0917/evidence/e2e/run/delivery/record.jsonl` に照らした。
> **`kind=state` / `kind=merge_ready` / `record.check_summary` / `record.review_disposition` /
> `record.plan_hash` は実 record に存在せず手書きに留まる**。

## 6. テスト結果サマリ

| コマンド | 結果 |
|---------|------|
| `python3 scripts/ai-loop/test_run_evidence.py` | **78 tests / OK（exit 0）** |
| `python3 scripts/ai-loop/test_run_evidence_verify.py` | **30 tests / OK（exit 0）** |
| `sh tests/run-tests.sh </dev/null` | **523 passed / 0 failed（exit 0）**・baseline 513 |
| `sh tests/extras/ta-60-run-evidence.sh </dev/null` | **pass=9 / fail=0** |
| `python3 scripts/ai-loop/check_exec_boundary.py` | **clean（30 ファイル / 違反 0）** |
| `PLANGATE_HOOK_STRICT=1 PLANGATE_HOOK_FILES="<10 fixture>" sh scripts/hooks/check-metrics-privacy.sh` | **PASS（10 files checked）** |
| `npx markdownlint-cli2 <変更 md>` | **0 issues** |
| 不変 7 ファイル + `ai-loop-runs/` + `tests/run-tests.sh` の `git diff --stat origin/main` | **0 行** |

**変異注入 29 件**（M1 〜 M29）で新規テストの検出力を実証した。**2 件（M17 / M21）が当初 survive**
したため、入力側 reject の識別と出力側 backstop の単体検査を追加して kill した。
一覧は `todo.md` の「T-12 〜 T-36 完了記録」を参照。

## 7. 引き継ぎ文書（5 分で状況把握）

`#874` は **1 回の ai-loop run が終端に達したときに発行する run 単位の証跡（RunEvidence）**の
契約層を作る PBI である。本 exec で以下が揃った。

- **契約正本** `docs/workflows/ai-loop/run-evidence-contract.md` と **schema**（`required` 21）
- **決定論 producer** `scripts/ai-loop/run_evidence.py`（時刻を内部参照せず・ネットワーク / 外部
  プロセスを呼ばず・入力は `task_dir` と `runs_dir` に閉じる）
- **受理器** `scripts/ai-loop/run_evidence_verify.py`（exit 0 / 1 / 10 / 11。`10` の意味は
  姉妹受理器 `c3prime_verify.py` と同一）
- **golden fixture 10 件** と **`tests/extras/ta-60-run-evidence.sh`**（CI 導線 + EH-8 実走）

設計の要は 3 つ。
①**`unavailable` を 0 や空配列で埋めない**（Phase 1 の producer 出力は必ず partial = exit 11）。
②**`MERGE_READY` は `kind=merge_ready` entry の物理存在のみを条件にする**（`MERGE_READY_CANDIDATE`
を丸めない）。
③**生成側の申告を信頼しない**（受理器が `approvals/c3.json` と `delivery/record.jsonl` を
再読込して再計算照合する）。

**次の担当者が最初にやること**は K-1（plugin 同期）と K-2（敵対レビュー）。
その後 T-40 〜 T-44（65 TC 対応表・issue コメント・予約起票）へ進む。
