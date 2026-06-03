#!/bin/sh
# apply-spec-check-to-workflow.sh — sync-plugin-plangate.yml に spec check ステップを追加
# Human が実行してください: sh scripts/apply-spec-check-to-workflow.sh

set -eu

REPO_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
WF="$REPO_ROOT/.github/workflows/sync-plugin-plangate.yml"

if ! [ -f "$WF" ]; then
  printf 'ERROR: %s not found\n' "$WF" >&2; exit 1
fi

if grep -q 'Codex skill spec check' "$WF"; then
  printf 'Already applied — skipping.\n'; exit 0
fi

python3 - "$WF" << 'PYEOF'
import sys
path = sys.argv[1]
with open(path, encoding="utf-8") as fh:
    content = fh.read()
old = '      - name: Run sync script\n        run: sh scripts/sync-plugin-plangate.sh'
new = ('      - name: Codex skill spec check\n'
       '        run: sh scripts/check-codex-skill-spec.sh --warn-only\n\n'
       '      - name: Run sync script\n'
       '        run: sh scripts/sync-plugin-plangate.sh')
assert old in content, f'Pattern not found in {path}'
content = content.replace(old, new)
with open(path, "w", encoding="utf-8") as fh:
    fh.write(content)
print(f'Patched: {path}')
PYEOF

printf 'Done. Commit with:\n'
printf '  git add .github/workflows/sync-plugin-plangate.yml\n'
printf '  git commit -m "chore: sync workflow に spec check ステップを追加"\n'
