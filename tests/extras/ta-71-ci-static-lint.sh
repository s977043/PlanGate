# tests/extras/ta-71-ci-static-lint.sh
# PG_EXTRA_CAPABILITY: standalone-capable
# Sourced by tests/run-tests.sh — uses $pass / $fail counters
#
# CI 静的解析ラッパ（scripts/lint-shell.sh / scripts/lint-workflows.sh）と
# HO 適用スクリプト（scripts/apply-ci-lint-wiring.sh）の振る舞い回帰テスト。
#
# 「空振り fixture を作らない」ことを最優先にしている: 正側（故意に違反を仕込んだ
# サンドボックスで lint が非ゼロを返す）と負側（クリーンな入力で検出ゼロ）の両方を
# 見る。負側だけだと「lint がそもそも 1 ファイルも見ていない」状態でも緑になる。
#
#   TC-01: lint-shell --list が非空で、bin/plangate（拡張子なし）を含む
#          ＝固定 glob ではなく shebang 探索で拾えている
#   TC-02: lint-shell --list が除外宣言 docs/working/ を含まない
#   TC-03: lint-shell / lint-workflows / apply-ci-lint-wiring の引数 strict 検証
#   TC-04: 実 repo に対する lint-shell gate が rc=0 かつ [PASS] 行を出す
#   TC-05: sandbox 正側（変異注入）— 故意に壊した .sh で rc!=0 かつ当該ファイル名が出る
#   TC-06: sandbox 負側 — クリーンな入力で rc=0 かつ [PASS] 行
#   TC-07: tool 不在シーム — PG_SHELLCHECK が解決不能なら [SKIP]+rc=0、
#          --require-tool 併用なら失敗表示で rc=1（黙って緑にしない）
#   TC-08: 実 repo に対する lint-workflows が rc=0 かつ [PASS] 行
#   TC-09: sandbox 正側 — actionlint 違反を含む workflow で rc!=0
#   TC-10: apply-ci-lint-wiring — dry-run は 1 バイトも書かない
#   TC-11: apply-ci-lint-wiring — sandbox 適用後に marker が入り、再実行は冪等 skip
#   TC-12: apply-ci-lint-wiring — アンカー未検出なら exit 1（何も書かない）

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
pg_extra_contract_init ta-71-ci-static-lint standalone-capable

if pg_extra_contract_is_standalone; then
  unset PLANGATE_SKIP_REASON PLANGATE_HOOK_TASK PLANGATE_HOOK_FILE PLANGATE_BYPASS_HOOK PLANGATE_HOOK_STRICT PG_HARNESS_SOURCED PLANGATE_ALLOW_MASS_DELETE 2>/dev/null || true
fi

printf '\n=== TA-71: CI static lint wrappers (shellcheck / actionlint) ===\n'

t71_pass() { pass=$((pass + 1)); printf '  [PASS] %s\n' "$1"; }
t71_fail() { fail=$((fail + 1)); printf '  [FAIL] %s\n' "$1" >&2; }

_T71_ROOT="$(CDPATH= cd -- "$_pg_extra_dir/../.." && pwd)"
_T71_LS="$_T71_ROOT/scripts/lint-shell.sh"
_T71_LW="$_T71_ROOT/scripts/lint-workflows.sh"
_T71_AP="$_T71_ROOT/scripts/apply-ci-lint-wiring.sh"

for _t71_f in "$_T71_LS" "$_T71_LW" "$_T71_AP"; do
  if [ ! -f "$_t71_f" ]; then
    pg_extra_contract_skip "missing target script: $_t71_f"
    return 0 2>/dev/null || exit 3
  fi
done

# --- TC-01 / TC-02 対象列挙 ---
_t71_rc=0
_t71_list="$(sh "$_T71_LS" --list 2>&1)" || _t71_rc=$?
if [ "$_t71_rc" -eq 0 ] && printf '%s\n' "$_t71_list" | grep -qx 'bin/plangate'; then
  t71_pass "TC-01 --list が拡張子なしの bin/plangate を shebang 探索で拾う"
else
  t71_fail "TC-01 --list が bin/plangate を含まない (rc=$_t71_rc)"
fi

if [ "$_t71_rc" -eq 0 ] && ! printf '%s\n' "$_t71_list" | grep -q '^docs/working/'; then
  t71_pass "TC-02 --list が除外宣言 docs/working/ を含まない"
