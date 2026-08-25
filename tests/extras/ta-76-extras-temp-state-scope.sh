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
# TC-01: 対象 extras が register_cleanup へ登録している
#        （コメント化した呼出は数えない / 陽性・陰性コントロールつき）
# TC-02: extras の top-level EXIT trap は「文書化済み例外」と「既知違反」の
#        どちらかに明示登録されたものだけ。本数まで契約し stale / 追加を検出
# TC-03: scope reset の呼出が「実 repo パスへの最初の副作用」より前にある
# TC-04: ta-12 の fixture TTL 契約（上限 + heredoc 側の直書き禁止）
# TC-05: 中断残骸を注入した状態でも対象 4 本が PASS し、残骸が drain される
# TC-06: ta-44 / ta-45 の単体実行が「宣言した固定名パス」を残さない
#        （実 repo の porcelain 全体では他セッションの変更で偽 FAIL する）
#
# 射程宣言（本ファイルが実 repo に作るもの / 規約 9）:
#   - $_t76_tmp（mktemp -d 配下の検出器コントロール用 fixture）
#   - TC-05 が **自分で注入した** 残骸パスだけ。ta-76 は他 TA が所有する
#     パスを先頭で一括 prune しない（所有者以外が消すと、並走している
#     その TA の実行を壊すため）。注入したものは注入した側が消す。

# ---- extras execution contract bootstrap (#921) ----------------------------
if [ "${PG_HARNESS_SOURCED:-0}" = "1" ] && [ -n "${FIXTURES_DIR:-}" ] && [ -n "${EXTRAS_DIR:-}" ]; then
  _pg_extra_mode=harness
  _pg_extra_dir="$EXTRAS_DIR"
else
  # standalone: 規約 8 に従い呼び出し元 env を無害化する（run-tests.sh 冒頭と
  # 同一の 7 env）。base では欠落しており ta-26 TC-33 の包含検査が落ちていた。
  unset PLANGATE_SKIP_REASON PLANGATE_HOOK_TASK PLANGATE_HOOK_FILE PLANGATE_BYPASS_HOOK PLANGATE_HOOK_STRICT PG_HARNESS_SOURCED PLANGATE_ALLOW_MASS_DELETE 2>/dev/null || true
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

# top-level EXIT trap の登録簿（m9 / 2026-08-25 の実測で 2 群へ分割）。
# 旧実装は 4 件すべてを「文書化済み例外」と説明していたが、実体は違った。
# 根拠は「規約 N 適合」のような番号だけの参照ではなく、**行番号 + 本文** で引く。
# README 本文にはその番号表記が存在せず（実測: 本文が番号で自己参照するのは
# 規約 8 と規約 1-2 の 2 箇所のみ）、番号引用は誤読と検証不能を生むため。
#
#   - documented（trap が必要な場合の許容形として README が名指ししている 2 形）:
#       tests/extras/README.md:144-146
#       「どうしても trap が必要な場合は**サブシェルに閉じ込める**（ta-28 方式）か、
#         自前ガード変数で再実行を no-op 化する（ta-09 方式）。」
#       ta-09-metrics.sh = 自前ガード変数方式。:16 の
#         `[ -n "${METRICS_CLEANUP_DONE:-}" ] && return 0` と :460 の
#         `METRICS_CLEANUP_DONE=1` で再実行を no-op 化し、さらに :457-458 の
#         コメント「後続 extras が trap EXIT を上書きするため、trap に頼らず
#         ここで明示実行する」のとおり自ら trap 依存を回避している
#       ta-28-plugin-version.sh = サブシェル方式。:87 / :114 の trap はいずれも
#         コマンド置換 `$( ... )` の中にあり、source 連鎖の親シェルへ漏れない
#       （README:128「（ta-09 で実害を確認済み）」は **規約が生まれた経緯の
#         出典表示** であって現在の評価ではない。同じ規約が :145 で ta-09 を
#         許容形として名指ししているので、経緯と評価は分けて読む）
#
#   - known violation（README が明示的に禁止している操作）:
#       tests/extras/README.md:146
#       「親シェルの trap を `trap - EXIT` で消さない（他 extras / ハーネスの
#         cleanup を巻き込むため）」
#       ta-07-eval-runner.sh     :20 `trap cleanup_eval EXIT INT TERM` /
#                                :56 `trap - EXIT INT TERM`
#       ta-24-parallel-review.sh :257 `trap 'rm -rf "$t24_tmpdir4"' EXIT INT TERM` /
#                                :285 `trap - EXIT INT TERM`
#       実害も観測済みで、ta-24:285 は source 順で先行する ta-09:23
#       `trap cleanup_metrics EXIT INT TERM` を実際に解除する。
#       本 PR の担当外（別 issue 候補）なので trap 本体は修正せず、
#       「既知違反」として明示登録するにとどめる。
#
# 行番号は 2026-08-25 時点・本ブランチでの実測値。行番号は移動しうるので、
# 同定は併記した本文で行うこと。
_T76_TRAP_DOCUMENTED='ta-09-metrics.sh ta-28-plugin-version.sh'
_T76_TRAP_KNOWN_VIOLATION='ta-07-eval-runner.sh ta-24-parallel-review.sh'
# 期待 trap 行数（実測 2026-08-25）。ファイル粒度の登録だけだと
# (a) 登録済みファイルへ trap を足し放題 (b) trap を消しても登録が残る（stale）
# の 2 方向で乖離するため、本数まで契約する。
# 正本は README 規約 9「契約値」表。
_T76_TRAP_COUNTS='ta-07-eval-runner.sh:2 ta-09-metrics.sh:1 ta-24-parallel-review.sh:2 ta-28-plugin-version.sh:2'

