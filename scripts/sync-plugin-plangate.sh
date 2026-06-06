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

# スキルはサブディレクトリ構造を持つため再帰コピーで同期する
# 各スキルの SKILL.md を plugin/plangate/skills/<name>/SKILL.md にコピー
_plugin_skills="$PLUGIN_DIR/skills"
mkdir -p "$_plugin_skills"
for _skill_dir in "$SKILLS_DIR"/*/; do
  [ -d "$_skill_dir" ] || continue
  _skill_name="$(basename "$_skill_dir")"
  _src_md="$_skill_dir/SKILL.md"
  [ -f "$_src_md" ] || continue
  _dst_dir="$_plugin_skills/$_skill_name"
  _dst_md="$_dst_dir/SKILL.md"
  mkdir -p "$_dst_dir"
  if [ ! -f "$_dst_md" ] || ! cmp -s "$_src_md" "$_dst_md"; then
    if [ "$DRY_RUN" = "1" ]; then _drylog "WOULD COPY: skills/$_skill_name/SKILL.md"
    else cp "$_src_md" "$_dst_md"; _log "COPY: skills/$_skill_name/SKILL.md"; fi
    changed=1
  fi
done

# バージョン番号を CHANGELOG から取得（README.md / plugin.json 共用）
_ver=""
if [ -f "$REPO_ROOT/CHANGELOG.md" ]; then
  _ver=$(grep '^## v[0-9]' "$REPO_ROOT/CHANGELOG.md" | head -1 | sed 's/## \(v[^ ]*\).*/\1/')
fi
# semver 形式を検証（CHANGELOG フォーマット変更時の誤 version 注入を防ぐ）。
# 非 semver なら _ver を空にし、後続の version 書き込みを全てスキップする。
if [ -n "$_ver" ]; then
  # X.Y.Z（任意で -prerelease）を厳格検証。case の glob は緩く 8.11.0.1 等を
  # 通してしまうため grep -E の正規表現で判定する。
  if ! printf '%s' "${_ver#v}" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$'; then
    _log "WARN: CHANGELOG の version '$_ver' が semver 形式でないため version 同期をスキップ"
    _ver=""
  fi
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
  _pcur=$(python3 - "$PLUGIN_JSON" << 'PYJSON' 2>/dev/null || true
import json, sys
try:
    with open(sys.argv[1], encoding='utf-8') as f:
        print(json.load(f).get('version', ''))
except Exception:
    print('')
PYJSON
)
  _ver_noprefix="${_ver#v}"
  if [ "$_pcur" != "$_ver_noprefix" ]; then
    if [ "$DRY_RUN" = "1" ]; then _drylog "WOULD UPDATE plugin.json version: $_pcur -> $_ver_noprefix"
    else
      python3 - "$PLUGIN_JSON" "$_ver" << 'PYEOF'
import json, sys
path, ver = sys.argv[1], sys.argv[2]
with open(path, encoding='utf-8') as f:
    d = json.load(f)
d['version'] = ver.lstrip('v')
with open(path, 'w', encoding='utf-8') as f:
    json.dump(d, f, indent=2, ensure_ascii=False)
    f.write('\n')
PYEOF
      _log "UPDATE plugin.json version: $_pcur -> $_ver_noprefix"
    fi
    changed=1
  fi
fi

# marketplace.json の plugins[].version を更新（plugin.json と同期 / #456）
MARKETPLACE_JSON="$REPO_ROOT/.claude-plugin/marketplace.json"
if [ -n "$_ver" ] && [ -f "$MARKETPLACE_JSON" ] && command -v python3 >/dev/null 2>&1; then
  _ver_noprefix="${_ver#v}"
  _mp_changed=$(python3 - "$MARKETPLACE_JSON" "$_ver_noprefix" "$DRY_RUN" << 'PYJSON'
import json, sys
path, ver, dry = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    with open(path, encoding='utf-8') as f:
        d = json.load(f)
except Exception as e:
    sys.stderr.write('marketplace.json read/parse error: %s\n' % e)
    sys.exit(1)
target = [p for p in d.get('plugins', []) if p.get('name') == 'plangate']
if not target:
    sys.stderr.write('marketplace.json に plangate plugin 定義がありません\n')
    sys.exit(1)
changed = []
for plug in target:
    if plug.get('version') != ver:
        changed.append('%s -> %s' % (plug.get('version'), ver))
        if dry != '1':
            plug['version'] = ver
# marketplace 自体の metadata.version も同期（plugins[].version との二重管理防止）
md = d.get('metadata')
if isinstance(md, dict) and md.get('version') not in (None, ver):
    changed.append('metadata %s -> %s' % (md.get('version'), ver))
    if dry != '1':
        md['version'] = ver
if changed and dry != '1':
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(d, f, indent=2, ensure_ascii=False)
        f.write('\n')
print(';'.join(changed))
PYJSON
) || { _log "ERROR: marketplace.json 同期に失敗（parse 失敗 / plangate 未定義）"; exit 1; }
  if [ -n "$_mp_changed" ]; then
    if [ "$DRY_RUN" = "1" ]; then _drylog "WOULD UPDATE marketplace.json version: $_mp_changed"
    else _log "UPDATE marketplace.json version: $_mp_changed"; fi
    changed=1
  fi
fi

if [ "$changed" = "1" ]; then
  _log "Sync complete — changes detected"
else
  _log "Sync complete — no changes"
fi
