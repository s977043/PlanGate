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

# アンカー検証（_maint 定義行の存在確認）
if ! grep -qF '_maint="$REPO_ROOT/docs/working/_maintenance/maintenance.json"' "$HOOK"; then
  printf 'ERROR: アンカー行が見つかりません（hook 構造が変化している可能性あり）\n' >&2
  exit 1
fi

# doc-light ブロック: _maint 定義直後に挿入し、maintenance ガード付きで発火
# _maint 未定義の状態で評価されないよう _maint="..." の後ろに配置する（Gemini HIGH）
DOC_LIGHT_BLOCK='
  # [TASK-0138] doc-light 経路: 非 HO .md ファイルを記録付き自動 SKIP
  # maintenance ファイルが存在する場合は token ライフサイクルを優先し doc-light を発火させない。
  # no-maint 時のみ非 HO .md を記録付き自動 SKIP（POSIX case 文で拡張子判定）。
  if [ ! -f "$_maint" ]; then
    case "$_norm_target" in
      *.[mM][dD])
        _dlog_dl="$WORKING_DIR/_audit/skip-decision-log.jsonl"
        mkdir -p "$(dirname "$_dlog_dl")"
        _ts_dl=$(date -u '"'"'+%Y-%m-%dT%H:%M:%SZ'"'"')
        _esc_dl=$(printf '"'"'%s'"'"' "${_norm_target:-unknown}" | tr -d '"'"'\n\r\t'"'"')
        printf '"'"'{"ts":"%s","event":"EH-3_DOC_LIGHT_SKIP","target":"%s","acknowledged_by":null,"acknowledged_at":null}\n'"'"' "$_ts_dl" "$_esc_dl" >>"$_dlog_dl"
        reason="DOC_LIGHT_SKIP: non-HO .md target (${_norm_target:-unknown}) — auto-skipped"
        log_event "DOC_LIGHT_SKIP" "$reason"
        printf '"'"'[Hook EH-3 DOC_LIGHT_SKIP] %s\n'"'"' "$reason"
        exit 0
        ;;
    esac
  fi
'

if [ "$MODE" = "--dry-run" ]; then
  printf '[dry-run] _maint 定義直後に以下のブロックを挿入します:\n\n'
  printf '%s\n' "$DOC_LIGHT_BLOCK"
  exit 0
elif [ "$MODE" = "--apply" ]; then
  python3 - "$HOOK" "$DOC_LIGHT_BLOCK" << 'PY'
import sys, pathlib
hook = pathlib.Path(sys.argv[1])
block = sys.argv[2]
anchor = '  _maint="$REPO_ROOT/docs/working/_maintenance/maintenance.json"'
content = hook.read_text(encoding='utf-8')
if anchor not in content:
    print('ERROR: anchor not found', file=sys.stderr); sys.exit(1)
hook.write_text(content.replace(anchor, anchor + '\n' + block, 1), encoding='utf-8')
print('APPLIED: doc-light block inserted after _maint definition')
PY
  printf '次のステップ: sh tests/extras/ta-39-eh3-doc-light.sh\n'
else
  printf 'usage: %s [--dry-run|--apply]\n' "$0" >&2; exit 1
fi
