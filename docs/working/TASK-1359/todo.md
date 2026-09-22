# TASK-1359 EXECUTION TODO

## Mode

**モード**: critical

## 🤖 Agent タスク

### 0. Evaluation-order dependency

- [ ] T-00: #1337 paired evaluation result固定を確認する
  - Owner: agent
  - depends_on: #1337 result fixed
  - progress: PR #1364 execution freeze merged; protocol/config/input/smoke contract fixed
  - files: 読取: #1337 / PR #1364 / smoke evidence / 48-run raw evidence / blind scoring / final pair-level decision
  - completion: #1337の3-call smoke・48 generations・blind scoringが完了し、最終pair-level判定とdownstream decisionを確認してTASK-1359 replan要否をdecision-logへ記録する
  - rollback: 不要
  - 🚩 チェックポイント: regression / no-effect / guidance変更があればT-03以降を開始せずreplan

### 1. 準備

- [x] T-01: #1358 merge後にmainへrebaseする
  - Owner: agent
  - depends_on: #1358 merge
  - files: repository branch
  - completion: branchが#1358およびPR #1364 merge後のlatest mainをbaseに持ち、shared filesのconflictが解消されている
  - rollback: rebase前branch SHAへ戻す
  - 🚩 チェックポイント: conflictがshared skill/templateに出たらreplan

- [x] T-02: rebase後のreview責務境界を再確認する
  - Owner: agent
  - depends_on: T-01
  - files: 読取: `.agents/skills/diff-audit/SKILL.md`, `.agents/skills/review-gate/SKILL.md`
  - completion: diff-audit/review-gateの責務境界が再確認され、Plan修正不要またはreplan済み
  - rollback: 不要
  - 🚩 チェックポイント: `diff-audit`=generic pre-PR / `review-gate`=independent completion review が崩れていたらreplan

### 2. Plan生成契約

- [ ] T-03: plan templateへPrior Artifact ImpactとReadiness構造を追加する
  - Owner: agent
  - depends_on: H-01, T-02
  - files: `docs/working/templates/plan.md`
  - completion: plan templateでPrior Artifact / Unknown / Readinessを条件付き表現できる
  - rollback: T-03 commitをrevert
  - 🚩 チェックポイント: low-riskで空section必須化になっていないか確認

- [ ] T-04: Prompt 1正本へrepository-first / Unknown classificationを反映する
  - Owner: agent
  - depends_on: T-03
  - files: `docs/ai-driven-development.md`
  - completion: Prompt 1正本がtemplateと同じ語彙・repository-first規則を持つ
  - rollback: T-04 commitをrevert
  - 🚩 チェックポイント: templateと正本の語彙が一致すること

- [ ] T-05: ai-dev-planへprior-artifact discovery / blocking readinessを反映する
  - Owner: agent
  - depends_on: T-04
  - files: `.agents/skills/ai-dev-plan/SKILL.md`
  - completion: ai-dev-planがsame-TASK inventoryとBlocking Unknown readinessを実行可能に記述する
  - rollback: T-05 commitをrevert
  - 🚩 チェックポイント: generic Unknown subsystemを新設しない

### 3. Knowledge Delta

- [ ] T-06: plan templateへconditional Knowledge Deltaを追加する
  - Owner: agent
  - depends_on: T-03
  - files: `docs/working/templates/plan.md`
  - completion: Knowledge Deltaがtrigger時のみPlanへ出力され、非該当時は省略できる
  - rollback: T-06 commitをrevert
  - 🚩 チェックポイント: trigger非該当時はsection省略可能

- [ ] T-07: Prompt 1正本へKnowledge Delta trigger / skip / change separationを反映する
  - Owner: agent
  - depends_on: T-06
  - files: `docs/ai-driven-development.md`
  - completion: Prompt 1正本がKnowledge Delta / change separationを重複なく定義する
  - rollback: T-07 commitをrevert
  - 🚩 チェックポイント: #794 / existing refactor evidenceを重複定義しない

- [ ] T-08: ai-dev-planへCharacterization / Preparatory Refactoring順序を反映する
  - Owner: agent
  - depends_on: T-07
  - files: `.agents/skills/ai-dev-plan/SKILL.md`
  - completion: ai-dev-planがsafe refactor orderingとdeferred structural workを実行規範化する
  - rollback: T-08 commitをrevert
  - 🚩 チェックポイント: Red baselineからstructural changeを許可しない

### 4. Review統合

- [ ] T-09: C1-B1B2-16 / C1-PLAN-02 / C1-PLAN-03 / C1-PLAN-06へconformance観点を統合する
  - Owner: agent
  - depends_on: T-05, T-08
  - files: `docs/working/templates/review-self.md`
  - completion: 4既存checkでconformanceを確認でき、C-1 heading count不変、#1358所有のC1-TEST-14は変更0
  - rollback: T-09 commitをrevert
  - 🚩 チェックポイント: 新check_id追加禁止 / C1-TEST-14変更禁止 / heading count不変

