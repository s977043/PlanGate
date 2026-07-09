#!/bin/sh
# apply-claude-md-v8160.sh -- CLAUDE.md「最新リリース」節を v8.16.0 へ更新
#
# CLAUDE.md は Hardening Override (HO) 対象（self-mod guard）。AI は --dry-run
# のみ実行可。--apply の実行は Human-owned（.claude/rules/responsibility-classes.md）。
#
# 背景: CLAUDE.md の「最新リリース」節は v8.13.0 のまま v8.14/8.15/8.16 の
# 3 リリースで未更新（version 同期マップの対象外だったことが構造原因。
# 本 PR で docs/release-process.md 側にも同期対象として追記済み）。
#
# Usage:
#   sh scripts/apply-claude-md-v8160.sh --dry-run   # 差分プレビュー（書込なし）
#   sh scripts/apply-claude-md-v8160.sh --apply     # 適用（Human 実行のみ）
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
F="$ROOT/CLAUDE.md"
[ $# -eq 1 ] || { echo "usage: $0 --dry-run|--apply" >&2; exit 1; }

OLD_HEAD='## v8.13.0 全体健全化・エージェント model tier（最新リリース機能）'
NEW_HEAD='## v8.16.0 ai-loop 実運用（dogfooding）・Plugin 同梱配布（最新リリース機能）'
NEW_BODY='> 最新リリース: **v8.16.0**（2026-07-08）ai-loop（旧 Arbiter）を自身の開発プロセスへの dogfooding として初実運用（Run-001〜021 の摩擦是正閉ループ・auto-merge 廃止 + merge-ready 運用・rubric grader・HO 境界の実行時 parse 化。**PlanGate 本番フロー WF-00〜07 は不変・ai-loop は PoC**）+ `ai-loop-cycle` スキルの plangate プラグイン同梱（bundled resources・導入前に ho-paths の導入先確定が必須）+ Hook Enforcement 物理配線 11/12 + サブエージェント委譲プロトコル正本。v8.15.0 で Review Gate 機械化・approve ハードニング、v8.14.0 で C-3 HTML 出力 + ワンアクション承認、v8.13.0 で全体健全化 + model tier。リリース履歴の正本は [`CHANGELOG.md`](CHANGELOG.md)。'

grep -qF "$OLD_HEAD" "$F" || { echo "[apply] SKIP: 対象節が見つからない（適用済み or 構造変更）"; exit 0; }

if [ "$1" = "--dry-run" ]; then
  echo "[dry-run] 置換予定:"
  echo "  - 見出し: $OLD_HEAD"
  echo "  +        : $NEW_HEAD"
  echo "  - 本文  : 「> 最新リリース: **v8.13.0**…」の段落 1 つを v8.16.0 版に置換"
  exit 0
elif [ "$1" = "--apply" ]; then
  python3 - "$F" "$NEW_HEAD" "$NEW_BODY" <<'PY'
import sys
f, new_head, new_body = sys.argv[1], sys.argv[2], sys.argv[3]
s = open(f, encoding="utf-8").read()
old_head = "## v8.13.0 全体健全化・エージェント model tier（最新リリース機能）"
i = s.index(old_head)
j = s.index("\n\n", s.index("> 最新リリース", i))
s = s[:i] + new_head + "\n\n" + new_body + s[j:]
open(f, "w", encoding="utf-8", newline="\n").write(s)
print("[apply] CLAUDE.md 最新リリース節を v8.16.0 に更新")
PY
  exit 0
fi
echo "usage: $0 --dry-run|--apply" >&2; exit 1
