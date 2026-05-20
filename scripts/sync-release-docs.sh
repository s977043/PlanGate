#!/usr/bin/env sh
# リリース時に CHANGELOG.md を /docs 配信面（docs/changelog.md）へ同期する。
# 冪等: 差分が無ければ no-op。手動実行も可。生成物は手動編集しない。
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/CHANGELOG.md"
DST="$ROOT/docs/changelog.md"
[ -f "$SRC" ] || { echo "error: $SRC not found" >&2; exit 1; }
tmp="$(mktemp -t sync-docs.XXXXXX 2>/dev/null || mktemp)"
trap 'rm -f "$tmp"' EXIT
{
  printf '# Changelog\n\n'
  printf '> このページは [CHANGELOG.md](https://github.com/s977043/PlanGate/blob/main/CHANGELOG.md) を\n'
  printf '> リリース時に自動同期したものです（手動編集しない）。生成: scripts/sync-release-docs.sh\n\n'
  tail -n +2 "$SRC"
} > "$tmp"
if [ -f "$DST" ] && diff -q "$tmp" "$DST" >/dev/null 2>&1; then
  echo "no-op: docs/changelog.md is already in sync"
  exit 0
fi
mv "$tmp" "$DST"
trap - EXIT
echo "synced: docs/changelog.md"
