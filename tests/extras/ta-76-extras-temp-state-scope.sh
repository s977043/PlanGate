# tests/extras/ta-76-extras-temp-state-scope.sh
# PG_EXTRA_CAPABILITY: standalone-capable
# Sourced by tests/run-tests.sh — uses $pass / $fail counters
#
# #947 問題 1 / #1209 / #1210 の共通原因に対する回帰ガード。
#
# 共通原因: extras が「実行中だけ有効な状態」を共有の実 repo パスへ
#   (a) 射程宣言（誰が所有し・いつまで有効で・誰が消すか）なしに置き、
#   (b) 後片付けを「正常終了に到達すること」に依存させている。
# 症状は次のように分岐した:
#   - 中断残骸が次回実行の判定を汚す（#947 問題 1 / ta-42 TC-04 の誤 FAIL）
#   - 中断残骸がガードを緩める（#1209 / ta-12 が残す承認トークンで EH-3 が
#     非 HO パスに対し BLOCK(rc=2) → SKIP(rc=0) へ反転）
#   - 事前掃除が「使用箇所より後」にあり冪等宣言が効いていない（ta-42）
#   - 掃除経路が規約外の EXIT trap（ta-45。source 連鎖で発火保証なし）
#   - 変数未設定時に rm の対象が広がりうる（#1210・防御的措置）
#
# 本ファイルは「宣言 → body の副作用より前に一括 prune → register_cleanup 登録」
# の三点セットが守られていることを機械検査し、同型の再発を止める。
#
# TC-01: 対象 extras が register_cleanup へ登録している（陰性コントロールつき）
# TC-02: extras の top-level EXIT trap は文書化済み例外に限る（repo 全体）
# TC-03: scope reset の呼出が「実 repo パスへの最初の副作用」より前にある
# TC-04: ta-12 の fixture TTL 上限契約（#1209 の残骸窓を最小に保つ）
# TC-05: 中断残骸を注入した状態でも ta-42 が PASS する（#947 AC-1）
# TC-06: ta-44 / ta-45 の単体実行が docs/working に残留を増やさない

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
pg_extra_contract_init ta-76-extras-temp-state-scope standalone-capable

printf '\n=== TA-76: extras temp-state scope contract (#947 / #1209 / #1210) ===\n'

_T76_DIR="$_pg_extra_dir"
_T76_ROOT="$(CDPATH= cd -- "$_T76_DIR/../.." && pwd)"

t76_pass() { pass=$((pass + 1)); printf '  [PASS] %s\n' "$1"; }
t76_fail() { fail=$((fail + 1)); printf '  [FAIL] %s\n' "$1" >&2; }

# 検査対象（実 repo パスへ一時状態を置く extras）。ファイル名リストは
# 「どこを守るか」の宣言であり、判定そのものは各ファイルの中身を読んで行う。
_T76_TARGETS='ta-12-maintenance.sh ta-42-cli-subcommands.sh ta-44-eh457-cli-wiring.sh ta-45-c3-mode-config.sh'

# top-level EXIT trap の文書化済み例外（tests/extras/README.md 規約 2 が
# 「サブシェルに閉じ込める / 自前ガード変数」の形で認めている既存分）。
# 新規ファイルがここに無い trap を足したら TC-02 が落ちる。
_T76_TRAP_ALLOWED='ta-07-eval-runner.sh ta-09-metrics.sh ta-24-parallel-review.sh ta-28-plugin-version.sh'

_t76_tmp=$(mktemp -d)
register_cleanup "$_t76_tmp"

# 本ファイル自身も規約に従う: TC-05 が注入する残骸の射程を先に宣言し、
# body の副作用より前に prune して register_cleanup へ登録する。
_T76_WD="${_T76_ROOT:?ta-76: repo root unresolved}/docs/working"
_T76_RESIDUE="$_T76_WD/TASK-T999"
_t76_scope_reset() {
  for _t76_p in "$@"; do
    rm -rf "${_t76_p:?ta-76: empty cleanup path refused}"
    if command -v register_cleanup >/dev/null 2>&1; then
      register_cleanup "$_t76_p"
    fi
  done
}
_t76_scope_reset "$_T76_RESIDUE" "$_T76_WD/TASK-T420"

