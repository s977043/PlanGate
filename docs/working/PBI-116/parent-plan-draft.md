# PBI-116 親計画書（DRAFT）

> **Status**: DRAFT — ユーザー判断（着手 / 修正 / 保留）待ち。承認後に正式 `parent-plan.md` へ昇格。
> 関連: EPIC [#116](https://github.com/s977043/plangate/issues/116) / 子 P1 [#117](https://github.com/s977043/plangate/issues/117)〜[#122](https://github.com/s977043/plangate/issues/122)
> テンプレート: `docs/working/templates/parent-plan.md`
> 適用 Mode: **Orchestrator Mode**（[`docs/orchestrator-mode.md`](../../orchestrator-mode.md) / [`.claude/rules/orchestrator-mode.md`](../../../.claude/rules/orchestrator-mode.md)）

## Goal

GPT-5.5 以降の実行モデルに対応した PlanGate を構築する。具体的には、**outcome-first な Core Contract** を中核とし、モデル差分を **Model Profile + Adapter + Eval** で吸収できる仕組みを v8.2 milestone までに整備する。

## Why（背景）

最新の実行モデルでは、長い手順指定よりも目的・成功条件・制約・停止条件・出力を明確にする outcome-first な指示設計が有効。一方、現状の `CLAUDE.md` / `AGENTS.md` / rules / agents には手順指定や `必ず` `絶対` 等の冗長な記述が残存し、モデル別の差分吸収層も存在しない。

PlanGate Core（C-3 / C-4 / scope discipline / verification honesty）はモデル非依存で維持しつつ、差分はプロファイルとアダプタに閉じ込める。

## Acceptance Criteria（親 PBI 受入基準）

| AC | 内容 | カバー子 PBI |
|----|------|------------|
| AC-1 | Core Contract が outcome-first 形式で定義されている | #117 |
| AC-2 | 実行モデル別差分が Model Profile として設定化されている | #118 |
| AC-3 | prompt assembly が Core / Phase / Risk / Model Adapter の 4 層で説明・実装されている | #119 |
| AC-4 | Structured Outputs 化対象成果物が整理され schema 案が定義されている | #120 |
| AC-5 | model migration eval cases が追加されている | #121 |
| AC-6 | Tool Policy / Hook enforcement の責務境界が整理されている | #122 |
| AC-7 | C-3 / C-4 / scope discipline / verification honesty が全子 PBI で維持される | 全子 PBI |

## In Scope / Out of Scope

### In Scope（親レベル）
- Core Contract の outcome-first 化と入口ファイル（CLAUDE.md / AGENTS.md）の薄型化
- Model Profile / Adapter / Eval / Tool Policy の設計・設定追加
- Structured Outputs の schema 案整備
- 既存 PlanGate Gate（C-3 / C-4）の維持

### Out of Scope（親レベル）
- GPT-5.5 専用の PlanGate fork
- モデル別 plan/exec/review プロンプトの完全複製
- 完全自動マージ・自動デプロイ
- Hook / CLI の本格実装（境界定義のみ、実装は別 PBI）
- 外部 eval ダッシュボード

## 子 PBI 一覧

| 子 ID | Issue | タイトル | mode 想定 | 主要成果物 |
|------|-------|---------|----------|----------|
| C-1 | #117 | Outcome-first Core Contract への移行（prompt slimming） | high-risk | `docs/ai/core-contract.md` / 既存ルール棚卸し / CLAUDE.md/AGENTS.md 薄型化 |
| C-2 | #118 | Model Profile layer 追加 | standard | `model-profiles.yaml` 相当 / 4 プロファイル定義 |
| C-3 | #119 | Prompt assembly を 4 層化 | high-risk | `docs/ai/prompt-assembly.md` / 擬似コード or 実装 |
| C-4 | #120 | Structured Outputs / JSON Schema 方針 | standard | schema 案 / Markdown ↔ JSON 境界定義 |
| C-5 | #121 | Model migration Eval cases 追加 | standard | `docs/ai/eval-cases/` 7 ケース + 比較表テンプレ |
| C-6 | #122 | Tool Policy / Hook enforcement 境界整理 | standard | phase 別 allowed tools / Hook 候補一覧 |

## 依存関係グラフ

```
#117 (Core Contract / 基盤)
  ├──▶ #118 (Model Profile)         ──┐
  ├──▶ #120 (Structured Outputs)    ──┤
  └──▶ #122 (Tool Policy boundary)  ──┤
                                       ▼
                                     #119 (Prompt assembly 4 層)
                                       │
                                       ▼
                                     #121 (Eval cases、検証)
```

- **#117 が全ての前提**（Core Contract が他子 PBI の参照点になる）
- **#118 / #120 / #122 は #117 完了後に並行実行可能**（互いに独立）
- **#119 は #117 + #118 完了後**（Core Contract と Model Profile の両方を統合する設計層）
- **#121 は最後**（全子 PBI の成果物を eval で検証）

## 並行実行計画

| Phase | 並行子 PBI | 推定所要 |
|-------|-----------|---------|
| Phase 1 | #117 単独 | 1 セッション（high-risk、棚卸しが時間かかる） |
| Phase 2 | #118 / #120 / #122 並行 | 並列で 1 セッション相当 |
| Phase 3 | #119 単独 | 1 セッション（high-risk、設計層） |
| Phase 4 | #121 単独 | 1 セッション（検証） |

合計 4 phase。Phase 2 を並行実行することで実時間を短縮可能。

## 統合チェック（親完了条件）

`integration-plan.md` 化する候補:

- [ ] 全子 PBI の handoff.md が必須 6 要素を完備
- [ ] AC-1〜AC-6 が各子 PBI でカバー済み（`covers_parent_ac` の整合性）
- [ ] AC-7（既存 Gate 維持）が全子 PBI で確認済み
- [ ] `CLAUDE.md` / `AGENTS.md` の薄型化が完了し、巨大化していない
- [ ] eval cases（#121）で全子 PBI の成果物が PASS 判定
- [ ] v8.2 milestone リリース可能な状態

## リスク・未確定要素

| ID | リスク | severity | 緩和策 |
|----|------|---------|------|
| R-1 | Core Contract（#117）の方針が他子 PBI と整合しない | high | Phase 1 完了時点で C-3 ゲートを厳格化、整合確認後に Phase 2 着手 |
| R-2 | Model Profile（#118）の YAML schema が Prompt assembly（#119）と乖離 | medium | #119 の設計時に #118 の schema を引用 |
| R-3 | Structured Outputs（#120）が既存 `schemas/` と矛盾 | medium | 既存 schema との互換性確認を C-1 / C-2 で実施 |
| R-4 | Eval cases（#121）が他 PBI の成果物に依存して着手できない | medium | #121 を最後の Phase 4 に配置済み |
| R-5 | `必ず` / `絶対` などの語彙削減で意図せず重要制約を弱化 | high | 不変制約は Iron Law として明示的に保持、削減対象は手順指定のみ |

## 親 PBI 適用 Mode

**Orchestrator Mode**

理由:
- 子 PBI が 6 件、依存関係あり、並行実行ポイントあり
- AC が複数 PBI にまたがり統合確認が必要
- v8.2 milestone を一体として扱う必要がある

## 推奨次アクション（ユーザー判断）

1. **本素案のレビュー**（採用 / 修正 / 却下）
2. 採用時: `parent-plan-draft.md` を `parent-plan.md` に昇格、`approvals/parent-c3.json` を発行
3. 子 PBI YAML（`docs/working/PBI-116/children/PBI-116-{01〜06}.yaml`）を `docs/schemas/child-pbi.yaml` に従って作成
4. Phase 1（#117）から着手

## 関連リンク

- EPIC: https://github.com/s977043/plangate/issues/116
- 子 P1: #117 / #118 / #119 / #120 / #121 / #122
- Orchestrator Mode 仕様: `docs/orchestrator-mode.md`
- 親 PBI Gate 条件: `.claude/rules/orchestrator-mode.md`
- 子 PBI schema: `docs/schemas/child-pbi.yaml`
- doc-audit Try-3 として参照: `docs/working/retrospective-2026-04-30.md`
