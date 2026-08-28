# tests/extras/ta-79-eh3-bash-lane.sh
# PG_EXTRA_CAPABILITY: standalone-capable
# Sourced by tests/run-tests.sh — uses $pass / $fail counters
#
# #1104 / PR #1267 hotfix: EH-3 の **Bash レーン**を実行時 payload で測る。
#
# 背景（PR #1267 = origin/main 3f0cadd が main に入れた critical）:
#   .claude/settings.example.json の PreToolUse matcher "Bash" に
#   check-plan-hash.sh が配線されたが、同 hook の対象パス抽出は
#   tool_input.file_path のみを見る。Bash payload が持つのは tool_input.command
#   なので target_file が常に空になり、実測では次の 3 点だけが起きる:
#     (1) HO 判定は 1 度も一致しない（#1104 が塞ごうとした穴は塞がっていない）
#     (2) no-task セッションでは SKIP_REASON 未設定として **全 Bash が exit 2**
#     (3) SKIP_REASON を設定すると skip-decision-log へ未追認エントリが増え CI FAIL
#   **Bash 形状の PreToolUse payload を hook へ流す TC が 1 件も無かった**ことが、
#   この critical が 2 本のレビューを通り抜けた直接の原因。本ファイルがそれを埋める。
#
# 期待値ポリシー（ta-65 と同型）:
#   - 既定の期待値は **fixed**（patch 適用後の挙動）。実装が元へ戻れば CI が RED になる
#   - 未適用は tests/fixtures/eh3-bash-lane-pending-1104.flag という
#     **tracked ファイルの存在による明示 opt-in** でのみ gap を許容する
#   - flag があるのに実装が fixed なら **stale 宣言として FAIL**（TC-00b）
#   - PG_T79_EXPECT=fixed|gap で pin できる（デバッグ用。失敗を増やす方向のみ）
#
# patch 済み複製（TC-P*）は Human 適用を待たずに patch 内容そのものを実測する。
# patch は docs/working/_reports/1104-bash-lane-noop-patch-applicable.md の
# <!-- PG-PATCH-BEGIN --> / <!-- PG-PATCH-END --> block から抽出する
# （= その block が壊れると本ファイルが FAIL する）。
#
# 変異注入（TC-08）: patch 済み複製へ 4 種の変異を当て、**各変異が対応する TC を
# 実際に FAIL させる**ことを実測する（新 TC の検出力の実証）。変異は関数本体では
# なく **call site の条件・分岐**を壊す。
#
# 隔離: hook の REPO_ROOT は $0 由来なので mktemp サンドボックス複製で実 repo を
# 汚さない（tests/extras/README.md 規約 3 /「できること / できないこと」節）。
#
# 一時状態の射程（README 規約 9）: 本ファイルが作るのは mktemp -d 配下のみ。
# 実 repo の tracked / 共有パスには一切書かない（先頭 prune の対象なし）。

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
pg_extra_contract_init ta-79-eh3-bash-lane standalone-capable

printf '\n=== TA-77: EH-3 Bash lane (#1104 / PR #1267 hotfix) ===\n'

if [ "${PG_HARNESS_SOURCED:-0}" = "1" ] && [ -n "${FIXTURES_DIR:-}" ]; then
  _T79_FX="$FIXTURES_DIR"
else
  # standalone: 外部 env 汚染を無害化（tests/extras/README.md 規約 8）
  unset PLANGATE_SKIP_REASON PLANGATE_HOOK_TASK PLANGATE_HOOK_FILE \
    PLANGATE_BYPASS_HOOK PLANGATE_HOOK_STRICT PG_HARNESS_SOURCED \
    PLANGATE_ALLOW_MASS_DELETE 2>/dev/null || true
  _T79_FX=""
fi
if [ -n "$_T79_FX" ]; then
  _T79_ROOT="$(CDPATH= cd -- "$_T79_FX/../.." && pwd)"
else
  _T79_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
fi

t79_pass() { pass=$((pass + 1)); printf '  [PASS] %s\n' "$1"; }
t79_fail() { fail=$((fail + 1)); printf '  [FAIL] %s\n' "$1" >&2; }

