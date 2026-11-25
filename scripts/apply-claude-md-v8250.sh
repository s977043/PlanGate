#!/bin/sh
# apply-claude-md-v8250.sh -- CLAUDE.md「最新リリース」節を v8.25.0 へ更新
#
# CLAUDE.md は Hardening Override (HO) 対象（self-mod guard）。AI は本スクリプトを
# 作成するだけで実行しない。--apply / --rollback の実行は Human-owned
# （.claude/rules/responsibility-classes.md）。
#
# 背景: v8.25.0（EH-3 の no-task セッションでの plan.md 初回作成許可 #1649 と、
# plugin skill の検証規約の強化）のリリースに伴う「最新リリース」節の同期。
# 文面の出典: CHANGELOG.md の v8.25.0 節（収録範囲 v8.24.0..071198ba）。
# 本文の commit 数・PR 数・行数は 071198ba 時点の測定値であり、契約値ではない。
# 収録範囲が伸びた場合は CHANGELOG と本文の数値・SHA を測り直してから適用する。
#
# 置き換え対象: 「最新リリース」節が v8.24.0 の見出しのもの、または v8.25.0 の
# 見出しで本文が古いもの。どちらでもなければ形式変更とみなして止まる。
#
# リリース日は下の RELEASE_DATE で持つ。TBD のままでは --apply を拒否する
# （v8.22.0 で準備日のまま適用し、実リリース日へ直す追加スクリプトが要った再発防止）。
# tag を切る日に Human が YYYY-MM-DD へ直す。
#
# Usage:
#   sh scripts/apply-claude-md-v8250.sh --dry-run    # 差分プレビュー（書込なし）
#   sh scripts/apply-claude-md-v8250.sh --apply      # 適用（Human 実行のみ）
#   sh scripts/apply-claude-md-v8250.sh --verify     # 適用後の述語を検査
#   sh scripts/apply-claude-md-v8250.sh --rollback   # v8.24.0 tag 時点の節へ戻す（Human 実行のみ）
#
# --apply / --rollback は origin/main から切った feature ブランチでのみ動く
# （main への直接 commit は禁止）。適用後は commit → PR → C-4 → merge。
# 検証用に対象ファイルを PLANGATE_APPLY_FILE で上書きできる（その場合はブランチ検査を省く）。
# 本スクリプトは commit も push もしない。他の apply スクリプトと連結実行しない。
set -eu
ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
F="${PLANGATE_APPLY_FILE:-${ROOT}/CLAUDE.md}"
RELEASE_DATE="TBD"
PREV_TAG="v8.24.0"
usage() { echo "usage: $0 --dry-run|--apply|--verify|--rollback" >&2; exit 1; }
[ $# -eq 1 ] || usage
case "$1" in --dry-run|--apply|--verify|--rollback) ;; *) usage ;; esac
MODE="$1"
die() { printf 'ABORT: %s\n' "$*" >&2; exit 1; }

command -v python3 >/dev/null 2>&1 || die "python3 required"
[ -f "${F}" ] || die "${F} が存在しない"

