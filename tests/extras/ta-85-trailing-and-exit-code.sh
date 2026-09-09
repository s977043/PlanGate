# tests/extras/ta-85-trailing-and-exit-code.sh
# PG_EXTRA_CAPABILITY: standalone-capable
# Sourced by tests/run-tests.sh — uses $pass / $fail counters
#
# === TA-85: スクリプト末尾の `&&` リストが終了ステータスを漏らす形の検出 ===
#
# 背景（2026-09-08 の実害）:
#   scripts/install-plangate-skills-to-codex.sh の末尾に
#       [ "$curated_count" -gt 0 ] && printf 'curated_kept_names:\n%s' "$curated_names"
#   を追加したところ、条件が偽のとき `[ ]` の rc=1 がそのままスクリプトの
#   終了ステータスになり、**同期済みで何もすることが無い通常実行が「失敗」を返す**
#   退行が main に入った（#1308 → #1309 で是正）。
#
#   この形は `sh -n` でも `shellcheck` でも警告されない。shellcheck の SC2015 は
#   `A && B || C` を見るが、本ケース（`&&` リストが最終実行文）は対象外。
#
# 検査の設計:
#   最終行だけを見ても捕まらない。実害を出した形は
#       ...
#         [ "$c" -gt 0 ] && printf ...
#       fi                       <- 最終行はこれ
#   であり、`fi` の rc は直前のコマンドから伝播する。したがって
#   **末尾から `fi` / `done` / `esac` / `}` / `;;` をスキップして最初の実行文**を見る。
#
#   偽陽性は allowlist（下記 T85_ALLOW）で受け止める。allowlist は
#   「意図的にその形にしている」という宣言であり、白紙委任ではない
#   （宣言だけ残って実態から消えたら TC-04 が FAIL する）。
#
# 対象は `scripts/` 配下の `*.sh` 全件（再帰）。
# tests/ と fixtures は対象外（fixture は意図的に壊してある）。

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
pg_extra_contract_init ta-85-trailing-and-exit-code standalone-capable

if pg_extra_contract_is_standalone; then
  # standalone: 外部 env 汚染を無害化（tests/extras/README.md「隔離・後始末の規約」8 /
  # ta-26 TC-33 が静的検査する集合と一致させる）
  unset PLANGATE_SKIP_REASON PLANGATE_HOOK_TASK PLANGATE_HOOK_FILE \
    PLANGATE_BYPASS_HOOK PLANGATE_HOOK_STRICT PG_HARNESS_SOURCED \
    PLANGATE_ALLOW_MASS_DELETE 2>/dev/null || true
fi

printf '\n=== TA-85: trailing && exit-code leak ===\n'

# root / fixtures は **両モードで解決できる形**にする。standalone では
# FIXTURES_DIR が未定義のため、extras dir（$_pg_extra_dir）を起点にする
# （ta-83 と同じ方式）。
PG_T85_ROOT="$(CDPATH= cd -- "$_pg_extra_dir/../.." && pwd)"
PG_T85_FIX="$PG_T85_ROOT/tests/fixtures/ta85"

t85_pass() { pass=$((pass + 1)); printf '  [PASS] %s\n' "$1"; }
t85_fail() { fail=$((fail + 1)); printf '  [FAIL] %s\n' "$1" >&2; }

# 意図的に末尾 `&&` を許す資産の宣言。**白紙委任ではない**（同値照合なので、
# 宣言だけ残って実態から消えても TC-04 が FAIL する）。追加するときは理由を必ず書く。
#
#   scripts/gen-codex-agents.sh
#     `--check` モードの判定値として意図的にこの形。
#     `[ "$_updated" -eq 0 ] && [ "$_created" -eq 0 ]` が then 分岐の終端にあり、
#     drift / missing がゼロのときだけ rc=0 を返す仕様（rc が結果そのもの）。
T85_ALLOW="scripts/gen-codex-agents.sh"