else
  t71_fail "TC-02 除外宣言が効いていない (rc=$_t71_rc)"
fi

# --- TC-03 引数 strict 検証 ---
_t71_strict_ok=yes
for _t71_s in "$_T71_LS" "$_T71_LW" "$_T71_AP"; do
  _t71_rc=0
  _t71_out="$(sh "$_t71_s" --definitely-not-a-flag 2>&1)" || _t71_rc=$?
  if [ "$_t71_rc" -ne 1 ]; then
    _t71_strict_ok="no ($_t71_s rc=$_t71_rc)"
    break
  fi
  if ! printf '%s' "$_t71_out" | grep -q 'unknown argument'; then
    _t71_strict_ok="no ($_t71_s: 診断メッセージなし)"
    break
  fi
done
if [ "$_t71_strict_ok" = yes ]; then
  t71_pass "TC-03 3 スクリプトとも未知引数で exit 1 + 診断メッセージ"
else
  t71_fail "TC-03 引数 strict 検証が破れている: $_t71_strict_ok"
fi

# --- TC-04 実 repo gate ---
_t71_rc=0
_t71_out="$(sh "$_T71_LS" 2>&1)" || _t71_rc=$?
if [ "$_t71_rc" -eq 0 ] && printf '%s' "$_t71_out" | grep -q '\[PASS\] lint-shell gate'; then
  t71_pass "TC-04 実 repo の lint-shell gate が rc=0 かつ [PASS] 行を出す"
elif printf '%s' "$_t71_out" | grep -q '\[SKIP\] lint-shell'; then
  t71_pass "TC-04 shellcheck 未導入環境: [SKIP] が明示され rc=0（黙って緑ではない）"
else
  t71_fail "TC-04 実 repo の lint-shell gate が緑でない (rc=$_t71_rc): $(printf '%s' "$_t71_out" | tail -3 | tr '\n' ';')"
fi

# --- TC-05 / TC-06 sandbox 正側・負側 ---
_T71_SB="$(mktemp -d)"
register_cleanup "$_T71_SB"
mkdir -p "$_T71_SB/scripts" "$_T71_SB/.github/workflows"
cp "$_T71_LS" "$_T71_SB/scripts/lint-shell.sh"
cp "$_T71_LW" "$_T71_SB/scripts/lint-workflows.sh"
printf '#!/bin/sh\nset -eu\necho clean\n' >"$_T71_SB/scripts/clean.sh"
_t71_sb_init=0
if command -v git >/dev/null 2>&1; then
  ( cd "$_T71_SB" && git init -q && git add -A ) >/dev/null 2>&1 || _t71_sb_init=1
else
  _t71_sb_init=1
fi


if [ "$_t71_sb_init" -ne 0 ]; then
  printf '  [SKIP] TC-05/TC-06/TC-09: sandbox の初期化に失敗（git 不在等）\n'
else
  # 負側: クリーンな入力 → rc=0 かつ [PASS] 行（「FAIL が無い」では到達を証明できない）
  _t71_rc=0
  _t71_out="$(sh "$_T71_SB/scripts/lint-shell.sh" 2>&1)" || _t71_rc=$?
  if printf '%s' "$_t71_out" | grep -q '\[SKIP\] lint-shell'; then
    printf '  [SKIP] TC-06: shellcheck 未導入のため負側を評価できない\n'
  elif [ "$_t71_rc" -eq 0 ] && printf '%s' "$_t71_out" | grep -q '\[PASS\] lint-shell gate'; then
    t71_pass "TC-06 sandbox 負側: クリーン入力で rc=0 かつ [PASS] 行"
  else
    t71_fail "TC-06 sandbox 負側が緑にならない (rc=$_t71_rc)"
  fi
fi

