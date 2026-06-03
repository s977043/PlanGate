#!/bin/sh
# check-codex-skill-spec.sh — .codex/skills/ の openai.yaml 仕様チェック
# 仕様: https://openai.com/academy/codex-plugins-and-skills/
#
# Usage: sh scripts/check-codex-skill-spec.sh [--warn-only] [--target DIR]
# Exit: 0=OK, 1=violation(s) found (--warn-only 時は常に 0)

set -eu

REPO_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
TARGET_DIR="$REPO_ROOT/.codex/skills"
WARN_ONLY=0

while [ $# -gt 0 ]; do
  case "$1" in
    --warn-only) WARN_ONLY=1; shift ;;
    --target)    TARGET_DIR="$2"; shift 2 ;;
    *) printf 'Unknown option: %s\n' "$1" >&2; exit 1 ;;
  esac
done

python3 - "$TARGET_DIR" "$WARN_ONLY" << 'PYEOF'
import os, re, sys, json

target_dir = sys.argv[1]
warn_only = sys.argv[2] == '1'

violations = []
checked = 0

for name in sorted(os.listdir(target_dir)):
    if name.startswith('.'): continue
    yaml_path = os.path.join(target_dir, name, 'agents', 'openai.yaml')
    if not os.path.exists(yaml_path): continue
    checked += 1
    with open(yaml_path, encoding='utf-8') as fh:
        content = fh.read()

    # short_description: 25-64 chars
    m = re.search(r'short_description:\s*"([^"]*)"', content)
    if not m:
        violations.append(f'{name}: short_description missing')
    else:
        sd = m.group(1)
        if len(sd) < 25:
            violations.append(f'{name}: short_description too short ({len(sd)} chars, min 25): "{sd}"')
        elif len(sd) > 64:
            violations.append(f'{name}: short_description too long ({len(sd)} chars, max 64): "{sd}"')

    # default_prompt: must contain $skill-name
    m2 = re.search(r'default_prompt:\s*"([^"]*)"', content)
    if not m2:
        violations.append(f'{name}: default_prompt missing')
    else:
        dp = m2.group(1)
        if f'${name}' not in dp:
            violations.append(f'{name}: default_prompt does not contain "${name}": "{dp[:50]}"')

    # icon_small / icon_large
    if 'icon_small' not in content:
        violations.append(f'{name}: icon_small missing')
    if 'icon_large' not in content:
        violations.append(f'{name}: icon_large missing')

print(f'[spec-check] Checked {checked} skills in {target_dir}')
if violations:
    print(f'[spec-check] VIOLATIONS ({len(violations)}):')
    for v in violations:
        print(f'  - {v}')
    if not warn_only:
        sys.exit(1)
    else:
        print('[spec-check] --warn-only: continuing despite violations')
else:
    print('[spec-check] All skills PASS spec check')
PYEOF
