#!/bin/sh
# apply-ai-loop-phase1-command.sh -- /ai-loop-workflow コマンド定義を
# Phase 1（導入先実リポジトリでの検証・lite 全域 auto-approve 可）表現へ更新する
#
# .claude/commands/*.md は HO 対象（self-mod guard 相当・
# .claude/rules/mode-classification.md Hardening Override 対象パス・
# scripts/hooks/check-plan-hash.sh の物理 block 9 カテゴリの1つ）。AI は
# --dry-run のみ実行可。--apply の実行は Human-owned
# （.claude/rules/responsibility-classes.md）。
#
# 背景: issue #807（ai-loop Phase 1 移行）。適用ドメイン記述を「①plangate 本体
# = docs/workflows/ai-loop/ 配下のみ ②導入先リポジトリ = ho-paths 確定 +
# LoopSpec scope.allowed_paths 宣言を前提に適用可」の 2 層へ統一する一環として、
# コマンドの実行前チェック文言（適用ドメイン判定）を Phase 1 表現に置換する
# （HO 対象外の正本群・SKILL・plugin 同期は本スクリプト範囲外で直接反映済み）。
#
# Usage:
#   sh scripts/apply-ai-loop-phase1-command.sh --dry-run   # 差分プレビュー（書込なし）
#   sh scripts/apply-ai-loop-phase1-command.sh --apply     # 適用（Human 実行のみ）
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
F1="$ROOT/.claude/commands/ai-loop-workflow.md"

[ $# -eq 1 ] || { echo "usage: $0 --dry-run|--apply" >&2; exit 1; }
case "$1" in --dry-run|--apply) ;; *) echo "usage: $0 --dry-run|--apply" >&2; exit 1;; esac
[ -f "$F1" ] || { echo "[apply] ERROR: 対象ファイルが見つかりません: $F1" >&2; exit 1; }

# 冪等性チェック: 置換対象の旧文言が既に消えていれば適用済み（またはそもそも
# 該当箇所が無い）とみなし SKIP する。
if ! grep -qF '対象変更が低リスク帯（docs 等・可逆）か' "$F1" 2>/dev/null; then
  echo "[apply] SKIP: 対象箇所が見つからない（適用済み or 参照なし）"
  exit 0
fi

if [ "$1" = "--dry-run" ]; then
  echo "[dry-run] 置換予定（実行前チェック 3. 適用ドメイン → Phase 1 表現）:"
  echo "--- $F1 ---"
  grep -nF '対象変更が低リスク帯（docs 等・可逆）か' "$F1" || true
  echo
  echo "[dry-run] 置換後の文言（適用時に反映される内容）:"
  cat <<'NEWTEXT' | sed 's/^/  (新) /'
3. **適用ドメイン（Phase 1）**: 対象変更が lite 帯候補か（`lite-criteria.md` §2 の
   4 軸〔変更規模・新規設計の有無・既存パターン踏襲・可逆性〕を満たしうる変更。
   docs に限らず実機能も含む — Human 決定 #807）。承認境界・本番承認フローに
   触れる場合は本コマンドを使わず通常フローへ
NEWTEXT
  exit 0
elif [ "$1" = "--apply" ]; then
  rc=0
  python3 - "$F1" <<'PY' || rc=$?
import sys

f = sys.argv[1]
s = open(f, encoding="utf-8").read()

old = (
    "3. **適用ドメイン**: 対象変更が低リスク帯（docs 等・可逆）か。承認境界・本番\n"
    "   承認フローに触れる場合は本コマンドを使わず通常フローへ"
)
new = (
    "3. **適用ドメイン（Phase 1）**: 対象変更が lite 帯候補か（`lite-criteria.md` §2 の\n"
    "   4 軸〔変更規模・新規設計の有無・既存パターン踏襲・可逆性〕を満たしうる変更。\n"
    "   docs に限らず実機能も含む — Human 決定 #807）。承認境界・本番承認フローに\n"
    "   触れる場合は本コマンドを使わず通常フローへ"
)

if old not in s:
    print(f"[apply] {f}: 置換対象なし (SKIP)")
    sys.exit(3)  # 3 = SKIP（呼び出し側で次ステップ案内を抑制）

n = s.count(old)
s = s.replace(old, new)
open(f, "w", encoding="utf-8", newline="\n").write(s)
print(f"[apply] {f}: {n} 件置換")
PY
  if [ "$rc" -eq 3 ]; then
    exit 0  # SKIP: 置換なし。次ステップ案内は出さない（誤解防止）
  elif [ "$rc" -ne 0 ]; then
    exit "$rc"
  fi
  echo "[apply] 次: sh scripts/sync-plugin-plangate.sh を実行して plugin/plangate/commands/ へ伝播してください"
  echo "[apply] 次: git diff で反映内容を確認してから commit してください（HO 対象のため人間コミット推奨）"
  exit 0
fi
echo "usage: $0 --dry-run|--apply" >&2; exit 1
