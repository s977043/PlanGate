#!/bin/sh
# PG_EXTRA_CAPABILITY: standalone-capable
# tests/extras/ta-89-plan-deliberation-schema.sh
# TASK-1353 / #1353 — Plan Deliberation schema proposal contract.
#
# Pre-HO state:
#   validates the deterministic generated schema + fixtures without writing schemas/.
# Post-HO state:
#   additionally requires the Human-applied schema to byte-match the generator.

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
pg_extra_contract_init ta-89-plan-deliberation-schema standalone-capable

if pg_extra_contract_is_standalone; then
  unset PLANGATE_SKIP_REASON PLANGATE_HOOK_TASK PLANGATE_HOOK_FILE \
    PLANGATE_BYPASS_HOOK PLANGATE_HOOK_STRICT PG_HARNESS_SOURCED \
    PLANGATE_ALLOW_MASS_DELETE 2>/dev/null || true
fi

printf '\n=== TA-89: Plan Deliberation schema contract (#1353) ===\n'

if [ "$_pg_extra_mode" = harness ]; then
  _T89_ROOT="$(CDPATH= cd -- "${FIXTURES_DIR:?}/../.." && pwd)"
else
  _T89_ROOT="${_pg_extra_dir%/tests/extras}"
fi
PLANGATE_BIN="$_T89_ROOT/bin/plangate"
_T89_GEN="$_T89_ROOT/scripts/generate-plan-deliberation-schema.py"
_T89_APPLY="$_T89_ROOT/scripts/apply-task-1353-plan-deliberation-schema.sh"
_T89_CASES="$_T89_ROOT/tests/fixtures/plan-deliberation/cases.json"
_T89_TARGET="$_T89_ROOT/schemas/plan-deliberation.schema.json"
_T89_TMP="$(mktemp)"
register_cleanup "$_T89_TMP"

if [ -f "$_T89_GEN" ] && python3 "$_T89_GEN" >"$_T89_TMP"; then
  printf '[PASS] generator emits schema JSON\n'
  pass=$((pass + 1))
else
  printf '[FAIL] generator failed\n'
  fail=$((fail + 1))
fi

if python3 -m json.tool "$_T89_TMP" >/dev/null 2>&1; then
  printf '[PASS] generated schema is valid JSON\n'
  pass=$((pass + 1))
else
  printf '[FAIL] generated schema is not valid JSON\n'
  fail=$((fail + 1))
fi

if python3 -c 'import jsonschema' >/dev/null 2>&1; then
  if python3 - "$_T89_TMP" "$_T89_CASES" <<'PY'
import copy
import json
import pathlib
import sys

from jsonschema import Draft202012Validator

schema_path = pathlib.Path(sys.argv[1])
cases_path = pathlib.Path(sys.argv[2])
schema = json.loads(schema_path.read_text(encoding="utf-8"))
cases = json.loads(cases_path.read_text(encoding="utf-8"))

Draft202012Validator.check_schema(schema)
validator = Draft202012Validator(schema)

assert schema["properties"]["stability"]["enum"] == ["experimental"]
assert schema["additionalProperties"] is False

def resolve_parent(obj, parts):
    cur = obj
    for part in parts[:-1]:
        if isinstance(cur, list):
            cur = cur[int(part)]
        else:
            cur = cur[part]
    return cur, parts[-1]

def apply_ops(base, ops):
    obj = copy.deepcopy(base)
    for op in ops:
        parts = op["path"].split(".")
        parent, leaf = resolve_parent(obj, parts)
        key = int(leaf) if isinstance(parent, list) else leaf
        if op["op"] == "set":
            parent[key] = copy.deepcopy(op["value"])
        elif op["op"] == "delete":
            del parent[key]
        else:
            raise AssertionError(f"unknown fixture op: {op['op']}")
    return obj

errors = []
for case in cases["valid_cases"]:
    instance = apply_ops(cases["base"], case["ops"])
    found = list(validator.iter_errors(instance))
    if found:
        errors.append(
            f"valid/{case['name']} unexpectedly failed: {found[0].message}"
        )

for case in cases["invalid_cases"]:
    instance = apply_ops(cases["base"], case["ops"])
    found = list(validator.iter_errors(instance))
    if not found:
        errors.append(f"invalid/{case['name']} unexpectedly passed")

if errors:
    raise SystemExit("\n".join(errors))

print(
    f"valid={len(cases['valid_cases'])} "
    f"invalid={len(cases['invalid_cases'])}"
)
PY
  then
    printf '[PASS] Draft 2020-12 schema + valid/invalid fixtures\n'
    pass=$((pass + 1))
  else
    printf '[FAIL] schema/fixture semantic validation failed\n'
    fail=$((fail + 1))
  fi
else
  printf '[SKIP] TA-89 semantic fixtures — jsonschema package not installed (CI will install it)\n'
fi

if [ -f "$_T89_TARGET" ]; then
  _T89_BEFORE="present:$(cksum <"$_T89_TARGET")"
else
  _T89_BEFORE="absent"
fi

if [ -f "$_T89_APPLY" ] &&
   sh "$_T89_APPLY" --dry-run >/dev/null 2>&1; then
  if [ -f "$_T89_TARGET" ]; then
    _T89_AFTER="present:$(cksum <"$_T89_TARGET")"
  else
    _T89_AFTER="absent"
  fi
  if [ "$_T89_BEFORE" = "$_T89_AFTER" ]; then
    printf '[PASS] Human apply script dry-run succeeds and changes no target bytes\n'
    pass=$((pass + 1))
  else
    printf '[FAIL] Human apply script --dry-run changed target state/content\n'
    fail=$((fail + 1))
  fi
else
  printf '[FAIL] Human apply script --dry-run failed\n'
  fail=$((fail + 1))
fi

if sh "$_T89_APPLY" >/dev/null 2>&1; then
  printf '[FAIL] Human apply script accepted missing explicit confirmation\n'
  fail=$((fail + 1))
else
  printf '[PASS] Human apply path requires explicit --human-confirmed\n'
  pass=$((pass + 1))
fi

if [ -f "$_T89_TARGET" ]; then
  if cmp -s "$_T89_TARGET" "$_T89_TMP"; then
    printf '[PASS] Human-applied schema byte-matches deterministic generator\n'
    pass=$((pass + 1))
  else
    printf '[FAIL] Human-applied schema differs from deterministic generator\n'
    fail=$((fail + 1))
  fi
else
  printf '[SKIP] HO schema not yet Human-applied (expected for prep PR)\n'
fi

pg_extra_contract_finalize
