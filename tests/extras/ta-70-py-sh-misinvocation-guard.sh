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
#   TC-01: 走査対象 3 群の全 .py の guard が **正典テンプレートとバイト列で一致**
#          する（#1178 AC-1/AC-a、#1250 R5 で判定モデルを作り直し）
#          — 先頭行（shebang があれば `#!/usr/bin/env python3` 厳密一致）、
#          ガード開始行 `""":"`、閉じ行 `":"""` を厳密照合したうえで、
#          その間の中身を **1 本の正典テンプレートとバイト列比較**する。
#          1 バイトでも違えば無条件 FAIL。
#          **R3 までの「許可形の allowlist を字句器で判定する」モデルは捨てた**。
#          手書きの字句器は sh 引用規則の部分実装であり、実装していない構文
#          （R4 が実測した ANSI-C 引用 / `>&2` 高速パスの語頭捏造）がそのまま
#          回避経路になったため（詳細は `_t70_struct_ok` 直前のコメント）
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
#          到達不能 exit 2 / バックスラッシュ・エスケープ 2 種 /
#          行をまたぐ未終端引用符 / 行継続バックスラッシュ /
#          **ANSI-C 引用** / **`>&2` 直後のコメントによる語頭捏造** の 9 クラスが
#          正典一致判定で落ちる
#          （本 TA に検出力があることの実証。ここが PASS しないと TC-06 は空振り。
#          最後の 2 クラスは R4 が旧字句モデルで SURVIVE を実測したもの）
#   TC-08: 合成 fixture — ガード付きでも python3 起動の挙動は不変
#   TC-09: 実走の timeout 配線が効いている（#1178 AC-5 / #1250 F1。未ガードの .py が
#          ブロックする外部コマンドを参照していても FAIL でありハングでないこと。
#          `rc=124`（timeout 固有）と経過 < ハング秒数 の連言で「timeout が
#          発火したこと」自体を見る。standalone 実行には CI の timeout-minutes が
#          効かないため本体側で持つ）
#
# 残存脅威モデル（#1250 F3 / C-1 / R3 / R5 で限定・打ち切り宣言。完全性は主張しない）:
#   - 守るもの: 走査対象 3 群の .py について、**先頭行からガード閉じ行までの
#     バイト列が正典テンプレートと完全に一致すること**。この領域のバイト列が
#     決まれば `sh` / `bash` がそこで実行する内容も決まる。正典そのものが
#     `sh` 起動で rc=2 / guard 固有の診断 / sentinel 未発火であることは
#     TC-06 が**正典と同一バイトの fixture を実走して**実測する
#   - **過去 3 回、この節に「fail-closed である」「このクラスは塞いだ」と
#     実測を添えずに書き、そのたびに破られた**（#1250 C-1 / R3 / R4）。
#     直近 R4 で破れたのは R3 の「字句モデルは部分実装だが未実装構文は
#     fail-closed で落ちる」という記述で、**ANSI-C 引用は実測で素通りした**
#     （rc=0 = 受理）。この文言は撤回済みで、R5 は allowlist 判定そのものを
#     やめて一致判定に置き換えた。**今後もこの節に、実測を伴わない
#     「塞いだ」「fail-closed」を書かないこと**
#   - 守らないもの: (a) 走査対象 3 群の **外** にある .py。
#     (b) `sh` 以外の誤起動経路（`source` / `.` によるカレントシェルでの読み込み等）。
#     (c) **ガード閉じ行より後ろ**の内容（Python 本体側）。ここは TC-03 の
#     compile 可否しか見ていない。
#     (d) TC-04 は sandbox 実行なので、**docstring が実 repo の実在ファイルを
#     参照して初めて発火する型の副作用**は再現されない（fixture 側の
#     TC-06 / TC-07 が sentinel でその型を担保する）。
#     (e) 副作用先が **sandbox の外**（`/tmp` 等の絶対パス）である副作用。
#     TC-05 は sandbox のファイル構成と実 repo の git status しか見ないため
#     backstop にならない（#1250 C-1 の実測）。ここを守るのは一致判定だけで
#     あり、多層になっていない。
#     (f) **正典テンプレート自体が書き換えられる**攻撃。正典は本ファイル内に
#     あるため、正典と走査対象を同時に書き換えられれば TC-01 は緑になる。
#     ここを守るのは TC-06 の実走（正典の実挙動）と **C-4 Human レビュー**であり、
#     本 TA 単独では守らない
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
# 選定順の是正（#1250 m-3）: 旧実装は `timeout` を無条件で `gtimeout` より
# 優先していた。`timeout` という名の**非 coreutils 実装**が PATH にある環境では
# それが選ばれ、rc が coreutils の 124 にならず TC-09 が常時赤になる。
# **`timeout --version` に GNU coreutils の署名があるものを優先**し、
# 無ければ `gtimeout`、それも無ければ素の `timeout`（rc は後述のとおり
# 124 / 143 の両方を許容する）へ落とす。
_t70_is_coreutils() {
  command -v "$1" >/dev/null 2>&1 || return 1
  "$1" --version 2>/dev/null | head -1 | grep -qi 'coreutils'
}
_T70_TIMEOUT=''
if _t70_is_coreutils timeout; then
  _T70_TIMEOUT='timeout'
