#!/bin/sh
# apply-script-guards.sh — scripts/apply-eh3-ho-always.sh の 4 性質を実測する
# （docs/ai/ho-change-workflow.md「標準フロー」要件: 冪等 / --dry-run /
#   引数 strict 検証 / アンカー検証）
#
#   sh docs/working/TASK-1089/evidence/apply-script-guards.sh <repo_root>
set -u
SRC=$(CDPATH= cd -- "${1:?usage: sh $0 <repo_root>}" && pwd)
W=$(mktemp -d)
APPLY=scripts/apply-eh3-ho-always.sh
FLAG=tests/fixtures/eh3-known-gap-1089.flag
HOOK=scripts/hooks/check-plan-hash.sh

mkrepo() {
  rm -rf "$1"; mkdir -p "$1"
  ( cd "$SRC" && git archive HEAD ) | tar -x -C "$1"
  for f in "$APPLY" "$FLAG" tests/extras/ta-65-eh3-ho-task-context.sh; do
    [ -f "$SRC/$f" ] && cp "$SRC/$f" "$1/$f"
  done
  return 0
}
sha() { shasum -a 256 "$1" | awk '{print $1}'; }

echo "===== A1: 引数 strict 検証（未知引数 / 引数過多）====="
mkrepo "$W/a1"
sh "$W/a1/$APPLY" --bogus >/dev/null 2>&1; echo "unknown-arg rc=$?  (期待 1)"
sh "$W/a1/$APPLY" --dry-run --apply >/dev/null 2>&1; echo "too-many-args rc=$?  (期待 1)"

echo
echo "===== A2: --dry-run（既定）は 1 バイトも書かない ====="
mkrepo "$W/a2"
h0=$(sha "$W/a2/$HOOK"); r0=$(sha "$W/a2/.claude/rules/mode-classification.md")
sh "$W/a2/$APPLY" >/dev/null 2>&1; echo "default(no arg) rc=$?  (期待 0)"
sh "$W/a2/$APPLY" --dry-run >/dev/null 2>&1; echo "--dry-run rc=$?  (期待 0)"
h1=$(sha "$W/a2/$HOOK"); r1=$(sha "$W/a2/.claude/rules/mode-classification.md")
[ "$h0" = "$h1" ] && echo "hook 未変更 OK" || echo "NG: hook が変わった"
[ "$r0" = "$r1" ] && echo "rules 未変更 OK" || echo "NG: rules が変わった"
[ -f "$W/a2/$FLAG" ] && echo "flag 残存 OK" || echo "NG: flag が消えた"

echo
echo "===== A3: アンカー検証（base から drift）→ exit 1 かつ部分適用なし ====="
mkrepo "$W/a3"
sed -i.bak 's|^    bin/plangate) _override=1 ;;$|    bin/plangate) _override=1 ;; # drifted|' "$W/a3/$HOOK"
rm -f "$W/a3/$HOOK.bak"
h0=$(sha "$W/a3/$HOOK"); r0=$(sha "$W/a3/.claude/rules/mode-classification.md")
# exit code を失わないよう、パイプせずに出力を捕捉してから rc を読む
out=$(sh "$W/a3/$APPLY" --apply 2>&1); rc=$?
echo "  $out"
echo "anchor-drift rc=$rc  (期待 1)"
h1=$(sha "$W/a3/$HOOK"); r1=$(sha "$W/a3/.claude/rules/mode-classification.md")
[ "$h0" = "$h1" ] && echo "hook 未変更 OK" || echo "NG: hook が変わった"
[ "$r0" = "$r1" ] && echo "rules 未変更 OK（部分適用なし）" || echo "NG: rules だけ適用された"
[ -f "$W/a3/$FLAG" ] && echo "flag 残存 OK（部分適用なし）" || echo "NG: flag だけ消えた"

echo
echo "===== A4: 冪等性（--apply を 2 回 / 適用後の --dry-run）====="
mkrepo "$W/a4"
sh "$W/a4/$APPLY" --apply >/dev/null 2>&1; echo "1st --apply rc=$?  (期待 0)"
out=$(sh "$W/a4/$APPLY" --apply 2>&1); echo "2nd --apply rc=$?  (期待 0)"
echo "  出力: $out"
h0=$(sha "$W/a4/$HOOK")
out=$(sh "$W/a4/$APPLY" --dry-run 2>&1); echo "適用後 --dry-run rc=$?  (期待 0)"
echo "  出力: $out"
h1=$(sha "$W/a4/$HOOK")
[ "$h0" = "$h1" ] && echo "2 回目以降に hook を書き換えない OK" || echo "NG: 再適用で変化した"

rm -rf "$W"
