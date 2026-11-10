# tests/extras/ta-119-eh3-plan-create.sh
# PG_EXTRA_CAPABILITY: standalone-capable
# Sourced by tests/run-tests.sh — uses $pass / $fail counters
#
# #1197 案 B: EH-3 の no-task 分岐で、未承認 TASK の plan.md 初回作成（Write）だけを許可する。
#
# 期待値ポリシー（ta-79 と同型）:
#   - 既定の期待値は fixed（patch 適用後の挙動）
#   - 未適用は tests/fixtures/eh3-plan-create-pending-1197.flag の存在による明示 opt-in でのみ gap を許容
#   - flag があるのに実 hook が適用済みなら stale 宣言として FAIL（TC-00b）
#
# レーン:
#   P: patch 文書の PG-PATCH を mktemp 複製へ当てた hook に全 TC を流す（Human 適用を待たずに測る）
#   R: 実 hook。fixed なら全 TC、gap なら「許可ケースがまだ block である」ことだけを測る
#   M: 変異注入（PG_T119_MUTATION=1 の opt-in。所要 約 8 分のため既定では走らせない）
#
# TC の本体は tests/fixtures/eh3-plan-create-1197/cases.sh（子プロセスで実行）。
# 各 TC は mktemp -d 配下に git sandbox を作り、作成に失敗したら ABORT（rc=3）する。
# ABORT は PASS に数えない（前提不成立のまま素通りさせない）。
#
# 一時状態の射程（README 規約 9）: mktemp -d 配下のみ。実 repo の tracked / 共有パスには書かない。

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
pg_extra_contract_init ta-119-eh3-plan-create standalone-capable

printf '\n=== TA-119: EH-3 plan.md initial creation for unapproved TASK (#1197) ===\n'

if pg_extra_contract_is_standalone; then
  unset PLANGATE_SKIP_REASON PLANGATE_HOOK_TASK PLANGATE_HOOK_FILE \
    PLANGATE_BYPASS_HOOK PLANGATE_HOOK_STRICT PG_HARNESS_SOURCED 2>/dev/null || true
fi

if [ "$_pg_extra_mode" = harness ]; then
  _T119_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
else
  _T119_ROOT="${_pg_extra_dir%/tests/extras}"
fi

t119_pass() { pass=$((pass + 1)); printf '  [PASS] %s\n' "$1"; }
t119_fail() { fail=$((fail + 1)); printf '  [FAIL] %s\n' "$1" >&2; }

_T119_HOOK="$_T119_ROOT/scripts/hooks/check-plan-hash.sh"
_T119_DOC="$_T119_ROOT/docs/working/_reports/1197-eh3-plan-create-patch.md"
_T119_FLAG="$_T119_ROOT/tests/fixtures/eh3-plan-create-pending-1197.flag"
_T119_CASES="$_T119_ROOT/tests/fixtures/eh3-plan-create-1197/cases.sh"
_T119_MUTS="$_T119_ROOT/tests/fixtures/eh3-plan-create-1197/mutants.sh"
_T119_MARK="PLAN_CREATE_ALLOW"

_T119_OK=1
for _t119_f in "$_T119_ROOT/bin/plangate" "$_T119_HOOK" "$_T119_DOC" "$_T119_CASES" "$_T119_MUTS"; do
  if [ ! -f "$_t119_f" ]; then
    t119_fail "TC-00: required file missing: $_t119_f"
    _T119_OK=0
  fi
done
if [ "$_T119_OK" = "1" ]; then
  for _t119_c in git jq python3; do
    if ! command -v "$_t119_c" >/dev/null 2>&1; then
      pg_extra_contract_skip "$_t119_c unavailable"
      _T119_OK=0
      break
    fi
  done
fi

if [ "$_T119_OK" = "1" ]; then

_T119_TMP=$(mktemp -d)
if command -v register_cleanup >/dev/null 2>&1; then
  register_cleanup "$_T119_TMP"
fi

# cases.sh の 1 行ずつを pass/fail に写す。$1=レーン名 $2=hook $3=filter
# 出力: _T119_RUN_RC（cases.sh の rc）。ABORT は FAIL に数える。
_T119_RUN_RC=0
_t119_lane() {
  _T119_RUN_RC=0
  sh "$_T119_CASES" "$2" "$3" >"$_T119_TMP/lane.out" 2>&1 || _T119_RUN_RC=$?
  while IFS= read -r _t119_l; do
    case "$_t119_l" in
      "  [PASS] "*) t119_pass "$1 ${_t119_l#  \[PASS\] }" ;;
      "  [FAIL] "*) t119_fail "$1 ${_t119_l#  \[FAIL\] }" ;;
      "  [ABORT] "*) t119_fail "$1 sandbox ABORT: ${_t119_l#  \[ABORT\] }" ;;
      "  [KNOWN-GAP] "*) printf '  [INFO] %s %s\n' "$1" "${_t119_l#  }" ;;
    esac
  done <"$_T119_TMP/lane.out"
}

