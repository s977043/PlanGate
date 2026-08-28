# tests/extras/ta-73-apply-pr-issue-link-comment-removal.sh
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
# 入力は tests/fixtures/apply-baseline/workflows/check-pr-issue-link.yml（**未適用状態で
# 凍結**）。実 workflow をコピーしていた旧設計は、実 repo が適用済みだと apply が no-op に
# なり、削除対象が既に無い / 追加対象が既にある入力で **検出力ゼロの恒真 PASS** を作って
# いた（TC-05 / TC-11 / TC-14）。詳細は tests/fixtures/apply-baseline/README.md。
#
# 契約する不変条件:
#   TC-00 fixture が未適用である（恒真 PASS 防止。適用済みなら SKIP でなく FAIL）
#   TC-01 スクリプトが存在する
#   TC-02 sh -n が通る（構文）
#   TC-03 引数なし / --dry-run が rc=0 かつ 1 バイトも書かない、diff を出す
#   TC-04 未知引数 / 引数過多は rc=1 かつ書き込みなし
#   TC-05 --apply が Post warning comment を消し Annotate WARN / Annotate NOTICE
#         + Cleanup を足す
#   TC-06 冪等（2 回目は already applied で rc=0、バイト不変）
#   TC-07 START アンカー未検出 -> rc=1 かつ 1 バイトも書かない
#   TC-08 削除対象ブロックの内容が想定外 -> rc=1 かつ書き込みなし
#   TC-09 アンカー間に挿入された無関係 step を巻き込まない（minor-3 回帰）
#   TC-10 END アンカー（Output summary）が無くても START ブロックだけ置換できる
#   TC-11 生成後の cleanup step の DELETE が失敗許容（fork PR で job を赤くしない）
#   TC-12 対象ファイル不在 -> rc=1
#   TC-14 生成 step が 4 値判定に写像される（WARN->::warning:: / NOTICE->::notice::、
#         いずれも PR タイムラインを汚さない設計意図つき）
#   TC-15 生成後の workflow が yaml.safe_load を通る
#   TC-16 実 repo アンカー probe（実 workflow への --dry-run が rc=0・書き込みなし）
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
pg_extra_contract_init ta-73-apply-pr-issue-link-comment-removal standalone-capable

printf '\n=== TA-73: apply-pr-issue-link-comment-removal.sh (#159) ===\n'

if [ "${PG_HARNESS_SOURCED:-0}" = "1" ] && [ -n "${FIXTURES_DIR:-}" ]; then
  _T73_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
else
  unset PLANGATE_SKIP_REASON PLANGATE_HOOK_TASK PLANGATE_HOOK_FILE PLANGATE_BYPASS_HOOK PLANGATE_HOOK_STRICT PG_HARNESS_SOURCED PLANGATE_ALLOW_MASS_DELETE 2>/dev/null || true
  _T73_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
fi

_T73_APPLY="$_T73_ROOT/scripts/apply-pr-issue-link-comment-removal.sh"

# ── 入力の射程宣言（規約 9 と同じ思想）───────────────────────────────
# 本 TA が読む入力は次の 2 つだけ。どちらも **実 repo の適用状態に依存しない**。
#   (1) _T73_WF   : 未適用状態で凍結した fixture（唯一の apply 対象入力）
#                   tests/fixtures/apply-baseline/README.md を参照
#   (2) _T73_REAL : 実 check-pr-issue-link.yml（**--dry-run の probe でのみ読む**）
# 書き込みは mktemp サンドボックス配下のみ。register_cleanup + 末尾 rm -rf で回収。
if [ "${PG_HARNESS_SOURCED:-0}" = "1" ] && [ -n "${FIXTURES_DIR:-}" ]; then
  _T73_FXD="$FIXTURES_DIR"
else
  _T73_FXD="$(CDPATH= cd -- "$(dirname -- "$0")/../fixtures" && pwd)"
fi
_T73_WF="$_T73_FXD/apply-baseline/workflows/check-pr-issue-link.yml"
_T73_REAL="$_T73_ROOT/.github/workflows/check-pr-issue-link.yml"

t73_pass() { pass=$((pass + 1)); printf '  [PASS] %s\n' "$1"; }
t73_fail() { fail=$((fail + 1)); printf '  [FAIL] %s\n' "$1" >&2; }

# set -e 安全な rc 捕捉（README 規約 4 / OR-list 形式）
_t73_rc=0
_t73_out=""
_t73_run() {
  _t73_rc=0
  _t73_out=$("$@" 2>&1) || _t73_rc=$?
}

