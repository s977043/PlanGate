---
task_id: TASK-0871
artifact_type: handoff
schema_version: 1
status: final
issued_at: 2026-07-19
author: qa-reviewer
v1_release: "4c5d1e6 (PR #881) + 07a9d66 (PR #882)"
---

# Handoff Package — TASK-0871 正本定義統合・PoC 制約分離

## メタ情報

```yaml
task: TASK-0871
related_issue: https://github.com/s977043/plangate/issues/871
author: qa-reviewer
issued_at: 2026-07-19
v1_release: "PR #881 mergeCommit 4c5d1e6 / PR #882 mergeCommit 07a9d66"
```

## 1. 要件適合確認結果

全数実測は [`evidence/verification/ac-final-matrix.md`](./evidence/verification/ac-final-matrix.md) を正とする。

| 受入基準 | 判定 | 根拠 / コメント |
|---------|------|---------------|
| AC-1 5 責務定義 | PASS | 00_concept §2.1（Evolution 列追加 = D-12 解消） |
| AC-2 terminal state 3 状態 + 判定主体 | PASS | 00_concept §2.2（`MERGE_READY` 表記正規化 = D-7 解消） |
| AC-3 ai-dev 工程の共通利用 | PASS | 00_concept §1 / §2.4 |
| AC-4 C-3/C-3' 経路・判定主体 | PASS | 00_concept §3.2/§3.5/§3.6（順序図・役割分界 = D-9 解消）+ 独立レビュー ×2 矛盾 0 |
| AC-5 invariant / rollout 分離 | PASS | rollout-policy.md 新設 + 00_concept は参照 + 要約表（D-2/D-10 解消） |
| AC-6 裁定状態 / Delivery 状態の区別 | PASS | 00_concept §2.3 + adaptive Stop 行是正（D-5 解消） |
| AC-7 内外 Loop 区別 | PASS | 00_concept §4.1 |
| AC-8 harness 自己変更禁止 | PASS | 00_concept §4.1 |
| AC-9 複数正本なし（限定スコープ） | PASS | 実定義は 00_concept のみ・他は参照/採否記録（Q4 C-3 承認済み・#866 別トラック） |
| AC-10 6 ファイル参照整合 | PASS | command / core-contract / SKILL 両版 / six-stage / adaptive すべて正本参照化 |

**総合**: **10/10 基準 PASS**（+ TC-14/TC-15 PASS + Verification 4/4 PASS）
**FAIL / WARN の扱い**: なし

## 2. 既知課題一覧

| 課題 | Severity | 状態 | V2 候補か |
|------|---------|------|---------|
| pre-existing markdownlint MD032 ×2（`docs/ai/core-contract.md` L24 / `docs/working/TASK-0871/plan.md` Mode 判定節）— 本 TASK diff 起因でないことを git show で証明済み | minor | open（本 TASK スコープ外） | Yes（軽微 chore） |
| sync スクリプト stale コメント「17 本」（実態: rollout-policy 追加で workflows 11 本）— 動作影響ゼロ（glob 駆動）。N-2 で不採用と記録 | info | accepted | Yes |
| 「適用ドメイン（Phase 1）」注記が plan 名指し外の 6 ファイルに残置（workflows 4 + spec 層 2） | minor | accepted（採否理由記録済み） | Yes（D-8 完全解消） |

**Critical 課題の対応**: critical / major の未解決課題なし。

## 3. V2 候補

| V2 候補 | 理由 | 推定優先度 | 関連 Issue |
|--------|------|----------|-----------|
| D-8 完全解消: 旧 Phase 1 注記残置 6 件（lite-criteria / loop-safety-gates / decision-table / review-feedback-loop / design-philosophy / arbiter-policy）の rollout-policy 参照 1 行化 | plan S4 名指し外・Non-goals「一括移動」に接続するため見送り | Medium | #870 系 follow-up |
| spec 層（`docs/ai/ai-loop/concept.md` L56 等）の merge-ready → `MERGE_READY` 表記統一 | TC-09/TC-12 で採否記録に留めた（正本参照文脈として可読） | Low | T-12 所見 5 |
| core-contract Iron Law #7 への ai-loop 経路脚注 | T-12 参考所見 3。§1-bis 参照 1 段落で現状十分 | Low | follow-up 候補 |
| sync スクリプト コメント数値レス化 | N-2 不採用の解消 | Low | #877 系 chore |
| pr-watch SKILL の merge-ready 用語統一 | plan Files 外（走査のみ対象・R-010） | Low | — |

## 4. 妥協点

