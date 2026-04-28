# Workflow: Orchestrator Decomposition (親 PBI → 子 PBI 分解フロー)

> **Status**: Specification（v1, 仕様策定のみ）
> 関連: [`docs/orchestrator-mode.md`](../orchestrator-mode.md) / Issue [#109](https://github.com/s977043/plangate/issues/109)
> 主担当 Agent: Parent Supervisor Agent（既存 `orchestrator` の親 PBI 層拡張）

## 目的

親 PBI（`PBI-XXX`）を独立実装可能な子 PBI 群（`PBI-XXX-01`, `PBI-XXX-02`, ...）に分解し、依存関係グラフと並行実行計画を生成する。最終出力として `parent:decomposition_approved` 状態に到達する。

## 入力

- 親 PBI の `pbi-input.md`（または GitHub Issue）
- 既存 v7 hybrid の WF-01〜WF-02 の出力（context-load / requirement-gap-scan）
- リポジトリのファイル構造とアクセス権境界

## 完了条件

以下のすべてを満たすと `parent:decomposition_approved` に遷移する:

1. `parent-plan.md` が作成されている
2. `dependency-graph.md` が作成されている
3. `parallelization-plan.md` が作成されている
4. `children/PBI-XXX-NN.yaml` が 1 つ以上存在し、すべて schema validation PASS
5. `risk-report.md` が作成されている
6. **親計画ゲート（C-3 相当）** が 👤 人間 APPROVE
7. `approvals/parent-c3.json` に `decision=APPROVED` が記録されている

## 状態遷移

```text
parent:draft
   │
   │  Step D-1: 親 PBI 分析
   │   ├ 受入基準分析
   │   ├ 影響範囲特定
   │   └ 既存資産調査
   ▼
parent:analyzed
   │
   │  Step D-2: 子 PBI 候補抽出
   │   ├ ドメイン境界での分割案
   │   ├ レイヤー境界での分割案
   │   └ 副作用境界での分割案
   ▼
parent:candidates_identified
   │
   │  Step D-3: 子 PBI 仕様化
   │   ├ 各候補を docs/schemas/child-pbi.yaml に従って YAML 化
   │   ├ allowed_files / forbidden_files の境界確定
   │   └ 依存関係 (dependencies) 確定
   ▼
parent:children_drafted
   │
   │  Step D-4: 依存関係グラフ生成
   │   └ docs/working/templates/dependency-graph.md に従って mermaid 化
   ▼
parent:graph_generated
   │
   │  Step D-5: 並行実行可否判定
   │   └ docs/working/templates/parallelization-plan.md に従って判定
   ▼
parent:parallelization_planned
   │
   │  Step D-6: リスク集約
   │   └ risk-report.md に親 PBI レベル集約リスクを記述
   ▼
parent:decomposed
   │
   │  Step D-7: 親計画ゲート（C-3 相当）
   │   ├ 👤 人間レビュー（plan + dependency-graph + parallelization + children + risk）
   │   └ APPROVE / CONDITIONAL / REJECT
   ▼
parent:decomposition_approved
   │
   ▼
（次フェーズ: 子 PBI 群の planning / approval / execution へ）
```

## 各 Step の詳細

### Step D-1: 親 PBI 分析

| 項目 | 内容 |
| --- | --- |
| 入力 | `pbi-input.md` / 既存コードベース |
| 出力 | `parent-plan.md`（暫定版、Goal / Constraints / Approach Overview のみ） |
| Sub Agent | Parent Supervisor（兼 requirements-analyst） |
| Skill | `requirement-gap-scan` / `context-load` |

### Step D-2: 子 PBI 候補抽出

| 項目 | 内容 |
| --- | --- |
| 入力 | Step D-1 の暫定 plan |
| 出力 | 候補リスト（タイトル / ゴール / 想定 in_scope の 3 列） |
| Sub Agent | Parent Supervisor |
| Skill | `architecture-sketch`（既存） |

候補抽出の観点:

- ドメイン境界（DDD の Bounded Context 単位）
- レイヤー境界（domain / application / infrastructure / presentation）
- 副作用境界（pure / side-effecting / external integration）
- 変更頻度境界（共有コンポーネント vs 機能固有）

### Step D-3: 子 PBI 仕様化

| 項目 | 内容 |
| --- | --- |
| 入力 | 候補リスト |
| 出力 | `children/PBI-XXX-NN.yaml` × N |
| Sub Agent | Child Planner（既存 solution-architect 拡張） |
| Skill | `acceptance-criteria-build` / `architecture-sketch` |

各子 PBI YAML は [`docs/schemas/child-pbi.yaml`](../schemas/child-pbi.yaml) に従う。

### Step D-4: 依存関係グラフ生成

| 項目 | 内容 |
| --- | --- |
| 入力 | 各子 PBI の `dependencies` フィールド |
| 出力 | `dependency-graph.md`（mermaid graph） |
| Sub Agent | Parent Supervisor |
| Skill | （新規）`dependency-graph-build` または手動 |

循環依存が検出された場合は Step D-3 に差し戻す。

### Step D-5: 並行実行可否判定

| 項目 | 内容 |
| --- | --- |
| 入力 | 子 PBI YAML 群 + dependency-graph |
| 出力 | `parallelization-plan.md` |
| Sub Agent | Parent Supervisor |
| 検証ルール | [`docs/orchestrator-mode.md`](../orchestrator-mode.md) の「並行実行可能 / 不可条件」 |

並行不可と判定された場合は `parallelizable: false` に修正し、`merge_after` を設定する。

### Step D-6: リスク集約

| 項目 | 内容 |
| --- | --- |
| 入力 | 各子 PBI の `risk` フィールド + 親 PBI 全体観 |
| 出力 | `risk-report.md` |
| Sub Agent | Parent Supervisor + Review Agent |
| Skill | `risk-assessment`（既存） |

### Step D-7: 親計画ゲート（C-3 相当）

| 項目 | 内容 |
| --- | --- |
| 入力 | parent-plan / dependency-graph / parallelization / children / risk-report |
| 出力 | `approvals/parent-c3.json` |
| 担当 | 👤 人間 |
| 判定値 | APPROVE / CONDITIONAL / REJECT |

判定後の遷移:

- **APPROVE**: `parent:decomposition_approved` へ → 子 PBI planning フェーズに進む
- **CONDITIONAL**: 指摘内容を Step D-3 / D-4 / D-5 にフィードバックし簡易再生成
- **REJECT**: Step D-1 から再実施

## 既存 PlanGate Gate との対応

| 既存 PlanGate Phase | Orchestrator Decomposition の対応 |
| --- | --- |
| A: PBI INPUT PACKAGE | 親 PBI の pbi-input.md と同等 |
| B: plan / todo / test-cases 生成 | Step D-1 〜 D-3 の親 + 子レベルで二重実行 |
| C-1: セルフレビュー | 各子 PBI YAML に対して実施（C-1 簡易） |
| **C-3: 人間レビュー** | **Step D-7 親計画ゲート**（親 PBI 全体） |
| 子 PBI 単位の C-3 | 子 PBI 各々の plan 生成後に通常通り実施 |

つまり Orchestrator Mode では C-3 ゲートが **2 段階** になる:

1. **親計画ゲート**（Step D-7）: 子 PBI 群と分解戦略全体を承認
2. **子 PBI ゲート**: 各子 PBI の plan を個別承認

## 呼び出す Skill

| Skill | 使用 Step | 出典 |
| --- | --- | --- |
| `context-load` | D-1 | 既存 `.claude/skills/` |
| `requirement-gap-scan` | D-1 | 既存 |
| `architecture-sketch` | D-2, D-3 | 既存 |
| `acceptance-criteria-build` | D-3 | 既存 |
| `risk-assessment` | D-6 | 既存 |
| `dependency-graph-build` | D-4 | **新規（実装 PBI で追加検討）** |

## エラーハンドリング

| 異常 | 対処 |
| --- | --- |
| 循環依存検出 | Step D-3 に戻り、子 PBI 分割を再検討 |
| schema validation 失敗 | 該当子 PBI YAML を修正し Step D-3 末尾から再開 |
| 並行不可判定の連鎖（実質直列のみ） | 親 PBI が大きすぎる可能性。親 PBI 分割を検討（人間判断） |
| 親計画ゲート REJECT | Step D-1 から再実施 |

## 実装フェーズ提案（後続 PBI で）

1. **Phase 1**: 手動運用（テンプレート + Sub Agent 責務定義のみ）
2. **Phase 2**: `plangate decompose` CLI 実装（[`docs/rfc/plangate-decompose.md`](../rfc/plangate-decompose.md)）
3. **Phase 3**: dependency-graph 自動生成 / parallelization 自動判定
4. **Phase 4**: Workflow DSL（`workflows/orchestrator-*.yaml`）対応
