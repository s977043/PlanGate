# tests/extras/ta-33-agent-model-tier.sh
# Sourced by tests/run-tests.sh
# model tier（docs/ai/model-profiles.md §11）の機械検査。読み取り専用・sandbox 不要。

printf '\n=== TA-33: agent model tier (model-profiles.md §11) ===\n'

_t33_root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"

# TC-01: .claude/agents の tier 割当が §11 正本どおり（定型 6 体=sonnet / 他=inherit）
_t33_sonnet_set=" explorer-agent linter-fixer retrospective-analyst setup-coordinator documentation-writer skill-designer "
_t33_bad=""
_t33_count=0
for _t33_f in "$_t33_root"/.claude/agents/*.md; do
  [ -f "$_t33_f" ] || continue
  _t33_n="$(basename "$_t33_f" .md)"
  case "$_t33_n" in README) continue ;; esac
  _t33_count=$((_t33_count + 1))
  _t33_m="$(grep -m1 '^model:' "$_t33_f" | sed 's/^model: *//')"
  case "$_t33_sonnet_set" in
    *" $_t33_n "*) _t33_expect="sonnet" ;;
    *) _t33_expect="inherit" ;;
  esac
  [ "$_t33_m" = "$_t33_expect" ] || _t33_bad="$_t33_bad $_t33_n:$_t33_m(expect $_t33_expect)"
done
if [ -z "$_t33_bad" ] && [ "$_t33_count" -eq 17 ]; then
  printf '[PASS] TA-33 TC-01: .claude/agents の tier 割当が §11 と一致（17 体）\n'
  pass=$((pass + 1))
else
  printf '[FAIL] TA-33 TC-01: tier 不一致 or 体数変動(%s 体):%s\n' "$_t33_count" "$_t33_bad"
  fail=$((fail + 1))
fi

# TC-02: plugin 配布版 agents は model: inherit に正規化されている
_t33_bad=""
for _t33_f in "$_t33_root"/plugin/plangate/agents/*.md; do
  [ -f "$_t33_f" ] || continue
  case "$(basename "$_t33_f")" in README.md) continue ;; esac
  _t33_m="$(grep -m1 '^model:' "$_t33_f" | sed 's/^model: *//')"
  [ "$_t33_m" = "inherit" ] || _t33_bad="$_t33_bad $(basename "$_t33_f"):$_t33_m"
done
if [ -z "$_t33_bad" ]; then
  printf '[PASS] TA-33 TC-02: plugin 配布版 agents は全て model: inherit\n'
  pass=$((pass + 1))
else
  printf '[FAIL] TA-33 TC-02: 正規化漏れ:%s\n' "$_t33_bad"
  fail=$((fail + 1))
fi

# TC-03: Codex 側 tier（定型=low / 判断系=medium）が正本どおり
_t33_expect_low="explorer_agent linter_fixer retrospective_analyst setup_coordinator documentation_writer skill_designer"
_t33_expect_medium="orchestrator workflow_conductor requirements_analyst solution_architect spec_writer implementation_agent implementer qa_reviewer acceptance_tester code_optimizer project_planner"
_t33_bad=""
_t33_toml_count="$(ls "$_t33_root"/.codex/agents/*.toml 2>/dev/null | wc -l | tr -d ' ')"
[ "$_t33_toml_count" -eq 17 ] || _t33_bad="$_t33_bad toml総数=$_t33_toml_count(expect 17)"
for _t33_n in $_t33_expect_low; do
  [ -f "$_t33_root/.codex/agents/$_t33_n.toml" ] || { _t33_bad="$_t33_bad $_t33_n:missing"; continue; }
  _t33_e="$(grep -m1 'model_reasoning_effort' "$_t33_root/.codex/agents/$_t33_n.toml" | sed 's/.*"\(.*\)".*/\1/')"
  [ "$_t33_e" = "low" ] || _t33_bad="$_t33_bad $_t33_n:$_t33_e(expect low)"
done
for _t33_n in $_t33_expect_medium; do
  [ -f "$_t33_root/.codex/agents/$_t33_n.toml" ] || { _t33_bad="$_t33_bad $_t33_n:missing"; continue; }
  _t33_e="$(grep -m1 'model_reasoning_effort' "$_t33_root/.codex/agents/$_t33_n.toml" | sed 's/.*"\(.*\)".*/\1/')"
  [ "$_t33_e" = "medium" ] || _t33_bad="$_t33_bad $_t33_n:$_t33_e(expect medium)"
done
if [ -z "$_t33_bad" ]; then
  printf '[PASS] TA-33 TC-03: Codex effort tier が model-profiles.md §11 と一致\n'
  pass=$((pass + 1))
else
  printf '[FAIL] TA-33 TC-03: tier 不一致:%s\n' "$_t33_bad"
  fail=$((fail + 1))
fi
