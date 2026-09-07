# tests/extras/ta-80-eh3-outside-repo.sh
# PG_EXTRA_CAPABILITY: standalone-capable
# Sourced by tests/run-tests.sh — uses $pass / $fail counters
#
# #1234: EH-3 の no-task 経路が **REPO_ROOT の外**のパス（/tmp、ハーネスの
# スクラッチパッド、$HOME 配下）まで `SKIP_BLOCKED` (rc=2) にしていた欠陥の
# 回帰網。仕様の正本は
#   docs/working/_reports/1234-eh3-outside-repo-patch-applicable.md
# の §8「回帰網の仕様」（TC 表）。本ファイルはその表をそのまま実装する。
#
# 期待値ポリシー（ta-79 / ta-65 と同型）:
#   - 既定の期待値は **fixed**（patch 適用後の挙動）
#   - 未適用は tests/fixtures/eh3-outside-repo-pending-1234.flag という
#     **tracked ファイルの存在による明示 opt-in** でのみ gap を許容する
#   - flag があるのに実装が fixed なら **stale 宣言として FAIL**（TC-00b）
#   - PG_T80_EXPECT=fixed|gap で pin できる（デバッグ用。失敗を増やす方向のみ）
#
# patch 済み複製（TC-01〜TC-09）は Human 適用を待たずに patch 内容そのものを
# 実測する。patch は上記 report の <!-- PG-PATCH-BEGIN --> / <!-- PG-PATCH-END -->
# block から抽出する（= その block が壊れると本ファイルが FAIL する）。
#
# 隔離: hook の REPO_ROOT は $0 由来なので mktemp サンドボックス複製で実 repo を
# 汚さない（tests/extras/README.md 規約 3）。**サンドボックスは repo の外**
# （mktemp -d）に置くこと — repo 内サブディレクトリで `git apply` すると patch の
# パスが cwd の外を指すため **何も適用せず rc=0 で成功したように見える**。
#
# 一時状態の射程（README 規約 9）: 本ファイルが作るのは mktemp -d 配下のみ。
# 実 repo の tracked / 共有パスには一切書かない。
#
# 「0 件が期待値」の検査（TC-06 のバイト一致 / TC-07 の skip-decision-log
# 行数不変）は **positive control 付き**で書く（検査器が実際に差分・追記を
# 検出できることを同 TC 内で実証してから 0 件を主張する）。
#
# ── rc 固定と plaform 依存についての点検結果（#1289 CI fail 由来）────
# ta-79 の #1278 レーンは「監査ログを書けなくする」前提を作るため、
# **リダイレクト失敗時の rc が shell 依存**（macOS /bin/sh=1 / dash=2。実測）に
# なり、gap レーンで rc を数値固定していたことが Ubuntu CI の FAIL を招いた。
# 本ファイルは **監査ログを書けない状態を一切作らない**（各 fixture は
# docs/working/_audit を書き込み可能な通常ディレクトリとして用意する）ため、
# 観測される rc はすべて **hook 自身の exit（0 / 2）** で shell 非依存である。
# 実測: macOS /bin/sh と dash（PATH の sh も dash へ差し替え）で 40 PASS / 0 FAIL 一致。
# よって本ファイルの rc + トークン対は据え置く。**将来 TC を足すときも、監査ログを
# 書けなくする前提を導入するなら rc を数値固定しないこと**（gap 側は
# 「PlanGate の理由トークンが出ない」を主判定にする / ta-79 の TC-12 参照）。

# ---- extras execution contract bootstrap (#921) ----------------------------
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
pg_extra_contract_init ta-80-eh3-outside-repo standalone-capable

printf '\n=== TA-80: EH-3 outside-repo SKIP (#1234) ===\n'

if pg_extra_contract_is_standalone; then
  # standalone: 外部 env 汚染を無害化（tests/extras/README.md 規約 8）
  unset PLANGATE_SKIP_REASON PLANGATE_HOOK_TASK PLANGATE_HOOK_FILE \
    PLANGATE_BYPASS_HOOK PLANGATE_HOOK_STRICT PG_HARNESS_SOURCED \
    PLANGATE_ALLOW_MASS_DELETE 2>/dev/null || true
fi

_T80_FX=""
if [ "$_pg_extra_mode" = harness ]; then
  _T80_FX="${FIXTURES_DIR:-}"
