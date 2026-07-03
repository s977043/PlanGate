#!/usr/bin/env bash
# scripts/repo-guard/install-repo-guard.sh — repo guard を core.hooksPath 方式で配線
#
# 出典: issue #684。scripts/repo-guard/pre-push を `.git/hooks` を直接汚さず
# `core.hooksPath` 経由で配線する apply スクリプト。AI が作成し、実行判断・
# 実行は Human が行う（.claude/rules/responsibility-classes.md の
# AI-owned/Human-owned 分界に整合。settings.json 系ではないため self-mod
# ガード対象ではないが、本スクリプトも「作成は AI・適用実行は Human」を
# 既定運用とする — apply-*.sh 群の慣行踏襲）。
#
# 既定は --dry-run（差分プレビューのみ）。実適用は --apply を明示指定する。
#
# 使用例:
#   sh scripts/repo-guard/install-repo-guard.sh              # 既定 = dry-run
#   sh scripts/repo-guard/install-repo-guard.sh --dry-run     # 明示 dry-run
#   sh scripts/repo-guard/install-repo-guard.sh --apply       # 実適用
#
# 冪等性: 既に core.hooksPath が scripts/repo-guard を指しており、
#   pre-push が配置済みなら「変更なし」として skip する。
#
# 設定支援: --apply 実行時、.repo-guard.conf が無ければサンプルを提示する
#   （自動生成はしない。期待アカウント等はユーザーが明示的に宣言する）。

set -eu

REPO_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
HOOKS_DIR="$REPO_ROOT/scripts/repo-guard"
PRE_PUSH="$HOOKS_DIR/pre-push"
CONF_FILE="$REPO_ROOT/.repo-guard.conf"

MODE="dry-run"
case "${1:-}" in
  --apply) MODE="apply" ;;
  --dry-run|"") MODE="dry-run" ;;
  *)
    echo "Usage: $0 [--dry-run|--apply]" >&2
    exit 2
    ;;
esac

if [ ! -d "$REPO_ROOT/.git" ] && [ ! -f "$REPO_ROOT/.git" ]; then
  echo "ERROR: not a git repository: $REPO_ROOT" >&2
  exit 1
fi

if [ ! -f "$PRE_PUSH" ]; then
  echo "ERROR: template not found: $PRE_PUSH" >&2
  exit 1
fi

if [ ! -x "$PRE_PUSH" ]; then
  echo "[install-repo-guard] pre-push に実行権限がありません（+x 必要）" >&2
fi

current_hooks_path="$(git -C "$REPO_ROOT" config --local --get core.hooksPath 2>/dev/null || true)"
target_hooks_path="scripts/repo-guard"

echo "[install-repo-guard] mode: $MODE"
echo "[install-repo-guard] repo: $REPO_ROOT"
echo "[install-repo-guard] current core.hooksPath: ${current_hooks_path:-'(未設定)'}"
echo "[install-repo-guard] target  core.hooksPath: $target_hooks_path"

if [ "$current_hooks_path" = "$target_hooks_path" ]; then
  echo "[install-repo-guard] 既に core.hooksPath=$target_hooks_path が設定済み（冪等・変更なし）"
else
  if [ "$MODE" = "dry-run" ]; then
    echo "[install-repo-guard] DRY-RUN: git config --local core.hooksPath $target_hooks_path を実行予定"
    if [ -n "$current_hooks_path" ] && [ "$current_hooks_path" != "$target_hooks_path" ]; then
      echo "[install-repo-guard] 警告: 既存 core.hooksPath='$current_hooks_path' を上書きします。"
      echo "  既存の .git/hooks 直接配置（例: scripts/install-pre-push.sh 経由の"
      echo "  .git/hooks/pre-push）は core.hooksPath 変更後は git から参照されなくなります。"
    fi
  else
    if [ -n "$current_hooks_path" ] && [ "$current_hooks_path" != "$target_hooks_path" ]; then
      echo "[install-repo-guard] 警告: 既存 core.hooksPath='$current_hooks_path' を上書きします。"
    fi
    git -C "$REPO_ROOT" config --local core.hooksPath "$target_hooks_path"
    echo "[install-repo-guard] core.hooksPath=$target_hooks_path を設定しました"
  fi
fi

if [ ! -f "$CONF_FILE" ]; then
  echo ""
  echo "[install-repo-guard] .repo-guard.conf が未設定です。期待アカウント検証を"
  echo "  有効化する場合は、リポジトリルートに以下のようなファイルを作成してください"
  echo "  （本スクリプトは自動生成しません — 期待値の宣言は人間が行う）:"
  echo ""
  echo "    # .repo-guard.conf"
  echo "    REPO_GUARD_PROTECTED_BRANCHES=\"main master release/*\""
  echo "    REPO_GUARD_EXPECTED_GH_LOGIN=\"<your-gh-login>\""
  echo "    REPO_GUARD_GH_MISMATCH_MODE=\"block\"  # block | warn"
  echo ""
  echo "  .repo-guard.conf は個人環境依存のため .gitignore への追加を推奨します"
  echo "  （チーム共有したい場合はコミットしても構いません）。"
fi

if [ "$MODE" = "dry-run" ]; then
  echo ""
  echo "[install-repo-guard] DRY-RUN 完了。実適用するには --apply を指定してください。"
  exit 0
fi

echo ""
echo "[install-repo-guard] done: pre-push は $PRE_PUSH 経由で有効化されました"
echo "  検証: git push (dry-run 相当の確認は git push --dry-run) で protected branch block を確認できます"
exit 0
