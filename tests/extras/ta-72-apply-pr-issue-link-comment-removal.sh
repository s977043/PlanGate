# tests/extras/ta-72-apply-pr-issue-link-comment-removal.sh
# PG_EXTRA_CAPABILITY: standalone-capable
# Sourced by tests/run-tests.sh -- uses $pass / $fail counters
# scripts/apply-pr-issue-link-comment-removal.sh (#159) の HO 適用スクリプト検証。
#
# repo 慣行: scripts/apply-*.sh には ta-XX を付ける
# （ta-41-approve-hardening.sh / ta-58 / ta-59）。本ファイルはその欠落を埋める。
#
# 隔離（tests/extras/README.md 「隔離・後始末の規約」）:
#   対象 workflow yml は Hardening Override 対象（HO）のため一切書かない。
#   mktemp サンドボックスに scripts/ と workflow を複製し、対象スクリプトの
#   REPO_ROOT 解決（scripts/ -> ..）がサンドボックスを指す性質を使って検証する。
#   trap は張らず register_cleanup + 末尾 rm -rf の二重で回収する。
#
# 契約する不変条件:
#   TC-01 スクリプトが存在する
#   TC-02 sh -n が通る（構文）
#   TC-03 引数なし / --dry-run が rc=0 かつ 1 バイトも書かない、diff を出す
#   TC-04 未知引数 / 引数過多は rc=1 かつ書き込みなし
#   TC-05 --apply が Post warning comment を消し Annotate WARN + Cleanup を足す
#   TC-06 冪等（2 回目は already applied で rc=0、バイト不変）
#   TC-07 START アンカー未検出 -> rc=1 かつ 1 バイトも書かない
#   TC-08 削除対象ブロックの内容が想定外 -> rc=1 かつ書き込みなし
#   TC-09 アンカー間に挿入された無関係 step を巻き込まない（minor-3 回帰）
#   TC-10 END アンカー（Output summary）が無くても START ブロックだけ置換できる
#   TC-11 生成後の cleanup step の DELETE が失敗許容（fork PR で job を赤くしない）
#   TC-12 対象ファイル不在 -> rc=1
#   TC-13 サンドボックスを明示削除（実 workflow には一切書き込まない）

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
pg_extra_contract_init ta-72-apply-pr-issue-link-comment-removal standalone-capable

printf '\n=== TA-72: apply-pr-issue-link-comment-removal.sh (#159) ===\n'

if [ "${PG_HARNESS_SOURCED:-0}" = "1" ] && [ -n "${FIXTURES_DIR:-}" ]; then
  _T72_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
else
  unset PLANGATE_SKIP_REASON PLANGATE_HOOK_TASK PLANGATE_HOOK_FILE PLANGATE_BYPASS_HOOK PLANGATE_HOOK_STRICT PG_HARNESS_SOURCED PLANGATE_ALLOW_MASS_DELETE 2>/dev/null || true
  _T72_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
fi

_T72_APPLY="$_T72_ROOT/scripts/apply-pr-issue-link-comment-removal.sh"
_T72_WF="$_T72_ROOT/.github/workflows/check-pr-issue-link.yml"

t72_pass() { pass=$((pass + 1)); printf '  [PASS] %s\n' "$1"; }
t72_fail() { fail=$((fail + 1)); printf '  [FAIL] %s\n' "$1" >&2; }

# set -e 安全な rc 捕捉（README 規約 4 / OR-list 形式）
_t72_rc=0
_t72_out=""
_t72_run() {
  _t72_rc=0
  _t72_out=$("$@" 2>&1) || _t72_rc=$?
}

if [ ! -f "$_T72_APPLY" ] || [ ! -f "$_T72_WF" ]; then
  pg_extra_contract_skip "apply script or workflow absent"
else

