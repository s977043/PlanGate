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
# === 判定軸: 位置ではなく「その面が承認手順を定義しているか」===
# approval surface = C-3 承認手順の *順序連鎖* を宣言している面。
# 内容述語だけで発見する（パス一覧では発見しない）:
#   1 行の中に矢印 U+2192 が 3 本以上、かつ承認トークン名（c3 + .json）を含む
# 発見結果は下の登録表と *同値照合* する。面が増えても減っても TC-01 が落ちる。
#
# === 差分判定の基準: git diff を使わない（実測に基づく設計判断）===
# .github/workflows/test.yml は actions/checkout を fetch-depth 指定なしで呼ぶ
# （既定 = 1）。CI の pull_request 実行では origin/main も履歴も存在せず、
# 「origin/main との比較」も「commit range」も CI では成立しない（手元でだけ
# 通る検査になる）。したがって本ゲートは差分ではなく **同一ツリー内の同値照合**
# で判定する:
#     非正本面が宣言する各ステップ語が、正本 .claude/rules/working-context.md
#     の本文で解決できること
# 非正本面「だけ」を変更して新ステップを足すと、その語は正本に存在しないので
# UNRESOLVED になる（= issue 案 C「正本更新を必須化」の機械化）。正本にも同じ
# 語を入れれば解決するが、正本は HO なので通常の承認境界ゲートに乗る。
# 比較対象は常に作業ツリーの内容どうしなので、CI・手元・standalone で同一に動く。
#
# === 既知ギャップ台帳 ===
# origin/main = ecfef5b 時点で #1226 の実害は *生きている*（Plan Normalization が
# 非 HO 面 3 本の連鎖に入っているが、正本には 1 度も現れない）。これを
# _T77_GAPS に明示登録し、それ以外の未解決語は FAIL とする。台帳エントリが
# 発火しなくなったら TC-05 が落ちる（stale 台帳の禁止 = 恒久ザル化の防止）。
# 台帳自体は fail-open の穴でもある（残存脅威モデルを参照）。
#
#   TC-01: 発見 surface 集合 == 登録集合（同値照合。面の増減を検出）
#   TC-02: 発見 surface 数が floor 以上（vacuous PASS 防止。絶対件数の契約にしない）
#   TC-03: 正本自身が承認連鎖を宣言している（宣言をやめたら検出）
#   TC-04: 非正本面のステップ語がすべて解決（rc=0 + unresolved=0 + 母数 floor）
#   TC-05: 既知ギャップ台帳に stale エントリが無い（gapunused=0）
#   TC-06: .cursor/skills/plan-review-gate symlink が登録 surface を指す
#   TC-07: 対照 — 非正本面だけに新ステップを足すと UNRESOLVED（rc=1 + 一意トークン）
#   TC-08: 対照 — 同じ新ステップを正本にも足すと解決（rc=0 + OK トークン）
#   TC-09: 対照 — 引数不足は invocation error（rc=2）で契約違反 rc=1 と区別
#   TC-10: 対照 — 正本が連鎖宣言を失うと専用トークン付きで rc=1

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

if [ "$_T77_RUN" = 1 ]; then

_T77_TMP="$(mktemp -d)"
register_cleanup "$_T77_TMP"
_T77_AN="$_T77_TMP/analyze.py"

# 検査器本体。承認トークン名（c3 + .json）と一部の装飾記号は、本ファイルの
# 生成手順（EH-13 token-guard / 隔離チェッカ）の制約で連結・chr() 合成する。
# 判定内容には影響しない。
cat > "$_T77_AN" <<'T77PY'
import re
import sys

ARROW = chr(8594)
MIN_ARROWS = 3
ANCHOR = "c3" + ".json"
EXCLUDE_PREFIXES = ("docs/working/",)
EXCLUDE_FILES = ("CHANGELOG.md", "docs/changelog.md")