if [ ! -f "$_T73_APPLY" ] || [ ! -f "$_T73_WF" ]; then
  pg_extra_contract_skip "apply script or baseline fixture absent"
else

_t73_mksbx() {
  _t73_sbx=$(mktemp -d)
  register_cleanup "$_t73_sbx"
  mkdir -p "$_t73_sbx/scripts" "$_t73_sbx/.github/workflows"
  cp "$_T73_APPLY" "$_t73_sbx/scripts/apply-pr-issue-link-comment-removal.sh"
  cp "$_T73_WF" "$_t73_sbx/.github/workflows/check-pr-issue-link.yml"
}
_t73_wf_of() { printf '%s' "$1/.github/workflows/check-pr-issue-link.yml"; }
_t73_run_of() { printf '%s' "$1/scripts/apply-pr-issue-link-comment-removal.sh"; }
_t73_sum() { cksum <"$1"; }

# === TC-00: fixture 前提検査（未適用であること）===
# fixture が「適用済み」に差し替わると TC-05 / TC-09 / TC-10 / TC-11 / TC-14 は
# 差分ゼロで恒真 PASS になる（実際に旧設計ではそうなっていた）。ここで FAIL させる。
_t73_pre=1
_t73_why=''
if ! grep -Fq "      - name: Post warning comment (if WARN)" "$_T73_WF"; then
  _t73_pre=0; _t73_why="$_t73_why 削除対象 'Post warning comment' が無い;"
fi
if grep -Fq "      - name: Annotate WARN" "$_T73_WF"; then
  _t73_pre=0; _t73_why="$_t73_why 追加対象 'Annotate WARN' が既にある;"
fi
if [ "$_t73_pre" -eq 1 ]; then
  t73_pass "TC-00 fixture が未適用状態（削除対象あり / 追加対象なし）"
else
  t73_fail "TC-00 fixture が未適用でない — 以降の TC が恒真 PASS になる:$_t73_why"
fi

# === TC-01: 存在 ===
if [ -f "$_T73_APPLY" ]; then
  t73_pass "TC-01 scripts/apply-pr-issue-link-comment-removal.sh が存在する"
else
  t73_fail "TC-01 apply スクリプトが無い"
fi

# === TC-02: 構文 ===
_t73_run sh -n "$_T73_APPLY"
if [ "$_t73_rc" -eq 0 ]; then
  t73_pass "TC-02 sh -n が通る"
else
  t73_fail "TC-02 sh -n rc=$_t73_rc: $_t73_out"
fi

# === TC-03: 引数なし / --dry-run は rc=0・書き込みなし・diff 出力 ===
_t73_mksbx
_t73_s1="$_t73_sbx"
_t73_w1=$(_t73_wf_of "$_t73_s1")
_t73_b1=$(_t73_sum "$_t73_w1")
_t73_run sh "$(_t73_run_of "$_t73_s1")"
_t73_rc_noarg=$_t73_rc
_t73_run sh "$(_t73_run_of "$_t73_s1")" --dry-run
_t73_a1=$(_t73_sum "$_t73_w1")
if [ "$_t73_rc_noarg" -eq 0 ] && [ "$_t73_rc" -eq 0 ] && [ "$_t73_b1" = "$_t73_a1" ]; then
  t73_pass "TC-03a 引数なし / --dry-run とも rc=0 で対象ファイルはバイト不変"
else
  t73_fail "TC-03a rc_noarg=$_t73_rc_noarg rc_dry=$_t73_rc sum $_t73_b1 -> $_t73_a1"
fi
_t73_ok=1
for _t73_tok in "[dry-run] no file written" "-      - name: Post warning comment (if WARN)" "+      - name: Annotate WARN" "+      - name: Annotate NOTICE" "+      - name: Cleanup stale warning comment"; do
  if ! printf '%s\n' "$_t73_out" | grep -Fq -- "$_t73_tok"; then
    t73_fail "TC-03b --dry-run 出力に marker が無い: $_t73_tok"
    _t73_ok=0
  fi
done
if [ "$_t73_ok" -eq 1 ]; then
  t73_pass "TC-03b --dry-run が unified diff と no-write 明示を出す"
fi

