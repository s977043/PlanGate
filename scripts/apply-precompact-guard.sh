#!/bin/sh
# apply-precompact-guard.sh -- TASK issue #742
# Installs scripts/precompact-memory-guard.sh into scripts/hooks/ and wires
# it as a PreCompact hook in .claude/settings.json (+ settings.example.json
# for contract parity, per docs/ai/settings-wiring-contract.md).
#
# settings*.json and scripts/hooks/ are Hardening Override (HO) targets
# (self-mod guard). AI must only run this with --dry-run. Actual --apply
# execution is Human-owned (or a session-explicit approved AI execution),
# per .claude/rules/responsibility-classes.md.
#
# Idempotent: if precompact-memory-guard already wired, each step is skipped.
#
# Usage:
#   sh scripts/apply-precompact-guard.sh --dry-run   # diff preview (no writes)
#   sh scripts/apply-precompact-guard.sh --apply     # apply (Human execution only)
# (an argument is required; running without arguments exits 1)
#
# After --apply, verify:
#   git diff scripts/hooks/precompact-memory-guard.sh .claude/settings.json .claude/settings.example.json
#   sh tests/extras/ta-50-precompact-guard.sh
#   bin/plangate doctor

set -eu

export PYTHONUTF8=1

REPO_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"

if [ "$#" -eq 0 ]; then
  printf 'ERROR: an argument is required. Usage: %s --dry-run|--apply\n' "$0" >&2
  exit 1
fi
if [ "$#" -gt 1 ]; then
  printf 'ERROR: exactly one argument allowed. Usage: %s --dry-run|--apply\n' "$0" >&2
  exit 1
fi
case "$1" in
  --dry-run) MODE="dry-run" ;;
  --apply) MODE="apply" ;;
  *) printf 'ERROR: invalid argument: %s. Usage: %s --dry-run|--apply\n' "$1" "$0" >&2; exit 1 ;;
esac

command -v python3 >/dev/null 2>&1 || { printf 'ERROR: python3 required\n' >&2; exit 1; }

SRC="$REPO_ROOT/scripts/precompact-memory-guard.sh"
DST="$REPO_ROOT/scripts/hooks/precompact-memory-guard.sh"

if [ ! -f "$SRC" ]; then
  printf 'ERROR: %s not found\n' "$SRC" >&2
  exit 1
fi

for f in .claude/settings.json .claude/settings.example.json; do
  [ -f "$REPO_ROOT/$f" ] || { printf 'ERROR: %s not found\n' "$f" >&2; exit 1; }
done

if [ "$MODE" = "apply" ]; then
  printf 'WARNING: this script writes to Hardening Override (HO) target files\n' >&2
  printf '         (scripts/hooks/ + .claude/settings*.json). AI must not run\n' >&2
  printf '         this with --apply (docs/ai/ho-change-workflow.md). Confirm\n' >&2
  printf '         this execution is by a Human (or session-explicit approved AI run).\n' >&2
fi

# --- (a) stage hook into scripts/hooks/ ---
if [ -f "$DST" ] && cmp -s "$SRC" "$DST"; then
  printf '  [skip] scripts/hooks/precompact-memory-guard.sh (already up to date)\n'
elif [ "$MODE" = "dry-run" ]; then
  printf '  [dry-run] scripts/hooks/precompact-memory-guard.sh would be (re)installed from %s:\n' "$(basename "$SRC")"
  if [ -f "$DST" ]; then
    diff -u "$DST" "$SRC" | sed 's/^/    /' || true
  else
    printf '    (new file, %s lines)\n' "$(wc -l < "$SRC" | tr -d ' ')"
  fi
else
  mkdir -p "$REPO_ROOT/scripts/hooks"
  cp "$SRC" "$DST"
  chmod +x "$DST"
  printf '  [applied] scripts/hooks/precompact-memory-guard.sh installed\n'
fi

# --- (b) wire PreCompact hook in settings.json (+ example.json) ---
_DRY=0
[ "$MODE" = "dry-run" ] && _DRY=1

python3 - "$REPO_ROOT" "$_DRY" <<'PY'
import json, sys, difflib, os

repo, dry = sys.argv[1], sys.argv[2] == "1"
CMD = "sh ${CLAUDE_PROJECT_DIR}/scripts/hooks/precompact-memory-guard.sh"
ENTRY = {"hooks": [{"type": "command", "command": CMD}]}

changed_any = False
for rel in (".claude/settings.json", ".claude/settings.example.json"):
    path = os.path.join(repo, rel)
    orig = open(path, encoding="utf-8").read()
    d = json.loads(orig)
    pc = d.setdefault("hooks", {}).setdefault("PreCompact", [])
    already = any(
        "precompact-memory-guard.sh" in h.get("command", "")
        for e in pc for h in e.get("hooks", [])
    )
    if already:
        sys.stderr.write("  [skip] %s (PreCompact already wired)\n" % rel)
        continue
    pc.append(ENTRY)
    new = json.dumps(d, ensure_ascii=False, indent=2) + "\n"
    changed_any = True
    if dry:
        diff = difflib.unified_diff(
            orig.splitlines(True), new.splitlines(True),
            fromfile=rel, tofile=rel + " (after)",
        )
        sys.stdout.write("".join(diff))
    else:
        with open(path, "w", encoding="utf-8") as f:
            f.write(new)
        sys.stderr.write("  [applied] %s wired with PreCompact precompact-memory-guard\n" % rel)

if not changed_any and not dry:
    sys.stderr.write("nothing to do (already wired)\n")
PY

printf '\n'
if [ "$MODE" = "dry-run" ]; then
  printf '=== --dry-run complete. No files were written. ===\n'
  printf 'To apply (Human only): sh scripts/apply-precompact-guard.sh --apply\n'
else
  printf '=== apply complete. Verify: ===\n'
  printf '  git diff scripts/hooks/precompact-memory-guard.sh .claude/settings.json .claude/settings.example.json\n'
  printf '  sh tests/extras/ta-50-precompact-guard.sh\n'
  printf '  bin/plangate doctor\n'
fi
