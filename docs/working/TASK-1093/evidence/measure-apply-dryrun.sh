#!/bin/sh
# 全 apply-*.sh を --dry-run で実測し、rc / [dry-run] 有無 / 先頭行 を表にする。
ROOT="$1"
for f in "$ROOT"/scripts/apply-*.sh; do
  b=$(basename "$f")
  out="$(sh "$f" --dry-run 2>&1)" && rc=0 || rc=$?
  dr=$(printf '%s' "$out" | grep -c '\[dry-run\]')
  first=$(printf '%s' "$out" | head -1 | cut -c1-90)
  printf '%s|rc=%s|dryrun_hits=%s|%s\n' "$b" "$rc" "$dr" "$first"
done
