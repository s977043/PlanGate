#!/bin/sh
# PG_EXTRA_CAPABILITY: standalone-capable
# tests/extras/ta-89-plan-deliberation-schema.sh
# TASK-1353 / #1353 — Plan Deliberation schema contract.
#
# Validates the canonical schemas/plan-deliberation.schema.json directly and
# evaluates every valid/invalid case in tests/fixtures/plan-deliberation/cases.json.

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
_T89_CASES="$_T89_ROOT/tests/fixtures/plan-deliberation/cases.json"
_T89_SCHEMA="$_T89_ROOT/schemas/plan-deliberation.schema.json"

if [ -f "$_T89_SCHEMA" ] && python3 -m json.tool "$_T89_SCHEMA" >/dev/null 2>&1; then
  printf '[PASS] canonical schema exists and is valid JSON\n'
  pass=$((pass + 1))
else
  printf '[FAIL] canonical schema missing or not valid JSON: %s\n' "$_T89_SCHEMA"
  fail=$((fail + 1))
fi

if python3 -c 'import jsonschema' >/dev/null 2>&1; then
  if python3 - "$_T89_SCHEMA" "$_T89_CASES" <<'PY'
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
assert cases["valid_cases"] and cases["invalid_cases"], "fixture cases are empty"

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

# #1505 F-1: pin the top-level required contract independently of schema.
# Iterating only schema["required"] would silently shrink when the schema is
# weakened; the explicit baseline is the negative-control oracle.
expected_required = {
    "schema_version", "artifact_type", "stability", "task_id",
    "plan_ref", "source_reviews", "execution", "trigger",
    "participants", "problem_frames", "positions", "outcome",
}
missing_required = expected_required - set(schema.get("required", []))
if missing_required:
    errors.append(f"top-level required contract weakened: {sorted(missing_required)}")

# Exercise a missing-field instance for EACH independent required property.
# Check that the error is the intended top-level 'required' diagnostic,
# not an unrelated failure from an allOf branch.
for required_key in sorted(expected_required):
    instance = copy.deepcopy(cases["base"])
    instance.pop(required_key, None)
    found = list(validator.iter_errors(instance))
    if not any(
        err.validator == "required"
        and list(err.absolute_path) == []
        and f"'{required_key}'" in err.message
        for err in found
    ):
        errors.append(
            f"top-level missing/{required_key} did not raise required diagnostic"
        )

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
        continue
    # #1505 F-2: any unrelated error is NOT enough to pass an invalid case.
    # Match the reason against the fixture's canonical diagnostic identity.
    expected = case.get("expected_error")
    if not isinstance(expected, dict) or set(expected) != {"path", "validator"}:
        errors.append(f"invalid/{case['name']} missing expected_error contract")
        continue
    matching = [
        err for err in found
        if ".".join(map(str, err.absolute_path)) == expected["path"]
        and err.validator == expected["validator"]
    ]
    if not matching:
        observed = [
            ( ".".join(map(str, err.absolute_path)), err.validator )
            for err in found
        ]
        errors.append(
            f"invalid/{case['name']} expected {expected!r}; got {observed!r}"
        )

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

pg_extra_contract_finalize
