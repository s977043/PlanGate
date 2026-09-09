# tests/extras/ta-84-corpus-hash.sh
# PG_EXTRA_CAPABILITY: standalone-capable
# Sourced by tests/run-tests.sh — uses $pass / $fail counters
#
# #1299: harness_version.corpus_hash が enforcement 層（scripts/hooks/**）を
# 含むことの実測。
#
# 背景: corpus_hash は run_evidence.py では注入値として形式検査されるだけで、
#   「何から計算するか」の実装が存在しなかった。定義は carve-out ①②③ に閉じて
#   おり、hook（= Gate の実体）を書き換えても値が動かない状態だった。実害:
#   2026-09-08 に scripts/hooks/check-plan-hash.sh を +158/-5 したのに
#   corpus_hash は不変だった。
#
#   TC-01: unit test の CI 導線（scripts/ai-loop/test_corpus_hash.py）
#          ※ run-tests.sh は python を呼ばないため、導線が無いと一度も走らない
#   TC-02: positive control — sandbox の hook を 1 バイト変えると full が変わる
#   TC-03: 対照 — 同じ変更で carve-out（#1299 以前の定義）は変わらない
#   TC-04: 対象 0 件は exit 2（fail-closed。空 glob で「常に同じ値」にしない）
#
# 一時状態の射程（README 規約 9）: 本ファイルが作るのは mktemp -d 配下のみ。
# 実 repo の tracked / 共有パスには一切書かない。

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
pg_extra_contract_init ta-84-corpus-hash standalone-capable

if pg_extra_contract_is_standalone; then
  unset PLANGATE_SKIP_REASON PLANGATE_HOOK_TASK PLANGATE_HOOK_FILE \
    PLANGATE_BYPASS_HOOK PLANGATE_HOOK_STRICT PG_HARNESS_SOURCED \
    PLANGATE_ALLOW_MASS_DELETE 2>/dev/null || true
fi

printf '\n=== TA-84: corpus_hash enforcement coverage (#1299) ===\n'

t84_pass() { pass=$((pass + 1)); printf '  [PASS] %s\n' "$1"; }
t84_fail() { fail=$((fail + 1)); printf '  [FAIL] %s\n' "$1" >&2; }

_T84_ROOT="$(CDPATH= cd -- "$_pg_extra_dir/../.." && pwd)"
_T84_SCRIPT="$_T84_ROOT/scripts/ai-loop/corpus_hash.py"
_T84_PY="${PLANGATE_PYTHON:-python3}"

if [ ! -f "$_T84_SCRIPT" ]; then
  t84_fail "corpus_hash.py が存在しない: $_T84_SCRIPT"
else

# --- TC-01: unit test の CI 導線 -------------------------------------------
_t84_rc=0
_t84_out=$(PYTHONDONTWRITEBYTECODE=1 "$_T84_PY" "$_T84_ROOT/scripts/ai-loop/test_corpus_hash.py" 2>&1) || _t84_rc=$?
if [ "$_t84_rc" = "0" ]; then
  t84_pass "unit: test_corpus_hash.py（$(printf '%s' "$_t84_out" | sed -n 's/^Ran \([0-9]*\) tests.*/\1/p') tests）"
else
  printf '%s\n' "$_t84_out" >&2
  t84_fail "unit: test_corpus_hash.py が FAIL（exit ${_t84_rc}）"
fi

# --- TC-02 / TC-03: positive control と対照（sandbox 上で実測）--------------
# 実 repo の hook は Hardening Override 対象であり書き換えない。最小の擬似 repo で
# 「hook を 1 バイト変える」を実行し、full が動き carve-out が動かないことを対で示す。
_t84_sbx=$(mktemp -d)
register_cleanup "$_t84_sbx" 2>/dev/null || true
mkdir -p "$_t84_sbx/scripts/ai-loop" "$_t84_sbx/scripts/hooks"
printf 'engine v1\n' > "$_t84_sbx/scripts/ai-loop/engine.py"
printf '#!/bin/sh\nexit 0\n' > "$_t84_sbx/scripts/hooks/check-plan-hash.sh"