elif _t70_is_coreutils gtimeout; then
  _T70_TIMEOUT='gtimeout'
elif command -v gtimeout >/dev/null 2>&1; then
  _T70_TIMEOUT='gtimeout'
elif command -v timeout >/dev/null 2>&1; then
  _T70_TIMEOUT='timeout'
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

# guard の一致判定（#1178 AC-1 / AC-a、#1250 追走の AC-e。#1250 R5 で判定モデルを
# **手書きの字句器から「正典テンプレートとのバイト列完全一致」へ作り直した**）。
#
# 【なぜ手書きの字句器をやめたか / R4 critical・major】
# R3 で導入した「引用状態を持つ文字単位の字句モデル」は、R3 が挙げた 2 クラス
# （行またぎ未終端引用符 / 行継続バックスラッシュ）を確かに落とした。しかし
# **モデルが sh の字句規則の部分実装であるかぎり、実装していない引用種別が
# そのまま回避経路になる**。R4 で実測された 2 クラス:
#
#   (1) ANSI-C 引用（`$` + 単一引用符で開く形。実測 SURVIVE / critical）
#       実シェル（`sh`=bash / `bash` / `ksh` / `zsh`）はこれを **第 3 の引用種別**
#       として開き、内側のバックスラッシュ + 単一引用符をエスケープとして読み、
#       3 個目の単一引用符で閉じる。旧モデルは `$` をリテラル・単一引用符を
#       通常の引用符として読むためパリティがずれ、`single quote left open` にも
#       落ちなかった。実測（2026-08-27）: 旧モデル rc=0（＝受理）／ `sh` 起動は
#       rc=2 + guard 固有の診断を出しつつ攻撃者の `touch` が発火。すなわち
#       TC-01 / TC-03 / TC-04 / TC-05 の**すべてを欺いた**。
#       （`dash` だけはこの構文を持たないため拒否する。旧モデルの意味論は
#       「その構文を持たない dash」と一致していただけで、本 TA が守ると宣言して
#       いる `sh` / `bash` とは一致していなかった）
#   (2) `>&2` 高速パスによる語頭の捏造（実測 SURVIVE / major）
#       旧モデルは allowlist のために `>&2` を**語境界検査なしで 3 文字消費**し
#       内部状態を「語の外」に戻していた。これが**人工的な語頭**を作り、直後の
#       `#` がコメント扱いになって以降の連結コマンドが不可視になる。bash 実測で
#       攻撃者の `touch` が発火。
#
# どちらも「トークンを 1 個足す」是正では閉じない。**sh の字句を手書きで
# 再実装しているかぎり、実装漏れの引用種別・展開種別がそのまま穴になる**という
# クラスそのものが原因だからである。
#
# 【新しいモデル: 正典テンプレート 1 本とのバイト列完全一致】
# ガードブロックは走査対象の全ファイルで同一であるべきもので、可変にする必要が
# 実在しない。**実測（2026-08-27 / 走査 88 件）でも distinct なブロックは 1 種類**、
# shebang も `#!/usr/bin/env python3` か不在の 2 通りだけだった。したがって:
#   - 正典テンプレート（`_T70_CANON`）を本ファイル内に 1 本だけ持つ
#   - 各ファイルのガード開始行〜閉じ行の**中身をバイト列として**取り出し、
#     正典と等値比較する。1 バイトでも違えば無条件 FAIL
#   - 先頭行も固定する（shebang があるなら上記の 1 種類、無いならガード開始行）
# これにより、ガード領域（ファイル先頭から閉じ行まで）の**バイト列が完全に決定**
# する。`sh` がそこで何を実行するかも決定するので、
# **「新しい回避構文」というクラスが原理的に存在しなくなる**
# （回避には正典と異なるバイトが必要で、それは即 FAIL になる）。
#
# 【この判定が保証する範囲 / しない範囲】
# 保証するのは「ガード領域のバイト列が正典と一致すること」だけである。
# **正典テンプレートそのものが安全であること**は本判定の外側であり、TC-06 が
# **正典と同一バイトの fixture を実際に `sh` で起動して** rc=2 / guard 固有の診断 /
# sentinel 未発火 を実測することで担保する（TC-01 と TC-06 の合成で閉じる）。
# 正典を書き換える変更は TC-06 の実走で必ず再評価される。
# 一致判定の外側は依然として守らない（ファイル冒頭の「残存脅威モデル」を参照）。
#
# 実装は python3 に置く（バイト列比較と行分割を正確に行うため）。python3 不在時は
# `_t70_struct_ok` が非ゼロを返して TC-01 が FAIL する ＝ fail-closed
# （TC-03 も python3 必須なので依存は増えない）。
#
# 非機能コスト: R3 の字句器版と同じく走査 1 件ごとに python3 を 1 プロセス起動する。
# 母数が数百件規模に増えたら 1 プロセスで全件を処理する batch 化を検討すること
# （そのときも実装は 1 本に保ち、単体呼び出しと別経路にしないこと — 経路が 2 本に
# なると TC-07 が実証した検出力が TC-01 側で担保されなくなる）。

