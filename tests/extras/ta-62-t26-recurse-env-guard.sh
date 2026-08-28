# tests/extras/ta-62-t26-recurse-env-guard.sh
# PG_EXTRA_CAPABILITY: standalone-capable
# Sourced by tests/run-tests.sh — uses $pass / $fail counters
# TASK-1036 (#1036): PG_T26_NO_RECURSE の呼び出し元 env 漏れ回帰テスト。
#
# ta-26 の再帰防止シグナル PG_T26_NO_RECURSE が呼び出し元 env から漏れた場合、
# harness 経路（run-tests.sh から source）では ta-26 の harness 分岐が unset して
# 無害化することを検証する（漏れると ta-26 の 17 TC が黙って [SKIP] で消える）。
#   TC-D: 動的同値照合 — ミニ harness ドライバで ta-26 を leak/clean の 2 回
#         source し、出力の diff 完全一致 + leak 側の再帰防止 [SKIP] 0 +
#         clean 側 [PASS] >= 1（非空下限。絶対件数ではない）を assert
#   TC-S: 静的配置検査 — unset が ta-26 の harness 分岐（else 節）にのみ存在し、
#         preamble / standalone 分岐（案 (c) 型）にも run-tests.sh の unset 集合
#         （案 (a) 型 = TC-33 波及）にも存在しないことを grep で固定。加えて
#         run-tests.sh が PG_HARNESS_SOURCED を export していないこと（ta-26
#         harness 分岐の前提）を固定する

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
pg_extra_contract_init ta-62-t26-recurse-env-guard standalone-capable

# ta-26 TC-33（静的検査 / README 規約 8）準拠: FIXTURES_DIR:- を含む extras は
# standalone 経路で runner と同一の 7 env unset を自ファイル内に持つ必要がある。
# helper init が既に unset 済みのため機能的には冪等（静的包含要件のための明示行）。
if pg_extra_contract_is_standalone; then
  unset PLANGATE_SKIP_REASON PLANGATE_HOOK_TASK PLANGATE_HOOK_FILE PLANGATE_BYPASS_HOOK PLANGATE_HOOK_STRICT PG_HARNESS_SOURCED PLANGATE_ALLOW_MASS_DELETE 2>/dev/null || true
fi

printf '\n=== TA-62: t26 recurse env guard (#1036) ===\n'

t62_pass() { pass=$((pass + 1)); printf '  [PASS] %s\n' "$1"; }
t62_fail() { fail=$((fail + 1)); printf '  [FAIL] %s\n' "$1" >&2; }

_T62_DIR="$_pg_extra_dir"
_T62_ROOT="$(CDPATH= cd -- "$_T62_DIR/../.." && pwd)"
_T62_TA26="$_T62_DIR/ta-26-plugin-sync.sh"
_T62_RUNNER="$_T62_ROOT/tests/run-tests.sh"
_T62_FIXTURES="$_T62_ROOT/tests/fixtures"

# per-run timeout (ta-61 R-026 と同型): timeout(1) on CI, perl alarm fallback on macOS
_T62_TIMEOUT=180
if command -v timeout >/dev/null 2>&1; then
  _t62_to() { timeout "$_T62_TIMEOUT" "$@"; }
else
  _t62_to() { perl -e 'alarm shift; exec @ARGV' "$_T62_TIMEOUT" "$@"; }
fi

