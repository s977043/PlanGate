# PBI INPUT PACKAGE — TASK-0874

> Issue: [#874](https://github.com/s977043/plangate/issues/874)（P1 / enhancement / area:workflow / area:eval / area:metrics）
> Parent EPIC: [#870](https://github.com/s977043/plangate/issues/870)
> 作成: 2026-07-20（調査・main 裏取り済み。AC/fixture は issue verbatim）

## Context / Why

issue #872（Plan-first + c3-prime 束縛）が 4 PR merge 済みで、c3-prime 契約（`docs/workflows/ai-loop/c3-prime-contract.md`）が確定した。#874 はその Delivery evidence を統一 **RunEvidence 契約**にまとめ、外側の Evolution Loop（#869）と Promotion Gate（#811）へ接続する。EPIC #870 の順序は `#872 → #873 → #874 → #870 E2E`。

実測（2026-07-20・main）:

- **RunEvidence は未実装**: `rg "run_evidence|RunEvidence|harness_version" scripts/` は 0 件（設計文書側のみ）。producer / validator / schema いずれも未着手
- 近縁は arbiter 裁定 record（`docs/working/ai-loop-runs/*.json` **28 件**・実測）だが、issue 定義の 20 フィールド RunEvidence とは**別物**（共通は `target_sha`/`decision`/run メタ程度）
- **record の世代分裂が残存**: legacy 9 キー（25 件）/ run メタ付き 14 キー（3 件）。`metrics.py` が両世代を明示区分して読む（legacy/invalid/skip を fail-silent 禁止で集計）
- **c3-prime 契約は #874 を文書冒頭 L6 の消費者一覧で「供給元」と記すが、§7 の consumer IF 詳述は #873 のみ**（§6 は LoopSpec 派生で #874 非言及）。#874 の consumer 接続は §7 追記が必要
- **schema 配置の HO 分岐**: `schemas/**` は **HO**（`ho-paths.md:28`「AI 直接編集不可」）。非 HO 前例は `docs/schemas/child-pbi.yaml` のみ（#869 は HO の `schemas/` を提案しており非 HO 前例ではない）

## What（Scope）

### In scope

1. **RunEvidence schema + versioning policy**: 下記 20 フィールドを最低項目とする schema と versioning policy を定義。配置先は HO 分岐（下記 Notes）で C-3 確定
2. **決定論 producer `run_evidence.py`**（`scripts/ai-loop/`・**非 HO**）: 同一入力 events から byte 同一 RunEvidence を再生成。`plan_package.py`/`c3prime_verify.py` の決定論・fail-closed・冪等規約を踏襲（timestamp 注入・`now()` 直参照禁止・`json.dumps(sort_keys=True)`）
3. **validator**: missing / partial / tampered evidence を ready 扱いせず明示状態にする（`metrics.py` の legacy/invalid/skip 明示区分パターンを転写）
4. **フィールド結合**: Plan hash・C-3'・final head SHA・CI・review・routing・terminal state を同一 run へ結合。**#868 の requested/resolved routing と outcome を `routing_decisions[]` に区別して記録**（#868 未実装のため粒度は暫定・後日整合）
5. **observation と cause hypothesis の分離**（フィールド分離）
6. **privacy 制約**: hidden CoT / raw transcript / secret / account 識別子を要求も保存もしない
7. **c3-prime-contract §7 への #874 consumer 登録追記**: 読むフィールドと fail-closed 再検証（§4 全規則の再実行）。§8 versioning は #872/#873/#874 の 3 issue 合意事項
8. **#869/#811 接続 adapter IF**（再実装せず provenance 橋渡しのみ）: RunEvidence→#869 shadow candidate の `source_run_ids` / `baseline harness version` 保持、#811 promotion decision と改善 PR/commit の追跡 IF
9. **legacy record migration/compatibility**: 既存 9/14 キー arbiter record との関係整理（RunEvidence は arbiter record の後継でなく上位 artifact で 1 入力ソースとして参照）
10. **10 fixture 全実装**（下記 verbatim）

### Out of scope（issue Non-goals verbatim）

- #869 の clustering / experiment policy を再定義すること
- #811 の promotion decision table を再定義すること
- AI による merge
- active run への hot patch
- SaaS や外部 memory service を必須化すること

## RunEvidence 最低フィールド（issue 本文・20 項目）

`run_id, task_id, started_at, completed_at, repository, source_sha, final_head_sha, plan_hash, c3_prime_decision_ref, harness_version, routing_decisions[], ci_outcomes[], review_findings[], repair_rounds, replan_count, human_interventions[], terminal_state(MERGE_READY|HUMAN_ESCALATED|BLOCKED), quality_metrics{}, cost_metrics{}, evidence_refs[]`

## 受入基準（issue #874 verbatim・13 項目）

- AC-1: RunEvidence schema と versioning policy がある
- AC-2: 同一入力 events から同一 RunEvidence を再生成できる
- AC-3: Plan hash、C-3'、final head SHA、CI、review、routing、terminal state が同一 run へ結合される
- AC-4: missing / partial / tampered evidence を ready 扱いせず明示状態にする
- AC-5: observation と cause hypothesis が分離される
- AC-6: hidden CoT / raw transcript / secret を要求・保存しない
- AC-7: #869 が RunEvidence のみから shadow candidate を生成できる
- AC-8: candidate が source_run_ids と baseline harness version を保持する
- AC-9: improvement TASK が通常の Plan-first / C-3' / PR 収束を通る
- AC-10: paired replay、独立 grader、activation check、rollback 結果を source candidate へ戻せる
- AC-11: #811 promotion decision と改善 PR/commit を追跡できる
- AC-12: active run の harness version が途中で変化しない
- AC-13: #862/#866 未解決の正本へ自動 promotion しない fail-closed 条件がある

### In scope↔AC 対応（issue AC に無いが In scope 実装物に紐づく検証条件）

- AC-14（In scope 7 対応）: `c3-prime-contract.md §7` に #874 consumer が追記され、RunEvidence 生成時に §4 全規則（hash/source_sha/verdict 整合）を fail-closed 再検証する
- AC-15（In scope 9 対応）: legacy 9 キー / run メタ 14 キー record との関係が migration/compatibility として定義され、RunEvidence が上位 artifact（arbiter record を 1 入力ソースとして参照）であることが機械検証可能
- AC-16（In scope 10 対応）: 下記 10 fixture が `tests/extras/ta-NN` で CI 実行され、AC↔fixture 対応表が残る

### 必須 fixture（issue verbatim・10 件）

1. first-pass MERGE_READY / 2. CI repair あり MERGE_READY / 3. review repair あり MERGE_READY / 4. HUMAN_ESCALATED / 5. BLOCKED / 6. routing escalation あり / 7. partial/tampered evidence / 8. 3 件以上の同型 Run から shadow candidate 生成 / 9. baseline/candidate paired replay / 10. failed canary から rollback

### DoD / Close 条件（issue verbatim 要点）

AC と 10 fixture 全 PASS / schema・producer・validator・consumer adapter が main へ merge / #869 shadow mode 統合 test / #811 promotion provenance test / privacy test / **failed canary rollback 実走または再現 fixture** / Issue コメントに schema・test command・sample record・integration log link / #870 Evolution DoD へ evidence link。**schema 文書のみ、candidate の手動作成のみ、効果測定なしでは close しない**。

## Notes from Refinement（調査で確定した設計方針）

- **HO 分岐（C-3 論点）**: RunEvidence schema を `schemas/` に置くと **HO patch（Human 適用）**が必要（#872 PR-2 と同型の「非 HO 受理器 + HO patch を Human 適用」= commit c0461bb 型）。AI 主体で回すなら `docs/schemas/`（非 HO・前例 `child-pbi.yaml`）に契約文書として置き、機械検証は非 HO validator（`scripts/ai-loop/`）が担う。**どちらを採るかを C-3 で確定**（schemas/=機械強制強・Human 適用 / docs/schemas/=AI 完結・機械検証は validator）
- **producer/validator は非 HO**: `scripts/ai-loop/**` は PoC 隔離（本番から呼ばれない）で AI 実装可能
- **#872 契約接続**: §7 に #874 consumer を追記（`c3_prime_decision_ref` 経由で `decision`/`source_sha`/`plan_hash`/`plan_package_hash`/`task_id`）。trust boundary は decision 無検証信頼禁止 → RunEvidence 生成時も §4 全規則の fail-closed 再検証。§6 `derived_loopspec_hash`/`plan_hash` が `harness_version`/`plan_hash` の供給元
- **上流未実装のため fixture 先行**: #873（delivery.py の terminal_state 供給元）と #811 が未実装・OPEN。#874 の consumer adapter は fixture 8/9/10（shadow candidate / paired replay / rollback）で契約検証する構造
- **決定論パターン先例**: `plan_package.py`（決定論・fail-closed・冪等）/ `c3prime_verify.py`（exit code 契約）/ `metrics.py`（世代分裂の legacy/invalid/skip 明示区分）を転写

> **✅ schema 配置論点の裁定（2026-07-31・Human。本ブロックは schema 配置のみに係る — 他の C-3 論点は未裁定のまま）**: **案 2 段階方式**を採用。Phase 1（shadow）は
> `docs/schemas/`（非 HO）で 4 PBI（#894/#874/#869/#908）同側に統一し、本番接続
> （promotion gate / Gate 接続）の C-3 で `schemas/` へ **1 回の HO patch で昇格**
> （前例 `3ec2e24`）。昇格判定は Gate 接続 PR の Human C-3 チェックリストで行う。
> 裁定の正本: [`docs/working/discussions/2026-07-31-schema-placement-ho-arbitration.md`](../discussions/2026-07-31-schema-placement-ho-arbitration.md) §7

## Estimation Evidence

### Risks

| リスク | 検証手段 | Fallback |
|--------|---------|----------|
| schema HO 分岐（`schemas/` vs `docs/schemas/`）で承認境界の強度が割れる | C-3 で配置先確定。schemas/ なら HO patch 分割（ho-apply-approval 型）| docs/schemas/ + 非 HO validator で AI 完結（機械強制は validator 側） |
| 上流（#873 delivery.py / #811）未実装で consumer adapter が検証不能 | fixture 8/9/10 で契約先行検証（実 delivery を待たない） | adapter IF はフィールド契約まで・実接続は #873/#811 完了後 |
| RunEvidence が arbiter record（9/14 キー分裂）と混同される | RunEvidence を上位 artifact と位置づけ・arbiter record は 1 入力ソース | legacy record は migration 定義で明示分離 |
| canary 実走が #866（OPEN）未解決で不可（#861/#862 は解消済み） | fixture 10（failed canary→rollback 再現）で DoD を満たす | canary 実走は Deferred（下記 blocker） |
| privacy 違反（raw transcript/secret 保存） | privacy test で機械検証（AC-6） | evidence_refs は参照のみ・本文非保存 |

### Unknowns

- schema 配置先（`schemas/` HO vs `docs/schemas/` 非 HO）→ **C-3 で確定**
- versioning policy の粒度（RunEvidence schema version と既存 arbiter record の 9/14 キー世代の関係）→ plan で確定
- #869/#811 adapter IF の最小フィールド（source_run_ids / baseline harness version 以外）→ #869/#811 の pbi と整合

### Deferred blocker（canary 実走の前提・EPIC #870 明記）

- **#866（OPEN のみ）**: canary 実走前の正本性解消の残存前提。**#861 / #862 は既に CLOSED（解消済み）**ため blocker から除外（実測: 2026-07-20 に #861/#862=CLOSED / #866=OPEN を確認）。#874 AC-13「#862/#866 未解決へ自動 promotion しない fail-closed」は #866 に対して有効
- **#863**: 導入先 plugin E2E 完了の前提（capability/degradation 契約）
- **#873（delivery.py）/ #811**: 未実装・OPEN → fixture 先行で実装
- **canary は「実走 Deferred / 再現 fixture(10) In scope」の二段構え**で DoD の「実走または再現 fixture」を満たす
- （C-3 論点: EPIC #870 本文の blocker 記述も #861/#862 CLOSED を反映していない古い文言 → #870 側の記述更新を別途 issue コメントで提起推奨）

### Assumptions

- 新設: `run_evidence.py` + test + validator + adapter IF + schema（配置先は C-3）+ 10 fixture（`tests/extras/ta-NN`）+ c3-prime-contract §7 追記
- **Mode: critical で確定**（`mode-classification.md` 定量基準: **受入基準数 11+ → 超高（critical）が決定論的**。本 PBI は AC 13 + In scope 対応 3 = 実質 16 で 11+ 確定。変更ファイル数も schema + producer + validator + adapter + 10 fixture + テスト + contract 追記で 16+（超高）。「各軸の最大値を採用」で critical 確定）。**autonomous APPROVE 不可・人間 C-3 必須・V-4 リリース前チェック要**。schema を `schemas/` に置く場合は **Hardening Override 発火**（autonomous 完全排除・lite_eligible 無効化）が追加で確定