# 非空チェックだけでは `/` を弾けないので実体で確かめる（README 規約 9）
_T79_OK=1
if [ -z "$_T79_ROOT" ] || [ ! -f "$_T79_ROOT/bin/plangate" ]; then
  t79_fail "ta-79 TC-00: repo root unresolved (_T79_ROOT=$_T79_ROOT)"
  _T79_OK=0
fi

_T79_HOOK_SRC="$_T79_ROOT/scripts/hooks/check-plan-hash.sh"
_T79_SET_SRC="$_T79_ROOT/.claude/settings.example.json"
_T79_REPORT="$_T79_ROOT/docs/working/_reports/1104-bash-lane-noop-patch-applicable.md"
_T79_FLAG="$_T79_ROOT/tests/fixtures/eh3-bash-lane-pending-1104.flag"
_T79_MARK="BASH_LANE_NOOP"

if [ "$_T79_OK" = "1" ] && [ ! -f "$_T79_HOOK_SRC" ]; then
  t79_fail "ta-79 TC-00: hook not found: $_T79_HOOK_SRC"
  _T79_OK=0
fi
if [ "$_T79_OK" = "1" ] && [ ! -f "$_T79_REPORT" ]; then
  t79_fail "ta-79 TC-00: patch report not found: $_T79_REPORT"
  _T79_OK=0
fi
if [ "$_T79_OK" = "1" ] && ! command -v jq >/dev/null 2>&1; then
  pg_extra_contract_skip "jq unavailable (the Bash lane guard requires jq)"
  _T79_OK=0
fi
if [ "$_T79_OK" = "1" ] && ! command -v git >/dev/null 2>&1; then
  pg_extra_contract_skip "git unavailable (patch application requires git apply)"
  _T79_OK=0
fi

if [ "$_T79_OK" = "1" ]; then

_T79_TMP=$(mktemp -d)
if command -v register_cleanup >/dev/null 2>&1; then
  register_cleanup "$_T79_TMP"
fi

# ── ヘルパ ────────────────────────────────────────────────────────
# サンドボックス repo root を作る（hook の REPO_ROOT は $0 由来）。
_t79_mkroot() {
  mkdir -p "$1/scripts/hooks" "$1/.claude" "$1/docs/working/_audit"
  cp "$_T79_HOOK_SRC" "$1/scripts/hooks/check-plan-hash.sh"
  cp "$_T79_SET_SRC" "$1/.claude/settings.example.json"
}

# TASK 文脈用 fixture（plan_hash mismatch を作る）。
_t79_mktask() {
  mkdir -p "$1/docs/working/TASK-T79TMP/approvals"
  printf 'plan body for ta-79\n' > "$1/docs/working/TASK-T79TMP/plan.md"
  printf '{"c3_status":"APPROVED","plan_hash":"sha256:%s"}\n' \
    "0000000000000000000000000000000000000000000000000000000000000000" \
    > "$1/docs/working/TASK-T79TMP/approvals/c3.json"
}

# hook 実行。$1=hook path $2=TASK $3=SKIP_REASON $4=STRICT $5=payload JSON
# 結果は _t79_rc / _t79_out に入れる。
_t79_rc=0
_t79_out=""
_t79_run() {
  printf '%s' "$5" > "$_T79_TMP/in.json"
  _t79_rc=0
  PLANGATE_HOOK_TASK="$2" PLANGATE_SKIP_REASON="$3" PLANGATE_HOOK_STRICT="$4" \
    PLANGATE_HOOK_FILE="" PLANGATE_BYPASS_HOOK="0" \
    sh "$1" < "$_T79_TMP/in.json" > "$_T79_TMP/out.txt" 2>&1 || _t79_rc=$?
  _t79_out=$(cat "$_T79_TMP/out.txt" 2>/dev/null || true)
}

