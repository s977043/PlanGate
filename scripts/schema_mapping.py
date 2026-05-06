"""schema_mapping.py — PlanGate 共通 schema マッピング

Issue #172 / TASK-0051 — `scripts/validate-schemas.py` と
`scripts/eval-runner.py` が同じ FILENAME_TO_SCHEMA を参照できるよう
1 箇所に集約したモジュール。

両 script は実行時に `sys.path.insert(0, str(REPO_ROOT / "scripts"))` を
してから `from schema_mapping import FILENAME_TO_SCHEMA, lookup_schema`
で読み込む。
"""
from __future__ import annotations

from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
SCHEMAS_DIR = REPO_ROOT / "schemas"

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
}


def lookup_schema(json_path: Path) -> Path | None:
    """JSON ファイルパスから対応する schema ファイルパスを返す（無ければ None）"""
    schema_name = FILENAME_TO_SCHEMA.get(json_path.name)
    if schema_name is None:
        return None
    schema_path = SCHEMAS_DIR / schema_name
    return schema_path if schema_path.is_file() else None
