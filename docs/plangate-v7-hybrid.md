# PlanGate v7 ハイブリッドアーキテクチャ

> **キャッチコピー**: Governance × Modularity =「強固な運用 × 柔軟な実行」
>
> 親 PBI: [#22](https://github.com/s977043/plangate/issues/22) / `docs/working/TASK-0021/pbi-input.md`

## 概要

PlanGate v7 は、v5/v6 の「統制」と、Workflow / Skill / Agent 3 層モデルの「実行」を組み合わせた **ハイブリッドアーキテクチャ**。

- **統制層（PlanGate）**: 計画を止める・承認する・状態を保存する
- **実行層（Workflow / Skill / Agent）**: 柔軟で拡張可能な実行基盤

両者は補完関係にあり、ハイブリッド化により **統制の強さを保ったまま、実行の再利用性・拡張性をスケール**できる。

## v5 / v6 / v7 の関係

| Version | 位置付け | ドキュメント |
|---------|---------|------------|
| v5 | 現行（ゲート型開発ワークフロー）。全 PBI で A→B→C-1〜D→L-0→V-1〜V-4→PR→C-4 を実行 | [docs/plangate.md](./plangate.md) |
| v6 | ロードマップ（context-engineering 統合、決定論的フック、推論サンドイッチ 等） | [docs/plangate-v6-roadmap.md](./plangate-v6-roadmap.md) |
| **v7** | **ハイブリッドアーキテクチャ（本書）**。v5/v6 のガバナンスを維持しつつ、実行層を Workflow/Skill/Agent 3 層で再構築 | 本書 |

### 差分・位置付け

| 観点 | v5 | v6 | v7 |
|-----|----|----|----|
| ゲート | A/B/C-1〜C-4 / L-0 / V-1〜V-4 | v5 踏襲 | v5 踏襲（統制層で維持） |
| 実行単位 | 各フェーズで特定 agent が動作 | 同左 + 決定論的フック | **Workflow 5 phase + Skill 10 + Agent 5 責務** |
| 再利用 | 観点が plan.md に埋め込まれやすい | v5 の改善計画中 | **Skill 層で再利用単位を分離** |
| 設計 artifact | plan.md のみ | v5 踏襲 | **design.md（WF-03）** を独立化 |
| 完了後資産 | status.md で進行管理 | v5 踏襲 | **handoff.md（WF-05）** を全 PBI 必須化 |

v5/v6 を**置換せず、内側で拡張**する設計。既存プロジェクトは v5/v6 運用を継続しつつ、段階的に v7 要素を opt-in できる。

## 4 軸ガバナンス（統制層）

PlanGate v5/v6 の責務を 4 軸で整理:

| 軸 | 責務 | v7 ハイブリッドでの実装 |
|----|------|----------------------|
| **GATE** | 計画を止める | C-3 ゲート（三値）/ C-4 ゲート（GitHub PR）/ Workflow phase 完了条件 |
| **STATUS** | 状態を保存する | status.md + current-state.md + **handoff.md** |
| **APPROVAL** | 承認管理 | C-3 APPROVE / CONDITIONAL / REJECT / C-4 APPROVE / REQUEST CHANGES |
| **ARTIFACT** | 成果物正本化 | plan.md + **design.md** + **handoff.md** + review-self.md + review-external.md |

太字は v7 で追加・強化された要素。

## 3 層実行層

### Workflow 層（5 phase、Rule 1）

| Phase | 目的 | 主担当 Agent |
|-------|------|-------------|
| **WF-01** Context Bootstrap | 前提・制約・品質基準を読み込む | `orchestrator`, `requirements-analyst` |
| **WF-02** Requirement Expansion | 要件の抜け漏れ洗い出し | `requirements-analyst`, `qa-reviewer` |
| **WF-03** Solution Design | 仕様を実装可能な構造へ落とす | `solution-architect` |
| **WF-04** Build & Refine | 設計に従った最小単位実装 | `implementation-agent` |
| **WF-05** Verify & Handoff | 品質確認 + handoff 発行 | `qa-reviewer`, `orchestrator` |

詳細: [docs/workflows/](./workflows/)

### Skill 層（10 個、Rule 2）

| カテゴリ | Skill |
|---------|-------|
| Scan | context-load / requirement-gap-scan |
| Check | nonfunctional-check / edgecase-enumeration / risk-assessment |
| Design | acceptance-criteria-build / architecture-sketch |
| Build | feature-implement |
| Review | acceptance-review / known-issues-log |

詳細: [.claude/skills/](../.claude/skills/), [docs/workflows/skill-mapping.md](./workflows/skill-mapping.md)

### Agent 層（5 体、Rule 3）

| Agent | 責務 |
|-------|------|
| `orchestrator` | ワークフロー遷移管理 / 完了条件判定 |
| `requirements-analyst` | 要求 → 仕様変換 |
| `solution-architect` | 仕様 → 実装構造設計 |
| `implementation-agent` | 設計 → 実装 + 自己レビュー |
| `qa-reviewer` | 要件適合確認 + handoff 準備 |

詳細: [.claude/agents/](../.claude/agents/), [docs/workflows/execution-sequence.md](./workflows/execution-sequence.md)

## Rule 1〜5（再構築ルール）

| Rule | 内容 |
|------|------|
| **Rule 1** | **Workflow は順序と完了条件だけを持つ**。実装ノウハウは書かない |
| **Rule 2** | **Skill は再利用単位に限定する**。案件固有の話を入れない |
| **Rule 3** | **Agent は責務だけを持つ**。ツール固有手順や案件固有仕様は持たせない |
| **Rule 4** | **案件固有情報は CLAUDE.md に寄せる**。Agent や Skill に埋め込まない |
| **Rule 5** | **最終成果物は毎回 handoff に集約する**。仕様 / 既知課題 / V2 候補 / 確認結果を残す |

正本ルール: [.claude/rules/hybrid-architecture.md](../.claude/rules/hybrid-architecture.md)

## CLAUDE.md / Skill / Hook の境界ルール

Rule 4 を補完する **強制力の軸** での境界定義:

| 対象 | 役割 | 置き場所 | 強制力 |
|------|------|---------|-------|
| **CLAUDE.md** | 案件固有情報、常時必要な文脈 | プロジェクトルート | ソフト（LLM が参照） |
| **Skill** | 再利用可能な手順・観点（必要時だけ読み込む） | `.claude/skills/` or `.claude/commands/` | ソフト（LLM が呼び出し） |
| **Hook** | 強制力が必要な決定論的制御（100% 強制） | `.claude/settings.json` の hooks | **ハード**（harness が実行） |

| 用途 | 推奨配置 |
|------|---------|
| プロジェクトのルール・制約 | CLAUDE.md |
| 再利用可能な観点・チェックリスト | Skill |
| 「絶対に通さない」制御（例: plan 未作成なら block） | Hook |

## ガバナンス層 × 実行層 接続表

| 統制層（PlanGate） | 実行層（Workflow / Skill / Agent） |
|-------------------|--------------------------------|
| **GATE**（計画を止める） | Workflow phase 完了条件で制御 |
| **STATUS**（状態を保存） | status.md + current-state.md + handoff.md |
| **APPROVAL**（承認管理） | C-3 ゲート / C-4 ゲート |
| **ARTIFACT**（成果物正本化） | plan.md / design.md / handoff.md |

| PlanGate フェーズ | 対応する Workflow phase |
|-----------------|----------------------|
| A（PBI INPUT PACKAGE） | WF-01 Context Bootstrap |
| A / B（plan 前段） | WF-02 Requirement Expansion |
| B の一部 + C-1〜C-3 | WF-03 Solution Design |
| D（exec）+ C-1 + L-0 | WF-04 Build & Refine |
| V-1〜V-4 + handoff（新設） | WF-05 Verify & Handoff |

PlanGate 既存フェーズへの Workflow 挿入位置図: [docs/workflows/plangate-insertion-map.md](./workflows/plangate-insertion-map.md)

## 実行シーケンス（責務ベース Agent × Workflow）

```
orchestrator (WF-01)
  → requirements-analyst (WF-02: requirement-gap-scan)
  → qa-reviewer (WF-02: edgecase + AC 確定)
  → solution-architect (WF-03: architecture-sketch)
  → implementation-agent (WF-04: feature-implement + self-review)
  → qa-reviewer (WF-05: acceptance-review + known-issues-log)
  → orchestrator (handoff 発行)
```

詳細: [docs/workflows/execution-sequence.md](./workflows/execution-sequence.md)

## 既存利用者向け移行パス

### Phase 1: Opt-in（現状）

- v5/v6 フロー（A/B/C-1〜V-4）をそのまま継続
- v7 の Workflow / Skill / Agent は **opt-in で追加採用**
- design.md / handoff.md の生成は推奨

### Phase 2: Default（将来）

- design.md / handoff.md を全 PBI で必須化（`.claude/rules/` で強制）
- Hook 導入で決定論的制御を強化

### Phase 3: Full v7（将来）

- 責務ベース Agent 5 体で実行
- 既存 PlanGate 特化 Agent は legacy として温存

**注**: 完全移行は必須ではありません。デュアル運用のままでも問題ありません。

## 参照

### v7 ハイブリッドアーキテクチャのドキュメント

- [docs/workflows/](./workflows/) — 5 phase 定義 + README + 実行シーケンス + skill-mapping + insertion-map
- [docs/working/templates/design.md](./working/templates/design.md) — WF-03 成果物テンプレート
- [docs/working/templates/handoff.md](./working/templates/handoff.md) — WF-05 成果物テンプレート
- [.claude/agents/](../.claude/agents/) — 責務ベース 5 体 + 既存 14 体
- [.claude/skills/](../.claude/skills/) — Skill 10 個 + 既存 8 個
- [.claude/rules/hybrid-architecture.md](../.claude/rules/hybrid-architecture.md) — Rule 1〜5 + 境界ルール（正本）
- [.claude/rules/working-context.md](../.claude/rules/working-context.md) — handoff 必須化

### 親 Issue

- [#22 TASK-0021](https://github.com/s977043/plangate/issues/22) — PlanGate × Workflow/Skill/Agent ハイブリッドアーキテクチャ導入
- サブ: #23 (基盤) / #24 (Skill) / #25 (Agent) / #26 (WF-03) / #27 (WF-05) / #28 (本書)

### v5 / v6

- [docs/plangate.md](./plangate.md) — v5 正本
- [docs/plangate-v6-roadmap.md](./plangate-v6-roadmap.md) — v6 ロードマップ