# PLANGATE_HOOK_FILE を明示する版（$2=対象パス / $3=payload）
_t79_run_file() {
  printf '%s' "$3" > "$_T79_TMP/in.json"
  _t79_rc=0
  PLANGATE_HOOK_TASK="" PLANGATE_SKIP_REASON="" PLANGATE_HOOK_STRICT="0" \
    PLANGATE_HOOK_FILE="$2" PLANGATE_BYPASS_HOOK="0" \
    sh "$1" < "$_T79_TMP/in.json" > "$_T79_TMP/out.txt" 2>&1 || _t79_rc=$?
  _t79_out=$(cat "$_T79_TMP/out.txt" 2>/dev/null || true)
}

# 判定は rc と一意 reason トークンの **対** で行う（README「PASS 判定の書き方」）。
# 戻り値でも結果を返す（変異注入が「この TC が落ちること」を測るため）。
_t79_expect() {
  if [ "$_t79_rc" = "$2" ] && printf '%s' "$_t79_out" | grep -q -- "$3"; then
    t79_pass "$1 (rc=$2 / $3)"
    return 0
  fi
  t79_fail "$1: rc=$_t79_rc (want $2) token='$3' out=[$(printf '%s' "$_t79_out" | head -1)]"
  return 1
}

# 判定のみ（pass/fail カウンタを動かさない）。変異注入用。
_t79_holds() {
  [ "$_t79_rc" = "$1" ] && printf '%s' "$_t79_out" | grep -q -- "$2"
}

# payload 定数
_T79_P_HARMLESS='{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"echo hi"}}'
_T79_P_HOWRITE='{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"echo x >> bin/plangate"}}'
_T79_P_WHO='{"hook_event_name":"PreToolUse","tool_name":"Write","tool_input":{"file_path":"bin/plangate"}}'
_T79_P_WMD='{"hook_event_name":"PreToolUse","tool_name":"Write","tool_input":{"file_path":"docs/foo.md"}}'
_T79_P_WPLAN='{"hook_event_name":"PreToolUse","tool_name":"Write","tool_input":{"file_path":"docs/working/TASK-9999/plan.md"}}'

# ── patch 抽出（marker 基準 / 行アンカー付き）────────────────────
_T79_PATCH="$_T79_TMP/1104.patch"
sed -n '/^<!-- PG-PATCH-BEGIN -->$/,/^<!-- PG-PATCH-END -->$/p' "$_T79_REPORT" \
  | sed -e '1d' -e '$d' | sed -e '1d' -e '$d' > "$_T79_PATCH" || true

if [ -s "$_T79_PATCH" ] && grep -q '^--- a/scripts/hooks/check-plan-hash.sh$' "$_T79_PATCH"; then
  t79_pass "TC-00a: patch block extracted from report (marker-anchored, non-empty)"
else
  t79_fail "TC-00a: patch block extraction failed ($_T79_REPORT)"
fi

# ── 実 hook の適用状態を測る ──────────────────────────────────────
_T79_REAL_PATCHED=0
grep -q "$_T79_MARK" "$_T79_HOOK_SRC" && _T79_REAL_PATCHED=1
_T79_FLAG_PRESENT=0
[ -f "$_T79_FLAG" ] && _T79_FLAG_PRESENT=1

# 期待値の決定（既定 fixed / flag があるときだけ gap）
if [ -n "${PG_T79_EXPECT:-}" ]; then
  _T79_EXPECT="$PG_T79_EXPECT"
elif [ "$_T79_FLAG_PRESENT" = "1" ]; then
  _T79_EXPECT=gap
else
  _T79_EXPECT=fixed
fi

# TC-00b: stale 宣言の検出（flag が残っているのに実装は fixed）
if [ "$_T79_FLAG_PRESENT" = "1" ] && [ "$_T79_REAL_PATCHED" = "1" ]; then
  t79_fail "TC-00b: stale gap flag — patch は適用済みなのに $_T79_FLAG が残っている（削除すること）"
else
  t79_pass "TC-00b: gap flag と実装状態が整合 (flag=$_T79_FLAG_PRESENT patched=$_T79_REAL_PATCHED expect=$_T79_EXPECT)"
fi

