#!/bin/sh
# TASK-1608 HD-1 / D-017: add the hash-pinned reference parser steps to .github/workflows/test.yml.
# Human-owned (HO path). AI does not run this script except `--dry-run`.
# Usage: sh apply-test-yml.sh [apply|--dry-run|--verify|--rollback]
# Flow (D-017): run on a feature branch cut from origin/main, review the diff, commit, open a PR, merge it
# before PR #1611. The steps are guarded by hashFiles(), so they are skipped until #1611 adds the requirements.
set -eu
REPO=$(git rev-parse --show-toplevel) || { printf 'ABORT: not in a git repository\n' >&2; exit 1; }
PATCH="docs/working/TASK-1608/ho/test-yml.patch"
TARGET=".github/workflows/test.yml"
REQ="tests/requirements-seed-delta-reference.txt"
MODE="${1:-apply}"
die() { printf 'ABORT: %s\n' "$*" >&2; exit 1; }
ok()  { printf '  ok  %s\n' "$1"; }

script_top=$(cd "$(dirname "$0")" && git rev-parse --show-toplevel) || die "cannot resolve the script's repository"
[ "$script_top" = "$REPO" ] || die "cwd repository ($REPO) differs from the script's repository ($script_top)"
printf 'target repository: %s\n' "$REPO"
cd "$REPO"

[ -f "$PATCH" ] || die "patch not found: $PATCH"
head -1 "$PATCH" | grep -q '^diff --git ' || die "patch is not a unified diff"

require_feature_branch() {
  br=$(git rev-parse --abbrev-ref HEAD)
  case "$br" in
    HEAD) die "detached HEAD; create a feature branch from origin/main" ;;
    main|master|release/*) die "protected branch '$br'; create a feature branch from origin/main" ;;
  esac
  printf 'branch: %s\n' "$br"
  [ -z "$(git status --porcelain -- "$TARGET")" ] || die "uncommitted changes in $TARGET"
}

verify() {
  python3 - "$TARGET" "$REQ" <<'PY' || die "verify failed"
import os, re, sys
try:
    import yaml
except ImportError:
    sys.exit("PyYAML is required for --verify (pip install pyyaml)")
target, req = sys.argv[1], sys.argv[2]
with open(target, encoding="utf-8") as f:
    doc = yaml.safe_load(f)
guard = "hashFiles('tests/requirements-seed-delta-reference.txt') != ''"
steps = doc["jobs"]["plangate-cli"]["steps"]
by_name = {s.get("name"): s for s in steps}
inst = by_name.get("Install seed-delta reference parser (hash-pinned)")
run = by_name.get("Run seed-delta differential test")
cli = by_name.get("Run CLI tests")
errs = []
if inst is None or run is None or cli is None:
    errs.append("expected steps missing")
else:
    for s in (inst, run):
        if s.get("if") != guard:
            errs.append(f"{s['name']}: if != {guard}")
    for tok in ("--require-hashes", "--no-deps", "-r tests/requirements-seed-delta-reference.txt"):
        if tok not in inst.get("run", ""):
            errs.append(f"install step: '{tok}' missing")
    env = run.get("env") or {}
    if env.get("SEED_DELTA_REFERENCE") != "1":
        errs.append("differential step: env SEED_DELTA_REFERENCE != '1'")
    if env.get("SEED_DELTA_MINIMIZE") != "0":
        errs.append("differential step: env SEED_DELTA_MINIMIZE != '0'")
    if not isinstance(run.get("timeout-minutes"), int):
        errs.append("differential step: timeout-minutes missing")
    if "scripts/test_improvement_seed_delta_reference.py" not in run.get("run", ""):
        errs.append("differential step: harness not invoked")
    if cli.get("env"):
        errs.append("Run CLI tests: env must stay unset")
if os.path.exists(req):
    pins = {"markdown-it-py": "4.2.0", "mdurl": "0.1.2"}
    text = open(req, encoding="utf-8").read()
    reqs = [r for r in re.split(r"(?<!\\)\n", text) if r.strip() and not r.lstrip().startswith("#")]
    seen = {}
    for r in reqs:
        m = re.match(r"\s*([A-Za-z0-9_.-]+)==([^\s\\]+)", r)
        if not m:
            errs.append(f"requirement without exact pin: {r.strip()[:60]}")
            continue
        seen[m.group(1).lower()] = (m.group(2), re.findall(r"--hash=sha256:[0-9a-f]{64}", r))
    for name, ver in pins.items():
        if name not in seen:
            errs.append(f"{name} missing from {req}")
        elif seen[name][0] != ver:
            errs.append(f"{name}=={seen[name][0]} (expected {ver})")
    for name, (_, hashes) in seen.items():
        if not hashes:
            errs.append(f"{name}: no sha256 hash")
    if set(seen) - set(pins):
        errs.append(f"unexpected dependencies: {sorted(set(seen) - set(pins))}")
else:
    print(f"  note  {req} absent: steps stay skipped by hashFiles (E-1 unmet)")
if errs:
    print("\n".join("  FAIL " + e for e in errs))
    sys.exit(1)
PY
  ok "verify"
}

case "$MODE" in
  --dry-run)
    if git apply --check "$PATCH" 2>/dev/null; then ok "forward apply possible"
    elif git apply --check -R "$PATCH" 2>/dev/null; then ok "already applied"
    else die "neither forward nor reverse applies (stale patch)"; fi
    ;;
  apply)
    require_feature_branch
    if git apply --check "$PATCH" 2>/dev/null; then
      git apply "$PATCH" || die "apply failed"
    elif git apply --check -R "$PATCH" 2>/dev/null; then
      printf 'already applied; verifying only\n'
    else
      die "neither forward nor reverse applies (stale patch)"
    fi
    verify
    printf 'applied. review `git diff -- %s`, then commit, open a PR, and merge it before #1611.\n' "$TARGET"
    ;;
  --verify) verify ;;
  --rollback)
    require_feature_branch
    git apply --check -R "$PATCH" 2>/dev/null || die "cannot reverse-apply"
    git apply -R "$PATCH" || die "reverse-apply failed"
    ok "rolled back (commit on this branch and open a PR)"
    ;;
  *) die "unknown mode: $MODE" ;;
esac
