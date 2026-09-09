#!/bin/sh
# negative control fixture — 同じ意図を if ... fi で書いた形（rc は漏れない）。
set -eu
n=0
if [ "${1:-}" = "x" ]; then
  n=1
fi
printf 'n=%s\n' "$n"
if [ "$n" -gt 0 ]; then
  printf 'extra\n'
fi
