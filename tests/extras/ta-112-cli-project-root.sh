#!/bin/sh
# PG_EXTRA_CAPABILITY: standalone-capable
# TA-112 — CLI target project root resolution and downstream command routing (#962).

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
  if [ "$_pg_extra_mode" = harness ]; then fail=$((fail + 1)); return 0; fi
  exit 1
fi
. "$_pg_extra_helper"
pg_extra_contract_init ta-112-cli-project-root standalone-capable

if [ "$_pg_extra_mode" = harness ]; then
  _T112_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
  _T112_BIN="$PLANGATE_BIN"
else
  _T112_ROOT="${_pg_extra_dir%/tests/extras}"
  _T112_BIN="$_T112_ROOT/bin/plangate"
fi

printf 'TA-112: CLI target project root resolution (#962)\n'

_t112_tmp=$(mktemp -d)
register_cleanup "$_t112_tmp"
_t112_a="$_t112_tmp/project-a"
_t112_b="$_t112_tmp/project-b"
_t112_outside="$_t112_tmp/outside"
mkdir -p "$_t112_a/docs/working" "$_t112_b/docs/working" "$_t112_outside"
git -C "$_t112_a" init -q
git -C "$_t112_b" init -q

_t112_task="TASK-962ROOT"
_t112_make_task() {
  _t112_root=$1
  _t112_label=$2
  _t112_dir="$_t112_root/docs/working/$_t112_task"
  mkdir -p "$_t112_dir/approvals"
  printf '# PBI %s\n' "$_t112_label" >"$_t112_dir/pbi-input.md"
  printf '# PLAN %s\n' "$_t112_label" >"$_t112_dir/plan.md"
  printf '# TODO\n' >"$_t112_dir/todo.md"
  printf '# TEST CASES\n' >"$_t112_dir/test-cases.md"
  printf '# SELF REVIEW\n' >"$_t112_dir/review-self.md"
}
_t112_make_task "$_t112_a" A
_t112_make_task "$_t112_b" B

_t112_status_in() {
  _t112_cwd=$1
  shift
  _t112_rc=0
  _t112_out=$(
    unset PLANGATE_PROJECT_ROOT
    cd "$_t112_cwd"
    sh "$_T112_BIN" "$@" 2>&1
  ) || _t112_rc=$?
}

# 1. cwd git root.
_t112_status_in "$_t112_a" status "$_t112_task"
if [ "$_t112_rc" -eq 0 ] && printf '%s' "$_t112_out" | grep -Fq "Work dir: $_t112_a/docs/working/$_t112_task"; then
  printf '  [PASS] cwd git root targets downstream TASK\n'; pass=$((pass + 1))
else
  printf '  [FAIL] cwd git root resolution\n%s\n' "$_t112_out" >&2; fail=$((fail + 1))
fi

# 2. env overrides cwd git root.
_t112_rc=0
_t112_out=$(
  cd "$_t112_a"
  PLANGATE_PROJECT_ROOT="$_t112_b" sh "$_T112_BIN" status "$_t112_task" 2>&1
) || _t112_rc=$?
if [ "$_t112_rc" -eq 0 ] && printf '%s' "$_t112_out" | grep -Fq "Work dir: $_t112_b/docs/working/$_t112_task"; then
  printf '  [PASS] PLANGATE_PROJECT_ROOT overrides cwd git root\n'; pass=$((pass + 1))
else
  printf '  [FAIL] env root precedence\n%s\n' "$_t112_out" >&2; fail=$((fail + 1))
fi

# 3. explicit flag overrides env and cwd.
_t112_rc=0
_t112_out=$(
  cd "$_t112_b"
  PLANGATE_PROJECT_ROOT="$_t112_b" sh "$_T112_BIN" --project-root "$_t112_a" status "$_t112_task" 2>&1
) || _t112_rc=$?
if [ "$_t112_rc" -eq 0 ] && printf '%s' "$_t112_out" | grep -Fq "Work dir: $_t112_a/docs/working/$_t112_task"; then
  printf '  [PASS] --project-root has highest precedence\n'; pass=$((pass + 1))
else
  printf '  [FAIL] explicit root precedence\n%s\n' "$_t112_out" >&2; fail=$((fail + 1))
fi

