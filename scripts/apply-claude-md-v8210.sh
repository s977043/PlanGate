#!/bin/sh
# apply-claude-md-v8210.sh -- CLAUDE.md「最新リリース」節を v8.21.0 へ更新
#
# CLAUDE.md は Hardening Override (HO) 対象（self-mod guard）。AI は --dry-run
# のみ実行可。--apply の実行は Human-owned（.claude/rules/responsibility-classes.md）。
#
# 背景: v8.21.0（参照解決順の空振り段の除去 / EH-3・EH-13 のガード迂回封鎖）の
# リリースに伴う「最新リリース」節の同期。
#
# 文面の出典: CHANGELOG.md の v8.21.0 節および
#   docs/working/_merge/v8.21.0-release-runbook.md §0「このリリースの要点」。
#
# Usage:
#   sh scripts/apply-claude-md-v8210.sh --dry-run   # 差分プレビュー（書込なし）
#   sh scripts/apply-claude-md-v8210.sh --apply     # 適用（Human 実行のみ）
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
F="$ROOT/CLAUDE.md"
[ $# -eq 1 ] || { echo "usage: $0 --dry-run|--apply" >&2; exit 1; }
case "$1" in --dry-run|--apply) ;; *) echo "usage: $0 --dry-run|--apply" >&2; exit 1 ;; esac

OLD_HEAD="## v8.20.0 配布経路の false green 是正（最新リリース機能）"
NEW_HEAD="## v8.21.0 参照解決順とガード迂回の是正（最新リリース機能）"
NEW_BODY="> 最新リリース: **v8.21.0**（2026-08-19）v8.20.0 タグ以降に main へ蓄積した 42 コミットを反映（実測: \`git rev-list --count v8.20.0..645220b\`）。主題は **「参照はあるが解決されない」「ガードはあるが迂回できる」構造の実測是正**。主要変更: **skill の参照解決順から構造上必ず空振りする plugin root 段を除去**（#954。計 41 ファイル。\`docs/**\` は \`sync-plugin-plangate.sh\` の設計上 plugin の配布対象外のため常に解決されない手順だった）・**不在 rules 参照の張り替えと正本宣言の 4 root 統一**（#1123/#1125/#1126/#1127）・**EH-3 の Hardening Override 迂回の解消**（#1089。\`PLANGATE_HOOK_TASK\` 設定下では HO 9 カテゴリすべてが block されず、PlanGate 作業中のセッションこそ保護が外れていた。適用済みのため \`tests/fixtures/eh3-known-gap-1089.flag\` は削除）・**EH-13 承認トークンガードの迂回 2 クラス封鎖**（#1115 の外側ゲート ワイルドカード迂回＝実測 21 コマンドが素通り / #1110 のリダイレクト相関判定。fail-closed は不変）・**C-1 セルフレビュー項目数を実体（全 25 項目）へ是正**（#960）。**\`schemas/*.json\` / \`bin/plangate\` は変更ゼロ**（Schema / CLI の挙動は不変）。**block 挙動の強化は \`scripts/hooks/\` を配線している利用者に影響**（plugin 配布物には含まれない）。semver は規約 §2.2 上 major の材料を含むが **Human 裁定で minor**（経緯は [\`docs/working/_merge/v8.21.0-release-runbook.md\`](docs/working/_merge/v8.21.0-release-runbook.md) §1）。**PlanGate 本番フロー WF-00〜07 は不変・NO MERGE BY AI／C-4・merge は Human-owned 固定**。リリース履歴の正本は [\`CHANGELOG.md\`](CHANGELOG.md)。"

command -v python3 >/dev/null 2>&1 || { echo "python3 required" >&2; exit 1; }
[ -f "$F" ] || { echo "FAIL: $F が存在しない" >&2; exit 1; }
grep -qF "$NEW_HEAD" "$F" && { echo "SKIP: 適用済み（新見出しが既に存在）"; exit 0; }
grep -qF "$OLD_HEAD" "$F" || { echo "FAIL: 旧見出しが見つからない（適用済み or 形式変更）" >&2; exit 1; }

TMP=$(mktemp "${TMPDIR:-/tmp}/claude-md-v8210.XXXXXX")
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
