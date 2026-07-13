#!/bin/sh
# apply-claude-md-v8171.sh -- CLAUDE.md「最新リリース」節を v8.17.1 へ更新
#
# CLAUDE.md は Hardening Override (HO) 対象（self-mod guard）。AI は --dry-run
# のみ実行可。--apply の実行は Human-owned（.claude/rules/responsibility-classes.md）。
#
# 背景: v8.17.0（plugin version bump・ai-loop 最新の plugin 配布反映）と
# v8.17.1（plugin-sync 同期漏れ追従）のリリースに伴う「最新リリース」節の同期。
#
# Usage:
#   sh scripts/apply-claude-md-v8171.sh --dry-run   # 差分プレビュー（書込なし）
#   sh scripts/apply-claude-md-v8171.sh --apply     # 適用（Human 実行のみ）
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
F="$ROOT/CLAUDE.md"
[ $# -eq 1 ] || { echo "usage: $0 --dry-run|--apply" >&2; exit 1; }

OLD_HEAD="## v8.16.0 ai-loop 実運用（dogfooding）・Plugin 同梱配布（最新リリース機能）"
NEW_HEAD="## v8.17.1 ai-loop 最新の Plugin 配布反映（最新リリース機能）"
NEW_BODY="> 最新リリース: **v8.17.1**（2026-07-13）v8.16.0 タグ以降に main へ蓄積した ai-loop の変更を plugin 配布へ反映（v8.17.0）+ plugin-sync 同期漏れの追従（v8.17.1）。主要変更: ai-loop Phase 1 移行＝導入先実リポジトリ検証の正式化（#808）・fail-closed + allowed_paths の機械層配線（#813）・計測基盤の実データ稼働 \`metrics.py\` / run メタ刻印（#812/#815）・LoopSpec cost_cap 超過の escalate（#840）・HOTL 境界正本化 + 回帰テスト（#827〜#832/#830）。**PlanGate 本番フロー WF-00〜07 は不変・ai-loop は Phase 1（導入先検証）**。v8.16.0 で ai-loop 初実運用（Run-001〜021）+ plugin 同梱、v8.15.0 で Review Gate 機械化・approve ハードニング、v8.14.0 で C-3 HTML 出力 + ワンアクション承認。リリース履歴の正本は [\`CHANGELOG.md\`](CHANGELOG.md)。"

grep -qF "$OLD_HEAD" "$F" || { echo "[apply] SKIP: 対象節が見つからない（適用済み or 構造変更）"; exit 0; }

if [ "$1" = "--dry-run" ]; then
  echo "[dry-run] 置換予定:"
  echo "  - 見出し: $OLD_HEAD"
  echo "  +        : $NEW_HEAD"
  echo "  - 本文  : 「> 最新リリース: **v8.16.0**…」の段落 1 つを v8.17.1 版に置換"
  exit 0
elif [ "$1" = "--apply" ]; then
  python3 - "$F" "$NEW_HEAD" "$NEW_BODY" <<'PY'
import sys
f, new_head, new_body = sys.argv[1], sys.argv[2], sys.argv[3]
s = open(f, encoding="utf-8").read()
old_head = "## v8.16.0 ai-loop 実運用（dogfooding）・Plugin 同梱配布（最新リリース機能）"
i = s.index(old_head)
j = s.index("\n\n", s.index("> 最新リリース", i))
s = s[:i] + new_head + "\n\n" + new_body + s[j:]
open(f, "w", encoding="utf-8", newline="\n").write(s)
print("[apply] CLAUDE.md 最新リリース節を v8.17.1 に更新")
PY
  exit 0
fi
echo "usage: $0 --dry-run|--apply" >&2; exit 1
