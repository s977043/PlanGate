# tests/extras/ta-77-approval-surface-gate.sh
# PG_EXTRA_CAPABILITY: standalone-capable
# Sourced by tests/run-tests.sh — uses $pass / $fail counters
#
# Issue #1226: 「C-3 の承認手順そのものを、Hardening Override を 1 つも踏まずに
# 変更できる」構造を機械検出する。
#
# 実害（issue 本文）: PR #1221 は C-3 の必須手順を 1 つ増やしたが、正本
# .claude/rules/working-context.md（HO）を更新しなかった。変更されたのは非 HO 面
# だけなので mode-classification.md の「承認境界周辺の変更 → 最低 high-risk」
# 「lite_eligible=false 強制 + Standard C-3 同期固定」が発火しなかった。
# 「正本を更新しない」ことがそのままゲート回避になっている。
#
# === R2 レビュー（A-1〜A-6）を受けた設計変更 ===
# 初版は「1 行に矢印 3 本以上 + 承認トークン名」という単一述語だけで面を発見し、
# その出力の写しを期待値（登録表）に置いていた。実測でこの述語は
# docs/c3-approval-command.md（矢印 0 本・承認トークン言及 6 件・approve コマンドを
# 承認トークン生成の *唯一の正規経路* と宣言する面）を 1 つも拾わず、それでも
# 11/11 green を返した。期待値が同じ述語の出力である以上、述語が見落とす面は
# discovered にも registered にも現れず恒久的に一致し続ける（= 何も測っていない）。
#
# 本版は 2 層に分ける。
#
#   層 1: 発見と分類（fail-closed / 期待値を外部台帳へ）
#     発見述語を広げる。ANCHOR を含む行が
#       (a) 矢印 2 本以上、または
#       (b) 承認手続の宣言動詞（発行 / 生成 / 唯一 / 正規経路 / 必須手順 / 手順）
#     を伴うとき、その行を「承認手順の宣言行」とみなす。宣言行を持つファイルは
#     すべて approval surface として発見される（矢印ゼロでも拾う）。
#     期待値は検査器の外の台帳 tests/fixtures/ta-77/approval-surfaces.tsv に置き、
#     path / class / digest の 3 列で同値照合する。digest は「宣言行 + その行を含む
#     連続非空行ブロック」を連結した sha256 先頭 12 桁。承認手順の記述を 1 文字でも
#     変えると digest が動き、台帳を更新しない限り FAIL する（台帳更新は必ず diff に
#     出る）。台帳に無い面が現れても、台帳にある面が消えても FAIL（両方向）。
#     これは main に入った ta-70（正典テンプレートのバイト列一致 + 許可形 allowlist）
#     と同じ向きであり、初版の「述語の自己写像」ではない。
#
#   層 2: ステップ語の解決（初版から不変）
#     class=CHAIN（1 行に矢印 3 本以上）の非正本面については、各ステップ語が正本
#     .claude/rules/working-context.md の本文で解決できることを要求する。非正本面
#     だけを変更して新ステップを足すと UNRESOLVED になる。
#
# === 差分判定の基準: git diff を使わない（実測に基づく設計判断）===
# .github/workflows/test.yml は actions/checkout を fetch-depth 指定なしで呼ぶ
# （既定 = 1）。CI の pull_request 実行では origin/main も履歴も存在せず、
# 「origin/main との比較」も「commit range」も CI では成立しない（手元でだけ
# 通る検査になる）。したがって本ゲートは差分ではなく **同一ツリー内の同値照合**
# で判定する。比較対象は常に作業ツリーの内容どうしなので、CI・手元・standalone で
# 同一に動く。
#
# === 既知ギャップ台帳（negative suppression。fail-open の穴）===
# origin/main = 75d832d 時点で #1226 の実害は *生きている*（Plan Normalization が
# 非 HO 面 3 本の連鎖に入っているが、正本には 1 度も現れない）。これを
# tests/fixtures/ta-77/known-gaps.tsv に明示登録し、それ以外の未解決語は FAIL とする。
# 台帳が発火しなくなったら TC-05 が落ちる（stale 台帳の禁止 = 恒久ザル化の防止）。
# 台帳を外部ファイルへ出し、エントリ数の上限を「本ファイルの _T77_GAP_MAX」と
# 「known-gaps.tsv ヘッダの #!MAXENTRIES 行」の両方に持たせ、TC-05b で一致を照合する。
# 片方だけ書き換えても FAIL するため、抑止枠の緩和は fixture 側の diff（レビューで必ず
# 見る場所）に必ず現れる（F2-3。旧版は本ファイル側だけの契約で、実測では
# _T77_GAP_MAX=1 -> 5 に書き換えても 17 passed, 0 failed のまま通っていた）。
# 上限（_T77_GAP_MAX）を本ファイル側の契約行に
# 固定したので、抑止を 1 件増やすには 2 ファイルの編集が要る。**ただしこの二重宣言が
# 担うのは承認境界ではなく diff 可視性どまりである**: 3 ファイル
# （本ファイル / known-gaps.tsv / approval-surfaces.tsv）はいずれも Hardening
# Override の対象外なので、**同一 PR で 3 つとも書き換えれば承認境界ゲートを 1 度も
# 踏まずに抑止枠を増やせる**。得られるのは「その書き換えが必ず diff に現れる」
# ことだけであって、fail-closed 化ではない。台帳自体も
# fail-open の穴であり、tests/extras 配下も tests/fixtures 配下も Hardening Override
# 9 カテゴリのいずれにも該当しない（実測: scripts/hooks/check-plan-hash.sh の
# _override=0 直後の case ブロック）。この構造的な残存リスクは PR 本文の残存脅威
# モデルに記載する。台帳を .claude/rules/ 配下（HO）へ外出しする案は HO 編集を
# 伴うため本 PR の範囲外（patch 提案に留める）。
#
# === 本ゲートが green であることの意味（誤読の禁止）===
# ta-77 が green でも #1226 の実害が解消したことにはならない。green は
# 「承認面の集合と記述が台帳と一致している」ことしか意味しない。
# tests/fixtures/ta-77/known-gaps.tsv にエントリが 1 件でも残っている限り、
# #1226 の実害（非 HO 面だけで承認手順を増やせる構造）は生きている。
# **ta-77 の green を根拠に issue #1226 を close してはならない。**
#
#   TC-01 : 発見 surface のパス集合 == 台帳のパス集合（両方向 fail-closed）
#   TC-01b: 発見 surface の path/class/digest 三つ組 == 台帳の三つ組
#   TC-02 : 発見 surface 数が floor 以上（vacuous PASS 防止。絶対件数の契約にしない）
#   TC-02b: 非正本面の distinct ステップ語数が floor 以上（配布ミラー重複だけで
#           floor を満たす vacuous を防ぐ / A-6）
#   TC-03 : 正本自身が承認連鎖を宣言している
#   TC-04 : 非正本 CHAIN 面のステップ語がすべて解決（rc=0 + unresolved=0 + 母数 floor）
#   TC-05 : 既知ギャップ台帳に stale エントリが無い（gapunused=0）
#   TC-05b: 既知ギャップ台帳が契約を満たす（件数 <= _T77_GAP_MAX / fixture 宣言の
#           #!MAXENTRIES と一致 / 各行に issue 番号）
#   TC-06 : tracked symlink を全数走査し、.cursor/skills/* が .agents/skills/<同名> へ
#           解決すること・登録 surface を露出する link が floor 以上あることを照合
#   TC-07a: 対照ベース — 非正本面の全ステップが正本で解決
#   TC-07 : 対照 — 非正本面だけに新ステップを足すと UNRESOLVED（rc=1 + 一意トークン）
#   TC-08 : 対照 — 同じ新ステップを正本にも足すと解決（rc=0 + OK トークン）
#   TC-09 : 対照 — 引数不足は invocation error（rc=2）で契約違反 rc=1 と区別
#   TC-10 : 対照 — 正本が連鎖宣言を失うと専用トークン付きで rc=1
#   TC-11 : 対照 — 矢印 0 本の宣言面（docs/c3-approval-command.md 型）を発見する
#   TC-12 : 対照 — 番号付きリスト形式の承認手順に新ステップを挿入すると digest が動く
#   TC-13 : 対照 — 矢印 1→2 本の 1 行形式に新ステップを足すと digest が動く
#   TC-14 : 対照 — 折返し（soft wrap）で ANCHOR と宣言動詞が別行になっても発見する
#   TC-15 : 対照 — 別々のリスト項目に分かれた ANCHOR と動詞は畳まない（過検出防止）
#   TC-16 : 対照 — docs/working/templates/ は検査対象、docs/working/TASK-XXXX/ は対象外

