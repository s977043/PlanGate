# tests/extras/ta-04-check-pr-issue-link.sh
# Sourced by tests/run-tests.sh — relies on $pass / $fail / $PLANGATE_BIN / $FIXTURES_DIR
# Issue #170 で run-tests.sh から分離

printf '\n=== TA-04: check-pr-issue-link.sh ===\n'

PR_LINK_SCRIPT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)/scripts/check-pr-issue-link.sh"
PR_LINK_FIXTURES="$FIXTURES_DIR/check-pr-issue-link"

run_pr_link_fixture() {
  fixture_dir=$1
  expected=$2
  label=$3
  out=$(sh "$PR_LINK_SCRIPT" \
    --body-file "$fixture_dir/body.txt" \
    --labels-file "$fixture_dir/labels.txt" \
    --changed-files "$fixture_dir/changed-files.txt" 2>&1) || {
    printf '[FAIL] %s — script exited non-zero: %s\n' "$label" "$out"
    fail=$((fail + 1))
    return
  }
  case "$out" in
    "$expected"*)
      printf '[PASS] %s — got %s\n' "$label" "$expected"
      pass=$((pass + 1))
      ;;
    *)
      printf '[FAIL] %s — expected prefix %s, got: %s\n' "$label" "$expected" "$out"
      fail=$((fail + 1))
      ;;
  esac
}

run_pr_link_fixture "$PR_LINK_FIXTURES/pass" "PASS" "pass: closes #N present"
run_pr_link_fixture "$PR_LINK_FIXTURES/warn" "WARN" "warn: no closing keyword"
run_pr_link_fixture "$PR_LINK_FIXTURES/skip-label" "SKIP" "skip-label: documentation label"
run_pr_link_fixture "$PR_LINK_FIXTURES/skip-marker" "SKIP" "skip-marker: HTML comment marker"