fi
if [ -n "$_T80_FX" ]; then
  _T80_ROOT="$(CDPATH= cd -- "$_T80_FX/../.." && pwd)"
else
  _T80_ROOT="${_pg_extra_dir%/tests/extras}"
fi

t80_pass() { pass=$((pass + 1)); printf '  [PASS] %s\n' "$1"; }
t80_fail() { fail=$((fail + 1)); printf '  [FAIL] %s\n' "$1" >&2; }

_T80_OK=1
if [ -z "$_T80_ROOT" ] || [ ! -f "$_T80_ROOT/bin/plangate" ]; then
  t80_fail "ta-80 TC-00: repo root unresolved (_T80_ROOT=$_T80_ROOT)"
  _T80_OK=0
fi

_T80_HOOK_SRC="$_T80_ROOT/scripts/hooks/check-plan-hash.sh"
_T80_REPORT="$_T80_ROOT/docs/working/_reports/1234-eh3-outside-repo-patch-applicable.md"
_T80_FLAG="$_T80_ROOT/tests/fixtures/eh3-outside-repo-pending-1234.flag"
_T80_MARK="OUTSIDE_REPO_SKIP"

if [ "$_T80_OK" = "1" ] && [ ! -f "$_T80_HOOK_SRC" ]; then
  t80_fail "ta-80 TC-00: hook not found: $_T80_HOOK_SRC"
  _T80_OK=0
fi
if [ "$_T80_OK" = "1" ] && [ ! -f "$_T80_REPORT" ]; then
  t80_fail "ta-80 TC-00: patch report not found: $_T80_REPORT"
  _T80_OK=0
fi
if [ "$_T80_OK" = "1" ] && ! command -v python3 >/dev/null 2>&1; then
  pg_extra_contract_skip "python3 unavailable (the #1234 containment check requires python3)"
  _T80_OK=0
fi
if [ "$_T80_OK" = "1" ] && ! command -v git >/dev/null 2>&1; then
  pg_extra_contract_skip "git unavailable (patch application requires git apply)"
  _T80_OK=0
fi

if [ "$_T80_OK" = "1" ]; then

_T80_TMP=$(mktemp -d)
if command -v register_cleanup >/dev/null 2>&1; then
  register_cleanup "$_T80_TMP"
fi

# ── ヘルパ ────────────────────────────────────────────────────────
# サンドボックス fixture（report §1 と同じレイアウト）を 1 式作る。
# $1 = base dir / $2 = 設置する hook のパス
# git worktree add は使わない（git 非依存で linked worktree を手組みする）。
_t80_mkfixture() {
  _t80_fx="$1"
  _t80_fx_root="$1/root"
  mkdir -p "$_t80_fx_root/scripts/hooks" "$_t80_fx_root/bin" \
    "$_t80_fx_root/docs/working/_audit" "$_t80_fx_root/docs/working/_reports" \
    "$_t80_fx_root/docs/working/TASK-9999" "$_t80_fx_root/.claude/worktrees/x" \
    "$_t80_fx_root/.git/worktrees/wt" \
    "$1/outside" "$1/home" "$1/deep/sub" "$1/wt-ext/bin"
  cp "$2" "$_t80_fx_root/scripts/hooks/check-plan-hash.sh"
  printf 'root claude\n' > "$_t80_fx_root/CLAUDE.md"
  printf '#!/bin/sh\n' > "$_t80_fx_root/bin/plangate"
  printf 'plan body for ta-80\n' > "$_t80_fx_root/docs/working/TASK-9999/plan.md"
  printf 'report body\n' > "$_t80_fx_root/docs/working/_reports/x.md"
  printf 'print(1)\n' > "$_t80_fx_root/scripts/foo.py"
  printf 'worktree claude\n' > "$_t80_fx_root/.claude/worktrees/x/CLAUDE.md"
  printf '../..\n' > "$_t80_fx_root/.git/worktrees/wt/commondir"
  printf 'gitdir: %s/.git/worktrees/wt\n' "$_t80_fx_root" > "$1/wt-ext/.git"
  printf 'worktree claude\n' > "$1/wt-ext/CLAUDE.md"
  printf '#!/bin/sh\n' > "$1/wt-ext/bin/plangate"
  printf '<html>\n' > "$1/wt-ext/x.html"
  printf 'outside claude\n' > "$1/outside/CLAUDE.md"
  ln -s "$_t80_fx_root" "$1/outside/link"
  ln -s "$_t80_fx_root/CLAUDE.md" "$1/outside/x.md"
  ln -s "$_t80_fx_root/docs/working/TASK-9999/plan.md" "$1/outside/y.md"
  # 字句では repo 内・物理では repo 外へ抜ける表記（TC-04a / M-LEX 用）
  ln -s "$1/deep/sub" "$1/linkdir"
}

