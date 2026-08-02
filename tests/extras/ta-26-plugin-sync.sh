# tests/extras/ta-26-plugin-sync.sh
# Sourced by tests/run-tests.sh — uses $pass / $fail counters
# TASK-0124: plugin/plangate sync script 検証

printf '\n=== TA-26: plugin-sync (TASK-0124) ===\n'

# 単体実行 fallback（#861 / #877 F3）: run-tests.sh から source されず直接実行
# された場合、FIXTURES_DIR / pass / fail / register_cleanup を自前定義する。
#
# 判別は run-tests.sh が設定する PG_HARNESS_SOURCED=1 と FIXTURES_DIR の AND で
# 行う（片方でも欠ければ standalone 側 = 安全側へ倒す）。FIXTURES_DIR 単独判定
# だと、外部 env に FIXTURES_DIR が漏れているだけで harness 実行と誤判定し、
# standalone 実行時（set -u が無い）に空変数のまま cd して誤ルートを静かに返す。
#
# 方針（#877 / R-204）: 新規 extras は PG_HARNESS_SOURCED を使う。
# FIXTURES_DIR 単独判定を使っている既存 extras の移行と tests/extras/README.md
# の規約追記は follow-up issue で扱う（本 PBI では touch しない）。
if [ "${PG_HARNESS_SOURCED:-0}" != "1" ] || [ -z "${FIXTURES_DIR:-}" ]; then
  PG_T26_STANDALONE=1
  # 呼び出し元 env の漏れで guard 検証が無効化されるのを防ぐ（run-tests.sh L15
  # の規約と対称。standalone 実行にはその防御が効かないため自前で行う）。
  unset PLANGATE_ALLOW_MASS_DELETE 2>/dev/null || true
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

# TC-03 / TC-04 は実リポジトリに対して sync を計 3 回走らせるため、このファイル
# 内で最も重い（実測 合計 約 13 秒）。TC-13 が起動する再帰防止モードの子プロセス
# （PG_T26_NO_RECURSE=1）では省略する — 子の目的は standalone fallback が機能して
# サマリ行を出すことの証明に限られ、TC-03/04 は必ず親プロセス側で実行されるため
# カバレッジは変わらない。
if [ "${PG_T26_NO_RECURSE:-0}" = "1" ]; then
  printf '  [SKIP] TC-03/TC-04（再帰防止の子プロセスでは省略・親で実行済み）\n'
else
  # TC-03: --dry-run が exit 0 で完了（#877 AC-8）
  # rc は `|| rc=$?` で捕捉する（tests/extras/README.md 規約 4）。旧実装は
  # `out=$(cmd) || true` の直後に $? を読んでおり常に 0 = exit code 未検証だった。
  # 判定は「rc = 0 かつ Sync complete を含む」の AND。OR にすると、guard 発火時も
  # 終端で Sync complete を出してから exit 3 する設計のため空振りが再発する。
  _t26_rc=0
  _t26_out=$(sh "$PG_T26_SCRIPT" --dry-run 2>&1) || _t26_rc=$?
  if [ "$_t26_rc" -eq 0 ] && printf '%s' "$_t26_out" | grep -q "Sync complete"; then
    t26_pass "TC-03 --dry-run が exit 0 で正常終了（exit code を実検証）"
  else
    t26_fail "TC-03 --dry-run 失敗 (rc=$_t26_rc): $_t26_out"
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
# exit code も捕捉する（#877）。この sandbox は実 .claude/{agents,rules,commands} +
# 実 plugin/plangate のコピーであり、実リポジトリの stale 関係をそのまま再現する。
# guard の閾値を締めすぎた等で「実 repo で誤発火 → CI 恒常 fail」に倒れた場合、
# ここが最初に赤くなる見張りになる（dry-run 実行の TC-03/TC-04 は exit 3 を
# 構造上返さないため、この経路でしか検出できない）。
_t26_rc5=0
sh "$_t26_sb/scripts/sync-plugin-plangate.sh" >/dev/null 2>&1 || _t26_rc5=$?
_t26_missing=0
for _f in "$_t26_sb/.claude/agents/"*.md; do
  [ -f "$_f" ] || continue
  _base="$(basename "$_f")"
  if [ ! -f "$_t26_sb/plugin/plangate/agents/$_base" ]; then
    _t26_missing=$((_t26_missing + 1))
  fi
