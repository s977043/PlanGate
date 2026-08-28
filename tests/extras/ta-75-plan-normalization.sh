# tests/extras/ta-75-plan-normalization.sh
# PG_EXTRA_CAPABILITY: standalone-capable
# Sourced by tests/run-tests.sh — uses $pass / $fail counters
#
# Issue #1220: Canonical Plan normalization の機械契約を固定する。
#
# 設計意図: 「非ゼロなら何でも合格」にしない。exit 1（契約違反）と exit 2
# （起動不正 / 入力不良）を区別し、履歴検出パターンは 1 パターン 1 TC に
# 分割する。まとめて 2 パターン混入させた fixture は、片方を消す変異が
# 生き残る（もう片方が検出するため）。
#
#   TC-01: 正常な Canonical Plan は exit 0
#   TC-02: before の AC-2 が after から消えると exit 1
#   TC-03: before == after（no-op）は exit 1 — 承認ゲートの自己証明を塞ぐ
#   TC-04: 必須見出し（Verification Plan）欠落は exit 1
#   TC-05〜TC-12: 履歴依存表現 8 パターンを 1 パターン 1 TC で exit 1
#   TC-13: 取り消し線（構造マーカー）は exit 1
#   TC-14: 履歴/代替案を宣言する見出し（構造マーカー）は exit 1
#   TC-15: 番号付き見出し / h1 / 副題併記でも必須見出しとして通る（exit 0）
#   TC-16: 見出し照合は前方一致でない — "Goalpost" では Goal を満たさない
#   TC-17: R-NNN（C-2 指摘 ID）の消失も exit 1
#   TC-18: before に ID が 1 つも無い場合は exit 1（恒真 PASS を塞ぐ）
#   TC-19: 引数なしは exit 2
#   TC-20: 不在ファイルは exit 2
#   TC-21: 非 UTF-8 入力は exit 2
#   TC-22: --before-ref は git 由来 baseline を読んで exit 0
#   TC-23: --before と --before-ref の併用は exit 2（排他）
#   TC-24: --before 使用時は「検証されていない入力」の WARN を出す

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
pg_extra_contract_init ta-75-plan-normalization standalone-capable

if pg_extra_contract_is_standalone; then
  unset PLANGATE_SKIP_REASON PLANGATE_HOOK_TASK PLANGATE_HOOK_FILE PLANGATE_BYPASS_HOOK PLANGATE_HOOK_STRICT PG_HARNESS_SOURCED PLANGATE_ALLOW_MASS_DELETE 2>/dev/null || true
fi

printf '\n=== TA-75: Plan Normalization Gate contract ===\n'

_T75_ROOT="${_pg_extra_dir%/tests/extras}"
_T75_CHECKER="$_T75_ROOT/scripts/check-plan-normalization.py"
_T75_TMP="$(mktemp -d)"
register_cleanup "$_T75_TMP"


t75_pass() {
  printf '  [PASS] %s\n' "$1"
  pass=$((pass + 1))
}

t75_fail() {
  printf '  [FAIL] %s\n' "$1"
  fail=$((fail + 1))
}

# t75_rc <expected-rc> <label> <checker args...>
# exit 1 (contract violation) と exit 2 (invocation error) を必ず区別する。
t75_rc() {
  _t75_want=$1
  _t75_label=$2
  shift 2
  _t75_got=0
  _t75_out="$(python3 "$_T75_CHECKER" "$@" 2>&1)" || _t75_got=$?
  if [ "$_t75_got" = "$_t75_want" ]; then
    t75_pass "$_t75_label (rc=$_t75_got)"
  else
    t75_fail "$_t75_label: expected rc=$_t75_want, got rc=$_t75_got"
    printf '%s\n' "$_t75_out" | sed 's/^/         /'
  fi
}

_T75_B="$_T75_TMP/before.md"
_T75_A="$_T75_TMP/after.md"

cat > "$_T75_B" <<'T75EOF'
# TASK-X Plan

## Goal

AC-1 と AC-2 を満たす。

## Scope

- In: canonicalize plan
- Out: runtime implementation

## Global Constraints

- REQ-1 を維持する。
- R-001 の指摘を反映済み。

## Work Breakdown

- AC-1: normalize current state
- AC-2: preserve verification

## Verification Plan

- REQ-1 を検証する。
T75EOF

# 正常な canonical after（before と本文が異なる = 実際に正規化されている）
cat > "$_T75_A" <<'T75EOF'
# TASK-X Plan

## Goal

AC-1 と AC-2 を満たす canonical state を定義する。

## Scope

- In Scope: canonicalize plan
- Out of Scope: runtime implementation

## Global Constraints

- REQ-1 を維持する。
- R-001 の反映内容を現在形で記述する。

## Work Breakdown

- AC-1: current canonical state を生成する
- AC-2: verification contract を維持する

