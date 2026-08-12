#!/bin/sh
# check-outcome-contract.sh — サブエージェント完了報告の OUTCOME 契約を機械判定する
#
# 正本: docs/ai/subagent-delegation/outcome-contract.md
#   §6 オーケストレータ受け入れ確認チェックリストのうち、**汎用に機械判定できる
#   項目 3・4・5** を判定する（#1061）。
#     3. OUTCOME が最終行に 1 回だけあるか（^OUTCOME: (success|partial|failure)$）
#     4. 要判断事項が P0 / P1 / P2 で分類されているか
#     5. 検証結果が「実行済み / 未実行 / 失敗 / 未検証」で明示されているか
#   項目 1（要求された成果物があるか）・2（制約違反がないか）は**タスク依存で
#   汎用判定が不能**なため意図的に実装しない（目視のまま）。
#
# 既知の限界:
#   - コードフェンス内かどうかを区別しない。報告本文に契約の実例を貼る場合は
#     `OUTCOME:` を行頭に置かないこと（複数出現として検出される）。
#
# Usage:
#   sh scripts/check-outcome-contract.sh <FILE>
#   cat report.txt | sh scripts/check-outcome-contract.sh
#   sh scripts/check-outcome-contract.sh -        # 明示的に標準入力
#
# Exit:
#   0 = 項目 3・4・5 をすべて充足
#   1 = 契約違反あり（違反内容を出力）
#   2 = 使い方エラー（ファイル不在・引数過多）

set -eu

PROG=check-outcome-contract
STRICT_RE='^OUTCOME: (success|partial|failure)$'

usage() {
  cat <<'EOF'
Usage: sh scripts/check-outcome-contract.sh [FILE|-]

サブエージェント完了報告の OUTCOME 契約（outcome-contract.md §6 の項目 3・4・5）を
判定する。FILE 省略時 / "-" 指定時は標準入力を読む。

Exit: 0=充足 / 1=契約違反 / 2=使い方エラー
EOF
}

case "${1:-}" in
  -h|--help) usage; exit 0 ;;
esac

if [ "$#" -gt 1 ]; then
  printf '[%s] ERROR: 引数は 0 個または 1 個です（受領: %d 個）\n' "$PROG" "$#" >&2
  usage >&2
  exit 2
fi

TMP=''
cleanup() { [ -n "$TMP" ] && rm -f "$TMP"; return 0; }
trap cleanup EXIT INT TERM

if [ "$#" -eq 0 ] || [ "${1:-}" = "-" ]; then
  TMP=$(mktemp) || { printf '[%s] ERROR: mktemp に失敗\n' "$PROG" >&2; exit 2; }
  cat > "$TMP"
  SRC="$TMP"
else
  SRC="$1"
  if [ ! -f "$SRC" ] || [ ! -r "$SRC" ]; then
    printf '[%s] ERROR: 読み取れないファイル: %s\n' "$PROG" "$SRC" >&2
    exit 2
  fi
fi

violations=0
report_pass() { printf '[%s] PASS (%s): %s\n' "$PROG" "$1" "$2"; }
report_fail() {
  violations=$((violations + 1))
  printf '[%s] FAIL (%s): %s\n' "$PROG" "$1" "$2" >&2
}

# ---------------------------------------------------------------------------
# 項目 3: OUTCOME が最終行に 1 回だけあるか
# ---------------------------------------------------------------------------
strict_n=$(grep -cE "$STRICT_RE" "$SRC" 2>/dev/null || true)
[ -n "$strict_n" ] || strict_n=0
# 表記ゆれ候補: 行頭の outcome: 形式のうち、厳密形に一致しないもの
variants=$(grep -nEi '^[[:space:]]*outcome[[:space:]]*:' "$SRC" 2>/dev/null \
  | grep -vE "^[0-9]+:OUTCOME: (success|partial|failure)\$" || true)
last_line=$(tail -n 1 "$SRC" 2>/dev/null || true)