# hook 実行。$1=hook path $2=対象パス $3=TASK $4=STRICT
_t80_rc=0
_t80_out=""
_t80_run() {
  _t80_rc=0
  PLANGATE_HOOK_TASK="$3" PLANGATE_SKIP_REASON="" PLANGATE_HOOK_STRICT="$4" \
    PLANGATE_HOOK_FILE="$2" PLANGATE_BYPASS_HOOK="0" \
    sh "$1" </dev/null > "$_T80_TMP/out.txt" 2>&1 || _t80_rc=$?
  _t80_out=$(cat "$_T80_TMP/out.txt" 2>/dev/null || true)
}

# PATH を差し替えて実行（TC-09: python3 不在の degrade-to-base）
_t80_run_path() {
  _t80_rc=0
  PATH="$5" PLANGATE_HOOK_TASK="$3" PLANGATE_SKIP_REASON="" PLANGATE_HOOK_STRICT="$4" \
    PLANGATE_HOOK_FILE="$2" PLANGATE_BYPASS_HOOK="0" \
    sh "$1" </dev/null > "$_T80_TMP/out.txt" 2>&1 || _t80_rc=$?
  _t80_out=$(cat "$_T80_TMP/out.txt" 2>/dev/null || true)
}

# 判定は rc と一意 reason トークンの **対** で行う（README「PASS 判定の書き方」P-1）。
_t80_expect() {
  if [ "$_t80_rc" = "$2" ] && printf '%s' "$_t80_out" | grep -q -- "$3"; then
    t80_pass "$1 (rc=$2 / $3)"
    return 0
  fi
  t80_fail "$1: rc=$_t80_rc (want $2) token='$3' out=[$(printf '%s' "$_t80_out" | head -1)]"
  return 1
}

# 判定のみ（pass/fail カウンタを動かさない）。変異注入用。
_t80_holds() {
  [ "$_t80_rc" = "$1" ] && printf '%s' "$_t80_out" | grep -q -- "$2"
}

# ── patch 抽出（marker 基準）──────────────────────────────────────
_T80_PATCH="$_T80_TMP/1234.patch"
sed -n '/^<!-- PG-PATCH-BEGIN -->$/,/^<!-- PG-PATCH-END -->$/p' "$_T80_REPORT" \
  | sed -e '1d' -e '$d' | sed -e '1d' -e '$d' > "$_T80_PATCH" || true

if [ -s "$_T80_PATCH" ] && grep -q '^--- a/scripts/hooks/check-plan-hash.sh$' "$_T80_PATCH"; then
  t80_pass "TC-00a: patch block extracted from report (marker-anchored, non-empty)"
else
  t80_fail "TC-00a: patch block extraction failed ($_T80_REPORT)"
fi

# ── 実 hook の適用状態を測る ──────────────────────────────────────
# NOTE: `grep -q ... && var=1` と書くと **grep が外れた行が文の rc=1 になり**、
# harness（run-tests.sh の set -e）ではスイートごと落ちる。if/fi で受ける。
_T80_REAL_PATCHED=0
if grep -q "$_T80_MARK" "$_T80_HOOK_SRC"; then
  _T80_REAL_PATCHED=1
fi
_T80_FLAG_PRESENT=0
if [ -f "$_T80_FLAG" ]; then
  _T80_FLAG_PRESENT=1
fi

if [ -n "${PG_T80_EXPECT:-}" ]; then
  _T80_EXPECT="$PG_T80_EXPECT"
elif [ "$_T80_FLAG_PRESENT" = "1" ]; then
  _T80_EXPECT=gap
else
  _T80_EXPECT=fixed
fi

