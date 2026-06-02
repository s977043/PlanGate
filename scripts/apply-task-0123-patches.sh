#!/bin/sh
# apply-task-0123-patches.sh — TASK-0123 HO ファイル変更適用スクリプト
#
# Human が実行することで Hardening Override 対象ファイルへの変更を適用する。
# べき等性: 2回実行しても壊れない（既存変更の存在チェック付き）
#
# Usage:
#   sh scripts/apply-task-0123-patches.sh [--dry-run]

set -eu

REPO_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
DRY_RUN=0
if [ "${1:-}" = "--dry-run" ]; then
  DRY_RUN=1
fi

_log() { printf '[apply-task-0123] %s\n' "$1"; }
_logdry() { printf '[apply-task-0123][dry-run] %s\n' "$1"; }

_apply() {
  _desc="$1"
  if [ "$DRY_RUN" = "1" ]; then
    _logdry "WOULD APPLY: $_desc"
  else
    _log "APPLYING: $_desc"
  fi
}

_already() {
  _log "SKIP (already applied): $1"
}

###############################################################################
# Patch 1: schemas/maintenance.schema.json — hmac_signature フィールド追加
###############################################################################

SCHEMA_FILE="$REPO_ROOT/schemas/maintenance.schema.json"

_apply "schemas/maintenance.schema.json — hmac_signature フィールド追加"

if python3 -c "import json; d=json.load(open('$SCHEMA_FILE')); exit(0 if 'hmac_signature' in d.get('properties',{}) else 1)" 2>/dev/null; then
  _already "schemas/maintenance.schema.json (hmac_signature already present)"
else
  if [ "$DRY_RUN" = "0" ]; then
    python3 - "$SCHEMA_FILE" <<'PY1'
import json, sys, os
path = sys.argv[1]
with open(path) as f:
    d = json.load(f)
d["properties"]["hmac_signature"] = {
    "type": "string",
    "minLength": 1,
    "description": "HMAC-SHA256 signature of canonical JSON (key=PLANGATE_MAINTENANCE_KEY)"
}
tmp = path + ".tmp"
with open(tmp, "w") as f:
    json.dump(d, f, indent=2, ensure_ascii=False)
    f.write("\n")
os.replace(tmp, path)
print("OK: hmac_signature added to maintenance.schema.json")
PY1
  fi
fi

###############################################################################
# Patch 2: scripts/hooks/check-approval-token-write.sh — 新規作成
###############################################################################

TOKEN_GUARD="$REPO_ROOT/scripts/hooks/check-approval-token-write.sh"
TOKEN_GUARD_SRC="$REPO_ROOT/scripts/check-approval-token-write.sh"

_apply "scripts/hooks/check-approval-token-write.sh — 新規作成"

if [ -f "$TOKEN_GUARD" ]; then
  _already "scripts/hooks/check-approval-token-write.sh (already exists)"
else
  if [ "$DRY_RUN" = "0" ]; then
    if [ ! -f "$TOKEN_GUARD_SRC" ]; then
      printf '[apply-task-0123] ERROR: src not found: %s\n' "$TOKEN_GUARD_SRC" >&2
      exit 1
    fi
    cp "$TOKEN_GUARD_SRC" "$TOKEN_GUARD"
    chmod +x "$TOKEN_GUARD"
    _log "OK: check-approval-token-write.sh copied from scripts/ to scripts/hooks/ and made executable"
  fi
fi

###############################################################################
# Patch 3: scripts/hooks/check-plan-hash.sh — HMAC 署名検証追加
###############################################################################

PLAN_HASH_HOOK="$REPO_ROOT/scripts/hooks/check-plan-hash.sh"

_apply "scripts/hooks/check-plan-hash.sh — HMAC 署名検証ブロック追加"

if grep -q "PLANGATE_MAINTENANCE_KEY" "$PLAN_HASH_HOOK" 2>/dev/null; then
  _already "scripts/hooks/check-plan-hash.sh (HMAC verification already present)"