# TC-00c: patch がサンドボックス複製へ適用できる（Human 適用を待たずに測る seam）
_T79_PATCHED="$_T79_TMP/patched"
_t79_mkroot "$_T79_PATCHED"
_t79_mktask "$_T79_PATCHED"
_T79_APPLY_RC=0
if [ "$_T79_REAL_PATCHED" = "1" ]; then
  # 既に適用済みなら複製もそのまま fixed
  t79_pass "TC-00c: real hook already patched — sandbox copy is fixed as-is"
else
  (cd "$_T79_PATCHED" && git apply "$_T79_PATCH") >/dev/null 2>&1 || _T79_APPLY_RC=$?
  if [ "$_T79_APPLY_RC" = "0" ] && grep -q "$_T79_MARK" "$_T79_PATCHED/scripts/hooks/check-plan-hash.sh"; then
    t79_pass "TC-00c: patch applies to sandbox copy and installs the $_T79_MARK branch"
  else
    t79_fail "TC-00c: patch failed to apply to sandbox copy (rc=$_T79_APPLY_RC)"
  fi
fi

# TC-00d: patch 適用後の hook が sh -n を通る / settings.example.json が valid JSON
if sh -n "$_T79_PATCHED/scripts/hooks/check-plan-hash.sh" 2>/dev/null; then
  t79_pass "TC-00d-1: patched hook passes sh -n"
else
  t79_fail "TC-00d-1: patched hook has a syntax error"
fi
if python3 -c 'import json,sys; json.load(open(sys.argv[1]))' \
     "$_T79_PATCHED/.claude/settings.example.json" >/dev/null 2>&1; then
  t79_pass "TC-00d-2: patched settings.example.json is valid JSON"
else
  t79_fail "TC-00d-2: patched settings.example.json is not valid JSON"
fi

# TC-00e: _comment_ が実測と一致する（「HO 判定を適用する」という誤記が残っていない）
_T79_CMT=$(python3 - "$_T79_PATCHED/.claude/settings.example.json" <<'PYC' 2>/dev/null || true
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
for b in d.get("hooks", {}).get("PreToolUse", []):
    c = b.get("_comment_", "")
    if "EH-3b" in c:
        print(c)
        break
PYC
)
if printf '%s' "$_T79_CMT" | grep -q 'EH-3b' \
   && ! printf '%s' "$_T79_CMT" | grep -q 'Applies the same HO decision'; then
  t79_pass "TC-00e: EH-3b _comment_ no longer claims an HO decision it does not make"
else
  t79_fail "TC-00e: EH-3b _comment_ still misdescribes the Bash lane: [$_T79_CMT]"
fi

_T79_PHOOK="$_T79_PATCHED/scripts/hooks/check-plan-hash.sh"

# ── TC-P*: patch 済み hook の実測（期待は常に fixed）────────────────
printf '  -- patched hook (expect: fixed) --\n'

_t79_run "$_T79_PHOOK" "" "" "0" "$_T79_P_HARMLESS"
_t79_expect "TC-P01: Bash / no-task / SKIP_REASON なし / 無害コマンド → block しない" 0 "$_T79_MARK" || true

_t79_run "$_T79_PHOOK" "" "" "0" "$_T79_P_HOWRITE"
_t79_expect "TC-P02: Bash / no-task / HO パスへの書き込み命令 → 通る（既知の穴 / #1104 open）" 0 "$_T79_MARK" || true

# TC-P03: SKIP_REASON 経路でも skip-decision-log を汚さない
_T79_SB3="$_T79_TMP/sb3"
_t79_mkroot "$_T79_SB3"
if [ "$_T79_REAL_PATCHED" != "1" ]; then
  (cd "$_T79_SB3" && git apply "$_T79_PATCH") >/dev/null 2>&1 || true
fi
_t79_run "$_T79_SB3/scripts/hooks/check-plan-hash.sh" "" "probe reason" "0" "$_T79_P_HARMLESS"
_t79_expect "TC-P03-1: Bash / no-task / SKIP_REASON あり → block しない" 0 "$_T79_MARK" || true
if [ ! -f "$_T79_SB3/docs/working/_audit/skip-decision-log.jsonl" ]; then
  t79_pass "TC-P03-2: Bash レーンは skip-decision-log.jsonl へ追認待ちエントリを書かない"