# 4. invalid explicit root fails instead of silently falling back.
_t112_rc=0
_t112_out=$(
  cd "$_t112_a"
  PLANGATE_PROJECT_ROOT="$_t112_b" sh "$_T112_BIN" --project-root "$_t112_tmp/missing" status "$_t112_task" 2>&1
) || _t112_rc=$?
if [ "$_t112_rc" -eq 2 ] && printf '%s' "$_t112_out" | grep -Fq -- '--project-root is not an accessible directory'; then
  printf '  [PASS] invalid explicit root fails closed\n'; pass=$((pass + 1))
else
  printf '  [FAIL] invalid explicit root handling (rc=%s)\n%s\n' "$_t112_rc" "$_t112_out" >&2; fail=$((fail + 1))
fi

# 5. --project-root=<dir> form is equivalent to the split-argument form.
_t112_rc=0
_t112_out=$(sh "$_T112_BIN" "--project-root=$_t112_a" status "$_t112_task" 2>&1) || _t112_rc=$?
if [ "$_t112_rc" -eq 0 ] && printf '%s' "$_t112_out" | grep -Fq "Work dir: $_t112_a/docs/working/$_t112_task"; then
  printf '  [PASS] --project-root=<dir> targets downstream TASK\n'; pass=$((pass + 1))
else
  printf '  [FAIL] equals-form project root\n%s\n' "$_t112_out" >&2; fail=$((fail + 1))
fi

# 6. invalid env root also fails instead of falling back to cwd/CLI root.
_t112_rc=0
_t112_out=$(
  cd "$_t112_a"
  PLANGATE_PROJECT_ROOT="$_t112_tmp/missing-env" sh "$_T112_BIN" status "$_t112_task" 2>&1
) || _t112_rc=$?
if [ "$_t112_rc" -eq 2 ] && printf '%s' "$_t112_out" | grep -Fq 'PLANGATE_PROJECT_ROOT is not an accessible directory'; then
  printf '  [PASS] invalid env root fails closed\n'; pass=$((pass + 1))
else
  printf '  [FAIL] invalid env root handling (rc=%s)\n%s\n' "$_t112_rc" "$_t112_out" >&2; fail=$((fail + 1))
fi

# 7. validate reads downstream artifacts while validator implementation stays in CLI root.
_t112_plan_hash=$(python3 - "$_t112_b/docs/working/$_t112_task/plan.md" <<'PY'
import hashlib, pathlib, sys
print(hashlib.sha256(pathlib.Path(sys.argv[1]).read_bytes()).hexdigest())
PY
)
printf '{"c3_status":"APPROVED","plan_hash":"sha256:%s"}\n' "$_t112_plan_hash" >"$_t112_b/docs/working/$_t112_task/approvals/c3.json"
_t112_rc=0
_t112_out=$(sh "$_T112_BIN" --project-root "$_t112_b" validate "$_t112_task" 2>&1) || _t112_rc=$?
if [ "$_t112_rc" -eq 0 ] \
  && printf '%s' "$_t112_out" | grep -Fq 'Result: PASS' \
  && printf '%s' "$_t112_out" | grep -Fq 'plan.md hash matches'; then
  printf '  [PASS] validate operates on downstream artifacts\n'; pass=$((pass + 1))
else
  printf '  [FAIL] downstream validate (rc=%s)\n%s\n' "$_t112_rc" "$_t112_out" >&2; fail=$((fail + 1))
fi

# 8. approve resolves downstream before Human-presence gate; never bypass L1-L4.
_t112_no_plan="TASK-962NOPLAN"
mkdir -p "$_t112_b/docs/working/$_t112_no_plan/approvals"
_t112_rc=0
_t112_out=$(sh "$_T112_BIN" --project-root "$_t112_b" approve "$_t112_no_plan" 2>&1) || _t112_rc=$?
if [ "$_t112_rc" -eq 1 ] \
  && printf '%s' "$_t112_out" | grep -Fq "plan.md not found: $_t112_b/docs/working/$_t112_no_plan/plan.md" \
  && [ ! -f "$_t112_b/docs/working/$_t112_no_plan/approvals/c3.json" ]; then
  printf '  [PASS] approve targets downstream without weakening Human presence\n'; pass=$((pass + 1))
else
  printf '  [FAIL] downstream approve preflight (rc=%s)\n%s\n' "$_t112_rc" "$_t112_out" >&2; fail=$((fail + 1))
fi

