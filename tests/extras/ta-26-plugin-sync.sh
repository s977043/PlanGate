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
# FIXTURES_DIR 単独判定を使っていた既存 extras の移行と tests/extras/README.md
# の規約追記は follow-up の #914 で完了（README 規約 8 / 残存 0 は TC-33 が静的検査）。
if [ "${PG_HARNESS_SOURCED:-0}" != "1" ] || [ -z "${FIXTURES_DIR:-}" ]; then
  PG_T26_STANDALONE=1
  # 呼び出し元 env の漏れで guard 検証・hook 挙動が歪むのを防ぐ（run-tests.sh
  # 冒頭の unset 集合と同一の 7 env — TASK-0914 論点 F / README 規約 8。
  # standalone 実行には harness 側の防御が効かないため自前で行う）。
  unset PLANGATE_SKIP_REASON PLANGATE_HOOK_TASK PLANGATE_HOOK_FILE PLANGATE_BYPASS_HOOK PLANGATE_HOOK_STRICT PG_HARNESS_SOURCED PLANGATE_ALLOW_MASS_DELETE 2>/dev/null || true
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
  # harness 分岐でのみ呼び出し元 env の漏れを無害化する（#1036）。
  # 実害: PG_T26_NO_RECURSE が外部から export されていると、harness 経路
  # （sh tests/run-tests.sh）で本ファイルの TC 群（mass-delete guard 回帰
  # #877 / #914 / #970 を含む）が黙って [SKIP] され、回帰検出力が失われる。
  # run-tests.sh
  # 冒頭の unset 集合に PG_T26_NO_RECURSE を足すと TC-33 の包含検査が全 extras に
  # 波及するため、ta-26 自身のこの経路で消す。preamble / standalone 分岐で unset
  # してはならない — TC-13 の子（PG_T26_NO_RECURSE=1 前置）でも走り再帰防止ガード
  # 自体が壊れる（孫 spawn の再入ループ）。この経路が親（harness で source された
  # ta-26）だけを通る前提は「PG_HARNESS_SOURCED は非 export」（run-tests.sh /
  # README 規約 8）に依存する。この前提は ta-62 TC-S(4) が run-tests.sh の実装を
  # 直接 grep して静的固定する（ta-26 TC-30 は README 文言の存在検査のみで実装は
  # 見ていないため、TC-30 では前提を守れない）。unset の配置自体は ta-62 TC-S(1)〜(3)
  # が静的検査する。
  unset PG_T26_NO_RECURSE 2>/dev/null || true
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
# >>> PG_T26_SANDBOX_BUILDER_BEGIN
# TC-40 はこのマーカーで囲まれた **実行される行**だけから `cp -r` のディレクトリ
# 供給経路を抽出する（#1249 MINOR-1）。ファイル全体を走査していた旧実装は、
# 末尾のコメント行に `cp -r "$PG_T26_ROOT/docs" ...` と書くだけで「docs/ 配下は
# すべて供給済み」と誤認し、陽性コントロール（sandbox 一覧から 1 件落とす変異）
# が無効化された。マーカーの移動・削除は TC-40 の PARSE-FAIL になる。
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
# ai-dev-{plan,exec,verify,brainstorm} の同梱ソース（#1232）。
# sandbox は「実リポジトリの stale 関係をそのまま再現する」ことが前提であり、
# sync の入力を 1 つでも欠くと期待集合が空になり mass-delete guard が正当に
# 発火して exit 3 になる（= sandbox 側の欠損であって実装の誤りではない）。
# sync 側の同梱対象（_ai_dev_ref_spec）を増やしたら、ここにも足すこと。
mkdir -p "$_t26_sb/docs/working/templates"
for _f26 in \
  docs/ai-driven-development.md \
  docs/plangate.md \
  docs/ai/core-contract.md \
  docs/ai/plan-metrics-verification.md \
  docs/ai/settings-wiring-contract.md \
  docs/working/templates/plan.md \
  docs/working/templates/todo.md \
  docs/working/templates/test-cases.md \
  docs/working/templates/INDEX.md \
  docs/working/templates/current-state.md \
  docs/working/templates/review-self.md \
  docs/working/templates/review-external.md \
  docs/working/templates/pbi-input.md \
  docs/working/templates/handoff.md
do
  if [ -f "$PG_T26_ROOT/$_f26" ]; then
    mkdir -p "$_t26_sb/$(dirname "$_f26")"
    cp "$PG_T26_ROOT/$_f26" "$_t26_sb/$_f26"
  fi
done
# <<< PG_T26_SANDBOX_BUILDER_END
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

# TC-20〜TC-25（経路2 guard）は sandbox repo を都度構築して sync を実走させるため
# 重い。TC-13 が起動する再帰防止モードの子プロセス（PG_T26_NO_RECURSE=1）では省略
# する — 子の目的は standalone fallback が機能してサマリ行を出すことの証明に限られ、
# これらの TC は必ず親プロセス側で実行されるためカバレッジは変わらない。ヘルパー定義
# （_T26_AI_LOOP_REFS_REL / _t26_mk_ai_loop_guard_sandbox）と静的検査 TC-30 / TC-33
# はゲート外に残す（ゲートを 2 組に分割している理由）。
if [ "${PG_T26_NO_RECURSE:-0}" = "1" ]; then
  printf '  [SKIP] TC-20〜TC-25（再帰防止の子プロセスでは省略・親で実行済み）\n'
else
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
fi

# 経路1（汎用 references）用 sandbox。_t26_mk_guard_sandbox と同型。
# 複数 skill 構成は skill 名（$4）を変えて同一 sandbox dir へ複数回呼んで構築する
# （TC-26 が skill-A / skill-B を要求。skill ループは glob 順 = 辞書順で
#  skill-A → skill-B の順に処理される）。
_t26_mk_refs_guard_sandbox() {
  # $1=sandbox dir / $2=src references *.md 件数 / $3=stale 件数
  # / $4=skill 名（既定 skill-A） / $5=dst 事前状態（mirror=src 同名を旧内容で
  #   dst にも置く（既定。dst 件数 = $2+$3） / empty=stale のみ置く）
  _t26_rf_dir="$1"; _t26_rf_src="$2"; _t26_rf_stale="$3"
  _t26_rf_skill="${4:-skill-A}"; _t26_rf_dst="${5:-mirror}"
  mkdir -p "$_t26_rf_dir/scripts" \
    "$_t26_rf_dir/.agents/skills/$_t26_rf_skill/references" \
    "$_t26_rf_dir/plugin/plangate/skills/$_t26_rf_skill/references"
  [ -f "$_t26_rf_dir/scripts/sync-plugin-plangate.sh" ] || cp "$PG_T26_SCRIPT" "$_t26_rf_dir/scripts/"
  printf -- '---\nname: %s\n---\nbody\n' "$_t26_rf_skill" \
    > "$_t26_rf_dir/.agents/skills/$_t26_rf_skill/SKILL.md"
  _t26_rf_i=1
  while [ "$_t26_rf_i" -le "$_t26_rf_src" ]; do
    printf 'ref %s\n' "$_t26_rf_i" \
      > "$_t26_rf_dir/.agents/skills/$_t26_rf_skill/references/ref-$_t26_rf_i.md"
    if [ "$_t26_rf_dst" = "mirror" ]; then
      # 旧内容で置く（同期対象として COPY による更新が起きる状態を再現）
      printf 'old %s\n' "$_t26_rf_i" \
        > "$_t26_rf_dir/plugin/plangate/skills/$_t26_rf_skill/references/ref-$_t26_rf_i.md"
    fi
    _t26_rf_i=$((_t26_rf_i + 1))
  done
  _t26_rf_i=1
  while [ "$_t26_rf_i" -le "$_t26_rf_stale" ]; do
    printf 'stale %s\n' "$_t26_rf_i" \
      > "$_t26_rf_dir/plugin/plangate/skills/$_t26_rf_skill/references/stale-$_t26_rf_i.md"
    _t26_rf_i=$((_t26_rf_i + 1))
  done
}