else
  t79_fail "TC-P03-2: Bash レーンが skip-decision-log.jsonl を汚した（CI 負債が再発する）"
fi

# TC-P04: TASK 文脈は退行させない（plan_hash 突合が生きている）
_t79_run "$_T79_PHOOK" "TASK-T79TMP" "" "0" "$_T79_P_HARMLESS"
_t79_expect "TC-P04-1: Bash / TASK 文脈あり → plan_hash 突合（warning）" 0 "plan_hash mismatch" || true
_t79_run "$_T79_PHOOK" "TASK-T79TMP" "" "1" "$_T79_P_HARMLESS"
_t79_expect "TC-P04-2: Bash / TASK 文脈あり / STRICT=1 → block" 1 "plan.md was modified after C-3 approval" || true

# TC-P05〜07: Edit/Write レーンの対照（退行させない）
_t79_run "$_T79_PHOOK" "" "" "0" "$_T79_P_WHO"
_t79_expect "TC-P05: Write / HO パス → block（対照）" 2 "HARDENING_OVERRIDE" || true
_t79_run "$_T79_PHOOK" "" "" "0" "$_T79_P_WPLAN"
_t79_expect "TC-P06: Write / plan.md / no-task → block（対照）" 2 "plan.md edited without TASK context" || true
_t79_run "$_T79_PHOOK" "" "" "0" "$_T79_P_WMD"
_t79_expect "TC-P07: Write / 非 HO .md → DOC_LIGHT_SKIP（対照）" 0 "DOC_LIGHT_SKIP" || true

# TC-P08: Bash payload でも PLANGATE_HOOK_FILE を明示すれば従来判定が働く
_t79_run_file "$_T79_PHOOK" "bin/plangate" "$_T79_P_HARMLESS"
_t79_expect "TC-P08: Bash + PLANGATE_HOOK_FILE 明示 → 従来どおり HO block" 2 "HARDENING_OVERRIDE" || true

# ── TC-R*: 実 hook の実測（期待は flag に従う）──────────────────────
printf '  -- real hook (expect: %s) --\n' "$_T79_EXPECT"
_T79_REAL="$_T79_TMP/real"
_t79_mkroot "$_T79_REAL"
_t79_mktask "$_T79_REAL"
_T79_RHOOK="$_T79_REAL/scripts/hooks/check-plan-hash.sh"

_t79_run "$_T79_RHOOK" "" "" "0" "$_T79_P_HARMLESS"
if [ "$_T79_EXPECT" = "fixed" ]; then
  _t79_expect "TC-R01: Bash / no-task / SKIP_REASON なし → block しない" 0 "$_T79_MARK" || true
else
  _t79_expect "TC-R01(gap): Bash / no-task / SKIP_REASON なし → 現状は全 Bash が block される" 2 "SKIP" || true
fi

_t79_run "$_T79_RHOOK" "" "" "0" "$_T79_P_HOWRITE"
if [ "$_T79_EXPECT" = "fixed" ]; then
  _t79_expect "TC-R02: Bash / HO write → 通る（既知の穴 / #1104 open）" 0 "$_T79_MARK" || true
else
  _t79_expect "TC-R02(gap): Bash / HO write → HO ではなく SKIP_REASON 由来で block" 2 "SKIP" || true
fi

# 実 hook でも Edit/Write レーンは常に同じでなければならない（gap/fixed 不問）
_t79_run "$_T79_RHOOK" "" "" "0" "$_T79_P_WHO"
_t79_expect "TC-R05: Write / HO パス → block（対照 / mode 不問）" 2 "HARDENING_OVERRIDE" || true
_t79_run "$_T79_RHOOK" "" "" "0" "$_T79_P_WPLAN"
_t79_expect "TC-R06: Write / plan.md / no-task → block（対照 / mode 不問）" 2 "plan.md edited without TASK context" || true
_t79_run "$_T79_RHOOK" "" "" "0" "$_T79_P_WMD"
_t79_expect "TC-R07: Write / 非 HO .md → DOC_LIGHT_SKIP（対照 / mode 不問）" 0 "DOC_LIGHT_SKIP" || true

