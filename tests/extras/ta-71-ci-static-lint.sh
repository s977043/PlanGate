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
#   TC-13: apply-ci-lint-wiring — 実 HO パス（<repo>/.github/workflows/**）への
#          --apply は PLANGATE_APPLY_CONFIRM 無しでは exit 1 かつ 1 バイトも書かない
#   TC-09b: apply-ci-lint-wiring の入力 fixture が未適用である（恒真 PASS 防止）
#   TC-13b: 実 repo アンカー probe — 実 ci.yml への --dry-run が rc=0（書き込みなし）
#   TC-14: lint-shell 列挙の自己検査 — 対象 0 件 / 下限割れ / 自己参照欠落で FAIL
#          （恒真 PASS 防止。3 変異すべてで KILL を実証）
#   TC-15: lint-shell --advisory — 常に rc=0 / [INFO] finding(s) / SC1007 は除外
#          （CI では非 gate の run step なので rc が立つと job が落ちる）
#   TC-16: lint-shell — CRLF / UTF-8 BOM 付き shebang の拡張子なしファイルを
#          silently skip しない
#   TC-17: lint-shell — 空白・引用符入りファイル名でも未検査にならない（xargs -0）
#   TC-18: 両ラッパの --help が行番号ハードコードでなくヘッダ全体を出す
#   TC-19: --list が「未追跡ファイルは対象外」を明示する
#
# 注記: サンドボックスは数ファイルしか無いため lint-shell の対象下限
#       （MIN_TARGETS）に引っかかる。サンドボックス実行では
#       PG_LINT_MIN_TARGETS=1 を前置する（テスト専用シーム）。

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

# ── apply-ci-lint-wiring 用入力の射程宣言（規約 9 と同じ思想）─────────────
# TC-10〜13 が読む入力は次の 2 つだけ。どちらも **実 repo の適用状態に依存しない**。
#   (1) _T71_CI   : 未適用状態で凍結した fixture（唯一の apply 対象入力）
#                   tests/fixtures/apply-baseline/README.md を参照
#   (2) _T71_REAL : 実 .github/workflows/ci.yml（**--dry-run の probe でのみ読む**）
# 実 ci.yml をコピーしていた旧設計は、実 repo が適用済みだと apply が no-op になり
# dry-run 差分も冪等判定も成立しなかった（TC-10 / TC-12 が誤 FAIL、TC-11 / TC-13 は
# 恒真 PASS）。書き込みは mktemp サンドボックス配下のみ。
if [ "${PG_HARNESS_SOURCED:-0}" = "1" ] && [ -n "${FIXTURES_DIR:-}" ]; then
  _T71_FXD="$FIXTURES_DIR"
else
  _T71_FXD="$(CDPATH= cd -- "$_pg_extra_dir/../fixtures" && pwd)"
fi
_T71_CI="$_T71_FXD/apply-baseline/workflows/ci.yml"
_T71_REAL="$_T71_ROOT/.github/workflows/ci.yml"

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
  _t71_out="$(PG_LINT_MIN_TARGETS=1 sh "$_T71_SB/scripts/lint-shell.sh" 2>&1)" || _t71_rc=$?
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
  _t71_out="$(PG_LINT_MIN_TARGETS=1 sh "$_T71_SB/scripts/lint-shell.sh" 2>&1)" || _t71_rc=$?
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

# --- TC-09b fixture 前提検査（未適用であること）---
# fixture が「適用済み」に差し替わると TC-11 / TC-13 は差分ゼロで恒真 PASS になる。
# 黙って緑にしないため FAIL させる（SKIP ではない）。
if [ ! -f "$_T71_CI" ]; then
  t71_fail "TC-09b baseline fixture が無い: $_T71_CI"
elif grep -q '^  shell-lint:' "$_T71_CI" || grep -q '^  workflow-lint:' "$_T71_CI"; then
  t71_fail "TC-09b fixture が未適用でない（shell-lint / workflow-lint が既にある）— 以降の TC が恒真 PASS になる"
elif ! grep -q '^  markdown:$' "$_T71_CI"; then
  t71_fail "TC-09b fixture に挿入アンカー '  markdown:' が無い"
else
  t71_pass "TC-09b fixture が未適用状態（2 job 未挿入 / アンカーあり）"
fi

# --- TC-10 / TC-11 / TC-12 apply-ci-lint-wiring ---
if [ ! -f "$_T71_CI" ]; then
  printf '  [SKIP] TC-10/11/12: baseline fixture ci.yml が無い\n'
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

