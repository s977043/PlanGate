# tests/extras/ta-67-pg-fold-path-portability.sh
# PG_EXTRA_CAPABILITY: standalone-capable
# Sourced by tests/run-tests.sh — uses $pass / $fail counters
# #1101 / TASK-1101 Step 6 (AC-4): 正規化関数 _pg_fold_path の 4 シェル可搬性。
#
# 【なぜ ta-65 経由で確認しないか】
#   ta-65 は hook を常に `sh "$_T65_HOOK"` で起動するため、**どのシェルで実行しても
#   hook 内部は sh で動く**。したがって ta-65 をシェルを変えて回しても
#   「_pg_fold_path が zsh でも同じ結果になるか」は一切測れない（false green）。
#   本テストは**関数を各シェルで直接評価**する（正本: tests/fixtures/pg-fold-path.sh）。
#
# 【回帰の根拠】
#   - C-2 実測: 単語分割（IFS=/ + 未クォート展開）に依存した実装は **zsh で no-op**
#   - RiverReview 実測: `${v,,}` は sh(bash 3.2) / dash とも `bad substitution`
#     → 小文字化は自作ロジックになるため、**大文字入力を必ず測る**（M-7）
#   - PR 前レビュー: repo root 除去が大小文字厳密だと root 前置部だけ大文字の
#     絶対パスで HO を迂回できる → **root 大文字入力を必ず測る**
#
# 期待値は **repo の実パスに依存しない固定 root**（/Fake/Repo/Root）で表現する。

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
pg_extra_contract_init ta-67-pg-fold-path-portability standalone-capable

printf '\n=== TA-67: _pg_fold_path 4 シェル可搬性 (#1101 / AC-4) ===\n'

if [ "${PG_HARNESS_SOURCED:-0}" = "1" ] && [ -n "${FIXTURES_DIR:-}" ]; then
  _T67_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
else
  unset PLANGATE_SKIP_REASON PLANGATE_HOOK_TASK PLANGATE_HOOK_FILE PLANGATE_BYPASS_HOOK PLANGATE_HOOK_STRICT PG_HARNESS_SOURCED PLANGATE_ALLOW_MASS_DELETE 2>/dev/null || true
  _T67_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
fi
_T67_LIB="$_T67_ROOT/tests/fixtures/pg-fold-path.sh"
_T67_FAKE_ROOT='/Fake/Repo/Root'

t67_pass() { pass=$((pass + 1)); printf '  [PASS] %s\n' "$1"; }
t67_fail() { fail=$((fail + 1)); printf '  [FAIL] %s\n' "$1" >&2; }

_T67_ABORT=0
if [ ! -r "$_T67_LIB" ]; then
  _T67_ABORT=1
  pg_extra_contract_skip "正規化関数の正本が読めない: $_T67_LIB"
fi

# ── 利用可能なシェルを検出（CI に zsh / dash が無い環境を許容）──────
if [ "$_T67_ABORT" = "0" ]; then
  _T67_SHELLS=''
  _T67_MISSING=''
  for _t67_s in sh dash bash zsh; do
    if command -v "$_t67_s" >/dev/null 2>&1; then
      _T67_SHELLS="$_T67_SHELLS $_t67_s"
    else
      _T67_MISSING="$_T67_MISSING $_t67_s"
    fi
  done
  _T67_NSH=0
  for _t67_s in $_T67_SHELLS; do _T67_NSH=$((_T67_NSH + 1)); done
  if [ -n "$_T67_MISSING" ]; then
    printf '  [INFO] 未導入のため測定対象外:%s\n' "$_T67_MISSING"
  fi
  if [ "$_T67_NSH" -lt 2 ]; then
    _T67_ABORT=1
    pg_extra_contract_skip "比較に必要なシェルが 2 種未満 (available:$_T67_SHELLS)"
  fi
fi

if [ "$_T67_ABORT" = "0" ]; then
  _T67_TMP=$(mktemp -d)
  register_cleanup "$_T67_TMP"

  # ── ドライバ: 関数を source して入出力を 1 行 1 ケースで出力する ────
  cat > "$_T67_TMP/drive.sh" <<'T67DRV'
