# tests/extras/ta-60-run-evidence.sh
# Sourced by tests/run-tests.sh -- uses $pass / $fail counters
# RunEvidence 契約（TASK-0874 / #874）: golden fixture 10 件 / 受理器 exit code /
# 新規 unit test 2 本の CI 導線 / EH-8 実走
#
# 背景:
#   1. run-tests.sh は python を一切呼ばず tests/extras/*.sh を glob source する
#      だけなので、導線が無いと新規 unit test が CI で一度も実行されない
#      （TASK-0917 R-020 の実害型）。③ で 2 モジュールを 1 PASS 行ずつ実行する。
#   2. .github/workflows/metrics-privacy.yml の scan 対象は
#      `grep -v '^tests/fixtures/'` で tests/fixtures/ を明示除外しており、
#      .claude/settings.example.json の hooks にも EH-8 は存在しない。
#      ⇒ 本 PBI が commit する 10 fixture にだけ CI の自動強制が効かないため、
#      ④ で EH-8 本体を実走させて回帰保護を持たせる。
#
# 隔離（tests/extras/README.md §隔離・後始末の規約）:
#   commit 済み fixture は読むだけ。書き込みは mktemp サンドボックスに限定し、
#   trap は張らず register_cleanup + 末尾明示 rm -rf の二重で回収する。

printf '\n=== TA-60: RunEvidence contract (#874) ===\n'

# 単体実行 fallback（#877 F3 / README 規約）: PG_HARNESS_SOURCED と FIXTURES_DIR
# の AND で判別し、片方でも欠ければ standalone（安全側）へ倒す。
if [ "${PG_HARNESS_SOURCED:-0}" != "1" ] || [ -z "${FIXTURES_DIR:-}" ]; then
  _T60_STANDALONE=1
  unset PLANGATE_SKIP_REASON PLANGATE_HOOK_TASK PLANGATE_HOOK_FILE \
    PLANGATE_BYPASS_HOOK PLANGATE_HOOK_STRICT PG_HARNESS_SOURCED \
    PLANGATE_ALLOW_MASS_DELETE 2>/dev/null || true
  FIXTURES_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/../fixtures" && pwd)"
  pass=0
  fail=0
  _T60_CLEANUP_PATHS=""
  register_cleanup() {
    for _pg_cp in "$@"; do
      if [ -n "$_pg_cp" ]; then
        _T60_CLEANUP_PATHS="${_T60_CLEANUP_PATHS}${_pg_cp}
"
      fi
    done
  }
else
  _T60_STANDALONE=0
fi

_T60_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
_T60_FX="$FIXTURES_DIR/run-evidence"
_T60_AI_LOOP="$_T60_ROOT/scripts/ai-loop"
_T60_VERIFY="$_T60_AI_LOOP/run_evidence_verify.py"
_T60_PY="${PLANGATE_PYTHON:-python3}"

t60_pass() { pass=$((pass + 1)); printf '  [PASS] %s\n' "$1"; }
t60_fail() { fail=$((fail + 1)); printf '  [FAIL] %s\n' "$1" >&2; }

# --- ① golden fixture 10 件の存在と命名（TC-48 の件数側）--------------------
_t60_count=$(find "$_T60_FX" -name '*.json' -type f | wc -l | tr -d ' ')
if [ "$_t60_count" = "10" ]; then
  t60_pass "fixture: golden 10 件（issue verbatim の必須 fixture 数）"
else
  t60_fail "fixture: golden が 10 件でない（実測 $_t60_count 件）"
fi

_t60_missing=""
for _t60_name in fx-01-first-pass fx-02-ci-repair fx-03-review-repair \
  fx-04-human-escalated fx-05-blocked fx-06-routing-escalation \
  fx-07-tampered-expected-errors fx-08-shadow-candidate-input \
  fx-09-paired-replay fx-10-canary-rollback; do
  [ -f "$_T60_FX/$_t60_name.json" ] || _t60_missing="$_t60_missing $_t60_name"
done
if [ -z "$_t60_missing" ]; then
  t60_pass "fixture: 10 件の命名が AC↔fixture 対応表と一致"
else
  t60_fail "fixture: 欠落 ->$_t60_missing"
fi

# --- ② 受理器 exit code の検証 ---------------------------------------------
# 0（complete）と 11（partial）は task_dir 束縛の再計算照合を要するため
# ③ の unit test（test_run_evidence_verify.py / test_run_evidence.py）が担う。
# ここでは task_dir を要さない 1（NG）と 10（legacy）を shell から固定する。
_t60_sbx=$(mktemp -d)
register_cleanup "$_t60_sbx"

# 10 = legacy（EV ではなく arbiter record を渡された）
_t60_legacy="$_t60_sbx/legacy.json"
cat >"$_t60_legacy" <<'JSON'
{"boundary_check": {}, "class_check": {}, "decision": "AUTO_APPROVED",
 "issued_by": "arbiter-v0.1", "lite_check": {}, "policy_ref": "p@v4",
 "target_sha": "abc1234", "timestamp": "2100-01-01T00:00:00Z", "w_check": {}}
JSON
_t60_rc=0
"$_T60_PY" "$_T60_VERIFY" "$_t60_legacy" "$_t60_sbx/TASK-9999" >/dev/null 2>&1 || _t60_rc=$?
if [ "$_t60_rc" = "10" ]; then
  t60_pass "verifier: arbiter record -> exit 10（legacy 委譲・c3prime_verify と同一意味）"
