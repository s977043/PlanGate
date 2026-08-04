# tests/extras/ta-59-apply-settings-merge.sh
# Sourced by tests/run-tests.sh -- uses $pass / $fail counters
# scripts/apply-claude-settings.sh: settings.example.json hooks の冪等 merge
# （#928 AC-1 前提 / #914 の doctor --check-settings ブロッカー解消）
#
# 背景: 旧実装の merge は「EH-3 引数付与」「EH-9 ブロック取り込み」の 2 分岐
# ハードコードだった。settings.json に check-plan-hash.sh ブロック自体が無く
# EH-9 が既にある実環境では両分岐とも no-op となり、何回実行しても
# `doctor --check-settings` が FAIL（不足 5 件）のままだった。
#
# 隔離（tests/extras/README.md §隔離・後始末の規約）:
#   `.claude/settings*.json` は self-mod ガード対象（HO）のため **一切書かない**。
#   mktemp サンドボックスに scripts/ と .claude/ を複製し、対象スクリプトの
#   ROOT 解決（scripts/ → ..）がサンドボックスを指す性質を使って検証する。
#   trap は張らず register_cleanup + 末尾 rm -rf の二重で回収する。

printf '\n=== TA-59: apply-claude-settings.sh idempotent hooks merge (#928) ===\n'

# 単体実行 fallback（#877 F3 / README 規約）: PG_HARNESS_SOURCED と FIXTURES_DIR
# の AND で判別し、片方でも欠ければ standalone（安全側）へ倒す。
if [ "${PG_HARNESS_SOURCED:-0}" != "1" ] || [ -z "${FIXTURES_DIR:-}" ]; then
  _T59_STANDALONE=1
  # 呼び出し元 env の漏れで hook 挙動が変わるのを防ぐ（run-tests.sh L20 と対称）
  unset PLANGATE_SKIP_REASON PLANGATE_HOOK_TASK PLANGATE_HOOK_FILE \
    PLANGATE_BYPASS_HOOK PLANGATE_HOOK_STRICT PG_HARNESS_SOURCED \
    PLANGATE_ALLOW_MASS_DELETE 2>/dev/null || true
  FIXTURES_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/../fixtures" && pwd)"
  pass=0
  fail=0
  _T59_CLEANUP_PATHS=""
  register_cleanup() {
    for _pg_cp in "$@"; do
      if [ -n "$_pg_cp" ]; then
        _T59_CLEANUP_PATHS="${_T59_CLEANUP_PATHS}${_pg_cp}
"
      fi
    done
  }
else
  _T59_STANDALONE=0
fi

_T59_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
_T59_APPLY="$_T59_ROOT/scripts/apply-claude-settings.sh"
_T59_WIRING="$_T59_ROOT/scripts/check-settings-wiring.sh"
_T59_EXAMPLE="$_T59_ROOT/.claude/settings.example.json"

t59_pass() { pass=$((pass + 1)); printf '  [PASS] %s\n' "$1"; }
t59_fail() { fail=$((fail + 1)); printf '  [FAIL] %s\n' "$1" >&2; }

# サンドボックス生成: <tmp>/scripts/{apply,wiring} + <tmp>/.claude/settings*.json
# $1 = settings.json の中身（空文字なら settings.json を作らない）
_t59_mksbx() {
  _t59_sbx=$(mktemp -d)
  register_cleanup "$_t59_sbx"
  mkdir -p "$_t59_sbx/scripts" "$_t59_sbx/.claude"
  cp "$_T59_APPLY" "$_t59_sbx/scripts/apply-claude-settings.sh"
  cp "$_T59_WIRING" "$_t59_sbx/scripts/check-settings-wiring.sh"
  cp "$_T59_EXAMPLE" "$_t59_sbx/.claude/settings.example.json"
  if [ -n "$1" ]; then
    printf '%s\n' "$1" > "$_t59_sbx/.claude/settings.json"
  fi
}

# 現行 .claude/settings.json 相当（PreToolUse は EH-9 + EH-12 の 2 本だけ）
_T59_MINIMAL='{
  "hooks": {
    "PreToolUse": [
      { "matcher": "Bash", "hooks": [ { "type": "command",
        "command": "sh ${CLAUDE_PROJECT_DIR}/scripts/hooks/check-delegation-commit-boundary.sh" } ] }
    ]
  }
}'

# ローカル固有 hook + 引数なし EH-3 を含む settings.json
_T59_LOCAL='{
  "hooks": {
    "PreToolUse": [
      { "_comment_": "LOCAL ONLY", "matcher": "Edit|Write", "hooks": [ { "type": "command",
        "command": "sh ${CLAUDE_PROJECT_DIR}/scripts/hooks/local-only-example.sh" } ] },
      { "matcher": "Edit|Write", "hooks": [ { "type": "command",
        "command": "sh ${CLAUDE_PROJECT_DIR}/scripts/hooks/check-plan-hash.sh ${PLANGATE_HOOK_TASK:-}" } ] }
    ],
    "Stop": [
      { "_comment_": "LOCAL ONLY Stop", "hooks": [ { "type": "command",
        "command": "sh ${CLAUDE_PROJECT_DIR}/scripts/hooks/local-only-stop.sh" } ] }
    ]
  }
}'