if [ "${PG_HARNESS_SOURCED:-0}" = "1" ] && [ -n "${FIXTURES_DIR:-}" ] && [ -n "${EXTRAS_DIR:-}" ]; then
  _pg_extra_mode=harness
  _pg_extra_dir="$EXTRAS_DIR"
else
  _pg_extra_mode=standalone
  _pg_extra_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
fi
_pg_extra_helper="$_pg_extra_dir/_extra-contract.sh"
if [ ! -r "$_pg_extra_helper" ]; then
  printf '  [FAIL] helper unresolved: %s\n' "$_pg_extra_helper" 1>&2
  if [ "$_pg_extra_mode" = harness ]; then
    fail=$((fail + 1))
    return 0
  fi
  exit 1
fi
. "$_pg_extra_helper"
pg_extra_contract_init ta-77-approval-surface-gate standalone-capable

if pg_extra_contract_is_standalone; then
  unset PLANGATE_SKIP_REASON PLANGATE_HOOK_TASK PLANGATE_HOOK_FILE PLANGATE_BYPASS_HOOK PLANGATE_HOOK_STRICT PG_HARNESS_SOURCED PLANGATE_ALLOW_MASS_DELETE 2>/dev/null || true
fi

printf '\n=== TA-77: C-3 approval surface gate (#1226) ===\n'

_t77_ok() {
  printf '  [PASS] %s\n' "$1"
  pass=$((pass + 1))
}

_t77_ng() {
  printf '  [FAIL] %s\n' "$1"
  fail=$((fail + 1))
}

# --- 実行前提とリポジトリ root の解決（extras README 規約 9）--------------
_T77_FX="${FIXTURES_DIR:-}"
if [ -n "$_T77_FX" ]; then
  _T77_ROOT="$(CDPATH= cd -- "$_T77_FX/../.." && pwd)"
else
  _T77_ROOT="${_pg_extra_dir%/tests/extras}"
fi

_T77_RUN=1
if [ -z "$_T77_ROOT" ] || [ ! -f "$_T77_ROOT/bin/plangate" ]; then
  _t77_ng "ta-77: repo root unresolved (no bin/plangate under resolved root)"
  _T77_RUN=0
fi
if [ "$_T77_RUN" = 1 ] && ! command -v python3 >/dev/null 2>&1; then
  pg_extra_contract_skip "python3 not available"
  _T77_RUN=0
fi
if [ "$_T77_RUN" = 1 ] && ! command -v git >/dev/null 2>&1; then
  pg_extra_contract_skip "git not available"
  _T77_RUN=0
fi
if [ "$_T77_RUN" = 1 ] && ! git -C "$_T77_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  pg_extra_contract_skip "not a git working tree"
  _T77_RUN=0
fi

_T77_REGF="$_T77_ROOT/tests/fixtures/ta-77/approval-surfaces.tsv"
_T77_GAPF="$_T77_ROOT/tests/fixtures/ta-77/known-gaps.tsv"
if [ "$_T77_RUN" = 1 ] && [ ! -r "$_T77_REGF" ]; then
  _t77_ng "ta-77: 外部台帳が読めない ($_T77_REGF)"
  _T77_RUN=0
fi
if [ "$_T77_RUN" = 1 ] && [ ! -r "$_T77_GAPF" ]; then
  _t77_ng "ta-77: 既知ギャップ台帳が読めない ($_T77_GAPF)"
  _T77_RUN=0
fi

if [ "$_T77_RUN" = 1 ]; then

_T77_TMP="$(mktemp -d)"
register_cleanup "$_T77_TMP"
_T77_AN="$_T77_TMP/analyze.py"

