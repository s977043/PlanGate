# PBI INPUT PACKAGE — TASK-0032

## メタ情報

```yaml
task: TASK-0032
related_issue: https://github.com/s977043/plangate/issues/57
author: human
phase: A（PBI INPUT PACKAGE）
created_at: 2026-04-26
```

## Context / Why（なぜやるか）

Phase 1（TASK-0029〜0031）完了後、PlanGate を「開発統制 OS」に拡張する Epic #53 の Phase 2 として実施する。

Phase 1 で Intent Classifier / Evidence Ledger / pg コマンド群の基盤が整備された。しかし「AIが完了を主張した = 実際に完了している」という曖昧な状態は依然として残っている。「動くはず」「たぶん通過した」という曖昧な完了主張を排除し、証拠に基づく Gate 通過を強制する仕組みが必要。

4 Gate システム（Design Gate / TDD Gate / Review Gate / Completion Gate）を定義し、Mode 別に適用条件を明確化することで、AIの自己申告に依存しない統制フローを実現する。

## What（Scope）

### In scope

- **Design Gate**: high-risk 以上のモードで設計なしに実装へ進むことを防ぐルール定義
- **TDD Gate**: failing test evidence を必須とするルール定義（pg-tdd.md + evidence-ledger 連携）
- **Review Gate**: critical finding を Completion Gate に伝達するルール定義
- **Completion Gate**: 全 Gate の通過を一元管理する最終チェックポイント定義
- **Mode 別 Gate マトリクス**: mode-classification.md に Gate 適用表を追加
- **Working Context**: TASK-0032 一式（pbi-input / plan / todo / test-cases / INDEX / current-state / handoff）

### Out of scope

- CI hook の自動化（GitHub Actions / pre-commit フック実装）
- TypeScript / JSON スキーマ実装
- 既存 handoff.md への遡及適用
- 4 Gate 以外の追加 Gate（例: Performance Gate、Security Gate）

## 受入基準

| AC-ID | 内容 |
|-------|------|
| AC-1 | high-risk 以上で Design Gate なしに実装へ進めない（completion-gate.md に明記） |
| AC-2 | critical で rollback plan なしに完了できない（completion-gate.md に明記） |
| AC-3 | TDD 必須モードで failing test evidence がない場合にブロックできる（pg-tdd.md + evidence-ledger 連携） |
| AC-4 | Review Gate で critical finding がある場合に Completion Gate が失敗する（review-gate.md + completion-gate.md 連携） |
| AC-5 | Evidence Ledger なしに Completion Gate が passed にならない（completion-gate.md に明記） |
| AC-6 | 軽微修正では Design/TDD/Review を過剰要求しない（mode-classification.md の Gate マトリクスで ultra-light/light は省略） |

## Notes from Refinement

- Phase A（Agent A: Design Gate、Agent B: TDD Gate + Review Gate）は実装済み
- Phase B（Agent C: Completion Gate + Mode マトリクス統合 + Working Context）が本チケット
- 4 Gate システムは Markdown 定義のみで V1 完了とする。CI 自動化は V2 以降
- `mode-classification.md` の「高」ラベルは TASK-0029 で `full` → `high-risk` にリネーム済み

## Estimation Evidence

| 項目 | 見積もり |
|------|---------|
| 変更ファイル数 | 8 件 |
| 受入基準数 | 6 件 |
| Mode 判定 | high-risk（機能追加、複数ファイル・複数レイヤーの変更） |

### Risks

- `mode-classification.md` 更新時に既存セクションを壊すリスク → セクション追加のみで対応
- `completion-gate.md` と `evidence-ledger.md` の整合性 → 参照関係を明示して管理

### Unknowns

- `/pg-verify` コマンドの詳細実装は TASK-0031 で確認済み

### Assumptions

- Phase A の 5 ファイル（design-gate.md / design-gate/SKILL.md / pg-tdd.md / review-gate.md / review-gate/SKILL.md）は実装済みで変更不要
