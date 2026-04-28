# Rule: Orchestrator Mode Gate Conditions（正本）

> **Status**: Specification（v1, 仕様策定のみ。実装による強制力は別 PBI）
> 関連: [`docs/orchestrator-mode.md`](../../docs/orchestrator-mode.md) / Issue [#109](https://github.com/s977043/plangate/issues/109)
> 役割: PlanGate Orchestrator Mode の Gate 条件と AI 自己完結禁止条項の **正本** を提供する

## 位置付け

このルールは [`docs/orchestrator-mode.md`](../../docs/orchestrator-mode.md) の Gate 条件章を **機械可読・運用可能な形** で正本化したものである。重複定義を避けるため、概念説明はアーキテクチャ正本側、強制条件はこのルール側に置く。

| 観点 | 配置 |
|------|------|
| アーキテクチャ概念 / 状態遷移図 / Sub Agent 責務 | [`docs/orchestrator-mode.md`](../../docs/orchestrator-mode.md) |
| **Gate 不変条件 / 機械チェック規則** | **本ルール（正本）** |
| Skill / Workflow への参照 | [`docs/workflows/orchestrator-{decomposition,integration}.md`](../../docs/workflows/) |

## 既存ルールとの関係

| 既存ルール | 関係 |
|----------|------|
| [`mode-classification.md`](./mode-classification.md) | 5 mode 分類は本ルールと **直交**。子 PBI のモード判定は mode-classification に従い、本ルールは親子関係上の Gate を補う |
| [`hybrid-architecture.md`](./hybrid-architecture.md) | Rule 1〜5 を継承。本ルールは Rule 5（最終成果物は handoff に集約）を親 PBI 層に拡張 |
| [`working-context.md`](./working-context.md) | `docs/working/TASK-XXXX/` 構造を子 PBI 層で再利用、親 PBI 層は `docs/working/PBI-XXX/` を別途使用 |
| [`review-principles.md`](./review-principles.md) | レビュー判定フレームを親 / 子両方に適用 |

## 不変条件 1: ChildExecAllowed

子 PBI の exec phase 開始を許可する条件。

```text
ChildExecAllowed =
  ChildPlanApproved
  AND ParentPlanApproved
  AND ScopeBoundaryDefined
  AND DependencyResolved
  AND RiskGatePassed
```

### 機械チェック規則

| 項目 | チェック方法 |
|------|------------|
| `ChildPlanApproved` | `docs/working/<child-context>/approvals/c3.json` 存在 + `decision == "APPROVED"` |
| `ParentPlanApproved` | `docs/working/PBI-XXX/approvals/parent-c3.json` 存在 + `decision == "APPROVED"` |
| `ScopeBoundaryDefined` | 子 PBI YAML の `allowed_files` と `forbidden_files` 両方が non-empty |
| `DependencyResolved` | YAML の `dependencies` 配列の各 ID が `child:done` 状態である |
| `RiskGatePassed` | `risk.level` が `high` / `critical` の場合は追加 approval 記録あり |

**いずれか 1 つでも未充足 → 子 PBI exec を block する。**

## 不変条件 2: ParentDone

親 PBI を `parent:done` に遷移させる条件。

```text
ParentDone =
  AllRequiredChildrenAccepted
  AND ParentAcceptanceCriteriaCovered
  AND IntegrationChecksPassed
  AND NoOpenBlockingGap
  AND HumanOrPolicyFinalApprovalPassed
```

### 機械チェック規則

| 項目 | チェック方法 |
|------|------------|
| `AllRequiredChildrenAccepted` | required な全子 PBI YAML の状態が `done` |
| `ParentAcceptanceCriteriaCovered` | `parent-plan.md` の各 AC（受入基準）が、子 PBI YAML の `covers_parent_ac` に少なくとも 1 件含まれる |
| `IntegrationChecksPassed` | `integration-plan.md` の全チェック項目が PASS |
| `NoOpenBlockingGap` | `integration-plan.md` の Gap リストに「先送り合意済み」以外の未解決項目なし |
| `HumanOrPolicyFinalApprovalPassed` | `approvals/parent-integration.json` 存在 + `decision == "APPROVED"` |

**いずれか 1 つでも未充足 → `parent:done` 宣言を block する。**

## 不変条件 3: NewChildPBIAllowed

exec 中に新規子 PBI を追加することを許可する条件。

```text
NewChildPBIAllowed =
  GapDetected
  AND (
    WithinParentScope
    OR HumanApprovedScopeChange
  )
```

### 機械チェック規則

| 項目 | チェック方法 |
|------|------------|
| `GapDetected` | `integration-plan.md` の Gap リストにエントリあり、または exec 中の証跡で AC 未達確認 |
| `WithinParentScope` | 提案される子 PBI の `goal` と `in_scope` が親 `parent-plan.md` の Goal / Acceptance Criteria に内包 |
| `HumanApprovedScopeChange` | 親スコープ外の場合、`approvals/parent-c3.json` の更新（Re-approval）が記録されている |

**いずれの条件も未充足 → 新規子 PBI 追加を block する。**

## AI 自己完結禁止条項

PlanGate Orchestrator Mode において、AI Agent は以下のアクションを **完全自動で実行してはならない**。実装層 / Hook 層で強制力を持たせる前提とする。

### 禁止アクション一覧

| ID | 禁止アクション | 必須通過 Gate |
|----|--------------|--------------|
| AS-1 | 親 PBI 分解の確定（`parent:decomposed` → `parent:decomposition_approved`）| 親計画ゲート（C-3 相当、👤 人間）|
| AS-2 | 子 PBI exec 開始（C-3 相当）| 子 PBI 単位の C-3 ゲート（👤 人間）|
| AS-3 | 親 PBI 完了宣言（`parent:integration_review` → `parent:done`）| 統合ゲート（👤 人間 or 事前定義 policy）|
| AS-4 | 親スコープ外の新規子 PBI 追加 | `HumanApprovedScopeChange`（👤 人間）|
| AS-5 | 既存子 PBI のスコープ拡大（`forbidden_files` 解除）| 該当子 PBI の C-3 再承認（👤 人間）|

### 違反検出

将来的な Hook 実装で以下を強制する想定:

```text
on action "transition parent state":
  if to_state in ["decomposition_approved", "done"]:
    require approval record AND human_decision == "APPROVED"
    else: block

on action "create child PBI":
  if scope outside parent.in_scope:
    require parent-c3.json updated_at > new_child created_at
    else: block

on action "modify forbidden_files":
  require c3.json updated_at > modification_at
  else: block
```

実装は本 PBI 範囲外。本ルールは強制対象の **正本定義** として機能する。

## 状態遷移制約

子 PBI の状態は以下に従う:

```text
planned → approved → executing → review → done
any     → blocked  (with reason)
blocked → 任意の前状態 (with re-approval if needed)
```

親 PBI の状態は [`docs/orchestrator-mode.md`](../../docs/orchestrator-mode.md) の状態遷移図に従う。

## handoff 必須化

[`hybrid-architecture.md`](./hybrid-architecture.md) Rule 5 を Orchestrator Mode に拡張:

| 層 | handoff 配置 | 必須要素 |
|----|------------|---------|
| 子 PBI | `docs/working/<child-context>/handoff.md` | 既存 6 要素 + `covers_parent_ac` 明示 |
| 親 PBI | `docs/working/PBI-XXX/handoff.md` | 既存 6 要素を **集約** + 全子 PBI 一覧 + 統合チェック結果 |

## 監査ログ

将来的な実装では以下を append-only に記録する想定:

| File | Path | 内容 |
|------|------|------|
| 親決定ログ | `docs/working/PBI-XXX/decision-log.jsonl` | 親計画変更 / 子 PBI 追加削除 / Gate 通過記録 |
| 子決定ログ | `docs/working/<child-context>/decision-log.jsonl` | 既存形式 |

## 検証可能性

本ルールに従って実装される機械チェックは、以下の条件を満たすこと:

1. **冪等性**: 同じ入力に対して常に同じ判定
2. **明示的失敗**: block 時は理由を文字列で返す
3. **トレーサビリティ**: チェック対象ファイルパスを失敗メッセージに含む
4. **テスト可能性**: 各不変条件に対してユニットテストを書ける構造

## バージョニング

本ルール v1 は **仕様定義のみ**。実装層での強制力導入時に v2 として扱い、その時点で:

- 機械チェック実装（CLI / Hook）
- 失敗時のメッセージフォーマット
- bypass 条件（緊急時のみの override mechanism）

を確定する。

## 参照

- [`docs/orchestrator-mode.md`](../../docs/orchestrator-mode.md)
- [`docs/workflows/orchestrator-decomposition.md`](../../docs/workflows/orchestrator-decomposition.md)
- [`docs/workflows/orchestrator-integration.md`](../../docs/workflows/orchestrator-integration.md)
- [`docs/schemas/child-pbi.yaml`](../../docs/schemas/child-pbi.yaml)
- [`docs/rfc/plangate-decompose.md`](../../docs/rfc/plangate-decompose.md)
- [`mode-classification.md`](./mode-classification.md)
- [`hybrid-architecture.md`](./hybrid-architecture.md)
- [`working-context.md`](./working-context.md)
