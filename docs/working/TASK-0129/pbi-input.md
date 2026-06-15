# PBI INPUT PACKAGE: TASK-0129

## Context / Why

#543「Plan Review Gate の判定連携」を #544 Loop 安全制御の **Phase2（強制化）** として実装する。設計ノート（PR #553 マージ済 `docs/working/discussions/2026-06-15-543-plan-review-gate-design.md`）で方針確定済み。

PlanGate の責務はレビューそのものでなく「**レビュー結果で進行可否を判定し止める・通す**」こと。外部レビュー結果（Decision/Risk/Stop-Work 等）と #544/#551 の plan 充足を入力に、C-3 判定へ接続する。

> ⚠️ **本 PBI は承認境界の中核（c3-approval.schema / working-context.md = HO）を変更する**。mode-classification「承認境界周辺の変更 → 最低 high・lite_eligible=false・Standard 同期 C-3 固定・autonomous APPROVE 不可」が適用される。**実装着手（exec）には人間の C-3 承認が必須**。HO ファイルへの適用も人間（apply-script 経由）。

Relates #543 #544 #527 / 設計: PR #553

## What

### In scope
- 外部レビュー結果スキーマ（Decision: go/revise_plan/human_approval_required/no_go、Risk、Stop-Work Conditions 等）→ C-3 判定（c3_status）への **mapping 定義**
- `schemas/c3-approval.schema.json`（HO）への拡張: Decision 由来の判定根拠フィールド（apply-script + 人間適用）
- C-1 拡張: plan の充足チェック（Stop Condition / Replan Triggers 機械値 記入）を検出（#544 Phase1 と連結）
- Stop-Work Conditions → #544/#551 機械トリガー（変更ファイル2倍/+5・連続失敗3回・反復3回・plan外波及・AC変更）への対応表
- Do Not Touch → forbidden_files（EH-6）接続 / Verification Required → Verification Automation 注入

### Out of scope
- 機械トリガーの**実行層実装**（codex-guarded.sh / doctor）→ 別 PBI（#527 配下・本 PBI は判定 mapping まで）
- Risk Budget / 自律度（#487）
- 外部レビューア接続規約そのものの変更（external-reviewer-interface.md は参照のみ）

## 受入基準

| AC | 内容 |
|----|------|
| AC-01 | Decision → c3_status マッピングが定義され schema/doc に反映（go→APPROVED / revise_plan→CONDITIONAL / human_approval_required→人間C-3強制 / no_go→REJECTED） |
| AC-02 | Risk=high で最低 high mode・autonomous APPROVE 無効化が機械判定に接続 |
| AC-03 | C-1 が plan の Stop Condition / Replan Triggers(機械値) 記入を検出（未記入で WARN/FAIL） |
| AC-04 | Stop-Work Conditions ↔ #544/#551 機械トリガーの対応が定義される |
| AC-05 | schema 変更は apply-script で提示し AI は直接編集しない（HO・人間適用） |
| AC-06 | 全変更が承認境界整合（mode=high-risk以上・Standard C-3・lite_eligible=false を明記） |

## Estimation Evidence

### Risks / Unknowns
- c3-approval.schema.json（HO）拡張は承認境界の中核 → 既存 c3.json 後方互換の担保
- Decision→c3_status の schema 表現（新フィールド vs gate_checks 拡張）
- 機械トリガー実行層との責務分界（本 PBI は mapping まで・実行は #527 配下）

### Assumptions
- 設計ノート（PR #553）の方針を踏襲
- exec は人間 C-3 承認後。HO 適用は人間（apply-script）
