# PBI INPUT PACKAGE — TASK-0873

> Issue: [#873](https://github.com/s977043/plangate/issues/873)（P0 / enhancement / area:workflow）
> Parent EPIC: [#870](https://github.com/s977043/plangate/issues/870)
> 作成: 2026-07-20（調査リフレッシュ・main c0461bb 裏取り済みを反映）

## Context / Why

`ai-loop run TASK-XXXX`（#872 で Plan-first 化）が C-3'（c3-prime）で AUTO_APPROVED した後、PR 作成 → CI・AI レビュー対応 → 修正反復 → **MERGE_READY** へ収束させる状態機械が未実装。現状は状態遷移の docs 語彙（`PR_CREATED → MERGE_READY → MERGED`）と Scheduling 判断表しかなく、機械実装がない。

実測（2026-07-20・main c0461bb）:

- 状態語彙 `WAITING_FOR_CHECKS` / `WAITING_FOR_REVIEW` / `CHECKS_FAILED` は**リポジトリ内に未実在（#873 が新規導入）**。既存 docs 語彙は `00_concept.md` L82（`PR_CREATED/MERGE_READY/MERGED`）+ `execution-runbook.md` L197-245（Scheduling 判断表）
- `scripts/ai-loop/delivery.py` は**未存在（新設）**。既存 `arbiter.py` / `plan_package.py` / `c3prime_verify.py` は「決定論・fail-closed・冪等」の同型設計
- c3-prime 契約（#872）は `c3-prime-contract.md` **§7** に delivery.py 向け引き渡し（読むフィールド `task_id`/`decision`/`source_sha`/`plan_hash`/`plan_package_hash` + trust boundary 再検証責務）を確定済み

## What（Scope）

### In scope

1. **状態機械契約（machine-readable）**: state transition を **schema または同等の機械可読契約**として定義（`docs/schemas/` or 正本 doc + 検証）。新状態語彙（`WAITING_FOR_CHECKS`/`WAITING_FOR_REVIEW`/`CHECKS_FAILED` 等）を既存 docs 語彙（`PR_CREATED/MERGE_READY/MERGED` + Scheduling 判断表）へ**正規化**。`scripts/ai-loop/delivery.py` 新設（決定論・fail-closed・冪等）
2. **最新 head SHA 束縛**: 最新 head SHA 以外の CI success / required review 未着弾の pending では **MERGE_READY にしない**
3. **CI failure taxonomy と repair 反復**: CI failure を **code / flaky / environment / permission / unknown** へ分類し、修正・push・再評価へ遷移。permission/API 不明時は成功扱いせず HUMAN_ESCALATED
4. **review disposition 追跡**: review 指摘を **修正 commit または実測 evidence 付き不採用**へ紐付け（採否 / evidence / repair commit）
5. **Plan 逸脱検出**: Plan 外修正を検出したら exec 差し戻し または C-3' 再裁定
6. **conflict 再評価**: conflict 解消後に **base/head/結果の三点照合** + CI/review 再評価
7. **round 上限**: 最大 **3 repair round**。round 4 へ進まず HUMAN_ESCALATED
8. **c3-prime 受理側 trust boundary**（§7）: `decision` を無検証で信頼せず `c3prime_verify.py` を import 再利用 or 同等再検証で fail-closed。head SHA 束縛は `source_sha` 基点
9. **NO MERGE BY AI（Iron Law）担保**: 遷移表に `MERGED` 遷移を持たせない（`MERGE_READY` 止まり・C-4 待ちで停止）+ delivery.py が merge API シンボル（`gh pr merge` / `merge_pull_request`）を含まないソース走査テスト
10. **resume 冪等性（V1 必須）**: run record の `source_sha` / head SHA を基点に、resume を複数回実行しても同じコメント・修正・push を**重複しない**。fixture で固定
11. **MERGE_READY record**: **PR 番号 / head SHA / check summary / review disposition / round / plan hash** を残す
12. **E2E テスト**: 下記 10 必須 fixture を `tests/extras/ta-56-*.sh`（番号仮）で ta-55 様式（sandbox + 直接叩き + HO 未適用 SKIP）で実走

### Out of scope

- ai-dev plan/exec/verify の再実装（#872 の資産再利用）
- C-4 / merge 自動化（NO MERGE BY AI・Human 固定）
- Evolution Loop（#874/#869）への接続（本 PBI は Delivery まで）

## 受入基準（#873 issue verbatim + 調査反映）

- AC-1: state transition が **schema または同等の機械可読契約**として定義されている
- AC-2: 最新 head SHA 以外の CI success で MERGE_READY にならない
- AC-3: required review 未着弾の pending 状態で MERGE_READY にならない
- AC-4: CI failure から修正・push・再評価へ遷移できる（taxonomy: code/flaky/environment/permission/unknown）
- AC-5: review 指摘から修正 commit または evidence 付き不採用を追跡できる
- AC-6: Plan 外修正を検出すると exec 差し戻しまたは C-3' 再裁定になる
- AC-7: conflict 解消後に base/head/結果の三点照合 + CI/review を再評価する
- AC-8: round 4 へ進まず HUMAN_ESCALATED になる
- AC-9: permission/API 不明時に成功扱いせず HUMAN_ESCALATED になる
- AC-10: resume を複数回実行しても同じコメント・修正・push を重複しない
- AC-11: MERGE_READY record に PR 番号・head SHA・check summary・review disposition・round・plan hash が残る
- AC-12: merge 実行経路がなく、C-4 待ちで停止する

### 必須 fixture（issue verbatim・10 件）

1. CI pending / 2. CI green・review pending / 3. CI fail→repair→green / 4. major review→repair→re-review / 5. false positive→実測 evidence 付き不採用 / 6. stale CI on old SHA / 7. merge conflict→解消→再評価 / 8. round limit 超過 / 9. API permission 不足 / 10. process 中断→resume

DoD: AC + 10 fixture すべて CI PASS / sandbox で `PR_CREATED → CI failure/review repair → MERGE_READY` 実走 / 最新 head SHA 紐づき MERGE_READY evidence 保存 / 実装 PR main merge / issue コメントに E2E run・fixture log・状態遷移 record link / #870 収束 DoD へ evidence link。**手順書追加のみ・CI green のみ・review 未着弾では close しない**

## Notes from Refinement（調査で確定した設計方針）

- **契約接続点（#872）**: 読むフィールド = `task_id`/`decision`/`source_sha`/`plan_hash`/`plan_package_hash`（§7）。再検証リファレンス = `c3prime_verify.py` 全体（L107-178 の evidence/hash/snapshot 再検証）
- **merge 静的ガード既存**: `check-delegation-commit-boundary.sh` L105-107（`gh pr merge` を block）。delivery.py のソース走査テストはこの様式を踏襲
- **CI 相乗り**: #872 の `ta-55-c3prime-accept.sh` の sandbox 生成様式（`plan_package.build_c3_prime` + `test_plan_package._make_task_dir`）をそのまま流用可能
- **#874 との関係**: #872/#873 は契約合意後に並行実装（EPIC #870 の順序）。#873 の Delivery evidence を #874 が外側 Evolution Loop へ接続

## Estimation Evidence

### Risks

| リスク | 検証手段 | Fallback |
|--------|---------|----------|
| 新状態語彙と既存 docs 語彙の二重管理 | 正規化マッピング表を正本 doc に固定 | 新語彙を既存 3 状態のサブステートとして定義 |
| resume 冪等の設計が greenfield | fixture 10（process 中断→resume）で複数回 resume の重複なしを検証 | resume は **V1 必須**（issue AC-10）のため V2 送りにしない。実装難時は record への冪等キー（head SHA + round）で「実行済み操作の再実行抑止」に最小化する |
| delivery.py が c3-prime 再検証を誤実装 | c3prime_verify.py を import 再利用（再実装しない）| §4 全規則の再実装 + 敵対レビュー |

### Unknowns

- CI から unittest 本体（test_delivery.py）を直接走らせる配線を追加するか、ta-56 の直接叩きのみにするか → plan で確定
- 新状態語彙の粒度（issue タイトルの 3 語彙をそのまま導入 vs 既存 Scheduling 判断表の優先度体系に吸収）→ C-3 論点

### Assumptions

- delivery.py + test_delivery.py + ta-56 + 遷移表正本 doc の新設 + c3-prime-contract §7 の additive 更新
- Mode 見込み: high-risk（状態機械 + 承認境界接続）。人間 C-3 推奨