# TC-00b: stale 宣言の検出（flag が残っているのに実装は fixed）
if [ "$_T80_FLAG_PRESENT" = "1" ] && [ "$_T80_REAL_PATCHED" = "1" ]; then
  t80_fail "TC-00b: stale gap flag — patch は適用済みなのに $_T80_FLAG が残っている（削除すること）"
else
  t80_pass "TC-00b: gap flag と実装状態が整合 (flag=$_T80_FLAG_PRESENT patched=$_T80_REAL_PATCHED expect=$_T80_EXPECT)"
fi

# TC-00c: patch をサンドボックス（repo 外 mktemp）で適用し、patched hook を得る
_T80_STAGE="$_T80_TMP/stage"
mkdir -p "$_T80_STAGE/scripts/hooks"
cp "$_T80_HOOK_SRC" "$_T80_STAGE/scripts/hooks/check-plan-hash.sh"
_T80_APPLY_RC=0
if [ "$_T80_REAL_PATCHED" = "1" ]; then
  t80_pass "TC-00c: real hook already patched — sandbox copy is fixed as-is"
else
  (cd "$_T80_STAGE" && git apply "$_T80_PATCH") >/dev/null 2>&1 || _T80_APPLY_RC=$?
  if [ "$_T80_APPLY_RC" = "0" ] && grep -q "$_T80_MARK" "$_T80_STAGE/scripts/hooks/check-plan-hash.sh"; then
    t80_pass "TC-00c: patch applies to the sandbox copy and installs the $_T80_MARK branch"
  else
    t80_fail "TC-00c: patch failed to apply to sandbox copy (rc=$_T80_APPLY_RC)"
  fi
fi
_T80_PSRC="$_T80_STAGE/scripts/hooks/check-plan-hash.sh"

# TC-00d: patch 適用後の hook が sh -n を通る
if sh -n "$_T80_PSRC" 2>/dev/null; then
  t80_pass "TC-00d: patched hook passes sh -n"
else
  t80_fail "TC-00d: patched hook has a syntax error"
fi

# ── patched fixture ───────────────────────────────────────────────
_T80_P="$_T80_TMP/patched"
_t80_mkfixture "$_T80_P" "$_T80_PSRC"
_T80_PHOOK="$_T80_P/root/scripts/hooks/check-plan-hash.sh"
_T80_PROOT="$_T80_P/root"

printf '  -- patched hook (expect: fixed) --\n'

# TC-01: repo 外は SKIP（是正の本体）
_t80_run "$_T80_PHOOK" "$_T80_P/outside/scratch.html" "" "0"
_t80_expect "TC-01a: repo 外 (outside/scratch.html) → OUTSIDE_REPO_SKIP" 0 "$_T80_MARK" || true
_t80_run "$_T80_PHOOK" "$_T80_P/home/x.html" "" "0"
_t80_expect "TC-01b: repo 外 (\$HOME 相当) → OUTSIDE_REPO_SKIP" 0 "$_T80_MARK" || true
_t80_run "$_T80_PHOOK" "$_T80_P/outside/newdir/nonexist/x.html" "" "0"
_t80_expect "TC-01c: repo 外・未存在 dir → OUTSIDE_REPO_SKIP" 0 "$_T80_MARK" || true
_t80_run "$_T80_PHOOK" "$_T80_P/outside/scratch.html" "" "1"
_t80_expect "TC-01d: repo 外 + STRICT=1 → 従来どおり block" 2 "Usage:" || true
_t80_run "$_T80_PHOOK" "$_T80_P/outside/scratch.html" "TASK-9999" "0"
_t80_expect "TC-01e: repo 外 + TASK 文脈 → plan_hash 経路（退行なし）" 0 "c3.json not found" || true
_t80_run "$_T80_PHOOK" "$_T80_P/outside/CLAUDE.md" "" "0"
_t80_expect "TC-01f: repo 外 .md → OUTSIDE_REPO_SKIP" 0 "$_T80_MARK" || true

