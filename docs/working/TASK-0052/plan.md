# EXECUTION PLAN: TASK-0052 / Issue #171

> Mode: **light**

## Goal

plangate 作業時に gh CLI active account を `s977043` に自動固定する shim を提供。SessionStart hook + 単発実行 CLI の両方を opt-in で利用可能にする。

## Approach

1. `scripts/gh-pin-account.sh`: POSIX sh、`gh api user --jq .login` で現在 user 取得、`gh auth switch` 実行
2. `.claude/settings.example.json` の `hooks.SessionStart` に登録（opt-in）
3. 環境変数 `PLANGATE_GH_USER` でデフォルト `s977043` を override 可能（他 user で plangate fork した場合等）
4. 失敗時は exit 1〜2 で診断可能、session 継続性を妨げない

## 変更ファイル

| ファイル | 種別 |
|---------|------|
| `scripts/gh-pin-account.sh` | 新規 |
| `.claude/settings.example.json` | 編集（SessionStart hook 追加）|
| `docs/working/TASK-0052/*` | 新規 |

## Mode判定

light（環境改善、CI 影響なし、既存挙動への副作用ゼロ）

## Risks & Mitigations

| Risk | Mitigation |
|------|----------|
| `gh api user` が一時的に失敗 | fallback で `gh auth status` 解析、それでも取れなければ強制 switch |
| 別 user で fork したい開発者が困る | `PLANGATE_GH_USER` 環境変数で override 可能 |
| SessionStart hook が誤動作で session 阻害 | hook の exit code は Claude Code 側で warning 扱い（block しない）、shim も exit 1 程度で session 継続 |

## 確認方法

- `sh scripts/gh-pin-account.sh` を 2 回実行 → 1 回目「switched」or「already」、2 回目「already pinned」
- `PLANGATE_GH_USER=nonexistent sh scripts/gh-pin-account.sh` → exit 1, "not in gh auth status"
- `.claude/settings.example.json` に SessionStart hook が含まれている
