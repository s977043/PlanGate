#!/bin/sh
# sync-plugin-plangate.sh — .claude/ を plugin/plangate/ に同期
# TASK-0124: push to main で CI が呼び出し、差分あり時に PR を自動作成
# ローカル実行: sh scripts/sync-plugin-plangate.sh [--dry-run]

set -eu

REPO_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
DRY_RUN=0
if [ "${1:-}" = "--dry-run" ]; then
  DRY_RUN=1
fi

_log()    { printf '[sync-plugin] %s\n' "$1"; }
_drylog() { printf '[sync-plugin][dry-run] %s\n' "$1"; }

PLUGIN_DIR="$REPO_ROOT/plugin/plangate"
CLAUDE_DIR="$REPO_ROOT/.claude"
SKILLS_DIR="$REPO_ROOT/.agents/skills"

changed=0

sync_dir() {
  _src="$1"; _dst="$2"; _label="$3"
  [ -d "$_src" ] || { _log "SKIP (src not found): $_label"; return 0; }
  mkdir -p "$_dst"
  for _f in "$_src"/*.md "$_src"/*.yaml "$_src"/*.yml "$_src"/*.json; do
    [ -f "$_f" ] || continue
    _base="$(basename "$_f")"
    _dfile="$_dst/$_base"
    if [ ! -f "$_dfile" ] || ! cmp -s "$_f" "$_dfile"; then
      if [ "$DRY_RUN" = "1" ]; then _drylog "WOULD COPY: $_label/$_base"
      else cp "$_f" "$_dfile"; _log "COPY: $_label/$_base"; fi
      changed=1
    fi
  done
  for _f in "$_dst"/*.md "$_dst"/*.yaml "$_dst"/*.yml "$_dst"/*.json; do
    [ -f "$_f" ] || continue
    _base="$(basename "$_f")"
    [ "$_base" = "README.md" ] && continue
    if [ ! -f "$_src/$_base" ]; then
      if [ "$DRY_RUN" = "1" ]; then _drylog "WOULD DELETE: $_label/$_base"
      else rm "$_f"; _log "DELETE: $_label/$_base"; fi
      changed=1
    fi
  done
}

for _dir in agents rules commands; do
  sync_dir "$CLAUDE_DIR/$_dir" "$PLUGIN_DIR/$_dir" "$_dir"
done
sync_dir "$SKILLS_DIR" "$PLUGIN_DIR/skills" "skills"

# バージョン番号を CHANGELOG から取得（README.md / plugin.json 共用）
_ver=""
if [ -f "$REPO_ROOT/CHANGELOG.md" ]; then
  _ver=$(grep '^## v[0-9]' "$REPO_ROOT/CHANGELOG.md" | head -1 | sed 's/## \(v[^ ]*\).*/\1/')
fi

# README.md の Version 行を更新
PLUGIN_README="$PLUGIN_DIR/README.md"
if [ -n "$_ver" ] && [ -f "$PLUGIN_README" ]; then
  _cur=$(grep '^\- \*\*Version\*\*:' "$PLUGIN_README" | sed 's/.*: //' || true)
  if [ "$_cur" != "$_ver" ]; then
    if [ "$DRY_RUN" = "1" ]; then _drylog "WOULD UPDATE README version: $_cur -> $_ver"
    else
      _tmp=$(mktemp)
      sed "s/^\(- \*\*Version\*\*:\).*/\1 $_ver/" "$PLUGIN_README" > "$_tmp" && mv "$_tmp" "$PLUGIN_README"
      _log "UPDATE README version: $_cur -> $_ver"
    fi
    changed=1
  fi
fi

# plugin.json の version フィールドを更新
PLUGIN_JSON="$PLUGIN_DIR/.claude-plugin/plugin.json"
if [ -n "$_ver" ] && [ -f "$PLUGIN_JSON" ] && command -v python3 >/dev/null 2>&1; then
  _pcur=$(python3 -c "import json; d=json.load(open('$PLUGIN_JSON')); print(d.get('version',''))" 2>/dev/null || true)
  if [ "$_pcur" != "$_ver" ]; then
    if [ "$DRY_RUN" = "1" ]; then _drylog "WOULD UPDATE plugin.json version: $_pcur -> $_ver"
    else
      python3 - "$PLUGIN_JSON" "$_ver" << 'PYEOF'
import json, sys
path, ver = sys.argv[1], sys.argv[2]
with open(path) as f:
    d = json.load(f)
d['version'] = ver
with open(path, 'w') as f:
    json.dump(d, f, indent=2, ensure_ascii=False)
    f.write('\n')
PYEOF
      _log "UPDATE plugin.json version: $_pcur -> $_ver"
    fi
    changed=1
  fi
fi

if [ "$changed" = "1" ]; then
  _log "Sync complete — changes detected"
else
  _log "Sync complete — no changes"
fi
