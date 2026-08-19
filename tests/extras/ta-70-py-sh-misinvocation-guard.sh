# tests/extras/ta-70-py-sh-misinvocation-guard.sh
# PG_EXTRA_CAPABILITY: standalone-capable
# Sourced by tests/run-tests.sh — uses $pass / $fail counters
# scripts/*.py の「誤インタプリタ起動」副作用ガード回帰テスト（#1169）。
#
# 背景: sh scripts/check-skill-frontmatter.py を実行すると、sh は module
# docstring を二重引用符文字列として読むため docstring 内のバッククォートが
# コマンド置換として評価される。実際に
# scripts/install-plangate-skills-to-codex.sh が起動し .codex/skills の
# 34 ファイルが書き換わった（v8.21.0 リリース準備レビュー中の実害）。
# shebang と実行権限は既に付いていたため、それだけでは塞がらない。
#
#   TC-01: 全 scripts/*.py が PG-SH-GUARD marker を持つ（新規追加ファイル込みの
#          再発検知。バッククォート除去だけでは再導入で再発するため構造で塞ぐ）
#   TC-02: marker がファイル先頭 12 行以内（sh が危険な行を読む前に止まる位置）
#   TC-03: 全 scripts/*.py が python3 で compile できる（polyglot が Python を壊さない）
#   TC-04: 実ファイル — 全 scripts/*.py を sh で起動すると exit 2 かつ診断メッセージ
#   TC-05: 実ファイル — TC-04 の一連の実行で repo が 1 バイトも変わらない
#   TC-06: 合成 fixture 正側 — ガード付きは sentinel を起動せず exit 2
#   TC-07: 合成 fixture 負側（変異注入） — ガードを外すと sentinel が実際に起動する
#          （本 TA に検出力があることの実証。ここが PASS しないと TC-06 は空振り）
#   TC-08: 合成 fixture — ガード付きでも python3 起動時の挙動は不変

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
pg_extra_contract_init ta-70-py-sh-misinvocation-guard standalone-capable

# ta-26 TC-33（静的検査 / README 規約 8）準拠
if pg_extra_contract_is_standalone; then
  unset PLANGATE_SKIP_REASON PLANGATE_HOOK_TASK PLANGATE_HOOK_FILE PLANGATE_BYPASS_HOOK PLANGATE_HOOK_STRICT PG_HARNESS_SOURCED PLANGATE_ALLOW_MASS_DELETE 2>/dev/null || true
fi

printf '\n=== TA-70: scripts/*.py sh-misinvocation guard (#1169) ===\n'

t70_pass() { pass=$((pass + 1)); printf '  [PASS] %s\n' "$1"; }
t70_fail() { fail=$((fail + 1)); printf '  [FAIL] %s\n' "$1" >&2; }

_T70_ROOT="$(CDPATH= cd -- "$_pg_extra_dir/../.." && pwd)"
_T70_MARKER='PG-SH-GUARD'

