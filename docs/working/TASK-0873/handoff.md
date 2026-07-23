---
task_id: TASK-0873
artifact_type: handoff
schema_version: 1
status: final
issued_at: 2026-07-23
author: orchestrator
v1_release: ""
---

# Handoff Package — TASK-0873（MERGE_READY 状態機械 delivery.py）

## メタ情報

```yaml
task: TASK-0873
related_issue: https://github.com/s977043/plangate/issues/873
author: orchestrator
issued_at: 2026-07-23
v1_release: ""  # PR 未作成（exec 完了・River Review → PR が残タスク）
branch: feat/task-0873-delivery（worktree task-0873-exec・origin/main +7 commit）
```

## 1. 要件適合確認結果

test-cases.md の AC-1〜12 を test_delivery.py（51 テスト）+ ta-56 E2E（10 項目）で機械突合。`sh tests/run-tests.sh` = **421 passed / 0 failed / exit 0**（クリーン 1 回実行）。

| 受入基準 | 判定 | 根拠 |
|---------|------|------|
| AC-1 状態遷移の機械可読契約 | PASS | `delivery.py contract` 決定論 emit + doc↔contract byte 一致（sha256 同一・V-1 独立確認） |
| AC-2 旧 head の CI success で MERGE_READY にならない | PASS | TC-06（stale checks → WAITING_FOR_CHECKS） |
| AC-3 required review pending で MERGE_READY にならない | PASS | TC-02 |
| AC-4 CI failure → 修正・push・再評価遷移 | PASS | TC-03 + ta-56 sandbox 実走（CHECKS_FAILED→repair→MERGE_READY） |
| AC-5 review 指摘 → 修正 commit / evidence 付き不採用の追跡 | PASS | TC-04/05（内容真正性は C-4 責務・§5 明文化） |
| AC-6 Plan 外修正 → EXEC_RETURN | PASS | TC-14 + R1 A-03（ディレクトリ境界判定） |
| AC-7 conflict 三点照合 + 再評価 | PASS | TC-07 |
| AC-8 round 4 へ進まず HUMAN_ESCALATED | PASS | TC-08/E1 + R2（head 跨ぎ通算・リセット不可） |
| AC-9 permission/API 不明で成功扱いせず escalate | PASS | TC-09/13（未知 taxonomy fail-closed） |
| AC-10 resume 冪等 | PASS | TC-10/15/E5/E6 + ta-56（record 差分ゼロ）+ R1 A-05（entry_id 再計算） |
| AC-11 MERGE_READY record 6 フィールド | PASS | TC-16 + ta-56 |
| AC-12 merge 経路なし・C-4 待ち | PASS | TC-17/18 + ta-56（MERGED 遷移 0・禁止トークン 0・V-1 独立確認） |

**総合**: **12/12 PASS**（V-1 acceptance-tester が全 AC を機械突合し PASS 判定・FAIL 0。contract sha256 `0923a770…c5df4` で doc↔emit byte 一致・MERGED 0・禁止トークン 0 を独立確認）

## 2. 既知課題一覧

| 課題 | Severity | 状態 | V2 候補か |
|------|---------|------|---------|
| disposition evidence_ref の**内容**真正性を delivery が検証しない（記録の存在のみ機械保証） | minor | accepted（責務分界: C-4 が最終確認・§5 明文化） | Yes（evidence 内容の機械検証） |
| snapshot 信頼境界 Phase 1（悪意ある snapshot 供給者は scope 外） | info | accepted（c3-prime §4 と同型） | Yes（raw check evidence 束縛） |
| receipt の署名/hash-chain なし（record.jsonl 直書き偽造は entry_id 再計算 + pr/head 束縛で実害縮小だが完全防御でない） | info | accepted（Phase 1・信頼済みローカル repo） | Yes（署名 provenance） |

**Critical 課題**: なし（R1 の fail-open 3 件 = mergeable/severity 未検証・task_id 非束縛はすべて是正済み）

## 3. V2 候補

