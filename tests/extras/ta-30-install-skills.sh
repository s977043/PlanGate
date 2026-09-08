# tests/extras/ta-30-install-skills.sh
# Sourced by tests/run-tests.sh — uses $pass / $fail counters
# Plugin 配布の中核スクリプト install-plangate-skills.sh の回帰テスト

printf '\n=== TA-30: install-skills coverage ===\n'

PG_T30_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
PG_T30_SH="$PG_T30_ROOT/plugin/plangate/scripts/install-plangate-skills.sh"
PG_T30_TOCODEX="$PG_T30_ROOT/scripts/install-plangate-skills-to-codex.sh"
PG_T30_SPEC="$PG_T30_ROOT/scripts/check-codex-skill-spec.sh"

t30_pass() { pass=$((pass + 1)); printf '  [PASS] %s\n' "$1"; }
t30_fail() { fail=$((fail + 1)); printf '  [FAIL] %s\n' "$1" >&2; }

# TC-01: install-plangate-skills.sh 存在・実行可能
if [ -f "$PG_T30_SH" ] && [ -x "$PG_T30_SH" ]; then
  t30_pass "TC-01 install-plangate-skills.sh 存在・実行可能"
else
  t30_fail "TC-01 不在 or 非実行可能"
fi

# TC-01b: to-codex installer は「変更なし」でも rc=0 を返す（#1308 の退行検出 / 2026-09-09）
#   2026-09-08 に末尾へ `[ "$curated_count" -gt 0 ] && printf ...` を足したことで、
#   curated が 0 件のとき最終コマンドの rc=1 がスクリプトの rc になり、
#   **同期済みで何もすることが無い通常実行が「失敗」を返す**退行が main に入った。
#   `sh -n`（TC-02）では捕まらない。実行して rc を見る TC が要る。
#
#   installer は ROOT_DIR を $0 の親の親から求め、書き込み先を $ROOT_DIR/.codex/skills に
#   固定する（--target 相当のオプションは無い）。そこで **mktemp サンドボックスへ
#   ROOT_DIR 相当の最小構成を複製し、その中の scripts/ から起動**する。
#   実 repo の .codex/ には一切書き込まない。
_t30_cx=$(mktemp -d 2>/dev/null || printf '')
if [ -n "$_t30_cx" ]; then
  mkdir -p "$_t30_cx/scripts" "$_t30_cx/.agents" "$_t30_cx/plugin/plangate"
  cp "$PG_T30_TOCODEX" "$_t30_cx/scripts/"
  cp -R "$PG_T30_ROOT/.agents/skills" "$_t30_cx/.agents/" 2>/dev/null || true
  cp -R "$PG_T30_ROOT/plugin/plangate/assets" "$_t30_cx/plugin/plangate/" 2>/dev/null || true

  # 1 回目: 全 skill を展開
  sh "$_t30_cx/scripts/install-plangate-skills-to-codex.sh" >/dev/null 2>&1
  _t30_cx_rc1=$?
  # 2 回目: 変更なし（installed 0 件 / curated 0 件）でも rc=0 でなければならない
  sh "$_t30_cx/scripts/install-plangate-skills-to-codex.sh" >/dev/null 2>&1
  _t30_cx_rc2=$?

  if [ "$_t30_cx_rc1" -eq 0 ] && [ "$_t30_cx_rc2" -eq 0 ]; then
    t30_pass "TC-01b to-codex installer は初回・再実行とも rc=0 (rc1=$_t30_cx_rc1 rc2=$_t30_cx_rc2)"
  else
    t30_fail "TC-01b to-codex installer の rc が 0 でない (rc1=$_t30_cx_rc1 rc2=$_t30_cx_rc2)"
  fi

  # TC-01c: サンドボックスが実際に生成物を持つ（TC-01b が「何もせず rc=0」で通っていない対照）
  _t30_cx_n=$(ls "$_t30_cx/.codex/skills" 2>/dev/null | wc -l | tr -d ' ')
  if [ "${_t30_cx_n:-0}" -gt 0 ]; then
    t30_pass "TC-01c サンドボックスに skill が展開された (n=$_t30_cx_n・件数は契約値にしない)"
  else
    t30_fail "TC-01c サンドボックスに展開物が無い — TC-01b は空振りの可能性 (n=${_t30_cx_n:-0})"
  fi

  rm -rf "$_t30_cx"
else
  t30_fail "TC-01b mktemp -d 失敗"
fi