- [ ] T-10: diff-auditへPlan-time Unknown / Assumption / Knowledge Delta再検査を追加する
  - Owner: agent
  - depends_on: T-02, T-08
  - files: `.agents/skills/diff-audit/SKILL.md`
  - completion: diff-auditがPlan-time Unknown/Assumption/Knowledge DeltaをPR前に再検査できる
  - rollback: T-10 commitをrevert
  - 🚩 チェックポイント: review-gateの独立review責務を取り込まない

### 5. Distribution / Fixtures

- [ ] T-11: canonical skill/template変更を既存sync経路で配布派生へ反映する
  - Owner: agent
  - depends_on: T-05, T-08, T-09, T-10
  - files: plugin/Codex mirrors
  - completion: canonicalとplugin/Codex派生のsync driftが0
  - rollback: sync commitをrevert
  - 🚩 チェックポイント: 手編集でしか揃わない派生があれば停止

- [ ] T-12: simple / prior-artifact fixtureを追加する
  - Owner: agent
  - depends_on: T-05, T-08
  - files: `examples/eval-fixtures/**`
  - completion: simple/prior-artifact fixtureが正負の期待挙動を固定している
  - rollback: T-12 commitをrevert
  - 🚩 チェックポイント: simple caseで儀式的sectionが増えないこと

- [ ] T-13: blocking-unknown / knowledge-delta fixtureを追加する
  - Owner: agent
  - depends_on: T-05, T-08, T-10
  - files: `examples/eval-fixtures/**`
  - completion: blocking-unknown/knowledge-delta fixtureがstop/structural orderingを固定している
  - rollback: T-13 commitをrevert
  - 🚩 チェックポイント: blocked caseをready扱いしない

### 6. 検証

- [ ] T-14: C-1 count / #1358 compatibility / stale refs / sync driftを検証する
  - Owner: agent
  - depends_on: T-09, T-11, T-12, T-13
  - files: 読取: repository
  - completion: C-1 count不変、C1-TEST-14が#1358 merge後baselineから不変、stale ref 0、sync dry-run no changes
  - rollback: 不要
  - 🚩 チェックポイント: C-1 heading countがbaselineから変化したらFAIL

- [ ] T-15: full test / CI相当検査を実行する
  - Owner: agent
  - depends_on: T-14
  - files: 読取: repository
  - completion: full testsが0 failedで、CI相当検査に新規FAILがない
  - rollback: 不要
  - 🚩 チェックポイント: baseline由来でないFAILは修正して再実行

### 7. 完了

- [ ] T-16: review結果・残存risk・HO follow-up有無をTASK記録へ反映する
  - Owner: agent
  - depends_on: T-15
  - files: `docs/working/TASK-1359/**`
  - completion: review結果・残risk・follow-upがTASK記録に残りPR-ready可否が明示されている
  - rollback: 不要
  - 🚩 チェックポイント: critical/major未解決ならPR readyにしない

## 👤 Human タスク

- [ ] H-01: C-3 critical-mode Plan承認
  - Owner: human
  - depends_on: T-00, T-01, T-02
  - files: `docs/working/TASK-1359/approvals/c3.json`
  - completion: HumanのC-3 APPROVED記録が存在し、承認対象plan hashが確定している
  - rollback: 不要
  - 🚩 チェックポイント: APPROVEDまでT-03以降を開始しない

- [ ] H-02: C-4 PR review / merge
  - Owner: human
  - depends_on: T-16
  - files: GitHub PR
  - completion: HumanがPRをAPPROVE/REQUEST CHANGES/REJECTし、merge判断を行っている
  - rollback: 不要
  - 🚩 チェックポイント: mergeはHuman-owned

## ⚠️ 依存関係

| タスク | depends_on | 種別 | 備考 |
|---|---|---|---|
| T-00 | #1337 result fixed | Eval | frozen candidateを汚染しない |
| T-01 | #1358 merge | Repo | shared skill/templateの競合回避 |
| H-01 | T-00, T-01, T-02 | Agent/Eval → Human | #1337固定後のみC-3 |
| T-03 | H-01 | Human → Agent | critical C-3 |
| T-09 | T-05, T-08 | Agent | planning guidance確定後にreviewへ反映 |
| T-10 | T-02, T-08 | Agent | diff-audit境界再確認後 |
| T-11 | T-05, T-08, T-09, T-10 | Agent | canonical完成後だけsync |
| H-02 | T-16 | Agent → Human | review完了後 |