# 検査器: スクリプトの終了ステータスを決めうる「最終実行文」を列挙し、
# その中に `&&` リストがあれば 1 を返す（該当行を標準出力に出す）。
#
# 素朴に「末尾から閉じトークンを遡って最初の 1 文」を見る実装では、次の形を
# 取りこぼす（レビュー指摘 C-3。実 repo に `scripts/gen-codex-agents.sh:101` が実在）:
#
#     if [ "$_check" = "1" ]; then
#       printf ...
#       [ "$_updated" -eq 0 ] && [ "$_created" -eq 0 ]   <- then 分岐の終端
#     else
#       printf ...                                        <- ここしか見ていなかった
#     fi
#
# そこで **末尾の構造ブロック内で「次の実行行が閉じトークンである行」= 分岐の終端**
# をすべて候補にする。`}` が最終行のとき（＝関数定義で終わり、実行文が無い）は
# 走査を打ち切る（関数本体を最終実行文と誤認する偽陽性を避ける）。
t85_probe() {
  awk '
    /^[[:space:]]*#/ { next }
    /^[[:space:]]*$/ { next }
    { raw[++n] = $0 }
    END {
      if (n == 0) exit 0

      # 末尾が関数定義の閉じ `}` なら、スクリプトは最終実行文を持たない
      s = raw[n]; gsub(/^[[:space:]]+|[[:space:]]+$/, "", s)
      if (s == "}") exit 0

      # 最終行が閉じトークンでなければ、**それがそのまま最終実行文**。
      # 構造ブロックの中を見に行ってはいけない（`exit 0` で終わるスクリプトの
      # 手前の分岐を拾って偽陽性になる。実測: scripts/check-codex-plugin-status.sh）。
      if (s !~ /^(fi|done|esac|;;)/) {
        if (s ~ /&&/ && s !~ /\|\|/) { print s; exit 1 }
        exit 0
      }

      # ここから先は「最終行が fi / done / esac / ;;」の場合のみ。
      # その構造の**各分岐の終端**が終了ステータスを決めうるので、すべて候補にする。
      start = 1
      for (i = n; i >= 1; i--) {
        if (raw[i] ~ /^(if|case|while|for|until)[[:space:](]/) { start = i; break }
      }

      hit = 0
      for (i = start; i <= n; i++) {
        cur = raw[i]; gsub(/^[[:space:]]+|[[:space:]]+$/, "", cur)
        if (cur ~ /^(fi|done|esac|\}|;;|else|elif)/) continue

        is_terminal = 0
        if (i == n) {
          is_terminal = 1
        } else {
          nx = raw[i+1]; gsub(/^[[:space:]]+|[[:space:]]+$/, "", nx)
          if (nx ~ /^(fi|done|esac|\}|;;|else|elif)/) is_terminal = 1
        }
        if (!is_terminal) continue

        # 行継続で始まる `&&` も拾うため、直前行が `\` 終端なら連結して見る
        line = cur
        if (i > 1) {
          pv = raw[i-1]; gsub(/[[:space:]]+$/, "", pv)
          if (pv ~ /\\$/) { sub(/\\$/, "", pv); line = pv " " cur }
        }
        # `&&` リストは条件が偽のとき非ゼロを返す。`||` で受けていれば漏れない。
        if (line ~ /&&/ && line !~ /\|\|/) { print line; hit = 1 }
      }
      exit (hit ? 1 : 0)
    }
  ' "$1"
}

# --- TC-01: positive control（検査器が実害の形を検出する） ---
_t85_hits=0
for _f in "$PG_T85_FIX/bad-trailing-and.sh" "$PG_T85_FIX/bad-nested-fi.sh" "$PG_T85_FIX/bad-then-branch.sh"; do
  if [ -f "$_f" ]; then
    t85_probe "$_f" >/dev/null 2>&1 || _t85_hits=$((_t85_hits + 1))
  fi
done
if [ "$_t85_hits" -eq 3 ]; then
  t85_pass "TC-01 positive control — bad fixture 3 本とも検出（末尾 / fi 直前 / then 分岐の終端）"
else
  t85_fail "TC-01 positive control 不成立 — 検出 ${_t85_hits} / 3（検査器が空振りしている）"