# TC-26〜TC-29 / TC-32 / TC-34〜TC-36（経路1 guard・#970 symlink 集計）も同様に
# sandbox 実行を伴い重い。再帰防止モードの子プロセスでは省略する（親で実行済み）。
# _t26_mk_refs_guard_sandbox の定義はゲート外（上）に残してあるため、ゲート外から
# 参照されるシンボルは無い。
if [ "${PG_T26_NO_RECURSE:-0}" = "1" ]; then
  printf '  [SKIP] TC-26〜29/32/34〜36（再帰防止の子プロセスでは省略・親で実行済み）\n'
else
  # TC-26: 経路1 — _src_refs 空化 → 当該 skill のみ guard 発火（#914 AC-2 負側 + 制御フロー）
  # skill-B の dst は empty で始め、sync による COPY 実行を「skill-A の guard 後も
  # 処理が継続した」証拠にする（break 誤用の封鎖。検出力は M-5 で実証）。
  _t26_t26=$(mktemp -d); register_cleanup "$_t26_t26"
  _t26_mk_refs_guard_sandbox "$_t26_t26" 0 4 skill-A
  _t26_mk_refs_guard_sandbox "$_t26_t26" 3 0 skill-B empty
  _t26_rc26=0
  _t26_out26=$(sh "$_t26_t26/scripts/sync-plugin-plangate.sh" 2>&1) || _t26_rc26=$?
  _t26_lefta26=$(_t26_count_files "$_t26_t26/plugin/plangate/skills/skill-A/references")
  _t26_leftb26=$(_t26_count_files "$_t26_t26/plugin/plangate/skills/skill-B/references")
  rm -rf "$_t26_t26"
  if printf '%s' "$_t26_out26" | grep -q 'DELETE skipped for skills/skill-A/references' \
    && [ "$_t26_lefta26" = "4" ] && [ "$_t26_leftb26" = "3" ] \
    && printf '%s' "$_t26_out26" | grep -q 'COPY: skills/skill-B/references/ref-1.md'; then
    t26_pass "TC-26 経路1: skill-A のみ guard 発火・dst 4 件残存、skill-B は正常同期（3 件 COPY）"
  else
    t26_fail "TC-26 失敗 (rc=$_t26_rc26 / A left=$_t26_lefta26 期待4 / B left=$_t26_leftb26 期待3): $_t26_out26"
  fi

  # TC-27: 経路1 — guard 発火時に終端 exit 3（#914 AC-2）
  _t26_t27=$(mktemp -d); register_cleanup "$_t26_t27"
  _t26_mk_refs_guard_sandbox "$_t26_t27" 0 4 skill-A
  _t26_mk_refs_guard_sandbox "$_t26_t27" 3 0 skill-B empty
  _t26_rc27=0
  _t26_out27=$(sh "$_t26_t27/scripts/sync-plugin-plangate.sh" 2>&1) || _t26_rc27=$?
  _t26_lefta27=$(_t26_count_files "$_t26_t27/plugin/plangate/skills/skill-A/references")
  rm -rf "$_t26_t27"
  if [ "$_t26_rc27" -eq 3 ] && [ "$_t26_lefta27" = "4" ] \
    && printf '%s' "$_t26_out27" | grep -q 'mass-delete safety guard が発火'; then
    t26_pass "TC-27 経路1: guard 発火で終端 exit 3"
  else
    t26_fail "TC-27 失敗 (rc=$_t26_rc27 期待3 / A left=$_t26_lefta27 期待4): $_t26_out27"
  fi

  # TC-28: 経路1 — PLANGATE_ALLOW_MASS_DELETE=1 で override（#914 AC-4）
  _t26_t28=$(mktemp -d); register_cleanup "$_t26_t28"
  _t26_mk_refs_guard_sandbox "$_t26_t28" 0 4 skill-A
  _t26_mk_refs_guard_sandbox "$_t26_t28" 3 0 skill-B empty
  _t26_rc28=0
  _t26_out28=$(PLANGATE_ALLOW_MASS_DELETE=1 sh "$_t26_t28/scripts/sync-plugin-plangate.sh" 2>&1) || _t26_rc28=$?
  _t26_lefta28=$(_t26_count_files "$_t26_t28/plugin/plangate/skills/skill-A/references")
  rm -rf "$_t26_t28"
  if [ "$_t26_rc28" -eq 0 ] && [ "$_t26_lefta28" = "0" ] \
    && printf '%s' "$_t26_out28" | grep -q '解除しました'; then
    t26_pass "TC-28 経路1: override で削除実行・exit 0・解除ログ出力（skill-A dst 4 件全削除）"
  else
    t26_fail "TC-28 失敗 (rc=$_t26_rc28 期待0 / A left=$_t26_lefta28 期待0): $_t26_out28"
  fi

  # TC-29: 経路1 正常系 — src 3 件・stale 1 件（guard 非発火。検出力は M-6 で実証）
  _t26_t29=$(mktemp -d); register_cleanup "$_t26_t29"
  _t26_mk_refs_guard_sandbox "$_t26_t29" 3 1 skill-A
  _t26_rc29=0
  _t26_out29=$(sh "$_t26_t29/scripts/sync-plugin-plangate.sh" 2>&1) || _t26_rc29=$?
  _t26_left29=$(_t26_count_files "$_t26_t29/plugin/plangate/skills/skill-A/references")
  _t26_stale29=1
  [ -f "$_t26_t29/plugin/plangate/skills/skill-A/references/stale-1.md" ] || _t26_stale29=0
  rm -rf "$_t26_t29"
  if [ "$_t26_rc29" -eq 0 ] && [ "$_t26_left29" = "3" ] && [ "$_t26_stale29" = "0" ] \
    && ! printf '%s' "$_t26_out29" | grep -q 'DELETE skipped'; then
    t26_pass "TC-29 経路1 正常系: base=3/stale=1 で非発火・stale 1 件のみ削除・exit 0"
  else
    t26_fail "TC-29 失敗 (rc=$_t26_rc29 期待0 / left=$_t26_left29 期待3 / stale残=$_t26_stale29 期待0): $_t26_out29"
  fi

  # TC-32: 経路1 — dry-run と実行の判定一致（乖離帯 base=3/stale=4 / R-303b）
  _t26_t32a=$(mktemp -d); register_cleanup "$_t26_t32a"
  _t26_t32b=$(mktemp -d); register_cleanup "$_t26_t32b"
  _t26_mk_refs_guard_sandbox "$_t26_t32a" 3 4 skill-A
  _t26_mk_refs_guard_sandbox "$_t26_t32b" 3 4 skill-A
  _t26_rc32a=0
  _t26_out32a=$(sh "$_t26_t32a/scripts/sync-plugin-plangate.sh" --dry-run 2>&1) || _t26_rc32a=$?
  _t26_left32a=$(_t26_count_files "$_t26_t32a/plugin/plangate/skills/skill-A/references")
  _t26_rc32b=0
  _t26_out32b=$(sh "$_t26_t32b/scripts/sync-plugin-plangate.sh" 2>&1) || _t26_rc32b=$?
  _t26_left32b=$(_t26_count_files "$_t26_t32b/plugin/plangate/skills/skill-A/references")
  rm -rf "$_t26_t32a" "$_t26_t32b"
  _t26_fired32a=no; printf '%s' "$_t26_out32a" | grep -q 'safety guard' && _t26_fired32a=yes
  _t26_fired32b=no; printf '%s' "$_t26_out32b" | grep -q 'safety guard' && _t26_fired32b=yes
  if [ "$_t26_fired32a" = "yes" ] && [ "$_t26_fired32b" = "yes" ] \
    && [ "$_t26_rc32a" -eq 0 ] && [ "$_t26_left32a" = "7" ] \
    && ! printf '%s' "$_t26_out32a" | grep -q 'WOULD DELETE' \
    && [ "$_t26_rc32b" -eq 3 ] && [ "$_t26_left32b" = "7" ]; then
    t26_pass "TC-32 経路1: 乖離帯 base=3/stale=4 で dry-run と実行の guard 判定が一致"
  else
    t26_fail "TC-32 失敗 (dry: fired=$_t26_fired32a rc=$_t26_rc32a left=$_t26_left32a 期待 yes/0/7 / run: fired=$_t26_fired32b rc=$_t26_rc32b left=$_t26_left32b 期待 yes/3/7)"
  fi

  # TC-34: 経路1 境界 — base = stale（同数）で guard 非発火（RV-M4 / M-6b 用 fixture）
  # stale > base が偽（3 > 3 不成立）なので削除実行が正しい。閾値を >= へ 1 段
  # ずらす変異（M-6b）はこの fixture でのみ検出できる（乖離帯は stale=base+1）。
  _t26_t34=$(mktemp -d); register_cleanup "$_t26_t34"
  _t26_mk_refs_guard_sandbox "$_t26_t34" 3 3 skill-A
  _t26_rc34=0
  _t26_out34=$(sh "$_t26_t34/scripts/sync-plugin-plangate.sh" 2>&1) || _t26_rc34=$?
  _t26_left34=$(_t26_count_files "$_t26_t34/plugin/plangate/skills/skill-A/references")
  _t26_stale34=0
  for _t26_n34 in 1 2 3; do
    [ -f "$_t26_t34/plugin/plangate/skills/skill-A/references/stale-$_t26_n34.md" ] \
      && _t26_stale34=$((_t26_stale34 + 1))
  done
  _t26_kept34=0
  for _t26_n34 in 1 2 3; do
    [ -f "$_t26_t34/plugin/plangate/skills/skill-A/references/ref-$_t26_n34.md" ] \
      && _t26_kept34=$((_t26_kept34 + 1))
  done
  rm -rf "$_t26_t34"
  if [ "$_t26_rc34" -eq 0 ] && [ "$_t26_left34" = "3" ] \
    && [ "$_t26_stale34" = "0" ] && [ "$_t26_kept34" = "3" ] \
    && ! printf '%s' "$_t26_out34" | grep -q 'DELETE skipped'; then
    t26_pass "TC-34 経路1 境界: base=3/stale=3（同数）で非発火・stale 3 件削除・src 一致 3 件保持"
  else
    t26_fail "TC-34 失敗 (rc=$_t26_rc34 期待0 / left=$_t26_left34 期待3 / stale残=$_t26_stale34 期待0 / 保持=$_t26_kept34 期待3): $_t26_out34"
  fi

  # TC-35: 経路1 — 解決可能 symlink stale を集計に含める（#970 / 集計 = 削除の厳密一致）
  # base=3/stale=3 の非発火 fixture へ「解決可能 symlink stale」2 件を追加注入し、
  # 集計が symlink を含む（stale=5 > base=3 → 発火）ことを guard ログの文字列で直接固定する。
  # 集計が symlink を除外する実装（修正前 = 変異 M-1）では stale=3 と数えて 3 > 3 が偽 →
  # 非発火のまま 5 件を削除する（「N 件と数えて M 件消す」guard 無効化）。
  # 副次検査: target が存在しない symlink（dangling-1.md）は [ -f ] が偽のため集計に入らない
  #（`base=3 / stale=5` の文字列一致が変わらないことで固定 / 変異 M-2 を検出する）。
  # ヘルパーのシグネチャは変更せず、通常呼び出しの**後**に sandbox へ symlink を追加注入する。
  # symlink の target は同期の走査対象外である sandbox 直下 targets/ に置く。
  _t26_t35=$(mktemp -d); register_cleanup "$_t26_t35"
  _t26_mk_refs_guard_sandbox "$_t26_t35" 3 3 skill-A
  _t26_refs35="$_t26_t35/plugin/plangate/skills/skill-A/references"
  mkdir -p "$_t26_t35/targets"
  for _t26_n35 in 1 2; do
    printf 'linked target %s\n' "$_t26_n35" > "$_t26_t35/targets/target-$_t26_n35.md"
    ln -s "$_t26_t35/targets/target-$_t26_n35.md" "$_t26_refs35/link-$_t26_n35.md"
  done
  ln -s "$_t26_t35/targets/missing.md" "$_t26_refs35/dangling-1.md"
  _t26_rc35=0
  _t26_out35=$(sh "$_t26_t35/scripts/sync-plugin-plangate.sh" 2>&1) || _t26_rc35=$?
  _t26_left35=$(_t26_count_files "$_t26_refs35")
  _t26_tgt35=0
  for _t26_n35 in 1 2; do
    [ -f "$_t26_t35/targets/target-$_t26_n35.md" ] && _t26_tgt35=$((_t26_tgt35 + 1))
  done
  rm -rf "$_t26_t35"
  if [ "$_t26_rc35" -eq 3 ] && [ "$_t26_left35" = "9" ] && [ "$_t26_tgt35" = "2" ] \
    && printf '%s' "$_t26_out35" | grep -q 'base=3 / stale=5' \
    && printf '%s' "$_t26_out35" | grep -q 'DELETE skipped for skills/skill-A/references'; then
    t26_pass "TC-35 経路1: 解決可能 symlink stale 2 件が集計に入り base=3/stale=5 で発火・9 件全残存・target 非破壊"
  else
    t26_fail "TC-35 失敗 (rc=$_t26_rc35 期待3 / left=$_t26_left35 期待9 / target残=$_t26_tgt35 期待2 / 期待文字列 'base=3 / stale=5'): $_t26_out35"
  fi

  # TC-36: 経路1 非発火帯 — 解決可能 symlink stale が実際に削除される（#970 逆方向）
  # TC-35 は guard 発火帯のため削除ループが実行されず、「削除ループにだけ [ -L ] 除外を
  # 足す」変異（M-1'）を検出できない。本 TC は非発火帯（stale == base）で symlink が
  # 実削除されることを DELETE ログで固定し、集計 = 削除の**逆方向**を塞ぐ。
  # base=3 / stale=2 + 解決可能 symlink 1 件 = stale 3 → 3 > 3 が偽で非発火 → 3 件削除。
  _t26_t36=$(mktemp -d); register_cleanup "$_t26_t36"
  _t26_mk_refs_guard_sandbox "$_t26_t36" 3 2 skill-A
  _t26_refs36="$_t26_t36/plugin/plangate/skills/skill-A/references"
  mkdir -p "$_t26_t36/targets"
  printf 'linked target 1\n' > "$_t26_t36/targets/target-1.md"
  ln -s "$_t26_t36/targets/target-1.md" "$_t26_refs36/link-1.md"
  _t26_rc36=0
  _t26_out36=$(sh "$_t26_t36/scripts/sync-plugin-plangate.sh" 2>&1) || _t26_rc36=$?
  _t26_left36=$(_t26_count_files "$_t26_refs36")
  _t26_tgt36=0
  [ -f "$_t26_t36/targets/target-1.md" ] && _t26_tgt36=1
  rm -rf "$_t26_t36"
  if [ "$_t26_rc36" -eq 0 ] && [ "$_t26_left36" = "3" ] && [ "$_t26_tgt36" = "1" ] \
    && printf '%s' "$_t26_out36" | grep -q 'DELETE: skills/skill-A/references/link-1.md' \
    && ! printf '%s' "$_t26_out36" | grep -q 'DELETE skipped'; then
    t26_pass "TC-36 経路1 非発火帯: 解決可能 symlink stale が実削除される（集計 = 削除の逆方向・target 非破壊）"
  else
    t26_fail "TC-36 失敗 (rc=$_t26_rc36 期待0 / left=$_t26_left36 期待3 / target残=$_t26_tgt36 期待1 / 期待ログ 'DELETE: skills/skill-A/references/link-1.md'): $_t26_out36"
  fi