# ── TC-08: 変異注入（新 TC の検出力の実証）─────────────────────────
# 各変異は patch 済み hook の **call site** を壊し、対応する TC が実際に
# FAIL することを測る。変異が検出されなければ、その TC は空振りしている。
printf '  -- mutation testing (detection power) --\n'

_t79_mutate() {
  # $1 = mutant id / $2 = 出力 hook path
  cp "$_T79_PHOOK" "$2"
  MUT="$1" TGT="$2" python3 - <<'PYM'
import os, re, sys
mut = os.environ["MUT"]; tgt = os.environ["TGT"]
s = open(tgt, encoding="utf-8").read()
if mut == "M1":
    # ガード全体を削除（PR #1267 の状態へ差し戻す）
    i = s.index("# ===== EH-3b:")
    j = s.index("# ===== Hardening Override")
    s = s[:i] + s[j:]
elif mut == "M2":
    # call site の tool_name 比較を壊す（Bash を判別しなくなる）
    s = s.replace('"${_tool_name:-}" = "Bash"', '"${_tool_name:-}" = "Edit"', 1)
elif mut == "M3":
    # TASK 文脈ガードを外す（TASK 付き Bash まで no-op になる）
    s = s.replace('[ -z "$target_file" ] && [ -z "$task_id" ] &&',
                  '[ -z "$target_file" ] &&', 1)
elif mut == "M4":
    # no-op 分岐の rc を block へ反転
    s = s.replace('printf \'[Hook EH-3 BASH_LANE_NOOP] %s\\n\' "$reason"\n    exit 0',
                  'printf \'[Hook EH-3 BASH_LANE_NOOP] %s\\n\' "$reason"\n    exit 2', 1)
else:
    sys.exit(9)
open(tgt, "w", encoding="utf-8").write(s)
PYM
}

# $1=mutant $2=TC ラベル $3=TASK $4=SKIP $5=STRICT $6=payload $7=want_rc $8=want_token
_t79_mut_case() {
  _t79_mh="$_T79_TMP/mut-$1.sh"
  if ! _t79_mutate "$1" "$_t79_mh"; then
    t79_fail "TC-08/$1: mutation could not be applied（変異が当たっていない = 検出力を主張できない）"
    return 0
  fi
  if cmp -s "$_T79_PHOOK" "$_t79_mh"; then
    t79_fail "TC-08/$1: mutant is byte-identical to the patched hook（変異が当たっていない）"
    return 0
  fi
  _t79_run "$_t79_mh" "$3" "$4" "$5" "$6"
  if _t79_holds "$7" "$8"; then
    t79_fail "TC-08/$1: 変異したのに $2 が依然 PASS する（この TC は空振り）"
  else
    t79_pass "TC-08/$1: 変異により $2 が FAIL する（検出力あり / rc=${_t79_rc}）"
  fi
}

_t79_mut_case M1 "TC-P01" "" "" "0" "$_T79_P_HARMLESS" 0 "$_T79_MARK"
_t79_mut_case M2 "TC-P01" "" "" "0" "$_T79_P_HARMLESS" 0 "$_T79_MARK"
_t79_mut_case M3 "TC-P04-1" "TASK-T79TMP" "" "0" "$_T79_P_HARMLESS" 0 "plan_hash mismatch"
_t79_mut_case M4 "TC-P01" "" "" "0" "$_T79_P_HARMLESS" 0 "$_T79_MARK"

# ── 後片付け（trap は使わない / README 規約 1・2）────────────────────
rm -rf "$_T79_TMP"
if [ -e "$_T79_TMP" ]; then
  t79_fail "TC-09: sandbox cleanup failed: $_T79_TMP"
else
  t79_pass "TC-09: sandbox removed (no residue outside mktemp)"
fi

fi

pg_extra_contract_finalize
