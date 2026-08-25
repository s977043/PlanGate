# tests/extras/ta-77-c1-item-count.sh
# PG_EXTRA_CAPABILITY: standalone-capable
# Sourced by tests/run-tests.sh -- uses $pass / $fail counters
#
# Issue #960 再発防止: C-1 チェック項目数の直書き乖離を機械検出する
# `scripts/check-c1-item-count.py` の検出力を回帰テストで固定する。
#
# 背景: C-1 の項目数が本文に直書きされ、正本（docs/working/templates/review-self.md）
# を更新しても追随せず 15 / 17 / 20 / 25 の 4 通りに散った（#960）。方針の正本は
# docs/ai/c1-item-count-policy.md。
#
# ---------------------------------------------------------------------------
# Sandbox 方式（ta-69 を踏襲）
# ---------------------------------------------------------------------------
# 検査スクリプトは REPO_ROOT を `Path(__file__).resolve().parent.parent` で
# 解決するため、tmp の <sandbox>/scripts/ へコピーすると REPO_ROOT が
# サンドボックスを指す。これにより **引数なしの既定経路**（CI が通る経路）を
# 実 repo を汚さずに検証できる。
#
# ---------------------------------------------------------------------------
# 不変条件（ta-69 と同一 / set -e 安全性）
# ---------------------------------------------------------------------------
# run-tests.sh は `set -eu` で動き、extras を **source** する。
#   (1) rc 捕捉は必ず `_t77_rc_of`（OR-list 形式）を通す。
#       `( cd "$D" && python3 x.py; echo $? )` 形式は rc≠0 のとき set -e が
#       `echo $?` に到達する前にサブシェルを終了させ、捕捉値が **空文字**に
#       なる。結果 rc=1 を期待する TC が全滅し、rc=0 を期待する TC だけが
#       （空の sandbox でも）通ってしまう。
#   (2) sandbox への注入は **前提条件として明示検証**する
#       （`_t77_assert_contains` / `_t77_assert_total`）。注入が silently
#       失敗すると検査器は「違反なし」で rc=0 を返し、**TC が緑になる**。
#   (3) (2) の検出力そのものを TC-G1〜TC-G3 で実証する。
#
# ---------------------------------------------------------------------------
# 件数契約の禁止（#960 / 成長する正本に絶対件数を書かない）
# ---------------------------------------------------------------------------
# 「25」「17」といった項目数を本ファイルにハードコードしない。期待値は
# すべて **sandbox の正本から実測した値との相対**（total / total+1 /
# 導出不能なセンチネル）で組み立てる。正本の項目数が増減しても本テストは
# 追随不要でなければならない（それが #960 の再発防止そのもの）。
#
# 射程宣言（本ファイルが作る一時状態 / README 規約 9）:
#   - $_T77_S（mktemp -d 配下の sandbox）のみ。**実 repo パスには一切書かない**。
#     register_cleanup へ登録し、末尾でも明示 rm する。trap は張らない。
#
# TC 一覧:
#   TC-1   現ツリー（引数なし既定経路）-> rc=0（陰性コントロール）
#   TC-2   sandbox 正本の合計値を実体とズラす -> rc=1（自己整合の検出）
#   TC-3   走査対象 doc に導出不能な項目数を注入 -> rc=1
#   TC-4   .claude/worktrees/ 配下に同じ違反を置く -> rc=0（除外が効いている）
#   TC-G1  pristine sandbox -> rc=0（TC-2 / TC-3 の注入前ベースライン）
#   TC-G2  注入前提の検証ヘルパが、注入失敗時に明示的な失敗として発火する
#   TC-G3a センチネル値が正本から導出できないことを検査器自身の導出で確認
#   TC-G3b/c TC-2 / TC-3 の各注入の直前が rc=0（rc 反転が注入由来であること）

# ---- extras execution contract bootstrap (#921) ----------------------------
if [ "${PG_HARNESS_SOURCED:-0}" = "1" ] && [ -n "${FIXTURES_DIR:-}" ] && [ -n "${EXTRAS_DIR:-}" ]; then
  _pg_extra_mode=harness
  _pg_extra_dir="$EXTRAS_DIR"
else
  # standalone: 規約 8 に従い呼び出し元 env を無害化する（run-tests.sh 冒頭と
  # 同一の 7 env）。
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
pg_extra_contract_init ta-77-c1-item-count standalone-capable

