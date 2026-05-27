# tests/extras/ta-20-codex-review.sh
# Sourced by tests/run-tests.sh — uses $pass / $fail counters
# TASK-0109 (#315): bin/plangate review --reviewer codex の wiring 検証

printf '\n=== TA-20: codex review wiring (#315 TASK-0109) ===\n'

PG_T20_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
PG_T20_BIN="$PG_T20_ROOT/bin/plangate"

t20_pass() { pass=$((pass + 1)); printf '  [PASS] %s\n' "$1"; }
t20_fail() { fail=$((fail + 1)); printf '  [FAIL] %s\n' "$1" >&2; }

# === TC-01 (AC-1): bin/plangate review codex case が placeholder ではない ===
if grep -qE "codex review placeholder" "$PG_T20_BIN"; then
  t20_fail "TC-01 codex review 未実装 (placeholder 残存)"
else
  t20_pass "TC-01 codex review placeholder 削除済"
fi

# === TC-02 (AC-1/R-005 CRITICAL): --sandbox read-only 付与 ===
if grep -qE "codex exec.*--sandbox read-only|sandbox read-only.*codex exec" "$PG_T20_BIN"; then
  t20_pass "TC-02 codex exec に --sandbox read-only (R-005 CRITICAL)"
else
  # 改行で分かれている可能性
  if grep -A3 "codex exec" "$PG_T20_BIN" | grep -qE "sandbox read-only"; then
    t20_pass "TC-02 codex exec に --sandbox read-only (改行検出)"
  else
    t20_fail "TC-02 --sandbox read-only なし"
  fi
fi

# === TC-03 (R-006): timeout wrap + macOS gtimeout fallback (Gemini HIGH 反映後) ===
if grep -qE 'codex_timeout_cmd="timeout 600"|timeout 600 codex' "$PG_T20_BIN"; then
  t20_pass "TC-03 timeout 600 で codex exec wrap (R-006)"
else
  t20_fail "TC-03 timeout wrap なし"
fi
if grep -qE "gtimeout 600" "$PG_T20_BIN"; then
  t20_pass "TC-03b gtimeout (macOS coreutils) fallback (Gemini HIGH 反映)"
else
  t20_fail "TC-03b gtimeout fallback なし"
fi

# === TC-04 (R-007): --output-last-message でクリーン出力 ===
if grep -qE "output-last-message" "$PG_T20_BIN"; then
  t20_pass "TC-04 --output-last-message でクリーン出力 (R-007)"
else
  t20_fail "TC-04 --output-last-message なし"
fi

# === TC-05 (R-010): codex CLI 未 install error handling ===
if grep -qE "command -v codex.*codex CLI not found|codex CLI not found" "$PG_T20_BIN"; then
  t20_pass "TC-05 codex CLI 未 install error handling (R-010)"
else
  t20_fail "TC-05 未 install check なし"
fi

# === TC-06 (AC-2/CX-2): .codex/hooks.json で EH-1/2/3/6/9 配線確認 ===
HOOKS_JSON="$PG_T20_ROOT/.codex/hooks.json"
if [ -f "$HOOKS_JSON" ]; then
  if grep -qE "check-plan-exists.sh" "$HOOKS_JSON" && \
     grep -qE "check-c3-approval.sh" "$HOOKS_JSON" && \
     grep -qE "check-plan-hash.sh" "$HOOKS_JSON" && \
     grep -qE "check-forbidden-files.sh" "$HOOKS_JSON" && \
     grep -qE "check-delegation-commit-boundary.sh" "$HOOKS_JSON"; then
    t20_pass "TC-06 .codex/hooks.json で EH-1/2/3/6/9 全 5 hook 配線済 (CX-2)"
  else
    t20_fail "TC-06 hook 配線不足"
  fi
else
  t20_fail "TC-06 .codex/hooks.json 不在"
fi

# === TC-07 (AC-2/CX-2): .codex/hooks/eh-bridge.sh 存在 + shim symlink 対応 ===
BRIDGE="$PG_T20_ROOT/.codex/hooks/eh-bridge.sh"
if [ -f "$BRIDGE" ] && [ -x "$BRIDGE" ]; then
  if grep -qE 'CDPATH= cd -- .*pwd' "$BRIDGE"; then
    t20_pass "TC-07 eh-bridge.sh 存在 + shim symlink 解決 (R-009)"
  else
    t20_fail "TC-07 eh-bridge.sh shim symlink 対応なし"
  fi
else
  t20_fail "TC-07 eh-bridge.sh 不在 or 非実行"
fi

# === TC-08 (AC-3): docs/rfc/provider-codex.md 存在 + 主要 section ===
RFC="$PG_T20_ROOT/docs/rfc/provider-codex.md"
if [ -f "$RFC" ]; then
  # Gemini R-002: grep -q | head -1 はパイプライン終了 status を head が常に 0 で隠蔽するため不可
  # grep -qE 単体で終了 status 評価
  if grep -qE "## (Summary|Motivation|Architecture|Implementation|Setup)" "$RFC"; then
    t20_pass "TC-08 provider-codex.md 存在 + 主要 section"
  else
    t20_fail "TC-08 主要 section 不足"
  fi
  # Role Mapping 確認 (R-010 Gemini 提案)
  if grep -qE "Role Mapping" "$RFC"; then
    t20_pass "TC-08b Role Mapping 表存在 (Gemini R-010)"
  else
    t20_fail "TC-08b Role Mapping 表不在"
  fi
else
  t20_fail "TC-08 provider-codex.md 不在"
fi

# === TC-09: bin/plangate syntax check (改修後も sh -n PASS) ===
if sh -n "$PG_T20_BIN" 2>/dev/null; then
  t20_pass "TC-09 bin/plangate syntax check (sh -n PASS)"
else
  t20_fail "TC-09 bin/plangate syntax error"
fi
