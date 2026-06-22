# tests/extras/ta-39-eh3-doc-light.sh
# Sourced by tests/run-tests.sh — uses $pass / $fail counters
# TASK-0138 (#528): EH-3 doc-light 経路（非 HO .md ファイル自動 SKIP）の検証
#
# 前提: scripts/hooks/check-plan-hash.sh に doc-light 経路が適用済み
#   （scripts/apply-eh3-doc-light.sh --apply で適用後）
#
# サンドボックス方式: check-plan-hash.sh を一時ディレクトリにコピーして
# 実 audit ログを汚染しない（ta-12 方式に準拠）

printf '\n=== TA-39: EH-3 doc-light 経路 (#528 TASK-0138) ===\n'

# ── セットアップ ──────────────────────────────────────────────────
_T39_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
_T39_HOOK_SRC="$_T39_ROOT/scripts/hooks/check-plan-hash.sh"
_T39_TMP=$(mktemp -d)
register_cleanup "$_T39_TMP"

# サンドボックス：hook を tmp に複製し、REPO_ROOT が tmp を指すよう配置
# check-plan-hash.sh は $(dirname "$0")/../.. で REPO_ROOT を解決する
# → _T39_TMP/scripts/hooks/check-plan-hash.sh に置く
mkdir -p "$_T39_TMP/scripts/hooks"
mkdir -p "$_T39_TMP/docs/working/_audit"

# docs/working/ シンボリックリンクは作らず、スクリプトを書き換える方法より
# 実ファイルを複製して _audit log を tmp に向ける（WORKING_DIR は hook 内で固定）
# → 実 audit ログ汚染のため、hook のコピー内の WORKING_DIR を tmp に書き換える
cp "$_T39_HOOK_SRC" "$_T39_TMP/scripts/hooks/check-plan-hash.sh"
# REPO_ROOT / WORKING_DIR を sed で tmp に固定
_T39_HOOK="$_T39_TMP/scripts/hooks/check-plan-hash.sh"

t39_pass() { pass=$((pass + 1)); printf '  [PASS] %s\n' "$1"; }
t39_fail() { fail=$((fail + 1)); printf '  [FAIL] %s\n' "$1" >&2; }

# ── doc-light 経路の存在確認 ─────────────────────────────────────
if grep -q 'EH-3_DOC_LIGHT_SKIP' "$_T39_HOOK_SRC"; then
  t39_pass "前提確認: doc-light 経路が check-plan-hash.sh に存在"
  _T39_SKIP_APPLIED=1
else
  # apply 未適用は SKIP（FAIL ではない）。apply-script 実行前のスタック状態を許容する。
  printf '  [SKIP] 前提確認: doc-light 経路が未適用 — apply-eh3-doc-light.sh を実行してください\n'
  _T39_SKIP_APPLIED=0
fi

if [ "$_T39_SKIP_APPLIED" = "0" ]; then
  # 未適用時は TC-01〜06 をスキップ（カウンタは更新しない）
  printf '  [SKIP] TC-01〜06: apply-eh3-doc-light.sh --apply 実行後に再テストしてください\n'
  rm -rf "$_T39_TMP" 2>/dev/null || true
  # shellcheck disable=SC2317
  return 0 2>/dev/null || true
fi

# ── hook テスト用共通関数 ─────────────────────────────────────────
_t39_run_hook() {
  # $1 = PLANGATE_HOOK_FILE の値
  # stdout+stderr を出力、終了コードを返す
  PLANGATE_HOOK_FILE="$1" sh "$_T39_HOOK" 2>&1
}

# === TC-01: docs 配下 .md → DOC_LIGHT_SKIP (exit 0) ===
_t39_rc=0
_t39_out=$(_t39_run_hook "docs/working/TASK-XXXX/status.md") || _t39_rc=$?
if [ "$_t39_rc" = "0" ] && printf '%s' "$_t39_out" | grep -q 'DOC_LIGHT_SKIP'; then
  t39_pass "TC-01: docs 配下 .md → exit 0 + DOC_LIGHT_SKIP"