fi

# TC-30: tests/extras/README.md に harness 判別規約が存在（#914 AC-5 / 静的検査）
_t26_readme30="$PG_T26_ROOT/tests/extras/README.md"
if grep -q 'PG_HARNESS_SOURCED' "$_t26_readme30" 2>/dev/null \
  && grep -q '非 export' "$_t26_readme30" \
  && grep -q 'AND' "$_t26_readme30" \
  && grep -q 'standalone 側（安全側）' "$_t26_readme30"; then
  t26_pass "TC-30 README.md に判別規約（PG_HARNESS_SOURCED / 非 export / AND / standalone 側（安全側））"
else
  t26_fail "TC-30 README.md の判別規約が不足（PG_HARNESS_SOURCED / 非 export / AND / standalone 側（安全側） のいずれか欠落）"
fi

# TC-33: FIXTURES_DIR 単独判別の残存 0 + unset 集合の包含（#914 AC-9 / R-304 / R-306）
# 「統一」は残存 0 という全体性質であり個別ファイルの置換完了とは別命題。
# 件数（11 等）をハードコードしない grep ベース検査:
#   (1) 判別行（FIXTURES_DIR:- を含む条件行）に AND の相方 PG_HARNESS_SOURCED が
#       同居していること
#   (2) run-tests.sh 冒頭の unset 集合 ⊆ FIXTURES_DIR 判別を持つ各 extras
#       （ta-26 自身も対象）の standalone unset 集合
#
# (1) の是正（#994 / #1178 AC-c）: 旧実装は `grep -q 'PG_HARNESS_SOURCED' <file>`
# の**ファイル単位**判定で、実際に守っていたのは「相方シグナルの文字列が
# ファイル中に存在すること」であって「判別式が AND であること」ではなかった。
# 判別行を `FIXTURES_DIR:-` を含む**条件行**（`if` / `elif` / `; then`）に
# 限定し、その行に相方が同居しているかを見る。行継続で折られた判別式に
# 対応するため、(2) と同じ awk 継続行結合を共有する。
_t26_viol33=""
_t26_incl33=""
_t26_nocond33=""
_t26_scanned33=0
# 行継続（末尾 `\`）を 1 行へ結合する共有正規化。旧実装は `grep '^\s*unset '`
# を直接かけていたため、複数行に折られた unset の 2 行目以降が不可視になり
# （かつ末尾 `\` を env 名として収集し）false positive を出していた
# （#914 / PR #986 CI 実害。ta-60 が該当）。
_t26_join_cont33() {
  awk '
    { if (cont) { buf = buf " " $0 } else { buf = $0 } }
    buf ~ /\\$/ { sub(/\\$/, "", buf); cont = 1; next }
    { cont = 0; print buf }
    END { if (cont) print buf }
  ' "$1" 2>/dev/null
}
# unset 行 → env 名列への正規化（リスト増減に自動追従・件数非依存）。
# 先頭の unset と末尾の 2>/dev/null / || true をリダイレクト・演算子ごと落とす。
# 注意: case の [A-Z]* でのトークン選別は locale collation 下で 'true' 等の
# 小文字にもマッチし得るため使わない（実測で混入を確認済み）。
_t26_unset_envs33() {
  _t26_join_cont33 "$1" \
    | grep -E '^[[:space:]]*unset ' \
    | sed -e 's/[[:space:]]*2>\/dev\/null.*$//' -e 's/[[:space:]]*||.*$//' \
          -e 's/^[[:space:]]*unset[[:space:]]*//'
}
# 判別行（条件行のうち FIXTURES_DIR:- を含むもの）。コメント行は除く。
# 末尾 `|| true`（および呼び出し側の `|| true`）は必須 — 一致 0 件で grep が
# 非ゼロを返すと、harness（run-tests.sh の `set -eu` 下で source）では関数が
# その場で打ち切られ、`nocond` を印字しないまま非ゼロで戻って**違反に化ける**
# （standalone は set -e が無いため再現せず、harness だけで落ちる型の差）。
_t26_disc_lines33() {
  _t26_join_cont33 "$1" \
    | grep -v '^[[:space:]]*#' \
    | grep 'FIXTURES_DIR:-' \
    | grep -E '^[[:space:]]*(if|elif)[[:space:]]|;[[:space:]]*then([[:space:]]|$)' \
    || true
}
# 判別行に相方が同居しているか。判別行が 1 本も無いファイル（root 導出だけに
# FIXTURES_DIR を使う harness 専用 extras）は、旧来のファイル単位判定へ
# フォールバックし、件数を可視化する（黙って検査対象外にしない）。
_t26_disc_ok33() {
  _t26_dl33=$(_t26_disc_lines33 "$1") || _t26_dl33=""
  if [ -z "$_t26_dl33" ]; then
    printf 'nocond\n'
    if grep -q 'PG_HARNESS_SOURCED' "$1"; then
      return 0
    fi
    return 1
  fi
  printf 'cond\n'
  if printf '%s\n' "$_t26_dl33" | grep -v 'PG_HARNESS_SOURCED' | grep -q .; then
    return 1
  fi
  return 0
}
_t26_hset33=$(_t26_unset_envs33 "$PG_T26_ROOT/tests/run-tests.sh" | tr '\n' ' ')
for _t26_f33 in "$PG_T26_ROOT/tests/extras/"ta-*.sh; do
  [ -f "$_t26_f33" ] || continue
  grep -q 'FIXTURES_DIR:-' "$_t26_f33" || continue
  _t26_scanned33=$((_t26_scanned33 + 1))
  # (1) 判別行の AND 同居（#994 / #1178 AC-c）
  _t26_shape33=""
  _t26_ok33=0
  _t26_shape33=$(_t26_disc_ok33 "$_t26_f33") || _t26_ok33=1
  case "$_t26_shape33" in
    nocond) _t26_nocond33="$_t26_nocond33 ${_t26_f33##*/}" ;;
  esac
  if [ "$_t26_ok33" != "0" ]; then
    _t26_viol33="$_t26_viol33 ${_t26_f33##*/}"
    continue
  fi
  # (2) unset 包含（当該ファイルの unset 行群から env 名を収集して照合）
  _t26_fset33=$(_t26_unset_envs33 "$_t26_f33" | tr '\n' ' ')
  for _t26_e33 in $_t26_hset33; do
    case " $_t26_fset33 " in
      *" $_t26_e33 "*) : ;;
      *) _t26_incl33="$_t26_incl33 ${_t26_f33##*/}:$_t26_e33" ;;
    esac
  done