done
rm -rf "$_t26_tmpdir"  # 早期解放（register_cleanup との二重実行は冪等）
if [ "$_t26_missing" = "0" ] && [ "$_t26_rc5" -eq 0 ]; then
  t26_pass "TC-05 sandbox 実行後 .claude/agents/ の全 .md が plugin に存在・exit 0（guard 誤発火なし / 実 repo 非破壊）"
else
  t26_fail "TC-05 失敗 (missing=$_t26_missing 期待0 / rc=$_t26_rc5 期待0 — rc=3 なら実 repo 相当で guard が誤発火している)"
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

# ── #877: guard の fail-closed 化に伴う TC 群 ────────────────────────────────
# sandbox は TC-08 と同じ「最小」構成に固定する（CHANGELOG.md /
# .claude-plugin/marketplace.json を置かない）。TC-05 のフル sandbox を真似ると
# version 同期・marketplace 経路（exit 1）が有効化され、guard の exit 3 判定を
# 汚染する。
_t26_mk_guard_sandbox() {
  # $1=sandbox dir / $2=src 件数 / $3=stale 件数 / $4=label（既定 agents）
  _t26_g_dir="$1"; _t26_g_src="$2"; _t26_g_stale="$3"; _t26_g_label="${4:-agents}"
  mkdir -p "$_t26_g_dir/scripts" "$_t26_g_dir/.claude/$_t26_g_label" \
    "$_t26_g_dir/plugin/plangate/$_t26_g_label"
  [ -f "$_t26_g_dir/scripts/sync-plugin-plangate.sh" ] || cp "$PG_T26_SCRIPT" "$_t26_g_dir/scripts/"
  _t26_g_i=1
  while [ "$_t26_g_i" -le "$_t26_g_src" ]; do
    printf -- '---\nname: keep-%s\nmodel: opus\n---\nbody\n' "$_t26_g_i" \
      > "$_t26_g_dir/.claude/$_t26_g_label/keep-$_t26_g_i.md"
    _t26_g_i=$((_t26_g_i + 1))
  done
  _t26_g_i=1
  while [ "$_t26_g_i" -le "$_t26_g_stale" ]; do
    printf 'stale %s\n' "$_t26_g_i" \
      > "$_t26_g_dir/plugin/plangate/$_t26_g_label/stale-$_t26_g_i.md"
    _t26_g_i=$((_t26_g_i + 1))
  done
}

_t26_count_files() { ls "$1" 2>/dev/null | wc -l | tr -d ' '; }

# TC-09: DELETE 正常系（#877 AC-5）— src=2 / stale=1 は guard 発火条件を満たさない
_t26_t9=$(mktemp -d); register_cleanup "$_t26_t9"
_t26_mk_guard_sandbox "$_t26_t9" 2 1
_t26_rc9=0
_t26_out9=$(sh "$_t26_t9/scripts/sync-plugin-plangate.sh" 2>&1) || _t26_rc9=$?
_t26_left9=$(_t26_count_files "$_t26_t9/plugin/plangate/agents")
rm -rf "$_t26_t9"
if [ "$_t26_rc9" -eq 0 ] && [ "$_t26_left9" = "2" ] && ! printf '%s' "$_t26_out9" | grep -q 'safety guard'; then
  t26_pass "TC-09 DELETE 正常系（src=2/stale=1 → stale 削除・guard 非発火・exit 0）"
else
  t26_fail "TC-09 DELETE 正常系 失敗 (rc=$_t26_rc9 / left=$_t26_left9/2): $_t26_out9"