# TC-02: repo 内は 1 行も緩めない
_t80_run "$_T80_PHOOK" "$_T80_PROOT/bin/plangate" "" "0"
_t80_expect "TC-02a-1: repo 内 HO (bin/plangate) → block" 2 "HARDENING_OVERRIDE" || true
_t80_run "$_T80_PHOOK" "$_T80_PROOT/CLAUDE.md" "" "0"
_t80_expect "TC-02a-2: repo 内 HO (CLAUDE.md) → block" 2 "HARDENING_OVERRIDE" || true
_t80_run "$_T80_PHOOK" "$_T80_PROOT/scripts/foo.py" "" "0"
_t80_expect "TC-02b: repo 内 .py → SKIP 拒否" 2 "SKIP 拒否" || true
_t80_run "$_T80_PHOOK" "docs/working/_reports/x.md" "" "0"
_t80_expect "TC-02c: repo 内相対 .md → DOC_LIGHT_SKIP" 0 "DOC_LIGHT_SKIP" || true
_t80_run "$_T80_PHOOK" "$_T80_PROOT/docs/working/TASK-9999/plan.md" "" "0"
_t80_expect "TC-02d: repo 内 plan.md / no-task → block" 2 "plan.md edited without TASK context" || true

# TC-03: symlink 経由の逆方向迂回（union で強化される側）
_t80_run "$_T80_PHOOK" "$_T80_P/outside/link/bin/plangate" "" "0"
_t80_expect "TC-03a: dir symlink → repo 内 HO → block" 2 "HARDENING_OVERRIDE" || true
_t80_run "$_T80_PHOOK" "$_T80_P/outside/x.md" "" "0"
_t80_expect "TC-03b: file symlink → CLAUDE.md → block" 2 "HARDENING_OVERRIDE" || true
_t80_run "$_T80_PHOOK" "$_T80_P/outside/y.md" "" "0"
_t80_expect "TC-03c: file symlink → plan.md → block" 2 "resolves to" || true

# TC-04: 字句 fail-closed（#1101）を緩めない
_t80_run "$_T80_PHOOK" "$_T80_P/linkdir/../root/CLAUDE.md" "" "0"
_t80_expect "TC-04a: 字句 repo 内 / 物理 repo 外 → SKIP しない（AND 条件）" 2 "HARDENING_OVERRIDE" || true
_t80_run "$_T80_PHOOK" "$_T80_PROOT/nonexist/../CLAUDE.md" "" "0"
_t80_expect "TC-04b: 未存在 dir 経由の .. → #1101 の字句判定で block" 2 "HARDENING_OVERRIDE" || true
_t80_run "$_T80_PHOOK" "$_T80_P/outside/newdir/../x.html" "" "0"
_t80_expect "TC-04c: 未存在 dir 経由の .. (UNSURE) → 縮退（従来判定）" 2 "SKIP 拒否" || true

# TC-05: worktree（#1277 を解決も悪化もさせない）
_t80_run "$_T80_PHOOK" "$_T80_PROOT/.claude/worktrees/x/CLAUDE.md" "" "0"
_t80_expect "TC-05a: root 配下 worktree HO .md → #1277 のまま (DOC_LIGHT_SKIP)" 0 "DOC_LIGHT_SKIP" || true
_t80_run "$_T80_PHOOK" "$_T80_P/wt-ext/bin/plangate" "" "0"
_t80_expect "TC-05b: root 外 linked worktree → WORKTREE 縮退（SKIP しない）" 2 "SKIP 拒否" || true

# TC-06: (ii) と (ii-b) の 9 カテゴリ行がバイト一致（positive control 付き）
_t80_cmp_cases() {
  PG_T80_FILE="$1" python3 - <<'PYCMP' 2>/dev/null || true
import os, sys
lines = open(os.environ["PG_T80_FILE"], encoding="utf-8").read().splitlines()
def block(head):
    # header 行の次から、strip して "esac" になる行の直前までを取り出す。
    # (ii) は 2 space / (ii-b) は if の内側で 4 space インデントなので、
    # 比較はインデントを外した行単位で行う（パターン本体はバイト一致を要求）。
    for i, ln in enumerate(lines):
        if ln.strip() == head:
            out = []
            for ln2 in lines[i + 1:]:
                if ln2.strip() == "esac":
                    return out
                if ln2.strip():
                    out.append(ln2.strip())
            break
    return None
a = block('case "$_ho_key" in')
b = block('case "$_phys_key" in')
if a is None or b is None or not a:
    print("MISSING"); sys.exit(0)
print("MATCH" if a == b else "DIFF")
PYCMP
}
_T80_CMP=$(_t80_cmp_cases "$_T80_PHOOK")
# positive control: 片方の 9 行を 1 文字変えた複製で検査器が DIFF を返すこと
_T80_CMPMUT="$_T80_TMP/cmp-mutant.sh"
PG_T80_IN="$_T80_PHOOK" PG_T80_OUT="$_T80_CMPMUT" python3 - <<'PYCMPM' 2>/dev/null || true
import os
s = open(os.environ["PG_T80_IN"], encoding="utf-8").read()
i = s.index('case "$_phys_key" in')
head, tail = s[:i], s[i:]
tail = tail.replace("bin/plangate) _override=1 ;;", "bin/plangate2) _override=1 ;;", 1)
open(os.environ["PG_T80_OUT"], "w", encoding="utf-8").write(head + tail)
PYCMPM
_T80_CMP_PC=$(_t80_cmp_cases "$_T80_CMPMUT")
if [ "$_T80_CMP_PC" != "DIFF" ]; then
  t80_fail "TC-06: positive control failed — 9 カテゴリを 1 行変えた複製を検査器が検出できない (got=$_T80_CMP_PC)"