done
# 走査 0 件（glob 空振り・パス誤り）でも「違反 0 件」で緑になる恒真を塞ぐ。
# floor は絶対件数の契約値ではない（`-eq` にしない / #1087 AC-9）。
_T26_MIN_SCANNED33=20
if [ -n "$_t26_hset33" ] && [ -z "$_t26_viol33" ] && [ -z "$_t26_incl33" ] \
   && [ "$_t26_scanned33" -ge "$_T26_MIN_SCANNED33" ]; then
  t26_pass "TC-33 判別行に AND の相方が同居（走査 ${_t26_scanned33} 件 / 判別行なし:${_t26_nocond33:- なし}）+ standalone unset が run-tests.sh の unset 集合を包含"
else
  t26_fail "TC-33 失敗 (判別行違反:${_t26_viol33:- なし} / unset欠落:${_t26_incl33:- なし} / 走査 ${_t26_scanned33} 件 / harness集合:${_t26_hset33:- 空})"
fi

# TC-38: README 規約 8 の例示コードブロックが TC-33 の抽出規則 (1)(2) を通る
# （#1004 / #1178 AC-d）。規約の「正本」が例示コードである以上、その例示が
# 検査器を通らない（あるいは検査器が例示の形を読めない）状態は、規約と
# 検査器の乖離そのもの。例示を fixture として抽出し機械照合する。
_t26_tmp38=$(mktemp -d)
if command -v register_cleanup >/dev/null 2>&1; then
  register_cleanup "$_t26_tmp38"
