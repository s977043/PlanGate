# TASK-0112 EXECUTION PLAN

> Source: pbi-input.md / Codex 推奨 C / Mode: **light**
> Generated: 2026-05-26

## Goal

`.claude/rules/mode-classification.md` の例外ルールに「承認境界周辺の変更 → 最低でも『高』」を追加し、自動推定の安全側ルールと整合させる。TASK-0106 Retrospective Try アクションを構造化。

## Constraints / Non-goals

- 既存の 3 例外ルール（セキュリティ/DB/公開 API）を破壊しない（additive change）
- mode 自動推定の実装変更を含まない（文言追加のみ）
- `working-context.md` AC-10/AC-8 と重複定義せず相互参照
- 既存テスト regression なし

## Approach Overview

`.claude/rules/mode-classification.md` の例外ルールセクション 1 箇所への追記のみ。`.claude/rules/` は Hardening Override 対象のため、本 PBI の C-3 APPROVED + maintenance window 経由で適用。

## Work Breakdown

| # | Step | Output | Owner | Risk | 🚩 |
|---|------|--------|-------|------|----|
| 1 | **T-01**: 既存例外ルール構造確認 + Hardening Override 対象パスの単一情報源（check-plan-hash.sh）抽出 | 調査メモ | AI | low | パス一覧確定 |
| 2 | **T-02**: `.claude/rules/mode-classification.md` 例外ルール追記 (承認境界周辺→最低「高」 + 対象パス一覧 + 監査ログ CLI 例外 + 自動推定安全側) | mode-classification.md | AI | medium (Hardening Override) | maintenance window 経由 + markdownlint pass |
| 3 | **T-03**: handoff.md (Rule 5) + V-1 | handoff.md | AI | low | AC-1..6 PASS |

## Files / Components to Touch

| ファイル | 性質 |
|---------|------|
| `.claude/rules/mode-classification.md` | 例外ルール追記（**Hardening Override 対象**） |
| `docs/working/TASK-0112/handoff.md` | WF-05 |

## Testing Strategy

- **markdownlint**: `.claude/rules/mode-classification.md`
- **リンク健全性 CI**: 既存 reference 健全性 check で `working-context.md` への相互参照確認
- **CI**: settings wiring drift / Markdown lint / SKIP_REASON 追認 / check 全 PASS

## Risks & Mitigations

| Risk | Sev | Mitigation |
|------|-----|------------|
| Hardening Override 対象パス改変が EH-3 で block | high | C-3 APPROVED + maintenance window 経由で適用（TASK-0106 で実証済の運用） |
| 既存進行中 PBI の mode 判定再評価リクエスト | low | 「本 PBI merge 後着手の PBI から適用」を文言に含める |
| 例外ルール乱立 | low | 対象パスを Hardening Override と完全一致させて単一情報源化 |

## Mode 判定

**light** (`lite_eligible=false` 強制)

- 変更ファイル数: 1（+handoff 1）
- 受入基準数: 6
- 変更種別: docs (rule) 追記
- リスク: 中 (Hardening Override 対象だが内容は additive 文言追加)
- ロールバック: 容易 (git revert)
- 影響範囲: `.claude/rules/mode-classification.md` のみ、以降の PBI mode 推定に波及

→ light で進行、ただし `lite_eligible=false` 強制（承認境界周辺自体）。**自己適用**（本 PBI 自体が新ルール対象なら最低「高」になるが、文言追加のみで影響範囲が rule 文言に限定されるため light で C-3 判定を仰ぐ）
