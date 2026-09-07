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

__doc__ = """_version_sites.py — plugin 配布 manifest の version 宣言箇所の正本 (#1257).

背景: version 文字列 `8.21.0` が同一でも payload が 3 種類あった (#1257 実測)。
version は 4 箇所で宣言されているが、それらが同値であることを保証する機械が
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
  parity        宣言 4 箇所の値が全て一致するか

rc: 0 = OK / 1 = 違反 / 2 = 使い方エラー / 3 = 前提不足 (root が repo でない)
"""

import argparse
import glob
import json
import os
import re
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
# 「plugin manifest の族」を glob で定義し、族の外は対象外だと明示する。
MANIFEST_GLOBS = (
    ".claude-plugin/*.json",
    ".codex-plugin/*.json",
    "plugin/*/.claude-plugin/*.json",
    "plugin/*/.codex-plugin/*.json",
)

VERSION_VALUE_RE = re.compile(r"^\d+\.\d+\.\d+")


def _walk(node, prefix, out):
    """version らしき値を持つ全パスを (path, value) で集める。"""
    if isinstance(node, dict):
        for key, value in node.items():
            path = "%s.%s" % (prefix, key) if prefix else key
            if key == "version" and isinstance(value, str) and VERSION_VALUE_RE.match(value):
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


def discovered(root):
    """[(key, value)] を返す (ソート済み)。"""
    rows = []
    seen = set()
    for pattern in MANIFEST_GLOBS:
        for abspath in sorted(glob.glob(os.path.join(root, pattern))):
            relpath = os.path.relpath(abspath, root).replace(os.sep, "/")
            if relpath in seen:
                continue
            seen.add(relpath)
            doc, _err = _load(abspath)
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
