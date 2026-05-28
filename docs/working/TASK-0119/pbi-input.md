# TASK-0119 PBI INPUT PACKAGE

> 出自: Session Retrospective 2026-05-24〜28 (PR #401) Try #1
> 関連: INC-2026-05-26-001 / TASK-0113 (claude-mem 検知 pre-commit hook)

## Context / Why

本セッション (TASK-0108〜0118) で `git add -A` の多用により、scope 外ファイル (AGENTS.md の claude-mem 自動挿入 / skip-decision-log.jsonl / TASK-0059 eval-result) が複数回 commit に誤混入。PR #376/#383/#395 で cleanup commit が発生、PR #340 系では CI fail も誘発。

退避策 (個別 `git add <path>` + `git restore --staged`) は機能したが属人的で、機械ガードがない。

## What (Scope)

### In scope

- `scripts/hooks/check-git-add-scope.sh` (新規) — pre-commit 段階で staged file に「scope 外と推定される noise」を検知
  - 既定検知対象: `docs/working/_audit/skip-decision-log.jsonl` (未追認) / `<claude-mem-context>` 含む file / `docs/working/TASK-*/eval-result.*` (他 TASK の dirty)
- TASK-0113 (claude-mem 検知) との統合 or 並列 (重複回避、共通 pre-commit dispatcher 検討)
- allowlist marker / 設定可能化 (TASK-0113 と同 pattern)
- `docs/ai/git-add-scope-guard.md` 運用ガイド
- `tests/extras/ta-22-git-add-scope.sh`

### Out of scope

- `git add -A` コマンド自体の禁止 (git wrapper は侵襲的、検知に留める)
- AI 行動規範 (TASK-0115 で Bash 連結 guard 済、本 PBI は機械ガード)

## 受入基準

- AC-1: `scripts/hooks/check-git-add-scope.sh` が staged diff に noise (skip-log 未追認 / claude-mem / 他 TASK eval-result) を検知して warning + exit 1
- AC-2: TASK-0113 hook との重複回避 (共通化 or 明確な責務分界)
- AC-3: allowlist marker で個別許可可能
- AC-4: `docs/ai/git-add-scope-guard.md` 運用ガイド
- AC-5: `tests/extras/ta-22-git-add-scope.sh` で fixture 検証
- AC-6: markdownlint + 既存テスト regression なし

## Notes from Refinement

- TASK-0113 (claude-mem) / TASK-0114 (pre-push) と並列構造、scripts/templates/ + install pattern 踏襲
- scripts/hooks/ は Hardening Override → c3.json APPROVED + plan_hash 一致で AI exec 可
- TASK-0113 との統合は T-01 で実体確認 (pre-commit dispatcher が既にあるか)

## Estimation

### Risks
- TASK-0113 と機能重複 → mitigation: T-01 で統合 or 責務分界明確化
- false positive → mitigation: allowlist marker + 設定可能化

### Unknowns
- TASK-0113 の pre-commit.sample に統合すべきか別 hook か → T-01

### Assumptions
- scripts/hooks/ HO、c3 + plan_hash で AI exec 可 (本セッションで実証済)
