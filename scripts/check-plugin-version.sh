#!/bin/sh
# check-plugin-version.sh — plugin.json の version が最新 release tag と一致するか検証
#
# v8.11.0 で plugin.json version が release tag と乖離する事象（#453）の再発防止。
# リリース後の整合検証に使う（開発中の version 先行を許容する場合は --warn-only）。
#
# Usage: sh scripts/check-plugin-version.sh [--warn-only]
# Exit: 0=一致 or tag無し, 1=不一致（--warn-only 時は常に 0）

set -eu

REPO_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
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

if [ "$PLUGIN_VERSION" = "$LATEST_TAG" ]; then
  printf '[plugin-version] OK: plugin.json (%s) = tag (v%s)\n' "$PLUGIN_VERSION" "$LATEST_TAG"
  exit 0
fi

printf '[plugin-version] MISMATCH: plugin.json=%s / latest tag=v%s\n' "$PLUGIN_VERSION" "$LATEST_TAG" >&2
printf '  リリース時は plugin.json version を tag に合わせてください（sync-plugin-plangate.sh が CHANGELOG から自動更新）。\n' >&2
[ "$WARN_ONLY" = "1" ] && { printf '[plugin-version] --warn-only: 継続\n'; exit 0; }
exit 1
