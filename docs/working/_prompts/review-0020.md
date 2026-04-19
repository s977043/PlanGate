You are performing the PlanGate C-2 external AI review.

# Target
Review the following 4 files for TASK-0020:
- docs/working/TASK-0020/pbi-input.md
- docs/working/TASK-0020/plan.md
- docs/working/TASK-0020/todo.md
- docs/working/TASK-0020/test-cases.md

Read all 4 files carefully. Cross-reference the parent ticket context in docs/working/TASK-0016/pbi-input.md for the overall initiative.

# Review Framework (from .claude/rules/review-principles.md)

## 5 Review Perspectives
1. **可読性 (Readability)**: clarity of naming, structure, comprehensibility
2. **拡張性 (Extensibility)**: architectural boundaries, dependency direction, responsibility separation
3. **パフォーマンス (Performance)**: efficiency (for planning docs, this maps to "efficiency of the planned work")
4. **セキュリティ (Security)**: input validation, auth, sensitive info, injection
5. **保守性 (Maintainability)**: test quality, pattern consistency, debugging ease, leftover artifacts

## Severity Levels
- **critical**: production-breaking, data corruption, vulnerability (blocker)
- **major**: logic error, insufficient tests, design violation (fix recommended)
- **minor**: improvement suggestion, naming, style (optional)
- **info**: FYI, future considerations (ignorable)

## Judgment
- **Auto-approve**: critical=0, major=0, no security concerns
- **Human review recommended**: major >= 1 or total score 70-89
- **Human review required**: critical >= 1 or total score < 70

# Additional Review Criteria for PlanGate B-phase Documents

Check also:
- **C1-PLAN-01**: Acceptance criteria coverage — are all acceptance criteria in pbi-input.md mapped to plan/todo/test-cases?
- **C1-PLAN-02**: Unknowns processing — are all Unknowns in pbi-input.md addressed?
- **C1-PLAN-03**: Scope control — does plan/todo stay within In scope / avoid Out of scope?
- **C1-PLAN-04**: Testing strategy — is it comprehensive and aligned with acceptance criteria?
- **C1-PLAN-05**: Work Breakdown Output — does each step have concrete Output specified?
- **C1-PLAN-06**: Dependencies — are dependencies between tasks and on prerequisite TASKs correctly captured?
- **C1-PLAN-07**: Verification automation — are there automated verification commands in Testing Strategy?

# Output
Write the review result to: docs/working/TASK-0020/review-external.md

Use this exact structure:

```markdown
# TASK-0020 外部AIレビュー結果

> 実施日: 2026-04-19
> レビュアー: Codex (codex-cli 0.115.0)
> 対象: pbi-input.md / plan.md / todo.md / test-cases.md

## 総合判定

**判定**: {Auto-approve | Human review recommended | Human review required}
**総合スコア**: {0-100}/100

## Severity 集計

| Severity | 件数 |
|----------|------|
| critical | N |
| major    | N |
| minor    | N |
| info     | N |

## 5観点スコア

| 観点 | スコア | 所感 |
|-----|-------|-----|
| 可読性 | /20 | ... |
| 拡張性 | /20 | ... |
| パフォーマンス | /20 | ... |
| セキュリティ | /20 | ... |
| 保守性 | /20 | ... |

## PlanGate B-phase チェック (C1-PLAN-01〜07)

| ID | 項目 | 判定 | 備考 |
|----|------|------|------|
| C1-PLAN-01 | 受入基準網羅性 | PASS/WARN/FAIL | ... |
| C1-PLAN-02 | Unknowns処理 | PASS/WARN/FAIL | ... |
| C1-PLAN-03 | スコープ制御 | PASS/WARN/FAIL | ... |
| C1-PLAN-04 | テスト戦略 | PASS/WARN/FAIL | ... |
| C1-PLAN-05 | Work Breakdown Output | PASS/WARN/FAIL | ... |
| C1-PLAN-06 | 依存関係 | PASS/WARN/FAIL | ... |
| C1-PLAN-07 | 動作検証自動化 | PASS/WARN/FAIL | ... |

## 指摘事項

### Critical (N件)
（なければ「なし」）

### Major (N件)
- **[観点]** 指摘内容
  - 対象ファイル:行番号
  - 改善案: ...

### Minor (N件)
- ...

### Info (N件)
- ...

## 推奨アクション

- [ ] ...
- [ ] ...

## 結論

{1-2文で総括}
```

Be specific. Reference file paths and line numbers where applicable. Avoid generic feedback.

Apply False-positive guards:
- Do not flag issues that static analysis tools would catch
- Limit minor/info to 5 items total
- Do not comment on unchanged code
- Do not make speculative assumptions