## Verification Plan

- REQ-1 と AC-1 / AC-2 を検証する。
T75EOF
t75_rc 0 "TC-01 正常な Canonical Plan" --before "$_T75_B" --after "$_T75_A"
cat > "$_T75_A" <<'T75EOF'
# TASK-X Plan

## Goal

AC-1 を満たす canonical state を定義する。

## Scope

- In Scope: canonicalize plan

## Global Constraints

- REQ-1 を維持する。
- R-001 の反映内容を現在形で記述する。

## Work Breakdown

- AC-1: current canonical state を生成する

## Verification Plan

- REQ-1 と AC-1 を検証する。
T75EOF
t75_rc 1 "TC-02 before の AC-2 が after から消えると違反" --before "$_T75_B" --after "$_T75_A"

cp "$_T75_B" "$_T75_A"
t75_rc 1 "TC-03 before == after（no-op）は違反 — 自己証明を塞ぐ" --before "$_T75_B" --after "$_T75_A"

cat > "$_T75_A" <<'T75EOF'
# TASK-X Plan

## Goal

AC-1 と AC-2 を満たす canonical state を定義する。

## Scope

- In Scope: canonicalize plan

## Global Constraints

- REQ-1 を維持する。
- R-001 の反映内容を現在形で記述する。

## Work Breakdown

- AC-1: current canonical state を生成する
- AC-2: verification contract を維持する
T75EOF
t75_rc 1 "TC-04 必須見出し Verification Plan 欠落は違反" --before "$_T75_B" --after "$_T75_A"

cat > "$_T75_A" <<'T75EOF'
# TASK-X Plan

## Goal

AC-1 と AC-2 を満たす canonical state を定義する。当初は別の構成だった。

## Scope

- In Scope: canonicalize plan

## Global Constraints

- REQ-1 を維持する。
- R-001 の反映内容を現在形で記述する。

## Work Breakdown

- AC-1: current canonical state を生成する
- AC-2: verification contract を維持する

## Verification Plan

- REQ-1 と AC-1 / AC-2 を検証する。
T75EOF
t75_rc 1 "TC-05 履歴依存表現 1/8: 当初" --before "$_T75_B" --after "$_T75_A"

cat > "$_T75_A" <<'T75EOF'
# TASK-X Plan

## Goal

AC-1 と AC-2 を満たす canonical state を定義する。詳細は先ほどのレビューを参照。

## Scope

- In Scope: canonicalize plan

## Global Constraints

- REQ-1 を維持する。
- R-001 の反映内容を現在形で記述する。

## Work Breakdown

- AC-1: current canonical state を生成する
- AC-2: verification contract を維持する

## Verification Plan

- REQ-1 と AC-1 / AC-2 を検証する。
T75EOF
t75_rc 1 "TC-06 履歴依存表現 2/8: 先ほどのレビュー" --before "$_T75_B" --after "$_T75_A"

cat > "$_T75_A" <<'T75EOF'
# TASK-X Plan

## Goal

AC-1 と AC-2 を満たす canonical state を定義する。前述の指摘に対応済み。

## Scope

- In Scope: canonicalize plan

## Global Constraints

- REQ-1 を維持する。
- R-001 の反映内容を現在形で記述する。

## Work Breakdown

- AC-1: current canonical state を生成する
- AC-2: verification contract を維持する

## Verification Plan

- REQ-1 と AC-1 / AC-2 を検証する。
T75EOF
t75_rc 1 "TC-07 履歴依存表現 3/8: 前述の指摘" --before "$_T75_B" --after "$_T75_A"

cat > "$_T75_A" <<'T75EOF'
# TASK-X Plan

## Goal

AC-1 と AC-2 を満たす canonical state を定義する。以前の案は採用しない。

## Scope

- In Scope: canonicalize plan

## Global Constraints

- REQ-1 を維持する。
- R-001 の反映内容を現在形で記述する。

## Work Breakdown

- AC-1: current canonical state を生成する
- AC-2: verification contract を維持する

## Verification Plan

- REQ-1 と AC-1 / AC-2 を検証する。
T75EOF
t75_rc 1 "TC-08 履歴依存表現 4/8: 以前の案" --before "$_T75_B" --after "$_T75_A"

cat > "$_T75_A" <<'T75EOF'
# TASK-X Plan

## Goal

AC-1 と AC-2 を満たす canonical state を定義する。レビューで構成を修正した。

## Scope

- In Scope: canonicalize plan

## Global Constraints

- REQ-1 を維持する。
- R-001 の反映内容を現在形で記述する。

## Work Breakdown

- AC-1: current canonical state を生成する
- AC-2: verification contract を維持する

## Verification Plan

- REQ-1 と AC-1 / AC-2 を検証する。
T75EOF
t75_rc 1 "TC-09 履歴依存表現 5/8: レビューで変更" --before "$_T75_B" --after "$_T75_A"

