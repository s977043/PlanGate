# tests/extras/ta-65-codex-plugin-manifest.sh
# PG_EXTRA_CAPABILITY: standalone-capable
# Sourced by tests/run-tests.sh — uses $pass / $fail counters
# #1085: Codex 用 plugin マニフェスト `.codex-plugin/plugin.json` の存在と、
#        Claude 用 `.claude-plugin/plugin.json` との整合を機械検査する。
#
# 背景: plugin/plangate/ は Claude 用と Codex 用の 2 マニフェストを持つ。
#   手動二重管理では version が黙って乖離し、「片方だけ古い plugin」が配布される。
#   さらに Codex 公式 validator は `.codex-plugin/plugin.json` を required として
#   扱うため、不在だと validator ベースの検査すべてが素通り（bail out）する。
#   TC-01: .codex-plugin/plugin.json が存在し JSON として parse できる
#   TC-02: parity checker が存在し実行可能
#   TC-03: 実リポジトリで parity checker が exit 0
#   TC-04: 負側（変異注入）— version を片方だけずらすと exit 1
#   TC-05: 負側 — name を片方だけずらすと exit 1
#   TC-06: 正側 — `./skills/` と `skills` の表記差は不一致にしない（偽陽性ガード）
#   TC-07: 負側 — .codex-plugin/plugin.json 不在は exit 2（緑にしない）
#   TC-08: Codex validator の必須トップレベル項目が揃っている
#          （name / version / description / author.name / interface）

if [ "${PG_HARNESS_SOURCED:-0}" = "1" ] && [ -n "${FIXTURES_DIR:-}" ] && [ -n "${EXTRAS_DIR:-}" ]; then
  _pg_extra_mode=harness
  _pg_extra_dir="$EXTRAS_DIR"
else
  _pg_extra_mode=standalone
  _pg_extra_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
fi
_pg_extra_helper="$_pg_extra_dir/_extra-contract.sh"
if [ ! -r "$_pg_extra_helper" ]; then
  printf '  [FAIL] helper unresolved: %s\n' "$_pg_extra_helper" >&2
  if [ "$_pg_extra_mode" = harness ]; then
    fail=$((fail + 1))
    return 0
  fi
  exit 1
fi
. "$_pg_extra_helper"
pg_extra_contract_init ta-65-codex-plugin-manifest standalone-capable

# ta-26 TC-33（静的検査 / README 規約 8）準拠
if pg_extra_contract_is_standalone; then
  unset PLANGATE_SKIP_REASON PLANGATE_HOOK_TASK PLANGATE_HOOK_FILE PLANGATE_BYPASS_HOOK PLANGATE_HOOK_STRICT PG_HARNESS_SOURCED PLANGATE_ALLOW_MASS_DELETE 2>/dev/null || true
fi

printf '\n=== TA-65: codex plugin manifest parity (#1085) ===\n'

t65_pass() { pass=$((pass + 1)); printf '  [PASS] %s\n' "$1"; }
t65_fail() { fail=$((fail + 1)); printf '  [FAIL] %s\n' "$1" >&2; }

_T65_ROOT="$(CDPATH= cd -- "$_pg_extra_dir/../.." && pwd)"
_T65_PLUGIN="$_T65_ROOT/plugin/plangate"
_T65_CODEX="$_T65_PLUGIN/.codex-plugin/plugin.json"
_T65_CLAUDE="$_T65_PLUGIN/.claude-plugin/plugin.json"
_T65_SCRIPT="$_T65_ROOT/scripts/check-plugin-manifest-parity.sh"

if ! command -v python3 >/dev/null 2>&1; then
  pg_extra_contract_skip "python3 未導入のため TA-65 を skip"
  return 0
fi

# === TC-01 Codex マニフェストの存在と JSON 妥当性 ===
if [ -f "$_T65_CODEX" ] && python3 -c 'import json,sys; json.load(open(sys.argv[1],encoding="utf-8"))' "$_T65_CODEX" 2>/dev/null; then
  t65_pass "TC-01 .codex-plugin/plugin.json が存在し JSON として parse 可能"
else
  t65_fail "TC-01 .codex-plugin/plugin.json が不在 or JSON 不正: $_T65_CODEX"
fi

# === TC-02 parity checker の存在 ===
if [ -f "$_T65_SCRIPT" ] && [ -x "$_T65_SCRIPT" ]; then
  t65_pass "TC-02 check-plugin-manifest-parity.sh が存在し実行可能"
else
  t65_fail "TC-02 check-plugin-manifest-parity.sh が不在 or 非実行可能: $_T65_SCRIPT"
fi

# === TC-03 実リポジトリで一致 ===
_t65_rc3=0
_t65_out3=$(sh "$_T65_SCRIPT" "$_T65_PLUGIN" 2>&1) || _t65_rc3=$?
if [ "$_t65_rc3" -eq 0 ]; then
  t65_pass "TC-03 実リポジトリの 2 マニフェストが一致"
else
  t65_fail "TC-03 不一致を検出 (rc=$_t65_rc3): $(printf '%s' "$_t65_out3" | tr '\n' ';')"
fi

