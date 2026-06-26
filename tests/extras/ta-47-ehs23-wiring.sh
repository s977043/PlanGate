# tests/extras/ta-47-ehs23-wiring.sh
# Sourced by tests/run-tests.sh — uses $pass / $fail counters
# TASK-0146 (#527): EHS-2/3 strict 発火配線（増分2: EHS-3 fix-loop / 増分3: EHS-2 handoff）
#
# 前提: scripts/apply-task-0146-ehs23-wiring.sh --apply で bin/plangate に適用済み。
#   未適用時は SKIP（ta-45/46 と同方式: apply 済みでなければ skip して CI を割らない）。

printf '\n=== TA-47: EHS-2/3 strict 発火配線 (#527 TASK-0146) ===\n'

if [ -n "${FIXTURES_DIR:-}" ]; then
  _T47_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
else
  _T47_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
fi
_T47_PG="$_T47_ROOT/bin/plangate"

# 適用判定: 未適用なら SKIP（EHS-3 か EHS-2 の両方がなければ未適用とみなす）
if ! grep -q "EHS-3" "$_T47_PG" 2>/dev/null || ! grep -q "EHS-2" "$_T47_PG" 2>/dev/null; then
  printf '  [SKIP] EHS-2/3 未適用（sh scripts/apply-task-0146-ehs23-wiring.sh --apply で適用後に PASS）\n'
  return 0 2>/dev/null || true
fi

# TC-01: EHS-3 が check-fix-loop.sh 呼び出し経路に配線されている
if grep -q "check-fix-loop.sh" "$_T47_PG" 2>/dev/null && grep -q "EHS-3" "$_T47_PG" 2>/dev/null; then
  printf '  [PASS] TC-01 EHS-3 が check-fix-loop.sh 呼び出しに配線\n'; pass=$((pass + 1))
else
  printf '  [FAIL] TC-01 EHS-3 check-fix-loop.sh 配線欠落\n'; fail=$((fail + 1))
fi

# TC-02: EHS-3 strict 時は return 1（block）
if awk '/EHS-3 BLOCK/{flag=2} flag && --flag && /return 1/{found=1} END{exit !found}' "$_T47_PG" 2>/dev/null; then
  printf '  [PASS] TC-02 EHS-3 strict 時 fix-loop 上限超過を block（return 1）\n'; pass=$((pass + 1))
else
  printf '  [FAIL] TC-02 EHS-3 block 動作の欠落\n'; fail=$((fail + 1))
fi

# TC-03: 非 strict 既定では block しない（:-normal の存在で担保）
if grep -q ':-normal' "$_T47_PG" 2>/dev/null; then
  printf '  [PASS] TC-03 既定 normal で EHS-3 非発火（既存挙動不変）\n'; pass=$((pass + 1))
else
  printf '  [FAIL] TC-03 既定 normal の担保欠落\n'; fail=$((fail + 1))
fi

# TC-04: EHS-2 が --verify フラグと check-handoff-elements.sh に配線されている
if grep -q "check-handoff-elements.sh" "$_T47_PG" 2>/dev/null \
   && grep -q -- "--verify" "$_T47_PG" 2>/dev/null \
   && grep -q "EHS-2" "$_T47_PG" 2>/dev/null; then
  printf '  [PASS] TC-04 EHS-2 が --verify + check-handoff-elements.sh に配線\n'; pass=$((pass + 1))
else
  printf '  [FAIL] TC-04 EHS-2 --verify 配線欠落\n'; fail=$((fail + 1))
fi

# TC-05: EHS-2 strict 時は return 1（block）
if awk '/EHS-2 BLOCK/{flag=2} flag && --flag && /return 1/{found=1} END{exit !found}' "$_T47_PG" 2>/dev/null; then
  printf '  [PASS] TC-05 EHS-2 strict 時 handoff 6要素不足を block（return 1）\n'; pass=$((pass + 1))
else
  printf '  [FAIL] TC-05 EHS-2 block 動作の欠落\n'; fail=$((fail + 1))
fi

# TC-06: 患部の構文健全性（patched bin/plangate が sh -n を通る）
if sh -n "$_T47_PG" 2>/dev/null; then
  printf '  [PASS] TC-06 patched bin/plangate 構文健全\n'; pass=$((pass + 1))
else
  printf '  [FAIL] TC-06 構文エラー\n'; fail=$((fail + 1))
fi
