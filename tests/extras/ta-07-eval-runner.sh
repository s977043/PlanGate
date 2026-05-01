# tests/extras/ta-07-eval-runner.sh
# Sourced by tests/run-tests.sh
# Issue #170 で run-tests.sh から分離

printf '\n=== TA-07: eval-runner (Issue #156) ===\n'

if python3 -c 'import jsonschema' >/dev/null 2>&1; then
  EVAL_FIXTURE="$FIXTURES_DIR/eval-runner/sample-task"
  EVAL_TASK_NAME="TASK-9990"
  EVAL_TASK_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)/docs/working/$EVAL_TASK_NAME"

  cleanup_eval() { rm -rf "$EVAL_TASK_DIR"; }
  trap cleanup_eval EXIT INT TERM

  cleanup_eval
  mkdir -p "$EVAL_TASK_DIR/approvals"
  cp "$EVAL_FIXTURE/handoff.md" "$EVAL_TASK_DIR/handoff.md"
  cp "$EVAL_FIXTURE/approvals/c3.json" "$EVAL_TASK_DIR/approvals/c3.json"

  if sh "$PLANGATE_BIN" eval "$EVAL_TASK_NAME" --no-write >/dev/null 2>&1; then
    printf '[PASS] eval: sample task → exit 0 (no blockers)\n'
    pass=$((pass + 1))
  else
    printf '[FAIL] eval: sample task — expected exit 0\n'
    fail=$((fail + 1))
  fi

  out=$(sh "$PLANGATE_BIN" eval "$EVAL_TASK_NAME" --no-write 2>&1 || true)
  case "$out" in
    *"AC coverage"*)
      printf '[PASS] eval: stdout contains AC coverage line\n'
      pass=$((pass + 1))
      ;;
    *)
      printf '[FAIL] eval: stdout missing AC coverage line\n'
      fail=$((fail + 1))
      ;;
  esac

  if sh "$PLANGATE_BIN" eval 2>&1 | grep -q 'Usage'; then
    printf '[PASS] eval: no args emits Usage text\n'
    pass=$((pass + 1))
  else
    printf '[FAIL] eval: usage text missing\n'
    fail=$((fail + 1))
  fi

  cleanup_eval
  trap - EXIT INT TERM
else
  printf '[SKIP] eval-runner suite — jsonschema not installed\n'
fi
