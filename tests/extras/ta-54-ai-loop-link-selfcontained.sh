# tests/extras/ta-54-ai-loop-link-selfcontained.sh
# Sourced by tests/run-tests.sh — uses $pass / $fail counters
# issue #790: plugin/plangate/skills/ai-loop-cycle/references/ の markdown リンクを
# 自己完結化（bundle内部 → ./name.md、本スキル自身の SKILL.md → ../SKILL.md、
# それ以外の外部正本 → インラインコード化）する sync-plugin-plangate.sh 改修の検証。

printf '\n=== TA-54: ai-loop plugin bundle link self-containment (issue #790) ===\n'

PG_T54_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
PG_T54_SCRIPT="$PG_T54_ROOT/scripts/sync-plugin-plangate.sh"
PG_T54_REWRITER="$PG_T54_ROOT/scripts/_ai_loop_link_rewrite.py"
PG_T54_PLUGIN="$PG_T54_ROOT/plugin/plangate"
PG_T54_REFS="$PG_T54_PLUGIN/skills/ai-loop-cycle/references"

t54_pass() { pass=$((pass + 1)); printf '  [PASS] %s\n' "$1"; }
t54_fail() { fail=$((fail + 1)); printf '  [FAIL] %s\n' "$1" >&2; }

# TC-00: rewriter helper 存在・構文チェック（scripts/_*.py は HO 外 / mode-classification.md）
if [ -f "$PG_T54_REWRITER" ] && python3 -m py_compile "$PG_T54_REWRITER" 2>/dev/null; then
  t54_pass "TC-00 _ai_loop_link_rewrite.py 存在・compile OK"
else
  t54_fail "TC-00 _ai_loop_link_rewrite.py 不在 or compile error"
fi

# 実行前に plugin/plangate 全体をバックアップ（ta-26 と同じ流儀。テスト実行が
# 他テストや実リポジトリ状態を汚染しないようにする / #530-3 trap 非依存）
PG_T54_TMPDIR=$(mktemp -d)
register_cleanup "$PG_T54_TMPDIR"
cp -r "$PG_T54_PLUGIN" "$PG_T54_TMPDIR/plugin_backup"

# 1 回目の sync 実行（dead-link 0 検証・変換内容検証はこの後の状態に対して行う）
sh "$PG_T54_SCRIPT" >/dev/null 2>&1 || true

# TC-01: dead-link 0 検証。ただし本スキル自身の SKILL.md 参照（../SKILL.md）は
# references/ の親ディレクトリに実在するため意図的な例外として除外する
# （rule 2）。それ以外の `](../` パターンが 1 件でも残っていれば dead link。
if [ -d "$PG_T54_REFS" ]; then
  _t54_dead=$(grep -rnE '\]\(\.\./' "$PG_T54_REFS"/*.md 2>/dev/null | grep -v '](\.\./SKILL\.md' || true)
else
  _t54_dead="NO_REFS_DIR"
fi
if [ -z "$_t54_dead" ]; then
  t54_pass "TC-01 dead-link 0（../SKILL.md 以外の ](../ パターンなし）"
else
  t54_fail "TC-01 dead link 残存: $_t54_dead"
fi

# TC-02: 冪等性 — 2 回目の sync 実行で references/ に追加差分が出ないこと
_t54_hash_before=$(find "$PG_T54_REFS" -type f 2>/dev/null | sort | xargs cat 2>/dev/null | md5sum 2>/dev/null || find "$PG_T54_REFS" -type f 2>/dev/null | sort | xargs cat 2>/dev/null | cksum)
sh "$PG_T54_SCRIPT" >/dev/null 2>&1 || true
_t54_hash_after=$(find "$PG_T54_REFS" -type f 2>/dev/null | sort | xargs cat 2>/dev/null | md5sum 2>/dev/null || find "$PG_T54_REFS" -type f 2>/dev/null | sort | xargs cat 2>/dev/null | cksum)
if [ "$_t54_hash_before" = "$_t54_hash_after" ]; then
  t54_pass "TC-02 2 回目の sync で references/ に差分なし（冪等性）"
else
  t54_fail "TC-02 2 回目の sync で references/ に差分あり（冪等性違反）"
fi

# TC-03: 変換の正しさ — bundle 内部参照（00_concept.md）が ./00_concept.md に、
# 外部参照（working-context.md）が inline code に変換されていること
if [ -f "$PG_T54_REFS/adaptive-production-loop.md" ] \
  && grep -q '](\./00_concept\.md)' "$PG_T54_REFS/adaptive-production-loop.md" 2>/dev/null; then
  t54_pass "TC-03a bundle 内部参照が ./00_concept.md に変換されている"
else
  t54_fail "TC-03a bundle 内部参照（00_concept.md）の変換を確認できない"
fi

if [ -f "$PG_T54_REFS/00_concept.md" ] \
  && grep -q '`working-context\.md`' "$PG_T54_REFS/00_concept.md" 2>/dev/null \
  && ! grep -q '\]\([^)]*working-context\.md\)' "$PG_T54_REFS/00_concept.md" 2>/dev/null; then
  t54_pass "TC-03b 外部参照（working-context.md）がインラインコードに変換されている"
else
  t54_fail "TC-03b 外部参照（working-context.md）のインラインコード変換を確認できない"
fi

# TC-04: 本スキル自身の SKILL.md 参照は ../SKILL.md のまま維持される（rule 2、
# references/ の親に実在するため dead link ではない）
if [ -f "$PG_T54_REFS/execution-runbook.md" ] \
  && grep -q '](\.\./SKILL\.md)' "$PG_T54_REFS/execution-runbook.md" 2>/dev/null; then
  t54_pass "TC-04 本スキル自身の SKILL.md 参照が ../SKILL.md に正規化されている"
else
  t54_fail "TC-04 ../SKILL.md への正規化を確認できない"
fi

# TC-05: 正本 docs/workflows/ai-loop/*.md・docs/ai/ai-loop/*.md は変更されない
# （リンク変換は plugin コピーにのみ適用。sync 実行によるワークツリー差分が
# 正本側に出ていないことを git status で確認）
_t54_src_dirty=$(git -C "$PG_T54_ROOT" status --porcelain -- docs/workflows/ai-loop docs/ai/ai-loop 2>/dev/null || true)
if [ -z "$_t54_src_dirty" ]; then
  t54_pass "TC-05 正本 docs/workflows/ai-loop・docs/ai/ai-loop は無変更"
else
  t54_fail "TC-05 正本 docs に意図しない差分: $_t54_src_dirty"
fi

# restore（ta-26 と同じ流儀 — テストが実リポジトリ state を変えたままにしない）
rm -rf "$PG_T54_PLUGIN"
cp -r "$PG_T54_TMPDIR/plugin_backup" "$PG_T54_PLUGIN"
rm -rf "$PG_T54_TMPDIR"
