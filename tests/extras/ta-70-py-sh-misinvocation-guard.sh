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
#          なり、そのまま TC-04 で sh 起動されるのを防ぐ（#1250 F3）。
#          判定は **行指向ではなく文字単位の字句状態機械**で行う（#1250 R3）。
#          シェルの字句は行をまたぐため、「1 行 = 1 コマンド」を前提にした述語は
#          未終端引用符 / 行継続を原理的に見られない（詳細は `_t70_struct_ok`
#          直前のコメント）
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
#          **行をまたぐ未終端引用符** / **行継続バックスラッシュ** の 7 クラスが
#          構造判定で落ちる
#          （本 TA に検出力があることの実証。ここが PASS しないと TC-06 は空振り）
#   TC-08: 合成 fixture — ガード付きでも python3 起動の挙動は不変
#   TC-09: 実走の timeout 配線が効いている（#1178 AC-5 / #1250 F1。未ガードの .py が
#          ブロックする外部コマンドを参照していても FAIL でありハングでないこと。
#          `rc=124`（timeout 固有）と経過 < ハング秒数 の連言で「timeout が
#          発火したこと」自体を見る。standalone 実行には CI の timeout-minutes が
#          効かないため本体側で持つ）
#
# 残存脅威モデル（#1250 F3 / C-1 / R3 で限定・打ち切り宣言）:
#   - 守るもの: 走査対象 3 群の .py を `sh` / `bash` で起動したとき、ガード
#     ブロック本体が **既知の許可形（空行 / コメント / 副作用のない
#     echo・printf / top-level の `exit 2`）だけで構成されていること**、
#     およびガードより後ろの行が実行されないこと。判定は **シェルと同じ
#     引用状態を持つ文字単位の字句モデル**で行い、コマンド境界は行ではなく
#     「引用符の外の改行 / `;`」で決める
#   - **「副作用を持ちうる行が一切存在しない」とは主張しない**（#1250 C-1 /
#     R3 でこの文言が 2 度破れた）。R3 で破れたのは **述語の粒度**そのもので、
#     「1 行 = 1 コマンド」という前提がシェルの字句単位と一致していなかった
#     （未終端引用符が行をまたぐ / 行継続バックスラッシュ）。是正は
#     トークン指向への作り直しで、対照は TC-07 の 6・7 クラス目として恒久固定
#     した。**字句モデルは POSIX sh の引用規則の部分実装であり、実装していない
#     構文（`$'...'` / here-document / 算術展開 等）は allowlist かメタ文字
#     reject で落ちる設計（fail-closed）だが、完全性は主張しない**
#   - 守らないもの: (a) 走査対象 3 群の **外** にある .py。(b) `sh` 以外の
#     誤起動経路（`source` / `.` によるカレントシェルでの読み込み等）。
#     (c) guard より前に置かれた shebang 行そのものの改変。
#     (d) TC-04 は sandbox 実行なので、**docstring が実 repo の実在ファイルを
#     参照して初めて発火する型の副作用**は再現されない（fixture 側の
#     TC-06 / TC-07 が sentinel でその型を担保する）。
#     (e) 副作用先が **sandbox の外**（`/tmp` 等の絶対パス）である副作用。
#     TC-05 は sandbox のファイル構成と実 repo の git status しか見ないため
#     backstop にならない（#1250 C-1 の実測）。ここを守るのは構造判定だけで
#     あり、多層になっていない
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

