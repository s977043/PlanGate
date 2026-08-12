# tests/extras/ta-63-outcome-contract.sh
# PG_EXTRA_CAPABILITY: standalone-capable
# Sourced by tests/run-tests.sh — uses $pass / $fail counters
# #1061: 委譲プロトコル適用機構（薄い実行入口 skill + OUTCOME 機械検証）の回帰テスト。
#
#   TC-01〜06: subagent-delegation-brief skill が 2 配置に存在し byte-identical で、
#              8 要素チェックリスト / 要素 4 の反証許可 / 要素 7 の OUTCOME 導線 /
#              成果物形式 / worktree 定型を持ち、正本へリンクしていること
#   TC-07〜08: scripts/check-outcome-contract.sh の存在・構文・正例 exit 0
#   TC-09〜17: 負側 9 ケース（表記ゆれ 3 / 複数出現 / 最終行でない / OUTCOME なし /
#              要判断事項 未分類 / 要判断事項 セクション欠落 / 検証状態 欠落）が
#              すべて非ゼロ exit。未分類と欠落は診断メッセージで区別されること

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
pg_extra_contract_init ta-63-outcome-contract standalone-capable

# ta-26 TC-33（静的検査 / README 規約 8）準拠: FIXTURES_DIR:- を含む extras は
# standalone 経路で runner と同一の 7 env unset を自ファイル内に持つ必要がある。
if pg_extra_contract_is_standalone; then
  unset PLANGATE_SKIP_REASON PLANGATE_HOOK_TASK PLANGATE_HOOK_FILE PLANGATE_BYPASS_HOOK PLANGATE_HOOK_STRICT PG_HARNESS_SOURCED PLANGATE_ALLOW_MASS_DELETE 2>/dev/null || true
fi

printf '\n=== TA-63: subagent delegation brief + OUTCOME contract (#1061) ===\n'

t63_pass() { pass=$((pass + 1)); printf '  [PASS] %s\n' "$1"; }
t63_fail() { fail=$((fail + 1)); printf '  [FAIL] %s\n' "$1" >&2; }

_T63_ROOT="$(CDPATH= cd -- "$_pg_extra_dir/../.." && pwd)"
_T63_AGENTS_SKILL="$_T63_ROOT/.agents/skills/subagent-delegation-brief/SKILL.md"
_T63_CLAUDE_SKILL="$_T63_ROOT/.claude/skills/subagent-delegation-brief/SKILL.md"
_T63_SCRIPT="$_T63_ROOT/scripts/check-outcome-contract.sh"

_T63_TMP="${TMPDIR:-/tmp}/pg-ta63-$$"
rm -rf "$_T63_TMP"
mkdir -p "$_T63_TMP"
if command -v register_cleanup >/dev/null 2>&1; then
  register_cleanup "$_T63_TMP"
fi

# ---------------------------------------------------------------- skill 配置

# TC-01: 正本（.agents/skills）に存在
if [ -f "$_T63_AGENTS_SKILL" ]; then
  t63_pass "TC-01 .agents/skills/subagent-delegation-brief/SKILL.md が存在（skills の正本側）"
else
  t63_fail "TC-01 .agents/skills 側の SKILL.md が不在"
fi

# TC-02: セッション側（.claude/skills）に存在
if [ -f "$_T63_CLAUDE_SKILL" ]; then
  t63_pass "TC-02 .claude/skills/subagent-delegation-brief/SKILL.md が存在（HEAD 反映側）"
else
  t63_fail "TC-02 .claude/skills 側の SKILL.md が不在"
fi

# TC-03: 2 配置が byte-identical（二重配置の drift 検出）
if [ -f "$_T63_AGENTS_SKILL" ] && [ -f "$_T63_CLAUDE_SKILL" ] && diff "$_T63_AGENTS_SKILL" "$_T63_CLAUDE_SKILL" >/dev/null 2>&1; then
  t63_pass "TC-03 .agents 側と .claude 側の SKILL.md が byte-identical"
else
  t63_fail "TC-03 2 配置の SKILL.md に差分がある（または片側不在）"
fi

