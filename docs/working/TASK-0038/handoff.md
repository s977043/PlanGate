# Handoff — TASK-0038: Parent-Child PBI Orchestrator Mode 仕様策定

> 関連 Issue: [#109](https://github.com/s977043/plangate/issues/109)
> 親 Epic: [#72](https://github.com/s977043/plangate/issues/72)
> モード: high-risk（仕様策定のみ）
> ブランチ: `feat/task-0038-parent-child-pbi`
> 完了日: 2026-04-28

## 1. 要件適合確認結果

Issue #109 の受入基準 9 項目および本 PBI の AC-1〜AC-9 すべて **PASS**（自動検証スクリプト `scripts/check-orchestrator-docs.sh` で 20 / 20 PASS）。

| AC | 説明 | 対応文書 | 検証 TC | 結果 |
|----|------|---------|--------|------|
| AC-1 | 親 PBI / 子 PBI 責務定義 | `docs/orchestrator-mode.md` | TC-01, TC-02 | ✅ |
| AC-2 | 子 PBI フォーマット定義 | `docs/schemas/child-pbi.yaml` | TC-03, TC-04, TC-05 | ✅ |
| AC-3 | `plangate decompose` 仕様化 | `docs/rfc/plangate-decompose.md` | TC-06, TC-07 | ✅ |
| AC-4 | dependency / parallelization / integration 成果物 | `docs/working/templates/{dependency-graph,parallelization-plan,integration-plan}.md` | TC-08, TC-09, TC-10 | ✅ |
| AC-5 | 子 PBI ごとの PR 作成方針 | `docs/schemas/child-pbi.yaml` `pr_strategy` + `docs/orchestrator-mode.md` | TC-11, TC-12 | ✅ |
| AC-6 | 並行実行可能 / 不可条件 | `docs/orchestrator-mode.md` + `docs/working/templates/parallelization-plan.md` | TC-13 | ✅ |
| AC-7 | 新規子 PBI 作成時の親計画再承認 | `.claude/rules/orchestrator-mode.md` `NewChildPBIAllowed` | TC-14 | ✅ |
| AC-8 | 親 PBI 完了判定（受入基準カバレッジ）| `.claude/rules/orchestrator-mode.md` `ParentDone` + `docs/workflows/orchestrator-integration.md` | TC-15 | ✅ |
| AC-9 | AI 自己完結禁止 Gate 条件 | `.claude/rules/orchestrator-mode.md`「AI 自己完結禁止条項」 | TC-16, TC-17 | ✅ |

整合性チェック (TC-18〜TC-20) も PASS（リンク網羅 / 用語統一 / 検証スクリプト存在）。

### V-1 検証結果サマリ

```text
$ sh scripts/check-orchestrator-docs.sh
[PASS] TC-01 〜 TC-20  (20 件)
=== Summary ===
Results: 20 passed, 0 failed
```

## 2. 既知課題一覧

| ID | 内容 | 影響範囲 | 対応方針 |
|----|------|---------|---------|
| K-1 | rule ファイルは英名 (`ParentAcceptanceCriteriaCovered` 等) ベース、本文は日本語混在 | 機械可読性 | 実装 PBI で機械チェック実装時に最終確定 |
| K-2 | `dependency-graph-build` / `coverage-matrix-build` Skill は新規候補として言及されているが、Skill 定義ファイル (`.claude/skills/...`) は未作成 | Skill 層 | 別 PBI で Skill 化検討 |
| K-3 | GitHub Issue sub-issue API との連携可否は仕様化していない（OQ-1）| 連携層 | 実装 PBI で確定 |
| K-4 | `plangate status` の親 PBI 拡張 vs 新コマンド `plangate parent-status` 新設の判断は保留（OQ-2）| CLI 層 | 実装 PBI で確定 |
| K-5 | `--mode auto` での LLM provider 出力フォーマット標準化は未着手（OQ-3）| Provider 層 | `--mode auto` 実装 PBI で確定 |
| K-6 | 親 PBI レベルの decision-log.jsonl フォーマットは「append-only」とのみ規定、具体的なスキーマは未定義 | ログ層 | 実装 PBI で確定 |
| K-7 | TC-19（用語統一）は grep ベースのため、構造的逸脱は検出できない | 検証層 | 別 PBI で構造解析チェッカ追加検討 |

## 3. V2 候補（後続 PBI）

仕様策定で残した実装 / 機能拡張領域:

| カテゴリ | 内容 | 推奨 PBI |
|---------|------|---------|
| **CLI 実装** | `plangate decompose --mode manual` の最小実装 | 別 PBI（Phase 1）|
| **CLI 実装** | `plangate decompose --mode assisted`（heuristic）| 別 PBI（Phase 2）|
| **CLI 実装** | `plangate decompose --validate`（YAML schema validation）| 別 PBI（Phase 3）|
| **CLI 実装** | `plangate decompose --mode auto`（LLM provider 統合）| 別 PBI（Phase 4）|
| **Agent 実装** | Parent Supervisor / Integration Agent の実装本体 | 別 PBI |
| **Skill 追加** | `dependency-graph-build` / `coverage-matrix-build` Skill | 別 PBI |
| **Hook 実装** | Gate 不変条件（ChildExecAllowed / ParentDone / NewChildPBIAllowed）の機械強制 | 別 PBI |
| **Workflow DSL** | `workflows/orchestrator-decomposition.yaml` / `orchestrator-integration.yaml` | 別 PBI |
| **Status 拡張** | `plangate status` の親 PBI 表示対応 or `parent-status` 新設 | 別 PBI |
| **GitHub 連携** | sub-issue API による親 / 子 PBI の Issue 自動作成 | 別 PBI（オプション）|
| **Evidence Ledger** | 親 PBI レベルの Ledger 集約 | 別 PBI |
| **並行ランタイム** | マルチプロセス並行実行（worktree + 各 child の exec を並列起動）| 別 PBI |

## 4. 妥協点（採用しなかった選択肢と理由）

| 妥協 | 採用しなかった選択 | 理由 |
|------|------------------|------|
| 新規 Agent 5 体を全部追加 | Parent Supervisor / Child Planner / Child Implementer / Review / Integration を **すべて新規追加** | 既存 v7 hybrid の 5 Agent と責務が重複するため、**既存 Agent の責務を親 / 子層で再評価**するアプローチに変更（Integration Agent のみ新規）|
| 新規 Workflow phase を 5 phase 全部置換 | 既存 WF-01〜WF-05 を破棄して orchestrator 用 5 phase に置換 | 既存 PBI 運用との後方互換性を損なうため、**並立追加**（Decomposition / Integration の 2 phase を WF と並立）に変更 |
| schema を JSON Schema で記述 | `docs/schemas/child-pbi.yaml` を JSON Schema 形式 | 仕様策定段階では「コメント付き代表 YAML」のほうが可読性が高い。実装 PBI で JSON Schema / Pydantic 化 |
| `plangate decompose` を即実装 | 本 PBI で CLI 実装まで含める | スコープが膨張し high-risk が critical 化する。**RFC を Draft で確定、実装は別 PBI** に委譲 |
| 親 PBI 用の独立 working context 構造 | `docs/working/PBI-XXX/` を新規構造として完全独立 | 既存 `docs/working/TASK-XXXX/` 運用との互換性のため、**並立可能**な設計に留めた（最終構造は実装 PBI で確定）|

## 5. 引き継ぎ文書（5 分で状況把握）

### この PBI で何が完成したか

PlanGate を **単一 PBI 制御**から **親 PBI 配下の複数子 PBI を統制するオーケストレーションシステム**へ拡張するための **仕様文書群** が確定した。

- 設計原則: 「AI に任せる範囲を広げる。ただし、Gate を消さない。」
- 既存 v7 hybrid を **置換せず内側で拡張**
- 既存 5 mode（ultra-light 〜 critical）と **直交する軸**

### 新規追加された 11 ファイル

| カテゴリ | ファイル | 役割 |
|---------|---------|------|
| アーキ正本 | `docs/orchestrator-mode.md` | Parent-Child モデル / 状態遷移 / Sub Agent / Gate 条件の概念定義 |
| Schema | `docs/schemas/child-pbi.yaml` | 子 PBI YAML スキーマ + バリデーション規則 |
| Workflow | `docs/workflows/orchestrator-decomposition.md` | 分解フロー（D-1〜D-7）|
| Workflow | `docs/workflows/orchestrator-integration.md` | 統合フロー（I-1〜I-4 + Gap 分岐）|
| Template | `docs/working/templates/parent-plan.md` | 親計画テンプレート |
| Template | `docs/working/templates/dependency-graph.md` | 依存関係グラフテンプレート |
| Template | `docs/working/templates/parallelization-plan.md` | 並行実行計画テンプレート |
| Template | `docs/working/templates/integration-plan.md` | 統合計画テンプレート |
| Rule | `.claude/rules/orchestrator-mode.md` | Gate 不変条件の正本（機械チェック規則を含む）|
| RFC | `docs/rfc/plangate-decompose.md` | `plangate decompose` CLI RFC（Status: Draft）|
| 検証スクリプト | `scripts/check-orchestrator-docs.sh` | TC-01〜TC-20 自動検証 |

### 更新ファイル（4 ファイル）

- `README.md` / `README_en.md` — Read Next 表に orchestrator-mode を追加
- `docs/index.md` — はじめに読むもの に追加
- `docs/workflows/README.md` — Orchestrator Mode 拡張セクションを追加

### 次に何をすべきか

1. **本 PBI の C-4 ゲート（PR レビュー）通過 → main マージ**
2. 後続 PBI として最低 3 つを順次起票:
   - `plangate decompose --mode manual` 最小実装（Phase 1）
   - Parent Supervisor / Integration Agent の責務定義 → Skill / Agent ファイル化
   - Hook による Gate 不変条件の機械強制
3. 実運用での試験（ダミー親 PBI で fork & test）

### よくある質問

- **Q: 既存 PBI 運用は破壊的に変更されるか？**
  - A: いいえ。既存 `docs/working/TASK-XXXX/` と `workflows/<mode>.yaml` は **無変更**。Orchestrator Mode は並立追加のみ。
- **Q: いつから使えるか？**
  - A: 本 PBI は **仕様のみ**。実装は後続 PBI が必要。手動運用は本 PBI マージ後すぐ可能（テンプレートをコピーして親計画を立て、子 PBI を YAML で記述）。
- **Q: 既存の CLAUDE.md / AGENTS.md を更新する必要は？**
  - A: 現時点では不要。実装 PBI で `plangate decompose` が CLI 化されるタイミングで更新する。

## 6. テスト結果サマリ

### 自動検証

```text
$ sh scripts/check-orchestrator-docs.sh
Results: 20 passed, 0 failed
```

### 既存テスト（回帰なし）

```text
$ sh tests/run-tests.sh
Results: 10 passed, 0 failed
```

### YAML 構文検証

```text
$ python3 -c "import yaml; yaml.safe_load(open('docs/schemas/child-pbi.yaml'))"
（成功）
```

### V-2 / V-3 / V-4

| ステップ | 結果 |
|---------|------|
| V-2 コード最適化 | N/A（コード変更なし）|
| V-3 外部モデルレビュー | 任意 / スキップ（ドキュメント整合性検証で代替）|
| V-4 リリース前チェック | N/A（critical のみ対象）|

---

**handoff 完了 — C-4 ゲート（PR レビュー）に進む。**