fi

# --- TC-02: negative control（正しい形を誤検出しない） ---
_t85_fp=0
for _f in "$PG_T85_FIX/good-if-fi.sh" "$PG_T85_FIX/good-func-tail.sh"; do
  t85_probe "$_f" >/dev/null 2>&1 || _t85_fp=$((_t85_fp + 1))
done
if [ "$_t85_fp" -eq 0 ]; then
  t85_pass "TC-02 negative control — if ... fi 形と「関数定義で終わる」形を誤検出しない"
else
  t85_fail "TC-02 negative control 失敗 — 正しい形を ${_t85_fp} 件 誤検出した"
fi

# --- TC-03: fixture の rc が実際に漏れている（検査対象が机上でない） ---
# `set -e` 下でも止まらない形で rc を受ける。`cmd; rc=$?` は cmd が非ゼロを
# 返した時点で errexit が発火する（CI の run-tests.sh は set -e。ローカルの
# 簡易再現では set -e が無く、この違いを見落として 1 度 CI を落とした）。
_t85_bad_rc=0
sh "$PG_T85_FIX/bad-trailing-and.sh" >/dev/null 2>&1 || _t85_bad_rc=$?
_t85_good_rc=0
sh "$PG_T85_FIX/good-if-fi.sh" >/dev/null 2>&1 || _t85_good_rc=$?
if [ "$_t85_bad_rc" -ne 0 ] && [ "$_t85_good_rc" -eq 0 ]; then
  t85_pass "TC-03 fixture の実 rc が想定どおり（bad=${_t85_bad_rc} good=${_t85_good_rc}）"
else
  t85_fail "TC-03 fixture の rc が想定と違う（bad=${_t85_bad_rc} good=${_t85_good_rc}）"
fi

# --- TC-04: 実資産に該当が無い（allowlist と実態の同値照合） ---
#   走査対象は find で列挙する（glob 直書きは、対象ディレクトリに *.sh が 1 本も
#   無いシェル（zsh 等）で nomatch となりテストが途中終了するため）。
_t85_list=$(find "$PG_T85_ROOT/scripts" -type f -name '*.sh' 2>/dev/null | sort)
_t85_found=""
for _f in $_t85_list; do
  [ -f "$_f" ] || continue
  _rel=${_f#"$PG_T85_ROOT"/}
  _line=$(t85_probe "$_f" 2>/dev/null) || {
    _t85_found="${_t85_found}${_rel}
"
    printf '    [detail] %s: %s\n' "$_rel" "$_line"
  }
done
# grep -c は 0 件でも "0" を出力して rc=1 を返す。`|| printf '0'` を足すと
# "0\n0" の二重出力になる（2026-09-08 に踏んだ既知の失敗）。`|| true` で受ける。
_t85_found_n=$(printf '%s' "$_t85_found" | grep -c . || true)
_t85_allow_n=$(printf '%s' "$T85_ALLOW" | grep -c . || true)
if [ "$_t85_found_n" -eq "$_t85_allow_n" ]; then
  t85_pass "TC-04 実資産の該当件数が allowlist と一致（found=${_t85_found_n} allow=${_t85_allow_n}・件数は契約値にしない）"
else
  t85_fail "TC-04 実資産の該当が allowlist と一致しない（found=${_t85_found_n} allow=${_t85_allow_n}）— 意図的なら T85_ALLOW へ理由つきで宣言すること"
fi

# --- TC-05: 検査対象が 0 件に張り付いていない（探索そのものの liveness） ---
_t85_scanned=$(printf '%s\n' "$_t85_list" | grep -c . || true)
if [ "$_t85_scanned" -gt 0 ]; then
  t85_pass "TC-05 走査対象が存在する（scanned=${_t85_scanned}・下限のみを見る）"
else
  t85_fail "TC-05 走査対象が 0 件 — TC-04 の「該当なし」は空振りの可能性"
fi

# 本 TA は読み取りのみでサンドボックスを作らないため後始末は不要。
# 最終行は finalize 単独とする（extras 実行契約）。
pg_extra_contract_finalize