# TC-04: frontmatter は name / description の 2 キーのみ
if [ -f "$_T63_AGENTS_SKILL" ]; then
  _t63_fm_keys=$(awk 'NR==1 && $0=="---" {inside=1; next} inside && $0=="---" {exit} inside && /^[a-zA-Z_]+:/ {sub(/:.*/,""); print}' "$_T63_AGENTS_SKILL")
  if [ "$(printf '%s\n' "$_t63_fm_keys" | grep -c .)" = "2" ] \
    && printf '%s\n' "$_t63_fm_keys" | grep -qx 'name' \
    && printf '%s\n' "$_t63_fm_keys" | grep -qx 'description'; then
    t63_pass "TC-04 frontmatter は name / description の 2 キーのみ"
  else
    t63_fail "TC-04 frontmatter のキー構成が想定外: $(printf '%s' "$_t63_fm_keys" | tr '\n' ' ')"
  fi
else
  t63_fail "TC-04 SKILL.md 不在のため frontmatter を検査できない"
fi

# TC-05: 本文が 8 要素チェックリストと必須の追加規約を持つ
if [ -f "$_T63_AGENTS_SKILL" ]; then
  _t63_missing=''
  for _t63_kw in '却下済み' '反証' 'OUTCOME' 'P0' '検証状態' 'worktree' '成果物'; do
    grep -q "$_t63_kw" "$_T63_AGENTS_SKILL" || _t63_missing="$_t63_missing $_t63_kw"
  done
  # 8 要素すべてが番号付きで列挙されているか（1〜8 の行頭 | N |）
  _t63_elems=0
  for _t63_n in 1 2 3 4 5 6 7 8; do
    grep -q "^| $_t63_n |" "$_T63_AGENTS_SKILL" && _t63_elems=$((_t63_elems + 1))
  done
  if [ -z "$_t63_missing" ] && [ "$_t63_elems" = "8" ]; then
    t63_pass "TC-05 8 要素チェックリスト + 要素4(却下済み/反証) + 要素7(OUTCOME/P0/検証状態) + worktree/成果物 を含む"
  else
    t63_fail "TC-05 不足キーワード:${_t63_missing:- なし} / 列挙された要素数=$_t63_elems (期待 8)"
  fi
else
  t63_fail "TC-05 SKILL.md 不在のため本文を検査できない"
fi

# TC-06: 正本へリンクしている（契約本文を複製せず参照で到達する）
if [ -f "$_T63_AGENTS_SKILL" ] \
  && grep -q 'docs/ai/subagent-delegation/dispatch-template.md' "$_T63_AGENTS_SKILL" \
  && grep -q 'docs/ai/subagent-delegation/outcome-contract.md' "$_T63_AGENTS_SKILL"; then
  t63_pass "TC-06 dispatch-template / outcome-contract の正本へリンクしている"
else
  t63_fail "TC-06 正本（dispatch-template / outcome-contract）へのリンクが無い"
fi

# ------------------------------------------------------- check-outcome-contract

# TC-07: スクリプト存在・実行可能・構文
if [ -f "$_T63_SCRIPT" ] && [ -x "$_T63_SCRIPT" ] && sh -n "$_T63_SCRIPT" 2>/dev/null; then
  t63_pass "TC-07 check-outcome-contract.sh 存在・実行可能・sh -n OK"
else
  t63_fail "TC-07 check-outcome-contract.sh が不在 / 非実行可能 / 構文エラー"
fi

_t63_write() {
  # _t63_write <path> — 本体は標準入力から
  cat > "$1"
}

_t63_neg() {
  # _t63_neg <label> <fixture-path> [期待する診断キーワード]
  if [ ! -x "$_T63_SCRIPT" ]; then
    t63_fail "$1（スクリプト不在のため判定不能）"
    return 0
  fi
  _t63_out=$(sh "$_T63_SCRIPT" "$2" 2>&1) && _t63_rc=0 || _t63_rc=$?
  if [ "$_t63_rc" = "0" ]; then
    t63_fail "$1 — 契約違反なのに exit 0 になった"
    return 0
  fi
  if [ -n "${3:-}" ] && ! printf '%s' "$_t63_out" | grep -q "$3"; then
    t63_fail "$1 — 非ゼロ exit だが診断に '$3' を含まない"
    return 0
  fi
  t63_pass "$1 rc=${_t63_rc}"
}

# 正例
_t63_write "$_T63_TMP/ok.txt" <<'EOF'
結論: 対象スクリプトを追加した。

成果物: scripts/example.sh

## 要判断事項

- [P1] 命名を統一する余地がある（今回は既存踏襲）

## 検証結果

- 単体テスト `sh tests/example.sh`: 実行済み（3 件 PASS / 0 件 FAIL）
- 負荷試験: 未検証（計測環境が無いため）

