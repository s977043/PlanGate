# tests/extras/ta-44-hook-wiring.sh
# Sourced by tests/run-tests.sh — uses $pass / $fail counters
# TASK-0143 (#527 子1 / #500 §1): hook 物理配線 6/12→12/12（増分1: 群A EH-4/5/7）
#
# 前提: scripts/apply-task-0143-hook-wiring.sh で群A配線が適用済み。
#   未適用時は SKIP（ta-43 と同方式: apply 済みでなければ skip して CI を割らない）。
#   群A配線は conductor / hook-enforcement.md（HO パス）の Human 適用を待つため。

printf '\n=== TA-44: hook 配線 群A EH-4/5/7 (#527 TASK-0143) ===\n'

if [ -n "${FIXTURES_DIR:-}" ]; then
  _T44_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
else
  _T44_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
fi

_T44_CONDUCTOR="$_T44_ROOT/.claude/agents/workflow-conductor.md"
_T44_ENFORCE="$_T44_ROOT/docs/ai/hook-enforcement.md"

# ── 適用判定: 未適用なら SKIP（fail にしない）──────────────────────
if ! grep -q "Phase-Gate Hook 配線契約（TASK-0143" "$_T44_CONDUCTOR" 2>/dev/null; then
  printf '  [SKIP] 群A未適用（sh scripts/apply-task-0143-hook-wiring.sh で適用後に PASS）\n'
  return 0 2>/dev/null || true
fi

# TC-01: conductor が EH-4/5/7 phase-gate hook を明文配線している
_t44_miss=0
for _h in check-test-cases.sh check-verification-evidence.sh check-merge-approvals.sh; do
  grep -q "$_h" "$_T44_CONDUCTOR" || { _t44_miss=1; printf '    miss: %s in conductor\n' "$_h" >&2; }
done
if [ "$_t44_miss" = "0" ]; then
  printf '  [PASS] TC-01 conductor が EH-4/5/7 を Phase-Gate 配線\n'; pass=$((pass + 1))
else
  printf '  [FAIL] TC-01 conductor の EH-4/5/7 配線欠落\n'; fail=$((fail + 1))
fi

# TC-07: hook-enforcement.md 配線表が群A配線済みを反映
if grep -q "配線済み（群A / TASK-0143）" "$_T44_ENFORCE" 2>/dev/null; then
  printf '  [PASS] TC-07 hook-enforcement.md 配線表が群A配線済みを反映\n'; pass=$((pass + 1))
else
  printf '  [FAIL] TC-07 配線表が群A未反映\n'; fail=$((fail + 1))
fi
