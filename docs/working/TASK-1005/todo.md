# EXECUTION TODO — TASK-1005

> Plan: [`plan.md`](./plan.md) / Test Cases: [`test-cases.md`](./test-cases.md)
> Mode: **high-risk**（開発フローと Human approval boundary を扱うため C-3 必須）

## 依存関係

```text
T-01 現行正本・label・milestone 実測
  ├─→ T-02 Admission Control 正本
  ├─→ T-03 RR1 committed candidate 表
  └─→ T-04 Issue writeback

T-02 + T-03 + T-04
  └─→ T-05 C-2 review
        └─→ H-01 Human C-3
              ├─→ 個別 #921 plan/exec
              └─→ T-06 2-cycle measurement 開始

#921 + negative controls >= 2 + Human C-3
  └─→ #978 vertical slice
```

## Human Tasks

- [ ] **H-01**: TASK-1005 の C-3 判断
- [ ] **H-02**: milestone 9 の Committed を 6〜8 件へ確定
- [ ] **H-03**: lifecycle label を既存ラベルで表現するか新設するか決定
- [ ] **H-04**: #942 の HO workflow patch を適用し test PR を実行
- [ ] **H-05**: 各実装 PR の C-4 / merge
- [ ] **H-06**: 2 cycle 後の WIP limit を keep / decrease / increase で判断

## Agent Tasks

### Planning / Governance

- [ ] **T-01: 現行 governance 正本を実測**
  - issue governance / label / milestone / DoD / handoff の正本パスを検索
  - lifecycle state と衝突する既存用語を列挙
  - milestone 9 の Issue を取得し、Committed 候補と Backlog 候補を Human review 用に分離
  - 既存データを変更しない
  - Evidence: `status.md`

- [ ] **T-02: Admission Control 正本を作成**
  - Discovery / Qualified / Committed の entry / promotion / owner / forbidden action
  - WIP limits と stop / emergency interrupt / decommit rule
  - Discovery Log template
  - scope split record
  - completion class と Issue writeback template
  - priority / milestone / lifecycle の責務分離
  - Markdown lint / link check

- [ ] **T-03: Reliability Recovery 1 candidate を固定**
  - target 6、maximum 8
  - first slot: #921
  - observation fidelity: #997 / #994 を優先候補
  - set symmetry: #991 / #970 は file conflict と root cause を再確認して commit/PR 単位決定
  - HO CI: #942 は Human handoff slot
  - vertical slice: #978
  - #947 は relative-state / accounting / cleanup を分離し、同一 PR へ無条件統合しない

- [ ] **T-04: 既存 Issue へ execution contract を writeback**
  - #921: first dependency / standalone + source negative control
  - #997: content-hash before/after / mutation
  - #994: target condition parser / mutation
  - #942: Human HO / real PR negative test
  - #978: start gate / source provenance / non-goals
  - 各 comment に #1005 link を含める

### Review / Approval

- [ ] **T-05: C-2 独立レビュー**
  - lane 1: agile flow / WIP / admission control
  - lane 2: test architecture / negative control
  - lane 3: approval boundary / fail-closed
  - 同一指摘の収斂、推測指摘の実測、採否を記録
  - `review-external.md` を作成

- [ ] **T-05b: C-1 更新**
  - 現行正本パスと label collision unknown を解消
  - plan readiness を再判定
  - `review-self.md` を作成

- [ ] **T-05c: C-3 package 作成**
  - pbi-input / plan / todo / test-cases / review-self / review-external
  - Human decision points を1ページで提示
  - AI は approval artifact を発行しない

### Post-approval measurement

- [ ] **T-06: 2-cycle status ledger**
  - queue entered_at / exited_at
  - Human wait / active work
  - completion class
  - follow-up origin
  - negative-control evidence
  - WIP exceed time

- [ ] **T-07: Cycle 1 review**
  - #921 完了状況
  - negative control 2クラスの成立
  - #978 start gate 判定
  - 新規 finding の promotion 違反確認

- [ ] **T-08: Cycle 2 review**
  - C-3/C-4 wait distribution
  - fully satisfied close / partial / follow-up ratio
  - WIP limit の変更提案
  - Human H-06 へ提出

## Stop / Escalation

- [ ] lifecycle label や milestone を一括更新する前に停止し Human 承認
- [ ] `.github/workflows/**`, `.claude/rules/**`, settings, hooks の apply 前に停止
- [ ] C-3 前の code implementation を禁止
- [ ] #978 が #906/#916 を必要とした場合は停止して replan
- [ ] negative control が修正前を落とせない場合は実装を進めず test design を修正
- [ ] WIP limit 到達時は新規 start ではなく review / unblock / writeback を優先

## Completion Checklist

- [ ] AC-01〜AC-12 が test-cases.md で PASS
- [ ] C-2 指摘が反映または理由付き却下
- [ ] Human C-3
- [ ] Issue writeback 5件
- [ ] 2 cycle の metric ledger
- [ ] WIP limit 再評価の Human decision
