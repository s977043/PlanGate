#!/bin/sh
# TASK-1608 HD-1: apply the hash-pinned reference parser step to .github/workflows/test.yml.
# Human-owned (HO path). AI does not run this script except `--dry-run`.
# Usage: sh apply-test-yml.sh [apply|--dry-run|--verify|--rollback]
# Precondition for apply: tests/requirements-seed-delta-reference.txt exists (added in exec T-23).
set -eu
REPO="${PLANGATE_APPLY_REPO:-$(git rev-parse --show-toplevel)}"
PATCH="docs/working/TASK-1608/ho/test-yml.patch"
TARGET=".github/workflows/test.yml"
REQ="tests/requirements-seed-delta-reference.txt"
MODE="${1:-apply}"
die() { printf 'ABORT: %s\n' "$*" >&2; exit 1; }
ok()  { printf '  ok  %s\n' "$1"; }
cd "$REPO" || die "cannot enter repo: $REPO"

[ -f "$PATCH" ] || die "patch not found: $PATCH"
head -1 "$PATCH" | grep -q '^diff --git ' || die "patch is not a unified diff"

verify() {
  grep -qF -- 'SEED_DELTA_REFERENCE: "1"' "$TARGET" || die "env marker missing in $TARGET"
  grep -qF -- '--require-hashes' "$TARGET" || die "--require-hashes missing in $TARGET"
  python3 -c "import yaml,sys; yaml.safe_load(open(sys.argv[1]))" "$TARGET" 2>/dev/null \
    || printf '  warn  YAML parse skipped or failed (PyYAML not available?)\n'
  [ -f "$REQ" ] || die "requirements missing: $REQ"
  grep -q -- '--hash=sha256:' "$REQ" || die "requirements are not hash-pinned: $REQ"
  ok "verify"
}

case "$MODE" in
  --dry-run)
    if git apply --check "$PATCH" 2>/dev/null; then ok "forward apply possible"
    elif git apply --check -R "$PATCH" 2>/dev/null; then ok "already applied"
    else die "neither forward nor reverse applies (stale patch)"; fi
    ;;
  apply)
    br=$(git rev-parse --abbrev-ref HEAD)
    [ "$br" = "main" ] || die "branch is not main (current: $br)"
    dirty=$(git status --porcelain -- "$TARGET")
    [ -z "$dirty" ] || die "uncommitted changes in $TARGET"
    if git apply --check "$PATCH" 2>/dev/null; then
      git apply "$PATCH" || die "apply failed"
    elif git apply --check -R "$PATCH" 2>/dev/null; then
      printf 'already applied; verifying only\n'
    else
      die "neither forward nor reverse applies (stale patch)"
    fi
    verify
    printf 'applied. review `git diff -- %s`, then commit and open a PR yourself.\n' "$TARGET"
    ;;
  --verify) verify ;;
  --rollback)
    git apply --check -R "$PATCH" 2>/dev/null || die "cannot reverse-apply"
    git apply -R "$PATCH" || die "reverse-apply failed"
    ok "rolled back"
    ;;
  *) die "unknown mode: $MODE" ;;
esac
