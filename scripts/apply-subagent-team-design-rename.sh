#!/bin/sh
# apply-subagent-team-design-rename.sh -- setup-team（plangate 版）→
# subagent-team-design 改名 (#800) の参照名を HO (Hardening Override) 対象
# ファイル (.claude/commands|agents|rules) へ反映するフォールバックスクリプト
#
# .claude/commands/*.md, .claude/agents/*.md, .claude/rules/*.md は HO 対象
# （self-mod guard 相当・.claude/rules/mode-classification.md Hardening
# Override 対象パス）。AI は --dry-run のみ実行可。--apply の実行は
# Human-owned（.claude/rules/responsibility-classes.md）。
#
# 背景: #800 の Human 判断（2026-07-10、内容乖離 53%）により setup-team
# （plangate 版）を subagent-team-design へ改名した。非 HO 配置
# （.claude/skills, .agents/skills, .codex/skills, plugin/plangate/skills
# 配下および docs/ 等の通常ファイル）は本改名作業で直接編集済み。
#
# 実装時点（2026-07-10）の ref-integrity-scan（.agents/skills/ref-integrity-scan/
# SKILL.md 手順）では .claude/commands|agents|rules 配下に "setup-team" の
# 参照は検出されなかった（0 件）。そのため本スクリプトは apply-diff-audit-rename.sh
# （#796 の同型スクリプト）を雛形にした「将来 HO パスに参照が追加された場合の
# 追従用フォールバック」として維持する。現時点の --dry-run は「対象なし」を
# 返す想定（scripts/apply-diff-audit-rename.sh の F1/F2 ハードコードと異なり、
# 本スクリプトは対象を都度スキャンして決定する汎用版）。
#
# Usage:
#   sh scripts/apply-subagent-team-design-rename.sh --dry-run   # 差分プレビュー（書込なし）
#   sh scripts/apply-subagent-team-design-rename.sh --apply     # 適用（Human 実行のみ）
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

[ $# -eq 1 ] || { echo "usage: $0 --dry-run|--apply" >&2; exit 1; }
ACTION="$1"
case "$ACTION" in --dry-run|--apply) ;; *) echo "usage: $0 --dry-run|--apply" >&2; exit 1;; esac

# HO 対象パス走査（"setup-team" を含むファイルのみ対象にする。冪等: 0件ならSKIP）
set --  # 対象を位置パラメータで保持（スペース含みパス安全・gemini 指摘）
for pat in "$ROOT"/.claude/commands/*.md "$ROOT"/.claude/agents/*.md "$ROOT"/.claude/rules/*.md; do
  [ -f "$pat" ] || continue
  if grep -qF 'setup-team' "$pat" 2>/dev/null; then
    set -- "$@" "$pat"
  fi
done

if [ $# -eq 0 ]; then
  echo "[apply] SKIP: HO 対象 (.claude/commands|agents|rules) に 'setup-team' 参照なし（対応不要・適用済み or 該当なし）"
  exit 0
fi

if [ "$ACTION" = "--dry-run" ]; then
  echo "[dry-run] 置換予定（setup-team → subagent-team-design）:"
  echo "[注意] growth-core / repo-local / river-review 文脈の setup-team 言及行は置換対象外。"
  echo "       該当行が含まれる場合は --apply せず手動編集すること（命名ポリシー: 他版は名前を保持）。"
  for f in "$@"; do
    echo "--- $f ---"
    grep -nF 'setup-team' "$f" || true
  done
  exit 0
elif [ "$ACTION" = "--apply" ]; then
  # sed -i の互換性 (BSD/GNU) を避け、python3 で明示置換する（apply-diff-audit-rename.sh と同方針）。
  python3 - "$@" <<'PY'
import sys
for f in sys.argv[1:]:
    s = open(f, encoding="utf-8").read()
    n = s.count("setup-team")
    if n > 0:
        s = s.replace("setup-team", "subagent-team-design")
        open(f, "w", encoding="utf-8", newline="\n").write(s)
        print(f"[apply] {f}: {n} 件置換")
    else:
        print(f"[apply] {f}: 置換対象なし (SKIP)")
PY
  echo "[apply] 次: sh scripts/sync-plugin-plangate.sh を実行して plugin/plangate/ へ伝播してください"
  exit 0
fi
echo "usage: $0 --dry-run|--apply" >&2; exit 1
