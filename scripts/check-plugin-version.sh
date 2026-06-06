#!/bin/sh
# check-plugin-version.sh — plugin.json の version が最新 release tag と一致するか検証
#
# v8.11.0 で plugin.json version が release tag と乖離する事象（#453）の再発防止。
# リリース後の整合検証に使う（開発中の version 先行を許容する場合は --warn-only）。
#
# Usage: sh scripts/check-plugin-version.sh [--warn-only]
# Exit: 0=一致 or tag無し, 1=不一致（--warn-only 時は常に 0）

set -eu

# REPO_ROOT は通常スクリプト位置から決まるが、テスト用に PLANGATE_REPO_ROOT で
# 上書き可能（shallow clone で tag が無い等のケース検証のため。後方互換）。
REPO_ROOT="${PLANGATE_REPO_ROOT:-$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)}"
WARN_ONLY=0
[ "${1:-}" = "--warn-only" ] && WARN_ONLY=1

PLUGIN_JSON="$REPO_ROOT/plugin/plangate/.claude-plugin/plugin.json"

if [ ! -f "$PLUGIN_JSON" ]; then
  printf '[plugin-version] ERROR: %s が存在しません\n' "$PLUGIN_JSON" >&2
  exit 1
fi
command -v python3 >/dev/null 2>&1 || { printf '[plugin-version] ERROR: python3 required\n' >&2; exit 1; }

PLUGIN_VERSION=$(python3 - "$PLUGIN_JSON" << 'PYEOF'
import json, sys
try:
    with open(sys.argv[1], encoding='utf-8') as f:
        print(json.load(f).get('version', ''))
except Exception:
    print('')
PYEOF
)

LATEST_TAG=$(git -C "$REPO_ROOT" describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || true)

if [ -z "$LATEST_TAG" ]; then
  printf '[plugin-version] WARN: release tag が見つかりません（検証スキップ）\n'
  exit 0
fi

# marketplace.json の plugins[name==plangate].version も検証（#456）
# 存在する以上は version を厳格に取得（parse 失敗・plangate 未定義・version 空は
# サイレントスキップせずエラー扱い）
MARKETPLACE_JSON="$REPO_ROOT/.claude-plugin/marketplace.json"
MARKETPLACE_VERSION=""
MARKETPLACE_ERR=""
if [ -f "$MARKETPLACE_JSON" ]; then
  MARKETPLACE_VERSION=$(python3 - "$MARKETPLACE_JSON" << 'PYMP'
import json, sys
try:
    with open(sys.argv[1], encoding='utf-8') as f:
        d = json.load(f)
except Exception as e:
    sys.stderr.write('parse-error: %s\n' % e)
    sys.exit(1)
if not isinstance(d, dict):
    sys.stderr.write('parse-error: root element is not a dictionary\n')
    sys.exit(1)
pv = None
for plug in d.get('plugins', []):
    if plug.get('name') == 'plangate':
        pv = plug.get('version', '')
        break
if not pv:
    sys.stderr.write('plangate plugin version が空 or 未定義\n')
    sys.exit(1)
# metadata.version も検証（plugins[].version との二重管理 drift 防止 / #481）
md = d.get('metadata', {})
mdv = md.get('version') if isinstance(md, dict) else None
if mdv is not None and mdv != pv:
    sys.stderr.write('metadata.version (%s) != plugins[].version (%s)\n' % (mdv, pv))
    sys.exit(1)
print(pv)
sys.exit(0)
PYMP
) || MARKETPLACE_ERR=1
fi

_mismatch=0
if [ "$PLUGIN_VERSION" != "$LATEST_TAG" ]; then
  printf '[plugin-version] ERROR: plugin.json version mismatch — plugin.json=%s / latest tag=v%s\n' "$PLUGIN_VERSION" "$LATEST_TAG" >&2
  _mismatch=1
fi
if [ -n "$MARKETPLACE_ERR" ]; then
  printf '[plugin-version] ERROR: marketplace.json から plangate version を取得できません（存在するのに parse 失敗 / plangate 未定義 / version 空）\n' >&2
  _mismatch=1
elif [ -n "$MARKETPLACE_VERSION" ] && [ "$MARKETPLACE_VERSION" != "$LATEST_TAG" ]; then
  printf '[plugin-version] ERROR: marketplace.json version mismatch — marketplace.json=%s / latest tag=v%s\n' "$MARKETPLACE_VERSION" "$LATEST_TAG" >&2
  _mismatch=1
fi

if [ "$_mismatch" = "0" ]; then
  if [ -n "$MARKETPLACE_VERSION" ]; then
    printf '[plugin-version] OK: plugin.json (%s) = marketplace.json (%s) = tag (v%s)\n' "$PLUGIN_VERSION" "$MARKETPLACE_VERSION" "$LATEST_TAG"
  else
    printf '[plugin-version] OK: plugin.json (%s) = tag (v%s)（marketplace.json なし）\n' "$PLUGIN_VERSION" "$LATEST_TAG"
  fi
  exit 0
fi

printf '  リリース時は plugin.json / marketplace.json version を tag に合わせてください（sync-plugin-plangate.sh が CHANGELOG から自動更新）。\n' >&2
[ "$WARN_ONLY" = "1" ] && { printf '[plugin-version] --warn-only: 継続\n'; exit 0; }
exit 1