# ---------------------------------------------------------------------------
# TC-S: 静的配置検査（AC-2 / AC-4。案 (c)・案 (a) 混入の予防線）
#   (1) ta-26 の harness 分岐（PG_T26_STANDALONE=0 の else 節ブロック）に
#       `unset PG_T26_NO_RECURSE` が存在する
#   (2) 同 unset がそのブロックの外（preamble 無条件経路 / standalone 分岐）に
#       存在しない — 案 (c) 型は TC-13 の子のガードを破壊し孫 spawn 再入ループ
#   (3) run-tests.sh の unset 集合（行継続を結合して走査）に PG_T26_NO_RECURSE が
#       混入していない — 案 (a) 型は TC-33 の包含検査で全 extras に波及する
#   (4) run-tests.sh が PG_HARNESS_SOURCED を export していない — export すると
#       TC-13 の子（FIXTURES_DIR 明示 + PG_T26_NO_RECURSE=1 前置）が ta-26 の
#       harness 分岐へ落ち、自らガードを unset して TC-13 を再実行 → 孫を同条件
#       で spawn する無限再帰（fork bomb）になる。ta-26 の unset 配置は
#       「PG_HARNESS_SOURCED は非 export」を前提としており、その前提をここで固定
#       する（ta-26 TC-30 は README 文言の存在検査のみで実装は見ていない）
#
# 注意: (1)/(2) の grep は行頭アンカー付き（^[[:space:]]*unset[[:space:]]+…）。
# アンカーなしだと ta-26 の禁止理由コメントに文字列が現れるだけで (1) が成立し、
# 実コード行の削除（M-1 型変異）を取り逃がす。(1)(2) は同一式で相対比較する。
if [ -f "$_T62_TA26" ] && [ -f "$_T62_RUNNER" ]; then
  # else 節ブロック = PG_T26_STANDALONE=0 の行から直近のトップレベル fi まで
  _t62_else_blk=$(awk '/PG_T26_STANDALONE=0/{f=1} f{print} f&&/^fi$/{exit}' "$_T62_TA26")
  _t62_re_unset='^[[:space:]]*unset[[:space:]]+PG_T26_NO_RECURSE'
  _t62_total=$(grep -cE "$_t62_re_unset" "$_T62_TA26" 2>/dev/null || true)
  _t62_inblk=$(printf '%s\n' "$_t62_else_blk" | grep -cE "$_t62_re_unset" 2>/dev/null || true)
  _t62_s1=0
  [ "${_t62_inblk:-0}" -ge 1 ] && _t62_s1=1
  _t62_s2=0
  [ "$_t62_total" = "$_t62_inblk" ] && _t62_s2=1
  # run-tests.sh: 行継続（末尾 \）を 1 行へ結合してから unset 行の env 名を走査
  # （ta-26 TC-33 と同じ正規化。件数ハードコードなし）
  _t62_runner_unsets=$(awk '
    { if (cont) { buf = buf " " $0 } else { buf = $0 } }
    buf ~ /\\$/ { sub(/\\$/, "", buf); cont = 1; next }
    { cont = 0; print buf }
    END { if (cont) print buf }
  ' "$_T62_RUNNER" 2>/dev/null \
    | grep -E '^[[:space:]]*unset ' \
    | sed -e 's/[[:space:]]*2>\/dev\/null.*$//' -e 's/[[:space:]]*||.*$//' \
          -e 's/^[[:space:]]*unset[[:space:]]*//')
  _t62_s3=1
  case " $(printf '%s' "$_t62_runner_unsets" | tr '\n' ' ') " in
    *" PG_T26_NO_RECURSE "*) _t62_s3=0 ;;
  esac
  # (4) runner が PG_HARNESS_SOURCED を export していない（前提の静的固定）
  # 検査形: (a) export 行に PG_HARNESS_SOURCED が含まれる（複数名 export
  # `export FIXTURES_DIR PG_HARNESS_SOURCED` を含む）/ (b) `set -a`（allexport）
  # による暗黙 export / (c) `PG_HARNESS_SOURCED=1; export …` の同一行結合形。
  # 1 名目位置しか見ない grep は (a) の複数名形と (b) を survivor にする。
  # コメント行（^ の直後が #）は除外する。
  _t62_s4=1
  awk '/^[[:space:]]*#/ {next}
       /^[[:space:]]*export[[:space:]]/ && /PG_HARNESS_SOURCED/ {f=1}
       /^[[:space:]]*set[[:space:]]+-[a-zA-Z]*a([[:space:]]|$)/ {f=1}
       /PG_HARNESS_SOURCED[[:space:]]*=[^;]*;[[:space:]]*export/ {f=1}
       END{exit f?0:1}' "$_T62_RUNNER" && _t62_s4=0
  if [ "$_t62_s1" = "1" ] && [ "$_t62_s2" = "1" ] && [ "$_t62_s3" = "1" ] && [ "$_t62_s4" = "1" ]; then
    t62_pass "TC-S unset PG_T26_NO_RECURSE は ta-26 harness 分岐にのみ存在（無条件経路 0 / runner unset 集合に混入なし / runner は PG_HARNESS_SOURCED 非 export = export 行・set -a・;export 形を検査）"
  else
    t62_fail "TC-S 配置検査不成立 (harness分岐に存在=$_t62_s1 期待1 / ブロック外0件=$_t62_s2 期待1 / runner非混入=$_t62_s3 期待1 / runner非export=$_t62_s4 期待1): $_T62_TA26 / $_T62_RUNNER"
  fi
else
  t62_fail "TC-S 検査対象が不在: $_T62_TA26 / $_T62_RUNNER"
fi

