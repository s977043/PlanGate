# tests/extras/ta-70-py-sh-misinvocation-guard.sh
# PG_EXTRA_CAPABILITY: standalone-capable
# Sourced by tests/run-tests.sh — uses $pass / $fail counters
# Python スクリプトの「誤インタプリタ起動」副作用ガード回帰テスト（#1169）。
#
# 走査対象は 3 群:
#   1. scripts/*.py            （#1175 で是正した射程）
#   2. scripts/ai-loop/*.py    （残射程。sh 誤起動で gh pr merge /
#      gh pr review --approve / gh pr close へ実際に到達する経路を含む）
#   3. plugin/plangate/skills/ai-loop-cycle/scripts/*.py（配布ミラー）
#
# 背景: sh scripts/check-skill-frontmatter.py を実行すると、sh は module
# docstring を二重引用符文字列として読むため docstring 内のバッククォートが
# コマンド置換として評価される。実際に
# scripts/install-plangate-skills-to-codex.sh が起動し .codex/skills の
# 34 ファイルが書き換わった（v8.21.0 リリース準備レビュー中の実害）。
# shebang と実行権限は既に付いていたため、それだけでは塞がらない。
#
#   TC-01: 走査対象 3 群の全 .py が guard を **構造として** 持つ（#1178 AC-1/AC-a）
#          — marker 文字列の有無ではなく「(shebang があればその次の) 行が厳密に
#          ガード開始行 `""":"` であり、閉じ行 `":"""` までのブロック内に
#          `PG-SH-GUARD` と `exit 2` の両方がある」ことを検査する。
#          marker 文字列だけを持つ未ガードファイル（この規約自体の lint を
#          後から足す等）が緑になり、そのまま TC-04 で sh 起動されるのを防ぐ
#   TC-02: guard marker がファイル先頭 12 行以内（sh が危険な行を読む前に止まる位置）
#   TC-03: 走査対象の全 .py が python3 で compile できる（polyglot が Python を壊さない）
#   TC-04: 実ファイル — 走査対象を sh で起動すると exit 2 かつ **guard 固有の**
#          診断文字列を出す（#1178 AC-3。`python3` の語は本 repo の Usage 定型に
#          頻出するため判別に使わない）
#   TC-05: 実ファイル — TC-04 の一連の実行で repo が 1 バイトも変わらない
#          （#1178 MN-1: ignored も含めて比較し `__pycache__` のみの副作用も捕捉）
#   TC-06: 合成 fixture 正側 — ガード付きは sentinel を起動せず exit 2
#   TC-07: 合成 fixture 負側（変異注入） — ガードを外すと sentinel が実際に起動する
#          （本 TA に検出力があることの実証。ここが PASS しないと TC-06 は空振り）
#   TC-08: 合成 fixture — ガード付きでも python3 起動の挙動は不変
#   TC-09: 実走の timeout 配線が効いている（#1178 AC-5。未ガードの .py が
#          ブロックする外部コマンドを参照していても FAIL でありハングでないこと。
#          standalone 実行には CI の timeout-minutes が効かないため本体側で持つ）
#
# vacuous PASS 対策（#1178 AC-4）: TC-01〜TC-04 はいずれも「走査 0 件でも
# 違反 0 件」で PASS しうる。走査母数 `_t70_total` の floor 判定を各 PASS 条件の
# 連言に加える。floor は `-ge 20`（件数は運用で増減するため `-eq` にしない / #1087 AC-9）。

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

printf '\n=== TA-70: python sh-misinvocation guard (#1169) ===\n'

t70_pass() { pass=$((pass + 1)); printf '  [PASS] %s\n' "$1"; }
t70_fail() { fail=$((fail + 1)); printf '  [FAIL] %s\n' "$1" >&2; }

_T70_ROOT="$(CDPATH= cd -- "$_pg_extra_dir/../.." && pwd)"
_T70_MARKER='PG-SH-GUARD'
# guard 固有の診断文字列（#1178 AC-3）。`python3` の語は `scripts/*.py` の
# Usage 定型（`python3 scripts/foo.py`）に頻出し、未ガードファイルが sh で
# 落ちたときのエラー出力にもそのまま現れるため判別に使えない。
_T70_DIAG='is a Python script; do not run it with sh/bash.'
# 走査母数の floor（#1087 AC-9: 絶対件数を契約値にしない。`-eq` にしないこと）
_T70_MIN_TOTAL=20

_T70_TMP="$(mktemp -d)"
register_cleanup "$_T70_TMP"
mkdir -p "$_T70_TMP/scripts"

