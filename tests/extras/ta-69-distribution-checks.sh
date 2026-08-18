# tests/extras/ta-69-distribution-checks.sh
# PG_EXTRA_CAPABILITY: standalone-capable
# Sourced by tests/run-tests.sh -- uses $pass / $fail counters
# Issue #1087: 配布物検査 2 本（name collisions / stale refs）の分類境界
#
# Sandbox: 検査スクリプトを tmp の <sandbox>/scripts/ にコピーすることで
# スクリプト自身の REPO_ROOT 解決（__file__/../..）がサンドボックスを指す。
# これにより **引数なしの既定経路**（本番 CI が通る経路）を検証できる。
# `--extra-root` 等のテスト専用引数に負側 TC を偏らせない（#1087 AC / diff-audit P6-7）。
#
# 件数契約の禁止（#1087 AC-9）: 本番ツリーの件数（46 / 7 等）を assert しない。
# 「true collision = 0」「stale = 0」「注入した違反が出力に含まれる」で契約する。
#
# ---------------------------------------------------------------------------
# set -e 安全性（#1087 / PR #1149 の CI FAIL 是正）
# ---------------------------------------------------------------------------
# run-tests.sh は `set -eu` で動き、extras を **source** する。初版は rc を
#     ( cd "$D" && python3 x.py >/dev/null 2>&1; echo $? )
# で捕捉していたが、これは set -e 下で壊れる:
#   python3 が rc=1 を返す → `cd && python3` の AND-list が失敗 → set -e が
#   **`echo $?` に到達する前にサブシェルを終了** → 捕捉値が **空文字**になる。
#   結果 `[ "" = "1" ]` が偽となり、**rc=1 を期待する TC が全滅**する一方、
#   `[ "0" = "0" ]` は真なので **rc=0 を期待する TC は（空の sandbox でも）通る**。
#   さらに素の代入で使うと set -e が **ハーネス全体を中断**する。
#
# したがって本ファイルでは以下を不変条件とする:
#   (1) rc 捕捉は必ず `_t69_rc_of`（OR-list 形式）を通す
#   (2) sandbox への注入は **前提条件として明示検証**する（_t69_assert_defs /
#       _t69_assert_probe）。注入が silently 失敗すると検査器は「違反なし」で
#       rc=0 を返し、**TC が緑になってしまう**ため
#   (3) (2) の検出力そのものを TC-G1 / TC-G2 で実証する

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
pg_extra_contract_init ta-69-distribution-checks standalone-capable

printf '\n=== TA-69: distribution checks classification (#1087) ===\n'

if [ "${PG_HARNESS_SOURCED:-0}" = "1" ] && [ -n "${FIXTURES_DIR:-}" ]; then
  _T69_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
else
  unset PLANGATE_SKIP_REASON PLANGATE_HOOK_TASK PLANGATE_HOOK_FILE PLANGATE_BYPASS_HOOK PLANGATE_HOOK_STRICT PG_HARNESS_SOURCED PLANGATE_ALLOW_MASS_DELETE 2>/dev/null || true
  _T69_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
fi

t69_pass() { pass=$((pass + 1)); printf '  [PASS] %s\n' "$1"; }
t69_fail() { fail=$((fail + 1)); printf '  [FAIL] %s\n' "$1" >&2; }

# set -e 安全な rc 捕捉。$1=作業ディレクトリ、$2 以降=実行するコマンド。
# OR-list（`... || rc=$?`）にすることで set -e の対象外にする。
_t69_rc_of() {
  _t69_rc_dir="$1"
  shift
  _t69_rc_val=0
  ( CDPATH= cd -- "$_t69_rc_dir" && "$@" >/dev/null 2>&1 ) || _t69_rc_val=$?
  printf '%s' "$_t69_rc_val"
}

# set -e 安全な stdout 捕捉。
_t69_out_of() {
  _t69_out_dir="$1"
  shift
  ( CDPATH= cd -- "$_t69_out_dir" && "$@" 2>&1 ) || true
}