if [ ! -f "$_T59_APPLY" ] || [ ! -f "$_T59_WIRING" ] || [ ! -f "$_T59_EXAMPLE" ]; then
  t59_fail "TA-59 前提ファイル不在（apply / wiring / settings.example.json）"
else

# === TC-01: 不足 hook を取り込み wiring 契約を満たす（V-1）===
_t59_mksbx "$_T59_MINIMAL"
_t59_sbx1="$_t59_sbx"
_t59_rc=0
_t59_out=$(sh "$_t59_sbx1/scripts/apply-claude-settings.sh" 2>&1) || _t59_rc=$?
_t59_wrc=0
sh "$_t59_sbx1/scripts/check-settings-wiring.sh" --target user >/dev/null 2>&1 || _t59_wrc=$?
if [ "$_t59_rc" -eq 0 ] && [ "$_t59_wrc" -eq 0 ]; then
  t59_pass "TC-01 EH-9 のみの settings.json を merge → wiring 契約 PASS (apply rc=0)"
else
  t59_fail "TC-01 merge 後も契約未充足 (apply rc=$_t59_rc / wiring rc=$_t59_wrc): $_t59_out"
fi

# === TC-02: 契約トークンが全件そろう（不足 5 件の解消を個別に確認）===
_t59_missing=""
for _t59_tok in check-plan-exists.sh check-c3-approval.sh check-forbidden-files.sh \
                check-plan-hash.sh '${PLANGATE_HOOK_FILE:-}'; do
  grep -qF "$_t59_tok" "$_t59_sbx1/.claude/settings.json" || _t59_missing="$_t59_missing $_t59_tok"
done
if [ -z "$_t59_missing" ]; then
  t59_pass "TC-02 EH-1 / EH-2 / EH-6 / EH-3 + PLANGATE_HOOK_FILE 引数がすべて配線される"
else
  t59_fail "TC-02 merge 後も不足:$_t59_missing"
fi

# === TC-03: 冪等（2 回目は変更なし・バイト一致）===
cp "$_t59_sbx1/.claude/settings.json" "$_t59_sbx1/after1.json"
_t59_rc=0
_t59_out=$(sh "$_t59_sbx1/scripts/apply-claude-settings.sh" 2>&1) || _t59_rc=$?
if [ "$_t59_rc" -eq 0 ] \
  && cmp -s "$_t59_sbx1/after1.json" "$_t59_sbx1/.claude/settings.json" \
  && printf '%s' "$_t59_out" | grep -q '変更なし'; then
  t59_pass "TC-03 2 回目実行は「変更なし」かつ settings.json がバイト一致（冪等）"
else
  t59_fail "TC-03 冪等でない (rc=$_t59_rc): $_t59_out"
fi

# === TC-04: 「変更なし」出力が「契約準拠」を主張しない（River Review inf-1）===
if printf '%s' "$_t59_out" | grep -q '変更なし' \
  && ! printf '%s' "$_t59_out" | grep -q '既に契約準拠'; then
  t59_pass "TC-04 変更なし文言が契約準拠判定を主張しない（判定は後段 wiring 検証）"
else
  t59_fail "TC-04 変更なし文言が契約準拠を主張している: $_t59_out"
fi

# === TC-05: settings.json 固有ブロックを削除しない（V-3 / mass-delete 思想）===
_t59_mksbx "$_T59_LOCAL"
_t59_sbx2="$_t59_sbx"
_t59_rc=0
_t59_out=$(sh "$_t59_sbx2/scripts/apply-claude-settings.sh" 2>&1) || _t59_rc=$?
if [ "$_t59_rc" -eq 0 ] \
  && grep -qF 'local-only-example.sh' "$_t59_sbx2/.claude/settings.json" \
  && grep -qF 'local-only-stop.sh' "$_t59_sbx2/.claude/settings.json"; then
  t59_pass "TC-05 example に無いローカル固有 hook（PreToolUse / Stop）が保持される"
else
  t59_fail "TC-05 ローカル固有 hook が失われた (rc=$_t59_rc): $_t59_out"
fi

# === TC-06: EH-3 は引数が付与され、ブロックは二重取り込みされない ===
_t59_n=$(grep -cF 'check-plan-hash.sh' "$_t59_sbx2/.claude/settings.json" || true)
if [ "$_t59_n" -eq 1 ] \
  && grep -qF 'check-plan-hash.sh ${PLANGATE_HOOK_TASK:-} ${PLANGATE_HOOK_FILE:-}' \
       "$_t59_sbx2/.claude/settings.json"; then
  t59_pass "TC-06 引数なし EH-3 に PLANGATE_HOOK_FILE を付与し二重配線しない（出現 1 回）"
else
  t59_fail "TC-06 EH-3 の引数付与 or 重複排除に失敗（check-plan-hash.sh 出現 $_t59_n 回）"