fi
_t26_readme38="$PG_T26_ROOT/tests/extras/README.md"
_t26_fx38="$_t26_tmp38/ta-99-readme-example.sh"
awk '
  !seen && /^8\. \*\*harness\/standalone/ { seen = 1; next }
  seen && !inblk && /^[[:space:]]*```sh[[:space:]]*$/ { inblk = 1; next }
  seen && inblk && /^[[:space:]]*```[[:space:]]*$/ { exit }
  seen && inblk { sub(/^   /, ""); print }
' "$_t26_readme38" > "$_t26_fx38" 2>/dev/null || true
_t26_fxlines38=$(grep -c . "$_t26_fx38" 2>/dev/null || true)
[ -n "$_t26_fxlines38" ] || _t26_fxlines38=0
_t26_v38=""
# 抽出できたこと自体を先に確かめる（空ファイルを「違反 0 件」と読まない）
if [ "$_t26_fxlines38" -lt 3 ]; then
  _t26_v38="$_t26_v38 抽出失敗(${_t26_fxlines38}行)"
else
  # (1) 判別行の AND 同居
  _t26_shape38=$(_t26_disc_ok33 "$_t26_fx38") || _t26_v38="$_t26_v38 判別行(${_t26_shape38})"
  # (2) unset 包含: 例示の unset は行継続で 3 行に折られている。
  #     awk 結合が効いていなければここで落ちる
  _t26_fset38=$(_t26_unset_envs33 "$_t26_fx38" | tr '\n' ' ')
  for _t26_e38 in $_t26_hset33; do
    case " $_t26_fset38 " in
      *" $_t26_e38 "*) : ;;
      *) _t26_v38="$_t26_v38 unset欠落:$_t26_e38" ;;
    esac
  done
fi
if [ -n "$_t26_hset33" ] && [ -z "$_t26_v38" ]; then
  t26_pass "TC-38 README 規約 8 の例示（${_t26_fxlines38} 行）が TC-33 の抽出規則 (1)(2) を通る"
else
  t26_fail "TC-38 README 規約 8 の例示が TC-33 の規則を通らない:${_t26_v38:- harness集合が空}"
fi

# TC-37: skills 索引 README.md の同期経路（#1057 / #1199 / #1221 再発防止）
#
# スキル同期ループは "$SKILLS_DIR"/*/ と**ディレクトリのみ**を走査するため、
# .agents/skills/ 直下のファイルである README.md はかつてどの同期経路にも
# 入っておらず、配布側は手作業でしか追従できなかった（#1199 で手作業追従した
# 5 日後に #1221 で再乖離）。同期経路を追加したので、その経路が**消えたら
# 落ちる**ことを固定する。
#
# 本 TC が無いと、追加ブロックを丸ごと削除しても ta-26 / ta-69 / CI drift-check が
# すべて緑のまま通る（敵対レビューで変異注入により実証済み）。
_t26_t37=$(mktemp -d); register_cleanup "$_t26_t37"
mkdir -p "$_t26_t37/scripts" "$_t26_t37/.agents/skills/dummy-skill" \
  "$_t26_t37/plugin/plangate/skills"
cp "$PG_T26_SCRIPT" "$_t26_t37/scripts/"
printf -- '---\nname: dummy-skill\n---\nbody\n' > "$_t26_t37/.agents/skills/dummy-skill/SKILL.md"
printf 'canonical index v2\n' > "$_t26_t37/.agents/skills/README.md"
# 配布側は「古い版」— 同期経路が生きていれば上書きされる
printf 'stale index v1\n' > "$_t26_t37/plugin/plangate/skills/README.md"
_t26_rc37=0
_t26_out37=$(sh "$_t26_t37/scripts/sync-plugin-plangate.sh" 2>&1) || _t26_rc37=$?
_t26_got37=$(cat "$_t26_t37/plugin/plangate/skills/README.md" 2>/dev/null)
# 2 回目は差分なし（冪等）であることも同時に固定する
_t26_out37b=$(sh "$_t26_t37/scripts/sync-plugin-plangate.sh" 2>&1) || true
rm -rf "$_t26_t37"
if [ "$_t26_rc37" = "0" ] \
  && [ "$_t26_got37" = "canonical index v2" ] \
  && printf '%s' "$_t26_out37" | grep -q 'COPY: skills/README\.md' \
  && printf '%s' "$_t26_out37b" | grep -q 'no changes'; then
  t26_pass "TC-37 skills/README.md が正本から同期され、2 回目は差分なし（#1057 再発防止）"
else
  t26_fail "TC-37 skills/README.md の同期経路が機能していない (rc=$_t26_rc37 / 内容=${_t26_got37:- 空} / 1回目=${_t26_out37} / 2回目=${_t26_out37b})"
fi

# ── #1249 敵対レビュー MAJOR-2 / MAJOR-3 / MINOR-4 の回帰 TC 群 ──────────────
#
# #1249（ai-dev 実行資材の同梱）は 176 行の guard / spec ロジックを足しながら
# ta-26 に TC を 1 件も足さなかった。敵対レビューの変異実測では
#   - spec の `plan-template.md` を `plan.md` へ revert（唯一の Human 決定の破棄）
#   - sandbox 一覧から `handoff.md` を 1 件だけ落とす
# のいずれも **34 passed / 0 failed = 検出されない**（配布物は実際に劣化する）。
# 以下はその 2 変異と、spec ソース不在の無警告脱落・二重管理の非収束を固定する。

PG_T26_PY="$(command -v python3 2>/dev/null || true)"

