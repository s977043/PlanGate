#!/bin/sh
# apply-claude-md-v8190.sh -- CLAUDE.md「最新リリース」節を v8.19.0 へ更新
#
# CLAUDE.md は Hardening Override (HO) 対象（self-mod guard）。AI は --dry-run
# のみ実行可。--apply の実行は Human-owned（.claude/rules/responsibility-classes.md）。
#
# 背景: v8.19.0（承認境界ガード EH-13 の fail-closed 化 + 破壊的 git 操作ガード
# EH-12 + tests/extras 共有 exit 契約）のリリースに伴う「最新リリース」節の同期。
#
# 文面の出典: docs/working/_merge/v8.19.0-release-runbook.md §3 Step 2 の推奨文面。
#   ただし同 runbook は #1045 マージ（#1069）より前に書かれており推奨文面に
#   #1045 が含まれていないため、CHANGELOG.md v8.19.0 §Fixed に合わせて
#   「EH-13 の読み取り誤 block の解消（#1045/#1069）」の 1 句のみ追記している。
#   この 1 句が不要なら NEW_BODY から当該句を削って実行してよい。
#
# Usage:
#   sh scripts/apply-claude-md-v8190.sh --dry-run   # 差分プレビュー（書込なし）
#   sh scripts/apply-claude-md-v8190.sh --apply     # 適用（Human 実行のみ）
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
F="$ROOT/CLAUDE.md"
[ $# -eq 1 ] || { echo "usage: $0 --dry-run|--apply" >&2; exit 1; }
case "$1" in --dry-run|--apply) ;; *) echo "usage: $0 --dry-run|--apply" >&2; exit 1 ;; esac

OLD_HEAD="## v8.18.0 実 PR 収束（MERGE_READY）の一気通貫（最新リリース機能）"
NEW_HEAD="## v8.19.0 承認境界ガードの fail-closed 化（最新リリース機能）"
NEW_BODY="> 最新リリース: **v8.19.0**（2026-08-13）v8.18.0 タグ以降に main へ蓄積した 65 マージ（+65.5k 行）を反映。主要変更: **EH-13 承認トークン書き込みガードの fail-closed 化**（#1023/#1042。block を exit 1 → **exit 2**・stdin 常時独立評価・jq 不在 / malformed を parse-unknown として block。**\`jq\` が実質必須**）・**EH-13 の読み取り誤 block の解消**（#1045/#1069。\`2>/dev/null\` 等の fd 複製・破棄を書き込み判定から除外）・**EH-12 protected branch 上の破壊的 git 操作ガード**（#967/#985。配線は \`scripts/apply-eh-git-destructive-guard.sh --apply\` = Human-owned）・**tests/extras 共有 exit 契約**による「静かに通る失敗」の封鎖（#921 Slice 1 / #1046）・**plugin skill 参照解決の 3 段フォールバック化**（#954 系。Codex 経由導入で解決不能だった相対リンクを是正）。**PlanGate 本番フロー WF-00〜07 は不変・NO MERGE BY AI／C-4・merge は Human-owned 固定**。リリース履歴の正本は [\`CHANGELOG.md\`](CHANGELOG.md)。"

command -v python3 >/dev/null 2>&1 || { echo "python3 required" >&2; exit 1; }
[ -f "$F" ] || { echo "FAIL: $F が存在しない" >&2; exit 1; }
grep -qF "$NEW_HEAD" "$F" && { echo "SKIP: 適用済み（新見出しが既に存在）"; exit 0; }
grep -qF "$OLD_HEAD" "$F" || { echo "FAIL: 旧見出しが見つからない（適用済み or 形式変更）" >&2; exit 1; }

TMP=$(mktemp "${TMPDIR:-/tmp}/claude-md-v8190.XXXXXX")
trap 'rm -f "$TMP"' EXIT INT TERM

export OLD_HEAD NEW_HEAD NEW_BODY F TMP
python3 - <<'PY'
import os, re, sys
f = os.environ['F']
s = open(f, encoding='utf-8').read()
old_head = os.environ['OLD_HEAD']; new_head = os.environ['NEW_HEAD']; new_body = os.environ['NEW_BODY']
# 旧節 = 旧見出し行 + 直後の「> 最新リリース:」段落（次の空行まで）を置換
pat = re.compile(re.escape(old_head) + r"\n\n> 最新リリース:[^\n]*\n")
m = pat.search(s)
if not m:
    print("FAIL: 旧本文パターン不一致", file=sys.stderr); sys.exit(1)
new = new_head + "\n\n" + new_body + "\n"
out = s[:m.start()] + new + s[m.end():]
open(os.environ['TMP'], 'w', encoding='utf-8', newline='\n').write(out)
print("--- 置換プレビュー（新見出し + 本文先頭 260 字）---")
print(new[:260])
PY

case "$1" in
  --dry-run)
    echo "[dry-run] 書込なし。差分:"
    diff -u "$F" "$TMP" | head -30 || true
    ;;
  --apply)
    cp "$TMP" "$F"
    echo "[apply] CLAUDE.md を更新しました（Human 実行前提）"
    ;;
esac