# === TC-04: 引数エラーは rc=1 かつ書き込みなし ===
_t73_b1=$(_t73_sum "$_t73_w1")
_t73_run sh "$(_t73_run_of "$_t73_s1")" --bogus
_t73_rc_unknown=$_t73_rc
_t73_run sh "$(_t73_run_of "$_t73_s1")" --dry-run --apply
_t73_rc_many=$_t73_rc
_t73_a1=$(_t73_sum "$_t73_w1")
if [ "$_t73_rc_unknown" -eq 1 ] && [ "$_t73_rc_many" -eq 1 ] && [ "$_t73_b1" = "$_t73_a1" ]; then
  t73_pass "TC-04 未知引数 / 引数過多は rc=1 かつバイト不変"
else
  t73_fail "TC-04 rc_unknown=$_t73_rc_unknown rc_many=$_t73_rc_many sum $_t73_b1 -> $_t73_a1"
fi

# === TC-05: --apply 本体 ===
_t73_mksbx
_t73_s2="$_t73_sbx"
_t73_w2=$(_t73_wf_of "$_t73_s2")
_t73_run sh "$(_t73_run_of "$_t73_s2")" --apply
_t73_rc_apply=$_t73_rc
_t73_after=$(_t73_sum "$_t73_w2")
_t73_ok=1
if [ "$_t73_rc_apply" -ne 0 ]; then
  t73_fail "TC-05 --apply rc=$_t73_rc_apply out=$_t73_out"
  _t73_ok=0
fi
if grep -Fq "Post warning comment" "$_t73_w2"; then
  t73_fail "TC-05 Post warning comment が残っている"
  _t73_ok=0
fi
for _t73_tok in "      - name: Annotate WARN" "      - name: Annotate NOTICE" "      - name: Cleanup stale warning comment" "      - name: Output summary"; do
  if ! grep -Fq "$_t73_tok" "$_t73_w2"; then
    t73_fail "TC-05 step が無い: $_t73_tok"
    _t73_ok=0
  fi
done
if [ "$_t73_ok" -eq 1 ]; then
  t73_pass "TC-05 --apply が Post warning を除去し Annotate WARN/NOTICE と Cleanup を追加（Output summary は保持）"
fi

# === TC-06: 冪等 ===
_t73_run sh "$(_t73_run_of "$_t73_s2")" --apply
_t73_again=$(_t73_sum "$_t73_w2")
if [ "$_t73_rc" -eq 0 ] && [ "$_t73_after" = "$_t73_again" ] && printf '%s\n' "$_t73_out" | grep -Fq "already applied"; then
  t73_pass "TC-06 2 回目の --apply は already applied で rc=0・バイト不変（冪等）"
else
  t73_fail "TC-06 rc=$_t73_rc sum $_t73_after -> $_t73_again out=$_t73_out"
fi

# === TC-11: cleanup の DELETE が失敗許容（minor-4 回帰）===
_t73_ok=1
if ! grep -Fq 'if ! gh api -X DELETE "repos/$REPO/issues/comments/$id"; then' "$_t73_w2"; then
  _t73_ok=0
fi
if ! grep -Fq "token may be read-only" "$_t73_w2"; then
  _t73_ok=0
fi
if [ "$_t73_ok" -eq 1 ]; then
  t73_pass "TC-11 cleanup の gh api DELETE は失敗許容（fork PR で job を赤くしない）"
else
  t73_fail "TC-11 cleanup の DELETE が失敗許容になっていない"
fi

# === TC-14: 4 値判定の注釈チャネルへの写像（#159 敵対レビュー major-4）===
# WARN -> ::warning:: / NOTICE -> ::notice::。どちらも PR タイムラインを汚さない
# 注釈チャネルであることを、生成物の実テキストで確認する。
_t73_ok=1
if ! grep -Fq "        if: startsWith(steps.check.outputs.result, 'WARN')" "$_t73_w2"; then
  t73_fail "TC-14 Annotate WARN の if 条件が WARN prefix になっていない"
  _t73_ok=0
fi
if ! grep -Fq "        if: startsWith(steps.check.outputs.result, 'NOTICE')" "$_t73_w2"; then
  t73_fail "TC-14 Annotate NOTICE の if 条件が NOTICE prefix になっていない"
  _t73_ok=0
fi
if ! grep -Fq "::warning title=Check PR Issue Link::" "$_t73_w2"; then
  t73_fail "TC-14 ::warning:: 注釈が無い"
  _t73_ok=0
fi
if ! grep -Fq "::notice title=Check PR Issue Link::" "$_t73_w2"; then
  t73_fail "TC-14 ::notice:: 注釈が無い（NOTICE の可視面が Step Summary だけになる）"
  _t73_ok=0
