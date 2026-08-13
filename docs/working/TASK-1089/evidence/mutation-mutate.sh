#!/bin/sh
# mutation-mutate.sh — #1089 AC-2（変異注入で ta-65 の検出力を実証）
#
# 再現手順（セッション固有パスに依存しない）:
#   sh docs/working/TASK-1089/evidence/mutation-mutate.sh <repo_root>
#   例: sh docs/working/TASK-1089/evidence/mutation-mutate.sh "$(pwd)"
#
# 各変異は mktemp サンドボックスに `git archive HEAD` で materialize した
# リポジトリ複製に対して行う（実リポジトリを書き換えない）。
# 期待: すべての変異で ta-65 が rc=1（= kill）になること。
set -u

SRC=${1:-}
if [ -z "$SRC" ] || [ ! -d "$SRC/.git" ] && [ ! -f "$SRC/.git" ]; then
  printf 'usage: sh %s <repo_root>\n' "$0" >&2
  exit 1
fi
SRC=$(CDPATH= cd -- "$SRC" && pwd)
W=$(mktemp -d)
TA65=tests/extras/ta-65-eh3-ho-task-context.sh
APPLY=scripts/apply-eh3-ho-always.sh
FLAG=tests/fixtures/eh3-known-gap-1089.flag
rc_summary=""

mkrepo() { # $1 = dest — 作業ツリー（未 commit 分含む）を複製
  rm -rf "$1"; mkdir -p "$1"
  ( cd "$SRC" && git archive HEAD ) | tar -x -C "$1"
  for f in "$TA65" "$APPLY" "$FLAG"; do
    [ -f "$SRC/$f" ] && cp "$SRC/$f" "$1/$f"
  done
  return 0
}

run65() { # $1 = repo dir
  sh "$1/$TA65" </dev/null 2>&1
}

report() { # $1 = label, $2 = rc, $3 = output
  printf '%s\n' "$3" | grep -E '^\s+\[(PASS|FAIL)\]|standalone:'
  printf '%s_RC=%s\n\n' "$1" "$2"
  if [ "$2" = "1" ]; then
    rc_summary="${rc_summary}${1}=killed "
  else
    rc_summary="${rc_summary}${1}=SURVIVED "
  fi
}

echo "===== M1: 是正適用後に判定 call site を破壊 (\$_override = \"1\" → \"9\") ====="
mkrepo "$W/m1"
sh "$W/m1/$APPLY" --apply >/dev/null 2>&1
sed -i.bak 's/if \[ "\$_override" = "1" \]; then/if [ "$_override" = "9" ]; then/' "$W/m1/scripts/hooks/check-plan-hash.sh"
out=$(run65 "$W/m1"); rc=$?
report M1 "$rc" "$out"

echo "===== M2: 是正適用後に HO カテゴリを 1 件削除 (bin/plangate) ====="
mkrepo "$W/m2"
sh "$W/m2/$APPLY" --apply >/dev/null 2>&1
sed -i.bak '/^  bin\/plangate) _override=1 ;;$/d' "$W/m2/scripts/hooks/check-plan-hash.sh"
out=$(run65 "$W/m2"); rc=$?
report M2 "$rc" "$out"

echo "===== M3: 是正適用後に HO カテゴリを改名 (.claude/rules/*.md → NOPE.md) ====="
mkrepo "$W/m3"
sh "$W/m3/$APPLY" --apply >/dev/null 2>&1
sed -i.bak 's|^  \.claude/rules/\*\.md) _override=1 ;;$|  .claude/rules/NOPE.md) _override=1 ;;|' "$W/m3/scripts/hooks/check-plan-hash.sh"
out=$(run65 "$W/m3"); rc=$?
report M3 "$rc" "$out"

echo "===== M4 (#1089 再発): 是正適用後に hook を元の構造へ revert（flag は戻さない）====="
mkrepo "$W/m4"
sh "$W/m4/$APPLY" --apply >/dev/null 2>&1
( cd "$SRC" && git show HEAD:scripts/hooks/check-plan-hash.sh ) > "$W/m4/scripts/hooks/check-plan-hash.sh"
out=$(run65 "$W/m4"); rc=$?
report M4 "$rc" "$out"

echo "===== M5: patch のみ手動適用し KNOWN-GAP flag を残す（stale 宣言）====="
mkrepo "$W/m5"
sh "$W/m5/$APPLY" --apply >/dev/null 2>&1
cp "$SRC/$FLAG" "$W/m5/$FLAG"
out=$(run65 "$W/m5"); rc=$?
report M5 "$rc" "$out"

echo "===== M6: 未適用のまま PG_T65_EXPECT=fixed で pin ====="
mkrepo "$W/m6"
out=$(PG_T65_EXPECT=fixed sh "$W/m6/$TA65" </dev/null 2>&1); rc=$?
report M6 "$rc" "$out"

echo "===== 対照: 未適用（flag あり）/ 適用後（flag なし）はいずれも rc=0 ====="
mkrepo "$W/base"
out=$(run65 "$W/base"); rc=$?
printf 'BASE_UNPATCHED_RC=%s\n' "$rc"
mkrepo "$W/fixed"
sh "$W/fixed/$APPLY" --apply >/dev/null 2>&1
out=$(run65 "$W/fixed"); rc=$?
printf 'BASE_PATCHED_RC=%s\n\n' "$rc"

printf 'SUMMARY: %s\n' "$rc_summary"
rm -rf "$W"