_t76_tmp=$(mktemp -d)
register_cleanup "$_t76_tmp"

_T76_WD="${_T76_ROOT:?ta-76: repo root unresolved}/docs/working"

_t76_in_list() {
  for _t76_h in $2; do
    [ "$_t76_h" = "$1" ] && return 0
  done
  return 1
}

# ---------------------------------------------------------------------------
# TC-01: 対象 extras が register_cleanup へ登録している
# （ta-12 / ta-45 は origin/main 時点で 0 件だった＝この TC が守る回帰）
#
# 検出器はコメントを先に落とす。素の grep だと `: # register_cleanup "x"` の
# ように **コメント化した呼出** を「登録あり」と数えてしまい、prune/登録を
# コメントアウトする退行を素通しする（M1 の実測）。
_T76_RC_ERE='(^|[^_[:alnum:]])register_cleanup[[:space:]]+"'
_t76_decomment() {
  # 行頭または空白直後の # 以降を落とす（引用符内の # は落ちないが、
  # 本検出器は「多く数えすぎない」側に倒れれば十分）
  sed -E 's/(^|[[:space:]])#.*$/\1/' "$1"
}
_t76_count_rc() {
  _t76_decomment "$1" | grep -cE "$_T76_RC_ERE" || true
}
_t76_ok=1
_t76_missing=''
for _t76_b in $_T76_TARGETS; do
  _t76_f="$_T76_DIR/$_t76_b"
  if [ ! -r "$_t76_f" ]; then
    t76_fail "TC-01: target not readable: $_t76_f"
    _t76_ok=0
    continue
  fi
  _t76_n=$(_t76_count_rc "$_t76_f")
  [ "$_t76_n" -ge 1 ] || { _t76_ok=0; _t76_missing="$_t76_missing $_t76_b"; }
done
# 陰性コントロール 1: register_cleanup を 1 文字も含まないファイル → 0
printf 'echo no cleanup here\n' > "$_t76_tmp/neg-none.sh"
_t76_neg1=$(_t76_count_rc "$_t76_tmp/neg-none.sh")
# 陰性コントロール 2（M1）: 呼出が **コメントとしてしか** 現れないファイル → 0
printf '%s\n' '# register_cleanup "$a"' ': # register_cleanup "$b"' '  #register_cleanup "$c"' \
  > "$_t76_tmp/neg-comment.sh"
_t76_neg2=$(_t76_count_rc "$_t76_tmp/neg-comment.sh")
# 陽性コントロール: 本物の呼出は数える（decomment が行ごと消していないこと）
printf '%s\n' 'register_cleanup "$x"' > "$_t76_tmp/pos-rc.sh"
_t76_pos1=$(_t76_count_rc "$_t76_tmp/pos-rc.sh")
if [ "$_t76_neg1" != "0" ]; then
  t76_fail "TC-01: negative control 1 failed — detector reports $_t76_neg1 on a file with no registration"
  _t76_ok=0