# --- TC-13 apply-ci-lint-wiring: 実 HO パスへの --apply は確認必須 ---
# 実 repo の ci.yml を対象にすると（ガードが壊れていた場合に）実ファイルを書き換えて
# しまうため、**偽 repo root** を作って検査する。REPO_ROOT はスクリプト自身の
# 位置から導出されるので、コピー先の <sb>/.github/workflows/ci.yml が既定 TARGET になる。
_T71_FR="$(mktemp -d)"
register_cleanup "$_T71_FR"
mkdir -p "$_T71_FR/scripts" "$_T71_FR/.github/workflows"
cp "$_T71_AP" "$_T71_FR/scripts/apply-ci-lint-wiring.sh"
if [ ! -f "$_T71_CI" ]; then
  printf '  [SKIP] TC-13: baseline fixture ci.yml が無い\n'
else
  cp "$_T71_CI" "$_T71_FR/.github/workflows/ci.yml"
  _t71_before="$(cksum <"$_T71_FR/.github/workflows/ci.yml")"
  _t71_rc=0
  _t71_out="$(sh "$_T71_FR/scripts/apply-ci-lint-wiring.sh" --apply 2>&1)" || _t71_rc=$?
  _t71_after="$(cksum <"$_T71_FR/.github/workflows/ci.yml")"
  _t71_rc2=0
  _t71_out2="$(PLANGATE_APPLY_CONFIRM=1 sh "$_T71_FR/scripts/apply-ci-lint-wiring.sh" --apply 2>&1)" || _t71_rc2=$?
  if [ "$_t71_rc" -eq 1 ] && [ "$_t71_before" = "$_t71_after" ] \
     && printf '%s' "$_t71_out" | grep -q 'PLANGATE_APPLY_CONFIRM' \
     && [ "$_t71_rc2" -eq 0 ] && grep -q '^  shell-lint:' "$_T71_FR/.github/workflows/ci.yml"; then
    t71_pass "TC-13 実 HO パスへの --apply: 確認なしは exit 1 + 無変更 / 確認ありで適用"
  else
    t71_fail "TC-13 HO 書き込みガードが破れている (no-confirm rc=$_t71_rc / confirm rc=$_t71_rc2)"
  fi
fi

# --- TC-13b 実 repo アンカー probe（read-only）---
# 実 ci.yml に対し --dry-run を 1 回だけ走らせる。dry-run は 1 バイトも書かないので
# HO パスに触れない。実 ci.yml がアンカーを失う方向に drift すれば apply は
# anchor not found で rc=1 になり、ここが落ちる。
#   未適用 checkout -> dry-run 差分で rc=0 / 適用済み checkout -> already applied で rc=0
# どちらでも rc=0 なので **適用状態に依存しない**。
if [ ! -f "$_T71_REAL" ]; then
  printf '  [SKIP] TC-13b: 実 .github/workflows/ci.yml が無い\n'
else
  _t71_before="$(cksum <"$_T71_REAL")"
  _t71_rc=0
  _t71_out="$(sh "$_T71_AP" --dry-run --target "$_T71_REAL" 2>&1)" || _t71_rc=$?
  _t71_after="$(cksum <"$_T71_REAL")"
  if [ "$_t71_rc" -eq 0 ] && [ "$_t71_before" = "$_t71_after" ] \
     && { printf '%s' "$_t71_out" | grep -q 'dry-run' \
          || printf '%s' "$_t71_out" | grep -q 'already applied'; }; then
    t71_pass "TC-13b 実 repo アンカー probe: --dry-run rc=0 かつ実 ci.yml はバイト不変"
  else
    t71_fail "TC-13b 実 ci.yml がアンカーを失っている可能性 (rc=$_t71_rc): $_t71_out"
  fi
fi

# --- TC-14 lint-shell 列挙の自己検査（3 変異すべてで KILL）---
# 「対象 0 件 -> findings 0 件 -> [PASS] rc=0」という恒真 PASS を塞げているか。
_T71_SC="$(mktemp -d)"
register_cleanup "$_T71_SC"
mkdir -p "$_T71_SC/scripts"
cp "$_T71_LS" "$_T71_SC/scripts/lint-shell.sh"
printf '#!/bin/sh\nset -eu\necho ok\n' >"$_T71_SC/scripts/a.sh"
printf '#!/bin/sh\nset -eu\necho ok\n' >"$_T71_SC/scripts/b.sh"
_t71_sc_init=0
if command -v git >/dev/null 2>&1; then
  git -C "$_T71_SC" init -q >/dev/null 2>&1 && git -C "$_T71_SC" add -A >/dev/null 2>&1 || _t71_sc_init=1
