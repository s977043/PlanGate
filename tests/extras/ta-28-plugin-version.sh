# tests/extras/ta-28-plugin-version.sh
# Sourced by tests/run-tests.sh — uses $pass / $fail counters
# #453: plugin.json version が最新 release tag と一致することを検証

printf '\n=== TA-28: plugin-version (#453) ===\n'

PG_T28_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
PG_T28_SCRIPT="$PG_T28_ROOT/scripts/check-plugin-version.sh"
PG_T28_JSON="$PG_T28_ROOT/plugin/plangate/.claude-plugin/plugin.json"

t28_pass() { pass=$((pass + 1)); printf '  [PASS] %s\n' "$1"; }
t28_fail() { fail=$((fail + 1)); printf '  [FAIL] %s\n' "$1" >&2; }

# TC-01: スクリプト存在・実行可能
if [ -f "$PG_T28_SCRIPT" ] && [ -x "$PG_T28_SCRIPT" ]; then
  t28_pass "TC-01 check-plugin-version.sh 存在・実行可能"
else
  t28_fail "TC-01 不在 or 非実行可能"
fi

# TC-02: sh -n syntax
if sh -n "$PG_T28_SCRIPT" 2>/dev/null; then
  t28_pass "TC-02 sh -n syntax check"
else
  t28_fail "TC-02 syntax error"
fi

# TC-03: plugin.json に version フィールドが存在
if grep -q '"version"' "$PG_T28_JSON" 2>/dev/null; then
  t28_pass "TC-03 plugin.json に version あり"
else
  t28_fail "TC-03 plugin.json に version なし"
fi

# TC-04: --warn-only は不一致でも exit 0
if sh "$PG_T28_SCRIPT" --warn-only >/dev/null 2>&1; then
  t28_pass "TC-04 --warn-only は exit 0"
else
  t28_fail "TC-04 --warn-only が exit 非0"
fi

# TC-05: version が v プレフィックスを持たない（8.11.0 形式）
_t28_ver=$(python3 -c "import json; print(json.load(open('$PG_T28_JSON'))['version'])" 2>/dev/null || printf '')
case "${_t28_ver:-}" in
  v*) t28_fail "TC-05 plugin.json version に v プレフィックス（${_t28_ver:-}）" ;;
  "") t28_fail "TC-05 plugin.json version 取得失敗" ;;
  *)  t28_pass "TC-05 plugin.json version は v プレフィックスなし（${_t28_ver:-}）" ;;
esac

# TC-06: marketplace.json に plangate plugin の version フィールドが存在（#456）
PG_T28_MP="$PG_T28_ROOT/.claude-plugin/marketplace.json"
_t28_mpver=$(python3 - "$PG_T28_MP" << 'PYMP' 2>/dev/null || printf ''
import json, sys
try:
    d = json.load(open(sys.argv[1], encoding='utf-8'))
    for plug in d.get('plugins', []):
        if plug.get('name') == 'plangate':
            print(plug.get('version', '')); break
except Exception:
    print('')
PYMP
)
if [ -n "${_t28_mpver:-}" ]; then
  t28_pass "TC-06 marketplace.json に plangate version あり（${_t28_mpver:-}）"
else
  t28_fail "TC-06 marketplace.json に plangate version なし"
fi

# TC-07: plugin.json version == marketplace.json version（二重管理 drift なし / #456）
if [ -n "${_t28_ver:-}" ] && [ "${_t28_ver:-}" = "${_t28_mpver:-}" ]; then
  t28_pass "TC-07 plugin.json (${_t28_ver:-}) = marketplace.json (${_t28_mpver:-}) — version drift なし"
else
  t28_fail "TC-07 version drift: plugin.json=${_t28_ver:-} / marketplace.json=${_t28_mpver:-}"
fi

# TC-08: marketplace.json mismatch で exit 1（negative / 本体の動的分岐検証 / レビュー major）
# tag 不在環境（shallow clone 等）では検証不能のためスキップ。実ファイルは即復元。
_t28_tag=$(git -C "$PG_T28_ROOT" describe --tags --abbrev=0 2>/dev/null || printf '')
_t28_mp="$PG_T28_ROOT/.claude-plugin/marketplace.json"
if [ -n "$_t28_tag" ] && [ -f "$_t28_mp" ]; then
  # 実 tracked file（marketplace.json）を一時改変するため、トラップをサブシェルに
  # 閉じ込めて親シェル（run-tests.sh）の trap を汚染せず、かつ set -e 中断 /
  # Ctrl-C 時もサブシェル EXIT トラップで確実に復元する。判定は stdout の 0/1 で返す。
  _t28_neg=$(
    _bak=$(mktemp)
    cp "$_t28_mp" "$_bak"
    trap 'cp "$_bak" "$_t28_mp" 2>/dev/null; rm -f "$_bak"' EXIT INT TERM
    python3 - "$_t28_mp" << 'PYBREAK' 2>/dev/null || true
import json, sys
d = json.load(open(sys.argv[1], encoding='utf-8'))
for plug in d.get('plugins', []):
    if plug.get('name') == 'plangate':
        plug['version'] = '0.0.0-ta28test'
json.dump(d, open(sys.argv[1], 'w', encoding='utf-8'), indent=2, ensure_ascii=False)
open(sys.argv[1], 'a', encoding='utf-8').write('\n')
PYBREAK
    if sh "$PG_T28_SCRIPT" >/dev/null 2>&1; then printf 0; else printf 1; fi
  )
  if [ "$_t28_neg" = "1" ]; then
    t28_pass "TC-08 marketplace.json mismatch で exit 1（動的分岐）"
  else
    t28_fail "TC-08 mismatch なのに exit 0（検出漏れ）"
  fi
else
  t28_pass "TC-08 SKIP（tag 不在 or marketplace.json なし）"
fi

# TC-09: tag 不在（shallow clone 相当）で WARN + exit 0（#476 / 運用の穴を固定）
# PLANGATE_REPO_ROOT を tag の無い一時 git repo に向け、LATEST_TAG 空時の挙動を検証。
# TC-08 同様、trap をサブシェルに閉じ込めて親シェル（run-tests.sh）を汚染せず、
# 中断時も一時ディレクトリを確実に掃除する。判定は stdout で返す。
_t28_res=$(
  _sh=$(mktemp -d) || exit 9
  trap 'rm -rf "$_sh"' EXIT INT TERM
  mkdir -p "$_sh/plugin/plangate/.claude-plugin" "$_sh/.claude-plugin"
  printf '{"version":"8.11.0"}\n' > "$_sh/plugin/plangate/.claude-plugin/plugin.json"
  printf '{"plugins":[{"name":"plangate","version":"8.11.0"}]}\n' > "$_sh/.claude-plugin/marketplace.json"
  ( cd "$_sh" && git init -q 2>/dev/null )  # tag を作らない → describe 失敗
  if PLANGATE_REPO_ROOT="$_sh" sh "$PG_T28_SCRIPT" 2>&1 | grep -q 'tag が見つかりません' \
     && PLANGATE_REPO_ROOT="$_sh" sh "$PG_T28_SCRIPT" >/dev/null 2>&1; then
    printf PASS
  else
    printf FAIL
  fi
)
if [ "$_t28_res" = "PASS" ]; then
  t28_pass "TC-09 tag 不在で WARN + exit 0（shallow clone 相当）"
elif [ "$_t28_res" = "FAIL" ]; then
  t28_fail "TC-09 tag 不在時の WARN/exit 0 が成立しない"
else
  t28_fail "TC-09 一時 repo 作成失敗（mktemp）"
fi
