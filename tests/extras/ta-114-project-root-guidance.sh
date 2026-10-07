#!/bin/sh
# PG_EXTRA_CAPABILITY: standalone-capable
# TA-114 — Active guidance must follow the #962 project-root contract.

if [ "${PG_HARNESS_SOURCED:-0}" = "1" ] && [ -n "${FIXTURES_DIR:-}" ] && [ -n "${EXTRAS_DIR:-}" ]; then
  _pg_extra_mode=harness
  _pg_extra_dir="$EXTRAS_DIR"
else
  _pg_extra_mode=standalone
  _pg_extra_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
  unset PLANGATE_SKIP_REASON PLANGATE_HOOK_TASK PLANGATE_HOOK_FILE \
    PLANGATE_BYPASS_HOOK PLANGATE_HOOK_STRICT PG_HARNESS_SOURCED \
    PLANGATE_ALLOW_MASS_DELETE PLANGATE_PROJECT_ROOT \
    PLANGATE_PROJECT_ROOT_SOURCE 2>/dev/null || true
fi

_pg_extra_helper="$_pg_extra_dir/_extra-contract.sh"
if [ ! -r "$_pg_extra_helper" ]; then
  printf '  [FAIL] helper unresolved: %s\n' "$_pg_extra_helper" >&2
  if [ "$_pg_extra_mode" = harness ]; then fail=$((fail + 1)); return 0; fi
  exit 1
fi
. "$_pg_extra_helper"
pg_extra_contract_init ta-114-project-root-guidance standalone-capable

if [ "$_pg_extra_mode" = harness ]; then
  _T114_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
else
  _T114_ROOT="${_pg_extra_dir%/tests/extras}"
fi

printf 'TA-114: #962 active guidance contract\n'

_t114_mirror_fail=0
for _t114_skill in \
  ai-dev-plan \
  ai-dev-exec \
  ai-dev-verify \
  working-context \
  plan-review-gate \
  local-exec-handoff \
  plangate-setup \
  intent-classifier
do
  _t114_src="$_T114_ROOT/.agents/skills/$_t114_skill/SKILL.md"
  for _t114_dst in \
    "$_T114_ROOT/.codex/skills/$_t114_skill/SKILL.md" \
    "$_T114_ROOT/plugin/plangate/skills/$_t114_skill/SKILL.md"
  do
    if [ ! -f "$_t114_src" ] || [ ! -f "$_t114_dst" ] || ! cmp -s "$_t114_src" "$_t114_dst"; then
      printf '  [FAIL] guidance mirror drift: %s -> %s\n' "$_t114_src" "$_t114_dst" >&2
      _t114_mirror_fail=1
    fi
  done
done
if [ "$_t114_mirror_fail" -eq 0 ]; then
  printf '  [PASS] canonical skill guidance matches Codex/plugin mirrors\n'
  pass=$((pass + 1))
else
  fail=$((fail + 1))
fi

_t114_stale_fail=0
for _t114_file in \
  "$_T114_ROOT/.agents/skills/ai-dev-plan/SKILL.md" \
  "$_T114_ROOT/.agents/skills/ai-dev-exec/SKILL.md" \
  "$_T114_ROOT/.agents/skills/ai-dev-verify/SKILL.md" \
  "$_T114_ROOT/.agents/skills/working-context/SKILL.md" \
  "$_T114_ROOT/.agents/skills/plan-review-gate/SKILL.md" \
  "$_T114_ROOT/.agents/skills/local-exec-handoff/SKILL.md" \
  "$_T114_ROOT/.agents/skills/plangate-setup/SKILL.md" \
  "$_T114_ROOT/.agents/skills/intent-classifier/SKILL.md" \
  "$_T114_ROOT/.claude/skills/plangate-setup/SKILL.md" \
  "$_T114_ROOT/.claude/skills/intent-classifier/SKILL.md" \
  "$_T114_ROOT/.claude/agents/setup-coordinator.md" \
  "$_T114_ROOT/.claude/agents/workflow-conductor.md" \
  "$_T114_ROOT/.claude/commands/plangate-setup.md" \
  "$_T114_ROOT/plugin/plangate/agents/setup-coordinator.md" \
  "$_T114_ROOT/plugin/plangate/agents/workflow-conductor.md" \
  "$_T114_ROOT/plugin/plangate/commands/plangate-setup.md"
do
  if [ ! -f "$_t114_file" ]; then
    printf '  [FAIL] active guidance file missing: %s\n' "$_t114_file" >&2
    _t114_stale_fail=1
    continue
  fi
  if grep -Fq 'doctor の検査対象は cwd ではなく CLI 本体の位置' "$_t114_file" \
    || grep -Fq 'TASK-XXXX 位置引数は cwd ではなく CLI 本体の位置' "$_t114_file" \
    || grep -Fq '導入先の TASK を対象にすることはできない' "$_t114_file" \
    || grep -Fq '実行はできるが**セットアップ検証には使えない**' "$_t114_file"; then
    printf '  [FAIL] stale pre-#1497 root guidance remains: %s\n' "$_t114_file" >&2
    _t114_stale_fail=1
  fi
done
if [ "$_t114_stale_fail" -eq 0 ]; then
  printf '  [PASS] stale CLI-root target claims absent from active guidance\n'
  pass=$((pass + 1))
else
  fail=$((fail + 1))
fi

_t114_required_fail=0
for _t114_file in \
  "$_T114_ROOT/.agents/skills/plangate-setup/SKILL.md" \
  "$_T114_ROOT/.claude/skills/plangate-setup/SKILL.md" \
  "$_T114_ROOT/.claude/agents/setup-coordinator.md" \
  "$_T114_ROOT/.claude/commands/plangate-setup.md"
do
  if ! grep -Fq -- '--project-root' "$_t114_file" \
    || ! grep -Fq 'PLANGATE_PROJECT_ROOT' "$_t114_file" \
    || ! grep -Fq 'rc=2' "$_t114_file" \
    || ! grep -Fq 'no-write' "$_t114_file"; then
    printf '  [FAIL] resolver/fail-closed contract missing from: %s\n' "$_t114_file" >&2
    _t114_required_fail=1
  fi
done
if [ "$_t114_required_fail" -eq 0 ]; then
  printf '  [PASS] setup guidance preserves resolver precedence and downstream repair boundary\n'
  pass=$((pass + 1))
else
  fail=$((fail + 1))
fi

unset _t114_skill _t114_src _t114_dst _t114_file \
  _t114_mirror_fail _t114_stale_fail _t114_required_fail 2>/dev/null || true

pg_extra_contract_finalize