# 9. doctor --check-settings inspects selected target; implementation script stays in CLI root.
_t112_rc=0
_t112_out=$(sh "$_T112_BIN" --project-root "$_t112_b" doctor --check-settings 2>&1) || _t112_rc=$?
if [ "$_t112_rc" -eq 1 ] \
  && printf '%s' "$_t112_out" | grep -Fq "PlanGate Doctor target: $_t112_b (source=flag)" \
  && printf '%s' "$_t112_out" | grep -Fq "$_t112_b/.claude/settings.json"; then
  printf '  [PASS] doctor --check-settings inspects downstream target\n'; pass=$((pass + 1))
else
  printf '  [FAIL] downstream doctor target (rc=%s)\n%s\n' "$_t112_rc" "$_t112_out" >&2; fail=$((fail + 1))
fi

# 10. doctor --json preserves JSON stdout and reports target identity in-band.
_t112_json="$_t112_tmp/doctor.json"
_t112_err="$_t112_tmp/doctor.err"
_t112_rc=0
sh "$_T112_BIN" --project-root "$_t112_b" doctor --json --scope hooks >"$_t112_json" 2>"$_t112_err" || _t112_rc=$?
_t112_json_ok=0
if python3 - "$_t112_json" "$_t112_b" <<'PY'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
assert d["project_root"] == sys.argv[2]
assert d["project_root_source"] == "flag"
PY
then
  _t112_json_ok=1
fi
if [ "$_t112_json_ok" -eq 1 ] && [ "$_t112_rc" -eq 1 ] && [ ! -s "$_t112_err" ]; then
  printf '  [PASS] doctor --json keeps machine-readable stdout and selected target\n'; pass=$((pass + 1))
else
  printf '  [FAIL] doctor --json target contract (rc=%s json_ok=%s)\n' "$_t112_rc" "$_t112_json_ok" >&2
  cat "$_t112_err" >&2
  fail=$((fail + 1))
fi

# 11. doctor --fix --dry-run reads canonical hooks from CLI root but plans writes in target.
_t112_before_count=$(find "$_t112_b" -type f 2>/dev/null | wc -l | tr -d ' ')
_t112_rc=0
_t112_out=$(sh "$_T112_BIN" --project-root "$_t112_b" doctor --fix --dry-run 2>&1) || _t112_rc=$?
_t112_after_count=$(find "$_t112_b" -type f 2>/dev/null | wc -l | tr -d ' ')
if [ "$_t112_rc" -eq 0 ] \
  && printf '%s' "$_t112_out" | grep -Fq 'settings.json hooks (via doctor_fix.py --dry-run)' \
  && printf '%s' "$_t112_out" | grep -Fq 'plan: create .claude/settings.json with PlanGate hook blocks' \
  && [ "$_t112_before_count" = "$_t112_after_count" ]; then
  printf '  [PASS] doctor --fix dry-run separates CLI source from downstream target\n'; pass=$((pass + 1))
else
  printf '  [FAIL] doctor --fix dry-run source/target split (rc=%s before=%s after=%s)\n%s\n' "$_t112_rc" "$_t112_before_count" "$_t112_after_count" "$_t112_out" >&2
  fail=$((fail + 1))
fi

# 12. CLI-root fallback remains available outside a git repository.
_t112_fallback="TASK-962FALLBACK"
_t112_fallback_dir="$_T112_ROOT/docs/working/$_t112_fallback"
mkdir -p "$_t112_fallback_dir/approvals"
register_cleanup "$_t112_fallback_dir"
printf '# PBI\n' >"$_t112_fallback_dir/pbi-input.md"
printf '# PLAN\n' >"$_t112_fallback_dir/plan.md"
_t112_rc=0
_t112_out=$(
  unset PLANGATE_PROJECT_ROOT
  cd "$_t112_outside"
  sh "$_T112_BIN" status "$_t112_fallback" 2>&1
) || _t112_rc=$?
if [ "$_t112_rc" -eq 0 ] && printf '%s' "$_t112_out" | grep -Fq "Work dir: $_T112_ROOT/docs/working/$_t112_fallback"; then
  printf '  [PASS] non-git cwd falls back to CLI root\n'; pass=$((pass + 1))
else
  printf '  [FAIL] CLI-root fallback (rc=%s)\n%s\n' "$_t112_rc" "$_t112_out" >&2; fail=$((fail + 1))
fi

pg_extra_contract_finalize
