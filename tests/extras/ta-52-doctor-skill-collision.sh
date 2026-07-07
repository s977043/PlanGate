# tests/extras/ta-52-doctor-skill-collision.sh
# Sourced by tests/run-tests.sh -- uses $pass / $fail counters
# Issue #721: doctor skill/command/agent name collision detection integration
#
# Sandbox: copy scripts/doctor_check.py + scripts/_paths.py +
# scripts/check-skill-name-collisions.py into a tmp dir so doctor_check.py's
# own REPO_ROOT resolution points into the sandbox (ta-39/ta-50 pattern).

printf '\n=== TA-52: doctor skill name collision integration (#721) ===\n'

if [ -n "${FIXTURES_DIR:-}" ]; then
  _T52_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
else
  _T52_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
fi

_T52_TMP=$(mktemp -d)
if command -v register_cleanup >/dev/null 2>&1; then
  register_cleanup "$_T52_TMP"
fi

mkdir -p "$_T52_TMP/scripts"
cp "$_T52_ROOT/scripts/doctor_check.py" "$_T52_TMP/scripts/doctor_check.py"
cp "$_T52_ROOT/scripts/_paths.py" "$_T52_TMP/scripts/_paths.py"
cp "$_T52_ROOT/scripts/check-skill-name-collisions.py" "$_T52_TMP/scripts/check-skill-name-collisions.py"

t52_pass() { pass=$((pass + 1)); printf '  [PASS] %s\n' "$1"; }
t52_fail() { fail=$((fail + 1)); printf '  [FAIL] %s\n' "$1" >&2; }

_t52_run() {
  ( cd "$_T52_TMP" && python3 scripts/doctor_check.py --scope v8.6.0 2>&1 )
}

_t52_collision_ok() {
  printf '%s' "$1" | python3 -c '
import json, sys
d = json.load(sys.stdin)
for c in d["checks"]:
    if c["name"].startswith("skill/command/agent"):
        print("true" if c["ok"] else "false")
        sys.exit(0)
print("MISSING")
'
}

# --- TC-01: no .claude / plugin dirs at all -> no collision -> ok=true ---
_t52_out=$(_t52_run) || true
_t52_ok=$(_t52_collision_ok "$_t52_out")
if [ "$_t52_ok" = "true" ]; then
  t52_pass "TC-01: no skill roots -> ok=true (no collision)"
else
  t52_fail "TC-01: expected ok=true, got $_t52_ok"
fi

# --- TC-02: single repo-local skill (no plugin mirror) -> no collision ---
mkdir -p "$_T52_TMP/.claude/skills/only-here"
printf -- '---\nname: only-here\ndescription: solo\n---\n# only-here\n' \
  > "$_T52_TMP/.claude/skills/only-here/SKILL.md"
_t52_out=$(_t52_run) || true
_t52_ok=$(_t52_collision_ok "$_t52_out")
if [ "$_t52_ok" = "true" ]; then
  t52_pass "TC-02: repo-local only skill -> ok=true (no collision)"
else
  t52_fail "TC-02: expected ok=true, got $_t52_ok"
fi

# --- TC-03: repo-local + plugin same name -> collision -> ok=false + WARN ---
mkdir -p "$_T52_TMP/plugin/plugin-a/skills/only-here"
printf -- '---\nname: only-here\ndescription: mirrored\n---\n# only-here\n' \
  > "$_T52_TMP/plugin/plugin-a/skills/only-here/SKILL.md"
_t52_out=$(_t52_run) || true
_t52_ok=$(_t52_collision_ok "$_t52_out")
if [ "$_t52_ok" = "false" ] && printf '%s' "$_t52_out" | grep -q '多重定義'; then
  t52_pass "TC-03: repo-local + plugin collision -> ok=false (WARN with detail)"
else
  t52_fail "TC-03: expected ok=false + detail, got ok=$_t52_ok"
fi

# --- TC-04: WARN level is warn, not fail (never blocks passed) ---
if printf '%s' "$_t52_out" | python3 -c '
import json, sys
d = json.load(sys.stdin)
c = [x for x in d["checks"] if x["name"].startswith("skill/command/agent")][0]
assert c["level"] == "warn"
' 2>/dev/null; then
  t52_pass "TC-04: collision check is level=warn (does not count toward failures)"
else
  t52_fail "TC-04: expected level=warn for collision check"
fi

# --- TC-05: script missing -> ok=true (skip, not a crash) ---
rm -f "$_T52_TMP/scripts/check-skill-name-collisions.py"
_t52_out=$(_t52_run) || true
_t52_ok=$(_t52_collision_ok "$_t52_out")
if [ "$_t52_ok" = "true" ] && printf '%s' "$_t52_out" | grep -q 'not found'; then
  t52_pass "TC-05: collision script missing -> ok=true skip (no crash)"
else
  t52_fail "TC-05: expected ok=true skip on missing script, got ok=$_t52_ok"
fi

rm -rf "$_T52_TMP" 2>/dev/null || true
