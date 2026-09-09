#!/bin/sh
set -eu
c=0
if [ "${1:-}" = "json" ]; then
  printf 'json\n'
  [ "$c" -gt 0 ] && printf 'names\n'
else
  printf 'text\n'
fi
