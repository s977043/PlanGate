# tests/extras/ta-81-version-bump-gate.sh
# PG_EXTRA_CAPABILITY: standalone-capable
# Sourced by tests/run-tests.sh — uses $pass / $fail counters
#
# #1257: version bump ゲート。
#
# 背景（issue #1257 実測 / 測定時点 origin/main = ecfef5b）:
#   `/plugin update` は version が変わらなければ no-op。version を bump しない限り
#   配布系 PR を何本マージしても consumer には 1 件も届かない。ecfef5b 時点の実測では
#   v8.21.0 タグ以降 45 commits / 配布系 PR 9 本が未配布のまま宣言 version は据え置きの
#   8.21.0 で、しかも同じ `8.21.0` を名乗る payload が 3 種類（Claude Aug 20 /
#   Codex Aug 26 / main Aug 27）存在した。**version 文字列は同一性を保証していなかった。**
#   （45 / 9 / 3 は測定時点の値であり、運用で増える。契約値ではない）
#
# ゲートを掛ける位置（A-2' / 2026-09-07 Human 決定）:
#   * PR CI     = `--parity` のみ。git 履歴に依存しないので shallow clone でも動く
#   * リリース時 = `--bump --since-latest-tag`（`scripts/release-prep.sh --check` 経由）
#   `--bump` を PR CI に置くと、直近 2 か月で `plugin/plangate` に触れた first-parent
#   commit 99 件のうち 91 件が赤になる（自動同期 PR は恒久的に赤）。ゲートは
#   「マージのたび」ではなく「リリースのたび」に置く。
#
# 本ファイルが測る 3 つのこと:
#   (a) parity — version 宣言箇所が全て同値か（PR CI で走る側）
#   (b) bump   — 監視対象に差分がある range で version が bump されているか
#                （downgrade / 既発行 tag への衝突を含む）
#   (c) 配線   — release-prep が (b) を実際に呼んでいるか（存在は「効いている証拠」でない）
#
# 設計上の要点:
#   - **宣言テーブルの網羅性を別 TC で担保する**（TC-03）。宣言は
#     scripts/version_sites.py の DECLARED_SITES にハードコードされているが、
#     manifest の実走査（discovered）との**同値照合**で「5 箇所目が増えたのに
#     検査から漏れる」を検出する。宣言側にしか無い（= stale）も同時に見る
#   - **絶対件数を書かない**。宣言箇所は「4」という契約値ではなく
#     declared / discovered の**集合が一致すること**として検査する（README P-6 /
#     成長する対象に assertEqual N を置かない）
#   - **positive control を全ての「0 件が期待値」検査に入れる**（TC-03b / TC-03c /
#     TC-04 / TC-06 / TC-07b / TC-08b）。検査器が恒真に退行していないことを同 TC 内で実測する
#   - PASS 判定は **rc と分岐固有 reason トークンの対**（README P-1 / P-3）
#   - **live tree を直接読まない**（#1257 R2 の cross-test 結合指摘）。実 repo の
#     manifest は HEAD からスナップショットして sandbox で検査する。ta-28 TC-08 が
#     tracked な marketplace.json を一時改変する窓と重なっても誤 FAIL しない
#
# 隔離: 実 repo は読むだけ。変異注入・合成 git repo はすべて mktemp -d 配下
#   （README 規約 3 / 9。実 repo の tracked パスには一切書かない = 先頭 prune 対象なし）
#
# 一時状態の射程（README 規約 9）: mktemp -d 配下のみ。register_cleanup に登録する。

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
pg_extra_contract_init ta-81-version-bump-gate standalone-capable

printf '\n=== TA-81: version bump gate (#1257) ===\n'

if pg_extra_contract_is_standalone; then
  unset PLANGATE_SKIP_REASON PLANGATE_HOOK_TASK PLANGATE_HOOK_FILE \
    PLANGATE_BYPASS_HOOK PLANGATE_HOOK_STRICT PG_HARNESS_SOURCED \
    PLANGATE_ALLOW_MASS_DELETE 2>/dev/null || true
fi

_T81_FX=""
if [ "$_pg_extra_mode" = harness ]; then
  _T81_FX="${FIXTURES_DIR:-}"
fi
if [ -n "$_T81_FX" ]; then
  _T81_ROOT="$(CDPATH= cd -- "$_T81_FX/../.." && pwd)"
else
  _T81_ROOT="${_pg_extra_dir%/tests/extras}"
fi

t81_pass() { pass=$((pass + 1)); printf '  [PASS] %s\n' "$1"; }
t81_fail() { fail=$((fail + 1)); printf '  [FAIL] %s\n' "$1" >&2; }
t81_info() { printf '  [INFO] %s\n' "$1"; }

_T81_OK=1
# 非空チェックだけでは `/` を弾けないので実体で確かめる（README 規約 9）
if [ -z "$_T81_ROOT" ] || [ ! -f "$_T81_ROOT/bin/plangate" ]; then
  t81_fail "ta-81 TC-00: repo root unresolved (_T81_ROOT=$_T81_ROOT)"
  _T81_OK=0
fi

_T81_SH="$_T81_ROOT/scripts/check-version-bump.sh"
_T81_PY="$_T81_ROOT/scripts/version_sites.py"
_T81_RELPREP="$_T81_ROOT/scripts/release-prep.sh"
_T81_RELDOC="$_T81_ROOT/docs/release-process.md"

if [ "$_T81_OK" = "1" ] && [ ! -f "$_T81_SH" ]; then
  t81_fail "ta-81 TC-00: gate script not found: $_T81_SH"
  _T81_OK=0
fi
if [ "$_T81_OK" = "1" ] && [ ! -f "$_T81_PY" ]; then
  t81_fail "ta-81 TC-00: sites module not found: $_T81_PY"
  _T81_OK=0
fi
if [ "$_T81_OK" = "1" ] && ! command -v python3 >/dev/null 2>&1; then
  pg_extra_contract_skip "python3 unavailable (version site extraction requires python3)"
  _T81_OK=0
fi
if [ "$_T81_OK" = "1" ] && ! command -v git >/dev/null 2>&1; then
  pg_extra_contract_skip "git unavailable (the bump gate inspects a commit range)"
  _T81_OK=0
fi

if [ "$_T81_OK" = "1" ]; then

_T81_TMP=$(mktemp -d)
if command -v register_cleanup >/dev/null 2>&1; then
  register_cleanup "$_T81_TMP"
fi

