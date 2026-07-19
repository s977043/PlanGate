# TASK-0871 T-13 — AC 最終突合マトリクス

- 実測日時: 2026-07-19（closeout ワーカー・branch `docs/task-0871-closeout`）
- 実測ベース: origin/main（PR-1 #881 mergeCommit `4c5d1e6` + PR-2 #882 mergeCommit `07a9d66` を包含）
- 判定方式: 全件実測（rg / ls / dry-run / evidence artifact の存在・内容確認）。推測記載なし
- issue #871 は CLOSED（COMPLETED）

## 1. AC-1〜AC-10 突合（issue #871 受入基準・pbi-input.md 転記）

| AC | 内容（要約） | 判定 | 根拠（実測） | PR |
|----|------------|------|-------------|-----|
| AC-1 | 5 責務の定義 | **PASS** | `00_concept.md` §2.1 に 5 責務表（`rg -c "ai-loop Delivery\|ai-loop Evolution\|PlanGate Core"` = 10。各行に責務 + AI 責務終点） | #881 |
| AC-2 | `PR_CREATED` / `MERGE_READY` / `MERGED` の明記 | **PASS** | §2.2 terminal state 表（rg 28 件・L66 に「判定主体」列 = ai-dev / ai-loop DoD 判定 / Human） | #881 |
| AC-3 | Plan / exec / verify を再実装せず共通利用 | **PASS** | §1 L33「再実装せず共通利用」+ §2.4 L101（EPIC #870 Non-goals 参照つき） | #881 |
| AC-4 | C-3 / C-3' の経路・判定主体が矛盾なし | **PASS** | §3.2 L146-148（C-3'=標準自動経路・判定主体 arbiter / Human C-3=escalate・判定主体 Human）+ §3.5 役割分界 + 独立レビュー ×2 で矛盾 0 件 | #881 |
| AC-5 | invariant / rollout policy の分離 | **PASS** | `rollout-policy.md` 実在（ls）+ 00_concept の「Phase 1」記述は参照 + 要約表のみ（rg 5 件・全て参照/注記文脈） | #881 |
| AC-6 | 裁定状態と Delivery 状態の区別 | **PASS** | §2.3 語彙群区別表 + adaptive §4 Stop 行の同列列挙是正（PR-2）。CMD3 残 4 件は全て区別を定義/注記する側（terminology-audit §9） | #881/#882 |
| AC-7 | 内側 Delivery / 外側 Evolution Loop の区別 | **PASS** | §4.1 内外 Loop 区別表（Delivery = 1 run / Evolution = completed runs → improvement PR） | #881 |
| AC-8 | active run harness 自己変更禁止・改善は別 TASK/PR | **PASS** | §4.1 L269-270（開始時 harness / `harness_version` 保持・改善は別 TASK/Plan/PR） | #881 |
| AC-9 | 同じ責務の複数正本なし（ai-dev/ai-loop アーキ文書限定・#866 別トラック = Q4 C-3 承認済み） | **PASS** | 責務・terminal state・経路の実定義は 00_concept のみ。周辺 6 docs は参照化（PR-2）・design-philosophy §5 参照更新（six-stage 経由）・spec 層は採否理由記録（terminology-audit §9）。Q4 承認記録 = c3.json ×2 + issue #871 scope 注記 | #881/#882 |
| AC-10 | command / ai-loop-cycle / 00_concept / six-stage / adaptive / Core Contract の参照整合 | **PASS** | command に C-3'/rollout-policy 参照 3 件・core-contract §1-bis に参照 1 段落（rg 1 件）・SKILL 両版正本参照化（TC-14 rg 0 件）・six-stage/adaptive は §2.3 参照（PR-2） | #881/#882 |

集計: **10/10 PASS**。

## 2. TC-14 / TC-15（C-2 レーン間 AC 候補）

| TC | 判定 | 根拠（実測） |
|----|------|-------------|
| TC-14（SKILL 両版の旧 PoC 表現） | **PASS** | `rg -n "独立 PoC\|隔離 PoC\|適用ドメイン（Phase 1）" .claude/skills/ai-loop-cycle/SKILL.md .agents/skills/ai-loop-cycle/SKILL.md` → **0 件（exit 1）** |
| TC-15（spec 層と新正本の矛盾 0 件） | **PASS** | 独立レビュー #1/#2 で矛盾 0 件。spec 層（concept.md L56 等）の merge-ready 旧表記は「正本参照文脈として意味が通る・表記統一は follow-up」と採否理由記録済み（terminology-audit §9・T-12 所見 5） |

## 3. Verification 4 項目（issue #871 準拠）

| 項目 | 判定 | 実測 |
|------|------|------|
| 文書リンクチェック PASS | **PASS** | PR-1: `lint-linkcheck.log`（broken 0・markdownlint CI 等価 exit 0）/ PR-2: `lint-linkcheck-pr2.log`（broken 0・exit 0）。link check 専用 CI job 不在の記録つき代替実施 |
| rg 用語監査（残置は一覧 + 採否理由） | **PASS** | `terminology-audit.md` §1-2（before・D-1〜D-12 全再現）/ §5（PR-1 after）/ §9（PR-2 after・最終残置 4 分類すべて採否理由付き） |
| plugin sync dry-run 差分ゼロ | **PASS** | 本 closeout branch（merge 済み main）で再実測: 「Sync complete — no changes」exit 0。PR-1/PR-2 各ブランチでも差分ゼロを evidence 化済み |
| 独立レビュー矛盾 0 件 | **PASS** | `independent-review-1.md`（PR-1・748db9d・矛盾 0）+ `independent-review-2.md`（PR-2・e5e2c33/bf43529/98c9861・矛盾 0）。Stop Condition 非該当 |

## 4. TC-01〜TC-13 の判定所在

- TC-01〜TC-08: 上表 AC-1〜AC-8 の根拠列（本ドキュメントで実測）
- TC-09: AC-9 根拠列 + terminology-audit §9（EC-5 = design-philosophy §5 語彙集は区別の説明を保持しつつ、区別正本参照は 00_concept §2.3 へ更新〔six-stage 経由・PR-2〕）
- TC-10: AC-10 根拠列 + lint-linkcheck.log
- TC-11: 上表 Verification「sync dry-run」
- TC-12: terminology-audit §5/§9（残置採否理由。EC-3 = verbatim 引用の merge-ready 残置は「歴史的 verbatim 引用に限る」と 00_concept L72-73 に明文化）
- TC-13: independent-review-1/2（矛盾 0 件 ×2）
- EC-1: H-02 承認 + Human 適用（`approvals/ho-apply-approval.md` + commit a50ccb3）で解消
- EC-4: `rg -c "touches-HO|NO MERGE BY AI|判定不能"` = rollout-policy 9 / 00_concept 9（欠落 0・弱化なし）

総合判定: **AC 10/10 + TC-14/TC-15 + Verification 4/4 = 全件 PASS**。