_t72_mksbx() {
  _t72_sbx=$(mktemp -d)
  register_cleanup "$_t72_sbx"
  mkdir -p "$_t72_sbx/scripts" "$_t72_sbx/.github/workflows"
  cp "$_T72_APPLY" "$_t72_sbx/scripts/apply-pr-issue-link-comment-removal.sh"
  cp "$_T72_WF" "$_t72_sbx/.github/workflows/check-pr-issue-link.yml"
}
_t72_wf_of() { printf '%s' "$1/.github/workflows/check-pr-issue-link.yml"; }
_t72_run_of() { printf '%s' "$1/scripts/apply-pr-issue-link-comment-removal.sh"; }
_t72_sum() { cksum <"$1"; }

# === TC-01: 存在 ===
if [ -f "$_T72_APPLY" ]; then
  t72_pass "TC-01 scripts/apply-pr-issue-link-comment-removal.sh が存在する"
else
  t72_fail "TC-01 apply スクリプトが無い"
fi

# === TC-02: 構文 ===
_t72_run sh -n "$_T72_APPLY"
if [ "$_t72_rc" -eq 0 ]; then
  t72_pass "TC-02 sh -n が通る"
else
  t72_fail "TC-02 sh -n rc=$_t72_rc: $_t72_out"
fi

# === TC-03: 引数なし / --dry-run は rc=0・書き込みなし・diff 出力 ===
_t72_mksbx
_t72_s1="$_t72_sbx"
_t72_w1=$(_t72_wf_of "$_t72_s1")
_t72_b1=$(_t72_sum "$_t72_w1")
_t72_run sh "$(_t72_run_of "$_t72_s1")"
_t72_rc_noarg=$_t72_rc
_t72_run sh "$(_t72_run_of "$_t72_s1")" --dry-run
_t72_a1=$(_t72_sum "$_t72_w1")
if [ "$_t72_rc_noarg" -eq 0 ] && [ "$_t72_rc" -eq 0 ] && [ "$_t72_b1" = "$_t72_a1" ]; then
  t72_pass "TC-03a 引数なし / --dry-run とも rc=0 で対象ファイルはバイト不変"
else
  t72_fail "TC-03a rc_noarg=$_t72_rc_noarg rc_dry=$_t72_rc sum $_t72_b1 -> $_t72_a1"
fi
_t72_ok=1
for _t72_tok in "[dry-run] no file written" "-      - name: Post warning comment (if WARN)" "+      - name: Annotate WARN" "+      - name: Cleanup stale warning comment"; do
  if ! printf '%s\n' "$_t72_out" | grep -Fq -- "$_t72_tok"; then
    t72_fail "TC-03b --dry-run 出力に marker が無い: $_t72_tok"
    _t72_ok=0
  fi
done
if [ "$_t72_ok" -eq 1 ]; then
  t72_pass "TC-03b --dry-run が unified diff と no-write 明示を出す"
fi

# === TC-04: 引数エラーは rc=1 かつ書き込みなし ===
_t72_b1=$(_t72_sum "$_t72_w1")
_t72_run sh "$(_t72_run_of "$_t72_s1")" --bogus
_t72_rc_unknown=$_t72_rc
_t72_run sh "$(_t72_run_of "$_t72_s1")" --dry-run --apply
_t72_rc_many=$_t72_rc
_t72_a1=$(_t72_sum "$_t72_w1")
if [ "$_t72_rc_unknown" -eq 1 ] && [ "$_t72_rc_many" -eq 1 ] && [ "$_t72_b1" = "$_t72_a1" ]; then
  t72_pass "TC-04 未知引数 / 引数過多は rc=1 かつバイト不変"
else
  t72_fail "TC-04 rc_unknown=$_t72_rc_unknown rc_many=$_t72_rc_many sum $_t72_b1 -> $_t72_a1"
fi

# === TC-05: --apply 本体 ===
_t72_mksbx
_t72_s2="$_t72_sbx"
_t72_w2=$(_t72_wf_of "$_t72_s2")
_t72_run sh "$(_t72_run_of "$_t72_s2")" --apply
_t72_rc_apply=$_t72_rc
_t72_after=$(_t72_sum "$_t72_w2")
_t72_ok=1
if [ "$_t72_rc_apply" -ne 0 ]; then
  t72_fail "TC-05 --apply rc=$_t72_rc_apply out=$_t72_out"
  _t72_ok=0