# 変異注入用のセッター（テスト側ツール。site key = <relpath>::<jsonpath>）
_T81_SETTER="$_T81_TMP/set-version.py"
cat > "$_T81_SETTER" << 'PYSET'
import json, re, sys
path, jsonpath, value = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path, encoding='utf-8') as fh:
    doc = json.load(fh)
tokens = re.findall(r"\[[^\]]*\]|[^.\[\]]+", jsonpath)
cursor = doc
for token in tokens[:-1]:
    if token.startswith('['):
        inner = token[1:-1]
        if inner.startswith('name='):
            cursor = [e for e in cursor if e.get('name') == inner[5:]][0]
        else:
            cursor = cursor[int(inner)]
    else:
        cursor = cursor[token]
cursor[tokens[-1]] = value
with open(path, 'w', encoding='utf-8') as fh:
    json.dump(doc, fh, indent=2, ensure_ascii=False)
    fh.write('\n')
PYSET

# 実 repo の manifest を **HEAD から** sandbox へ複製する（#1257 R2: cross-test 結合）。
# live tree を直接読むと、ta-28 TC-08 が tracked な marketplace.json を一時改変する
# 窓（subshell trap で復元）に重なったとき誤 FAIL する。HEAD 由来なら他テストの
# 作業ツリー改変から独立する。working tree が dirty なら（= リリース準備中に
# version を編集している最中など）live を複製し、その旨を出力する。
_T81_SNAP_SRC="HEAD"
_t81_snapshot() {
  # $1 = 出力先ディレクトリ
  rm -rf "$1"
  mkdir -p "$1"
  if [ "$_T81_SNAP_SRC" = "HEAD" ]; then
    ( cd "$_T81_ROOT" && git archive HEAD -- \
        .claude-plugin/marketplace.json \
        plugin/plangate/.claude-plugin/plugin.json \
        plugin/plangate/.codex-plugin/plugin.json ) | ( cd "$1" && tar xf - )
  else
    ( cd "$_T81_ROOT" && tar cf - .claude-plugin/marketplace.json \
        plugin/plangate/.claude-plugin/plugin.json \
        plugin/plangate/.codex-plugin/plugin.json ) | ( cd "$1" && tar xf - )
  fi
}

if git -C "$_T81_ROOT" diff --quiet HEAD -- \
    .claude-plugin/marketplace.json \
    plugin/plangate/.claude-plugin/plugin.json \
    plugin/plangate/.codex-plugin/plugin.json 2>/dev/null; then
  _T81_SNAP_SRC="HEAD"
else
  _T81_SNAP_SRC="worktree"
  t81_info "ta-81: manifest が working tree で未コミット変更あり — HEAD ではなく作業ツリーを検査する"
fi

# ---------------------------------------------------------------------------
# TC-01: gate script が POSIX sh として解釈でき、使い方エラーが rc=2
# ---------------------------------------------------------------------------
if sh -n "$_T81_SH" 2>/dev/null; then
  t81_pass "ta-81 TC-01a: check-version-bump.sh sh -n"
else
  t81_fail "ta-81 TC-01a: check-version-bump.sh に syntax error"
fi

# 対照（README P-4）: --bump だけで --base を欠くと rc=2（使い方エラー）
_t81_rc=0
_t81_out=$(sh "$_T81_SH" --bump 2>&1) || _t81_rc=$?
if [ "$_t81_rc" = "2" ] && printf '%s' "$_t81_out" | grep -q -- '--bump には --base か --since-latest-tag が必須です'; then
  t81_pass "ta-81 TC-01b: --bump without --base -> rc=2 (usage error)"
else
  t81_fail "ta-81 TC-01b: expected rc=2 + usage diagnostic (rc=$_t81_rc out=$_t81_out)"
fi

# TC-01c: option の**値欠落**も rc=2（使い方エラー）。#1257 R2 指摘の回帰テスト。
# 旧実装は `set -e` 下で引数を使い切った後の末尾 `shift` が失敗し、
# **出力ゼロ・rc=1** で落ちていた。rc=1 は「契約違反を検出した」の意味なので
# 呼び出し側（release-prep）が「未 bump を検出した」と誤判定する。
_t81_c1c_bad=""
for _t81_argset in "--bump --base" "--bump --base --head HEAD" "--bump --base --root ." "--bump --head"; do
  # 引数列を意図的に単語分割させる（値欠落の形を再現するため）。
  # shellcheck disable=SC2086
  _t81_rc=0
  _t81_out=$(sh "$_T81_SH" $_t81_argset 2>&1) || _t81_rc=$?
  if [ "$_t81_rc" != "2" ] || ! printf '%s' "$_t81_out" | grep -q 'Usage:'; then
    _t81_c1c_bad="$_t81_c1c_bad [$_t81_argset -> rc=$_t81_rc]"
  fi
done
if [ -z "$_t81_c1c_bad" ]; then
  t81_pass "ta-81 TC-01c: option の値欠落は rc=2 + usage（rc=1 と混ざらない）"
else
  t81_fail "ta-81 TC-01c: 値欠落の rc 契約違反:$_t81_c1c_bad"
fi

# ---------------------------------------------------------------------------
# TC-02: 実 repo の parity（受入基準 2）— rc=0 + VERSION_PARITY_OK
# ---------------------------------------------------------------------------
_T81_SNAP="$_T81_TMP/snapshot"
_t81_snapshot "$_T81_SNAP"
_t81_rc=0
_t81_out=$(sh "$_T81_SH" --parity --root "$_T81_SNAP" 2>&1) || _t81_rc=$?
if [ "$_t81_rc" = "0" ] && printf '%s' "$_t81_out" | grep -q 'VERSION_PARITY_OK'; then
  t81_pass "ta-81 TC-02: 実 repo（$_T81_SNAP_SRC 由来）の version 宣言箇所が全て同値 ($(printf '%s' "$_t81_out" | sed -n 's/.*VERSION_PARITY_OK //p'))"
else
  t81_fail "ta-81 TC-02: parity NG (rc=$_t81_rc out=$_t81_out)"
fi