_t76_in_list() {
  for _t76_h in $2; do
    [ "$_t76_h" = "$1" ] && return 0
  done
  return 1
}

# ---------------------------------------------------------------------------
# TC-01: 対象 extras が register_cleanup へ登録している
# （ta-12 / ta-45 は origin/main 時点で 0 件だった＝この TC が守る回帰）
_T76_RC_ERE='(^|[^_[:alnum:]])register_cleanup[[:space:]]+"'
_t76_ok=1
_t76_missing=''
for _t76_b in $_T76_TARGETS; do
  _t76_f="$_T76_DIR/$_t76_b"
  if [ ! -r "$_t76_f" ]; then
    t76_fail "TC-01: target not readable: $_t76_f"
    _t76_ok=0
    continue
  fi
  _t76_n=$(grep -cE "$_T76_RC_ERE" "$_t76_f" || true)
  [ "$_t76_n" -ge 1 ] || { _t76_ok=0; _t76_missing="$_t76_missing $_t76_b"; }
done
# 陰性コントロール: 同じ検出器が「register_cleanup を含まないファイル」に対し
# 0 を返すことを確認する（空出力を 0 件の証拠にしない / 検出器の空振り防止）
printf 'echo no cleanup here\n' > "$_t76_tmp/neg.sh"
_t76_neg=$(grep -cE "$_T76_RC_ERE" "$_t76_tmp/neg.sh" || true)
if [ "$_t76_neg" != "0" ]; then
  t76_fail "TC-01: negative control failed — detector reports $_t76_neg on a file with no registration"
  _t76_ok=0
fi
if [ "$_t76_ok" = "1" ]; then
  t76_pass "TC-01: every declared target registers its temp paths (negative control OK)"
else
  t76_fail "TC-01: targets missing register_cleanup:$_t76_missing"
fi

# ---------------------------------------------------------------------------
# TC-02: extras の top-level EXIT trap は文書化済み例外に限る（repo 全体）
# README「隔離・後始末の規約」1/2: source 型の構造上 EXIT trap は後続 extras に
# 上書きされ発火が保証されない。ta-45 はこれに反していた（本 PR で解消）。
_T76_TRAP_ERE='^[[:space:]]*trap[[:space:]]'
_t76_ok=1
_t76_viol=''
_t76_seen=0
for _t76_f in "$_T76_DIR"/ta-*.sh; do
  [ -r "$_t76_f" ] || continue
  _t76_seen=$((_t76_seen + 1))
  _t76_b=$(basename "$_t76_f")
  if grep -qE "$_T76_TRAP_ERE" "$_t76_f"; then
    _t76_in_list "$_t76_b" "$_T76_TRAP_ALLOWED" || { _t76_ok=0; _t76_viol="$_t76_viol $_t76_b"; }
  fi
done
# 陽性コントロール: 検出器が実際に top-level trap を拾うことを実証する
printf 'trap cleanup EXIT\n' > "$_t76_tmp/pos.sh"
if ! grep -qE "$_T76_TRAP_ERE" "$_t76_tmp/pos.sh"; then
  t76_fail "TC-02: positive control failed — detector missed a literal top-level trap"
  _t76_ok=0
fi
if [ "$_t76_seen" -lt 1 ]; then
  t76_fail "TC-02: discovered 0 extras files (glob did not expand) — refusing a vacuous PASS"
elif [ "$_t76_ok" = "1" ]; then
  t76_pass "TC-02: no undocumented top-level EXIT trap across $_t76_seen extras (positive control OK)"
else
  t76_fail "TC-02: undocumented top-level trap in:$_t76_viol"
fi

