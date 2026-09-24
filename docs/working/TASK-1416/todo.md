# TASK-1416 EXECUTION TODO

## Mode

**モード**: critical

> workflow planning surfacesに触れるためcritical。production executionは#1337/#1359のhard dependency解消まで開始しない。

## 🤖 Agent タスク

### 1. 準備

- [ ] T-00: #1337 / #1359 / #894 / #1383 のfresh stateとmain差分を再確認する
  - Owner: agent
  - depends_on: なし
  - files: 読取: GitHub Issues #1337, #1359, #894, #1383 / current main
  - rollback: 不要（読取のみ）
  - 🚩 チェックポイント: #1337 pair-level result未固定、または#1359 Human C-3未完了ならproduction exec停止

- [ ] T-01: #1359 merge後のPlan / Skill / C-1 surfaceをinventoryし、#1416差分だけを抽出する
  - Owner: agent
  - depends_on: T-00
  - files: 読取: `docs/working/templates/plan.md`, `.agents/skills/ai-dev-plan/SKILL.md`, `docs/working/templates/review-self.md`, related mirrors
  - rollback: 不要（読取のみ）
  - 🚩 チェックポイント: duplicate responsibilityが見つかったらPlanをre-plan

- [ ] T-02: ai-loop handoffのcanonical ownerと#894/#1383 runtime boundaryをinventoryする
  - Owner: agent
  - depends_on: T-00
  - files: 読取: ai-loop V2 docs / #894 / #1383
  - rollback: 不要（読取のみ）
  - 🚩 チェックポイント: HO pathまたはruntime policy変更が必要なら停止

### 2. 実装

- [ ] T-03: AI Execution Readinessの6 dimensionsをcanonical planning guidanceへ差分統合する
  - Owner: agent
  - depends_on: T-01
  - files: `docs/ai/plan-design-principles.md`（T-00で最終確認）
  - rollback: commit revert
  - 🚩 チェックポイント: #1359と重複するAssumptions/Unknownsを再定義しない

- [ ] T-04: dependency readinessを declared / available / verified としてplanning guidanceへ追加する
  - Owner: agent
  - depends_on: T-03
  - files: `.agents/skills/ai-dev-plan/SKILL.md`（T-00で最終確認）
  - rollback: commit revert
  - 🚩 チェックポイント: fixed Human questionnaire化しない

- [ ] T-05: DetectabilityをREADY条件へ接続する
  - Owner: agent
  - depends_on: T-04
  - files: `.agents/skills/ai-dev-plan/SKILL.md`, `docs/working/templates/plan.md`
  - rollback: commit revert
  - 🚩 チェックポイント: verificationの存在ではなくfailure detection可能性を扱う

- [ ] T-06: Recovery / Escalation handoffをruntime owner参照として追加する
  - Owner: agent
  - depends_on: T-02,T-05
  - files: `docs/working/templates/plan.md`, confirmed handoff canonical doc
  - rollback: commit revert
  - 🚩 チェックポイント: #894/#1383のretry/convergence semanticsをコピーしない

- [ ] T-07: C-1/C-2へ最小統合する
  - Owner: agent
  - depends_on: T-05,T-06
  - files: `docs/working/templates/review-self.md`, relevant review guidance
  - rollback: commit revert
  - 🚩 チェックポイント: new C-1 check IDを追加しないことを優先

- [ ] T-08: canonical変更をdistribution mirrorsへ同期する
  - Owner: agent
  - depends_on: T-03,T-04,T-05,T-06,T-07
  - files: plugin/Codex mirrors confirmed by current sync tooling
  - rollback: commit revert
  - 🚩 チェックポイント: 手編集でdriftを作らず既存sync routeを使う

### 3. Fixture / 検証

- [ ] T-09: simple-ready fixtureを追加する
  - Owner: agent
  - depends_on: T-08
  - files: fixture path determined by current eval/test convention
  - rollback: commit revert
  - 🚩 チェックポイント: empty/N/A ceremonyが増えていない

- [ ] T-10: dependency-blocked fixtureを追加する
  - Owner: agent
  - depends_on: T-08
  - files: fixture path determined by current eval/test convention
  - rollback: commit revert
  - 🚩 チェックポイント: declaredだけではREADYにならない

- [ ] T-11: detection-missing fixtureを追加する
  - Owner: agent
  - depends_on: T-08
  - files: fixture path determined by current eval/test convention
  - rollback: commit revert
  - 🚩 チェックポイント: high-impact failure + detectorなし = READY不可

- [ ] T-12: recovery-required fixtureを追加する
  - Owner: agent
  - depends_on: T-08
  - files: fixture path determined by current eval/test convention
  - rollback: commit revert
  - 🚩 チェックポイント: retry/re-plan/stop/escalation boundary不足を検出

- [ ] T-13: C-1 count / mirror sync / stale reference / fixture期待値を検証する
  - Owner: agent
  - depends_on: T-09,T-10,T-11,T-12
  - files: 読取: modified canonical/mirror/fixture files
  - rollback: 不要（検証のみ）
  - 🚩 チェックポイント: driftまたはnew check ID発生時は修正して再検証

- [ ] T-14: full repository CI/test対象を実行する
  - Owner: agent
  - depends_on: T-13
  - files: 読取: repository test/config
  - rollback: 不要（検証のみ）
  - 🚩 チェックポイント: baseline外failureは原因分類してre-plan

### 4. 完了

- [ ] T-15: 実装後のAssumption / Unknown / Dependency readinessを再確認する
  - Owner: agent
  - depends_on: T-14
  - files: `docs/working/TASK-1416/plan.md`, evidence
  - rollback: 不要（記録のみ）
  - 🚩 チェックポイント: 新Blocking UnknownがあればPR readinessをblockedへ戻す

- [ ] T-16: status/current-state/INDEXとIssue #1416を更新する
  - Owner: agent
  - depends_on: T-15
  - files: `docs/working/TASK-1416/status.md`, `current-state.md`, `INDEX.md`, GitHub Issue #1416
  - rollback: 不要（記録のみ）
  - 🚩 チェックポイント: completion claimはevidenceと一致させる

## 👤 Human タスク

- [ ] H-01: #1337 / #1359 upstream gateの完了を確認し、TASK-1416 production execのC-3を判断する
  - Owner: human
  - depends_on: T-00
  - files: `docs/working/TASK-1416/approvals/c3.json`
  - rollback: 不要（判断のみ）
  - 🚩 チェックポイント: APPROVEDまでT-03以降を開始しない

- [ ] H-02: PR C-4レビュー
  - Owner: human
  - depends_on: T-16
  - files: GitHub PR
  - rollback: 不要（判断のみ）
  - 🚩 チェックポイント: mergeはHuman-owned

## ⚠️ 依存関係

```text
#1337 pair-level result
        ↓
#1359 T-00 + Human C-3 + production integration
        ↓
TASK-1416 T-00/T-01/T-02
        ↓
Human H-01
        ↓
T-03..T-08 implementation
        ↓
T-09..T-14 fixtures/verification
        ↓
T-15/T-16 evidence + handoff
        ↓
Human H-02
```
