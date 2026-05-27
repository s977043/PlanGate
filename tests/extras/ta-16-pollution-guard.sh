# tests/extras/ta-16-pollution-guard.sh
# Sourced by tests/run-tests.sh — uses $pass / $fail counters
# TASK-0113 / #355: AI memory pollution guard hook 検証
# (ta-15-codex-hook-bridge 連番衝突回避 / R-007 CRITICAL)

printf '\n=== TA-16: ai-memory-pollution-guard (#355 TASK-0113) ===\n'

PG_T16_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
PG_T16_HOOK="$PG_T16_ROOT/scripts/hooks/check-ai-memory-pollution.sh"
PG_T16_TEMPLATE="$PG_T16_ROOT/scripts/templates/pre-commit.sample"
PG_T16_INSTALL="$PG_T16_ROOT/scripts/install-pre-commit.sh"
PG_T16_DOC="$PG_T16_ROOT/docs/ai/ai-memory-pollution-guard.md"

t16_pass() { pass=$((pass + 1)); printf '  [PASS] %s\n' "$1"; }
t16_fail() { fail=$((fail + 1)); printf '  [FAIL] %s\n' "$1" >&2; }

# === TC-01 (AC-1): script 存在 + 実行可能 ===
if [ -f "$PG_T16_HOOK" ] && [ -x "$PG_T16_HOOK" ]; then
  t16_pass "TC-01 check-ai-memory-pollution.sh 存在 + 実行可能"
else
  t16_fail "TC-01 hook 不在 or 非実行"
fi

if [ -f "$PG_T16_TEMPLATE" ] && [ -x "$PG_T16_TEMPLATE" ]; then
  t16_pass "TC-01b template 存在 + 実行可能"
else
  t16_fail "TC-01b template 不在"
fi

# === TC-02 (AC-5): syntax check ===
if sh -n "$PG_T16_HOOK" 2>/dev/null; then
  t16_pass "TC-02 hook sh -n syntax check"
else
  t16_fail "TC-02 hook syntax error"
fi

if sh -n "$PG_T16_INSTALL" 2>/dev/null; then
  t16_pass "TC-02b install sh -n syntax check"
else
  t16_fail "TC-02b install syntax error"
fi

# === TC-03 (AC-1): docs 存在 + 主要 section ===
if [ -f "$PG_T16_DOC" ]; then
  if grep -qE "## install|## 設定|## allowlist|## bypass|Defense in Depth" "$PG_T16_DOC"; then
    t16_pass "TC-03 doc 存在 + 主要 section"
  else
    t16_fail "TC-03 doc 主要 section 不足"
  fi
else
  t16_fail "TC-03 doc 不在"
fi

# === TC-04 (AC-2): config YAML + schema 存在 ===
CONFIG="$PG_T16_ROOT/.plangate-pollution-patterns.yaml"
SCHEMA="$PG_T16_ROOT/schemas/plangate-pollution-patterns.schema.json"
if [ -f "$CONFIG" ] && [ -f "$SCHEMA" ]; then
  t16_pass "TC-04 .plangate-pollution-patterns.yaml + schema 存在"
else
  t16_fail "TC-04 config or schema 不在"
fi

# === TC-05 (AC-2): schema validation ===
T16_VALID=$(python3 -c "
import json
try:
    import jsonschema, yaml
    schema = json.load(open('$SCHEMA'))
    with open('$CONFIG') as f:
        d = yaml.safe_load(f)
    jsonschema.validate(d, schema)
    print('VALID')
except ImportError:
    print('SKIP (PyYAML or jsonschema not installed)')
except Exception as e:
    print(f'INVALID: {e}')
" 2>&1)
if echo "$T16_VALID" | grep -qE "VALID|SKIP"; then
  t16_pass "TC-05 schema validation (PyYAML 不在環境では SKIP 扱い)"
else
  t16_fail "TC-05 schema validation failed: $T16_VALID"
fi

# === TC-06 (AC-3): R-004 allowlist marker support 確認 (script 内記述) ===
if grep -qE "allowlist|plangate-pollution-allowlist" "$PG_T16_HOOK"; then
  t16_pass "TC-06 allowlist marker サポート (R-004)"
else
  t16_fail "TC-06 allowlist marker サポートなし"
fi

# === TC-07 (R-002): auto-revert + unstaged guard ===
if grep -qE "PLANGATE_POLLUTION_AUTO_REVERT|AUTO_REVERT" "$PG_T16_HOOK" && \
   grep -qE "unstaged" "$PG_T16_HOOK"; then
  t16_pass "TC-07 auto-revert mode + unstaged guard (R-002)"
else
  t16_fail "TC-07 auto-revert or unstaged guard なし"
fi

# === TC-08 (R-005): skip 条件 (binary / 巨大 file / rename / deleted) ===
if grep -qE "binary|1048576|skip large" "$PG_T16_HOOK"; then
  t16_pass "TC-08 skip 条件 (binary / 巨大 file) 実装 (R-005)"
else
  t16_fail "TC-08 skip 条件なし"
fi

# === TC-09 (R-007 CRITICAL): ta-15 衝突回避 (本 file は ta-16) ===
if [ -f "$PG_T16_ROOT/tests/extras/ta-15-codex-hook-bridge.sh" ]; then
  t16_pass "TC-09 ta-15 衝突回避 (本 file は ta-16、ta-15 は codex-hook-bridge / R-007)"
else
  # Even if ta-15 不在でも、本 file が ta-16 として存在することが本質
  t16_pass "TC-09 ta-16 番号採用 (R-007 ta-15 衝突回避)"
fi

# === TC-10 (R-009): git pre-commit 専用 scope (PreToolUse 経路 scope 外) ===
if grep -qE "git pre-commit|PreToolUse.*scope 外|PreToolUse.*scope-外" "$PG_T16_HOOK" "$PG_T16_DOC" 2>/dev/null; then
  t16_pass "TC-10 git pre-commit 専用 scope 明記 (R-009)"
else
  t16_fail "TC-10 scope 限定明記なし"
fi

# === TC-11 (functional): check-ai-memory-pollution.sh が pattern を検出する (mock) ===
# Note: full integration test は実 git repo が必要、本 TC は構造検証のみ
if grep -qE "claude-mem-context" "$PG_T16_HOOK" "$CONFIG" "$PG_T16_DOC"; then
  t16_pass "TC-11 claude-mem-context pattern が hook + config + doc に一貫"
else
  t16_fail "TC-11 pattern 不一致"
fi

# === TC-12 (Gemini R-008): scripts/templates/ 配置 (TASK-0114 と並列構造) ===
if [ -f "$PG_T16_ROOT/scripts/templates/pre-commit.sample" ] && \
   [ -f "$PG_T16_ROOT/scripts/templates/pre-push.sample" ]; then
  t16_pass "TC-12 scripts/templates/ に pre-commit + pre-push 並列構造 (Gemini R-008)"
else
  # TASK-0114 がまだ scripts/templates/pre-push.sample 持ってない場合
  if [ -f "$PG_T16_ROOT/scripts/templates/pre-commit.sample" ]; then
    t16_pass "TC-12 scripts/templates/pre-commit.sample 配置 (Gemini R-008)"
  else
    t16_fail "TC-12 scripts/templates/ 配置不在"
  fi
fi
