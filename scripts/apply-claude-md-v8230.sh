#!/bin/sh
# DRAFT (未 commit): scripts/apply-claude-md-v8230.sh として置く想定。
# repo への Write が EH-3（SKIP_REASON 未設定）で block されたため scratchpad に退避した。
#
# apply-claude-md-v8230.sh -- CLAUDE.md「最新リリース」節を v8.23.0 へ更新
#
# CLAUDE.md は Hardening Override (HO) 対象（self-mod guard）。AI は --dry-run と
# --verify のみ実行可。--apply の実行は Human-owned（.claude/rules/responsibility-classes.md）。
#
# 背景: v8.23.0（Intent Context Package v1 / Context Lifecycle / ai-loop V2 の
# Delivery runtime と Ratchet）のリリースに伴う「最新リリース」節の同期。
# 文面の出典: CHANGELOG.md の v8.23.0 節。
#
# リリース日は下の RELEASE_DATE で持つ。TBD のままでは --apply を拒否する
# （v8.22.0 では準備日 2026-09-11 のまま apply し、実リリース日 2026-09-23 へ
# 直す追加スクリプトが要った。その再発を防ぐ）。
#
# Usage:
#   sh scripts/apply-claude-md-v8230.sh --dry-run   # 差分プレビュー（書込なし）
#   sh scripts/apply-claude-md-v8230.sh --apply     # 適用（Human 実行のみ）
#   sh scripts/apply-claude-md-v8230.sh --verify    # 適用後の述語を検査
#
# 検証用に対象ファイルを PLANGATE_APPLY_FILE で上書きできる。
# 本スクリプトは commit も push もしない。
set -eu
ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
F="${PLANGATE_APPLY_FILE:-$ROOT/CLAUDE.md}"
RELEASE_DATE="TBD"
[ $# -eq 1 ] || { echo "usage: $0 --dry-run|--apply|--verify" >&2; exit 1; }
case "$1" in --dry-run|--apply|--verify) ;; *) echo "usage: $0 --dry-run|--apply|--verify" >&2; exit 1 ;; esac
MODE="$1"

command -v python3 >/dev/null 2>&1 || { echo "python3 required" >&2; exit 1; }
[ -f "$F" ] || { echo "FAIL: ${F} が存在しない" >&2; exit 1; }

TMP=$(mktemp "${TMPDIR:-/tmp}/claude-md-v8230.XXXXXX")
trap 'rm -f "$TMP"' EXIT INT TERM

export F TMP MODE RELEASE_DATE
rc=0
python3 - <<'PY' || rc=$?
import os, re, sys

f, tmp, mode, date = os.environ["F"], os.environ["TMP"], os.environ["MODE"], os.environ["RELEASE_DATE"]

OLD_HEAD = "## v8.22.0 承認境界ガードの判定精度（最新リリース機能）"
NEW_HEAD = "## v8.23.0 Intent Context と Context Lifecycle（最新リリース機能）"
NEW_BODY = (
    "> 最新リリース: **v8.23.0**（" + date + "）v8.22.0 タグ以降に main へ蓄積した 33 コミットを反映"
    "（実測: `git rev-list --count v8.22.0..db91ed16` は 34。リリース準備 commit #1432 を除く）。"
    "主題は **Context の受け渡しを「会話の持ち越し」から「正本 artifact の参照」へ移すこと**と、"
    "**ai-loop V2 の runtime を最初に動かすこと**。主要変更: "
    "**Intent Context Package v1 の契約**（#1396。新規 schema `intent-context-package.schema.json`）・"
    "**Dynamic Context Engine からの参照**（#1404。`context-manifest.schema.json` に任意フィールド `intent_context`）・"
    "**Context Lifecycle の fresh-context 方針**（#1411。worker / model / runtime の切り替え・独立レビューの開始・"
    "worker 間の引き継ぎでは、会話を持ち越さず正本の state を checkpoint してから fresh context で再開する。"
    "standard 以上で必須・ultra-light / light では任意。**plugin の `working-context` / `context-packager` skill を含む**）・"
    "**Plan Contract と Intent Context の意味上の束縛**（#1405。authoritative な情報源の矛盾が未解消なら "
    "C-3' は AUTO_APPROVED を出さず fail-closed）・"
    "**ai-loop V2 の Delivery runtime と verification-skipped Ratchet**（#1402 / #1409。E2E 実行可能仕様は #1383）・"
    "**外部レビュー結果の正規化境界**（#1413）・**GPT-6 モデルプロファイルの実行経路への接続**"
    "（`--profile=` / `--mode=` は opt-in）・**AI 運用 4 原則の文面の平易化**（#1414。承認が必要な範囲は不変）・"
    "**Plan Deliberation schema の正本化**（#1412。新規 schema `plan-deliberation.schema.json`。#1414 と合わせて HO は #1433 で適用）。"
    "**`bin/plangate` は変更ゼロ**、`schemas/` は追加のみ（削除行 0）。破壊的変更の commit は 0 件。"
    "semver は **Human 裁定により minor**。"
    "**PlanGate 本番フロー WF-00〜07 は不変・NO MERGE BY AI／C-4・merge は Human-owned 固定**。"
    "リリース履歴の正本は [`CHANGELOG.md`](CHANGELOG.md)。"
)
KEEP = [
    "<law>",
    "</law>",
    "### 承認境界の適用順（迷ったら上が勝つ）",
    "1. **HO（Hardening Override）対象パス** — 例外なく Human 適用。",
    "5. 上記のいずれにも当たらなければ、第 1 原則どおり y/n を取る",
]
PAT = re.compile(r"^## v[0-9.]+ [^\n]*（最新リリース機能）\n\n> 最新リリース:[^\n]*\n", re.M)

