# TASK-0115 EXECUTION PLAN

> Source: pbi-input.md / INC-2026-05-26-001 P-3 / Mode: **light**
> Generated: 2026-05-26

## Goal

`.claude/rules/responsibility-classes.md` に「Bash 連結コマンド時の error guard」セクションを追加し、INC-2026-05-26-001 寄与要因 C-1 を文書化された運用 rule として構造化。

## Constraints / Non-goals

- AI 側自動チェック実装は scope 外 (P-1 = TASK-0114 と層分離)
- TASK-0112 例外ルールを破壊しない (additive)
- AI 運用 4 原則 (CLAUDE.md `<law>`) との階層関係を明示

## Approach Overview

`.claude/rules/responsibility-classes.md` への追記のみ (TASK-0112 と同じ操作手順)。Hardening Override 対象のため C-3 APPROVED + maintenance window 経由で適用。

## Work Breakdown

| # | Step | Output | Owner | Risk | 🚩 |
|---|------|--------|-------|------|----|
| 1 | **T-01 調査**: TASK-0112 適用パターン確認、`responsibility-classes.md` 既存セクション構造把握 | 調査メモ | AI | low | 構造把握 |
| 2 | **T-02 追記**: `.claude/rules/responsibility-classes.md` に新セクション「Bash 連結コマンド時の error guard (INC-2026-05-26-001 P-3)」追加 | responsibility-classes.md | AI | medium (Hardening Override) | maintenance window 経由 + markdownlint |
| 3 | **T-03**: handoff.md + V-1 | handoff.md | AI | low | AC-1..5 PASS |

## Files / Components to Touch

| ファイル | 性質 |
|---------|------|
| `.claude/rules/responsibility-classes.md` | 追記 (**Hardening Override 対象**) |
| `docs/working/TASK-0115/handoff.md` | WF-05 |

## Testing Strategy

- markdownlint
- リンク健全性 CI (INC report への相対パス確認)
- 既存テスト regression なし

## Risks & Mitigations

| Risk | Sev | Mitigation |
|------|-----|------------|
| Hardening Override 対象改修が EH-3 で block | high | C-3 APPROVED + maintenance window 経由 (TASK-0106/0112 で実証済) |
| TASK-0114 (P-1 hook) との重複感 | low | 文言で「物理 block は TASK-0114 (P-1)」「行動規範は本 rule (P-3)」と層分離明示 |
| AI 自己解釈で rule 緩和 | medium | 文言明確 + INC 参照で実例固定 + 第 4 原則 (解釈変更禁止) を引用 |

## Mode 判定

**light** (lite_eligible=false)

- 変更ファイル数: 1 (+handoff 1)
- 受入基準数: 5
- 変更種別: docs (rule) 追記
- リスク: 中 (Hardening Override 対象)
- ロールバック: 容易
- 影響範囲: `.claude/rules/responsibility-classes.md` のみ、以降の AI 運用に波及

→ light で進行、ただし `lite_eligible=false` 強制 (承認境界周辺自体、TASK-0112 例外ルール該当)。
