#!/bin/sh
# apply-task-0127-render.sh — TASK-0127
# bin/plangate に `render` サブコマンド（C-3 レビュー HTML 出力）を追加する。
#
# bin/plangate は Hardening Override 対象のため AI は直接編集できない。本スクリプトを
# AI が用意し、Human が dry-run で差分確認のうえ適用する（責務4分類: HO 実適用は Human）。
#
# 追加内容:
#   - cmd_render(): scripts/render_review.py を呼び出し <TASK>-c3-review.html を生成
#   - dispatch `render)` + help 行
#
# 使い方:
#   sh scripts/apply-task-0127-render.sh --dry-run
#   sh scripts/apply-task-0127-render.sh
#
# 冪等: cmd_render が既にあれば何もしない。
set -eu

REPO_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
TARGET="$REPO_ROOT/bin/plangate"
DRY_RUN=0
if [ $# -gt 0 ]; then
  if [ "$1" = "--dry-run" ] && [ $# -eq 1 ]; then DRY_RUN=1
  else echo "ERROR: Usage: $0 [--dry-run]" >&2; exit 1; fi
fi
[ -f "$TARGET" ] || { echo "ERROR: $TARGET が見つかりません"; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 が必要です"; exit 1; }

if grep -q 'cmd_render()' "$TARGET"; then
  echo "SKIP: cmd_render は既に適用済み"; exit 0
fi
for anchor in '# ── dispatch ──' 'maintenance) cmd_maintenance "$@" ;;'; do
  grep -qF "$anchor" "$TARGET" || { echo "ERROR: アンカー '$anchor' が見つかりません"; exit 1; }
done

python3 - "$TARGET" "$DRY_RUN" <<'PY'
import sys, difflib
target, dry = sys.argv[1], sys.argv[2] == "1"
src = open(target).read()

FUNC = r'''
# ── render (TASK-0127 / C-3 review aggregation to self-contained HTML) ──
# C-3 対象 7 種 MD を 1 枚の自己完結 HTML に集約（scripts/render_review.py 委譲）。
# Python 標準ライブラリのみ・外部 CDN 依存なし。
cmd_render() {
  _rd_task=""; _rd_out=""; _rd_html=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --html) _rd_html=1; shift ;;
      --out)  [ $# -lt 2 ] && { printf 'error: --out requires an argument\n' >&2; return 2; }; _rd_out="$2"; shift 2 ;;
      -*)     printf 'error: unknown arg: %s\n' "$1" >&2; return 2 ;;
      *)      _rd_task="$1"; shift ;;
    esac
  done
  if [ -z "$_rd_task" ]; then
    printf 'Usage: plangate render <TASK-XXXX> [--html] [--out <file>]\n' >&2
    return 2
  fi
  plangate_validate_task_id "$_rd_task"
  _rd_py="$plangate_root/scripts/render_review.py"
  [ -f "$_rd_py" ] || { printf 'error: scripts/render_review.py not found\n' >&2; return 2; }
  if [ -n "$_rd_out" ]; then
    python3 "$_rd_py" --task "$_rd_task" --out "$_rd_out"
  else
    python3 "$_rd_py" --task "$_rd_task"
  fi
}
'''

DISPATCH_OLD = '  maintenance) cmd_maintenance "$@" ;;'
DISPATCH_NEW = DISPATCH_OLD + '\n  render)      cmd_render "$@" ;;'
HELP_OLD = '    "  maintenance <start|stop> ...   In-session edit window (Human-only, L1-L4 defense) (TASK-0106)" \\'
HELP_NEW = '    "  render <TASK-XXXX> [--html]    Aggregate C-3 review MDs into self-contained HTML (TASK-0127)" \\\n' + HELP_OLD
MARK = '# ── dispatch ──'

new = src
idx = new.index(MARK)
new = new[:idx] + FUNC.lstrip('\n') + '\n' + new[idx:]
assert DISPATCH_OLD in new
new = new.replace(DISPATCH_OLD, DISPATCH_NEW, 1)
if HELP_OLD in new:
    new = new.replace(HELP_OLD, HELP_NEW, 1)
else:
    sys.stderr.write("WARN: help anchor not found; skipping help line\n")

if dry:
    sys.stdout.write("".join(difflib.unified_diff(
        src.splitlines(True), new.splitlines(True),
        fromfile="bin/plangate", tofile="bin/plangate (after)")))
    sys.stderr.write("\n[dry-run] 上記差分。適用するには --dry-run なしで実行。\n")
else:
    open(target, "w").write(new)
    sys.stderr.write("[applied] cmd_render を bin/plangate に追加しました。\n")
PY