if [ "$strict_n" -eq 0 ]; then
  if [ -n "$variants" ]; then
    report_fail "3/OUTCOME" "OUTCOME 行が厳密形 '${STRICT_RE}' に一致しません（表記ゆれ）:"
    printf '%s\n' "$variants" | sed 's/^/    /' >&2
  else
    report_fail "3/OUTCOME" "OUTCOME 行がありません（最終行に 'OUTCOME: success|partial|failure' を 1 回だけ書く）"
  fi
elif [ "$strict_n" -gt 1 ]; then
  report_fail "3/OUTCOME" "OUTCOME 行が $strict_n 回出現しています（1 回だけにする）"
elif [ -n "$variants" ]; then
  report_fail "3/OUTCOME" "厳密形の OUTCOME 行に加えて表記ゆれの OUTCOME 行があります:"
  printf '%s\n' "$variants" | sed 's/^/    /' >&2
elif ! printf '%s\n' "$last_line" | grep -qE "$STRICT_RE"; then
  if [ -z "$(printf '%s' "$last_line" | tr -d '[:space:]')" ]; then
    report_fail "3/OUTCOME" "OUTCOME 行の後に空行が続いています（OUTCOME 行を最終行にする）"
  else
    report_fail "3/OUTCOME" "OUTCOME 行が最終行ではありません（最終行: '$last_line'）"
  fi
else
  report_pass "3/OUTCOME" "OUTCOME 行が最終行に 1 回だけある"
fi

# ---------------------------------------------------------------------------
# 項目 4: 要判断事項が P0 / P1 / P2 で分類されているか
#   「分類が無い」と「要判断事項の記載自体が無い」を別の診断で区別する。
# ---------------------------------------------------------------------------
marker_n=$(grep -cE '\[P[0-2]\]' "$SRC" 2>/dev/null || true)
[ -n "$marker_n" ] || marker_n=0
section_n=$(grep -c '要判断事項' "$SRC" 2>/dev/null || true)
[ -n "$section_n" ] || section_n=0

if [ "$marker_n" -gt 0 ]; then
  report_pass "4/要判断事項" "P0/P1/P2 の分類が $marker_n 件ある"
elif [ "$section_n" -eq 0 ]; then
  report_fail "4/要判断事項" "要判断事項の記載自体がありません（無い場合も『要判断事項: なし』と明記する）"
else
  section_body=$(awk '/要判断事項/{f=1} f && /^#/ && !/要判断事項/{exit} f{print}' "$SRC" 2>/dev/null || true)
  if printf '%s\n' "$section_body" \
    | grep -qEi '^[[:space:]]*(-[[:space:]]*)?(なし|無し|none|n/a)[[:space:]]*$'; then
    report_pass "4/要判断事項" "要判断事項なしと明記されている"
  else
    report_fail "4/要判断事項" "要判断事項に P0/P1/P2 の分類がありません（各項目に [P0]/[P1]/[P2] を付ける）"
  fi
fi

# ---------------------------------------------------------------------------
# 項目 5: 検証結果が「実行済み / 未実行 / 失敗 / 未検証」で明示されているか
# ---------------------------------------------------------------------------
if grep -qE '実行済み|未実行|失敗|未検証' "$SRC" 2>/dev/null; then
  report_pass "5/検証状態" "検証状態が 4 区分（実行済み/未実行/失敗/未検証）で記載されている"
else
  report_fail "5/検証状態" "検証状態が 4 区分（実行済み/未実行/失敗/未検証）で明示されていません"
fi

# ---------------------------------------------------------------------------
if [ "$violations" -eq 0 ]; then
  printf '[%s] OK: 項目 3・4・5 を充足（項目 1・2 はタスク依存のため目視）\n' "$PROG"
  exit 0
fi
printf '[%s] NG: 契約違反 %d 件。同一サブエージェントへ追指示して是正させる（別セッションへ再委譲しない）\n' \
  "$PROG" "$violations" >&2
exit 1
