#!/bin/sh
# 振り返り評価配点の複製サイトを検査する TASK-0121 / R-012 ドリフト対策。
# 権威サイトのみを対象に、旧配点残存・新5軸欠落・inline順序不一致を検出する。

set -eu

TARGETS='docs/ai-driven-development.md
.claude/agents/workflow-conductor.md
.claude/agents/retrospective-analyst.md
plugin/plangate/agents/workflow-conductor.md'

status=0
SCORE_SEP='[ |/{}N]*'
EXPECTED_INLINE_ORDER='計画精度30/テスト品質15/プロセス遵守15/効率性10/成果物品質30'

has_score() {
  file=$1
  axis=$2
  value=$3

  grep -Eq "$axis$SCORE_SEP$value" "$file"
}

print_score_matches() {
  file=$1
  axis=$2
  value=$3
  message=$4

  grep -nE "$axis$SCORE_SEP$value" "$file" | while IFS= read -r line; do
    printf "%s:%s: %s: %s%d\n" "$file" "$line" "$message" "$axis" "$value" >&2
  done
}

check_old_scores() {
  file=$1
  bad=0
  old_order="計画精度${SCORE_SEP}15${SCORE_SEP}テスト品質${SCORE_SEP}15${SCORE_SEP}プロセス遵守${SCORE_SEP}15${SCORE_SEP}効率性${SCORE_SEP}25${SCORE_SEP}成果物品質${SCORE_SEP}30"

  if has_score "$file" "計画精度" 15; then
    print_score_matches "$file" "計画精度" 15 "old score remains"
    bad=1
  fi

  if has_score "$file" "効率性" 25; then
    print_score_matches "$file" "効率性" 25 "old score remains"
    bad=1
  fi

  if grep -Eq "$old_order" "$file"; then
    grep -nE "$old_order" "$file" | while IFS= read -r line; do
      printf "%s:%s: old score order remains: 計画精度15/テスト品質15/プロセス遵守15/効率性25/成果物品質30\n" "$file" "$line" >&2
    done
    bad=1
  fi

  return "$bad"
}

check_new_scores() {
  file=$1
  bad=0

  if ! has_score "$file" "計画精度" 30; then
    echo "$file: missing required score: 計画精度30" >&2
    bad=1
  fi
  if ! has_score "$file" "テスト品質" 15; then
    echo "$file: missing required score: テスト品質15" >&2
    bad=1
  fi
  if ! has_score "$file" "プロセス遵守" 15; then
    echo "$file: missing required score: プロセス遵守15" >&2
    bad=1
  fi
  if ! has_score "$file" "効率性" 10; then
    echo "$file: missing required score: 効率性10" >&2
    bad=1
  fi
  if ! has_score "$file" "成果物品質" 30; then
    echo "$file: missing required score: 成果物品質30" >&2
    bad=1
  fi

  return "$bad"
}

check_inline_order() {
  file=$1

  if ! grep -Fq "$EXPECTED_INLINE_ORDER" "$file"; then
    echo "$file: missing required inline score order: $EXPECTED_INLINE_ORDER" >&2
    return 1
  fi

  return 0
}

for file in $TARGETS; do
  if [ ! -f "$file" ]; then
    echo "$file: target file is missing" >&2
    status=1
    continue
  fi

  if ! check_old_scores "$file"; then
    status=1
  fi

  if ! check_new_scores "$file"; then
    status=1
  fi
done

if ! check_inline_order ".claude/agents/workflow-conductor.md"; then
  status=1
fi

if ! check_inline_order "plugin/plangate/agents/workflow-conductor.md"; then
  status=1
fi

if [ "$status" -eq 0 ]; then
  echo "[retro-scoring] OK: old scores absent, required scores present, inline order valid"
else
  echo "[retro-scoring] FAIL: scoring consistency violations found" >&2
fi

exit "$status"