# === 変異注入用の fixture（実マニフェストを複製して片方だけ壊す）===
_T65_TMP="$(mktemp -d)"
register_cleanup "$_T65_TMP"

_t65_make_fixture() {
  # $1 = fixture 名 / $2 = codex 側に適用する python 式（manifest 変数を書き換える）
  _f="$_T65_TMP/$1"
  mkdir -p "$_f/.claude-plugin" "$_f/.codex-plugin"
  cp "$_T65_CLAUDE" "$_f/.claude-plugin/plugin.json"
  python3 - "$_T65_CODEX" "$_f/.codex-plugin/plugin.json" "$2" << 'PYM'
import json, sys
src, dst, expr = sys.argv[1], sys.argv[2], sys.argv[3]
manifest = json.load(open(src, encoding='utf-8'))
exec(expr, {'manifest': manifest})
json.dump(manifest, open(dst, 'w', encoding='utf-8'))
PYM
  printf '%s' "$_f"
}

# === TC-04 負側: version 乖離 ===
_t65_f4=$(_t65_make_fixture mut-version "manifest['version'] = '0.0.1'")
_t65_rc4=0
_t65_out4=$(sh "$_T65_SCRIPT" "$_t65_f4" 2>&1) || _t65_rc4=$?
if [ "$_t65_rc4" -eq 1 ] && printf '%s' "$_t65_out4" | grep -q 'version'; then
  t65_pass "TC-04 負側: version 乖離を exit 1 で検出"
else
  t65_fail "TC-04 負側で検出できず (rc=$_t65_rc4, 期待 1): $(printf '%s' "$_t65_out4" | tr '\n' ';')"
fi

# === TC-05 負側: name 乖離 ===
_t65_f5=$(_t65_make_fixture mut-name "manifest['name'] = 'not-plangate'")
_t65_rc5=0
_t65_out5=$(sh "$_T65_SCRIPT" "$_t65_f5" 2>&1) || _t65_rc5=$?
if [ "$_t65_rc5" -eq 1 ] && printf '%s' "$_t65_out5" | grep -q 'name'; then
  t65_pass "TC-05 負側: name 乖離を exit 1 で検出"
else
  t65_fail "TC-05 負側で検出できず (rc=$_t65_rc5, 期待 1): $(printf '%s' "$_t65_out5" | tr '\n' ';')"
fi

# === TC-06 正側: skills パスの表記差は偽陽性にしない ===
_t65_f6=$(_t65_make_fixture same-skills "manifest['skills'] = 'skills'")
_t65_rc6=0
_t65_out6=$(sh "$_T65_SCRIPT" "$_t65_f6" 2>&1) || _t65_rc6=$?
if [ "$_t65_rc6" -eq 0 ]; then
  t65_pass "TC-06 正側: './skills/' と 'skills' の表記差を不一致にしない"
else
  t65_fail "TC-06 偽陽性 (rc=$_t65_rc6, 期待 0): $(printf '%s' "$_t65_out6" | tr '\n' ';')"
fi

# === TC-07 負側: Codex マニフェスト不在は exit 2（前提未充足を緑にしない）===
_t65_f7="$_T65_TMP/no-codex"
mkdir -p "$_t65_f7/.claude-plugin"
cp "$_T65_CLAUDE" "$_t65_f7/.claude-plugin/plugin.json"
_t65_rc7=0
sh "$_T65_SCRIPT" "$_t65_f7" >/dev/null 2>&1 || _t65_rc7=$?
if [ "$_t65_rc7" -eq 2 ]; then
  t65_pass "TC-07 負側: .codex-plugin/plugin.json 不在は exit 2"
else
  t65_fail "TC-07 不在時の rc が 2 でない (rc=$_t65_rc7)"
fi

# === TC-08 Codex validator の必須トップレベル項目 ===
_t65_rc8=0
cat > "$_T65_TMP/required-fields.py" << 'PYR'
import json, sys
m = json.load(open(sys.argv[1], encoding='utf-8'))
missing = [k for k in ('name', 'version', 'description', 'interface') if not m.get(k)]
if not isinstance(m.get('author'), dict) or not m['author'].get('name'):
    missing.append('author.name')
iface = m.get('interface') if isinstance(m.get('interface'), dict) else {}
for k in ('displayName', 'shortDescription', 'longDescription', 'developerName', 'category'):
    if not iface.get(k):
        missing.append('interface.' + k)
if not isinstance(iface.get('capabilities'), list) or not iface['capabilities']:
    missing.append('interface.capabilities')
if 'defaultPrompt' not in iface and 'default_prompt' not in iface:
    missing.append('interface.defaultPrompt')
if missing:
    print('missing: ' + ', '.join(missing))
    raise SystemExit(1)
print('ok')
PYR
_t65_out8=$(python3 "$_T65_TMP/required-fields.py" "$_T65_CODEX" 2>&1) || _t65_rc8=$?
if [ "$_t65_rc8" -eq 0 ]; then
  t65_pass "TC-08 Codex validator の必須項目が揃っている"
else
  t65_fail "TC-08 必須項目不足: $(printf '%s' "$_t65_out8" | tr '\n' ';')"
fi

rm -rf "$_T65_TMP"

pg_extra_contract_finalize