# `_ai_dev_ref_spec` の **実出力**を `<skill>\t<配布先 basename>\t<ソース>` で吐く
# （#1249 MAJOR-3(new)）。
#
# 旧実装は `'([^' ]+\.(?:md|json|yaml))\s+([^']+)'` という字句正規表現で spec を
# 読んでいたが、これはシングルクォート + 特定拡張子という **書き方** にしか当たら
# ない。実測でダブルクォート表記・`.sh` 拡張子・既存行のクォート変更がいずれも
# 無警告で母数から落ち、`PAIRS >= 20` / `srcs >= 15` の floor は
# 「完全な空振り」しか止めなかった（4〜5 本の消失を許す）。
# 抽出した関数を実際に `sh` で実行し、その出力を正とすればクォート種別・拡張子・
# 行継続はシェル自身が解釈するため形状に依存しない。
# 取得失敗（関数が無い / 一覧が無い / 出力が空）は stdout を空にして返し、
# 呼び出し側が PARSE-FAIL として扱う。
_t26_spec_dump() {
  _t26_sd_script="$1"
  _t26_sd_fn="$(mktemp)"
  awk '/^_ai_dev_ref_spec\(\) \{/{f=1} f{print} f&&/^\}$/{exit}' \
    "$_t26_sd_script" > "$_t26_sd_fn" 2>/dev/null || true
  if ! grep -q '^_ai_dev_ref_spec() {' "$_t26_sd_fn" 2>/dev/null; then
    rm -f "$_t26_sd_fn"; return 0
  fi
  _t26_sd_skills="$(grep -m1 '^AI_DEV_SKILLS=' "$_t26_sd_script" 2>/dev/null \
    | sed 's/^AI_DEV_SKILLS=//; s/"//g')"
  for _t26_sd_s in $_t26_sd_skills; do
    sh -c '. "$1"; _ai_dev_ref_spec "$2"' _ "$_t26_sd_fn" "$_t26_sd_s" 2>/dev/null \
      | awk -v k="$_t26_sd_s" 'NF{print k"\t"$1"\t"$2}'
  done
  rm -f "$_t26_sd_fn"
}

_T26_SPEC_DUMP="$(mktemp)"
register_cleanup "$_T26_SPEC_DUMP"
_t26_spec_dump "$PG_T26_SCRIPT" > "$_T26_SPEC_DUMP" 2>/dev/null || true

# TC-39: 配布 references/ に basename `plan.md` が存在しない（spec + 実配布物の両面）
#
# `scripts/hooks/check-plan-hash.sh` の EH-3 は **basename** `plan.md` で block する
# （パス判定ではない）。そのまま同梱すると導入先で雛形が編集不能になるため、
# `docs/working/templates/plan.md` は配布先で `plan-template.md` へリネームする
# ——これが #1232 で唯一の Human 決定である。spec を revert しても実配布物は
# 次の sync まで変わらないので、**spec 側**も併せて検査しないと変異が生き残る。
_t26_v39=''
if [ -z "$PG_T26_PY" ]; then
  t26_fail "TC-39 python3 が解決できない"
else
  # (a) spec が配布先 basename に plan.md を出さない
  #     判定は `_ai_dev_ref_spec` の **実出力**（$_T26_SPEC_DUMP）で行う。
  #     字句解析だとクォート種別を変えるだけで対象行が母数から消える（MAJOR-3(new)）。
  _t26_pairs39=$(awk 'NF' "$_T26_SPEC_DUMP" 2>/dev/null | wc -l | tr -d ' ')
  if [ "${_t26_pairs39:-0}" = "0" ]; then
    _t26_v39="$_t26_v39 spec-parse-fail"
  fi
  _t26_spec39=$(awk -F'\t' 'NF==3{print "BASE\t"$2"\t"$3}' "$_T26_SPEC_DUMP" 2>/dev/null)
  # 陽性コントロール: 抽出が空振りしていないこと（PAIRS>=20）と、
  # リネーム後の basename が実際に spec に居ること
  [ -n "$_t26_pairs39" ] && [ "$_t26_pairs39" -ge 20 ] 2>/dev/null \
    || _t26_v39="$_t26_v39 spec-pairs-too-few(${_t26_pairs39:-none})"
  printf '%s' "$_t26_spec39" | grep -q "^BASE	plan-template.md	" \
    || _t26_v39="$_t26_v39 plan-template.md-not-in-spec"
  # 本体判定: 配布先 basename に plan.md が無い
  if printf '%s' "$_t26_spec39" | grep -q "^BASE	plan.md	"; then
    _t26_v39="$_t26_v39 spec-emits-plan.md"
  fi
  # (b) 実配布ツリーにも basename plan.md が無い
  for _t26_f39 in "$PG_T26_PLUGIN"/skills/*/references/plan.md; do
    [ -f "$_t26_f39" ] || continue
    _t26_v39="$_t26_v39 distributed:${_t26_f39#"$PG_T26_ROOT"/}"
  done
  # (c) block の根拠（EH-3 の basename case）が実在する — 前提が消えたら気づく
  grep -q '\*/plan\.md|plan\.md' "$PG_T26_ROOT/scripts/hooks/check-plan-hash.sh" 2>/dev/null \
    || _t26_v39="$_t26_v39 eh3-basename-case-missing"
  if [ -z "$_t26_v39" ]; then
    t26_pass "TC-39 配布 references/ に basename plan.md なし（spec ${_t26_pairs39} 件 / plan-template.md 実在 / EH-3 basename case 実在）"
  else
    t26_fail "TC-39 失敗:$_t26_v39"
  fi
fi

# TC-40: _ai_dev_ref_spec のソース集合 ⊆ ta-26 sandbox の同梱一覧（機械照合）
#
# sandbox が sync の入力を 1 件でも欠くと、その skill の期待集合が縮んで
# 実 repo と違う条件で guard を検査することになる（TC-05 の前提が崩れる）。
# ta-57 TC-E8 / ta-60 の「for ループと case 文の集合一致」と同型の drift 検査。
if [ -z "$PG_T26_PY" ]; then
  t26_fail "TC-40 python3 が解決できない"
else
  _t26_rc40=0
  _t26_out40=$("$PG_T26_PY" - "$_T26_SPEC_DUMP" "$PG_T26_ROOT/tests/extras/ta-26-plugin-sync.sh" <<'PY' 2>&1
import pathlib, re, sys

dump = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
selfsrc = pathlib.Path(sys.argv[2]).read_text(encoding="utf-8")

# spec は `_ai_dev_ref_spec` の実出力（字句解析ではない / #1249 MAJOR-3(new)）。
rows = [ln.split("\t") for ln in dump.splitlines() if ln.strip()]
assert rows and all(len(r) == 3 for r in rows), (
    "PARSE-FAIL: _ai_dev_ref_spec の実出力が取れない (rows=%d)" % len(rows))
spec_srcs = {r[2] for r in rows}
assert len(spec_srcs) >= 15, "PARSE-FAIL: spec ソースの実出力が少なすぎる (%d)" % len(spec_srcs)

block = re.search(r"^for _f26 in \\\n(.*?)^do$", selfsrc, re.S | re.M)
assert block, "PARSE-FAIL: sandbox 一覧 (for _f26) が見つからない"
listed = {ln.strip().rstrip("\\").strip() for ln in block.group(1).splitlines()}
listed = {p for p in listed if p}
assert len(listed) >= 10, "PARSE-FAIL: sandbox 一覧の抽出が空振り (%d)" % len(listed)

# ファイル単位の一覧のほかに、sandbox は `cp -r "$PG_T26_ROOT/<dir>"` で
# ディレクトリごと持ち込む経路も持つ（docs/workflows/ai-loop など）。
# その配下は「一覧に無くても供給されている」ため被覆に数える。
#
# 走査対象は **sandbox builder のマーカー区間の、コメントでない行**に限る
# （#1249 MINOR-1）。ファイル全体を対象にしていた旧実装は、実行されない
# コメント行 `# cp -r "$PG_T26_ROOT/docs" ...` を書くだけで docs/ 配下を
# 全被覆と誤認し、陽性コントロールを無効化できた（実測）。
region = re.search(
    r"^# >>> PG_T26_SANDBOX_BUILDER_BEGIN$(.*?)^# <<< PG_T26_SANDBOX_BUILDER_END$",
    selfsrc, re.S | re.M)
assert region, "PARSE-FAIL: sandbox builder のマーカー区間が見つからない"
exec_lines = "\n".join(ln for ln in region.group(1).splitlines()
                       if not ln.lstrip().startswith("#"))
dirs = set(re.findall(r'cp -r "\$PG_T26_ROOT/([^"]+)"', exec_lines))

def covered(p):
    return p in listed or any(p.startswith(d.rstrip("/") + "/") for d in dirs)

missing = sorted(p for p in spec_srcs if not covered(p))
assert not missing, (
    "sandbox drift: _ai_dev_ref_spec のソースが ta-26 sandbox の同梱経路に無い -> %s"
    % missing)
print("OK spec=%d sandbox_files=%d sandbox_dirs=%d" % (len(spec_srcs), len(listed), len(dirs)))
PY
) || _t26_rc40=$?
  if [ "$_t26_rc40" = "0" ] && printf '%s' "$_t26_out40" | grep -q '^OK spec='; then
    t26_pass "TC-40 spec ソース集合 ⊆ sandbox 同梱一覧（$(printf '%s' "$_t26_out40" | tr -d '\n')）"
  else
    t26_fail "TC-40 失敗 (rc=$_t26_rc40): $_t26_out40"
  fi