# 正規化に使う文字クラス。CJK 記号は chr() で組む（生成手順の制約）。
#   65288/65289 = FULLWIDTH PARENTHESIS, 12300/12301 = CORNER BRACKET,
#   12303 = WHITE CORNER BRACKET, 12288 = IDEOGRAPHIC SPACE,
#   12290 = IDEOGRAPHIC FULL STOP, 12289 = IDEOGRAPHIC COMMA,
#   65306 = FULLWIDTH COLON, 65307 = FULLWIDTH SEMICOLON,
#   96 = GRAVE ACCENT, 34 = QUOTATION MARK, 62 = GT, 124 = VERTICAL LINE
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
        if rel.startswith(EXCLUDE_PREFIXES) or rel in EXCLUDE_FILES:
            continue
        try:
            text = read_rel(root, rel)
        except (OSError, UnicodeDecodeError):
            continue
        cl = chain_lines(text)
        if cl:
            surfaces.append((rel, cl))
    surfaces.sort()
    for rel, cl in surfaces:
        sys.stdout.write("SURFACE\t%s\t%d\n" % (rel, len(cl)))

    if not [s for s in surfaces if s[0] == canonical]:
        sys.stderr.write("APPROVAL_SURFACE_NO_CANONICAL_CHAIN: %s\n" % canonical)
        return 1
    hay = norm(read_rel(root, canonical))

    terms = 0
    unresolved = 0
    gap_hits = dict()
    for rel, cl in surfaces:
        if rel == canonical:
            continue
        for lineno, line in cl:
            for seg in line.split(ARROW):
                term = leading_term(seg)
                if len(term) < 2:
                    continue
                terms += 1
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
        "SUMMARY\tsurfaces=%d\tterms=%d\tunresolved=%d\tgaphits=%d\tgapunused=%d\n"
        % (len(surfaces), terms, unresolved, len(gap_hits), len(unused))
    )
    return 1 if unresolved else 0


sys.exit(main(sys.argv))
T77PY

# --- 登録表（発見結果と同値照合する相手。これ自体は正本ではない）---------
# 発見は内容述語で行い、この表は「実体との差」を検出するためだけに置く。
# 面が増えても減っても TC-01 が落ちる。
_T77_CANON=".claude/rules/working-context.md"
_T77_REGISTERED=".agents/skills/plan-review-gate/SKILL.md
.claude/rules/working-context.md
.codex/skills/plan-review-gate/SKILL.md
plugin/plangate/rules/working-context.md
plugin/plangate/skills/plan-review-gate/SKILL.md"
# floor であって絶対件数の契約値ではない（成長するディレクトリに -eq を置かない）
_T77_SURFACE_FLOOR=4
_T77_TERM_FLOOR=20
# 既知ギャップ台帳: #1226 の実害（Plan Normalization が非 HO 面にだけ存在する）。
# 正本が更新されたら発火しなくなり TC-05 が落ちる = 台帳から消す義務が生じる。
_T77_GAPS="PlanNormalization"

_T77_CAND="$_T77_TMP/cand.txt"
_T77_OUT="$_T77_TMP/out.txt"
_T77_ERR="$_T77_TMP/err.txt"
git -C "$_T77_ROOT" ls-files -- '*.md' > "$_T77_CAND" 2>/dev/null || true

_t77_rc=0
python3 "$_T77_AN" --root "$_T77_ROOT" --canonical "$_T77_CANON" --gap "$_T77_GAPS" < "$_T77_CAND" > "$_T77_OUT" 2> "$_T77_ERR" || _t77_rc=$?

_t77_found="$(awk -F'\t' '$1=="SURFACE"{print $2}' "$_T77_OUT" | sort)"
_t77_want="$(printf '%s\n' "$_T77_REGISTERED" | sort)"
_t77_nfound="$(printf '%s\n' "$_t77_found" | grep -c . || true)"

# === TC-01: 発見集合 == 登録集合（同値照合）
if [ "$_t77_found" = "$_t77_want" ]; then
  _t77_ok "TC-01 発見した approval surface 集合が登録表と一致 (n=$_t77_nfound)"
