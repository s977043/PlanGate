# TASK-0022 EXECUTION TODO

> 生成日: 2026-04-20
> PBI: [TASK-0021-A] Workflow 5 phase を定義する（WF-01〜WF-05）
> モード: full（C-2 EX-01 対応で standard → full に再分類）

## 🤖 Agent タスク

### Phase 1: 準備

- [ ] **T-1**: ブランチ作成 `docs/TASK-0022-workflow-phases-definition`（main から / EX-04 対応で repo 既存命名規則に準拠）
  - Owner: agent
  - 🚩: ブランチがローカル + remote に作成される

- [ ] **T-2**: `docs/workflows/` ディレクトリ新設
  - Owner: agent
  - depends_on: T-1
  - 🚩: ディレクトリが存在する

### Phase 2: 実装（TDD）

- [ ] **T-3**: `docs/workflows/01_context_bootstrap.md` 作成
  - Owner: agent
  - depends_on: T-2
  - 🚩: 必須6項目（目的 / 入力 / 完了条件 / 呼び出しSkill / 主担当Agent / 次phaseへの引き継ぎ）が全て含まれる

- [ ] **T-4**: `docs/workflows/02_requirement_expansion.md` 作成
  - Owner: agent
  - depends_on: T-2
  - 🚩: 必須6項目を含む、呼び出す Skill が `requirement-gap-scan` / `nonfunctional-check` / `edgecase-enumeration` / `acceptance-criteria-build` を含む

- [ ] **T-5**: `docs/workflows/03_solution_design.md` 作成
  - Owner: agent
  - depends_on: T-2
  - 🚩: 必須6項目を含む、呼び出す Skill が `architecture-sketch` / `risk-assessment` を含む

- [ ] **T-6**: `docs/workflows/04_build_and_refine.md` 作成
  - Owner: agent
  - depends_on: T-2
  - 🚩: 必須6項目を含む、呼び出す Skill が `feature-implement` を含む

- [ ] **T-7**: `docs/workflows/05_verify_and_handoff.md` 作成
  - Owner: agent
  - depends_on: T-2
  - 🚩: 必須6項目を含む、呼び出す Skill が `acceptance-review` / `known-issues-log` を含む

- [ ] **T-8**: `docs/workflows/README.md` 作成
  - Owner: agent
  - depends_on: T-3〜T-7
  - 🚩:
    - 5 phase の目次がある
    - PlanGate 既存フェーズとの対応表が含まれる
    - 親 PBI の実行シーケンスが記載される

### Phase 3: 検証

- [ ] **T-9**: Rule 1 準拠セルフチェック（禁止単語検出）
  - Owner: agent
  - depends_on: T-3〜T-7
  - Output: `docs/working/TASK-0022/evidence/rule1-compliance-check.md`
  - 🚩: 禁止単語（手順 / 実施する / 実行する / How to / Steps）が完了条件セクションに出現しない

- [ ] **T-10**: 既存ドキュメント整合確認
  - Owner: agent
  - depends_on: T-3〜T-8
  - Output: `docs/working/TASK-0022/evidence/consistency-check.md`
  - 🚩: `docs/plangate.md` / `docs/plangate-v6-roadmap.md` との矛盾なし、または矛盾点が記録されフォロー方針が明記

- [ ] **T-11**: markdown lint 検証
  - Owner: agent
  - depends_on: T-3〜T-8
  - 🚩: lint がエラーなしで通る

### Phase 4: 完了

- [ ] **T-12**: コミット（`feat(workflow): WF-01〜WF-05 phase 定義を追加`）
  - Owner: agent
  - depends_on: T-9〜T-11
  - 🚩: 変更が全てステージされコミット成功

- [ ] **T-13**: push + PR 作成
  - Owner: agent
  - depends_on: T-12
  - 🚩: PR が作成され、親 Issue #22 / サブ Issue #23 が参照される

- [ ] **T-14**: status.md 更新（完了記録）
  - Owner: agent
  - depends_on: T-13
  - 🚩: `docs/working/TASK-0022/status.md` が「PR 作成完了・C-4 ゲート待ち」状態

## 👤 Human タスク

### C-3 ゲート（plan 承認 / 三値）

- [ ] **H-1**: `plan.md` / `todo.md` / `test-cases.md` / `review-self.md` を確認
- [ ] **H-2**: 三値判断
  - APPROVE: agent が T-1 から開始
  - CONDITIONAL: 指摘反映 + 簡易 C-1 再実行 → APPROVE
  - REJECT: plan 再生成

### C-4 ゲート（PR レビュー / 三値）

- [ ] **H-3**: GitHub 上で PR をレビュー
- [ ] **H-4**: 三値判断
  - APPROVE: マージ → Done
  - REQUEST CHANGES: 指摘に基づき exec から再実行
  - REJECT: plan からやり直し

## ⚠️ 依存関係

```text
[Human: H-1 → H-2 (C-3 ゲート)]
    ↓ APPROVE
[Agent: T-1 → T-2 → T-3〜T-7 (並行) → T-8 → T-9/T-10/T-11 (並行) → T-12 → T-13 → T-14]
    ↓
[Human: H-3 → H-4 (C-4 ゲート)]
```

## 🚩 チェックポイント総括

| タイミング | 確認内容 |
|---|---|
| C-3 前 | Rule 1 準拠の作業計画か、完了条件が状態形式か |
| T-3〜T-7 各完了時 | 必須6項目の存在、Skill / Agent 名の整合 |
| T-9 完了時 | 禁止単語の非出現 |
| T-10 完了時 | 既存ドキュメントとの矛盾なし |
| T-11 完了時 | markdown lint 通過 |
| C-4 前 | PR 本文に受入基準チェックリスト、親 / サブ issue 参照 |

## Iron Law 遵守

- **NO EXECUTION WITHOUT REVIEWED PLAN**: C-3 ゲート APPROVE 後のみ T-1 開始
- **NO SCOPE CHANGE WITHOUT USER APPROVAL**: In scope 外の変更があれば停止してユーザー確認
- **NO COMPLETION CLAIMS WITHOUT EVIDENCE**: T-9/T-10 の evidence が status.md で参照可能