_t84_full_before=$("$_T84_PY" "$_T84_SCRIPT" --root "$_t84_sbx" --scope full 2>/dev/null || true)
_t84_carve_before=$("$_T84_PY" "$_T84_SCRIPT" --root "$_t84_sbx" --scope carve-out 2>/dev/null || true)
printf '#\n' >> "$_t84_sbx/scripts/hooks/check-plan-hash.sh"
_t84_full_after=$("$_T84_PY" "$_T84_SCRIPT" --root "$_t84_sbx" --scope full 2>/dev/null || true)
_t84_carve_after=$("$_T84_PY" "$_T84_SCRIPT" --root "$_t84_sbx" --scope carve-out 2>/dev/null || true)

if [ -n "$_t84_full_before" ] && [ "$_t84_full_before" != "$_t84_full_after" ]; then
  t84_pass "TC-02 positive control: hook 1 バイト変更で full corpus_hash が変わる"
else
  t84_fail "TC-02 positive control 不成立: full が動かない（before=$_t84_full_before after=$_t84_full_after）"
fi

if [ -n "$_t84_carve_before" ] && [ "$_t84_carve_before" = "$_t84_carve_after" ]; then
  t84_pass "TC-03 対照: 同じ変更で carve-out（#1299 以前の定義）は変わらない"
else
  t84_fail "TC-03 対照 不成立: carve-out が hook を含んでいる（before=$_t84_carve_before after=$_t84_carve_after）"
fi

# --- TC-04: 対象 0 件は fail-closed ----------------------------------------
_t84_empty=$(mktemp -d)
register_cleanup "$_t84_empty" 2>/dev/null || true
_t84_rc=0
"$_T84_PY" "$_T84_SCRIPT" --root "$_t84_empty" >/dev/null 2>&1 || _t84_rc=$?
if [ "$_t84_rc" = "2" ]; then
  t84_pass "TC-04 fail-closed: 対象 0 件は exit 2"
else
  t84_fail "TC-04 fail-closed 不成立: 対象 0 件で exit ${_t84_rc}（期待 2）"
fi

# --- TC-05: 実 repo で enforcement 層が実際に展開されている（空 glob 検出）--
_t84_hooks=$("$_T84_PY" "$_T84_SCRIPT" --root "$_T84_ROOT" --scope enforcement --explain 2>/dev/null \
  | grep -c '"scripts/hooks/' || true)
if [ "${_t84_hooks:-0}" -gt 0 ]; then
  t84_pass "TC-05 実 repo: enforcement scope に scripts/hooks/ が ${_t84_hooks} 件"
else
  t84_fail "TC-05 実 repo: enforcement scope に scripts/hooks/ が 0 件（glob 空振り）"
fi

rm -rf "$_t84_sbx" "$_t84_empty" 2>/dev/null || true
fi

# --- TC-06: producer と consumer の接続状態を **実測で固定** する（#1299 未了）----
#   producer（scripts/ai-loop/corpus_hash.py）は本 PR で新設したが、consumer
#   （scripts/ai-loop/run_evidence.py）は依然として注入値の**形式**しか見ておらず、
#   producer の計算値と照合しない。つまり producer を呼ばずに任意の 64hex を
#   注入でき、#1299 の実害（hook を変えても corpus_hash が動かない）は再現しうる。
#
#   照合を run_evidence.py に入れると golden fixture 8 件（corpus_hash が
#   プレースホルダ sha256:0…0）が byte 不一致になり、既存 unit が 13 件落ちる
#   （実測）。fixture の再生成とセットで別 PBI とする。
#
#   ここでは **未接続であること自体を実測として固定**する。接続されたらこの TC が
#   赤くなり、SKILL.md / 契約 doc の「機械強制は未接続」記述の更新を強制する
#   （ta-83 TC-11 と同じ「盲点の実測固定」パターン）。
_t84_re="$_T84_ROOT/scripts/ai-loop/run_evidence.py"
if [ -f "$_t84_re" ]; then
  if grep -q "import corpus_hash" "$_t84_re" 2>/dev/null; then
    t84_fail "TC-06 run_evidence.py が corpus_hash を import している — producer と consumer が接続された。SKILL.md / run-evidence-contract.md の「機械強制は未接続」記述と、本 TC を更新すること"
  else
    t84_pass "TC-06 producer と consumer は未接続（run_evidence.py は形式検査のみ）— #1299 の follow-up として固定"
  fi
else
  t84_fail "TC-06 run_evidence.py が見つからない: $_t84_re"
fi

pg_extra_contract_finalize
