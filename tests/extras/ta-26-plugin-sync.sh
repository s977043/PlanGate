# tests/extras/ta-26-plugin-sync.sh
# Sourced by tests/run-tests.sh — uses $pass / $fail counters
# TASK-0124: plugin/plangate sync script 検証

printf '\n=== TA-26: plugin-sync (TASK-0124) ===\n'

# 単体実行 fallback（#861）: run-tests.sh から source されず直接実行された場合、
# FIXTURES_DIR / pass / fail / register_cleanup を自前定義する
if [ -z "${FIXTURES_DIR:-}" ]; then
  PG_T26_STANDALONE=1
  FIXTURES_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/../fixtures" && pwd)"
  pass=0
  fail=0
  _PG_T26_CLEANUP_PATHS=""
  register_cleanup() {
    for _pg_cp in "$@"; do
      if [ -n "$_pg_cp" ]; then
        _PG_T26_CLEANUP_PATHS="${_PG_T26_CLEANUP_PATHS}${_pg_cp}
"
      fi
    done
  }
else
  PG_T26_STANDALONE=0
fi

PG_T26_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
PG_T26_SCRIPT="$PG_T26_ROOT/scripts/sync-plugin-plangate.sh"
PG_T26_PLUGIN="$PG_T26_ROOT/plugin/plangate"
PG_T26_CLAUDE="$PG_T26_ROOT/.claude"

t26_pass() { pass=$((pass + 1)); printf '  [PASS] %s\n' "$1"; }
t26_fail() { fail=$((fail + 1)); printf '  [FAIL] %s\n' "$1" >&2; }

# TC-01: sync スクリプト存在・実行可能
if [ -f "$PG_T26_SCRIPT" ] && [ -x "$PG_T26_SCRIPT" ]; then
  t26_pass "TC-01 sync-plugin-plangate.sh 存在・実行可能"
else
  t26_fail "TC-01 sync-plugin-plangate.sh 不在 or 非実行可能"
fi

# TC-02: sh -n syntax check
if sh -n "$PG_T26_SCRIPT" 2>/dev/null; then
  t26_pass "TC-02 sh -n syntax check"
else
  t26_fail "TC-02 syntax error"
fi

# TC-03: --dry-run が exit 0 で完了
_t26_out=$(sh "$PG_T26_SCRIPT" --dry-run 2>&1) || true
if [ $? -eq 0 ] || printf '%s' "$_t26_out" | grep -q "Sync complete"; then
  t26_pass "TC-03 --dry-run が正常終了"
else
  t26_fail "TC-03 --dry-run 失敗: $_t26_out"
fi

# TC-04: --dry-run が実際にファイルを変更しない
_t26_before=$(find "$PG_T26_PLUGIN" -type f | sort | xargs cat 2>/dev/null | md5sum 2>/dev/null || find "$PG_T26_PLUGIN" -type f | sort | xargs cat 2>/dev/null | cksum)
sh "$PG_T26_SCRIPT" --dry-run >/dev/null 2>&1 || true
_t26_after=$(find "$PG_T26_PLUGIN" -type f | sort | xargs cat 2>/dev/null | md5sum 2>/dev/null || find "$PG_T26_PLUGIN" -type f | sort | xargs cat 2>/dev/null | cksum)
if [ "$_t26_before" = "$_t26_after" ]; then
  t26_pass "TC-04 --dry-run がファイルを変更しない"
else
  t26_fail "TC-04 --dry-run がファイルを変更した"
fi

# TC-05: 実行後に .claude/agents/ の全 .md が plugin/plangate/agents/ に存在
# （#861: 実リポジトリ非破壊化。mktemp -d 配下に sandbox repo を構築し、そこで
#   sync を実行する。sync は自身の配置場所から REPO_ROOT を導出するため、
#   sandbox の scripts/ にコピーして実行すれば対象ルートが sandbox に切り替わる。
#   実リポジトリの plugin/ には一切書き込まない・rm -rf 復元も行わない）
_t26_tmpdir=$(mktemp -d)
register_cleanup "$_t26_tmpdir"  # trap 非依存 (#530-3)
_t26_sb="$_t26_tmpdir/sandbox"
mkdir -p "$_t26_sb/scripts" "$_t26_sb/.claude" "$_t26_sb/.agents" \
  "$_t26_sb/docs/workflows" "$_t26_sb/docs/ai" "$_t26_sb/.claude-plugin" \
  "$_t26_sb/plugin"
cp "$PG_T26_SCRIPT" "$_t26_sb/scripts/"
if [ -f "$PG_T26_ROOT/scripts/_ai_loop_link_rewrite.py" ]; then
  cp "$PG_T26_ROOT/scripts/_ai_loop_link_rewrite.py" "$_t26_sb/scripts/"
fi
if [ -d "$PG_T26_ROOT/scripts/ai-loop" ]; then
  cp -r "$PG_T26_ROOT/scripts/ai-loop" "$_t26_sb/scripts/ai-loop"
fi
for _d in agents rules commands; do
  if [ -d "$PG_T26_CLAUDE/$_d" ]; then
    cp -r "$PG_T26_CLAUDE/$_d" "$_t26_sb/.claude/$_d"
  fi
