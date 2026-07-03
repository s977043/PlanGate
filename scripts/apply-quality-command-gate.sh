#!/bin/sh
# apply-quality-command-gate.sh — #683
# working-context.md（HO パス）に「品質コマンド実行証跡ゲート」節を追加する。
#
# AI は HO パス（.claude/rules/*.md）を直接編集できないため、本スクリプトを
# AI が用意し、Human が dry-run で差分確認のうえ適用する（責務4分類: HO 実適用は Human）。
# 仕様の正本は docs/ai/quality-command-evidence.md（非 HO）。
#
# 使い方:
#   sh scripts/apply-quality-command-gate.sh --dry-run   # 差分プレビュー
#   sh scripts/apply-quality-command-gate.sh --apply      # 実適用（Human が実行）
#
# 冪等: 既に本節が存在すれば何もしない。
set -eu

REPO_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
TARGET="$REPO_ROOT/.claude/rules/working-context.md"
ANCHOR="### improvement-seeds.md（WF-06 Retro / opt-in・append-only）"
MODE=""

if [ $# -eq 0 ]; then
  echo "ERROR: 引数が必要です。Usage: $0 --dry-run|--apply" >&2
  exit 1
fi
if [ $# -gt 1 ]; then
  echo "ERROR: 引数は1つのみ指定してください。Usage: $0 --dry-run|--apply" >&2
  exit 1
fi
case "$1" in
  --dry-run) MODE="dry-run" ;;
  --apply) MODE="apply" ;;
  *)
    echo "ERROR: 不正な引数です。Usage: $0 --dry-run|--apply" >&2
    exit 1
    ;;
esac

if [ "$MODE" = "apply" ]; then
  echo "NOTICE: --apply は Human-owned 操作です（.claude/rules/*.md は HO パス）。" >&2
  echo "AI がこのモードを自動実行してはいけません。" >&2
fi

[ -f "$TARGET" ] || { echo "ERROR: $TARGET が見つかりません"; exit 1; }

if grep -q "品質コマンド実行証跡ゲート" "$TARGET"; then
  echo "SKIP: 品質コマンド実行証跡ゲートは既に適用済み"
  exit 0
fi
if ! grep -qF "$ANCHOR" "$TARGET"; then
  echo "ERROR: アンカー '$ANCHOR' が見つかりません（構造変更の可能性）"; exit 1
fi

command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 が必要です"; exit 1; }

DRY_FLAG="1"
[ "$MODE" = "apply" ] && DRY_FLAG="0"

python3 - "$TARGET" "$ANCHOR" "$DRY_FLAG" <<'PY'
import sys
path, anchor, dry = sys.argv[1], sys.argv[2], sys.argv[3]
s = open(path, encoding="utf-8").read()

section = """#### 品質コマンド実行証跡ゲート（PR/handoff 前提条件 / #683）

V-1 受け入れ検査 / handoff 完了、および PR 作成フェーズ遷移の**前提条件**として、
プロジェクト定義の品質コマンド（`docs/working/quality-commands.yaml` の
`pre_pr_commands`、宣言があれば `pbi-input.md` 側で上書き）のうち
`required: true` の全項目が [`evidence-ledger`](../../plugin/plangate/skills/evidence-ledger/SKILL.md)
の `EvidenceItem`（`phase: "verification"`）として記録され、`exitCode == 0`
であること。未実行（`EvidenceItem` 欠落）または `exitCode != 0` のまま
PR 作成フェーズへ遷移しようとした場合は **block** する。宣言が存在しない
プロジェクトでは本ゲートは no-op（既存挙動を変えない）。

詳細仕様・判定表・除外条件は
[`docs/ai/quality-command-evidence.md`](../../docs/ai/quality-command-evidence.md)
を正本とする。「ガードの存在」ではなく「**ガードの実行がゲート条件になって
いない**」という構造問題への対処であり、ドキュメント指示のみで実行を
担保しない（[`hybrid-architecture.md`](./hybrid-architecture.md) の
CLAUDE.md / Skill / Hook 境界ルールに従い機械ゲート化する）。

"""

needle = anchor + "\n"
assert s.count(needle) == 1, "anchor not unique"
out = s.replace(needle, section + needle, 1)

if dry == "1":
    import difflib
    diff = difflib.unified_diff(
        s.splitlines(keepends=True), out.splitlines(keepends=True),
        fromfile="a/working-context.md", tofile="b/working-context.md")
    sys.stdout.write("".join(diff))
    print("\n[dry-run] 上記差分を適用予定（書き込みなし）")
else:
    open(path, "w", encoding="utf-8").write(out)
    print("APPLIED: 品質コマンド実行証跡ゲート節を挿入しました")
PY