# --- 正典テンプレート（ガード開始行と閉じ行の「中身」。1 バイトも変えないこと）---
# ここを変更するときは、走査対象の全 .py を同時に同じバイト列へ更新すること。
# 片側だけ変えると TC-01 が全件 FAIL する（＝ drift が必ず可視化される設計）。
_T70_CANON="$_T70_TMP/_t70_canonical_guard.txt"
cat >"$_T70_CANON" <<'PG_T70_CANON_EOF'
# --- PG-SH-GUARD (#1169): sh / bash 誤起動ガード ---
# sh はこのファイルの module docstring を二重引用符文字列として読むため、
# docstring 内のバッククォートがコマンド置換として評価され、repo を書き換える
# 副作用が起きる。python3 以外のインタプリタでは何も評価する前にここで止める。
echo "ERROR: $0 is a Python script; do not run it with sh/bash." >&2
echo "       Use: python3 $0 [args...]" >&2
exit 2
PG_T70_CANON_EOF

# 正典自体の健全性（vacuous PASS 対策）。正典が空 / marker 欠落 / 診断文字列欠落 /
# `exit 2` 欠落 なら、全件一致しても意味が無いので TC-01 を FAIL させる。
_t70_canon_bad=''
[ -s "$_T70_CANON" ] || _t70_canon_bad="$_t70_canon_bad empty"
grep -qF "$_T70_MARKER" "$_T70_CANON" || _t70_canon_bad="$_t70_canon_bad no-marker"
grep -qF "$_T70_DIAG" "$_T70_CANON" || _t70_canon_bad="$_t70_canon_bad no-diag"
grep -qx 'exit 2' "$_T70_CANON" || _t70_canon_bad="$_t70_canon_bad no-exit2"

