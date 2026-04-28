# EXECUTION PLAN — TASK-0038: Parent-Child PBI Orchestrator Mode 仕様策定

> 関連 Issue: [#109](https://github.com/s977043/plangate/issues/109)
> モード判定: **high-risk**

## Goal

PlanGate を「単一 PBI 制御」から「親 PBI 配下の複数子 PBI を統制するオーケストレーションシステム」へ拡張するための **仕様文書群を確定**する。実装は本 PBI には含めない。

完了状態: 受入基準 9 項目（AC-1〜AC-9）すべてが、対応する仕様文書に **必要十分な記述** で反映されている。

## Constraints / Non-goals

### Constraints

- 既存 v7 hybrid architecture（5 phase / 5 agent / 10 skill）を**置換せず内側で拡張**する。
- 既存の `docs/working/TASK-XXXX/` ベース運用と**互換**性を保つ。
- 「Gate を消さない」原則を維持する。AI 自己完結の完了判定は禁止。
- 既存 5 mode（ultra-light 〜 critical）と直交する軸として設計する。

### Non-goals

- CLI 実装（`plangate decompose` 本体）
- Agent 実装（Parent Supervisor / Child Planner / Integration Agent 本体）
- Hook 実装（自動分解検知、再承認自動化）
- マルチプロセス並行実行ランタイム
- GitHub Projects / Linear 連携
- 既存 `workflows/<mode>.yaml` への破壊的変更

## Approach Overview

仕様策定は **5 つの階層** で構成する:

```text
Layer 1: アーキテクチャ正本（docs/orchestrator-mode.md）
   ↓ defines
Layer 2: スキーマ定義（docs/schemas/child-pbi.yaml）
   ↓ defines
Layer 3: Workflow 定義（docs/workflows/orchestrator-{decomposition,integration}.md）
   ↓ produces
Layer 4: Template 群（docs/working/templates/{parent-plan,dependency-graph,parallelization-plan,integration-plan}.md）
   ↓ enforced by
Layer 5: Rule 正本（.claude/rules/orchestrator-mode.md）+ RFC（docs/rfc/plangate-decompose.md）
```

各層は上層の制約を満たし、下層へ要件を委譲する単方向参照とする（循環参照なし）。

## Work Breakdown

### Step 1: アーキテクチャ正本作成 — `docs/orchestrator-mode.md`

| 項目 | 内容 |
|------|------|
| Output | Parent-Child PBI モデル定義、分解フロー（7 状態）、サブエージェント実行モデル（5 役割）、Gate 条件の形式化（ChildExecAllowed / ParentDone / NewChildPBIAllowed）|
| Owner | claude（仕様作成） |
| Risk | 既存 v7 hybrid architecture と責務重複（R1） |
| 🚩 チェックポイント | 既存 `.claude/agents/` の 5 Agent との責務境界が表で明記されているか |
| カバー AC | AC-1, AC-7, AC-8, AC-9 |

### Step 2: 子 PBI スキーマ定義 — `docs/schemas/child-pbi.yaml`

| 項目 | 内容 |
|------|------|
| Output | YAML schema（id / parent_id / scope / dependencies / allowed_files / forbidden_files / acceptance_criteria / required_checks / pr_strategy）+ 各フィールドの説明 + バリデーション規則 |
| Owner | claude |
| Risk | 既存 plan.md / todo.md / test-cases.md と機能重複（R2） |
| 🚩 チェックポイント | `forbidden_files` が glob で表現でき、scope_boundary を機械的に評価できる構造か |
| カバー AC | AC-2 |

### Step 3: 分解フロー Workflow — `docs/workflows/orchestrator-decomposition.md`

| 項目 | 内容 |
|------|------|
| Output | 状態遷移図（parent:draft → done）、各状態の入力・出力・完了条件、Sub Agent 割当、Gate 挿入位置 |
| Owner | claude |
| Risk | 状態遷移と既存 PlanGate phase の対応が曖昧になる |
| 🚩 チェックポイント | parent / child 各状態が PlanGate の C-3 / C-4 ゲートと対応する図表を含むか |
| カバー AC | AC-7, AC-9 |

### Step 4: 統合 Workflow — `docs/workflows/orchestrator-integration.md`

| 項目 | 内容 |
|------|------|
| Output | 親 PBI 完了判定フロー、統合チェック項目、Integration Agent の責務、`ParentDone` 不変条件の運用手順 |
| Owner | claude |
| Risk | 親 PBI 受入基準カバレッジ判定の機械化が困難 |
| 🚩 チェックポイント | カバレッジ未達時の差し戻し条件が記述されているか |
| カバー AC | AC-8, AC-9 |

### Step 5: Template 4 種作成 — `docs/working/templates/`

| 項目 | 内容 |
|------|------|
| Output | parent-plan.md / dependency-graph.md / parallelization-plan.md / integration-plan.md の 4 テンプレート（必須セクション + 記入例） |
| Owner | claude |
| Risk | テンプレート間の整合性欠落（R4） |
| 🚩 チェックポイント | 4 テンプレートが `docs/orchestrator-mode.md` の用語・状態名と一致しているか |
| カバー AC | AC-4, AC-6 |

### Step 6: Rule 正本作成 — `.claude/rules/orchestrator-mode.md`

| 項目 | 内容 |
|------|------|
| Output | Parent / Child Gate 条件の機械可読な定義、CLAUDE.md からの参照パス、既存 mode-classification.md との関係 |
| Owner | claude |
| Risk | rule とアーキテクチャ正本の二重管理 |
| 🚩 チェックポイント | アーキテクチャ正本へのリンクのみで内容が一意に定まるか |
| カバー AC | AC-9 |

### Step 7: CLI RFC 作成 — `docs/rfc/plangate-decompose.md`

| 項目 | 内容 |
|------|------|
| Output | `plangate decompose <PBI>` CLI コマンドの RFC（Status: Draft）。入力 / 出力 / フラグ / 期待動作 / 既存コマンドとの整合性 / 実装フェーズ提案 |
| Owner | claude |
| Risk | RFC が実装制約を過度に固定化（U3） |
| 🚩 チェックポイント | Status が `Draft` で、実装は別 PBI 扱いと明記されているか |
| カバー AC | AC-3, AC-5 |

### Step 8: PR 作成方針の追記 — Step 7 RFC + アーキテクチャ正本

| 項目 | 内容 |
|------|------|
| Output | `pr_strategy` フィールドの仕様化（branch 命名 / pr_size / merge_after / required_checks の運用ルール） |
| Owner | claude |
| Risk | 既存 `release-manager` skill / agent の責務と重複 |
| 🚩 チェックポイント | 既存リリース運用との重複・競合がレビューされたか |
| カバー AC | AC-5 |

### Step 9: README / index 更新 — 既存ドキュメントへのリンク追加

| 項目 | 内容 |
|------|------|
| Output | `README.md` Read Next 表 / `docs/index.md` への新規 9 ファイルのリンク追加 |
| Owner | claude |
| Risk | リンク追加漏れ / 順序不整合 |
| 🚩 チェックポイント | 新規 9 ファイルすべてが entry-point から到達可能か |
| カバー AC | AC-1〜AC-9 全体（可視化） |

## Files / Components to Touch

### 新規作成（9 ファイル）

| パス | カテゴリ |
|------|---------|
| `docs/orchestrator-mode.md` | アーキテクチャ正本 |
| `docs/schemas/child-pbi.yaml` | スキーマ |
| `docs/workflows/orchestrator-decomposition.md` | Workflow |
| `docs/workflows/orchestrator-integration.md` | Workflow |
| `docs/working/templates/parent-plan.md` | Template |
| `docs/working/templates/dependency-graph.md` | Template |
| `docs/working/templates/parallelization-plan.md` | Template |
| `docs/working/templates/integration-plan.md` | Template |
| `.claude/rules/orchestrator-mode.md` | Rule |
| `docs/rfc/plangate-decompose.md` | RFC |

### 更新（最小限）

| パス | 変更内容 |
|------|---------|
| `README.md` | Read Next 表に `docs/orchestrator-mode.md` を追加 |
| `README_en.md` | 同上（英訳）|
| `docs/index.md` | 新規 9 ファイルへのリンク追加 |
| `docs/workflows/README.md` | orchestrator-decomposition / integration へのリンク追加 |

### 触らない

- 既存 `workflows/*.yaml`（5 mode DSL）
- 既存 `.claude/agents/`、`.claude/skills/`
- `bin/plangate`
- `tests/`、`fixtures/`

## Testing Strategy

実装ではないため **テストはドキュメント整合性検証** に限定する。

### Unit（ドキュメント単体）

- 新規 9 ファイルが指定パスに存在する（`test -f`）
- 各ファイルに必須セクションが含まれる（`grep -q "## <section>"`）
- YAML スキーマが yaml-lint に通る（`python3 -c "import yaml; yaml.safe_load(open('docs/schemas/child-pbi.yaml'))"`）

### Integration（ドキュメント間）

- アーキテクチャ正本から 8 ファイルすべてへ相対リンクが張られている
- 4 テンプレートの用語が `docs/orchestrator-mode.md` の用語と一致する
- 状態名（parent:draft, child:planned 等）が全文書で表記揺れなく使われている

### Acceptance（受入基準突合）

- 9 受入基準（AC-1〜AC-9）それぞれに対応する文書セクションが存在する
- AC ↔ 文書セクション対応表が `test-cases.md` で網羅されている

### Verification Automation

- `sh scripts/check-orchestrator-docs.sh`（簡易 shell スクリプト、本 PBI で同梱）で「全 9 ファイル存在 + 必須セクション grep」を一括実行
- CI への組み込みは別 PBI に委譲

## Risks & Mitigations

| ID | Risk | Mitigation |
|----|------|-----------|
| R1 | 既存 v7 hybrid と責務重複 | Step 1 で既存 5 Agent との責務境界表を作成、🚩で機械検証 |
| R2 | 子 PBI YAML が plan.md と重複 | Step 2 で「子 PBI YAML は親 PBI から見た契約」「plan.md は子 PBI 内部の実装計画」と層を分ける |
| R3 | Gate 維持 vs 並行性 | アーキ正本に「Gate は parent/child 両方で必須、並行は exec phase のみ」と明記 |
| R4 | 文書間の参照不整合 | Step 9 でリンクチェック、verification script に grep ベースの整合性チェックを追加 |
| R5 | 仕様の過剰具体化 | RFC は Status=Draft、実装制約は Non-goal に明記 |

## Questions / Unknowns

- **U1**: 親 PBI / 子 PBI の GitHub 表現（sub-issue API or label） → **本 PBI では「Issue 表現は実装 PBI で確定」と明記**して保留
- **U2**: Evidence Ledger と並列実行の関係 → **本 PBI では「子 PBI 単位で独立 Ledger を持つ」を仮置き**
- **U3**: `plangate decompose` の外部 LLM 依存 → **RFC で 2 案併記**（ローカル決定論 / 外部 LLM 補助）

## Mode判定

**モード**: high-risk

### 判定根拠

| 軸 | 値 | モード |
|----|----|-------|
| 変更ファイル数 | 新規 9 + 更新 4 = 13 | high-risk |
| 受入基準数 | 9 | high-risk |
| 変更種別 | アーキテクチャ仕様策定 | high-risk |
| リスク | 高（既存 v7 hybrid 拡張、責務再定義）| high-risk |
| 影響範囲 | 既存 PlanGate 全体に影響する仕様 | high-risk |
| **最終判定** | **high-risk** | — |

**例外ルール適用なし**（セキュリティ / DB / 公開 API 破壊変更のいずれも該当せず）。

ただし**実装を含まない**点で純粋な high-risk より検証コストは低い。
