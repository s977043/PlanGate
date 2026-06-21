# TEST CASES — TASK-0137 (#581 残要素3/4)

## AC → TC
### AC-01: dispatch/ テンプレ
- TC-01: docs/working/templates/dispatch/ に task-NNN-brief.md / task-NNN-report.md / task-NNN-review-package.md / progress-ledger.md が存在。種別: 機械（ls）
### AC-02: context-packager の brief 保存規定
- TC-02: context-packager SKILL に「dispatch/task-NNN-brief.md に保存」相当の記述。種別: 機械（grep）
### AC-03: ファイルベース原則
- TC-03: subagent-dispatch / subagent-driven-development に「会話履歴でなくファイル / progress-ledger から再開」が明文化。種別: 機械（grep 両ファイル）
### AC-04: Review Gate Plan Alignment
- TC-04: review-gate SKILL + review-external に Plan Alignment / Evidence Alignment / Production Readiness ブロック（design.md逸脱/test↔Evidence/Target Files外/Out of Scope/過剰機能）。種別: 機械（grep 両ファイル）
### AC-05: 5観点不変・HO非改変
- TC-05: review-principles.md が unchanged（`git diff origin/main -- .claude/rules/review-principles.md` が空）+ qa-reviewer.md / plugin/plangate/rules/* 未改変。5観点・Severity 不変。種別: 機械（git diff）
### AC-06: #583/#584 と非重複
- TC-06: 追加内容が要素1（Task Sizing/No Placeholders）・要素2（TDD phase）と重複しない（要素3・4 のみ）。種別: レビュー

## Edge cases
- EC-01: dispatch/ と evidence/ は責務分離（dispatch=実行前ブリーフ/進捗、evidence=検証証跡）
- EC-02: Plan Alignment は §2-4 不変の追加レーン（観点数を 5 から増やさない）
- EC-03: TDD 必須 mode 以外では RED/GREEN 証跡欠落を major にしない（条件付き）
