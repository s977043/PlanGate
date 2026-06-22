#!/bin/sh
# apply-approve-hardening.sh — TASK-0139 (#550)
# bin/plangate の cmd_approve / _plangate_presence_gate / cmd_maintenance_start を強化する。
#
# bin/plangate は Hardening Override 対象のため AI は直接編集できない。本スクリプトを
# AI が用意し、Human が dry-run で差分確認のうえ適用する（責務4分類: HO 実適用は Human）。
#
# 変更内容:
#   (a) cmd_approve の対話 read → read -r 化（2箇所 / AC-01）
#   (b) _plangate_presence_gate の PLANGATE_FAKE_PPID_COMM を PLANGATE_TEST_MODE=1 時のみ有効化（AC-03）
#   (c) cmd_maintenance_start の PLANGATE_FAKE_PPID_COMM も同様にガード（AC-03）
#   (d) cmd_maintenance_start の read _ack → read -r _ack（AC-02）
#   (e) cmd_approve の c3.json 既存チェック: note → abort（--force なし時 return 2 / AC-04）
#
# 使い方:
#   sh scripts/apply-approve-hardening.sh --dry-run   # 差分プレビュー
#   sh scripts/apply-approve-hardening.sh             # 実適用（Human が実行）
#
# 冪等: 既に適用済み（TASK-0139 AC-04 コメントが bin/plangate にある）なら何もしない。
set -eu

