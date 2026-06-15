#!/bin/sh
# apply-task-0128-p0-hardening.sh — #550 P0（approve 承認境界の最小ハードニング）
# bin/plangate の cmd_approve / _plangate_presence_gate を強化する。
#
# bin/plangate は Hardening Override 対象のため AI は直接編集できない。本スクリプトを
# AI が用意し、Human が dry-run 確認のうえ適用する（責務4分類: HO 実適用は Human）。
#
# 変更（approve 経路のみ・maintenance は不変）:
#   (a) _plangate_presence_gate の PLANGATE_FAKE_PPID_COMM を PLANGATE_TEST_MODE=1 時のみ有効化
#       （本番経路で L3 を env で上書きできる穴を塞ぐ / #550 Codex review）
#   (b) cmd_approve の対話 read を read -r 化（バックスラッシュのエスケープ防止 / gemini #546）
#
# 注: (c) c3.json 上書き既定拒否（plan_hash 変化時自動許可）は plan_hash 計算の再順序を
#     要するため P0.5 として別途（本スクリプト対象外・#550 ノート参照）。
#
# 使い方:
#   sh scripts/apply-task-0128-p0-hardening.sh --dry-run
#   sh scripts/apply-task-0128-p0-hardening.sh
#
# 冪等: 既に適用済み（PLANGATE_TEST_MODE ガードが presence gate にある）なら何もしない。
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

grep -q 'cmd_approve()' "$TARGET" || { echo "ERROR: cmd_approve が見つかりません（#546 未適用？）"; exit 1; }

# 冪等: 既に P0 適用済み（test-mode gate コメントが presence gate にある）なら何もしない
if grep -q 'PLANGATE_TEST_MODE=1 のときのみ honor する（#550 P0）' "$TARGET"; then
  echo "SKIP: #550 P0 は既に適用済み"; exit 0
fi

python3 - "$TARGET" "$DRY_RUN" <<'PY'
import sys, difflib
target, dry = sys.argv[1], sys.argv[2] == "1"
src = open(target, encoding='utf-8').read()
new = src

# (a) presence gate の FAKE_PPID を test-mode gate 化（approve 経路 = _plangate_presence_gate 内のみ）
#     maintenance(cmd_maintenance) の同一行は対象外にするため、_plangate_presence_gate 内の文脈で置換。
gate_old = '''  _pcomm=$(ps -p $PPID -o comm= 2>/dev/null | tr -d ' ')
  if [ -n "${PLANGATE_FAKE_PPID_COMM:-}" ]; then _pcomm="$PLANGATE_FAKE_PPID_COMM"; fi
  if printf '%s' "$_pcomm" | grep -iqE 'claude|codex|cursor'; then
    _pg_audit reject_L3 "ppid comm=$_pcomm"'''
gate_new = '''  _pcomm=$(ps -p $PPID -o comm= 2>/dev/null | tr -d ' ')
  # PLANGATE_FAKE_PPID_COMM はテスト専用注入。本番経路で L3 を上書きされる穴を塞ぐため
  # PLANGATE_TEST_MODE=1 のときのみ honor する（#550 P0）。
  if [ "${PLANGATE_TEST_MODE:-0}" = "1" ] && [ -n "${PLANGATE_FAKE_PPID_COMM:-}" ]; then _pcomm="$PLANGATE_FAKE_PPID_COMM"; fi
  if printf '%s' "$_pcomm" | grep -iqE 'claude|codex|cursor'; then
    _pg_audit reject_L3 "ppid comm=$_pcomm"'''
assert gate_old in new, "presence gate L3 anchor not found"
new = new.replace(gate_old, gate_new, 1)

# (b) cmd_approve の対話 read → read -r
b1_old = "if [ -t 0 ]; then printf 'rejection reason> '; read _ap_reason || _ap_reason=\"\"; fi"
b1_new = "if [ -t 0 ]; then printf 'rejection reason> '; read -r _ap_reason || _ap_reason=\"\"; fi"
assert b1_old in new, "read _ap_reason anchor not found"
new = new.replace(b1_old, b1_new, 1)
b2_old = "if [ -t 0 ]; then printf 'conditions> '; read _ap_conditions || _ap_conditions=\"\"; fi"
b2_new = "if [ -t 0 ]; then printf 'conditions> '; read -r _ap_conditions || _ap_conditions=\"\"; fi"
assert b2_old in new, "read _ap_conditions anchor not found"
new = new.replace(b2_old, b2_new, 1)

if dry:
    sys.stdout.write("".join(difflib.unified_diff(src.splitlines(True), new.splitlines(True),
        fromfile="bin/plangate", tofile="bin/plangate (after)")))
    sys.stderr.write("\n[dry-run] 上記差分。\n")
else:
    open(target, 'w', encoding='utf-8').write(new)
    sys.stderr.write("[applied] #550 P0 ハードニングを bin/plangate に適用しました。\n")
PY