# guard の構造判定（#1178 AC-1 / AC-a、#1250 追走の AC-e。#1250 R3 で **述語の粒度**
# を行指向からトークン指向へ作り直した）。
#
# 【なぜ行指向では原理的に閉じないか / R3 critical】
# 旧述語は awk の 1 レコード = 1 行を「1 コマンド」とみなしていた。しかし
# **シェルの字句は行をまたぐ**。そのため次の 2 クラスが構造的に見えなかった:
#
#   (1) 未終端の引用符が行をまたぐ
#         echo <単一引用符>x           ← 引用符を開いたまま行が終わる
#         <単一引用符閉じ>; <任意コマンド>
#       シェルにとって 2 行目の先頭は**文字列の終端**だが、その行が `#` で
#       始まって見えるため、行指向の述語には**コメント行**に見えて `next` され、
#       直後の `;` 連結が丸ごと不可視になる。この形は rc=2 を返し guard 固有の
#       診断も出すため **TC-04 も欺かれ**、副作用先が絶対パスなら TC-05 も
#       backstop にならない（R2 の `\"` 型は TC-01 だけを欺いた。こちらは悪化形）
#   (2) 行継続バックスラッシュ
#         echo harmless <backslash>
#         exit 2
#       シェルは 2 行を 1 コマンド `echo harmless exit 2` として実行する
#       （＝ guard が完全に無効化され、以降の Python 本体まで sh が読み進む。
#       実測: 出力 `harmless exit 2` + 8 行目 syntax error）。旧述語は行末の
#       孤立 `\` を `gsub(/\\./, "", rest)`（`\` + 任意 1 文字）では消せず、
#       `\` 自体もメタ文字クラスに無かったため `exit 2` を「独立した行」として
#       数え、STRUCT_OK=ACCEPTED になった
#
# どちらも **トークンを 1 個足す是正では閉じない**。「行」という単位が
# シェルの実際の字句単位と一致していないことが原因だからである。
#
# 【新しい粒度: 文字単位の字句状態機械（トークン指向）】
# ガードブロック本体を **1 本の文字列として**走査し、シェルと同じ状態
# （NORMAL / 単一引用符内 / 二重引用符内、およびバックスラッシュ・エスケープ）
# を持たせる。コマンド境界は「行」ではなく **引用符の外にある改行 / `;`** で
# 決める。この粒度なら:
#   - (1) は「引用符を開いたまま行末に到達した」時点で reject できる。
#     `#` 始まりに見える行も**コメントではなく文字列の一部**として正しく
#     読まれるため、続く連結コマンドは独立コマンドとして allowlist 検査に
#     必ずかかる
#   - (2) は「バックスラッシュ + 改行（行継続）で行が終わった」時点で reject
#     できる。行継続を許すと**人間が読む行と shell が実行するコマンドが乖離**
#     し、以後どんな allowlist を足しても同じ乖離が再現するため、
#     ガードブロックでは行継続そのものを禁止する（正規の guard に必要ない）
# すなわち **reject 条件を「行の中身」ではなく「行末での字句状態」に置く**のが
# 要点。これは R2 の `\"` / `\'` 非対称（引用符除去の正規化が壊れるクラス）も
# 同じ機構で吸収する — 正規化で引用を *消す* のをやめ **引用状態として
# *追跡する*** ようにしたため、「対応の非対称」という概念自体が消える。
#
# 【allowlist（トークン列に対して適用）】
#   (a) 空行 / コメント（引用符の外の、語頭にある `#` から行末まで）
#   (b) コマンド先頭語が `echo` / `printf`。引用符の外に現れる
#       `&` `|` `<` `(` `)` と、`>&2` 以外のリダイレクトは reject。
#       コマンド置換（バッククォート / `$(`）は**二重引用符の内側でも評価される**
#       ため NORMAL / 二重引用符内の双方で reject（単一引用符内でも保守的に reject）
#   (c) `exit 2`（引数まで厳密一致）。分岐・ループは先頭語が allowlist 外に
#       なるので自動的に落ち、`exit 2` は常に top-level かつ到達可能である
#   (d) `exit 2` より後ろに実行コマンドを置くことは許さない
#
# 【この判定が保証する範囲 / しない範囲】
# 保証するのは「ガードブロックが上記の字句モデルで allowlist に一致すること」。
# 字句モデルは POSIX sh の引用規則の**部分実装**であり、`$'...'` / here-document /
# 算術展開など**実装していない構文は先頭語 allowlist かメタ文字 reject のどちらか
# で落ちる設計（fail-closed）**にしてあるが、**完全性は主張しない**。
# 新しい回避クラスを見つけたら塞いだうえで TC-07 のクラスを 1 つ増やすこと。
#
# 実装は python3 に置く（awk のレコード指向では上記の粒度を表現できない）。
# python3 不在時は `_t70_struct_ok` が非ゼロを返して TC-01 が FAIL する
# ＝ fail-closed（TC-03 も同じく python3 必須なので依存は増えない）。
#
# 非機能コスト（実測 / 2026-08-27・同一機・standalone）: awk 版 13.7s →
# 本実装 19.1s（+5.4s）。増分は走査 1 件ごとの python3 プロセス起動で、
# 走査母数に比例する。harness の watchdog は 300s なので余裕はあるが、
# **母数が数百件規模に増えたら 1 プロセスで全件を処理する batch 化を検討する
# こと**（そのときも実装は 1 本に保ち、単体呼び出しと別経路にしない —
# 経路が 2 本になると TC-07 が実証した検出力が TC-01 側で担保されなくなる）。
_T70_GUARD_LINT="$_T70_TMP/_t70_guard_lint.py"
cat >"$_T70_GUARD_LINT" <<'PG_T70_LINT_EOF'
"""ガードブロックの字句レベル検査（#1250 R3）。

行指向ではなく文字単位の状態機械で走査する。理由は呼び出し元
(tests/extras/ta-70-py-sh-misinvocation-guard.sh) のコメントを参照。
本ファイルは mktemp サンドボックス内にのみ生成され、走査対象には入らない。
"""
import sys