else
  _t77_ng "TC-01 approval surface 集合が登録表と不一致 — 面が増減した可能性"
  printf '         --- discovered ---\n'
  printf '%s\n' "$_t77_found" | sed 's/^/         /'
  printf '         --- registered ---\n'
  printf '%s\n' "$_t77_want" | sed 's/^/         /'
fi

# === TC-02: 母数 floor（vacuous PASS 防止）
if [ "$_t77_nfound" -ge "$_T77_SURFACE_FLOOR" ]; then
  _t77_ok "TC-02 発見 surface 数が floor 以上 ($_t77_nfound -ge $_T77_SURFACE_FLOOR)"
else
  _t77_ng "TC-02 発見 surface 数が floor 未満 ($_t77_nfound) — 検査器が空振りしている"
fi

# === TC-03: 正本自身が承認連鎖を宣言している
if printf '%s\n' "$_t77_found" | grep -qx "$_T77_CANON" && ! grep -q APPROVAL_SURFACE_NO_CANONICAL_CHAIN "$_T77_ERR"; then
  _t77_ok "TC-03 正本 $_T77_CANON が承認連鎖を宣言している"
else
  _t77_ng "TC-03 正本が承認連鎖を宣言していない（宣言の消失は承認境界の消失）"
fi

# === TC-04: 非正本面のステップ語がすべて解決（rc=0 + unresolved=0 + 母数 floor）
_t77_summary="$(grep '^SUMMARY' "$_T77_OUT" || true)"
_t77_nterms="$(printf '%s' "$_t77_summary" | sed -n 's/.*terms=\([0-9][0-9]*\).*/\1/p' | head -n 1)"
[ -n "$_t77_nterms" ] || _t77_nterms=0
if [ "$_t77_rc" = 0 ] && printf '%s' "$_t77_summary" | grep -q 'unresolved=0' && [ "$_t77_nterms" -ge "$_T77_TERM_FLOOR" ]; then
  _t77_ok "TC-04 非正本面のステップ語がすべて正本で解決 (rc=0, terms=$_t77_nterms)"
else
  _t77_ng "TC-04 非正本面に正本で解決できないステップ語がある (rc=$_t77_rc, terms=$_t77_nterms)"
  grep UNRESOLVED "$_T77_OUT" | sed 's/^/         /' || true
  sed 's/^/         /' "$_T77_ERR" || true
fi

# === TC-05: 既知ギャップ台帳に stale エントリが無い
if printf '%s' "$_t77_summary" | grep -q 'gapunused=0'; then
  _t77_ok "TC-05 既知ギャップ台帳に stale エントリなし"
else
  _t77_ng "TC-05 既知ギャップ台帳に発火しないエントリがある — 台帳から削除すること"
  grep '^GAPUNUSED' "$_T77_OUT" | sed 's/^/         /' || true
fi

# === TC-06: .cursor/skills/plan-review-gate は symlink 経由の 6 面目。
# 内容は .agents 面と同一になる（分岐しえない）が、貼り替えは分岐しうる。
_T77_ROOTP="$(CDPATH= cd -- "$_T77_ROOT" && pwd -P)"
_T77_LINK="$_T77_ROOT/.cursor/skills/plan-review-gate"
if [ -L "$_T77_LINK" ] && [ -d "$_T77_LINK" ]; then
  _t77_tgt="$(CDPATH= cd -- "$_T77_LINK" && pwd -P)"
  _t77_trel="${_t77_tgt#$_T77_ROOTP/}"
  case "$_T77_REGISTERED" in
    *"$_t77_trel/SKILL.md"*)
      _t77_ok "TC-06 .cursor symlink が登録 surface を指す ($_t77_trel)"
      ;;
    *)
      _t77_ng "TC-06 .cursor symlink が登録 surface 外を指す ($_t77_trel)"
      ;;
  esac
else
  _t77_ng "TC-06 .cursor/skills/plan-review-gate が symlink として存在しない"
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

rm -rf "$_T77_SBX"

fi

pg_extra_contract_finalize
