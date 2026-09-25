#!/usr/bin/env python3
"""Resolve a declared PlanGate profile to a safe Codex CLI model ID."""

from __future__ import annotations

import re
import sys
from pathlib import Path

import yaml


MODEL_ID_PATTERN = re.compile(r"^gpt-[A-Za-z0-9._-]+$")


def fail(message: str) -> int:
    print(f"model profile resolution failed: {message}", file=sys.stderr)
    return 1


def main(argv: list[str]) -> int:
    if len(argv) not in (2, 3, 4):
        return fail("usage: _resolve_model_id.py PROFILE [MODEL_PROFILES_YAML] [MODE]")

    profile_key = argv[1]
    config_path = Path(argv[2]) if len(argv) >= 3 else Path("docs/ai/model-profiles.yaml")
    mode = argv[3] if len(argv) == 4 else ""

    try:
        document = yaml.safe_load(config_path.read_text(encoding="utf-8"))
    except (OSError, yaml.YAMLError) as error:
        return fail(f"cannot read {config_path}: {error}")

    models = document.get("models") if isinstance(document, dict) else None
    profile = models.get(profile_key) if isinstance(models, dict) else None
    if not isinstance(profile, dict):
        return fail(f"unknown profile: {profile_key}")

    model_id = profile.get("model_id")
    if not isinstance(model_id, str) or not MODEL_ID_PATTERN.fullmatch(model_id):
        return fail(f"profile {profile_key} has no valid model_id")

    disallowed_modes = profile.get("disallowed_modes", [])
    if not isinstance(disallowed_modes, list) or not all(isinstance(item, str) for item in disallowed_modes):
        return fail(f"profile {profile_key} has invalid disallowed_modes")
    if disallowed_modes:
        if not mode:
            return fail(f"profile {profile_key} requires --mode because it has disallowed_modes")
        yaml_mode = mode.replace("-", "_")
        if yaml_mode in disallowed_modes:
            return fail(f"profile {profile_key} is disallowed for mode: {mode}")

    print(model_id)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
