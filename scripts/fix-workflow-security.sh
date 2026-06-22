#!/bin/sh
# scripts/fix-workflow-security.sh — OpenSSF Scorecard セキュリティアラート修正
#
# 修正対象 (open alerts):
#   Pinned-Dependencies #25/26/27/28/29: actions/checkout@v7 → SHA ピン（全5ファイル）
#   Pinned-Dependencies #15:             actions/setup-python@v6 → SHA ピン
#   Pinned-Dependencies #17:             pip install 'jsonschema>=4,<5' → ==4.23.0
#   Token-Permissions #21/#18:           トップレベル contents:write → permissions:{} + job レベル移動
#
# .github/workflows/*.yml は Hardening Override (HO) 対象のため AI が本スクリプトを生成し、
# --apply は Human が実行する（docs/ai/responsibility-classes.md AI/Human 分界）。
#
# 使い方:
#   sh scripts/fix-workflow-security.sh --dry-run   # 差分確認（変更なし）
#   sh scripts/fix-workflow-security.sh --apply     # 適用（冪等）

set -eu
MODE="${1:---dry-run}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

CHECKOUT_V7_SHA="9c091bb21b7c1c1d1991bb908d89e4e9dddfe3e0"
SETUP_PYTHON_V6_SHA="a309ff8b426b58ec0e2a45f0f869d46889d02405"

if [ "$MODE" = "--dry-run" ]; then
  printf '[dry-run] 以下の変更を .github/workflows/ に適用します:\n\n'
  printf '  1. actions/checkout@v7  → @%s # v7  (5ファイル)\n' "$CHECKOUT_V7_SHA"
  printf '  2. actions/setup-python@v6 → @%s # v6  (schema-validate.yml)\n' "$SETUP_PYTHON_V6_SHA"
  printf '  3. pip install jsonschema>=4,<5 → jsonschema==4.23.0  (schema-validate.yml)\n'
  printf '  4. sync-plugin-plangate.yml: workflow-level permissions:{write} → permissions:{} + job-level\n'
  printf '  5. release-docs-sync.yml:    workflow-level permissions:{write} → permissions:{} + job-level\n'
  exit 0
elif [ "$MODE" != "--apply" ]; then
  printf 'usage: %s [--dry-run|--apply]\n' "$0" >&2
  exit 1
fi

python3 - "$ROOT" "$CHECKOUT_V7_SHA" "$SETUP_PYTHON_V6_SHA" << 'PY'
import sys, pathlib, re

root   = pathlib.Path(sys.argv[1])
co_sha = sys.argv[2]
py_sha = sys.argv[3]

WF = root / '.github' / 'workflows'

def pin_checkout(text, sha):
    return re.sub(r'(uses:\s*)actions/checkout@v7\b', rf'\1actions/checkout@{sha} # v7', text)

def pin_setup_python(text, sha):
    return re.sub(r'(uses:\s*)actions/setup-python@v6\b', rf'\1actions/setup-python@{sha} # v6', text)

def pin_pip_jsonschema(text):
    return text.replace("pip install 'jsonschema>=4,<5'", "pip install 'jsonschema==4.23.0'")

def move_permissions_to_job(text, job_name):
    if 'permissions: {}' in text:
        return text
    text = re.sub(
        r'^permissions:\n  contents: write\n  pull-requests: write\n',
        'permissions: {}\n', text, flags=re.MULTILINE
    )
    job_perms = '    permissions:\n      contents: write\n      pull-requests: write\n'
    text = re.sub(rf'^(  {re.escape(job_name)}:\n)', rf'\1{job_perms}', text, count=1, flags=re.MULTILINE)
    return text

changes = []

for fname, ops in [
    ('sync-plugin-plangate.yml',  ['checkout', 'perm_sync']),
    ('schema-validate.yml',       ['checkout', 'setup_python', 'pip']),
    ('release-docs-sync.yml',     ['checkout', 'perm_sync']),
    ('metrics-privacy.yml',       ['checkout']),
    ('check-pr-issue-link.yml',   ['checkout']),
]:
    f = WF / fname
    t = orig = f.read_text(encoding='utf-8')
    if 'checkout' in ops:    t = pin_checkout(t, co_sha)
    if 'setup_python' in ops: t = pin_setup_python(t, py_sha)
    if 'pip' in ops:         t = pin_pip_jsonschema(t)
    if 'perm_sync' in ops:   t = move_permissions_to_job(t, 'sync')
    if t != orig:
        f.write_text(t, encoding='utf-8')
        changes.append(fname)

print('APPLIED to:', ', '.join(changes) if changes else '(none — already applied)')
PY
