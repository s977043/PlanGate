# EXECUTION TODO — TASK-0132 (#566)

## 🤖 Agent タスク
### 準備
- [ ] T1 plugin の2スキル + mode-classification マトリクス + WF-00 現状を精読 (owner:agent, files:docs/workflows, rollback:不要・読取のみ)
### 実装
- [ ] T2 [S1] .claude/skills/intent-classifier/SKILL.md 正本新設 (owner:agent, files:.claude/skills/intent-classifier/SKILL.md, depends_on:T1, rollback:新設ファイルを削除)
- [ ] T3 [S2] .claude/skills/skill-policy-router/SKILL.md 正本新設 + Mode別表を mode-classification 参照に置換 (owner:agent, files:.claude/skills/skill-policy-router/SKILL.md, depends_on:T1, rollback:新設ファイルを削除)
- [ ] T4 [S3] plugin 側2スキルを mirror 整合 + export 注記 (owner:agent, files:plugin/plangate/skills/intent-classifier/SKILL.md;plugin/plangate/skills/skill-policy-router/SKILL.md, depends_on:T2,T3,T6, rollback:plugin 2ファイルを git checkout で復元)
- [ ] T5 [S4] WF-00 に advisory 配線を文書化 (owner:agent, files:docs/workflows/00_*.md, depends_on:T2,T3, rollback:WF-00 追記を git checkout で復元)
- [ ] T6 [S5] lite_eligible 責務分界を router/skill に明記 (owner:agent, files:.claude/skills/intent-classifier/SKILL.md;.claude/skills/skill-policy-router/SKILL.md, depends_on:T2,T3, rollback:該当追記を git checkout で復元)
### 検証
- [ ] T7 正本↔mirror diff 一致 / router に Mode別表が無い grep / WF-00 advisory grep / doctor (owner:agent, depends_on:T4,T5,T6, rollback:不要・検証のみ)
### 完了
- [ ] T8 handoff.md 作成(6要素) (owner:agent, files:docs/working/TASK-0132/handoff.md, rollback:不要)

## 👤 Human タスク
- [ ] H1 C-3 承認（critical / Standard 同期・複数観点 C-2 推奨・exec 前ゲート） (owner:human 🚩)
- [ ] H2 C-4 PR レビュー (owner:human)

## ⚠️ 依存
- T1 → T2/T3 → T5 / T6 → T4 → T7
- exec 開始は H1(C-3) 必須。本 PBI は HO対象ファイル(.claude/rules / bin/plangate)を**触らない**ため HO apply は不要（mode-classification は参照のみ）。

## 📌 rollback 記法サンプル（#565 規約適用）
各タスクに `rollback:` を記載（critical のため必須）。
