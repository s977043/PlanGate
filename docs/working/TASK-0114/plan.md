# TASK-0114 EXECUTION PLAN

> Source: pbi-input.md / INC-2026-05-26-001 P-1 / Mode: **standard**
> Generated: 2026-05-26

## Goal

PlanGate 標準テンプレに pre-push hook を提供し、AI からの main / master / release branch 直接 push を **physical block**。INC-2026-05-26-001 寄与要因 C-3 を解消。

## Constraints / Non-goals

- GitHub branch protection (P-2) には触れない (Human-owned)
- `.claude/rules/` 追記 (P-3 = TASK-0115) には触れない (orthogonal)
- AI が `.git/hooks/` を repo にコミットしない (template + install script のみ)

## Approach Overview

TASK-0113 (#355 pre-commit hook、PR #358) と並列構造で pre-push 版を提供。

## Work Breakdown

| # | Step | Output | Owner | Risk | 🚩 |
|---|------|--------|-------|------|----|
| 1 | **T-01 調査**: TASK-0113 template / install pattern 確認、git pre-push 仕様 (stdin format) 確認 | 調査メモ | AI | low | パターン把握 |
| 2 | **T-02 (R-002/R-007)**: `scripts/templates/pre-push.sample` (POSIX sh、stdin parsing、protected check via `case $branch in $pattern)` (右辺 unquoted で glob)、エラーメッセージ) | scripts/templates/pre-push.sample | AI | medium | protected push 検出 + 明確メッセージ + release/* glob 動作 |
| 3 | **T-03**: `scripts/install-pre-push.sh` (TASK-0113 install スクリプトと並列、`.bak` 保持) | scripts/install-pre-push.sh | AI | low | install 後 hook 発火 |
| 4 | **T-04**: `docs/ai/direct-push-prevention.md` 運用ガイド | docs/ai/direct-push-prevention.md | AI | low | Human が読んで運用可能 |
| 5 | **T-05**: `tests/extras/ta-17-pre-push-guard.sh` fixture 5 case | tests/extras/ta-17-pre-push-guard.sh | AI | low | tests/run-tests.sh + ta-17 PASS |
| 6 | **T-06 handoff + V-1** | handoff.md | AI | low | AC-1..7 PASS |

## Files / Components to Touch

| ファイル | 性質 |
|---------|------|
| `scripts/templates/pre-push.sample` | 新規 (POSIX sh) |
| `scripts/install-pre-push.sh` | 新規 |
| `docs/ai/direct-push-prevention.md` | 新規 |
| `tests/extras/ta-17-pre-push-guard.sh` | 新規 |
| `docs/working/TASK-0114/handoff.md` | WF-05 |

`.claude/settings.json` / `.git/hooks/` (repo 内) には触れない。

## Testing Strategy

- Unit: fixture stdin で hook 単体動作 (5 case)
- Integration: 一時 repo で `git push` 経由発火確認
- 回帰: tests/run-tests.sh + tests/hooks/run-tests.sh
- markdownlint + shellcheck

## Risks & Mitigations

| Risk | Sev | Mitigation |
|------|-----|------------|
| feature branch push false positive | low | protected list 明確化 + override env |
| 既存 hook 衝突 | low | `.bak` 保持 + 明示警告 |
| `--no-verify` で容易 bypass | acceptable (R-003) | 緊急脱出弁、P-2 (GitHub branch protection) との責務分界を doc に強く明記 — **local hook は最後の防衛線、repo-wide enforcement は P-2 必須** |
| stdin format の OS 差 | low | git 公式仕様準拠 (`<local ref> <local sha> <remote ref> <remote sha>`) |

## Mode 判定

**standard** (lite_eligible=false)

- 変更ファイル数: 5 (新規)
- 受入基準数: 7
- 変更種別: 新規 template + install + doc + test
- リスク: 中 (push 経路への介入、ただし opt-in install で影響限定)
- 影響範囲: install するまで効果なし
- 承認境界: `scripts/templates/` は新規パス、Hardening Override 対象外 → standard
