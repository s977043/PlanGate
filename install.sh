#!/bin/sh
# install.sh — PlanGate を Claude Code / Codex にインストール
#
# Usage:
#   sh install.sh                 # 自動検出してインストール
#   sh install.sh --claude        # Claude Code のみ
#   sh install.sh --codex         # Codex のみ
#   sh install.sh --target DIR    # インストール先を指定（Claude Code 用）
#   sh install.sh --dry-run       # 変更内容を確認（実行しない）

set -eu

REPO_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
PLUGIN_DIR="$REPO_ROOT/plugin/plangate"
DRY_RUN=0
MODE="auto"  # auto / claude / codex
TARGET_DIR=""

_log()  { printf '\033[1;32m[install]\033[0m %s\n' "$1"; }
_warn() { printf '\033[1;33m[install]\033[0m %s\n' "$1"; }
_dry()  { printf '\033[1;36m[dry-run]\033[0m %s\n' "$1"; }

while [ $# -gt 0 ]; do
  case "$1" in
    --claude)   MODE="claude"; shift ;;
    --codex)    MODE="codex"; shift ;;
    --target)   TARGET_DIR="$2"; shift 2 ;;
    --dry-run)  DRY_RUN=1; shift ;;
    --help|-h)
      printf 'Usage: sh install.sh [--claude|--codex] [--target DIR] [--dry-run]\n'
      exit 0 ;;
    *) printf 'Unknown option: %s\n' "$1" >&2; exit 1 ;;
  esac
done

# ===== Claude Code インストール =====
install_claude() {
  # インストール先を決定
  if [ -n "$TARGET_DIR" ]; then
    DEST="$TARGET_DIR"
  elif [ -d "$(pwd)/.claude" ]; then
    DEST="$(pwd)/.claude"
  else
    DEST="$(pwd)/.claude"
    _warn ".claude/ が見つかりません。作成します: $DEST"
  fi

  _log "Claude Code: $PLUGIN_DIR → $DEST"

  for dir in agents skills commands rules; do
    src="$PLUGIN_DIR/$dir"
    dst="$DEST/$dir"
    [ -d "$src" ] || continue
    if [ "$DRY_RUN" = "1" ]; then
      _dry "WOULD COPY: $dir/ → $dst/"
    else
      mkdir -p "$dst"
      cp -r "$src/." "$dst/"
      _log "COPIED: $dir/ ($(ls "$src" | wc -l | tr -d ' ') items)"
    fi
  done

  _log "Claude Code インストール完了"
  _log "確認: Claude Code セッションで /setup-team を実行してください"
}

# ===== Codex インストール =====
install_codex() {
  CODEX_DIR="${TARGET_DIR:-$(pwd)/.codex/skills}"
  _log "Codex: skills → $CODEX_DIR"

  if [ "$DRY_RUN" = "1" ]; then
    _dry "WOULD RUN: sh $PLUGIN_DIR/scripts/install-plangate-skills.sh --target $CODEX_DIR"
  else
    sh "$PLUGIN_DIR/scripts/install-plangate-skills.sh" --target "$CODEX_DIR"
    _log "Codex インストール完了"
  fi
}

# ===== 自動検出 =====
case "$MODE" in
  auto)
    _log "インストール先を自動検出します..."
    HAS_CLAUDE=0
    HAS_CODEX=0
    [ -d "$(pwd)/.claude" ] && HAS_CLAUDE=1
    [ -d "$(pwd)/.codex" ]  && HAS_CODEX=1

    if [ "$HAS_CLAUDE" = "0" ] && [ "$HAS_CODEX" = "0" ]; then
      _warn "Claude Code / Codex のディレクトリが見つかりません"
      _warn "--claude または --codex を指定して実行してください"
      printf '\n  sh install.sh --claude   # Claude Code にインストール\n'
      printf '  sh install.sh --codex    # Codex にインストール\n\n'
      exit 1
    fi

    [ "$HAS_CLAUDE" = "1" ] && install_claude
    [ "$HAS_CODEX"  = "1" ] && install_codex
    ;;
  claude) install_claude ;;
  codex)  install_codex ;;
esac
