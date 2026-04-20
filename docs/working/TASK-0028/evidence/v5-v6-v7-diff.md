# v5 / v6 / v7 差分整理

> 作成日: 2026-04-20

## 概要

| Version | 位置付け | ドキュメント |
|---------|---------|------------|
| v5 | 現行（ゲート型開発ワークフロー） | docs/plangate.md |
| v6 | ロードマップ（context-engineering 統合、決定論的フック、推論サンドイッチ 等） | docs/plangate-v6-roadmap.md |
| v7 | ハイブリッドアーキテクチャ | docs/plangate-v7-hybrid.md（本 TASK で新設） |

## 主要差分

| 観点 | v5 | v6 | v7 |
|-----|----|----|----|
| 位置付け | 現行実運用 | 将来の拡張方針 | 統制層 + 実行層 3 層モデル |
| ゲート | A/B/C-1〜C-4, L-0, V-1〜V-4 | v5 踏襲 | v5 踏襲（統制層で維持） |
| 実行単位 | フェーズ × 特定 agent | v5 + 決定論的フック | Workflow 5 phase + Skill 10 + Agent 5 責務 |
| 再利用 | plan.md に観点埋め込み | v5 の改善計画中 | Skill 層で分離 |
| 設計 artifact | plan.md のみ | v5 踏襲 | design.md（WF-03）独立化 |
| 完了後資産 | status.md | v5 踏襲 | handoff.md（WF-05）必須化 |
| Rule | 明文化なし | 実装計画あり | **Rule 1〜5 明文化** |

## v7 で追加された要素

### 新規ドキュメント
- `docs/plangate-v7-hybrid.md` — v7 本書
- `docs/workflows/*.md` — 5 phase 定義 + README + skill-mapping + insertion-map + execution-sequence
- `docs/working/templates/design.md` — WF-03 テンプレート
- `docs/working/templates/handoff.md` — WF-05 テンプレート
- `.claude/rules/hybrid-architecture.md` — Rule 1〜5 正本

### 新規 Skill（10 個）
- Scan: context-load, requirement-gap-scan
- Check: nonfunctional-check, edgecase-enumeration, risk-assessment
- Design: acceptance-criteria-build, architecture-sketch
- Build: feature-implement
- Review: acceptance-review, known-issues-log

### 新規 Agent（4 体 + 既存 orchestrator 採用）
- requirements-analyst, solution-architect, implementation-agent, qa-reviewer（新規）
- orchestrator（既存を採用、責務更新）

### 必須化
- 全 PBI で handoff.md 必須（Rule 5）

## v5 / v6 ドキュメントとの整合

既存 v5/v6 ドキュメント:
- `docs/plangate.md`: 冒頭に v7 への導線 note を追加
- `docs/plangate-v6-roadmap.md`: 冒頭に v7 への導線 note を追加

両者の既存内容は **置換せず、維持**。v7 への導線のみ追加。

## 置換 vs 拡張の判断

v7 は v5/v6 を **置換せず、内側で拡張**:

- v5/v6 のガバナンス層（A/B/C-1〜V-4、ゲート、artifact 正本化）は維持
- 実行層を Workflow / Skill / Agent 3 層で再構築
- 既存プロジェクトは v5/v6 運用を継続しつつ、v7 要素を opt-in 可能

## 移行パス

### Phase 1: Opt-in（現状）

- v5/v6 フローをそのまま継続
- v7 の Workflow / Skill / Agent は opt-in で追加採用
- design.md / handoff.md の生成は推奨

### Phase 2: Default（将来）

- design.md / handoff.md を全 PBI で必須化
- Hook 導入で決定論的制御を強化

### Phase 3: Full v7（将来）

- 責務ベース Agent 5 体で実行
- 既存 PlanGate 特化 Agent は legacy として温存

**注**: 完全移行は必須ではない。デュアル運用可能。

## 矛盾の解消

v5/v6 ドキュメント内で v7 と矛盾する記述は、本 TASK の時点では発見されず。将来的に矛盾が発生した場合は、**v5/v6 が正本（既存運用維持）、v7 が opt-in 拡張**として扱う。

Rule や用語の追加・置換は、新規ファイル（`hybrid-architecture.md`、`plangate-v7-hybrid.md`）に集約されており、既存ファイルには note 追加のみ。