fi

# TC-10: guard 発火時 exit 3 + メッセージ要件（#877 AC-1 / AC-9）
_t26_t10=$(mktemp -d); register_cleanup "$_t26_t10"
_t26_mk_guard_sandbox "$_t26_t10" 1 4
_t26_rc10=0
_t26_err10=$(sh "$_t26_t10/scripts/sync-plugin-plangate.sh" 2>&1 >/dev/null) || _t26_rc10=$?
_t26_left10=$(_t26_count_files "$_t26_t10/plugin/plangate/agents")
rm -rf "$_t26_t10"
if [ "$_t26_rc10" -eq 3 ] && [ "$_t26_left10" = "5" ] \
  && printf '%s' "$_t26_err10" | grep -q 'agents' \
  && printf '%s' "$_t26_err10" | grep -q 'PLANGATE_ALLOW_MASS_DELETE'; then
  t26_pass "TC-10 guard 発火で exit 3・stderr に label と override 手順を出力"
else
  t26_fail "TC-10 失敗 (rc=$_t26_rc10 期待3 / dst=$_t26_left10 期待5 / stderr): $_t26_err10"
fi

# TC-11: PLANGATE_ALLOW_MASS_DELETE=1 による override（#877 AC-2）
_t26_t11=$(mktemp -d); register_cleanup "$_t26_t11"
_t26_mk_guard_sandbox "$_t26_t11" 1 4
_t26_rc11=0
_t26_out11=$(PLANGATE_ALLOW_MASS_DELETE=1 sh "$_t26_t11/scripts/sync-plugin-plangate.sh" 2>&1) || _t26_rc11=$?
_t26_left11=$(_t26_count_files "$_t26_t11/plugin/plangate/agents")
rm -rf "$_t26_t11"
if [ "$_t26_rc11" -eq 0 ] && [ "$_t26_left11" = "1" ] \
  && printf '%s' "$_t26_out11" | grep -q 'PLANGATE_ALLOW_MASS_DELETE=1 で解除'; then
  t26_pass "TC-11 override で削除実行・exit 0・解除ログ出力"
else
  t26_fail "TC-11 失敗 (rc=$_t26_rc11 期待0 / dst=$_t26_left11 期待1): $_t26_out11"
fi

# TC-12: dry-run と実行で guard 判定が一致（#877 AC-3）
# 乖離帯 src=3 / stale=4 を使う。旧判定式（src*2 < dst）では dry-run 非発火 /
# 実行発火と食い違った（dst をコピー後に数えるため）。src=1/stale=4 は旧式でも
# 両モード発火するため回帰検出力が無く、fixture として使ってはならない。
_t26_t12a=$(mktemp -d); register_cleanup "$_t26_t12a"
_t26_t12b=$(mktemp -d); register_cleanup "$_t26_t12b"
_t26_mk_guard_sandbox "$_t26_t12a" 3 4
_t26_mk_guard_sandbox "$_t26_t12b" 3 4
_t26_rc12a=0
_t26_out12a=$(sh "$_t26_t12a/scripts/sync-plugin-plangate.sh" --dry-run 2>&1) || _t26_rc12a=$?
_t26_left12a=$(_t26_count_files "$_t26_t12a/plugin/plangate/agents")
_t26_rc12b=0
_t26_out12b=$(sh "$_t26_t12b/scripts/sync-plugin-plangate.sh" 2>&1) || _t26_rc12b=$?
_t26_left12b=$(_t26_count_files "$_t26_t12b/plugin/plangate/agents")
rm -rf "$_t26_t12a" "$_t26_t12b"
_t26_fired12a=no; printf '%s' "$_t26_out12a" | grep -q 'safety guard' && _t26_fired12a=yes
_t26_fired12b=no; printf '%s' "$_t26_out12b" | grep -q 'safety guard' && _t26_fired12b=yes
if [ "$_t26_fired12a" = "yes" ] && [ "$_t26_fired12b" = "yes" ] \
  && [ "$_t26_rc12a" -eq 0 ] && [ "$_t26_left12a" = "4" ] \
  && ! printf '%s' "$_t26_out12a" | grep -q 'WOULD DELETE' \
  && [ "$_t26_rc12b" -eq 3 ] && [ "$_t26_left12b" = "7" ]; then
  t26_pass "TC-12 乖離帯 src=3/stale=4 で dry-run と実行の guard 判定が一致"
