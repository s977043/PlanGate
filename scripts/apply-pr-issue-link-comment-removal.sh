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
#   判定ロジック側の是正（`Refs: #N` を有効な linkage として PASS 扱いにする）は
#   `scripts/check-pr-issue-link.sh`（非 HO）で別途適用済み。本スクリプトは
#   その残る一半である「コメント投稿という出力チャネル」を廃止する。
#
# 本スクリプトは 1 オペレーションで次の 2 つを行う（部分適用を避ける）:
#   (1) `Post warning comment (if WARN)` step を削除【HO パス】
#   (2) `Annotate WARN` step を追加（GitHub Actions の ::warning:: 注釈）【HO パス】
#   (3) `Cleanup stale warning comment` step を追加（if: always()）【HO パス】
#
#   (2) を同時に入れないと WARN の可視面が Step Summary だけになり、
#   「ノイズ除去」ではなく「シグナル消滅」になる。注釈は Actions UI と
#   checks サマリに出るが PR タイムラインは汚さない。
#
#   `permissions: pull-requests: write` は (2) の削除操作に必要なため維持する。
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
#   1 = 引数エラー / アンカー未検出 / 対象ファイル不在（＝何も書き込まない）
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
            gh api -X DELETE "repos/$REPO/issues/comments/$id"
          done
"""

# ── 冪等性チェック ────────────────────────────────────────────────
if "Cleanup stale warning comment" in original or "Annotate WARN" in original:
    if "Post warning comment" in original or "Cleanup stale warning comment" not in original \
            or "Annotate WARN" not in original:
        sys.stderr.write(
            "error: partially applied state detected "
            "(cleanup step present but 'Post warning comment' step still exists)\n"
        )
        sys.exit(1)
    sys.stdout.write("already applied: %s (no change)\n" % wf)
    sys.exit(0)

# ── アンカー検証 ──────────────────────────────────────────────────
START = "      - name: Post warning comment (if WARN)\n"
END = "      - name: Output summary\n"

if START not in original:
    sys.stderr.write("error: anchor not found: 'Post warning comment (if WARN)' step\n")
    sys.exit(1)
if END not in original:
    sys.stderr.write("error: anchor not found: 'Output summary' step\n")
    sys.exit(1)

start_idx = original.index(START)
end_idx = original.index(END, start_idx)
if end_idx <= start_idx:
    sys.stderr.write("error: anchors out of order\n")
    sys.exit(1)

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