# ---------------------------------------------------------------------------
# TC-D: 動的同値照合（AC-1 / AC-2 の主担体）
# tmp のミニ harness ドライバ（run-tests.sh の source 環境の最小再現 =
# pass/fail カウンタ + register_cleanup + 実 FIXTURES_DIR + 非 export の
# PG_HARNESS_SOURCED=1 + runner 冒頭と同一の 7 env unset）で ta-26 を source し、
#   (1) PG_T26_NO_RECURSE=1 を export した leak 実行
#   (2) env なしの clean 実行
# の出力を diff 完全一致で照合する。件数のハードコードなし・ta-26 の TC 増減に
# 自動追従。leak 側に再帰防止起因の [SKIP] が 1 行でも出れば漏れが素通りしている。
# 注意: ドライバは PG_T26_NO_RECURSE を unset しない（それは検証対象の穴そのもの。
# 無害化の責務は ta-26 harness 分岐側にある）。
_t62_tmp=$(mktemp -d)
register_cleanup "$_t62_tmp"
cat > "$_t62_tmp/driver.sh" <<'T62_DRIVER'
#!/bin/sh
# mini harness driver: tests/run-tests.sh の source 環境を最小再現する
set -eu
# runner 冒頭と同一の 7 env 無害化（PG_T26_NO_RECURSE は意図的に含めない）
unset PLANGATE_SKIP_REASON PLANGATE_HOOK_TASK PLANGATE_HOOK_FILE PLANGATE_BYPASS_HOOK PLANGATE_HOOK_STRICT PG_HARNESS_SOURCED PLANGATE_ALLOW_MASS_DELETE 2>/dev/null || true
FIXTURES_DIR="$1"
_t62d_target="$2"
PG_HARNESS_SOURCED=1
pass=0
fail=0
_t62d_cleanup=""
register_cleanup() {
  for _t62d_p in "$@"; do
    [ -n "$_t62d_p" ] || continue
    _t62d_cleanup="${_t62d_cleanup}${_t62d_p}
"
  done
}
. "$_t62d_target"
# runner 末尾の drain 相当（登録パスのみ削除）
printf '%s' "$_t62d_cleanup" | while IFS= read -r _t62d_p; do
  [ -n "$_t62d_p" ] || continue
  rm -rf "$_t62d_p" 2>/dev/null || true
done
printf 'DRIVER-SUMMARY: pass=%s fail=%s\n' "$pass" "$fail"
T62_DRIVER

if [ -f "$_T62_TA26" ] && [ -d "$_T62_FIXTURES" ]; then
  _t62_rc_leak=0
  ( PG_T26_NO_RECURSE=1; export PG_T26_NO_RECURSE
    _t62_to sh "$_t62_tmp/driver.sh" "$_T62_FIXTURES" "$_T62_TA26" </dev/null \
      >"$_t62_tmp/leak.out" 2>&1 ) || _t62_rc_leak=$?
  _t62_rc_clean=0
  ( unset PG_T26_NO_RECURSE 2>/dev/null || true
    _t62_to sh "$_t62_tmp/driver.sh" "$_T62_FIXTURES" "$_T62_TA26" </dev/null \
      >"$_t62_tmp/clean.out" 2>&1 ) || _t62_rc_clean=$?
  _t62_skips=$(grep -c '再帰防止' "$_t62_tmp/leak.out" 2>/dev/null || true)
  _t62_passes=$(grep -c '\[PASS\]' "$_t62_tmp/clean.out" 2>/dev/null || true)
  _t62_diff_ok=0
  diff "$_t62_tmp/leak.out" "$_t62_tmp/clean.out" >/dev/null 2>&1 && _t62_diff_ok=1
  # per-run timeout の切り分け（#1062）: timeout(1)=124 / perl alarm=142。
  # 打ち切られた側の出力は途中で切れるため diff は必ず不一致になり、素の
  # 「同値照合不成立」メッセージは「ta-26 の出力が leak/clean で食い違った」
  # という誤った診断を出す（#1062 実測: rc_clean=142 の回で発生）。
  # 検出力は変えない — timeout は従来どおり FAIL（SKIP にしない）。
  _t62_timedout=0
  case " $_t62_rc_leak $_t62_rc_clean " in
    *" 124 "*|*" 142 "*) _t62_timedout=1 ;;
  esac
  if [ "$_t62_timedout" = "1" ]; then
    t62_fail "TC-D driver run TIMED OUT (>${_T62_TIMEOUT}s / rc_leak=$_t62_rc_leak rc_clean=$_t62_rc_clean) — 同値照合は未実施。FAIL 扱い（SKIP にしない）。ta-26 1 本の所要が per-run 上限に達している"
  elif [ "$_t62_rc_leak" = "0" ] && [ "$_t62_rc_clean" = "0" ] \
    && [ "$_t62_diff_ok" = "1" ] && [ "$_t62_skips" = "0" ] && [ "$_t62_passes" -ge 1 ]; then
    t62_pass "TC-D leak/clean の harness 実行出力が完全一致（再帰防止 [SKIP] 0・非空実行）"
  else
    _t62_diff_head=$(diff "$_t62_tmp/leak.out" "$_t62_tmp/clean.out" 2>&1 | head -10 | tr '\n' ';')
    t62_fail "TC-D 同値照合不成立 (rc_leak=$_t62_rc_leak rc_clean=$_t62_rc_clean 期待0/0 / diff一致=$_t62_diff_ok 期待1 / leak側再帰防止SKIP=$_t62_skips 期待0 / clean側PASS行=$_t62_passes 期待>=1): $_t62_diff_head"
  fi
else
  t62_fail "TC-D 前提不在: $_T62_TA26 / $_T62_FIXTURES"
fi

pg_extra_contract_finalize