OUTCOME: success
EOF

# TC-08: 正例は exit 0
if [ -x "$_T63_SCRIPT" ]; then
  if sh "$_T63_SCRIPT" "$_T63_TMP/ok.txt" >/dev/null 2>&1; then
    t63_pass "TC-08 契約準拠の報告は exit 0"
  else
    t63_fail "TC-08 契約準拠の報告を FAIL 判定した（false positive）"
  fi
else
  t63_fail "TC-08 スクリプト不在のため正例を判定できない"
fi

# TC-09: 小文字 Outcome
sed 's/^OUTCOME: success$/Outcome: success/' "$_T63_TMP/ok.txt" > "$_T63_TMP/n1.txt"
_t63_neg "TC-09 負例 'Outcome: success'（小文字）" "$_T63_TMP/n1.txt" 'OUTCOME'

# TC-10: スペースなし
sed 's/^OUTCOME: success$/OUTCOME:success/' "$_T63_TMP/ok.txt" > "$_T63_TMP/n2.txt"
_t63_neg "TC-10 負例 'OUTCOME:success'（スペースなし）" "$_T63_TMP/n2.txt" 'OUTCOME'

# TC-11: コロン前スペース
sed 's/^OUTCOME: success$/OUTCOME : success/' "$_T63_TMP/ok.txt" > "$_T63_TMP/n3.txt"
_t63_neg "TC-11 負例 'OUTCOME : success'（コロン前スペース）" "$_T63_TMP/n3.txt" 'OUTCOME'

# TC-12: 複数出現
{ cat "$_T63_TMP/ok.txt"; printf 'OUTCOME: partial\n'; } > "$_T63_TMP/n4.txt"
_t63_neg "TC-12 負例 OUTCOME 行が複数出現" "$_T63_TMP/n4.txt" 'OUTCOME'

# TC-13: 最終行でない
{ cat "$_T63_TMP/ok.txt"; printf '補足: 追記した本文\n'; } > "$_T63_TMP/n5.txt"
_t63_neg "TC-13 負例 OUTCOME 行の後に本文が続く" "$_T63_TMP/n5.txt" '最終行'

# TC-14: OUTCOME 行が無い
grep -v '^OUTCOME: ' "$_T63_TMP/ok.txt" > "$_T63_TMP/n6.txt"
_t63_neg "TC-14 負例 OUTCOME 行が無い" "$_T63_TMP/n6.txt" 'OUTCOME'

# TC-15: 要判断事項が優先度なし
sed 's/^- \[P1\] /- /' "$_T63_TMP/ok.txt" > "$_T63_TMP/n7.txt"
_t63_neg "TC-15 負例 要判断事項に P0/P1/P2 分類が無い" "$_T63_TMP/n7.txt" '分類'

# TC-16: 要判断事項セクション自体が無い（TC-15 と別診断であること）
sed -e '/^## 要判断事項$/d' -e '/^- \[P1\] /d' "$_T63_TMP/ok.txt" > "$_T63_TMP/n8.txt"
if [ -x "$_T63_SCRIPT" ]; then
  _t63_o7=$(sh "$_T63_SCRIPT" "$_T63_TMP/n7.txt" 2>&1) || true
  _t63_o8=$(sh "$_T63_SCRIPT" "$_T63_TMP/n8.txt" 2>&1) && _t63_rc8=0 || _t63_rc8=$?
  if [ "${_t63_rc8:-0}" != "0" ] && [ "$_t63_o7" != "$_t63_o8" ]; then
    t63_pass "TC-16 要判断事項セクション欠落を非ゼロ exit + TC-15 と異なる診断で報告"
  else
    t63_fail "TC-16 セクション欠落が exit 0、または未分類と同一診断（区別できていない）"
  fi
else
  t63_fail "TC-16 スクリプト不在のため判定できない"
fi

# TC-17: 検証状態 4 区分が無い（sed の \n 置換は BSD/GNU で挙動が割れるため直書き）
_t63_write "$_T63_TMP/n9.txt" <<'EOF'
結論: 対象スクリプトを追加した。

成果物: scripts/example.sh

## 要判断事項

- [P1] 命名を統一する余地がある（今回は既存踏襲）

## 検証結果

- テストは問題ありません

OUTCOME: success
EOF
_t63_neg "TC-17 負例 検証状態が 4 区分で明示されていない" "$_T63_TMP/n9.txt" '検証'

rm -rf "$_T63_TMP"

pg_extra_contract_finalize