_T69_COLL_SRC="$_T69_ROOT/scripts/check-skill-name-collisions.py"
_T69_STALE_SRC="$_T69_ROOT/scripts/check-stale-skill-refs.py"

if [ ! -f "$_T69_COLL_SRC" ] || [ ! -f "$_T69_STALE_SRC" ]; then
  pg_extra_contract_skip "distribution check scripts not found"
  return 0 2>/dev/null || exit 3
fi

# ===========================================================================
# Part 1: check-skill-name-collisions.py の分類境界
# ===========================================================================

_T69_C=$(mktemp -d)
if command -v register_cleanup >/dev/null 2>&1; then register_cleanup "$_T69_C"; fi
mkdir -p "$_T69_C/scripts"
cp "$_T69_COLL_SRC" "$_T69_C/scripts/check-skill-name-collisions.py"

# サンドボックスに skill 定義を 1 つ置く: $1=相対ルート $2=ディレクトリ名 $3=name $4=description
# 失敗は握り潰さず、呼び出し側が前提条件検証で必ず気付けるようにする。
_t69_skill() {
  mkdir -p "$_T69_C/$1/$2" || return 1
  printf -- '---\nname: %s\ndescription: %s\n---\n# %s\n' "$3" "$4" "$3" \
    > "$_T69_C/$1/$2/SKILL.md" || return 1
  [ -s "$_T69_C/$1/$2/SKILL.md" ] || return 1
  return 0
}

# サンドボックス内の SKILL.md 実数を数える（注入が本当に成立したかの前提条件）。
# 一時ディレクトリ内の「今まさに自分で作った数」なので、成長するディレクトリへの
# 件数 assert（時限爆弾）には当たらない。
_t69_count_defs() {
  find "$_T69_C/.claude" "$_T69_C/plugin" -name SKILL.md 2>/dev/null | wc -l | tr -d ' '
}

# 注入が期待どおり成立したかを検証する。不成立なら **明示的に FAIL** させる。
# これが無いと、注入失敗時に検査器が「違反なし」で rc=0 を返し TC が緑になる。
_t69_assert_defs() {
  _t69_ad_want="$1"
  _t69_ad_label="$2"
  _t69_ad_got=$(_t69_count_defs)
  if [ "$_t69_ad_got" != "$_t69_ad_want" ]; then
    t69_fail "$_t69_ad_label: sandbox injection failed (SKILL.md want=$_t69_ad_want got=$_t69_ad_got)"
    return 1
  fi
  return 0
}

# 既定経路（引数なし）で実行する
_t69_coll_rc()  { _t69_rc_of "$_T69_C" python3 scripts/check-skill-name-collisions.py; }
_t69_coll_run() { _t69_out_of "$_T69_C" python3 scripts/check-skill-name-collisions.py; }

_t69_reset_coll() { rm -rf "$_T69_C/.claude" "$_T69_C/plugin" 2>/dev/null || true; }

# --- TC-G1: 前提条件カウンタが「注入されていない状態」を検出できる ---
# sandbox 構築失敗が silently rc=0（緑）に化けないことの土台。
_t69_reset_coll
_t69_g1=$(_t69_count_defs)
if [ "$_t69_g1" = "0" ]; then
  t69_pass "TC-G1: precondition counter sees an empty sandbox as 0 defs"
else
  t69_fail "TC-G1: expected 0 defs in a reset sandbox, got $_t69_g1"
fi

# --- TC-G2: 注入失敗が [FAIL] として顕在化することの実証 ---
# t69_fail をサブシェル内で差し替え、_t69_assert_defs が実際に発火するか見る。
_t69_reset_coll
_t69_g2=$( t69_fail() { printf 'GUARD_FIRED\n'; }; _t69_assert_defs 3 "probe" || true )
if printf '%s' "$_t69_g2" | grep -q 'GUARD_FIRED'; then
  t69_pass "TC-G2: a failed injection surfaces as an explicit [FAIL], not a silent rc=0"
