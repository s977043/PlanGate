# tests/extras/ta-52-doctor-skill-collision.sh
# PG_EXTRA_CAPABILITY: standalone-capable
# Sourced by tests/run-tests.sh -- uses $pass / $fail counters
# Issue #721: doctor skill/command/agent name collision detection integration
#
# Sandbox: copy scripts/doctor_check.py + scripts/_paths.py +
# scripts/check-skill-name-collisions.py into a tmp dir so doctor_check.py's
# own REPO_ROOT resolution points into the sandbox (ta-39/ta-50 pattern).

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
pg_extra_contract_init ta-52-doctor-skill-collision standalone-capable

printf '\n=== TA-52: doctor skill name collision integration (#721) ===\n'

if [ "${PG_HARNESS_SOURCED:-0}" = "1" ] && [ -n "${FIXTURES_DIR:-}" ]; then
  _T52_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
else
  # standalone 実行: 外部 env 汚染を無害化（tests/extras/README.md 規約 8。
  # unset 集合は run-tests.sh 冒頭と同一の 7 env — TASK-0914 論点 F）
  unset PLANGATE_SKIP_REASON PLANGATE_HOOK_TASK PLANGATE_HOOK_FILE PLANGATE_BYPASS_HOOK PLANGATE_HOOK_STRICT PG_HARNESS_SOURCED PLANGATE_ALLOW_MASS_DELETE 2>/dev/null || true
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

# --- TC-03: repo-local + plugin の **配布ミラー** -> 衝突ではない -> ok=true ---
# (#1087) plugin/<p>/ は sync-plugin-plangate.sh が生成する export であり、
# root 内相対パスが一致する repo-local との対は「1 つの定義とその配布コピー」。
mkdir -p "$_T52_TMP/plugin/plugin-a/skills/only-here"
printf -- '---\nname: only-here\ndescription: mirrored\n---\n# only-here\n' \
  > "$_T52_TMP/plugin/plugin-a/skills/only-here/SKILL.md"
_t52_out=$(_t52_run) || true
_t52_ok=$(_t52_collision_ok "$_t52_out")
if [ "$_t52_ok" = "true" ]; then
  t52_pass "TC-03: repo-local <-> plugin export mirror -> ok=true (not a collision)"
else
  t52_fail "TC-03: expected ok=true for an export mirror, got $_t52_ok"
fi

# --- TC-03b: 3 定義（repo-local + plugin-a + plugin-b）-> 真の衝突 -> ok=false + WARN ---
# 元 issue #692 の動機ケース（供給元が 3 つ）。ミラー除外が広すぎないことの回帰。
mkdir -p "$_T52_TMP/plugin/plugin-b/skills/only-here"
printf -- '---\nname: only-here\ndescription: mirrored\n---\n# only-here\n' \
  > "$_T52_TMP/plugin/plugin-b/skills/only-here/SKILL.md"
_t52_out=$(_t52_run) || true
_t52_ok=$(_t52_collision_ok "$_t52_out")
if [ "$_t52_ok" = "false" ] && printf '%s' "$_t52_out" | grep -q '多重定義'; then
  t52_pass "TC-03b: 3 definitions -> ok=false (WARN with detail)"
else
  t52_fail "TC-03b: expected ok=false + detail, got ok=$_t52_ok"
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

pg_extra_contract_finalize
