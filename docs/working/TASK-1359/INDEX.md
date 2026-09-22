# TASK-1359 INDEX

> 最終更新: 2026-09-23 02:38
> Issue: #1359
> Draft PR: #1360
> Mode: critical

## チケット概要

#933（Prior Artifact Discovery）/ #810（Unknown Discovery）/ #867（Knowledge Delta）を、
Plan生成時の evidence / uncertainty / knowledge continuity として一つのplanning flowへ統合する。

## 現在のフェーズ

**C-3 待ち**

#1358 merge/rebase、TC-12 compatibility、C-1/C-2 refreshまで完了。
implementationはHuman C-3 APPROVEDまで開始しない。

## 次のアクション

1. Human C-3 review
2. APPROVEDならT-03以降を開始
3. CONDITIONALなら条件をplan/todo/test-casesへ反映して再review
4. REJECTならPlanをreplan

## ファイルマップ

| ファイル | 用途 |
|---|---|
| `pbi-input.md` | #933/#810/#867統合要件・AC・source ownership |
| `plan.md` | critical implementation plan / source hierarchy / C-1 landing map |
| `todo.md` | T-01〜T-16 + H-01/H-02 |
| `test-cases.md` | TC-01〜TC-12 / AC trace / #1358 compatibility |
| `review-self.md` | fresh C-1 25項目レビュー |
| `review-external.md` | fresh multi-perspective/C-2相当レビュー |
| `decision-log.jsonl` | planning decisions append-only |
| `evidence/c1-review/2026-09-23-rebase-compatibility.md` | rebase / TC-12 fresh evidence |
| `status.md` | phase history |
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