fi
if [ "$_t76_neg2" != "0" ]; then
  t76_fail "TC-01: negative control 2 failed — commented-out register_cleanup counted as $_t76_neg2 (M1)"
  _t76_ok=0
fi
if [ "$_t76_pos1" -lt 1 ]; then
  t76_fail "TC-01: positive control failed — a real register_cleanup call was not counted"
  _t76_ok=0
fi
if [ "$_t76_ok" = "1" ]; then
  t76_pass "TC-01: every declared target registers its temp paths (pos/neg controls OK, comments excluded)"
else
  t76_fail "TC-01: targets missing register_cleanup:$_t76_missing"
fi

# ---------------------------------------------------------------------------
# TC-02: extras の top-level EXIT trap は登録簿にあるものだけ（repo 全体 + 本数）
# README「隔離・後始末の規約」1/2: source 型の構造上 EXIT trap は後続 extras に
# 上書きされ発火が保証されない。ta-45 はこれに反していた（本 PR で解消）。
_T76_TRAP_ERE='^[[:space:]]*trap[[:space:]]'
_t76_ok=1
_t76_viol=''
_t76_seen=0
_t76_registered="$_T76_TRAP_DOCUMENTED $_T76_TRAP_KNOWN_VIOLATION"
_t76_expected_count() {
  for _t76_e in $_T76_TRAP_COUNTS; do
    case "$_t76_e" in
      "$1":*) printf '%s' "${_t76_e#*:}"; return 0 ;;
    esac
  done
  return 1
}
for _t76_f in "$_T76_DIR"/ta-*.sh; do
  [ -r "$_t76_f" ] || continue
  _t76_seen=$((_t76_seen + 1))
  _t76_b=$(basename "$_t76_f")
  _t76_tn=$(grep -cE "$_T76_TRAP_ERE" "$_t76_f" || true)
  if [ "$_t76_tn" -gt 0 ]; then
    _t76_in_list "$_t76_b" "$_t76_registered" \
      || { _t76_ok=0; _t76_viol="$_t76_viol $_t76_b(unregistered:$_t76_tn)"; }
  fi
done
# stale / 追加 検査（m9）: 登録簿の各エントリは宣言した本数と一致すること。
# 「登録済みなのに trap が 1 本も無い」= stale、「宣言より多い」= 無検査の追加。
for _t76_b in $_t76_registered; do
  _t76_f="$_T76_DIR/$_t76_b"
  if [ ! -r "$_t76_f" ]; then
    _t76_ok=0; _t76_viol="$_t76_viol $_t76_b(registered-but-missing)"; continue
  fi
  _t76_tn=$(grep -cE "$_T76_TRAP_ERE" "$_t76_f" || true)
  _t76_exp=$(_t76_expected_count "$_t76_b" || true)
  if [ -z "$_t76_exp" ]; then
    _t76_ok=0; _t76_viol="$_t76_viol $_t76_b(no-declared-count)"
  elif [ "$_t76_tn" != "$_t76_exp" ]; then
    _t76_ok=0; _t76_viol="$_t76_viol $_t76_b(trap-count $_t76_tn/$_t76_exp)"
  fi
done
# 陽性コントロール: 検出器が実際に top-level trap を拾うことを実証する
printf 'trap cleanup EXIT\n' > "$_t76_tmp/pos.sh"
if ! grep -qE "$_T76_TRAP_ERE" "$_t76_tmp/pos.sh"; then
  t76_fail "TC-02: positive control failed — detector missed a literal top-level trap"
  _t76_ok=0
fi
# 陰性コントロール: trap を含まないファイルでは 0 件
printf 'echo no trap here\n' > "$_t76_tmp/neg-trap.sh"
_t76_ntrap=$(grep -cE "$_T76_TRAP_ERE" "$_t76_tmp/neg-trap.sh" || true)
if [ "$_t76_ntrap" != "0" ]; then
  t76_fail "TC-02: negative control failed — detector reports $_t76_ntrap traps on a file with none"
  _t76_ok=0
fi
if [ "$_t76_seen" -lt 1 ]; then
  t76_fail "TC-02: discovered 0 extras files (glob did not expand) — refusing a vacuous PASS"
elif [ "$_t76_ok" = "1" ]; then
  t76_pass "TC-02: trap registry matches reality (documented 2 / known-violation 2, counts pinned) across $_t76_seen extras"
