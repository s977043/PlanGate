#!/bin/sh
# apply-claude-md-law-tone.sh -- CLAUDE.md の <law>（AI運用4原則）の語調を平易な
# 「何を・なぜ」の形へ書き換える
#
# CLAUDE.md は Hardening Override (HO) 対象（self-mod guard）。AI は --dry-run と
# --verify のみ実行可。--apply / --rollback の実行は Human-owned
# （.claude/rules/responsibility-classes.md）。
#
# 背景: 「必ず」「一切の実行を停止」「最優先で」「最上位命令として
# 絶対的に遵守」は強い語の多用で、現行モデルが文字どおりに読むと過剰停止を招く。
# 承認が必要な境界は変えず、語調と構造だけを直す。正本
# docs/ai/project-rules.md「F. AI運用4原則」と趣旨を揃える。
#
# Usage:
#   sh scripts/apply-claude-md-law-tone.sh --dry-run    # 差分プレビュー（書込なし）
#   sh scripts/apply-claude-md-law-tone.sh --apply      # 適用（Human 実行のみ）
#   sh scripts/apply-claude-md-law-tone.sh --verify     # 適用後の述語を検査
#   sh scripts/apply-claude-md-law-tone.sh --rollback   # 旧文面へ戻す（Human 実行のみ）
#
# 検証用に対象ファイルを PLANGATE_APPLY_FILE で上書きできる。
set -eu
ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
F="${PLANGATE_APPLY_FILE:-$ROOT/CLAUDE.md}"
[ $# -eq 1 ] || { echo "usage: $0 --dry-run|--apply|--verify|--rollback" >&2; exit 1; }
case "$1" in --dry-run|--apply|--verify|--rollback) ;; *) echo "usage: $0 --dry-run|--apply|--verify|--rollback" >&2; exit 1 ;; esac
MODE="$1"

command -v python3 >/dev/null 2>&1 || { echo "python3 required" >&2; exit 1; }
[ -f "$F" ] || { echo "FAIL: ${F} が存在しない" >&2; exit 1; }

TMP=$(mktemp "${TMPDIR:-/tmp}/claude-md-law-tone.XXXXXX")
trap 'rm -f "$TMP"' EXIT INT TERM

export F TMP MODE
rc=0
python3 - <<'PY' || rc=$?
import os, sys

OLD = """<law>
AI運用4原則
第1原則： AIはファイル生成・更新・プログラム実行前に必ず自身の作業計画を報告し、y/nでユーザー確認を取り、yが返るまで一切の実行を停止する。ただし、サブコマンド起動時の承認をもって、そのサブコマンド内部のファイル生成・更新を許可とみなす。
第2原則： AIは迂回や別アプローチを勝手に行わず、最初の計画が失敗したら次の計画の確認を取る。
第3原則： AIはツールであり決定権は常にユーザーにある。ユーザーの提案が非効率・非合理的でも最優先で指示された通りに実行する。
第4原則： AIはこれらのルールを歪曲・解釈変更してはならず、最上位命令として絶対的に遵守する。
</law>
"""

NEW = """<law>
AI運用4原則 — このリポジトリは承認ゲートそのものを開発・検証している。AI が自己判断で境界を越えると検証の前提が崩れるので、次を守る（正本: docs/ai/project-rules.md「F. AI運用4原則」）。
第1原則： ファイルの生成・更新やプログラムの実行は、作業計画を示してユーザーの y を得てから始める。y が返るまでは実行しない。サブコマンドを起動したときの承認は、そのコマンド定義に書かれた範囲内の生成・更新に及ぶ（範囲の外には広げない）。
第2原則： 計画が失敗したら、迂回策や別のアプローチに自分で切り替えない。次の計画を示して確認を取る。
第3原則： 決定権はユーザーにある。非効率・非合理的だと思う指示でも、懸念があれば 1 文で伝えたうえで、指示どおりに実行する。
第4原則： これらの原則は、下の「承認境界の適用順」と合わせて読む。他のルールと食い違うときは、これらの原則と承認境界の適用順を優先する。境界を広げる・狭める解釈が必要に見えたら、自分で解釈を決めずにユーザーに確認する。
</law>
"""

