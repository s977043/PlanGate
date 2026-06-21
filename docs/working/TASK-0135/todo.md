# EXECUTION TODO — TASK-0135 (#578)

## 🤖 Agent タスク
### 準備
- [ ] T1 plan.md / review-self.md / metrics-privacy.md / decision-log-schema.md の現状を精読（重複確認）(owner:agent, files:docs/working/templates/plan.md;docs/working/templates/review-self.md, rollback:不要・読取のみ)
### 実装
- [ ] T2 [S1] plan.md Verification Plan に「実行不能時の理由+代替確認」行 + Scope 予防注記を追加 (owner:agent, files:docs/working/templates/plan.md, depends_on:T1, rollback:git checkout で plan.md 復元)
- [ ] T3 [S2] review-self.md に C1-SEC-01 + C1-SCOPE-DISC-01 を追加 + 件数更新 (owner:agent, files:docs/working/templates/review-self.md, depends_on:T1, rollback:git checkout で review-self.md 復元)
- [ ] T4 [S3] plan/review-self から既存正本（decision-log.jsonl / AGENT_LEARNINGS.md / `_audit/` / documentation-management.md）への参照リンク追記（役割分担 Done を参照で充足）(owner:agent, files:docs/working/templates/plan.md;docs/working/templates/review-self.md, depends_on:T2,T3, rollback:git checkout -- docs/working/templates/plan.md docs/working/templates/review-self.md で復元)
### 検証
- [ ] T5 新項目 grep / 件数整合 / 重複ゼロ確認 / markdownlint (owner:agent, depends_on:T2,T3,T4, rollback:不要・検証のみ)
### 完了
- [ ] T6 handoff.md 作成(6要素) (owner:agent, files:docs/working/TASK-0135/handoff.md, depends_on:T5, rollback:不要)

## 👤 Human タスク
- [ ] H1 C-3 承認（standard・Security 観点含むため安全側で人間 C-3 同期）(owner:human 🚩)
- [ ] H2 C-4 PR レビュー (owner:human)

## ⚠️ 依存
- T1 → T2/T3 → T4 → T5 → T6
- exec 開始は H1(C-3) 必須。HO 対象（AGENTS.md/.claude/rules）を**触らない**ため HO apply 不要。

## 📌 rollback 記法サンプル（#565 規約適用）
各タスクに rollback: を記載（standard だが #565 規約に準拠）。
