#!/bin/sh
# apply-pr-issue-link-comment-removal.sh — #159 改善の HO 適用スクリプト（非 HO）
#
# 目的:
#   `.github/workflows/check-pr-issue-link.yml` が WARN 時に PR へ
#   warning コメントを投稿する挙動を廃止し、Step Summary のみで表現する。
#   併せて、既存の `<!-- check-pr-issue-link:warning -->` コメントを
#   判定結果に関わらず毎回削除する cleanup step を追加する。
#
# 背景（実測 / 2026-08-20、直近 40 PR）:
#   - 本文の linkage 宣言は `Refs: #N` が主流（30 件超）、`Closes #N` は 6 件のみ
#   - その結果 #1199 / #1195 / #1193 / #1187 / #1184 / #1176 など事実上全 PR に
#     同一の WARN コメントが投稿されており、シグナルとして機能していない
#   - #1176 は `documentation` ラベル付き（= SKIP 条件成立）だが、ラベル付与前に
#     投稿されたコメントが残存する。重複防止の identifier 判定が、逆に stale な
#     コメントを固定していた
#
#   判定ロジック側の是正（`Refs: #N` を有効な linkage として扱い、closing の
#   有無を PASS / NOTICE で分ける 4 値判定）は `scripts/check-pr-issue-link.sh`
#   （非 HO）で別途適用済み。本スクリプトはその残る一半である「コメント投稿と
#   いう出力チャネル」を廃止し、代わりに注釈チャネルへ 4 値を写像する。
#
# 本スクリプトは 1 オペレーションで次の 4 つを行う（部分適用を避ける）:
#   (1) `Post warning comment (if WARN)` step を削除【HO パス】
#   (2) `Annotate WARN` step を追加（GitHub Actions の ::warning:: 注釈）【HO パス】
#   (3) `Annotate NOTICE` step を追加（::notice:: 注釈）【HO パス】
#   (4) `Cleanup stale warning comment` step を追加（if: always()）【HO パス】
#
#   (2) を同時に入れないと WARN の可視面が Step Summary だけになり、
#   「ノイズ除去」ではなく「シグナル消滅」になる。注釈は Actions UI と
#   checks サマリに出るが PR タイムラインは汚さない。
#
#   (3) は判定器の 4 値化（#159 敵対レビュー major-4 / Human 裁定 (b)）に対応する。
#   NOTICE = 非クローズ型リンクのみ。WARN と NOTICE を **別 step** に分けるのは:
#     - 判定の分類は判定器の出力 prefix 1 箇所に閉じ、workflow 側で prefix を
#       再パースする第 2 の分類器を作らない（`if:` 条件だけで済む）
#     - WARN 経路のテキストを 1 バイトも変えないので、NOTICE 追加が WARN 経路を
#       退行させ得ない（差分が純粋に additive）
#     - Actions UI 上どちらの判定で発火したかが step 名で一目で分かる
#   代償は skip される step が 1 つ増えることだけ。
#
#   `permissions: pull-requests: write` は (4) の削除操作（`gh api -X DELETE`）に
#   必要なため維持する（(2) / (3) の注釈出力自体は追加権限を要さない）。
#
# 置換範囲（minor-3 是正 / 適用時点の未知 step を巻き込まない）:
#   削除対象は `- name: Post warning comment (if WARN)` から **次の
#   `      - name:` 行（または steps リストの終端）まで** に限定する。
#   `- name: Output summary` を END アンカーとして両者の「間を全部消す」旧実装は、
#   適用までの間に別 step が挿入されるとそれを無警告で削除していた。
#   併せて削除対象ブロックの内容を検証し、想定外なら 1 バイトも書かずに exit 1。
#
# 責務: docs/ai/ho-change-workflow.md「標準フロー」に従う。
#   AI は本スクリプトの**作成と --dry-run のみ**。`--apply` の実行は **Human-owned**。
#
# Usage:
#   sh scripts/apply-pr-issue-link-comment-removal.sh              # dry-run（既定・書き込みなし）
#   sh scripts/apply-pr-issue-link-comment-removal.sh --dry-run    # 同上（明示）
#   sh scripts/apply-pr-issue-link-comment-removal.sh --apply      # 実適用（Human-owned）
#
# Exit codes:
#   0 = 成功（適用 / dry-run / 既適用 skip）
#   1 = 引数エラー / アンカー未検出 / アンカー多重 / 削除対象ブロックの内容が
#       想定外 / 部分適用状態 / 対象ファイル不在（いずれも 1 バイトも書かない）
#
# Refs: #159