fi
if grep -Fq "Post warning comment" "$_t72_w2"; then
  t72_fail "TC-05 Post warning comment が残っている"
  _t72_ok=0
fi
for _t72_tok in "      - name: Annotate WARN" "      - name: Cleanup stale warning comment" "      - name: Output summary"; do
  if ! grep -Fq "$_t72_tok" "$_t72_w2"; then
    t72_fail "TC-05 step が無い: $_t72_tok"
    _t72_ok=0
  fi
done
if [ "$_t72_ok" -eq 1 ]; then
  t72_pass "TC-05 --apply が Post warning を除去し Annotate/Cleanup を追加（Output summary は保持）"
fi

# === TC-06: 冪等 ===
_t72_run sh "$(_t72_run_of "$_t72_s2")" --apply
_t72_again=$(_t72_sum "$_t72_w2")
if [ "$_t72_rc" -eq 0 ] && [ "$_t72_after" = "$_t72_again" ] && printf '%s\n' "$_t72_out" | grep -Fq "already applied"; then
  t72_pass "TC-06 2 回目の --apply は already applied で rc=0・バイト不変（冪等）"
else
  t72_fail "TC-06 rc=$_t72_rc sum $_t72_after -> $_t72_again out=$_t72_out"
fi

# === TC-11: cleanup の DELETE が失敗許容（minor-4 回帰）===
_t72_ok=1
if ! grep -Fq 'if ! gh api -X DELETE "repos/$REPO/issues/comments/$id"; then' "$_t72_w2"; then
  _t72_ok=0
fi
if ! grep -Fq "token may be read-only" "$_t72_w2"; then
  _t72_ok=0
fi
if [ "$_t72_ok" -eq 1 ]; then
  t72_pass "TC-11 cleanup の gh api DELETE は失敗許容（fork PR で job を赤くしない）"
else
  t72_fail "TC-11 cleanup の DELETE が失敗許容になっていない"
fi

# === TC-07: START アンカー未検出 -> rc=1 / 1 バイトも書かない ===
_t72_mksbx
_t72_s3="$_t72_sbx"
_t72_w3=$(_t72_wf_of "$_t72_s3")
sed "s/      - name: Post warning comment (if WARN)/      - name: Renamed Away/" "$_t72_w3" >"$_t72_w3.tmp"
mv "$_t72_w3.tmp" "$_t72_w3"
_t72_b3=$(_t72_sum "$_t72_w3")
_t72_run sh "$(_t72_run_of "$_t72_s3")" --apply
_t72_a3=$(_t72_sum "$_t72_w3")
if [ "$_t72_rc" -eq 1 ] && [ "$_t72_b3" = "$_t72_a3" ] && printf '%s\n' "$_t72_out" | grep -Fq "anchor not found"; then
  t72_pass "TC-07 START アンカー未検出は rc=1・バイト不変（部分適用しない）"
else
  t72_fail "TC-07 rc=$_t72_rc sum $_t72_b3 -> $_t72_a3 out=$_t72_out"
fi

# === TC-08: 削除対象ブロックの内容が想定外 -> rc=1 / 書き込みなし ===
_t72_mksbx
_t72_s4="$_t72_sbx"
_t72_w4=$(_t72_wf_of "$_t72_s4")
sed "s/^          gh pr comment .*$/          echo noop/" "$_t72_w4" >"$_t72_w4.tmp"
mv "$_t72_w4.tmp" "$_t72_w4"
_t72_b4=$(_t72_sum "$_t72_w4")
_t72_run sh "$(_t72_run_of "$_t72_s4")" --apply
_t72_a4=$(_t72_sum "$_t72_w4")
if [ "$_t72_rc" -eq 1 ] && [ "$_t72_b4" = "$_t72_a4" ] && printf '%s\n' "$_t72_out" | grep -Fq "does not look like the expected"; then
  t72_pass "TC-08 削除対象ブロックの内容検証に失敗すると rc=1・バイト不変"
else
  t72_fail "TC-08 rc=$_t72_rc sum $_t72_b4 -> $_t72_a4 out=$_t72_out"
fi