else
  t76_fail "TC-02: trap registry drift:$_t76_viol"
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
    _t76_bad="$_t76_bad $_t76_b(reset@$_t76_reset_ln/fx@$_t76_fx_ln)"
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
# TC-04: ta-12 の fixture TTL 契約（#1209）
# ta-12 は EH-3 のメンテ承認判定を検査するため実 repo 配下の承認トークンを
# 作る。bin/plangate も scripts/hooks/ も $REPO_ROOT 固定参照で env seam が
# 無く（どちらも Hardening Override 対象で触れない）、sandbox へ逃がせない。
# よって「中断残骸が有効でいられる時間」を上限で縛るのが唯一の恒久緩和。
#
# 検査は 2 本。宣言 `_T12_TTL=N` の上限だけを見ても、heredoc 側で
# `$((_t12_n+600))` と直書きすれば実際の窓は宣言と無関係に広がる（M3 の実測）。
# 契約値の正本は tests/extras/README.md 規約 9「契約値」表。ここはその写しで、
# 数値を変えるときは README を先に直す（正本が test 側にある状態を作らない）。
_T76_TTL_MAX=120
_T76_TA12="$_T76_DIR/ta-12-maintenance.sh"
_t76_ok=1
_t76_ttl=$(sed -nE 's/^_T12_TTL=([0-9]+).*/\1/p' "$_T76_TA12" | head -1)
if [ -z "$_t76_ttl" ]; then
  t76_fail "TC-04: ta-12 does not declare _T12_TTL (fixture TTL contract missing)"
  _t76_ok=0
elif [ "$_t76_ttl" -gt "$_T76_TTL_MAX" ]; then
  t76_fail "TC-04: ta-12 fixture TTL ${_t76_ttl}s exceeds the ${_T76_TTL_MAX}s contract (residual skip window too wide)"
  _t76_ok=0
fi
# until を作る式は _T12_TTL を経由するか、期限切れ fixture の負オフセットのみ。
# 正の直書き（+600 等）は宣言を迂回するので拒否する。
# 走査対象は「shell の算術式で until を組み立てている fixture 行」だけ。
# schema 検査用の python リテラル（"until":2000000000）は token を作らないので
# 対象外にする。件数も固定して「$((...)) をリテラルへ置換して迂回」を塞ぐ。
# 行単位ではなく **until の式だけ** を切り出して判定する。同じ行に
# "granted_at":$((_t12_n-1)) が同居しており、行単位で負オフセットを除外すると
# until 側の +600 直書きを取りこぼす（実測でこの取りこぼしを確認）。
_T76_UNTIL_ERE='"until"[[:space:]]*:[[:space:]]*[$][(][(][^)]*'
_T76_UNTIL_N=3
_t76_until_exprs() {
  grep -oE "$_T76_UNTIL_ERE" "$1" || true
}
_t76_until_scan() {
  _t76_until_exprs "$1" | grep -vE '_T12_TTL' | grep -vE '_t12_n[[:space:]]*-' || true
}
_t76_until_count() {
  _t76_until_exprs "$1" | grep -c '' || true
}
_t76_until_n=$(_t76_until_count "$_T76_TA12")
if [ "$_t76_until_n" != "$_T76_UNTIL_N" ]; then
  t76_fail "TC-04: ta-12 has $_t76_until_n arithmetic until fixtures, expected $_T76_UNTIL_N (a literal rewrite would evade the TTL contract)"
  _t76_ok=0
fi
_t76_until_bad=$(_t76_until_scan "$_T76_TA12")
if [ -n "$_t76_until_bad" ]; then
  t76_fail "TC-04: ta-12 hardcodes an until offset outside _T12_TTL: $(printf '%s' "$_t76_until_bad" | tr '\n' ' ')"
  _t76_ok=0
fi
# 陽性コントロール: 直書き fixture を検出できることを実証する
printf '%s\n' '{"until":$((_t12_n+600)),"scope":"t"}' > "$_t76_tmp/until-bad.txt"
if [ -z "$(_t76_until_scan "$_t76_tmp/until-bad.txt")" ]; then
  t76_fail "TC-04: positive control failed — detector missed a hardcoded +600 until offset"
  _t76_ok=0