printf '\n=== TA-77: C-1 item-count drift detection (#960) ===\n'

_T77_ROOT="$(CDPATH= cd -- "$_pg_extra_dir/../.." && pwd)"

t77_pass() { pass=$((pass + 1)); printf '  [PASS] %s\n' "$1"; }
t77_fail() { fail=$((fail + 1)); printf '  [FAIL] %s\n' "$1" >&2; }

# set -e 安全な rc 捕捉。$1=作業ディレクトリ、$2 以降=実行するコマンド。
_t77_rc_of() {
  _t77_rc_dir="$1"
  shift
  _t77_rc_val=0
  ( CDPATH= cd -- "$_t77_rc_dir" && "$@" >/dev/null 2>&1 ) || _t77_rc_val=$?
  printf '%s' "$_t77_rc_val"
}

# set -e 安全な stdout+stderr 捕捉。
_t77_out_of() {
  _t77_out_dir="$1"
  shift
  ( CDPATH= cd -- "$_t77_out_dir" && "$@" 2>&1 ) || true
}

_T77_SRC="$_T77_ROOT/scripts/check-c1-item-count.py"
_T77_CANON_REL="docs/working/templates/review-self.md"
_T77_CANON_SRC="$_T77_ROOT/$_T77_CANON_REL"

if [ ! -f "$_T77_SRC" ] || [ ! -f "$_T77_CANON_SRC" ]; then
  pg_extra_contract_skip "check-c1-item-count.py or the C-1 canon is absent"
  return 0
fi

if ! command -v python3 >/dev/null 2>&1; then
  pg_extra_contract_skip "python3 not available"
  return 0
fi

# ---------------------------------------------------------------------------
# sandbox 構築（実 repo には一切書かない）
# ---------------------------------------------------------------------------
_T77_S=$(mktemp -d)
if command -v register_cleanup >/dev/null 2>&1; then register_cleanup "$_T77_S"; fi
rm -rf "$_T77_S/scripts" "$_T77_S/docs" "$_T77_S/.claude" 2>/dev/null || true
mkdir -p "$_T77_S/scripts" "$_T77_S/docs/working/templates" "$_T77_S/docs/ai" \
         "$_T77_S/.claude/worktrees/agent-ta77probe"
cp "$_T77_SRC" "$_T77_S/scripts/check-c1-item-count.py"
cp "$_T77_CANON_SRC" "$_T77_S/$_T77_CANON_REL"
cp "$_T77_CANON_SRC" "$_T77_S/pristine-canon.md"

_T77_SB_CANON="$_T77_S/$_T77_CANON_REL"
_T77_PROBE="$_T77_S/docs/ai/ta77-probe.md"
_T77_WT_PROBE="$_T77_S/.claude/worktrees/agent-ta77probe/ta77-probe.md"

_t77_sb_rc()  { _t77_rc_of  "$_T77_S" python3 scripts/check-c1-item-count.py; }
_t77_sb_run() { _t77_out_of "$_T77_S" python3 scripts/check-c1-item-count.py; }

# sandbox を pristine（無改変のコピー + probe 無し）へ戻す。
_t77_reset() {
  cp "$_T77_S/pristine-canon.md" "$_T77_SB_CANON" 2>/dev/null || return 1
  rm -f "$_T77_PROBE" "$_T77_WT_PROBE" 2>/dev/null || true
  return 0
}

# 正本の「合計」宣言値を読む（値そのものは契約せず、相対値の起点にだけ使う）。
_t77_total_of() {
  sed -nE 's/^\|[[:space:]]*\*\*合計\*\*[[:space:]]*\|[^|]*\|[[:space:]]*\*\*([0-9]+)\*\*[[:space:]]*\|.*/\1/p' "$1" | head -1
}

# 注入が本当に成立したかの前提条件検証。不成立なら **明示的に FAIL** させる。
# これが無いと、注入失敗時に検査器が「違反なし」で rc=0 を返し TC が緑になる。
_t77_assert_contains() {
  # $1=path $2=literal $3=label
  if [ ! -f "$1" ] || ! grep -qF -- "$2" "$1" 2>/dev/null; then
    t77_fail "$3: sandbox injection failed (literal not found in $1)"
    return 1
  fi
  return 0
}

