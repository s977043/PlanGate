# tests/extras/ta-51-doctor-w6.sh
# Sourced by tests/run-tests.sh -- uses $pass / $fail counters
# Issue #720: doctor W-6 (C-3 Autonomous APPROVE) introduction gap detection
#
# Sandbox: copy scripts/doctor_check.py + scripts/_paths.py into a tmp dir
# mimicking <tmp>/scripts + <tmp>/.claude/rules + <tmp>/docs/working so that
# doctor_check.py's own REPO_ROOT resolution (Path(__file__).resolve().parents[1])
# points into the sandbox (ta-39/ta-50 pattern) -- avoids touching the real repo.

printf '\n=== TA-51: doctor W-6 introduction gap detection (#720) ===\n'

if [ "${PG_HARNESS_SOURCED:-0}" = "1" ] && [ -n "${FIXTURES_DIR:-}" ]; then
  _T51_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
else
  # standalone 実行: 外部 env 汚染を無害化（tests/extras/README.md 規約 8。
  # unset 集合は run-tests.sh 冒頭と同一の 7 env — TASK-0914 論点 F）
  unset PLANGATE_SKIP_REASON PLANGATE_HOOK_TASK PLANGATE_HOOK_FILE PLANGATE_BYPASS_HOOK PLANGATE_HOOK_STRICT PG_HARNESS_SOURCED PLANGATE_ALLOW_MASS_DELETE 2>/dev/null || true
  _T51_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
fi

_T51_TMP=$(mktemp -d)
if command -v register_cleanup >/dev/null 2>&1; then
  register_cleanup "$_T51_TMP"
fi

mkdir -p "$_T51_TMP/scripts"
mkdir -p "$_T51_TMP/.claude/rules"
mkdir -p "$_T51_TMP/docs/working"
cp "$_T51_ROOT/scripts/doctor_check.py" "$_T51_TMP/scripts/doctor_check.py"
cp "$_T51_ROOT/scripts/_paths.py" "$_T51_TMP/scripts/_paths.py"
# skill collision + pre-push checks also run as part of --scope v8.6.0; keep
# them harmless/no-op in this sandbox (script absent -> "skip" warn, not a crash).

t51_pass() { pass=$((pass + 1)); printf '  [PASS] %s\n' "$1"; }
t51_fail() { fail=$((fail + 1)); printf '  [FAIL] %s\n' "$1" >&2; }

_t51_run() {
  ( cd "$_T51_TMP" && python3 scripts/doctor_check.py --scope v8.6.0 2>&1 )
}

_t51_w6_ok() {
  # $1 = json blob; prints "true"/"false" for the W-6 check's ok field
  printf '%s' "$1" | python3 -c '
import json, sys
d = json.load(sys.stdin)
for c in d["checks"]:
    if c["name"].startswith("W-6"):
        print("true" if c["ok"] else "false")
        sys.exit(0)
print("MISSING")
'
}

# --- TC-01: not introduced + no record -> ok (no WARN) ---
rm -f "$_T51_TMP/.claude/rules/working-context.md"
rm -rf "$_T51_TMP/docs/working"/TASK-*
_t51_out=$(_t51_run) || true
_t51_ok=$(_t51_w6_ok "$_t51_out")
if [ "$_t51_ok" = "true" ]; then
  t51_pass "TC-01: not introduced + no record -> ok=true (no WARN)"
else
  t51_fail "TC-01: expected ok=true, got $_t51_ok"
fi

# --- TC-02: not introduced + record exists -> WARN (ok=false) ---
printf '# rules\n(no W-6 heading here)\n' > "$_T51_TMP/.claude/rules/working-context.md"
mkdir -p "$_T51_TMP/docs/working/TASK-9001"
printf '## C-3 Gate: AUTONOMOUS APPROVED\n\n- w6_status: not_introduced\n' \
  > "$_T51_TMP/docs/working/TASK-9001/status.md"
_t51_out=$(_t51_run) || true
_t51_ok=$(_t51_w6_ok "$_t51_out")
if [ "$_t51_ok" = "false" ] && printf '%s' "$_t51_out" | grep -q 'TASK-9001'; then
  t51_pass "TC-02: not introduced + record exists -> WARN (ok=false, task listed)"
else
  t51_fail "TC-02: expected ok=false + TASK-9001 in detail, got ok=$_t51_ok"
fi

# --- TC-03: introduced (heading present) + record exists -> ok (no WARN) ---
printf '#### C-3 Autonomous APPROVE (autonomous exec delegation)\n\nmatrix here\n' \
  > "$_T51_TMP/.claude/rules/working-context.md"
_t51_out=$(_t51_run) || true
_t51_ok=$(_t51_w6_ok "$_t51_out")
if [ "$_t51_ok" = "true" ]; then
  t51_pass "TC-03: introduced + record exists -> ok=true (no WARN)"
else
  t51_fail "TC-03: expected ok=true, got $_t51_ok"
fi

# --- TC-04: introduced + no record -> ok (no WARN) ---
rm -rf "$_T51_TMP/docs/working"/TASK-*
_t51_out=$(_t51_run) || true
_t51_ok=$(_t51_w6_ok "$_t51_out")
if [ "$_t51_ok" = "true" ]; then
  t51_pass "TC-04: introduced + no record -> ok=true (no WARN)"
else
  t51_fail "TC-04: expected ok=true, got $_t51_ok"
fi

# --- TC-05: WARN never fails the overall scope (level is warn, not fail) ---
printf '# rules\n(no W-6 heading here)\n' > "$_T51_TMP/.claude/rules/working-context.md"
mkdir -p "$_T51_TMP/docs/working/TASK-9002"
printf '## C-3 Gate: AUTONOMOUS APPROVED\n' > "$_T51_TMP/docs/working/TASK-9002/status.md"
_t51_out=$(_t51_run) || true
if printf '%s' "$_t51_out" | python3 -c '
import json, sys
d = json.load(sys.stdin)
w6 = [c for c in d["checks"] if c["name"].startswith("W-6")][0]
assert w6["level"] == "warn"
assert w6["ok"] is False
' 2>/dev/null; then
  t51_pass "TC-05: W-6 gap is level=warn (never blocks passed via failures)"
else
  t51_fail "TC-05: expected level=warn for W-6 gap check"
fi

rm -rf "$_T51_TMP" 2>/dev/null || true