fi
# 陰性コントロール: _T12_TTL 経由の式は拾わない
printf '%s\n' '{"until":$((_t12_n+_T12_TTL)),"scope":"t"}' > "$_t76_tmp/until-ok.txt"
if [ -n "$(_t76_until_scan "$_t76_tmp/until-ok.txt")" ]; then
  t76_fail "TC-04: negative control failed — a _T12_TTL-derived until was flagged"
  _t76_ok=0
fi
if [ "$_t76_ok" = "1" ]; then
  t76_pass "TC-04: ta-12 fixture TTL bounded (${_t76_ttl}s vs max ${_T76_TTL_MAX}s) and no hardcoded until offset (controls OK)"
fi

# ---------------------------------------------------------------------------
# TC-05: 中断残骸を注入した状態でも対象 extras が PASS し、残骸が drain される
# （#947 AC-1 を 4 本すべてへ拡張。旧実装は ta-42 の 1 本しか実走させておらず、
#  4 本すべての prune を no-op にしても落ちるのは本 TC だけだった = M2）
#
# 注入先は「対象 extras 自身が所有する一時パス」。ta-76 は他 TA のパスを先頭で
# 一括 prune しない（規約 9 の射程宣言 = 所有者以外が消さない）が、**自分が
# 注入したもの** は自分で始末する。対象はいずれも harness 実行が可能なので
# 共有 fixture の最小ハーネスで隔離実行する（tests/run-tests.sh には触れない）。
_T76_MINI="$_T76_ROOT/tests/fixtures/extras-mini-harness.sh"
_t76_tc05_run=0
_t76_tc05_bad=''
_t76_tc05_case() {
  # $1 = extras ファイル名 / $2 = 自分が注入した残骸パス（この関数が始末する）
  _t76_c_extra=$1
  _t76_c_path=$2
  _t76_c_rc=0
  _t76_c_out=$(sh "$_T76_MINI" "$_T76_ROOT" "$_t76_c_extra" 2>&1) || _t76_c_rc=$?
  _t76_tc05_run=$((_t76_tc05_run + 1))
  if [ "$_t76_c_rc" -ne 0 ] || ! printf '%s' "$_t76_c_out" | grep -qE 'MINI:[0-9]+:0$'; then
    _t76_c_why=$(printf '%s' "$_t76_c_out" | grep -E 'FAIL|MINI:' | head -2 | tr '\n' ' ')
    _t76_tc05_bad="$_t76_tc05_bad $_t76_c_extra(rc=$_t76_c_rc $_t76_c_why)"
  elif [ -e "$_t76_c_path" ]; then
    _t76_tc05_bad="$_t76_tc05_bad $_t76_c_extra(residue-not-drained)"
  fi
  if [ -e "$_t76_c_path" ]; then
    rm -rf "${_t76_c_path:?ta-76: empty injected path refused}"
  fi
}
if [ ! -r "$_T76_MINI" ]; then
  t76_fail "TC-05: mini harness fixture missing: $_T76_MINI"