# ---------------------------------------------------------------------------
# TC-03: 宣言テーブルの網羅性（将来 version 宣言が増えても検査から漏れない）
#   絶対件数は書かない。declared 集合と discovered 集合の**同値照合**で見る。
# ---------------------------------------------------------------------------
_t81_discovered=$(python3 "$_T81_PY" discovered --root "$_T81_ROOT" | cut -f1 | sort)
_t81_rc=0
_t81_out=$(python3 "$_T81_PY" verify-sites --root "$_T81_ROOT" 2>&1) || _t81_rc=$?
if [ "$_t81_rc" = "0" ] && printf '%s' "$_t81_out" | grep -q 'VERSION_SITES_COMPLETE'; then
  # 母数の floor（README P-6）: 走査が空振りしていたら vacuous PASS になる
  _t81_n=$(printf '%s\n' "$_t81_discovered" | grep -c . || true)
  if [ "$_t81_n" -ge 2 ]; then
    t81_pass "ta-81 TC-03a: 宣言テーブル = 実 manifest 走査（$_t81_n sites、件数は契約値にしない）"
  else
    t81_fail "ta-81 TC-03a: manifest 走査が空振り（discovered=$_t81_n）— 検査が vacuous"
  fi
else
  t81_fail "ta-81 TC-03a: 宣言/走査が乖離 (rc=$_t81_rc out=$_t81_out)"
fi

# TC-03b positive control: 未宣言の manifest を 1 本足すと UNDECLARED で検出されるか
# （「0 件が期待値」の検査が確かに検出できることを同 TC 内で実測する）
_T81_SB="$_T81_TMP/sandbox-sites"
_t81_snapshot "$_T81_SB"
mkdir -p "$_T81_SB/plugin/probe/.claude-plugin"
printf '{\n  "name": "probe",\n  "version": "0.0.1"\n}\n' \
  > "$_T81_SB/plugin/probe/.claude-plugin/plugin.json"
_t81_rc=0
_t81_out=$(python3 "$_T81_PY" verify-sites --root "$_T81_SB" 2>&1) || _t81_rc=$?
if [ "$_t81_rc" = "1" ] && printf '%s' "$_t81_out" | grep -q 'VERSION_SITE_UNDECLARED plugin/probe/.claude-plugin/plugin.json::version'; then
  t81_pass "ta-81 TC-03b: positive control — 未宣言 manifest を UNDECLARED として検出"
else
  t81_fail "ta-81 TC-03b: 未宣言 manifest を検出できない = TC-03a は恒真 (rc=$_t81_rc out=$_t81_out)"
fi

# TC-03c positive control（逆向き）: 宣言だけ残って実体が消えたら STALE で落ちるか
rm -f "$_T81_SB/plugin/probe/.claude-plugin/plugin.json"
rm -f "$_T81_SB/plugin/plangate/.codex-plugin/plugin.json"
_t81_rc=0
_t81_out=$(python3 "$_T81_PY" verify-sites --root "$_T81_SB" 2>&1) || _t81_rc=$?
if [ "$_t81_rc" = "1" ] && printf '%s' "$_t81_out" | grep -q 'VERSION_SITE_STALE plugin/plangate/.codex-plugin/plugin.json::version'; then
  t81_pass "ta-81 TC-03c: positive control — 宣言のみ残る stale site を検出"
else
  t81_fail "ta-81 TC-03c: stale site を検出できない (rc=$_t81_rc out=$_t81_out)"
fi

# ---------------------------------------------------------------------------
# TC-04: parity の変異注入（受入基準 3 前半 / 1 箇所だけずらす）
#   宣言された **全 site** をループする。site を増やしたら自動的に本 TC の
#   母数も増える（ハードコード列挙にしない）。
# ---------------------------------------------------------------------------
_t81_total=0
_t81_killed=0
_t81_surv=""
python3 "$_T81_PY" declared --root "$_T81_ROOT" | cut -f1,2 > "$_T81_TMP/sites.tsv"
while IFS="$(printf '\t')" read -r _t81_id _t81_key; do
  [ -n "${_t81_key:-}" ] || continue
  _t81_total=$((_t81_total + 1))
  _T81_MUT="$_T81_TMP/mut-$_t81_id"
  _t81_snapshot "$_T81_MUT"
  _t81_file="${_t81_key%%::*}"
  _t81_path="${_t81_key#*::}"
  # 変異が実際に入ったことを先に確認する（README P-7: 空振り変異を PASS にしない）
  _t81_before=$(python3 "$_T81_PY" declared --root "$_T81_MUT" | grep -F "	$_t81_key	" | cut -f3)
  python3 "$_T81_SETTER" "$_T81_MUT/$_t81_file" "$_t81_path" "99.99.99" 2>/dev/null || true
  _t81_after=$(python3 "$_T81_PY" declared --root "$_T81_MUT" | grep -F "	$_t81_key	" | cut -f3)
  if [ "$_t81_before" = "$_t81_after" ]; then
    _t81_surv="$_t81_surv $_t81_id(mutation-noop)"
    continue
  fi
  _t81_rc=0
  _t81_out=$(sh "$_T81_SH" --parity --root "$_T81_MUT" 2>&1) || _t81_rc=$?
  if [ "$_t81_rc" = "1" ] && printf '%s' "$_t81_out" | grep -q 'VERSION_PARITY_MISMATCH'; then
    _t81_killed=$((_t81_killed + 1))
  else
    _t81_surv="$_t81_surv $_t81_id(rc=$_t81_rc)"
  fi
done < "$_T81_TMP/sites.tsv"

if [ "$_t81_total" -ge 2 ] && [ "$_t81_killed" = "$_t81_total" ]; then
  t81_pass "ta-81 TC-04: 変異注入 — 宣言 $_t81_total site を 1 箇所ずつずらして全て KILL"
else
  t81_fail "ta-81 TC-04: 変異が SURVIVE / 母数不足 (total=$_t81_total killed=$_t81_killed survived:$_t81_surv)"
fi

# ---------------------------------------------------------------------------
# TC-05: bump ゲートを合成 git repo で双方向検証（受入基準 1 / 3 後半）
# ---------------------------------------------------------------------------
_T81_GIT="$_T81_TMP/synthetic"
rm -rf "$_T81_GIT"
mkdir -p "$_T81_GIT/plugin/plangate/.claude-plugin" "$_T81_GIT/plugin/plangate/skills" "$_T81_GIT/docs"
printf '{\n  "name": "plangate",\n  "version": "1.0.0"\n}\n' \
  > "$_T81_GIT/plugin/plangate/.claude-plugin/plugin.json"
printf 'base\n' > "$_T81_GIT/plugin/plangate/skills/a.md"
printf 'base\n' > "$_T81_GIT/docs/unrelated.md"
git -C "$_T81_GIT" init -q 2>/dev/null
git -C "$_T81_GIT" config user.email ta81@example.invalid
git -C "$_T81_GIT" config user.name ta81
git -C "$_T81_GIT" add -A >/dev/null 2>&1
git -C "$_T81_GIT" -c commit.gpgsign=false commit -q -m base >/dev/null 2>&1
_t81_base=$(git -C "$_T81_GIT" rev-parse HEAD)

