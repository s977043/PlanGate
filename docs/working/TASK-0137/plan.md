# EXECUTION PLAN — TASK-0137 (#581 残要素3/4)

## Goal
#581 の残要素3（Subagent ファイルベース復元）と要素4（Review Gate Plan Alignment）を skills/templates の追加で実装し、#581 をクローズ可能にする。既存（context-packager / review-gate）を活かし不足層のみ追加。

## Constraints / Non-goals
- skills（context-packager / subagent-dispatch / subagent-driven-development / review-gate）+ templates のみ編集（**HO 非該当**）。
- `.claude/rules/review-principles.md`（HO）は**参照のみ・本体改変しない**。5 観点・Severity・判定基準（§2-4）不変。
- `.claude/agents/qa-reviewer.md`（HO）は対象外。`plugin/plangate/rules/` の指定 3 ファイル（review-gate/completion-gate/subagent-roles）は本ツリー不在のため対象外・既存 tracked rules も編集しない（Refs R-002）。
- schema/CLI 拡張・gate 強制しない。#583/#584 と重複しない（要素1/2 は完了済）。

## Approach Overview（researcher 重複マッピング反映）
**要素3**: #584 の `evidence/tdd/` dir 規約パターンを踏襲し `dispatch/` 成果物層を追加。
1. `docs/working/templates/dispatch/` に brief/report/review-package/progress-ledger テンプレ新設。
2. context-packager に「Allowed Context → dispatch/task-NNN-brief.md 保存」工程を追記。
3. subagent-dispatch / subagent-driven-development に「会話でなくファイルで渡す / progress-ledger で再開」を明文化。

**要素4**: review-principles §2-4 を不変に保ち、追加レーンとして実装。
4. review-gate SKILL + review-external テンプレに Plan Alignment / Evidence Alignment / Production Readiness ブロックを追加（design.md 逸脱 / test↔Evidence / Target Files 外 / Out of Scope / 過剰機能）。

## Work Breakdown
- **S1** dispatch/ テンプレ 4 種を新設 / Owner: agent / Risk: 既存 evidence/ との粒度整合 / rollback: git rm -r docs/working/templates/dispatch
- **S2** context-packager に dispatch/brief 保存工程を追記 / Owner: agent / Risk: 既存出力との整合 / rollback: git checkout -- plugin/plangate/skills/context-packager/SKILL.md
- **S3** subagent-dispatch / subagent-driven-development にファイルベース原則を明文化 / Owner: agent / Risk: 既存手順との重複 / rollback: git checkout -- plugin/plangate/skills/subagent-dispatch/SKILL.md .claude/skills/subagent-driven-development/SKILL.md
- **S4** review-gate SKILL + review-external に Plan Alignment ブロック（§2-4 不変）/ Owner: agent / Risk: review-principles との二重定義 / rollback: git checkout -- plugin/plangate/skills/review-gate/SKILL.md docs/working/templates/review-external.md

## Files / Components to Touch
- `docs/working/templates/dispatch/{task-NNN-brief,task-NNN-report,task-NNN-review-package,progress-ledger}.md`（新規・AI 可）
- `plugin/plangate/skills/context-packager/SKILL.md`（AI 可・HO 外）
- `plugin/plangate/skills/subagent-dispatch/SKILL.md` / `.claude/skills/subagent-driven-development/SKILL.md`（AI 可・HO 外）
- `plugin/plangate/skills/review-gate/SKILL.md`（AI 可・HO 外）
- `docs/working/templates/review-external.md`（AI 可・HO 外）
- 参照のみ: `.claude/rules/review-principles.md`（HO）/ `.claude/agents/qa-reviewer.md`（HO）/ `plugin/plangate/rules/*`（未tracked）

## Testing Strategy
- 機械: dispatch/ テンプレ 4 種の存在（ls）、context-packager/subagent SKILL に「ファイル/dispatch/progress-ledger」grep、review-gate/review-external に Plan Alignment ブロック grep、review-principles.md が unchanged（git diff 空）
- レビュー: 5 観点・Severity 不変、rules/qa-reviewer 未改変、#583/#584 と非重複
- markdownlint

## Risks & Mitigations
- R1 review-principles.md(HO) 改変 / skill/template のみに置き rules 参照 / git diff で rules unchanged 検証
- R2 変更ファイル多数で複雑 / 要素3/4 を S1-S4 に分離・各 rollback 明示 / 段階確認
- R3 plugin/plangate/rules 未tracked を誤編集 / 対象外明記・本ツリー skill/template のみ / find で確認

## Metrics Evidence
- 対象「変更ファイル」: 実数 9（dispatch 4 + context-packager 1 + subagent×2 + review-gate 1 + review-external 1）/ 見積もり 9 / ratio 1.0 → high-risk（Refs R-003）。

## Questions / Unknowns
- dispatch/ と既存 evidence/ の関係 → dispatch=実行前ブリーフ/進捗、evidence=検証証跡で責務分離。

## Mode判定

**モード**: high-risk

**判定根拠**:
- 変更ファイル数: 9（dispatch 4 + skills 3 + review-gate 1 + review-external 1）→ high-risk
- 受入基準数: 6 → high-risk 寄り
- 変更種別: 複数 skill + 新規テンプレ群（実行層の dispatch/review 構造）
- 影響範囲: subagent 実行・review フロー（複数レイヤー）
- **最終判定**: high-risk（lite_eligible=false・**人間 C-3 必須**・autonomous APPROVE 不可）。ただし HO 非該当（skills/templates・rules 参照のみ）のため C-3 後 exec は AI 可。
