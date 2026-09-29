# TASK-1416 EXECUTION TODO

## Mode

**モード**: critical

> #1416はworkflow planning surfacesを変更するためcritical。
> 本ファイルは現在 **planning-baseline phase**。production taskは推測で置かず、upstream unblock後のT-13で concrete Plan v2 / todo v2へ置き換える。

## A. Planning baseline / PR #1417

- [x] **T-01**: #1416 PBIをAI Execution Readiness projectionとして整理する
  - Owner: agent
  - depends_on: なし
  - files: docs/working/TASK-1416/pbi-input.md, plan.md
  - completion: six dimensionsが既存正本からのprojectionとして定義され、new gate/state subsystemを作らない
  - rollback: commit revert
  - 🚩 チェックポイント: Recovery / Escalationを新しいretry-policy正本にしない

- [x] **T-02**: readiness state semanticsを一意化する
  - Owner: agent
  - depends_on: T-01
  - files: docs/working/TASK-1416/pbi-input.md, plan.md, test-cases.md
  - completion: ready / needs_clarification / blocked の条件が定義され、fixed fixtureが単一期待値を持つ
  - rollback: commit revert
  - 🚩 チェックポイント: blocked or needs_clarification のような二値期待を残さない

- [x] **T-03**: Pre-C3 Replan GateとC-3物理依存を設計する
  - Owner: agent
  - depends_on: T-01
  - files: docs/working/TASK-1416/plan.md, todo.md
  - completion: production taskはPlan v2生成後のみ定義され、Human C-3 APPROVEDへtransitively依存する契約になっている
  - rollback: commit revert
  - 🚩 チェックポイント: narrative stop wordingだけでC-3を表現しない

- [x] **T-04**: Working Context / review artifact不足を補完する
  - Owner: agent
  - depends_on: T-01,T-02,T-03
  - files: docs/working/TASK-1416/INDEX.md, current-state.md, status.md, decision-log.jsonl, review-self.md, review-external.md
  - completion: L0/current-stateでBLOCKEDが見え、review artifactsがschema-valid、C-2 unavailable状態が独立性を偽装せず記録される
  - rollback: commit revert
  - 🚩 チェックポイント: same-maker multi-perspective reviewをindependent C-2として扱わない

