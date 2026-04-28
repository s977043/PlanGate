# テストケース定義 — TASK-0038

> 関連 Issue: [#109](https://github.com/s977043/plangate/issues/109)
> 種別: ドキュメント整合性検証（実装テストなし）

## 受入基準 → テストケース マッピング

| AC | 説明 | 対応テストケース |
|----|------|----------------|
| AC-1 | 親 PBI / 子 PBI の責務定義 | TC-01, TC-02 |
| AC-2 | 子 PBI フォーマット定義 | TC-03, TC-04, TC-05 |
| AC-3 | 親 PBI 分解コマンド仕様 | TC-06, TC-07 |
| AC-4 | dependency-graph / parallelization-plan / integration-plan 仕様 | TC-08, TC-09, TC-10 |
| AC-5 | 子 PBI ごとの PR 作成方針 | TC-11, TC-12 |
| AC-6 | 並行実行可能 / 不可条件 | TC-13 |
| AC-7 | 新規子 PBI 作成時の親計画再承認条件 | TC-14 |
| AC-8 | 親 PBI 完了判定（受入基準カバレッジ） | TC-15 |
| AC-9 | AI 自己完結を防ぐ Gate 条件 | TC-16, TC-17 |
| 整合性 | 文書間整合性 | TC-18, TC-19, TC-20 |

## テストケース一覧

### TC-01: アーキテクチャ正本の存在と Parent-Child 責務定義

| 項目 | 内容 |
|------|------|
| 種別 | Unit（ファイル存在 + grep）|
| 前提 | exec phase 完了 |
| 入力 | `docs/orchestrator-mode.md` |
| 期待出力 | ファイル存在 + 「親 PBI」「子 PBI」「責務」が含まれる + 親子の役割表が存在 |
| 検証 | `test -f docs/orchestrator-mode.md && grep -q "親 PBI" docs/orchestrator-mode.md && grep -q "子 PBI" docs/orchestrator-mode.md` |
| カバー AC | AC-1 |

### TC-02: 既存 v7 hybrid Agent との責務境界

| 項目 | 内容 |
|------|------|
| 種別 | Unit（grep）|
| 入力 | `docs/orchestrator-mode.md` |
| 期待出力 | `orchestrator` / `solution-architect` / `implementation-agent` / `qa-reviewer` / `requirements-analyst` のうち少なくとも 3 体が言及され、Parent Supervisor / Child Planner との責務境界が表で示される |
| 検証 | `grep -c "orchestrator\|solution-architect\|implementation-agent" docs/orchestrator-mode.md` ≥ 3 |
| カバー AC | AC-1, AC-9 |

### TC-03: 子 PBI YAML スキーマファイルの存在と構文有効性

| 項目 | 内容 |
|------|------|
| 種別 | Unit（YAML 構文検証）|
| 入力 | `docs/schemas/child-pbi.yaml` |
| 期待出力 | `python3 -c "import yaml; yaml.safe_load(open(...))"` がエラーなく完了 |
| 検証 | exit code 0 |
| カバー AC | AC-2 |

### TC-04: 子 PBI スキーマの必須フィールド

| 項目 | 内容 |
|------|------|
| 種別 | Unit（grep）|
| 入力 | `docs/schemas/child-pbi.yaml` |
| 期待出力 | `id` / `parent_id` / `in_scope` / `out_of_scope` / `dependencies` / `allowed_files` / `forbidden_files` / `acceptance_criteria` / `pr_strategy` の 9 キーすべてが定義されている |
| 検証 | 各キーごとに `grep -q "^[[:space:]]*<key>:" docs/schemas/child-pbi.yaml` |
| カバー AC | AC-2 |

### TC-05: forbidden_files が glob 表現可能

| 項目 | 内容 |
|------|------|
| 種別 | Unit（grep）|
| 入力 | `docs/schemas/child-pbi.yaml` |
| 期待出力 | `forbidden_files` 配下に少なくとも 1 つの `**` または `*` を含む例 |
| 検証 | `grep -A 5 "forbidden_files:" docs/schemas/child-pbi.yaml \| grep -E "\\*\\*|\\*"` |
| カバー AC | AC-2, AC-6 |

### TC-06: `plangate decompose` RFC の存在と Status

| 項目 | 内容 |
|------|------|
| 種別 | Unit |
| 入力 | `docs/rfc/plangate-decompose.md` |
| 期待出力 | ファイル存在 + `Status: Draft` または `Status: 提案中` を含む |
| 検証 | `test -f docs/rfc/plangate-decompose.md && grep -qE "Status:[[:space:]]*(Draft\|提案中)" docs/rfc/plangate-decompose.md` |
| カバー AC | AC-3 |

### TC-07: RFC が実装を別 PBI として明記

| 項目 | 内容 |
|------|------|
| 種別 | Unit（grep）|
| 入力 | `docs/rfc/plangate-decompose.md` |
| 期待出力 | 「実装は別 PBI」「Implementation: out of scope」等の文言を含む |
| 検証 | `grep -E "実装は別|別 PBI|out of scope" docs/rfc/plangate-decompose.md` |
| カバー AC | AC-3 |

### TC-08: dependency-graph テンプレート

| 項目 | 内容 |
|------|------|
| 種別 | Unit |
| 入力 | `docs/working/templates/dependency-graph.md` |
| 期待出力 | ファイル存在 + mermaid `graph` または `flowchart` 記述を含む |
| 検証 | `test -f && grep -E "mermaid\|graph TD\|flowchart" docs/working/templates/dependency-graph.md` |
| カバー AC | AC-4 |

### TC-09: parallelization-plan テンプレート

| 項目 | 内容 |
|------|------|
| 種別 | Unit |
| 入力 | `docs/working/templates/parallelization-plan.md` |
| 期待出力 | ファイル存在 + 「並行可能」「並行不可」両セクションが存在 |
| 検証 | `test -f && grep -q "並行可能" && grep -q "並行不可"` |
| カバー AC | AC-4, AC-6 |

### TC-10: integration-plan テンプレート

| 項目 | 内容 |
|------|------|
| 種別 | Unit |
| 入力 | `docs/working/templates/integration-plan.md` |
| 期待出力 | ファイル存在 + 「統合チェック」「完了条件」両セクションが存在 |
| 検証 | `test -f && grep -q "統合チェック" && grep -q "完了条件"` |
| カバー AC | AC-4, AC-8 |

### TC-11: pr_strategy フィールド仕様

| 項目 | 内容 |
|------|------|
| 種別 | Unit |
| 入力 | `docs/schemas/child-pbi.yaml` + `docs/orchestrator-mode.md` |
| 期待出力 | `pr_strategy` 配下に `branch` / `pr_size` / `merge_after` の 3 サブフィールドが定義されている |
| 検証 | `grep -A 5 "pr_strategy:" docs/schemas/child-pbi.yaml \| grep -qE "branch:.*pr_size:.*merge_after:"`（順序は問わない、3 キー全存在）|
| カバー AC | AC-5 |

### TC-12: ブランチ命名規則の明示

| 項目 | 内容 |
|------|------|
| 種別 | Unit |
| 入力 | `docs/orchestrator-mode.md` または `docs/rfc/plangate-decompose.md` |
| 期待出力 | ブランチ命名規則（`feature/PBI-XXX-NN-*` 等）が記述されている |
| 検証 | `grep -E "feature/PBI-|branch:.*命名"` |
| カバー AC | AC-5 |

### TC-13: 並行実行可能 / 不可条件の明文化

| 項目 | 内容 |
|------|------|
| 種別 | Unit |
| 入力 | `docs/orchestrator-mode.md` または `docs/working/templates/parallelization-plan.md` |
| 期待出力 | 並行可能条件（5 項目）と並行不可条件（5 項目）の両方が箇条書きで記述されている |
| 検証 | 「並行実行可能」配下のリスト項目数 ≥ 4、「並行実行不可」配下も ≥ 4 |
| カバー AC | AC-6 |

### TC-14: 新規子 PBI 作成時の再承認条件

| 項目 | 内容 |
|------|------|
| 種別 | Unit |
| 入力 | `.claude/rules/orchestrator-mode.md` または `docs/orchestrator-mode.md` |
| 期待出力 | `NewChildPBIAllowed` 不変条件 + 「親 PBI 計画の再承認」言及 |
| 検証 | `grep -q "NewChildPBIAllowed" && grep -q "再承認"` |
| カバー AC | AC-7 |

### TC-15: 親 PBI 完了判定の条件定義

| 項目 | 内容 |
|------|------|
| 種別 | Unit |
| 入力 | `.claude/rules/orchestrator-mode.md` または `docs/workflows/orchestrator-integration.md` |
| 期待出力 | `ParentDone` 不変条件 + 「受入基準カバレッジ」言及 |
| 検証 | `grep -q "ParentDone" && grep -q "受入基準"` |
| カバー AC | AC-8 |

### TC-16: ChildExecAllowed 不変条件

| 項目 | 内容 |
|------|------|
| 種別 | Unit |
| 入力 | `.claude/rules/orchestrator-mode.md` |
| 期待出力 | `ChildExecAllowed = ChildPlanApproved AND ParentPlanApproved AND ScopeBoundaryDefined AND DependencyResolved AND RiskGatePassed` 相当の式が含まれる |
| 検証 | `grep -q "ChildExecAllowed" && grep -q "ChildPlanApproved" && grep -q "ParentPlanApproved"` |
| カバー AC | AC-9 |

### TC-17: AI 自己完結禁止条項

| 項目 | 内容 |
|------|------|
| 種別 | Unit |
| 入力 | `docs/orchestrator-mode.md` または `.claude/rules/orchestrator-mode.md` |
| 期待出力 | 「AI が分解・承認・実装・完了判定を完全自己完結してはならない」相当の記述が存在 |
| 検証 | `grep -E "自己完結\|完全自動.*禁止\|人間承認.*必須"` |
| カバー AC | AC-9 |

### TC-18: アーキテクチャ正本から全文書へのリンク網羅

| 項目 | 内容 |
|------|------|
| 種別 | Integration |
| 入力 | `docs/orchestrator-mode.md` |
| 期待出力 | 新規 8 ファイル（schema / 2 workflow / 4 template / rule / RFC のうち少なくとも 6）への相対リンクが存在 |
| 検証 | `grep -cE "\\(\\.\\./schemas/\|\\(\\./workflows/orchestrator\|\\(\\./working/templates/\|\\(\\.\\./\\.claude/rules/orchestrator\|\\(\\./rfc/plangate-decompose"` ≥ 6 |
| カバー AC | 整合性 |

### TC-19: 用語統一（状態名）

| 項目 | 内容 |
|------|------|
| 種別 | Integration |
| 入力 | 新規 9 ファイル全体 |
| 期待出力 | `parent:draft` / `parent:decomposed` / `parent:done` / `child:planned` / `child:executing` の状態名が表記揺れなし（半角コロン、全文書共通） |
| 検証 | `grep -lE "parent[:：]draft\|parent[:：]decomposed"` で全角コロン使用ファイルが 0 |
| カバー AC | 整合性 |

### TC-20: 検証スクリプト存在と実行成功

| 項目 | 内容 |
|------|------|
| 種別 | Integration |
| 入力 | `scripts/check-orchestrator-docs.sh` |
| 期待出力 | スクリプト存在 + `sh scripts/check-orchestrator-docs.sh` が exit code 0 |
| 検証 | `test -f scripts/check-orchestrator-docs.sh && sh scripts/check-orchestrator-docs.sh` |
| カバー AC | 整合性 |

## エッジケース

### EC-01: スキーマ YAML の文字コード

YAML ファイルに UTF-8 BOM が混入していないこと（`file docs/schemas/child-pbi.yaml` で確認）。

### EC-02: 相対リンクの実在性

`docs/orchestrator-mode.md` 内のリンク先がすべて実在すること（broken link なし）。

### EC-03: テンプレート間の用語不一致

4 テンプレートのいずれも「親 PBI」「子 PBI」「parent_id」「child_id」「並行実行」の表記がアーキテクチャ正本と一致すること。

### EC-04: RFC の Status 誤記

`Status: Implemented` 等の誤記が無いこと（実装は本 PBI 範囲外のため）。

### EC-05: forbidden_files の実害

子 PBI YAML 例の `forbidden_files` が、現実のリポジトリに存在しうるパス例（`prisma/schema.prisma` 等）になっており、実用性があること。

## 自動化可否

| TC | 自動化 | 備考 |
|----|-------|------|
| TC-01 〜 TC-20 | ✅ 全自動化 | shell script + grep で完結 |
| EC-01 〜 EC-05 | △ 半自動 | EC-03 / EC-04 は人間レビュー併用推奨 |

検証スクリプト `scripts/check-orchestrator-docs.sh`（exec phase で作成）が TC-01 〜 TC-20 を一括実行する。
