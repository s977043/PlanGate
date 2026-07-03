#!/bin/sh
# apply-reviewer-silence-gate.sh — #685 レビュアー沈黙時のフォールバック仕様の
# 既存正本（review-principles.md / gate-checks.md）への参照追記を適用する。
#
# 責務4分類: AI が本スクリプトを作成し、実行は Human が行う（HO パスへの
# 適用は Human-owned）。review-principles.md は .claude/rules/*.md（HO 対象）
# のため、AI（Claude/Codex）は本スクリプトを実行してはならない。dry-run で
# 差分を確認した上で、人間が --apply を実行すること。
#
# 各変更は冪等（既適用なら skip）。--dry-run（既定）で差分のみ表示し
# 書き込まない。anchor が見つからない場合は明示的に fail する。
#
# Usage:
#   sh scripts/apply-reviewer-silence-gate.sh --dry-run   # 差分確認（既定と同じ、書き込みなし）
#   sh scripts/apply-reviewer-silence-gate.sh --apply      # 適用（Human のみ実行可）
#
# 適用後の検証:
#   git diff -- .claude/rules/review-principles.md docs/ai/gate-checks.md
#   npx markdownlint-cli2 .claude/rules/review-principles.md docs/ai/gate-checks.md

set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
MODE="dry-run"
case "${1:-}" in
  --apply) MODE="apply" ;;
  --dry-run|"") MODE="dry-run" ;;
  *) printf 'Unknown argument: %s (use --dry-run or --apply)\n' "${1:-}" >&2; exit 1 ;;
esac
command -v python3 >/dev/null 2>&1 || { printf 'python3 required\n' >&2; exit 1; }

FAILED=0

# apply_patch <relpath> : stdin の python が new content を stdout に出す
# （冪等）。anchor が見つからず変更できなかった場合、python 側が exit code 2
# を返す規約とし、ここで明示 fail する。
apply_patch() {
  _f="$ROOT/$1"
  if [ ! -f "$_f" ]; then
    printf '  [FAIL] %s が存在しません\n' "$1"
    FAILED=1
    return 0
  fi
  _tmp=$(mktemp)
  _rc=0
  python3 - "$_f" > "$_tmp" || _rc=$?
  if [ "$_rc" = "2" ]; then
    printf '  [FAIL] %s: anchor が見つかりません（正本の構造が変わった可能性）\n' "$1"
    FAILED=1
    rm -f "$_tmp"
    return 0
  elif [ "$_rc" != "0" ]; then
    printf '  [FAIL] %s: python 変換でエラー（rc=%s）\n' "$1" "$_rc"
    FAILED=1
    rm -f "$_tmp"
    return 0
  fi
  if cmp -s "$_f" "$_tmp"; then
    printf '  [skip] %s（既適用 or 変更なし）\n' "$1"
  elif [ "$MODE" = "dry-run" ]; then
    printf '  [dry-run] %s の差分:\n' "$1"
    diff -u "$_f" "$_tmp" | sed 's/^/    /' || true
  else
    cat "$_tmp" > "$_f"
    printf '  [applied] %s\n' "$1"
  fi
  rm -f "$_tmp"
}

printf '=== #685: review-principles.md §7-ter にフォールバック参照を追記 ===\n'
apply_patch .claude/rules/review-principles.md <<'PY1'
import sys
p = sys.argv[1]; s = open(p, encoding='utf-8').read()
marker = "レビュアー沈黙時のフォールバック（#685）"
if marker in s:
    sys.stdout.write(s); sys.exit(0)
anchor = "## 8. レビューの優先順位"
if anchor not in s:
    sys.exit(2)
addition = (
    "本仕様を拡張し、複数レビュアー系統を前提にした gate 通過条件・"
    "レビュアー沈黙時のフォールバック（#685）・無レビューマージの構造的"
    "禁止を定義した正本は [`docs/ai/reviewer-silence-fallback.md`]"
    "(../../docs/ai/reviewer-silence-fallback.md)。\n\n"
)
s = s.replace(anchor, addition + anchor, 1)
sys.stdout.write(s)
PY1

printf '=== #685: gate-checks.md に review_gate_passed 参照フィールドを追記 ===\n'
apply_patch docs/ai/gate-checks.md <<'PY2'
import sys
p = sys.argv[1]; s = open(p, encoding='utf-8').read()
marker = "review_gate_passed"
if marker in s:
    sys.stdout.write(s); sys.exit(0)
anchor = "| `gate_checks.note` | string | 任意 | 人間の補足コメント |"
if anchor not in s:
    sys.exit(2)
addition = (
    "\n| `gate_checks.review_gate_passed` | boolean | 任意 | "
    "[`reviewer-silence-fallback.md`](./reviewer-silence-fallback.md) §2 の "
    "`ReviewGatePassed`（最低 N 系統のレビュー実施証跡が記録されているか）を "
    "満たしているか（#685） |"
)
s = s.replace(anchor, anchor + addition, 1)
sys.stdout.write(s)
PY2

printf '\n'
if [ "$FAILED" = "1" ]; then
  printf '=== 一部の適用に失敗しました（anchor 不一致等）。上記 [FAIL] を確認してください ===\n' >&2
  exit 1
fi
if [ "$MODE" = "dry-run" ]; then
  printf '=== dry-run 完了（書き込みなし）。適用するには --apply を Human が実行してください ===\n'
else
  printf '=== 適用完了 ===\n'
fi