cat > "$_T75_A" <<'T75EOF'
# TASK-X Plan

## Goal

AC-1 と AC-2 を満たす canonical state を定義する。This section was originally different.

## Scope

- In Scope: canonicalize plan

## Global Constraints

- REQ-1 を維持する。
- R-001 の反映内容を現在形で記述する。

## Work Breakdown

- AC-1: current canonical state を生成する
- AC-2: verification contract を維持する

## Verification Plan

- REQ-1 と AC-1 / AC-2 を検証する。
T75EOF
t75_rc 1 "TC-10 履歴依存表現 6/8: originally" --before "$_T75_B" --after "$_T75_A"

cat > "$_T75_A" <<'T75EOF'
# TASK-X Plan

## Goal

AC-1 と AC-2 を満たす canonical state を定義する。See the previous review for context.

## Scope

- In Scope: canonicalize plan

## Global Constraints

- REQ-1 を維持する。
- R-001 の反映内容を現在形で記述する。

## Work Breakdown

- AC-1: current canonical state を生成する
- AC-2: verification contract を維持する

## Verification Plan

- REQ-1 と AC-1 / AC-2 を検証する。
T75EOF
t75_rc 1 "TC-11 履歴依存表現 7/8: previous review" --before "$_T75_B" --after "$_T75_A"

cat > "$_T75_A" <<'T75EOF'
# TASK-X Plan

## Goal

AC-1 と AC-2 を満たす canonical state を定義する。As discussed above, this stays.

## Scope

- In Scope: canonicalize plan

## Global Constraints

- REQ-1 を維持する。
- R-001 の反映内容を現在形で記述する。

## Work Breakdown

- AC-1: current canonical state を生成する
- AC-2: verification contract を維持する

## Verification Plan

- REQ-1 と AC-1 / AC-2 を検証する。
T75EOF
t75_rc 1 "TC-12 履歴依存表現 8/8: as discussed above" --before "$_T75_B" --after "$_T75_A"

cat > "$_T75_A" <<'T75EOF'
# TASK-X Plan

## Goal

AC-1 と AC-2 を満たす canonical state を定義する。

## Scope

- In Scope: canonicalize plan
- ~~旧構成~~ は残さない

## Global Constraints

- REQ-1 を維持する。
- R-001 の反映内容を現在形で記述する。

## Work Breakdown

- AC-1: current canonical state を生成する
- AC-2: verification contract を維持する

## Verification Plan

- REQ-1 と AC-1 / AC-2 を検証する。
T75EOF
t75_rc 1 "TC-13 構造マーカー: 取り消し線が残ると違反" --before "$_T75_B" --after "$_T75_A"

cat > "$_T75_A" <<'T75EOF'
# TASK-X Plan

## Goal

AC-1 と AC-2 を満たす canonical state を定義する。

## Scope

- In Scope: canonicalize plan

### 代替案の検討

- 採用しなかった構成

## Global Constraints

- REQ-1 を維持する。
- R-001 の反映内容を現在形で記述する。

## Work Breakdown

- AC-1: current canonical state を生成する
- AC-2: verification contract を維持する

## Verification Plan

- REQ-1 と AC-1 / AC-2 を検証する。
T75EOF
t75_rc 1 "TC-14 構造マーカー: 代替案見出しが残ると違反" --before "$_T75_B" --after "$_T75_A"

cat > "$_T75_A" <<'T75EOF'
# TASK-X Plan

# 1. Goal

AC-1 と AC-2 を満たす canonical state を定義する。

## Scope (In/Out)

- In Scope: canonicalize plan

### 2. Global Constraints

- REQ-1 を維持する。
- R-001 の反映内容を現在形で記述する。

## Work Breakdown:

- AC-1: current canonical state を生成する
- AC-2: verification contract を維持する

## Verification Plan（自動 + 手動）

- REQ-1 と AC-1 / AC-2 を検証する。
T75EOF
t75_rc 0 "TC-15 番号付き / h1 / 副題併記の見出しでも通る" --before "$_T75_B" --after "$_T75_A"

cat > "$_T75_A" <<'T75EOF'
# TASK-X Plan

## Goalpost

AC-1 と AC-2 を満たす canonical state を定義する。

## Scope

- In Scope: canonicalize plan

## Global Constraints

- REQ-1 を維持する。
- R-001 の反映内容を現在形で記述する。

## Work Breakdown

- AC-1: current canonical state を生成する
- AC-2: verification contract を維持する

## Verification Plan

- REQ-1 と AC-1 / AC-2 を検証する。
T75EOF
t75_rc 1 "TC-16 見出し照合は前方一致でない（Goalpost は Goal を満たさない）" --before "$_T75_B" --after "$_T75_A"

cat > "$_T75_A" <<'T75EOF'
# TASK-X Plan

