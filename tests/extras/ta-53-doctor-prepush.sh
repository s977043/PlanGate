# tests/extras/ta-53-doctor-prepush.sh
# PG_EXTRA_CAPABILITY: standalone-capable
# Sourced by tests/run-tests.sh -- uses $pass / $fail counters
# Issue #722: doctor pre-push gh account drift guard installation verification
#
# Sandbox: copy scripts/doctor_check.py + scripts/_paths.py into a tmp dir
# with a fake .git/hooks/pre-push so doctor_check.py's own REPO_ROOT
# resolution points into the sandbox (ta-39/ta-50 pattern).

# ---- extras execution contract bootstrap (#921) ----------------------------
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
pg_extra_contract_init ta-53-doctor-prepush standalone-capable

printf '\n=== TA-53: doctor pre-push guard installation verification (#722) ===\n'

if [ "${PG_HARNESS_SOURCED:-0}" = "1" ] && [ -n "${FIXTURES_DIR:-}" ]; then
  _T53_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
else
  # standalone 実行: 外部 env 汚染を無害化（tests/extras/README.md 規約 8。
  # unset 集合は run-tests.sh 冒頭と同一の 7 env — TASK-0914 論点 F）
  unset PLANGATE_SKIP_REASON PLANGATE_HOOK_TASK PLANGATE_HOOK_FILE PLANGATE_BYPASS_HOOK PLANGATE_HOOK_STRICT PG_HARNESS_SOURCED PLANGATE_ALLOW_MASS_DELETE 2>/dev/null || true
  _T53_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
fi

_T53_TMP=$(mktemp -d)
if command -v register_cleanup >/dev/null 2>&1; then
  register_cleanup "$_T53_TMP"
fi

mkdir -p "$_T53_TMP/scripts"
mkdir -p "$_T53_TMP/.git/hooks"
cp "$_T53_ROOT/scripts/doctor_check.py" "$_T53_TMP/scripts/doctor_check.py"
cp "$_T53_ROOT/scripts/_paths.py" "$_T53_TMP/scripts/_paths.py"

t53_pass() { pass=$((pass + 1)); printf '  [PASS] %s\n' "$1"; }
t53_fail() { fail=$((fail + 1)); printf '  [FAIL] %s\n' "$1" >&2; }

_t53_run() {
  ( cd "$_T53_TMP" && python3 scripts/doctor_check.py --scope v8.6.0 2>&1 )
}

_t53_prepush_ok() {
  printf '%s' "$1" | python3 -c '
import json, sys
d = json.load(sys.stdin)
for c in d["checks"]:
    if c["name"].startswith("pre-push guard"):
        print("true" if c["ok"] else "false")
        sys.exit(0)
print("MISSING")
'
}

# --- TC-01: no pre-push hook at all -> WARN (ok=false) ---
rm -f "$_T53_TMP/.git/hooks/pre-push"
_t53_out=$(_t53_run) || true
_t53_ok=$(_t53_prepush_ok "$_t53_out")
if [ "$_t53_ok" = "false" ] && printf '%s' "$_t53_out" | grep -q '未導入'; then
  t53_pass "TC-01: pre-push hook absent -> WARN (ok=false, detail present)"
else
  t53_fail "TC-01: expected ok=false + detail, got ok=$_t53_ok"
fi

# --- TC-02: pre-push hook present but not executable -> WARN (ok=false) ---
printf '#!/bin/sh\nexit 0\n' > "$_T53_TMP/.git/hooks/pre-push"
chmod -x "$_T53_TMP/.git/hooks/pre-push"
_t53_out=$(_t53_run) || true
_t53_ok=$(_t53_prepush_ok "$_t53_out")
if [ "$_t53_ok" = "false" ]; then
  t53_pass "TC-02: pre-push hook present but not executable -> WARN (ok=false)"
else
  t53_fail "TC-02: expected ok=false, got ok=$_t53_ok"
fi

# --- TC-03: pre-push hook present and executable -> ok (no WARN) ---
chmod +x "$_T53_TMP/.git/hooks/pre-push"
_t53_out=$(_t53_run) || true
_t53_ok=$(_t53_prepush_ok "$_t53_out")
if [ "$_t53_ok" = "true" ]; then
  t53_pass "TC-03: pre-push hook installed + executable -> ok=true (no WARN)"
else
  t53_fail "TC-03: expected ok=true, got ok=$_t53_ok"
fi

# --- TC-04: WARN level is warn, not fail (never blocks passed) ---
rm -f "$_T53_TMP/.git/hooks/pre-push"
_t53_out=$(_t53_run) || true
if printf '%s' "$_t53_out" | python3 -c '
import json, sys
d = json.load(sys.stdin)
c = [x for x in d["checks"] if x["name"].startswith("pre-push guard")][0]
assert c["level"] == "warn"
' 2>/dev/null; then
  t53_pass "TC-04: prepush guard gap is level=warn (does not count toward failures)"
else
  t53_fail "TC-04: expected level=warn for prepush guard check"
fi

rm -rf "$_T53_TMP" 2>/dev/null || true

pg_extra_contract_finalize
