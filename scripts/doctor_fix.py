#!/usr/bin/env python3
"""
PlanGate Doctor Fix — TASK-0069.

Deterministically wires PlanGate hooks into `.claude/settings.json` by merging
the hook blocks defined in `.claude/settings.example.json` (the source of truth).

Design constraints (plan.md Step 2 / Constraints):
    - merge-only: never drop or overwrite existing user keys
    - backup required: write a `.bak` before modifying an existing settings.json
      (new-create needs no backup). If `.bak` already exists, rotate it to
      `.bak.<epoch>` first (never overwrite an existing backup).
    - idempotent: a second run is a byte-identical no-op
    - invalid JSON in settings.json → abort, no changes made, no `.bak`
    - standard library only (no jq, no third-party deps)

Wiring unit: a hook is identified by the tuple
(event, matcher, type, command). The example's double-list structure
`hooks.<event>[].hooks[]` is preserved on merge.

Usage:
    python3 scripts/doctor_fix.py --project-dir DIR (--check | --apply | --dry-run)

Exit codes:
    0 — success / (with --check) all expected hooks already wired
    1 — (with --check) one or more expected hooks not wired
    2 — error (invalid JSON, write failure, bad arguments)
"""

from __future__ import annotations

import argparse
import json
import sys
import time
from pathlib import Path

META_KEYS = ("_comment_", "_usage_")


def _strip_meta(obj):
    """Drop leading-underscore metadata keys recursively from dict/list."""
    if isinstance(obj, dict):
        return {k: _strip_meta(v) for k, v in obj.items() if k not in META_KEYS}
    if isinstance(obj, list):
        return [_strip_meta(v) for v in obj]
    return obj


def _block_key(event: str, matcher, htype: str, command: str) -> tuple:
    """Identity tuple for a single hook (event, matcher, type, command)."""
    return (event, matcher, htype, command)


def expected_hooks(example: dict) -> list[tuple]:
    """Extract the expected (event, matcher, type, command) set from example."""
    keys: list[tuple] = []
    for event, blocks in example.get("hooks", {}).items():
        if not isinstance(blocks, list):
            continue
        for block in blocks:
            if not isinstance(block, dict):
                continue
            matcher = block.get("matcher")
            for h in block.get("hooks", []) or []:
                if isinstance(h, dict):
                    keys.append(_block_key(event, matcher, h.get("type"), h.get("command")))
    return keys


def present_hooks(settings: dict) -> set[tuple]:
    """Identity tuples already wired in settings.json."""
    found: set[tuple] = set()
    for event, blocks in settings.get("hooks", {}).items():
        if not isinstance(blocks, list):
            continue
        for block in blocks:
            if not isinstance(block, dict):
                continue
            matcher = block.get("matcher")
            for h in block.get("hooks", []) or []:
                if isinstance(h, dict):
                    found.add(_block_key(event, matcher, h.get("type"), h.get("command")))
    return found


def missing_hooks(example: dict, settings: dict) -> list[tuple]:
    have = present_hooks(settings)
    return [k for k in expected_hooks(example) if k not in have]


def merge_hooks(example: dict, settings: dict) -> dict:
    """Return a new settings dict with missing example hook blocks appended.

    The example's double-list structure is preserved: each example block
    (matcher + its hooks list) that is not already fully present is appended
    under its event as-is (meta keys stripped).
    """
    result = json.loads(json.dumps(settings))  # deep copy
    have = present_hooks(result)
    result.setdefault("hooks", {})
    for event, blocks in example.get("hooks", {}).items():
        if not isinstance(blocks, list):
            continue
        for block in blocks:
            if not isinstance(block, dict):
                continue
            matcher = block.get("matcher")
            missing_inner = [
                h
                for h in block.get("hooks", []) or []
                if isinstance(h, dict)
                if _block_key(event, matcher, h.get("type"), h.get("command")) not in have
            ]
            if not missing_inner:
                continue
            new_block: dict = {}
            if matcher is not None:
                new_block["matcher"] = matcher
            new_block["hooks"] = missing_inner
            result["hooks"].setdefault(event, [])
            if not isinstance(result["hooks"][event], list):
                result["hooks"][event] = []
            result["hooks"][event].append(new_block)
            for h in missing_inner:
                have.add(_block_key(event, matcher, h.get("type"), h.get("command")))
    return result


def _serialize(settings: dict) -> str:
    return json.dumps(settings, indent=2, ensure_ascii=False) + "\n"


