# TASK-0117 EXECUTION PLAN

> Source: pbi-input.md / Issue #351 / Mode: **light**
> Generated: 2026-05-26 / Codex 推奨

## Goal

`ai-dev-plan` skill に「事前メトリクス検証」step を追加し、A → B 遷移時の規模見積もりギャップ (process drift の主因) を構造的に防ぐ。PocketEitan PR #371 最小ポート。

## Constraints / Non-goals

- AI 実コマンド実行強制は本 PBI scope 外 (ソフトルール強化のみ)
- TASK-0112 例外ルールとの重複定義なし (相互参照のみ)
- 既存 ai-dev-plan skill 構造を破壊しない (additive)

## Approach Overview

(1) T-01 既存 ai-dev-plan skill 構造把握、(2) T-02 skill に「事前メトリクス検証」セクション追記、(3) T-03 `docs/ai/plan-metrics-verification.md` 運用ガイド、(4) T-04 ta-19 機械検証 test、(5) T-05 handoff + V-1。

## Work Breakdown

| # | Step | Output | Owner | Risk | 🚩 |
|---|------|--------|-------|------|----|
| 1 | **T-01 調査**: `.claude/skills/ai-dev-plan/` (or `.claude/commands/`) 構造把握、PocketEitan PR #371 該当セクション参照 | 調査メモ | AI | low | 既存構造マップ |
| 2 | **T-02 skill 追記**: ai-dev-plan skill に「事前メトリクス検証」セクション追加 (検証コマンド例 / 判定基準 / 実例 link) | `.claude/skills/ai-dev-plan/SKILL.md` (or 該当 file) | AI | medium (Hardening Override) | maintenance window 経由 + markdownlint |
| 3 | **T-03 doc**: `docs/ai/plan-metrics-verification.md` 新規 (運用ガイド + PocketEitan 実例 + 判定基準数値) | docs/ai/plan-metrics-verification.md | AI | low | Human/AI 双方が参照可能 |
| 4 | **T-04 test**: `tests/extras/ta-19-plan-metrics-verification.sh` (skill に該当セクション含むことを grep で機械検証) | tests/extras/ta-19-plan-metrics-verification.sh | AI | low | ta-19 PASS |
| 5 | **T-05 handoff + V-1** | handoff.md | AI | low | AC-1..7 PASS |

## Files / Components to Touch

| ファイル | 性質 |
|---------|------|
| `.claude/skills/ai-dev-plan/SKILL.md` (or 該当 file) | 追記 (**Hardening Override**) |
| `docs/ai/plan-metrics-verification.md` | 新規 |
| `tests/extras/ta-19-plan-metrics-verification.sh` | 新規 |
| `docs/working/TASK-0117/handoff.md` | WF-05 |

## Testing Strategy

- 機械検証: ta-19 で skill に該当セクション grep
- markdownlint
- 既存テスト regression なし

## Risks & Mitigations

| Risk | Sev | Mitigation |
|------|-----|------------|
| LLM 解釈依存でソフトルール効果薄い | medium | 判定基準を数値化 (3 倍 / 1〜3 倍 / <1) + 実例 + コマンド例で具体性確保 |
| Hardening Override 対象改修が EH-3 で block | high | C-3 APPROVED + maintenance window (TASK-0106/0112/0115 で実証済) |
| TASK-0112 と重複定義感 | low | 相互参照のみ、本 PBI = plan 前メトリクス、TASK-0112 = mode 自動補正 |
| 既存 ai-dev-plan 動作 regression | low | additive only、既存 step 不変 |

## Mode 判定

**light** (lite_eligible=false / Hardening Override)

- 変更ファイル数: 4 (skill 追記 + doc 新規 + test 新規 + handoff)
- 受入基準数: 7
- 変更種別: skill 追記 + docs + test
- リスク: 中 (Hardening Override 対象)
- ロールバック: 容易
- 影響範囲: A → B 遷移時の AI 動作に波及 (process drift 抑制)

→ light で進行 (lite_eligible=false 強制、`.claude/` 配下のため)。
