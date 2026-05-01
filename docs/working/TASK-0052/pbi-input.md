# PBI INPUT PACKAGE: TASK-0052 / Issue #171

> Source: [#171 gh CLI active account 自動固定 shim](https://github.com/s977043/plangate/issues/171)
> Mode: **light**

## Context / Why

retrospective 2026-04-30 T-5 / 2026-05-01 P-1。plangate での作業中に gh CLI の active account が `kominem-unilabo` へ勝手に切り戻る現象が頻発。本セッションだけで 4 回以上、共有 mutation が `does not have the correct permissions` で失敗 → 手動 `gh auth switch` 必要。

## What

### In scope
- `scripts/gh-pin-account.sh`: 現在 user チェック + 必要時のみ `gh auth switch` 実行
- 環境変数 `PLANGATE_GH_USER` で username override（デフォルト `s977043`）
- `.claude/settings.example.json` の SessionStart hook に追加（opt-in）
- 不在 / 切替失敗時の明確なエラーメッセージ

### Out of scope
- Claude Code 以外の AI（Codex / Gemini）連携
- gh CLI 自体のバグ修正（上流 issue 領域）

## Acceptance Criteria

- AC-1: `sh scripts/gh-pin-account.sh` が冪等（複数回実行しても問題なし）
- AC-2: 既に正しい user 時は `already pinned` と出力 + exit 0
- AC-3: 別 user 時は切り替え + `switched to` と出力 + exit 0
- AC-4: 該当 user が logged-in でない時は `not in gh auth status` と stderr + exit 1
- AC-5: `gh` 不在時は `not installed` と stderr + exit 1
- AC-6: `.claude/settings.example.json` に SessionStart hook が登録されている
