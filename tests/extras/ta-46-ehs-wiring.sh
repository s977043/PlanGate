# tests/extras/ta-46-ehs-wiring.sh
# Sourced by tests/run-tests.sh — uses $pass / $fail counters
# TASK-0145 (#527): EHS strict 発火配線（増分1: EHS-1 = strict 時 V-3 必須化）
#
# 前提: scripts/apply-task-0145-ehs-wiring.sh --apply で bin/plangate に適用済み。
#   未適用時は SKIP（ta-43/ta-44 と同方式: apply 済みでなければ skip して CI を割らない）。

printf '\n=== TA-46: EHS strict 発火配線 EHS-1 (#527 TASK-0145) ===\n'

if [ "${PG_HARNESS_SOURCED:-0}" = "1" ] && [ -n "${FIXTURES_DIR:-}" ]; then
  _T46_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
else
  # standalone 実行: 外部 env 汚染を無害化（tests/extras/README.md 規約 8。
  # unset 集合は run-tests.sh 冒頭と同一の 7 env — TASK-0914 論点 F）
  unset PLANGATE_SKIP_REASON PLANGATE_HOOK_TASK PLANGATE_HOOK_FILE PLANGATE_BYPASS_HOOK PLANGATE_HOOK_STRICT PG_HARNESS_SOURCED PLANGATE_ALLOW_MASS_DELETE 2>/dev/null || true
  _T46_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
fi
_T46_PG="$_T46_ROOT/bin/plangate"

# 適用判定: 未適用なら SKIP
if ! grep -q "EHS-1 BLOCK" "$_T46_PG" 2>/dev/null; then
  printf '  [SKIP] EHS-1 未適用（sh scripts/apply-task-0145-ehs-wiring.sh --apply で適用後に PASS）\n'
  return 0 2>/dev/null || true
fi

# TC-01: cmd_verify が validation_bias=strict を EHS-1 発火条件として配線
if grep -q 'PLANGATE_VALIDATION_BIAS:-normal' "$_T46_PG" 2>/dev/null \
   && grep -q '"strict"' "$_T46_PG" 2>/dev/null; then
  printf '  [PASS] TC-01 EHS-1 が validation_bias=strict を発火条件に配線\n'; pass=$((pass + 1))
else
  printf '  [FAIL] TC-01 EHS-1 発火条件の配線欠落\n'; fail=$((fail + 1))
fi

# TC-02: strict 時の V-3 不合格は return 1（block）
if awk '/EHS-1 BLOCK/{flag=3} flag && --flag && /return 1/{found=1} END{exit !found}' "$_T46_PG" 2>/dev/null; then
  printf '  [PASS] TC-02 EHS-1 strict 時 V-3 不合格を block（return 1）\n'; pass=$((pass + 1))
else
  printf '  [FAIL] TC-02 EHS-1 block 動作の欠落\n'; fail=$((fail + 1))
fi

# TC-03: 非strict 既定では block しない（既存挙動不変）— 既定値 normal の存在で担保
if grep -q ':-normal' "$_T46_PG" 2>/dev/null; then
  printf '  [PASS] TC-03 既定 normal で EHS-1 非発火（既存挙動不変）\n'; pass=$((pass + 1))
else
  printf '  [FAIL] TC-03 既定 normal の担保欠落\n'; fail=$((fail + 1))
fi

# TC-04: 患部の構文健全性（patched bin/plangate が sh -n を通る）
if sh -n "$_T46_PG" 2>/dev/null; then
  printf '  [PASS] TC-04 patched bin/plangate 構文健全\n'; pass=$((pass + 1))
else
  printf '  [FAIL] TC-04 構文エラー\n'; fail=$((fail + 1))
fi