| V2 候補 | 理由 | 優先度 | 関連 |
|--------|------|--------|------|
| repair 実行の機械化（実 PR/gh を叩く action consumer） | V1 は snapshot 判定エンジン + sandbox スタブまで | Medium | #873 follow-up |
| disposition evidence 内容の機械検証 | Phase 1 は C-4 が最終確認 | Low | B2-11 |
| raw check evidence への snapshot 束縛 | Phase 1 信頼境界を狭める | Low | R1 A-08 残余 |
| Evolution Loop への Delivery evidence 接続 | 本 PBI は Delivery まで | Medium | #874/#869 |

## 4. 妥協点

| 選択した実装 | 諦めた代替案 | 理由 |
|------------|-----------|------|
| A-1 snapshot 判定エンジン（純判定器・stdin/引数入力） | A-2 gh API 常駐ループ | 非決定論で 10 fixture の CI 実走が困難・fail-closed 設計と衝突 |
| B-1 code 単一定義 + contract emit + doc byte 一致テスト | B-3 schemas/*.schema.json 配置 | HO 化で Human 適用待ちの 2 段構成になり P0 が重くなる |
| c3_contract import（canonical_hash） | c3prime_verify のみ import | #896 が先行 merge（plan Replan Trigger 規定・C-3 承認済み）→ 共通契約層を最初から利用 |
| TRANSITIONS を stateless 到達グラフに | 前状態依存の遷移強制 | assess は各回 snapshot 駆動で stateless（A-07 是正） |

## 5. 引き継ぎ文書

### 概要

issue #873（P0）の MERGE_READY 状態機械を `scripts/ai-loop/delivery.py`（決定論・fail-closed・冪等・純判定器）として実装完了。c3-prime AUTO_APPROVED 後の `PR_CREATED → CI/レビュー対応反復 → MERGE_READY` を snapshot 入力の判定エンジンで機械化。**exec は完了・全テスト green（421/0）・R1/R2 敵対レビュー収束**。残タスクは River Review（PR 作成前・新規律）→ PR 作成のみ。

### 触れないでほしいファイル

- `scripts/ai-loop/c3prime_verify.py` / `c3_contract.py`: #872/#896 の承認境界受理器。delivery は import 再利用のみ（改変すると受理契約が壊れる）
- `docs/workflows/ai-loop/delivery-state-machine.md` の `<!-- contract:begin/end -->` ブロック: `delivery.py contract` の emit と byte 一致必須（手編集せず emit で再生成）

### 次に手を入れるなら

- **River Review をローカルで実施**（feat/task-0873-delivery の diff）→ 指摘是正 → PR 作成（GH_TOKEN=$(gh auth token --user s977043) スコープ）
- delivery.py を変更したら必ず `sh scripts/sync-plugin-plangate.sh` を 2 回実行（plugin 再生成・no-op 確認）+ doc contract ブロック再生成
- 避けるべき: contract ブロックの手編集 / snapshot enum の緩和 / round スコープの pr_number 除去

### 参照リンク

- 親 EPIC: #870 / issue: #873
- 正本: `docs/workflows/ai-loop/delivery-state-machine.md`
- status.md: `docs/working/TASK-0873/status.md`

## 6. テスト結果サマリ

| レイヤー | 件数 | PASS | FAIL/SKIP | 備考 |
|---------|------|------|-----------|------|
| Unit（test_delivery.py） | 51 | 51 | 0 | R1 回帰 13 + R2 回帰 2 含む |
| Integration（c3-prime 入口再検証） | — | PASS | — | TC-19/20/21 + legacy BLOCK |
| E2E（ta-56） | 10 | 10 | 0 | sandbox 実走 + doc 整合 + 純判定器走査 |
| run-tests.sh 全体 | 421 | 421 | 0 | クリーン 1 回実行 exit 0 |

**FAIL/SKIP**: なし。未 commit 変更下の TC-05 pollution 偽陽性（既知）は commit 後に解消済み。

## 7. Metrics summary

該当なし（本セッションで metrics --collect 未実施）。