REPO_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
TARGET="$REPO_ROOT/bin/plangate"
DRY_RUN=0
if [ $# -gt 0 ]; then
  if [ "$1" = "--dry-run" ] && [ $# -eq 1 ]; then
    DRY_RUN=1
  else
    echo "ERROR: 不正な引数です。Usage: $0 [--dry-run]" >&2
    exit 1
  fi
fi

[ -f "$TARGET" ] || { echo "ERROR: $TARGET が見つかりません"; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 が必要です"; exit 1; }

# cmd_approve の存在確認（TASK-0128 未適用なら中止）
grep -q 'cmd_approve()' "$TARGET" || { echo "ERROR: cmd_approve が見つかりません（TASK-0128 未適用？）"; exit 1; }

# 冪等: 既に TASK-0139 適用済みか確認
if grep -q 'TASK-0139 AC-04: abort if c3.json exists and --force not given' "$TARGET"; then
  echo "SKIP: TASK-0139 は既に適用済み"; exit 0
fi

python3 - "$TARGET" "$DRY_RUN" <<'PY'
import sys, difflib

target, dry = sys.argv[1], sys.argv[2] == "1"
src = open(target, encoding='utf-8').read()
new = src

# ── (a) cmd_approve: read _ap_reason → read -r _ap_reason (AC-01) ──
a1_old = "if [ -t 0 ]; then printf 'rejection reason> '; read _ap_reason || _ap_reason=\"\"; fi"
a1_new = "if [ -t 0 ]; then printf 'rejection reason> '; read -r _ap_reason || _ap_reason=\"\"; fi"
if a1_old in new:
    new = new.replace(a1_old, a1_new, 1)
    sys.stderr.write("  (a1) read _ap_reason → read -r applied\n")
else:
    if "read -r _ap_reason" not in new:
        sys.exit("ERROR: read _ap_reason anchor not found in bin/plangate")
    sys.stderr.write("  (a1) read -r _ap_reason: already applied\n")

# ── (a) cmd_approve: read _ap_conditions → read -r _ap_conditions (AC-01) ──
a2_old = "if [ -t 0 ]; then printf 'conditions> '; read _ap_conditions || _ap_conditions=\"\"; fi"
a2_new = "if [ -t 0 ]; then printf 'conditions> '; read -r _ap_conditions || _ap_conditions=\"\"; fi"
if a2_old in new:
    new = new.replace(a2_old, a2_new, 1)
    sys.stderr.write("  (a2) read _ap_conditions → read -r applied\n")
else:
    if "read -r _ap_conditions" not in new:
        sys.exit("ERROR: read _ap_conditions anchor not found in bin/plangate")
    sys.stderr.write("  (a2) read -r _ap_conditions: already applied\n")

# ── (b) _plangate_presence_gate: FAKE_PPID_COMM → TEST_MODE guard (AC-03) ──
b_old = '''  # L3: parent process heuristic
  _pcomm=$(ps -p $PPID -o comm= 2>/dev/null | tr -d ' ')
  if [ -n "${PLANGATE_FAKE_PPID_COMM:-}" ]; then _pcomm="$PLANGATE_FAKE_PPID_COMM"; fi
  if printf '%s' "$_pcomm" | grep -iqE 'claude|codex|cursor'; then
    _pg_audit reject_L3 "ppid comm=$_pcomm"'''
b_new = '''  # L3: parent process heuristic
  _pcomm=$(ps -p $PPID -o comm= 2>/dev/null | tr -d ' ')
  # PLANGATE_FAKE_PPID_COMM はテスト専用注入。本番経路での L3 上書きを防ぐため
  # PLANGATE_TEST_MODE=1 のときのみ honor する（TASK-0139 AC-03）。
  if [ "${PLANGATE_TEST_MODE:-0}" = "1" ] && [ -n "${PLANGATE_FAKE_PPID_COMM:-}" ]; then _pcomm="$PLANGATE_FAKE_PPID_COMM"; fi
  if printf '%s' "$_pcomm" | grep -iqE 'claude|codex|cursor'; then
    _pg_audit reject_L3 "ppid comm=$_pcomm"'''
if b_old in new:
    new = new.replace(b_old, b_new, 1)
    sys.stderr.write("  (b) _plangate_presence_gate FAKE_PPID guard applied\n")
elif b_new in new:
    sys.stderr.write("  (b) _plangate_presence_gate: already applied\n")
else:
    sys.exit("ERROR: _plangate_presence_gate L3 anchor not found")

# ── (c) cmd_maintenance_start: read _ack → read -r _ack (AC-02) ──
c_old = "      read _ack || _ack=\"\"\n"
c_new = "      read -r _ack || _ack=\"\"\n"
if c_old in new:
    new = new.replace(c_old, c_new, 1)
    sys.stderr.write("  (c) maintenance read _ack → read -r applied\n")
elif "read -r _ack" in new:
    sys.stderr.write("  (c) maintenance read -r _ack: already applied\n")
else:
    sys.exit("ERROR: maintenance read _ack anchor not found")

# ── (d) cmd_maintenance_start: FAKE_PPID_COMM → TEST_MODE guard (AC-03) ──
d_old = '''      # --- L3: parent process heuristic ---
      _pcomm=$(ps -p $PPID -o comm= 2>/dev/null | tr -d ' ')
      # PLANGATE_FAKE_PPID_COMM is test-only injection (R-026)
      if [ -n "${PLANGATE_FAKE_PPID_COMM:-}" ]; then _pcomm="$PLANGATE_FAKE_PPID_COMM"; fi
      if printf '%s' "$_pcomm" | grep -iqE 'claude|codex|cursor'; then'''
d_new = '''      # --- L3: parent process heuristic ---
      _pcomm=$(ps -p $PPID -o comm= 2>/dev/null | tr -d ' ')
      # PLANGATE_FAKE_PPID_COMM はテスト専用注入。本番経路での L3 上書きを防ぐため
      # PLANGATE_TEST_MODE=1 のときのみ honor する（TASK-0139 AC-03）。
      if [ "${PLANGATE_TEST_MODE:-0}" = "1" ] && [ -n "${PLANGATE_FAKE_PPID_COMM:-}" ]; then _pcomm="$PLANGATE_FAKE_PPID_COMM"; fi
      if printf '%s' "$_pcomm" | grep -iqE 'claude|codex|cursor'; then'''
if d_old in new:
    new = new.replace(d_old, d_new, 1)
    sys.stderr.write("  (d) maintenance FAKE_PPID guard applied\n")
else:
    d_old2 = '''      # --- L3: parent process heuristic ---
      _pcomm=$(ps -p $PPID -o comm= 2>/dev/null | tr -d ' ')
      if [ -n "${PLANGATE_FAKE_PPID_COMM:-}" ]; then _pcomm="$PLANGATE_FAKE_PPID_COMM"; fi
      if printf '%s' "$_pcomm" | grep -iqE 'claude|codex|cursor'; then'''
    if d_old2 in new:
        new = new.replace(d_old2, d_new, 1)
        sys.stderr.write("  (d) maintenance FAKE_PPID guard applied (alt anchor)\n")
    elif d_new in new:
        sys.stderr.write("  (d) maintenance FAKE_PPID guard: already applied\n")
    else:
        sys.exit("ERROR: maintenance L3 anchor not found")

# ── (e) cmd_approve: c3.json overwrite → abort if --force not given (AC-04) ──
e_old = '''  # 既存 c3.json
  _ap_c3="$_ap_dir/approvals/c3.json"
  if [ -f "$_ap_c3" ] && [ "$_ap_force" = "false" ]; then
    printf 'note: existing c3.json found; re-approval will overwrite (use --force to skip this note)\\n' >&2
  fi'''
e_new = '''  # 既存 c3.json
  _ap_c3="$_ap_dir/approvals/c3.json"
  # TASK-0139 AC-04: abort if c3.json exists and --force not given
  # 承認記録の不可逆性を保護する（既存承認の無断上書き禁止）。
  if [ -f "$_ap_c3" ] && [ "$_ap_force" = "false" ]; then
    printf 'error: existing c3.json found for %s; use --force to overwrite\\n' "$_ap_task" >&2
    return 2
  fi'''
if e_old in new:
    new = new.replace(e_old, e_new, 1)
    sys.stderr.write("  (e) c3.json overwrite block applied\n")
elif "TASK-0139 AC-04" in new:
    sys.stderr.write("  (e) c3.json overwrite block: already applied\n")
else:
    sys.exit("ERROR: c3.json overwrite anchor not found in bin/plangate")

if dry:
    diff = difflib.unified_diff(src.splitlines(True), new.splitlines(True),
                                fromfile="bin/plangate", tofile="bin/plangate (after)")
    sys.stdout.write("".join(diff))
    sys.stderr.write("\n[dry-run] 上記差分。適用するには --dry-run なしで実行。\n")
else:
    open(target, "w", encoding="utf-8").write(new)
    sys.stderr.write("[applied] TASK-0139 ハードニングを bin/plangate に適用しました。\n")
PY
