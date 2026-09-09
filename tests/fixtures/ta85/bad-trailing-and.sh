#!/bin/sh
# positive control fixture — スクリプト末尾の `[ ] && cmd` で rc が漏れる形。
# 2026-09-08 に install-plangate-skills-to-codex.sh が実際にこの形で main を壊した。
set -eu
n=0
if [ "${1:-}" = "x" ]; then
  n=1
fi
printf 'n=%s\n' "$n"
[ "$n" -gt 0 ] && printf 'extra\n'
