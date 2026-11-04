#!/bin/sh
# TASK-1608 HD-1 / D-017 / D-018: add the seed-delta-reference job to .github/workflows/test.yml.
# Human-owned (HO path). AI does not run this script except `--dry-run`.
# Usage: sh apply-test-yml.sh [apply|--dry-run|--verify|--rollback]
# Flow (D-017): `git fetch origin`, cut a feature branch from origin/main, bring in this ho/ directory
# (`git checkout origin/plan/1608-seed-parser -- docs/working/TASK-1608/ho`), run apply, review the diff, commit,
# open a PR, merge it before PR #1611. The steps are guarded by hashFiles(), so they are skipped until #1611
# adds the requirements.
# Scope of the safety checks (D-018 / R-023):
#   apply / --rollback : branch check + base check (origin/main is an ancestor, nothing but the target differs
#                        from origin/main) + dirty check + YAML verify.
#   --dry-run          : only `git apply --check` against the working tree. No branch / base / dirty check.
#   --verify           : only the YAML / requirements structure. No branch / base / dirty check.
#   A passing --dry-run or --verify is NOT evidence that apply is safe on the current branch.
set -eu
REPO=$(git rev-parse --show-toplevel) || { printf 'ABORT: not in a git repository\n' >&2; exit 1; }
PATCH="docs/working/TASK-1608/ho/test-yml.patch"
TARGET=".github/workflows/test.yml"
REQ="tests/requirements-seed-delta-reference.txt"
HARNESS="scripts/test_improvement_seed_delta_reference.py"
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
  git rev-parse --verify -q origin/main >/dev/null || die "origin/main not found; run git fetch origin"
  git merge-base --is-ancestor origin/main HEAD || die "origin/main is not an ancestor of HEAD; branch from origin/main"
  # The ho/ files themselves may be brought in from the #1611 branch; nothing else may differ.
  extra=$(git diff --name-only origin/main | grep -vxF "$TARGET" | grep -v '^docs/working/TASK-1608/ho/' || true)
  [ -z "$extra" ] || die "files other than $TARGET differ from origin/main: $(printf '%s' "$extra" | tr '\n' ' ')"
  [ -z "$(git ls-files --others --exclude-standard -- .github)" ] || die "untracked files under .github"
  ok "base: origin/main is an ancestor and only $TARGET may differ"
}

verify() {
  python3 - "$TARGET" "$REQ" "$HARNESS" <<'PY' || die "verify failed"
import os, re, sys
try:
    import yaml
except ImportError:
    sys.exit("PyYAML is required for --verify (pip install pyyaml)")
target, req, harness = sys.argv[1], sys.argv[2], sys.argv[3]
with open(target, encoding="utf-8") as f:
    doc = yaml.safe_load(f)
guard = "hashFiles('tests/requirements-seed-delta-reference.txt') != ''"
errs = []
jobs = doc.get("jobs") or {}
cli_job = jobs.get("plangate-cli") or {}
ref_job = jobs.get("seed-delta-reference")
if set(jobs) != {"plangate-cli", "seed-delta-reference"}:
    errs.append(f"jobs != {{plangate-cli, seed-delta-reference}}: {sorted(jobs)}")
if cli_job.get("timeout-minutes") != 10:
    errs.append("plangate-cli: timeout-minutes changed (expected 10)")
if [s.get("name") for s in cli_job.get("steps", [])] != ["Checkout", "Run CLI tests"]:
    errs.append("plangate-cli: steps changed")
for s in cli_job.get("steps", []):
    if s.get("name") == "Run CLI tests" and (s.get("env") or s.get("run") != "sh tests/run-tests.sh"):
        errs.append("Run CLI tests: env/run must stay unchanged")
if ref_job is None:
    errs.append("job seed-delta-reference missing")
else:
    for k in ("needs", "continue-on-error", "if", "strategy"):
        if k in ref_job:
            errs.append(f"seed-delta-reference: '{k}' must be absent")
    job_to = ref_job.get("timeout-minutes")
    if not isinstance(job_to, int):
        errs.append("seed-delta-reference: timeout-minutes missing")
    steps = ref_job.get("steps") or []
    names = [s.get("name") for s in steps]
    want = ["Checkout", "Install seed-delta reference parser (hash-pinned)", "Run seed-delta differential test"]
    if names != want:
        errs.append(f"seed-delta-reference: steps != {want}: {names}")
    else:
        _, inst, run = steps
        want_run = {
            inst["name"]: [
                'python3 -m venv "$RUNNER_TEMP/seed-delta-ref"',
                '"$RUNNER_TEMP/seed-delta-ref/bin/python" -m pip install --require-hashes --no-deps \\',
                "-r tests/requirements-seed-delta-reference.txt",
            ],
            run["name"]: ['"$RUNNER_TEMP/seed-delta-ref/bin/python" scripts/test_improvement_seed_delta_reference.py'],
        }
        step_total = 0
        for s in (inst, run):
            if s.get("if") != guard:
                errs.append(f"{s['name']}: if != {guard}")
            if "continue-on-error" in s:
                errs.append(f"{s['name']}: continue-on-error must be absent")
            lines = [l.strip() for l in (s.get("run") or "").splitlines() if l.strip()]
            if lines != want_run[s["name"]]:
                errs.append(f"{s['name']}: run lines differ from the fixed set: {lines}")
            to = s.get("timeout-minutes")
            if not isinstance(to, int):
                errs.append(f"{s['name']}: timeout-minutes missing")
            else:
                step_total += to
        if isinstance(job_to, int) and step_total and not step_total < job_to:
            errs.append(f"step timeouts ({step_total}) must be < job timeout ({job_to})")
        if (inst.get("env") or None) is not None:
            errs.append("install step: env must be absent")
        env = run.get("env") or {}
        if env != {"SEED_DELTA_REFERENCE": "1", "SEED_DELTA_MINIMIZE": "0"}:
            errs.append(f"differential step: env != SEED_DELTA_REFERENCE=1, SEED_DELTA_MINIMIZE=0: {env}")
if os.path.exists(harness) and not os.path.exists(req):
    errs.append(f"{harness} exists but {req} is absent (steps would be skipped forever)")
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
    printf '  note  dry-run checks patch applicability only (no branch/base/dirty check)\n'
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
