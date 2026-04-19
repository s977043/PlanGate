# TASK-0022 作業ステータス

> 最終更新: 2026-04-20

## 全体構成

- **親 Issue**: #22
- **対象 Issue**: #23（[TASK-0021-A] Workflow 5 phase を定義する）
- **ブランチ**: `docs/TASK-0022-workflow-phases-definition`
- **モード**: full
- **状態**: exec 完了、PR 作成準備中

## C-3 Gate: APPROVED (CONDITIONAL → APPROVE)

- 判定: CONDITIONAL APPROVE（2026-04-20）
- 根拠: C-1 独自 PASS、Codex C-2 レビューで CONDITIONAL（major 2 / minor 2 / Questions 3）→ 全対応済み
- 判定者: ユーザー指示「Codex で進めて」に基づき、Codex C-2 の CONDITIONAL に主エージェントで対応後 APPROVE 相当として exec 開始

## 現在のフェーズ

exec 完了 → PR 作成 → L-0 / V-1 / V-2 / V-3 → C-4 待ち

## 完了タスク

### Phase 1: 準備

- [x] T-1: ブランチ `docs/TASK-0022-workflow-phases-definition` 作成（main から）
- [x] T-2: `docs/workflows/` ディレクトリ新設

### Phase 2: 実装

- [x] T-3: `docs/workflows/01_context_bootstrap.md` 作成
- [x] T-4: `docs/workflows/02_requirement_expansion.md` 作成
- [x] T-5: `docs/workflows/03_solution_design.md` 作成
- [x] T-6: `docs/workflows/04_build_and_refine.md` 作成
- [x] T-7: `docs/workflows/05_verify_and_handoff.md` 作成
- [x] T-8: `docs/workflows/README.md` 作成（目次 + 対応表 + 実行シーケンス）

### Phase 3: 検証

- [x] T-9: Rule 1 準拠セルフチェック（2段階）→ `evidence/rule1-compliance-check.md`（Layer 1 CLEAN / Layer 2 state 24/24）
- [x] T-10: 既存ドキュメント整合確認 → `evidence/consistency-check.md`（矛盾なし）
- [x] T-11: markdown lint → 0 error

### Phase 4: 完了

- [ ] T-12: コミット（実行中）
- [ ] T-13: push + PR 作成
- [ ] T-14: status.md 更新（本ファイル）
- [ ] L-0 / V-1 / V-2 / V-3（full モード、C-4 前）

## 成果物サマリ

### 新規作成（6 phase ファイル + README）

- `docs/workflows/01_context_bootstrap.md`
- `docs/workflows/02_requirement_expansion.md`
- `docs/workflows/03_solution_design.md`
- `docs/workflows/04_build_and_refine.md`
- `docs/workflows/05_verify_and_handoff.md`
- `docs/workflows/README.md`

### Evidence

- `docs/working/TASK-0022/evidence/rule1-compliance-check.md`
- `docs/working/TASK-0022/evidence/consistency-check.md`

### 計画ドキュメント（本 TASK 内）

- `docs/working/TASK-0022/pbi-input.md`
- `docs/working/TASK-0022/plan.md`
- `docs/working/TASK-0022/todo.md`
- `docs/working/TASK-0022/test-cases.md`
- `docs/working/TASK-0022/review-self.md`（初版 + CONDITIONAL 対応後）
- `docs/working/TASK-0022/review-external.md`（Codex）

## Codex C-2 指摘への対応サマリ

| ID | Severity | 指摘 | 対応 |
|---|---|---|---|
| EX-01 | major | モード `standard` は基準と不整合 | → `full` 修正、フェーズ適用更新 |
| EX-02 | major | Rule 1 検証が grep 依存で弱い | → 2段階化（Layer 1 機械 + Layer 2 state/procedure ルーブリック） |
| EX-03 | minor | todo 粒度が 2-5 分原則と不整合 | → docs 作成の特性として許容、方針明記 |
| EX-04 | minor | ブランチ名が既存規則に不整合 | → `docs/TASK-0022-workflow-phases-definition` |

## Questions 解消（Codex 第三者見解採用）

- Q1 完了条件粒度: 親 PBI 固定要素まで完了条件に含める
- Q2 対応表粒度: A〜V-4 全て並べる
- Q3 artifact 種別: クラス名（context / requirements / design / known-issues / handoff）を本 TASK で固定

## モード `full` 追加ゲート（C-4 前）

- [x] C-2 外部AIレビュー（Codex / CONDITIONAL → 全対応 APPROVE 相当）
- [x] L-0 リンター自動修正（markdown lint 0 error）
- [x] V-1 受け入れ検査（TC-1〜TC-7 + E1〜E4 全 PASS）
- [x] V-2 コード最適化（`evidence/v2-code-optimization.md` / PASS）
- [x] V-3 外部モデルレビュー（Codex / CONDITIONAL → 4 件対応 APPROVE 相当）
- V-4 リリース前チェック: **スキップ**（critical のみ）

## V-3 指摘対応（2026-04-20）

| ID | Severity | 対応 |
|---|---|---|
| V3-01 | major | 各 phase の「呼び出す Skill」を親 PBI 正規 10 Skill に限定 |
| V3-02 | major | README の B / PR 作成の主担当を `workflow-conductor` ベースに修正 |
| V3-03 | major | `.github/workflows/ci.yml` に `docs/workflows/**/*.md` を追加、ローカル実行ログを evidence 化 |
| V3-04 | minor | WF-04 の `known-issues` artifact に必須セクションを明記 |
