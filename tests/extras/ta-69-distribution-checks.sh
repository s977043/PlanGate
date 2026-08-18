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
_t69_skill() {
  mkdir -p "$_T69_C/$1/$2"
  printf -- '---\nname: %s\ndescription: %s\n---\n# %s\n' "$3" "$4" "$3" \
    > "$_T69_C/$1/$2/SKILL.md"
}

# 既定経路（引数なし）で実行する
_t69_coll_run() { ( cd "$_T69_C" && python3 scripts/check-skill-name-collisions.py 2>&1 ); }
_t69_coll_rc()  { ( cd "$_T69_C" && python3 scripts/check-skill-name-collisions.py >/dev/null 2>&1; echo $? ); }

_t69_reset_coll() { rm -rf "$_T69_C/.claude" "$_T69_C/plugin" 2>/dev/null || true; }

# --- TC-C9: 単一定義のみ -> 多重定義ではない -> rc=0 ---
_t69_reset_coll
_t69_skill ".claude/skills" "solo" "solo" "only one"
if [ "$(_t69_coll_rc)" = "0" ]; then
  t69_pass "TC-C9: single definition -> rc=0"
else
  t69_fail "TC-C9: expected rc=0 for a single definition"
fi

# --- TC-C3: repo-local <-> plugin のミラー（root 内相対パス一致）-> rc=0 ---
_t69_reset_coll
_t69_skill ".claude/skills" "mirrored" "mirrored" "same text"
_t69_skill "plugin/pa/skills" "mirrored" "mirrored" "same text"
if [ "$(_t69_coll_rc)" = "0" ]; then
  t69_pass "TC-C3: repo-local <-> plugin mirror -> rc=0 (accepted)"
else
  t69_fail "TC-C3: expected rc=0 for an export mirror pair"
fi

# --- TC-C2: ミラーは出力から消えず INFO として印字される ---
if _t69_coll_run | grep -q 'INFO:'; then
  t69_pass "TC-C2: mirrors are reported as INFO (not silently dropped)"
else
  t69_fail "TC-C2: expected mirrors to be printed as INFO"
fi

# --- TC-C8: ミラーだが description が異なる -> rc=0（M-1）---
_t69_reset_coll
_t69_skill ".claude/skills" "drifted" "drifted" "repo side text"
_t69_skill "plugin/pa/skills" "drifted" "drifted" "plugin side text"
if [ "$(_t69_coll_rc)" = "0" ]; then
  t69_pass "TC-C8: mirror with description drift -> rc=0"
else
  t69_fail "TC-C8: expected rc=0 for a mirror with description drift"
fi

# --- TC-C4: 3 定義（repo-local + plugin-a + plugin-b）-> rc=1（#692 動機ケース）---
_t69_reset_coll
_t69_skill ".claude/skills" "triple" "triple" "t"
_t69_skill "plugin/pa/skills" "triple" "triple" "t"
_t69_skill "plugin/pb/skills" "triple" "triple" "t"
if [ "$(_t69_coll_rc)" = "1" ] && _t69_coll_run | grep -q 'triple'; then
  t69_pass "TC-C4: 3 definitions -> rc=1 (true collision)"
else
  t69_fail "TC-C4: expected rc=1 for 3 definitions of one name"
fi

# --- TC-C5: plugin 同士のみの同名（repo-local 無し）-> rc=1 ---
_t69_reset_coll
_t69_skill "plugin/pa/skills" "pclash" "pclash" "a"
_t69_skill "plugin/pb/skills" "pclash" "pclash" "b"
if [ "$(_t69_coll_rc)" = "1" ] && _t69_coll_run | grep -q 'pclash'; then
  t69_pass "TC-C5: plugin-vs-plugin same name -> rc=1"
else
  t69_fail "TC-C5: expected rc=1 for plugin-vs-plugin collision"
fi

# --- TC-C6: 非ミラー位置での同名 -> rc=1 ---
_t69_reset_coll
_t69_skill ".claude/skills" "here" "shifted" "repo side"
_t69_skill "plugin/pa/skills" "elsewhere" "shifted" "plugin side"
if [ "$(_t69_coll_rc)" = "1" ] && _t69_coll_run | grep -q 'shifted'; then
  t69_pass "TC-C6: same name at non-mirrored paths -> rc=1"
else
  t69_fail "TC-C6: expected rc=1 for a non-mirrored same-name pair"
fi

# --- TC-C7: 同一 root 内の重複 -> rc=1（#1087 で新規に検出可能）---
_t69_reset_coll
_t69_skill ".claude/skills" "dup-a" "dup" "A"
_t69_skill ".claude/skills" "dup-b" "dup" "B"
if [ "$(_t69_coll_rc)" = "1" ] && _t69_coll_run | grep -q 'dup'; then
  t69_pass "TC-C7: same-root duplicate name -> rc=1 (newly detectable)"
else
  t69_fail "TC-C7: expected rc=1 for a same-root duplicate"
fi

# --- TC-C1: 本番ツリー（引数なし既定経路）-> rc=0 かつ true collision 0 件 ---
( cd "$_T69_ROOT" && python3 scripts/check-skill-name-collisions.py >/dev/null 2>&1 )
if [ "$?" = "0" ]; then
  t69_pass "TC-C1: production tree -> rc=0 (no true collision)"
else
  t69_fail "TC-C1: expected rc=0 on the production tree"
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

# gitignore 除外を検証するにはサンドボックスが git repo である必要がある
( cd "$_T69_S" && git init -q . && printf '.claude/settings.json\n' > .gitignore ) >/dev/null 2>&1