fi
# 「PR タイムラインは汚さない」という設計意図が WARN / NOTICE の両 step に残るか。
# 2 件を下回ったら片方の注記が失われている。
_t73_intent=$(grep -c "PR タイムラインは" "$_t73_w2" || true)
if [ "$_t73_intent" -lt 2 ]; then
  t73_fail "TC-14 設計意図（PR タイムラインを汚さない）の注記が $_t73_intent 件しかない"
  _t73_ok=0
fi
if [ "$_t73_ok" -eq 1 ]; then
  t73_pass "TC-14 WARN->::warning:: / NOTICE->::notice:: が別 step として生成される"
fi

# === TC-15: 生成後の workflow が yaml.safe_load を通る ===
_t73_run python3 -c 'import sys, yaml; yaml.safe_load(open(sys.argv[1], encoding="utf-8")); print("yaml-ok")' "$_t73_w2"
if [ "$_t73_rc" -eq 0 ] && printf '%s\n' "$_t73_out" | grep -Fq "yaml-ok"; then
  t73_pass "TC-15 生成後の workflow が yaml.safe_load を通る"
elif printf '%s\n' "$_t73_out" | grep -Fq "ModuleNotFoundError"; then
  t73_pass "TC-15 (skipped) PyYAML 未導入のため safe_load 検証を省略"
else
  t73_fail "TC-15 yaml.safe_load rc=$_t73_rc out=$_t73_out"
fi

# === TC-07: START アンカー未検出 -> rc=1 / 1 バイトも書かない ===
_t73_mksbx
_t73_s3="$_t73_sbx"
_t73_w3=$(_t73_wf_of "$_t73_s3")
sed "s/      - name: Post warning comment (if WARN)/      - name: Renamed Away/" "$_t73_w3" >"$_t73_w3.tmp"
mv "$_t73_w3.tmp" "$_t73_w3"
_t73_b3=$(_t73_sum "$_t73_w3")
_t73_run sh "$(_t73_run_of "$_t73_s3")" --apply
_t73_a3=$(_t73_sum "$_t73_w3")
if [ "$_t73_rc" -eq 1 ] && [ "$_t73_b3" = "$_t73_a3" ] && printf '%s\n' "$_t73_out" | grep -Fq "anchor not found"; then
  t73_pass "TC-07 START アンカー未検出は rc=1・バイト不変（部分適用しない）"
else
  t73_fail "TC-07 rc=$_t73_rc sum $_t73_b3 -> $_t73_a3 out=$_t73_out"
fi

# === TC-08: 削除対象ブロックの内容が想定外 -> rc=1 / 書き込みなし ===
_t73_mksbx
_t73_s4="$_t73_sbx"
_t73_w4=$(_t73_wf_of "$_t73_s4")
sed "s/^          gh pr comment .*$/          echo noop/" "$_t73_w4" >"$_t73_w4.tmp"
mv "$_t73_w4.tmp" "$_t73_w4"
_t73_b4=$(_t73_sum "$_t73_w4")
_t73_run sh "$(_t73_run_of "$_t73_s4")" --apply
_t73_a4=$(_t73_sum "$_t73_w4")
if [ "$_t73_rc" -eq 1 ] && [ "$_t73_b4" = "$_t73_a4" ] && printf '%s\n' "$_t73_out" | grep -Fq "does not look like the expected"; then
  t73_pass "TC-08 削除対象ブロックの内容検証に失敗すると rc=1・バイト不変"
else
  t73_fail "TC-08 rc=$_t73_rc sum $_t73_b4 -> $_t73_a4 out=$_t73_out"
fi

# === TC-09: アンカー間に挿入された無関係 step を巻き込まない（minor-3 回帰）===
_t73_mksbx
_t73_s5="$_t73_sbx"
_t73_w5=$(_t73_wf_of "$_t73_s5")
_t73_marker=ta73-unrelated-marker
{
  sed "/^      - name: Output summary$/q" "$_t73_w5" | sed '$d'
  printf '      - name: TA73 Unrelated Step\n        run: |\n          echo %s\n\n' "$_t73_marker"
  sed -n "/^      - name: Output summary$/,\$p" "$_t73_w5"
} >"$_t73_w5.tmp"
mv "$_t73_w5.tmp" "$_t73_w5"
_t73_before=$(grep -c "$_t73_marker" "$_t73_w5" || true)
_t73_run sh "$(_t73_run_of "$_t73_s5")" --apply
_t73_afterm=$(grep -c "$_t73_marker" "$_t73_w5" || true)
_t73_ok=1
if [ "$_t73_rc" -ne 0 ]; then _t73_ok=0; fi
if [ "$_t73_before" != "1" ]; then _t73_ok=0; fi
if [ "$_t73_afterm" != "1" ]; then _t73_ok=0; fi
if grep -Fq "Post warning comment" "$_t73_w5"; then _t73_ok=0; fi
if [ "$_t73_ok" -eq 1 ]; then
  t73_pass "TC-09 アンカー間の無関係 step を無警告削除しない（minor-3 回帰）"
