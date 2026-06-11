# tests/extras/ta-38-agent-tools.sh
# Sourced by tests/run-tests.sh
# 改善提案 3（2026-06-11）: エージェント定義の tools 欄が実在ツール名のみで構成されることを検証。
# 背景: explorer-agent に ViewCodeItem / FindByName（実在しない）が v6 期から残存していた。

printf '\n=== TA-38: agent tools validation ===\n'

_t38_root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
# Claude Code の既知ツール名（エージェント定義で使用を許容する集合）
_t38_allow=" Read Grep Glob Bash Edit Write Agent NotebookEdit WebFetch WebSearch AskUserQuestion Skill "

_t38_bad=""
for _t38_f in "$_t38_root"/.claude/agents/*.md; do
  [ -f "$_t38_f" ] || continue
  case "$(basename "$_t38_f")" in README.md) continue ;; esac
  _t38_tools="$(grep -m1 '^tools:' "$_t38_f" | sed 's/^tools: *//' | tr ',' ' ')"
  for _t38_t in $_t38_tools; do
    case "$_t38_allow" in
      *" $_t38_t "*) ;;
      *) _t38_bad="$_t38_bad $(basename "$_t38_f" .md):$_t38_t" ;;
    esac
  done
done
if [ -z "$_t38_bad" ]; then
  printf '[PASS] TA-38 TC-01: 全エージェントの tools が既知ツール名のみ\n'; pass=$((pass + 1))
else
  printf '[FAIL] TA-38 TC-01: 実在しないツール名:%s\n' "$_t38_bad"; fail=$((fail + 1))
fi