# (a) 配布物だけ変えて version 据え置き -> VERSION_BUMP_MISSING / rc=1
printf 'changed\n' > "$_T81_GIT/plugin/plangate/skills/a.md"
git -C "$_T81_GIT" add -A >/dev/null 2>&1
git -C "$_T81_GIT" -c commit.gpgsign=false commit -q -m 'plugin change without bump' >/dev/null 2>&1
_t81_rc=0
_t81_out=$(sh "$_T81_SH" --bump --base "$_t81_base" --root "$_T81_GIT" 2>&1) || _t81_rc=$?
if [ "$_t81_rc" = "1" ] && printf '%s' "$_t81_out" | grep -q 'VERSION_BUMP_MISSING'; then
  t81_pass "ta-81 TC-05a: 配布物差分 + version 据え置き -> rc=1 VERSION_BUMP_MISSING"
else
  t81_fail "ta-81 TC-05a: 未 bump を検出できない (rc=$_t81_rc out=$_t81_out)"
fi

# (b) 同じ差分に bump を足すと通る（対照 / README P-4）
printf '{\n  "name": "plangate",\n  "version": "1.1.0"\n}\n' \
  > "$_T81_GIT/plugin/plangate/.claude-plugin/plugin.json"
git -C "$_T81_GIT" add -A >/dev/null 2>&1
git -C "$_T81_GIT" -c commit.gpgsign=false commit -q -m 'bump' >/dev/null 2>&1
_t81_rc=0
_t81_out=$(sh "$_T81_SH" --bump --base "$_t81_base" --root "$_T81_GIT" 2>&1) || _t81_rc=$?
if [ "$_t81_rc" = "0" ] && printf '%s' "$_t81_out" | grep -q 'VERSION_BUMP_OK_BUMPED'; then
  t81_pass "ta-81 TC-05b: 対照 — bump ありは rc=0 VERSION_BUMP_OK_BUMPED"
else
  t81_fail "ta-81 TC-05b: bump ありが通らない (rc=$_t81_rc out=$_t81_out)"
fi

# (c) 配布物に触れない差分は要求しない（過検出しないことの対照）
_t81_mid=$(git -C "$_T81_GIT" rev-parse HEAD)
printf 'doc only\n' > "$_T81_GIT/docs/unrelated.md"
git -C "$_T81_GIT" add -A >/dev/null 2>&1
git -C "$_T81_GIT" -c commit.gpgsign=false commit -q -m 'doc only' >/dev/null 2>&1
_t81_rc=0
_t81_out=$(sh "$_T81_SH" --bump --base "$_t81_mid" --root "$_T81_GIT" 2>&1) || _t81_rc=$?
if [ "$_t81_rc" = "0" ] && printf '%s' "$_t81_out" | grep -q 'VERSION_BUMP_OK_NO_PLUGIN_DIFF'; then
  t81_pass "ta-81 TC-05c: 対照 — 配布物に差分が無い range は bump を要求しない"
else
  t81_fail "ta-81 TC-05c: 過検出 (rc=$_t81_rc out=$_t81_out)"
fi

# (d) base 未解決は rc=3（= 検査していない）。rc=0 で成功を装わないこと
_t81_rc=0
_t81_out=$(sh "$_T81_SH" --bump --base "deadbeefdeadbeefdeadbeefdeadbeefdeadbeef" --root "$_T81_GIT" 2>&1) || _t81_rc=$?
if [ "$_t81_rc" = "3" ] && printf '%s' "$_t81_out" | grep -q 'VERSION_BASE_UNRESOLVED'; then
  t81_pass "ta-81 TC-05d: base 未解決は rc=3 VERSION_BASE_UNRESOLVED（rc=0 で装わない）"
else
  t81_fail "ta-81 TC-05d: base 未解決の扱いが誤り (rc=$_t81_rc out=$_t81_out)"
fi

# ---------------------------------------------------------------------------
# TC-06: 実 repo の履歴で双方向検証（#1257 の実事象そのもの）
#   shallow clone では対象 commit が無いため、その場合は「検査していない」ことを
#   明示して pass/fail のどちらにも数えない。
# ---------------------------------------------------------------------------
# a82426a = plugin/plangate 差分あり・bump なし（#1271。#1257 が報告した型）
# 33d8de8 = v8.21.0 リリース準備（plugin 差分 + bump）
_t81_real_missing=a82426a
_t81_real_bumped=33d8de8
if git -C "$_T81_ROOT" rev-parse --verify --quiet "$_t81_real_missing^{commit}" >/dev/null 2>&1 &&
   git -C "$_T81_ROOT" rev-parse --verify --quiet "$_t81_real_bumped^{commit}" >/dev/null 2>&1; then
  _t81_rc=0
  _t81_out=$(sh "$_T81_SH" --bump --base "$_t81_real_missing^" --head "$_t81_real_missing" --root "$_T81_ROOT" 2>&1) || _t81_rc=$?
  if [ "$_t81_rc" = "1" ] && printf '%s' "$_t81_out" | grep -q 'VERSION_BUMP_MISSING'; then
    t81_pass "ta-81 TC-06a: 実 commit ${_t81_real_missing}（配布物変更・未 bump）を検出"
  else
    t81_fail "ta-81 TC-06a: 実 commit で未 bump を検出できない (rc=$_t81_rc out=$_t81_out)"
  fi
  _t81_rc=0
  _t81_out=$(sh "$_T81_SH" --bump --base "$_t81_real_bumped^" --head "$_t81_real_bumped" --root "$_T81_ROOT" 2>&1) || _t81_rc=$?
  if [ "$_t81_rc" = "0" ] && printf '%s' "$_t81_out" | grep -q 'VERSION_BUMP_OK_BUMPED'; then
    t81_pass "ta-81 TC-06b: 対照 — 実 commit ${_t81_real_bumped}（bump あり）は通る"
  else
    t81_fail "ta-81 TC-06b: 実 commit の bump ありが通らない (rc=$_t81_rc out=$_t81_out)"
  fi
else
  t81_info "ta-81 TC-06: 実 commit 不在（shallow clone）— 実履歴での検証は未実施"
fi

