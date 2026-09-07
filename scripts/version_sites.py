#!/usr/bin/env python3
""":"
# --- PG-SH-GUARD (#1169): sh / bash 誤起動ガード ---
# sh はこのファイルの module docstring を二重引用符文字列として読むため、
# docstring 内のバッククォートがコマンド置換として評価され、repo を書き換える
# 副作用が起きる。python3 以外のインタプリタでは何も評価する前にここで止める。
echo "ERROR: $0 is a Python script; do not run it with sh/bash." >&2
echo "       Use: python3 $0 [args...]" >&2
exit 2
":"""

__doc__ = """version_sites.py — plugin 配布 manifest の version 宣言箇所の正本 (#1257).

**保守者が直接編集するファイルである** (内部ヘルパではない)。
`docs/release-process.md` の version 同期マップが本ファイルの `DECLARED_SITES` を
正本として参照しているため、新しい manifest を足すときはリリース手順の一部として
ここを更新する (旧名 `_version_sites.py` の `_` 接頭辞はこの位置付けと矛盾したため
#1257 のレビュー指摘 m-3 で改名した)。

背景: version 文字列 `8.21.0` が同一でも payload が 3 種類あった (#1257 実測)。
version は複数箇所で宣言されているが、それらが同値であることを保証する機械が
`.codex-plugin/plugin.json` を含む形では存在しなかった。

本ファイルは「どこで version が宣言されているか」の**正本テーブル**を持ち、
同時に **manifest を実走査して宣言漏れを検出する** (`verify-sites`)。
テーブルをハードコードしても、走査との同値照合で網羅性が担保される。

site key の形式: `<repo 相対パス>::<json path>`
  json path は dict のキー連結。list 要素は `name` キーがあれば `[name=<v>]`、
  無ければ `[<index>]` で表す。

modes:
  declared      宣言テーブルと実値を出力
  discovered    manifest 走査で見つかった version 宣言箇所を出力
  verify-sites  declared と discovered の同値照合 (網羅性ゲート)
  parity        宣言箇所の値が全て一致するか

rc: 0 = OK / 1 = 違反 / 2 = 使い方エラー / 3 = 前提不足 (root が repo でない)

残存脅威モデル (走査が原理的に見ないもの / #1257 R2):
  - 走査対象は `MANIFEST_DIRS` に挙げた plugin manifest ディレクトリ名を持つ
    JSON のみ。**族の外**に version 宣言が増えたら検出できない
    (例: `package.json` / CI 変数 / README の散文)。それらは
    `docs/release-process.md` の同期マップと人間レビューが担保する。
  - `version` という**キー名**で宣言された文字列だけを見る。別名キー
    (`pluginVersion` 等) は対象外。
  - 値の形式は問わない (`8.21.0` も `v8.21.0` も site として拾う)。
    「同値か」だけを見るので、形式の妥当性は別ゲート
    (`tests/extras/ta-28-plugin-version.sh` の v プレフィックス検査) が担う。
"""

import argparse
import json
import os
import re
import subprocess
import sys

# --- 正本テーブル -----------------------------------------------------------
# (site_id, repo 相対パス, json path)
DECLARED_SITES = (
    ("marketplace.metadata", ".claude-plugin/marketplace.json", "metadata.version"),
    ("marketplace.plugin", ".claude-plugin/marketplace.json", "plugins[name=plangate].version"),
    ("plugin.claude", "plugin/plangate/.claude-plugin/plugin.json", "version"),
    ("plugin.codex", "plugin/plangate/.codex-plugin/plugin.json", "version"),
)