_T70_GUARD_LINT="$_T70_TMP/_t70_guard_lint.py"
cat >"$_T70_GUARD_LINT" <<'PG_T70_LINT_EOF'
"""ガードブロックのバイト列完全一致検査（#1250 R5）。

手書きの字句モデルをやめ、正典テンプレート 1 本との**バイト列完全一致**だけを
見る。理由は呼び出し元 (tests/extras/ta-70-py-sh-misinvocation-guard.sh) の
コメントを参照。本ファイルは mktemp サンドボックス内にのみ生成され、走査対象
には入らない。

比較はすべて bytes で行う（str へデコードすると、エンコーディング正規化の
差分そのものが新しい回避経路になりうるため）。
"""
import sys

GUARD_OPEN = b'""":"'
GUARD_CLOSE = b'":"""'
SHEBANG = b'#!/usr/bin/env python3'
MAX_LINES = 40


def reject(msg):
    sys.stderr.write('reject: %s\n' % msg)
    return 1


def main(path, canon_path):
    try:
        with open(path, 'rb') as fh:
            raw = fh.read()
        with open(canon_path, 'rb') as fh:
            canon = fh.read()
    except OSError as exc:
        return reject('unreadable: %s' % exc)
    if not canon:
        return reject('canonical template is empty')
    lines = raw.split(b'\n')
    i = 0
    if lines and lines[0].startswith(b'#!'):
        if lines[0] != SHEBANG:
            return reject('shebang must be exactly %r, got %r' % (SHEBANG, lines[0]))
        i = 1
    if i >= len(lines) or lines[i] != GUARD_OPEN:
        return reject('guard opening line %r not found at line %d' % (GUARD_OPEN, i + 1))
    close = None
    for j in range(i + 1, min(len(lines), MAX_LINES)):
        if lines[j] == GUARD_CLOSE:
            close = j
            break
    if close is None:
        return reject('guard closing line %r not found within first %d lines'
                      % (GUARD_CLOSE, MAX_LINES))
    block = b'\n'.join(lines[i + 1:close]) + b'\n'
    if block != canon:
        return reject('guard block differs from the canonical template '
                      '(byte-exact match required; got %d bytes, want %d)'
                      % (len(block), len(canon)))
    return 0


if __name__ == '__main__':
    if len(sys.argv) != 3:
        sys.stderr.write('usage: _t70_guard_lint.py <file> <canonical-block>\n')
        raise SystemExit(2)
    raise SystemExit(main(sys.argv[1], sys.argv[2]))
PG_T70_LINT_EOF

_t70_struct_ok() {
  python3 "$_T70_GUARD_LINT" "$1" "$_T70_CANON" >/dev/null 2>&1
}

# === TC-01 走査対象 3 群の全 .py の guard が正典テンプレートとバイト列一致する ===
_t70_missing=''
while IFS= read -r _t70_f; do
  [ -n "$_t70_f" ] || continue
  _t70_struct_ok "$_t70_f" || _t70_missing="$_t70_missing ${_t70_f#"$_T70_ROOT"/}"
done <"$_T70_LIST"
if [ "$_t70_total" -ge "$_T70_MIN_TOTAL" ] && [ -z "$_t70_missing" ] && [ -z "$_t70_emptydir" ] \
   && [ -z "$_t70_canon_bad" ]; then
  t70_pass "TC-01 走査対象 ${_t70_total} 件すべての guard が正典テンプレートとバイト列一致 (${_T70_DIRS})"
