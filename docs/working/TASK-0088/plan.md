# EXECUTION PLAN — TASK-0088 / #226

## Goal
ultra-light→standard 成長パスを正本化し、初回導入を Day 1 体験レベルに下げる。

## Constraints / Non-goals
docs のみ。settings.json 実配線・hook 実装は変更しない。

## Approach
新規 `docs/staged-adoption-guide.md`：Phase 0-3 + フック推奨順序 + エージェント
最小セット + チェックリスト。実 hook/agent 名で記述。plangate.md に参照節追加。

## Work Breakdown
| Step | Output | Owner | Risk | 🚩 |
|------|--------|-------|------|----|
| S1 | staged-adoption-guide.md 作成 | agent | 低 | 🚩 AC1-4 |
| S2 | plangate.md 参照節追加 | agent | 低 | 🚩 AC5 |

## Files
- docs/staged-adoption-guide.md（新規）
- docs/plangate.md（参照節）

## Testing Strategy
Verification: AC1-5 を grep 構造突合（test-cases.md）。

## Risks & Mitigations
実 hook/agent 名不整合 → hook-enforcement.md / .claude/agents/ と突合済

## Questions / Unknowns
なし

## Mode判定
**モード**: light
**判定根拠**: 変更2ファイル / 受入5 / docs新規 / リスク低 → **light**（docs only）
