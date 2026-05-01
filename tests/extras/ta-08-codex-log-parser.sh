# tests/extras/ta-08-codex-log-parser.sh
# Sourced by tests/run-tests.sh
# Issue #168 / TASK-0054: codex session log parser + eval-runner 統合の検証

printf '\n=== TA-08: codex log parser (Issue #168) ===\n'

CODEX_FIXTURE="$FIXTURES_DIR/codex-log/sample.jsonl"
PARSER_SCRIPT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)/scripts/parsers/codex_log_parser.py"

if [ ! -f "$CODEX_FIXTURE" ] || [ ! -f "$PARSER_SCRIPT" ]; then
  printf '[SKIP] codex log parser tests — fixture or parser missing\n'
else
  # 1. parser 単体: latency_seconds が抽出できる
  out=$(python3 "$PARSER_SCRIPT" "$CODEX_FIXTURE" 2>&1) && rc=0 || rc=$?
  if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q '"latency_seconds": *[0-9]'; then
    printf '[PASS] codex_log_parser: latency_seconds extracted\n'
    pass=$((pass + 1))
  else
    printf '[FAIL] codex_log_parser: latency_seconds missing (rc=%d)\n' "$rc"
    fail=$((fail + 1))
  fi

  # 2. completion_tokens
  if printf '%s' "$out" | grep -q '"completion_tokens": *[0-9]'; then
    printf '[PASS] codex_log_parser: completion_tokens extracted\n'
    pass=$((pass + 1))
  else
    printf '[FAIL] codex_log_parser: completion_tokens missing\n'
    fail=$((fail + 1))
  fi

  # 3. eval-runner 統合: --session-log で metrics が埋まる
  if python3 -c 'import jsonschema' >/dev/null 2>&1; then
    EVAL_FIXTURE="$FIXTURES_DIR/eval-runner/sample-task"
    LOG_TASK_NAME="TASK-9991"
    LOG_TASK_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)/docs/working/$LOG_TASK_NAME"

    rm -rf "$LOG_TASK_DIR"
    mkdir -p "$LOG_TASK_DIR/approvals"
    cp "$EVAL_FIXTURE/handoff.md" "$LOG_TASK_DIR/handoff.md"
    cp "$EVAL_FIXTURE/approvals/c3.json" "$LOG_TASK_DIR/approvals/c3.json"

    eval_out=$(sh "$PLANGATE_BIN" eval "$LOG_TASK_NAME" --no-write --session-log "$CODEX_FIXTURE" 2>&1) && erc=0 || erc=$?
    if [ "$erc" -eq 0 ] && printf '%s' "$eval_out" | grep -q 'Latency / Cost: \*\*PASS\*\*.*latency='; then
      printf '[PASS] eval-runner: --session-log produces PASS + latency value\n'
      pass=$((pass + 1))
    else
      printf '[FAIL] eval-runner: latency line missing (rc=%d)\n' "$erc"
      fail=$((fail + 1))
    fi

    rm -rf "$LOG_TASK_DIR"
  else
    printf '[SKIP] eval-runner integration — jsonschema not installed\n'
  fi
fi