if [ "$_t71_sb_init" -eq 0 ]; then
  # 正側（変異注入）: 故意に壊した .sh を追加 → rc!=0 かつ当該ファイル名が出る
  printf '#!/bin/sh\ncase $x in\n' >"$_T71_SB/scripts/broken.sh"
  ( cd "$_T71_SB" && git add -A ) >/dev/null 2>&1 || true
  _t71_rc=0
  _t71_out="$(sh "$_T71_SB/scripts/lint-shell.sh" 2>&1)" || _t71_rc=$?
  if printf '%s' "$_t71_out" | grep -q '\[SKIP\] lint-shell'; then
    printf '  [SKIP] TC-05: shellcheck 未導入のため正側を評価できない\n'
  elif [ "$_t71_rc" -ne 0 ] && printf '%s' "$_t71_out" | grep -q 'scripts/broken.sh'; then
    t71_pass "TC-05 sandbox 正側（変異注入）: 違反を検出し rc!=0 + 該当ファイル名を出す"
  else
    t71_fail "TC-05 変異注入を検出できていない (rc=$_t71_rc) — 本 TA が空振りしている"
  fi
  rm -f "$_T71_SB/scripts/broken.sh"
  ( cd "$_T71_SB" && git add -A ) >/dev/null 2>&1 || true
fi

# --- TC-07 tool 不在シーム（黙って緑にしない）---
_t71_rc=0
_t71_out="$(PG_SHELLCHECK=pg-absent-shellcheck-xyz sh "$_T71_LS" 2>&1)" || _t71_rc=$?
_t71_rc2=0
_t71_out2="$(PG_SHELLCHECK=pg-absent-shellcheck-xyz sh "$_T71_LS" --require-tool 2>&1)" || _t71_rc2=$?
if [ "$_t71_rc" -eq 0 ] && printf '%s' "$_t71_out" | grep -q '\[SKIP\] lint-shell' \
   && [ "$_t71_rc2" -eq 1 ] && printf '%s' "$_t71_out2" | grep -q '\[FAIL\] lint-shell'; then
  t71_pass "TC-07 tool 不在: 既定は SKIP 表示で rc=0 / --require-tool では失敗表示で rc=1"
else
  t71_fail "TC-07 tool 不在時の扱いが契約どおりでない (rc=$_t71_rc / require rc=$_t71_rc2)"
fi

# --- TC-08 実 repo の workflow lint ---
_t71_rc=0
_t71_out="$(sh "$_T71_LW" 2>&1)" || _t71_rc=$?
if [ "$_t71_rc" -eq 0 ] && printf '%s' "$_t71_out" | grep -q '\[PASS\] lint-workflows'; then
  t71_pass "TC-08 実 repo の lint-workflows が rc=0 かつ [PASS] 行を出す"
elif printf '%s' "$_t71_out" | grep -q '\[SKIP\] lint-workflows'; then
  t71_pass "TC-08 actionlint 未導入環境: [SKIP] が明示され rc=0（黙って緑ではない）"
else
  t71_fail "TC-08 実 repo の lint-workflows が緑でない (rc=$_t71_rc)"
fi

# --- TC-09 sandbox 正側: actionlint 違反を含む workflow ---
if [ "$_t71_sb_init" -eq 0 ]; then
  {
    printf 'name: bad\n'
    printf 'on: push\n'
    printf 'jobs:\n'
    printf '  bad:\n'
    printf '    runs-on: ubuntu-latest\n'
    printf '    steps:\n'
    printf '      - uses: actions/checkout@v4\n'
    printf '        run: echo hi\n'
  } >"$_T71_SB/.github/workflows/bad.yml"
  ( cd "$_T71_SB" && git add -A ) >/dev/null 2>&1 || true
  _t71_rc=0
  _t71_out="$(sh "$_T71_SB/scripts/lint-workflows.sh" 2>&1)" || _t71_rc=$?
  if printf '%s' "$_t71_out" | grep -q '\[SKIP\] lint-workflows'; then
    printf '  [SKIP] TC-09: actionlint 未導入のため正側を評価できない\n'
  elif [ "$_t71_rc" -ne 0 ] && printf '%s' "$_t71_out" | grep -q 'bad.yml'; then
    t71_pass "TC-09 sandbox 正側: 違反 workflow を検出し rc!=0 + 該当ファイル名を出す"
  else
    t71_fail "TC-09 違反 workflow を検出できていない (rc=$_t71_rc) — 本 TA が空振りしている"
  fi
fi

# --- TC-10 / TC-11 / TC-12 apply-ci-lint-wiring ---
_T71_CI="$_T71_ROOT/.github/workflows/ci.yml"
if [ ! -f "$_T71_CI" ]; then
  printf '  [SKIP] TC-10/11/12: .github/workflows/ci.yml が無い\n'