GUARD_OPEN = '""":"'
GUARD_CLOSE = '":"""'
MARKER = 'PG-SH-GUARD'
MAX_LINES = 40
ALLOWED_HEADS = ('echo', 'printf')
REDIR = '\x00>&2'


def reject(msg):
    sys.stderr.write('reject: %s\n' % msg)
    return 1


def lex(block):
    """ガードブロックを (コマンド = 語のリスト) の列へ落とす。

    reject する条件はすべて「シェルが実際に見る字句状態」で決める:
      - 行末で引用符が開いたまま         -> 行と実行単位が乖離する
      - 行継続（バックスラッシュ + 改行） -> 同上
      - 引用符の外のメタ文字 / コマンド置換
    失敗時は int 1 を返す（成功時は list）。
    """
    src = '\n'.join(block)
    n = len(src)
    i = 0
    state = 'N'          # N=normal, S=single-quoted, D=double-quoted
    cmds = []
    words = []
    cur = None
    while i < n:
        c = src[i]
        if state == 'N':
            if c == '\\':
                if i + 1 >= n:
                    return reject('trailing backslash at end of guard block')
                if src[i + 1] == '\n':
                    return reject('line continuation (backslash-newline): the line '
                                  'a human reads is not the command sh runs')
                cur = (cur or '') + src[i + 1]
                i += 2
                continue
            if c == "'":
                state = 'S'
                cur = cur or ''
                i += 1
                continue
            if c == '"':
                state = 'D'
                cur = cur or ''
                i += 1
                continue
            if c == '#' and cur is None:
                while i < n and src[i] != '\n':
                    i += 1
                continue
            if c == '\n' or c == ';':
                if cur is not None:
                    words.append(cur)
                    cur = None
                if words:
                    cmds.append(words)
                words = []
                i += 1
                continue
            if c in ' \t':
                if cur is not None:
                    words.append(cur)
                    cur = None
                i += 1
                continue
            if c == '`':
                return reject('command substitution (backquote)')
            if c == '$' and i + 1 < n and src[i + 1] == '(':
                return reject('command substitution $( )')
            if c == '>':
                if src[i:i + 3] == '>&2':
                    if cur is not None:
                        words.append(cur)
                        cur = None
                    words.append(REDIR)
                    i += 3
                    continue
                return reject('redirection other than >&2')
            if c in '&|<()':
                return reject('unquoted shell metacharacter %r' % c)
            cur = (cur or '') + c
            i += 1
            continue
        if state == 'S':
            if c == '\n':
                return reject('single quote left open at end of line')
            if c == "'":
                state = 'N'
                i += 1
                continue
            if c == '`':
                return reject('backquote inside single quotes (rejected conservatively)')
            cur += c
            i += 1
            continue
        # state == 'D'
        if c == '\n':
            return reject('double quote left open at end of line')
        if c == '\\':
            if i + 1 >= n:
                return reject('trailing backslash at end of guard block')
            if src[i + 1] == '\n':
                return reject('line continuation inside double quotes')
            cur += src[i + 1]
            i += 2
            continue
        if c == '"':
            state = 'N'
            i += 1
            continue
        if c == '`':
            return reject('command substitution (backquote) inside double quotes')
        if c == '$' and i + 1 < n and src[i + 1] == '(':
            return reject('command substitution $( ) inside double quotes')
        cur += c
        i += 1
    if state != 'N':
        return reject('quote left open at end of guard block')
    if cur is not None:
        words.append(cur)
    if words:
        cmds.append(words)
    return cmds