# === TC-09: アンカー間に挿入された無関係 step を巻き込まない（minor-3 回帰）===
_t72_mksbx
_t72_s5="$_t72_sbx"
_t72_w5=$(_t72_wf_of "$_t72_s5")
_t72_marker=ta72-unrelated-marker
{
  sed "/^      - name: Output summary$/q" "$_t72_w5" | sed '$d'
  printf '      - name: TA72 Unrelated Step\n        run: |\n          echo %s\n\n' "$_t72_marker"
  sed -n "/^      - name: Output summary$/,\$p" "$_t72_w5"
} >"$_t72_w5.tmp"
mv "$_t72_w5.tmp" "$_t72_w5"
_t72_before=$(grep -c "$_t72_marker" "$_t72_w5" || true)
_t72_run sh "$(_t72_run_of "$_t72_s5")" --apply
_t72_afterm=$(grep -c "$_t72_marker" "$_t72_w5" || true)
_t72_ok=1
if [ "$_t72_rc" -ne 0 ]; then _t72_ok=0; fi
if [ "$_t72_before" != "1" ]; then _t72_ok=0; fi
if [ "$_t72_afterm" != "1" ]; then _t72_ok=0; fi
if grep -Fq "Post warning comment" "$_t72_w5"; then _t72_ok=0; fi
if [ "$_t72_ok" -eq 1 ]; then
  t72_pass "TC-09 アンカー間の無関係 step を無警告削除しない（minor-3 回帰）"
else
  t72_fail "TC-09 rc=$_t72_rc marker $_t72_before -> $_t72_afterm"
fi

# === TC-10: END アンカー不在でも START ブロックだけ置換できる ===
_t72_mksbx
_t72_s6="$_t72_sbx"
_t72_w6=$(_t72_wf_of "$_t72_s6")
sed "/^      - name: Output summary$/q" "$_t72_w6" | sed '$d' >"$_t72_w6.tmp"
mv "$_t72_w6.tmp" "$_t72_w6"
_t72_run sh "$(_t72_run_of "$_t72_s6")" --apply
_t72_ok=1
if [ "$_t72_rc" -ne 0 ]; then _t72_ok=0; fi
if ! grep -Fq "      - name: Annotate WARN" "$_t72_w6"; then _t72_ok=0; fi
if grep -Fq "Post warning comment" "$_t72_w6"; then _t72_ok=0; fi
if [ "$_t72_ok" -eq 1 ]; then
  t72_pass "TC-10 END アンカー(Output summary)不在でも適用できる（END 非依存）"
else
  t72_fail "TC-10 rc=$_t72_rc out=$_t72_out"
fi

# === TC-12: 対象ファイル不在 -> rc=1 ===
_t72_mksbx
_t72_s7="$_t72_sbx"
_t72_w7=$(_t72_wf_of "$_t72_s7")
rm -f "$_t72_w7"
_t72_run sh "$(_t72_run_of "$_t72_s7")" --apply
if [ "$_t72_rc" -eq 1 ] && printf '%s\n' "$_t72_out" | grep -Fq "target not found"; then
  t72_pass "TC-12 対象 workflow 不在は rc=1"
else
  t72_fail "TC-12 rc=$_t72_rc out=$_t72_out"
fi

# === TC-13: サンドボックスを明示削除（実 workflow には一切書き込まない）===
rm -rf "$_t72_s1" "$_t72_s2" "$_t72_s3" "$_t72_s4" "$_t72_s5" "$_t72_s6" "$_t72_s7"
_t72_left=0
for _t72_d in "$_t72_s1" "$_t72_s2" "$_t72_s3" "$_t72_s4" "$_t72_s5" "$_t72_s6" "$_t72_s7"; do
  if [ -d "$_t72_d" ]; then
    _t72_left=$((_t72_left + 1))
  fi
done
if [ "$_t72_left" -eq 0 ]; then
  t72_pass "TC-13 サンドボックスを明示削除（実 workflow には一切書き込まない）"
else
  t72_fail "TC-13 サンドボックスが $_t72_left 件残存"
fi

fi

pg_extra_contract_finalize