# ── patch 抽出（awk / fence 長・空行に依存しない）──────────────────
awk 'BEGIN{q=sprintf("%c",96)}
     /^<!-- PG-PATCH-BEGIN -->$/{b=1;next}
     /^<!-- PG-PATCH-END -->$/{exit}
     b && substr($0,1,1)==q{f=!f;next}
     f' "$_T119_DOC" >"$_T119_TMP/1197.patch" 2>/dev/null || true
if [ -s "$_T119_TMP/1197.patch" ] && head -1 "$_T119_TMP/1197.patch" | grep -qF -- 'diff --git a/scripts/hooks/check-plan-hash.sh '; then
  t119_pass "TC-00a: PG-PATCH block extracted"
else
  t119_fail "TC-00a: PG-PATCH block extraction failed ($_T119_DOC)"
fi

# ── 実 hook の適用状態と flag ──────────────────────────────────────
_T119_REAL=0
grep -qF -- "$_T119_MARK" "$_T119_HOOK" && _T119_REAL=1
_T119_FLAGP=0
[ -f "$_T119_FLAG" ] && _T119_FLAGP=1
if [ "$_T119_FLAGP" = "1" ]; then _T119_EXPECT=gap; else _T119_EXPECT=fixed; fi
if [ "$_T119_FLAGP" = "1" ] && [ "$_T119_REAL" = "1" ]; then
  t119_fail "TC-00b: stale gap flag — patch は適用済みなのに $_T119_FLAG が残っている（削除すること）"
else
  t119_pass "TC-00b: flag と実装状態が整合 (flag=$_T119_FLAGP patched=$_T119_REAL expect=$_T119_EXPECT)"
fi

# ── patched 複製を作る ─────────────────────────────────────────────
_T119_STAGE="$_T119_TMP/stage"
mkdir -p "$_T119_STAGE/scripts/hooks"
cp "$_T119_HOOK" "$_T119_STAGE/scripts/hooks/check-plan-hash.sh"
_T119_PATCHED=""
if [ "$_T119_REAL" = "1" ]; then
  _T119_PATCHED="$_T119_HOOK"
  t119_pass "TC-00c: real hook already patched; lane P uses it"
else
  _t119_ap=$( (cd "$_T119_STAGE" && git apply -v "$_T119_TMP/1197.patch") 2>&1) && _t119_aprc=0 || _t119_aprc=$?
  if [ "$_t119_aprc" = "0" ] && ! printf '%s' "$_t119_ap" | grep -qF -- 'offset'; then
    _T119_PATCHED="$_T119_STAGE/scripts/hooks/check-plan-hash.sh"
    t119_pass "TC-00c: patch applies to a copy of the real hook without offset"
  else
    t119_fail "TC-00c: patch does not apply cleanly (rc=$_t119_aprc): $(printf '%s' "$_t119_ap" | tail -2 | tr '\n' ' ')"
  fi
fi

# ── レーン P: patched hook に全 TC ────────────────────────────────
if [ -n "$_T119_PATCHED" ]; then
  _t119_lane "P:" "$_T119_PATCHED" "."
fi

# ── レーン R: 実 hook ─────────────────────────────────────────────
if [ "$_T119_EXPECT" = "fixed" ]; then
  _t119_lane "R:" "$_T119_HOOK" "."
else
  # gap: 許可ケースの主ケース（TC-01）が実 hook ではまだ block であること。
  _T119_RUN_RC=0
  sh "$_T119_CASES" "$_T119_HOOK" 'TC-01' >"$_T119_TMP/gap.out" 2>&1 || _T119_RUN_RC=$?
  if [ "$_T119_RUN_RC" = "1" ] && grep -qF -- '[FAIL] TC-01 want=allow got=block' "$_T119_TMP/gap.out"; then
    t119_pass "R: gap observed — TC-01 is still block on the unpatched real hook (flag present)"
  else
    t119_fail "R: gap expected but not observed (rc=$_T119_RUN_RC): $(head -2 "$_T119_TMP/gap.out" | tr '\n' ' ')"
  fi
fi

# ── レーン M: 変異注入（opt-in）──────────────────────────────────
if [ "${PG_T119_MUTATION:-0}" = "1" ] && [ -n "$_T119_PATCHED" ]; then
  _t119_mrc=0
  sh "$_T119_MUTS" "$_T119_PATCHED" >"$_T119_TMP/mut.out" 2>&1 || _t119_mrc=$?
  if [ "$_t119_mrc" = "0" ]; then
    t119_pass "M: $(grep -F -- 'MUT ' "$_T119_TMP/mut.out" | tail -1)"
  else
    grep -vF -- '[KILLED]' "$_T119_TMP/mut.out" >&2
    t119_fail "M: mutation lane rc=$_t119_mrc"
  fi
fi

rm -rf "$_T119_TMP"
if [ -e "$_T119_TMP" ]; then
  t119_fail "TC-99: sandbox cleanup failed: $_T119_TMP"
fi

fi

pg_extra_contract_finalize
