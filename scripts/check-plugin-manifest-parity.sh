#!/bin/sh
# check-plugin-manifest-parity.sh — 2 つの plugin マニフェストの整合検査（#1085 AC-4）
#
# plugin/plangate/ は Claude 用 `.claude-plugin/plugin.json` と Codex 用
# `.codex-plugin/plugin.json` の 2 つを持つ。手動二重管理では version / name /
# skills パスが黙って乖離し、「片方だけ古い plugin が配布される」状態になる。
# 本スクリプトは 3 フィールド（name / version / skills）の一致を機械検出する。
#
# `description` は**比較対象に含めない**。現状 2 マニフェストは同文だが、Codex 側は
# `interface.longDescription` など UI 向けの記述を別に持つ設計であり、配布の正しさ
# （どの version の・どの名前の plugin が・どこの skills を配るか）に影響しない。
# 表現の揺れで FAIL する偽陽性のほうが害が大きいため、意図的に対象外とする。
#
# Usage:
#   sh scripts/check-plugin-manifest-parity.sh [PLUGIN_DIR]
#     PLUGIN_DIR 既定: <repo-root>/plugin/plangate
# Exit:
#   0 = 一致 / 2 = 前提未充足（マニフェスト不在・python3 不在）/ 1 = 不一致

set -eu

REPO_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
PLUGIN_DIR="${1:-$REPO_ROOT/plugin/plangate}"
CLAUDE_MANIFEST="$PLUGIN_DIR/.claude-plugin/plugin.json"
CODEX_MANIFEST="$PLUGIN_DIR/.codex-plugin/plugin.json"

command -v python3 >/dev/null 2>&1 || {
  printf '[manifest-parity] python3 required\n' >&2
  exit 2
}

for _m in "$CLAUDE_MANIFEST" "$CODEX_MANIFEST"; do
  if [ ! -f "$_m" ]; then
    printf '[manifest-parity] MISSING: %s\n' "$_m" >&2
    exit 2
  fi
done

python3 - "$CLAUDE_MANIFEST" "$CODEX_MANIFEST" << 'PYP'
import json, sys
from pathlib import PurePosixPath


def norm_skills(value):
    """`./skills/` と `skills` を同一視する（Codex validator の正規化と同じ規則）。"""
    if value is None:
        return None
    return PurePosixPath(str(value)).as_posix().rstrip('/')


paths = sys.argv[1:3]
try:
    manifests = [json.load(open(p, encoding='utf-8')) for p in paths]
except (OSError, json.JSONDecodeError) as exc:
    print('[manifest-parity] unreadable manifest: %s' % exc, file=sys.stderr)
    raise SystemExit(2)

# 「両方に無い」を一致扱いにしない（no-op 退行の封鎖）。
# 単純な != 比較だけだと両マニフェストから skills が消えたとき None == None で
# rc=0 になり、検査が黙って空振りする。
for path, manifest in zip(paths, manifests):
    absent = [f for f in ('name', 'version', 'skills') if not manifest.get(f)]
    if absent:
        print('[manifest-parity] MISSING FIELD(S) in %s: %s' % (path, ', '.join(absent)),
              file=sys.stderr)
        raise SystemExit(2)

mismatches = []
for field, transform in (('name', lambda v: v), ('version', lambda v: v), ('skills', norm_skills)):
    left, right = (transform(m.get(field)) for m in manifests)
    if left != right:
        mismatches.append((field, left, right))

if mismatches:
    print('[manifest-parity] MISMATCH between:')
    for p in paths:
        print('  - %s' % p)
    for field, left, right in mismatches:
        print('  %-8s claude=%r codex=%r' % (field, left, right))
    raise SystemExit(1)

print('[manifest-parity] OK name=%s version=%s skills=%s' % (
    manifests[0].get('name'),
    manifests[0].get('version'),
    norm_skills(manifests[0].get('skills')),
))
PYP
