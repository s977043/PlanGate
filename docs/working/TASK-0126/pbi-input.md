# PBI INPUT PACKAGE: TASK-0126

## Context / Why
外部レビュー接続 IF（`docs/ai/external-reviewer-interface.md`）に plan-quality レーンの具体 Skill が存在せず、C-2 での plan 設計妥当性チェックが口頭運用に留まっている。`review-principles.md §7-bis` の 2 レーン設計を Skill 化し、R-NNN 集約フローと繋ぐことで機械的に再現可能にする。

Closes #429 (Phase 1 — plan-quality PoC)

## What

### In scope
- `.claude/skills/plan-quality-reviewer/SKILL.md` 新規作成（設計妥当性レーン専用）
- `docs/ai/external-reviewer-interface.md` への plan-quality エントリ追記

### Out of scope
- security-risk / test-strategy 以降の reviewer Skill 化
- MCP 権限分離・新規 hook 追加
- Lite ゲートの変更
- 実装コードレビュー（V-3 担当）

## 受入基準

| AC | 内容 |
|----|------|
| AC-01 | SKILL.md が `review-principles.md §7-bis` 設計妥当性レーンの責務（plan/todo/test-cases を読む・実コード原則不読）を明示している |
| AC-02 | Skill 出力フォーマットが `R-NNN / lane / severity / status` を含み `review-external.md` 追記と互換である |
| AC-03 | `external-reviewer-interface.md` に plan-quality を導入パターン（1 本目）として追記済みである |
| AC-04 | SKILL.md が案件固有情報を含まず他リポジトリで再利用可能である（`hybrid-architecture.md` Rule 2 準拠） |

## Notes from Refinement
- Codex / Gemini 合意: 2 レーン設計（§7-bis）を壊さない
- R-NNN 集約フローとの互換は必須

## Estimation Evidence

### Risks / Unknowns
- `external-reviewer-interface.md` の既存構造と新エントリの整合性

### Assumptions
- 既存 `.claude/skills/` 配下のパターンに沿って SKILL.md を作成
