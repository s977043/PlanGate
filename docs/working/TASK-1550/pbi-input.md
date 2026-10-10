---
task_id: TASK-1550
artifact_type: pbi-input
schema_version: 1
status: draft
---

# TASK-1550 — PR本文のRollback / Detectionを自動生成経路へ届ける

> Issue: [#1550](https://github.com/s977043/PlanGate/issues/1550)
> Depends on: [PR #1547](https://github.com/s977043/PlanGate/pull/1547)（共通テンプレート）
> 状態: Discovery / C-3未承認。現状の実利用改善は未検証。

## Why

PRテンプレートへRollback / Detectionを追加しても、Claude/Codex/CLIの生成PRが本文を自前で組み立てる場合はテンプレートを使わない。公開ルールを整備しただけでは実運用の採用を保証できない。

## Evidence / Assumptions / Unknowns

- Evidence E-01: 2026-10-10 GitHub検索の「更新順のマージ済みPR 30件」では旧テンプレート主要3見出しが3/30、Rollback / Detection見出し0/30。**導入前参考値**であり無作為標本でも採用後効果でもない。出典・抽出条件は[Issue #1550](https://github.com/s977043/PlanGate/issues/1550)。
- Evidence E-02: `.claude/agents/workflow-conductor.md` はPR作成をサブエージェントに委譲する説明を持つ。ただし運用上の実際のPR本文生成元は未特定。
- Evidence E-03: `scripts/apply-task-0124-patches.sh` は `gh pr create --body` を含むが、現在呼び出されているかは**未確認**。
- Evidence E-04: `.claude/rules/mode-classification.md` は `.claude/agents/*.md` と `.github/workflows/*.yml` をHO対象と定義する。
- Evidence E-05: `scripts/ai-loop/gh_exec.py` は明示allowlistの操作を扱う。コードの一部にPRコメント本文の経路があることだけを理由に、PR作成経路とみなさない。
- Assumption A-01: 優先度の高い1つの実在経路だけへの介入で、テンプレートの未利用を減らせる可能性がある。**要実測**。
- Unknown U-01 (**blocking**): 実際のPR作成 caller → body producer → GitHub API/CLIの対応と稼働状況。
- Unknown U-02 (**blocking**): 選定経路の変更対象とHuman C-3/HOの承認記録。
- Unknown U-03: #1547採用後に必要な追跡指標と観測期間（採用効果はまだ計測できない）。

## Goal

実際に利用されるPR生成経路が、Rollback / Detectionの3要素を既存Issueリンクや承認境界を壊さず提示できるようにし、導入前後の採用状況を区別して検証する。

## Acceptance Criteria

- AC-01: GitHub/CLI/Agent/pluginの経路をcaller・本文作成者・呼び出し先・稼働証拠・保護分類で追跡できる。
- AC-02: 実利用されている対象経路を選び、最小差分でKill-switch・Detection signal・Observation windowを提示できる。
- AC-03: docs-only、挙動変更docs、通常コード、独自PR本文、項目欠落を正負両面で検証し、`N/A (reason)`の妥当性を区別する。
- AC-04: Issue closing/linkキーワード、既存PR本文、C-3/C-4/HOの権限境界を壊さない。
- AC-05: Plugin/Claude/Codexを誤配布・手動二重同期せず、変更した経路の出力証拠を示せる。
- AC-06: 反映されたことと実際のPRで使われたことを分け、同じ抽出条件の観測を記録する。未計測なら未検証と明記する。
- AC-07: rollback対象、早期検知と停止・回復の手順を残す。

## Non-goals

- C-4承認、PRマージ、HO適用をAIが代行すること。
- PR本文の存在だけで実装品質や手戻り削減を証明したと主張すること。
- 新しい必須CI Gate、Schema、汎用PR本文エンジン、外部SDKや依存を増やすこと。
- `AGENT_LEARNINGS.md`を新規一次記録先にすること。Retro seedsはC-3のopt-in条件と人間確認が必要。

## Execution Readiness

**BLOCKED for production implementation**: U-01 / U-02とHuman C-3承認未解決。調査・Plan/TCレビュー・Human用パッチ準備は継続できる。