else
  t60_fail "verifier: legacy の exit が 10 でない（実測 ${_t60_rc}）"
fi

# 1 = NG（必須キー欠落）。fixture 1 から 1 キー落として渡す。
_t60_broken="$_t60_sbx/broken.json"
"$_T60_PY" -c "
import json, sys
data = json.load(open(sys.argv[1], encoding='utf-8'))
del data['terminal_state']
json.dump(data, open(sys.argv[2], 'w', encoding='utf-8'), sort_keys=True)
" "$_T60_FX/fx-01-first-pass.json" "$_t60_broken"
_t60_rc=0
_t60_err=$("$_T60_PY" "$_T60_VERIFY" "$_t60_broken" "$_t60_sbx/TASK-9999" 2>&1) || _t60_rc=$?
if [ "$_t60_rc" = "1" ]; then
  case "$_t60_err" in
    *terminal_state*) t60_pass "verifier: 必須キー欠落 -> exit 1 + 欠落キー名を stderr へ" ;;
    *) t60_fail "verifier: exit 1 だが欠落キー名が stderr に無い" ;;
  esac
else
  t60_fail "verifier: 必須キー欠落の exit が 1 でない（実測 ${_t60_rc}）"
fi

# fixture 7（期待エラー列）は 0 を期待値に持たない
_t60_rc=0
"$_T60_PY" -c "
import json, sys
spec = json.load(open(sys.argv[1], encoding='utf-8'))
exits = [c['expected_exit'] for c in spec['cases']]
assert exits, 'cases が空'
assert 0 not in exits, f'tampered/partial が exit 0 を期待している: {exits}'
" "$_T60_FX/fx-07-tampered-expected-errors.json" >/dev/null 2>&1 || _t60_rc=$?
if [ "$_t60_rc" = "0" ]; then
  t60_pass "fixture 7: 期待 exit がケースごとに一意（0 を含まない）"
else
  t60_fail "fixture 7: 期待 exit の固定が壊れている"
fi

# --- ③ 新規 unit test 2 本の CI 導線（TC-47）--------------------------------
# これが無いと run-tests.sh は python を呼ばないため一度も実行されない。
# 2 モジュールが 1 PASS 行ずつ現れることが TC-47 の期待出力そのもの。
for _t60_mod in test_run_evidence test_run_evidence_verify; do
  _t60_rc=0
  _t60_out=$("$_T60_PY" "$_T60_AI_LOOP/$_t60_mod.py" 2>&1) || _t60_rc=$?
  if [ "$_t60_rc" = "0" ]; then
    t60_pass "unit: $_t60_mod.py（$(printf '%s' "$_t60_out" | sed -n 's/^Ran \([0-9]*\) tests.*/\1/p') tests）"
  else
    printf '%s\n' "$_t60_out" >&2
    t60_fail "unit: $_t60_mod.py が FAIL（exit ${_t60_rc}）"
  fi
done

# --- ④ EH-8 本体の実走（TC-22 / privacy CI が tests/fixtures/ を除外するため）
_t60_files=""
for _t60_f in "$_T60_FX"/*.json; do
  _t60_files="$_t60_files $_t60_f"
done
_t60_rc=0
PLANGATE_HOOK_STRICT=1 PLANGATE_HOOK_FILES="$_t60_files" \
  sh "$_T60_ROOT/scripts/hooks/check-metrics-privacy.sh" >/dev/null 2>&1 || _t60_rc=$?
if [ "$_t60_rc" = "0" ]; then
  t60_pass "EH-8: golden fixture 10 件が privacy 検査を通過（自主規制でなく hook で証明）"
else
  t60_fail "EH-8: golden fixture が BLOCK された（exit ${_t60_rc}）"
fi

# --- ⑤ plugin 同期リストの drift 検出（2 箇所の basename 集合が一致するか） ---
# sync-plugin-plangate.sh は「コピー対象の for ループ」と「whitelist の case 文」の
# 2 箇所に同じ basename を書く。片方だけ更新すると sync drift になる。
_t60_rc=0
"$_T60_PY" - "$_T60_ROOT/scripts/sync-plugin-plangate.sh" <<'PY' >/dev/null 2>&1 || _t60_rc=$?
import pathlib, re, sys
text = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
loop = re.search(r'for _f in ("\$AI_LOOP_SCRIPTS_DIR/.*?); do', text, re.S).group(1)
listed = sorted(re.findall(r"AI_LOOP_SCRIPTS_DIR/([A-Za-z0-9_]+\.py)", loop))
case = re.search(r"^\s+(arbiter\.py\|.*?)\) : ;;", text, re.M).group(1)
assert listed == sorted(case.split("|")), (
    f"sync drift: loop-only={sorted(set(listed) - set(case.split('|')))} "
    f"case-only={sorted(set(case.split('|')) - set(listed))}")
PY
if [ "$_t60_rc" = "0" ]; then
  t60_pass "sync: sync-plugin-plangate.sh の 2 箇所の basename 集合が一致"
else
  t60_fail "sync: sync-plugin-plangate.sh の 2 箇所に drift がある"
fi

# --- 後始末（trap 不使用 / register_cleanup と末尾明示 rm の二重） -----------
rm -rf "$_t60_sbx"

if [ "$_T60_STANDALONE" = "1" ]; then
  printf '\nTA-60 standalone: pass=%s fail=%s\n' "$pass" "$fail"
  [ "$fail" = "0" ] || exit 1
fi