else
  _t71_sc_init=1
fi

if [ "$_t71_sc_init" -ne 0 ]; then
  printf '  [SKIP] TC-14/TC-15/TC-16/TC-17: sandbox の初期化に失敗（git 不在等）\n'
else
  # 基準（変異なし）: 3 ファイルで緑になること。これが赤なら以下の KILL は無意味
  _t71_rc=0
  _t71_out="$(PG_LINT_MIN_TARGETS=1 sh "$_T71_SC/scripts/lint-shell.sh" 2>&1)" || _t71_rc=$?
  _t71_base_ok=0
  if printf '%s' "$_t71_out" | grep -q '\[SKIP\] lint-shell'; then
    _t71_base_ok=skip
  elif [ "$_t71_rc" -eq 0 ]; then
    _t71_base_ok=1
  fi

  # 変異 1: 列挙を壊す（git ls-files を存在しない pathspec に固定）
  sed -e 's|^git ls-files -z >|git ls-files -z -- PG-NOPE-NONEXISTENT >|' \
    "$_T71_SC/scripts/lint-shell.sh" >"$_T71_SC/scripts/mut-empty.sh"
  _t71_m1_rc=0
  _t71_m1_out="$(PG_LINT_MIN_TARGETS=1 sh "$_T71_SC/scripts/mut-empty.sh" 2>&1)" || _t71_m1_rc=$?

  # 変異 2: 下限割れ（実装は変えず、下限だけ実際の対象数より大きくする）
  _t71_m2_rc=0
  _t71_m2_out="$(PG_LINT_MIN_TARGETS=9999 sh "$_T71_SC/scripts/lint-shell.sh" 2>&1)" || _t71_m2_rc=$?

  # 変異 3: 自己参照の欠落。**scripts/lint-shell.sh が存在しない**別 sandbox に
  # 別名で置く（同居させると本物が対象に入って変異が効かない＝空振りになる）。
  _T71_SC2="$_T71_SC-renamed"
  register_cleanup "$_T71_SC2"
  rm -rf "$_T71_SC2"
  mkdir -p "$_T71_SC2/scripts"
  cp "$_T71_LS" "$_T71_SC2/scripts/renamed-linter.sh"
  printf '#!/bin/sh\nset -eu\necho ok\n' >"$_T71_SC2/scripts/a.sh"
  _t71_m3_rc=0
  if git -C "$_T71_SC2" init -q >/dev/null 2>&1 && git -C "$_T71_SC2" add -A >/dev/null 2>&1; then
    _t71_m3_out="$(PG_LINT_MIN_TARGETS=1 sh "$_T71_SC2/scripts/renamed-linter.sh" 2>&1)" || _t71_m3_rc=$?
  else
    _t71_m3_out='sandbox init failed'
  fi
  rm -f "$_T71_SC/scripts/mut-empty.sh"
  git -C "$_T71_SC" add -A >/dev/null 2>&1 || true

  if [ "$_t71_base_ok" = skip ]; then
    printf '  [SKIP] TC-14: shellcheck 未導入のため基準（変異なしで緑）を確認できない\n'
  elif [ "$_t71_base_ok" != 1 ]; then
    t71_fail "TC-14 基準が緑でない (rc=$_t71_rc) — 変異の KILL 判定が意味を持たない"
  elif [ "$_t71_m1_rc" -eq 1 ] && printf '%s' "$_t71_m1_out" | grep -q '1 件も解決できなかった' \
    && [ "$_t71_m2_rc" -eq 1 ] && printf '%s' "$_t71_m2_out" | grep -q '下限' \
    && [ "$_t71_m3_rc" -eq 1 ] && printf '%s' "$_t71_m3_out" | grep -q '自分自身'; then
    t71_pass "TC-14 列挙の自己検査: 0 件 / 下限割れ / 自己参照欠落 の 3 変異すべてで FAIL"
  else
    t71_fail "TC-14 恒真 PASS を塞げていない (m1=$_t71_m1_rc m2=$_t71_m2_rc m3=$_t71_m3_rc)"
  fi
fi

