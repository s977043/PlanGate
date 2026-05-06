# tests/extras/ta-09-metrics.sh
# Sourced by tests/run-tests.sh
# Issue #195 / PBI-HI-001 (Metrics v1)

printf '\n=== TA-09: metrics (Issue #195) ===\n'

METRICS_TASK_NAME="TASK-9991"
METRICS_REPO_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
METRICS_TASK_DIR="$METRICS_REPO_ROOT/docs/working/$METRICS_TASK_NAME"
METRICS_LOG="$METRICS_REPO_ROOT/.tmp-metrics-events.ndjson"
METRICS_AUDIT_LOG="$METRICS_REPO_ROOT/docs/working/_audit/hook-events.log"
METRICS_AUDIT_BACKUP=""

cleanup_metrics() {
  rm -rf "$METRICS_TASK_DIR"
  rm -f "$METRICS_LOG"
  if [ -n "$METRICS_AUDIT_BACKUP" ] && [ -f "$METRICS_AUDIT_BACKUP" ]; then
    mv "$METRICS_AUDIT_BACKUP" "$METRICS_AUDIT_LOG"
  fi
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

# Test 9 (privacy C-2): emitted events MUST NOT contain forbidden fields (privacy §4)
if [ -s "$METRICS_LOG" ]; then
  forbidden_re='"file_path"|"file_paths"|"stack_trace"|"command_output"|"stdout"|"stderr"|"raw_response"|"raw_request"|"api_key"|"user_prompt"|"system_prompt"|"prompt_text"|"absolute_path"'
  if ! grep -E "$forbidden_re" "$METRICS_LOG" >/dev/null 2>&1; then
    printf '[PASS] metrics (C-2): emitted events contain no forbidden fields (privacy §4)\n'
    pass=$((pass + 1))
  else
    hit=$(grep -oE "$forbidden_re" "$METRICS_LOG" | sort -u | tr '\n' ',' | sed 's/,$//')
    printf '[FAIL] metrics (C-2): forbidden field detected in events.ndjson — %s\n' "$hit"
    fail=$((fail + 1))
  fi
fi

# Test 10 (privacy D-1 negative): schema MUST reject events with forbidden fields
if python3 -c 'import jsonschema' >/dev/null 2>&1; then
  schema_path="$METRICS_REPO_ROOT/schemas/plangate-event.schema.json"
  if python3 -c "
import json, jsonschema, sys
schema = json.load(open('$schema_path'))
bad = {
    'schema_version': '1.0',
    'ts': '2026-05-06T08:00:00Z',
    'task_id': 'TASK-9999',
    'event': 'v1_completed',
    'verdict': 'PASS',
    'file_path': '/secret/path/handoff.md',
}
try:
    jsonschema.validate(bad, schema)
    sys.exit(0)  # unexpectedly accepted
except jsonschema.ValidationError:
    sys.exit(1)  # expected rejection
" 2>/dev/null; then
    printf '[FAIL] metrics (D-1): schema accepted forbidden field (file_path) — privacy §4 not enforced\n'
    fail=$((fail + 1))
  else
    printf '[PASS] metrics (D-1): schema rejects forbidden field (additionalProperties:false)\n'
    pass=$((pass + 1))
  fi
else
  printf '[SKIP] metrics (D-1): jsonschema not available\n'
fi

# Test 11 (A-1): hook_violation auto-derive from audit log
# fixture: 一時 hook-events.log を作る（既存ログがあれば backup）
if [ -f "$METRICS_AUDIT_LOG" ]; then
  METRICS_AUDIT_BACKUP="$METRICS_AUDIT_LOG.bak.$$"
  mv "$METRICS_AUDIT_LOG" "$METRICS_AUDIT_BACKUP"
fi
mkdir -p "$(dirname "$METRICS_AUDIT_LOG")"
cat > "$METRICS_AUDIT_LOG" <<HOOKLOG
2026-05-06T07:00:00Z	VIOLATION	check-c3-approval	$METRICS_TASK_NAME	C-3 gate not cleared
2026-05-06T07:01:00Z	WARNING	check-plan-exists	$METRICS_TASK_NAME	plan.md not found
2026-05-06T07:02:00Z	PASS	check-merge-approvals	$METRICS_TASK_NAME	c3=APPROVED c4=APPROVED
2026-05-06T07:03:00Z	BYPASS	check-c3-approval	$METRICS_TASK_NAME	bypass set
2026-05-06T07:04:00Z	VIOLATION	check-test-cases	OTHER-TASK	(unrelated)
HOOKLOG

# 既存 events.ndjson をクリアしてから再 collect
rm -f "$METRICS_LOG"
sh "$PLANGATE_BIN" metrics "$METRICS_TASK_NAME" --collect --events-log "$METRICS_LOG" >/dev/null 2>&1

violations=$(grep -c '"event": "hook_violation"' "$METRICS_LOG" 2>/dev/null || echo 0)
# expect: 2 hook_violations (VIOLATION + WARNING for our task), exclude PASS / BYPASS / OTHER-TASK
if [ "$violations" = "2" ]; then
  printf '[PASS] metrics (A-1): hook_violation auto-derived 2 events from audit log (filters PASS/BYPASS/other-task)\n'
  pass=$((pass + 1))
else
  printf '[FAIL] metrics (A-1): expected 2 hook_violations, got %s\n' "$violations"
  fail=$((fail + 1))
fi

# Test 12 (A-1): hook_id mapping (check-c3-approval → EH-2)
if grep -q '"hook_id": "EH-2"' "$METRICS_LOG" 2>/dev/null; then
  printf '[PASS] metrics (A-1): hook_name to hook_id mapping (check-c3-approval → EH-2)\n'
  pass=$((pass + 1))
else
  printf '[FAIL] metrics (A-1): hook_id mapping incorrect\n'
  fail=$((fail + 1))
fi

# Test 13 (A-1): hook_result level mapping (VIOLATION → block, WARNING → warn)
if grep -q '"hook_result": "block"' "$METRICS_LOG" 2>/dev/null && grep -q '"hook_result": "warn"' "$METRICS_LOG" 2>/dev/null; then
  printf '[PASS] metrics (A-1): hook_result mapping (VIOLATION→block, WARNING→warn)\n'
  pass=$((pass + 1))
else
  printf '[FAIL] metrics (A-1): hook_result mapping missing\n'
  fail=$((fail + 1))
fi

# Test 14 (A-1): cumulative collect で events.ndjson が valid に保たれる
if python3 -c "import json; [json.loads(l) for l in open('$METRICS_LOG') if l.strip()]" 2>/dev/null; then
  printf '[PASS] metrics (A-1): events.ndjson remains valid JSON after hook events appended\n'
  pass=$((pass + 1))
else
  printf '[FAIL] metrics (A-1): events.ndjson invalid after hook append\n'
  fail=$((fail + 1))
fi

# Test 15 (A-1): hook_violation events も schema 妥当
if python3 -c 'import jsonschema' >/dev/null 2>&1; then
  if python3 -c "
import json, jsonschema, sys
schema = json.load(open('$METRICS_REPO_ROOT/schemas/plangate-event.schema.json'))
events = [json.loads(l) for l in open('$METRICS_LOG') if l.strip()]
hv = [e for e in events if e.get('event') == 'hook_violation']
for e in hv:
    jsonschema.validate(e, schema)
sys.exit(0 if hv else 1)
" 2>/dev/null; then
    printf '[PASS] metrics (A-1): hook_violation events conform to schema\n'
    pass=$((pass + 1))
  else
    printf '[FAIL] metrics (A-1): hook_violation schema validation failed\n'
    fail=$((fail + 1))
  fi
else
  printf '[SKIP] metrics (A-1): jsonschema not available for hook_violation validation\n'
fi

# Test 16 (D-2): existing baseline file conforms to eval-baseline.schema.json
if python3 -c 'import jsonschema' >/dev/null 2>&1; then
  baseline_schema="$METRICS_REPO_ROOT/schemas/eval-baseline.schema.json"
  baseline_file="$METRICS_REPO_ROOT/docs/ai/eval-baselines/2026-05-04-baseline.json"
  if [ -f "$baseline_schema" ] && [ -f "$baseline_file" ]; then
    if python3 -c "
import json, jsonschema, sys
schema = json.load(open('$baseline_schema'))
data = json.load(open('$baseline_file'))
jsonschema.validate(data, schema)
" 2>/dev/null; then
      printf '[PASS] metrics (D-2): 2026-05-04-baseline.json conforms to eval-baseline.schema.json\n'
      pass=$((pass + 1))
    else
      printf '[FAIL] metrics (D-2): baseline schema validation failed\n'
      fail=$((fail + 1))
    fi
  else
    printf '[SKIP] metrics (D-2): baseline schema or file not present\n'
  fi
fi

# Test 17 (D-2): baseline schema rejects forbidden fields (privacy §4 also applies to baselines)
if python3 -c 'import jsonschema' >/dev/null 2>&1; then
  baseline_schema="$METRICS_REPO_ROOT/schemas/eval-baseline.schema.json"
  if [ -f "$baseline_schema" ] && python3 -c "
import json, jsonschema, sys
schema = json.load(open('$baseline_schema'))
bad = {
    'baseline_id': '2026-05-06',
    'evaluated_at': '2026-05-06T08:00:00Z',
    'release': 'v8.6.0',
    'evaluator_version': '1.2.0',
    'tasks': [{'task_id': 'TASK-0001', 'ac_coverage_pct': 100, 'file_path': '/secret'}],
    'aggregate': {'task_count': 1},
}
try:
    jsonschema.validate(bad, schema)
    sys.exit(0)
except jsonschema.ValidationError:
    sys.exit(1)
" 2>/dev/null; then
    printf '[FAIL] metrics (D-2): baseline schema accepted forbidden field — additionalProperties:false missing\n'
    fail=$((fail + 1))
  else
    printf '[PASS] metrics (D-2): baseline schema rejects forbidden field at task level\n'
    pass=$((pass + 1))
  fi
fi

# Test (H-1, v8.6.0 PR5): bin/plangate metrics --validate
if python3 -c 'import jsonschema' >/dev/null 2>&1 && [ -s "$METRICS_LOG" ]; then
  if sh "$PLANGATE_BIN" metrics --validate --events-log "$METRICS_LOG" 2>&1 | grep -q "all events valid"; then
    printf '[PASS] metrics (H-1): --validate command checks events against schema\n'
    pass=$((pass + 1))
  else
    printf '[FAIL] metrics (H-1): --validate did not pass on valid events\n'
    fail=$((fail + 1))
  fi

  # negative: append a bad event and expect --validate to exit 1
  bad_log="$METRICS_LOG.bad"
  cp "$METRICS_LOG" "$bad_log"
  echo '{"schema_version":"1.0","ts":"2026-05-06T08:00:00Z","task_id":"TASK-9999","event":"v1_completed","verdict":"PASS","file_path":"/secret"}' >> "$bad_log"
  sh "$PLANGATE_BIN" metrics --validate --events-log "$bad_log" >/dev/null 2>&1 && rc=0 || rc=$?
  if [ "$rc" -eq 1 ]; then
    printf '[PASS] metrics (H-1): --validate exits 1 on schema violation (forbidden field)\n'
    pass=$((pass + 1))
  else
    printf '[FAIL] metrics (H-1): --validate did not detect violation (rc=%d)\n' "$rc"
    fail=$((fail + 1))
  fi
  rm -f "$bad_log"
fi

# Test (J-1, v8.6.0 PR5): validate-schemas integrates eval-baseline.schema.json
if python3 -c 'import jsonschema' >/dev/null 2>&1; then
  if grep -q "eval-baseline.schema.json" "$METRICS_REPO_ROOT/scripts/schema_mapping.py" 2>/dev/null; then
    printf '[PASS] metrics (J-1): schema_mapping.py includes eval-baseline.schema.json\n'
    pass=$((pass + 1))
  else
    printf '[FAIL] metrics (J-1): schema_mapping.py missing eval-baseline.schema.json\n'
    fail=$((fail + 1))
  fi
fi

# Test (F-3, v8.6.0 PR5): plangate doctor reports v8.6.0 metrics & privacy
if sh "$PLANGATE_BIN" doctor 2>&1 | grep -q "v8.6.0 Metrics & Privacy"; then
  printf '[PASS] metrics (F-3): plangate doctor includes v8.6.0 metrics health check\n'
  pass=$((pass + 1))
else
  printf '[FAIL] metrics (F-3): plangate doctor missing v8.6.0 section\n'
  fail=$((fail + 1))
fi

# Test (H-3, v8.6.0 PR6): aggregate report shows per-mode breakdown
out=$(sh "$PLANGATE_BIN" metrics --report --aggregate --events-log "$METRICS_LOG" 2>&1)
if printf '%s' "$out" | grep -q "By mode (H-3)"; then
  printf '[PASS] metrics (H-3): aggregate report includes by-mode section\n'
  pass=$((pass + 1))
else
  printf '[FAIL] metrics (H-3): by-mode section missing\n'
  fail=$((fail + 1))
fi

# Test (H-3): JSON output contains by_mode key
if sh "$PLANGATE_BIN" metrics --report --aggregate --json --events-log "$METRICS_LOG" 2>/dev/null \
  | python3 -c 'import json,sys; d=json.load(sys.stdin); assert "by_mode" in d["summary"]' 2>/dev/null; then
  printf '[PASS] metrics (H-3): --json output includes by_mode\n'
  pass=$((pass + 1))
else
  printf '[FAIL] metrics (H-3): by_mode not in JSON\n'
  fail=$((fail + 1))
fi

# Test 18 (C-3): baseline-snapshot.py --dry-run produces schema-valid output for real TASKs
if python3 -c 'import jsonschema' >/dev/null 2>&1; then
  snapshot_script="$METRICS_REPO_ROOT/scripts/baseline-snapshot.py"
  baseline_schema="$METRICS_REPO_ROOT/schemas/eval-baseline.schema.json"
  if [ -f "$snapshot_script" ] && python3 "$snapshot_script" \
       --baseline-id 2026-05-06-test \
       --release v8.6.0 \
       --tasks TASK-0059 \
       --dry-run 2>/dev/null \
     | python3 -c "
import json, jsonschema, sys
schema = json.load(open('$baseline_schema'))
data = json.load(sys.stdin)
jsonschema.validate(data, schema)
" 2>/dev/null; then
    printf '[PASS] metrics (C-3): baseline-snapshot.py --dry-run output is schema-valid\n'
    pass=$((pass + 1))
  else
    printf '[FAIL] metrics (C-3): baseline-snapshot.py --dry-run failed schema validation\n'
    fail=$((fail + 1))
  fi
fi
