#!/usr/bin/env python3
"""validate-yaml-schemas.py — yaml 設定ファイルの JSON Schema 検証（issue #521）

schema を持つ yaml 実体が CI を素通りする Shadow Spec（2026-06-10 棚卸し）の解消。
bin/plangate validate-schemas は JSON 専用のため、yaml は本スクリプトが担う。
tests/extras/ta-35 から呼ばれ「plangate CLI tests」CI ジョブで全 PR 検証される。

usage: python3 scripts/validate-yaml-schemas.py [--file YAML --schema SCHEMA]
  引数なし: 既知ペアを一括検証（存在しない optional yaml は SKIP）
exit code: 0=全 PASS / 1=FAIL あり / 2=依存欠如
"""
import json
import os
import sys

try:
    import yaml
    import jsonschema
except ImportError as e:
    print(f"SKIP: dependency missing ({e})")
    sys.exit(2)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# (yaml, schema, required) — required=False は存在時のみ検証
KNOWN_PAIRS = [
    ("docs/ai/model-profiles.yaml", "schemas/model-profile.schema.json", True),
    (".plangate-pollution-patterns.yaml", "schemas/plangate-pollution-patterns.schema.json", True),
    (".plangate-reviewers.yaml", "schemas/plangate-reviewers.schema.json", False),
]


def validate_pair(yaml_path: str, schema_path: str) -> str | None:
    """戻り値: None=PASS / エラーメッセージ=FAIL"""
    with open(yaml_path, encoding="utf-8") as f:
        data = yaml.safe_load(f)
    with open(schema_path, encoding="utf-8") as f:
        schema = json.load(f)
    try:
        jsonschema.validate(data, schema)
        return None
    except jsonschema.ValidationError as e:
        return f"{e.json_path}: {e.message}"


def main() -> int:
    if len(sys.argv) == 5 and sys.argv[1] == "--file" and sys.argv[3] == "--schema":
        pairs = [(sys.argv[2], sys.argv[4], True)]
    else:
        pairs = [(os.path.join(ROOT, y), os.path.join(ROOT, s), req)
                 for y, s, req in KNOWN_PAIRS]

    failed = False
    for yaml_path, schema_path, required in pairs:
        rel = os.path.relpath(yaml_path, ROOT) if yaml_path.startswith(ROOT) else yaml_path
        if not os.path.exists(yaml_path):
            if required:
                print(f"FAIL {rel}: file not found")
                failed = True
            else:
                print(f"SKIP {rel}: not present (optional)")
            continue
        err = validate_pair(yaml_path, schema_path)
        if err is None:
            print(f"PASS {rel}")
        else:
            print(f"FAIL {rel}: {err}")
            failed = True
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
