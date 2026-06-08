#!/bin/sh
# apply-mode-classification-doc-light.sh — #496
# mode-classification.md（HO パス）に「変更種別軸 + doc-light モード」を追加する。
#
# AI は HO パス（.claude/rules/*.md）を直接編集できないため、本スクリプトを
# AI が用意し、Human が dry-run で差分確認のうえ適用する（責務4分類: HO 実適用は Human）。
#
# 使い方:
#   sh scripts/apply-mode-classification-doc-light.sh --dry-run   # 差分プレビュー
#   sh scripts/apply-mode-classification-doc-light.sh             # 実適用（Human が実行）
#
# 冪等: 既に doc-light が存在すれば何もしない。
set -eu

REPO_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
TARGET="$REPO_ROOT/.claude/rules/mode-classification.md"
ANCHOR="## フェーズ適用マトリクス"
DRY_RUN=0
[ "${1:-}" = "--dry-run" ] && DRY_RUN=1

[ -f "$TARGET" ] || { echo "ERROR: $TARGET が見つかりません"; exit 1; }

if grep -q "doc-light モード" "$TARGET"; then
  echo "SKIP: doc-light は既に適用済み"
  exit 0
fi
if ! grep -qF "$ANCHOR" "$TARGET"; then
  echo "ERROR: アンカー '$ANCHOR' が見つかりません（構造変更の可能性）"; exit 1
fi

command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 が必要です"; exit 1; }

python3 - "$TARGET" "$ANCHOR" "$DRY_RUN" <<'PY'
import sys
path, anchor, dry = sys.argv[1], sys.argv[2], sys.argv[3]
s = open(path, encoding="utf-8").read()

section = """## 変更種別軸（doc / config / code）と doc-light モード

> #496 で追加。5 段階規模モードと**直交する補助軸**。doc-only 変更のリリース要否判断を
> 体系化する（規模軸だけでは doc-only を ultra-light に押し込むしかなく、リリース可否を
> 毎回手動判断していた問題への対応）。

### 変更種別軸

| 種別 | 判定 | 代表例 |
|------|------|-------|
| **doc** | 差分が `*.md` / `docs/` 配下のみ（コード・設定・スキーマを含まない） | ドキュメント追記・修正、README 更新 |
| **config** | 設定値・非実行系メタの変更（挙動を変えうるが論理コードでない） | CI 設定、lint 設定、依存メタ |
| **code** | 実行系コード・スキーマ・hook 等ロジックを含む | 機能実装、バグ修正、スキーマ変更 |

判定は安全側: doc/config/code の境界が曖昧なら **上位種別（code > config > doc）** として扱う。

### doc-light モード

変更種別 = **doc** かつ規模が ultra-light / light 相当のとき選択できる doc 特化モード。

| 項目 | doc-light の扱い |
|------|----------------|
| スキップ | V-2 / V-3 / V-4 / **単独リリース** |
| 既定のリリース方針 | **次回機能リリースに同梱**（develop に溜める。doc-only で単独 tag/Release を切らない） |
| 維持（必須） | L-0（リンク / 整合チェック）/ **doc 専用 V-1** / PR / C-4 |

#### doc 専用 V-1 の観点

- リンク切れ（相対パス・アンカー）がない
- 正本整合（他ページと矛盾する記述を追加していない）
- 実行例の到達性（記載したコマンド・パスが実在する）

#### doc-light の除外条件（安全側 / 通常モードへフォールバック）

以下のいずれかに該当する場合、doc-light を **適用せず** 通常モードに従う:

- 差分に `*.md` / `docs/` 以外を 1 つでも含む
- 承認境界周辺（Hardening Override 対象パス）の `.md`（例: `.claude/rules/*.md` / `CLAUDE.md` / `AGENTS.md`）を変更する → 「承認境界周辺の変更 → 最低 high」が優先し doc-light 無効
- ドキュメントが API 仕様・契約の正本で、コード側の追従を要する

"""

needle = anchor + "\n"
assert s.count(needle) == 1, "anchor not unique"
out = s.replace(needle, section + needle, 1)

if dry == "1":
    import difflib
    diff = difflib.unified_diff(
        s.splitlines(keepends=True), out.splitlines(keepends=True),
        fromfile="a/mode-classification.md", tofile="b/mode-classification.md")
    sys.stdout.write("".join(diff))
    print("\n[dry-run] 上記差分を適用予定（書き込みなし）")
else:
    open(path, "w", encoding="utf-8").write(out)
    print("APPLIED: doc-light セクションを挿入しました")
PY