else
  if [ "$DRY_RUN" = "0" ]; then
    python3 - "$PLAN_HASH_HOOK" << 'PY3'
import sys, os

path = sys.argv[1]
with open(path) as f:
    content = f.read()

hmac_block = '''
  # maintenance.json HMAC 署名検証（TASK-0123）
  if [ -f "$_maint" ]; then
    _maint_sig=$(python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print(d.get('hmac_signature',''))" -- "$_maint" 2>/dev/null || true)
    _maint_key="${PLANGATE_MAINTENANCE_KEY:-}"
    if [ -n "$_maint_sig" ] && [ -n "$_maint_key" ]; then
      _expected_sig=$(python3 -c "
import json, hmac, hashlib, sys
with open(sys.argv[1]) as f:
    d = json.load(f)
d_copy = {k:v for k,v in d.items() if k != 'hmac_signature'}
canonical = json.dumps(d_copy, sort_keys=True, separators=(',',':'))
h = hmac.new(sys.argv[2].encode(), canonical.encode(), hashlib.sha256)
print(h.hexdigest())
" -- "$_maint" "$_maint_key" 2>/dev/null || true)
      if [ -n "$_expected_sig" ] && [ "$_maint_sig" != "$_expected_sig" ]; then
        log_event "MAINTENANCE_HMAC_FAIL" "HMAC署名不一致"
        printf '[EH-3] maintenance.json: HMAC署名不一致（AI自作または改ざんの可能性）\n' >&2
        exit 1
      fi
    elif [ -n "$_maint_sig" ] && [ -z "$_maint_key" ]; then
      log_event "MAINTENANCE_HMAC_NOKEY" "署名あり・鍵未設定 → fail-closed"
      printf '[EH-3] maintenance.json: PLANGATE_MAINTENANCE_KEY 未設定。署名検証不可 → fail-closed\n' >&2
      exit 1
    fi
  fi
'''

# "    esac" の直後（maintenance case ブロックの終端）に挿入
insert_marker = '    esac\n'
idx = content.find(insert_marker)
if idx == -1:
    print("ERROR: insertion point '    esac' not found", file=sys.stderr)
    sys.exit(1)

insert_pos = idx + len(insert_marker)
new_content = content[:insert_pos] + hmac_block + content[insert_pos:]

import shutil, stat
orig_mode = os.stat(path).st_mode
tmp = path + ".tmp"
with open(tmp, "w") as f:
    f.write(new_content)
os.chmod(tmp, stat.S_IMODE(orig_mode))
os.replace(tmp, path)
print("OK: HMAC verification block inserted into check-plan-hash.sh")
PY3
  fi
fi

###############################################################################
# Patch 4: bin/plangate — maintenance start に HMAC 署名追加
###############################################################################

PLANGATE_BIN="$REPO_ROOT/bin/plangate"

_apply "bin/plangate — maintenance start HMAC 署名生成追加"

if grep -q "PLANGATE_MAINTENANCE_KEY" "$PLANGATE_BIN" 2>/dev/null; then
  _already "bin/plangate (HMAC signature generation already present)"
else
  if [ "$DRY_RUN" = "0" ]; then
    python3 - "$PLANGATE_BIN" << 'PY4'
import sys, os

path = sys.argv[1]
with open(path) as f:
    content = f.read()

# PYW 終端（maintenance start の inline python heredoc の後）を探して挿入
# "os.replace(tmp, target)\n" の後の最初の "PYW\n"
insert_after = "os.replace(tmp, target)\n"
pyinline_end = "PYW\n"

idx_replace = content.find(insert_after)
if idx_replace == -1:
    print("ERROR: 'os.replace(tmp, target)' not found", file=sys.stderr)
    sys.exit(1)

idx_pyw = content.find(pyinline_end, idx_replace)
if idx_pyw == -1:
    print("ERROR: PYW terminator not found after os.replace", file=sys.stderr)
    sys.exit(1)