else
  t70_fail "TC-01 正典テンプレート不一致 (走査 ${_t70_total} 件 / 不一致:${_t70_missing:- なし} / 空 glob:${_t70_emptydir:- なし} / 正典異常:${_t70_canon_bad:- なし})"
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
    # rc=124（coreutils）/ 143（TERM 由来）は timeout = ハング。FAIL として可視化する
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
# TC-06 の fixture guard は **正典テンプレートそのもの**から組み立てる（#1250 R5）。
# 手書きの複製を置くと、正典を書き換えたときに fixture だけ旧内容のまま残り、
# 「TC-01 は正典に一致することを見て / TC-06 は別物を実走する」ズレが起きる。
# ここを 1 本にすることで、**TC-01（全件が正典と一致）と TC-06（正典と同一バイトの
# ものが実際に `sh` で無害に exit 2 する）が合成**され、正典の安全性が実測で担保される。
_T70_GUARD="$(printf '""":"\n'; cat "$_T70_CANON"; printf '":"""\n\n__doc__ = """')"

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

# TC-07d/e 対照（#1250 C-1 の恒久固定）: `echo` 行の allowlist を
# **バックスラッシュ・エスケープ**で素通りするクラス。`\"` / `\'` はシェルでは
# リテラルの引用符だが、正規化の `gsub(/"[^"]*"/, ...)` はこれを引用符の**対**
# として消す。この非対称で `;` 連結した任意コマンドを丸ごと「引用済みスパン」
# として消せた（実測 SURVIVE: 9 passed / 0 failed のまま `touch` が発火）。
# 副作用先を sandbox 外の絶対パスにすると TC-05 も backstop にならないため、
# ここで構造判定側に固定する。
# 注意: 副作用行に `$(` / バッククォートを**入れない**。入れるとコマンド置換の
# 禁止則（行全体で `index($0, "$(")`）が先に落とすため、エスケープ非対称という
# 検出したいクラスそのものを測れなくなる（陽性コントロールが空振りする）。
printf '#!/usr/bin/env python3\n""":"\n# --- PG-SH-GUARD (#1169) ---\necho \\" ; touch ./FIRED-esc ; echo \\"\necho "ERROR: $0 is a Python script; do not run it with sh/bash." >&2\nexit 2\n":"""\n\nprint("x")\n' \
  >"$_T70_TMP/scripts/escdq.py"
_t70_struct7d=ok
_t70_struct_ok "$_T70_TMP/scripts/escdq.py" || _t70_struct7d=ng
printf '#!/usr/bin/env python3\n""":"\n# --- PG-SH-GUARD (#1169) ---\necho \\%s ; touch ./FIRED-esc ; echo \\%s\necho "ERROR: $0 is a Python script; do not run it with sh/bash." >&2\nexit 2\n":"""\n\nprint("x")\n' \
  "'" "'" >"$_T70_TMP/scripts/escsq.py"
_t70_struct7e=ok
_t70_struct_ok "$_T70_TMP/scripts/escsq.py" || _t70_struct7e=ng

# TC-07f/g 対照（#1250 R3 の恒久固定 / **行指向述語では原理的に見えなかった 2 クラス**）:
# シェルの字句が **行をまたぐ** ため、「1 行 = 1 コマンド」を前提にした述語が
# 構造的に検出できなかったクラス。両方とも旧述語では STRUCT_OK=ACCEPTED
# （SURVIVE）だった実測がある。
#   (f) 未終端の単一引用符が行をまたぎ、次の行の先頭 `#` が**コメントに見える**。
#       旧述語はその行を `next` し、同じ行の `;` 連結コマンドを丸ごと落とした。
#       このクラスは rc=2 + guard 固有の診断も出すため **TC-04 でも捕まらず**、
#       副作用先を絶対パスにすれば TC-05 も backstop にならない
#       （R2 の `\"` 型は TC-01 だけを欺いた。こちらはより深く欺く悪化形）
#   (g) 行継続バックスラッシュ。sh は 2 行を 1 コマンドとして実行するので guard が
#       無効化される（実測: 出力 `harmless exit 2` のあと sh が Python 本体まで
#       読み進めて syntax error）。旧述語は `exit 2` を独立した行として数えていた
# 注意: 副作用先は **sandbox 内の相対パス**にする（テスト自身が repo 外へ
# 副作用を出さないため。実クラスの危険性は絶対パスでも同じ）。
printf '#!/usr/bin/env python3\n""":"\n# --- PG-SH-GUARD (#1169) ---\necho %sx\n#%s; touch ./FIRED-multiline\necho "ERROR: $0 is a Python script; do not run it with sh/bash." >&2\nexit 2\n":"""\n\nprint("x")\n' \
  "'" "'" >"$_T70_TMP/scripts/mlquote.py"