_t69_probe() { printf '%s\n' "$1" > "$_T69_S/.claude/skills/probe/SKILL.md"; }
_t69_stale_run() { ( cd "$_T69_S" && python3 scripts/check-stale-skill-refs.py 2>&1 ); }
_t69_stale_rc()  { ( cd "$_T69_S" && python3 scripts/check-stale-skill-refs.py >/dev/null 2>&1; echo $? ); }

# --- TC-S4: 実在しないパスへの通常の Markdown リンク -> WARN（真の stale）---
_t69_probe 'see [x](docs/no-such-file-1087.md) here'
if [ "$(_t69_stale_rc)" = "1" ] && _t69_stale_run | grep -q 'no-such-file-1087.md'; then
  t69_pass "TC-S4: real stale markdown link -> rc=1"
else
  t69_fail "TC-S4: expected rc=1 for a genuinely stale markdown link"
fi

# --- TC-S5: 実在しないパスへのインラインコード参照 -> WARN ---
_t69_probe 'run `scripts/no-such-script-1087.py` now'
if [ "$(_t69_stale_rc)" = "1" ] && _t69_stale_run | grep -q 'no-such-script-1087.py'; then
  t69_pass "TC-S5: real stale inline-code path -> rc=1"
else
  t69_fail "TC-S5: expected rc=1 for a stale inline-code path"
fi

# --- TC-S6: コードスパン内のリンク記法 -> WARN されない（S-1）---
_t69_probe '`` `[file.md](./file.md)` `` 形式でリンク化し'
if [ "$(_t69_stale_rc)" = "0" ]; then
  t69_pass "TC-S6: link notation inside a code span -> not a reference"
else
  t69_fail "TC-S6: expected rc=0 for link notation inside a code span"
fi

# --- 既存挙動の維持: 実在するパスへのリンクは WARN されない ---
_t69_probe 'see [ok](docs/real-target.md)'
if [ "$(_t69_stale_rc)" = "0" ]; then
  t69_pass "TC-S6b: link to an existing path -> rc=0"
else
  t69_fail "TC-S6b: expected rc=0 for a link to an existing path"
fi

# --- TC-S7: gitignore 対象パス -> WARN されない（S-2）---
_t69_probe 'wire `.claude/settings.json` first'
if [ "$(_t69_stale_rc)" = "0" ] && _t69_stale_run | grep -q 'gitignore'; then
  t69_pass "TC-S7: gitignored path -> excluded and reported as INFO"
else
  t69_fail "TC-S7: expected rc=0 + INFO for a gitignored path"
fi

# --- TC-S2/TC-S3: 判定が実行環境に依存しない ---
# 是正前は Path.exists() だけを見ていたため、gitignore 対象ファイルの
# 有無（CI = 無い / wiring 済み開発機 = 有る）で rc が変わっていた。
# 同じ入力で「無い環境」と「有る環境」の rc が一致することを実測する。
_t69_probe 'wire `.claude/settings.json` first'
_t69_s2_rc=$(_t69_stale_rc)                       # TC-S2: settings.json が無い（CI 相当）
mkdir -p "$_T69_S/.claude"
printf '{}\n' > "$_T69_S/.claude/settings.json"
_t69_s3_rc=$(_t69_stale_rc)                       # TC-S3: settings.json が有る（開発機相当）
rm -f "$_T69_S/.claude/settings.json"
if [ "$_t69_s2_rc" = "0" ] && [ "$_t69_s3_rc" = "0" ]; then
  t69_pass "TC-S2/S3: verdict is environment-independent (absent=$_t69_s2_rc present=$_t69_s3_rc)"
else
  t69_fail "TC-S2/S3: expected rc=0 in both, got absent=$_t69_s2_rc present=$_t69_s3_rc"
fi

# --- TC-S8: ignore パターンに合致しない typo -> WARN される（除外が広すぎない）---
_t69_probe 'wire `.claude/settingz.json` first'
if [ "$(_t69_stale_rc)" = "1" ] && _t69_stale_run | grep -q 'settingz.json'; then
  t69_pass "TC-S8: typo near an ignored path is still detected"
else
  t69_fail "TC-S8: expected rc=1 for a typo that no ignore pattern matches"
fi

# --- TC-S9: git 不在 -> 除外なしへ縮退（crash しない / 隠さない）---
_t69_probe 'wire `.claude/settings.json` first'
_T69_PY="$(command -v python3)"
_t69_nogit_rc=$( cd "$_T69_S" && env PATH=/nonexistent-1087 "$_T69_PY" scripts/check-stale-skill-refs.py >/dev/null 2>&1; echo $? )
if [ "$_t69_nogit_rc" = "1" ]; then
  t69_pass "TC-S9: without git -> degrades to no-exclusion (safe side, no crash)"
else
  t69_fail "TC-S9: expected rc=1 (no exclusion) without git, got $_t69_nogit_rc"
fi

# --- TC-S1: 本番ツリー（引数なし既定経路）-> rc=0 ---
( cd "$_T69_ROOT" && python3 scripts/check-stale-skill-refs.py >/dev/null 2>&1 )
if [ "$?" = "0" ]; then
  t69_pass "TC-S1: production tree -> rc=0 (no stale refs)"
else
  t69_fail "TC-S1: expected rc=0 on the production tree"
fi

rm -rf "$_T69_S" 2>/dev/null || true

pg_extra_contract_finalize