# ---------------------------------------------------------------------------
# TC-07: **リリース経路への配線**（A-2'）。
#   ゲートの存在は「効いている証拠」ではない。A-2' では PR CI ではなく
#   scripts/release-prep.sh --check が --bump を呼ぶ。呼んでいなければ
#   #1257 の受入基準 1 は黙って未達になる。
#   grep はファイル全体ではなく **run_checks から呼ばれる関数**まで見る
#   （旧 TC-07 の「test.yml 全体を grep」は、別 job が増えたときに誤判定した）。
# ---------------------------------------------------------------------------
if [ -f "$_T81_RELPREP" ]; then
  _t81_wired=1
  grep -q 'check-version-bump.sh" --bump --since-latest-tag' "$_T81_RELPREP" || _t81_wired=0
  grep -q '^  check_version_bump$' "$_T81_RELPREP" || _t81_wired=0
  grep -q 'check-version-bump.sh" --parity' "$_T81_RELPREP" || _t81_wired=0
  if [ "$_t81_wired" = "1" ]; then
    t81_pass "ta-81 TC-07a: release-prep --check が --parity と --bump --since-latest-tag を配線している"
  else
    t81_fail "ta-81 TC-07a: release-prep への配線が無い — リリース時ゲートが働かない ($_T81_RELPREP)"
  fi

  # positive control: 実在しない関数名は当然ヒットしない = 上の grep は恒真でない
  if grep -q '^  check_version_bump_nonexistent$' "$_T81_RELPREP"; then
    t81_fail "ta-81 TC-07b: positive control 失敗 — 実在しない関数名がヒットした"
  else
    t81_pass "ta-81 TC-07b: positive control — 未配線の名前は確かに未ヒット"
  fi
else
  t81_fail "ta-81 TC-07: scripts/release-prep.sh が見つかりません: $_T81_RELPREP"
fi

# ---------------------------------------------------------------------------
# TC-08: version 同期マップ（docs/release-process.md）が 4 箇所全てを載せているか
#   #1257 実測: `.codex-plugin/plugin.json` が同期マップから漏れていた。
#   宣言テーブル（正本）側の**ファイル集合**と突き合わせる（件数は書かない）。
# ---------------------------------------------------------------------------
if [ -f "$_T81_RELDOC" ]; then
  _t81_missdoc=""
  _t81_nfile=0
  for _t81_f in $(python3 "$_T81_PY" declared --root "$_T81_ROOT" | cut -f2 | sed 's/::.*//' | sort -u); do
    _t81_nfile=$((_t81_nfile + 1))
    grep -qF "$_t81_f" "$_T81_RELDOC" || _t81_missdoc="$_t81_missdoc $_t81_f"
  done
  if [ "$_t81_nfile" -ge 2 ] && [ -z "$_t81_missdoc" ]; then
    t81_pass "ta-81 TC-08a: version 同期マップが宣言 manifest を全て網羅（$_t81_nfile ファイル）"
  else
    t81_fail "ta-81 TC-08a: version 同期マップに未記載:$_t81_missdoc (母数=$_t81_nfile)"
  fi
  # positive control: 存在しないはずのパスは当然ヒットしない = grep 検査が恒真でない
  if grep -qF "plugin/plangate/.nonexistent-plugin/plugin.json" "$_T81_RELDOC"; then
    t81_fail "ta-81 TC-08b: positive control 失敗 — 実在しないパスが同期マップにヒットした"
  else
    t81_pass "ta-81 TC-08b: positive control — 未記載パスは確かに未ヒット（TC-08a の grep は恒真でない）"
  fi
else
  t81_fail "ta-81 TC-08: docs/release-process.md が見つかりません"
fi

# ---------------------------------------------------------------------------
# TC-09: 合成 git repo で **--since-latest-tag**（リリース経路そのもの）を双方向検証。
#   #1257 の実障害「tag 以降に配布物差分があるのに version 据え置き」を
#   最小再現し、tag を base にして検出できることを実測する。
# ---------------------------------------------------------------------------
_T81_TAG="$_T81_TMP/tagged"
rm -rf "$_T81_TAG"
mkdir -p "$_T81_TAG/plugin/plangate/.claude-plugin" "$_T81_TAG/plugin/plangate/skills"
printf '{\n  "name": "plangate",\n  "version": "1.0.0"\n}\n' \
  > "$_T81_TAG/plugin/plangate/.claude-plugin/plugin.json"
printf 'base\n' > "$_T81_TAG/plugin/plangate/skills/a.md"
git -C "$_T81_TAG" init -q 2>/dev/null
git -C "$_T81_TAG" config user.email ta81@example.invalid
git -C "$_T81_TAG" config user.name ta81
git -C "$_T81_TAG" add -A >/dev/null 2>&1
git -C "$_T81_TAG" -c commit.gpgsign=false commit -q -m 'release 1.0.0' >/dev/null 2>&1
git -C "$_T81_TAG" tag v1.0.0

# (a) tag 以降に配布物差分・version 据え置き -> rc=1 VERSION_BUMP_MISSING（#1257 の実障害型）
printf 'changed after release\n' > "$_T81_TAG/plugin/plangate/skills/a.md"
git -C "$_T81_TAG" add -A >/dev/null 2>&1
git -C "$_T81_TAG" -c commit.gpgsign=false commit -q -m 'plugin change after tag' >/dev/null 2>&1
_t81_rc=0
_t81_out=$(sh "$_T81_SH" --bump --since-latest-tag --root "$_T81_TAG" 2>&1) || _t81_rc=$?
if [ "$_t81_rc" = "1" ] && printf '%s' "$_t81_out" | grep -q 'VERSION_BUMP_MISSING'; then
  t81_pass "ta-81 TC-09a: --since-latest-tag が「tag 以降に配布物差分・version 据え置き」を検出（#1257 実障害の再現）"
else
  t81_fail "ta-81 TC-09a: 最新 tag 基準の未 bump を検出できない (rc=$_t81_rc out=$_t81_out)"
fi

# (b) 対照: bump すると通る
printf '{\n  "name": "plangate",\n  "version": "1.1.0"\n}\n' \
  > "$_T81_TAG/plugin/plangate/.claude-plugin/plugin.json"
git -C "$_T81_TAG" add -A >/dev/null 2>&1
git -C "$_T81_TAG" -c commit.gpgsign=false commit -q -m 'bump to 1.1.0' >/dev/null 2>&1
_t81_rc=0
_t81_out=$(sh "$_T81_SH" --bump --since-latest-tag --root "$_T81_TAG" 2>&1) || _t81_rc=$?
if [ "$_t81_rc" = "0" ] && printf '%s' "$_t81_out" | grep -q 'VERSION_BUMP_OK_BUMPED'; then
  t81_pass "ta-81 TC-09b: 対照 — 最新 tag 以降に bump があれば通る"
