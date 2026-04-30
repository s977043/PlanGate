#!/usr/bin/env python3
"""validate-schemas.py — JSON ファイル群を schemas/ で検証する

PlanGate Issue #158 / TASK-0047 — Structured Outputs CI 統合の中核。

Usage:
    python3 scripts/validate-schemas.py <file>...
    python3 scripts/validate-schemas.py --dir <task-dir>
    python3 scripts/validate-schemas.py --files-from <list-file>

ファイル名（basename）→ schema のマッピングで自動検出する。マッピング外は skip。

Exit code:
    0  すべて PASS / SKIP（違反なし）
    1  schema 違反あり
    2  内部エラー（jsonschema 未インストール 等）
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Iterable

REPO_ROOT = Path(__file__).resolve().parents[1]
SCHEMAS_DIR = REPO_ROOT / "schemas"

# basename → schema filename
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
}


def lookup_schema(json_path: Path) -> Path | None:
    schema_name = FILENAME_TO_SCHEMA.get(json_path.name)
    if schema_name is None:
        return None
    schema_path = SCHEMAS_DIR / schema_name
    return schema_path if schema_path.is_file() else None


def validate_one(json_path: Path) -> tuple[str, str]:
    """Return (status, message) where status in {'PASS', 'FAIL', 'SKIP', 'ERROR'}."""
    if not json_path.is_file():
        return ("ERROR", f"file not found: {json_path}")

    schema_path = lookup_schema(json_path)
    if schema_path is None:
        return ("SKIP", f"no schema mapping for {json_path.name}")

    try:
        from jsonschema import Draft202012Validator
    except ImportError:
        return (
            "ERROR",
            "jsonschema not installed. Run: pip install 'jsonschema>=4,<5'",
        )

    try:
        with json_path.open() as f:
            instance = json.load(f)
        with schema_path.open() as f:
            schema = json.load(f)
    except json.JSONDecodeError as e:
        return ("FAIL", f"invalid JSON: {e}")
    except OSError as e:
        return ("ERROR", f"read error: {e}")

    validator = Draft202012Validator(schema)
    errors = sorted(validator.iter_errors(instance), key=lambda e: e.path)
    if errors:
        first = errors[0]
        path = "/".join(str(p) for p in first.absolute_path) or "<root>"
        return (
            "FAIL",
            f"{json_path.name} ↔ {schema_path.name}: {len(errors)} error(s); first at {path}: {first.message}",
        )
    return ("PASS", f"{json_path.name} ↔ {schema_path.name}")


def collect_paths(args: argparse.Namespace) -> list[Path]:
    paths: list[Path] = []
    if args.dir:
        base = Path(args.dir).resolve()
        if not base.is_dir():
            print(f"error: --dir not a directory: {base}", file=sys.stderr)
            sys.exit(2)
        paths.extend(sorted(base.rglob("*.json")))
    if args.files_from:
        list_path = Path(args.files_from)
        if not list_path.is_file():
            print(f"error: --files-from not found: {list_path}", file=sys.stderr)
            sys.exit(2)
        for line in list_path.read_text().splitlines():
            line = line.strip()
            if line and not line.startswith("#"):
                paths.append(Path(line))
    paths.extend(Path(p) for p in args.files)
    return paths


def main(argv: Iterable[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Validate JSON artifacts against PlanGate schemas/."
    )
    parser.add_argument("files", nargs="*", help="JSON files to validate")
    parser.add_argument("--dir", help="recursively scan a directory for *.json")
    parser.add_argument(
        "--files-from",
        help="read newline-separated paths from a file (e.g. git diff output)",
    )
    parser.add_argument(
        "--quiet",
        action="store_true",
        help="suppress PASS/SKIP lines, print only FAIL/ERROR + summary",
    )
    args = parser.parse_args(argv)

    paths = collect_paths(args)
    if not paths:
        print("validate-schemas: no JSON paths supplied (nothing to do)")
        return 0

    seen: set[Path] = set()
    counts = {"PASS": 0, "FAIL": 0, "SKIP": 0, "ERROR": 0}
    failed_msgs: list[str] = []

    for p in paths:
        rp = p.resolve()
        if rp in seen:
            continue
        seen.add(rp)
        status, msg = validate_one(rp)
        counts[status] += 1
        if status in {"FAIL", "ERROR"}:
            print(f"[{status}] {msg}")
            failed_msgs.append(msg)
        elif not args.quiet:
            print(f"[{status}] {msg}")

    print()
    print(
        f"Summary: PASS={counts['PASS']}, FAIL={counts['FAIL']}, "
        f"SKIP={counts['SKIP']}, ERROR={counts['ERROR']}"
    )

    if counts["ERROR"] > 0:
        return 2
    if counts["FAIL"] > 0:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