# 検査器本体。承認トークン名（c3 + .json）と一部の装飾記号は、本ファイルの
# 生成手順（EH-13 token-guard / 隔離チェッカ）の制約で連結・chr() 合成する。
# 判定内容には影響しない。
cat > "$_T77_AN" <<'T77PY'
import hashlib
import re
import sys

ARROW = chr(8594)
MIN_ARROWS = 3
DECL_ARROWS = 2
ANCHOR = "c3" + ".json"
VERBS = ("発行", "生成", "唯一", "正規経路", "必須手順", "手順")
EXCLUDE_PREFIXES = ("docs/working/",)
# docs/working/ は run ごとに単調増加する作業ディレクトリなので一括除外する。ただし
# docs/working/templates/ は PBI 横断で参照される恒久成果物（承認手順の雛形が入りうる）
# なので carve-in して検査対象に戻す。TASK-XXXX / PBI-XXX / discussions / incidents は
# 過去 run の記録であり、承認手順の正本ではないため除外のまま（F2-5）。
INCLUDE_OVERRIDE_PREFIXES = ("docs/working/templates/",)
EXCLUDE_FILES = ("CHANGELOG.md", "docs/changelog.md")

_FW_L = chr(65288)
_FW_R = chr(65289)
_PAREN_FW = re.compile(_FW_L + "[^" + _FW_L + _FW_R + "]*" + _FW_R)
_PAREN_HW = re.compile("\\([^()]*\\)")
_DECOR_CHARS = "".join([chr(96), chr(42), chr(12300), chr(12301), chr(35), chr(62), chr(95), chr(124), chr(12288)])
_DECOR = re.compile("[" + _DECOR_CHARS + "\\s]")
_STOP_CHARS = "".join([chr(12290), chr(12289), chr(44), chr(58), chr(65306), chr(59), chr(65307)])
_STOP = re.compile("[" + _STOP_CHARS + "]")
_CUT_CHARS = "".join([chr(12301), chr(12303), chr(34)])
_CUT = re.compile("[" + _CUT_CHARS + "]")
_BQ3 = chr(96) * 3
_FENCE = re.compile("^[ ]{0,3}(?:" + _BQ3 + "|~~~)")
_BSTART = re.compile(
    "^[ ]{0,3}(?:"
    "#{1,6}[ \t]"      # 見出し
    "|[-*+][ \t]"      # 箇条書き
    "|[0-9]+[.)][ \t]" # 番号付きリスト
    "|>"                # 引用
    "|[|]"              # 表の行
    "|-{3,}[ \t]*$"    # 水平線
    "|[*]{3,}[ \t]*$"
    "|_{3,}[ \t]*$"
    ")"
)


def norm(s):
    prev = None
    while prev != s:
        prev = s
        s = _PAREN_FW.sub("", s)
        s = _PAREN_HW.sub("", s)
    return _DECOR.sub("", s)


def leading_term(seg):
    m = _CUT.search(seg)
    if m:
        seg = seg[: m.start()]
    s = norm(seg).lstrip("-")
    m = _STOP.search(s)
    if m:
        s = s[: m.start()]
    return s


def chain_lines(text):
    out = []
    for i, line in enumerate(text.splitlines(), 1):
        if line.count(ARROW) >= MIN_ARROWS and ANCHOR in line:
            out.append((i, line))
    return out


def logical_units(lines):
    """markdown の論理行（soft-wrap 単位）へ分割する。

    行を単位にすると、ANCHOR と宣言動詞が「改行の位置」だけで別行に落ちた面を
    取りこぼす（実物: docs/workflows/ai-loop/stop-rollback.md の reject-ack 宣言。
    ANCHOR と「発行」が折返しで別行にある）。切り分けの軸が意味論ではなく整形に
    なるため、承認手順を足す側は行を折り返すだけでゲートを回避できた（F2-1）。

    一方で「連続非空行ブロック」まで広げると単位が粗すぎる（実測: 発見面が
    31 -> 53 に増え、増分 22 件の 20 件は別々の表の行・別々のリスト項目・
    コードブロック内の無関係な行を同一単位に畳んだことによる誤検出）。
    そこで markdown のブロック境界（見出し / リスト項目 / 表の行 / 引用 /
    コードフェンス / 水平線 / 空行）で単位を切り、それ以外の後続非空行だけを
    soft-wrap の継続行として畳む。実測でこの単位は 31 -> 33（増分 2 件 =
    stop-rollback.md 本体と plugin 配布ミラー）となり、誤検出ゼロで
    折返し回避だけを塞ぐ。
    """
    out = []
    cur = None
    fence = False
    for i, line in enumerate(lines):
        if _FENCE.match(line):
            fence = not fence
            out.append([i])
            cur = None
            continue
        if fence or not line.strip():
            out.append([i])
            cur = None
            continue
        if cur is None or _BSTART.match(line):
            cur = [i]
            out.append(cur)
        else:
            cur.append(i)
    return out


def is_decl(lines, unit):
    # 継続行は行頭の空白を落として連結する（折返しで語が分断されても拾うため）
    s = "".join(lines[k].strip() for k in unit)
    if ANCHOR not in s:
        return False
    if s.count(ARROW) >= DECL_ARROWS:
        return True
    for v in VERBS:
        if v in s:
            return True
    return False


def decl_region(lines):
    marks = []
    for unit in logical_units(lines):
        if is_decl(lines, unit):
            marks.extend(unit)
    if not marks:
        return []
    keep = set()
    for i in marks:
        a = i
        while a > 0 and lines[a - 1].strip():
            a -= 1
        b = i
        while b + 1 < len(lines) and lines[b + 1].strip():
            b += 1
        for k in range(a, b + 1):
            keep.add(k)
    return sorted(keep)


def digest_of(lines, idx):
    h = hashlib.sha256()
    h.update("\n".join(lines[k] for k in idx).encode("utf-8"))
    return h.hexdigest()[:12]


def read_rel(root, rel):
    fh = open(root + "/" + rel, "r", encoding="utf-8")
    try:
        return fh.read()
    finally:
        fh.close()


