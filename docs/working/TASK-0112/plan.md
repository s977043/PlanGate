# TASK-0112 EXECUTION PLAN

> Source: pbi-input.md / Codex 推奨 C / Mode: **standard** (R-001 反映)
> Generated: 2026-05-26

## Goal

`.claude/rules/mode-classification.md` の例外ルールに「承認境界周辺の変更 → 最低でも『高』」を追加し、自動推定の安全側ルールと整合させる。TASK-0106 Retrospective Try アクションを構造化。

## Constraints / Non-goals

- 既存の 3 例外ルール（セキュリティ/DB/公開 API）を破壊しない（additive change）
- mode 自動推定の実装変更を含まない（文言追加のみ）
- `working-context.md` AC-10/AC-8 と重複定義せず相互参照
- 既存テスト regression なし

## Approach Overview

`.claude/rules/mode-classification.md` の例外ルールセクション 1 箇所への追記のみ。`.claude/rules/` は Hardening Override 対象のため、本 PBI は **Human-owned patch (PR ベース)** で適用 (R-002 反映: maintenance window 経由は承認境界変更を一時 window で通す前提が現行防御モデルと衝突するため不採用)。

## Work Breakdown

| # | Step | Output | Owner | Risk | 🚩 |
|---|------|--------|-------|------|----|
| 1 | **T-01**: 既存例外ルール構造確認 + Hardening Override 対象パスの単一情報源（check-plan-hash.sh）抽出 | 調査メモ | AI | low | パス一覧確定 |
| 2 | **T-02 (R-002/R-003)**: `.claude/rules/mode-classification.md` 例外ルール追記 (承認境界周辺→最低「高」 + **9 カテゴリ対象パス一覧** (check-plan-hash.sh L124-134 と一致) + 監査ログ CLI 例外 + 自動推定安全側) | mode-classification.md | **Human (PR patch)** | medium (Hardening Override) | **Human-owned patch** + markdownlint pass |
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
| Hardening Override 対象パス改変が EH-3 で block | high | **Human-owned patch** で適用 (R-002 反映、maintenance window 経由は承認境界変更を一時 window で通す前提が防御モデルと衝突のため不採用) |
| 既存進行中 PBI の mode 判定再評価リクエスト | low | 「本 PBI merge 後着手の PBI から適用」を文言に含める |
| 例外ルール乱立 | low | 対象パスを Hardening Override と完全一致させて単一情報源化 |

## Mode 判定 (R-001 反映)

**standard** (`lite_eligible=false` 強制)

- 変更ファイル数: 1 (+handoff 1)
- 受入基準数: 6
- 変更種別: docs (rule) 追記
- リスク: 中-高 (Hardening Override 対象、承認境界自体への改修)
- ロールバック: 容易 (git revert)
- 影響範囲: `.claude/rules/mode-classification.md`、以降の PBI mode 推定に波及

→ **standard に補正** (旧 light は R-001 反映で修正)。本 PBI 自身が「承認境界周辺は最低 高」を導入するため、自己例外 (light) は設計レーン上の矛盾。Hardening Override 対象の rule 改修は最低 standard、本 PBI の作業量は light 相当だが **リスクと影響範囲で standard** を選択。