def validate(cmds):
    if not cmds:
        return reject('guard block contains no executable command')
    seen_exit = False
    for words in cmds:
        if seen_exit:
            return reject('command placed after `exit 2` (unreachable / post-exit code)')
        real = [w for w in words if w != REDIR]
        if not real:
            return reject('command consisting only of a redirection')
        head = real[0]
        if head == 'exit':
            if real != ['exit', '2']:
                return reject('exit must be exactly `exit 2`, got %r' % (real,))
            seen_exit = True
            continue
        if head in ALLOWED_HEADS:
            continue
        return reject('command head not in allowlist: %r' % head)
    if not seen_exit:
        return reject('no top-level `exit 2`')
    return 0


def main(path):
    try:
        with open(path, encoding='utf-8') as fh:
            lines = fh.read().split('\n')
    except (OSError, UnicodeDecodeError) as exc:
        return reject('unreadable: %s' % exc)
    i = 1 if (lines and lines[0].startswith('#!')) else 0
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
    block = lines[i + 1:close]
    if not any(MARKER in line for line in block):
        return reject('marker %r missing from guard block' % MARKER)
    cmds = lex(block)
    if isinstance(cmds, int):
        return cmds
    return validate(cmds)


if __name__ == '__main__':
    if len(sys.argv) != 2:
        sys.stderr.write('usage: _t70_guard_lint.py <file>\n')
        raise SystemExit(2)
    raise SystemExit(main(sys.argv[1]))
PG_T70_LINT_EOF

_t70_struct_ok() {
  python3 "$_T70_GUARD_LINT" "$1" >/dev/null 2>&1
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

if [ "$_t70_fired7" = yes ] && [ "$_t70_struct7" = ng ] \
   && [ "$_t70_struct7b" = ng ] && [ "$_t70_struct7c" = ng ] \
   && [ "$_t70_struct7d" = ng ] && [ "$_t70_struct7e" = ng ] \
   && [ "$_t70_struct7f" = ng ] && [ "$_t70_struct7g" = ng ]; then
  t70_pass "TC-07 変異注入: guard 除去 / ブロック内副作用行 / 到達不能 exit 2 / バックスラッシュ・エスケープ（\\\" と \\'） / 行をまたぐ未終端引用符 / 行継続バックスラッシュ の 7 クラスすべてが構造判定で落ちる（検出力の実証）"
else
  t70_fail "TC-07 変異注入 (rc=$_t70_rc7 / FIRED=$_t70_fired7 / 構造判定=$_t70_struct7 / 副作用行=$_t70_struct7b / 到達不能=$_t70_struct7c / エスケープ\\\"=$_t70_struct7d / エスケープ\\'=$_t70_struct7e / 行またぎ引用符=$_t70_struct7f / 行継続=$_t70_struct7g) — TC-01/TC-06 が空振りしている"
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