else
  t26_fail "TC-12 失敗 (dry: fired=$_t26_fired12a rc=$_t26_rc12a dst=$_t26_left12a 期待 yes/0/4 / run: fired=$_t26_fired12b rc=$_t26_rc12b dst=$_t26_left12b 期待 yes/3/7)"
fi

# TC-13: PG_HARNESS_SOURCED による harness/standalone 判別（#877 AC-4）
# 自己再帰の防止: 子プロセスには PG_T26_NO_RECURSE=1 を渡し、その環境では
# TC-13 自体をスキップする（無ガードで自分や run-tests.sh を再実行すると
# スイート全体が再入ループになる）。harness 側の確認は子プロセスを起動せず
# 静的自己証明で行う。
if [ "${PG_T26_NO_RECURSE:-0}" = "1" ]; then
  printf '  [SKIP] TC-13 再帰防止（PG_T26_NO_RECURSE=1）\n'
else
  # ①: 素の standalone 実行
  _t26_rc13a=0
  _t26_out13a=$(PG_T26_NO_RECURSE=1 sh "$PG_T26_ROOT/tests/extras/ta-26-plugin-sync.sh" 2>&1) || _t26_rc13a=$?
  # ②: FIXTURES_DIR だけが外部 env から漏れている standalone 実行
  _t26_rc13b=0
  _t26_out13b=$(FIXTURES_DIR=/tmp/pg-t26-dummy PG_T26_NO_RECURSE=1 \
    sh "$PG_T26_ROOT/tests/extras/ta-26-plugin-sync.sh" 2>&1) || _t26_rc13b=$?
  # ③: harness 側は静的自己証明（このブロックが source 経由で走っている事実 +
  #     run-tests.sh に代入が存在すること）
  _t26_13c=0
  if [ "$PG_T26_STANDALONE" = "0" ]; then
    [ "${PG_HARNESS_SOURCED:-0}" = "1" ] && _t26_13c=1
  else
    _t26_13c=1  # standalone 実行時は ①② の結果のみで判定する
  fi
  # 判定は子プロセスの総合 exit code ではなく standalone サマリ行を見る。
  # rc に依存させると他 TC の失敗が TC-13 へ道連れで伝播し、原因が読めなくなる。
  if printf '%s' "$_t26_out13a" | grep -q 'TA-26 standalone: .* 0 failed' \
    && printf '%s' "$_t26_out13b" | grep -q 'TA-26 standalone: .* 0 failed' \
    && [ "$_t26_13c" = "1" ] \
    && grep -q 'PG_HARNESS_SOURCED=1' "$PG_T26_ROOT/tests/run-tests.sh"; then
    t26_pass "TC-13 PG_HARNESS_SOURCED で harness/standalone を判別（FIXTURES_DIR 汚染にも耐える）"
  else
    t26_fail "TC-13 失敗 (① rc=$_t26_rc13a / ② rc=$_t26_rc13b / ③ $_t26_13c)"
  fi
fi

# TC-16: 複数 label 同時発火（#877 AC-1 後段 / A-1 案の中核）
_t26_t16=$(mktemp -d); register_cleanup "$_t26_t16"
for _t26_lb in agents rules commands; do
  _t26_mk_guard_sandbox "$_t26_t16" 1 4 "$_t26_lb"
