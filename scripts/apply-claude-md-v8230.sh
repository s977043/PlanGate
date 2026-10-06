#!/bin/sh
# apply-claude-md-v8230.sh -- CLAUDE.md「最新リリース」節を v8.23.0 へ更新
#
# CLAUDE.md は Hardening Override (HO) 対象（self-mod guard）。AI は --dry-run と
# --verify のみ実行可。--apply の実行は Human-owned（.claude/rules/responsibility-classes.md）。
#
# 背景: v8.23.0（Intent Context Package v1 / Context Lifecycle / ai-loop V2 の
# Delivery runtime・Ratchet・Runtime Evidence / bin/plangate の C-3 判定の共通化と
# 対象 repo の解決）のリリースに伴う「最新リリース」節の同期。
# 文面の出典: CHANGELOG.md の v8.23.0 節（収録範囲 v8.22.0..61d3f14b）。
# 本文の commit 数・PR 数・行数は 61d3f14b 時点の測定値であり、契約値ではない。
#
# 置き換え対象: 「最新リリース」節が v8.22.0 の見出しのもの、または旧い値
# （33 コミット / db91ed16）で書かれた v8.23.0 の見出しのもの（PR #1439 が先に
# merge された場合）。どちらでもなければ形式変更とみなして止まる。
#
# リリース日は下の RELEASE_DATE で持つ。TBD のままでは --apply を拒否する
# （v8.22.0 では準備日 2026-09-11 のまま apply し、実リリース日 2026-09-23 へ
# 直す追加スクリプトが要った。その再発を防ぐ）。v8.23.0 は tag を切る日 2026-10-07 に確定した。
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
RELEASE_DATE="2026-10-07"
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
    "> 最新リリース: **v8.23.0**（" + date + "）v8.22.0 タグ以降に main へ蓄積した 198 コミット・PR 64 件を反映"
    "（`61d3f14b` 時点の測定値。実測: `git rev-list --count v8.22.0..61d3f14b`。"
    "PR 64 件のうち #1432 / #1433 / #1434 / #1498 はリリース準備）。"
    "主題は **Context の受け渡しを「会話の持ち越し」から「正本 artifact の参照」へ移すこと**・"
    "**ai-loop V2 の runtime / Runtime Evidence を最初に動かすこと**・"
    "**`bin/plangate` の C-3 判定を共通化し、導入先の repo を対象にできるようにすること**。主要変更: "
    "**Intent Context Package v1 の契約**（#1396。新規 schema `intent-context-package.schema.json`）・"
    "**Dynamic Context Engine からの参照**（#1404。`context-manifest.schema.json` に任意フィールド `intent_context`）・"
    "**Context Lifecycle の fresh-context 方針**（#1411。worker / model / runtime の切り替え・独立レビューの開始・"
    "worker 間の引き継ぎでは、会話を持ち越さず正本の state を checkpoint してから fresh context で再開する。"
    "standard 以上で必須・ultra-light / light では任意。**plugin の `working-context` / `context-packager` skill を含む**）・"
    "**Plan Contract と Intent Context の意味上の束縛**（#1405。authoritative な情報源の矛盾が未解消なら "
    "C-3' は AUTO_APPROVED を出さず fail-closed）・"
    "**ai-loop V2 の Delivery runtime・verification-skipped Ratchet・Runtime Evidence**（#1402 / #1409 / #1466。"
    "E2E 実行可能仕様は #1383 / PR #1387。外部 verifier の境界は candidate のまま repo 内からの自己昇格を許さず、"
    "Human が決める P0 decision packet は ADR-007 として Proposed（#1499））・"
    "**外部レビュー結果の正規化境界**（#1413）・**GPT-6 モデルプロファイルの実行経路への接続**"
    "（`--profile=` / `--mode=` は opt-in）・"
    "**`bin/plangate` の C-3 判定を status / validate / exec で共通化**（#1481 / #1492。壊れた legacy `c3.json` と "
    "dispatch の想定外 rc を fail-closed で止める）・"
    "**`bin/plangate` の既定の対象 repo を cwd の git root に**（#1497。決定順は `--project-root` > "
    "`PLANGATE_PROJECT_ROOT` > cwd の git root > CLI 本体の root。clone の外の git repo で実行すると対象が変わり、"
    "clone の外を対象にした `doctor --fix` は rc=2。従来の挙動は `--project-root <clone>`）・"
    "**`validate-schemas` の対象拡大**（`intent-context.json` / `plan-contract.json` / `plan-deliberation.json` が "
    "SKIP から検証へ）・**AI 運用 4 原則の文面の平易化**（#1414。承認が必要な範囲は不変）・"
    "**Plan Deliberation schema の正本化**（#1412 / #1494。新規 schema `plan-deliberation.schema.json`。"
    "#1414 と合わせて HO は #1433 で適用）。"
    "**`bin/plangate` は +279 / −106 行**、`schemas/` は追加と任意フィールド・enum 値の追加のみ（削除行 0）。"
    "破壊的変更を宣言した commit は 0 件。semver は **Human 裁定により minor**"
    "（#1497 は規約 §2.4 の major 候補だったが、#962 の不具合修正として minor）。"
    "**PlanGate 本番フロー WF-00〜07 は不変・NO MERGE BY AI／C-4・merge は Human-owned 固定**。"
    "リリース履歴の正本は [`CHANGELOG.md`](CHANGELOG.md)。"
)
NEW_SECTION = NEW_HEAD + "\n\n" + NEW_BODY + "\n"
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
    found = PAT.findall(text)
    if len(found) != 1:
        ng.append("「最新リリース」節が 1 個ではない")
    elif found[0] != NEW_SECTION:
        ng.append("「最新リリース」節の本文が本スクリプトの本文と一致しない（旧い値のままの可能性）")
    if "61d3f14b" not in NEW_BODY or "#1497" not in NEW_BODY:
        ng.append("本文に収録範囲の基点 61d3f14b / #1497 が無い")
    if "（TBD）" in "".join(found):
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
    print("  ok  最新リリース節は v8.23.0（1 個・本文一致）・旧見出し 0・日付確定・承認境界の節 %d 件を確認" % len(KEEP))
    sys.exit(0)

found = PAT.findall(s)
if len(found) != 1:
    print("FAIL: 「最新リリース」節が 1 個ではない（形式変更の可能性）", file=sys.stderr)
    sys.exit(1)
if found[0] == NEW_SECTION:
    print("SKIP: 適用済み（本文まで一致）")
    sys.exit(3)
m = PAT.search(s)
cur = m.group(0)
if not (cur.startswith(OLD_HEAD + "\n") or cur.startswith(NEW_HEAD + "\n")):
    print("FAIL: 置き換え対象の見出しではない（v8.22.0 / v8.23.0 のどちらでもない）: " + cur.split("\n", 1)[0], file=sys.stderr)
    sys.exit(1)
if s.count(OLD_HEAD) + s.count(NEW_HEAD) != 1:
    print("FAIL: v8.22.0 / v8.23.0 の見出しが合わせて 1 個ではない", file=sys.stderr)
    sys.exit(1)
out = s[:m.start()] + NEW_SECTION + s[m.end():]
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
