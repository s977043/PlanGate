#!/bin/sh
# apply-claude-md-v8220.sh -- CLAUDE.md「最新リリース」節を v8.22.0 へ更新
#
# CLAUDE.md は Hardening Override (HO) 対象（self-mod guard）。AI は --dry-run
# のみ実行可。--apply の実行は Human-owned（.claude/rules/responsibility-classes.md）。
#
# 背景: v8.22.0（承認境界ガードの判定精度 — EH-3 の worktree 素通りと
# EH-12 の誤検知の解消）のリリースに伴う「最新リリース」節の同期。
#
# 文面の出典: CHANGELOG.md の v8.22.0 節。
#
# Usage:
#   sh scripts/apply-claude-md-v8220.sh --dry-run   # 差分プレビュー（書込なし）
#   sh scripts/apply-claude-md-v8220.sh --apply     # 適用（Human 実行のみ）
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
F="$ROOT/CLAUDE.md"
[ $# -eq 1 ] || { echo "usage: $0 --dry-run|--apply" >&2; exit 1; }
case "$1" in --dry-run|--apply) ;; *) echo "usage: $0 --dry-run|--apply" >&2; exit 1 ;; esac

OLD_HEAD="## v8.21.0 参照解決順とガード迂回の是正（最新リリース機能）"
NEW_HEAD="## v8.22.0 承認境界ガードの判定精度（最新リリース機能）"
NEW_BODY="> 最新リリース: **v8.22.0**（2026-09-11）v8.21.0 タグ以降に main へ蓄積した 102 コミットを反映（実測: \`git rev-list --count v8.21.0..319d6121\`）。主題は **承認境界ガードの判定精度** — 「文字列で近似する」実装から「トークン列で判定する」実装への作り直し。主要変更: **EH-3 が linked worktree 配下の Hardening Override を素通りさせていた穴の解消**（#1277。\`.claude/worktrees/<name>/\` のような REPO_ROOT **配下**の linked worktree と REPO_ROOT 外の worktree の双方で HO 12 カテゴリが block されていなかった。本リポジトリは linked worktree が 60 本以上あり、**承認境界が最も使われる経路で外れていた**。回帰網 \`ta-80\` は 40 → 52 TC で、TC-R05〜R08 が**実 hook**に対して assert する）・**EH-3 の残存欠陥 3 件**（#1278 の \`log_event\` fail-open 化 / #1234 の \`OUTSIDE_REPO_SKIP\` / #1226 の承認サーフェス台帳）・**EH-3 の Bash レーン配線と HO パス正規化**（#1104 / #1101。\`bin/../bin/plangate\` のような別表記による迂回を封鎖）・**EH-12 の判定を同一コマンドのトークン列へ限定**（#1326。\`git push\` のトークン列に属さない \`--force\` / \`+\` を拾い、\`echo\` の引数やコミットメッセージのような**実行されない文字列**でも block していた。\`;\` \`&&\` \`||\` \`|\` \`&\` と**物理改行**でセグメント分割し、先頭語が \`git\` そのもののときだけ精密解析へ入る。それ以外は**従来の部分文字列判定へ落とす fail-closed**。実 hook 44 ケースの対照で**本物の破壊的操作 32 件は是正前後とも 32/32 BLOCK**・非破壊 12 件が 6 件の誤 block → 0 件。回帰網 \`ta-86\` を 56 TC で新設）・**EH-13 配線の回帰防止**（#1259。\`EH-13-EDIT\` / \`-WRITE\` を \`TRACKED_FAIL\` として登録し \`ta-83\` で gate の liveness を固定）・**承認の適用順の明示**（#1318。\`<law>\` 直後に 5 段。**各層を弱めず順序だけを定める**）・**version bump ゲートのリリース時配線**（#1257。\`plugin/\` に差分があるのに version が据え置きなら NOT READY。**bump しないと \`/plugin update\` は no-op で consumer に 1 件も届かない**）・**ai-dev ワークフローの実行資材を plugin へ同梱**（#1232）・**\`.codex/skills\` の drift 検査を push レーンへ拡張**（#1288。従来は \`pull_request\` でしか走らず main に drift が入っても main の CI は緑のままだった）・**ai-loop V2 Phase 0.1 完了**（#1275。canon docs 自身の Independence Level は I1 を**明示的な例外**とし、**失効条件 M-1 / M-2 / M-3 を判定コマンド + baseline つきで定義**。follow-up は #1329）・**\`ho-apply-script\` skill の新設**（#1316。HO 適用の型と**実際に踏んだ落とし穴 11 件**）。**\`bin/plangate\` は変更ゼロ**、\`schemas/\` は \`review-result.schema.json\` の説明文 1 行のみ（Schema / CLI の挙動は不変）。**\`scripts/hooks/\` / \`scripts/check-git-destructive.sh\` を配線している利用者は block 挙動が変わる**（plugin 配布物には含まれない）。semver は v8.21.0 と同型の材料で **Human 裁定により minor**。**PlanGate 本番フロー WF-00〜07 は不変・NO MERGE BY AI／C-4・merge は Human-owned 固定**。リリース履歴の正本は [\`CHANGELOG.md\`](CHANGELOG.md)。"

command -v python3 >/dev/null 2>&1 || { echo "python3 required" >&2; exit 1; }
[ -f "$F" ] || { echo "FAIL: $F が存在しない" >&2; exit 1; }
grep -qF "$NEW_HEAD" "$F" && { echo "SKIP: 適用済み（新見出しが既に存在）"; exit 0; }
grep -qF "$OLD_HEAD" "$F" || { echo "FAIL: 旧見出しが見つからない（適用済み or 形式変更）" >&2; exit 1; }

TMP=$(mktemp "${TMPDIR:-/tmp}/claude-md-v8220.XXXXXX")
trap 'rm -f "$TMP"' EXIT INT TERM

export OLD_HEAD NEW_HEAD NEW_BODY F TMP
python3 - <<'PY'
import os, re, sys
f = os.environ['F']
s = open(f, encoding='utf-8').read()
old_head = os.environ['OLD_HEAD']; new_head = os.environ['NEW_HEAD']; new_body = os.environ['NEW_BODY']
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
