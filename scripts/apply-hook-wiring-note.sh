#!/bin/sh
# apply-hook-wiring-note.sh — CLAUDE.md の Hook enforcement 表現を実態整合（Human 実行）
#
# 背景: 2026-06-10 の Shadow Spec 棚卸しで「12/12」公称に対し物理配線は 6/12 と判明。
# 正本（docs/ai/hook-enforcement.md）には配線状態表を追加済み。CLAUDE.md は
# Hardening Override 対象のため本スクリプトで Human が適用する。
#
# 使い方: sh scripts/apply-hook-wiring-note.sh [--dry-run|--apply]
set -eu
MODE="${1:---dry-run}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
F="$ROOT/CLAUDE.md"
OLD='Hook enforcement は **12/12**'
NEW='Hook enforcement は **12/12 実装**（物理配線 6/12、詳細は [`docs/ai/hook-enforcement.md`](docs/ai/hook-enforcement.md)）'

if grep -qF "$NEW" "$F"; then echo "OK (already applied)"; exit 0; fi
grep -qF "$OLD" "$F" || { echo "ERROR: アンカーが見つかりません: $OLD" >&2; exit 1; }
if [ "$MODE" = "--dry-run" ]; then
  echo "[dry-run] CLAUDE.md:"; echo "- $OLD"; echo "+ $NEW"
elif [ "$MODE" = "--apply" ]; then
  python3 - "$F" "$OLD" "$NEW" <<'PY'
import sys
f, old, new = sys.argv[1], sys.argv[2], sys.argv[3]
with open(f, encoding="utf-8") as fp: s = fp.read()
assert s.count(old) == 1
with open(f, "w", encoding="utf-8") as fp: fp.write(s.replace(old, new))
PY
  echo "APPLIED: CLAUDE.md"
else
  echo "usage: $0 [--dry-run|--apply]"; exit 1
fi