# ---------------------------------------------------------------------------
# TC-03: scope reset の呼出が「実 repo パスへの最初の副作用」より前にある
# （#947 問題 1 の実体: ta-42 は TASK-T999 の掃除が TC-04 の判定より後にあった）
_T76_RESET_ERE='^_t[0-9]+_scope_reset[[:space:]]'
_T76_FX_ERE='(^|[^[:alnum:]_])(mkdir|touch)[[:space:]]|cat[[:space:]]*>[[:space:]]*"|[[:space:]]init[[:space:]]'
_t76_first_fx() {
  # 素の行番号で「コメントでない最初の副作用行」を返す
  grep -nE "$_T76_FX_ERE" "$1" | grep -vE '^[0-9]+:[[:space:]]*#' | head -1 | cut -d: -f1
}
_t76_ok=1
_t76_bad=''
_t76_checked=0
for _t76_b in $_T76_TARGETS; do
  _t76_f="$_T76_DIR/$_t76_b"
  [ -r "$_t76_f" ] || continue
  _t76_reset_ln=$(grep -nE "$_T76_RESET_ERE" "$_t76_f" | head -1 | cut -d: -f1)
  _t76_fx_ln=$(_t76_first_fx "$_t76_f")
  if [ -z "$_t76_reset_ln" ]; then
    _t76_ok=0; _t76_bad="$_t76_bad $_t76_b(no-scope-reset)"; continue
  fi
  if [ -z "$_t76_fx_ln" ]; then
    printf '  [INFO] TC-03: %s has no detectable side effect line — ordering check not applicable\n' "$_t76_b"
    continue
  fi
  _t76_checked=$((_t76_checked + 1))
  if [ "$_t76_reset_ln" -ge "$_t76_fx_ln" ]; then
    _t76_ok=0
    _t76_bad="$_t76_bad $_t76_b(reset@$_t76_reset_ln>=fx@$_t76_fx_ln)"
  fi
done
# 陽性コントロール: 順序が逆の fixture を検出できることを実証する
printf '%s\n' 'mkdir -p x' '_t99_scope_reset "x"' > "$_t76_tmp/order.sh"
_t76_pc_reset=$(grep -nE "$_T76_RESET_ERE" "$_t76_tmp/order.sh" | head -1 | cut -d: -f1)
_t76_pc_fx=$(_t76_first_fx "$_t76_tmp/order.sh")
if [ -z "$_t76_pc_reset" ] || [ -z "$_t76_pc_fx" ] || [ "$_t76_pc_reset" -lt "$_t76_pc_fx" ]; then
  t76_fail "TC-03: positive control failed — detector did not flag reversed order (reset=$_t76_pc_reset fx=$_t76_pc_fx)"
  _t76_ok=0
fi
if [ "$_t76_checked" -lt 1 ]; then
  t76_fail "TC-03: no target was actually ordering-checked — refusing a vacuous PASS"
elif [ "$_t76_ok" = "1" ]; then
  t76_pass "TC-03: scope reset precedes the first real-repo side effect in all $_t76_checked checked targets (positive control OK)"
else
  t76_fail "TC-03: prune ordering violation:$_t76_bad"
fi

# ---------------------------------------------------------------------------
# TC-04: ta-12 の fixture TTL 上限契約（#1209）
# ta-12 は EH-3 のメンテ承認判定を検査するため実 repo 配下の承認トークンを
# 作る。bin/plangate も scripts/hooks/ も $REPO_ROOT 固定参照で env seam が
# 無く（どちらも Hardening Override 対象で触れない）、sandbox へ逃がせない。
# よって「中断残骸が有効でいられる時間」を上限で縛るのが唯一の恒久緩和。
_T76_TTL_MAX=120
_t76_ttl=$(sed -nE 's/^_T12_TTL=([0-9]+).*/\1/p' "$_T76_DIR/ta-12-maintenance.sh" | head -1)
if [ -z "$_t76_ttl" ]; then
  t76_fail "TC-04: ta-12 does not declare _T12_TTL (fixture TTL contract missing)"
