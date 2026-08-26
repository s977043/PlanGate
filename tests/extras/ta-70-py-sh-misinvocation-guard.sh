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
#          ガード開始行 `""":"` であり、閉じ行 `":"""` までのブロック内が
#          許可形（空行 / コメント / 副作用のない echo・printf / top-level の
#          `exit 2`）だけで構成されている」ことを検査する。
#          marker 文字列だけを持つ未ガードファイルや、**到達不能な `exit 2`**・
#          **`exit 2` 到達前に実行される任意の副作用行**を持つファイルが緑に
#          なり、そのまま TC-04 で sh 起動されるのを防ぐ（#1250 F3）
#   TC-02: guard marker がファイル先頭 12 行以内（sh が危険な行を読む前に止まる位置）
#   TC-03: 走査対象の全 .py が python3 で compile できる（polyglot が Python を壊さない）
#   TC-04: 走査対象を **repo 外のサンドボックスへ複製してから** sh で起動すると
#          exit 2 かつ **guard 固有の**診断文字列を出す（#1178 AC-3 / #1250 F3。
#          `python3` の語は本 repo の Usage 定型に頻出するため判別に使わない）
#   TC-05: TC-04 の一連の実行で sandbox のファイル構成も実 repo も変わらない
#          （#1178 MN-1: ignored も含めて比較し `__pycache__` のみの副作用も捕捉。
#          #1250 F7: git 不在で両辺 `GIT-UNAVAILABLE` になる恒真を塞ぐ）
#   TC-06: 合成 fixture 正側 — ガード付きは sentinel を起動せず exit 2
#   TC-07: 合成 fixture 負側（変異注入） — ガード除去 / ブロック内副作用行 /
#          到達不能 exit 2 の 3 クラスが構造判定で落ちる
#          （本 TA に検出力があることの実証。ここが PASS しないと TC-06 は空振り）
#   TC-08: 合成 fixture — ガード付きでも python3 起動の挙動は不変
#   TC-09: 実走の timeout 配線が効いている（#1178 AC-5 / #1250 F1。未ガードの .py が
#          ブロックする外部コマンドを参照していても FAIL でありハングでないこと。
#          `rc=124`（timeout 固有）と経過 < ハング秒数 の連言で「timeout が
#          発火したこと」自体を見る。standalone 実行には CI の timeout-minutes が
#          効かないため本体側で持つ）
#
# 残存脅威モデル（#1250 F3 / 打ち切り宣言）:
#   - 守るもの: 走査対象 3 群の .py を `sh` / `bash` で起動しても、ガードより
#     後ろの行が一切実行されないこと。構造判定は「ガードブロック本体に
#     副作用を持ちうる行が存在しない」ことまで保証する
#   - 守らないもの: (a) 走査対象 3 群の **外** にある .py。(b) `sh` 以外の
#     誤起動経路（`source` / `.` によるカレントシェルでの読み込み等）。
#     (c) guard より前に置かれた shebang 行そのものの改変。
#     (d) TC-04 は sandbox 実行なので、**docstring が実 repo の実在ファイルを
#     参照して初めて発火する型の副作用**は再現されない（fixture 側の
#     TC-06 / TC-07 が sentinel でその型を担保する）
#   - 本検査は多層防御の 1 層であり、最終的な保証は C-4 Human レビューと
#     runtime の allowlist（NO MERGE BY AI）が担う
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
# 出力は「パイプ捕捉」ではなくファイル経由で受け取る。
#
# 根拠の是正（#1250 F4）: 当初この選択の理由を「timeout は直接の子（sh）しか
# 殺さず、孫がパイプを握ったままだと `$(...)` が閉じるまで待ってハングが残る」
# と**実測した挙動であるかのように**書いていたが、これは未実測の推測だった。
# 敵対レビューが PIPE 捕捉 / FILE 捕捉の双方を実測した結果、この fixture では
# **どちらも rc=124 / 約 2s で復帰し差は出ていない**。
# ファイル経由は「孫がパイプを握るケースが理論上ありうる」ことに対する
# 予防的な選択であって、ハング再現を実測した結果ではない。
# 実装は無害なので維持するが、根拠は上記のとおり推測である。
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

