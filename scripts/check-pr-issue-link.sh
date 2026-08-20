#!/bin/sh
# check-pr-issue-link.sh
# PR 本文に issue への linkage が含まれているか検証する。
# closing keyword (closes/fixes/resolves #N) に加え、issue を閉じない linkage
# 宣言 (Refs: #N / Part of #N / Related to #N) も有効なリンクとして扱う。
#
# Usage:
#   sh scripts/check-pr-issue-link.sh \
#     --body-file <path>   # PR body 内容
#     --labels-file <path> # PR labels（1 行 1 ラベル、カンマ区切りも可）
#     --changed-files <path> # PR 変更ファイル一覧（1 行 1 path）
#
# 出力 (stdout, 1 行):
#   PASS: <理由>
#   WARN: <理由>
#   SKIP: <理由>
#
# Exit code: 常に 0（warning は出力でのみ表現）。
# 引数誤りなど内部エラーのみ非ゼロ。
#
# 関連: docs/working/TASK-0045/, Issue #159

set -eu

BODY_FILE=""
LABELS_FILE=""
CHANGED_FILES=""

while [ $# -gt 0 ]; do
  case "$1" in
    --body-file)
      BODY_FILE=$2
      shift 2
      ;;
    --labels-file)
      LABELS_FILE=$2
      shift 2
      ;;
    --changed-files)
      CHANGED_FILES=$2
      shift 2
      ;;
    *)
      printf 'ERROR: unknown arg %s\n' "$1" >&2
      exit 2
      ;;
  esac
done

if [ -z "$BODY_FILE" ] || [ ! -f "$BODY_FILE" ]; then
  printf 'ERROR: --body-file required and must exist\n' >&2
  exit 2
fi

# --- skip marker check ---
if grep -q '<!-- *skip-issue-link-check *-->' "$BODY_FILE"; then
  printf 'SKIP: marker "<!-- skip-issue-link-check -->" found\n'
  exit 0
fi

# --- skip label check ---
if [ -n "$LABELS_FILE" ] && [ -f "$LABELS_FILE" ]; then
  # ラベルは行 or カンマ区切り、両対応
  labels_normalized=$(tr ',' '\n' <"$LABELS_FILE" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep -v '^$' || true)
  for skip_label in chore documentation; do
    if printf '%s\n' "$labels_normalized" | grep -qx "$skip_label"; then
      printf 'SKIP: label "%s" matched skip rule\n' "$skip_label"
      exit 0
    fi
  done
fi

# --- closing keyword extraction ---
# GitHub の正式な closing keyword: close, closes, closed, fix, fixes, fixed,
# resolve, resolves, resolved（case-insensitive）
# 形式: <keyword> [owner/repo]#<issue-number>
keyword_re='(close|closes|closed|fix|fixes|fixed|resolve|resolves|resolved)[[:space:]]+([A-Za-z0-9._-]+/[A-Za-z0-9._-]+)?#([0-9]+)'

# --- non-closing link keyword (#159 改善) ---
# 本リポジトリの実運用では 1 issue を複数 PR のスライスに分割するため、issue を
# 閉じない linkage 宣言（Refs: #N / Part of #N / Related to #N）が主流である。
# これらは「issue 未リンク」ではないので WARN の対象から外す。
# `(^|[^A-Za-z])` は xrefs / prefs 等の部分一致による誤検出を防ぐ語頭ガード
# （裸の `#N` は linkage 宣言ではないため意図的に対象外 = TC warn-bare-hash）。
nonclosing_re='(^|[^A-Za-z])(refs?|related([[:space:]]+to)?|part[[:space:]]+of)[[:space:]:]+([A-Za-z0-9._-]+/[A-Za-z0-9._-]+)?#([0-9]+)'

# 該当 issue 番号を全て抽出
closing_issues=$(grep -Eio "$keyword_re" "$BODY_FILE" 2>/dev/null \
  | grep -Eo '#[0-9]+' \
  | sort -u \
  | tr '\n' ' ' \
  | sed 's/[[:space:]]*$//' || true)

nonclosing_issues=$(grep -Eio "$nonclosing_re" "$BODY_FILE" 2>/dev/null \
  | grep -Eo '#[0-9]+' \
  | sort -u \
  | tr '\n' ' ' \
  | sed 's/[[:space:]]*$//' || true)

# expected_issue 照合は closing / non-closing の双方を対象にする
matched_issues=$(printf '%s %s' "$closing_issues" "$nonclosing_issues" \
  | tr ' ' '\n' \
  | grep -v '^$' \
  | sort -u \
  | tr '\n' ' ' \
  | sed 's/[[:space:]]*$//' || true)

# --- expected issue from child PBI YAML (optional) ---
expected_issue=""
if [ -n "$CHANGED_FILES" ] && [ -f "$CHANGED_FILES" ]; then
  yaml_paths=$(grep -E '^docs/working/PBI-[0-9]+/children/.*\.ya?ml$' "$CHANGED_FILES" 2>/dev/null || true)
  if [ -n "$yaml_paths" ]; then
    for yaml in $yaml_paths; do
      if [ -f "$yaml" ]; then
        # related_issue: 123 形式から抽出（quote 有無問わず）
        ri=$(grep -E '^[[:space:]]*related_issue:[[:space:]]*' "$yaml" 2>/dev/null \
          | head -1 \
          | sed -E 's/.*related_issue:[[:space:]]*"?([0-9]+)"?.*/\1/' || true)
        if [ -n "$ri" ]; then
          expected_issue="$ri"
          break
        fi
      fi
    done
  fi
fi

# --- judgment ---
if [ -z "$matched_issues" ]; then
  printf 'WARN: no issue link found (expected one of: closes #N / fixes #N / resolves #N / Refs: #N / Part of #N)\n'
  exit 0
fi

if [ -n "$expected_issue" ]; then
  if printf '%s' "$matched_issues" | grep -qw "#$expected_issue"; then
    printf 'PASS: expected issue #%s present in issue link(s) (%s)\n' "$expected_issue" "$matched_issues"
  else
    printf 'WARN: expected issue #%s (from child PBI YAML) not in issue link(s) (%s)\n' "$expected_issue" "$matched_issues"
  fi
  exit 0
fi

if [ -n "$closing_issues" ]; then
  printf 'PASS: closing keyword(s) %s found\n' "$closing_issues"
else
  printf 'PASS: non-closing link(s) %s found (issue stays open by design)\n' "$nonclosing_issues"
fi
exit 0