else
  t69_fail "TC-G2: expected the precondition guard to fire on a failed injection"
fi

# --- TC-C9: 単一定義のみ -> 多重定義ではない -> rc=0 ---
_t69_reset_coll
_t69_skill ".claude/skills" "solo" "solo" "only one" || true
if _t69_assert_defs 1 "TC-C9"; then
  if [ "$(_t69_coll_rc)" = "0" ]; then
    t69_pass "TC-C9: single definition -> rc=0"
  else
    t69_fail "TC-C9: expected rc=0 for a single definition, got $(_t69_coll_rc)"
  fi
fi

# --- TC-C3: repo-local <-> plugin のミラー（root 内相対パス一致）-> rc=0 ---
_t69_reset_coll
_t69_skill ".claude/skills" "mirrored" "mirrored" "same text" || true
_t69_skill "plugin/pa/skills" "mirrored" "mirrored" "same text" || true
if _t69_assert_defs 2 "TC-C3"; then
  if [ "$(_t69_coll_rc)" = "0" ]; then
    t69_pass "TC-C3: repo-local <-> plugin mirror -> rc=0 (accepted)"
  else
    t69_fail "TC-C3: expected rc=0 for an export mirror pair, got $(_t69_coll_rc)"
  fi
fi

# --- TC-C2: ミラーは出力から消えず INFO として印字される ---
if _t69_coll_run | grep -q 'INFO:'; then
  t69_pass "TC-C2: mirrors are reported as INFO (not silently dropped)"
else
  t69_fail "TC-C2: expected mirrors to be printed as INFO"
fi

# --- TC-C8: ミラーだが description が異なる -> rc=0（M-1）---
_t69_reset_coll
_t69_skill ".claude/skills" "drifted" "drifted" "repo side text" || true
_t69_skill "plugin/pa/skills" "drifted" "drifted" "plugin side text" || true
if _t69_assert_defs 2 "TC-C8"; then
  if [ "$(_t69_coll_rc)" = "0" ]; then
    t69_pass "TC-C8: mirror with description drift -> rc=0"
  else
    t69_fail "TC-C8: expected rc=0 for a mirror with description drift, got $(_t69_coll_rc)"
  fi
fi

# --- TC-C4: 3 定義（repo-local + plugin-a + plugin-b）-> rc=1（#692 動機ケース）---
_t69_reset_coll
_t69_skill ".claude/skills" "triple" "triple" "t" || true
_t69_skill "plugin/pa/skills" "triple" "triple" "t" || true
_t69_skill "plugin/pb/skills" "triple" "triple" "t" || true
if _t69_assert_defs 3 "TC-C4"; then
  if [ "$(_t69_coll_rc)" = "1" ] && _t69_coll_run | grep -q 'triple'; then
    t69_pass "TC-C4: 3 definitions -> rc=1 (true collision)"
  else
    t69_fail "TC-C4: expected rc=1 for 3 definitions of one name, got $(_t69_coll_rc)"
  fi
fi

# --- TC-C5: plugin 同士のみの同名（repo-local 無し）-> rc=1 ---
_t69_reset_coll
_t69_skill "plugin/pa/skills" "pclash" "pclash" "a" || true
_t69_skill "plugin/pb/skills" "pclash" "pclash" "b" || true
if _t69_assert_defs 2 "TC-C5"; then
  if [ "$(_t69_coll_rc)" = "1" ] && _t69_coll_run | grep -q 'pclash'; then
    t69_pass "TC-C5: plugin-vs-plugin same name -> rc=1"
  else
    t69_fail "TC-C5: expected rc=1 for plugin-vs-plugin collision, got $(_t69_coll_rc)"
  fi
fi

