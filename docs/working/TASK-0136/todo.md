# EXECUTION TODO — TASK-0136 (#579)

## 🤖 Agent タスク
### 準備
- [ ] T1 design-ui-addendum.md / plan.md / review-self.md / design.md の現状精読（重複確認）(owner:agent, files:docs/ai/design-ui-addendum.md;docs/working/templates/plan.md;docs/working/templates/review-self.md;docs/working/templates/design.md, rollback:不要・読取のみ)
### 実装
- [ ] T2 [S1] design-ui-addendum.md に states(6)/design token/component再利用+variant/a11y + 提案扱いルール + DESIGN.md参照方針を追記し、design.md 視覚設計テーブルにも 4 観点を反映 (owner:agent, files:docs/ai/design-ui-addendum.md;docs/working/templates/design.md, depends_on:T1, rollback:git checkout -- docs/ai/design-ui-addendum.md docs/working/templates/design.md)
- [ ] T3 [S2] plan.md に is_ui_task 条件付き UI チェック注記 (owner:agent, files:docs/working/templates/plan.md, depends_on:T1, rollback:git checkout -- docs/working/templates/plan.md)
- [ ] T4 [S3] review-self.md に C1-UI-01（条件付き・N/A許容）+ 件数注記 (owner:agent, files:docs/working/templates/review-self.md, depends_on:T1, rollback:git checkout -- docs/working/templates/review-self.md)
### 検証
- [ ] T5 grep（4観点/提案扱い/C1-UI-01）+ 新SKILL/rule未作成 find + 重複ゼロ + markdownlint (owner:agent, depends_on:T2,T3,T4, rollback:不要・検証のみ)
### 完了
- [ ] T6 handoff.md 作成(6要素) (owner:agent, files:docs/working/TASK-0136/handoff.md, depends_on:T5, rollback:不要)

## 👤 Human タスク
- [ ] H1 C-3 承認（standard・UI デザイン観点）(owner:human 🚩)
- [ ] H2 C-4 PR レビュー (owner:human)

## ⚠️ 依存
- T1 → T2/T3/T4 → T5 → T6
- exec 開始は H1(C-3) 必須。HO 対象（bin/plangate / .claude/rules）を**触らない**ため HO apply 不要。

## 📌 rollback 記法サンプル（#565 規約適用）
各タスクに rollback: を記載。