def load_example(claude_dir: Path) -> dict:
    example_path = claude_dir / "settings.example.json"
    if not example_path.is_file():
        raise FileNotFoundError(f"missing: {example_path}")
    return _strip_meta(json.loads(example_path.read_text(encoding="utf-8")))


def load_settings(settings_path: Path) -> dict | None:
    """Return parsed settings, {} if absent. Raise ValueError on invalid JSON."""
    if not settings_path.is_file():
        return None
    raw = settings_path.read_text(encoding="utf-8")
    try:
        return json.loads(raw)
    except json.JSONDecodeError as exc:
        raise ValueError(
            f"{settings_path} is not valid JSON — aborting, no changes made"
        ) from exc


def cmd_check(claude_dir: Path) -> int:
    example = load_example(claude_dir)
    settings_path = claude_dir / "settings.json"
    try:
        settings = load_settings(settings_path)
    except ValueError as exc:
        print(f"[error] {exc}", file=sys.stderr)
        return 2
    if settings is None:
        settings = {}
    miss = missing_hooks(example, settings)
    if miss:
        print(f"[fail] PlanGate hooks not wired: {len(miss)} block(s) missing")
        return 1
    print("[ok] all PlanGate hook blocks wired")
    return 0


def cmd_dry_run(claude_dir: Path) -> int:
    example = load_example(claude_dir)
    settings_path = claude_dir / "settings.json"
    try:
        settings = load_settings(settings_path)
    except ValueError as exc:
        print(f"[error] {exc}", file=sys.stderr)
        return 2
    if settings is None:
        print("plan: create .claude/settings.json with PlanGate hook blocks")
        settings = {}
    miss = missing_hooks(example, settings)
    if not miss:
        print("plan: nothing to do — already wired (no-op)")
        return 0
    print(f"plan: would add {len(miss)} hook block(s) (merge-only, no files written):")
    for event, matcher, htype, command in miss:
        print(f"  + [{event}] matcher={matcher!r} {htype}: {command}")
    print("(dry-run: no settings.json or .bak changes)")
    return 0


def cmd_apply(claude_dir: Path) -> int:
    example = load_example(claude_dir)
    settings_path = claude_dir / "settings.json"

    existed = settings_path.is_file()
    try:
        settings = load_settings(settings_path)
    except ValueError as exc:
        print(f"[error] {exc}", file=sys.stderr)
        return 2
    if settings is None:
        settings = {}

    merged = merge_hooks(example, settings)
    new_text = _serialize(merged)

    # Idempotent no-op: byte-identical → do not touch file or write backup.
    if existed and settings_path.read_text(encoding="utf-8") == new_text:
        print("[ok] already wired — no changes (idempotent no-op)")
        return 0
    if not existed and not missing_hooks(example, {}):
        # example has no hooks at all — nothing to wire
        pass

    try:
        if existed:
            backup = settings_path.with_name(settings_path.name + ".bak")
            if backup.exists():
                # Rotate the existing .bak out of the way WITHOUT ever
                # overwriting any pre-existing backup (incl. a prior
                # .bak.<epoch> from a same-second run). Find the first
                # free suffix deterministically.
                base = f"{settings_path.name}.bak.{int(time.time())}"
                rotated = settings_path.with_name(base)
                seq = 0
                while rotated.exists():
                    seq += 1
                    rotated = settings_path.with_name(f"{base}-{seq}")
                backup.replace(rotated)
            backup.write_text(
                settings_path.read_text(encoding="utf-8"), encoding="utf-8"
            )
        # atomic-ish write via temp file in same dir, then replace
        tmp = settings_path.with_name(settings_path.name + ".tmp")
        tmp.write_text(new_text, encoding="utf-8")
        tmp.replace(settings_path)
    except OSError as exc:
        print(
            f"[error] failed to write {settings_path}: {exc} — no partial write",
            file=sys.stderr,
        )
        return 2

    action = "wired" if existed else "created"
    print(f"[ok] settings.json {action} with PlanGate hook blocks")
    return 0


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument(
        "--project-dir",
        default=".",
        help="project root containing .claude/ (default: cwd)",
    )
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--check", action="store_true", help="exit 0 if wired, 1 if not")
    mode.add_argument("--apply", action="store_true", help="merge-only apply + backup")
    mode.add_argument("--dry-run", action="store_true", help="print plan, write nothing")
    args = parser.parse_args(argv)

    claude_dir = Path(args.project_dir).resolve() / ".claude"
    try:
        if args.check:
            return cmd_check(claude_dir)
        if args.dry_run:
            return cmd_dry_run(claude_dir)
        return cmd_apply(claude_dir)
    except FileNotFoundError as exc:
        print(f"[error] {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
