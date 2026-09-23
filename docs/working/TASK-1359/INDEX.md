# TASK-1359 INDEX

> 最終更新: 2026-09-23 12:45
> Issue: #1359
> Draft PR: #1360
> Mode: critical

## チケット概要

#933 / #810 / #867 を Plan生成時の evidence / uncertainty / knowledge continuity として統合する。
#1358 compatibilityは解消済み。PR #1364でexecution protocol/config/smoke contract、PR #1366でCodex runtime compatibility contractまでfreeze済み。実モデル評価結果固定が次のhard dependency。

## 現在のフェーズ

- **Planning package: MERGE_READY**
- **Execution: BLOCKED**

- internal Plan review: complete
- PR #1360 CI/Test/CodeQL/Issue Link: PASS
- PR #1360 diff: `docs/working/TASK-1359/**` only
- planning baseline merge does not modify frozen #1337 baseline/candidate SHAs
- execution blocker: **#1337 paired evaluation result not fixed**
- Human C-3 / production implementation: blocked until T-00

## 次のアクション

1. Human C-4: planning-only PR #1360 をmergeしてplanning baselineをmainへ確定
2. #1337 3-call smoke（Codex CLI >=0.144.0 / exact version freeze）→ 48 generations → blind scoringを完了し、pair-level result / downstream decisionを固定
3. T-00で結果を読み、TASK-1359 replan要否を判定
4. 必要ならC-1/C-2 refresh
5. Human C-3
6. APPROVEDなら実装用branch/PRでT-03以降

## ファイルマップ

| ファイル | 用途 |
|---|---|
| `pbi-input.md` | 統合要件・AC・dependency ownership |
| `plan.md` | critical Plan / source hierarchy / external blocker |
| `todo.md` | T-00〜T-16 + H-01/H-02 |
| `test-cases.md` | TC-01〜TC-13 |
| `review-self.md` | fresh C-1 |
| `review-external.md` | fresh multi-perspective review |
| `decision-log.jsonl` | append-only decisions |
| `evidence/c1-review/2026-09-23-rebase-compatibility.md` | #1358 compatibility |
| `evidence/c1-review/2026-09-23-evaluation-integrity.md` | #1337 candidate isolation / TC-13 initial |
| `evidence/c1-review/2026-09-23-post-1364-evaluation-integrity.md` | #1364 merge後のlatest-main isolation / TC-13 refresh |
| `evidence/c1-review/2026-09-23-post-1366-evaluation-integrity.md` | #1366 runtime hardening merge後のlatest-main isolation / TC-13 refresh |
| `status.md` | phase history |
| `current-state.md` | resumable snapshot |

## Explicit ownership boundaries

- #1337: Plan Design Principles paired evaluation
- #1347: Human Decision Surface / Plan compression experiment after #1337
- ADR-006 / #1352-#1355: Plan Deliberation / C-2 disagreement clarification
- #1343/#1349: Human Attention measurement semantics
- #1359: Prior Artifact / Unknown / Knowledge Delta continuity
- #960: HO-side C-1 execution drift
