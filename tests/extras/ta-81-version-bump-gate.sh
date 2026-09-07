# tests/extras/ta-81-version-bump-gate.sh
# PG_EXTRA_CAPABILITY: standalone-capable
# Sourced by tests/run-tests.sh — uses $pass / $fail counters
#
# #1257: version bump ゲート。
#
# 背景（issue #1257 実測 / origin/main = ecfef5b）:
#   `/plugin update` は version が変わらなければ no-op。version を bump しない限り
#   配布系 PR を何本マージしても consumer には 1 件も届かない。実測では 45 commits /
#   配布系 PR 9 本が未配布のまま宣言 version は据え置きの 8.21.0 で、しかも同じ
#   `8.21.0` を名乗る payload が 3 種類（Claude Aug 20 / Codex Aug 26 / main Aug 27）
#   存在した。**version 文字列は同一性を保証していなかった。**
#
# 本ファイルが測る 2 つのゲート（受入基準 1 / 2）:
#   (a) bump   — plugin/plangate/** に差分がある range で version が bump されているか
#   (b) parity — version 宣言箇所（実測 4 箇所）が全て同値か
#
# 設計上の要点:
#   - **宣言テーブルの網羅性を別 TC で担保する**（TC-03）。宣言は
#     scripts/_version_sites.py の DECLARED_SITES にハードコードされているが、
#     manifest の実走査（discovered）との**同値照合**で「5 箇所目が増えたのに
#     検査から漏れる」を検出する。宣言側にしか無い（= stale）も同時に見る
#   - **絶対件数を書かない**。宣言 4 箇所は「4」という契約値ではなく
#     declared / discovered の**集合が一致すること**として検査する（README P-6 /
#     成長する対象に assertEqual N を置かない）
#   - **positive control を全ての「0 件が期待値」検査に入れる**（TC-03b / TC-03c /
#     TC-04 / TC-06）。検査器が恒真に退行していないことを同 TC 内で実測する
#   - PASS 判定は **rc と分岐固有 reason トークンの対**（README P-1 / P-3）
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
_T81_PY="$_T81_ROOT/scripts/_version_sites.py"
_T81_WF="$_T81_ROOT/.github/workflows/test.yml"
_T81_PATCHDOC="$_T81_ROOT/docs/working/_reports/1257-ci-fetch-depth-patch-applicable.md"
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
if [ "$_t81_rc" = "2" ] && printf '%s' "$_t81_out" | grep -q -- '--bump には --base が必須です'; then
  t81_pass "ta-81 TC-01b: --bump without --base -> rc=2 (usage error)"
else
  t81_fail "ta-81 TC-01b: expected rc=2 + usage diagnostic (rc=$_t81_rc out=$_t81_out)"
fi

# ---------------------------------------------------------------------------
# TC-02: 実 repo の parity（受入基準 2）— rc=0 + VERSION_PARITY_OK
# ---------------------------------------------------------------------------
_t81_rc=0
_t81_out=$(sh "$_T81_SH" --parity --root "$_T81_ROOT" 2>&1) || _t81_rc=$?
if [ "$_t81_rc" = "0" ] && printf '%s' "$_t81_out" | grep -q 'VERSION_PARITY_OK'; then
  t81_pass "ta-81 TC-02: 実 repo の version 宣言箇所が全て同値 ($(printf '%s' "$_t81_out" | sed -n 's/.*VERSION_PARITY_OK //p'))"
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
rm -rf "$_T81_SB"
mkdir -p "$_T81_SB"
( cd "$_T81_ROOT" && tar cf - .claude-plugin/marketplace.json \
    plugin/plangate/.claude-plugin/plugin.json \
    plugin/plangate/.codex-plugin/plugin.json ) | ( cd "$_T81_SB" && tar xf - )
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
  rm -rf "$_T81_MUT"
  mkdir -p "$_T81_MUT"
  ( cd "$_T81_ROOT" && tar cf - .claude-plugin/marketplace.json \
      plugin/plangate/.claude-plugin/plugin.json \
      plugin/plangate/.codex-plugin/plugin.json ) | ( cd "$_T81_MUT" && tar xf - )
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
# TC-07: CI 有効化状態の宣言（ta-79 と同型の pending-flag 方式）
#   ゲートの存在は「効いている証拠」ではない。actions/checkout が既定の
#   fetch-depth: 1 のままだと base が解決できず rc=3 になり、CI では働かない。
# ---------------------------------------------------------------------------
_t81_depth0=0
if [ -f "$_T81_WF" ] && grep -q 'fetch-depth: *0' "$_T81_WF"; then
  _t81_depth0=1
