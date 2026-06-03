# Execution Plan: TASK-0126

## Goal
`review-principles.md §7-bis` の設計妥当性レーンを Skill 化（`plan-quality-reviewer`）し、
C-2 外部レビュー時に R-NNN 形式の構造化出力を `review-external.md` へ追記できるようにする。
Closes #429 Phase 1。

## Constraints / Non-goals
- 既存の `plan-quality-check` Skill（内部セルフチェック）は変更しない
- security-risk / test-strategy 以降の reviewer は本 PBI 範囲外
- MCP 権限分離・新規 hook 追加は範囲外
- `.plangate-reviewers.yaml` の変更は範囲外

## Approach Overview
1. `.claude/skills/plan-quality-reviewer/SKILL.md` を新規作成
   - 設計妥当性レーンの責務（plan/todo/test-cases を読む、実コード原則不読）
   - 出力フォーマット: `R-NNN / lane=design-validity / severity / status`
   - `review-external.md` 追記互換
2. `docs/ai/external-reviewer-interface.md` に plan-quality-reviewer エントリを追記

## Mode 判定
**light** — 変更ファイル 2 件、新規 Skill 1 本の追加のみ、HO 対象パス非該当

## Files / Components to Touch
- `.claude/skills/plan-quality-reviewer/SKILL.md`（新規）
- `docs/ai/external-reviewer-interface.md`（追記）
- `docs/working/TASK-0126/`（作業コンテキスト）

## Testing Strategy
- SKILL.md の frontmatter / 必須セクション存在チェック（sh -n 相当の lint）
- `hybrid-architecture.md` Rule 2 準拠確認（案件固有情報なし）
- `external-reviewer-interface.md` 追記後の整合確認（markdownlint）

## Risks & Mitigations
- `external-reviewer-interface.md` は正本ファイル — 既存構造を破壊しない追記に限定

## Questions / Unknowns
- 既存の `plan-quality-check` との名称混同を避けるコメントが必要か → SKILL.md に明示
