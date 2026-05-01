# tests/extras/ta-05-validate-schemas.sh
# Sourced by tests/run-tests.sh
# Issue #170 で run-tests.sh から分離

printf '\n=== TA-05: validate-schemas (Issue #158) ===\n'

if python3 -c 'import jsonschema' >/dev/null 2>&1; then
  SCHEMA_FIXTURES="$FIXTURES_DIR/schema-validate"

  if sh "$PLANGATE_BIN" validate-schemas "$SCHEMA_FIXTURES/valid/c3.json" >/dev/null 2>&1; then
    printf '[PASS] valid/c3.json passes c3-approval schema\n'
    pass=$((pass + 1))
  else
    printf '[FAIL] valid/c3.json — expected PASS\n'
    fail=$((fail + 1))
  fi

  if ! sh "$PLANGATE_BIN" validate-schemas "$SCHEMA_FIXTURES/invalid/c3.json" >/dev/null 2>&1; then
    printf '[PASS] invalid/c3.json fails c3-approval schema (exit non-zero)\n'
    pass=$((pass + 1))
  else
    printf '[FAIL] invalid/c3.json — expected FAIL\n'
    fail=$((fail + 1))
  fi

  if sh "$PLANGATE_BIN" validate-schemas 2>&1 | grep -q 'Usage'; then
    printf '[PASS] validate-schemas: no args emits Usage text\n'
    pass=$((pass + 1))
  else
    printf '[FAIL] validate-schemas: usage text missing\n'
    fail=$((fail + 1))
  fi
else
  printf '[SKIP] validate-schemas suite — jsonschema package not installed (CI will install it)\n'
fi