# --- TC-C6: 非ミラー位置での同名 -> rc=1 ---
_t69_reset_coll
_t69_skill ".claude/skills" "here" "shifted" "repo side" || true
_t69_skill "plugin/pa/skills" "elsewhere" "shifted" "plugin side" || true
if _t69_assert_defs 2 "TC-C6"; then
  if [ "$(_t69_coll_rc)" = "1" ] && _t69_coll_run | grep -q 'shifted'; then
    t69_pass "TC-C6: same name at non-mirrored paths -> rc=1"
  else
    t69_fail "TC-C6: expected rc=1 for a non-mirrored same-name pair, got $(_t69_coll_rc)"
  fi
fi

# --- TC-C7: 同一 root 内の重複 -> rc=1（#1087 で新規に検出可能）---
_t69_reset_coll
_t69_skill ".claude/skills" "dup-a" "dup" "A" || true
_t69_skill ".claude/skills" "dup-b" "dup" "B" || true
if _t69_assert_defs 2 "TC-C7"; then
  if [ "$(_t69_coll_rc)" = "1" ] && _t69_coll_run | grep -q 'dup'; then
    t69_pass "TC-C7: same-root duplicate name -> rc=1 (newly detectable)"
  else
    t69_fail "TC-C7: expected rc=1 for a same-root duplicate, got $(_t69_coll_rc)"
  fi
fi

# --- TC-C1: 本番ツリー（引数なし既定経路）-> rc=0 かつ true collision 0 件 ---
_t69_c1_rc=$(_t69_rc_of "$_T69_ROOT" python3 scripts/check-skill-name-collisions.py)
if [ "$_t69_c1_rc" = "0" ]; then
  t69_pass "TC-C1: production tree -> rc=0 (no true collision)"
else
  t69_fail "TC-C1: expected rc=0 on the production tree, got $_t69_c1_rc"
fi

rm -rf "$_T69_C" 2>/dev/null || true

# ===========================================================================
# Part 2: check-stale-skill-refs.py の分類境界
# ===========================================================================

_T69_S=$(mktemp -d)
if command -v register_cleanup >/dev/null 2>&1; then register_cleanup "$_T69_S"; fi
mkdir -p "$_T69_S/scripts" "$_T69_S/.claude/skills/probe" "$_T69_S/docs"
cp "$_T69_STALE_SRC" "$_T69_S/scripts/check-stale-skill-refs.py"
printf 'placeholder\n' > "$_T69_S/docs/real-target.md"

# gitignore 除外を検証するにはサンドボックスが git repo である必要がある。
# 失敗を握り潰すと TC-S7 の前提が崩れたまま緑になるため、成否を検証する。
_t69_git_ok=1
( CDPATH= cd -- "$_T69_S" && git init -q . ) >/dev/null 2>&1 || _t69_git_ok=0
printf '.claude/settings.json\n' > "$_T69_S/.gitignore" 2>/dev/null || _t69_git_ok=0
[ -d "$_T69_S/.git" ] && [ -s "$_T69_S/.gitignore" ] || _t69_git_ok=0
if [ "$_t69_git_ok" = "1" ]; then
  t69_pass "TC-G3: stale sandbox is a git repo with a .gitignore (TC-S7 precondition holds)"
else
  t69_fail "TC-G3: stale sandbox git setup failed — TC-S7/S8 verdicts would be meaningless"
fi

# probe ファイルを書く。書けなければ後続 TC の前提が無いので明示的に失敗させる。
_t69_probe() {
  printf '%s\n' "$1" > "$_T69_S/.claude/skills/probe/SKILL.md" || return 1
  [ -s "$_T69_S/.claude/skills/probe/SKILL.md" ] || return 1
  return 0
}
_t69_assert_probe() {
  if ! _t69_probe "$1"; then
    t69_fail "$2: sandbox probe write failed"
    return 1
  fi
  return 0
}