elif [ "$_t76_ttl" -le "$_T76_TTL_MAX" ]; then
  t76_pass "TC-04: ta-12 fixture TTL is bounded (${_t76_ttl}s <= ${_T76_TTL_MAX}s)"
else
  t76_fail "TC-04: ta-12 fixture TTL ${_t76_ttl}s exceeds the ${_T76_TTL_MAX}s contract (residual skip window too wide)"
fi

# ---------------------------------------------------------------------------
# TC-05: 中断残骸を注入した状態でも ta-42 が PASS する（#947 AC-1）
# ta-42 は harness-only（$FIXTURES_DIR 依存）なので、共有 fixture の最小
# ハーネスで隔離実行する（tests/run-tests.sh 本体には触れない）。
_T76_MINI="$_T76_ROOT/tests/fixtures/extras-mini-harness.sh"
if [ ! -r "$_T76_MINI" ]; then
  t76_fail "TC-05: mini harness fixture missing: $_T76_MINI"
else
  # 前回中断で残ったのと同じ形（ta-42 TC-06 が作る TASK-T999 + handoff.md）を注入
  mkdir -p "$_T76_RESIDUE"
  : > "$_T76_RESIDUE/handoff.md"
  _t76_rc=0
  _t76_out=$(sh "$_T76_MINI" "$_T76_ROOT" ta-42-cli-subcommands.sh 2>&1) || _t76_rc=$?
  if [ "$_t76_rc" -eq 0 ] && printf '%s' "$_t76_out" | grep -q 'MINI:10:0'; then
    t76_pass "TC-05: ta-42 passes from a dirty start (interrupt residue injected) — #947 AC-1"
  else
    t76_fail "TC-05: ta-42 is order-dependent on residue (rc=$_t76_rc): $(printf '%s' "$_t76_out" | grep -E 'FAIL|MINI:' | head -3)"
  fi
  _t76_scope_reset "$_T76_RESIDUE"
fi

# ---------------------------------------------------------------------------
# TC-06: ta-44 / ta-45 の単体実行が docs/working に残留を増やさない
# 判定軸は「絶対的な空」ではなく「実行前後の差分ゼロ」— harness 実行中は
# 他 extras の未 drain な一時ディレクトリが同居しているため（成長する
# ディレクトリに絶対件数を書かない）。append-only の監査ログは残留ではない
# ので比較対象から除く。
if command -v git >/dev/null 2>&1 && [ -e "$_T76_ROOT/.git" ]; then
  _t76_snap() {
    git -C "$_T76_ROOT" status --porcelain -- docs/working 2>/dev/null \
      | grep -v 'docs/working/_audit/' | LC_ALL=C sort
  }
  _t76_before=$(_t76_snap)
  _t76_sub_ok=1
  for _t76_b in ta-44-eh457-cli-wiring.sh ta-45-c3-mode-config.sh; do
    _t76_src=0
    sh "$_T76_DIR/$_t76_b" </dev/null >/dev/null 2>&1 || _t76_src=$?
    # rc=0（全 pass）/ rc=3（前提未充足）はどちらも残留検査の前提として妥当
    case "$_t76_src" in
      0|3) : ;;
      *) _t76_sub_ok=0; t76_fail "TC-06: $_t76_b standalone rc=$_t76_src (expected 0 or 3)" ;;
    esac
  done
  _t76_after=$(_t76_snap)
  if [ "$_t76_sub_ok" = "1" ] && [ "$_t76_before" = "$_t76_after" ]; then
    t76_pass "TC-06: ta-44 / ta-45 standalone runs leave docs/working unchanged (before == after)"
  elif [ "$_t76_sub_ok" = "1" ]; then
    t76_fail "TC-06: docs/working changed across standalone runs: $(printf '%s\n%s' "$_t76_before" "$_t76_after" | LC_ALL=C sort | uniq -u | tr '\n' ' ')"
  fi
else
  printf '  [INFO] TC-06: git unavailable or not a work tree — residue diff not measurable here\n'
fi

pg_extra_contract_finalize