set -eu

REPO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
WF="$REPO_ROOT/.github/workflows/check-pr-issue-link.yml"

# ── 引数 strict 検証（未知引数は即 exit 1）─────────────────────────
MODE=dry-run
case "${1:-}" in
  "") MODE=dry-run ;;
  --dry-run) MODE=dry-run ;;
  --apply) MODE=apply ;;
  *)
    printf 'error: unknown argument: %s\n' "$1" >&2
    printf 'usage: sh scripts/apply-pr-issue-link-comment-removal.sh [--dry-run|--apply]\n' >&2
    exit 1
    ;;
esac
if [ "$#" -gt 1 ]; then
  printf 'error: too many arguments (%s)\n' "$#" >&2
  exit 1
fi

if [ ! -f "$WF" ]; then
  printf 'error: target not found: %s\n' "$WF" >&2
  exit 1
fi

MODE="$MODE" WF="$WF" python3 - <<'PY'
import difflib
import os
import sys

mode = os.environ["MODE"]
wf = os.environ["WF"]

with open(wf, encoding="utf-8") as fh:
    original = fh.read()

NEW_STEP = """      - name: Annotate WARN
        if: startsWith(steps.check.outputs.result, 'WARN')
        env:
          RESULT: ${{ steps.check.outputs.result }}
        run: |
          set -eu
          # PR コメントは廃止（#159）。WARN は Actions の注釈として残す:
          # Actions UI / checks サマリには出るが PR タイムラインは汚さない。
          printf '::warning title=Check PR Issue Link::%s\\n' "$RESULT"

      - name: Annotate NOTICE
        if: startsWith(steps.check.outputs.result, 'NOTICE')
        env:
          RESULT: ${{ steps.check.outputs.result }}
        run: |
          set -eu
          # NOTICE = 非クローズ型リンク（Refs / Part of / Related to）のみ。
          # リンクはあるので WARN ではないが、`Refs:` の参照先は issue とは限らず
          # PR も混在するため「closing の書き忘れ」を弱いシグナルとして残す。
          # ::notice:: は Actions UI / checks サマリには出るが PR タイムラインは
          # 汚さない（WARN と同じ設計意図。強制力は増やさない）。
          printf '::notice title=Check PR Issue Link::%s\\n' "$RESULT"

      - name: Cleanup stale warning comment
        if: always()
        env:
          GH_TOKEN: ${{ github.token }}
          PR_NUMBER: ${{ github.event.pull_request.number }}
          REPO: ${{ github.repository }}
        run: |
          set -eu
          # コメント投稿は廃止済み（#159）。過去 run が残した warning コメントを
          # 判定結果に関わらず回収する。ラベル追加等で SKIP へ転じた PR に stale な
          # WARN コメントが残り続ける問題（実例: PR #1176）への恒久対応。
          identifier='<!-- check-pr-issue-link:warning -->'
          ids=$(gh api --paginate "repos/$REPO/issues/$PR_NUMBER/comments" \\
            --jq ".[] | select(.body | contains(\\"$identifier\\")) | .id" || true)
          if [ -z "$ids" ]; then
            echo "No stale warning comment found."
            exit 0
          fi
          for id in $ids; do
            echo "Deleting stale warning comment $id"
            # fork からの pull_request では GITHUB_TOKEN が read-only になるため
            # DELETE が 403 になる。cleanup の失敗で job を赤くする理由はないので
            # 失敗許容にする（旧実装は同状況でも緑だった / #159）。
            if ! gh api -X DELETE "repos/$REPO/issues/comments/$id"; then
              echo "warning: could not delete comment $id (token may be read-only); skipping"
            fi
          done
"""