else
  t73_fail "TC-09 rc=$_t73_rc marker $_t73_before -> $_t73_afterm"
fi

# === TC-10: END アンカー不在でも START ブロックだけ置換できる ===
_t73_mksbx
_t73_s6="$_t73_sbx"
_t73_w6=$(_t73_wf_of "$_t73_s6")
sed "/^      - name: Output summary$/q" "$_t73_w6" | sed '$d' >"$_t73_w6.tmp"
mv "$_t73_w6.tmp" "$_t73_w6"
_t73_run sh "$(_t73_run_of "$_t73_s6")" --apply
_t73_ok=1
if [ "$_t73_rc" -ne 0 ]; then _t73_ok=0; fi
if ! grep -Fq "      - name: Annotate WARN" "$_t73_w6"; then _t73_ok=0; fi
if grep -Fq "Post warning comment" "$_t73_w6"; then _t73_ok=0; fi
if [ "$_t73_ok" -eq 1 ]; then
  t73_pass "TC-10 END アンカー(Output summary)不在でも適用できる（END 非依存）"
else
  t73_fail "TC-10 rc=$_t73_rc out=$_t73_out"
fi

# === TC-12: 対象ファイル不在 -> rc=1 ===
_t73_mksbx
_t73_s7="$_t73_sbx"
_t73_w7=$(_t73_wf_of "$_t73_s7")
rm -f "$_t73_w7"
_t73_run sh "$(_t73_run_of "$_t73_s7")" --apply
if [ "$_t73_rc" -eq 1 ] && printf '%s\n' "$_t73_out" | grep -Fq "target not found"; then
  t73_pass "TC-12 対象 workflow 不在は rc=1"
else
  t73_fail "TC-12 rc=$_t73_rc out=$_t73_out"
fi

# === TC-16: 実 repo アンカー probe（read-only）===
# 実 check-pr-issue-link.yml に対し --dry-run を 1 回だけ走らせる。dry-run は 1 バイトも
# 書かないので HO パスに触れない。実 workflow がアンカーを失う方向に drift すれば
# apply は anchor not found で rc=1 になり、ここが落ちる。
#   未適用 checkout -> unified diff で rc=0 / 適用済み checkout -> already applied で rc=0
# どちらでも rc=0 なので **適用状態に依存しない**。
if [ ! -f "$_T73_REAL" ]; then
  printf '  [SKIP] TC-16: 実 workflow が無い: %s\n' "$_T73_REAL"
else
  _t73_rb=$(_t73_sum "$_T73_REAL")
  _t73_run sh "$_T73_APPLY" --dry-run
  _t73_ra=$(_t73_sum "$_T73_REAL")
  if [ "$_t73_rc" -eq 0 ] && [ "$_t73_rb" = "$_t73_ra" ] \
     && { printf '%s\n' "$_t73_out" | grep -Fq "[dry-run] no file written" \
          || printf '%s\n' "$_t73_out" | grep -Fq "already applied"; }; then
    t73_pass "TC-16 実 repo アンカー probe: --dry-run rc=0 かつ実ファイルはバイト不変"
  else
    t73_fail "TC-16 実 workflow がアンカーを失っている可能性 (rc=$_t73_rc): $_t73_out"
  fi
fi

# === TC-13: サンドボックスを明示削除（実 workflow には一切書き込まない）===
rm -rf "$_t73_s1" "$_t73_s2" "$_t73_s3" "$_t73_s4" "$_t73_s5" "$_t73_s6" "$_t73_s7"
_t73_left=0
for _t73_d in "$_t73_s1" "$_t73_s2" "$_t73_s3" "$_t73_s4" "$_t73_s5" "$_t73_s6" "$_t73_s7"; do
  if [ -d "$_t73_d" ]; then
    _t73_left=$((_t73_left + 1))
  fi
done
if [ "$_t73_left" -eq 0 ]; then
  t73_pass "TC-13 サンドボックスを明示削除（実 workflow には一切書き込まない）"
else
  t73_fail "TC-13 サンドボックスが $_t73_left 件残存"
fi

fi

pg_extra_contract_finalize
