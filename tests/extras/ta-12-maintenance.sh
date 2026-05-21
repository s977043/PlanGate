# tests/extras/ta-12-maintenance.sh
# Sourced by tests/run-tests.sh — uses $pass / $fail counters
# TASK-0106: bin/plangate maintenance + EH-3 v2 (allowed_paths/one_shot/consumed_at + Override + flock+inode)

printf '\n=== TA-12: TASK-0106 maintenance + EH-3 v2 ===\n'

PG_T12_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
PG_T12_PG="$PG_T12_ROOT/bin/plangate"
PG_T12_HOOK="$PG_T12_ROOT/scripts/hooks/check-plan-hash.sh"
PG_T12_MAINT_DIR="$PG_T12_ROOT/docs/working/_maintenance"
PG_T12_MAINT="$PG_T12_MAINT_DIR/maintenance.json"
PG_T12_SCHEMA="$PG_T12_ROOT/schemas/maintenance.schema.json"

mkdir -p "$PG_T12_MAINT_DIR"
rm -f "$PG_T12_MAINT" 2>/dev/null || true

t12_pass() { pass=$((pass + 1)); printf '  [PASS] %s\n' "$1"; }
t12_fail() { fail=$((fail + 1)); printf '  [FAIL] %s\n' "$1" >&2; }

# TC-25 (AC-5 L1): isatty reject (test env is non-tty)
_out=$("$PG_T12_PG" maintenance start --reason "test" 2>&1 || true)
if printf '%s' "$_out" | grep -q 'L1 interactive TTY required'; then
  t12_pass "TC-25 L1 isatty reject (non-tty)"
else
  t12_fail "TC-25 L1 reject"
fi

# stop noop
_out=$("$PG_T12_PG" maintenance stop 2>&1 || true)
printf '%s' "$_out" | grep -q 'no active maintenance window' \
  && t12_pass "stop noop" || t12_fail "stop noop"

# Schema validate
python3 - "$PG_T12_SCHEMA" <<'PYV'
import json, sys
try:
    import jsonschema
except ImportError:
    print("skip"); sys.exit(0)
sc = json.load(open(sys.argv[1]))
v1 = {"scope":"x","until":2000000000,"granted_at":1999999000,"reason":"x","approved_by":"x"}
jsonschema.validate(v1, sc)
v2 = {**v1, "allowed_paths":["README.md"], "one_shot":True, "consumed_at":1999999500}
jsonschema.validate(v2, sc)
bad = {**v1, "evil":"x"}
try:
    jsonschema.validate(bad, sc); raise SystemExit("did not reject")
except jsonschema.ValidationError:
    pass
print("ok")
PYV
if [ $? -eq 0 ]; then t12_pass "schema v1/v2/additionalProperties:false"; else t12_fail "schema"; fi

# Hook fixture helpers
_t12_now=$(date -u +%s)
_t12_v1() { cat > "$PG_T12_MAINT" <<EOF
{"scope":"t","until":$((_t12_now+600)),"granted_at":$((_t12_now-1)),"reason":"t","approved_by":"t"}
EOF
}
_t12_v2() { cat > "$PG_T12_MAINT" <<EOF
{"scope":"t","until":$((_t12_now+600)),"granted_at":$((_t12_now-1)),"reason":"t","approved_by":"t","allowed_paths":["README.md"],"one_shot":true}
EOF
}
_t12_expired() { cat > "$PG_T12_MAINT" <<EOF
{"scope":"t","until":$((_t12_now-10)),"granted_at":$((_t12_now-1200)),"reason":"t","approved_by":"t"}
EOF
}

# TC-24 (AC-3): Hardening Override 10 パターン
_t12_ov_failed=0
for p in \
  ".claude/rules/test.md" \
  ".claude/settings.json" \
  ".claude/commands/foo.md" \
  ".claude/agents/bar.md" \
  "scripts/hooks/check-plan-hash.sh" \
  "bin/plangate" \
  "schemas/maintenance.schema.json" \
  ".github/workflows/test.yml" \
  "AGENTS.md" \
  "CLAUDE.md"; do
  _t12_v1
  _out=$(PLANGATE_HOOK_FILE="$p" sh "$PG_T12_HOOK" 2>&1 || true)
  printf '%s' "$_out" | grep -q 'HARDENING_OVERRIDE' || { _t12_ov_failed=1; printf '    miss: %s\n' "$p" >&2; }
done
[ "$_t12_ov_failed" = "0" ] && t12_pass "TC-24 Hardening Override 10 パターン全 block" \
  || t12_fail "TC-24 Hardening Override"