else
  _T71_AB="$(mktemp -d)"
  register_cleanup "$_T71_AB"
  cp "$_T71_CI" "$_T71_AB/ci.yml"
  _t71_before="$(cksum <"$_T71_AB/ci.yml")"

  # TC-10 dry-run は 1 バイトも書かない
  _t71_rc=0
  _t71_out="$(sh "$_T71_AP" --dry-run --target "$_T71_AB/ci.yml" 2>&1)" || _t71_rc=$?
  _t71_after="$(cksum <"$_T71_AB/ci.yml")"
  if [ "$_t71_rc" -eq 0 ] && [ "$_t71_before" = "$_t71_after" ] \
     && printf '%s' "$_t71_out" | grep -q 'dry-run'; then
    t71_pass "TC-10 apply --dry-run は対象を 1 バイトも変更しない"
  else
    t71_fail "TC-10 dry-run が書き込んだ / 差分プレビューが出ない (rc=$_t71_rc)"
  fi
fi

if [ -n "${_T71_AB:-}" ]; then
  # TC-11 適用 → marker が入り、再実行は冪等 skip
  _t71_rc=0
  _t71_out="$(sh "$_T71_AP" --apply --target "$_T71_AB/ci.yml" 2>&1)" || _t71_rc=$?
  _t71_rc2=0
  _t71_out2="$(sh "$_T71_AP" --apply --target "$_T71_AB/ci.yml" 2>&1)" || _t71_rc2=$?
  if [ "$_t71_rc" -eq 0 ] && grep -q '^  shell-lint:' "$_T71_AB/ci.yml" \
     && grep -q '^  workflow-lint:' "$_T71_AB/ci.yml" \
     && [ "$_t71_rc2" -eq 0 ] && printf '%s' "$_t71_out2" | grep -q 'already applied'; then
    t71_pass "TC-11 apply --apply で 2 job が入り、再実行は冪等 skip"
  else
    t71_fail "TC-11 適用結果が期待どおりでない (rc=$_t71_rc / 再実行 rc=$_t71_rc2)"
  fi

  # 適用後の YAML が壊れていないこと（parse 可能 + timeout-minutes を持つ）
  if command -v python3 >/dev/null 2>&1 && python3 -c 'import yaml' >/dev/null 2>&1; then
    _t71_rc=0
    _t71_out="$(python3 -c 'import sys,yaml; d=yaml.safe_load(open(sys.argv[1])); j=d["jobs"]; assert "shell-lint" in j and "workflow-lint" in j; assert j["shell-lint"]["timeout-minutes"] and j["workflow-lint"]["timeout-minutes"]; print("ok")' "$_T71_AB/ci.yml" 2>&1)" || _t71_rc=$?
    if [ "$_t71_rc" -eq 0 ]; then
      t71_pass "TC-11b 適用後の ci.yml が YAML として parse でき、両 job に timeout-minutes がある"
    else
      t71_fail "TC-11b 適用後の ci.yml が壊れている: $_t71_out"
    fi
  else
    printf '  [SKIP] TC-11b: python3 の PyYAML が無い\n'
  fi

  # TC-12 アンカー未検出なら exit 1（何も書かない）
  cp "$_T71_CI" "$_T71_AB/noanchor.yml"
  grep -v '^  markdown:$' "$_T71_AB/noanchor.yml" >"$_T71_AB/noanchor2.yml"
  mv "$_T71_AB/noanchor2.yml" "$_T71_AB/noanchor.yml"
  _t71_before="$(cksum <"$_T71_AB/noanchor.yml")"
  _t71_rc=0
  _t71_out="$(sh "$_T71_AP" --apply --target "$_T71_AB/noanchor.yml" 2>&1)" || _t71_rc=$?
  _t71_after="$(cksum <"$_T71_AB/noanchor.yml")"
  if [ "$_t71_rc" -eq 1 ] && [ "$_t71_before" = "$_t71_after" ] \
     && printf '%s' "$_t71_out" | grep -q 'anchor not found'; then
    t71_pass "TC-12 アンカー未検出で exit 1 かつ 1 バイトも書かない"
  else
    t71_fail "TC-12 アンカー検証が破れている (rc=$_t71_rc)"
  fi
fi

rm -rf "$_T71_SB" "${_T71_AB:-/nonexistent-ta71}"

pg_extra_contract_finalize
