#!/bin/sh
# apply-ho-review-fixes-536.sh — PR #536 の Gemini レビュー反映（Human 実行）
#
# 対象は Hardening Override パスのため AI は本スクリプト作成と --dry-run まで。
# 修正 3 点:
#  1) [high] responsibility-classes.md: ブランチ作成手順を「fetch してから
#     origin/main を base に分岐」へ修正（fetch はローカル main を更新しないため）
#  2-3) [medium] mode-classification.md: doc-light 判定の *.md 表記を
#     「任意の .md」に明確化（ルート直下のみと誤読されないように）
#
# 使い方: sh scripts/apply-ho-review-fixes-536.sh [--dry-run|--apply]
set -eu
MODE="${1:---dry-run}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

apply_fix() {
  # $1=file $2=old $3=new
  f="$ROOT/$1"
  if grep -qF -- "$3" "$f"; then echo "OK (already): $1"; return 0; fi
  grep -qF -- "$2" "$f" || { echo "ERROR: アンカー不在: $1: $2" >&2; exit 1; }
  if [ "$MODE" = "--dry-run" ]; then
    echo "[dry-run] $1:"; echo "- $2"; echo "+ $3"
  else
    python3 - "$f" "$2" "$3" <<'PY'
import sys
f, old, new = sys.argv[1], sys.argv[2], sys.argv[3]
with open(f, encoding="utf-8") as fp: s = fp.read()
assert s.count(old) >= 1
with open(f, "w", encoding="utf-8") as fp: fp.write(s.replace(old, new))
PY
    echo "APPLIED: $1"
  fi
}

case "$MODE" in --dry-run|--apply) ;; *) echo "usage: $0 [--dry-run|--apply]"; exit 1 ;; esac

apply_fix ".claude/rules/responsibility-classes.md" \
  "（\`git checkout main && git fetch && git checkout -b <new>\`）" \
  "（\`git fetch && git checkout -b <new> origin/main\` — fetch はローカル main を更新しないため、origin/main を base に明示する）"

apply_fix ".claude/rules/mode-classification.md" \
  "| **doc** | 差分が \`*.md\` / \`docs/\` 配下のみ（コード・設定・スキーマを含まない） |" \
  "| **doc** | 差分が任意の \`.md\`（パス不問） / \`docs/\` 配下のみ（コード・設定・スキーマを含まない） |"

apply_fix ".claude/rules/mode-classification.md" \
  "- 差分に \`*.md\` / \`docs/\` 以外を 1 つでも含む" \
  "- 差分に任意の \`.md\` / \`docs/\` 以外を 1 つでも含む"

[ "$MODE" = "--apply" ] && echo "適用完了。AI が sync / commit / 返信を引き継ぎます。"
exit 0
