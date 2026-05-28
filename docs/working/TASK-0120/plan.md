# TASK-0120 EXECUTION PLAN

> Source: pbi-input.md / Session Retro Try #2 / Mode: **light**
> Generated: 2026-05-28

## Goal

gh 操作前に active account を s977043 に強制するラッパを整備し、本セッションで多発した account 切替による権限エラーを構造的に防ぐ。

## Constraints / Non-goals

- gh CLI 本体改修しない
- sockpuppet 禁止ルール自体は既存規定 (本 PBI はツール運用補助)
- scripts/ ルート直下は HO 対象外

## Approach Overview

(1) T-01 既存 SessionStart gh-pin-account hook 実装場所確認、(2) T-02 scripts/gh-s977043.sh 新規、(3) T-03 doc、(4) T-04 ta-23、(5) T-05 handoff。

## Work Breakdown

| # | Step | Output | Owner | Risk | 🚩 |
|---|------|--------|-------|------|----|
| 1 | T-01 調査: SessionStart gh-pin-account hook 実装場所 + 責務確認 | 調査メモ | AI | low | 責務整理 |
| 2 | T-02: scripts/gh-s977043.sh (auth switch + 冪等) | scripts/gh-s977043.sh | AI | low | switch + gh 実行 |
| 3 | T-03: docs/ai/github-account-pinning.md | docs/ai/github-account-pinning.md | AI | low | 運用ガイド |
| 4 | T-04: tests/extras/ta-23-gh-account-pin.sh | tests/extras/ta-23-gh-account-pin.sh | AI | low | ta-23 PASS |
| 5 | T-05: handoff + V-1 | handoff.md | AI | low | AC-1..6 PASS |

## Files / Components to Touch

| ファイル | 性質 |
|---------|------|
| scripts/gh-s977043.sh | 新規 (HO 対象外、scripts/ ルート) |
| docs/ai/github-account-pinning.md | 新規 |
| tests/extras/ta-23-gh-account-pin.sh | 新規 |
| docs/working/TASK-0120/handoff.md | WF-05 |

## Testing Strategy

- ラッパ存在 + switch ロジック grep 検証
- shellcheck + markdownlint + 既存テスト regression

## Risks & Mitigations

| Risk | Sev | Mitigation |
|------|-----|------------|
| switch 権限不足環境 | low | switch 失敗時 warning + 続行 |
| SessionStart hook と二重 pinning | low | 責務整理 doc |

## Mode 判定

**light** (HO 対象外、scripts/ ルート直下)

Session Retro Try #2 由来。TASK-0117 事前メトリクス: 想定 4 file、light 維持。