fi

# ai-dev 用 sandbox ビルダ（guard 境界 TC / spec 欠損 TC 共用）
# $1=dir / $2=skill 名 / $3=stale 件数 / $4以降=配置するソース相対パス
_t26_mk_ai_dev_sandbox() {
  _t26_ad_dir="$1"; _t26_ad_skill="$2"; _t26_ad_stale="$3"; shift 3
  mkdir -p "$_t26_ad_dir/scripts" \
    "$_t26_ad_dir/.agents/skills/$_t26_ad_skill" \
    "$_t26_ad_dir/plugin/plangate/skills/$_t26_ad_skill/references"
  cp "$PG_T26_SCRIPT" "$_t26_ad_dir/scripts/"
  cp "$PG_T26_ROOT/scripts/_ai_loop_link_rewrite.py" "$_t26_ad_dir/scripts/"
  printf -- '---\nname: %s\n---\nbody\n' "$_t26_ad_skill" \
    > "$_t26_ad_dir/.agents/skills/$_t26_ad_skill/SKILL.md"
  for _t26_ad_f in "$@"; do
    mkdir -p "$_t26_ad_dir/$(dirname "$_t26_ad_f")"
    printf 'src %s\n' "$_t26_ad_f" > "$_t26_ad_dir/$_t26_ad_f"
  done
  _t26_ad_i=1
  while [ "$_t26_ad_i" -le "$_t26_ad_stale" ]; do
    printf 'stale %s\n' "$_t26_ad_i" \
      > "$_t26_ad_dir/plugin/plangate/skills/$_t26_ad_skill/references/stale-$_t26_ad_i.md"
    _t26_ad_i=$((_t26_ad_i + 1))
  done
}

# ai-dev-brainstorm の期待集合は 3 件（spec 固定）。境界 base = stale を作れる。
_T26_BRAINSTORM_SRCS="docs/ai-driven-development.md docs/ai/core-contract.md docs/plangate.md"

# TC-41: ai-dev 削除 guard の境界 — base = stale は非発火 / base < stale は発火
#
# `_mass_delete_blocked` は `stale > base` でのみ block する。境界（同数）で
# 誤って発火すると正当な stale が消えなくなり、逆に境界を緩めると mass-delete が
# 素通りする。両側を 1 件差で固定する（片側だけでは閾値のズレを検出できない）。
_t26_t41a=$(mktemp -d); register_cleanup "$_t26_t41a"
# shellcheck disable=SC2086
_t26_mk_ai_dev_sandbox "$_t26_t41a" ai-dev-brainstorm 3 $_T26_BRAINSTORM_SRCS
_t26_rc41a=0
_t26_out41a=$(sh "$_t26_t41a/scripts/sync-plugin-plangate.sh" 2>&1) || _t26_rc41a=$?
_t26_left41a=$(ls "$_t26_t41a/plugin/plangate/skills/ai-dev-brainstorm/references" 2>/dev/null | wc -l | tr -d ' ')
_t26_stale41a=$(ls "$_t26_t41a/plugin/plangate/skills/ai-dev-brainstorm/references"/stale-*.md 2>/dev/null | wc -l | tr -d ' ')

_t26_t41b=$(mktemp -d); register_cleanup "$_t26_t41b"
# shellcheck disable=SC2086
_t26_mk_ai_dev_sandbox "$_t26_t41b" ai-dev-brainstorm 4 $_T26_BRAINSTORM_SRCS
_t26_rc41b=0
_t26_out41b=$(sh "$_t26_t41b/scripts/sync-plugin-plangate.sh" 2>&1) || _t26_rc41b=$?
_t26_stale41b=$(ls "$_t26_t41b/plugin/plangate/skills/ai-dev-brainstorm/references"/stale-*.md 2>/dev/null | wc -l | tr -d ' ')
rm -rf "$_t26_t41a" "$_t26_t41b"
if [ "$_t26_rc41a" -eq 0 ] && [ "$_t26_left41a" = "3" ] && [ "$_t26_stale41a" = "0" ] \
  && ! printf '%s' "$_t26_out41a" | grep -q 'safety guard' \
  && [ "$_t26_rc41b" -eq 3 ] && [ "$_t26_stale41b" = "4" ] \
  && printf '%s' "$_t26_out41b" | grep -q 'skills/ai-dev-brainstorm/references' \
  && printf '%s' "$_t26_out41b" | grep -q 'base=3 / stale=4'; then
  t26_pass "TC-41 ai-dev guard 境界: base=3/stale=3 は非発火（stale 3 件削除・期待 3 件のみ残存）/ base=3/stale=4 は発火（rc=3・4 件全残存）"
else
  t26_fail "TC-41 失敗 (同数: rc=$_t26_rc41a 期待0 left=$_t26_left41a 期待3 stale残=$_t26_stale41a 期待0 / 超過: rc=$_t26_rc41b 期待3 stale残=$_t26_stale41b 期待4): $_t26_out41a ||| $_t26_out41b"
fi

# TC-42: spec ソース不在は _warn し、配布側の既存ファイルを削除しない（MAJOR-3）
#
# spec は固定パス 24 件で ai-loop のディレクトリ glob と違い rename に追従しない。
# 旧実装は `[ -f ... ] || continue` で黙って落としていたため、上流の 1 本の rename で
# 配布物が警告ゼロで消えた（実測: core-contract.md のパスを 1 文字変えるだけで
# 4 skill の core-contract.md が rc=0・警告なしで DELETE された）。
_t26_t42=$(mktemp -d); register_cleanup "$_t26_t42"
# shellcheck disable=SC2086
_t26_mk_ai_dev_sandbox "$_t26_t42" ai-dev-brainstorm 0 $_T26_BRAINSTORM_SRCS
# 1 回目: 3 件が配布される
sh "$_t26_t42/scripts/sync-plugin-plangate.sh" >/dev/null 2>&1 || true
_t26_seed42=$(ls "$_t26_t42/plugin/plangate/skills/ai-dev-brainstorm/references" 2>/dev/null | wc -l | tr -d ' ')
# 上流 rename を模擬: ソース 1 本だけを消す
rm -f "$_t26_t42/docs/ai/core-contract.md"
_t26_rc42=0
_t26_out42=$(sh "$_t26_t42/scripts/sync-plugin-plangate.sh" 2>&1) || _t26_rc42=$?
_t26_kept42=0
[ -f "$_t26_t42/plugin/plangate/skills/ai-dev-brainstorm/references/core-contract.md" ] && _t26_kept42=1
rm -rf "$_t26_t42"
if [ "$_t26_seed42" = "3" ] && [ "$_t26_rc42" -eq 0 ] && [ "$_t26_kept42" = "1" ] \
  && printf '%s' "$_t26_out42" | grep -q 'WARN: spec のソースが見つかりません' \
  && printf '%s' "$_t26_out42" | grep -q 'docs/ai/core-contract.md' \
  && ! printf '%s' "$_t26_out42" | grep -q 'DELETE: skills/ai-dev-brainstorm/references/core-contract.md'; then
  t26_pass "TC-42 spec ソース不在で WARN 出力・配布側を保持（無警告脱落の再発防止 / seed=3）"
