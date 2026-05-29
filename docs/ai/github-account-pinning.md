# GitHub アカウント pinning（gh active account 固定）

> TASK-0120 (Session Retro Try #2) / Issue #171 系列。
> 本セッションで多発した「gh active account の想定外切替による権限エラー」を
> 構造的に防ぐためのツール運用ガイド。

## 背景

plangate での作業中、gh CLI の active account が想定外に別アカウントへ
切り戻り、共有 mutation（`gh pr create` / `gh pr merge` / GraphQL の
`resolveReviewThread` 等）が `must be a collaborator` / `403 FORBIDDEN` で
失敗する現象が頻発した。都度 `gh auth switch --user s977043` で復旧していたが
属人的・忘れやすい。

## 責務整理

2 つの仕組みを **補完関係** として併用する。重複（二重 pinning）は冪等性で回避。

| 仕組み | 発火タイミング | 責務 | 配置 |
|--------|--------------|------|------|
| `scripts/gh-pin-account.sh` (TASK-0052) | **SessionStart hook** | session 開始時に 1 回 active account を pin | `.claude/settings.example.json` の SessionStart に opt-in 登録 |
| `scripts/gh-s977043.sh` (TASK-0120) | **各 gh 操作の直前** | gh コマンド実行の都度 switch を強制し、session 中の drift に対応 | ラッパとして明示的に呼ぶ |

- **SessionStart hook は session 開始時のみ**発火するため、session 中に account が
  切り戻る drift には対応できない。本ラッパがその穴を埋める。
- 両者とも「既に desired account なら switch を skip」する**冪等**実装のため、
  併用しても二重 switch のオーバーヘッドや競合は発生しない。

## 運用

### 基本

共有 mutation を伴う gh 操作はラッパ経由で実行する:

```sh
sh scripts/gh-s977043.sh pr create --base main --head <branch> --title "..." --body "..."
sh scripts/gh-s977043.sh pr merge 123 --squash
sh scripts/gh-s977043.sh api graphql -f query='...'
```

### user の上書き

既定は `s977043`。別アカウントに固定したい場合:

```sh
PLANGATE_GH_USER=other-user sh scripts/gh-s977043.sh <gh args>
```

### エッジケース時の挙動

| 状況 | 挙動 |
|------|------|
| 既に s977043 active | switch を skip（冪等） |
| s977043 が `gh auth` 未登録 / 権限不足環境 | WARNING を出して**続行**（gh 本体の結果に委ねる） |
| gh CLI 未 install | エラー終了（exit 127） |

## 関連

- `scripts/gh-pin-account.sh`（TASK-0052 / SessionStart hook）
- sockpuppet 禁止ルール（既存規定。本ツールは運用補助であり承認境界は変更しない）
