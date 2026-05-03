# tests/extras/ta-09-metrics.sh
# Sourced by tests/run-tests.sh
# Issue #195 / PBI-HI-001 (Metrics v1)

printf '\n=== TA-09: metrics (Issue #195) ===\n'

METRICS_TASK_NAME="TASK-9991"
METRICS_TASK_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)/docs/working/$METRICS_TASK_NAME"
METRICS_LOG="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)/.tmp-metrics-events.ndjson"

cleanup_metrics() {
  rm -rf "$METRICS_TASK_DIR"
  rm -f "$METRICS_LOG"
}
trap cleanup_metrics EXIT INT TERM

cleanup_metrics
mkdir -p "$METRICS_TASK_DIR/approvals" "$METRICS_TASK_DIR/evidence"

# Minimal fixture
cat > "$METRICS_TASK_DIR/pbi-input.md" <<'PBI'
# pbi-input
PBI

cat > "$METRICS_TASK_DIR/plan.md" <<'PLAN'
# plan
**モード**: light
PLAN

cat > "$METRICS_TASK_DIR/handoff.md" <<'HANDOFF'
# Handoff: TASK-9991

## 1. 要件適合確認結果
| AC | 結果 |
|----|------|
| AC-01 | ✅ PASS |
| AC-02 | ✅ PASS |
| AC-03 | ✅ PASS |
HANDOFF

cat > "$METRICS_TASK_DIR/approvals/c3.json" <<'C3'
{"task_id":"TASK-9991","decision":"APPROVED"}
C3

# Test 1: collect (default mode, append)
if sh "$PLANGATE_BIN" metrics "$METRICS_TASK_NAME" --collect --events-log "$METRICS_LOG" >/dev/null 2>&1 && [ -s "$METRICS_LOG" ]; then
  printf '[PASS] metrics: collect appended events to events.ndjson\n'
  pass=$((pass + 1))
else
  printf '[FAIL] metrics: collect failed or events.ndjson empty\n'
  fail=$((fail + 1))
fi

# Test 2: each line is valid JSON
if [ -s "$METRICS_LOG" ] && python3 -c "import json,sys; [json.loads(l) for l in open('$METRICS_LOG') if l.strip()]" 2>/dev/null; then
  printf '[PASS] metrics: events.ndjson lines are valid JSON\n'
  pass=$((pass + 1))
else
  printf '[FAIL] metrics: events.ndjson contains invalid JSON\n'
  fail=$((fail + 1))
fi

# Test 3: schema validation (if jsonschema available)
if python3 -c 'import jsonschema' >/dev/null 2>&1 && [ -s "$METRICS_LOG" ]; then
  schema_path="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)/schemas/plangate-event.schema.json"
  if python3 -c "
import json, jsonschema, sys
schema = json.load(open('$schema_path'))
events = [json.loads(l) for l in open('$METRICS_LOG') if l.strip()]
for ev in events:
    jsonschema.validate(ev, schema)
sys.exit(0)
" 2>/dev/null; then
    printf '[PASS] metrics: events conform to plangate-event.schema.json\n'
    pass=$((pass + 1))
  else
    printf '[FAIL] metrics: schema validation failed\n'
    fail=$((fail + 1))
  fi
else
  printf '[SKIP] metrics: jsonschema not available, schema validation skipped\n'
fi

# Test 4: c3_decided event with verdict APPROVED
if grep -q '"event": "c3_decided"' "$METRICS_LOG" 2>/dev/null && grep -q '"verdict": "APPROVED"' "$METRICS_LOG" 2>/dev/null; then
  printf '[PASS] metrics: c3_decided event with APPROVED verdict emitted\n'
  pass=$((pass + 1))
else
  printf '[FAIL] metrics: c3_decided / verdict APPROVED missing\n'
  fail=$((fail + 1))
fi

# Test 5: v1_completed with PASS verdict (3 ✅ PASS markers in handoff)
if grep -q '"event": "v1_completed"' "$METRICS_LOG" 2>/dev/null; then
  if grep -E '"verdict": "PASS"' "$METRICS_LOG" >/dev/null; then
    printf '[PASS] metrics: v1_completed with PASS verdict (AC counts derived)\n'
    pass=$((pass + 1))
  else
    printf '[FAIL] metrics: v1_completed has unexpected verdict\n'
    fail=$((fail + 1))
  fi
else
  printf '[FAIL] metrics: v1_completed event missing\n'
  fail=$((fail + 1))
fi

# Test 6: report --json works
if sh "$PLANGATE_BIN" metrics "$METRICS_TASK_NAME" --report --json --events-log "$METRICS_LOG" 2>/dev/null | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["summary"]["c3"]["APPROVED"] >= 1' 2>/dev/null; then
  printf '[PASS] metrics: report --json shows c3 APPROVED count\n'
  pass=$((pass + 1))
else
  printf '[FAIL] metrics: report --json output incorrect\n'
  fail=$((fail + 1))
fi

# Test 7: aggregate report
if sh "$PLANGATE_BIN" metrics --report --aggregate --events-log "$METRICS_LOG" 2>&1 | grep -q 'aggregate'; then
  printf '[PASS] metrics: --aggregate report works\n'
  pass=$((pass + 1))
else
  printf '[FAIL] metrics: --aggregate report failed\n'
  fail=$((fail + 1))
fi

# Test 8: usage on no args
if sh "$PLANGATE_BIN" metrics 2>&1 | grep -q 'Usage'; then
  printf '[PASS] metrics: usage shown on no args\n'
  pass=$((pass + 1))
else
  printf '[FAIL] metrics: usage not shown on no args\n'
  fail=$((fail + 1))
fi
