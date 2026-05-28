# TASK-0119 EXECUTION PLAN

> Source: pbi-input.md / Session Retro Try #1 / Mode: **standard**
> Generated: 2026-05-28

## Goal

`git add -A` による scope 外ファイル誤混入を pre-commit 層で機械検知し、本セッションで多発した noise 混入を構造的に防ぐ。

## Constraints / Non-goals

- `git add -A` コマンド自体は禁止しない (検知に留める)
- TASK-0113 (claude-mem) と重複しない (統合 or 責務分界)
- scripts/hooks/ は Hardening Override (c3 + plan_hash で AI exec)

## Approach Overview

(1) T-01 既存 TASK-0113 pre-commit 構造 + 共通化可否確認、(2) T-02 check-git-add-scope.sh 新規 (or TASK-0113 統合)、(3) T-03 doc、(4) T-04 ta-22、(5) T-05 handoff。

## Work Breakdown

| # | Step | Output | Owner | Risk | 🚩 |
|---|------|--------|-------|------|----|
| 1 | T-01 調査: TASK-0113 check-ai-memory-pollution.sh / pre-commit.sample 構造 + 共通 dispatcher 可否 | 調査メモ | AI | low | 統合方針確定 |
| 2 | T-02: scripts/hooks/check-git-add-scope.sh (skip-log 未追認 / 他 TASK eval-result 検知) | scripts/hooks/check-git-add-scope.sh (HO) | AI | medium | 検知 + exit 1 |
| 3 | T-03: docs/ai/git-add-scope-guard.md | docs/ai/git-add-scope-guard.md | AI | low | Human 運用可能 |
| 4 | T-04: tests/extras/ta-22-git-add-scope.sh | tests/extras/ta-22-git-add-scope.sh | AI | low | ta-22 PASS |
| 5 | T-05: handoff + V-1 | docs/working/TASK-0119/handoff.md | AI | low | AC-1..6 PASS |

## Files / Components to Touch

| ファイル | 性質 |
|---------|------|
| scripts/hooks/check-git-add-scope.sh | 新規 (HO) |
| docs/ai/git-add-scope-guard.md | 新規 |
| tests/extras/ta-22-git-add-scope.sh | 新規 |
| (T-01 次第) scripts/templates/pre-commit.sample | 既存統合の可能性 |
| docs/working/TASK-0119/handoff.md | WF-05 |

## Testing Strategy

- fixture で noise file staged → 検知確認
- markdownlint + 既存テスト regression
- TASK-0113 共存確認

## Risks & Mitigations

| Risk | Sev | Mitigation |
|------|-----|------------|
| TASK-0113 機能重複 | medium | T-01 で統合 or 責務分界 |
| HO path EH-3 block | high | c3 APPROVED + plan_hash 一致 (実証済) |
| false positive | medium | allowlist + 設定可能化 |

## Mode 判定

**standard** (lite_eligible=false、scripts/hooks/ HO)

Session Retro Try #1 由来。TASK-0117 事前メトリクス: 想定 4 file、standard 維持。
