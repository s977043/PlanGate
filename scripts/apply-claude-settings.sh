#!/bin/sh
# apply-claude-settings.sh — settings wiring 契約 適用（TASK-0080 S1a / V-3 CR-1）
#
# `.claude/settings.json` を wiring 契約に整合させる。**ユーザーが実行**
# （AI は self-mod ガードで .claude/settings.json を編集不可）。
# JSON 構造マージで EH-3 の PLANGATE_HOOK_FILE 引数 / EH-9 ブロックを実適用。
# 冪等・backup&restore・適用後に契約検証し未適用残があれば非0（誤認防止）。
#
#   sh scripts/apply-claude-settings.sh [--dry-run]
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SJ="$ROOT/.claude/settings.json"
EX="$ROOT/.claude/settings.example.json"
DRY=0; [ "${1:-}" = "--dry-run" ] && DRY=1
[ -f "$EX" ] || { printf 'error: %s not found\n' "$EX" >&2; exit 2; }

if [ ! -f "$SJ" ]; then
  printf '[apply] .claude/settings.json 不在 → settings.example.json をコピー\n'
  [ "$DRY" -eq 1 ] || cp "$EX" "$SJ"
  [ "$DRY" -eq 1 ] && { printf '[apply] --dry-run: コピーせず\n'; exit 0; }
else
  [ "$DRY" -eq 1 ] && printf '[apply] --dry-run: 構造マージ内容のみ確認\n'
  BAK="$SJ.bak.$(date +%s)"
  [ "$DRY" -eq 1 ] || cp "$SJ" "$BAK"
  if ! python3 - "$SJ" "$EX" "$DRY" <<'PY'
import json, sys
SJ, EX, DRY = sys.argv[1], sys.argv[2], sys.argv[3] == "1"
try:
    doc = json.load(open(SJ))
except Exception as e:
    print(f"[apply] FAIL: {SJ} 無効 JSON: {e}", file=sys.stderr); sys.exit(2)
ex = json.load(open(EX))
pre = doc.setdefault("hooks", {}).setdefault("PreToolUse", [])
changed = []

# 1) EH-3: check-plan-hash.sh の command に ${PLANGATE_HOOK_FILE:-} を付与
for blk in pre:
    for h in blk.get("hooks", []) or []:
        c = h.get("command", "")
        if "check-plan-hash.sh" in c and "${PLANGATE_HOOK_FILE:-}" not in c:
            h["command"] = c.replace(
                "${PLANGATE_HOOK_TASK:-}",
                "${PLANGATE_HOOK_TASK:-} ${PLANGATE_HOOK_FILE:-}", 1)
            changed.append("EH-3 PLANGATE_HOOK_FILE")

# 2) EH-9: 無ければ settings.example.json の EH-9 ブロックを取り込む
def has_eh9(blocks):
    return any("check-delegation-commit-boundary.sh" in h.get("command", "")
               for b in blocks for h in (b.get("hooks") or []))
if not has_eh9(pre):
    ex_pre = ex.get("hooks", {}).get("PreToolUse", [])
    eh9 = next((b for b in ex_pre
                if any("check-delegation-commit-boundary.sh" in h.get("command", "")
                       for h in (b.get("hooks") or []))), None)
    if eh9 is not None:
        pre.append(eh9)
        changed.append("EH-9 block")
    else:
        print("[apply] WARN: settings.example.json に EH-9 ブロックが無い", file=sys.stderr)

if DRY:
    print(f"[apply] --dry-run 適用予定: {changed or ['(変更なし)']}")
    sys.exit(0)
if changed:
    json.dumps(doc)  # 妥当性
    with open(SJ, "w") as f:
        json.dump(doc, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print(f"[apply] 適用: {changed}")
else:
    print("[apply] 既に契約準拠（変更なし）")
sys.exit(0)
PY
  then
    rc=$?
    if [ "$DRY" -eq 0 ] && [ -f "$BAK" ]; then
      cp "$BAK" "$SJ"; printf '[apply] エラー→ %s から復元\n' "$BAK" >&2
    fi
    exit "$rc"
  fi
  [ "$DRY" -eq 0 ] && [ -f "$BAK" ] && rm -f "$BAK"
fi

[ "$DRY" -eq 1 ] && exit 0
# 適用後に契約検証（未適用残があれば非0＝「適用済み誤認」防止 / V-3 CR-1）
if sh "$ROOT/scripts/check-settings-wiring.sh" --target user >/dev/null 2>&1; then
  printf '[apply] done: settings wiring 契約準拠を確認\n'; exit 0
fi
printf '[apply] FAIL: 適用後も契約未準拠が残存（手動確認が必要）\n' >&2
sh "$ROOT/scripts/check-settings-wiring.sh" --target user 2>&1 | sed 's/^/  /' >&2
exit 1
