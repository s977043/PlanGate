# EXECUTION PLAN — TASK-0039 (PBI-116-01 / Issue #117)

> 親 PBI: [PBI-116](../PBI-116/parent-plan.md)
> 親 C-3 ゲート: [APPROVED](../PBI-116/approvals/parent-c3.json)（2026-04-30）
> Issue: [#117 Outcome-first Core Contract への移行（prompt slimming）](https://github.com/s977043/plangate/issues/117)

## Goal

PlanGate の中核ルール（Iron Law 7 項目）を維持したまま、**`CLAUDE.md` / `AGENTS.md` を outcome-first 形式に再構成**し、**それぞれが個別に baseline の 50% 以下** に削減する（合計ではなく各ファイル単独評価、ベースラインはマージ前の最新 main 上の行数）。Core Contract を `docs/ai/core-contract.md` に独立定義し、各入口から参照する構造に統一する。

> **削減対象の定義（C-2 EX-03 対応）**: 「常時ロード token 削減」の合否対象は **CLAUDE.md と AGENTS.md がそれぞれ単独で 50% 以下** に固定する（片方が削減できても他方が未達なら不合格）。`.claude/rules/` 等は段階的削減の対象だが本 PBI の合否判定には含めない（V2 候補）。

## Constraints / Non-goals

### Constraints

- 既存の AI 運用 4 原則（CLAUDE.md `<law>` セクション）は維持
- C-3 / C-4 ゲートの機能・運用は変更しない
- Iron Law 7 項目を hard mandate として保持（`必ず` / `NEVER` の使用を許容）
- Plugin 配布版（`plugin/plangate/`）との同期を維持
- Codex CLI（`AGENTS.md`）と Claude Code（`CLAUDE.md`）の双方で同一 Core Contract を参照可能にする

### Non-goals

- C-3 / C-4 Gate の削除・緩和
- モデル別に完全に別プロンプトを作成（→ PBI-116-03 で対応）
- Hook / CLI の実装変更（→ PBI-116-06 で境界定義のみ）
- Structured Outputs schema 設計（→ PBI-116-04 で対応）
- Model Profile 定義（→ PBI-116-02 で対応）

## Approach Overview

3 段階で進める:

1. **棚卸し**: 64 ファイルを対象に hard-mandate キーワード・冗長な手順指定・重複人格指定を抽出（[`notes-117-target-files.md`](../PBI-116/notes-117-target-files.md) の予備調査を活用）
2. **Core Contract の独立化**: `docs/ai/core-contract.md` を新規作成し、Role / Goal / Success criteria / Hard constraints / Decision rules / Available evidence / Stop rules / Output discipline の 8 セクションで定義
3. **入口ファイル薄型化**: `CLAUDE.md` / `AGENTS.md` を Core Contract への導線中心に書き換え、冗長な記述を削除

並列性は低い（同一ファイル群を順次編集するため）。Phase 内のステップは直列実行。

## Work Breakdown (Steps)

### PR 分割方針（Codex 相談 Q3 採用）

- **PR-A**（次セッション）: Step 5 → Step 3 → Step 4（入口ファイル薄型化と参照整合）
- **PR-B**（その次）: Step 6 → Step 7 → Step 8（hard-mandate 削減、検証、handoff）

理由: 入口ファイル薄型化は起動破壊リスクが高く単独レビューしやすい。hard-mandate 削減は `.claude/` と `plugin/plangate/` の同期もあり集中レビュー要。

### 実行順序（Codex 相談 Q4 採用）

- **本 PR (#132)**: Step 1 → Step 2（完了済）
- **PR-A**: Step 5（責務境界 = Core Contract 参照を project-rules に追加）→ Step 3（CLAUDE.md 21〜22 行へ）→ Step 4（AGENTS.md 24〜28 行へ）
- **PR-B**: Step 6 → Step 7 → Step 8

### Step 1: 棚卸し（Phase 1）

- **Output**: `evidence/inventory.md` — 64 ファイルの分類表、hard-mandate キーワード行番号、削減候補マーキング
- **Owner**: agent
- **Risk**: 中（見落としのリスク）
- 🚩 チェックポイント:
  - **必須**: 64 ファイル全件で grep 実行 + 結果記録
  - **本 PBI で編集する優先層**: 入口（CLAUDE.md / AGENTS.md）+ 共通（project-rules.md / ai-driven-development.md）+ 主要コマンド（ai-dev-workflow.md ローカル/Plugin）+ working-context.md（ローカル/Plugin）
  - **本 PBI で編集しない（V2 候補）**: hard-mandate ヒットなしの agents（19 件）、skills（12 件）等
- C-2 EX-05 対応: 棚卸し範囲（全件）と編集範囲（優先層）を明示分離

### Step 2: Core Contract 定義（Phase 2）

- **Output**: `docs/ai/core-contract.md`（新規）
- **Owner**: agent
- **Risk**: 高（Iron Law の正確な転記が必要）
- 🚩 チェックポイント: 8 セクション完備、Iron Law 7 項目が Hard constraints セクションで明示

### Step 3: CLAUDE.md 薄型化（Phase 3a）

- **Output**: `CLAUDE.md`（更新）
- **Owner**: agent
- **Risk**: 高（Claude Code の動作に影響）
- 🚩 チェックポイント: 行数 50% 以下、Core Contract 参照を含む、`<law>` セクション維持

### Step 4: AGENTS.md 薄型化（Phase 3b）

- **Output**: `AGENTS.md`（更新）
- **Owner**: agent
- **Risk**: 中（Codex CLI の動作に影響）
- 🚩 チェックポイント: 行数 50% 以下、Core Contract 参照を含む

### Step 5: project-rules.md 整合（Phase 3c）

- **Output**: `docs/ai/project-rules.md`（更新）
- **Owner**: agent
- **Risk**: 低
- 🚩 チェックポイント: G. 参照先テーブルに Core Contract を追加、ディレクトリ構造に `/docs/ai/core-contract.md` を追記

### Step 6: hard-mandate 削減（Phase 3d）

- **Output**: `.claude/rules/working-context.md`, `.claude/commands/ai-dev-workflow.md`, `plugin/plangate/rules/working-context.md`, `plugin/plangate/commands/ai-dev-workflow.md` 等の更新
- **Owner**: agent
- **Risk**: 中
- 🚩 チェックポイント: Iron Law 7 項目以外で `必ず` / `絶対` / `ALWAYS` / `NEVER` がゼロまたは合理的に説明可能

### Step 7: 検証（Phase 4）

- **Output**: `evidence/verification.md` — 削減前後の比較、grep 結果の差分、Core Contract 参照の到達性確認
- **Owner**: agent
- **Risk**: 中
- 🚩 チェックポイント:
  - **CLAUDE.md と AGENTS.md がそれぞれ単独で baseline の 50% 以下**（合計ではなく各ファイル単独評価、baseline は本 PR 開始時の main 上の値）
  - Iron Law 7 項目は **Core Contract が正本**、CLAUDE.md / AGENTS.md は参照中心（本文を重複転記しない）
  - hard-mandate キーワード残存 → Iron Law 7 項目および AI 運用 4 原則以外がゼロ

### Step 8: 完了（PR 作成）

- **Output**: PR、handoff.md
- **Owner**: agent
- **Risk**: 低
- 🚩 チェックポイント: handoff.md 必須 6 要素完備、status.md 更新

### Stop rules（Codex 相談 Q4 採用）

各 Step で以下が発生した場合は即停止し、ユーザー確認を求める:

| Step | Stop trigger |
|------|------------|
| Step 3 | `<law>` 全文維持と 22 行以下が両立しない |
| Step 4 | `.codex/instructions.md` と AGENTS.md の読み込み順序が矛盾 |
| Step 5 | Core Contract と project-rules の正本責務を一意に定義できない |
| Step 6 | Iron Law / AI 運用 4 原則以外の hard mandate か判断できない表現が出る |
| Step 7 | grep 残存件数が説明不能、またはリンク到達性・行数目標が未達 |
| Step 8 | handoff に未検証項目、WARN、手動確認未実施が残る |

## Files / Components to Touch

### 新規作成

- `docs/ai/core-contract.md`（Core Contract 本体）
- `docs/working/TASK-0039/evidence/inventory.md`（棚卸し）
- `docs/working/TASK-0039/evidence/verification.md`（検証）
- `docs/working/TASK-0039/handoff.md`（WF-05）

### 更新

- `CLAUDE.md`（薄型化）
- `AGENTS.md`（薄型化）
- `docs/ai/project-rules.md`（参照追加）
- `.claude/rules/working-context.md`（hard-mandate 削減）
- `.claude/commands/ai-dev-workflow.md`（同上）
- `plugin/plangate/rules/working-context.md`（同上）
- `plugin/plangate/commands/ai-dev-workflow.md`（同上）
- `.claude/agents/*.md`（hard-mandate ヒット 4 ファイルのみ、慎重に）
- `plugin/plangate/skills/*/SKILL.md`（hard-mandate ヒット 2 ファイルのみ）

### 触らない（forbidden_files）

- `bin/**`, `schemas/**`, `.github/workflows/**`
- `docs/orchestrator-mode.md`, `docs/plangate.md`, `docs/plangate-v7-hybrid.md`

## Testing Strategy

### Unit
- 該当なし（ドキュメント変更のため）

### Integration
- **Markdown lint**: 全更新ファイルで 0 error
- **既存リンクの到達性**: `CLAUDE.md` / `AGENTS.md` から参照される全リンクが解決可能

### E2E
- **Claude Code 起動確認**: 薄型化した CLAUDE.md でセッションが起動し、4 原則が機能すること（手動）
- **Codex CLI 起動確認**: 薄型化した AGENTS.md で codex が起動し、ai-dev-workflow が機能すること（手動）

### Edge cases
- 薄型化により参照先が見つからない場合の挙動（リンク切れチェック）
- Iron Law 7 項目のうち、複数ファイルに重複している項目の整理（Core Contract が正本、他は参照）

### Verification Automation
- `grep -rnE "必ず|絶対|ALWAYS|NEVER" CLAUDE.md AGENTS.md docs/ai/ .claude/ plugin/plangate/` で残存件数を確認 → **Iron Law 7 項目および AI 運用 4 原則以外がゼロ**（4 原則は CLAUDE.md `<law>` セクションで意図的に維持）
- `wc -l CLAUDE.md AGENTS.md` で削減率を測定（**各ファイルが個別に baseline の 50% 以下**、合否対象はこの 2 ファイルのみ）
- baseline は本 PR の base 時点（feat/PBI-116-01-impl ブランチ作成時）の値を `evidence/verification.md` に記録（CLAUDE.md / AGENTS.md それぞれの行数）

## Risks & Mitigations

| ID | Risk | Severity | Mitigation |
|----|------|----------|-----------|
| L1 | `必ず` / `絶対` 削減で意図せず Iron Law を弱化 | high | Iron Law 7 項目を Core Contract の Hard constraints に明示転記、削減対象は手順指定に限定 |
| L2 | 棚卸し 64 ファイルの削減が時間超過 | medium | 優先順序（入口 → 共通 → コマンド → ルール → Plugin）に従い、1 セッション内では入口 + 共通 + 必要最小限のコマンド層に絞る |
| L3 | 入口薄型化で Claude Code / Codex CLI 双方の動作が壊れる | high | C-2 外部AIレビュー必須、削減後に手動起動確認 |
| L4 | Plugin 配布版との同期漏れ | medium | allowed_files に plugin 側を含め、Step 6 で同期確認 |
| L5 | Iron Law 7 項目のうち #6（root cause）/ #7（two-stage review）が既存 ai-driven-development.md の 6 項目と齟齬 | medium | Core Contract 作成時に既存定義を吸収、ai-driven-development.md 側で参照に切替 |

## Questions / Unknowns

- Q1: `CLAUDE.md` / `AGENTS.md` の最終的な目標行数は？
  - A1: 50% 以下を目安。具体値は実施結果次第。
- Q2: `docs/ai/core-contract.md` は ai-driven-development.md の Iron Law 6 項目を吸収するか？
  - A2: 吸収する。ai-driven-development.md は Core Contract への参照に切替。
- Q3: Plugin 配布版（`plugin/plangate/rules/working-context.md`）はローカル版と同一内容にするか？
  - A3: ローカル版と同期。Plugin 配布形態固有の差分（v8.1 ガードレール）は Plugin 限定 rules に残す。

## Mode判定

**モード**: high-risk

判定根拠:
- 変更ファイル数: 10〜15（入口 + 共通 + コマンド + 一部 agents/skills）→ high-risk
- 受入基準数: 6 → standard 〜 high-risk
- 変更種別: 入口ファイル + 共通ルール + Plugin 同期（横断的）→ high-risk
- リスク: 高（Claude Code / Codex CLI 双方の動作に影響）→ high-risk
- ロールバック: PR revert で容易に戻せる → standard / high-risk
- **最終判定**: **high-risk**（子 PBI YAML の `mode: high-risk` と整合）

判定基準正本: [`.claude/rules/mode-classification.md`](../../../.claude/rules/mode-classification.md)