done
_t26_rc16=0
# stderr は sandbox 内のファイルへ退避する（固定 /tmp パスは並列実行時に衝突し、
# cleanup 漏れも起こす）。sandbox 直下のファイルは sync の走査対象外。
_t26_err16f="$_t26_t16/stderr.log"
sh "$_t26_t16/scripts/sync-plugin-plangate.sh" >/dev/null 2>"$_t26_err16f" || _t26_rc16=$?
_t26_err16=$(cat "$_t26_err16f" 2>/dev/null || true)
_t26_warn16=$(printf '%s\n' "$_t26_err16" | grep -c 'DELETE skipped for' || true)
_t26_copied16=1
for _t26_lb in agents rules commands; do
  [ -f "$_t26_t16/plugin/plangate/$_t26_lb/keep-1.md" ] || _t26_copied16=0
done
rm -rf "$_t26_t16"
if [ "$_t26_rc16" -eq 3 ] && [ "$_t26_warn16" = "3" ] && [ "$_t26_copied16" = "1" ]; then
  t26_pass "TC-16 複数 label 同時発火（WARN 3 行・exit 3 は 1 回・コピーは全 label 実行）"
else
  t26_fail "TC-16 失敗 (rc=$_t26_rc16 期待3 / WARN=$_t26_warn16 期待3 / copied=$_t26_copied16)"
fi

# TC-17: README.md を src/dst 対称に除外していること（#877 F2 / R-108）
# src 実体 1 件（keep-1.md）+ README.md、stale 2 件。
# - 対称除外（正）: src=1 / stale=2 → 2 > 1 で発火（rc=3・stale 残存）
# - 旧非対称（src 側が README を数える）: src=2 → 2 > 2 が偽 → stale を削除して rc=0
# この TC が無いと「README 除外を src 側だけ戻す」変異がテストを素通りする。
_t26_t17=$(mktemp -d); register_cleanup "$_t26_t17"
_t26_mk_guard_sandbox "$_t26_t17" 1 2
printf -- '# README\n' > "$_t26_t17/.claude/agents/README.md"
printf -- '# README\n' > "$_t26_t17/plugin/plangate/agents/README.md"
_t26_rc17=0
sh "$_t26_t17/scripts/sync-plugin-plangate.sh" >/dev/null 2>&1 || _t26_rc17=$?
_t26_stale17=0
for _t26_n in 1 2; do
  [ -f "$_t26_t17/plugin/plangate/agents/stale-$_t26_n.md" ] && _t26_stale17=$((_t26_stale17 + 1))
done
rm -rf "$_t26_t17"
if [ "$_t26_rc17" -eq 3 ] && [ "$_t26_stale17" = "2" ]; then
  t26_pass "TC-17 README.md を src/dst 対称に除外（src 実体1/stale2 で発火）"
else
  t26_fail "TC-17 失敗 (rc=$_t26_rc17 期待3 / stale 残存=$_t26_stale17 期待2 — src 側の README 除外が抜けている可能性)"
fi

# TC-15: override フラグが CI workflow に埋め込まれていない（#877 AC-2 後段 / AC-7）
# .github/workflows/** は Hardening Override 対象で AI が編集できないため、
# 「CI 側で恒久的に guard が無効化されていないこと」は tests 側から見張る。
if [ -d "$PG_T26_ROOT/.github" ]; then
  _t26_ci_hits=$(grep -rl 'PLANGATE_ALLOW_MASS_DELETE' "$PG_T26_ROOT/.github/" 2>/dev/null | wc -l | tr -d ' ')
else
  _t26_ci_hits=0
fi
if [ "$_t26_ci_hits" = "0" ]; then
  t26_pass "TC-15 PLANGATE_ALLOW_MASS_DELETE が .github/ に存在しない（CI での恒久無効化なし）"
else
  t26_fail "TC-15 .github/ に PLANGATE_ALLOW_MASS_DELETE が $_t26_ci_hits 件（CI で guard が無効化される）"
fi

