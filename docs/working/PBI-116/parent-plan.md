# Parent Plan — PBI-116

> **PlanGate Orchestrator Mode 親 PBI 計画**（Orchestrator Mode 実運用ケース第一号）
> 関連: [`docs/orchestrator-mode.md`](../../orchestrator-mode.md) / Issue [#116](https://github.com/s977043/plangate/issues/116)

## メタデータ

| 項目 | 値 |
|------|---|
| Parent PBI ID | PBI-116 |
| Title | 最新実行モデル対応: Outcome-first / Model Profile / Eval 基盤 |
| Issue | [#116](https://github.com/s977043/plangate/issues/116) |
| Mode | high-risk |
| Owner | s977043 |
| Status | parent:decomposed（親計画ゲート待ち） |
| Milestone | v8.2 |

## Goal

GPT-5.5 以降の実行モデルに対応した PlanGate を構築する。**outcome-first な Core Contract** を中核とし、モデル差分を **Model Profile + Adapter + Eval** で吸収できる仕組みを v8.2 milestone までに整備する。

## Why（背景・目的）

最新の実行モデルでは、長い手順指定よりも目的・成功条件・制約・停止条件・出力を明確にする outcome-first な指示設計が有効。一方、現状の `CLAUDE.md` / `AGENTS.md` / rules / agents には手順指定や `必ず` `絶対` 等の冗長な記述が残存し、モデル別の差分吸収層も存在しない。

PlanGate Core（C-3 / C-4 / scope discipline / verification honesty）はモデル非依存で維持しつつ、差分はプロファイルとアダプタに閉じ込める。

## Acceptance Criteria（親レベル受入基準）

- [ ] **parent-AC-1**: PlanGate Core Contract が outcome-first 形式で定義され、`CLAUDE.md` / `AGENTS.md` から参照されている
- [ ] **parent-AC-2**: 実行モデル別差分が Model Profile（`model-profiles.yaml` 相当）として設定化されている
- [ ] **parent-AC-3**: prompt assembly が Core / Phase / Risk / Model Adapter の 4 層で説明・実装されている
- [ ] **parent-AC-4**: Structured Outputs 化対象成果物が整理され、schema 案が定義されている
- [ ] **parent-AC-5**: model migration eval cases が追加され、Gate 違反 / 検証不正直は release blocker として扱われる
- [ ] **parent-AC-6**: Tool Policy / Hook enforcement の責務境界が整理され、phase 別 allowed tools が定義されている
- [ ] **parent-AC-7**: 全子 PBI 完了後も C-3 / C-4 / scope discipline / verification honesty が維持される
- [ ] **parent-AC-8**: `CLAUDE.md` / `AGENTS.md` の薄型化により、常時ロード指示の token 量が削減されている

## Constraints / Non-goals

### Constraints

- 既存 PlanGate Gate（C-3 / C-4）の機能・運用ルールは変更しない
- 既存 5 モード分類（ultra-light / light / standard / high-risk / critical）と整合
- handoff 必須化（Rule 5）は維持

### Non-goals

- GPT-5.5 専用の PlanGate fork
- モデル別 plan/exec/review プロンプトの完全複製
- 完全自動マージ・自動デプロイ
- Hook / CLI の本格実装（境界定義のみ、実装は別 PBI）
- 外部 eval ダッシュボード構築

## Approach Overview

ドメイン境界で 6 子 PBI に分解。**Core Contract（#117）を基盤** として、Model Profile / Structured Outputs / Tool Policy boundary（#118 / #120 / #122）を並行実行可能な 2 層目に配置。両者を統合する Prompt Assembly（#119）を 3 層目、最後に Eval cases（#121）で全体検証する 4 層構成。

各子 PBI は単一 Issue（#117〜#122）に対応し、parent-AC を `covers_parent_ac` でマッピング。

## Children（子 PBI 一覧）

| ID | Issue | Title | Mode | Parallelizable | Depends on |
|----|-------|-------|------|---------------|-----------|
| PBI-116-01 | #117 | Outcome-first Core Contract への移行（prompt slimming） | high-risk | false | — |
| PBI-116-02 | #118 | Model Profile layer 追加 | standard | true | PBI-116-01 |
| PBI-116-03 | #119 | Prompt assembly を Core / Phase / Risk / Model Adapter に分層化 | high-risk | false | PBI-116-01, PBI-116-02 |
| PBI-116-04 | #120 | Structured Outputs / JSON Schema 方針を PlanGate 成果物に適用 | standard | true | PBI-116-01 |
| PBI-116-05 | #121 | Model migration Eval cases 追加 | standard | false | PBI-116-01, PBI-116-02, PBI-116-03, PBI-116-04, PBI-116-06 |
| PBI-116-06 | #122 | Tool Policy / Hook enforcement 境界整理 | standard | true | PBI-116-01 |

各子 PBI の詳細は [`children/PBI-116-NN.yaml`](./children/) を参照。

## Integration Plan

統合チェックの代表項目（詳細は [`integration-plan.md`](./integration-plan.md)）:

- [ ] 全子 PBI の handoff.md が必須 6 要素を完備
- [ ] parent-AC-1〜AC-8 が各子 PBI の `covers_parent_ac` で網羅されている
- [ ] `CLAUDE.md` / `AGENTS.md` の薄型化が完了し、Core Contract への参照に統一
- [ ] eval cases（PBI-116-05）で全子 PBI 成果物が PASS 判定
- [ ] 既存 Gate（C-3 / C-4）の機能 / 運用が維持

## Risk

親 PBI レベルで集約したリスク（詳細は [`risk-report.md`](./risk-report.md)）:

| ID | Risk | Severity | Mitigation |
|----|------|----------|-----------|
| R1 | Core Contract（PBI-116-01）の方針が他子 PBI と整合しない | high | Phase 1 完了時の C-3 ゲート厳格化、整合確認後に Phase 2 着手 |
| R2 | Model Profile（PBI-116-02）の YAML schema が Prompt assembly（PBI-116-03）と乖離 | medium | PBI-116-03 設計時に PBI-116-02 schema を引用 |
| R3 | Structured Outputs（PBI-116-04）が既存 `schemas/` と矛盾 | medium | C-1 / C-2 で互換性確認 |
| R4 | `必ず` / `絶対` 削減で意図せず重要制約を弱化 | high | Iron Law 7 項目を明示保持、削減対象は手順指定のみ |
| R5 | Eval cases（PBI-116-05）依存が他 PBI 全完了で着手できない | medium | Phase 4 配置で他 5 PBI 完了後に着手、その分 buffer を見込む |

## Gates（ゲート計画）

| Gate | 名称 | タイミング | 担当 |
|------|------|-----------|------|
| Parent C-3 | 親計画ゲート | `parent:decomposed` 後（本 PR マージ後） | 👤 人間 |
| Child C-3 × 6 | 子 PBI 計画ゲート | 各子 PBI 単位（plan 提出後） | 👤 人間 |
| Child C-4 × 6 | 子 PBI PR レビュー | 各子 PBI PR | 👤 人間（GitHub）|
| Parent Integration Gate | 統合ゲート | `parent:integration_review` 後 | 👤 人間 |

## Approvals

| Approval | File | Decision | Approver | Date |
|----------|------|---------|----------|------|
| Parent C-3 | [`approvals/parent-c3.json`](./approvals/parent-c3.json) | pending | — | — |
| Parent Integration | `approvals/parent-integration.json` | (未作成、Phase 4 完了時に発行) | — | — |

## Status Log

| Date | Status | Note |
|------|--------|------|
| 2026-04-29 | parent:draft | EPIC #116 + P1 6 件起票 |
| 2026-04-30 | parent:analyzed | DRAFT 計画書（旧 `parent-plan-draft.md`）作成 |
| 2026-04-30 | parent:decomposed | 子 PBI YAML 6 件 + 補助ドキュメント完成、C-3 ゲート待機 |

## References

- [`docs/orchestrator-mode.md`](../../orchestrator-mode.md) — 仕様正本
- [`docs/workflows/orchestrator-decomposition.md`](../../workflows/orchestrator-decomposition.md)
- [`docs/workflows/orchestrator-integration.md`](../../workflows/orchestrator-integration.md)
- [`docs/schemas/child-pbi.yaml`](../../schemas/child-pbi.yaml)
- 予備調査: [`notes-117-target-files.md`](./notes-117-target-files.md)
- 振り返り: [`docs/working/retrospective-2026-04-30.md`](../retrospective-2026-04-30.md)
