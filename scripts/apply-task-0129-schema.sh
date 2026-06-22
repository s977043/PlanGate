#!/bin/sh
# apply-task-0129-schema.sh — TASK-0129 (#543) schema 拡張適用スクリプト
#
# schemas/c3-approval.schema.json は Hardening Override 対象。AI は直接編集不可。
# 本スクリプトを AI が生成し、Human が dry-run で差分確認のうえ適用する。
#
# 追加内容（additive・後方互換・required に追加しない）:
#   - review_decision: 外部レビュー Decision（go/revise_plan/human_approval_required/no_go）
#   - review_risk:     外部レビュー Risk（low/medium/high）
#   - review_stop_works: Stop-Work Conditions リスト（array of string）
#   - review_source:   レビューア識別子
#   - lite_eligible:   false 固定（承認境界変更 PBI）
#
# 使い方:
#   sh scripts/apply-task-0129-schema.sh --dry-run   # 差分プレビュー
#   sh scripts/apply-task-0129-schema.sh             # 実適用（Human が実行）
#
# べき等: review_decision が既に存在すれば SKIP。
# 後方互換検証: 既存の APPROVED/CONDITIONAL/REJECTED c3.json が拡張後も valid。

set -eu

REPO_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
TARGET="$REPO_ROOT/schemas/c3-approval.schema.json"
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
if python3 -c "import json; d=json.load(open('$TARGET')); exit(0 if 'review_decision' in d.get('properties',{}) else 1)" 2>/dev/null; then
  echo "SKIP: review_decision は既に適用済み（べき等）"
  exit 0
fi

python3 - "$TARGET" "$DRY_RUN" <<'PY'
import json, sys, difflib

target, dry = sys.argv[1], sys.argv[2] == "1"
with open(target) as f:
    src_text = f.read()
d = json.loads(src_text)

# additive 拡張フィールドを properties に追加
new_props = {
    "review_decision": {
        "type": "string",
        "enum": ["go", "revise_plan", "human_approval_required", "no_go"],
        "description": (
            "外部レビューの Decision。go→APPROVED候補 / revise_plan→CONDITIONAL / "
            "human_approval_required→人間C-3強制 / no_go→REJECTED。"
            "未知値・欠落は安全側（人間C-3強制）として扱う（TASK-0129 / #543）。"
        )
    },
    "review_risk": {
        "type": "string",
        "enum": ["low", "medium", "high"],
        "description": (
            "外部レビューの Risk。high→mode最低high-risk・autonomous APPROVE無効化。"
            "欠落は安全側（medium相当）として扱う（TASK-0129 / #543）。"
        )
    },
    "review_stop_works": {
        "type": "array",
        "items": {"type": "string"},
        "description": (
            "外部レビューの Stop-Work Conditions リスト。"
            "#544/#551 機械トリガーへのマッピングは "
            "docs/ai/review-gate-decision-mapping.md §4 参照（TASK-0129 / #543）。"
        )
    },
    "review_source": {
        "type": "string",
        "description": "外部レビューアの識別子（例: river-reviewer / gemini / codex）。"
    },
    "lite_eligible": {
        "type": "boolean",
        "description": (
            "Lite ゲート適用可否。承認境界変更 PBI では false 固定 "
            "（mode-classification.md AC-10 Hardening Override / TASK-0129 / #543）。"
        )
    }
}

for key, val in new_props.items():
    d["properties"][key] = val

new_text = json.dumps(d, ensure_ascii=False, indent=2) + "\n"

if dry:
    diff = list(difflib.unified_diff(
        src_text.splitlines(True),
        new_text.splitlines(True),
        fromfile="schemas/c3-approval.schema.json",
        tofile="schemas/c3-approval.schema.json (after)"
    ))
    sys.stdout.write("".join(diff))
    sys.stderr.write("\n[dry-run] 上記差分。適用するには --dry-run なしで実行。\n")
else:
    with open(target, "w", encoding="utf-8", newline="\n") as f:
        f.write(new_text)
    sys.stderr.write("[applied] review_decision 等 5 フィールドを schemas/c3-approval.schema.json に追加しました。\n")
PY

# 後方互換検証（実適用後）
if [ "$DRY_RUN" = "0" ]; then
  echo ""
  echo "=== 後方互換検証（既存 c3.json が拡張後も valid か） ==="
  SCHEMA_VALIDATE="$REPO_ROOT/scripts/validate-schemas.py"
  if [ -f "$SCHEMA_VALIDATE" ]; then
    python3 -c "import jsonschema" >/dev/null 2>&1 || {
      echo "[SKIP] jsonschema 未インストール（後方互換検証スキップ）"
      exit 0
    }
    FIXTURE_VALID="$REPO_ROOT/tests/fixtures/schema-validate/valid/c3.json"
    if [ -f "$FIXTURE_VALID" ]; then
      if python3 "$SCHEMA_VALIDATE" "$FIXTURE_VALID" >/dev/null 2>&1; then
        echo "[PASS] 後方互換: tests/fixtures/schema-validate/valid/c3.json → valid"
      else
        echo "[FAIL] 後方互換検証失敗: $FIXTURE_VALID が拡張後 schema で invalid" >&2
        exit 1
      fi
    else
      echo "[WARN] fixture が見つかりません: $FIXTURE_VALID"
    fi
  else
    echo "[SKIP] validate-schemas.py が見つかりません"
  fi
fi
