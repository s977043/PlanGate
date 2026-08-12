# tests/extras/ta-47-ehs23-wiring.sh
# PG_EXTRA_CAPABILITY: standalone-capable
# Sourced by tests/run-tests.sh — uses $pass / $fail counters
# TASK-0146 (#527): EHS-2/3 strict 発火配線（増分2: EHS-3 fix-loop / 増分3: EHS-2 handoff）
#
# 前提: scripts/apply-task-0146-ehs23-wiring.sh --apply で bin/plangate に適用済み。
#   未適用時は SKIP（ta-45/46 と同方式: apply 済みでなければ skip して CI を割らない）。

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
pg_extra_contract_init ta-47-ehs23-wiring standalone-capable

printf '\n=== TA-47: EHS-2/3 strict 発火配線 (#527 TASK-0146) ===\n'

if [ "${PG_HARNESS_SOURCED:-0}" = "1" ] && [ -n "${FIXTURES_DIR:-}" ]; then
  _T47_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
else
  # standalone 実行: 外部 env 汚染を無害化（tests/extras/README.md 規約 8。
  # unset 集合は run-tests.sh 冒頭と同一の 7 env — TASK-0914 論点 F）
  unset PLANGATE_SKIP_REASON PLANGATE_HOOK_TASK PLANGATE_HOOK_FILE PLANGATE_BYPASS_HOOK PLANGATE_HOOK_STRICT PG_HARNESS_SOURCED PLANGATE_ALLOW_MASS_DELETE 2>/dev/null || true
  _T47_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
fi
_T47_PG="$_T47_ROOT/bin/plangate"

# 適用判定: 未適用なら SKIP（EHS-3 か EHS-2 の両方がなければ未適用とみなす）
if ! grep -q "EHS-3" "$_T47_PG" 2>/dev/null || ! grep -q "EHS-2" "$_T47_PG" 2>/dev/null; then
  printf '  [SKIP] EHS-2/3 未適用（sh scripts/apply-task-0146-ehs23-wiring.sh --apply で適用後に PASS）\n'
  # #921: standalone では skip が rc=3 で exit、harness では skip 後の
  # top-level return 0 で source 元へ戻る（R-021: 旧 || true 型はシェル依存）
  pg_extra_contract_skip "EHS-2/3 配線が未適用 (apply-task-0146-ehs23-wiring.sh --apply)"
  return 0
fi

# TC-01: EHS-3 が check-fix-loop.sh 呼び出し経路に配線されている
if grep -q "check-fix-loop.sh" "$_T47_PG" 2>/dev/null && grep -q "EHS-3" "$_T47_PG" 2>/dev/null; then
  printf '  [PASS] TC-01 EHS-3 が check-fix-loop.sh 呼び出しに配線\n'; pass=$((pass + 1))
else
  printf '  [FAIL] TC-01 EHS-3 check-fix-loop.sh 配線欠落\n'; fail=$((fail + 1))
fi

# TC-02: EHS-3 strict 時は return 1（block）
if grep -q 'PLANGATE_HOOK_STRICT=1 sh.*check-fix-loop.sh.*increment || return 1' "$_T47_PG" 2>/dev/null; then
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
if grep -q 'PLANGATE_HOOK_STRICT=1 sh.*check-handoff-elements.sh.*|| return 1' "$_T47_PG" 2>/dev/null; then
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

pg_extra_contract_finalize