# 「合計」宣言値が期待どおり書き換わったかの前提条件検証。
_t77_assert_total() {
  # $1=want $2=label
  _t77_at_got=$(_t77_total_of "$_T77_SB_CANON")
  if [ "$_t77_at_got" != "$1" ]; then
    t77_fail "$2: sandbox canon mutation failed (total want=$1 got=${_t77_at_got:-<none>})"
    return 1
  fi
  return 0
}

# ---------------------------------------------------------------------------
# TC-G2: 前提条件検証ヘルパ自身の検出力（注入失敗が silent rc=0 に化けない）
# ---------------------------------------------------------------------------
_t77_g2=$( t77_fail() { printf 'GUARD_FIRED\n'; }; \
           _t77_assert_contains "$_T77_S/does-not-exist-960.md" "anything" "probe" || true )
if printf '%s' "$_t77_g2" | grep -q 'GUARD_FIRED'; then
  t77_pass "TC-G2: a failed injection surfaces as an explicit test failure, not a silent rc=0"
else
  t77_fail "TC-G2: expected the precondition guard to fire on a failed injection"
fi

# ---------------------------------------------------------------------------
# TC-G1: pristine sandbox -> rc=0（TC-2 / TC-3 のベースライン）
# ---------------------------------------------------------------------------
_t77_g1_total=''
if _t77_reset; then
  _t77_g1_total=$(_t77_total_of "$_T77_SB_CANON")
  if [ -z "$_t77_g1_total" ]; then
    t77_fail "TC-G1: could not read the declared total from the sandbox canon"
  else
    _t77_g1_rc=$(_t77_sb_rc)
    if [ "$_t77_g1_rc" = "0" ]; then
      t77_pass "TC-G1: pristine sandbox copy -> rc=0 (baseline for the injections)"
    else
      t77_fail "TC-G1: expected rc=0 on a pristine sandbox copy, got $_t77_g1_rc"
    fi
  fi
else
  t77_fail "TC-G1: sandbox reset failed"
fi

# 正本から導出できないセンチネル値。正本の実測 allowed 集合に含まれないことを
# 検査器自身の導出ロジックで確かめてから使う（定数の当てずっぽうにしない）。
_T77_SENTINEL=4243
_t77_sentinel_ok=$(
  CDPATH= cd -- "$_T77_S" && python3 - "$_T77_CANON_REL" "$_T77_SENTINEL" <<'PY' 2>/dev/null || true
import sys, importlib.util
spec = importlib.util.spec_from_file_location("c1chk", "scripts/check-c1-item-count.py")
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
text = open(sys.argv[1], encoding="utf-8").read()
_total, _headings, allowed = mod.derive_allowed(text)
print("outside" if int(sys.argv[2]) not in allowed else "inside")
PY
)
if [ "$_t77_sentinel_ok" = "outside" ]; then
  t77_pass "TC-G3a: sentinel $_T77_SENTINEL is verifiably outside the derived allowed set"
else
  t77_fail "TC-G3a: sentinel $_T77_SENTINEL not confirmed outside the allowed set (got '${_t77_sentinel_ok:-<none>}')"
fi

# ---------------------------------------------------------------------------
# TC-2: 正本の「合計」宣言値を実体とズラす -> rc=1（自己整合の検出）
# ---------------------------------------------------------------------------
if _t77_reset && [ -n "$_t77_g1_total" ]; then
  _t77_pre_rc=$(_t77_sb_rc)          # TC-G3b: 注入直前は rc=0 であること
  _t77_bogus=$((_t77_g1_total + 1))
  _t77_mut_ok=1
  ( CDPATH= cd -- "$_T77_S" && python3 - "$_T77_CANON_REL" "$_t77_g1_total" "$_t77_bogus" <<'PY'
import re, sys
p, old, new = sys.argv[1], sys.argv[2], sys.argv[3]
text = open(p, encoding="utf-8").read()
pat = re.compile(r"(\|\s*\*\*合計\*\*\s*\|[^|]*\|\s*\*\*)" + re.escape(old) + r"(\*\*\s*\|)")
text2, n = pat.subn(r"\g<1>" + new + r"\g<2>", text, count=1)
if n != 1:
    sys.exit(1)
open(p, "w", encoding="utf-8").write(text2)
PY
  ) || _t77_mut_ok=0

  if [ "$_t77_mut_ok" != "1" ]; then
    t77_fail "TC-2: could not rewrite the declared total in the sandbox canon"
  elif _t77_assert_total "$_t77_bogus" "TC-2"; then
    _t77_tc2_rc=$(_t77_sb_rc)
    if [ "$_t77_pre_rc" = "0" ]; then
      t77_pass "TC-G3b: rc=0 immediately before the TC-2 injection (the flip is injection-caused)"
    else
      t77_fail "TC-G3b: expected rc=0 immediately before the TC-2 injection, got $_t77_pre_rc"
    fi
    if [ "$_t77_tc2_rc" = "1" ] && _t77_sb_run | grep -q '宣言値と実体が不一致'; then
      t77_pass "TC-2: declared total out of sync with the actual headings -> rc=1"
    else
      t77_fail "TC-2: expected rc=1 for a desynced declared total, got $_t77_tc2_rc"
    fi
  fi
