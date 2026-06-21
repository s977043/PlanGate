#!/bin/sh
# TASK-0131(#565): working-context.md todo.md 規約に rollback 行を追加
# HO 対象(.claude/rules/working-context.md)のため AI は本 script を生成のみ。適用は人間。
# 冪等: 既適用ならスキップ。
set -e
cd "$(git rev-parse --show-toplevel)"
F=".claude/rules/working-context.md"
if grep -qF '各タスクに `rollback:`' "$F"; then echo "already applied: $F"; exit 0; fi
python3 - "$F" <<'INNER'
import sys
f=sys.argv[1]; s=open(f,encoding="utf-8").read()
old="- L-0〜V-4, PR作成はworkflow-conductorが自動制御するため含めない\n\n### test-cases.md（テストケース定義）"
new=("- L-0〜V-4, PR作成はworkflow-conductorが自動制御するため含めない\n"
"- 各タスクに `rollback:` を記載（戻し手順）。**必須=high-risk / critical の実装タスク**。standard 以下は任意、検証/読取のみは `rollback:不要` と明記可\n"
"\n### test-cases.md（テストケース定義）")
assert old in s, "anchor not found in working-context.md"
open(f,"w",encoding="utf-8",newline="\n").write(s.replace(old,new))
print("applied rollback rule to", f)
INNER
echo "DONE. 適用後は git diff で確認し、TASK-0131 ブランチにコミットしてください。"
