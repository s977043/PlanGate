---
task_id: TASK-1550
artifact_type: pbi-input
schema_version: 2
status: draft
---

# TASK-1550 — PR本文のRollback / Detectionを自動生成経路へ届ける

> Issue: [#1550](https://github.com/s977043/PlanGate/issues/1550)
> Depends on: [PR #1547](https://github.com/s977043/PlanGate/pull/1547)（共通テンプレート。2026-10-11 07:06 UTC MERGED、merge commit `2ea049de`）
> 状態: plan / C-3 未承認。実利用の改善は未検証。
> 改訂: 2026-11-02 12:06（origin/main `0d8d9468` 時点で経路と baseline を再測定）

## Why

PR テンプレートに Rollback / Detection を追加しても、Claude / Codex / CLI / Workflow が本文を `--body` で自前に組み立てる経路はテンプレートを経由しない。公開テンプレートを整備しただけでは実運用での採用を保証できない（false adoption）。

## Evidence / Assumptions / Unknowns

- E-01（baseline 再測定）: 2026-11-02 12:06 JST、`gh pr list --state merged --limit 30`、origin/main `0d8d9468`。対象 #1581〜#1632（merged 2026-10-16〜2026-11-02）。`## Rollback / Detection` 見出しは **3/30**、見出しに Rollback か Detection を含むものは **5/30**、3 行を TODO 以外で記入したものは **2/30**。詳細は [plan.md](./plan.md) §1.2。
- E-02: #1547 は main に入っている（テンプレート側の採用は完了）。残るのは自動生成経路側。
- E-03: 実稼働する bot 経路 `.github/workflows/sync-plugin-plangate.yml` は固定文の `--body` で PR を作る（実例 #1188 / #1253 / #1274）。
- E-04: `.github/workflows/*.yml` と `.claude/agents/*.md` は HO 対象（`.claude/rules/mode-classification.md`）。
- A-01: AI が PR を作る経路の起点（`pr-decision` Skill の PR 判定レポート）にテンプレートへの投影を 1 か所だけ置けば、AI 作成 PR の採用を増やせる可能性がある。**要実測**（O-01）。
- U-01: 採用後の効果（観測期間・比較方法）は導入後にしか測れない。

## Goal

AI が PR 本文を組み立てる主経路で、Rollback / Detection の 3 要素（Kill-switch / Detection signal / Observation window）がテンプレートと同じ意味で提示され、導入前後を同じ抽出条件で比較できる。

## Acceptance Criteria

- AC-01: PR 作成経路の根拠と最新 baseline（sample / 期間 / commit SHA）が追える。
- AC-02: 優先度の高い自動 PR 生成経路で 3 要素が利用者に提示され、fixture または実 PR 本文で確認できる。
- AC-03: 手動テンプレートと自動生成の文面に意味上の矛盾がなく、二重の規則正本を作らない。
- AC-04: C-3 / C-4 / HO、Human-owned merge、Issue linkage 判定を緩和しない。
- AC-05: 後方互換性・失敗検知・rollback・negative ケースの Evidence を PR に記録する。
- AC-06: 効果は「設計」「反映」「実利用」を分けて確認し、未観測なら未検証と書く。

## Non-goals

- PR の自動マージ・AI 自身による承認
- 全 PR への一律の新たな required CI Gate
- `AGENT_LEARNINGS.md` への直接追記の復活
- PR #1547 の Human C-4 を代行すること

## Execution Readiness

C-3 待ち。HO に触れる段（任意の Phase 2）は Human 適用に分離済み。
