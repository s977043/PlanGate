#!/bin/sh
# apply-responsibility-classes-branch-base.sh — #505 ギャップ1
# responsibility-classes.md（HO パス）の「Bash 連結コマンド時の error guard」節に
# 「新規ブランチ作成時の base（分岐元）verify」規範を追加する。
#
# AI は HO パス（.claude/rules/*.md）を直接編集できないため、本スクリプトを AI が
# 用意し、Human が dry-run で差分確認のうえ適用する（責務4分類: HO 実適用は Human）。
#
# 使い方:
#   sh scripts/apply-responsibility-classes-branch-base.sh --dry-run
#   sh scripts/apply-responsibility-classes-branch-base.sh
# 冪等: 既に項目5が存在すれば何もしない。
set -eu

REPO_ROOT="$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)"
TARGET="$REPO_ROOT/.claude/rules/responsibility-classes.md"
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
if grep -q "新規ブランチ作成時は base" "$TARGET"; then
  echo "SKIP: 項目5（ブランチ base verify）は既に適用済み"
  exit 0
fi
command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 が必要です"; exit 1; }

python3 - "$TARGET" "$DRY_RUN" <<'PY'
import sys, difflib
path, dry = sys.argv[1], sys.argv[2]
s = open(path, encoding="utf-8").read()

anchor = "   - **他 protected (`master`, `release/*` 等) への commit/push は事前明示確認必須**\n"
item5 = anchor + """5. **新規ブランチ作成時は base（分岐元）を verify**:
   - 新規 feature ブランチは **`main` から分岐**する（`git checkout main && git fetch && git checkout -b <new>`）。直前の作業ブランチ上で `git checkout -b` すると、そのブランチの全コミットを巻き込んだ PR になる。
   - 作成直後に `git diff main --stat`（または PR 作成後に `gh pr view <n> --json files`）で **変更ファイルが想定どおりか検証**する。混入時は `main` から作り直して `git push --force-with-lease`。
   - 実害: INC として #502 が #494 ブランチ上で `git checkout -b` され、#494 の 5 ファイルを巻き込んだ（#505 ギャップ1。INC-2026-05-26-001 と同型の git 事故）。
"""
assert s.count(anchor) == 1, "anchor not unique: %d" % s.count(anchor)
out = s.replace(anchor, item5, 1)

if dry == "1":
    sys.stdout.write("".join(difflib.unified_diff(
        s.splitlines(keepends=True), out.splitlines(keepends=True),
        fromfile="a/responsibility-classes.md", tofile="b/responsibility-classes.md")))
    print("\n[dry-run] 上記差分を適用予定（書き込みなし）")
else:
    open(path, "w", encoding="utf-8").write(out)
    print("APPLIED: 項目5（ブランチ base verify）を追加")
PY
