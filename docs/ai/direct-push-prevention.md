# Direct Push Prevention (#360 / TASK-0114)

> INC-2026-05-26-001 Prevention P-1 実装。
> Human-owned merge boundary を物理的に強化する pre-push hook。

## 目的

`main` / `master` / `release/*` への **直接 push を物理 block** し、PR 経由マージを強制する。

## 背景 (INC-2026-05-26-001)

AI (Claude Code) が `git checkout` 失敗の見落としで main 上で `git commit --allow-empty` + `git push` を実行 → empty commit 49448c5 が PR 経由せず直接 main に push される事故が発生。

機能的影響は皆無 (empty commit) だったが、ガバナンス上の規範違反として記録・対策実施。本 hook はその構造的解消手段。

## install (opt-in)

```sh
# 通常 install
sh scripts/install-pre-push.sh

# 適用前確認
sh scripts/install-pre-push.sh --dry-run
```

### install 内容

- `scripts/templates/pre-push.sample` → `.git/hooks/pre-push` にコピー
- 既存 hook は `.bak` に退避 (同一内容なら skip = idempotent / R-006)
- 既存 `.bak` がある場合は timestamp 付き別名で保護

## 設定

| 環境変数 | 既定値 | 説明 |
|---------|--------|------|
| `PLANGATE_PROTECTED_BRANCHES` | `main master release/*` | space-separated glob list (case 右辺 unquoted で評価) |

### override 例

```sh
# release/* も release も protected にする
PLANGATE_PROTECTED_BRANCHES="main release release/* prod" git push

# プロトタイプ用に main のみ protected
PLANGATE_PROTECTED_BRANCHES="main" git push
```

## bypass (緊急時、非推奨)

```sh
git push --no-verify
```

`--no-verify` は git client 標準の hook skip 機構。本 hook も含む全 git hook を一律 skip するため、**監査ログに残らない**。緊急時のみ使用。

### Defense in Depth (Gemini bot 指摘反映)

| 防衛線 | 機構 | 説明 |
|--------|------|------|
| **第一防衛線** | 本 hook (local pre-push) | 手元での誤操作防止、`--no-verify` で bypass 可 |
| **最後の防衛線** | GitHub branch protection (P-2、INC P-2) | repo-wide enforcement、bypass 不可 |

両者組合せで **物理 + 規範の二段防御**。本 hook は最後の砦ではない (P-2 が砦)。

## protected 判定仕様

stdin format (git pre-push spec):

```text
<local ref> <local sha> <remote ref> <remote sha>
```

判定:

1. `remote_ref` から `refs/heads/` prefix を除去 → `remote_branch`
2. `local_sha = 0...` (branch 削除) は許可
3. `PLANGATE_PROTECTED_BRANCHES` の各 pattern と `case` で glob 評価
4. マッチで exit 1 (block) + 対処メッセージ
5. マッチなしで exit 0 (push 続行)

### glob 評価詳細

- `release/*` は **remote branch 名ベース** (例: `release/v1.0` にマッチ)
- `case $remote_branch in $pattern)` で **右辺 unquoted** にして glob 評価
- script 冒頭で `set -f` (noglob) 適用、`for pattern in $PROTECTED` 展開時のファイルシステム glob 暴発を防止 (Gemini bot R-001)

## uninstall

```sh
rm .git/hooks/pre-push
# または .bak から復元
mv .git/hooks/pre-push.bak .git/hooks/pre-push
```

## トラブルシューティング

### Q: hook が走らない

- `ls -l .git/hooks/pre-push` で 実行 bit 確認
- install 後 `cat .git/hooks/pre-push | head -3` で内容確認
- husky 等別の hook manager と競合の可能性

### Q: feature branch push もブロックされる

- `PLANGATE_PROTECTED_BRANCHES` の値確認
- 既定: `main master release/*` のみ。それ以外は通過

### Q: release/* glob が効かない (個別 release ブランチがブロックされない)

- `set -f` 適用済か確認 (hook 冒頭)
- 環境変数 override 時に `release/*` を quote しているか (`PLANGATE_PROTECTED_BRANCHES="release/*"` で `set -f` 効かないと shell が ローカル展開する)

## 関連

- Issue: PR #360 (TASK-0114 plan)
- INC: [INC-2026-05-26-001](../working/incidents/2026-05-26-empty-commit-direct-push.md) Prevention P-1
- TASK-0113 (claude-mem 検知 pre-commit hook): 並列構造 (本 PBI は pre-push 階層)
- TASK-0115 (Bash 連結コマンド error guard): 同 INC P-3 (AI 行動規範)
