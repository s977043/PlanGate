# EXECUTION TODO — TASK-0137 (#581 残要素3/4)

## 🤖 Agent タスク
### 準備
- [ ] T1 context-packager / subagent-dispatch / subagent-driven-development / review-gate / review-external / review-principles の現状精読（重複・HO確認）(owner:agent, files:plugin/plangate/skills/context-packager/SKILL.md;plugin/plangate/skills/review-gate/SKILL.md, rollback:不要・読取のみ)
### 実装（要素3）
- [ ] T2 [S1] docs/working/templates/dispatch/ に brief/report/review-package/progress-ledger テンプレ新設 (owner:agent, files:docs/working/templates/dispatch/task-NNN-brief.md;docs/working/templates/dispatch/task-NNN-report.md;docs/working/templates/dispatch/task-NNN-review-package.md;docs/working/templates/dispatch/progress-ledger.md, depends_on:T1, rollback:git rm -r docs/working/templates/dispatch)
- [ ] T3 [S2] context-packager に Allowed Context→dispatch/brief 保存工程を追記 (owner:agent, files:plugin/plangate/skills/context-packager/SKILL.md, depends_on:T2, rollback:git checkout -- plugin/plangate/skills/context-packager/SKILL.md)
- [ ] T4 [S3] subagent-dispatch / subagent-driven-development にファイルベース原則(progress-ledger再開)を明文化 (owner:agent, files:plugin/plangate/skills/subagent-dispatch/SKILL.md;.claude/skills/subagent-driven-development/SKILL.md, depends_on:T2, rollback:git checkout -- plugin/plangate/skills/subagent-dispatch/SKILL.md .claude/skills/subagent-driven-development/SKILL.md)
### 実装（要素4）
- [ ] T5 [S4] review-gate SKILL + review-external に Plan/Evidence/Production Readiness ブロック追加（§2-4不変）(owner:agent, files:plugin/plangate/skills/review-gate/SKILL.md;docs/working/templates/review-external.md, depends_on:T1, rollback:git checkout -- plugin/plangate/skills/review-gate/SKILL.md docs/working/templates/review-external.md)
### 検証
- [ ] T6 dispatch/ 存在 ls / SKILL grep / review-principles unchanged(git diff空) / qa-reviewer・plugin rules 未改変 / markdownlint (owner:agent, depends_on:T2,T3,T4,T5, rollback:不要・検証のみ)
### 完了
- [ ] T7 handoff.md 作成(6要素) (owner:agent, files:docs/working/TASK-0137/handoff.md, depends_on:T6, rollback:不要)

## 👤 Human タスク
- [ ] H1 C-3 承認（high-risk・複数skill+テンプレ群・人間C-3必須）(owner:human 🚩)
- [ ] H2 C-4 PR レビュー (owner:human)

## ⚠️ 依存
- T1 → T2 → T3/T4 / T1 → T5 → T6 → T7
- exec 開始は H1(C-3) 必須。HO 対象(.claude/rules/review-principles・qa-reviewer)を**触らない**(参照のみ)ため HO apply 不要。

## 📌 rollback 記法サンプル（#565 規約適用・high-risk のため必須）
各タスクに rollback: を対象明示で記載。