_t69_stale_run() { _t69_out_of "$_T69_S" python3 scripts/check-stale-skill-refs.py; }
_t69_stale_rc()  { _t69_rc_of  "$_T69_S" python3 scripts/check-stale-skill-refs.py; }

# --- TC-S4: 実在しないパスへの通常の Markdown リンク -> WARN（真の stale）---
if _t69_assert_probe 'see [x](docs/no-such-file-1087.md) here' "TC-S4"; then
  if [ "$(_t69_stale_rc)" = "1" ] && _t69_stale_run | grep -q 'no-such-file-1087.md'; then
    t69_pass "TC-S4: real stale markdown link -> rc=1"
  else
    t69_fail "TC-S4: expected rc=1 for a genuinely stale markdown link, got $(_t69_stale_rc)"
  fi
fi

# --- TC-S5: 実在しないパスへのインラインコード参照 -> WARN ---
if _t69_assert_probe 'run `scripts/no-such-script-1087.py` now' "TC-S5"; then
  if [ "$(_t69_stale_rc)" = "1" ] && _t69_stale_run | grep -q 'no-such-script-1087.py'; then
    t69_pass "TC-S5: real stale inline-code path -> rc=1"
  else
    t69_fail "TC-S5: expected rc=1 for a stale inline-code path, got $(_t69_stale_rc)"
  fi
fi

# --- TC-S6: コードスパン内のリンク記法 -> WARN されない（S-1）---
if _t69_assert_probe '`` `[file.md](./file.md)` `` 形式でリンク化し' "TC-S6"; then
  if [ "$(_t69_stale_rc)" = "0" ]; then
    t69_pass "TC-S6: link notation inside a code span -> not a reference"
  else
    t69_fail "TC-S6: expected rc=0 for link notation inside a code span, got $(_t69_stale_rc)"
  fi
fi

# --- 既存挙動の維持: 実在するパスへのリンクは WARN されない ---
if _t69_assert_probe 'see [ok](docs/real-target.md)' "TC-S6b"; then
  if [ "$(_t69_stale_rc)" = "0" ]; then
    t69_pass "TC-S6b: link to an existing path -> rc=0"
  else
    t69_fail "TC-S6b: expected rc=0 for a link to an existing path, got $(_t69_stale_rc)"
  fi
fi

# --- TC-S7: gitignore 対象パス -> WARN されない（S-2）---
if _t69_assert_probe 'wire `.claude/settings.json` first' "TC-S7"; then
  if [ "$(_t69_stale_rc)" = "0" ] && _t69_stale_run | grep -q 'gitignore'; then
    t69_pass "TC-S7: gitignored path -> excluded and reported as INFO"
  else
    t69_fail "TC-S7: expected rc=0 + INFO for a gitignored path, got $(_t69_stale_rc)"
  fi
fi

# --- TC-S2/TC-S3: 判定が実行環境に依存しない ---
# 是正前は Path.exists() だけを見ていたため、gitignore 対象ファイルの
# 有無（CI = 無い / wiring 済み開発機 = 有る）で rc が変わっていた。
if _t69_assert_probe 'wire `.claude/settings.json` first' "TC-S2/S3"; then
  _t69_s2_rc=$(_t69_stale_rc)                       # settings.json が無い（CI 相当）
  mkdir -p "$_T69_S/.claude"
  printf '{}\n' > "$_T69_S/.claude/settings.json"
  _t69_s3_rc=$(_t69_stale_rc)                       # settings.json が有る（開発機相当）
  rm -f "$_T69_S/.claude/settings.json"
  if [ "$_t69_s2_rc" = "0" ] && [ "$_t69_s3_rc" = "0" ]; then
    t69_pass "TC-S2/S3: verdict is environment-independent (absent=$_t69_s2_rc present=$_t69_s3_rc)"
  else
    t69_fail "TC-S2/S3: expected rc=0 in both, got absent=$_t69_s2_rc present=$_t69_s3_rc"
  fi
fi