# --- TC-15 --advisory（CI では非 gate の run step。rc が立つと job が落ちる）---
if [ "$_t71_sc_init" -eq 0 ]; then
  # warning 相当だけを含むファイル（SC2034 未使用変数）。gate(-S error) では 0 件、
  # advisory(-S warning) では 1 件以上になる非対称を使って「両経路が実際に動いた」
  # ことを示す。
  printf '#!/bin/sh\nset -eu\nunused_var=1\necho done\n' >"$_T71_SC/scripts/warnish.sh"
  # SC1007 の false positive 源（この repo が意図して使う env-prefix 代入）
  printf '#!/bin/sh\nset -eu\nCDPATH= cd -- /tmp || exit 1\necho done\n' >"$_T71_SC/scripts/cdpath.sh"
  git -C "$_T71_SC" add -A >/dev/null 2>&1 || true

  _t71_g_rc=0
  _t71_g_out="$(PG_LINT_MIN_TARGETS=1 sh "$_T71_SC/scripts/lint-shell.sh" 2>&1)" || _t71_g_rc=$?
  _t71_a_rc=0
  _t71_a_out="$(PG_LINT_MIN_TARGETS=1 sh "$_T71_SC/scripts/lint-shell.sh" --advisory 2>&1)" || _t71_a_rc=$?
  # 陽性コントロール: 除外していない生の shellcheck では SC1007 が実際に出ること
  _t71_pc=0
  if command -v shellcheck >/dev/null 2>&1; then
    shellcheck -S warning -f gcc "$_T71_SC/scripts/cdpath.sh" 2>&1 | grep -q 'SC1007' && _t71_pc=1
  fi

  if printf '%s' "$_t71_a_out" | grep -q '\[SKIP\] lint-shell'; then
    printf '  [SKIP] TC-15: shellcheck 未導入のため advisory 経路を評価できない\n'
  elif [ "$_t71_g_rc" -eq 0 ] \
    && [ "$_t71_a_rc" -eq 0 ] \
    && printf '%s' "$_t71_a_out" | grep -Eq '\[INFO\] lint-shell advisory: [1-9][0-9]* finding' \
    && ! printf '%s' "$_t71_a_out" | grep -q 'SC1007' \
    && [ "$_t71_pc" -eq 1 ]; then
    t71_pass "TC-15 advisory: rc=0 かつ [INFO] finding(s)>0 かつ SC1007 は除外（陽性コントロール済）"
  else
    t71_fail "TC-15 advisory 経路が契約どおりでない (gate rc=$_t71_g_rc / advisory rc=$_t71_a_rc / SC1007 陽性コントロール=$_t71_pc)"
  fi
  rm -f "$_T71_SC/scripts/warnish.sh" "$_T71_SC/scripts/cdpath.sh"
  git -C "$_T71_SC" add -A >/dev/null 2>&1 || true
fi

# --- TC-16 CRLF / UTF-8 BOM の shebang を silently skip しない ---
if [ "$_t71_sc_init" -eq 0 ]; then
  printf '#!/bin/sh\r\ncase $x in\r\n' >"$_T71_SC/scripts/crlf-broken"
  printf '\357\273\277#!/bin/sh\ncase $x in\n' >"$_T71_SC/scripts/bom-broken"
  git -C "$_T71_SC" add -A >/dev/null 2>&1 || true
  _t71_rc=0
  _t71_out="$(PG_LINT_MIN_TARGETS=1 sh "$_T71_SC/scripts/lint-shell.sh" 2>&1)" || _t71_rc=$?
  _t71_lst="$(PG_LINT_MIN_TARGETS=1 sh "$_T71_SC/scripts/lint-shell.sh" --list 2>/dev/null)" || true
  if printf '%s' "$_t71_out" | grep -q '\[SKIP\] lint-shell'; then
    printf '  [SKIP] TC-16: shellcheck 未導入のため評価できない\n'
  elif [ "$_t71_rc" -ne 0 ] \
    && printf '%s\n' "$_t71_lst" | grep -qx 'scripts/crlf-broken' \
    && printf '%s\n' "$_t71_lst" | grep -qx 'scripts/bom-broken' \
    && printf '%s' "$_t71_out" | grep -q 'scripts/crlf-broken' \
    && printf '%s' "$_t71_out" | grep -q 'scripts/bom-broken'; then
    t71_pass "TC-16 CRLF / BOM 付き shebang（拡張子なし）を対象に含め違反を検出する"
  else
    t71_fail "TC-16 CRLF / BOM 付きファイルが silently skip されている (rc=$_t71_rc)"
  fi
  rm -f "$_T71_SC/scripts/crlf-broken" "$_T71_SC/scripts/bom-broken"
  git -C "$_T71_SC" add -A >/dev/null 2>&1 || true
fi

