# TASK-0038: Parent-Child PBI Orchestrator Mode 仕様策定

> 関連 Issue: [#109](https://github.com/s977043/plangate/issues/109)
> 親 Epic: [#72](https://github.com/s977043/plangate/issues/72)
> モード: high-risk
> スコープ: **仕様策定のみ**（実装は別 PBI）

## Context / Why

PlanGate は現在、単一 PBI に対して `plan → approve → exec → verify → handoff` を統制するワークフローとして強い価値を持っている。一方で、実プロダクト開発では 1 つの大きな PBI が複数の独立した実装単位に分解され、子 PBI ごとに PR を作成し、依存関係に応じて並行開発するケースが多い。

大きな PBI を AI エージェントに担当させるには、親 PBI を直接実装対象にするのではなく、親 PBI を「子 PBI 群を束ねる計画・制約・完了条件」として扱い、子 PBI 単位で PlanGate を適用する必要がある。

この機能により、PlanGate を **単一 PBI の実行制御**から、**親 PBI 配下の複数子 PBI を管理するオーケストレーションシステム**へ拡張する。

### 設計原則

> AI に任せる範囲を広げる。ただし、Gate を消さない。

「自動フローモード」ではなく、PlanGate の Gate 構造を維持したまま大きな PBI を複数子 PBI へ分解・実行・統合する **Orchestrator Mode** として扱う。

## What (Scope)

### In scope（本 PBI で仕様策定する範囲）

#### 1. Parent-Child PBI モデル定義

| 種別 | 役割 |
|------|------|
| 親 PBI | 目的、背景、受入基準、制約、除外範囲、統合方針、完了条件を管理する制御単位 |
| 子 PBI | 実装、PR、レビュー、テストの単位 |

親 PBI は原則として直接実装しない。実装は子 PBI 単位で行う。

#### 2. 子 PBI 分解フロー

```text
parent:draft
  ↓
parent:analyzed
  ↓
parent:decomposed
  ↓
parent:decomposition_approved
  ↓
child:planned / child:approved / child:executing
  ↓
parent:integration_review
  ↓
parent:done
```

成果物のディレクトリ構造例:

```text
docs/working/PBI-XXXX/
  parent-plan.md
  children/
    child-001.md
    child-002.md
    child-003.md
  dependency-graph.md
  parallelization-plan.md
  integration-plan.md
  risk-report.md
```

#### 3. 子 PBI YAML フォーマット

子 PBI が持つべき情報を YAML スキーマとして定義する。代表例:

```yaml
child_pbi:
  id: PBI-123-01
  parent_id: PBI-123
  title: 権限判定サービスを実装する
  goal: API や UI から共通利用できる権限判定関数を提供する
  user_value: ロールに応じて安全に操作可否を判定できる
  in_scope:
    - permission service の実装
    - unit test の追加
  out_of_scope:
    - DB schema 変更
    - 管理画面 UI
    - API middleware 適用
  dependencies: []
  parallelizable: true
  allowed_files:
    - src/domain/permission/**
    - src/lib/permission/**
    - tests/permission/**
  forbidden_files:
    - prisma/schema.prisma
    - src/app/api/**
    - .github/workflows/**
  acceptance_criteria:
    - role と action と resource から許可可否を返せる
    - 未定義権限は deny になる
    - unit test が主要ケースを網羅している
  required_checks:
    - lint
    - typecheck
    - unit-test
  pr_strategy:
    branch: feature/PBI-123-01-permission-service
    pr_size: small
    merge_after: []
```

#### 4. 依存関係・並行開発判定

並行実行可能な条件:

- 変更ファイルが重ならない
- 依存関係がない、または依存先が完了済み
- API contract / DB schema / 共通型が固定済み
- テスト境界が分離されている
- 高リスク領域ではない

並行実行不可の条件:

- 同一ファイルを複数子 PBI が変更する
- DB migration の順序依存がある
- 認証・認可・決済・セキュリティ領域である
- API contract が未確定
- 共通コンポーネントや共通型を同時変更する

#### 5. サブエージェント実行モデル

| Agent | 責務 |
|-------|------|
| Parent Supervisor Agent | 親 PBI 分析 / 子 PBI 分割 / 依存関係管理 / 並行実行可否判定 / 親 PBI 完了条件カバレッジ確認 |
| Child Planner Agent | 子 PBI ごとの plan / todo / test-cases 作成 |
| Child Implementer Agent | 子 PBI の実装 / 子 PBI 単位の PR 作成 |
| Review Agent | 差分レビュー / スコープ逸脱検出 / テスト不足検出 |
| Integration Agent | 子 PBI 群の統合確認 / 親 PBI 受入基準のカバレッジ確認 |

#### 6. 新規子 PBI 作成・再計画フロー

```text
parent:children_in_progress
  ↓
gap_detected
  ↓
new_child_pbi_proposed
  ↓
parent_plan_updated
  ↓
reapproval_required
  ↓
child:planned
```

新しい子 PBI 作成は、単なる作業追加ではなく **親 PBI 計画の更新**として扱う。

#### 7. 不変条件（Gate 条件の形式化）

実行許可条件:

```text
ChildExecAllowed =
  ChildPlanApproved
  AND ParentPlanApproved
  AND ScopeBoundaryDefined
  AND DependencyResolved
  AND RiskGatePassed
```

親 PBI 完了条件:

```text
ParentDone =
  AllRequiredChildrenAccepted
  AND ParentAcceptanceCriteriaCovered
  AND IntegrationChecksPassed
  AND NoOpenBlockingGap
  AND HumanOrPolicyFinalApprovalPassed
```

新規子 PBI 作成条件:

```text
NewChildPBIAllowed =
  GapDetected
  AND (
    WithinParentScope
    OR HumanApprovedScopeChange
  )
```

### Out of scope（本 PBI では扱わない）

- **実装系**:
  - Parent Supervisor Agent / Child Planner Agent 等の実装本体
  - `plangate decompose` CLI コマンドの実装本体
  - dependency-graph.md / parallelization-plan.md 自動生成ロジック
  - マルチプロセス並行実行ランタイム
- **統合系**:
  - GitHub Projects / Linear 連携の詳細実装
  - 既存 v7 hybrid architecture との統合実装
- **自動化系**:
  - 完全自動マージ / 完全自動デプロイ
  - AI 自身による無条件の親 PBI 完了宣言
  - 高リスク子 PBI の人間承認なし実行

## 受入基準

すべて Issue #109 の受入基準と同一。各項目は「ドキュメント / スキーマ / 仕様の **存在と必須セクション充足**」で評価する。

- [ ] **AC-1**: 親 PBI / 子 PBI の責務定義がドキュメント化されている
- [ ] **AC-2**: 子 PBI フォーマットが `docs/` または `schemas/` に定義されている
- [ ] **AC-3**: 親 PBI 分解コマンド案（例: `plangate decompose`）が仕様化されている
- [ ] **AC-4**: `dependency-graph.md` / `parallelization-plan.md` / `integration-plan.md` の成果物仕様が定義されている
- [ ] **AC-5**: 子 PBI ごとの PR 作成方針が定義されている
- [ ] **AC-6**: 並行実行可能条件・不可条件が明文化されている
- [ ] **AC-7**: 新規子 PBI 作成時に親 PBI 計画の再承認が必要になる条件が定義されている
- [ ] **AC-8**: 親 PBI 完了判定が、子 PBI 完了だけでなく親 PBI 受入基準カバレッジで判定される条件として定義されている
- [ ] **AC-9**: AI が「分解・承認・実装・完了判定」を完全自己完結しないための Gate 条件が定義されている

## Notes from Refinement

- **既存ワークフローとの関係**: PlanGate v5/v6/v7 hybrid を**置換せず内側で拡張**する。既存の TASK-XXXX ベース運用と並存可能とする。
- **PBI ID 命名規則**: 既存 TASK-XXXX と区別するため、本仕様で扱う親 PBI は `PBI-XXX`、子 PBI は `PBI-XXX-NN`（`-01` から）の形式を採用候補とする（最終確定は実装 PBI で）。
- **Gate との対応**: 既存 C-3 / C-4 を活かし、新たに「親計画承認ゲート」「子計画承認ゲート」「統合承認ゲート」の 3 段を提案する。
- **モード分類との統合**: 親 PBI 自体は通常 high-risk / critical 想定。子 PBI は親から制約を継承しつつ個別判定する。
- **5 mode workflow DSL との関係**: `workflows/<mode>.yaml` が現状単一 PBI 前提のため、orchestrator mode 用の追加スキーマ（または専用 YAML）が必要となる可能性。本 PBI ではあくまで **仕様要件**として扱い、DSL 設計の詳細は後続実装 PBI で確定する。

## Estimation Evidence

### Risks

- **R1**: 既存 v7 hybrid architecture（5 Agent / 5 phase）との責務境界が不明瞭になり、Agent が重複定義される
- **R2**: 子 PBI YAML スキーマが既存 plan.md / todo.md / test-cases.md と機能重複する
- **R3**: 「Gate を消さない」原則と「並行実行で速度を出す」要求が衝突する可能性
- **R4**: 仕様書間の参照不整合（`docs/orchestrator-mode.md` / `.claude/rules/orchestrator-mode.md` / `docs/schemas/child-pbi.yaml` 等）が発生しやすい

### Unknowns

- **U1**: 親 PBI / 子 PBI の関係を Issue 上で表現する際、GitHub Issue の sub-issue 機能を活用するか、ラベル + 命名規則のみで管理するか
- **U2**: 並列実行時の Evidence Ledger（plugin v7.2 で導入）がどう束ねられるか
- **U3**: `plangate decompose` がローカル CLI で完結するか、外部 LLM 呼び出しを含むか

### Assumptions

- **A1**: 本 PBI のスコープは「仕様文書 + スキーマ + RFC のみ」であり、CLI / Agent / Hook の実装は含まない
- **A2**: 既存 5 mode（ultra-light 〜 critical）と orchestrator mode は **直交**する軸として設計可能
- **A3**: 親 PBI / 子 PBI の状態管理は既存の `docs/working/` 配下に収まる（新たな永続層は不要）

## 想定成果物（exec phase で作成予定）

| 種別 | パス | 内容 |
|------|------|------|
| アーキテクチャ正本 | `docs/orchestrator-mode.md` | Parent-Child PBI モデル / 分解フロー / 統合ゲート |
| Schema | `docs/schemas/child-pbi.yaml` | 子 PBI YAML スキーマ定義 |
| Workflow | `docs/workflows/orchestrator-decomposition.md` | 分解フロー WF 定義 |
| Workflow | `docs/workflows/orchestrator-integration.md` | 統合・親 PBI 完了判定 WF 定義 |
| Template | `docs/working/templates/parent-plan.md` | 親 plan テンプレート |
| Template | `docs/working/templates/dependency-graph.md` | 依存関係グラフテンプレート |
| Template | `docs/working/templates/parallelization-plan.md` | 並行実行計画テンプレート |
| Template | `docs/working/templates/integration-plan.md` | 統合計画テンプレート |
| Rule | `.claude/rules/orchestrator-mode.md` | Parent/Child Gate 条件正本 |
| RFC | `docs/rfc/plangate-decompose.md` | `plangate decompose` CLI コマンド RFC |
