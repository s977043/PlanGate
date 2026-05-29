# git-add-scope-guard 運用ガイド

> TASK-0119 / scripts/check-git-add-scope.sh

## 概要

`git add -A` の多用による scope 外ファイルの誤混入を pre-commit 層で機械検知するスクリプトです。

検知しても `git add -A` は禁止しません。コミット前に警告して自分で判断できるようにします。

---

## 検知対象

| # | 検知内容 | 理由 |
|---|---------|------|
| 1 | `docs/working/_audit/skip-decision-log.jsonl` に `acknowledged_by:null` エントリがある状態で staged | 未追認のまま commit すると監査が壊れる |
| 2 | staged ファイルに `<claude-mem-context>` を含む | claude-mem 自動挿入の誤混入 (TASK-0113 補完) |
| 3 | `PLANGATE_HOOK_TASK` と異なる TASK-XXXX の `eval-result.*` が staged | 他タスクの評価結果の誤混入 |

### TASK-0113 との責務分界

- `<claude-mem-context>` 検知: **TASK-0113** (`scripts/hooks/check-ai-memory-pollution.sh`) が主担当
- 本スクリプトは TASK-0113 **未インストール時の補完**として機能します
- TASK-0113 がインストール済みの場合、`<claude-mem-context>` は二重警告になりますが動作上の問題はありません

---

## install

```sh
# pre-commit hook に統合 (scripts/install-pre-commit.sh 経由)
sh scripts/install-pre-commit.sh

# または手動で .git/hooks/pre-commit に追記
echo 'sh "$REPO_ROOT/scripts/check-git-add-scope.sh"' >> .git/hooks/pre-commit
```

### pre-commit.sample との統合

`scripts/templates/pre-commit.sample` を参照してください。

---

## 使用方法

通常は git commit 時に自動で動作します。

```sh
# 通常の commit (フック自動発動)
git commit -m "message"

# 現在の TASK を指定して正確な eval-result チェックを行う
PLANGATE_HOOK_TASK=TASK-0119 git commit -m "message"
```

---

## allowlist (スキップ方法)

### 全スキップ (緊急時)

```sh
PLANGATE_SKIP_SCOPE_CHECK=1 git commit -m "message"
```

> **注意**: 全スキップは緊急時のみ使用してください。通常は個別の対処を推奨します。

### skip-decision-log 未追認の解消

```sh
bin/plangate skip-acknowledge
```

### 対象ファイルを unstage

```sh
# 特定ファイルを unstage
git restore --staged docs/working/_audit/skip-decision-log.jsonl

# 確認
git diff --cached --name-only
```

---

## bypass

```sh
# git commit --no-verify で全フックをバイパス (緊急時のみ)
git commit --no-verify -m "message"
```

---

## Defense in Depth

本スクリプトは以下の多層防御の一部です。

| 層 | 機構 | 対応 |
|----|------|------|
| 規範層 | AI 行動規範 (TASK-0115) | Bash 連結エラーガード |
| 技術層 (pre-commit) | 本スクリプト (TASK-0119) | scope 外混入検知 |
| 技術層 (pre-commit) | TASK-0113 hook | claude-mem 自動挿入検知 |
| 技術層 (pre-push) | TASK-0114 hook | main 直接 push ブロック |

---

## トラブルシューティング

### `acknowledged_by:null` 警告が出る場合

`docs/working/_audit/skip-decision-log.jsonl` に未追認エントリが残っています。

```sh
# 追認コマンド
bin/plangate skip-acknowledge

# または手動で acknowledged_by / acknowledged_at を設定してから commit
```

### eval-result scope 警告が出る場合

`PLANGATE_HOOK_TASK` が設定されていないか、異なるタスクの eval-result が staged されています。

```sh
# 他タスクの eval-result を unstage
git restore --staged docs/working/TASK-XXXX/eval-result.json

# または PLANGATE_HOOK_TASK を正しく設定
PLANGATE_HOOK_TASK=TASK-0119 git commit -m "message"
```

---

## 関連ドキュメント

- [TASK-0113: ai-memory-pollution-guard](ai-memory-pollution-guard.md)
- [TASK-0114: pre-push guard](../working/TASK-0114/handoff.md)
- [TASK-0115: Bash 連結エラーガード](../../.claude/rules/responsibility-classes.md)
- [skip-decision-log 運用](../working/_audit/)
