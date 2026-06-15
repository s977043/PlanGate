# EXECUTION TODO — TASK-0130 (#544 Phase1)

## 🤖 Agent タスク

### 準備

- [ ] T1 rev.3 §3 スキーマと ai-driven-development.md Prompt1 の現状 diff を確認 (owner:agent)

### 実装

- [ ] T2 [S1] ai-driven-development.md に条項6欄 + Verification強化 + honest framing 追加 (owner:agent, files:docs/ai-driven-development.md)
- [ ] T3 [S2] working-context.md 追記の apply-script+patch を生成(AI編集しない) (owner:agent, depends_on:T1 🚩HO)
- [ ] T4 [S3] plan-quality-check SKILL + review-self.md に C-1 検出2項目追加 (owner:agent, depends_on:T2)
- [ ] T5 [S4] ai-dev-plan SKILL 参照行の追従確認 (owner:agent, depends_on:T2)

### 検証

- [ ] T6 markdownlint + doctor + grep 突合(TC-01〜07) (owner:agent, depends_on:T2,T4)

### 完了

- [ ] T7 handoff.md 作成(6要素) (owner:agent)

## 👤 Human タスク

- [ ] H1 C-3 承認(high-risk/Standard同期・exec前ゲート) (owner:human 🚩)
- [ ] H2 working-context.md の apply-script 実行(HO適用) (owner:human 🚩)
- [ ] H3 C-4 PRレビュー (owner:human)

## ⚠️ 依存

- T2 → T4/T5 → T6
- exec開始は H1(C-3) 必須 / S2反映は H2(HO適用) 必須
- AC-03/TC-03 の検証は H2(人間 apply)後に実施(それ以前は PASS にできない)
