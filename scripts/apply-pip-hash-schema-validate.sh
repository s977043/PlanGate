#!/bin/sh
# scripts/apply-pip-hash-schema-validate.sh
# .github/workflows/schema-validate.yml の pip install を hash 付きに変更（Scorecard #17）
#
# .github/workflows/*.yml は Hardening Override 対象のため AI が直接編集できない。
# このスクリプトを生成し、--apply は Human が実行する。
#
# 使い方:
#   sh scripts/apply-pip-hash-schema-validate.sh --dry-run
#   sh scripts/apply-pip-hash-schema-validate.sh --apply
set -eu
MODE="${1:---dry-run}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TARGET="$ROOT/.github/workflows/schema-validate.yml"

[ -f "$TARGET" ] || { printf 'ERROR: %s not found\n' "$TARGET" >&2; exit 1; }

# 冪等チェック
if grep -q 'require-hashes' "$TARGET" 2>/dev/null; then
  printf 'SKIP (already applied): --require-hashes は既に存在します\n'
  exit 0
fi

# アンカー確認
if ! grep -qF "pip install 'jsonschema==4.23.0'" "$TARGET"; then
  printf 'ERROR: アンカー行が見つかりません（workflow 構造が変化している可能性あり）\n' >&2
  exit 1
fi

OLD="      - name: Install jsonschema
        run: pip install 'jsonschema==4.23.0'"

NEW="      - name: Install jsonschema
        run: pip install --require-hashes -r requirements/schema-validate.txt"

if [ "$MODE" = "--dry-run" ]; then
  printf '[dry-run] 以下の変更を適用します:\n'
  printf '  FROM: %s\n' "$OLD"
  printf '  TO:   %s\n' "$NEW"
  exit 0
elif [ "$MODE" = "--apply" ]; then
  python3 - "$TARGET" << 'PY'
import sys, pathlib
target = pathlib.Path(sys.argv[1])
old = "      - name: Install jsonschema\n        run: pip install 'jsonschema==4.23.0'"
new = "      - name: Install jsonschema\n        run: pip install --require-hashes -r requirements/schema-validate.txt"
content = target.read_text(encoding='utf-8')
if old not in content:
    print('ERROR: anchor not found', file=sys.stderr); sys.exit(1)
target.write_text(content.replace(old, new, 1), encoding='utf-8')
print('APPLIED: pip install → --require-hashes -r requirements/schema-validate.txt')
PY
else
  printf 'usage: %s [--dry-run|--apply]\n' "$0" >&2; exit 1
fi