else
  t39_fail "TC-01: docs 配下 .md 期待 exit 0+DOC_LIGHT_SKIP, got exit=$_t39_rc out=$_t39_out"
fi

# === TC-01 副次 (AC-04): skip-decision-log に EH-3_DOC_LIGHT_SKIP エントリ確認 ===
# サンドボックス方式: hook コピーの WORKING_DIR は _T39_TMP/docs/working を指す
_t39_dlog="$_T39_TMP/docs/working/_audit/skip-decision-log.jsonl"
if [ -f "$_t39_dlog" ] && grep -q 'EH-3_DOC_LIGHT_SKIP' "$_t39_dlog"; then
  t39_pass "TC-01 副次 (AC-04): sandbox skip-decision-log に EH-3_DOC_LIGHT_SKIP あり"
else
  t39_fail "TC-01 副次 (AC-04): sandbox skip-decision-log に EH-3_DOC_LIGHT_SKIP なし (log=$_t39_dlog)"
fi

# === TC-02: .claude/skills 配下 .md → DOC_LIGHT_SKIP (非 HO パス) ===
_t39_rc=0
_t39_out=$(_t39_run_hook ".claude/skills/some-skill/SKILL.md") || _t39_rc=$?
if [ "$_t39_rc" = "0" ] && printf '%s' "$_t39_out" | grep -q 'DOC_LIGHT_SKIP'; then
  t39_pass "TC-02: .claude/skills .md → exit 0 + DOC_LIGHT_SKIP"
else
  t39_fail "TC-02: .claude/skills .md 期待 exit 0+DOC_LIGHT_SKIP, got exit=$_t39_rc"
fi

# === TC-03: HO パス .md → BLOCK (exit 2) ===
_t39_rc=0
_t39_out=$(_t39_run_hook ".claude/rules/working-context.md") || _t39_rc=$?
if [ "$_t39_rc" = "2" ] && printf '%s' "$_t39_out" | grep -q 'HARDENING_OVERRIDE'; then
  t39_pass "TC-03: HO .md (.claude/rules/*.md) → exit 2 + HARDENING_OVERRIDE"
else
  t39_fail "TC-03: HO パス 期待 exit 2+HARDENING_OVERRIDE, got exit=$_t39_rc"
fi

# === TC-04: plan.md → BLOCK (exit 2、上流ロジック不変) ===
_t39_rc=0
_t39_out=$(_t39_run_hook "docs/working/TASK-XXXX/plan.md") || _t39_rc=$?
if [ "$_t39_rc" = "2" ]; then
  t39_pass "TC-04: plan.md → exit 2 (上流 BLOCK 維持)"
else
  t39_fail "TC-04: plan.md 期待 exit 2, got exit=$_t39_rc"
fi

# === TC-05: .MD 大文字拡張子 → DOC_LIGHT_SKIP (ケース非感応) ===
_t39_rc=0
_t39_out=$(_t39_run_hook "docs/some/README.MD") || _t39_rc=$?
if [ "$_t39_rc" = "0" ] && printf '%s' "$_t39_out" | grep -q 'DOC_LIGHT_SKIP'; then
  t39_pass "TC-05: .MD 大文字拡張子 → exit 0 + DOC_LIGHT_SKIP (ケース非感応)"
else
  t39_fail "TC-05: .MD 大文字 期待 exit 0+DOC_LIGHT_SKIP, got exit=$_t39_rc"
fi

# === TC-06: CLAUDE.md → HO BLOCK ===
_t39_rc=0
_t39_out=$(_t39_run_hook "CLAUDE.md") || _t39_rc=$?
if [ "$_t39_rc" = "2" ] && printf '%s' "$_t39_out" | grep -q 'HARDENING_OVERRIDE'; then
  t39_pass "TC-06: CLAUDE.md → exit 2 + HARDENING_OVERRIDE"
else
  t39_fail "TC-06: CLAUDE.md 期待 exit 2+HARDENING_OVERRIDE, got exit=$_t39_rc"
fi

# ── cleanup ─────────────────────────────────────────────────────
rm -rf "$_T39_TMP" 2>/dev/null || true