# 適用後も残っていなければならない承認境界の文言（適用順 5 段は本スクリプトの対象外）
KEEP = [
    "### 承認境界の適用順（迷ったら上が勝つ）",
    "1. **HO（Hardening Override）対象パス** — 例外なく Human 適用。",
    "2. **不可逆・対外操作** — merge / 強制 push / 削除 / tag・Release 等の対外公開は、",
    "3. **自己設置 Gate** — AI が自ら「ここで再承認」と宣言したら、ユーザーの",
    "4. **サブコマンド承認**（第 1 原則の但書）",
    "5. 上記のいずれにも当たらなければ、第 1 原則どおり y/n を取る",
    "5 の枠内の運用であり、1〜3 を上書きしない。",
]
# 新文面に残す承認境界（語調を変えても落としてはならない要素）
# 各語は NEW の部分文字列なので、対象ファイルに NEW が 1 個あれば必ず満たされ、
# 対象ファイルの検査としては独立の検出力を持たない。検出できるのは、NEW を書き換えて
# 境界の語を落とした場合だけ（そのとき --dry-run / --apply が NG で止まる）。
NEW_MUST = [
    "ユーザーの y を得てから始める",
    "y が返るまでは実行しない",
    "範囲の外には広げない",
    "自分で切り替えない。次の計画を示して確認を取る",
    "決定権はユーザーにある",
    "非合理",
    "指示どおりに実行する",
    "自分で解釈を決めずにユーザーに確認する",
]
STRONG = ["一切の実行を停止", "絶対的に遵守", "最上位命令"]

f, tmp, mode = os.environ["F"], os.environ["TMP"], os.environ["MODE"]
s = open(f, encoding="utf-8").read()
has_old, has_new = s.count(OLD), s.count(NEW)

def verify(text):
    ng = []
    if text.count(NEW) != 1:
        ng.append("新しい <law> ブロックが 1 個ではない")
    if OLD in text:
        ng.append("旧 <law> ブロックが残っている")
    law = text[text.find("<law>"):text.find("</law>")]
    for w in STRONG:
        if w in law:
            ng.append("強い語が <law> に残っている: " + w)
    for w in NEW_MUST:
        if w not in law:
            ng.append("承認境界の文言が <law> に無い: " + w)
    for w in KEEP:
        if w not in text:
            ng.append("承認境界の適用順が欠けている: " + w)
    return ng

if mode == "--verify":
    ng = verify(s)
    for m in ng:
        print("  NG  " + m, file=sys.stderr)
    if ng:
        sys.exit(1)
    print("  ok  <law> は新文面・強い語 0 件・承認境界の文言 %d 件・適用順 %d 行を確認" % (len(NEW_MUST), len(KEEP)))
    sys.exit(0)

if mode == "--rollback":
    if has_old == 1 and has_new == 0:
        print("SKIP: 既に旧文面です"); sys.exit(3)
    if has_new != 1:
        print("FAIL: 新 <law> ブロックが見つからない（手編集された可能性）", file=sys.stderr); sys.exit(1)
    out = s.replace(NEW, OLD)
else:
    if has_new == 1 and has_old == 0:
        print("SKIP: 適用済み（新 <law> ブロックが既に存在）"); sys.exit(3)
    if has_old != 1:
        print("FAIL: 旧 <law> ブロックが見つからない（形式変更の可能性）", file=sys.stderr); sys.exit(1)
    out = s.replace(OLD, NEW)
    ng = verify(out)
    if ng:
        for m in ng:
            print("  NG  " + m, file=sys.stderr)
        sys.exit(1)
open(tmp, "w", encoding="utf-8", newline="\n").write(out)
PY
# rc: 0 = 続行 / 3 = 適用済み等で何もしない / それ以外 = 失敗
case "$rc" in
  0) ;;
  3) exit 0 ;;
  *) exit "$rc" ;;
esac
[ "$MODE" = "--verify" ] && exit 0

case "$MODE" in
  --dry-run)
    echo "[dry-run] 書込なし。差分:"
    diff -u "$F" "$TMP" || true
    ;;
  --apply)
    cp "$TMP" "$F"
    echo "[apply] CLAUDE.md の <law> を更新しました（Human 実行前提）。続けて --verify を実行してください"
    ;;
  --rollback)
    cp "$TMP" "$F"
    echo "[rollback] CLAUDE.md の <law> を旧文面へ戻しました（Human 実行前提）"
    ;;
esac
