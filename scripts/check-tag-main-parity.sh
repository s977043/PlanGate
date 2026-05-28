#!/bin/sh
# check-tag-main-parity.sh — NO RELEASE WITHOUT TAG-MAIN PARITY (TASK-0116 / #354)
#
# release tag が指す commit と origin/main の最新が一致するか機械検証。
# 不一致のまま GitHub Release を作成する事故を防ぐ Iron Law の実行 script。
#
# 設計原則 (C-2 R-001..R-004 反映):
#   R-001: 冒頭で git fetch origin main (stale 防止)、fetch 失敗時 exit + 警告
#   R-002: 不一致時の貼り替えは --force-with-lease + ref 明示 (docs 案内)
#   R-004: annotated / lightweight tag を ^{commit} で peel して比較
#
# 使用例:
#   sh scripts/check-tag-main-parity.sh v0.X.Y
#   → tag^{commit} == origin/main なら exit 0、不一致 exit 1
#
# 関連: docs/release-process.md (Iron Law + 失敗時フロー)

set -eu

TAG="${1:-}"
if [ -z "$TAG" ]; then
  echo "[tag-parity] FAIL: tag 引数が必要です" >&2
  echo "  usage: sh scripts/check-tag-main-parity.sh <tag>" >&2
  exit 1
fi

# R-001: stale 防止のため origin/main を fetch
if ! git fetch origin main >/dev/null 2>&1; then
  echo "[tag-parity] WARN: git fetch origin main 失敗 (offline?)。" >&2
  echo "  origin/main が stale の可能性があります。検証を中断します。" >&2
  exit 1
fi

# tag 存在確認
if ! git rev-parse "$TAG" >/dev/null 2>&1; then
  echo "[tag-parity] FAIL: tag '$TAG' が存在しません" >&2
  exit 1
fi

# R-004: annotated / lightweight tag を ^{commit} で peel
tag_commit=$(git rev-parse "$TAG^{commit}" 2>/dev/null || true)
main_commit=$(git rev-parse origin/main 2>/dev/null || true)

if [ -z "$tag_commit" ] || [ -z "$main_commit" ]; then
  echo "[tag-parity] FAIL: commit SHA の取得に失敗 (tag=$tag_commit main=$main_commit)" >&2
  exit 1
fi

if [ "$tag_commit" = "$main_commit" ]; then
  echo "[tag-parity] OK: tag '$TAG' = origin/main ($tag_commit)"
  exit 0
else
  echo "[tag-parity] MISMATCH: tag '$TAG' ($tag_commit) != origin/main ($main_commit)" >&2
  echo "" >&2
  echo "  NO RELEASE WITHOUT TAG-MAIN PARITY (Iron Law):" >&2
  echo "  一致するまで GitHub Release を作成しないでください。" >&2
  echo "" >&2
  echo "  貼り替え手順 (Human オペレーション):" >&2
  echo "    1. git tag -fa $TAG origin/main  # annotated tag を main に作り直し" >&2
  echo "    2. git push --force-with-lease origin refs/tags/$TAG:refs/tags/$TAG" >&2
  echo "    3. sh scripts/check-tag-main-parity.sh $TAG  # 再検証" >&2
  echo "" >&2
  echo "  詳細: docs/release-process.md" >&2
  exit 1
fi
