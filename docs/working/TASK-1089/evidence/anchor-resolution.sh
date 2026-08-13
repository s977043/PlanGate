#!/bin/sh
# anchor-resolution.sh — MAJOR-3: 記号アンカーが patch 適用前後の両方で
# 同じ 9 カテゴリ case ブロックへ解決することの実測。
#
#   sh docs/working/TASK-1089/evidence/anchor-resolution.sh <repo_root_or_sandbox>
#
# 正本の記法（行番号を使わない）:
#   scripts/hooks/check-plan-hash.sh の `_override=0` 直後の `case` ブロック（`esac` まで）
set -u
H="$1/scripts/hooks/check-plan-hash.sh"
echo "### $1"
echo "occurrences of _override=0 : $(grep -c '_override=0' "$H")"
echo "line of _override=0        : $(grep -n '_override=0' "$H" | cut -d: -f1)"
echo "--- extracted case block ---"
awk '/_override=0/{g=1;next} g&&/^[[:space:]]*esac/{exit} g' "$H"
echo "--- category count ---"
awk '/_override=0/{g=1;next} g&&/^[[:space:]]*esac/{exit} g' "$H" | grep -c '_override=1'