s = open(f, encoding="utf-8").read()

def verify(text):
    ng = []
    if text.count(NEW_HEAD) != 1:
        ng.append("新見出しが 1 個ではない")
    if OLD_HEAD in text:
        ng.append("旧見出しが残っている")
    if len(PAT.findall(text)) != 1:
        ng.append("「最新リリース」節が 1 個ではない")
    i = text.find(NEW_HEAD)
    body = text[i:text.find("\n", i + len(NEW_HEAD) + 2)] if i >= 0 else ""
    if "**v8.23.0**" not in body:
        ng.append("本文に **v8.23.0** が無い")
    if "（TBD）" in body:
        ng.append("リリース日が TBD のまま")
    for w in KEEP:
        if w not in text:
            ng.append("承認境界の節が欠けている: " + w)
    return ng

if mode == "--verify":
    ng = verify(s)
    for m in ng:
        print("  NG  " + m, file=sys.stderr)
    if ng:
        sys.exit(1)
    print("  ok  最新リリース節は v8.23.0（1 個）・旧見出し 0・日付確定・承認境界の節 %d 件を確認" % len(KEEP))
    sys.exit(0)

if s.count(NEW_HEAD) == 1 and OLD_HEAD not in s:
    print("SKIP: 適用済み（新見出しが既に存在）")
    sys.exit(3)
if s.count(OLD_HEAD) != 1:
    print("FAIL: 旧見出しが 1 個ではない（形式変更の可能性）", file=sys.stderr)
    sys.exit(1)
m = PAT.search(s)
if not m or not m.group(0).startswith(OLD_HEAD):
    print("FAIL: 旧本文パターン不一致", file=sys.stderr)
    sys.exit(1)
out = s[:m.start()] + NEW_HEAD + "\n\n" + NEW_BODY + "\n" + s[m.end():]
if mode == "--apply" and date == "TBD":
    print("FAIL: RELEASE_DATE が TBD のまま。スクリプト冒頭の RELEASE_DATE を実リリース日（YYYY-MM-DD）へ直してから --apply する", file=sys.stderr)
    sys.exit(1)
ng = [x for x in verify(out) if not (date == "TBD" and x == "リリース日が TBD のまま")]
if ng:
    for x in ng:
        print("  NG  " + x, file=sys.stderr)
    sys.exit(1)
open(tmp, "w", encoding="utf-8", newline="\n").write(out)
PY
case "$rc" in
  0) ;;
  3) exit 0 ;;
  *) exit "$rc" ;;
esac
[ "$MODE" = "--verify" ] && exit 0

case "$MODE" in
  --dry-run)
    echo "[dry-run] 書込なし（RELEASE_DATE=${RELEASE_DATE}）。差分:"
    diff -u "$F" "$TMP" || true
    ;;
  --apply)
    cp "$TMP" "$F"
    echo "[apply] CLAUDE.md の最新リリース節を v8.23.0 へ更新しました（Human 実行前提）。続けて --verify を実行してください"
    ;;
esac