# TC-33 (AC-12): target_file 表記揺れ
_t12_norm_failed=0
for p in "./.github/workflows/test.yml" ".github/workflows/test.yml" "$PG_T12_ROOT/.github/workflows/test.yml"; do
  _t12_v1
  _out=$(PLANGATE_HOOK_FILE="$p" sh "$PG_T12_HOOK" 2>&1 || true)
  printf '%s' "$_out" | grep -q 'HARDENING_OVERRIDE' || _t12_norm_failed=1
done
[ "$_t12_norm_failed" = "0" ] && t12_pass "TC-33 target_file 表記揺れ block (./ 有無/絶対パス)" \
  || t12_fail "TC-33 target_file 正規化"

# TC-12 (AC-7): v1 後方互換
_t12_v1
_out=$(PLANGATE_HOOK_FILE="docs/foo.md" sh "$PG_T12_HOOK" 2>&1 || true)
printf '%s' "$_out" | grep -q 'MAINTENANCE_SKIP' \
  && t12_pass "TC-12 v1 後方互換 (Override 対象以外 PASS)" \
  || t12_fail "TC-12 v1 backward compat"

# TC-03/TC-04 (AC-2/AC-11): one_shot 消費
_t12_v2
_out=$(PLANGATE_HOOK_FILE="README.md" sh "$PG_T12_HOOK" 2>&1 || true)
printf '%s' "$_out" | grep -q 'one_shot consumed' \
  && t12_pass "TC-03 one_shot 1 回目 consume + SKIP" \
  || t12_fail "TC-03 one_shot consume"
_consumed=$(python3 -c "import json; print(json.load(open('$PG_T12_MAINT')).get('consumed_at'))")
[ "$_consumed" != "None" ] \
  && t12_pass "TC-03 consumed_at atomically 書込" \
  || t12_fail "consumed_at not written"
_out=$(PLANGATE_HOOK_FILE="README.md" sh "$PG_T12_HOOK" 2>&1 || true)
printf '%s' "$_out" | grep -q 'SKIP_REASON 未設定' \
  && t12_pass "TC-04 2 回目 block (fall-through)" \
  || t12_fail "TC-04 2 回目 block"

# TC-06 (AC-3): out of scope
_t12_v2
_out=$(PLANGATE_HOOK_FILE="docs/foo.md" sh "$PG_T12_HOOK" 2>&1 || true)
printf '%s' "$_out" | grep -q 'SKIP_REASON 未設定' \
  && t12_pass "TC-06 out of scope block" \
  || t12_fail "TC-06 out of scope"

# TC-08 (AC-4): TTL expired
_t12_expired
_out=$(PLANGATE_HOOK_FILE="docs/foo.md" sh "$PG_T12_HOOK" 2>&1 || true)
printf '%s' "$_out" | grep -q 'SKIP_REASON 未設定' \
  && t12_pass "TC-08 TTL expired block" \
  || t12_fail "TC-08 TTL expired"

# TC-10 (AC-5/AC-10): env 経由有効化不可
rm -f "$PG_T12_MAINT"
_out=$(PLANGATE_HOOK_FILE="docs/foo.md" PLANGATE_MAINT_ENABLE=1 sh "$PG_T12_HOOK" 2>&1 || true)
printf '%s' "$_out" | grep -q 'SKIP_REASON 未設定' \
  && t12_pass "TC-10 env 経由有効化不可 (ファイル不在=block 維持)" \
  || t12_fail "TC-10 env-only"

# TC-34 (AC-13): doctor --json --scope maintenance
rm -f "$PG_T12_MAINT"
_out=$(python3 "$PG_T12_ROOT/scripts/doctor_check.py" --scope maintenance 2>/dev/null)
printf '%s' "$_out" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d.get('scope') == 'maintenance' and d['maintenance']['present'] is False
" 2>/dev/null \
  && t12_pass "TC-34 doctor --json (no maint, present:false)" \
  || t12_fail "TC-34 doctor JSON empty"

_t12_v2
_out=$(python3 "$PG_T12_ROOT/scripts/doctor_check.py" --scope maintenance 2>/dev/null)
printf '%s' "$_out" | python3 -c "
import json, sys
d = json.load(sys.stdin)
m = d['maintenance']
assert m['present'] is True and m['one_shot'] is True
assert m['allowed_paths'] == ['README.md']
assert 'remaining_mmss' in m and 'remaining_seconds' in m
" 2>/dev/null \
  && t12_pass "TC-34 doctor --json (active v2 fixture)" \
  || t12_fail "TC-34 doctor JSON v2"

# cleanup
rm -f "$PG_T12_MAINT" 2>/dev/null || true
