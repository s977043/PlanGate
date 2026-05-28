# TASK-0118 EXECUTION PLAN

> Source: pbi-input.md / Issue #352 / Mode: **standard**
> Generated: 2026-05-28 / Codex 推奨 A

## Goal

規模 L 以上の機能を **最小 MVP (Phase 1) → Phase 2 → ...** に分割する skill / command を整備し、A フェーズ前段で利用可能化。属人化された Codex 相談プロセスを標準化。

## Constraints / Non-goals

- Hardening Override 対象パス (`.claude/commands/` `.agents/skills/`) → Human-owned patch 設計 (本 PBI exec は AI 直接書き込み、c3.json APPROVED + plan_hash 一致で EH-3 通過)
- 既存 ai-dev-plan skill / B-1/B-2/B-3 フローを破壊しない (additive)
- TASK-0117 (#351 事前メトリクス検証) と重複定義しない (相互参照のみ)
- Codex 自動 dispatch は scope 外 (質問テンプレ提供のみ)

## Approach Overview

(1) T-01 既存 skill / command pattern 把握、(2) T-02 `.claude/commands/codex-mvp-split.md` 新規、(3) T-03 `.agents/skills/codex-mvp-split/SKILL.md` 新規、(4) T-04 `docs/ai/codex-mvp-split.md` 運用ガイド、(5) T-05 `tests/extras/ta-21-codex-mvp-split.sh`、(6) T-06 handoff + V-1。

## Work Breakdown

| # | Step | Output | Owner | Risk | 🚩 |
|---|------|--------|-------|------|----|
| 1 | **T-01 調査**: 既存 `.claude/commands/` / `.agents/skills/ai-dev-plan/` 構造 + PocketEitan PR #371 該当 commands 参照 | 調査メモ | AI | low | 既存 pattern マップ |
| 2 | **T-02 slash command**: `.claude/commands/codex-mvp-split.md` (frontmatter + 質問テンプレ + 4 選択肢 + 工数 S/M/L + 判断 3 軸 + Phase 分割表 template) | `.claude/commands/codex-mvp-split.md` (HO) | AI | medium (HO) | slash command 動作 |
| 3 | **T-03 skill**: `.agents/skills/codex-mvp-split/SKILL.md` (薄い skill、入出力規約のみ、詳細は doc 参照) | `.agents/skills/codex-mvp-split/SKILL.md` | AI | low | skill 構造 (ai-dev-plan と同 pattern) |
| 4 | **T-04 doc**: `docs/ai/codex-mvp-split.md` 運用ガイド (質問テンプレ詳細 + 採用フロー + PocketEitan 実例 2 件 + TASK-0117 連携) | docs/ai/codex-mvp-split.md | AI | low | Human/AI 双方が参照可能 |
| 5 | **T-05 template**: `docs/working/templates/pbi-input.md` に「Phase 分割表」section 追加 (AC-4 反映) | docs/working/templates/pbi-input.md | AI | low | 既存 template 整合 |
| 6 | **T-06 test**: `tests/extras/ta-21-codex-mvp-split.sh` (skill / command / doc / template 構造検証) | tests/extras/ta-21-codex-mvp-split.sh | AI | low | ta-21 全 PASS |
| 7 | **T-07 handoff + V-1** | handoff.md | AI | low | AC-1..8 PASS |

## Files / Components to Touch

| ファイル | 性質 |
|---------|------|
| `.claude/commands/codex-mvp-split.md` | 新規 (**Hardening Override**) |
| `.agents/skills/codex-mvp-split/SKILL.md` | 新規 (HO 対象外、`.agents/` 配下) |
| `docs/ai/codex-mvp-split.md` | 新規 |
| `docs/working/templates/pbi-input.md` | 追記 (Phase 分割表 section) |
| `tests/extras/ta-21-codex-mvp-split.sh` | 新規 |
| `docs/working/TASK-0118/handoff.md` | WF-05 |

## Testing Strategy

- 機械検証: ta-21 で skill / command / doc に必須要素 (4 選択肢 / 工数 / 3 軸 / 実例) 含有確認
- markdownlint
- 既存テスト regression なし

## Risks & Mitigations

| Risk | Sev | Mitigation |
|------|-----|------------|
| Hardening Override (`.claude/commands/`) 改修が EH-3 で block | high | c3.json APPROVED + plan_hash 一致で EH-3 通過 (TASK-0112/0113/0115/0117 で実証済) |
| LLM 解釈依存のソフトルール効果薄 | medium | 質問テンプレ + 4 選択肢 + 工数 + 3 軸で具体性確保 |
| TASK-0117 (#351) との重複感 | low | 本 PBI = MVP Phase 分割 (規模 L 以上)、TASK-0117 = 事前メトリクス検証 (規模判定)。AND 関係、相互参照のみ |
| PocketEitan 外部参照が不安定 | low | literal text として記録 (リンクではなく内容引用) |

## Mode 判定

**standard** (lite_eligible=false、`.claude/commands/` は HO)

- 変更ファイル数: 6
- 受入基準数: 8
- 変更種別: 新規 skill + command + docs + template + test
- リスク: 中 (HO 対象を含む、ただし TASK-0112 例外ルールで standard が下限)
- ロールバック: 容易
- 影響範囲: A フェーズ前段の AI workflow に波及

TASK-0117 (#351) 自己適用: 想定 6 file vs 実 6 file = 1.0 倍 → standard 維持。