elif [ "$_T80_CMP" = "MATCH" ]; then
  t80_pass "TC-06: (ii) と (ii-b) の 9 カテゴリ行が一致（インデント除去後バイト一致 / positive control OK）"
else
  t80_fail "TC-06: 9 カテゴリ行が (ii) と (ii-b) で一致しない (got=$_T80_CMP)"
fi

# TC-07: OUTSIDE_REPO_SKIP は skip-decision-log.jsonl を汚さない（positive control 付き）
_T80_S7="$_T80_TMP/sb7"
_t80_mkfixture "$_T80_S7" "$_T80_PSRC"
_T80_S7HOOK="$_T80_S7/root/scripts/hooks/check-plan-hash.sh"
_T80_S7LOG="$_T80_S7/root/docs/working/_audit/skip-decision-log.jsonl"
_t80_dlog_lines() {
  if [ -f "$1" ]; then wc -l < "$1" | tr -d ' '; else printf '0'; fi
}
_T80_L0=$(_t80_dlog_lines "$_T80_S7LOG")
_t80_run "$_T80_S7HOOK" "$_T80_S7/outside/scratch.html" "" "0"
_t80_run "$_T80_S7HOOK" "$_T80_S7/home/x.html" "" "0"
_t80_run "$_T80_S7HOOK" "$_T80_S7/outside/newdir/nonexist/x.html" "" "0"
_t80_run "$_T80_S7HOOK" "$_T80_S7/outside/CLAUDE.md" "" "0"
_T80_L1=$(_t80_dlog_lines "$_T80_S7LOG")
# positive control: 記録する経路（doc-light）を 1 回通し、カウンタが増分を検出する
_t80_run "$_T80_S7HOOK" "docs/working/_reports/x.md" "" "0"
_T80_L2=$(_t80_dlog_lines "$_T80_S7LOG")
if [ "$_T80_L2" -le "$_T80_L1" ]; then
  t80_fail "TC-07: positive control failed — DOC_LIGHT_SKIP を通しても行数が増えない（検査器が追記を検出できない: $_T80_L1 -> $_T80_L2）"
elif [ "$_T80_L1" = "$_T80_L0" ]; then
  t80_pass "TC-07: OUTSIDE_REPO_SKIP 4 経路で skip-decision-log.jsonl は不変（$_T80_L0 行 / positive control OK）"
else
  t80_fail "TC-07: OUTSIDE_REPO_SKIP が skip-decision-log.jsonl を汚した（$_T80_L0 -> $_T80_L1）"
fi

# ── TC-08: 変異注入（検出力の実証）───────────────────────────────
printf '  -- mutation testing (detection power) --\n'

