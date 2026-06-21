# PBI INPUT PACKAGE: Subagent ファイルベース復元 + Review Gate Plan Alignment (#581 残要素3/4)

> フェーズ A。正本: `.claude/rules/working-context.md`。#581 の要素1(#583)/要素2(#584) はマージ済、本 PBI で残る要素3・4 を完了し #581 をクローズする。

## Context / Why
Superpowers 由来の #581 で、要素3（Subagent をファイルベースで復元可能に）と要素4（Review Gate を Plan Alignment 中心に強化）が未着手。researcher 調査で、要素3 は土台（context-packager の Allowed Context 6 要素）があるがファイル成果物層が欠落、要素4 は review-gate 6 観点で半分カバーだが Plan 正本突合が欠落と判明。既存を活かし不足層のみ追加する。

## What（Scope）

### In scope
**要素3（Subagent ファイルベース復元）**
- `docs/working/templates/` に `dispatch/` 成果物テンプレを新設: `task-NNN-brief.md` / `task-NNN-report.md` / `task-NNN-review-package.md` / `progress-ledger.md`
- `context-packager` SKILL: Allowed Context 出力を「会話埋め込み」→「`dispatch/task-NNN-brief.md` に保存」と規定
- `subagent-dispatch` / `subagent-driven-development` SKILL: 「reviewer は review-package ファイルのみ入力・会話履歴を渡さない / compaction・モデル切替後は progress-ledger から再開」を明文化

**要素4（Review Gate Plan Alignment）**
- `plugin/plangate/skills/review-gate/SKILL.md` + `docs/working/templates/review-external.md`(C-2/V-3) に「Plan Alignment / Evidence Alignment / Production Readiness」チェックブロックを追加:
  - design.md 逸脱 / test-cases.md ↔ Evidence Ledger 対応 / Target Files 外変更 / Out of Scope 抵触 / 過剰機能
  - #584 の tdd_red/green 証跡を「TDD 必須 mode で RED/GREEN 証跡なしは major」として Evidence Alignment に紐付け
- **5 観点・Severity・判定基準（review-principles.md §2-4）は不変**（C-2 設計妥当性レーン §7-bis と整合する追加レーンとして設計）

### Out of scope
- `.claude/rules/review-principles.md`（HO・**参照のみ**・本体改変しない）
- `.claude/agents/qa-reviewer.md`（HO・別途 Human 適用が必要なため本 PBI 外）
- `plugin/plangate/rules/{review-gate,completion-gate,subagent-roles}.md`（**指定 3 ファイルは本ツリーに存在しないため対象外**。既存 tracked rules も編集対象外 / Refs R-002）
- schema / CLI 拡張・gate 機械強制

## 受入基準
- [ ] AC-01: `docs/working/templates/dispatch/` に brief/report/review-package/progress-ledger テンプレが存在する
- [ ] AC-02: context-packager が Allowed Context を `dispatch/task-NNN-brief.md` に保存する旨を規定している
- [ ] AC-03: subagent-dispatch/driven-development に「会話履歴でなくファイルで渡す / progress-ledger から再開」が明文化されている
- [ ] AC-04: review-gate SKILL + review-external に Plan Alignment / Evidence Alignment / Production Readiness ブロックが追加されている
- [ ] AC-05: 5 観点・Severity・判定基準（review-principles.md §2-4）は不変で、rules 本体・qa-reviewer.md を改変していない（HO 回避）
- [ ] AC-06: #581 要素1(#583)/要素2(#584) と重複しない（要素3・4 のみ）

## Notes from Refinement
researcher 調査の結論:
- 要素3: 土台あり（context-packager 6 要素・subagent-dispatch）、欠落=dispatch/ ファイル成果物層。#584 が `evidence/tdd/` dir 規約を作った前例と同パターン。
- 要素4: review-gate「仕様準拠/破壊的変更/セキュリティ」で半分カバー、欠落=Plan 正本突合。**review-principles §2-4 不変**が最大の整合制約。
- HO 回避: skill/template に置き rules は参照のみ。plugin/plangate/rules/* は未tracked（Plugin 配布限定）のため編集対象にしない。

## Estimation Evidence
### Risks
- review-principles.md（HO）改変リスク → skill/template のみに置き rules 参照
- 変更ファイル多数（skills 3-4 + templates 複数）→ high-risk
### Unknowns
- dispatch/ テンプレの粒度 → 初回は最小（brief/report/review-package/progress-ledger の枠）
### Assumptions
- skills/templates のみ（HO 非該当）→ C-3 後 AI exec 可