# 走査対象 manifest。ここに掛からない場所へ version が増えても検出できないため、
# 「plugin manifest の族」= このディレクトリ名を持つ階層の JSON、と定義する。
#
# #1257 R2 で塞いだ 2 つの穴:
#   (a) 深さ固定の glob だった (`plugin/*/.claude-plugin/*.json`)。
#       `plugin/a/b/.claude-plugin/plugin.json` は無検出だった
#       → repo 全体を walk して**ディレクトリ名**で拾う方式に変更（深さ非依存）。
#   (b) 値が semver 形でないと site として拾わなかった (`"v1.2.3"` が素通り)。
#       → 値の形式では絞らない（下の _walk 参照）。
MANIFEST_DIRS = (".claude-plugin", ".codex-plugin")

# walk から除外するディレクトリ（走査コストと、配布実体でないコピーの混入を避ける）。
# `worktrees` は git worktree の置き場（本 repo では gitignore 済みの
# `.claude/worktrees/`）。ここには plugin manifest の**複製**が並ぶため、
# 除外しないと「未宣言 manifest が数十件ある」という偽陽性になる。
PRUNE_DIRS = frozenset((".git", "node_modules", "__pycache__", ".venv", "venv", "worktrees"))


def _walk(node, prefix, out):
    """`version` キーを持つ全パスを (path, value) で集める。

    値の形式では絞らない。semver でない値（`"v1.2.3"` 等）を無視すると、
    その site が discovered から落ちて「宣言漏れ」を検出できなくなる（#1257 R2）。
    """
    if isinstance(node, dict):
        for key, value in node.items():
            path = "%s.%s" % (prefix, key) if prefix else key
            if key == "version" and isinstance(value, str) and value:
                out.append((path, value))
            else:
                _walk(value, path, out)
    elif isinstance(node, list):
        for index, value in enumerate(node):
            if isinstance(value, dict) and isinstance(value.get("name"), str):
                label = "[name=%s]" % value["name"]
            else:
                label = "[%d]" % index
            _walk(value, "%s%s" % (prefix, label), out)


def _resolve(node, path):
    """json path を辿って値を返す。到達できなければ None。"""
    cursor = node
    for token in re.findall(r"\[[^\]]*\]|[^.\[\]]+", path):
        if token.startswith("["):
            inner = token[1:-1]
            if not isinstance(cursor, list):
                return None
            if inner.startswith("name="):
                wanted = inner[len("name="):]
                found = None
                for element in cursor:
                    if isinstance(element, dict) and element.get("name") == wanted:
                        found = element
                        break
                cursor = found
            else:
                try:
                    cursor = cursor[int(inner)]
                except (ValueError, IndexError):
                    return None
        else:
            if not isinstance(cursor, dict) or token not in cursor:
                return None
            cursor = cursor[token]
        if cursor is None:
            return None
    return cursor


def _load(path):
    try:
        with open(path, encoding="utf-8") as handle:
            return json.load(handle), ""
    except Exception as exc:  # noqa: BLE001 - 診断文字列にして呼び出し側へ返す
        return None, str(exc)


def declared(root):
    """[(site_id, key, value_or_None, note)] を返す。"""
    rows = []
    cache = {}
    for site_id, relpath, jsonpath in DECLARED_SITES:
        key = "%s::%s" % (relpath, jsonpath)
        abspath = os.path.join(root, relpath)
        if relpath not in cache:
            if os.path.isfile(abspath):
                cache[relpath] = _load(abspath)
            else:
                cache[relpath] = (None, "file-absent")
        doc, err = cache[relpath]
        if doc is None:
            rows.append((site_id, key, None, err or "unreadable"))
            continue
        value = _resolve(doc, jsonpath)
        if isinstance(value, str) and value:
            rows.append((site_id, key, value, ""))
        else:
            rows.append((site_id, key, None, "path-absent"))
    return rows


def _is_manifest_relpath(relpath):
    head, tail = os.path.split(relpath)
    return tail.endswith(".json") and os.path.basename(head) in MANIFEST_DIRS


