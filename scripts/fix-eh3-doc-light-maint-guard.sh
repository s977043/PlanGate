#!/bin/sh
# scripts/fix-eh3-doc-light-maint-guard.sh
# TASK-0138 フォロー: doc-light ブロックを maintenance ファイル非存在条件付きに修正
#
# 問題: 現在の doc-light が maintenance チェック前に発火するため、
#   一-shot トークン消費・スコープチェック・TTL 期限切れ検証が迂回される（TA-12 7件 FAIL）
# 修正: _maint 存在チェックを追加し、maintenance ファイルがある場合は doc-light を発火させない
#
# ⚠️ 退役済み（#1101 / TASK-1101）
#   適用完了済みで以後 **no-op**（冪等判定 `grep -q '! -f "$_maint"'` が真 →
#   "SKIP (already fixed)"）。ただし `old` / `new` に **`_norm_target` を含む
#   当時のブロックを verbatim 保持**しており、#1101 以降は stale なスナップ
#   ショットである（HO 判定は `_ho_key` を見る形に変わった）。
#   → **本スクリプトを新規に実行しないこと**。
#   実測（#1101 exec / sandbox）: #1101 適用後の hook に対して `--dry-run` /
#   `--apply` とも rc=0「SKIP (already fixed)」で **ファイルを変更しない**。
#
# 使い方:
#   sh scripts/fix-eh3-doc-light-maint-guard.sh --dry-run
#   sh scripts/fix-eh3-doc-light-maint-guard.sh --apply
set -eu
MODE="${1:---dry-run}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOK="$ROOT/scripts/hooks/check-plan-hash.sh"

[ -f "$HOOK" ] || { printf 'ERROR: %s not found\n' "$HOOK" >&2; exit 1; }

# 冪等性チェック: 修正済みか確認
if grep -q '! -f "\$_maint"' "$HOOK" 2>/dev/null; then
  printf 'SKIP (already fixed): maintenance guard already present\n'
  exit 0
fi

# 旧ブロックの存在確認
if ! grep -q '# \[TASK-0138\] doc-light path:' "$HOOK"; then
  printf 'ERROR: TASK-0138 doc-light block not found in hook\n' >&2
  exit 1
fi
if ! grep -q '# (iii)-(v) maintenance valid' "$HOOK"; then
  printf 'ERROR: maintenance anchor not found\n' >&2
  exit 1
fi

if [ "$MODE" = "--dry-run" ]; then
  printf '[dry-run] 以下の修正を適用します:\n'
  printf '  - doc-light ブロックを _maint 定義後に移動\n'
  printf '  - [ ! -f "$_maint" ] で maintenance 非存在時のみ発火するよう変更\n'
  exit 0
elif [ "$MODE" = "--apply" ]; then
  python3 - "$HOOK" << 'PY'
import sys, pathlib

hook = pathlib.Path(sys.argv[1])
content = hook.read_text(encoding='utf-8')

old = (
    '  # [TASK-0138] doc-light path: auto-SKIP for non-HO .md files\n'
    '  # Inserted after HO check (_override=0 confirmed), before maintenance check.\n'
    "  _dl_ext=$(printf '%s' \"$_norm_target\" | sed 's/.*\\.//; y/ABCDEFGHIJKLMNOPQRSTUVWXYZ/abcdefghijklmnopqrstuvwxyz/')\n"
    '  if [ "$_dl_ext" = "md" ]; then\n'
    '    _dlog_dl="$WORKING_DIR/_audit/skip-decision-log.jsonl"\n'
    '    mkdir -p "$(dirname "$_dlog_dl")"\n'
    "    _ts_dl=$(date -u '+%Y-%m-%dT%H:%M:%SZ')\n"
    "    _esc_dl=$(printf '%s' \"${_norm_target:-unknown}\" | tr -d '\\n\\r\\t')\n"
    '    printf \'{"ts":"%s","event":"EH-3_DOC_LIGHT_SKIP","target":"%s","acknowledged_by":null,"acknowledged_at":null}\\n\' "$_ts_dl" "$_esc_dl" >>"$_dlog_dl"\n'
    '    reason="DOC_LIGHT_SKIP: non-HO .md target (${_norm_target:-unknown}) -- auto-skipped"\n'
    '    log_event "DOC_LIGHT_SKIP" "$reason"\n'
    '    printf \'[Hook EH-3 DOC_LIGHT_SKIP] %s\\n\' "$reason"\n'
    '    exit 0\n'
    '  fi\n'
    '\n'
    '  # (iii)-(v) maintenance valid + scope + one-shot atomic consume\n'
    '  _maint="$REPO_ROOT/docs/working/_maintenance/maintenance.json"\n'
    '  if [ -f "$_maint" ]; then\n'
)

new = (
    '  # (iii)-(v) maintenance valid + scope + one-shot atomic consume\n'
    '  _maint="$REPO_ROOT/docs/working/_maintenance/maintenance.json"\n'
    '  # [TASK-0138] doc-light path: auto-SKIP for non-HO .md files\n'
    '  # maintenance ファイルが存在する場合は token ライフサイクル（one-shot 消費等）を優先し\n'
    '  # doc-light は発火させない。no-maint 時のみ非 HO .md を記録付き自動 SKIP。\n'
    '  if [ ! -f "$_maint" ]; then\n'
    "    _dl_ext=$(printf '%s' \"$_norm_target\" | sed 's/.*\\.//; y/ABCDEFGHIJKLMNOPQRSTUVWXYZ/abcdefghijklmnopqrstuvwxyz/')\n"
    '    if [ "$_dl_ext" = "md" ]; then\n'
    '      _dlog_dl="$WORKING_DIR/_audit/skip-decision-log.jsonl"\n'
    '      mkdir -p "$(dirname "$_dlog_dl")"\n'
    "      _ts_dl=$(date -u '+%Y-%m-%dT%H:%M:%SZ')\n"
    "      _esc_dl=$(printf '%s' \"${_norm_target:-unknown}\" | tr -d '\\n\\r\\t')\n"
    '      printf \'{"ts":"%s","event":"EH-3_DOC_LIGHT_SKIP","target":"%s","acknowledged_by":null,"acknowledged_at":null}\\n\' "$_ts_dl" "$_esc_dl" >>"$_dlog_dl"\n'
    '      reason="DOC_LIGHT_SKIP: non-HO .md target (${_norm_target:-unknown}) -- auto-skipped"\n'
    '      log_event "DOC_LIGHT_SKIP" "$reason"\n'
    '      printf \'[Hook EH-3 DOC_LIGHT_SKIP] %s\\n\' "$reason"\n'
    '      exit 0\n'
    '    fi\n'
    '  fi\n'
    '  if [ -f "$_maint" ]; then\n'
)

if old not in content:
    print('ERROR: expected old block not found', file=sys.stderr)
    sys.exit(1)

hook.write_text(content.replace(old, new, 1), encoding='utf-8')
print('APPLIED: doc-light now fires only when no maintenance file present')
PY
  printf '次のステップ: sh tests/run-tests.sh\n'
else
  printf 'usage: %s [--dry-run|--apply]\n' "$0" >&2; exit 1
fi
