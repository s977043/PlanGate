#!/bin/sh
# sync-plugin-installed.sh — plugin/plangate/ → インストール済みキャッシュ・shared に同期
#
# リリース後にローカルの ~/.claude/plugins/ キャッシュと
# ~/.codex/skills/ を最新 plugin/plangate/ に揃える Human 向けスクリプト。
# CI は ~/.claude/ / ~/.codex/ にアクセスできないため、ローカル実行専用。
#
# 使い方:
#   sh scripts/sync-plugin-installed.sh [--dry-run]
#
# リリースフロー内での位置付け:
#   release-prep.sh --check → (NG なら) このスクリプトを実行 → --check 再実行 → READY

set -eu

REPO_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
DRY_RUN=0
[ "${1:-}" = "--dry-run" ] && DRY_RUN=1

_log()    { printf '[sync-installed] %s\n' "$*"; }
_drylog() { printf '[sync-installed][dry-run] %s\n' "$*"; }

PLUGIN_SRC="$REPO_ROOT/plugin/plangate"

# plugin.json からバージョンを取得
PLUGIN_VER=""
if command -v python3 >/dev/null 2>&1; then
  PLUGIN_VER=$(python3 - "$PLUGIN_SRC/.claude-plugin/plugin.json" << 'PY' 2>/dev/null || echo ""
import json, sys
try:
    print(json.load(open(sys.argv[1], encoding='utf-8')).get('version', ''))
except Exception:
    print('')
PY
)
fi

if [ -z "$PLUGIN_VER" ]; then
  _log "ERROR: plugin.json からバージョン取得失敗"
  exit 1
fi
_log "plugin version: $PLUGIN_VER"

changed_cc=0
changed_codex=0

# ── Claude Code: cache + shared ──────────────────────────────────────────────

CC_CACHE="${HOME}/.claude/plugins/cache/Growth-Teams-Agent/plangate/$PLUGIN_VER"
CC_SHARED="${HOME}/.claude/plugins/marketplaces/Growth-Teams-Agent/shared/plangate"

_sync_file() {
  # $1=src $2=dst $3=label
  if [ ! -f "$1" ]; then return 0; fi
  if [ ! -f "$2" ] || ! cmp -s "$1" "$2"; then
    if [ "$DRY_RUN" = "1" ]; then
      _drylog "WOULD COPY (CC): $3"
    else
      cp "$1" "$2"
      _log "COPY (CC): $3"
    fi
    changed_cc=1
  fi
}

if [ -d "$CC_CACHE" ] || [ -d "$CC_SHARED" ]; then
  # skills のみ対象（commands/agents/rules は shared にのみ存在）
  for skill_dir in "$PLUGIN_SRC/skills"/*/; do
    [ -d "$skill_dir" ] || continue
    skill_name="$(basename "$skill_dir")"
    src_md="$skill_dir/SKILL.md"
    [ -f "$src_md" ] || continue

    if [ -d "$CC_CACHE/skills/$skill_name" ]; then
      _sync_file "$src_md" "$CC_CACHE/skills/$skill_name/SKILL.md" "cache/skills/$skill_name/SKILL.md"
    fi
    if [ -d "$CC_SHARED/skills/$skill_name" ]; then
      _sync_file "$src_md" "$CC_SHARED/skills/$skill_name/SKILL.md" "shared/skills/$skill_name/SKILL.md"
    fi
  done

  # agents / commands / README を shared に同期
  for file in agents/*.md commands/*.md README.md; do
    src="$PLUGIN_SRC/$file"
    [ -f "$src" ] || continue
    dst="$CC_SHARED/$file"
    dir="$(dirname "$dst")"
    [ -d "$dir" ] && _sync_file "$src" "$dst" "shared/$file"
  done

  if [ "$changed_cc" = "1" ]; then
    _log "Claude Code 同期完了"
  else
    _log "Claude Code: 差分なし"
  fi
else
  _log "Claude Code plugin キャッシュ未検出（スキップ）"
fi

# ── Codex: .codex/skills ─────────────────────────────────────────────────────

CODEX_SKILLS="${HOME}/.codex/skills"
REPO_CODEX_SKILLS="$REPO_ROOT/.codex/skills"

if [ -d "$CODEX_SKILLS" ] && [ -d "$REPO_CODEX_SKILLS" ]; then
  for skill_dir in "$REPO_CODEX_SKILLS"/*/; do
    [ -d "$skill_dir" ] || continue
    skill_name="$(basename "$skill_dir")"
    [ "$skill_name" = ".system" ] && continue
    src_md="$skill_dir/SKILL.md"
    [ -f "$src_md" ] || continue
    dst_dir="$CODEX_SKILLS/$skill_name"
    dst_md="$dst_dir/SKILL.md"
    if [ -d "$dst_dir" ]; then
      if [ ! -f "$dst_md" ] || ! cmp -s "$src_md" "$dst_md"; then
        if [ "$DRY_RUN" = "1" ]; then
          _drylog "WOULD COPY (Codex): skills/$skill_name/SKILL.md"
        else
          cp "$src_md" "$dst_md"
          _log "COPY (Codex): skills/$skill_name/SKILL.md"
        fi
        changed_codex=1
      fi
    fi
  done

  if [ "$changed_codex" = "1" ]; then
    _log "Codex skills 同期完了"
  else
    _log "Codex skills: 差分なし"
  fi
else
  _log "Codex skills ディレクトリ未検出（スキップ）"
fi

# ── サマリ ────────────────────────────────────────────────────────────────────
if [ "$changed_cc" = "0" ] && [ "$changed_codex" = "0" ]; then
  printf '[sync-installed] no-op\n'
else
  printf '[sync-installed] done\n'
fi
