# PBI INPUT PACKAGE: AIエージェント開発 反パターンのチェック観点取り込み (#578)

> フェーズ A（PBI INPUT）。正本: `.claude/rules/working-context.md`。

## Context / Why
Zenn「AIエージェント開発のアンチパターン10選」由来。AI 開発で起きやすい事故（秘密情報混入・曖昧 Done・スコープ爆発・設計判断の喪失）を **Plan 段階で予防**したい。ただし Explore 重複マッピング（agent 調査）で大半は既存 PlanGate で充足済みと判明したため、**重複を排し新規観点のみ追加**する（Done 条件4: 過剰実装回避）。

## What（Scope）

### In scope
- `docs/working/templates/plan.md` / `review-self.md` に**新規 3 観点**を追加:
  1. **Verification**: 検証が実行不能なときの「理由 + 代替確認方法」明示欄（Stop Condition とは別概念）
  2. **Security**: 「.env / 秘密情報 / 個人パスに触れない設計か」の C-1 観点 +（扱う場合）secret scan / git diff 確認を Verification に含める要件
  3. **Scope**: 「実装中の発見を別 Issue/メモへ分離する」**予防**チェック（handoff/WF-06 は完了時集約のため Plan 段階の予防が欠落）
- #578「役割分担整理」Done は **既存への参照リンク追記**で充足（decision-log.jsonl / AGENT_LEARNINGS.md / `_audit/` / documentation-management.md）

### Out of scope
- `_docs/{sop,decisions,logs,learned}` 新設（既存 decision-log.jsonl / AGENT_LEARNINGS.md / `_audit/` と**重複・方式衝突**）
- `AGENTS.md` 役割再定義（HO・別 PBI）
- gate 機械強制（Plan 段階のチェック観点に留める。強制化は将来）
- 汎用 secret-scan ツール（gitleaks 等）の導入（別 PBI）

## 受入基準
- [ ] AC-01: plan.md Verification Plan に「検証実行不能時の理由 + 代替確認」行を追加
- [ ] AC-02: review-self に Security 観点（秘密情報/.env 非接触・扱う場合 secret scan を Verification に）を 1 項目追加
- [ ] AC-03: review-self / plan に Scope「実装中の発見を別 Issue/メモへ分離」予防チェックを追加
- [ ] AC-04: 既存重複観点は新設せず**既存参照**（_docs 新設しない・decision-log/AGENT_LEARNINGS を参照）。#578 役割分担 Done を参照リンクで充足
- [ ] AC-05: 既存テンプレとの重複ゼロ（過剰実装なし）を review-self で確認

## Notes from Refinement
Explore 重複マッピングの結論（判断の正本は decision-log.jsonl）:
- **既存充足**: スコープ明確/便乗リファクタ（plan.md Scope + C1-PLAN-03 + EH-6 + git-add-scope-guard）/ test-lint-typecheck・Done=検証完了（Verification Plan + AEE Stop Condition）/ 設計判断 repo 化（decision-log.jsonl + alternatives_rejected）/ AGENTS.md 恒常ルール（役割定義 + AGENT_LEARNINGS + _audit）。
- **新規は 3 観点のみ**。`_docs/decisions` は decision-log.jsonl と方式衝突のため不採用。

## Estimation Evidence
### Risks
- 既存 C-1 項目との重複・誤検出 → 既存を読み差分のみ追加（AC-05）
- Security 観点を含むため autonomous APPROVE 不可（安全側・人間 C-3）
### Unknowns
- secret scan を要件化のみか実装まで含むか → 初回は「Plan に含める要件」のみ（ツール導入は別 PBI）
### Assumptions
- templates のみ変更（HO 非該当）→ exec は AI 可（C-3 承認後）