else
  t81_fail "ta-81 TC-09b: bump ありが通らない (rc=$_t81_rc out=$_t81_out)"
fi

# ---------------------------------------------------------------------------
# TC-10: downgrade を bump として受理しない（#1257 R2 指摘）。
#   既に tag 済みの version へ戻す revert は「同じ version で別 payload」を
#   再生産する = #1257 の主症状そのもの。
# ---------------------------------------------------------------------------
printf 'reverted payload\n' > "$_T81_TAG/plugin/plangate/skills/a.md"
printf '{\n  "name": "plangate",\n  "version": "1.0.0"\n}\n' \
  > "$_T81_TAG/plugin/plangate/.claude-plugin/plugin.json"
git -C "$_T81_TAG" add -A >/dev/null 2>&1
git -C "$_T81_TAG" -c commit.gpgsign=false commit -q -m 'revert version to 1.0.0' >/dev/null 2>&1
_t81_head=$(git -C "$_T81_TAG" rev-parse HEAD)
_t81_prev=$(git -C "$_T81_TAG" rev-parse HEAD~1)
_t81_rc=0
_t81_out=$(sh "$_T81_SH" --bump --base "$_t81_prev" --head "$_t81_head" --root "$_T81_TAG" 2>&1) || _t81_rc=$?
if [ "$_t81_rc" = "1" ] && printf '%s' "$_t81_out" | grep -q 'VERSION_BUMP_DOWNGRADE'; then
  t81_pass "ta-81 TC-10a: 1.1.0 -> 1.0.0（配布物差分あり）を rc=1 VERSION_BUMP_DOWNGRADE で拒否"
else
  t81_fail "ta-81 TC-10a: downgrade を bump として受理している (rc=$_t81_rc out=$_t81_out)"
fi

# TC-10b positive control: 同じ形の**昇格**は通る（TC-10a が「差分があれば何でも落とす」
# 恒真ゲートに退行していないことを同 TC 内で実測する）
printf '{\n  "name": "plangate",\n  "version": "1.2.0"\n}\n' \
  > "$_T81_TAG/plugin/plangate/.claude-plugin/plugin.json"
git -C "$_T81_TAG" add -A >/dev/null 2>&1
git -C "$_T81_TAG" -c commit.gpgsign=false commit -q -m 'bump to 1.2.0' >/dev/null 2>&1
_t81_rc=0
_t81_out=$(sh "$_T81_SH" --bump --base "$_t81_head" --head HEAD --root "$_T81_TAG" 2>&1) || _t81_rc=$?
if [ "$_t81_rc" = "0" ] && printf '%s' "$_t81_out" | grep -q 'VERSION_BUMP_OK_BUMPED'; then
  t81_pass "ta-81 TC-10b: positive control — 同じ形の昇格 1.0.0 -> 1.2.0 は通る"
else
  t81_fail "ta-81 TC-10b: 昇格まで落ちている = downgrade 検査が恒真 (rc=$_t81_rc out=$_t81_out)"
fi

# ---------------------------------------------------------------------------
# TC-11: 既に tag 発行済みの version へ「bump」して別 payload を配ろうとしたら落とす
#   （downgrade ではないが同一 version で payload が分岐する経路）
# ---------------------------------------------------------------------------
git -C "$_T81_TAG" tag v2.0.0
printf 'payload that differs from what v2.0.0 points at\n' > "$_T81_TAG/plugin/plangate/skills/a.md"
printf '{\n  "name": "plangate",\n  "version": "2.0.0"\n}\n' \
  > "$_T81_TAG/plugin/plangate/.claude-plugin/plugin.json"
git -C "$_T81_TAG" add -A >/dev/null 2>&1
git -C "$_T81_TAG" -c commit.gpgsign=false commit -q -m 'claim already-tagged version' >/dev/null 2>&1
_t81_rc=0
_t81_out=$(sh "$_T81_SH" --bump --base "HEAD~1" --head HEAD --root "$_T81_TAG" 2>&1) || _t81_rc=$?
if [ "$_t81_rc" = "1" ] && printf '%s' "$_t81_out" | grep -q 'VERSION_TAG_PAYLOAD_CONFLICT'; then
  t81_pass "ta-81 TC-11: 既発行 tag と同じ version で別 payload を rc=1 VERSION_TAG_PAYLOAD_CONFLICT で拒否"
else
  t81_fail "ta-81 TC-11: 同一 version・別 payload を通している (rc=$_t81_rc out=$_t81_out)"
fi

# ---------------------------------------------------------------------------
# TC-12: 新ゲートが**リリース手順の中に**現れるか（#1292 後追い是正 major-2）
#   #1292 マージ時点の実測: `release-prep.sh --check` は「ゲートを掛ける位置」の
#   分界表にしか無く、`### 必須検証手順` にも .github/workflows/ にも無かった。
#   = 配線したと書いてあるだけで**手順として実行されない**。
#   **節を限定して検査する**。ファイル全体 grep は分界表にヒットして恒真になる
#   （README P-5: 文字列の存在ではなく構造を見る）。
# ---------------------------------------------------------------------------
# 見出しから次の見出しまでを切り出す（`### 必須検証手順` 本体）。
# **awk の文字列比較は使わない**: 本 repo の macOS 既定 awk は非 ASCII 見出しの
# `$0 == "### 必須検証手順"` が別の `### <日本語>` 行にも真を返す（実測: 4 行に HIT）。
# 見出し検出は grep -Fx（バイト一致）で行い、範囲切り出しは sed に任せる。
_t81_section() {
  # $1 = ファイル / $2 = 見出し行（完全一致）
  _sec_start=$(grep -n -Fx -- "$2" "$1" | head -1 | cut -d: -f1)
  [ -n "${_sec_start:-}" ] || return 1
  _sec_off=$(sed -n "$((_sec_start + 1)),\$p" "$1" | grep -n -E '^#{2,6} ' | head -1 | cut -d: -f1)
  if [ -n "${_sec_off:-}" ]; then
    _sec_end=$((_sec_start + _sec_off - 1))
  else
    _sec_end=$(grep -c '' "$1")
  fi
  [ "$_sec_end" -gt "$_sec_start" ] || return 1
  sed -n "$((_sec_start + 1)),${_sec_end}p" "$1"
}