_t70_struct7f=ok
_t70_struct_ok "$_T70_TMP/scripts/mlquote.py" || _t70_struct7f=ng
printf '#!/usr/bin/env python3\n""":"\n# --- PG-SH-GUARD (#1169) ---\necho harmless \\\nexit 2\n":"""\n\nprint("x")\n' \
  >"$_T70_TMP/scripts/linecont.py"
_t70_struct7g=ok
_t70_struct_ok "$_T70_TMP/scripts/linecont.py" || _t70_struct7g=ng

# TC-07h/i 対照（#1250 R5 の恒久固定 / **手書き字句器では原理的に見えなかった 2 クラス**）:
# R4 が実測した 2 クラス。どちらも R3 の字句モデル（旧実装）では rc=0 = 受理された。
#   (h) ANSI-C 引用（`$` + 単一引用符で開く形）。実シェルは第 3 の引用種別として
#       開き、内側のバックスラッシュ + 単一引用符をエスケープと読む。旧モデルは
#       `$` をリテラル扱いしていたためパリティがずれ、`;` 連結した任意コマンドが
#       素通りした。**rc=2 + guard 固有の診断も出るため TC-04 でも捕まらない**
#       （実測: TC-01/03/04/05 のすべてを欺きつつ `touch` が発火）
#   (i) `>&2` 高速パスによる語頭の捏造。旧モデルは `>&2` を語境界検査なしで
#       3 文字消費して内部状態を「語の外」に戻していたため、直後の `#` が
#       コメントとして扱われ、以降の連結コマンドが不可視になった（bash 実測で発火）
# 注意: 副作用先は **sandbox 内の相対パス**にする（テスト自身が repo 外へ副作用を
# 出さないため。実クラスの危険性は絶対パスでも同じ）。
printf '#!/usr/bin/env python3\n""":"\n# --- PG-SH-GUARD (#1169) ---\necho $%s\\%s; touch ./FIRED-ansic ; echo \\%s\necho "ERROR: $0 is a Python script; do not run it with sh/bash." >&2\nexit 2\n":"""\n\nprint("x")\n' \
  "'" "'" "'" >"$_T70_TMP/scripts/ansicq.py"
_t70_struct7h=ok
_t70_struct_ok "$_T70_TMP/scripts/ansicq.py" || _t70_struct7h=ng
printf '#!/usr/bin/env python3\n""":"\n# --- PG-SH-GUARD (#1169) ---\necho a >&2#; touch ./FIRED-redir\necho "ERROR: $0 is a Python script; do not run it with sh/bash." >&2\nexit 2\n":"""\n\nprint("x")\n' \
  >"$_T70_TMP/scripts/redirhash.py"
_t70_struct7i=ok
_t70_struct_ok "$_T70_TMP/scripts/redirhash.py" || _t70_struct7i=ng

if [ "$_t70_fired7" = yes ] && [ "$_t70_struct7" = ng ] \
   && [ "$_t70_struct7b" = ng ] && [ "$_t70_struct7c" = ng ] \
   && [ "$_t70_struct7d" = ng ] && [ "$_t70_struct7e" = ng ] \
   && [ "$_t70_struct7f" = ng ] && [ "$_t70_struct7g" = ng ] \
   && [ "$_t70_struct7h" = ng ] && [ "$_t70_struct7i" = ng ]; then
  t70_pass "TC-07 変異注入: guard 除去 / ブロック内副作用行 / 到達不能 exit 2 / バックスラッシュ・エスケープ（\\\" と \\'） / 行をまたぐ未終端引用符 / 行継続バックスラッシュ / ANSI-C 引用 / >&2 直後のコメント の 9 クラスすべてが正典一致判定で落ちる（検出力の実証）"
