# tests/extras/ta-66-codex-plugin-manifest.sh
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
#   TC-09: 負側 — 両マニフェストから同じフィールドが消えた状態を一致扱いにしない

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
pg_extra_contract_init ta-66-codex-plugin-manifest standalone-capable

# ta-26 TC-33（静的検査 / README 規約 8）準拠
if pg_extra_contract_is_standalone; then
  unset PLANGATE_SKIP_REASON PLANGATE_HOOK_TASK PLANGATE_HOOK_FILE PLANGATE_BYPASS_HOOK PLANGATE_HOOK_STRICT PG_HARNESS_SOURCED PLANGATE_ALLOW_MASS_DELETE 2>/dev/null || true
fi

printf '\n=== TA-66: codex plugin manifest parity (#1085) ===\n'

t66_pass() { pass=$((pass + 1)); printf '  [PASS] %s\n' "$1"; }
t66_fail() { fail=$((fail + 1)); printf '  [FAIL] %s\n' "$1" >&2; }

_T66_ROOT="$(CDPATH= cd -- "$_pg_extra_dir/../.." && pwd)"
_T66_PLUGIN="$_T66_ROOT/plugin/plangate"
_T66_CODEX="$_T66_PLUGIN/.codex-plugin/plugin.json"
_T66_CLAUDE="$_T66_PLUGIN/.claude-plugin/plugin.json"
_T66_SCRIPT="$_T66_ROOT/scripts/check-plugin-manifest-parity.sh"

if ! command -v python3 >/dev/null 2>&1; then
  pg_extra_contract_skip "python3 未導入のため TA-66 を skip"
  return 0
fi

# === TC-01 Codex マニフェストの存在と JSON 妥当性 ===
if [ -f "$_T66_CODEX" ] && python3 -c 'import json,sys; json.load(open(sys.argv[1],encoding="utf-8"))' "$_T66_CODEX" 2>/dev/null; then
  t66_pass "TC-01 .codex-plugin/plugin.json が存在し JSON として parse 可能"
else
  t66_fail "TC-01 .codex-plugin/plugin.json が不在 or JSON 不正: $_T66_CODEX"
fi

# === TC-02 parity checker の存在 ===
if [ -f "$_T66_SCRIPT" ] && [ -x "$_T66_SCRIPT" ]; then
  t66_pass "TC-02 check-plugin-manifest-parity.sh が存在し実行可能"
else
  t66_fail "TC-02 check-plugin-manifest-parity.sh が不在 or 非実行可能: $_T66_SCRIPT"
fi

# === TC-03 実リポジトリで一致 ===
_t66_rc3=0
_t66_out3=$(sh "$_T66_SCRIPT" "$_T66_PLUGIN" 2>&1) || _t66_rc3=$?
if [ "$_t66_rc3" -eq 0 ]; then
  t66_pass "TC-03 実リポジトリの 2 マニフェストが一致"
else
  t66_fail "TC-03 不一致を検出 (rc=$_t66_rc3): $(printf '%s' "$_t66_out3" | tr '\n' ';')"
fi

# === 変異注入用の fixture（実マニフェストを複製して片方だけ壊す）===
_T66_TMP="$(mktemp -d)"
register_cleanup "$_T66_TMP"

_t66_make_fixture() {
  # $1 = fixture 名 / $2 = codex 側に適用する python 式（manifest 変数を書き換える）
  _f="$_T66_TMP/$1"
  mkdir -p "$_f/.claude-plugin" "$_f/.codex-plugin"
  cp "$_T66_CLAUDE" "$_f/.claude-plugin/plugin.json"
  python3 - "$_T66_CODEX" "$_f/.codex-plugin/plugin.json" "$2" << 'PYM'
import json, sys
src, dst, expr = sys.argv[1], sys.argv[2], sys.argv[3]
manifest = json.load(open(src, encoding='utf-8'))
exec(expr, {'manifest': manifest})
json.dump(manifest, open(dst, 'w', encoding='utf-8'))
PYM
  printf '%s' "$_f"
}

# === TC-04 負側: version 乖離 ===
_t66_f4=$(_t66_make_fixture mut-version "manifest['version'] = '0.0.1'")
_t66_rc4=0
_t66_out4=$(sh "$_T66_SCRIPT" "$_t66_f4" 2>&1) || _t66_rc4=$?
if [ "$_t66_rc4" -eq 1 ] && printf '%s' "$_t66_out4" | grep -q 'version'; then
  t66_pass "TC-04 負側: version 乖離を exit 1 で検出"
