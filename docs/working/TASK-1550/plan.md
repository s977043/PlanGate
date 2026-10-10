---
task_id: TASK-1550
artifact_type: plan
schema_version: 1
status: draft
mode: high-risk
related_issue: https://github.com/s977043/PlanGate/issues/1550
created_by: planning-agent
---

# TASK-1550 — Execution Plan v0.1

> Status: **Draft / C-3未承認 / 実装BLOCKED**
> Base: 2026-10-11取得のmainおよびPR #1547の差分とIssue #1550。作業ブランチはmainから作成し、実装直前にbase・対象パスを再取得する。
> Guidance: [Plan Design Principles](../../ai/plan-design-principles.md) / [Core Contract](../../ai/core-contract.md) / [Responsibility Classes](../../../.claude/rules/responsibility-classes.md)

## Goal / Success

本当に利用されているPR本文生成経路の1つでRollback / Detectionの3要素を案内し、検証できるようにする。目的は追加の手順を強制することではなく、事故時の小さな回復と早期検知の明確化。

## Facts, assumptions and blocking unknowns

- Fact: #1547は現時点では未マージ。既存テンプレートの追加案と、実PRへの適用は別問題。
- Fact: `.claude/agents/workflow-conductor.md`はPR作成を委譲するが、`.claude/agents/*.md`はHO対象。
- Fact: `scripts/apply-task-0124-patches.sh`に`gh pr create --body`が存在する。ただし**稼働の証拠は未取得**。
- Fact: `.agents/skills/ai-dev-exec/SKILL.md`は実装担当であり、PR本文のownerだと仮定してはいけない。
- Assumption: 既存テンプレートを唯一の説明元として投影する方が別規範を追加するより保守負担が小さい。
- Blocking Unknown U-01: 直近の実PRについて**caller→body generator→GitHub**の証跡を確保し、対象経路の実在を確認する。
- Blocking Unknown U-02: 具体的な実装ファイル、canonical/mirror、必要なHuman C-3/HO承認を特定する。
- Non-blocking Unknown U-03: 今後の採用率と所要時間への影響（定量値は初回観測後に計画する）。

**Readiness = BLOCKED** until U-01/U-02 resolved and Human C-3 approval recorded. Documentation discovery and review are allowed; executable PR body generator changes are not.

## Scope

### In scope after approval

1. 実測済みの**1つ**のPR本文生成経路へ3要素の最小投影を追加。
2. 既存のIssue Link/closing keywordと人間C-4の維持。
3. docs-only等のpositive/negative fixtureと既存CIでの検証。
4. 観測窓・戻し方・採用後の実PR例の記録。

### Out of scope

- `.claude/agents/*.md`、`.github/workflows/*.yml`等のHOパスへのAI直接編集。必要な場合はHuman向け適用patchと専用Humanゲートに分離。
- `scripts/ai-loop/gh_exec.py`のallowlist拡大、approval policyの緩和。
- すべてのPRへの強制チェック、別のテンプレート正本、未稼働generatorの変更。
- #1547/#1548/#1549のC-4/merge。

## Alternatives reviewed

| Alternative | Advantage | Risk | Decision |
| --- | --- | --- | --- |
| A: 共通テンプレートだけ更新 | 最小・すでに#1547で準備 | `--body`等の自動生成経路に届かない | 単独では不採用 |
| B: 稼働中1経路へ3要素投影 | 採用状況を実測できる・可逆 | 選定経路がHOならHuman適用が必要 | **候補、U-01後に選定** |
| C: 全経路でCI強制 | 機械的網羅性 | False positive、重複正本、導入負荷増 | 現時点ではDefer |
| D: 新PR body framework | 将来の統一可能性 | 未実証の抽象化・複雑化 | Reject |

## Work Breakdown / Dependency

- D-01 (read-only): 現時点のPR生成経路を収集。Path/caller/body producer/evidence/status/HO分類を一覧化する。**未確認経路は推測でActiveにしない**。
- D-02 (read-only): #1547がmainに採用されたか、採用された文面/責務を実装前に再取得する。まだなら先行しない。
- D-03 (review): 1つの稼働経路と唯一のcanonical sourceを選ぶ。対象パスと導入コストを記録。HOの場合は人間適用用patchを準備し、AI direct writeを停止。
- H-01 (Human): C-3でGoal/対象パス/TC/rollback/HO分界を承認する。APPROVEDでない場合は実装しない。
- T-01 (after H-01): AC-03/04のテスト・fixtureを先に用意する（Failing test/Evidenceを記録）。
- T-02 (after T-01): 対象の1経路だけに最小実装する。既存文面の上書き、認可境界の変更はしない。
- T-03 (after T-02): 正負fixture・Issue Link・既存CI・配布同期の検証結果を記録し、第三者視点でレビューする。
- H-02 (Human): PRのC-4承認とmergeはHuman-owned。
- O-01 (after Human merge): 実際の生成PRを観測。採用/未採用と改善効果を区別。運用に問題があればrevert/修正提案。

## Test Strategy

[test-cases.md](./test-cases.md) TC-01〜TC-10とACマッピングを使用。テスト先行、fixture差分、権限境界とnegative controlの確認を必須とする。作業中の実行結果がない項目は**Not run**と記録。

## Detection, Rollback, Stop and Replan

- Detection: 本文に3要素が欠ける、N/A理由がない、挙動変更docsが安易にN/A、closing keywordが消える、HOをAIが触る、配布driftが出る。
- Rollback: 実装コミット単位revert。HOに触れる変更はHuman-owned apply/rollback、承認契約を維持。
- Stop: 対象生成経路が不明、承認がない、既存セキュリティcheckがFail、HOと判明、Pluginの二重同期が必要になる。
- Replan: 直近の実PRで前提が覆る、実装が1経路を超える、必須Gateが必要だと実証された、#1547が方針変更された場合。

## Handoff / Decision owner

Human maintainerに要求する判断は**「実測された対象経路・具体的なchanged paths・negative fixtures・HO適用計画を承認するか」**。未承認・未マージを自動的に次の実行許可へ昇格しない。
