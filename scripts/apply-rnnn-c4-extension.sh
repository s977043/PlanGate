#!/bin/sh
# apply-rnnn-c4-extension.sh
# issue #689: R-NNN 監査表を C-4（PR 段階）指摘まで拡張する（P-NNN 新設）。
# 仕様正本: docs/ai/review-feedback-c4-extension.md
#
# .claude/rules/working-context.md と .claude/rules/review-principles.md は
# Hardening Override 対象（.claude/rules/*.md）。
# AI はこのスクリプトを生成・dry-run のみ・実適用（--apply）は人間が実行する
# （[[feedback_ho_apply_script_no_ai_exec]] 相当 / responsibility-classes.md
#  の AI-owned / Human-owned 境界に従う）。
#
# Usage:
#   sh scripts/apply-rnnn-c4-extension.sh            # dry-run（差分プレビューのみ・既定）
#   sh scripts/apply-rnnn-c4-extension.sh --apply     # 実適用（人間が実行）
set -eu

REPO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
WC_TARGET="$REPO_ROOT/.claude/rules/working-context.md"
RP_TARGET="$REPO_ROOT/.claude/rules/review-principles.md"
APPLY=0
[ "${1:-}" = "--apply" ] && APPLY=1

if [ ! -f "$WC_TARGET" ]; then
  echo "[error] not found: $WC_TARGET" >&2
  exit 1
fi
if [ ! -f "$RP_TARGET" ]; then
  echo "[error] not found: $RP_TARGET" >&2
  exit 1
fi

# 冪等チェック（両方適用済みなら skip）
WC_APPLIED=0
RP_APPLIED=0
grep -q "P-NNN" "$WC_TARGET" && WC_APPLIED=1 || true
grep -q "C-2 と C-4 の責務分界" "$RP_TARGET" && RP_APPLIED=1 || true

if [ "$WC_APPLIED" = "1" ] && [ "$RP_APPLIED" = "1" ]; then
  echo "[skip] already applied (P-NNN 監査表 / C-2-C4 責務分界がいずれも既存)"
  exit 0
fi

python3 - "$WC_TARGET" "$RP_TARGET" "$APPLY" "$WC_APPLIED" "$RP_APPLIED" <<'PY'
import sys

wc_target, rp_target, apply_str, wc_applied, rp_applied = sys.argv[1:6]
apply = apply_str == "1"
wc_applied = wc_applied == "1"
rp_applied = rp_applied == "1"

# --- working-context.md: R-NNN 節の直後に P-NNN（C-4 拡張）節を追記 ---
wc_anchor = (
    "- 将来 #230（Gate Event Normalization）/ #200 と additive に events 連携\n"
    "  （`review-finding → plan-revision` トレース）。本 PBI は ID+Refs まで\n"
)
wc_addition = (
    "\n"
    "### P-NNN（C-4 段階指摘の追記専用集約 / #689）\n"
    "\n"
    "C-4（PR 段階レビュー）の bot / 人間指摘は `P-NNN` として同じ\n"
    "`review-external.md` に追記専用で集約する（`R-NNN` とは独立採番）。\n"
    "フィールド案・3-strike 還元手順・C-2/C-4 責務分界の詳細は\n"
    "[`docs/ai/review-feedback-c4-extension.md`](../../docs/ai/review-feedback-c4-extension.md)\n"
    "を正本とする。監査表: `| P-NNN | source(bot/human) | severity |\n"
    "reflected_in(commit) | status |`。指摘ゼロの PR でも「指摘なし」を\n"
    "明示記録する。\n"
)

# --- review-principles.md: §7-bis の直後（§7-ter の前）に C-2/C-4 責務分界を追記 ---
rp_anchor = "## 7-ter. 外部レビュー実行不可時の記録（#463）\n"
rp_addition = (
    "## 7-quater. C-2 と C-4 の責務分界（#689）\n"
    "\n"
    "> C-4（PR 段階レビュー）の bot / 人間指摘を `P-NNN` として\n"
    "> `review-external.md` に追記集約する規定は\n"
    "> [`working-context.md`](./working-context.md) の P-NNN 節を参照。\n"
    "> 本節は §7-bis（C-2 レビュア責務契約）と C-4 の責務分界のみを定義する。\n"
    "\n"
    "- **実装コードの欠陥検出は C-4 を正とする**（§7-bis により C-2 は実装\n"
    "  詳細レビューを原則行わず V-3/C-4 に寄せる方針と一貫）\n"
    "- **plan の論理・受入基準網羅の欠陥検出は C-2 を正とする**\n"
    "- **二重検出時**: 先に記録された ID を正とし、後発側は\n"
    "  `status = duplicate(R-NNN)` として記録する（削除・不記載にしない）\n"
    "- 詳細（フィールド定義・3-strike 還元手順）の正本:\n"
    "  [`docs/ai/review-feedback-c4-extension.md`](../../docs/ai/review-feedback-c4-extension.md)\n"
    "\n"
)

def preview_or_apply(target, anchor, addition, already_applied, label):
    if already_applied:
        print(f"[skip] {label}: already applied")
        return
    s = open(target).read()
    if anchor not in s:
        print(f"[error] anchor not found in {label}: {anchor[:50]!r}", file=sys.stderr)
        sys.exit(2)
    new = s.replace(anchor, anchor + addition, 1)
    if apply:
        open(target, "w").write(new)
        print(f"[applied] {label} に追記しました")
    else:
        print(f"=== DRY-RUN 差分プレビュー: {label} ===")
        for line in addition.splitlines():
            print("+ " + line)
        print(f"=== --apply で実適用（人間が実行）: {label} ===\n")

preview_or_apply(wc_target, wc_anchor, wc_addition, wc_applied, "working-context.md")
preview_or_apply(rp_target, rp_anchor, rp_addition, rp_applied, "review-principles.md")
PY