else
  t66_fail "TC-04 負側で検出できず (rc=$_t66_rc4, 期待 1): $(printf '%s' "$_t66_out4" | tr '\n' ';')"
fi

# === TC-05 負側: name 乖離 ===
_t66_f5=$(_t66_make_fixture mut-name "manifest['name'] = 'not-plangate'")
_t66_rc5=0
_t66_out5=$(sh "$_T66_SCRIPT" "$_t66_f5" 2>&1) || _t66_rc5=$?
if [ "$_t66_rc5" -eq 1 ] && printf '%s' "$_t66_out5" | grep -q 'name'; then
  t66_pass "TC-05 負側: name 乖離を exit 1 で検出"
else
  t66_fail "TC-05 負側で検出できず (rc=$_t66_rc5, 期待 1): $(printf '%s' "$_t66_out5" | tr '\n' ';')"
fi

# === TC-06 正側: skills パスの表記差は偽陽性にしない ===
_t66_f6=$(_t66_make_fixture same-skills "manifest['skills'] = 'skills'")
_t66_rc6=0
_t66_out6=$(sh "$_T66_SCRIPT" "$_t66_f6" 2>&1) || _t66_rc6=$?
if [ "$_t66_rc6" -eq 0 ]; then
  t66_pass "TC-06 正側: './skills/' と 'skills' の表記差を不一致にしない"
else
  t66_fail "TC-06 偽陽性 (rc=$_t66_rc6, 期待 0): $(printf '%s' "$_t66_out6" | tr '\n' ';')"
fi

# === TC-07 負側: Codex マニフェスト不在は exit 2（前提未充足を緑にしない）===
_t66_f7="$_T66_TMP/no-codex"
mkdir -p "$_t66_f7/.claude-plugin"
cp "$_T66_CLAUDE" "$_t66_f7/.claude-plugin/plugin.json"
_t66_rc7=0
sh "$_T66_SCRIPT" "$_t66_f7" >/dev/null 2>&1 || _t66_rc7=$?
if [ "$_t66_rc7" -eq 2 ]; then
  t66_pass "TC-07 負側: .codex-plugin/plugin.json 不在は exit 2"
else
  t66_fail "TC-07 不在時の rc が 2 でない (rc=$_t66_rc7)"
fi

# === TC-08 Codex validator の必須トップレベル項目 ===
_t66_rc8=0
cat > "$_T66_TMP/required-fields.py" << 'PYR'
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
_t66_out8=$(python3 "$_T66_TMP/required-fields.py" "$_T66_CODEX" 2>&1) || _t66_rc8=$?
if [ "$_t66_rc8" -eq 0 ]; then
  t66_pass "TC-08 Codex validator の必須項目が揃っている"
else
  t66_fail "TC-08 必須項目不足: $(printf '%s' "$_t66_out8" | tr '\n' ';')"
fi

# === TC-09 負側: 両マニフェストから同じフィールドが消えても緑にしない ===
# 単純な `left != right` 比較だけだと None == None で一致扱いになり、検査が
# 黙って空振りする（AC-5 で潰した「片側の事実だけ見て緑」と同型の no-op 退行）。
_t66_f9="$_T66_TMP/both-missing-skills"
mkdir -p "$_t66_f9/.claude-plugin" "$_t66_f9/.codex-plugin"
python3 - "$_T66_CLAUDE" "$_T66_CODEX" "$_t66_f9" << 'PYD'
import json, sys
src_claude, src_codex, dst = sys.argv[1], sys.argv[2], sys.argv[3]
for src, sub in ((src_claude, '.claude-plugin'), (src_codex, '.codex-plugin')):
    manifest = json.load(open(src, encoding='utf-8'))
    manifest.pop('skills', None)
    json.dump(manifest, open('%s/%s/plugin.json' % (dst, sub), 'w', encoding='utf-8'))
PYD
_t66_rc9=0
_t66_out9=$(sh "$_T66_SCRIPT" "$_t66_f9" 2>&1) || _t66_rc9=$?
if [ "$_t66_rc9" -eq 2 ] && printf '%s' "$_t66_out9" | grep -q 'MISSING FIELD'; then
  t66_pass "TC-09 負側: 両方に skills が無い状態を一致扱いにせず exit 2"
else
  t66_fail "TC-09 両方欠落を緑にしている (rc=$_t66_rc9, 期待 2): $(printf '%s' "$_t66_out9" | tr '\n' ';')"
fi

rm -rf "$_T66_TMP"

pg_extra_contract_finalize