else
  # ta-42: 前回中断で残ったのと同じ形（TC-06 が作る TASK-T999 + handoff.md）
  _t76_inj="$_T76_WD/TASK-T999"
  mkdir -p "$_t76_inj"
  : > "$_t76_inj/handoff.md"
  register_cleanup "$_t76_inj"
  _t76_tc05_case ta-42-cli-subcommands.sh "$_t76_inj"

  # ta-44: TC-02 が「test-cases.md が無いこと」を前提にする側へ残骸を仕込む
  _t76_inj="$_T76_WD/TASK-T4400-ta44-tmp"
  mkdir -p "$_t76_inj"
  : > "$_t76_inj/test-cases.md"
  register_cleanup "$_t76_inj"
  _t76_tc05_case ta-44-eh457-cli-wiring.sh "$_t76_inj"

  # ta-45: TASK ディレクトリの位置に **通常ファイル** を残骸として置く。
  # 前回の中断で中途半端な書き込みが残った状況を模す。prune が先に走らなければ
  # ta-45 の mkdir -p が失敗して以降の TC が総崩れになる（＝順序が要件）。
  # 承認トークン（approvals/c3json 相当）を残骸に使うほうが実態に近いが、
  # AI はトークンパスへ書けない（EH-13 token-guard）ため採らない。
  _t76_inj="$_T76_WD/TASK-T45"
  printf 'truncated leftover from an interrupted run\n' > "$_t76_inj"
  register_cleanup "$_t76_inj"
  _t76_tc05_case ta-45-c3-mode-config.sh "$_t76_inj"

  # ta-12 は残骸「注入」ができない（既知の制約 / 本 PR の到達点）。
  # ta-12 が所有する一時パスは承認トークンそのもので、AI がそこへ書くのは
  # EH-13 token-guard が block する。したがって注入なしで実走し、
  #   (a) 単体で MINI:*:0 になること
  #   (b) 実行後にトークンが残らないこと（prune + drain + 末尾 rm の合成）
  # までを測る。「中断残骸から復帰できるか」は測れていない — この穴は
  # tests/extras/README.md 規約 9 の「できないこと」に記載する。
  _t76_c_rc=0
  _t76_c_out=$(sh "$_T76_MINI" "$_T76_ROOT" ta-12-maintenance.sh 2>&1) || _t76_c_rc=$?
  _t76_tc05_run=$((_t76_tc05_run + 1))
  if [ "$_t76_c_rc" -ne 0 ] || ! printf '%s' "$_t76_c_out" | grep -qE 'MINI:[0-9]+:0$'; then
    _t76_c_why=$(printf '%s' "$_t76_c_out" | grep -E 'FAIL|MINI:' | head -2 | tr '\n' ' ')
    _t76_tc05_bad="$_t76_tc05_bad ta-12(rc=$_t76_c_rc $_t76_c_why)"
  elif [ -e "$_T76_WD/_maintenance/maintenance.json" ]; then
    _t76_tc05_bad="$_t76_tc05_bad ta-12(token-left-behind)"
  fi

  if [ "$_t76_tc05_run" -lt 3 ]; then
    t76_fail "TC-05: only $_t76_tc05_run residue cases ran — refusing a vacuous PASS"
  elif [ -z "$_t76_tc05_bad" ]; then
    t76_pass "TC-05: $_t76_tc05_run extras pass from a dirty start and drain their own residue — #947 AC-1"
  else
    t76_fail "TC-05: residue-dependent extras:$_t76_tc05_bad"
  fi
fi

# ---------------------------------------------------------------------------
# TC-06: ta-44 / ta-45 の単体実行が「宣言した固定名パス」を残さない
# 判定軸を実 repo の porcelain 全体にすると、他セッションが docs/working を
# 触っただけで落ちる（並走時 3 回中 2 回 偽 FAIL の実測 = M7）。本 TC が測るのは
# 「この 2 本が自分の宣言したパスを残すか」だけなので、対象を固定名に絞る。
_T76_TC06_PATHS="$_T76_WD/TASK-T4400-ta44-tmp $_T76_WD/TASK-T4401-ta44-tmp $_T76_WD/TASK-T45"
_t76_ok=1
_t76_ran0=0
for _t76_b in ta-44-eh457-cli-wiring.sh ta-45-c3-mode-config.sh; do
  _t76_src=0
  sh "$_T76_DIR/$_t76_b" </dev/null >/dev/null 2>&1 || _t76_src=$?
  # rc=0（全 pass）/ rc=3（前提未充足）はどちらも残留検査の前提として妥当
  case "$_t76_src" in
    0) _t76_ran0=$((_t76_ran0 + 1)) ;;
    3) : ;;
    *) _t76_ok=0; t76_fail "TC-06: $_t76_b standalone rc=$_t76_src (expected 0 or 3)" ;;
  esac
done
_t76_left=''
for _t76_p in $_T76_TC06_PATHS; do
  [ ! -e "$_t76_p" ] || _t76_left="$_t76_left $_t76_p"
done
# 陽性コントロール: 存在検出器が「ある」を実際に検出できることを実証する
mkdir -p "$_t76_tmp/exists-probe"
if [ ! -e "$_t76_tmp/exists-probe" ]; then
  t76_fail "TC-06: positive control failed — existence detector cannot see an existing path"
  _t76_ok=0
fi
if [ "$_t76_ran0" -lt 1 ]; then
  printf '  [INFO] TC-06: both targets reported SKIP (rc=3) — residue check is vacuous here\n'
fi
if [ "$_t76_ok" = "1" ] && [ -z "$_t76_left" ]; then
  t76_pass "TC-06: ta-44 / ta-45 standalone runs leave none of their declared paths behind"
elif [ "$_t76_ok" = "1" ]; then
  t76_fail "TC-06: declared paths left behind after standalone runs:$_t76_left"
fi

pg_extra_contract_finalize