_t80_mutate() {
  # $1 = mutant id / $2 = 出力 hook path
  cp "$_T80_PSRC" "$2"
  MUT="$1" TGT="$2" python3 - <<'PYM'
import os, sys
mut = os.environ["MUT"]; tgt = os.environ["TGT"]
s = open(tgt, encoding="utf-8").read()
if mut == "M1":
    i = s.index("# ===== (i-c) repo containment")
    j = s.index("# (ii) Hardening Override 物理先頭判定")
    s = s[:i] + s[j:]
elif mut == "M-OUT":
    s = s.replace('case "$_pg_contain" in',
                  '_pg_contain="OUTSIDE|forced"\ncase "$_pg_contain" in', 1)
elif mut == "M-IN":
    s = s.replace('case "$_pg_contain" in',
                  '_pg_contain="INSIDE|forced"\ncase "$_pg_contain" in', 1)
elif mut == "M3":
    s = s.replace('[ "$_pg_lex_outside" = "1" ] && [ -z "$task_id" ] &&',
                  '[ "$_pg_lex_outside" = "1" ] &&', 1)
elif mut == "M4":
    i = s.index("# (ii-b) #1234:")
    j = s.index('if [ "$_override" = "1" ]; then')
    s = s[:i] + s[j:]
elif mut == "M5":
    i = s.index("  # #1234: symlink 経由で repo 内 plan.md")
    j = s.index('  if [ "${PLANGATE_HOOK_STRICT:-0}" = "1" ]; then')
    s = s[:i] + s[j:]
elif mut == "M-LEX":
    s = s.replace('[ "$_pg_lex_outside" = "1" ] && ', '', 1)
elif mut == "M-WT":
    s = s.replace("if root_common is not None and common_dir(d) == root_common:",
                  "if False:", 1)
else:
    sys.exit(9)
open(tgt, "w", encoding="utf-8").write(s)
PYM
}

# $1=mutant $2=TC ラベル $3=対象パス（fixture base を @BASE@ / @ROOT@ で表す）
# $4=TASK $5=STRICT $6=want_rc $7=want_token
_t80_mut_case() {
  _t80_mdir="$_T80_TMP/mut-$1"
  _t80_mhook="$_T80_TMP/mut-$1.sh"
  if ! _t80_mutate "$1" "$_t80_mhook"; then
    t80_fail "TC-08/$1: mutation could not be applied（変異が当たっていない = 検出力を主張できない）"
    return 0
  fi
  if cmp -s "$_T80_PSRC" "$_t80_mhook"; then
    t80_fail "TC-08/$1: mutant is byte-identical to the patched hook（変異が当たっていない）"
    return 0
  fi
  _t80_mkfixture "$_t80_mdir" "$_t80_mhook"
  _t80_mtarget=$(printf '%s' "$3" | sed -e "s#@ROOT@#$_t80_mdir/root#g" -e "s#@BASE@#$_t80_mdir#g")
  _t80_run "$_t80_mdir/root/scripts/hooks/check-plan-hash.sh" "$_t80_mtarget" "$4" "$5"
  if _t80_holds "$6" "$7"; then
    t80_fail "TC-08/$1: 変異したのに $2 が依然 PASS する（この TC は空振り）"
  else
    t80_pass "TC-08/$1: 変異により $2 が FAIL する（検出力あり / rc=${_t80_rc}）"
  fi
}

_t80_mut_case M-OUT "TC-03a" "@BASE@/outside/link/bin/plangate" "" "0" 2 "HARDENING_OVERRIDE"
_t80_mut_case M-IN  "TC-01a" "@BASE@/outside/scratch.html" "" "0" 0 "$_T80_MARK"
_t80_mut_case M1    "TC-01a" "@BASE@/outside/scratch.html" "" "0" 0 "$_T80_MARK"
_t80_mut_case M3    "TC-01e" "@BASE@/outside/scratch.html" "TASK-9999" "0" 0 "c3.json not found"
_t80_mut_case M4    "TC-03b" "@BASE@/outside/x.md" "" "0" 2 "HARDENING_OVERRIDE"
_t80_mut_case M5    "TC-03c" "@BASE@/outside/y.md" "" "0" 2 "resolves to"
_t80_mut_case M-LEX "TC-04a" "@BASE@/linkdir/../root/CLAUDE.md" "" "0" 2 "HARDENING_OVERRIDE"
_t80_mut_case M-WT  "TC-05b" "@BASE@/wt-ext/bin/plangate" "" "0" 2 "SKIP 拒否"

# ── TC-09: python3 不在（degrade-to-base）──────────────────────────
_T80_PBIN="$_T80_TMP/nopy-bin"
mkdir -p "$_T80_PBIN"
_T80_PBIN_OK=1
for _t80_cmd in sh env sed tr awk head cut cat date mkdir dirname basename grep wc cp rm uname; do
  _t80_p=$(command -v "$_t80_cmd" 2>/dev/null || true)
  if [ -n "$_t80_p" ]; then
    ln -s "$_t80_p" "$_T80_PBIN/$_t80_cmd" 2>/dev/null || true
  else
    _T80_PBIN_OK=0
  fi
