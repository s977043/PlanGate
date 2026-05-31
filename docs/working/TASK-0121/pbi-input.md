---
task_id: TASK-0121
artifact_type: pbi-input
schema_version: 1
status: ready
---

# PBI INPUT PACKAGE — TASK-0121

## Context / Why

PlanGate の exec 完了後振り返りメトリクスは、現状では「計画精度15 / テスト品質15 / プロセス遵守15 / 効率性25 / 成果物品質30」の配点になっている。これは効率性を相対的に重く扱う一方で、PlanGate の思想である「Plan = 品質の発生源 / Exec = 保全」を十分に反映できていない。

本 PBI では、振り返りメトリクスを Plan-primacy 思想に合わせて再配点し、計画精度を C-1 語彙（受入基準網羅性 / スコープ制御 / テスト戦略妥当性）で評価できるようにする。あわせて、複製サイト間のドリフトを検知する consistency script を追加し、今後の配点乖離を機械的に防ぐ。

## What — Scope

### In scope

- 振り返りメトリクスの配点を以下に統一する。
  - 計画精度30
  - テスト品質15
  - プロセス遵守15
  - 効率性10
  - 成果物品質30
- 計画精度の評価内容を C-1 語彙へ拡張する。
  - 受入基準網羅性
  - スコープ制御
  - テスト戦略妥当性
- 成果物品質を「計画で定めた品質の達成度 = 保全達成度」として再定義する。
- 以下の複製サイトを同期する。
  - `docs/ai-driven-development.md`（非 Hardening Override）
  - `.claude/agents/workflow-conductor.md`（Hardening Override、人間編集）
  - `.claude/agents/retrospective-analyst.md`（Hardening Override、人間編集）
  - `plugin/plangate/agents/workflow-conductor.md`（非 Hardening Override）
- `.codex/agents/retrospective_analyst.toml` は thin pointer のため対象外とし、変更しない。
- `scripts/check-retro-scoring-consistency.sh` を新規追加し、以下を検証する。
  - 対象複製サイト内の旧配点文字列の残存が 0 件であること
  - 新 5 軸（計画精度30 / テスト品質15 / プロセス遵守15 / 効率性10 / 成果物品質30）が存在すること
  - 配点合計が 100 であること
- consistency script を pre-push へ連携する。CI 連携が必要な場合、`.github/workflows/` は Hardening Override として人間が編集する。

### Out of scope

- `.codex/agents/retrospective_analyst.toml` の編集
- 過去の `docs/working/` 配下レポートや既存 retrospective 実績値の再計算
- 振り返りメトリクスの 5 軸そのものの追加・削除
- PlanGate の mode 分類、C-1 / C-2 / C-3 ゲート定義の変更
- `.claude/agents/` 2 ファイルおよび `.github/workflows/` の AI 自動編集

## Acceptance Criteria

- [ ] AC-1: 振り返りメトリクスの配点が、対象複製サイトで「計画精度30 / テスト品質15 / プロセス遵守15 / 効率性10 / 成果物品質30」に統一され、合計が 100 である。
- [ ] AC-2: 計画精度の評価内容に C-1 語彙（受入基準網羅性 / スコープ制御 / テスト戦略妥当性）が明記されている。
- [ ] AC-3: 成果物品質が「計画で定めた品質の達成度 = 保全達成度」として再定義されている。
- [ ] AC-4: `docs/ai-driven-development.md`、`.claude/agents/workflow-conductor.md`、`.claude/agents/retrospective-analyst.md`、`plugin/plangate/agents/workflow-conductor.md` の配点・評価語彙が整合している。
- [ ] AC-5: `.codex/agents/retrospective_analyst.toml` は thin pointer として変更されていない。
- [ ] AC-6: `scripts/check-retro-scoring-consistency.sh` が、旧配点残存、新 5 軸欠落、合計 100 不一致を検出して non-zero exit できる。
- [ ] AC-7: consistency script は RED（旧状態で失敗）→ GREEN（同期後に成功）の証跡を残せる。
- [ ] AC-8: pre-push 連携は人間編集として扱われ、CI 連携が必要な `.github/workflows/` 変更も人間編集で行う。
- [ ] AC-9: Hardening Override 対象 2 件（`.claude/agents/workflow-conductor.md`、`.claude/agents/retrospective-analyst.md`）は人間編集として扱われる。

## Notes from Refinement

- Mode は `high-risk` とする。
- C-3 は APPROVED 済み。`approvals/c3.json` の発行・更新は人間タスクとする。
- Hardening Override 対象 2 件と pre-push / CI 配線は人間編集とする。
- consistency script の検証対象は、今回の配点同期対象である権威サイトに限定する。履歴資産である `docs/working/` 配下の過去 artifact はドリフト判定対象外とする。

## Estimation Evidence

**Risks**:
- 複製サイトが 4 か所あり、片方だけ新配点に更新されると再びドリフトする。
- `.claude/agents/` は Hardening Override 対象であり、AI が exec で直接編集すると運用境界違反になる。
- pre-push / CI 配線は運用導線に影響し、過検知すると push や CI を不要に止める。
- consistency script が履歴 artifact まで走査すると、過去の計画や振り返り記録を誤って失敗扱いする。

**Unknowns**:
- CI 連携を既存 workflow に追加するか、新規 workflow とするかは人間判断。
- pre-push 連携を `scripts/templates/pre-push.sample` へ直接追加するか、別 hook dispatcher を経由するかは人間判断。
- Human-owned 2 ファイルの最終反映タイミングは、C-3 artifact 発行後の人間作業に依存する。

**Assumptions**:
- `scripts/` ルート直下の新規 script は非 Hardening Override として AI が実装可能。
- `.codex/agents/retrospective_analyst.toml` は markdown 側を参照する thin pointer であり、配点の正本を持たない。
- 配点正本は「計画精度30 / テスト品質15 / プロセス遵守15 / 効率性10 / 成果物品質30」とし、合計 100 を固定する。
- exec 開始前に人間が `approvals/c3.json` を APPROVED として発行する。
