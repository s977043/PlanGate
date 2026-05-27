#!/usr/bin/env bash
# scripts/install-pre-push.sh — TASK-0114 / INC-2026-05-26-001 P-1
#
# scripts/templates/pre-push.sample を .git/hooks/pre-push に opt-in install。
# 既存 hook がある場合は .bak に退避 (Gemini bot R-006: 同一内容なら .bak skip)。
#
# 使用例:
#   sh scripts/install-pre-push.sh         # 通常 install
#   sh scripts/install-pre-push.sh --dry-run  # 適用前確認

set -eu

REPO_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
TEMPLATE="$REPO_ROOT/scripts/templates/pre-push.sample"
TARGET="$REPO_ROOT/.git/hooks/pre-push"

DRY_RUN=0
if [ "${1:-}" = "--dry-run" ]; then
  DRY_RUN=1
fi

# Pre-check
if [ ! -f "$TEMPLATE" ]; then
  echo "ERROR: template not found: $TEMPLATE" >&2
  exit 1
fi

if [ ! -d "$REPO_ROOT/.git" ]; then
  echo "ERROR: not a git repository: $REPO_ROOT" >&2
  exit 1
fi

mkdir -p "$REPO_ROOT/.git/hooks"

# Idempotent check (Gemini bot R-006)
if [ -f "$TARGET" ]; then
  if cmp -s "$TEMPLATE" "$TARGET"; then
    echo "[install-pre-push] 既存 hook は template と同一内容、何もしません (idempotent)"
    exit 0
  fi
  # 既存 hook を .bak 退避
  BACKUP="$TARGET.bak"
  # 既に .bak がある場合 rotate (BAK 上書き防止)
  if [ -f "$BACKUP" ]; then
    BACKUP="$TARGET.bak.$(date +%s)"
  fi
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[install-pre-push] DRY-RUN: 既存 hook を $BACKUP に退避予定"
    echo "[install-pre-push] DRY-RUN: $TEMPLATE → $TARGET 配置予定"
    exit 0
  fi
  cp "$TARGET" "$BACKUP"
  echo "[install-pre-push] 既存 hook を退避: $BACKUP"
fi

if [ "$DRY_RUN" -eq 1 ]; then
  echo "[install-pre-push] DRY-RUN: $TEMPLATE → $TARGET 配置予定"
  exit 0
fi

# install
cp "$TEMPLATE" "$TARGET"
chmod +x "$TARGET"
echo "[install-pre-push] 配置完了: $TARGET"
echo ""
echo "  protected branch (既定): main master release/*"
echo "  override: PLANGATE_PROTECTED_BRANCHES=\"<custom>\" git push"
echo "  bypass (緊急): git push --no-verify"
echo ""
echo "  詳細: docs/ai/direct-push-prevention.md"
