# tests/extras/ta-85-trailing-and-exit-code.sh
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

printf '\n=== TA-85: trailing && exit-code leak ===\n'

PG_T85_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
PG_T85_FIX="$FIXTURES_DIR/ta85"

t85_pass() { pass=$((pass + 1)); printf '  [PASS] %s\n' "$1"; }
t85_fail() { fail=$((fail + 1)); printf '  [FAIL] %s\n' "$1" >&2; }

# 意図的に末尾 `&&` を許す資産の宣言（現時点で 0 件）。
# 追加するときは理由をコメントで併記すること。
T85_ALLOW=""

# 末尾から閉じトークンを遡り、最初の実行文が `&&` リストなら 1 を返す検査器。
# 標準出力に該当行を出す（呼び出し側が理由として使える）。
t85_probe() {
  awk '
    # コメント行・空行は落とす
    /^[[:space:]]*#/ { next }
    /^[[:space:]]*$/ { next }
    { lines[++n] = $0 }
    END {
      for (i = n; i >= 1; i--) {
        s = lines[i]
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", s)
        # 構造の閉じトークンはスキップ（rc は直前から伝播する）
        if (s == "fi" || s == "done" || s == "esac" || s == "}" || s == ";;" || s == "else") continue
        # 最初の実行文がこれ
        if (s ~ /&&/ && s !~ /\|\|/) { print s; exit 1 }
        exit 0
      }
      exit 0
    }
  ' "$1"
}

# --- TC-01: positive control（検査器が実害の形を検出する） ---
_t85_hits=0
for _f in "$PG_T85_FIX/bad-trailing-and.sh" "$PG_T85_FIX/bad-nested-fi.sh"; do
  if [ -f "$_f" ]; then
    t85_probe "$_f" >/dev/null 2>&1 || _t85_hits=$((_t85_hits + 1))
  fi
done
if [ "$_t85_hits" -eq 2 ]; then
  t85_pass "TC-01 positive control — bad fixture 2 本とも検出（最終行が fi の形を含む）"
else
  t85_fail "TC-01 positive control 不成立 — 検出 $_t85_hits / 2（検査器が空振りしている）"
fi

# --- TC-02: negative control（正しい形を誤検出しない） ---
if t85_probe "$PG_T85_FIX/good-if-fi.sh" >/dev/null 2>&1; then
  t85_pass "TC-02 negative control — if ... fi 形は検出しない"
else
  t85_fail "TC-02 negative control 失敗 — 正しい形を誤検出した"
fi

# --- TC-03: fixture の rc が実際に漏れている（検査対象が机上でない） ---
sh "$PG_T85_FIX/bad-trailing-and.sh" >/dev/null 2>&1
_t85_bad_rc=$?
sh "$PG_T85_FIX/good-if-fi.sh" >/dev/null 2>&1
_t85_good_rc=$?
if [ "$_t85_bad_rc" -ne 0 ] && [ "$_t85_good_rc" -eq 0 ]; then
  t85_pass "TC-03 fixture の実 rc が想定どおり（bad=$_t85_bad_rc good=$_t85_good_rc）"
else
  t85_fail "TC-03 fixture の rc が想定と違う（bad=$_t85_bad_rc good=$_t85_good_rc）"
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
  t85_pass "TC-04 実資産の該当件数が allowlist と一致（found=$_t85_found_n allow=$_t85_allow_n・件数は契約値にしない）"
else
  t85_fail "TC-04 実資産の該当が allowlist と一致しない（found=$_t85_found_n allow=$_t85_allow_n）— 意図的なら T85_ALLOW へ理由つきで宣言すること"
fi

# --- TC-05: 検査対象が 0 件に張り付いていない（探索そのものの liveness） ---
_t85_scanned=$(printf '%s\n' "$_t85_list" | grep -c . || true)
if [ "$_t85_scanned" -gt 0 ]; then
  t85_pass "TC-05 走査対象が存在する（scanned=$_t85_scanned・下限のみを見る）"
else
  t85_fail "TC-05 走査対象が 0 件 — TC-04 の「該当なし」は空振りの可能性"
fi