# === TC-01 全 scripts/*.py が guard marker を持つ ===
_t70_total=0
_t70_missing=''
for _t70_f in "$_T70_ROOT"/scripts/*.py; do
  [ -f "$_t70_f" ] || continue
  _t70_total=$((_t70_total + 1))
  grep -q "$_T70_MARKER" "$_t70_f" || _t70_missing="$_t70_missing $(basename "$_t70_f")"
done
if [ "$_t70_total" -ge 20 ] && [ -z "$_t70_missing" ]; then
  t70_pass "TC-01 scripts/*.py ${_t70_total} 件すべてに $_T70_MARKER がある"
else
  t70_fail "TC-01 guard 欠落 (走査 ${_t70_total} 件 / 欠落:${_t70_missing:- なし})"
fi

# === TC-02 marker がファイル先頭 12 行以内（sh が危険な行を読む前に止まる位置） ===
_t70_late=''
for _t70_f in "$_T70_ROOT"/scripts/*.py; do
  [ -f "$_t70_f" ] || continue
  head -12 "$_t70_f" | grep -q "$_T70_MARKER" || _t70_late="$_t70_late $(basename "$_t70_f")"
done
if [ -z "$_t70_late" ]; then
  t70_pass "TC-02 guard が先頭 12 行以内にある"
else
  t70_fail "TC-02 guard 位置が遅い:$_t70_late"
fi

# === TC-03 polyglot が Python 側を壊していない ===
_t70_broken=''
for _t70_f in "$_T70_ROOT"/scripts/*.py; do
  [ -f "$_t70_f" ] || continue
  python3 -c 'import sys; compile(open(sys.argv[1], encoding="utf-8").read(), sys.argv[1], "exec")' "$_t70_f" >/dev/null 2>&1 || _t70_broken="$_t70_broken $(basename "$_t70_f")"
done
if [ -z "$_t70_broken" ]; then
  t70_pass "TC-03 全 scripts/*.py が python3 で compile 可能"
else
  t70_fail "TC-03 compile 失敗:$_t70_broken"
fi

# === TC-04 / TC-05 実ファイルを sh で起動しても副作用が出ない ===
# 安全順序: TC-01 が緑（= guard がある）ときだけ実走する。guard 不在のまま
# 実走すると本テスト自身が repo を書き換えてしまうため。
if [ -z "$_t70_missing" ] && [ "$_t70_total" -ge 20 ]; then
  _t70_before="$(cd "$_T70_ROOT" && git status --porcelain 2>/dev/null || printf 'GIT-UNAVAILABLE')"
  _t70_badrc=''
  _t70_nomsg=''
  for _t70_f in "$_T70_ROOT"/scripts/*.py; do
    [ -f "$_t70_f" ] || continue
    _t70_rel="scripts/$(basename "$_t70_f")"
    _t70_rc=0
    _t70_out="$(cd "$_T70_ROOT" && sh "$_t70_rel" </dev/null 2>&1)" || _t70_rc=$?
    [ "$_t70_rc" -eq 2 ] || _t70_badrc="$_t70_badrc $(basename "$_t70_f"):rc=$_t70_rc"
    printf '%s' "$_t70_out" | grep -q 'python3' || _t70_nomsg="$_t70_nomsg $(basename "$_t70_f")"
  done
  _t70_after="$(cd "$_T70_ROOT" && git status --porcelain 2>/dev/null || printf 'GIT-UNAVAILABLE')"
  if [ -z "$_t70_badrc" ] && [ -z "$_t70_nomsg" ]; then
    t70_pass "TC-04 全 scripts/*.py が sh 起動で exit 2 + python3 案内を出す"
  else
    t70_fail "TC-04 rc 不一致:${_t70_badrc:- なし} / 診断なし:${_t70_nomsg:- なし}"
  fi
  if [ "$_t70_before" = "$_t70_after" ]; then
    t70_pass "TC-05 sh 起動一巡で repo の git status が不変（副作用ゼロ）"
  else
    t70_fail "TC-05 sh 起動で repo が変化した（#1169 再発）"
  fi
else
  t70_fail "TC-04/TC-05 実走中止: guard 不在（TC-01 を先に直すこと）"
fi

# === TC-06 / TC-07 / TC-08 合成 fixture（変異注入で検出力を実証） ===
_T70_TMP="$(mktemp -d)"
register_cleanup "$_T70_TMP"
mkdir -p "$_T70_TMP/scripts"

# sentinel: 起動されたら FIRED を作る（= コマンド置換が評価された物的証拠）
printf '#!/bin/sh\ntouch "$(dirname "$0")/../FIRED"\n' | tee "$_T70_TMP/scripts/sentinel.sh" >/dev/null
chmod +x "$_T70_TMP/scripts/sentinel.sh"

_T70_VICTIM_DOC='victim — 詳細は `scripts/sentinel.sh` を参照。'
_T70_GUARD='""":"
# --- PG-SH-GUARD (#1169) ---
echo "ERROR: $0 is a Python script; do not run it with sh/bash." >&2
echo "       Use: python3 $0 [args...]" >&2
exit 2
":"""

__doc__ = """'

# --- TC-07 負側（変異注入）: guard を外すとバッククォートが評価され sentinel が起動する ---
printf '#!/usr/bin/env python3\n"""\n%s\n"""\nprint("python-ran")\n' "$_T70_VICTIM_DOC" | tee "$_T70_TMP/scripts/victim.py" >/dev/null
rm -f "$_T70_TMP/FIRED"
_t70_rc7=0
(cd "$_T70_TMP" && sh scripts/victim.py </dev/null >/dev/null 2>&1) || _t70_rc7=$?
if [ -f "$_T70_TMP/FIRED" ]; then
  t70_pass "TC-07 変異注入: guard を外すと sentinel が実際に起動する（検出力の実証）"
else
  t70_fail "TC-07 変異注入で sentinel が起動しない (rc=$_t70_rc7) — TC-06 が空振りしている"
fi

# --- TC-06 正側: guard 付きは sentinel を起動せず exit 2 ---
printf '#!/usr/bin/env python3\n%s\n%s\n"""\nprint("python-ran")\n' "$_T70_GUARD" "$_T70_VICTIM_DOC" | tee "$_T70_TMP/scripts/victim.py" >/dev/null
rm -f "$_T70_TMP/FIRED"
_t70_rc6=0
_t70_out6="$(cd "$_T70_TMP" && sh scripts/victim.py </dev/null 2>&1)" || _t70_rc6=$?
_t70_fired6=no
if [ -f "$_T70_TMP/FIRED" ]; then
  _t70_fired6=yes
fi
if [ "$_t70_fired6" = no ] && [ "$_t70_rc6" -eq 2 ] && printf '%s' "$_t70_out6" | grep -q 'python3'; then
  t70_pass "TC-06 guard 付きは sentinel 未起動 / exit 2 / 診断メッセージあり"
else
  t70_fail "TC-06 guard が効いていない (rc=$_t70_rc6, FIRED=$_t70_fired6)"
fi

# --- TC-08 guard 付きでも python3 起動の挙動は不変 ---
_t70_rc8=0
_t70_out8="$(cd "$_T70_TMP" && python3 scripts/victim.py </dev/null 2>&1)" || _t70_rc8=$?
if [ "$_t70_rc8" -eq 0 ] && printf '%s' "$_t70_out8" | grep -q 'python-ran'; then
  t70_pass "TC-08 guard 付きでも python3 起動は従来どおり（polyglot が Python を壊さない）"
else
  t70_fail "TC-08 python3 起動が壊れた (rc=$_t70_rc8): $(printf '%s' "$_t70_out8" | head -3 | tr '\n' ';')"
fi

rm -rf "$_T70_TMP"

pg_extra_contract_finalize
