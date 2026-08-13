#!/bin/sh
# plugin-mirror-drift.sh — MAJOR-3 の是正範囲の実測根拠
#
#   sh docs/working/TASK-1089/evidence/plugin-mirror-drift.sh <repo_root>
#
# 検証すること:
#   plugin/plangate/rules/mode-classification.md は .claude/rules/ の**生成ミラー**であり、
#   ミラー側だけを編集すると CI の plugin drift-check
#   (.github/workflows/sync-plugin-plangate.yml drift-check job:
#    `sh scripts/sync-plugin-plangate.sh` 後に `git diff --quiet -- plugin/plangate/`)
#   が落ちる。したがって MAJOR-3 の記号アンカー化は **HO 側（apply スクリプト）で行い、
#   ミラーは sync で追従させる**のが唯一整合する経路である。
set -u
SRC=$(CDPATH= cd -- "${1:?usage: sh $0 <repo_root>}" && pwd)
W=$(mktemp -d)

mkrepo() { # $1=dest
  rm -rf "$1"; mkdir -p "$1"
  ( cd "$SRC" && git archive HEAD ) | tar -x -C "$1"
  ( cd "$1" && git init -q . && git add -A >/dev/null 2>&1 \
    && git -c user.email=t@e -c user.name=t commit -qm base >/dev/null 2>&1 )
}

echo "===== D1: ミラーだけを編集した場合（= 当初のレビュー指摘どおりの是正）====="
mkrepo "$W/d1"
# ミラー側にだけ記号アンカーを入れる（HO 正本は L124-134 のまま）
sed -i.bak 's|L124-134 case 文|の `_override=0` 直後の `case` ブロック（`esac` まで）|' \
  "$W/d1/plugin/plangate/rules/mode-classification.md"
rm -f "$W/d1/plugin/plangate/rules/mode-classification.md.bak"
sh "$W/d1/scripts/sync-plugin-plangate.sh" >/dev/null 2>&1
( cd "$W/d1" && git diff --quiet -- plugin/plangate/ ) && d1=0 || d1=1
echo "drift-check 相当 (git diff --quiet -- plugin/plangate/) rc=$d1  (1 = CI RED)"
( cd "$W/d1" && git diff --stat -- plugin/plangate/ | tail -2 )

echo
echo "===== D2: 現ブランチの状態（ミラー未編集）====="
mkrepo "$W/d2"
sh "$W/d2/scripts/sync-plugin-plangate.sh" >/dev/null 2>&1
( cd "$W/d2" && git diff --quiet -- plugin/plangate/ ) && d2=0 || d2=1
echo "drift-check 相当 rc=$d2  (0 = CI GREEN)"

echo
echo "===== D3: HO 側を apply したうえで sync（= 正しい経路）====="
mkrepo "$W/d3"
sh "$W/d3/scripts/apply-eh3-ho-always.sh" --apply >/dev/null 2>&1
sh "$W/d3/scripts/sync-plugin-plangate.sh" >/dev/null 2>&1
if grep -q '_override=0' "$W/d3/plugin/plangate/rules/mode-classification.md"; then
  echo "sync 後のミラーに記号アンカーが伝播 OK"
else
  echo "NG: ミラーへ伝播していない"
fi
( cd "$W/d3" && git diff --quiet -- plugin/plangate/ ) && d3=0 || d3=1
echo "sync 実行後の drift-check 相当 rc=$d3  (0 = commit すれば GREEN)"

rm -rf "$W"
