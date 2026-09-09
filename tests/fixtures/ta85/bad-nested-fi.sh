#!/bin/sh
# positive control fixture — `&&` リストが `fi` の直前にある形。
# **最終行だけを見る検査では捕まらない**（最終行は `fi`）。
# install-plangate-skills-to-codex.sh の実際の形はこれ。
set -eu
c=0
if [ "${1:-}" = "json" ]; then
  printf '{}\n'
else
  printf 'text\n'
  [ "$c" -gt 0 ] && printf 'names\n'
fi