. "$1"
_R=$2
run() {
  _pg_fold_path "$1" "$_R" "${2:-1}"
  printf 'IN[%s]\tOUT[%s]\trc=%s\n' "$1" "$_PG_FOLD_OUT" "$_PG_FOLD_RC"
}
run 'docs/../CLAUDE.md'
run 'bin/../bin/plangate'
run 'a/b/../../c'
run 'bin//plangate'
run './/CLAUDE.md'
run 'bin/./plangate'
run './bin/../bin/plangate'
run 'Bin/PlanGate'
run 'CLAUDE.MD '
run '/Fake/Repo/Root/./BIN/plangate'
run '/Fake/Repo/Root/CLAUDE.md'
run '/FAKE/REPO/ROOT/CLAUDE.md'
run '/FAKE/REPO/ROOT/CLAUDE.MD'
run '/FAKE/REPO/ROOT/x/../bin/plangate'
run '/FAKE/REPO/ROOT/CLAUDE.md' 0
run '/private/tmp/x/note.md'
run '/PRIVATE/TMP/x/NOTE.md'
run '/CLAUDE.md'
run 'CLAUDE.md/'
run ' CLAUDE.md'
run 'bin\plangate'
run ''
run '/'
run 'ドキュメント/CLAUDE.md'
run 'Ａ/CLAUDE.MD'
run '..'
run '../plangate/CLAUDE.md'
run 'a/b/../../../CLAUDE.md'
_long=''
_i=0
while [ "$_i" -lt 257 ]; do _long="$_long"'x/'; _i=$((_i + 1)); done
_pg_fold_path "${_long}CLAUDE.md" "$_R" 1
printf 'IN[%s]\tOUT[%s]\trc=%s\n' '257seg' 'omitted' "$_PG_FOLD_RC"
# #1101 Step 7: 長さ由来の fail-closed（(c) 全体長 / (d) セグメント長）と
# その境界。二重化で組み立てる（1 文字ずつの連結はドライバ側が O(n^2) になる）。
_huge=A
_i=0
while [ "$_i" -lt 15 ]; do _huge="$_huge$_huge"; _i=$((_i + 1)); done
_pg_fold_path "$_huge" "$_R" 1
printf 'IN[%s]\tOUT[%s]\trc=%s\n' 'len32768' 'omitted' "$_PG_FOLD_RC"
_seg=B
_i=0
while [ "$_i" -lt 9 ]; do _seg="$_seg$_seg"; _i=$((_i + 1)); done
_pg_fold_path "docs/$_seg/CLAUDE.md" "$_R" 1
printf 'IN[%s]\tOUT[%s]\trc=%s\n' 'seg512' 'omitted' "$_PG_FOLD_RC"
_seg2=c
_i=0
while [ "$_i" -lt 8 ]; do _seg2="$_seg2$_seg2"; _i=$((_i + 1)); done
_seg2=${_seg2#?}
_pg_fold_path "docs/$_seg2/note.md" "$_R" 1
printf 'IN[%s]\tOUT[%s]\trc=%s\n' 'seg255' 'omitted' "$_PG_FOLD_RC"
T67DRV

  # ── 期待値（正本。repo の実パスに依存しない）────────────────────
  cat > "$_T67_TMP/expected.txt" <<'T67EXP'
IN[docs/../CLAUDE.md]	OUT[claude.md]	rc=0
IN[bin/../bin/plangate]	OUT[bin/plangate]	rc=0
IN[a/b/../../c]	OUT[c]	rc=0
IN[bin//plangate]	OUT[bin/plangate]	rc=0
IN[.//CLAUDE.md]	OUT[claude.md]	rc=0
IN[bin/./plangate]	OUT[bin/plangate]	rc=0
IN[./bin/../bin/plangate]	OUT[bin/plangate]	rc=0
IN[Bin/PlanGate]	OUT[bin/plangate]	rc=0
IN[CLAUDE.MD ]	OUT[claude.md]	rc=0
IN[/Fake/Repo/Root/./BIN/plangate]	OUT[bin/plangate]	rc=0
IN[/Fake/Repo/Root/CLAUDE.md]	OUT[claude.md]	rc=0
IN[/FAKE/REPO/ROOT/CLAUDE.md]	OUT[claude.md]	rc=0
IN[/FAKE/REPO/ROOT/CLAUDE.MD]	OUT[claude.md]	rc=0
IN[/FAKE/REPO/ROOT/x/../bin/plangate]	OUT[bin/plangate]	rc=0
IN[/FAKE/REPO/ROOT/CLAUDE.md]	OUT[/FAKE/REPO/ROOT/CLAUDE.md]	rc=0
IN[/private/tmp/x/note.md]	OUT[/private/tmp/x/note.md]	rc=0
IN[/PRIVATE/TMP/x/NOTE.md]	OUT[/private/tmp/x/note.md]	rc=0
IN[/CLAUDE.md]	OUT[/claude.md]	rc=0
IN[CLAUDE.md/]	OUT[claude.md/]	rc=0
IN[ CLAUDE.md]	OUT[ claude.md]	rc=0
IN[bin\plangate]	OUT[bin\plangate]	rc=0
IN[]	OUT[]	rc=0
IN[/]	OUT[/]	rc=0
IN[ドキュメント/CLAUDE.md]	OUT[ドキュメント/claude.md]	rc=0
IN[Ａ/CLAUDE.MD]	OUT[Ａ/claude.md]	rc=0
IN[..]	OUT[..]	rc=1
IN[../plangate/CLAUDE.md]	OUT[../plangate/CLAUDE.md]	rc=1
IN[a/b/../../../CLAUDE.md]	OUT[../CLAUDE.md]	rc=1
IN[257seg]	OUT[omitted]	rc=1
IN[len32768]	OUT[omitted]	rc=1
IN[seg512]	OUT[omitted]	rc=1
IN[seg255]	OUT[omitted]	rc=0
T67EXP

  # ── TC-01: 各シェルで rc=0（評価自体が成功する）───────────────────
  _t67_bad=0
  for _t67_s in $_T67_SHELLS; do
    _t67_rc=0
    "$_t67_s" "$_T67_TMP/drive.sh" "$_T67_LIB" "$_T67_FAKE_ROOT" \
      > "$_T67_TMP/out-$_t67_s.txt" 2>"$_T67_TMP/err-$_t67_s.txt" </dev/null || _t67_rc=$?
    if [ "$_t67_rc" != "0" ] || [ ! -s "$_T67_TMP/out-$_t67_s.txt" ]; then
      _t67_bad=$((_t67_bad + 1))
      printf '    %s: rc=%s / %s\n' "$_t67_s" "$_t67_rc" \
        "$(head -2 "$_T67_TMP/err-$_t67_s.txt" 2>/dev/null)" >&2
    fi
  done
  if [ "$_t67_bad" = "0" ]; then
    t67_pass "TC-01 (AC-4): 正規化関数を${_T67_SHELLS} で直接評価し全て rc=0"
  else
    t67_fail "TC-01 (AC-4): ${_t67_bad}/${_T67_NSH} シェルで評価に失敗（bad substitution 等）"
  fi

  # ── TC-02: 期待値と一致（1 シェルでも表と違えば FAIL）─────────────
  _t67_bad=0
  for _t67_s in $_T67_SHELLS; do
    [ -s "$_T67_TMP/out-$_t67_s.txt" ] || continue
    if ! cmp -s "$_T67_TMP/expected.txt" "$_T67_TMP/out-$_t67_s.txt"; then
      _t67_bad=$((_t67_bad + 1))
      printf '    %s: 期待値と不一致\n' "$_t67_s" >&2
      diff "$_T67_TMP/expected.txt" "$_T67_TMP/out-$_t67_s.txt" 2>/dev/null | head -8 >&2
    fi
  done
  if [ "$_t67_bad" = "0" ]; then
    t67_pass "TC-02 (AC-4): 全シェルの入出力が期待値表と一致（32 ケース / fail-closed 6 件 + 長さ境界 1 件を含む）"
  else
    t67_fail "TC-02 (AC-4): ${_t67_bad} シェルで期待値と乖離"
  fi

  # ── TC-03: シェル間で byte 一致（zsh no-op 回帰の検出）──────────
  _t67_ref=''
  for _t67_s in $_T67_SHELLS; do _t67_ref="$_t67_s"; break; done
  _t67_bad=0
  for _t67_s in $_T67_SHELLS; do
    [ "$_t67_s" = "$_t67_ref" ] && continue
    if ! cmp -s "$_T67_TMP/out-$_t67_ref.txt" "$_T67_TMP/out-$_t67_s.txt"; then
      _t67_bad=$((_t67_bad + 1))
      printf '    %s vs %s: 出力が割れている\n' "$_t67_ref" "$_t67_s" >&2
    fi
  done
  if [ "$_t67_bad" = "0" ]; then
    t67_pass "TC-03 (AC-4): ${_T67_NSH} シェルの出力が byte 一致（単語分割依存の回帰なし）"
  else
    t67_fail "TC-03 (AC-4): ${_t67_bad} シェルで出力が割れている"
  fi

  # ── TC-04: locale 非依存（LANG=ja_JP.UTF-8）───────────────────
  # 小文字化を A-Z の 1 文字 case 写像で行いマルチバイトを素通しするため、
  # locale を変えても結果は変わらない（plan Q3 の確定事項）。
  _t67_bad=0
  for _t67_s in $_T67_SHELLS; do
    [ -s "$_T67_TMP/out-$_t67_s.txt" ] || continue
    _t67_rc=0
    LANG=ja_JP.UTF-8 LC_ALL=ja_JP.UTF-8 "$_t67_s" "$_T67_TMP/drive.sh" "$_T67_LIB" "$_T67_FAKE_ROOT" \
      > "$_T67_TMP/ja-$_t67_s.txt" 2>/dev/null </dev/null || _t67_rc=$?
    if [ "$_t67_rc" != "0" ] || ! cmp -s "$_T67_TMP/out-$_t67_s.txt" "$_T67_TMP/ja-$_t67_s.txt"; then
      _t67_bad=$((_t67_bad + 1))
      printf '    %s: LANG=ja_JP.UTF-8 で結果が変わった (rc=%s)\n' "$_t67_s" "$_t67_rc" >&2
    fi
  done
  if [ "$_t67_bad" = "0" ]; then
    t67_pass "TC-04 (AC-4): 全シェルで LANG=ja_JP.UTF-8 でも C locale と byte 一致"
  else
    t67_fail "TC-04 (AC-4): ${_t67_bad} シェルで locale 依存が出た"
  fi

  # ── TC-05: 測定ベクタの自己検査（観点の silent な欠落を防ぐ）──────
  # 「大文字」「repo root 大文字」「マルチバイト」「fail-closed」を測っていない
  # ベクタに縮退したら FAIL する。旧版が `..` / `//` / `/./` の 3 クラスしか
  # 測っておらず、最もシェル差・locale 差が出る小文字化が未測定だった事故の再発防止。
  _t67_bad=0
  for _t67_need in \
    'IN\[Bin/PlanGate\]' \
    'IN\[/FAKE/REPO/ROOT/CLAUDE.md\]' \
    'IN\[ドキュメント/CLAUDE.md\]' \
    'IN\[CLAUDE.MD \]' \
    'rc=1'; do
    if ! grep -q "$_t67_need" "$_T67_TMP/expected.txt"; then
      _t67_bad=$((_t67_bad + 1))
      printf '    観点が欠落: %s\n' "$_t67_need" >&2
    fi
  done
  if [ "$_t67_bad" = "0" ]; then
    t67_pass "TC-05: 測定ベクタに 大文字 / repo root 大文字 / マルチバイト / 末尾空白 / fail-closed が含まれる"
  else
    t67_fail "TC-05: 測定ベクタから ${_t67_bad} 観点が欠落している"
  fi

  rm -rf "$_T67_TMP" 2>/dev/null || true
fi

pg_extra_contract_finalize
