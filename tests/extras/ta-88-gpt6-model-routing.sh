#!/bin/sh
# PG_EXTRA_CAPABILITY: standalone-capable
# TA-88 — GPT-6 profile to Codex CLI model routing.

if [ "${PG_HARNESS_SOURCED:-0}" = "1" ] && [ -n "${FIXTURES_DIR:-}" ] && [ -n "${EXTRAS_DIR:-}" ]; then
  _T88_MODE=harness
  _T88_EXTRA_DIR=$EXTRAS_DIR
else
  _T88_MODE=standalone
  _T88_EXTRA_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
fi

. "$_T88_EXTRA_DIR/_extra-contract.sh"
pg_extra_contract_init ta-88-gpt6-model-routing standalone-capable

if pg_extra_contract_is_standalone; then
  unset PLANGATE_SKIP_REASON PLANGATE_HOOK_TASK PLANGATE_HOOK_FILE \
    PLANGATE_BYPASS_HOOK PLANGATE_HOOK_STRICT PG_HARNESS_SOURCED \
    PLANGATE_ALLOW_MASS_DELETE 2>/dev/null || true
fi

if [ "$_T88_MODE" = harness ]; then
  _T88_ROOT=$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)
else
  _T88_ROOT=${_T88_EXTRA_DIR%/tests/extras}
fi

_T88_RESOLVER=$_T88_ROOT/scripts/_resolve_model_id.py
_T88_PROFILES=$_T88_ROOT/docs/ai/model-profiles.yaml
_T88_WORKFLOW=$_T88_ROOT/scripts/ai-dev-workflow

printf 'TA-88: GPT-6 model routing\n'

if [ ! -r "$_T88_RESOLVER" ] || [ ! -r "$_T88_PROFILES" ] || [ ! -x "$_T88_WORKFLOW" ]; then
  pg_extra_contract_skip 'model routing files are unavailable'
  if [ "$_T88_MODE" = harness ]; then return 0; fi
fi

for _T88_EXPECTED in gpt_6_sol:gpt-6-sol gpt_6_astra:gpt-6-astra gpt_6_luna:gpt-6-luna; do
  _T88_PROFILE=${_T88_EXPECTED%%:*}
  _T88_MODEL=${_T88_EXPECTED#*:}
  _T88_MODE=""
  if [ "$_T88_PROFILE" = gpt_6_luna ]; then _T88_MODE=light; fi
  if _T88_ACTUAL=$(python3 "$_T88_RESOLVER" "$_T88_PROFILE" "$_T88_PROFILES" "$_T88_MODE") \
    && [ "$_T88_ACTUAL" = "$_T88_MODEL" ]; then
    printf '  [PASS] %s resolves to %s\n' "$_T88_PROFILE" "$_T88_MODEL"
    pass=$((pass + 1))
  else
    printf '  [FAIL] %s does not resolve to %s\n' "$_T88_PROFILE" "$_T88_MODEL" >&2
    fail=$((fail + 1))
  fi
done

if python3 "$_T88_RESOLVER" gpt-5_5 "$_T88_PROFILES" >/dev/null 2>&1; then
  printf '  [FAIL] profile without model_id must be rejected\n' >&2
  fail=$((fail + 1))
else
  printf '  [PASS] profile without model_id is rejected\n'
  pass=$((pass + 1))
fi

if python3 "$_T88_RESOLVER" gpt_6_luna "$_T88_PROFILES" >/dev/null 2>&1 \
  || python3 "$_T88_RESOLVER" gpt_6_luna "$_T88_PROFILES" critical >/dev/null 2>&1 \
  || python3 "$_T88_RESOLVER" gpt_6_luna "$_T88_PROFILES" not-a-mode >/dev/null 2>&1; then
  printf '  [FAIL] Luna requires a known permitted mode\n' >&2
  fail=$((fail + 1))
else
  printf '  [PASS] Luna rejects missing, critical, and unknown modes\n'
  pass=$((pass + 1))
fi

if python3 "$_T88_RESOLVER" gpt_6_sol "$_T88_PROFILES" not-a-mode >/dev/null 2>&1; then
  printf '  [FAIL] all profiles reject unknown modes\n' >&2
  fail=$((fail + 1))
else
  printf '  [PASS] all profiles reject unknown modes\n'
  pass=$((pass + 1))
fi

if grep -Fq 'export PLANGATE_MODEL_PROFILE=$profile_key' "$_T88_ROOT/scripts/ai-dev-common.sh" \
  && grep -Fq 'export PLANGATE_VALIDATION_BIAS=$validation_bias' "$_T88_ROOT/scripts/ai-dev-common.sh"; then
  printf '  [PASS] selected profile exports validation context to Codex\n'
  pass=$((pass + 1))
else
  printf '  [FAIL] selected profile does not export validation context\n' >&2
  fail=$((fail + 1))
fi

if _T88_OUTPUT=$(sh "$_T88_WORKFLOW" TASK-GPT6 exec --profile=gpt_6_sol --dry-run 2>&1) \
  && printf '%s\n' "$_T88_OUTPUT" | grep -Fq 'Codex model: gpt-6-sol (profile: gpt_6_sol)'; then
  printf '  [PASS] exec dry-run discloses resolved model and profile\n'
  pass=$((pass + 1))
else
  printf '  [FAIL] exec dry-run does not disclose resolved model and profile\n' >&2
  fail=$((fail + 1))
fi

if _T88_OUTPUT=$(sh "$_T88_WORKFLOW" TASK-GPT6 plan --profile=gpt_6_astra --dry-run 2>&1) \
  && printf '%s\n' "$_T88_OUTPUT" | grep -Fq 'Codex model: gpt-6-astra (profile: gpt_6_astra)'; then
  printf '  [PASS] plan dry-run discloses resolved model and profile\n'
  pass=$((pass + 1))
else
  printf '  [FAIL] plan dry-run does not disclose resolved model and profile\n' >&2
  fail=$((fail + 1))
fi

if sh "$_T88_WORKFLOW" TASK-GPT6 exec --model=gpt-6-sol --dry-run >/dev/null 2>&1; then
  printf '  [FAIL] raw model option must be rejected\n' >&2
  fail=$((fail + 1))
else
  printf '  [PASS] raw model option is rejected\n'
  pass=$((pass + 1))
fi

pg_extra_contract_finalize
