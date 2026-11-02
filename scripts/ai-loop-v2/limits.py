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
# Size limits for the ai-loop V2 DecisionInput (#1393 I-11, R-086 / R-087 / R-090 / R-091).
#
# Leaf module: imports no other ai-loop-v2 module. Values are provisional and fixed
# by test_limits.py. The byte constants of the decision_made event are defined by a
# follow-up task once the V2 decision_made structure is fixed (R-091).
from __future__ import annotations

MAX_INPUT_REFS = 256
MAX_REQUIRED_VERIFIERS = 16
MAX_REF_CHARS = 71  # len("sha256:" + 64 lowercase hex), #1391 R-064
