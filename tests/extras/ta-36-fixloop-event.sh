# tests/extras/ta-36-fixloop-event.sh
# Sourced by tests/run-tests.sh
# Issue #522: fix_loop_incremented イベント生成（collector の INCREMENT 変換）。
# 一時 audit log fixture を使い実リポジトリを汚染しない。

printf '\n=== TA-36: fix_loop_incremented event generation (#522) ===\n'

_t36_root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"

if ! python3 -c 'import jsonschema' >/dev/null 2>&1; then
  printf '[SKIP] TA-36 — jsonschema 未導入\n'
else
  _t36_out="$(python3 - "$_t36_root" <<'PY'
import json, sys, tempfile, os
from pathlib import Path
root = sys.argv[1]
sys.path.insert(0, os.path.join(root, "scripts"))
import importlib
mc = importlib.import_module("metrics_collector")
import jsonschema

# fixture audit log: INCREMENT 2 件（対象 task）+ 他 task + PASS 行
with tempfile.NamedTemporaryFile("w", suffix=".log", delete=False) as f:
    f.write("2026-06-11T00:00:01Z\tINCREMENT\tcheck-fix-loop\tTASK-9936\tcount=1\n")
    f.write("2026-06-11T00:00:02Z\tPASS\tcheck-fix-loop\tTASK-9936\tcount=1, max=5\n")
    f.write("2026-06-11T00:00:03Z\tINCREMENT\tcheck-fix-loop\tTASK-OTHER\tcount=1\n")
    f.write("2026-06-11T00:00:04Z\tINCREMENT\tcheck-fix-loop\tTASK-9936\tcount=2\n")
    log = f.name
try:
    events = mc.derive_fix_loop_events("TASK-9936", Path(log))
    assert len(events) == 2, f"expected 2 events, got {len(events)}"
    assert [e["fix_loop_count"] for e in events] == [1, 2], events
    assert all(e["event"] == "fix_loop_incremented" for e in events)
    # schema 適合（fix_loop_incremented は fix_loop_count 必須）
    schema = json.load(open(os.path.join(root, "schemas", "plangate-event.schema.json")))
    for e in events:
        jsonschema.validate(e, schema)
    print("OK")
finally:
    os.unlink(log)
PY
)" && _t36_rc=0 || _t36_rc=$?
  if [ "$_t36_rc" -eq 0 ] && [ "$_t36_out" = "OK" ]; then
    printf '[PASS] TA-36 TC-01: INCREMENT 行から schema 適合の fix_loop_incremented を生成（他 task/PASS 行は除外）\n'
    pass=$((pass + 1))
  else
    printf '[FAIL] TA-36 TC-01: rc=%s out=%s\n' "$_t36_rc" "$_t36_out"
    fail=$((fail + 1))
  fi
fi