# ── #914: 経路1/経路2（references 削除経路）guard の TC 群 ──────────────────
# sandbox は #877 TC 群（TC-08〜TC-17）と同じ「最小」構成に固定する
# （CHANGELOG.md / .claude-plugin/marketplace.json を置かない — フル構成だと
# version 同期・marketplace 経路（exit 1）が有効化され guard の exit 3 判定を
# 汚染する）。rc 捕捉は _rc=0; _out=$(sh ...) || _rc=$? の型に統一（README 規約 4）。

_T26_AI_LOOP_REFS_REL="plugin/plangate/skills/ai-loop-cycle/references"

# 経路2（ai-loop references）用 sandbox。_t26_mk_guard_sandbox（上）と同型。
# _sync_ai_loop_ref_content は python3 "$AI_LOOP_LINK_REWRITER" を可用性ガード
# なしで呼ぶため、scripts/_ai_loop_link_rewrite.py を必ず同梱する（R-354 —
# 不在だと guard ロジックと無関係な理由で set -eu が異常終了する）。
_t26_mk_ai_loop_guard_sandbox() {
  # $1=sandbox dir / $2=正本（docs/workflows/ai-loop）*.md 件数 / $3=stale 件数
  # / $4=正本 2 ディレクトリの状態（present=作成（既定） / absent=作らない。
  #   $2=0 + present が「存在するが空」= TC-21、$2=0 + absent が「両方消失」=
  #   TC-20。$2>0 は present のみ有効）
  _t26_al_dir="$1"; _t26_al_src="$2"; _t26_al_stale="$3"; _t26_al_mode="${4:-present}"
  mkdir -p "$_t26_al_dir/scripts" "$_t26_al_dir/$_T26_AI_LOOP_REFS_REL"
  [ -f "$_t26_al_dir/scripts/sync-plugin-plangate.sh" ] || cp "$PG_T26_SCRIPT" "$_t26_al_dir/scripts/"
  [ -f "$_t26_al_dir/scripts/_ai_loop_link_rewrite.py" ] \
    || cp "$PG_T26_ROOT/scripts/_ai_loop_link_rewrite.py" "$_t26_al_dir/scripts/"
  if [ "$_t26_al_mode" = "present" ]; then
    mkdir -p "$_t26_al_dir/docs/workflows/ai-loop" "$_t26_al_dir/docs/ai/ai-loop"
  fi
  _t26_al_i=1
  while [ "$_t26_al_i" -le "$_t26_al_src" ]; do
    printf 'wf %s\n' "$_t26_al_i" > "$_t26_al_dir/docs/workflows/ai-loop/wf-$_t26_al_i.md"
    # 期待集合に載る正本ファイルは dst にも同名で置く（同期済み状態の再現）
    printf 'wf %s\n' "$_t26_al_i" > "$_t26_al_dir/$_T26_AI_LOOP_REFS_REL/wf-$_t26_al_i.md"
    _t26_al_i=$((_t26_al_i + 1))
  done
  _t26_al_i=1
  while [ "$_t26_al_i" -le "$_t26_al_stale" ]; do
    printf 'stale %s\n' "$_t26_al_i" > "$_t26_al_dir/$_T26_AI_LOOP_REFS_REL/stale-$_t26_al_i.md"
    _t26_al_i=$((_t26_al_i + 1))
  done
}

# TC-20: 経路2 — 正本 2 ディレクトリ両方が消失 → guard 発火・削除保留
# （#914 AC-1 負側 / #877 実害と同型: 期待集合が空になっても dst を消さない）
_t26_t20=$(mktemp -d); register_cleanup "$_t26_t20"
_t26_mk_ai_loop_guard_sandbox "$_t26_t20" 0 5 absent
_t26_rc20=0
_t26_out20=$(sh "$_t26_t20/scripts/sync-plugin-plangate.sh" 2>&1) || _t26_rc20=$?
_t26_left20=$(_t26_count_files "$_t26_t20/$_T26_AI_LOOP_REFS_REL")
rm -rf "$_t26_t20"
if printf '%s' "$_t26_out20" | grep -q 'DELETE skipped for skills/ai-loop-cycle/references' \
  && printf '%s' "$_t26_out20" | grep -q 'PLANGATE_ALLOW_MASS_DELETE=1' \
  && [ "$_t26_left20" = "5" ]; then
  t26_pass "TC-20 経路2: 正本 2 dir 消失で guard 発火（DELETE skipped + override 案内・dst 5 件残存）"