| 選択した実装 | 諦めた代替案 | 理由 |
|------------|-----------|------|
| B案: 00_concept.md を正本へ昇格・再構成 + rollout-policy.md 分離 | A案: architecture.md 新設 / C案: core-contract へ統合 | 参照パス不変で 12 ファイル規模の張り替え不要・二重正本の移行期リスクなし（plan 選択肢比較） |
| **Replan: 2 PR 分割**（PR-1 正本確定 10 ファイル / PR-2 周辺追従 12 ファイル） | 単一 PR（手編集 11 + sync で上限 12 超過） | CI drift-check（#842 R-005 fail-closed）で sync 生成物の各 PR 同梱が必須。Human 判断（2026-07-19）で「カウント除外の逸脱は不承認・原則どおり Replan」= Q7 |
| AC-9 監査対象を ai-dev / ai-loop アーキ文書に限定（#866 は別トラック） | skills 正本三つ巴矛盾まで本 TASK で解消 | ドメインが skills sync 機構側・修正経路も別（Q4・C-3 明示承認済み） |
| rollout-policy は汎用表現で verbatim 配布・雛形ヘッダなし | 導入先向け雛形注記ヘッダ機構の追加 | Q6 C-3 確定。plangate 固有の文脈依存表現を持ち込まない書き方で足りる |
| HO 対象 command は AI が patch 提示まで・適用は Human（H-02） | c3 承認を根拠に AI 直接編集 | HO 常時 block 運用（会話内承認でも AI 編集不可）。`evidence/ho-patch/` + `approvals/ho-apply-approval.md` で監査可能化 |
| N-2: sync stale コメント「17 本」は編集しない | 同 PR で数値レス化 | PR-1 のファイル数を 10 に保つ・動作影響ゼロ・別 chore で対応可 |

## 5. 引き継ぎ文書

### 概要

ai-dev / ai-loop のアーキテクチャ・責務定義を `docs/workflows/ai-loop/00_concept.md`
に**単一正本化**し（5 責務表 / terminal state `PR_CREATED`・`MERGE_READY`・`MERGED` +
判定主体 / C-3'=標準・Human C-3=escalate の経路 + WF-00〜07 不変の両立順序図 /
内外 Loop 区別 / harness 自己変更禁止）、Phase 1 適用制限（lite/clean/reversible・
auto-approve 方針・安全側不変条件）を新設 `docs/workflows/ai-loop/rollout-policy.md`
へ分離した。周辺文書（command / SKILL 両版 / core-contract / 周辺 6 docs / plugin
references）は正本参照化済み。PR-1（#881）+ PR-2（#882）で main へ merge 済み・
issue #871 CLOSED。

### 触れないでほしいファイル

- `docs/workflows/ai-loop/00_concept.md` §2〜§4: 単一正本。#872/#873 はここを参照する側で、定義の複製・改変は AC-9 の逆行（重複定義の再発）になる
- `docs/workflows/ai-loop/rollout-policy.md` §5 不変条件: 安全側の弱化禁止（NO MERGE BY AI / touches-HO escalate / lite AC-8 / 判定不能→false）。改版は policy 扱い（Human-owned）
- `.claude/commands/ai-loop-workflow.md`: HO 対象。変更は patch 提示 + Human 適用（H-02 方式）

### 次に手を入れるなら

- #872（Plan-first orchestration・C-3' artifact binding）/ #873（MERGE_READY state machine）が本正本の語彙（§2.2/§2.3）と経路定義（§3.2/§3.6）を契約として並行実装する想定（EPIC #870 実装順序）
- アンチパターン: 周辺 docs へ責務・terminal state の実定義を再追加すること / rollout 制約を 00_concept 本文へ書き戻すこと（AC-5 分離の崩壊）

### 参照リンク

- 親 EPIC: [#870](https://github.com/s977043/plangate/issues/870) / 本 issue: [#871](https://github.com/s977043/plangate/issues/871)（CLOSED）
- PR: #879（plan）/ #880（c3 保全）/ #881（PR-1）/ #882（PR-2）
- status.md: `docs/working/TASK-0871/status.md` / AC 突合: `evidence/verification/ac-final-matrix.md`

## 6. テスト結果サマリ

doc 変更のため Unit/Integration/E2E は該当なし。doc 検証の実測値:

| 検証 | 対象 | 結果 |
|------|------|------|
| markdownlint（CI 等価） | PR-1: docs/workflows 2 本 / PR-2: docs 6 本 + references 6 本 | **exit 0**（新規 violation 0。pre-existing MD032 ×2 は git show で証明・スコープ外） |
| link check（相対リンク実在・CI に専用 job なしのため代替） | PR-1: 8 ファイル / PR-2: 6 ファイル | **broken 0・exit 0** |
| plugin sync dry-run | PR-1 / PR-2 / merge 後 main（closeout で再実測） | **差分ゼロ（no changes・exit 0）×3** |
| 用語監査（付録 B rg 6 種） | before / PR-1 after / PR-2 after | D-1〜D-12 全解消 or 採否理由記録（terminology-audit.md §1-9） |
| 独立レビュー | #1（PR-1）/ #2（PR-2）別コンテキスト | **矛盾 0 件 PASS ×2** |
| HO patch 検証 | `git apply --check` + Human reverse-check | exit 0 ×2（適用は Human・a50ccb3） |

## 7. Metrics summary

該当なし（本 TASK では metrics --collect を未使用）。
