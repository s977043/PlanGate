#!/bin/sh
# Mutation testing for ta-65 (AC-2)
S=/private/tmp/claude-502/-Users-user-Documents-GitHub-plangate/53b845af-f03d-448c-bd9c-0fdfcc4cc6f1/scratchpad
SRC_FIXED="$S/applytest/scripts/hooks/check-plan-hash.sh"
SRC_ORIG="$S/base/scripts/hooks/check-plan-hash.sh"
EX=/Users/user/Documents/GitHub/plangate/.claude/worktrees/agent-a994472de700000d3/tests/extras

mk() { # $1=dir $2=hook_src
  rm -rf "$1"; mkdir -p "$1/scripts/hooks" "$1/tests/extras"
  cp "$2" "$1/scripts/hooks/check-plan-hash.sh"
  cp "$EX/_extra-contract.sh" "$EX/ta-65-eh3-ho-task-context.sh" "$1/tests/extras/"
  mkdir -p "$1/.claude/rules"
  cp /Users/user/Documents/GitHub/plangate/.claude/worktrees/agent-a994472de700000d3/.claude/rules/mode-classification.md "$1/.claude/rules/"
}

echo "===== M1: patched + call site 破壊 (if [ \"\$_override\" = \"1\" ] → \"9\") ====="
mk "$S/m1" "$SRC_FIXED"
sed -i '' 's/if \[ "\$_override" = "1" \]; then/if [ "$_override" = "9" ]; then/' "$S/m1/scripts/hooks/check-plan-hash.sh"
grep -c 'if \[ "\$_override" = "9" \]' "$S/m1/scripts/hooks/check-plan-hash.sh"
sh "$S/m1/tests/extras/ta-65-eh3-ho-task-context.sh" </dev/null; echo "M1_RC=$?"

echo
echo "===== M2: patched + 1 カテゴリ削除 (bin/plangate) ====="
mk "$S/m2" "$SRC_FIXED"
sed -i '' '/^  bin\/plangate) _override=1 ;;$/d' "$S/m2/scripts/hooks/check-plan-hash.sh"
sh "$S/m2/tests/extras/ta-65-eh3-ho-task-context.sh" </dev/null; echo "M2_RC=$?"

echo
echo "===== M3: 未適用 hook + PG_T65_EXPECT=fixed (pin) ====="
mk "$S/m3" "$SRC_ORIG"
PG_T65_EXPECT=fixed sh "$S/m3/tests/extras/ta-65-eh3-ho-task-context.sh" </dev/null; echo "M3_RC=$?"

echo
echo "===== M4: patched + no-task 経路の破壊 (case ラベルの .claude/rules を除去) ====="
mk "$S/m4" "$SRC_FIXED"
sed -i '' 's|^  \.claude/rules/\*\.md) _override=1 ;;$|  .claude/rules/NOPE.md) _override=1 ;;|' "$S/m4/scripts/hooks/check-plan-hash.sh"
sh "$S/m4/tests/extras/ta-65-eh3-ho-task-context.sh" </dev/null; echo "M4_RC=$?"
