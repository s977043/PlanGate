# TASK-0120 PBI INPUT PACKAGE

> 出自: Session Retrospective 2026-05-24〜28 (PR #401) Try #2
> 関連: feedback_github_account_switch memory

## Context / Why

本セッションで `gh` の active account が意図せず kominem-unilabo にスイッチし、`gh pr create` / GraphQL mutation (resolveReviewThread) が `must be a collaborator` / `FORBIDDEN` で失敗する事例が 5+ 回発生。都度 `gh auth switch --user s977043` で復旧したが属人的。

PlanGate ルール: コミット / PR / merge は s977043 アカウント固定 (sockpuppet 禁止、`feedback_github_account_switch` / `feedback_no_sockpuppet_merge`)。

## What (Scope)

### In scope

- `scripts/gh-s977043.sh` (新規) — gh 操作前に active account を s977043 に強制するラッパ
  - `gh auth switch --user s977043` を冒頭で実行してから引数を gh に渡す
- `docs/ai/github-account-pinning.md` (新規 or 既存追記) — 運用ガイド (commit/PR/merge は s977043 固定)
- SessionStart hook 連携確認 (既存 `gh-pin-account` hook が「already pinned to s977043」を出力していた → 本ラッパとの責務整理)
- `tests/extras/ta-23-gh-account-pin.sh` (ラッパ存在 + s977043 switch ロジック検証)

### Out of scope

- gh CLI 本体の改修
- 認証情報 (token) の管理 (既存 keyring 利用)
- sockpuppet 禁止ルール自体 (既存 memory / responsibility-classes で規定済)

## 受入基準

- AC-1: `scripts/gh-s977043.sh` が `gh auth switch --user s977043` 後に gh 引数を実行
- AC-2: active account が既に s977043 ならスイッチ skip (冪等)
- AC-3: `docs/ai/github-account-pinning.md` で運用ガイド (commit/PR/merge 固定)
- AC-4: 既存 SessionStart `gh-pin-account` hook との責務整理を doc に明記
- AC-5: `tests/extras/ta-23-gh-account-pin.sh` で検証
- AC-6: markdownlint + shellcheck + 既存テスト regression なし

## Notes from Refinement

- scripts/ ルート直下は Hardening Override 対象外 (scripts/hooks/ ではない)
- 既存 SessionStart hook `gh-pin-account` が pinning を試みているが、セッション中の mutation 操作前には効かない → 本ラッパで補完
- C (ツール運用変更) 分類

## Estimation

### Risks
- gh auth switch の権限不足環境 → mitigation: switch 失敗時 warning + 続行
- 既存 hook との二重 pinning → mitigation: 責務整理 doc

### Unknowns
- SessionStart hook の実装場所 (.claude/settings.json or scripts/hooks/) → T-01

### Assumptions
- s977043 アカウントが gh auth に登録済 (keyring)
