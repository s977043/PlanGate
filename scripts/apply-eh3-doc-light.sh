#!/bin/sh
# scripts/apply-eh3-doc-light.sh — check-plan-hash.sh に doc-light 経路を追加（TASK-0138）
#
# check-plan-hash.sh は Hardening Override 対象のため AI が本スクリプトを生成し、
# --apply は Human が実行する（docs/ai/responsibility-classes.md AI/Human 分界）。
#
# 使い方:
#   sh scripts/apply-eh3-doc-light.sh --dry-run   # 差分確認（変更なし）
#   sh scripts/apply-eh3-doc-light.sh --apply     # 適用（冪等）
set -eu
MODE="${1:---dry-run}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOK="$ROOT/scripts/hooks/check-plan-hash.sh"

[ -f "$HOOK" ] || { printf 'ERROR: %s not found\n' "$HOOK" >&2; exit 1; }

# 冪等性チェック
if grep -q 'EH-3_DOC_LIGHT_SKIP' "$HOOK" 2>/dev/null; then
  printf 'SKIP (already applied): doc-light 経路は既に存在します\n'
  exit 0
fi

# アンカー検証
if ! grep -qF '# (iii)-(v) maintenance valid' "$HOOK"; then
  printf 'ERROR: アンカー行が見つかりません（hook 構造が変化している可能性あり）\n' >&2
  exit 1
fi

DOC_LIGHT_BLOCK='
  # [TASK-0138] doc-light 経路: 非 HO .md ファイルを記録付き自動 SKIP
  # HO 判定後（_override=0 が確定）かつ maintenance 判定前に評価。
  # 拡張子判定: POSIX case 文（外部プロセス不要・大文字小文字非感応・false positive 防止）
  case "$_norm_target" in
    *.[mM][dD])
    _dlog_dl="$WORKING_DIR/_audit/skip-decision-log.jsonl"
    mkdir -p "$(dirname "$_dlog_dl")"
    _ts_dl=$(date -u '"'"'+%Y-%m-%dT%H:%M:%SZ'"'"')
    _esc_dl=$(printf '"'"'%s'"'"' "${_norm_target:-unknown}" | sed '"'"'s/\\/\\\\/g; s/"/\\"/g'"'"' | tr -d '"'"'\n\r\t'"'"')
    printf '"'"'{"ts":"%s","event":"EH-3_DOC_LIGHT_SKIP","target":"%s","acknowledged_by":null,"acknowledged_at":null}\n'"'"' "$_ts_dl" "$_esc_dl" >>"$_dlog_dl"
      reason="DOC_LIGHT_SKIP: non-HO .md target (${_norm_target:-unknown}) — auto-skipped"
      log_event "DOC_LIGHT_SKIP" "$reason"
      printf '"'"'[Hook EH-3 DOC_LIGHT_SKIP] %s\n'"'"' "$reason"
      exit 0
    ;;
  esac

'

if [ "$MODE" = "--dry-run" ]; then
  printf '[dry-run] HO 判定直後・maintenance 判定前に以下のブロックを挿入します:\n\n'
  printf '%s\n' "$DOC_LIGHT_BLOCK"
  exit 0
elif [ "$MODE" = "--apply" ]; then
  python3 - "$HOOK" "$DOC_LIGHT_BLOCK" << 'PY'
import sys, pathlib
hook = pathlib.Path(sys.argv[1])
block = sys.argv[2]
anchor = '  # (iii)-(v) maintenance valid'
content = hook.read_text(encoding='utf-8')
if anchor not in content:
    print('ERROR: anchor not found', file=sys.stderr); sys.exit(1)
hook.write_text(content.replace(anchor, block + anchor, 1), encoding='utf-8')
print('APPLIED: doc-light block inserted')
PY
  printf '次のステップ: sh tests/extras/ta-39-eh3-doc-light.sh\n'
else
  printf 'usage: %s [--dry-run|--apply]\n' "$0" >&2; exit 1
fi