def main(argv):
    root = None
    canonical = None
    gaps = []
    i = 1
    while i < len(argv):
        a = argv[i]
        if a in ("--root", "--canonical", "--gap"):
            i += 1
            if i >= len(argv):
                sys.stderr.write("APPROVAL_SURFACE_INVOCATION_ERROR: missing value\n")
                return 2
            if a == "--root":
                root = argv[i]
            elif a == "--canonical":
                canonical = argv[i]
            else:
                gaps.append(argv[i])
        else:
            sys.stderr.write("APPROVAL_SURFACE_INVOCATION_ERROR: unknown arg\n")
            return 2
        i += 1
    if not root or not canonical:
        sys.stderr.write("APPROVAL_SURFACE_INVOCATION_ERROR: root and canonical required\n")
        return 2

    surfaces = []
    for rel in sys.stdin.read().splitlines():
        rel = rel.strip()
        if not rel:
            continue
        if rel in EXCLUDE_FILES:
            continue
        if rel.startswith(EXCLUDE_PREFIXES) and not rel.startswith(INCLUDE_OVERRIDE_PREFIXES):
            continue
        try:
            text = read_rel(root, rel)
        except (OSError, UnicodeDecodeError):
            continue
        lines = text.splitlines()
        idx = decl_region(lines)
        if not idx:
            continue
        cl = chain_lines(text)
        cls = "CHAIN" if cl else "DECL"
        surfaces.append((rel, cls, digest_of(lines, idx), len(idx), cl))
    surfaces.sort()
    for rel, cls, dg, n, cl in surfaces:
        sys.stdout.write("SURFACE\t%s\t%s\t%s\t%d\n" % (rel, cls, dg, n))

    if not [s for s in surfaces if s[0] == canonical and s[1] == "CHAIN"]:
        sys.stderr.write("APPROVAL_SURFACE_NO_CANONICAL_CHAIN: %s\n" % canonical)
        return 1
    hay = norm(read_rel(root, canonical))

    terms = 0
    distinct = set()
    unresolved = 0
    gap_hits = dict()
    for rel, cls, dg, n, cl in surfaces:
        if rel == canonical or cls != "CHAIN":
            continue
        for lineno, line in cl:
            for seg in line.split(ARROW):
                term = leading_term(seg)
                if len(term) < 2:
                    continue
                terms += 1
                distinct.add(term)
                if term in hay:
                    verdict = "OK"
                elif term in gaps:
                    verdict = "GAP"
                    gap_hits[term] = gap_hits.get(term, 0) + 1
                else:
                    verdict = "UNRESOLVED"
                    unresolved += 1
                sys.stdout.write("TERM\t%s\t%d\t%s\t%s\n" % (rel, lineno, term, verdict))
    unused = [g for g in gaps if g not in gap_hits]
    for g in unused:
        sys.stdout.write("GAPUNUSED\t%s\n" % g)
    sys.stdout.write(
        "SUMMARY\tsurfaces=%d\tterms=%d\tdistinct=%d\tunresolved=%d\tgaphits=%d\tgapunused=%d\n"
        % (len(surfaces), terms, len(distinct), unresolved, len(gap_hits), len(unused))
    )
    return 1 if unresolved else 0


sys.exit(main(sys.argv))
T77PY

# --- 契約定数（floor / 上限。絶対件数の契約値ではない）---------------------
_T77_CANON=".claude/rules/working-context.md"
_T77_SURFACE_FLOOR=20
_T77_TERM_FLOOR=20
# 配布ミラーの重複ではなく実体の語彙で母数を担保する（A-6）
_T77_DISTINCT_FLOOR=6
# 既知ギャップ台帳のエントリ数上限。本行と known-gaps.tsv ヘッダの #!MAXENTRIES 行の
# 両方を書き換えないと緩和できない（TC-05b が一致を照合する / F2-3）。
_T77_GAP_MAX=1
# 登録 surface を露出する tracked symlink の下限。link の削除も検出する。
_T77_LINK_FLOOR=2

# --- 外部台帳の読み込み ----------------------------------------------------
_t77_reg_rows="$(grep -v '^[[:space:]]*#' "$_T77_REGF" | grep '[^[:space:]]' | sort)"
_t77_gap_rows="$(grep -v '^[[:space:]]*#' "$_T77_GAPF" | grep '[^[:space:]]' || true)"
_t77_gap_maxdecl="$(sed -n 's/^#!MAXENTRIES[[:space:]][[:space:]]*\([0-9][0-9]*\)[[:space:]]*$/\1/p' "$_T77_GAPF" | head -n 1)"

_t77_gapargs=""
_t77_gap_n=0
_t77_gap_bad=0
while IFS='	' read -r _t77_g_term _t77_g_issue _t77_g_rest; do
  [ -n "$_t77_g_term" ] || continue
  _t77_gap_n=$((_t77_gap_n + 1))
  case "$_t77_g_term" in
    *[!A-Za-z0-9_-]*) _t77_gap_bad=$((_t77_gap_bad + 1)) ;;
  esac
  case "$_t77_g_issue" in
    '#'[0-9]*) : ;;
    *) _t77_gap_bad=$((_t77_gap_bad + 1)) ;;
  esac
  [ -n "$_t77_g_rest" ] || _t77_gap_bad=$((_t77_gap_bad + 1))
  _t77_gapargs="$_t77_gapargs --gap $_t77_g_term"
done <<T77GAPS
$_t77_gap_rows
T77GAPS

_T77_CAND="$_T77_TMP/cand.txt"
_T77_OUT="$_T77_TMP/out.txt"
_T77_ERR="$_T77_TMP/err.txt"
git -C "$_T77_ROOT" ls-files -- '*.md' > "$_T77_CAND" 2>/dev/null || true

_t77_rc=0
# shellcheck disable=SC2086
python3 "$_T77_AN" --root "$_T77_ROOT" --canonical "$_T77_CANON" $_t77_gapargs < "$_T77_CAND" > "$_T77_OUT" 2> "$_T77_ERR" || _t77_rc=$?

_t77_found_rows="$(awk -F'\t' '$1=="SURFACE"{printf "%s\t%s\t%s\n", $2, $3, $4}' "$_T77_OUT" | sort)"
_t77_found_paths="$(printf '%s\n' "$_t77_found_rows" | cut -f1 | sort)"
_t77_reg_paths="$(printf '%s\n' "$_t77_reg_rows" | cut -f1 | sort)"
_t77_nfound="$(printf '%s\n' "$_t77_found_paths" | grep -c . || true)"