## Goal

AC-1 と AC-2 を満たす canonical state を定義する。

## Scope

- In Scope: canonicalize plan

## Global Constraints

- REQ-1 を維持する。

## Work Breakdown

- AC-1: current canonical state を生成する
- AC-2: verification contract を維持する

## Verification Plan

- REQ-1 と AC-1 / AC-2 を検証する。
T75EOF
t75_rc 1 "TC-17 R-NNN（C-2 指摘 ID）の消失も違反" --before "$_T75_B" --after "$_T75_A"

# TC-18: ID が 1 つも無い before は「差集合が常に空」で恒真 PASS になる。
cat > "$_T75_TMP/noid-before.md" <<'T75EOF'
# TASK-X Plan

## Goal

正規化の結果を固定する。

## Scope

- In Scope: canonicalize plan

## Global Constraints

- 既存の契約を壊さない。

## Work Breakdown

- canonical state を生成する

## Verification Plan

- 生成物を検証する。
T75EOF
cat > "$_T75_TMP/noid-after.md" <<'T75EOF'
# TASK-X Plan

## Goal

正規化の結果を固定する。

## Scope

- In Scope: canonicalize plan

## Global Constraints

- 既存の契約を壊さない。

## Work Breakdown

- current canonical state を生成する

## Verification Plan

- 生成物を検証する。
T75EOF
t75_rc 1 "TC-18 ID が 1 つも無い場合は違反（恒真 PASS を塞ぐ）" --before "$_T75_TMP/noid-before.md" --after "$_T75_TMP/noid-after.md"

# TC-19 / TC-20 / TC-21: exit 2（起動不正・入力不良）を exit 1 と区別する。
t75_rc 2 "TC-19 引数なしは invocation error"

t75_rc 2 "TC-20 不在ファイルは invocation error" --before "$_T75_TMP/absent.md" --after "$_T75_A"

printf '\377\376\000\001' > "$_T75_TMP/binary.md"
t75_rc 2 "TC-21 非 UTF-8 入力は invocation error" --before "$_T75_TMP/binary.md" --after "$_T75_A"

t75_rc 2 "TC-23 --before と --before-ref の併用は排他エラー" --before "$_T75_B" --before-ref HEAD --after "$_T75_A"


# === TC-24: --before（agent 自作 snapshot）は WARN で明示する
_t75_out="$(python3 "$_T75_CHECKER" --before "$_T75_B" --after "$_T75_A" 2>&1)" || true
if printf '%s' "$_t75_out" | grep -q 'WARN'; then
  t75_pass "TC-24 --before は未検証入力である旨を WARN で明示する"
else
  t75_fail "TC-24 --before の WARN が出ていない"
fi

# === TC-22: --before-ref は baseline を git から読む（承認ゲートの自己証明を塞ぐ本命）
if command -v git >/dev/null 2>&1; then
  _T75_REPO="$_T75_TMP/repo"
  mkdir -p "$_T75_REPO"
  git init -q "$_T75_REPO" >/dev/null 2>&1
  cp "$_T75_B" "$_T75_REPO/plan.md"
  git -C "$_T75_REPO" add plan.md >/dev/null 2>&1
  git -C "$_T75_REPO" -c user.email=ta75@example.invalid -c user.name=ta75 \
    commit -q -m "baseline plan" >/dev/null 2>&1
  cat > "$_T75_REPO/plan.md" <<'T75EOF'
# TASK-X Plan

## Goal

AC-1 と AC-2 を満たす canonical state を定義する。

## Scope

- In Scope: canonicalize plan

## Global Constraints

- REQ-1 を維持する。
- R-001 の反映内容を現在形で記述する。

## Work Breakdown

- AC-1: current canonical state を生成する
- AC-2: verification contract を維持する

## Verification Plan

- REQ-1 と AC-1 / AC-2 を検証する。
T75EOF
  _t75_got=0
  _t75_out="$(cd "$_T75_REPO" && python3 "$_T75_CHECKER" --before-ref HEAD --after plan.md 2>&1)" || _t75_got=$?
  if [ "$_t75_got" = 0 ]; then
    t75_pass "TC-22 --before-ref が git 由来 baseline を読む (rc=0)"
  else
    t75_fail "TC-22 --before-ref: expected rc=0, got rc=$_t75_got"
    printf '%s\n' "$_t75_out" | sed 's/^/         /'
  fi
  # git 由来のときは「未検証入力」WARN を出さない
  if printf '%s' "$_t75_out" | grep -q 'WARN'; then
    t75_fail "TC-22b git 由来 baseline なのに未検証 WARN が出ている"
  else
    t75_pass "TC-22b git 由来 baseline では未検証 WARN を出さない"
  fi
else
  pg_extra_contract_skip "git not available"
fi

pg_extra_contract_finalize