# 実走の上限秒（#1178 AC-5）。`</dev/null` は stdin 待ちしか塞がないため、
# 未ガードの .py の docstring がブロックする外部コマンドを参照していると
# FAIL ではなくハングする。CI の `timeout-minutes` は standalone 実行に
# 効かないので本体側で持つ。TC-09 が「この配線が実際に効くこと」を実証する。
_T70_SH_TIMEOUT_SEC="${PG_T70_SH_TIMEOUT_SEC:-20}"
_T70_TIMEOUT=''
if command -v timeout >/dev/null 2>&1; then
  _T70_TIMEOUT='timeout'
elif command -v gtimeout >/dev/null 2>&1; then
  _T70_TIMEOUT='gtimeout'
fi
# 出力は「パイプ捕捉」ではなくファイル経由で受け取る。timeout が直接の子
# （sh）を殺しても孫（docstring 由来の外部コマンド）が生き残ると、
# `$(...)` はパイプが閉じるまで待ち続けて結局ハングするため。
_t70_run_sh() {
  # $1=cwd  $2=起動する相対パス  $3=上限秒  $4=出力先ファイル
  if [ -n "$_T70_TIMEOUT" ]; then
    (cd "$1" && "$_T70_TIMEOUT" "$3" sh "$2" </dev/null >"$4" 2>&1)
  else
    (cd "$1" && sh "$2" </dev/null >"$4" 2>&1)
  fi
}