else
  t26_fail "TC-42 失敗 (seed=$_t26_seed42 期待3 / rc=$_t26_rc42 期待0 / 保持=$_t26_kept42 期待1): $_t26_out42"
fi

# TC-43: 汎用 skills ループとの二重管理は「消し合う」ではなく一方向 DELETE の非収束
#
# `.agents/skills/ai-dev-*/references/` を作ると、汎用ループが COPY した直後に
# ai-dev ループが stale として DELETE する。順序が固定なので配布側へは永久に
# 届かず、`changed=1` が立ち続けて "no changes" に収束しない。
# 実測どおりの性質を固定する（net のファイル状態は不変なので CI の
# `git diff --quiet` は緑のまま = 「CI 恒久 red」ではない、という点も含めて）。
_t26_t43=$(mktemp -d); register_cleanup "$_t26_t43"
# shellcheck disable=SC2086
_t26_mk_ai_dev_sandbox "$_t26_t43" ai-dev-brainstorm 0 $_T26_BRAINSTORM_SRCS
mkdir -p "$_t26_t43/.agents/skills/ai-dev-brainstorm/references"
printf 'dual-managed\n' > "$_t26_t43/.agents/skills/ai-dev-brainstorm/references/extra.md"
_t26_conv43=0   # "no changes" に収束した run の数
_t26_cycle43=0  # COPY と DELETE が同一 run に両方出た回数
_t26_i43=1
while [ "$_t26_i43" -le 3 ]; do
  _t26_o43=$(sh "$_t26_t43/scripts/sync-plugin-plangate.sh" 2>&1) || true
  if printf '%s' "$_t26_o43" | grep -q 'COPY (links self-contained): skills/ai-dev-brainstorm/references/extra.md' \
    || printf '%s' "$_t26_o43" | grep -q 'COPY: skills/ai-dev-brainstorm/references/extra.md'; then
    if printf '%s' "$_t26_o43" | grep -q 'DELETE: skills/ai-dev-brainstorm/references/extra.md'; then
      _t26_cycle43=$((_t26_cycle43 + 1))
    fi
  fi
  printf '%s' "$_t26_o43" | grep -q 'Sync complete — no changes' && _t26_conv43=$((_t26_conv43 + 1))
  _t26_i43=$((_t26_i43 + 1))
done
_t26_land43=0
[ -f "$_t26_t43/plugin/plangate/skills/ai-dev-brainstorm/references/extra.md" ] && _t26_land43=1
rm -rf "$_t26_t43"
if [ "$_t26_cycle43" = "3" ] && [ "$_t26_conv43" = "0" ] && [ "$_t26_land43" = "0" ]; then
  t26_pass "TC-43 二重管理は 3 run とも COPY→DELETE を反復し収束しない（配布側へ到達 0 / 'no changes' 0 回）"
else
  t26_fail "TC-43 失敗 (COPY→DELETE 同時発生=$_t26_cycle43 期待3 / 'no changes'=$_t26_conv43 期待0 / 配布到達=$_t26_land43 期待0)"
fi

# TC-44: guard 発火は当該 skill の削除ループだけを止め、他 skill は削除を続行する
#
# `_mass_delete_blocked` の判定は skill ごとに独立で、発火しても run 全体は
# 止まらない（設計どおり — コピーも他 skill も阻害しない）。裏返すと
# **rc=3 の run でも別 skill の配布物は実際に消えている**。
# 「rc=3 なら何も消えていない」と読まれると事故調査を誤るため、この非対称を固定する。
# per-skill 期待集合方式が ai-loop の合算方式より leverage が弱い理由の実測でもある
# （#1249 敵対レビュー MAJOR-3）。
_t26_t44=$(mktemp -d); register_cleanup "$_t26_t44"
mkdir -p "$_t26_t44/scripts"
cp "$PG_T26_SCRIPT" "$_t26_t44/scripts/"
cp "$PG_T26_ROOT/scripts/_ai_loop_link_rewrite.py" "$_t26_t44/scripts/"
for _t26_s44 in ai-dev-brainstorm ai-dev-verify; do
  mkdir -p "$_t26_t44/.agents/skills/$_t26_s44" \
    "$_t26_t44/plugin/plangate/skills/$_t26_s44/references"
  printf -- '---\nname: %s\n---\nbody\n' "$_t26_s44" \
    > "$_t26_t44/.agents/skills/$_t26_s44/SKILL.md"
done
# 両 skill の spec ソースを全部置く（欠損 WARN を出さず、guard 判定だけを見る）
for _t26_f44 in docs/ai-driven-development.md docs/plangate.md docs/ai/core-contract.md \
  docs/ai/settings-wiring-contract.md docs/workflows/ai-loop/c3-prime-contract.md \
  docs/working/templates/handoff.md; do
  mkdir -p "$_t26_t44/$(dirname "$_t26_f44")"
  printf 'src %s\n' "$_t26_f44" > "$_t26_t44/$_t26_f44"
done
# brainstorm: base=3 / stale=9 → 発火 ｜ verify: base=5 / stale=2 → 非発火
_t26_i44=1
while [ "$_t26_i44" -le 9 ]; do
  printf 'stale\n' > "$_t26_t44/plugin/plangate/skills/ai-dev-brainstorm/references/stale-$_t26_i44.md"
  _t26_i44=$((_t26_i44 + 1))
done
_t26_i44=1
while [ "$_t26_i44" -le 2 ]; do
  printf 'stale\n' > "$_t26_t44/plugin/plangate/skills/ai-dev-verify/references/stale-$_t26_i44.md"
  _t26_i44=$((_t26_i44 + 1))
done
_t26_rc44=0
_t26_out44=$(sh "$_t26_t44/scripts/sync-plugin-plangate.sh" 2>&1) || _t26_rc44=$?
_t26_bs44=$(ls "$_t26_t44/plugin/plangate/skills/ai-dev-brainstorm/references"/stale-*.md 2>/dev/null | wc -l | tr -d ' ')
_t26_vf44=$(ls "$_t26_t44/plugin/plangate/skills/ai-dev-verify/references"/stale-*.md 2>/dev/null | wc -l | tr -d ' ')
rm -rf "$_t26_t44"
if [ "$_t26_rc44" -eq 3 ] && [ "$_t26_bs44" = "9" ] && [ "$_t26_vf44" = "0" ] \
  && printf '%s' "$_t26_out44" | grep -q 'DELETE skipped for skills/ai-dev-brainstorm/references' \
  && printf '%s' "$_t26_out44" | grep -q 'base=3 / stale=9' \
  && printf '%s' "$_t26_out44" | grep -q 'DELETE: skills/ai-dev-verify/references/stale-1.md'; then
  t26_pass "TC-44 guard は skill 単位: rc=3 の同一 run で brainstorm は 9 件保持・verify は 2 件を実削除（rc=3 を「何も消えていない」と読めない）"
else
  t26_fail "TC-44 失敗 (rc=$_t26_rc44 期待3 / brainstorm残=$_t26_bs44 期待9 / verify残=$_t26_vf44 期待0): $_t26_out44"
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
