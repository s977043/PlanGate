# PlanGate Orchestrator Mode — Parent-Child PBI Architecture

> **Status**: Specification（v1, 仕様策定のみ。実装は後続 PBI）
> 関連 Issue: [#109](https://github.com/s977043/plangate/issues/109) / 親 Epic: [#72](https://github.com/s977043/plangate/issues/72)
> 関連 PBI: TASK-0038
> 設計原則: **AI に任せる範囲を広げる。ただし、Gate を消さない。**

## 概要

PlanGate Orchestrator Mode は、PlanGate を **単一 PBI 制御**から **親 PBI 配下の複数子 PBI を管理するオーケストレーションシステム** へ拡張するための仕様である。

### 位置付け

- 既存 v5 / v6 / v7 hybrid を **置換せず内側で拡張** する。
- 既存 5 mode（ultra-light / light / standard / high-risk / critical）と **直交** する軸として動作する。
- 既存 PlanGate Gate（C-3 / C-4）は維持しつつ、parent / child 双方のレイヤーで gate を発火させる。

### 適用対象

- 1 つの大きな PBI が複数の独立した実装単位に分解される場合
- 子 PBI ごとに PR を作成し、依存関係に応じて並行開発するケース
- AI エージェントに大規模機能の実装を委譲するケース

## Parent-Child PBI モデル

### 役割定義

| 種別 | 役割 | 直接実装 |
|------|------|----------|
| **親 PBI** | 目的 / 背景 / 受入基準 / 制約 / 除外範囲 / 統合方針 / 完了条件を管理する **制御単位** | ❌ 原則しない |
| **子 PBI** | 実装 / PR / レビュー / テストの **作業単位** | ✅ する |

親 PBI は子 PBI の集合に対する **契約** を提供し、各子 PBI は親 PBI の制約下で独立した PR を生む。

### ID 命名規則（提案）

| 種別 | 形式 | 例 |
|------|------|---|
| 親 PBI | `PBI-XXX` | `PBI-123` |
| 子 PBI | `PBI-XXX-NN` | `PBI-123-01`, `PBI-123-02` |

既存 `TASK-XXXX` 番号体系と区別する。実装 PBI で最終確定する。

## 分解フロー（状態遷移）

```text
parent:draft
   ↓ 親 PBI 起票・初期計画
parent:analyzed
   ↓ 影響範囲 / リスク / 子 PBI 候補の分析完了
parent:decomposed
   ↓ 子 PBI 群とその依存関係グラフが生成済み
parent:decomposition_approved
   ↓ 👤 人間承認（親計画ゲート）
   ↓
   ├─ child:planned       → 子 PBI ごとに plan / todo / test-cases 生成
   ├─ child:approved      → 子 PBI 単位の C-3 ゲート通過
   └─ child:executing     → 子 PBI exec 中（並行可能なものは並列）
   ↓ 全 required child が child:done
parent:integration_review
   ↓ 統合チェック + 親 PBI 受入基準カバレッジ確認
parent:done
```

各状態の詳細は [`docs/workflows/orchestrator-decomposition.md`](./workflows/orchestrator-decomposition.md) を参照。

## 成果物ディレクトリ構造

```text
docs/working/PBI-XXX/                  # 親 PBI のディレクトリ
  parent-plan.md                       # 親計画（テンプレート: docs/working/templates/parent-plan.md）
  dependency-graph.md                  # 子 PBI 間の依存関係グラフ（mermaid）
  parallelization-plan.md              # 並行実行計画
  integration-plan.md                  # 統合チェック / 親完了条件
  risk-report.md                       # 親 PBI レベルの集約リスク
  approvals/
    parent-c3.json                     # 親計画の C-3 ゲート承認記録
    parent-integration.json            # 統合ゲート承認記録
  children/
    PBI-XXX-01.yaml                    # 子 PBI 仕様（schema: docs/schemas/child-pbi.yaml）
    PBI-XXX-02.yaml
    ...
  handoff.md                           # 親 PBI 完了時の引き継ぎパッケージ
```

子 PBI の作業コンテキストは既存の `docs/working/TASK-XXXX/` 構造を再利用してもよいし、`docs/working/PBI-XXX/children/PBI-XXX-NN/` 配下に独立して持ってもよい（実装 PBI で確定）。

## サブエージェント実行モデル

### 5 役割

| Agent | 責務 | 既存 v7 hybrid Agent との関係 |
|-------|------|------------------------------|
| **Parent Supervisor Agent** | 親 PBI 分析 / 子 PBI 分割 / 依存関係管理 / 並行可否判定 / 親完了カバレッジ確認 | 既存 `orchestrator` を**親 PBI 層**に拡張 |
| **Child Planner Agent** | 子 PBI ごとの plan / todo / test-cases 作成 | 既存 `solution-architect` を子 PBI 単位に適用 |
| **Child Implementer Agent** | 子 PBI の実装 / PR 作成 | 既存 `implementation-agent` をそのまま再利用 |
| **Review Agent** | 差分レビュー / スコープ逸脱検出 / テスト不足検出 | 既存 `qa-reviewer` を子 PBI レビューに適用 |
| **Integration Agent** | 子 PBI 群の統合確認 / 親 PBI 受入基準カバレッジ確認 | **新規責務**（既存 `orchestrator` の handoff 発行を拡張） |

### 既存 v7 hybrid 5 Agent との責務境界

| 既存 Agent | 単一 PBI 時の責務 | Orchestrator Mode 時の責務 |
|-----------|------------------|--------------------------|
| `orchestrator` | Workflow 遷移管理 / 完了条件判定 / handoff 発行 | **親 PBI 層**の Supervisor を兼任 |
| `requirements-analyst` | 要求 → 仕様変換 | 親 PBI 仕様 → 子 PBI 候補抽出を兼任 |
| `solution-architect` | 仕様 → 実装構造設計 | **子 PBI 単位**で Planner として動作 |
| `implementation-agent` | 設計 → 実装 + 自己レビュー | 変更なし（子 PBI 単位で動作）|
| `qa-reviewer` | 要件適合確認 + handoff 準備 | 子 PBI 単位 + 親統合の二層で動作 |

**重要**: 新規 Agent を機械的に追加するのではなく、既存 5 Agent の責務を **親 PBI 層 / 子 PBI 層** で再評価する。Integration Agent のみ新規責務として `orchestrator` を拡張する。詳細実装は別 PBI で確定する。

## Gate 条件（不変条件）

「Gate を消さない」原則の形式化。すべての条件は `.claude/rules/orchestrator-mode.md` で正本管理する。

### 子 PBI 実行許可条件

```text
ChildExecAllowed =
  ChildPlanApproved
  AND ParentPlanApproved
  AND ScopeBoundaryDefined
  AND DependencyResolved
  AND RiskGatePassed
```

| 項目 | 意味 | 検証方法 |
|------|------|---------|
| `ChildPlanApproved` | 子 PBI の C-3 ゲート通過 | `approvals/c3.json` 存在 + `decision=APPROVED` |
| `ParentPlanApproved` | 親 PBI の親計画ゲート通過 | `approvals/parent-c3.json` 存在 + `decision=APPROVED` |
| `ScopeBoundaryDefined` | 子 PBI YAML に `allowed_files` / `forbidden_files` が定義済み | schema validation |
| `DependencyResolved` | `dependencies` に列挙された全子 PBI が `child:done` | 状態追跡 |
| `RiskGatePassed` | 子 PBI が高リスク領域なら追加承認取得済み | 高リスク領域定義表との突合 |

### 親 PBI 完了条件

```text
ParentDone =
  AllRequiredChildrenAccepted
  AND ParentAcceptanceCriteriaCovered
  AND IntegrationChecksPassed
  AND NoOpenBlockingGap
  AND HumanOrPolicyFinalApprovalPassed
```

| 項目 | 意味 |
|------|------|
| `AllRequiredChildrenAccepted` | required な全子 PBI が `child:done` |
| `ParentAcceptanceCriteriaCovered` | 親 PBI の受入基準すべてが少なくとも 1 つの子 PBI 受入基準でカバー |
| `IntegrationChecksPassed` | `integration-plan.md` の全チェック PASS |
| `NoOpenBlockingGap` | 未解決の `gap_detected` イベントがない |
| `HumanOrPolicyFinalApprovalPassed` | 統合ゲート（人間 or 自動 policy）APPROVE |

### 新規子 PBI 作成条件

```text
NewChildPBIAllowed =
  GapDetected
  AND (
    WithinParentScope
    OR HumanApprovedScopeChange
  )
```

| 項目 | 意味 |
|------|------|
| `GapDetected` | exec 中に親完了条件カバレッジ未達が検出された |
| `WithinParentScope` | 提案される子 PBI が親 PBI の `in_scope` 内 |
| `HumanApprovedScopeChange` | 親スコープ外の場合は人間承認による親計画更新を要する |

新規子 PBI 作成は **親計画の更新** として扱い、`reapproval_required` 状態を経由する。

## AI 自己完結禁止条項

PlanGate Orchestrator Mode において、AI は以下のアクションを **完全自動で実施してはならない**:

1. 親 PBI の **分解承認**（人間または明示的 policy が必要）
2. 子 PBI の **実装承認**（C-3 ゲート相当）
3. 親 PBI の **完了宣言**（統合ゲート）
4. 親 PBI スコープ外の **新規子 PBI 追加**

これらは Gate を通過するまで `pending` 状態にとどまる。AI は提案・分析・実装は行うが、最終決定権は人間または事前定義された policy に委ねる。

## 並行実行ポリシー

### 並行実行可能な条件（5 つ全て満たす場合）

1. 変更ファイルが重ならない（`allowed_files` の積集合が空）
2. 依存関係がない、または依存先がすべて完了済み
3. API contract / DB schema / 共通型が固定済み
4. テスト境界が分離されている
5. 高リスク領域でない

### 並行実行不可の条件（いずれか 1 つでも該当）

1. 同一ファイルを複数子 PBI が変更する
2. DB migration の順序依存がある
3. 認証・認可・決済・セキュリティ領域である
4. API contract が未確定
5. 共通コンポーネントや共通型を同時変更する

詳細な判定手順は [`docs/working/templates/parallelization-plan.md`](./working/templates/parallelization-plan.md) のテンプレートを参照。

## モード分類との統合

| 軸 | 値 |
|----|---|
| 親 PBI モード | 通常 `high-risk` または `critical`（横断的影響のため）|
| 子 PBI モード | 親から制約を継承しつつ、個別に判定（`light` 〜 `critical`）|
| Workflow DSL | 既存 `workflows/<mode>.yaml` は子 PBI 単位で適用。親 PBI 用 DSL は実装 PBI で検討 |

5 mode（ultra-light / light / standard / high-risk / critical）の判定基準は [`.claude/rules/mode-classification.md`](../.claude/rules/mode-classification.md) を参照。

## 関連ドキュメント

| カテゴリ | パス | 内容 |
|---------|------|------|
| Schema | [`docs/schemas/child-pbi.yaml`](./schemas/child-pbi.yaml) | 子 PBI YAML スキーマ |
| Workflow | [`docs/workflows/orchestrator-decomposition.md`](./workflows/orchestrator-decomposition.md) | 分解フロー定義 |
| Workflow | [`docs/workflows/orchestrator-integration.md`](./workflows/orchestrator-integration.md) | 統合フロー定義 |
| Template | [`docs/working/templates/parent-plan.md`](./working/templates/parent-plan.md) | 親計画テンプレート |
| Template | [`docs/working/templates/dependency-graph.md`](./working/templates/dependency-graph.md) | 依存関係グラフテンプレート |
| Template | [`docs/working/templates/parallelization-plan.md`](./working/templates/parallelization-plan.md) | 並行実行計画テンプレート |
| Template | [`docs/working/templates/integration-plan.md`](./working/templates/integration-plan.md) | 統合計画テンプレート |
| Rule | [`.claude/rules/orchestrator-mode.md`](../.claude/rules/orchestrator-mode.md) | Gate 条件正本 |
| RFC | [`docs/rfc/plangate-decompose.md`](./rfc/plangate-decompose.md) | `plangate decompose` CLI RFC |

## 既存ドキュメントとの関係

| 既存 | 関係 |
|------|------|
| [`docs/plangate.md`](./plangate.md) | v5 ガバナンス正本。本書は単一 PBI 前提を拡張する |
| [`docs/plangate-v7-hybrid.md`](./plangate-v7-hybrid.md) | v7 ハイブリッドアーキテクチャ。本書は同アーキテクチャを親 PBI 層へ拡張 |
| [`.claude/rules/hybrid-architecture.md`](../.claude/rules/hybrid-architecture.md) | Rule 1〜5 + 境界ルール。本書はそれらを満たす設計 |
| [`.claude/rules/working-context.md`](../.claude/rules/working-context.md) | handoff 必須化。Orchestrator Mode では親 / 子両方で handoff を発行 |

## 想定 V1 / V2 範囲

### V1（本仕様で策定）

- Parent-Child PBI モデル定義
- 子 PBI YAML スキーマ
- 分解 / 統合 Workflow 定義
- 4 種テンプレート
- Gate 条件正本（Rule）
- `plangate decompose` CLI RFC（Status: Draft）

### V2（後続 PBI で実装・拡張）

- Parent Supervisor / Integration Agent の実装本体
- `plangate decompose` CLI 実装
- dependency-graph.md / parallelization-plan.md 自動生成ロジック
- Workflow DSL の orchestrator mode 対応
- GitHub Issue sub-issue 連携
- Evidence Ledger の親子合算
- マルチプロセス並行実行ランタイム