def _git_listed_files(root):
    """git 管理下の候補パス（追跡済み + 未追跡だが ignore されていないもの）。

    git repo では**この経路を優先する**。素の os.walk だと gitignore された
    複製（`.claude/worktrees/<agent>/plugin/.../plugin.json` 等）まで拾い、
    「未宣言 manifest が大量にある」という偽陽性になる。git が無い / repo で
    ない場合は None を返し、呼び出し側が os.walk へフォールバックする。
    """
    try:
        proc = subprocess.run(
            ["git", "-C", root, "ls-files", "--cached", "--others", "--exclude-standard", "-z"],
            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, check=False,
        )
    except (OSError, ValueError):
        return None
    if proc.returncode != 0:
        return None
    return [p for p in proc.stdout.decode("utf-8", "replace").split("\0") if p]


def manifest_files(root):
    """走査対象 manifest の repo 相対パスを返す（深さ非依存 / ソート済み）。"""
    listed = _git_listed_files(root)
    if listed is not None:
        return sorted(set(
            p for p in listed
            if _is_manifest_relpath(p) and os.path.isfile(os.path.join(root, p))
        ))
    found = []
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in PRUNE_DIRS]
        if os.path.basename(dirpath) not in MANIFEST_DIRS:
            continue
        for name in filenames:
            if not name.endswith(".json"):
                continue
            abspath = os.path.join(dirpath, name)
            found.append(os.path.relpath(abspath, root).replace(os.sep, "/"))
    return sorted(set(found))


def discovered(root):
    """[(key, value)] を返す (ソート済み)。"""
    rows = []
    for relpath in manifest_files(root):
        doc, _err = _load(os.path.join(root, relpath))
        if doc is None:
            continue
        found = []
        _walk(doc, "", found)
        for jsonpath, value in found:
            rows.append(("%s::%s" % (relpath, jsonpath), value))
    return sorted(set(rows))


def main(argv):
    parser = argparse.ArgumentParser(add_help=True)
    parser.add_argument("mode", choices=("declared", "discovered", "verify-sites", "parity"))
    parser.add_argument("--root", default=".")
    args = parser.parse_args(argv)

    root = os.path.abspath(args.root)
    if not os.path.isdir(root):
        sys.stdout.write("VERSION_ROOT_ABSENT %s\n" % root)
        return 3

    if args.mode == "declared":
        for site_id, key, value, note in declared(root):
            sys.stdout.write("%s\t%s\t%s\t%s\n" % (site_id, key, value if value else "", note))
        return 0

    if args.mode == "discovered":
        for key, value in discovered(root):
            sys.stdout.write("%s\t%s\n" % (key, value))
        return 0

    if args.mode == "verify-sites":
        declared_keys = set(key for _id, key, _v, _n in declared(root))
        discovered_keys = set(key for key, _v in discovered(root))
        undeclared = sorted(discovered_keys - declared_keys)
        stale = sorted(declared_keys - discovered_keys)
        for key in undeclared:
            sys.stdout.write("VERSION_SITE_UNDECLARED %s\n" % key)
        for key in stale:
            sys.stdout.write("VERSION_SITE_STALE %s\n" % key)
        if undeclared or stale:
            return 1
        sys.stdout.write("VERSION_SITES_COMPLETE %d\n" % len(declared_keys))
        return 0

    # parity
    rows = declared(root)
    missing = [(site_id, key, note) for site_id, key, value, note in rows if value is None]
    for site_id, key, note in missing:
        sys.stdout.write("VERSION_SITE_MISSING %s %s (%s)\n" % (site_id, key, note))
    if missing:
        return 1
    values = sorted(set(value for _id, _k, value, _n in rows))
    if len(values) != 1:
        for site_id, key, value, _n in rows:
            sys.stdout.write("VERSION_PARITY_SITE %s %s %s\n" % (site_id, key, value))
        sys.stdout.write("VERSION_PARITY_MISMATCH %s\n" % " ".join(values))
        return 1
    sys.stdout.write("VERSION_PARITY_OK %s\n" % values[0])
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
