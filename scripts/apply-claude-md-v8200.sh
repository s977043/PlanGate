#!/bin/sh
# apply-claude-md-v8200.sh -- CLAUDE.md「最新リリース」節を v8.20.0 へ更新
#
# CLAUDE.md は Hardening Override (HO) 対象（self-mod guard）。AI は --dry-run
# のみ実行可。--apply の実行は Human-owned（.claude/rules/responsibility-classes.md）。
#
# 背景: v8.20.0（配布経路の false green 是正 — Codex plugin registered 判定 /
# skill frontmatter 破損 / Codex CLI parity の実測化）のリリースに伴う
# 「最新リリース」節の同期。
#
# 文面の出典: CHANGELOG.md の v8.20.0 節および
#   docs/working/_merge/v8.20.0-release-runbook.md §0「このリリースの要点」。
#
# Usage:
#   sh scripts/apply-claude-md-v8200.sh --dry-run   # 差分プレビュー（書込なし）
#   sh scripts/apply-claude-md-v8200.sh --apply     # 適用（Human 実行のみ）
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
F="$ROOT/CLAUDE.md"
[ $# -eq 1 ] || { echo "usage: $0 --dry-run|--apply" >&2; exit 1; }
case "$1" in --dry-run|--apply) ;; *) echo "usage: $0 --dry-run|--apply" >&2; exit 1 ;; esac

OLD_HEAD="## v8.19.0 承認境界ガードの fail-closed 化（最新リリース機能）"
NEW_HEAD="## v8.20.0 配布経路の false green 是正（最新リリース機能）"
NEW_BODY="> 最新リリース: **v8.20.0**（2026-08-14）v8.19.0 タグ以降に main へ蓄積した 7 マージを反映。主題は **「緑を出していた検出器が、実際には別のものを測っていた」箇所の実測是正**。主要変更: **Codex plugin の \`registered: YES\` false green を解消**（#1085/#1090。marketplace cache ディレクトリの存在ではなく \`config.toml\` の \`enabled\` 宣言 + \`plugins/cache\` 実体で判定）・**Codex 用 plugin マニフェスト \`plugin/plangate/.codex-plugin/plugin.json\` の新設と parity 機械検出**（#1085。\`scripts/check-plugin-manifest-parity.sh\` を \`release-prep.sh --check\` へ配線）・**skill frontmatter 破損を 4 root で同時是正 + YAML パース検査の CI 経路化**（#1084。導入先で skill が読み込まれない状態の解消）・**\`docs/ai/settings-wiring-contract.md\` §Codex CLI parity を「強制力 0/11」へ再是正**（#1078/#1080/#1083。実走スパイク #1082 / payload 実測 #1088 が根拠）。**\`schemas/*.json\` / \`bin/plangate\` / \`scripts/hooks/*.sh\` / \`.github/workflows/*\` は変更ゼロ**（Schema / CLI / Hook の挙動は不変）。**既知の未解消ギャップ: EH-3 の HO 迂回（#1089）は patch と回帰テストのみ同梱し hook 本体は未適用**（適用は \`sh scripts/apply-eh3-ho-always.sh --apply\` = Human-owned。適用後は \`tests/fixtures/eh3-known-gap-1089.flag\` を削除すること）。**PlanGate 本番フロー WF-00〜07 は不変・NO MERGE BY AI／C-4・merge は Human-owned 固定**。リリース履歴の正本は [\`CHANGELOG.md\`](CHANGELOG.md)。"

command -v python3 >/dev/null 2>&1 || { echo "python3 required" >&2; exit 1; }
[ -f "$F" ] || { echo "FAIL: $F が存在しない" >&2; exit 1; }
grep -qF "$NEW_HEAD" "$F" && { echo "SKIP: 適用済み（新見出しが既に存在）"; exit 0; }
grep -qF "$OLD_HEAD" "$F" || { echo "FAIL: 旧見出しが見つからない（適用済み or 形式変更）" >&2; exit 1; }

TMP=$(mktemp "${TMPDIR:-/tmp}/claude-md-v8200.XXXXXX")
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
