#!/usr/bin/env bash
# scripts/install-pre-commit.sh — TASK-0113 / #355
# scripts/templates/pre-commit.sample を .git/hooks/pre-commit に opt-in install
# (TASK-0114 install-pre-push.sh と並列構造、Gemini R-006: 冪等性)

set -eu
REPO_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
TEMPLATE="$REPO_ROOT/scripts/templates/pre-commit.sample"
TARGET="$REPO_ROOT/.git/hooks/pre-commit"

DRY_RUN=0
if [ "${1:-}" = "--dry-run" ]; then
  DRY_RUN=1
fi

[ -f "$TEMPLATE" ] || { echo "ERROR: template not found: $TEMPLATE" >&2; exit 1; }
[ -d "$REPO_ROOT/.git" ] || { echo "ERROR: not a git repository: $REPO_ROOT" >&2; exit 1; }

mkdir -p "$REPO_ROOT/.git/hooks"

if [ -f "$TARGET" ]; then
  if cmp -s "$TEMPLATE" "$TARGET"; then
    echo "[install-pre-commit] 既存 hook は template と同一内容、何もしません (idempotent)"
    exit 0
  fi
  BACKUP="$TARGET.bak"
  [ -f "$BACKUP" ] && BACKUP="$TARGET.bak.$(date +%s)"
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[install-pre-commit] DRY-RUN: 既存 hook を $BACKUP に退避予定"
    echo "[install-pre-commit] DRY-RUN: $TEMPLATE → $TARGET 配置予定"
    exit 0
  fi
  cp "$TARGET" "$BACKUP"
  echo "[install-pre-commit] 既存 hook を退避: $BACKUP"
fi

if [ "$DRY_RUN" -eq 1 ]; then
  echo "[install-pre-commit] DRY-RUN: $TEMPLATE → $TARGET 配置予定"
  exit 0
fi

cp "$TEMPLATE" "$TARGET"
chmod +x "$TARGET"
echo "[install-pre-commit] 配置完了: $TARGET"
echo ""
echo "  検知対象: AGENTS.md (既定)、.plangate-pollution-patterns.yaml で拡張可"
echo "  auto-revert: PLANGATE_POLLUTION_AUTO_REVERT=1 git commit"
echo "  bypass (緊急): git commit --no-verify"
echo "  詳細: docs/ai/ai-memory-pollution-guard.md"