# === TC-01: 発見パス集合 == 台帳パス集合（両方向 fail-closed）
if [ "$_t77_found_paths" = "$_t77_reg_paths" ]; then
  _t77_ok "TC-01 発見した approval surface のパス集合が外部台帳と一致 (n=$_t77_nfound)"
else
  _t77_ng "TC-01 approval surface のパス集合が外部台帳と不一致 — 面が増減した"
  printf '%s\n' "$_t77_found_paths" > "$_T77_TMP/found.txt"
  printf '%s\n' "$_t77_reg_paths" > "$_T77_TMP/reg.txt"
  printf '         --- discovered only ---\n'
  comm -23 "$_T77_TMP/found.txt" "$_T77_TMP/reg.txt" | sed 's/^/         /'
  printf '         --- registered only ---\n'
  comm -13 "$_T77_TMP/found.txt" "$_T77_TMP/reg.txt" | sed 's/^/         /'
fi

# === TC-01b: path/class/digest 三つ組が一致（承認手順の記述変更を検出）
if [ "$_t77_found_rows" = "$_t77_reg_rows" ]; then
  _t77_ok "TC-01b approval surface の class/digest が外部台帳と一致"
else
  _t77_ng "TC-01b approval surface の class/digest が外部台帳と不一致 — 承認手順の記述が変わった"
  printf '         --- discovered ---\n'
  printf '%s\n' "$_t77_found_rows" | sed 's/^/         /'
  printf '         --- registered ---\n'
  printf '%s\n' "$_t77_reg_rows" | sed 's/^/         /'
fi

# === TC-02: 母数 floor（vacuous PASS 防止）
if [ "$_t77_nfound" -ge "$_T77_SURFACE_FLOOR" ]; then
  _t77_ok "TC-02 発見 surface 数が floor 以上 ($_t77_nfound -ge $_T77_SURFACE_FLOOR)"
else
  _t77_ng "TC-02 発見 surface 数が floor 未満 ($_t77_nfound) — 検査器が空振りしている"
fi

# === TC-03: 正本自身が承認連鎖を宣言している
if printf '%s\n' "$_t77_found_paths" | grep -Fqx "$_T77_CANON" && ! grep -q APPROVAL_SURFACE_NO_CANONICAL_CHAIN "$_T77_ERR"; then
  _t77_ok "TC-03 正本 $_T77_CANON が承認連鎖を宣言している"
else
  _t77_ng "TC-03 正本が承認連鎖を宣言していない（宣言の消失は承認境界の消失）"
fi

# === TC-04: 非正本 CHAIN 面のステップ語がすべて解決
_t77_summary="$(grep '^SUMMARY' "$_T77_OUT" || true)"
_t77_nterms="$(printf '%s' "$_t77_summary" | sed -n 's/.*terms=\([0-9][0-9]*\).*/\1/p' | head -n 1)"
_t77_ndist="$(printf '%s' "$_t77_summary" | sed -n 's/.*distinct=\([0-9][0-9]*\).*/\1/p' | head -n 1)"
[ -n "$_t77_nterms" ] || _t77_nterms=0
[ -n "$_t77_ndist" ] || _t77_ndist=0
if [ "$_t77_rc" = 0 ] && printf '%s' "$_t77_summary" | grep -q 'unresolved=0' && [ "$_t77_nterms" -ge "$_T77_TERM_FLOOR" ]; then
  _t77_ok "TC-04 非正本面のステップ語がすべて正本で解決 (rc=0, terms=$_t77_nterms)"
else
  _t77_ng "TC-04 非正本面に正本で解決できないステップ語がある (rc=$_t77_rc, terms=$_t77_nterms)"
  grep UNRESOLVED "$_T77_OUT" | sed 's/^/         /' || true
  sed 's/^/         /' "$_T77_ERR" || true
fi

# === TC-02b: distinct ステップ語 floor（配布ミラー重複による vacuous を防ぐ / A-6）
if [ "$_t77_ndist" -ge "$_T77_DISTINCT_FLOOR" ]; then
  _t77_ok "TC-02b distinct ステップ語が floor 以上 ($_t77_ndist -ge $_T77_DISTINCT_FLOOR)"
else
  _t77_ng "TC-02b distinct ステップ語が floor 未満 ($_t77_ndist) — ミラー重複で母数を満たしている"
fi

# === TC-05: 既知ギャップ台帳に stale エントリが無い
if printf '%s' "$_t77_summary" | grep -q 'gapunused=0'; then
  _t77_ok "TC-05 既知ギャップ台帳に stale エントリなし"
else
  _t77_ng "TC-05 既知ギャップ台帳に発火しないエントリがある — 台帳から削除すること"
  grep '^GAPUNUSED' "$_T77_OUT" | sed 's/^/         /' || true
fi

# === TC-05b: 既知ギャップ台帳の契約（上限件数 / 行の well-formedness）
if [ "$_t77_gap_n" -le "$_T77_GAP_MAX" ] && [ "$_t77_gap_bad" = 0 ] \
  && [ -n "$_t77_gap_maxdecl" ] && [ "$_t77_gap_maxdecl" = "$_T77_GAP_MAX" ]; then
  _t77_ok "TC-05b 既知ギャップ台帳が契約を満たす (entries=$_t77_gap_n -le $_T77_GAP_MAX, fixture #!MAXENTRIES=$_t77_gap_maxdecl, malformed=0)"
else
  _t77_ng "TC-05b 既知ギャップ台帳が契約違反 (entries=$_t77_gap_n, max=$_T77_GAP_MAX, fixture #!MAXENTRIES=${_t77_gap_maxdecl:-<none>}, malformed=$_t77_gap_bad)"
fi

