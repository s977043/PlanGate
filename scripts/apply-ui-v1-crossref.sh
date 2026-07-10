#!/bin/sh
# apply-ui-v1-crossref.sh -- UI 専用 V-1 のクロスリファレンス 1 行を
# Hardening Override (HO) 対象 rule ファイルへ反映する (#797)
#
# .claude/rules/*.md は HO 対象（.claude/rules/mode-classification.md
# Hardening Override 対象パス）。AI は --dry-run のみ実行可。--apply の
# 実行は Human-owned（.claude/rules/responsibility-classes.md）。
#
# 背景: #797 で UI 専用 V-1（visual evidence 規約）を acceptance-review
# skill（skill 層 = 非 HO・ソフト強制）に新設した。doc 専用 V-1
# （mode-classification.md 内 = HO・mode 機構に結線）とは「発想が対称・
# placement は意図的に非対称」の兄弟規約であり、mode-classification.md の
# 「doc 専用 V-1 の観点」節の直後にクロスリファレンス 1 行を挿入して相互
# 発見性を確保する（#796 apply-diff-audit-rename.sh と同型の Human 適用方式）。
#
# Usage:
#   sh scripts/apply-ui-v1-crossref.sh --dry-run   # 差分プレビュー（書込なし）
#   sh scripts/apply-ui-v1-crossref.sh --apply     # 適用（Human 実行のみ）
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
F1="$ROOT/.claude/rules/mode-classification.md"

# 挿入アンカー: 「doc 専用 V-1 の観点」節の最終箇条書き行（一意）
ANCHOR='- 実行例の到達性（記載したコマンド・パスが実在する）'
# 挿入する 1 行（冪等性判定のマーカーを兼ねる）
CROSSREF='> UI 変更時の V-1 evidence 規約（PASS でも visual evidence 必須）は `acceptance-review` skill の「UI 変更時の visual evidence 規約」（#797）を参照（doc 専用 V-1 と発想が対称・placement は意図的に非対称の兄弟規約）。'

[ $# -eq 1 ] || { echo "usage: $0 --dry-run|--apply" >&2; exit 1; }
case "$1" in --dry-run|--apply) ;; *) echo "usage: $0 --dry-run|--apply" >&2; exit 1;; esac
[ -f "$F1" ] || { echo "[apply] ERROR: 対象ファイルが見つかりません: $F1" >&2; exit 1; }

# 冪等性チェック: クロスリファレンス行が既に存在すれば適用済みとして SKIP
if grep -qF 'UI 変更時の visual evidence 規約」（#797）' "$F1" 2>/dev/null; then
  echo "[apply] SKIP: 適用済み（#797 クロスリファレンスが既に存在）"
  exit 0
fi

# アンカー検証: 挿入位置が一意に定まらない場合は中断（誤位置挿入防止）
_n=$(grep -cF -- "$ANCHOR" "$F1" || true)
if [ "$_n" != "1" ]; then
  echo "[apply] ERROR: アンカー行が一意に見つかりません（count=$_n）: $ANCHOR" >&2
  echo "[apply]        mode-classification.md の「doc 専用 V-1 の観点」節を確認してください" >&2
  exit 1
fi

if [ "$1" = "--dry-run" ]; then
  echo "[dry-run] 挿入予定（.claude/rules/mode-classification.md）:"
  echo "--- アンカー行（この直後に空行 + 1 行挿入）---"
  grep -nF -- "$ANCHOR" "$F1"
  echo "--- 挿入内容 ---"
  printf '%s\n' "$CROSSREF"
  exit 0
elif [ "$1" = "--apply" ]; then
  # sed -i の互換性 (BSD/GNU) を避け、python3 で明示挿入する（#796 と同型）。
  PG_ANCHOR="$ANCHOR" PG_CROSSREF="$CROSSREF" python3 - "$F1" <<'PY'
import os, sys
f = sys.argv[1]
anchor = os.environ["PG_ANCHOR"]
crossref = os.environ["PG_CROSSREF"]
s = open(f, encoding="utf-8").read()
old = anchor + "\n"
new = anchor + "\n\n" + crossref + "\n"
assert s.count(old) == 1, "anchor not unique at apply time"
s = s.replace(old, new)
open(f, "w", encoding="utf-8", newline="\n").write(s)
print(f"[apply] {f}: 1 行挿入（#797 クロスリファレンス）")
PY
  echo "[apply] 次: sh scripts/sync-plugin-plangate.sh を実行して plugin/plangate/rules/ へ伝播してください"
  exit 0
fi
echo "usage: $0 --dry-run|--apply" >&2; exit 1