insert_pos = idx_pyw + len(pyinline_end)

hmac_block = '''      # HMAC 署名生成（TASK-0123）
      _maint_file="$_maint"
      if [ -n "${PLANGATE_MAINTENANCE_KEY:-}" ]; then
        _maint_sig=$(python3 -c "
import json, hmac, hashlib, sys
with open(sys.argv[1]) as f:
    d = json.load(f)
canonical = json.dumps(d, sort_keys=True, separators=(',',':'))
h = hmac.new(sys.argv[2].encode(), canonical.encode(), hashlib.sha256)
print(h.hexdigest())
" -- "$_maint_file" "${PLANGATE_MAINTENANCE_KEY}" 2>/dev/null || true)
        if [ -n "$_maint_sig" ]; then
          python3 -c "
import json, os, sys
with open(sys.argv[1]) as f:
    d = json.load(f)
d['hmac_signature'] = sys.argv[2]
tmp = sys.argv[1] + '.tmp'
with open(tmp, 'w') as f:
    json.dump(d, f, ensure_ascii=False, indent=2)
os.replace(tmp, sys.argv[1])
" -- "$_maint_file" "$_maint_sig"
        fi
      fi
'''

new_content = content[:insert_pos] + hmac_block + content[insert_pos:]

import stat
orig_mode = os.stat(path).st_mode
tmp = path + ".tmp"
with open(tmp, "w") as f:
    f.write(new_content)
os.chmod(tmp, stat.S_IMODE(orig_mode))
os.replace(tmp, path)
print("OK: HMAC signature generation added to bin/plangate")
PY4
  fi
fi

###############################################################################
# Patch 5: .github/workflows/check-maintenance-provenance.yml — 新規作成
###############################################################################

CI_WORKFLOW="$REPO_ROOT/.github/workflows/check-maintenance-provenance.yml"

_apply ".github/workflows/check-maintenance-provenance.yml — 新規作成"

if [ -f "$CI_WORKFLOW" ]; then
  _already ".github/workflows/check-maintenance-provenance.yml (already exists)"
else
  if [ "$DRY_RUN" = "0" ]; then
    mkdir -p "$(dirname "$CI_WORKFLOW")"
    cat > "$CI_WORKFLOW" << 'CI_YAML'
name: check-maintenance-provenance
on:
  pull_request:
    paths:
      - 'docs/working/_maintenance/maintenance.json'
jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Verify maintenance.json has HMAC signature
        run: |
          if [ -f docs/working/_maintenance/maintenance.json ]; then
            sig=$(python3 -c "import json; d=json.load(open('docs/working/_maintenance/maintenance.json')); print(d.get('hmac_signature',''))" 2>/dev/null || true)
            if [ -z "$sig" ]; then
              echo "ERROR: maintenance.json lacks hmac_signature — AI-generated token suspected"
              exit 1
            fi
            echo "OK: hmac_signature present"
          fi
CI_YAML
    _log "OK: check-maintenance-provenance.yml created"
  fi
fi

###############################################################################
# 完了報告
###############################################################################

if [ "$DRY_RUN" = "1" ]; then
  _logdry "=== Dry-run complete. No files were modified. ==="
  _logdry "Run without --dry-run to apply changes."
else
  _log "=== All patches applied successfully. ==="
  _log ""
  _log "Next steps (Human):"
  _log "  1. Set PLANGATE_MAINTENANCE_KEY in your shell environment"
  _log "     e.g.: export PLANGATE_MAINTENANCE_KEY=\$(openssl rand -hex 32)"
  _log "  2. Wire check-approval-token-write.sh in .claude/settings.json"
  _log "     (PreToolUse hook for Write/Edit/Bash tool calls)"
  _log "  3. Register GitHub Secret PLANGATE_MAINTENANCE_KEY_CI"
  _log "  4. Run: sh tests/run-tests.sh"
  _log "  5. Run: bin/plangate doctor"
fi