# --- TC-17 空白・引用符入りファイル名（xargs -0）---
if [ "$_t71_sc_init" -eq 0 ]; then
  printf '#!/bin/sh\nset -eu\ncase $x in\n' >"$_T71_SC/scripts/zz probe.sh"
  printf '#!/bin/sh\nset -eu\necho ok\n' >"$_T71_SC/scripts/zz'\''quote.sh"
  git -C "$_T71_SC" add -A >/dev/null 2>&1 || true
  _t71_rc=0
  _t71_out="$(PG_LINT_MIN_TARGETS=1 sh "$_T71_SC/scripts/lint-shell.sh" 2>&1)" || _t71_rc=$?
  if printf '%s' "$_t71_out" | grep -q '\[SKIP\] lint-shell'; then
    printf '  [SKIP] TC-17: shellcheck 未導入のため評価できない\n'
  elif [ "$_t71_rc" -ne 0 ] \
    && printf '%s' "$_t71_out" | grep -q 'zz probe.sh' \
    && ! printf '%s' "$_t71_out" | grep -q 'openBinaryFile' \
    && ! printf '%s' "$_t71_out" | grep -q 'unterminated quote'; then
    t71_pass "TC-17 空白 / 引用符入りファイル名でも実際に検査され違反を検出する"
  else
    t71_fail "TC-17 空白・引用符でファイル名が割れている (rc=$_t71_rc)"
  fi
  rm -f "$_T71_SC/scripts/zz probe.sh" "$_T71_SC/scripts/zz'\''quote.sh"
  git -C "$_T71_SC" add -A >/dev/null 2>&1 || true
fi

# --- TC-18 --help がヘッダ全体を出す（行番号ハードコードでない）---
_t71_help_ok=yes
for _t71_s in "$_T71_LS" "$_T71_LW"; do
  _t71_rc=0
  _t71_out="$(sh "$_t71_s" --help 2>&1)" || _t71_rc=$?
  if [ "$_t71_rc" -ne 0 ]; then
    _t71_help_ok="no ($_t71_s rc=$_t71_rc)"
    break
  fi
  # 先頭（2 行目のタイトル）と末尾（Exit codes 節）の両方が出ていること
  # ＝範囲が固定行番号でなくヘッダ全体に追随している
  if ! printf '%s' "$_t71_out" | grep -q 'Usage:'; then
    _t71_help_ok="no ($_t71_s: Usage 節なし)"
    break
  fi
  if ! printf '%s' "$_t71_out" | grep -q 'Exit codes:'; then
    _t71_help_ok="no ($_t71_s: Exit codes 節が欠落＝範囲が短すぎる)"
    break
  fi
  # 本体コードまで漏れていないこと（`set -eu` で止まる）
  if printf '%s' "$_t71_out" | grep -qx 'set -eu'; then
    _t71_help_ok="no ($_t71_s: 本体コードまで出力している)"
    break
  fi
done
if [ "$_t71_help_ok" = yes ]; then
  t71_pass "TC-18 両ラッパの --help がヘッダ全体（Usage〜Exit codes）を出し本体は出さない"
else
  t71_fail "TC-18 usage の範囲が壊れている: $_t71_help_ok"
fi

# --- TC-19 --list が未追跡ファイル非対象を明示する ---
_t71_note_ok=yes
_t71_out="$(sh "$_T71_LS" --list 2>&1)" || _t71_note_ok="no (lint-shell rc)"
if [ "$_t71_note_ok" = yes ] && ! printf '%s' "$_t71_out" | grep -q '未追跡'; then
  _t71_note_ok="no (lint-shell: 注記なし)"
fi
if [ "$_t71_note_ok" = yes ]; then
  _t71_out="$(sh "$_T71_LW" --list 2>&1)" || _t71_note_ok="no (lint-workflows rc)"
fi
if [ "$_t71_note_ok" = yes ] && ! printf '%s' "$_t71_out" | grep -q '未追跡'; then
  _t71_note_ok="no (lint-workflows: 注記なし)"
fi
if [ "$_t71_note_ok" = yes ]; then
  t71_pass "TC-19 --list が「未追跡ファイルは対象外」を明示する"
else
  t71_fail "TC-19 未追跡ファイルの注記がない: $_t71_note_ok"
fi

rm -rf "$_T71_SB" "${_T71_AB:-/nonexistent-ta71}" "${_T71_FR:-/nonexistent-ta71}" "${_T71_SC:-/nonexistent-ta71}" "${_T71_SC2:-/nonexistent-ta71}"

pg_extra_contract_finalize
