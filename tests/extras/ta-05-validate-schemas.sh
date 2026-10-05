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

  _t05_root="$(CDPATH= cd -- "$(dirname "$PLANGATE_BIN")/.." && pwd)"
  _t05_intent_fixture="$_t05_root/tests/fixtures/intent-context/valid/intent-context.json"
  _t05_intent_invalid="$_t05_root/tests/fixtures/intent-context/invalid/intent-context.json"
  _t05_intent_invalid_format="$_t05_root/tests/fixtures/intent-context/invalid-format/intent-context.json"
  _t05_plan_contract_fixture="$_t05_root/tests/fixtures/plan-contract/valid/plan-contract.json"
  _t05_deliberation_fixture="$_t05_root/tests/fixtures/plan-deliberation/valid/plan-deliberation.json"
  _t05_deliberation_invalid="$_t05_root/tests/fixtures/plan-deliberation/invalid/plan-deliberation.json"

  if sh "$PLANGATE_BIN" validate-schemas "$_t05_intent_fixture" >/dev/null 2>&1; then
    printf '[PASS] Intent Context Package fixture passes schema mapping/validation\n'
    pass=$((pass + 1))
  else
    printf '[FAIL] Intent Context Package fixture — expected schema PASS\n'
    fail=$((fail + 1))
  fi

  if ! sh "$PLANGATE_BIN" validate-schemas "$_t05_intent_invalid" >/dev/null 2>&1; then
    printf '[PASS] schema-valid semantic-invalid Intent Context fixture fails closed\n'
    pass=$((pass + 1))
  else
    printf '[FAIL] semantic-invalid Intent Context fixture produced false green\n'
    fail=$((fail + 1))
  fi

  if ! sh "$PLANGATE_BIN" validate-schemas "$_t05_intent_invalid_format" >/dev/null 2>&1; then
    printf '[PASS] invalid date-time Intent Context fixture fails closed through validate-schemas\n'
    pass=$((pass + 1))
  else
    printf '[FAIL] invalid date-time Intent Context fixture produced false green\n'
    fail=$((fail + 1))
  fi

  if python3 "$_t05_root/tests/test_intent_context_contract.py" >/dev/null 2>&1; then
    printf '[PASS] Intent Context Package contract scenarios pass\n'
    pass=$((pass + 1))
  else
    printf '[FAIL] Intent Context Package contract scenarios failed\n'
    fail=$((fail + 1))
  fi

  if sh "$PLANGATE_BIN" validate-schemas "$_t05_plan_contract_fixture" >/dev/null 2>&1; then
    printf '[PASS] Plan Contract fixture passes schema mapping/validation\n'
    pass=$((pass + 1))
  else
    printf '[FAIL] Plan Contract fixture — expected schema PASS\n'
    fail=$((fail + 1))
  fi

  # 未登録の basename は SKIP（exit 0）になるため、exit code ではなく PASS 件数で判定する
  if sh "$PLANGATE_BIN" validate-schemas "$_t05_deliberation_fixture" 2>&1 | grep -q '^Summary: PASS=1,'; then
    printf '[PASS] Plan Deliberation fixture passes schema mapping/validation\n'
    pass=$((pass + 1))
  else
    printf '[FAIL] Plan Deliberation fixture — expected schema PASS (not SKIP)\n'
    fail=$((fail + 1))
  fi

  # 非ゼロ終了だけでは fixture 欠落や壊れた JSON でも通るため、schema 違反で落ちたことまで確認する
  _t05_deliberation_rc=0
  _t05_deliberation_out=$(sh "$PLANGATE_BIN" validate-schemas "$_t05_deliberation_invalid" 2>&1) || _t05_deliberation_rc=$?
  if [ -f "$_t05_deliberation_invalid" ] &&
     [ "$_t05_deliberation_rc" -eq 1 ] &&
     printf '%s\n' "$_t05_deliberation_out" | grep -q '^Summary: PASS=0, FAIL=1,' &&
     printf '%s\n' "$_t05_deliberation_out" | grep -q "first at outcome/status: 'converged' is not one of"; then
    printf '[PASS] invalid Plan Deliberation fixture (partial cannot converge) fails closed\n'
    pass=$((pass + 1))
  else
    printf '[FAIL] invalid Plan Deliberation fixture produced false green\n'
    fail=$((fail + 1))
  fi

  if python3 "$_t05_root/tests/test_plan_contract_context_binding.py" >/dev/null 2>&1; then
    printf '[PASS] Plan Contract Context binding scenarios pass\n'
    pass=$((pass + 1))
  else
    printf '[FAIL] Plan Contract Context binding scenarios failed\n'
    fail=$((fail + 1))
  fi

  if python3 "$_t05_root/tests/test_context_engine_intent_context.py" >/dev/null 2>&1; then
    printf '[PASS] Context Engine Intent Context adapter scenarios pass\n'
    pass=$((pass + 1))
  else
    printf '[FAIL] Context Engine Intent Context adapter scenarios failed\n'
    fail=$((fail + 1))
  fi

  if sh "$PLANGATE_BIN" validate-schemas 2>&1 | grep -q 'Usage'; then
    printf '[PASS] validate-schemas: no args emits Usage text\n'
    pass=$((pass + 1))
  else
    printf '[FAIL] validate-schemas: usage text missing\n'
    fail=$((fail + 1))
  fi

  # TASK-0872 / #887 F-8: approval_kind=c3-prime かつ c3-prime.schema.json が
  # 未配置（PR-2 前）のとき、dispatch は SKIP でなく不在パス返却 → validate-schemas
  # は ERROR/非ゼロ終了で fail-closed になること（沈黙スキップの fail-open 窓防止）。
  # schemas/c3-prime.schema.json が実在する（PR-2 適用後）環境では本テストは
  # 「スキーマ実在 → 検証実行」に切り替わるため skip する。
  _t05_c3prime_schema="$(dirname "$PLANGATE_BIN")/../schemas/c3-prime.schema.json"
  if [ ! -f "$_t05_c3prime_schema" ]; then
    _t05_tmp=$(mktemp -d)
    cat > "$_t05_tmp/c3.json" <<'T05EOF'
{ "approval_kind": "c3-prime", "task_id": "TASK-9999", "decision": "AUTO_APPROVED" }
T05EOF
    if ! sh "$PLANGATE_BIN" validate-schemas "$_t05_tmp/c3.json" >/dev/null 2>&1; then
      printf '[PASS] F-8: c3-prime + schema 未配置 → fail-closed (非ゼロ終了)\n'
      pass=$((pass + 1))
    else
      printf '[FAIL] F-8: c3-prime + schema 未配置が SKIP/PASS になった (fail-open)\n'
      fail=$((fail + 1))
    fi
    rm -rf "$_t05_tmp"
  else
    printf '[SKIP] F-8: schemas/c3-prime.schema.json が既に配置済み (PR-2 適用後)\n'
  fi
else
  printf '[SKIP] validate-schemas suite — jsonschema package not installed (CI will install it)\n'
fi
