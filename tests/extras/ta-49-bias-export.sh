# tests/extras/ta-49-bias-export.sh
# Sourced by tests/run-tests.sh — uses $pass / $fail counters
# TASK-0147 (#527 follow-up): validation_bias の conductor export 配線
#
# 2 層:
#   A. _resolve_validation_bias.py の機能テスト（常時実行・AI-owned ヘルパー）
#   B. bin/plangate 配線テスト（HO 未適用時は SKIP）
#      前提: scripts/apply-task-0147-bias-export.sh --apply で適用済み。

printf '\n=== TA-49: validation_bias conductor export (#527 TASK-0147) ===\n'

if [ -n "${FIXTURES_DIR:-}" ]; then
  _T49_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
else
  _T49_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
fi
_T49_PG="$_T49_ROOT/bin/plangate"
_T49_RESOLVE="$_T49_ROOT/scripts/_resolve_validation_bias.py"
_T49_YAML="$_T49_ROOT/docs/ai/model-profiles.yaml"

# ---- 層 A: resolver helper（常時実行）-------------------------------------

# strict profile key を yaml から取得（存在すれば）
_T49_STRICT_KEY=$(python3 -c "
import yaml,sys
try:
    d=yaml.safe_load(open('$_T49_YAML'))
    ks=[k for k,v in (d.get('models') or {}).items() if isinstance(v,dict) and v.get('validation_bias')=='strict']
    print(ks[0] if ks else '')
except Exception:
    print('')
" 2>/dev/null)

# TC-01: strict profile → strict
if [ -n "$_T49_STRICT_KEY" ] && [ "$(python3 "$_T49_RESOLVE" "$_T49_STRICT_KEY" "$_T49_YAML" 2>/dev/null)" = "strict" ]; then
  printf '  [PASS] TC-01 strict profile (%s) → strict\n' "$_T49_STRICT_KEY"; pass=$((pass + 1))
else
  printf '  [FAIL] TC-01 strict profile 解決失敗\n'; fail=$((fail + 1))
fi

# TC-02: normal profile / 既定 → strict にならない
if [ "$(python3 "$_T49_RESOLVE" gpt-5_5 "$_T49_YAML" 2>/dev/null)" = "normal" ]; then
  printf '  [PASS] TC-02 normal profile は strict にならない\n'; pass=$((pass + 1))
else
  printf '  [FAIL] TC-02 normal profile 解決異常\n'; fail=$((fail + 1))
fi

# TC-04: 未知 key → normal fallback + stderr 警告
_t49_out=$(python3 "$_T49_RESOLVE" __nope__ "$_T49_YAML" 2>/tmp/ta49_err); _t49_err=$(cat /tmp/ta49_err 2>/dev/null)
if [ "$_t49_out" = "normal" ] && printf '%s' "$_t49_err" | grep -q "WARN"; then
  printf '  [PASS] TC-04 未知 key は normal fallback + stderr 警告\n'; pass=$((pass + 1))
else
  printf '  [FAIL] TC-04 未知 key の安全側 fallback/警告 欠落\n'; fail=$((fail + 1))
fi

# TC-06: yaml 欠落 → normal fallback + stderr 警告
_t49_out2=$(python3 "$_T49_RESOLVE" gpt-5_5 /no/such/file.yaml 2>/tmp/ta49_err2); _t49_err2=$(cat /tmp/ta49_err2 2>/dev/null)
if [ "$_t49_out2" = "normal" ] && printf '%s' "$_t49_err2" | grep -q "WARN"; then
  printf '  [PASS] TC-06 yaml 欠落は normal fallback + stderr 警告\n'; pass=$((pass + 1))
else
  printf '  [FAIL] TC-06 yaml 欠落の安全側 fallback/警告 欠落\n'; fail=$((fail + 1))
fi
rm -f /tmp/ta49_err /tmp/ta49_err2 2>/dev/null

# ---- 層 B: bin/plangate 配線（未適用なら SKIP）---------------------------

if ! grep -q "TASK-0147" "$_T49_PG" 2>/dev/null; then
  printf '  [SKIP] TC-03/TC-05 bin/plangate 未適用（sh scripts/apply-task-0147-bias-export.sh --apply で適用後に PASS）\n'
  return 0 2>/dev/null || true
fi

# TC-03: env 既設定を上書きしない（明示注入尊重）— 配線コードに既定尊重ガードが存在
if grep -q 'PLANGATE_VALIDATION_BIAS:-}" ] && \[ -n' "$_T49_PG" 2>/dev/null \
   || grep -q '\[ -z "${PLANGATE_VALIDATION_BIAS:-}" \]' "$_T49_PG" 2>/dev/null; then
  printf '  [PASS] TC-03 env 既設定尊重ガード（上書きしない）配線\n'; pass=$((pass + 1))
else
  printf '  [FAIL] TC-03 env 尊重ガードの配線欠落\n'; fail=$((fail + 1))
fi

# TC-05: patched bin/plangate 構文健全
if sh -n "$_T49_PG" 2>/dev/null; then
  printf '  [PASS] TC-05 patched bin/plangate 構文健全\n'; pass=$((pass + 1))
else
  printf '  [FAIL] TC-05 構文エラー\n'; fail=$((fail + 1))
fi