done
for _t80_cmd in jq shasum sha256sum; do
  _t80_p=$(command -v "$_t80_cmd" 2>/dev/null || true)
  [ -n "$_t80_p" ] && ln -s "$_t80_p" "$_T80_PBIN/$_t80_cmd" 2>/dev/null || true
done
# python3 が本当に見えないことは **新しいシェル**で確かめる。呼び出し元の
# `command -v` は自身のハッシュ表を参照するため、PATH を差し替えても既に解決済みの
# python3 を返す（実測で踏んだ。ここを誤ると TC-09 が黙って SKIP になる）。
if [ "$_T80_PBIN_OK" = "1" ] && ! env -i PATH="$_T80_PBIN" sh -c 'command -v python3' >/dev/null 2>&1; then
  _T80_S9="$_T80_TMP/sb9"
  _t80_mkfixture "$_T80_S9" "$_T80_PSRC"
  _T80_S9HOOK="$_T80_S9/root/scripts/hooks/check-plan-hash.sh"
  _t80_run_path "$_T80_S9HOOK" "$_T80_S9/outside/scratch.html" "" "0" "$_T80_PBIN"
  _t80_expect "TC-09a: python3 不在 → OUTSIDE_REPO_SKIP は発火せず従来判定（degrade）" 2 "SKIP 拒否" || true
  _t80_run_path "$_T80_S9HOOK" "$_T80_S9/outside/x.md" "" "0" "$_T80_PBIN"
  _t80_expect "TC-09b: python3 不在 → symlink union も発火せず before と同じ" 0 "DOC_LIGHT_SKIP" || true
else
  printf '  [SKIP] TC-09: minimal PATH の構築に失敗（必須コマンド不足 / python3 が残存）\n'
fi

# ── TC-R*: 実 hook の実測（期待は flag に従う）──────────────────────
printf '  -- real hook (expect: %s) --\n' "$_T80_EXPECT"
_T80_R="$_T80_TMP/real"
_t80_mkfixture "$_T80_R" "$_T80_HOOK_SRC"
_T80_RHOOK="$_T80_R/root/scripts/hooks/check-plan-hash.sh"

_t80_run "$_T80_RHOOK" "$_T80_R/outside/scratch.html" "" "0"
if [ "$_T80_EXPECT" = "fixed" ]; then
  _t80_expect "TC-R01: 実 hook / repo 外 → OUTSIDE_REPO_SKIP" 0 "$_T80_MARK" || true
else
  _t80_expect "TC-R01(gap): 実 hook / repo 外 → 現状は SKIP 拒否 (#1234 未適用)" 2 "SKIP 拒否" || true
fi

_t80_run "$_T80_RHOOK" "$_T80_R/outside/x.md" "" "0"
if [ "$_T80_EXPECT" = "fixed" ]; then
  _t80_expect "TC-R02: 実 hook / symlink → CLAUDE.md → block" 2 "HARDENING_OVERRIDE" || true
else
  _t80_expect "TC-R02(gap): 実 hook / symlink → CLAUDE.md → 現状は false negative" 0 "DOC_LIGHT_SKIP" || true
fi

# repo 内の対照は gap / fixed 不問で常に同じでなければならない
_t80_run "$_T80_RHOOK" "$_T80_R/root/bin/plangate" "" "0"
_t80_expect "TC-R03: 実 hook / repo 内 HO → block（対照 / mode 不問）" 2 "HARDENING_OVERRIDE" || true
_t80_run "$_T80_RHOOK" "$_T80_R/root/docs/working/TASK-9999/plan.md" "" "0"
_t80_expect "TC-R04: 実 hook / repo 内 plan.md → block（対照 / mode 不問）" 2 "plan.md edited without TASK context" || true

# ── 後片付け（trap は使わない / README 規約 1・2）────────────────────
rm -rf "$_T80_TMP"
if [ -e "$_T80_TMP" ]; then
  t80_fail "TC-10: sandbox cleanup failed: $_T80_TMP"
else
  t80_pass "TC-10: sandbox removed (no residue outside mktemp)"
fi

fi

pg_extra_contract_finalize