else
  t77_fail "TC-2: sandbox reset / total probe failed"
fi

# ---------------------------------------------------------------------------
# TC-3: 走査対象 doc に、正本から導出できない項目数を注入 -> rc=1
# ---------------------------------------------------------------------------
if _t77_reset; then
  _t77_pre_rc=$(_t77_sb_rc)          # TC-G3c: 注入直前は rc=0 であること
  printf '# ta-77 probe\n\nC-1 セルフレビューは全 %s 項目である。\n' "$_T77_SENTINEL" \
    > "$_T77_PROBE" 2>/dev/null || true
  if _t77_assert_contains "$_T77_PROBE" "$_T77_SENTINEL 項目" "TC-3"; then
    _t77_tc3_rc=$(_t77_sb_rc)
    if [ "$_t77_pre_rc" = "0" ]; then
      t77_pass "TC-G3c: rc=0 immediately before the TC-3 injection (the flip is injection-caused)"
    else
      t77_fail "TC-G3c: expected rc=0 immediately before the TC-3 injection, got $_t77_pre_rc"
    fi
    if [ "$_t77_tc3_rc" = "1" ] && _t77_sb_run | grep -q 'ta77-probe.md'; then
      t77_pass "TC-3: a hardcoded item count not derivable from the canon -> rc=1"
    else
      t77_fail "TC-3: expected rc=1 for a non-derivable hardcoded count, got $_t77_tc3_rc"
    fi
  fi
else
  t77_fail "TC-3: sandbox reset failed"
fi

# ---------------------------------------------------------------------------
# TC-4: 同じ違反を .claude/worktrees/ 配下に置く -> rc=0（除外が効いている）
# ---------------------------------------------------------------------------
if _t77_reset; then
  printf '# ta-77 worktree probe\n\nC-1 セルフレビューは全 %s 項目である。\n' "$_T77_SENTINEL" \
    > "$_T77_WT_PROBE" 2>/dev/null || true
  if _t77_assert_contains "$_T77_WT_PROBE" "$_T77_SENTINEL 項目" "TC-4"; then
    _t77_tc4_rc=$(_t77_sb_rc)
    if [ "$_t77_tc4_rc" = "0" ]; then
      t77_pass "TC-4: the same violation under .claude/worktrees/ -> rc=0 (excluded)"
    else
      t77_fail "TC-4: expected rc=0 for a violation under .claude/worktrees/, got $_t77_tc4_rc"
    fi
  fi
else
  t77_fail "TC-4: sandbox reset failed"
fi

_t77_reset || true

# ---------------------------------------------------------------------------
# TC-1: 現ツリー（引数なし既定経路）-> rc=0（陰性コントロール）
# ---------------------------------------------------------------------------
_t77_tc1_rc=$(_t77_rc_of "$_T77_ROOT" python3 scripts/check-c1-item-count.py)
if [ "$_t77_tc1_rc" = "0" ]; then
  t77_pass "TC-1: production tree -> rc=0 (no C-1 item-count drift)"
else
  t77_fail "TC-1: expected rc=0 on the production tree, got $_t77_tc1_rc"
  _t77_out_of "$_T77_ROOT" python3 scripts/check-c1-item-count.py | sed 's/^/    /' >&2
fi

rm -rf "$_T77_S" 2>/dev/null || true

pg_extra_contract_finalize
