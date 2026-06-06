# tests/extras/ta-32-real-ssot-pollution.sh
# Sourced by tests/run-tests.sh — uses $pass / $fail counters
# #452: 実 SSoT（AGENTS.md / CLAUDE.md）の AI memory 汚染を回帰チェックする。
#
# ta-29 は guard スクリプトの検出力を fixture で検証する。本テストは
# 「実ファイルが今汚染されていないか」を CI で可視化する回帰チェック。
#
# モード:
#   - 既定（warn-only）: 汚染を検出しても WARN 表示のみでテストスイートを壊さない。
#     #452 の AGENTS.md 汚染除去（HO・Human）完了までの暫定。
#   - STRICT_AGENTS_CHECK=1: 汚染検出を FAIL に昇格。AGENTS.md 除去完了後、
#     CI でこの環境変数を設定すれば再混入を block できる。

printf '\n=== TA-32: real-ssot-pollution (#452) ===\n'

PG_T32_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
PG_T32_SCRIPT="$PG_T32_ROOT/scripts/check-committed-memory-pollution.sh"
PG_T32_STRICT="${STRICT_AGENTS_CHECK:-0}"

t32_pass() { pass=$((pass + 1)); printf '  [PASS] %s\n' "$1"; }
t32_fail() { fail=$((fail + 1)); printf '  [FAIL] %s\n' "$1" >&2; }
t32_warn() { pass=$((pass + 1)); printf '  [WARN] %s\n' "$1"; }

# TC-01: 実 SSoT（既定の AGENTS.md / CLAUDE.md）が AI memory 汚染を含まない
# 汚染検出時は guard の詳細出力（どのファイルのどの行か）を CI ログに残す
# ＝本テストの目的「現状の汚染を可視化」を達成する
_t32_out=$(sh "$PG_T32_SCRIPT" 2>&1)
_t32_rc=$?
if [ "$_t32_rc" = "0" ]; then
  t32_pass "TC-01 実 SSoT に AI memory 汚染なし"
else
  printf '%s\n' "$_t32_out" | sed 's/^/      /'
  if [ "$PG_T32_STRICT" = "1" ]; then
    t32_fail "TC-01 実 SSoT に汚染検出（STRICT）— AGENTS.md 等から <claude-mem-context> ブロックを除去してください（#452）"
  else
    t32_warn "TC-01 実 SSoT に汚染残存（warn-only、#452 の HO 除去待ち）。除去後 STRICT_AGENTS_CHECK=1 で block 化"
  fi
fi
