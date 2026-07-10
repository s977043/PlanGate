#!/bin/sh
# apply-diff-audit-rename.sh -- self-review スキル改名 (diff-audit) の参照名を
# Hardening Override (HO) 対象 Agent 定義 2 ファイルへ反映する
#
# .claude/agents/*.md は HO 対象（self-mod guard 相当・
# .claude/rules/mode-classification.md Hardening Override 対象パス）。AI は
# --dry-run のみ実行可。--apply の実行は Human-owned
# （.claude/rules/responsibility-classes.md）。
#
# 背景: self-review スキルは repo-local / growth-core / plangate の 3 重定義
# 衝突（docs/ai/skill-collision-detection.md #692 実例）を解消するため
# plangate 版を diff-audit へ改名した（.claude/skills, .agents/skills,
# .codex/skills, plugin/plangate/skills は非 HO のため直接編集済み）。
# implementation-agent.md / workflow-conductor.md の Skill 参照名のみ
# 冪等 sed 置換で追従する（本文の意味・構造は変更しない）。
#
# Usage:
#   sh scripts/apply-diff-audit-rename.sh --dry-run   # 差分プレビュー（書込なし）
#   sh scripts/apply-diff-audit-rename.sh --apply     # 適用（Human 実行のみ）
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
F1="$ROOT/.claude/agents/implementation-agent.md"
F2="$ROOT/.claude/agents/workflow-conductor.md"

[ $# -eq 1 ] || { echo "usage: $0 --dry-run|--apply" >&2; exit 1; }
case "$1" in --dry-run|--apply) ;; *) echo "usage: $0 --dry-run|--apply" >&2; exit 1;; esac
[ -f "$F1" ] && [ -f "$F2" ] || { echo "[apply] ERROR: 対象ファイルが見つかりません: $F1 / $F2" >&2; exit 1; }

# 冪等性チェック: 置換対象の旧参照 self-review が両ファイルから既に消えていれば
# 適用済み（またはそもそも該当箇所が無い）とみなし SKIP する。
if ! grep -qF 'self-review' "$F1" "$F2" 2>/dev/null; then
  echo "[apply] SKIP: 対象箇所が見つからない（適用済み or 参照なし）"
  exit 0
fi

if [ "$1" = "--dry-run" ]; then
  echo "[dry-run] 置換予定（self-review → diff-audit、スキル参照のみ）:"
  echo "--- $F1 ---"
  grep -nF 'self-review' "$F1" || true
  echo "--- $F2 ---"
  grep -nF 'self-review' "$F2" || true
  exit 0
elif [ "$1" = "--apply" ]; then
  # sed -i の互換性 (BSD/GNU) を避け、python3 で明示置換する。
  # 置換は文字列 "self-review" の単純置換（スキル名・ファイルパスの参照のみで
  # 使われており、他語彙との衝突なし。Phase 13 ポータビリティ観点に合わせ
  # sed バージョン依存を避ける）。
  python3 - "$F1" "$F2" <<'PY'
import sys
for f in sys.argv[1:]:
    s = open(f, encoding="utf-8").read()
    n = s.count("self-review")
    if n > 0:
        s = s.replace("self-review", "diff-audit")
        open(f, "w", encoding="utf-8", newline="\n").write(s)
        print(f"[apply] {f}: {n} 件置換")
    else:
        print(f"[apply] {f}: 置換対象なし (SKIP)")
PY
  echo "[apply] 次: sh scripts/sync-plugin-plangate.sh を実行して plugin/plangate/agents/ へ伝播してください"
  exit 0
fi
echo "usage: $0 --dry-run|--apply" >&2; exit 1
