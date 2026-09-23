#!/bin/sh
# apply-claude-md-v8220-date.sh -- CLAUDE.md「最新リリース」節の v8.22.0 の日付を
# リリース準備日（2026-09-11）から実リリース日（2026-09-23）へ更新する
#
# CLAUDE.md は Hardening Override (HO) 対象（self-mod guard）。AI は --dry-run
# のみ実行可。--apply の実行は Human-owned（.claude/rules/responsibility-classes.md）。
#
# 背景: v8.22.0 は 2026-09-11 にリリース準備（#1331）を終えたが、tag push が
# 2026-09-23 になった。CHANGELOG / README / README_en / docs/changelog.md の日付は
# 同じ PR で更新しており、HO 対象の CLAUDE.md だけを本スクリプトで揃える。
#
# 既存の apply-claude-md-v8220.sh は「新見出しの有無」で適用済みを判定するため、
# 日付だけの変更は検出できない。本スクリプトはそれとは独立に、日付の 1 箇所だけを置換する。
#
# release-prep.sh の NG-1 は出力中の "[dry-run]" の有無だけで未適用を判定する。
# 適用済みのとき "[dry-run]" を印字すると偽陽性になるため、未適用のときだけ印字する。
#
# Usage:
#   sh scripts/apply-claude-md-v8220-date.sh --dry-run   # 差分プレビュー（書込なし）
#   sh scripts/apply-claude-md-v8220-date.sh --apply     # 適用（Human 実行のみ）
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
F="$ROOT/CLAUDE.md"
[ $# -eq 1 ] || { echo "usage: $0 --dry-run|--apply" >&2; exit 1; }
case "$1" in --dry-run|--apply) ;; *) echo "usage: $0 --dry-run|--apply" >&2; exit 1 ;; esac

OLD="**v8.22.0**（2026-09-11）"
NEW="**v8.22.0**（2026-09-23）"

command -v python3 >/dev/null 2>&1 || { echo "python3 required" >&2; exit 1; }
[ -f "$F" ] || { echo "FAIL: $F が存在しない" >&2; exit 1; }

old_n=$(grep -cF "$OLD" "$F" || true)
new_n=$(grep -cF "$NEW" "$F" || true)

if [ "$old_n" -eq 0 ] && [ "$new_n" -eq 1 ]; then
  echo "SKIP: 適用済み（v8.22.0 の日付は既に 2026-09-23）"
  exit 0
fi
[ "$old_n" -eq 1 ] && [ "$new_n" -eq 0 ] || {
  echo "FAIL: 想定外の状態（旧日付 ${old_n} 件 / 新日付 ${new_n} 件。旧 1・新 0 であるべき）" >&2
  exit 1
}

TMP=$(mktemp "${TMPDIR:-/tmp}/claude-md-v8220-date.XXXXXX")
trap 'rm -f "$TMP"' EXIT INT TERM

export OLD NEW F TMP
python3 - <<'PY'
import os
f = os.environ['F']
s = open(f, encoding='utf-8').read()
out = s.replace(os.environ['OLD'], os.environ['NEW'], 1)
open(os.environ['TMP'], 'w', encoding='utf-8', newline='\n').write(out)
PY

case "$1" in
  --dry-run)
    echo "[dry-run] 書込なし。差分:"
    diff -u "$F" "$TMP" | head -12 | cut -c1-160 || true
    ;;
  --apply)
    cp "$TMP" "$F"
    echo "[apply] CLAUDE.md の v8.22.0 の日付を 2026-09-23 へ更新しました（Human 実行前提）"
    ;;
esac
