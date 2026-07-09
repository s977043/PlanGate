# tests/extras/ta-54-ai-loop-link-selfcontained.sh
# Sourced by tests/run-tests.sh — uses $pass / $fail counters
# issue #790: plugin/plangate/skills/ai-loop-cycle/references/ の markdown リンクを
# 自己完結化（同一実体のbundle内部 → ./name.md、本スキル自身の SKILL.md →
# ../SKILL.md、それ以外の外部・別実体 → インラインコード化）する
# sync-plugin-plangate.sh 改修の検証。3 レーンレビュー反映（basename 衝突の
# 誤ポイント是正・変換差分検証力の強化・dead-link 走査の拡張）。

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
# （rule 2）。inline link `](../` に加え、参照定義 `]: ../` と autolink
# `<../...>` も検出対象に含める（現コーパスに無くても将来の堅牢化 / F2）。
if [ -d "$PG_T54_REFS" ]; then
  _t54_dead=$(grep -rnE '\]\(\.\./|\]:[[:space:]]*\.\./|<\.\./' "$PG_T54_REFS"/*.md 2>/dev/null \
    | grep -v '](\.\./SKILL\.md' || true)
else
  _t54_dead="NO_REFS_DIR"
fi
if [ -z "$_t54_dead" ]; then
  t54_pass "TC-01 dead-link 0（../SKILL.md 以外の ../ 参照が inline/ref/autolink とも 0）"
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

# TC-03a: 変換差分検証力（F3）— **実際に変換された行**を assert する。
# adaptive-production-loop.md の arbiter-policy 参照は正本で
# `](../../ai/ai-loop/arbiter-policy.md)`（cross-dir 相対）であり、変換後は
# `](./arbiter-policy.md)` になる。同時に正本側には `./arbiter-policy.md` が
# **無い**ことを確認し、無変換でも PASS してしまう空振りを防ぐ。
if [ -f "$PG_T54_REFS/adaptive-production-loop.md" ] \
  && grep -q '](\./arbiter-policy\.md)' "$PG_T54_REFS/adaptive-production-loop.md" 2>/dev/null \
  && ! grep -q '](\./arbiter-policy\.md)' "$PG_T54_ROOT/docs/workflows/ai-loop/adaptive-production-loop.md" 2>/dev/null; then
  t54_pass "TC-03a cross-dir bundle 参照が実際に ./arbiter-policy.md へ変換された（正本には無い）"
else
  t54_fail "TC-03a ./arbiter-policy.md への変換を確認できない（変換差分検証力）"
fi

# TC-03b: 外部参照（working-context.md）がインラインコードに変換されていること
if [ -f "$PG_T54_REFS/00_concept.md" ] \
  && grep -q '`working-context\.md`' "$PG_T54_REFS/00_concept.md" 2>/dev/null \
  && ! grep -q '\]\([^)]*working-context\.md\)' "$PG_T54_REFS/00_concept.md" 2>/dev/null; then
  t54_pass "TC-03b 外部参照（working-context.md）がインラインコードに変換されている"
else
  t54_fail "TC-03b 外部参照（working-context.md）のインラインコード変換を確認できない"
fi

# TC-03c: basename 衝突の誤ポイント回帰固定（Finding 1）。
# design-philosophy.md の `../subagent-delegation/README.md`（= 委譲プロトコル
# README、別実体）が basename `README.md` の衝突で ai-loop の README へ silent
# 誤ポイントしていた。同一実体判定により inline code `subagent-delegation/README.md`
# になり、`](./README.md)` 誤リンクが **存在しない** ことを assert する。
if [ -f "$PG_T54_REFS/design-philosophy.md" ] \
  && grep -q '`subagent-delegation/README\.md`' "$PG_T54_REFS/design-philosophy.md" 2>/dev/null \
  && ! grep -q '](\./README\.md)' "$PG_T54_REFS/design-philosophy.md" 2>/dev/null; then
  t54_pass "TC-03c basename 衝突が別実体として inline 化・./README.md 誤リンクなし"
else
  t54_fail "TC-03c 誤ポイント是正を確認できない（subagent-delegation/README.md）"
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

# restore（RiverReview I-3 hardening）— backup 存在を検証してから破壊的復元し、
# 復元失敗を検知して非ゼロ終了（$fail 加算）する。CI の tmp 書込失敗時に real
# plugin/plangate を破壊したまま復旧できずツリー汚染する経路を塞ぐ。
if [ -d "$PG_T54_TMPDIR/plugin_backup" ] && [ -n "$(ls -A "$PG_T54_TMPDIR/plugin_backup" 2>/dev/null)" ]; then
  rm -rf "$PG_T54_PLUGIN"
  if cp -r "$PG_T54_TMPDIR/plugin_backup" "$PG_T54_PLUGIN" 2>/dev/null; then
    :
  else
    t54_fail "TC-restore plugin/plangate の復元に失敗（ツリー汚染の可能性・要手動復旧）"
  fi
else
  t54_fail "TC-restore backup 不在のため復元スキップ（plugin/plangate を破壊しない）"
fi
rm -rf "$PG_T54_TMPDIR"