- [x] **T-05**: corrected planning baselineをfresh検証する
  - Owner: agent
  - depends_on: T-01,T-02,T-03,T-04
  - files: 読取: docs/working/TASK-1416/**, PR #1417
  - completion: branch behind main=0、production planning surface diff=0、frontmatter schema整合、CI/Test/CodeQL/Issue Linkが全てSUCCESS
  - rollback: 不要（検証のみ）
  - 🚩 チェックポイント: green CIをsemantic correctnessの代替にしない

## B. Upstream unblock後の Pre-C3 Replan Gate

- [ ] **T-10**: #1337 / #1359 / #894 / #1383 のfresh stateとcurrent mainを再確認する
  - Owner: agent
  - depends_on: H-00
  - files: 読取: GitHub Issues #1337, #1359, #894, #1383 / current main
  - completion: EB-01 / EB-02の状態とevidenceが記録され、未解消ならBLOCKED維持
  - rollback: 不要（読取のみ）
  - 🚩 チェックポイント: #1337 result未固定または#1359 production integration未完了ならT-11以降を開始しない

- [ ] **T-11**: #1359後のproduction planning surfaceをinventoryし#1416 deltaを抽出する
  - Owner: agent
  - depends_on: T-10
  - files: 読取: docs/ai/plan-design-principles.md, .agents/skills/ai-dev-plan/SKILL.md, docs/working/templates/plan.md, docs/working/templates/review-self.md, distribution mirrors
  - completion: owner matrix更新、duplicate proposed change=0、#1416 production deltaが具体ファイル単位で確定
  - rollback: 不要（読取のみ）
  - 🚩 チェックポイント: #1359と責務競合する変更は削除またはre-plan

- [ ] **T-12**: ai-loop handoff canonical ownerをinventoryする
  - Owner: agent
  - depends_on: T-10
  - files: 読取: #894, #1383, repository searchで確定したai-loop V2 canonical docs
  - completion: handoff ownerが具体的pathで確定し、runtime policy ownerとの境界が記録される
  - rollback: 不要（読取のみ）
  - 🚩 チェックポイント: HO path / runtime policy変更が必要ならStop Condition

- [ ] **T-13**: Plan v2のproduction file map / responsibility mapを確定する
  - Owner: agent
  - depends_on: T-11,T-12
  - files: docs/working/TASK-1416/plan.md, decision-log.jsonl
  - completion: production files / canonical owner / interface boundaryが具体パスで固定され、duplicate owner=0
  - rollback: planning artifact commitをrevert
  - 🚩 チェックポイント: determined by / confirmed later / relevant file 等を残さない

- [ ] **T-14**: todo v2をconcrete production task graphへ更新する
  - Owner: agent
  - depends_on: T-13
  - files: docs/working/TASK-1416/todo.md
  - completion: production tasksが2-5分/reviewable unit、concrete files/rollback付き、全production taskがHuman H-01へtransitively依存、H-02 production C-4あり
  - rollback: planning artifact commitをrevert
  - 🚩 チェックポイント: narrative-only C-3 boundaryを許可しない

- [ ] **T-15**: test-cases v2へ具体command / exact expected value / traceを固定する
  - Owner: agent
  - depends_on: T-13
  - files: docs/working/TASK-1416/test-cases.md
  - completion: AC trace完全、fixture exact verdict、verification commands具体化、expected-value source記録
  - rollback: planning artifact commitをrevert
  - 🚩 チェックポイント:複数期待値・実行不能command・根拠なしexpected valueを残さない

- [ ] **T-16**: Plan v2にcanonical 25-item C-1を実行する
  - Owner: agent
  - depends_on: T-14,T-15
  - files: docs/working/TASK-1416/review-self.md
  - completion: 25 checks全件結果あり、schema-valid、FAIL=0、C1-TODO-09/C1-TODO-11がH-01依存を検証
  - rollback: review artifact更新をrevert
  - 🚩 チェックポイント: custom narrative reviewでC-1を代替しない

- [ ] **T-17**: Plan v2にindependent C-2を実行する
  - Owner: agent
  - depends_on: T-14,T-15
  - files: docs/working/TASK-1416/review-external.md
  - completion: independent reviewer実行済み、latest Plan v2対象、unresolved critical/major=0
  - rollback: review artifact更新をrevert
  - 🚩 チェックポイント: unavailableの場合はWARN記録してH-01へ進まない

## 👤 Human タスク

- [ ] **H-00**: planning baseline PR #1417 C-4レビュー
  - Owner: human
  - depends_on: T-05
  - files: GitHub PR #1417
  - completion: planning baselineのみをAPPROVE / REQUEST CHANGES / REJECT。APPROVEしてもproduction execは許可しない
  - rollback: 不要（判断のみ）
  - 🚩 チェックポイント: merge = planning baselineの確定でありC-3ではない

- [ ] **H-01**: production Plan v2 C-3
  - Owner: human
  - depends_on: T-16,T-17
  - files: docs/working/TASK-1416/approvals/c3.json
  - completion: latest Plan v2 hashに対して APPROVE / CONDITIONAL / REJECT を記録。APPROVEDのみproduction exec可
  - rollback: 不要（判断のみ）
  - 🚩 チェックポイント: T-13で生成したtodo v2のproduction tasksはH-01 APPROVEDへ依存する

## ⚠️ 依存関係

### Planning baseline

T-01 -> T-02
T-01 -> T-03
T-01,T-02,T-03 -> T-04 -> T-05 -> H-00 planning C-4

### Production transition

H-00 planning baseline merge
  -> #1337 pair-level result fixed
  -> #1359 production integration complete
  -> T-10 fresh dependency check
  -> T-11 production surface inventory
  -> T-12 handoff inventory
  -> T-13 Plan v2 file/owner map
  -> T-14 todo v2 graph + T-15 test-cases v2
  -> T-16 canonical C-1 + T-17 independent C-2
  -> H-01 Human C-3
  -> concrete production tasks in todo v2
  -> H-02 production C-4

> **Iron Law**: current planning baseline contains no executable production task. Production tasks must be created by T-13 with concrete paths/commands and must depend on H-01 APPROVED before execution.
