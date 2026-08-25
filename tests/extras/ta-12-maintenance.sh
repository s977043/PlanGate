# tests/extras/ta-12-maintenance.sh
# Sourced by tests/run-tests.sh — uses $pass / $fail counters
# TASK-0106: bin/plangate maintenance + EH-3 v2 (allowed_paths/one_shot/consumed_at + Override + flock+inode)

printf '\n=== TA-12: TASK-0106 maintenance + EH-3 v2 ===\n'

# ────────── repo root の解決（M4 是正 / #1210）──────────
# 本 extras は harness 専用（$FIXTURES_DIR 依存）。$FIXTURES_DIR が未設定/空の
# まま合成すると cd -- "/../.." が / に解決され、以降のパスが
# //docs/working/... になる。合成後の文字列は「非空」なので
# 合成後のパスに付けた :? ガードは発火せず、rm がファイルシステムルート
# 直下を指す（stub rm 実測: RM-CALLED: -rf //docs/working/... が発火）。
# したがってガードは合成後ではなく「root 側」に置く（ta-44 / ta-45 と同形）。
_T12_FX="${FIXTURES_DIR:-}"
if [ -n "$_T12_FX" ]; then
  PG_T12_ROOT="$(CDPATH= cd -- "$_T12_FX/../.." && pwd)"
else
  # harness 実行ではないので、規約 8 に従い呼び出し元 env を無害化してから
  # 何もせず抜ける（run-tests.sh 冒頭と同一の 7 env）。
  unset PLANGATE_SKIP_REASON PLANGATE_HOOK_TASK PLANGATE_HOOK_FILE PLANGATE_BYPASS_HOOK PLANGATE_HOOK_STRICT PG_HARNESS_SOURCED PLANGATE_ALLOW_MASS_DELETE 2>/dev/null || true
  PG_T12_ROOT=""
fi
# root の健全性検査: 解決結果が本 repo でなければ副作用を一切出さずに抜ける
# （非空チェックだけでは / を弾けないため実体で確かめる）。
if [ -z "$PG_T12_ROOT" ] || [ ! -f "$PG_T12_ROOT/bin/plangate" ]; then
  printf '  [FAIL] ta-12: repo root unresolved (FIXTURES_DIR=%s root=%s) — refusing to run\n' \
    "${_T12_FX:-(unset)}" "${PG_T12_ROOT:-(empty)}" >&2
  if [ "${PG_HARNESS_SOURCED:-0}" = "1" ]; then
    fail=$((fail + 1))
    return 0
  fi
  exit 1
fi
PG_T12_PG="${PG_T12_ROOT:?ta-12: repo root unresolved}/bin/plangate"
PG_T12_HOOK="$PG_T12_ROOT/scripts/hooks/check-plan-hash.sh"
PG_T12_MAINT_DIR="$PG_T12_ROOT/docs/working/_maintenance"
PG_T12_MAINT="$PG_T12_MAINT_DIR/maintenance.json"
PG_T12_SCHEMA="$PG_T12_ROOT/schemas/maintenance.schema.json"

# ── 一時状態の射程宣言 + 先頭 prune + cleanup 登録（#1209 / #1210）──────
# 本 extras は EH-3 のメンテ承認判定を検査するため、$PG_T12_MAINT（実の repo 配下）
# を使うしかない。bin/plangate も scripts/hooks/check-plan-hash.sh も $REPO_ROOT 配下を
# 固定参照しており、sandbox へ逃がす env seam が存在しない（両者とも Hardening
# Override 対象のため本 PR からは触れない）。結果として中断残骸が EH-3 の
# legacy 窓を開けたままにしうる（#1209）。緩和は 3 点: (1) body の副作用より前の
# prune (2) register_cleanup 登録によるハーネス末尾 drain (3) TTL の最小化。
# 一時状態は 1 ファイルだけなので rm は -f のまま（#1210 の ${var:?} 化に
# 合わせて -rf へ広げると、退行時の爆風半径が「ファイル」から「木」へ拡大する）。
# ${_t12_p:?} は 2 段目の防御にすぎない。1 段目は上の root 健全性検査で、
# 「合成後は非空だが root が / 」という M4 のケースを実際に止めるのはそちら。
_t12_scope_reset() {
  for _t12_p in "$@"; do
    rm -f "${_t12_p:?ta-12: empty cleanup path refused}"
    if command -v register_cleanup >/dev/null 2>&1; then
      register_cleanup "$_t12_p"
    fi
  done
}
_t12_scope_reset "$PG_T12_MAINT"

mkdir -p "$PG_T12_MAINT_DIR"

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
# fixture の TTL 契約の正本は tests/extras/README.md 規約 9「契約値」表
# （上限 120 秒 / until は本変数経由・正の直書き禁止）。ta-76 TC-04 がその表を
# 機械検査する。ここは表に収まる範囲でテストが必要とする値を選ぶ（#1209）。旧実装は
# until = _t12_now + 600（_t12_now はファイル冒頭で 1 度だけ固定）で、中断残骸が
# 最大 600 秒「非 HO パスへの無条件 MAINTENANCE_SKIP」窓を残していた。呼出時に
# now を取り直し TTL=$_T12_TTL 秒にすることで、各 TC の hook 呼出には十分な余裕を
# 残しつつ残骸窓を 1/10 へ縮める。
_T12_TTL=60
_t12_v1() { _t12_n=$(date -u +%s); cat > "$PG_T12_MAINT" <<EOF
{"scope":"t","until":$((_t12_n+_T12_TTL)),"granted_at":$((_t12_n-1)),"reason":"t","approved_by":"t"}
EOF
}
_t12_v2() { _t12_n=$(date -u +%s); cat > "$PG_T12_MAINT" <<EOF
{"scope":"t","until":$((_t12_n+_T12_TTL)),"granted_at":$((_t12_n-1)),"reason":"t","approved_by":"t","allowed_paths":["README.md"],"one_shot":true}
EOF
}
_t12_expired() { _t12_n=$(date -u +%s); cat > "$PG_T12_MAINT" <<EOF
{"scope":"t","until":$((_t12_n-10)),"granted_at":$((_t12_n-1200)),"reason":"t","approved_by":"t"}
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
_out=$(PLANGATE_HOOK_FILE="docs/foo.ts" PLANGATE_MAINT_ENABLE=1 sh "$PG_T12_HOOK" 2>&1 || true)
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

# cleanup（register_cleanup 未提供環境向けの明示後始末。
# harness では _pg_drain_cleanup が二重に担保する）
rm -f "${PG_T12_MAINT:?ta-12: empty token path refused}" 2>/dev/null || true
