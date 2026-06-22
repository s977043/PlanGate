#!/bin/sh
# apply-task-0129-wc.sh — TASK-0129 (#543) working-context.md 追記適用スクリプト
#
# .claude/rules/working-context.md は Hardening Override 対象。AI は直接編集不可。
# 本スクリプトを AI が生成し、Human が dry-run で差分確認のうえ適用する。
#
# 追加内容:
#   1. review-self.md セクション: C1-LOOP-01/02 チェック項目を Planチェック内に追加
#   2. C-3ゲート セクション: review_decision → c3_status mapping の参照を追加
#
# 使い方:
#   sh scripts/apply-task-0129-wc.sh --dry-run   # 差分プレビュー
#   sh scripts/apply-task-0129-wc.sh             # 実適用（Human が実行）
#
# べき等: C1-LOOP-01 が既に存在すれば SKIP。

set -eu

REPO_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
TARGET="$REPO_ROOT/.claude/rules/working-context.md"
DRY_RUN=0

if [ $# -gt 0 ]; then
  if [ "$1" = "--dry-run" ] && [ $# -eq 1 ]; then
    DRY_RUN=1
  else
    echo "ERROR: 不正な引数です。Usage: $0 [--dry-run]" >&2
    exit 1
  fi
fi

[ -f "$TARGET" ] || { echo "ERROR: $TARGET が見つかりません"; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 が必要です"; exit 1; }

# べき等チェック
if grep -q 'C1-LOOP-01' "$TARGET" 2>/dev/null; then
  echo "SKIP: C1-LOOP-01 は既に適用済み（べき等）"
  exit 0
fi

python3 - "$TARGET" "$DRY_RUN" <<'PY'
import sys, difflib

target, dry = sys.argv[1], sys.argv[2] == "1"
with open(target, encoding="utf-8") as f:
    src_text = f.read()

# Patch 1: review-self.md セクションの Planチェック後に Loop チェック項目を追記
OLD1 = "- Planチェック（7項目）: 受入基準網羅性、Unknowns処理、スコープ制御、テスト戦略、Work Breakdown Output、依存関係、動作検証自動化"
NEW1 = (
    "- Planチェック（7項目）: 受入基準網羅性、Unknowns処理、スコープ制御、テスト戦略、Work Breakdown Output、依存関係、動作検証自動化\n"
    "  - **C1-LOOP-01（TASK-0129 / #543）**: plan に Stop Condition（停止条件）が記入されているか（未記入 → WARN、high-risk/critical では FAIL）\n"
    "  - **C1-LOOP-02（TASK-0129 / #543）**: plan に Replan Triggers と機械値（閾値）が記入されているか（未記入 → WARN、機械値なし → WARN、high-risk/critical では FAIL）"
)

if OLD1 not in src_text:
    print(f"ERROR: Patch 1 のアンカーが見つかりません", file=sys.stderr)
    sys.exit(1)

new_text = src_text.replace(OLD1, NEW1, 1)

# Patch 2: C-3ゲートセクションの判定基準の後に Decision mapping 参照を追記
OLD2 = "- C-2（`review-external.md`）は任意。C-2をスキップする場合はC-1のみで判断可"
NEW2 = (
    "- C-2（`review-external.md`）は任意。C-2をスキップする場合はC-1のみで判断可\n"
    "- **外部レビュー Decision → c3_status マッピング（TASK-0129 / #543）**:\n"
    "  外部レビューア（river-reviewer / Gemini / Codex 等）が返す `Decision` は以下で c3_status に接続する:\n"
    "  `go`→APPROVED候補 / `revise_plan`→CONDITIONAL / `human_approval_required`→人間C-3強制 / `no_go`→REJECTED。\n"
    "  未知値・欠落は安全側（人間C-3強制）。詳細: [`docs/ai/review-gate-decision-mapping.md`](../../docs/ai/review-gate-decision-mapping.md)"
)

if OLD2 not in new_text:
    print(f"ERROR: Patch 2 のアンカーが見つかりません", file=sys.stderr)
    sys.exit(1)

new_text = new_text.replace(OLD2, NEW2, 1)

if dry:
    diff = list(difflib.unified_diff(
        src_text.splitlines(True),
        new_text.splitlines(True),
        fromfile=".claude/rules/working-context.md",
        tofile=".claude/rules/working-context.md (after)"
    ))
    sys.stdout.write("".join(diff))
    sys.stderr.write("\n[dry-run] 上記差分。適用するには --dry-run なしで実行。\n")
else:
    with open(target, "w", encoding="utf-8", newline="\n") as f:
        f.write(new_text)
    sys.stderr.write("[applied] working-context.md に C1-LOOP-01/02 と Decision mapping 参照を追加しました。\n")
PY