else
  t70_fail "TC-07 変異注入 (rc=$_t70_rc7 / FIRED=$_t70_fired7 / 構造判定=$_t70_struct7 / 副作用行=$_t70_struct7b / 到達不能=$_t70_struct7c / エスケープ\\\"=$_t70_struct7d / エスケープ\\'=$_t70_struct7e / 行またぎ引用符=$_t70_struct7f / 行継続=$_t70_struct7g / ANSI-C 引用=$_t70_struct7h / >&2コメント=$_t70_struct7i) — TC-01/TC-06 が空振りしている"
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
# 是正: **上限で殺されたことを示す rc**（coreutils の 124、または TERM 由来の
# 143 / #1250 m-3）と **経過 < ハング秒数** の連言にする。閾値はハング秒数と
# 同じ変数から導出し、片方だけ変えても壊れないようにする。
# 「rc≠0」ではなく **この 2 値のいずれか**を要求する点が要 — rc≠0 では
# 「30 秒フル待ってから別の理由で落ちた」を区別できず、変異注入が SURVIVE する。
_T70_HANG_SEC=30          # fixture の docstring が呼ぶ sleep の秒数（＝配線が無いときの所要時間）
_T70_T09_LIMIT_SEC=2      # TC-09 で timeout に渡す上限。必ず _T70_HANG_SEC 未満
# 上限超過時の rc（#1250 m-3）。124 は GNU coreutils `timeout` / `gtimeout` 固有だが、
# **TERM を送って子の終了ステータスをそのまま返す実装では 128+15 = 143** になる。
# 124 決め打ちは fail-closed（安全側）ではあるが、そうした実装の環境で
# **偽 FAIL** を出して常時赤になる。両方を許す。
# どちらも「上限で殺された」ことを示す rc であり、通常終了（0 / 2）とは区別できる。
_T70_TIMEOUT_RC=124       # GNU coreutils timeout / gtimeout が上限超過で返す rc
_T70_TIMEOUT_RC_TERM=143  # TERM 由来（128+15）で返す実装のための許容値
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
elif { [ "$_t70_rc9" -eq "$_T70_TIMEOUT_RC" ] || [ "$_t70_rc9" -eq "$_T70_TIMEOUT_RC_TERM" ]; } \
     && [ "$_t70_el9" -lt "$_T70_HANG_SEC" ]; then
  # NOTE: 変数展開の直後に全角文字が続く場合は必ず `${VAR}` 形で囲む。
  # 波括弧なしで書くと全角括弧のバイト列が変数名に食い込み、`set -u` 下
  # （= harness 経由）でのみ unbound variable になる。standalone は `set -u` が
  # 無いため緑のまま通り、フルスイートだけが落ちる（#874 / #990 と同型）。
  # 本コメントに違反例そのものを書かないこと（機械走査を汚すため）。
  t70_pass "TC-09 実走 timeout が発火する（rc=$_t70_rc9 = 上限で殺された rc / ${_t70_el9}s < ハング ${_T70_HANG_SEC}s / timeout=${_T70_TIMEOUT}）"
else
  t70_fail "TC-09 実走 timeout が効いていない (rc=$_t70_rc9 期待 $_T70_TIMEOUT_RC または $_T70_TIMEOUT_RC_TERM / 経過 ${_t70_el9}s 期待 < ${_T70_HANG_SEC}s / timeout=$_T70_TIMEOUT)"
fi

# 後始末は register_cleanup 済み（README 規約 3）。最終行は finalize 単独とし、
# 直前に他コマンドを挟まない（README 実行契約 checklist 3 / #1178 MN-2）。
pg_extra_contract_finalize