else
  t26_fail "TC-20 失敗 (rc=$_t26_rc20 / left=$_t26_left20 期待5): $_t26_out20"
fi

# TC-21: 経路2 — 正本 2 ディレクトリが空化（存在するが *.md 0 件）→ guard 発火
# （ディレクトリ存在の有無で挙動が分岐しない = [ -d ] ガードすり抜けの封鎖）
_t26_t21=$(mktemp -d); register_cleanup "$_t26_t21"
_t26_mk_ai_loop_guard_sandbox "$_t26_t21" 0 5
_t26_rc21=0
_t26_out21=$(sh "$_t26_t21/scripts/sync-plugin-plangate.sh" 2>&1) || _t26_rc21=$?
_t26_left21=$(_t26_count_files "$_t26_t21/$_T26_AI_LOOP_REFS_REL")
rm -rf "$_t26_t21"
if printf '%s' "$_t26_out21" | grep -q 'DELETE skipped for skills/ai-loop-cycle/references' \
  && printf '%s' "$_t26_out21" | grep -q 'PLANGATE_ALLOW_MASS_DELETE=1' \
  && [ "$_t26_left21" = "5" ]; then
  t26_pass "TC-21 経路2: 正本 2 dir 空化でも guard 発火（TC-20 と同一挙動）"
else
  t26_fail "TC-21 失敗 (rc=$_t26_rc21 / left=$_t26_left21 期待5): $_t26_out21"
fi

# TC-22: 経路2 — guard 発火時に終端 exit 3
# （guard_fired の global 伝播をサブシェル問題ごと実証。#914 AC-1）
_t26_t22=$(mktemp -d); register_cleanup "$_t26_t22"
_t26_mk_ai_loop_guard_sandbox "$_t26_t22" 0 5 absent
_t26_rc22=0
_t26_out22=$(sh "$_t26_t22/scripts/sync-plugin-plangate.sh" 2>&1) || _t26_rc22=$?
_t26_left22=$(_t26_count_files "$_t26_t22/$_T26_AI_LOOP_REFS_REL")
rm -rf "$_t26_t22"
if [ "$_t26_rc22" -eq 3 ] && [ "$_t26_left22" = "5" ] \
  && printf '%s' "$_t26_out22" | grep -q 'mass-delete safety guard が発火'; then
  t26_pass "TC-22 経路2: guard 発火で終端 exit 3（guard_fired の global 伝播）"
else
  t26_fail "TC-22 失敗 (rc=$_t26_rc22 期待3 / left=$_t26_left22 期待5): $_t26_out22"
fi

# TC-23: 経路2 — PLANGATE_ALLOW_MASS_DELETE=1 で override（#914 AC-4）
_t26_t23=$(mktemp -d); register_cleanup "$_t26_t23"
_t26_mk_ai_loop_guard_sandbox "$_t26_t23" 0 5 absent
_t26_rc23=0
_t26_out23=$(PLANGATE_ALLOW_MASS_DELETE=1 sh "$_t26_t23/scripts/sync-plugin-plangate.sh" 2>&1) || _t26_rc23=$?
_t26_left23=$(_t26_count_files "$_t26_t23/$_T26_AI_LOOP_REFS_REL")
rm -rf "$_t26_t23"
if [ "$_t26_rc23" -eq 0 ] && [ "$_t26_left23" = "0" ] \
  && printf '%s' "$_t26_out23" | grep -q '解除しました'; then
  t26_pass "TC-23 経路2: override で削除実行・exit 0・解除ログ出力（dst 5 件全削除）"
