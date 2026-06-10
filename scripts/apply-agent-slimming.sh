#!/bin/sh
# apply-agent-slimming.sh — 未使用エージェント 6 体の削除 + README 2 層化（Human 適用）
#
# 背景: 2026-06-10 全体監査で、v6 一括追加以来 .claude/agents/README.md からのみ
# 参照され実使用の証跡がない 6 体（agile-coach / scrum-master / migration-agent /
# prompt-engineer / research-analyst / claude-code-reviewer）の削除（案2）を
# ユーザーが承認。HO 対象パス（.claude/agents/*.md）のため適用は Human が行う。
# plugin / .codex 側の対応物と参照 README/config は AI が同一ブランチで削除済み。
#
# 使い方:
#   sh scripts/apply-agent-slimming.sh --dry-run   # 変更内容の確認
#   sh scripts/apply-agent-slimming.sh --apply     # 適用
set -eu
MODE="${1:---dry-run}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
AGENTS="agile-coach scrum-master migration-agent prompt-engineer research-analyst claude-code-reviewer"

if [ "$MODE" = "--dry-run" ]; then
  echo "[dry-run] 削除予定:"
  for a in $AGENTS; do echo "  .claude/agents/$a.md"; done
  echo "[dry-run] 更新予定: .claude/agents/README.md（6 行削除 + 空セクション除去 + コア/支援 2 層注記）"
  exit 0
fi
[ "$MODE" = "--apply" ] || { echo "usage: $0 [--dry-run|--apply]"; exit 1; }

for a in $AGENTS; do
  git -C "$ROOT" rm -q --ignore-unmatch ".claude/agents/$a.md"
done

python3 - "$ROOT/.claude/agents/README.md" <<'PYEOF2'
import re, sys
p = sys.argv[1]
lines = open(p, encoding="utf-8").read().splitlines()
drop = ("| claude-code-reviewer ", "| prompt-engineer ", "| migration-agent ",
        "| research-analyst ", "| scrum-master ", "| agile-coach ")
out = [l for l in lines if not l.startswith(drop)]
s = "\n".join(out) + "\n"
# 空になったセクション（レビュー・改善 / アジャイル: 見出し+表ヘッダのみ）を除去
s = re.sub(r"### (レビュー・改善|アジャイル)\n\n\| エージェント \| ファイル \| Codex toml \| 説明 \|\n\|[-| ]+\|\n\n", "", s)
# 既存 17 体 → 11 体
s = s.replace("汎用・補助系の既存 17 体は引き続き利用可能", "汎用・補助系の既存 11 体は引き続き利用可能")
# コア/支援 2 層注記を一覧見出し直後に挿入
anchor = "## エージェント定義一覧\n"
note = anchor + """
> **2 層構成（2026-06-10 スリム化）**: ゲート列（WF-01〜06 / C / V / L-0）を担う
> **コア**（orchestrator / workflow-conductor / requirements-analyst /
> solution-architect / spec-writer / implementation-agent / implementer /
> qa-reviewer / acceptance-tester / code-optimizer / linter-fixer /
> retrospective-analyst / setup-coordinator）と、必要時に description マッチで
> 起動する **支援**（explorer-agent / project-planner / documentation-writer /
> skill-designer）の 2 層。実使用の証跡がない 6 体（agile-coach / scrum-master /
> migration-agent / prompt-engineer / research-analyst / claude-code-reviewer）は
> 2026-06-10 監査で削除（git 履歴から復元可能）。
"""
assert s.count(anchor) == 1
s = s.replace(anchor, note)
open(p, "w", encoding="utf-8").write(s)
print("README.md updated")
PYEOF2

git -C "$ROOT" add .claude/agents/README.md
echo "適用完了。git status を確認のうえコミットしてください。"