# ── 冪等性チェック ────────────────────────────────────────────────
# 適用後の workflow が満たすべき marker（NOTICE 段の追加で 3 本になった / #159）。
# 一部だけ存在する = 部分適用 or 旧版適用済みなので、1 バイトも書かずに落とす。
APPLIED_MARKERS = (
    "Annotate WARN",
    "Annotate NOTICE",
    "Cleanup stale warning comment",
)
present = [m for m in APPLIED_MARKERS if m in original]
if present:
    missing = [m for m in APPLIED_MARKERS if m not in original]
    if missing or "Post warning comment" in original:
        sys.stderr.write(
            "error: partially applied state detected; present=[%s] missing=[%s] "
            "post_warning_step_present=%s\n"
            % (
                ", ".join(present),
                ", ".join(missing),
                "Post warning comment" in original,
            )
        )
        sys.exit(1)
    sys.stdout.write("already applied: %s (no change)\n" % wf)
    sys.exit(0)

# ── アンカー検証（START のみ / END アンカーには依存しない）─────────
# 旧実装は START..END(`- name: Output summary`) の「間を全部」置換していたため、
# 適用までの間に別 step が挿入されると、それを無警告で削除していた（minor-3）。
# ここでは START step の **自ブロックだけ** を切り出して置換する。
START = "      - name: Post warning comment (if WARN)\n"
STEP_PREFIX = "      - "        # steps リストの項目行
STEP_INDENT = 6                 # 項目行のインデント幅

if START not in original:
    sys.stderr.write("error: anchor not found: 'Post warning comment (if WARN)' step\n")
    sys.exit(1)
if original.count(START) != 1:
    sys.stderr.write(
        "error: anchor is ambiguous: 'Post warning comment (if WARN)' appears %d times\n"
        % original.count(START)
    )
    sys.exit(1)

lines = original.splitlines(keepends=True)
start_line = None
for i, ln in enumerate(lines):
    if ln == START:
        start_line = i
        break
if start_line is None:  # pragma: no cover - START in original で担保済み
    sys.stderr.write("error: anchor not found (line scan)\n")
    sys.exit(1)


def _indent(text):
    return len(text) - len(text.lstrip(" "))


# ブロック終端 = 次の step 項目行、または steps リストからの dedent、または EOF
end_line = len(lines)
for i in range(start_line + 1, len(lines)):
    ln = lines[i]
    if not ln.strip():
        continue                       # 空行はブロック内に許容（末尾の分離行含む）
    if ln.startswith(STEP_PREFIX):
        end_line = i
        break
    if _indent(ln) < STEP_INDENT:
        end_line = i                   # steps リストの外へ出た
        break

removed = "".join(lines[start_line:end_line])

# ── 削除対象ブロックの内容検証（想定外なら 1 バイトも書かずに exit 1）──
REQUIRED_IN_REMOVED = (
    "if: startsWith(steps.check.outputs.result, 'WARN')",
    "<!-- check-pr-issue-link:warning -->",
    "gh pr comment",
)
missing = [tok for tok in REQUIRED_IN_REMOVED if tok not in removed]
if missing:
    sys.stderr.write(
        "error: block to remove does not look like the expected "
        "'Post warning comment (if WARN)' step; missing marker(s): %s\n"
        % ", ".join(missing)
    )
    sys.stderr.write("--- block that would have been removed ---\n")
    sys.stderr.write(removed)
    sys.exit(1)
# 自ブロック外の step を巻き込んでいないことを二重に確認（防御的）
extra_steps = [
    ln for ln in lines[start_line + 1:end_line] if ln.startswith(STEP_PREFIX)
]
if extra_steps:
    sys.stderr.write(
        "error: block to remove unexpectedly spans %d additional step(s)\n"
        % len(extra_steps)
    )
    sys.exit(1)

start_idx = len("".join(lines[:start_line]))
end_idx = start_idx + len(removed)

updated = original[:start_idx] + NEW_STEP + "\n" + original[end_idx:]

if updated == original:
    sys.stderr.write("error: no change produced (unexpected)\n")
    sys.exit(1)

diff = "".join(
    difflib.unified_diff(
        original.splitlines(keepends=True),
        updated.splitlines(keepends=True),
        fromfile="a/.github/workflows/check-pr-issue-link.yml",
        tofile="b/.github/workflows/check-pr-issue-link.yml",
    )
)

if mode == "dry-run":
    sys.stdout.write(diff)
    sys.stdout.write("\n[dry-run] no file written. Re-run with --apply (Human-owned).\n")
    sys.exit(0)

with open(wf, "w", encoding="utf-8") as fh:
    fh.write(updated)
sys.stdout.write(diff)
sys.stdout.write("\n[applied] %s\n" % wf)
PY