else
  t26_fail "TC-23 失敗 (rc=$_t26_rc23 期待0 / left=$_t26_left23 期待0): $_t26_out23"
fi

# TC-24: 経路2 正常系 — 1 件だけ正当に削除（guard 非発火）
# （形骸化防止: 正当な削減を block しないことの証明。検出力は M-6 で実証）
_t26_t24=$(mktemp -d); register_cleanup "$_t26_t24"
_t26_mk_ai_loop_guard_sandbox "$_t26_t24" 4 1
_t26_rc24=0
_t26_out24=$(sh "$_t26_t24/scripts/sync-plugin-plangate.sh" 2>&1) || _t26_rc24=$?
_t26_left24=$(_t26_count_files "$_t26_t24/$_T26_AI_LOOP_REFS_REL")
_t26_stale24=1
[ -f "$_t26_t24/$_T26_AI_LOOP_REFS_REL/stale-1.md" ] || _t26_stale24=0
rm -rf "$_t26_t24"
if [ "$_t26_rc24" -eq 0 ] && [ "$_t26_left24" = "4" ] && [ "$_t26_stale24" = "0" ] \
  && ! printf '%s' "$_t26_out24" | grep -q 'DELETE skipped'; then
  t26_pass "TC-24 経路2 正常系: base=4/stale=1 で非発火・stale 1 件のみ削除・exit 0"
else
  t26_fail "TC-24 失敗 (rc=$_t26_rc24 期待0 / left=$_t26_left24 期待4 / stale残=$_t26_stale24 期待0): $_t26_out24"
fi

# TC-25: 経路2 — dry-run と実行の判定一致（乖離帯 base=3/stale=4）
# （#877 論点 B が正面から潰した性質の経路2 版。dry-run は exit 0 維持・実行は exit 3）
_t26_t25a=$(mktemp -d); register_cleanup "$_t26_t25a"
_t26_t25b=$(mktemp -d); register_cleanup "$_t26_t25b"
_t26_mk_ai_loop_guard_sandbox "$_t26_t25a" 3 4
_t26_mk_ai_loop_guard_sandbox "$_t26_t25b" 3 4
_t26_rc25a=0
_t26_out25a=$(sh "$_t26_t25a/scripts/sync-plugin-plangate.sh" --dry-run 2>&1) || _t26_rc25a=$?
_t26_left25a=$(_t26_count_files "$_t26_t25a/$_T26_AI_LOOP_REFS_REL")
_t26_rc25b=0
_t26_out25b=$(sh "$_t26_t25b/scripts/sync-plugin-plangate.sh" 2>&1) || _t26_rc25b=$?
_t26_left25b=$(_t26_count_files "$_t26_t25b/$_T26_AI_LOOP_REFS_REL")
rm -rf "$_t26_t25a" "$_t26_t25b"
_t26_fired25a=no; printf '%s' "$_t26_out25a" | grep -q 'safety guard' && _t26_fired25a=yes
_t26_fired25b=no; printf '%s' "$_t26_out25b" | grep -q 'safety guard' && _t26_fired25b=yes
if [ "$_t26_fired25a" = "yes" ] && [ "$_t26_fired25b" = "yes" ] \
  && [ "$_t26_rc25a" -eq 0 ] && [ "$_t26_left25a" = "7" ] \
  && ! printf '%s' "$_t26_out25a" | grep -q 'WOULD DELETE' \
  && [ "$_t26_rc25b" -eq 3 ] && [ "$_t26_left25b" = "7" ]; then
  t26_pass "TC-25 経路2: 乖離帯 base=3/stale=4 で dry-run と実行の guard 判定が一致"
else
  t26_fail "TC-25 失敗 (dry: fired=$_t26_fired25a rc=$_t26_rc25a left=$_t26_left25a 期待 yes/0/7 / run: fired=$_t26_fired25b rc=$_t26_rc25b left=$_t26_left25b 期待 yes/3/7)"
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