# TC-02: syntax（両スクリプト）
if sh -n "$PG_T30_SH" 2>/dev/null && sh -n "$PG_T30_TOCODEX" 2>/dev/null; then
  t30_pass "TC-02 sh -n syntax check（両スクリプト）"
else
  t30_fail "TC-02 syntax error"
fi

# TC-03: --help が exit 0
if sh "$PG_T30_SH" --help >/dev/null 2>&1; then
  t30_pass "TC-03 --help が exit 0"
else
  t30_fail "TC-03 --help が exit 非0"
fi

# 一時ディレクトリを作成（空文字ガード: mktemp 失敗時に --target "" で
# リポジトリの .codex/skills を上書きする事故を防ぐ）。TC-04〜06 で共用。
_t30_tmp=$(mktemp -d)
if [ -n "$_t30_tmp" ] && [ -d "$_t30_tmp" ]; then
  sh "$PG_T30_SH" --target "$_t30_tmp" >/dev/null 2>&1

  # TC-04: 展開数 = plugin/plangate/skills 数（POSIX シェルループでカウント）
  _t30_src=0
  for _d in "$PG_T30_ROOT/plugin/plangate/skills"/*; do
    [ -d "$_d" ] && _t30_src=$((_t30_src + 1))
  done
  _t30_out=0
  for _d in "$_t30_tmp"/*; do
    [ -d "$_d" ] && _t30_out=$((_t30_out + 1))
  done
  if [ "$_t30_out" = "$_t30_src" ] && [ "$_t30_out" -gt 0 ]; then
    t30_pass "TC-04 --target 展開数($_t30_out) = plugin skills 数($_t30_src)"
  else
    t30_fail "TC-04 展開数不一致: out=$_t30_out src=$_t30_src"
  fi

  # TC-05: 展開物が check-codex-skill-spec を PASS
  if sh "$PG_T30_SPEC" --target "$_t30_tmp" >/dev/null 2>&1; then
    t30_pass "TC-05 展開物が check-codex-skill-spec PASS"
  else
    t30_fail "TC-05 spec check が FAIL"
  fi

  # TC-06: 各展開スキルに SKILL.md + agents/openai.yaml（サンプル: brainstorming）
  if [ -f "$_t30_tmp/brainstorming/SKILL.md" ] && [ -f "$_t30_tmp/brainstorming/agents/openai.yaml" ]; then
    t30_pass "TC-06 展開スキルに SKILL.md + agents/openai.yaml"
  else
    t30_fail "TC-06 展開スキルの構造不備"
  fi

  # TC-07: bundled resources 展開（ai-loop-cycle: references/ 17 + scripts/ 2）
  _t30_refs=0; _t30_scr=0
  for _f in "$_t30_tmp"/ai-loop-cycle/references/*.md; do
    [ -f "$_f" ] && _t30_refs=$((_t30_refs+1))
  done
  for _f in "$_t30_tmp"/ai-loop-cycle/scripts/*.py; do
    [ -f "$_f" ] && _t30_scr=$((_t30_scr+1))
  done
  if [ "$_t30_refs" -ge 17 ] && [ "$_t30_scr" -ge 2 ]; then
    t30_pass "TC-07 bundled resources 展開 (references=$_t30_refs scripts=$_t30_scr)"
  else
    t30_fail "TC-07 bundled resources 欠落 (references=$_t30_refs scripts=$_t30_scr)"
  fi

  # TC-08: 展開先で arbiter テストが自立 PASS（bundled 配置の ho-paths 解決）
  if python3 "$_t30_tmp/ai-loop-cycle/scripts/test_arbiter.py" >/dev/null 2>&1; then
    t30_pass "TC-08 展開先 arbiter テスト自立 PASS"
  else
    t30_fail "TC-08 展開先 arbiter テスト FAIL"
  fi

  # TC-09: 2 回目実行は全 skip（bundled 込み up-to-date 判定）
  _t30_out2=$(sh "$PG_T30_SH" --target "$_t30_tmp" 2>/dev/null | grep -oE 'installed: [0-9]+' | grep -oE '[0-9]+' || printf '')
  if [ "${_t30_out2:-x}" = "0" ]; then
    t30_pass "TC-09 2 回目実行は installed:0（up-to-date skip）"
  else
    t30_fail "TC-09 2 回目で再展開が発生 (installed=${_t30_out2:-?})"
  fi

  rm -rf "$_t30_tmp"
else
  t30_fail "TC-04 mktemp -d 失敗（TC-04〜06 をスキップ）"
fi