# guard の構造判定（#1178 AC-1 / AC-a、#1250 追走の AC-e で到達可能性まで拡張）。
#   - 1 行目が shebang ならそれを読み飛ばす（`scripts/_paths.py` 等の
#     ライブラリモジュールは shebang を持たず guard が 1 行目にある）
#   - その次の行が **厳密に** `""":"`（ガード開始行）であること
#   - 閉じ行 `":"""` までのブロック内に `PG-SH-GUARD` があること
#   - `exit 2` が **top-level（インデントなし）** にあること
#
# 「ブロック内のどこかに `exit 2` がある」だけでは不足である（#1250 敵対レビュー
# F3 で実測）。旧述語はブロック本体の内容を無制約に許したため、
#
#     """:"
#     # --- PG-SH-GUARD (#1169) ---
#     touch /tmp/pwned          ← 任意の副作用行が通る
#     if false; then
#     exit 2                    ← 到達不能な exit 2 でも `^exit 2$` に一致する
#     fi
#     echo "ERROR: ... " >&2
#     exit 2
#     ":"""
#
# のようなファイルが構造判定を通り、TC-04 の実走ゲートが開いた。実測では
# 9 passed / 0 failed のまま `touch` が実際に発火した（副作用先が repo 外なら
# TC-05 でも検出できない）。
#
# したがってブロック本体は **許可形の allowlist** で縛る。許可するのは
#   (a) 空行 / コメント行（`#` 始まり）
#   (b) `echo` / `printf` で始まる出力行。ただし
#       - コマンド置換（`` ` `` / `$(`）は **二重引用符の内側でも評価される**ため
#         行全体で禁止する
#       - 引用済み部分と `>&2` を落とした残りにシェルメタ文字（`; | & < > ( ) ` $`）
#         があるものは禁止（`echo "..." ; rm -rf /` 型の連結を弾く）
#   (c) `exit 2`（top-level・インデントなし）
# のみ。条件分岐・ループ・任意コマンドはいずれも許可形に該当せず落ちる。
# これにより `exit 2` の前に実行されうる行は「副作用のない出力」だけになり、
# かつ分岐が存在しえないので `exit 2` の到達可能性が構造的に保証される。
# `exit 2` より後ろに実行行を置くこと（＝到達不能な後続処理）も許さない。
_t70_struct_ok() {
  awk '
    NR > 40 { bad = 1; exit }
    NR == 1 && /^#!/ { next }
    !started {
      if ($0 != "\"\"\":\"") { bad = 1; exit }
      started = 1; next
    }
    closed { next }
    {
      if ($0 == "\":\"\"\"") { closed = 1; exit }
      if (/PG-SH-GUARD/) { marker = 1 }
      # 空行 / コメント行は常に無害
      if ($0 ~ /^[[:space:]]*$/ || $0 ~ /^#/) { next }
      # ここから先は「実行される行」。exit 2 より後ろには置かせない
      if (hasexit) { bad = 1; exit }
      if ($0 ~ /^exit 2[[:space:]]*$/) { hasexit = 1; next }
      if ($0 ~ /^(echo|printf)[[:space:]]/) {
        # コマンド置換は **二重引用符の内側でも評価される**ので行全体で見る
        if (index($0, "`") > 0 || index($0, "$(") > 0) { bad = 1; exit }
        # 引用符の内側の `;` `&` 等はただの文字。引用済み部分と `>&2`（標準
        # エラーへのリダイレクト）を落としたうえで、残りにシェルメタ文字が
        # 無いことを見る（`echo "..." ; rm -rf /` 型の連結を弾く）
        rest = $0
        gsub(/"[^"]*"/, "", rest)
        gsub(/'"'"'[^'"'"']*'"'"'/, "", rest)
        gsub(/>&2/, "", rest)
        if (rest ~ /[;|&<>()`$]/) { bad = 1; exit }
        next
      }
      bad = 1; exit
    }
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

# === TC-04 / TC-05 sh 起動しても exit 2 + guard 診断、かつ副作用が出ない ===
#
# 実走は **実 repo ではなく repo 外のサンドボックスへ複製してから**行う
# （#1250 敵対レビュー F3）。旧実装は `cd "$_T70_ROOT"` = 実 repo の cwd で
# 88 件を `sh` 起動していた。これは #1169 の実害経路そのもので、構造判定を
# 通り抜けた未ガードファイルが 1 件でも混ざれば **検査器が実 repo を書き換える**。
# 検証したいのは rc と診断文字列だけであり、実 repo の cwd は要らない。
#
# 安全順序（#1178 AC-2）: 実走ゲートは TC-01（構造）AND TC-02（位置）AND
# 母数 floor AND 空 glob なし AND **timeout 配線あり** の連言。
# timeout 連言（#1250 F8）: 素の macOS には `timeout` も `gtimeout` も無い。
# TC-09 は「timeout 不在なら FAIL」を持つが TC-09 は TC-04 より後ろで走るため、
# 不在環境では**上限なしの実走 88 回が先に走ってハングし得た**。ゲート側で閉じる。
_t70_sandbox="$_T70_TMP/sandbox"
if [ -z "$_t70_missing" ] && [ -z "$_t70_late" ] && [ -z "$_t70_emptydir" ] \
   && [ "$_t70_total" -ge "$_T70_MIN_TOTAL" ] && [ -n "$_T70_TIMEOUT" ]; then
  # 走査対象を相対パスのままサンドボックスへ複製する（`$0` に現れる相対パスを
  # 実 repo と同形にするため、ディレクトリ構造ごと再現する）
  rm -rf "$_t70_sandbox"
  while IFS= read -r _t70_f; do
    [ -n "$_t70_f" ] || continue
    _t70_rel="${_t70_f#"$_T70_ROOT"/}"
    mkdir -p "$_t70_sandbox/$(dirname "$_t70_rel")"
    cp "$_t70_f" "$_t70_sandbox/$_t70_rel"
  done <"$_T70_LIST"
  # サンドボックス側の副作用検出用スナップショット（git 管理外なので
  # ファイル一覧そのものを取る。新規生成・削除の双方を拾う）
  _t70_sbefore="$(cd "$_t70_sandbox" && find . | sort)"
  # MN-1: `git status --porcelain` は ignored を出さないため `__pycache__` だけが
  # 生成される種類の副作用を構造的に見逃す。`--ignored=matching` で拾う。
  # 実 repo 側は「本来 1 バイトも触らないはず」の最終防波堤として残す。
  _t70_before="$(cd "$_T70_ROOT" && git status --porcelain --ignored=matching 2>/dev/null || printf 'GIT-UNAVAILABLE')"
  _t70_badrc=''
  _t70_nomsg=''
  _t70_outf="$_T70_TMP/run.out"
  while IFS= read -r _t70_f; do
    [ -n "$_t70_f" ] || continue
    _t70_rel="${_t70_f#"$_T70_ROOT"/}"
    _t70_rc=0
    _t70_run_sh "$_t70_sandbox" "$_t70_rel" "$_T70_SH_TIMEOUT_SEC" "$_t70_outf" || _t70_rc=$?
    # rc=124 は timeout（GNU coreutils / gtimeout）= ハング。FAIL として可視化する
    [ "$_t70_rc" -eq 2 ] || _t70_badrc="$_t70_badrc ${_t70_rel}:rc=$_t70_rc"
    grep -qF "$_T70_DIAG" "$_t70_outf" || _t70_nomsg="$_t70_nomsg ${_t70_rel}"
  done <"$_T70_LIST"
  _t70_after="$(cd "$_T70_ROOT" && git status --porcelain --ignored=matching 2>/dev/null || printf 'GIT-UNAVAILABLE')"
  _t70_safter="$(cd "$_t70_sandbox" && find . | sort)"
  if [ -z "$_t70_badrc" ] && [ -z "$_t70_nomsg" ]; then
    t70_pass "TC-04 走査対象 ${_t70_total} 件すべてが sh 起動（隔離 sandbox）で exit 2 + guard 固有の診断を出す"
  else
    t70_fail "TC-04 rc 不一致:${_t70_badrc:- なし} / guard 診断なし:${_t70_nomsg:- なし}"
  fi
  # #1250 F7: git 不在環境では before / after が両辺 `GIT-UNAVAILABLE` で一致し
  # 恒真になる（＝「検査していない」を PASS と書く）。非 GIT-UNAVAILABLE を連言に置く。
  if [ "$_t70_before" != "GIT-UNAVAILABLE" ] && [ "$_t70_before" = "$_t70_after" ] \
     && [ "$_t70_sbefore" = "$_t70_safter" ]; then
    t70_pass "TC-05 sh 起動一巡で sandbox のファイル構成も実 repo の git status（ignored 込み）も不変（副作用ゼロ）"
  else
    t70_fail "TC-05 副作用検出 or git 不在 (repo変化=$([ "$_t70_before" = "$_t70_after" ] && echo no || echo yes) / sandbox変化=$([ "$_t70_sbefore" = "$_t70_safter" ] && echo no || echo yes) / git=${_t70_before})"
  fi
else
  t70_fail "TC-04/TC-05 実走中止: guard 構造不備 or marker 位置 or glob 空振り or timeout 不在（TC-01/TC-02/TC-09 を先に直すこと / timeout=${_T70_TIMEOUT:- なし}）"
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

# TC-07b 対照（#1250 F3 の恒久固定）: 「ガードブロック内のどこかに exit 2 がある」
# だけを見る述語へ退行したら落ちること。以下の 2 クラスを固定する:
#   (a) ブロック内に任意の副作用行がある（exit 2 到達前に実行されてしまう）
#   (b) exit 2 が到達不能な分岐の中にしかない
# どちらも旧述語では struct_ok が通り、TC-04 の実走ゲートが開いていた。
printf '#!/usr/bin/env python3\n""":"\n# --- PG-SH-GUARD (#1169) ---\ntouch "$(dirname "$0")/../FIRED"\necho "ERROR: $0 is a Python script; do not run it with sh/bash." >&2\nexit 2\n":"""\n\nprint("x")\n' \
  >"$_T70_TMP/scripts/sideeffect.py"
_t70_struct7b=ok
_t70_struct_ok "$_T70_TMP/scripts/sideeffect.py" || _t70_struct7b=ng
printf '#!/usr/bin/env python3\n""":"\n# --- PG-SH-GUARD (#1169) ---\nif false; then\nexit 2\nfi\necho "ERROR: $0 is a Python script; do not run it with sh/bash." >&2\nexit 2\n":"""\n\nprint("x")\n' \
  >"$_T70_TMP/scripts/unreachable.py"
_t70_struct7c=ok
_t70_struct_ok "$_T70_TMP/scripts/unreachable.py" || _t70_struct7c=ng

if [ "$_t70_fired7" = yes ] && [ "$_t70_struct7" = ng ] \
   && [ "$_t70_struct7b" = ng ] && [ "$_t70_struct7c" = ng ]; then
  t70_pass "TC-07 変異注入: guard 除去 / ブロック内副作用行 / 到達不能 exit 2 の 3 クラスすべてが構造判定で落ちる（検出力の実証）"
else
  t70_fail "TC-07 変異注入 (rc=$_t70_rc7 / FIRED=$_t70_fired7 / 構造判定=$_t70_struct7 / 副作用行=$_t70_struct7b / 到達不能=$_t70_struct7c) — TC-01/TC-06 が空振りしている"
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

# --- TC-09 実走の timeout 配線が効いている（#1178 AC-5 / #1250 F1 で是正） ---
# 未ガードで、かつ docstring が「ブロックする外部コマンド」を参照する .py を
# 合成する。sh はこれを読んだ時点でコマンド置換を評価してブロックするため、
# timeout が無ければ TC-04 は FAIL ではなくハングになる。
#
# 旧述語は `rc != 0 かつ 経過 < 60s` だった。fixture の sleep は 30s なので、
# **timeout 配線を丸ごと外しても 30 秒フル待って rc≠0 で戻り 30 < 60 で PASS** した
# （敵対レビューが変異注入で SURVIVE を実測 / 9 passed 0 failed）。
# これは「timeout が発火したこと」を一切見ていない。
# 是正: **rc=124（timeout / gtimeout が上限で殺した固有の rc）** と
# **経過 < ハング秒数** の連言にする。閾値はハング秒数と同じ変数から導出し、
# 片方だけ変えても壊れないようにする。
_T70_HANG_SEC=30          # fixture の docstring が呼ぶ sleep の秒数（＝配線が無いときの所要時間）
_T70_T09_LIMIT_SEC=2      # TC-09 で timeout に渡す上限。必ず _T70_HANG_SEC 未満
_T70_TIMEOUT_RC=124       # GNU coreutils timeout / gtimeout が上限超過で返す rc
printf '#!/usr/bin/env python3\n"""\nhang — 詳細は `sleep %s` を参照。\n"""\nprint("python-ran")\n' \
  "$_T70_HANG_SEC" >"$_T70_TMP/scripts/hang.py"
_t70_rc9=0
_t70_t0=$(date +%s)
_t70_run_sh "$_T70_TMP" "scripts/hang.py" "$_T70_T09_LIMIT_SEC" "$_T70_TMP/hang.out" || _t70_rc9=$?
_t70_t1=$(date +%s)
_t70_el9=$((_t70_t1 - _t70_t0))
if [ -z "$_T70_TIMEOUT" ]; then
  # timeout / gtimeout 不在は「検査していない」— 緑にしない
  t70_fail "TC-09 timeout コマンド（timeout / gtimeout）が無く、実走のハング上限を配線できない"
elif [ "$_T70_T09_LIMIT_SEC" -ge "$_T70_HANG_SEC" ]; then
  # 上限がハング秒数以上だと timeout は原理的に発火せず、以下の判定が無意味になる
  t70_fail "TC-09 fixture 設定不正: 上限 ${_T70_T09_LIMIT_SEC}s >= ハング ${_T70_HANG_SEC}s（timeout が発火し得ない）"
elif [ "$_t70_rc9" -eq "$_T70_TIMEOUT_RC" ] && [ "$_t70_el9" -lt "$_T70_HANG_SEC" ]; then
  t70_pass "TC-09 実走 timeout が発火する（rc=$_t70_rc9 = timeout 固有 / ${_t70_el9}s < ハング ${_T70_HANG_SEC}s）"
else
  t70_fail "TC-09 実走 timeout が効いていない (rc=$_t70_rc9 期待 $_T70_TIMEOUT_RC / 経過 ${_t70_el9}s 期待 < ${_T70_HANG_SEC}s)"
fi

# 後始末は register_cleanup 済み（README 規約 3）。最終行は finalize 単独とし、
# 直前に他コマンドを挟まない（README 実行契約 checklist 3 / #1178 MN-2）。
pg_extra_contract_finalize