if [ -f "$_T81_RELDOC" ]; then
  _T81_SECT="$_T81_TMP/relproc-required.txt"
  _t81_section "$_T81_RELDOC" '### 必須検証手順' > "$_T81_SECT"
  _t81_sect_lines=$(grep -c '' "$_T81_SECT" || true)
  _t81_file_lines=$(grep -c '' "$_T81_RELDOC" || true)

  # (a) 節が実体を持つこと（切り出しが空振りしていたら以降は vacuous / README P-6）
  if [ "$_t81_sect_lines" -ge 5 ] && [ "$_t81_sect_lines" -lt "$_t81_file_lines" ]; then
    t81_pass "ta-81 TC-12a: 「必須検証手順」節を切り出せた（$_t81_sect_lines 行 / ファイル $_t81_file_lines 行。件数は契約値にしない）"
  else
    t81_fail "ta-81 TC-12a: 節の切り出しが空振り or ファイル全体（節=$_t81_sect_lines 全体=${_t81_file_lines}）"
  fi

  # (b) positive control: 節の**外**にある「配線した」と書いてあるだけの行
  #     （分界表の `| **リリース準備** | ... release-prep.sh --check に配線） | ...`）が
  #     切り出しに混ざらないこと。この行こそがファイル全体 grep を恒真にする張本人で、
  #     混ざるなら (c) は「表に書いてあるだけ」を PASS にしてしまう。
  if grep -qF '**リリース準備**' "$_T81_RELDOC" && ! grep -qF '**リリース準備**' "$_T81_SECT"; then
    t81_pass "ta-81 TC-12b: positive control — 分界表の行（節外）は切り出しに含まれない"
  else
    t81_fail "ta-81 TC-12b: 節の限定が効いていない = TC-12c はファイル全体 grep と同義（恒真）"
  fi

  # (c) 本体: 必須検証手順の中で release-prep.sh --check を実行している
  if grep -qF 'scripts/release-prep.sh --check' "$_T81_SECT"; then
    t81_pass "ta-81 TC-12c: 必須検証手順に release-prep.sh --check のステップがある"
  else
    t81_fail "ta-81 TC-12c: 必須検証手順に release-prep.sh --check が無い — ゲートが手順から呼ばれない (#1292 major-2)"
  fi
else
  t81_fail "ta-81 TC-12: docs/release-process.md が見つかりません"
fi

# ---------------------------------------------------------------------------
# TC-13 / TC-14: release-prep の**準備経路**（`vX.Y.Z`）の rc と bump 実処理。
#   合成 root を組み、検査サブスクリプトはスタブに差し替える（本 TC が測るのは
#   release-prep 側の rc 伝播と bump の由来であって、各検査の中身ではない。
#   検査の中身は TC-02〜TC-11 が実測している）。
# ---------------------------------------------------------------------------
# $1 = 作る root / $2 = check-version-bump スタブが --bump で返す rc
_t81_mkprep() {
  _mk_root="$1"; _mk_bumprc="$2"
  rm -rf "$_mk_root"
  mkdir -p "$_mk_root/scripts" "$_mk_root/.claude-plugin" \
    "$_mk_root/plugin/plangate/.claude-plugin" "$_mk_root/plugin/plangate/.codex-plugin"
  cp "$_T81_RELPREP" "$_mk_root/scripts/release-prep.sh"
  cp "$_T81_PY" "$_mk_root/scripts/version_sites.py"
  printf '## Unreleased\n\n- 変更あり\n\n## v8.0.0 - 2026-01-01\n\n- 旧\n' \
    > "$_mk_root/CHANGELOG.md"
  printf '{\n  "name": "plangate",\n  "version": "8.21.0"\n}\n' \
    > "$_mk_root/plugin/plangate/.claude-plugin/plugin.json"
  printf '{\n  "name": "plangate",\n  "version": "8.21.0"\n}\n' \
    > "$_mk_root/plugin/plangate/.codex-plugin/plugin.json"
  printf '{\n  "metadata": {\n    "version": "8.21.0"\n  },\n  "plugins": [\n    {\n      "name": "plangate",\n      "version": "8.21.0"\n    }\n  ]\n}\n' \
    > "$_mk_root/.claude-plugin/marketplace.json"
  # check-version-bump スタブ: --parity は常に OK、--bump は指定 rc
  {
    printf '#!/bin/sh\n'
    printf 'for a in "$@"; do\n'
    printf '  [ "$a" = "--parity" ] && { echo "VERSION_PARITY_OK stub"; exit 0; }\n'
    printf 'done\n'
    printf 'echo "VERSION_BUMP_MISSING stub"\n'
    printf 'exit %s\n' "$_mk_bumprc"
  } > "$_mk_root/scripts/check-version-bump.sh"
  printf '#!/bin/sh\necho "manifest parity stub OK"\nexit 0\n' \
    > "$_mk_root/scripts/check-plugin-manifest-parity.sh"
  printf '#!/bin/sh\necho "no-op"\nexit 0\n' > "$_mk_root/scripts/sync-release-docs.sh"
  printf '#!/bin/sh\necho "no-op"\nexit 0\n' > "$_mk_root/scripts/sync-plugin-installed.sh"
  # apply-*.sh は置かない（= 適用待ちなし）
}

# TC-13a: NOT READY のとき準備経路が rc≠0 で終わる（fail-open ラッパの回帰検出）
_T81_PREP_NG="$_T81_TMP/prep-ng"
_t81_mkprep "$_T81_PREP_NG" 1
_t81_rc=0
_t81_out=$(sh "$_T81_PREP_NG/scripts/release-prep.sh" v9.9.9 2>&1) || _t81_rc=$?
if [ "$_t81_rc" != "0" ] && printf '%s' "$_t81_out" | grep -q 'NOT READY'; then
  t81_pass "ta-81 TC-13a: 準備経路は NOT READY を rc=$_t81_rc で返す（fail-open ではない / #1292 major-3）"
else
  t81_fail "ta-81 TC-13a: NOT READY なのに rc=$_t81_rc — 準備経路が fail-open (out=$_t81_out)"
fi

# TC-13b: rc は保持するが「次: …」の案内は出す（是正の意図そのもの）
if printf '%s' "$_t81_out" | grep -q '^次: '; then
  t81_pass "ta-81 TC-13b: NOT READY でも次アクションの案内は出力される"
else
  t81_fail "ta-81 TC-13b: 案内が失われた（rc 保持のために出力を削っている）"
fi

