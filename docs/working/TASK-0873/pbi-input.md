# PBI INPUT PACKAGE — TASK-0873

> Issue: [#873](https://github.com/s977043/plangate/issues/873)（P0 / enhancement / area:workflow）
> Parent EPIC: [#870](https://github.com/s977043/plangate/issues/870)
> 作成: 2026-07-20（調査リフレッシュ・main c0461bb 裏取り済みを反映）

## Context / Why

`ai-loop run TASK-XXXX`（#872 で Plan-first 化）が C-3'（c3-prime）で AUTO_APPROVED した後、PR 作成 → CI・AI レビュー対応 → 修正反復 → **MERGE_READY** へ収束させる状態機械が未実装。現状は状態遷移の docs 語彙（`PR_CREATED → MERGE_READY → MERGED`）と Scheduling 判断表しかなく、機械実装がない。

実測（2026-07-20・main c0461bb）:

- 状態語彙 `WAITING_FOR_CHECKS` / `WAITING_FOR_REVIEW` / `CHECKS_FAILED` は**リポジトリ内に未実在（#873 が新規導入）**。既存 docs 語彙は `00_concept.md` L82（`PR_CREATED/MERGE_READY/MERGED`）+ `execution-runbook.md` L197-245（Scheduling 判断表）
- `scripts/ai-loop/delivery.py` は**未存在（新設）**。既存 `arbiter.py` / `plan_package.py` / `c3prime_verify.py` は「決定論・fail-closed・冪等」の同型設計
- c3-prime 契約（#872）は `c3-prime-contract.md` §7 に delivery.py 向け引き渡し（読むフィールド・trust boundary）を確定済み。§6 consumer 一覧に `#873 delivery.py（読み取り）` 登録済み

## What（Scope）

### In scope

1. **MERGE_READY 状態機械**（`scripts/ai-loop/delivery.py` 新設）: `PR_CREATED` から `MERGE_READY` への収束を決定論・fail-closed・冪等で実装。新状態語彙（`WAITING_FOR_CHECKS` 等）を既存 docs 語彙（`PR_CREATED/MERGE_READY/MERGED` + Scheduling 判断表）へ**正規化**して導入
2. **c3-prime 受理側 trust boundary**（§7）: delivery.py は c3-prime record の `decision` を無検証で信頼せず、`c3prime_verify.py` を import 再利用 or 同等再検証で fail-closed。head SHA 束縛 = `source_sha` 基点で PR head が子孫でなければ fail-closed
3. **CI・AI レビュー対応の反復**: CI 全 job green AND AI レビュー指摘全件対応完了で MERGE_READY
4. **NO MERGE BY AI（Iron Law）担保**: 遷移表に `MERGED` 遷移を持たせない（`MERGE_READY` 止まり）+ delivery.py が merge API シンボル（`gh pr merge` / `merge_pull_request`）を含まないソース走査テスト
5. **resume 冪等性**: run record の `source_sha` を基点にした resume 冪等（#873 新規設計）
6. **E2E テスト**: `tests/extras/ta-56-*.sh`（番号仮）を ta-55 様式（sandbox + 直接叩き + HO 未適用 SKIP）で相乗り

### Out of scope

- ai-dev plan/exec/verify の再実装（#872 の資産再利用）
- C-4 / merge 自動化（NO MERGE BY AI・Human 固定）
- Evolution Loop（#874/#869）への接続（本 PBI は Delivery まで）

## 受入基準（#873 issue + 調査反映）

- AC-1: `PR_CREATED` から `MERGE_READY` への状態遷移が決定論・fail-closed・冪等
- AC-2: 新状態語彙が既存 docs 語彙（`00_concept` L82 / Scheduling 判断表）へ正規化され、正本 doc に定義
- AC-3: delivery.py が c3-prime `decision` を無検証で信頼せず fail-closed 再検証（§7 trust boundary）
- AC-4: head SHA 束縛（PR head が `source_sha` の子孫か）で不一致は BLOCK
- AC-5: 遷移表に `MERGED` 遷移が無い + delivery.py に merge API シンボル不在（ソース走査テストで固定）
- AC-6: resume 冪等（同一 run record から同一状態）
- AC-7: E2E fixture が CI 登録（ta-55 様式・run-tests.sh 経由）

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
| resume 冪等の設計が greenfield | fixture 駆動で同一 run record → 同一状態を検証 | Phase 1 は resume 非対応・単発実行のみ（V2 で resume）|
| delivery.py が c3-prime 再検証を誤実装 | c3prime_verify.py を import 再利用（再実装しない）| §4 全規則の再実装 + 敵対レビュー |

### Unknowns

- CI から unittest 本体（test_delivery.py）を直接走らせる配線を追加するか、ta-56 の直接叩きのみにするか → plan で確定
- 新状態語彙の粒度（issue タイトルの 3 語彙をそのまま導入 vs 既存 Scheduling 判断表の優先度体系に吸収）→ C-3 論点

### Assumptions

- delivery.py + test_delivery.py + ta-56 + 遷移表正本 doc の新設 + c3-prime-contract §7 の additive 更新
- Mode 見込み: high-risk（状態機械 + 承認境界接続）。人間 C-3 推奨
