# TASK-1359 INDEX

> 最終更新: 2026-09-23 02:13
> Issue: #1359
> Draft PR: #1360
> Mode: critical

## チケット概要

#933（Prior Artifact Discovery）/ #810（Unknown Discovery）/ #867（Knowledge Delta）を、
Plan生成時の evidence / uncertainty / knowledge continuity として一つのplanning flowへ統合する。

## 現在のフェーズ

**BLOCKED**

Plan package / C-1 / multi-perspective review は作成済み。
blocker は **PR #1358 の Human C-4 / merge**。#1358 merge前にTASK-1359のproduction planning surfacesへ実装しない。

## 次のアクション

1. PR #1358 を Human C-4 で判断・merge
2. TASK-1359 branchをmerge後mainへrebase
3. `diff-audit` / `review-gate` responsibility boundaryを再確認
4. #1358-owned `C1-TEST-14` baselineを保存
5. C-1再実行 + TC-12 compatibility review
6. C-2 refresh
7. Human C-3
8. APPROVED後にT-03以降をexec

## ファイルマップ

| ファイル | 用途 |
|---|---|
| `pbi-input.md` | #933/#810/#867統合要件・AC・source ownership |
| `plan.md` | critical implementation plan / source hierarchy / C-1 landing map |
| `todo.md` | T-01〜T-16 + H-01/H-02 |
| `test-cases.md` | TC-01〜TC-12 / AC trace / #1358 compatibility |
| `review-self.md` | C-1 25項目レビュー |
| `review-external.md` | architecture/governance/test/adversarial multi-perspective review |
| `decision-log.jsonl` | planning decisions append-only |
| `status.md` | phase history / blocker |
| `current-state.md` | resumable current snapshot |

## Planned production touch points

- `docs/working/templates/plan.md`
- `docs/ai-driven-development.md`
- `.agents/skills/ai-dev-plan/SKILL.md`
- `docs/working/templates/review-self.md`
- `.agents/skills/diff-audit/SKILL.md`
- plugin/Codex mirrors
- fixed evaluation fixtures

HO `.claude/rules/working-context.md` は変更しない。
