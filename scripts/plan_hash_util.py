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

__doc__ = """plan_hash_util.py — plan_hash 抽出/生成の共有正本（#193 follow-up / TASK-0100).

EH-3（scripts/hooks/check-plan-hash.sh）が承認境界の **shell 正本**。本 util は
Python 側消費者（keep-rate / context-engine / metrics_collector）の plan_hash
ロジック重複を 1 箇所へ集約する。

設計判断（実証検証で確定 / TASK-0100 handoff §4）:
- c3.json は **strict JSON で読む**（json.loads）。これは shell(sed) より
  厳格で、**不正 JSON の c3.json を承認記録として信用しない**＝承認境界を
  弱めない安全側。正常系では shell(sed) と完全一致（fixture で保証）。
- shell EH-3 の実行経路は変更しない（Non-goal）。本 util は Python 消費者
  専用の共有実装であり EH-3 を代替しない。

import 方法: `sys.path.insert(0, str(REPO/"scripts")); import plan_hash_util`
（schema_mapping.py と同方式）。
"""

import hashlib
import json
from pathlib import Path

_PREFIX = "sha256:"


def current_plan_hash(plan_path: Path) -> str:
    """plan.md の SHA-256 hexdigest（prefix なし）。OSError は呼び出し側責務。"""
    return hashlib.sha256(plan_path.read_bytes()).hexdigest()


def current_plan_hash_prefixed(plan_path: Path) -> str:
    """`sha256:<hex>` 形式（metrics event / c3.json の plan_hash 表記）。"""
    return _PREFIX + current_plan_hash(plan_path)


def recorded_plan_hash(c3_path: Path) -> str | None:
    """c3.json の plan_hash の sha256 hex 部を返す（strict JSON）。

    欠落 / 不正 JSON / 読込不可 / prefix 不一致 は None。
    strict JSON 採用理由は本モジュール docstring 参照（承認境界保護）。
    """
    try:
        data = json.loads(c3_path.read_text())
    except (OSError, ValueError):
        return None
    if not isinstance(data, dict):
        return None  # c3.json が object でない = 承認記録として信用しない
    value = data.get("plan_hash", "")
    if isinstance(value, str) and value.startswith(_PREFIX):
        return value[len(_PREFIX):]
    return None