# 走査対象は 1 箇所でのみ導出する（TC-01/02/03/04 が独立に glob を再列挙すると
# drift 源が 4 箇所になる）。件数は運用で増減するため絶対件数を契約値にしない。
# 代わりに「各群が 1 件以上に展開されたこと」を機械検出し、glob が丸ごと空振り
# した状態で緑になるのを防ぐ。
_T70_DIRS='scripts scripts/ai-loop plugin/plangate/skills/ai-loop-cycle/scripts'
_T70_LIST="$_T70_TMP/scan-list.txt"
: >"$_T70_LIST"
_t70_emptydir=''
for _t70_d in $_T70_DIRS; do
  _t70_n=0
  for _t70_g in "$_T70_ROOT/$_t70_d"/*.py; do
    [ -f "$_t70_g" ] || continue
    _t70_n=$((_t70_n + 1))
    printf '%s\n' "$_t70_g" >>"$_T70_LIST"
  done
  [ "$_t70_n" -gt 0 ] || _t70_emptydir="$_t70_emptydir $_t70_d"
done
_t70_total=$(grep -c . "$_T70_LIST" || true)
[ -n "$_t70_total" ] || _t70_total=0

# guard の構造判定（#1178 AC-1 / AC-a）。
#   - 1 行目が shebang ならそれを読み飛ばす（`scripts/_paths.py` 等の
#     ライブラリモジュールは shebang を持たず guard が 1 行目にある）
#   - その次の行が **厳密に** `""":"`（ガード開始行）であること
#   - 閉じ行 `":"""` までのブロック内に `PG-SH-GUARD` と `exit 2` があること
# marker 文字列がファイルのどこかにあるだけでは通らない。
_t70_struct_ok() {
  awk '
    NR == 1 && /^#!/ { next }
    !started {
      if ($0 != "\"\"\":\"") { bad = 1; exit }
      started = 1; next
    }
    started && !closed && $0 == "\":\"\"\"" { closed = 1; exit }
    started && !closed && $0 ~ /^exit 2[[:space:]]*$/ { hasexit = 1 }
    started && !closed && /PG-SH-GUARD/ { marker = 1 }
    NR > 40 { bad = 1; exit }
    END { exit (!bad && started && closed && marker && hasexit) ? 0 : 1 }
  ' "$1"
}

# === TC-01 走査対象 3 群の全 .py が guard を構造として持つ ===
_t70_missing=''
while IFS= read -r _t70_f; do
  [ -n "$_t70_f" ] || continue
  _t70_struct_ok "$_t70_f" || _t70_missing="$_t70_missing ${_t70_f#"$_T70_ROOT"/}"
done <"$_T70_LIST"
if [ "$_t70_total" -ge "$_T70_MIN_TOTAL" ] && [ -z "$_t70_missing" ] && [ -z "$_t70_emptydir" ]; then
  t70_pass "TC-01 走査対象 ${_t70_total} 件すべてが guard を構造として持つ (${_T70_DIRS})"
else
  t70_fail "TC-01 guard 構造欠落 (走査 ${_t70_total} 件 / 欠落:${_t70_missing:- なし} / 空 glob:${_t70_emptydir:- なし})"
fi

# === TC-02 marker がファイル先頭 12 行以内（sh が危険な行を読む前に止まる位置） ===
_t70_late=''
while IFS= read -r _t70_f; do
  [ -n "$_t70_f" ] || continue
  head -12 "$_t70_f" | grep -q "$_T70_MARKER" || _t70_late="$_t70_late ${_t70_f#"$_T70_ROOT"/}"
done <"$_T70_LIST"
# AC-4: `_t70_late` が初期値のまま（ループ 0 回転）でも PASS する恒真を塞ぐ
if [ -z "$_t70_late" ] && [ "$_t70_total" -ge "$_T70_MIN_TOTAL" ]; then
  t70_pass "TC-02 guard が先頭 12 行以内にある (走査 ${_t70_total} 件)"
else
  t70_fail "TC-02 guard 位置が遅い:${_t70_late:- なし} (走査 ${_t70_total} 件 / floor ${_T70_MIN_TOTAL})"
fi

# === TC-03 polyglot が Python 側を壊していない ===
_t70_broken=''
while IFS= read -r _t70_f; do
  [ -n "$_t70_f" ] || continue
  python3 -c 'import sys; compile(open(sys.argv[1], encoding="utf-8").read(), sys.argv[1], "exec")' "$_t70_f" >/dev/null 2>&1 || _t70_broken="$_t70_broken ${_t70_f#"$_T70_ROOT"/}"
done <"$_T70_LIST"
# AC-4: 同上（0 回転でも `_t70_broken` は空のまま）
if [ -z "$_t70_broken" ] && [ "$_t70_total" -ge "$_T70_MIN_TOTAL" ]; then
  t70_pass "TC-03 走査対象すべてが python3 で compile 可能 (走査 ${_t70_total} 件)"
else
  t70_fail "TC-03 compile 失敗:${_t70_broken:- なし} (走査 ${_t70_total} 件 / floor ${_T70_MIN_TOTAL})"
fi

# === TC-04 / TC-05 実ファイルを sh で起動しても副作用が出ない ===
# 安全順序（#1178 AC-2）: 実走ゲートは TC-01（構造）AND TC-02（位置）AND
# 母数 floor AND 空 glob なし の **連言**。guard 不在のまま実走すると本テスト
# 自身が repo を書き換える（#1169 の再発を検査器が引き起こす）ため、
# 「marker 文字列があった」程度の弱い述語でここを開けない。
if [ -z "$_t70_missing" ] && [ -z "$_t70_late" ] && [ -z "$_t70_emptydir" ] \
   && [ "$_t70_total" -ge "$_T70_MIN_TOTAL" ]; then
  # MN-1: `git status --porcelain` は ignored を出さないため `__pycache__` だけが
  # 生成される種類の副作用を構造的に見逃す。`--ignored=matching` で拾う。
  _t70_before="$(cd "$_T70_ROOT" && git status --porcelain --ignored=matching 2>/dev/null || printf 'GIT-UNAVAILABLE')"
  _t70_badrc=''
  _t70_nomsg=''
  _t70_outf="$_T70_TMP/run.out"
  while IFS= read -r _t70_f; do
    [ -n "$_t70_f" ] || continue
    _t70_rel="${_t70_f#"$_T70_ROOT"/}"
    _t70_rc=0
    _t70_run_sh "$_T70_ROOT" "$_t70_rel" "$_T70_SH_TIMEOUT_SEC" "$_t70_outf" || _t70_rc=$?
    # rc=124 は timeout（GNU coreutils）= ハング。FAIL として可視化する
    [ "$_t70_rc" -eq 2 ] || _t70_badrc="$_t70_badrc ${_t70_rel}:rc=$_t70_rc"
    grep -qF "$_T70_DIAG" "$_t70_outf" || _t70_nomsg="$_t70_nomsg ${_t70_rel}"
  done <"$_T70_LIST"
  _t70_after="$(cd "$_T70_ROOT" && git status --porcelain --ignored=matching 2>/dev/null || printf 'GIT-UNAVAILABLE')"
  if [ -z "$_t70_badrc" ] && [ -z "$_t70_nomsg" ]; then
    t70_pass "TC-04 走査対象 ${_t70_total} 件すべてが sh 起動で exit 2 + guard 固有の診断を出す"
  else
    t70_fail "TC-04 rc 不一致:${_t70_badrc:- なし} / guard 診断なし:${_t70_nomsg:- なし}"
  fi
  if [ "$_t70_before" = "$_t70_after" ]; then
    t70_pass "TC-05 sh 起動一巡で repo の git status（ignored 込み）が不変（副作用ゼロ）"
  else
    t70_fail "TC-05 sh 起動で repo が変化した（#1169 再発）"
  fi
else
  t70_fail "TC-04/TC-05 実走中止: guard 構造不備 or marker 位置 or glob 空振り（TC-01/TC-02 を先に直すこと）"
fi

# === TC-06 / TC-07 / TC-08 合成 fixture（変異注入で検出力を実証） ===

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
# 併せて TC-01 の構造述語の負側対照: guard を外した victim は構造判定に落ちること。
# （述語が「常に真」に退行していないことの陰性コントロール）
_t70_struct7=ok
_t70_struct_ok "$_T70_TMP/scripts/victim.py" || _t70_struct7=ng
_t70_fired7=no
if [ -f "$_T70_TMP/FIRED" ]; then
  _t70_fired7=yes
fi
if [ "$_t70_fired7" = yes ] && [ "$_t70_struct7" = ng ]; then
  t70_pass "TC-07 変異注入: guard を外すと sentinel が起動し、構造判定も落ちる（検出力の実証）"
else
  t70_fail "TC-07 変異注入 (rc=$_t70_rc7 / FIRED=$_t70_fired7 / 構造判定=$_t70_struct7) — TC-01/TC-06 が空振りしている"
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
_t70_struct6=ok
_t70_struct_ok "$_T70_TMP/scripts/victim.py" || _t70_struct6=ng
if [ "$_t70_fired6" = no ] && [ "$_t70_rc6" -eq 2 ] \
   && printf '%s' "$_t70_out6" | grep -qF "$_T70_DIAG" && [ "$_t70_struct6" = ok ]; then
  t70_pass "TC-06 guard 付きは sentinel 未起動 / exit 2 / guard 固有の診断 / 構造判定 OK"
else
  t70_fail "TC-06 guard が効いていない (rc=$_t70_rc6, FIRED=$_t70_fired6, 構造判定=$_t70_struct6)"
fi

# --- TC-08 guard 付きでも python3 起動の挙動は不変 ---
_t70_rc8=0
_t70_out8="$(cd "$_T70_TMP" && python3 scripts/victim.py </dev/null 2>&1)" || _t70_rc8=$?
if [ "$_t70_rc8" -eq 0 ] && printf '%s' "$_t70_out8" | grep -q 'python-ran'; then
  t70_pass "TC-08 guard 付きでも python3 起動は従来どおり（polyglot が Python を壊さない）"
else
  t70_fail "TC-08 python3 起動が壊れた (rc=$_t70_rc8): $(printf '%s' "$_t70_out8" | head -3 | tr '\n' ';')"
fi

# --- TC-09 実走の timeout 配線が効いている（#1178 AC-5） ---
# 未ガードで、かつ docstring が「ブロックする外部コマンド」を参照する .py を
# 合成する。sh はこれを読んだ時点でコマンド置換を評価してブロックするため、
# timeout が無ければ TC-04 は FAIL ではなくハングになる。
printf '#!/usr/bin/env python3\n"""\nhang — 詳細は `sleep 30` を参照。\n"""\nprint("python-ran")\n' \
  >"$_T70_TMP/scripts/hang.py"
_t70_rc9=0
_t70_t0=$(date +%s)
_t70_run_sh "$_T70_TMP" "scripts/hang.py" 2 "$_T70_TMP/hang.out" || _t70_rc9=$?
_t70_t1=$(date +%s)
_t70_el9=$((_t70_t1 - _t70_t0))
if [ -z "$_T70_TIMEOUT" ]; then
  # timeout / gtimeout 不在は「検査していない」— 緑にしない
  t70_fail "TC-09 timeout コマンド（timeout / gtimeout）が無く、実走のハング上限を配線できない"
elif [ "$_t70_rc9" -ne 0 ] && [ "$_t70_el9" -lt 60 ]; then
  t70_pass "TC-09 実走 timeout が効く（未ガードのブロック docstring で rc=$_t70_rc9 / ${_t70_el9}s で復帰）"
else
  t70_fail "TC-09 実走 timeout が効いていない (rc=$_t70_rc9 / 経過 ${_t70_el9}s)"
fi

# 後始末は register_cleanup 済み（README 規約 3）。最終行は finalize 単独とし、
# 直前に他コマンドを挟まない（README 実行契約 checklist 3 / #1178 MN-2）。
pg_extra_contract_finalize