# TC-13c positive control: 同じ形で全検査が緑なら rc=0 + READY
#   （TC-13a が「準備経路は常に rc≠0」の恒真ゲートに退行していないことを実測）
_T81_PREP_OK="$_T81_TMP/prep-ok"
_t81_mkprep "$_T81_PREP_OK" 0
_t81_rc=0
_t81_out=$(sh "$_T81_PREP_OK/scripts/release-prep.sh" v9.9.9 2>&1) || _t81_rc=$?
if [ "$_t81_rc" = "0" ] && printf '%s' "$_t81_out" | grep -q '^READY$'; then
  t81_pass "ta-81 TC-13c: positive control — 全検査 OK なら rc=0 READY（TC-13a は恒真でない）"
else
  t81_fail "ta-81 TC-13c: 検査が全て OK なのに rc=$_t81_rc (out=$_t81_out)"
fi

# ---------------------------------------------------------------------------
# TC-14: bump 実処理が **DECLARED_SITES 由来**であること（#1292 major-1）。
#   旧実装は release-prep 側に 3 ファイルを決め打ちしていたため、宣言テーブルに
#   5 番目を足しても bump されず、`--parity` は rc=0 なのにリリース準備の最中に
#   初めて VERSION_PARITY_MISMATCH になった。doc の「更新するのは DECLARED_SITES
#   （と本表）だけでよい」という主張と実装が食い違っていた。
# ---------------------------------------------------------------------------
_T81_PREP5="$_T81_TMP/prep-fifth"
_t81_mkprep "$_T81_PREP5" 0
# (1) 宣言テーブルに 5 番目を足す（doc が「これだけでよい」と言う操作）
mkdir -p "$_T81_PREP5/plugin/fifth/.claude-plugin"
printf '{\n  "name": "fifth",\n  "version": "8.21.0"\n}\n' \
  > "$_T81_PREP5/plugin/fifth/.claude-plugin/plugin.json"
# (2) 宣言テーブル**外**の manifest も置く（bump が「見つけた JSON を全部」で
#     ないこと = 宣言由来であることの negative control）
mkdir -p "$_T81_PREP5/plugin/undeclared/.claude-plugin"
printf '{\n  "name": "undeclared",\n  "version": "8.21.0"\n}\n' \
  > "$_T81_PREP5/plugin/undeclared/.claude-plugin/plugin.json"
_t81_declared_patched=0
python3 - "$_T81_PREP5" <<'PYDECL' && _t81_declared_patched=1
import sys
p = sys.argv[1] + "/scripts/version_sites.py"
s = open(p, encoding="utf-8").read()
anchor = '    ("plugin.codex", "plugin/plangate/.codex-plugin/plugin.json", "version"),\n'
if anchor not in s:
    raise SystemExit("anchor-not-found")
s = s.replace(anchor, anchor + '    ("plugin.fifth", "plugin/fifth/.claude-plugin/plugin.json", "version"),\n', 1)
open(p, "w", encoding="utf-8").write(s)
PYDECL
if [ "$_t81_declared_patched" != "1" ]; then
  t81_fail "ta-81 TC-14: 宣言テーブルへの変異注入が空振り（DECLARED_SITES の形が変わった）"
else
  _t81_before5=$(python3 - "$_T81_PREP5" <<'PYV'
import json, sys
print(json.load(open(sys.argv[1] + "/plugin/fifth/.claude-plugin/plugin.json"))["version"])
PYV
)
  _t81_rc=0
  _t81_out=$(sh "$_T81_PREP5/scripts/release-prep.sh" v9.9.9 2>&1) || _t81_rc=$?
  _t81_after5=$(python3 - "$_T81_PREP5" <<'PYV'
import json, sys
print(json.load(open(sys.argv[1] + "/plugin/fifth/.claude-plugin/plugin.json"))["version"])
PYV
)
  _t81_undecl=$(python3 - "$_T81_PREP5" <<'PYV'
import json, sys
print(json.load(open(sys.argv[1] + "/plugin/undeclared/.claude-plugin/plugin.json"))["version"])
PYV
)
  # (a) 宣言を足しただけで 5 番目が bump される
  if [ "$_t81_before5" != "9.9.9" ] && [ "$_t81_after5" = "9.9.9" ] &&
     printf '%s' "$_t81_out" | grep -q 'VERSION_SET_SITE plugin.fifth'; then
    t81_pass "ta-81 TC-14a: DECLARED_SITES に足しただけで 5 番目の manifest も bump（$_t81_before5 -> ${_t81_after5}）"
  else
    t81_fail "ta-81 TC-14a: 宣言済みの manifest が bump されない（before=$_t81_before5 after=$_t81_after5 rc=$_t81_rc out=$_t81_out）"
  fi
  # (b) negative control: 宣言していない manifest は触らない
  if [ "$_t81_undecl" = "8.21.0" ]; then
    t81_pass "ta-81 TC-14b: negative control — 未宣言 manifest は bump されない（宣言由来であることの確認）"
  else
    t81_fail "ta-81 TC-14b: 未宣言 manifest まで書き換えている（${_t81_undecl}）"
  fi
  # (c) bump 後に parity が保たれる（#1292 major-1 の実害そのもの）
  _t81_rc=0
  _t81_out=$(python3 "$_T81_PREP5/scripts/version_sites.py" parity --root "$_T81_PREP5" 2>&1) || _t81_rc=$?
  if [ "$_t81_rc" = "0" ] && printf '%s' "$_t81_out" | grep -q 'VERSION_PARITY_OK 9.9.9'; then
    t81_pass "ta-81 TC-14c: 準備実行の後に宣言箇所が全て同値（MISMATCH が出ない）"
  else
    t81_fail "ta-81 TC-14c: 準備実行の後に VERSION_PARITY_MISMATCH (rc=$_t81_rc out=$_t81_out)"
  fi
fi

# TC-14d: 実装側が宣言テーブル由来であることを構造で見る（決め打ち復活の検出）
if grep -q 'version_sites.py" set --value' "$_T81_RELPREP"; then
  t81_pass "ta-81 TC-14d: release-prep の bump が version_sites.py set 経由（決め打ちでない）"
else
  t81_fail "ta-81 TC-14d: release-prep の bump が宣言テーブル由来でない — doc の主張と食い違う"
fi
# positive control: 実在しない呼び出し形は当然ヒットしない
if grep -q 'version_sites.py" set --nonexistent-flag' "$_T81_RELPREP"; then
  t81_fail "ta-81 TC-14e: positive control 失敗 — 実在しない呼び出し形がヒットした"
else
  t81_pass "ta-81 TC-14e: positive control — 未使用の呼び出し形は確かに未ヒット"
fi

# 明示 cleanup（trap 非依存 / README 規約 1・2）
rm -rf "$_T81_TMP"

fi  # _T81_OK

pg_extra_contract_finalize