fi

# === TC-07: ローカル固有あり sandbox でも冪等 ===
cp "$_t59_sbx2/.claude/settings.json" "$_t59_sbx2/after1.json"
_t59_rc=0
_t59_out=$(sh "$_t59_sbx2/scripts/apply-claude-settings.sh" 2>&1) || _t59_rc=$?
if [ "$_t59_rc" -eq 0 ] && cmp -s "$_t59_sbx2/after1.json" "$_t59_sbx2/.claude/settings.json"; then
  t59_pass "TC-07 ローカル固有 hook 併存下でも 2 回目はバイト一致"
else
  t59_fail "TC-07 ローカル固有併存時に冪等でない (rc=$_t59_rc): $_t59_out"
fi

# === TC-08: 無効 JSON は fail-closed（rc≠0）+ 原本復元 ===
_t59_mksbx '{ "hooks": '
_t59_sbx3="$_t59_sbx"
_t59_rc=0
_t59_out=$(sh "$_t59_sbx3/scripts/apply-claude-settings.sh" 2>&1) || _t59_rc=$?
if [ "$_t59_rc" -ne 0 ] && grep -qF '{ "hooks": ' "$_t59_sbx3/.claude/settings.json"; then
  t59_pass "TC-08 無効 JSON は非 0 で終了し原本を復元する（fail-closed）"
else
  t59_fail "TC-08 無効 JSON が fail-open した (rc=$_t59_rc): $_t59_out"
fi

# === TC-09: --dry-run は settings.json を書き換えない ===
_t59_mksbx "$_T59_MINIMAL"
_t59_sbx4="$_t59_sbx"
cp "$_t59_sbx4/.claude/settings.json" "$_t59_sbx4/before.json"
_t59_rc=0
_t59_out=$(sh "$_t59_sbx4/scripts/apply-claude-settings.sh" --dry-run 2>&1) || _t59_rc=$?
if [ "$_t59_rc" -eq 0 ] \
  && cmp -s "$_t59_sbx4/before.json" "$_t59_sbx4/.claude/settings.json" \
  && printf '%s' "$_t59_out" | grep -q '適用予定'; then
  t59_pass "TC-09 --dry-run は適用予定を出すだけで settings.json を変更しない"
else
  t59_fail "TC-09 --dry-run が settings.json を変更した (rc=$_t59_rc): $_t59_out"
fi

# === TC-10: matcher をローカル拡張した hook を二重配線しない ===
# settings.json 側 `Edit|Write|MultiEdit` は example の `Edit|Write` を包含する。
# 包含判定が無いと同じ hook が Edit/Write で 2 回発火する重複ブロックが生える。
_t59_mksbx '{
  "hooks": {
    "PreToolUse": [
      { "matcher": "Edit|Write|MultiEdit", "hooks": [ { "type": "command",
        "command": "sh ${CLAUDE_PROJECT_DIR}/scripts/check-approval-token-write.sh" } ] }
    ]
  }
}'
_t59_sbx5="$_t59_sbx"
_t59_rc=0
_t59_out=$(sh "$_t59_sbx5/scripts/apply-claude-settings.sh" 2>&1) || _t59_rc=$?
_t59_n=$(grep -cF 'check-approval-token-write.sh' "$_t59_sbx5/.claude/settings.json" || true)
# 期待: ローカルの Edit|Write|MultiEdit 1 本 + example の Bash 1 本 = 2 本
if [ "$_t59_rc" -eq 0 ] && [ "$_t59_n" -eq 2 ]; then
  t59_pass "TC-10 matcher 包含（Edit|Write|MultiEdit ⊇ Edit|Write）を二重配線しない（出現 2 回）"
else
  t59_fail "TC-10 matcher 包含判定に失敗 (rc=$_t59_rc / 出現 $_t59_n 回・期待 2)"
fi

# === TC-11: サンドボックス後片付け（明示 rm -rf の実効確認）===
rm -rf "$_t59_sbx1" "$_t59_sbx2" "$_t59_sbx3" "$_t59_sbx4" "$_t59_sbx5"
if [ ! -d "$_t59_sbx1" ] && [ ! -d "$_t59_sbx2" ] && [ ! -d "$_t59_sbx5" ] \
  && [ ! -d "$_t59_sbx3" ] && [ ! -d "$_t59_sbx4" ]; then
  t59_pass "TC-11 サンドボックスを明示削除（実 .claude/ には一切書き込まない）"
else
  t59_fail "TC-11 サンドボックスが残存"
fi

fi

# standalone 実行時は自前 cleanup を drain して結果を出力
if [ "$_T59_STANDALONE" -eq 1 ]; then
  printf '%s' "$_T59_CLEANUP_PATHS" | while IFS= read -r _pg_cp; do
    [ -n "$_pg_cp" ] || continue
    rm -rf "$_pg_cp" 2>/dev/null || true
  done
  printf '\nResults: %d passed, %d failed\n' "$pass" "$fail"
  [ "$fail" -eq 0 ] || exit 1
fi