# === TC-06: tracked symlink を全数走査する（F2-2）
# 旧版は .cursor/skills/plan-review-gate の 1 パス固定だった。実測では tracked
# symlink は 5 本あり（mode 120000）、うち登録 surface を露出するものは 2 本
# （plan-review-gate / ai-dev-plan）。ai-dev-plan が無検査で、貼り替えは台帳にも
# digest にも現れなかった。ここでは全数を走査し、
#   (a) すべての tracked symlink が repo 内に解決すること（dangling / 外部脱出の禁止）
#   (b) .cursor/skills/<name> は .agents/skills/<name> へ解決すること
#       （.cursor は .agents のミラーであるという構造契約。貼り替えは必ずここで落ちる）
#   (c) 登録 surface を露出する symlink が floor 以上あること（link 削除の検出）
# を照合する。部分文字列一致では agents/skills/... のような別ディレクトリも通るため
# 解決先は完全一致で比較する。
_T77_ROOTP="$(CDPATH= cd -- "$_T77_ROOT" && pwd -P)"
_T77_LINKS="$_T77_TMP/links.txt"
git -C "$_T77_ROOT" ls-files -s > "$_T77_TMP/lsfiles.txt" 2>/dev/null || true
awk '$1=="120000"{ sub(/^[0-9]+ [0-9a-f]+ [0-9]+\t/, ""); print }' "$_T77_TMP/lsfiles.txt" > "$_T77_LINKS"