fi
if [ "$_t81_depth0" = "1" ] && [ -f "$_T81_PATCHDOC" ]; then
  t81_fail "ta-81 TC-07: stale 宣言 — test.yml は fetch-depth: 0 済みなのに pending patch doc が残っている: $_T81_PATCHDOC"
elif [ "$_t81_depth0" = "1" ]; then
  t81_pass "ta-81 TC-07: CI 有効（test.yml fetch-depth: 0）— bump ゲートが PR base を解決できる"
elif [ -f "$_T81_PATCHDOC" ]; then
  # 既知 gap は「patch が実際に当たること」まで実測する（提示だけで満足しない）
  _t81_patch="$_T81_TMP/ci.patch"
  awk '/PG-PATCH-BEGIN/{f=1;next} /PG-PATCH-END/{f=0} f' "$_T81_PATCHDOC" | grep -v '^```' > "$_t81_patch"
  _t81_rc=0
  _t81_out=$(git -C "$_T81_ROOT" apply --check "$_t81_patch" 2>&1) || _t81_rc=$?
  if [ "$_t81_rc" = "0" ]; then
    t81_pass "ta-81 TC-07: CI 未有効だが gap は明示宣言済みで、patch は git apply --check を通る（適用は Human-owned）"
  else
    t81_fail "ta-81 TC-07: pending patch が当たらない (rc=$_t81_rc out=$_t81_out)"
  fi
else
  t81_fail "ta-81 TC-07: CI 未有効（test.yml に fetch-depth: 0 なし）かつ gap 宣言も無い — #1257 AC-1 が黙って未達になる"
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
# TC-09: **実 PR / 実ブランチそのもの**に対する bump ゲート（受入基準 1 の本体）
#   TC-05 / TC-06 は「検出器が動くこと」の証明で、これが無いと *今の変更* は
#   1 度も検査されない（ゲートを持っているだけで働かない状態）。
#   base が解決できないとき（shallow clone）は pass にも fail にも数えず、
#   「検査していない」ことを明示する — rc=0 で成功を装わない。
# ---------------------------------------------------------------------------
_t81_base_ref=""
for _t81_cand in \
  "${PLANGATE_VERSION_BUMP_BASE:-}" \
  "${GITHUB_BASE_REF:+origin/$GITHUB_BASE_REF}" \
  "origin/main" "main"; do
  [ -n "$_t81_cand" ] || continue
  if git -C "$_T81_ROOT" rev-parse --verify --quiet "$_t81_cand^{commit}" >/dev/null 2>&1; then
    _t81_base_ref="$_t81_cand"
    break
  fi
done
if [ -n "$_t81_base_ref" ]; then
  _t81_rc=0
  _t81_out=$(sh "$_T81_SH" --bump --base "$_t81_base_ref" --head HEAD --root "$_T81_ROOT" 2>&1) || _t81_rc=$?
  case "$_t81_rc" in
    0)
      if printf '%s' "$_t81_out" | grep -q 'VERSION_BUMP_OK_NO_PLUGIN_DIFF\|VERSION_BUMP_OK_BUMPED'; then
        t81_pass "ta-81 TC-09: 実ブランチ（base=${_t81_base_ref}）は version bump 契約を満たす"
      else
        t81_fail "ta-81 TC-09: rc=0 だが既知 reason トークンが無い (out=$_t81_out)"
      fi
      ;;
    3)
      t81_info "ta-81 TC-09: base=${_t81_base_ref} を解決したが range 検査不能 — 未検査 ($_t81_out)"
      ;;
    *)
      t81_fail "ta-81 TC-09: 実ブランチが version bump 契約に違反 (rc=$_t81_rc)
$_t81_out"
      ;;
  esac
else
  t81_info "ta-81 TC-09: base ref 未解決（shallow clone 等）— 実ブランチの bump ゲートは未実行。CI で有効化するには test.yml の fetch-depth: 0 が要る（TC-07 参照）"
fi

# 明示 cleanup（trap 非依存 / README 規約 1・2）
rm -rf "$_T81_TMP"

fi  # _T81_OK

pg_extra_contract_finalize
