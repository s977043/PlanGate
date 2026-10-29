"""Size limits for the ai-loop V2 DecisionInput (#1393 I-11, R-086 / R-087 / R-090 / R-091).

Leaf module: imports no other ai-loop-v2 module. Values are provisional and fixed
by test_limits.py. The byte constants of the decision_made event are defined by a
follow-up task once the V2 decision_made structure is fixed (R-091).
"""
from __future__ import annotations

MAX_INPUT_REFS = 256
MAX_REQUIRED_VERIFIERS = 16
MAX_REF_CHARS = 71  # len("sha256:" + 64 lowercase hex), #1391 R-064