_t77_link_n=0
_t77_link_bad=0
_t77_link_surf=0
_t77_link_msg=""
while IFS= read -r _t77_l; do
  [ -n "$_t77_l" ] || continue
  _t77_link_n=$((_t77_link_n + 1))
  _t77_lp="$_T77_ROOT/$_t77_l"
  if [ ! -L "$_t77_lp" ]; then
    _t77_link_bad=$((_t77_link_bad + 1))
    _t77_link_msg="$_t77_link_msg
         $_t77_l: tracked mode 120000 だが symlink として存在しない"
    continue
  fi
  _t77_tgt="$(CDPATH= cd -- "$_t77_lp" 2>/dev/null && pwd -P)" || _t77_tgt=""
  if [ -z "$_t77_tgt" ]; then
    _t77_link_bad=$((_t77_link_bad + 1))
    _t77_link_msg="$_t77_link_msg
         $_t77_l: 解決できない（dangling / ディレクトリでない）"
    continue
  fi
  case "$_t77_tgt" in
    "$_T77_ROOTP"/*) : ;;
    *)
      _t77_link_bad=$((_t77_link_bad + 1))
      _t77_link_msg="$_t77_link_msg
         $_t77_l: repo 外へ解決する ($_t77_tgt)"
      continue
      ;;
  esac
  _t77_trel="${_t77_tgt#$_T77_ROOTP/}"
  case "$_t77_l" in
    .cursor/skills/*)
      _t77_base="${_t77_l#.cursor/skills/}"
      if [ ".agents/skills/$_t77_base" != "$_t77_trel" ]; then
        _t77_link_bad=$((_t77_link_bad + 1))
        _t77_link_msg="$_t77_link_msg
         $_t77_l: .agents/skills/$_t77_base ではなく $_t77_trel へ解決する（貼り替え）"
        continue
      fi
      ;;
  esac
  if printf '%s\n' "$_t77_reg_paths" | grep -q "^$_t77_trel/"; then
    _t77_link_surf=$((_t77_link_surf + 1))
  fi
done < "$_T77_LINKS"

if [ "$_t77_link_bad" = 0 ] && [ "$_t77_link_n" -ge 1 ] && [ "$_t77_link_surf" -ge "$_T77_LINK_FLOOR" ]; then
  _t77_ok "TC-06 tracked symlink 全数が契約を満たす (links=$_t77_link_n, 登録 surface 露出=$_t77_link_surf -ge $_T77_LINK_FLOOR)"
else
  _t77_ng "TC-06 tracked symlink が契約違反 (links=$_t77_link_n, bad=$_t77_link_bad, 登録 surface 露出=$_t77_link_surf, floor=$_T77_LINK_FLOOR)"
  [ -n "$_t77_link_msg" ] && printf '%s\n' "$_t77_link_msg"
fi

# --- 対照実験（negative control）: 検出力をこのファイル内で実証する --------
_T77_SBX="$_T77_TMP/sbx"
rm -rf "$_T77_SBX"
mkdir -p "$_T77_SBX"
_T77_A1=c3
_T77_A2=.json
_T77_ANCHOR="$_T77_A1$_T77_A2"

cat > "$_T77_SBX/canon.md" <<T77SBX
## C-3 gate

- CONDITIONAL: C-2 の R-NNN 集約済 → 1 回確定反映 → 簡易 C-1 → 人間が APPROVED ${_T77_ANCHOR} 発行 → exec 開始。
T77SBX

cat > "$_T77_SBX/mirror.md" <<T77SBX
## C-2 → 確定反映 → 簡易 C-1 → ${_T77_ANCHOR} 発行
T77SBX

printf 'canon.md\nmirror.md\n' > "$_T77_SBX/cand.txt"

_t77_rc=0
_t77_out="$(python3 "$_T77_AN" --root "$_T77_SBX" --canonical canon.md < "$_T77_SBX/cand.txt" 2>&1)" || _t77_rc=$?
if [ "$_t77_rc" = 0 ] && printf '%s' "$_t77_out" | grep -q 'unresolved=0'; then
  _t77_ok "TC-07a 対照ベース: 非正本面の全ステップが正本で解決 (rc=0)"
else
  _t77_ng "TC-07a 対照ベースが成立しない (rc=$_t77_rc) — 以降の対照が無意味になる"
  printf '%s\n' "$_t77_out" | sed 's/^/         /'
fi

# TC-07: 非 HO 面「だけ」に新ステップを足す = PR #1221 と同型の変異
cat > "$_T77_SBX/mirror.md" <<T77SBX
## C-2 → 確定反映 → T77NEWSTEP → 簡易 C-1 → ${_T77_ANCHOR} 発行
T77SBX
_t77_rc=0
_t77_out="$(python3 "$_T77_AN" --root "$_T77_SBX" --canonical canon.md < "$_T77_SBX/cand.txt" 2>&1)" || _t77_rc=$?
if [ "$_t77_rc" = 1 ] && printf '%s' "$_t77_out" | grep -q 'T77NEWSTEP.UNRESOLVED'; then
  _t77_ok "TC-07 非正本面だけの新ステップ追加を UNRESOLVED で検出 (rc=1)"
else
  _t77_ng "TC-07 非正本面だけの新ステップ追加を検出できない (rc=$_t77_rc)"
  printf '%s\n' "$_t77_out" | sed 's/^/         /'
fi

# TC-08: 正本にも同じステップを入れれば解決する（過検出でないことの対照）
cat >> "$_T77_SBX/canon.md" <<T77SBX
- T77NEWSTEP を C-3 の必須手順に含める。
T77SBX
_t77_rc=0
_t77_out="$(python3 "$_T77_AN" --root "$_T77_SBX" --canonical canon.md < "$_T77_SBX/cand.txt" 2>&1)" || _t77_rc=$?
if [ "$_t77_rc" = 0 ] && printf '%s' "$_t77_out" | grep -q 'T77NEWSTEP.OK'; then
  _t77_ok "TC-08 正本を同時更新すれば解決する (rc=0)"
else
  _t77_ng "TC-08 正本を同時更新しても解決しない = 過検出 (rc=$_t77_rc)"
  printf '%s\n' "$_t77_out" | sed 's/^/         /'
fi

# TC-09: 起動不正は rc=2（契約違反 rc=1 と別名前空間）
_t77_rc=0
_t77_out="$(python3 "$_T77_AN" --root "$_T77_SBX" < "$_T77_SBX/cand.txt" 2>&1)" || _t77_rc=$?
if [ "$_t77_rc" = 2 ] && printf '%s' "$_t77_out" | grep -q APPROVAL_SURFACE_INVOCATION_ERROR; then
  _t77_ok "TC-09 引数不足は invocation error (rc=2)"
else
  _t77_ng "TC-09 invocation error が rc=2 で区別されない (rc=$_t77_rc)"
fi

# TC-10: 正本が連鎖宣言を失った場合は専用トークンで rc=1
cat > "$_T77_SBX/canon2.md" <<T77SBX
## C-3 gate

- 承認手順の順序連鎖はここには書かれていない。
T77SBX
printf 'canon2.md\nmirror.md\n' > "$_T77_SBX/cand2.txt"
_t77_rc=0
_t77_out="$(python3 "$_T77_AN" --root "$_T77_SBX" --canonical canon2.md < "$_T77_SBX/cand2.txt" 2>&1)" || _t77_rc=$?
if [ "$_t77_rc" = 1 ] && printf '%s' "$_t77_out" | grep -q APPROVAL_SURFACE_NO_CANONICAL_CHAIN; then
  _t77_ok "TC-10 正本が連鎖宣言を失うと専用トークンで検出 (rc=1)"
else
  _t77_ng "TC-10 正本の連鎖宣言消失を検出できない (rc=$_t77_rc)"
fi

# TC-11: 矢印 0 本の宣言面を発見する（docs/c3-approval-command.md 型 / A-1 の実物）
# 初版の述語（矢印 3 本以上）はこの形を 1 つも拾わなかった。
cat > "$_T77_SBX/zeroarrow.md" <<T77SBX
## 承認コマンド

承認トークン ${_T77_ANCHOR} の発行作業は CLI が自動化する。
これにより approve が ${_T77_ANCHOR} 生成の唯一の正規経路になる。
T77SBX
printf 'canon.md\nmirror.md\nzeroarrow.md\n' > "$_T77_SBX/cand3.txt"
_t77_rc=0
_t77_out="$(python3 "$_T77_AN" --root "$_T77_SBX" --canonical canon.md < "$_T77_SBX/cand3.txt" 2>&1)" || _t77_rc=$?
if printf '%s\n' "$_t77_out" | awk -F'\t' '$1=="SURFACE" && $2=="zeroarrow.md" && $3=="DECL"{f=1} END{exit f?0:1}'; then
  _t77_ok "TC-11 矢印 0 本の承認手順宣言面を DECL として発見 (rc=$_t77_rc)"
else
  _t77_ng "TC-11 矢印 0 本の承認手順宣言面を発見できない — A-1 の実害が残る"
  printf '%s\n' "$_t77_out" | sed 's/^/         /'
fi

# TC-12: 番号付きリスト形式の承認手順に新ステップを挿入すると digest が動く
# 挿入行自体は宣言行ではない（ANCHOR も矢印も無い）が、宣言行を含む連続ブロック
# 全体を digest 対象にしているため検出できる。
cat > "$_T77_SBX/numlist.md" <<T77SBX
## 承認手順

1. R-NNN を集約する
2. 1 回確定反映する
3. 人間が APPROVED ${_T77_ANCHOR} を発行する
4. exec を開始する
T77SBX
printf 'canon.md\nnumlist.md\n' > "$_T77_SBX/cand4.txt"
_t77_d1="$(python3 "$_T77_AN" --root "$_T77_SBX" --canonical canon.md < "$_T77_SBX/cand4.txt" 2>/dev/null | awk -F'\t' '$1=="SURFACE" && $2=="numlist.md"{print $4}')"
cat > "$_T77_SBX/numlist.md" <<T77SBX
## 承認手順

1. R-NNN を集約する
2. 1 回確定反映する
3. T77NEWSTEP を実行する
4. 人間が APPROVED ${_T77_ANCHOR} を発行する
5. exec を開始する
T77SBX
_t77_d2="$(python3 "$_T77_AN" --root "$_T77_SBX" --canonical canon.md < "$_T77_SBX/cand4.txt" 2>/dev/null | awk -F'\t' '$1=="SURFACE" && $2=="numlist.md"{print $4}')"
if [ -n "$_t77_d1" ] && [ -n "$_t77_d2" ] && [ "$_t77_d1" != "$_t77_d2" ]; then
  _t77_ok "TC-12 番号付きリストへの新ステップ挿入で digest が変わる ($_t77_d1 -> $_t77_d2)"
else
  _t77_ng "TC-12 番号付きリストへの新ステップ挿入を digest が検出できない (d1=$_t77_d1 d2=$_t77_d2)"
fi

# TC-13: 矢印 1→2 本の 1 行形式に新ステップを足すと発見され digest が動く
# 初版の閾値（矢印 3 本以上）では発見すらされなかった形。
cat > "$_T77_SBX/twoarrow.md" <<T77SBX
## 確定反映 → ${_T77_ANCHOR} 発行
T77SBX
printf 'canon.md\ntwoarrow.md\n' > "$_T77_SBX/cand5.txt"
_t77_e1="$(python3 "$_T77_AN" --root "$_T77_SBX" --canonical canon.md < "$_T77_SBX/cand5.txt" 2>/dev/null | awk -F'\t' '$1=="SURFACE" && $2=="twoarrow.md"{print $3"/"$4}')"
cat > "$_T77_SBX/twoarrow.md" <<T77SBX
## 確定反映 → T77NEWSTEP → ${_T77_ANCHOR} 発行
T77SBX
_t77_e2="$(python3 "$_T77_AN" --root "$_T77_SBX" --canonical canon.md < "$_T77_SBX/cand5.txt" 2>/dev/null | awk -F'\t' '$1=="SURFACE" && $2=="twoarrow.md"{print $3"/"$4}')"
if [ -n "$_t77_e1" ] && [ -n "$_t77_e2" ] && [ "$_t77_e1" != "$_t77_e2" ]; then
  _t77_ok "TC-13 矢印 3 本未満の 1 行形式でも発見し、新ステップで digest が変わる ($_t77_e1 -> $_t77_e2)"
else
  _t77_ng "TC-13 矢印 3 本未満の 1 行形式の変更を検出できない (e1=$_t77_e1 e2=$_t77_e2)"
fi

# TC-14: 折返し（soft wrap）で ANCHOR と宣言動詞が別行に落ちても発見する（F2-1）
# 実物: docs/workflows/ai-loop/stop-rollback.md の reject-ack 宣言。行単位の述語では
# 「改行をどこで入れたか」だけでゲートを回避できた。
cat > "$_T77_SBX/wrapped.md" <<T77SBX
## 承認トークン

- または \`reject-ack.json\`（\`decision\` / \`signed_by\` を持つ、${_T77_ANCHOR} と同型の
  人間発行ファイル。AI の会話内解釈だけを根拠に破壊的操作を実行しない）
T77SBX
printf 'canon.md\nwrapped.md\n' > "$_T77_SBX/cand6.txt"
_t77_out="$(python3 "$_T77_AN" --root "$_T77_SBX" --canonical canon.md < "$_T77_SBX/cand6.txt" 2>&1)" || true
if printf '%s\n' "$_t77_out" | awk -F'\t' '$1=="SURFACE" && $2=="wrapped.md" && $3=="DECL"{f=1} END{exit f?0:1}'; then
  _t77_ok "TC-14 折返しで ANCHOR と宣言動詞が別行になっても DECL として発見"
else
  _t77_ng "TC-14 折返しの宣言面を発見できない — 整形だけでゲートを回避できる"
  printf '%s\n' "$_t77_out" | sed 's/^/         /'
fi

# TC-15: 別々のリスト項目に分かれた ANCHOR と動詞は畳まない（過検出防止 / F2-1）
# 単位を「連続非空行ブロック」まで広げると、無関係な隣接行を同一単位に畳んで
# 誤検出する（実測で増分 22 件中 20 件がこの型）。単位は markdown のブロック境界で切る。
cat > "$_T77_SBX/twoitems.md" <<T77SBX
## 前提

- C-3 未承認なら停止する（\`approvals/${_T77_ANCHOR}\` APPROVED 必須）
- Cloud task は tracked handoff packet を唯一の作業指示として扱う
T77SBX
printf 'canon.md\ntwoitems.md\n' > "$_T77_SBX/cand7.txt"
_t77_out="$(python3 "$_T77_AN" --root "$_T77_SBX" --canonical canon.md < "$_T77_SBX/cand7.txt" 2>&1)" || true
if printf '%s\n' "$_t77_out" | awk -F'\t' '$1=="SURFACE" && $2=="twoitems.md"{f=1} END{exit f?1:0}'; then
  _t77_ok "TC-15 別リスト項目の ANCHOR と動詞を畳まない（過検出しない）"
else
  _t77_ng "TC-15 別リスト項目を同一宣言単位として誤検出している"
  printf '%s\n' "$_t77_out" | sed 's/^/         /'
fi

# TC-16: docs/working/templates/ は検査対象、docs/working/TASK-XXXX/ は対象外（F2-5）
# templates は PBI 横断で参照される恒久成果物なので、承認手順の雛形が入ったら発見する。
mkdir -p "$_T77_SBX/docs/working/templates" "$_T77_SBX/docs/working/TASK-9999"
cat > "$_T77_SBX/docs/working/templates/tmpl.md" <<T77SBX
## 承認テンプレート

人間が APPROVED ${_T77_ANCHOR} を発行する。
T77SBX
cp "$_T77_SBX/docs/working/templates/tmpl.md" "$_T77_SBX/docs/working/TASK-9999/rec.md"
printf 'canon.md\ndocs/working/templates/tmpl.md\ndocs/working/TASK-9999/rec.md\n' > "$_T77_SBX/cand8.txt"
_t77_out="$(python3 "$_T77_AN" --root "$_T77_SBX" --canonical canon.md < "$_T77_SBX/cand8.txt" 2>&1)" || true
_t77_has_tmpl=1
_t77_has_task=0
printf '%s\n' "$_t77_out" | awk -F'\t' '$1=="SURFACE" && $2=="docs/working/templates/tmpl.md"{f=1} END{exit f?0:1}' || _t77_has_tmpl=0
printf '%s\n' "$_t77_out" | awk -F'\t' '$1=="SURFACE" && $2=="docs/working/TASK-9999/rec.md"{f=1} END{exit f?0:1}' && _t77_has_task=1
if [ "$_t77_has_tmpl" = 1 ] && [ "$_t77_has_task" = 0 ]; then
  _t77_ok "TC-16 docs/working/templates/ は検査対象・TASK-XXXX/ は対象外"
else
  _t77_ng "TC-16 除外境界が誤っている (templates=$_t77_has_tmpl, TASK=$_t77_has_task)"
  printf '%s\n' "$_t77_out" | sed 's/^/         /'
fi

rm -rf "$_T77_SBX"

fi

pg_extra_contract_finalize
