---
task_id: TASK-0081
artifact_type: test-cases
schema_version: 1
status: draft
---

# テストケース定義 — TASK-0081

| AC | TC |
|----|----|
| AC-1 | TC-1 |
| AC-2 | TC-2 |
| AC-3 | TC-3 |
| AC-4 | TC-4 |
| AC-5 | TC-5 |
| AC-6 | TC-6 |

## テストケース
- **TC-1**: `.claude/rules/responsibility-classes.md` が存在し AI/Human/CI/Workflow-owned の4分類と各境界を定義
- **TC-2**: 各クラスに具体例（settings適用=Human / settings-drift=CI / handoff=Workflow / 実装=AI 等）が記載
- **TC-3**: 既存ルール（hybrid Rule1-5 / orchestrator-mode / working-context タスクロック / mode-classification lite_eligible）との対応表が存在
- **TC-4**: hybrid-architecture.md に responsibility-classes.md への参照が追加（重複定義なし）
- **TC-5**: settings-wiring-contract 責務分離表 / TASK-0077 AC-4 と矛盾しない（突合 OK）
- **TC-6**: 既存ルール本文の責務記述が改変されていない（hybrid=参照1行追加のみ・他 rules diff ゼロ）+ hook 78/0

## エッジケース
- E1: merge は Human-owned 固定（sockpuppet 禁止と一貫）が明記
- E2: settings 実適用=Human / 検証=CI&AI(doctor) / 適用待ち追跡=Workflow の三者分担が明確
- E3: 本正本は上位集約・個別ルールは具体適用（矛盾でなく階層）