if [ -z "${PLANGATE_APPLY_FILE:-}" ] && { [ "${MODE}" = "--apply" ] || [ "${MODE}" = "--rollback" ]; }; then
  br=$(git -C "${ROOT}" rev-parse --abbrev-ref HEAD)
  case "${br}" in
    HEAD|main|master|release/*) die "origin/main から切った feature ブランチで実行すること（現在: ${br}）" ;;
  esac
  git -C "${ROOT}" fetch -q origin || die "origin の fetch に失敗"
  git -C "${ROOT}" merge-base --is-ancestor origin/main HEAD || die "origin/main から分岐していない（git merge origin/main か作り直しが要る）"
  dirty=$(git -C "${ROOT}" status --porcelain \
    | grep -v 'docs/working/_audit/skip-decision-log.jsonl' \
    | grep -vF -- 'CLAUDE.md' || true)
  [ -z "${dirty}" ] || { printf '%s\n' "${dirty}" >&2; die "未コミットの変更がある"; }
fi

PREV_SECTION_FILE=""
if [ "${MODE}" = "--rollback" ]; then
  git -C "${ROOT}" rev-parse -q --verify "refs/tags/${PREV_TAG}" >/dev/null || die "tag ${PREV_TAG} がローカルに無い（git fetch --tags origin）"
fi

TMP=$(mktemp "${TMPDIR:-/tmp}/claude-md-v8250.XXXXXX")
PREV=$(mktemp "${TMPDIR:-/tmp}/claude-md-v8240.XXXXXX")
trap 'rm -f "${TMP}" "${PREV}"' EXIT INT TERM
if [ "${MODE}" = "--rollback" ]; then
  git -C "${ROOT}" show "${PREV_TAG}:CLAUDE.md" > "${PREV}" || die "${PREV_TAG}:CLAUDE.md を読めない"
  PREV_SECTION_FILE="${PREV}"
fi

export F TMP MODE RELEASE_DATE PREV_SECTION_FILE
rc=0
python3 - <<'PY' || rc=$?
import os, re, sys

f, tmp, mode, date = os.environ["F"], os.environ["TMP"], os.environ["MODE"], os.environ["RELEASE_DATE"]
prev_file = os.environ.get("PREV_SECTION_FILE", "")

OLD_HEAD = "## v8.24.0 計画レビューの対話フィードバックと Ratchet の実差分判定（最新リリース機能）"
NEW_HEAD = "## v8.25.0 EH-3 の plan.md 初回作成許可と検証規約の強化（最新リリース機能）"
NEW_BODY = (
    "> 最新リリース: **v8.25.0**（" + date + "）v8.24.0 タグ以降に main へ蓄積した 64 コミット・PR 64 件を反映"
    "（`071198ba` 時点の測定値。実測: `git rev-list --count v8.24.0..071198ba`）。"
    "主題は **no-task セッションで ai-loop の入口（plan.md の初回作成）を塞がないこと**・"
    "**「通った」の根拠を CI と同じ経路と変更前後の差に置くこと**・"
    "**plugin の試し方・成功確認・やめ方を導入経路ごとに分けること**。主要変更: "
    "**EH-3 の no-task 経路で未承認 TASK の plan.md 初回作成を許可**（#1649 / #1197 案 B。"
    "`Write` で `docs/working/TASK-<id>/plan.md` を新規作成し、全 worktree と git 履歴に承認記録も plan.md も無い等の条件を"
    "すべて満たすときだけ `PLAN_CREATE_ALLOW` で rc=0。既存 plan.md の改変・Edit・Bash 経路は従来どおり。"
    "`scripts/hooks/check-plan-hash.sh` +139 行。hook を配線した上流 repo のみが対象で、plugin 配布物に hook は含まれない）・"
    "**plugin skill の検証規約の強化**（#1631 / #1638。変更前のコードでも満たされる期待値は証拠として無効〔WARN、置換できなければ FAIL〕・"
    "lint / test は CI が実際に呼ぶコマンド経由・`ai-dev-verify` の導入先 settings タスクロックを `N/A` から「停止し degrade を記録」へ）・"
    "**plugin README の導入経路・成功確認・撤去手順**（#1625 / #1628 / #1637。Marketplace を推奨に一本化、"
    "Codex は `codex plugin marketplace add` の後に `codex plugin add` が要る、`install.sh --uninstall` の既知の問題 #1636）・"
    "**plugin 同期スクリプトの fail-open の是正**（#1582 / #1584 / #1610）・"
    "**`release-prep.sh --check` が作業ツリーに書き込まないように**（#1580 / #1496）・"
    "**`pre-push.sample` の helper に stdin を渡さない**（#1570 / #1558。インストール済みの hook は再インストールが要る）・"
    "**ai-loop V2 の canon I1 例外の失効と I4 への移行**（#1650。PR テンプレートに I4 evidence のチェック項目）・"
    "**CI の flake 是正と GitHub Actions の更新**（#1569 / #1571 / #1577 / #1579、#1568 / #1590 / #1613 / #1629 / #1645 / #1661）。"
    "**`bin/plangate` と `schemas/` は変更ゼロ**。破壊的変更を宣言した commit は 0 件。semver は **minor（Human 決定 2026-11-25）**。"
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
    if "071198ba" not in NEW_BODY or "#1649" not in NEW_BODY:
        ng.append("本文に収録範囲の基点 071198ba / #1649 が無い")
    if "（TBD）" in "".join(found):
        ng.append("リリース日が TBD のまま")
    for w in KEEP:
        if w not in text:
            ng.append("承認境界の節が欠けている: " + w)
    return ng

def check_keep(text):
    return ["承認境界の節が欠けている: " + w for w in KEEP if w not in text]

if mode == "--verify":
    ng = verify(s)
    for m in ng:
        print("  NG  " + m, file=sys.stderr)
    if ng:
        sys.exit(1)
    print("  ok  最新リリース節は v8.25.0（1 個・本文一致）・旧見出し 0・日付確定・承認境界の節 %d 件を確認" % len(KEEP))
    sys.exit(0)

found = PAT.findall(s)
if len(found) != 1:
    print("FAIL: 「最新リリース」節が 1 個ではない（形式変更の可能性）", file=sys.stderr)
    sys.exit(1)
m = PAT.search(s)
cur = m.group(0)

if mode == "--rollback":
    prev = open(prev_file, encoding="utf-8").read()
    pf = PAT.findall(prev)
    if len(pf) != 1 or not pf[0].startswith(OLD_HEAD + "\n"):
        print("FAIL: v8.24.0 tag の CLAUDE.md から v8.24.0 の最新リリース節を 1 個取り出せない", file=sys.stderr)
        sys.exit(1)
    if cur == pf[0]:
        print("SKIP: 既に v8.24.0 の節（rollback 済み）")
        sys.exit(3)
    if not cur.startswith(NEW_HEAD + "\n"):
        print("FAIL: 現在の最新リリース節が v8.25.0 ではない: " + cur.split("\n", 1)[0], file=sys.stderr)
        sys.exit(1)
    out = s[:m.start()] + pf[0] + s[m.end():]
    ng = check_keep(out)
    if NEW_HEAD in out:
        ng.append("rollback 後も v8.25.0 の見出しが残っている")
    if ng:
        for x in ng:
            print("  NG  " + x, file=sys.stderr)
        sys.exit(1)
    open(tmp, "w", encoding="utf-8", newline="\n").write(out)
    sys.exit(0)

if found[0] == NEW_SECTION:
    print("SKIP: 適用済み（本文まで一致）")
    sys.exit(3)
if not (cur.startswith(OLD_HEAD + "\n") or cur.startswith(NEW_HEAD + "\n")):
    print("FAIL: 置き換え対象の見出しではない（v8.24.0 / v8.25.0 のどちらでもない）: " + cur.split("\n", 1)[0], file=sys.stderr)
    sys.exit(1)
if s.count(OLD_HEAD) + s.count(NEW_HEAD) != 1:
    print("FAIL: v8.24.0 / v8.25.0 の見出しが合わせて 1 個ではない", file=sys.stderr)
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
case "${rc}" in
  0) ;;
  3) exit 0 ;;
  *) exit "${rc}" ;;
esac
[ "${MODE}" = "--verify" ] && exit 0

case "${MODE}" in
  --dry-run)
    echo "[dry-run] 書込なし（RELEASE_DATE=${RELEASE_DATE}）。差分:"
    diff -u "${F}" "${TMP}" || true
    ;;
  --apply)
    cp "${TMP}" "${F}"
    echo "[apply] CLAUDE.md の最新リリース節を v8.25.0 へ更新しました（Human 実行前提）。続けて --verify を実行してください"
    ;;
  --rollback)
    cp "${TMP}" "${F}"
    echo "[rollback] CLAUDE.md の最新リリース節を ${PREV_TAG} の内容へ戻しました。git diff -- CLAUDE.md で確認してください"
    ;;
esac
