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

__doc__ = """schema_mapping.py — PlanGate 共通 schema マッピング

Issue #172 / TASK-0051 — `scripts/validate-schemas.py` と
`scripts/eval-runner.py` が同じ FILENAME_TO_SCHEMA を参照できるよう
1 箇所に集約したモジュール。

両 script は実行時に `sys.path.insert(0, str(REPO_ROOT / "scripts"))` を
してから `from schema_mapping import FILENAME_TO_SCHEMA, lookup_schema`
で読み込む。
"""

from pathlib import Path

import sys as _phsys; from pathlib import Path as _phP; _phsys.path.insert(0, str(_phP(__file__).resolve().parent))
from _paths import REPO_ROOT, SCHEMAS_DIR  # noqa: E402

# basename → schema filename
# 新 schema を追加するときは本ファイルにエントリを足すだけ。
FILENAME_TO_SCHEMA: dict[str, str] = {
    "c3.json": "c3-approval.schema.json",
    "c4-approval.json": "c4-approval.schema.json",
    "review-result.json": "review-result.schema.json",
    "review-self.json": "review-self.schema.json",
    "review-external.json": "review-external.schema.json",
    "acceptance-result.json": "acceptance-result.schema.json",
    "handoff-summary.json": "handoff-summary.schema.json",
    "mode-classification.json": "mode-classification.schema.json",
    "model-profile.json": "model-profile.schema.json",
    "status.json": "status.schema.json",
    "todo.json": "todo.schema.json",
    "test-cases.json": "test-cases.schema.json",
    "handoff.json": "handoff.schema.json",
    "pbi-input.json": "pbi-input.schema.json",
    "plan.json": "plan.schema.json",
    "run-event.json": "run-event.schema.json",
    # v8.6.0 PR5 (J-1): baseline snapshot 整合性を validate-schemas に統合
    # NDJSON である plangate-event.schema.json は本マッピングに含めない
    # （append-only NDJSON は plangate metrics --validate で検査する設計）
    "2026-05-04-baseline.json": "eval-baseline.schema.json",
    "plan-quality-check.json": "plan-quality-check.schema.json",
    "eval-comparison.json": "eval-comparison.schema.json",
    "context-manifest.json": "context-manifest.schema.json",
    "keep-rate-result.json": "keep-rate-result.schema.json",
}


def _dispatch_by_approval_kind(json_path: Path, schema_name: str) -> str:
    """c3.json の approval_kind による schema dispatch（TASK-0872 / R-006）。

    approvals/c3.json は legacy（approval_kind キーなし → c3-approval.schema.json）と
    c3-prime（approval_kind == "c3-prime" → c3-prime.schema.json）の 2 形式が同一
    basename を共有する。ファイル内容で判別する（契約正本:
    docs/workflows/ai-loop/c3-prime-contract.md §4）。JSON として読めない場合は
    legacy 側へ倒す（不正 JSON は schema 検証そのものが FAIL として捕捉する）。
    """
    if json_path.name != "c3.json":
        return schema_name
    try:
        import json

        data = json.loads(json_path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return schema_name
    if isinstance(data, dict) and data.get("approval_kind") == "c3-prime":
        return "c3-prime.schema.json"
    return schema_name


def lookup_schema(json_path: Path) -> Path | None:
    """JSON ファイルパスから対応する schema ファイルパスを返す（無ければ None）"""
    schema_name = FILENAME_TO_SCHEMA.get(json_path.name)
    if schema_name is None:
        return None
    dispatched = _dispatch_by_approval_kind(json_path, schema_name)
    schema_path = SCHEMAS_DIR / dispatched
    if dispatched != schema_name and not schema_path.is_file():
        # dispatch 先（c3-prime.schema.json）が未配置: None（=SKIP）に落とすと
        # c3-prime artifact が沈黙スキップされる fail-open 窓になるため、存在
        # しないパスをそのまま返し validate-schemas 側の読み込み ERROR で
        # fail-closed にする（#887 F-8。schema は PR-2 で配置される）。
        return schema_path
    return schema_path if schema_path.is_file() else None
