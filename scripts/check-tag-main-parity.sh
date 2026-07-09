#!/bin/sh
# check-tag-main-parity.sh — NO RELEASE WITHOUT TAG-MAIN PARITY (TASK-0116 / #354)
#
# release tag が指す commit と origin/main の最新が一致するか機械検証。
# 不一致のまま GitHub Release を作成する事故を防ぐ Iron Law の実行 script。
#
# 設計原則 (C-2 R-001..R-004 + #783 R-005 反映):
#   R-001: 冒頭で git fetch origin main (stale 防止)、fetch 失敗時 exit + 警告
#   R-002: 不一致時の貼り替えは --force-with-lease + ref 明示 (docs 案内)
#   R-004: annotated / lightweight tag を ^{commit} で peel して比較
#   R-005 (#783): 検証対象は「リモート tag 実体」を主とする。ローカル tag は
#     git fetch では更新されないため、ローカルのみ貼り替え済み・push 未完了
#     （リモートは旧 commit のまま）の状態でもローカル比較だけでは OK を誤返し
#     うる（2026-07-09 v8.16.0 リリースで実害化）。公開されるのはリモート
#     tag の実体であるため、`git ls-remote origin` でリモート実体を取得し、
#     それを主判定に用いる。ローカル tag との不整合（貼り替え未 push）も
#     追加検査で検出する。
#
# 使用例:
#   sh scripts/check-tag-main-parity.sh v0.X.Y
#   → リモート tag の ^{commit} == origin/main なら exit 0、不一致 exit 1
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

main_commit=$(git rev-parse origin/main 2>/dev/null || true)
if [ -z "$main_commit" ]; then
  echo "[tag-parity] FAIL: origin/main の commit SHA 取得に失敗しました" >&2
  exit 1
fi

# R-005: リモート tag の実体を取得 (annotated tag は ^{} で peel 要求)
if ! remote_refs=$(git ls-remote origin "refs/tags/$TAG" "refs/tags/$TAG^{}" 2>&1); then
  echo "[tag-parity] WARN: git ls-remote origin 実行に失敗しました (offline?)。" >&2
  echo "  リモート tag 実体を検証できません。検証を中断します (fail-closed)。" >&2
  echo "  $remote_refs" >&2
  exit 1
fi

if [ -z "$remote_refs" ]; then
  echo "[tag-parity] FAIL: tag '$TAG' が origin に存在しません（push 忘れ）" >&2
  echo "  origin へ tag を push してから再実行してください:" >&2
  echo "    git push origin refs/tags/$TAG:refs/tags/$TAG" >&2
  exit 1
fi

# annotated tag は peel 行 (refs/tags/$TAG^{}) の commit SHA を優先採用。
# lightweight tag は peel 行が現れないため refs/tags/$TAG 行の SHA を採用。
remote_tag_commit=$(printf '%s\n' "$remote_refs" | awk -v ref="refs/tags/$TAG^{}" '$2 == ref { print $1 }')
if [ -z "$remote_tag_commit" ]; then
  remote_tag_commit=$(printf '%s\n' "$remote_refs" | awk -v ref="refs/tags/$TAG" '$2 == ref { print $1 }')
fi

if [ -z "$remote_tag_commit" ]; then
  echo "[tag-parity] FAIL: リモート tag '$TAG' の commit SHA 解析に失敗しました" >&2
  echo "  $remote_refs" >&2
  exit 1
fi

# ローカル tag が存在する場合の ^{commit}（存在しなくても検証は継続する）
local_tag_commit=""
if git rev-parse --verify -q "refs/tags/$TAG^{commit}" >/dev/null 2>&1; then
  local_tag_commit=$(git rev-parse "refs/tags/$TAG^{commit}")
fi

if [ "$remote_tag_commit" = "$main_commit" ]; then
  # 主判定 OK。ただしローカル tag が別実体を指していないか追加検査 (R-005)。
  if [ -n "$local_tag_commit" ] && [ "$local_tag_commit" != "$remote_tag_commit" ]; then
    echo "[tag-parity] FAIL: ローカル tag '$TAG' ($local_tag_commit) とリモート tag ($remote_tag_commit) が不一致です" >&2
    echo "" >&2
    echo "  ローカル tag とリモート tag が不一致（貼り替え未 push の可能性）:" >&2
    echo "  ローカルで tag を貼り替えたが origin へ push できていない、" >&2
    echo "  または別途 push 済みの内容がローカルへ反映されていない可能性があります。" >&2
    echo "" >&2
    echo "  貼り替え手順 (Human オペレーション):" >&2
    echo "    git push --force-with-lease=refs/tags/$TAG:$remote_tag_commit origin refs/tags/$TAG:refs/tags/$TAG" >&2
    echo "    sh scripts/check-tag-main-parity.sh $TAG  # 再検証" >&2
    echo "" >&2
    echo "  詳細: docs/release-process.md" >&2
    exit 1
  fi

  echo "[tag-parity] OK: tag '$TAG' (origin 実体) = origin/main ($remote_tag_commit)"
  exit 0
else
  echo "[tag-parity] MISMATCH: tag '$TAG' (origin 実体: $remote_tag_commit) != origin/main ($main_commit)" >&2
  echo "" >&2
  echo "  NO RELEASE WITHOUT TAG-MAIN PARITY (Iron Law):" >&2
  echo "  一致するまで GitHub Release を作成しないでください。" >&2
  echo "" >&2

  if [ -n "$local_tag_commit" ] && [ "$local_tag_commit" = "$main_commit" ]; then
    echo "  ローカル tag は origin/main と一致していますが、リモート tag ($TAG) は" >&2
    echo "  古い commit のままです。貼り替え済み・push 未完了の可能性があります:" >&2
    echo "" >&2
    echo "  貼り替え手順 (Human オペレーション):" >&2
    echo "    git push --force-with-lease=refs/tags/$TAG:$remote_tag_commit origin refs/tags/$TAG:refs/tags/$TAG" >&2
    echo "    sh scripts/check-tag-main-parity.sh $TAG  # 再検証" >&2
  else
    echo "  貼り替え手順 (Human オペレーション):" >&2
    echo "    1. git tag -fa $TAG origin/main  # annotated tag を main に作り直し" >&2
    echo "    2. git push --force-with-lease origin refs/tags/$TAG:refs/tags/$TAG" >&2
    echo "    3. sh scripts/check-tag-main-parity.sh $TAG  # 再検証" >&2
  fi

  echo "" >&2
  echo "  詳細: docs/release-process.md" >&2
  exit 1
fi