# --- TC-S8: ignore パターンに合致しない typo -> WARN される（除外が広すぎない）---
if _t69_assert_probe 'wire `.claude/settingz.json` first' "TC-S8"; then
  if [ "$(_t69_stale_rc)" = "1" ] && _t69_stale_run | grep -q 'settingz.json'; then
    t69_pass "TC-S8: typo near an ignored path is still detected"
  else
    t69_fail "TC-S8: expected rc=1 for a typo that no ignore pattern matches, got $(_t69_stale_rc)"
  fi
fi

# --- TC-S9: git 不在 -> 除外なしへ縮退（crash しない / 隠さない）---
_T69_PY="$(command -v python3 || true)"
if [ -z "$_T69_PY" ]; then
  t69_fail "TC-S9: python3 not resolvable via command -v"
elif _t69_assert_probe 'wire `.claude/settings.json` first' "TC-S9"; then
  _t69_nogit_rc=$(_t69_rc_of "$_T69_S" env PATH=/nonexistent-1087 "$_T69_PY" scripts/check-stale-skill-refs.py)
  if [ "$_t69_nogit_rc" = "1" ]; then
    t69_pass "TC-S9: without git -> degrades to no-exclusion (safe side, no crash)"
  else
    t69_fail "TC-S9: expected rc=1 (no exclusion) without git, got $_t69_nogit_rc"
  fi
fi

# --- TC-S1: 本番ツリー（引数なし既定経路）-> rc=0 ---
_t69_s1_rc=$(_t69_rc_of "$_T69_ROOT" python3 scripts/check-stale-skill-refs.py)
if [ "$_t69_s1_rc" = "0" ]; then
  t69_pass "TC-S1: production tree -> rc=0 (no stale refs)"
else
  t69_fail "TC-S1: expected rc=0 on the production tree, got $_t69_s1_rc"
fi

rm -rf "$_T69_S" 2>/dev/null || true

# ===========================================================================
# Part 3: 配布 root 間の追従漏れ（#1087 で実際に持ち込んだ退行の回帰ガード）
# ===========================================================================
#
# 背景: #1087 で `.claude/skills` の例示パスをプレースホルダへ移行した際、
# `.codex/skills` だけ追従が漏れた。stale-refs は `.claude/**` しか走査しない
# ため、この漏れは検査で緑のまま通った（#1109 と同型）。
#
# なぜ「4 root の内容一致」を assert しないか（実測 2026-08-18）:
#   .agents vs plugin : 39/39 一致（sync-plugin-plangate.sh が生成。CI が担保）
#   .agents vs .codex : 39 中 26 が **正当に相違**
#   .agents vs .claude: 24 中  8 が **正当に相違**
# 各 root は配布先ごとの適応を持つため、内容一致は不変条件として成立しない。
# 件数 assert も同様に時限爆弾になる（root ごとに skill 数が増減する）。
#
# 代わりに「移行済みの具体例パスがどの root にも残っていない」という
# **固定リテラルのゼロ集合**を assert する。増減する母集団に依存しない。

_T69_LEGACY_LITERAL='app/admin` 配下で'
_t69_roots_present=''
for _r in .agents/skills .claude/skills .codex/skills plugin/plangate/skills; do
  [ -d "$_T69_ROOT/$_r" ] && _t69_roots_present="$_t69_roots_present $_r"
done

if [ -z "$_t69_roots_present" ]; then
  t69_fail "TC-R1: no distribution skill root found (expected at least one)"
else
  _t69_leftover=$( CDPATH= cd -- "$_T69_ROOT" && grep -rl "$_T69_LEGACY_LITERAL" $_t69_roots_present 2>/dev/null || true )
  if [ -z "$_t69_leftover" ]; then
    t69_pass "TC-R1: migrated example path absent from all present roots ($_t69_roots_present )"
  else
    t69_fail "TC-R1: legacy example path still present in: $_t69_leftover"
  fi
fi

pg_extra_contract_finalize