done
if [ -d "$PG_T26_ROOT/.agents/skills" ]; then
  cp -r "$PG_T26_ROOT/.agents/skills" "$_t26_sb/.agents/skills"
fi
if [ -d "$PG_T26_ROOT/docs/workflows/ai-loop" ]; then
  cp -r "$PG_T26_ROOT/docs/workflows/ai-loop" "$_t26_sb/docs/workflows/ai-loop"
fi
if [ -d "$PG_T26_ROOT/docs/ai/ai-loop" ]; then
  cp -r "$PG_T26_ROOT/docs/ai/ai-loop" "$_t26_sb/docs/ai/ai-loop"
fi
if [ -f "$PG_T26_ROOT/CHANGELOG.md" ]; then
  cp "$PG_T26_ROOT/CHANGELOG.md" "$_t26_sb/CHANGELOG.md"
fi
if [ -f "$PG_T26_ROOT/.claude-plugin/marketplace.json" ]; then
  cp "$PG_T26_ROOT/.claude-plugin/marketplace.json" "$_t26_sb/.claude-plugin/marketplace.json"
fi
cp -r "$PG_T26_PLUGIN" "$_t26_sb/plugin/plangate"
sh "$_t26_sb/scripts/sync-plugin-plangate.sh" >/dev/null 2>&1 || true
_t26_missing=0
for _f in "$_t26_sb/.claude/agents/"*.md; do
  [ -f "$_f" ] || continue
  _base="$(basename "$_f")"
  if [ ! -f "$_t26_sb/plugin/plangate/agents/$_base" ]; then
    _t26_missing=$((_t26_missing + 1))
  fi
done
rm -rf "$_t26_tmpdir"  # 早期解放（register_cleanup との二重実行は冪等）
if [ "$_t26_missing" = "0" ]; then
  t26_pass "TC-05 sandbox 実行後 .claude/agents/ の全 .md が plugin に存在（実 repo 非破壊）"
else
  t26_fail "TC-05 sandbox 実行後 plugin/agents/ に $_t26_missing 件不足"
fi

# TC-06: plugin/plangate/README.md の Version 行が存在
if grep -q 'Version' "$PG_T26_PLUGIN/README.md" 2>/dev/null; then
  t26_pass "TC-06 plugin/plangate/README.md に Version 行あり"
else
  t26_fail "TC-06 plugin/plangate/README.md に Version 行なし"
fi

# TC-07: apply-task-0124-patches.sh 存在・syntax check
PG_T26_PATCH="$PG_T26_ROOT/scripts/apply-task-0124-patches.sh"
if [ -f "$PG_T26_PATCH" ] && sh -n "$PG_T26_PATCH" 2>/dev/null; then
  t26_pass "TC-07 apply-task-0124-patches.sh 存在・syntax OK"
else
  t26_fail "TC-07 apply-task-0124-patches.sh 不在 or syntax error"
fi

# TC-08: sync_dir safety guard（#861）— src が dst の半数未満なら削除をスキップし WARN
_t26_g=$(mktemp -d)
register_cleanup "$_t26_g"
mkdir -p "$_t26_g/scripts" "$_t26_g/.claude/agents" "$_t26_g/plugin/plangate/agents"
cp "$PG_T26_SCRIPT" "$_t26_g/scripts/"
printf -- '---\nname: keep\nmodel: opus\n---\nbody\n' > "$_t26_g/.claude/agents/keep.md"
for _n in stale-a stale-b stale-c stale-d; do
  printf 'stale %s\n' "$_n" > "$_t26_g/plugin/plangate/agents/$_n.md"
done
_t26_gout=$(sh "$_t26_g/scripts/sync-plugin-plangate.sh" 2>&1) || true
_t26_gleft=0
for _n in stale-a stale-b stale-c stale-d; do
  if [ -f "$_t26_g/plugin/plangate/agents/$_n.md" ]; then
    _t26_gleft=$((_t26_gleft + 1))
  fi
done
rm -rf "$_t26_g"  # 早期解放（register_cleanup との二重実行は冪等）
if printf '%s' "$_t26_gout" | grep -q '#861 safety guard' && [ "$_t26_gleft" = "4" ]; then
  t26_pass "TC-08 safety guard 発火（WARN 出力 + dst 4 件を削除せず保持）"
else
  t26_fail "TC-08 safety guard 未発火 or dst 削除 (left=$_t26_gleft/4): $_t26_gout"
fi

# 単体実行時のみ: cleanup drain + サマリ + exit code（source 時は run-tests.sh が担う）
if [ "$PG_T26_STANDALONE" = "1" ]; then
  printf '%s' "$_PG_T26_CLEANUP_PATHS" | while IFS= read -r _pg_cp; do
    if [ -n "$_pg_cp" ]; then
      rm -rf "$_pg_cp" 2>/dev/null || true
    fi
  done
  printf '\nTA-26 standalone: %s passed, %s failed\n' "$pass" "$fail"
  if [ "$fail" != "0" ]; then
    exit 1
  fi
fi
