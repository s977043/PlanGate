# Parent Plan — PBI-XXX

> **Template**: PlanGate Orchestrator Mode 親 PBI 計画テンプレート
> 関連: [`docs/orchestrator-mode.md`](../../orchestrator-mode.md) / Issue #109
> 用途: `parent:draft` 〜 `parent:decomposition_approved` 段階で随時更新

## メタデータ

| 項目 | 値 |
|------|---|
| Parent PBI ID | PBI-XXX |
| Title | （親 PBI のタイトル）|
| Issue | (#XXXX) |
| Mode | high-risk / critical（推奨）|
| Owner | （担当 / 提案者）|
| Status | parent:draft / parent:analyzed / parent:decomposed / parent:decomposition_approved / parent:children_in_progress / parent:integration_review / parent:done |

## Goal

（親 PBI の最終目標を 1〜2 文で）

## Why（背景・目的）

（なぜこの PBI が必要か。ビジネス価値・問題設定・ステークホルダー）

## Acceptance Criteria（親レベル受入基準）

子 PBI の AC を集約しただけのものではなく、**親 PBI 単位でしか検証できない受入基準** を記述する。

- [ ] **parent-AC-1**: （例: 統合フローが端から端まで動作する）
- [ ] **parent-AC-2**: （例: 全機能を通して同一ユーザー体験が維持される）
- [ ] **parent-AC-3**: ...

## Constraints / Non-goals

### Constraints

- （技術的制約 / プロセス制約）

### Non-goals

- （明示的にこの親 PBI で扱わないもの）

## Approach Overview

子 PBI への分解戦略を 1 段落で説明。

例: 「ドメイン境界で分解。permission service を独立子 PBI 1 件、middleware 適用を子 PBI 2 件、UI 連携を子 PBI 3 件に分け、依存順に直列実行する」

## Children（子 PBI 一覧）

| ID | Title | Mode | Parallelizable | Depends on |
|----|-------|------|---------------|-----------|
| PBI-XXX-01 | （子 PBI 1 タイトル）| standard | true | — |
| PBI-XXX-02 | （子 PBI 2 タイトル）| standard | false | PBI-XXX-01 |
| PBI-XXX-03 | （子 PBI 3 タイトル）| light | true | PBI-XXX-01 |

各子 PBI の詳細は `children/PBI-XXX-NN.yaml` を参照。

## Integration Plan

統合チェックの代表項目（詳細は [`integration-plan.md`](./integration-plan.md)）:

- [ ] 子 PBI 間の API contract 整合性
- [ ] エンドツーエンドユーザーフロー
- [ ] パフォーマンス（累積影響）
- [ ] セキュリティ境界

## Risk

親 PBI レベルで集約したリスク（詳細は `risk-report.md`）:

| ID | Risk | Severity | Mitigation |
|----|------|----------|-----------|
| R1 | （例: 認証境界の変更が複数子 PBI に分散）| high | 親計画ゲート前に統合 design レビュー |
| R2 | ... | medium | ... |

## Gates（ゲート計画）

| Gate | 名称 | タイミング | 担当 |
|------|------|-----------|------|
| Parent C-3 | 親計画ゲート | `parent:decomposed` 後 | 👤 人間 |
| Child C-3 × N | 子 PBI 計画ゲート | 各子 PBI 単位 | 👤 人間 |
| Child C-4 × N | 子 PBI PR レビュー | 各子 PBI PR | 👤 人間（GitHub）|
| Parent Integration Gate | 統合ゲート | `parent:integration_review` 後 | 👤 人間 |

## Approvals

| Approval | File | Decision | Approver | Date |
|----------|------|---------|----------|------|
| Parent C-3 | `approvals/parent-c3.json` | (pending) | — | — |
| Parent Integration | `approvals/parent-integration.json` | (pending) | — | — |

## Status Log

| Date | Status | Note |
|------|--------|------|
| YYYY-MM-DD | parent:draft | 起票 |
| YYYY-MM-DD | parent:analyzed | Step D-1 完了 |
| YYYY-MM-DD | parent:decomposed | Step D-2 〜 D-6 完了、ゲート待機 |
| YYYY-MM-DD | parent:decomposition_approved | C-3 APPROVE |
| YYYY-MM-DD | parent:children_in_progress | 子 PBI exec 中 |
| YYYY-MM-DD | parent:integration_review | 統合確認中 |
| YYYY-MM-DD | parent:done | 統合ゲート APPROVE |

## References

- [`docs/orchestrator-mode.md`](../../orchestrator-mode.md) — 仕様正本
- [`docs/workflows/orchestrator-decomposition.md`](../../workflows/orchestrator-decomposition.md)
- [`docs/workflows/orchestrator-integration.md`](../../workflows/orchestrator-integration.md)
- [`docs/schemas/child-pbi.yaml`](../../schemas/child-pbi.yaml)
