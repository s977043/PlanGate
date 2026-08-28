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

from __future__ import annotations

__doc__ = """_paths.py — scripts 共有パス定数（#277 / reuse M-2 / EPIC #193 follow-up).

scripts/*.py に重複していた REPO ルート / docs/working / schemas /
scripts ディレクトリの算出を 1 箇所へ集約する。固定定数のみ。
環境変数 override / 設定注入 / package 化はしない（YAGNI・Codex 助言）。

import 方法（既存 sys.path.insert 慣習と整合）:
- 直接実行（python3 scripts/foo.py）: scripts/ が sys.path[0] に入るため
  `from _paths import REPO_ROOT, WORKING_DIR` がそのまま動く。
- 別 script から import される場合: 呼び出し側の
  `sys.path.insert(0, str(REPO_ROOT / "scripts"))` 慣習を維持すれば解決。

shell / hooks は対象外（本モジュールは Python 消費者専用）。
"""

from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
SCRIPTS_DIR = REPO_ROOT / "scripts"
WORKING_DIR = REPO_ROOT / "docs" / "working"
SCHEMAS_DIR = REPO_ROOT / "schemas"
