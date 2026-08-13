#!/bin/sh
# plugin-mirror-drift.sh — MAJOR-3 の是正範囲の実測根拠
#
#   sh docs/working/TASK-1089/evidence/plugin-mirror-drift.sh <repo_root>
#
# CI の drift-check（.github/workflows/sync-plugin-plangate.yml / PR トリガ）は
#   sh scripts/sync-plugin-plangate.sh
#   git diff --quiet -- plugin/plangate/     # 非ゼロなら exit 1（RED）
# であり、「**コミット済みのミラー**が正本から再生成した結果と一致するか」を見る。
#
# したがって plugin/plangate/rules/mode-classification.md（= .claude/rules/ の
# 生成ミラー）を**単独でコミット**すると必ず RED になる。MAJOR-3 の記号アンカー化は
# HO 正本（apply スクリプト）で行い、ミラーは sync で追従させるのが唯一整合する経路。
set -u
SRC=$(CDPATH= cd -- "${1:?usage: sh $0 <repo_root>}" && pwd)
W=$(mktemp -d)
MIRROR=plugin/plangate/rules/mode-classification.md

mkrepo() { # $1=dest（コミット前に $2 = 追加編集コマンドを実行できる）
  rm -rf "$1"; mkdir -p "$1"
  ( cd "$SRC" && git archive HEAD ) | tar -x -C "$1"
}
commit_all() {
  ( cd "$1" && git init -q . && git add -A >/dev/null 2>&1 \
    && git -c user.email=t@e -c user.name=t commit -qm base >/dev/null 2>&1 )
}
drift_rc() { # $1=repo ; CI と同じ手順。0=GREEN / 1=RED（要 sync + commit）
  sh "$1/scripts/sync-plugin-plangate.sh" >/dev/null 2>&1
  if ( cd "$1" && git diff --quiet -- plugin/plangate/ ); then echo 0; else echo 1; fi
}

echo "===== D1: ミラーだけを編集して**コミット**（= レビュー指摘どおりの是正）====="
mkrepo "$W/d1"
sed -i.bak 's|L124-134 case 文|の `_override=0` 直後の `case` ブロック（`esac` まで）|' "$W/d1/$MIRROR"
rm -f "$W/d1/$MIRROR.bak"
grep -q '_override=0' "$W/d1/$MIRROR" && echo "  ミラー編集: 適用済み" || echo "  ミラー編集: NG（sed 不一致）"
commit_all "$W/d1"
echo "  drift-check rc=$(drift_rc "$W/d1")   → 1 なら CI RED（期待 1）"
( cd "$W/d1" && git diff --stat -- plugin/plangate/ | tail -2 )

echo
echo "===== D2: 現ブランチの状態（ミラー未編集）====="
mkrepo "$W/d2"
commit_all "$W/d2"
echo "  drift-check rc=$(drift_rc "$W/d2")   → 0 なら CI GREEN（期待 0）"

echo
echo "===== D3: HO 側を apply → sync（= 正しい経路）====="
mkrepo "$W/d3"
commit_all "$W/d3"
sh "$W/d3/scripts/apply-eh3-ho-always.sh" --apply >/dev/null 2>&1
echo "  apply 直後の drift-check rc=$(drift_rc "$W/d3")   → 1（sync 結果の commit が必要）"
if grep -q '_override=0' "$W/d3/$MIRROR"; then
  echo "  sync 後のミラーに記号アンカーが伝播: OK"
else
  echo "  sync 後のミラーに記号アンカーが伝播: NG"
fi
( cd "$W/d3" && git add -A >/dev/null 2>&1 \
  && git -c user.email=t@e -c user.name=t commit -qm applied >/dev/null 2>&1 )
echo "  sync 結果を commit した後の drift-check rc=$(drift_rc "$W/d3")   → 0（期待 0）"

rm -rf "$W"
