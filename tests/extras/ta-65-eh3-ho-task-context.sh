# tests/extras/ta-65-eh3-ho-task-context.sh
# PG_EXTRA_CAPABILITY: standalone-capable
# Sourced by tests/run-tests.sh — uses $pass / $fail counters
# #1089 / TASK-1089: EH-3 Hardening Override が PLANGATE_HOOK_TASK 設定時にも
# 発火することの回帰テスト。
#
# 【期待値は既定 fixed / gap は明示 opt-in】(#1089 レビュー MAJOR-1 対応)
#   - **既定の期待値は fixed**（HO は TASK 文脈でも常時 block）。
#     被検査コードの構造から期待値を導かないため、**コードが元の構造へ戻ると
#     CI が RED になる**（#1089 の再発をテスト自身が検知する）。
#   - gap（既知ギャップの受理）は **tests/fixtures/eh3-known-gap-1089.flag の
#     存在という明示 opt-in でのみ**成立する。flag は tracked ファイルであり、
#     再追加はレビュー可能な差分として現れる。
#   - flag があるのに実装が fixed（＝ patch は当たったが flag 未削除）なら
#     **stale 宣言として FAIL** する（黙って緑にならない）。
#   - どちらの mode でも「全 HO カテゴリが同一挙動」を実測表明する
#     → 部分適用・カテゴリ取りこぼし・判定 call site の破壊は必ず FAIL
#   - PG_T65_EXPECT=fixed|gap で期待値を pin できる（デバッグ用）。この seam は
#     失敗を増やすことしかできない（成功を偽装する経路はない）
#
# HO カテゴリは絶対件数を assert せず hook 本体の case 文から導出する
# （正本: .claude/rules/mode-classification.md Hardening Override 節）。
# サンドボックス方式で実 audit ログを汚染しない（ta-39 / ta-12 方式）。

# ---- extras execution contract bootstrap (#921) ----------------------------
if [ "${PG_HARNESS_SOURCED:-0}" = "1" ] && [ -n "${FIXTURES_DIR:-}" ] && [ -n "${EXTRAS_DIR:-}" ]; then
  _pg_extra_mode=harness
  _pg_extra_dir="$EXTRAS_DIR"
else
  _pg_extra_mode=standalone
  _pg_extra_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
fi
_pg_extra_helper="$_pg_extra_dir/_extra-contract.sh"
if [ ! -r "$_pg_extra_helper" ]; then
  printf '  [FAIL] helper unresolved: %s\n' "$_pg_extra_helper" >&2
  if [ "$_pg_extra_mode" = harness ]; then
    fail=$((fail + 1))
    return 0
  fi
  exit 1
fi
. "$_pg_extra_helper"
pg_extra_contract_init ta-65-eh3-ho-task-context standalone-capable

printf '\n=== TA-65: EH-3 Hardening Override × TASK 文脈 (#1089) ===\n'

# ── セットアップ ──────────────────────────────────────────────────
if [ "${PG_HARNESS_SOURCED:-0}" = "1" ] && [ -n "${FIXTURES_DIR:-}" ]; then
  _T65_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
else
  # standalone 実行: 外部 env 汚染を無害化（tests/extras/README.md 規約 8）
  unset PLANGATE_SKIP_REASON PLANGATE_HOOK_TASK PLANGATE_HOOK_FILE PLANGATE_BYPASS_HOOK PLANGATE_HOOK_STRICT PG_HARNESS_SOURCED PLANGATE_ALLOW_MASS_DELETE 2>/dev/null || true
  _T65_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
fi
_T65_HOOK_SRC="$_T65_ROOT/scripts/hooks/check-plan-hash.sh"

t65_pass() { pass=$((pass + 1)); printf '  [PASS] %s\n' "$1"; }
t65_fail() { fail=$((fail + 1)); printf '  [FAIL] %s\n' "$1" >&2; }

# hook 実行ヘルパ: 位置引数で env を渡す（関数呼び出しへの env 前置は
# shell 間で永続化挙動が割れるため使わない）
#   $1 = TASK ("" で no-task) / $2 = 対象パス / $3 = STRICT(1) / $4 = BYPASS(1)
_t65_hook() {
  PLANGATE_HOOK_TASK="$1" PLANGATE_HOOK_FILE="$2" \
  PLANGATE_HOOK_STRICT="${3:-0}" PLANGATE_BYPASS_HOOK="${4:-0}" \
    sh "$_T65_HOOK" </dev/null 2>&1
}

_T65_ABORT=0
if [ ! -r "$_T65_HOOK_SRC" ]; then
  _T65_ABORT=1
  pg_extra_contract_skip "check-plan-hash.sh unresolved: $_T65_HOOK_SRC"
fi

if [ "$_T65_ABORT" = "0" ]; then
  _T65_TMP=$(mktemp -d)
  register_cleanup "$_T65_TMP"
  mkdir -p "$_T65_TMP/scripts/hooks" "$_T65_TMP/docs/working/_audit" \
           "$_T65_TMP/docs/working/TASK-T65/approvals"
  cp "$_T65_HOOK_SRC" "$_T65_TMP/scripts/hooks/check-plan-hash.sh"
  _T65_HOOK="$_T65_TMP/scripts/hooks/check-plan-hash.sh"
  _T65_TASK=TASK-T65

  # ── HO カテゴリ代表パスを hook の case 文から導出（件数を固定しない）──
  # `_override=0` の次行から直近の `esac` までの case ラベル左辺を `|` 分割し、
  # glob の `*` を `x` に置換して代表パスにする。
  _T65_PATTERNS=$(awk '
    /_override=0/ { grab=1; next }
    grab && /^[[:space:]]*esac/ { exit }
    grab && /_override=1/ {
      line=$0
      sub(/\)[[:space:]]*_override=1.*$/, "", line)
      gsub(/^[[:space:]]+/, "", line)
      n=split(line, parts, "|")
      for (i=1; i<=n; i++) {
        p=parts[i]
        gsub(/[[:space:]]/, "", p)
        if (p != "") print p
      }
    }
  ' "$_T65_HOOK_SRC" | sed 's/\*/x/g')
  _T65_PATTERN_COUNT=$(printf '%s\n' "$_T65_PATTERNS" | grep -c '[^[:space:]]' || true)

  if [ "${_T65_PATTERN_COUNT:-0}" -ge 1 ]; then
    t65_pass "TC-00: HO カテゴリを hook の case 文から導出 (${_T65_PATTERN_COUNT} パターン)"
  else
    t65_fail "TC-00: HO カテゴリ導出に失敗 (0 パターン) — case 文の構造が変わった可能性"
    _T65_ABORT=1
  fi
fi

# ── 期待値の決定（既定 fixed / gap は flag による明示 opt-in）──────
if [ "$_T65_ABORT" = "0" ]; then
  # 構造は「期待値の決定」には使わず、診断と stale 宣言の検出にだけ使う。
  _T65_LN_TASKBRANCH=$(grep -n 'if \[ -z "\$task_id" \]' "$_T65_HOOK_SRC" | head -1 | cut -d: -f1)
  _T65_LN_OVERRIDE=$(grep -n '_override=0' "$_T65_HOOK_SRC" | head -1 | cut -d: -f1)
  if [ -n "$_T65_LN_TASKBRANCH" ] && [ -n "$_T65_LN_OVERRIDE" ] && \
     [ "$_T65_LN_OVERRIDE" -lt "$_T65_LN_TASKBRANCH" ]; then
    _T65_STRUCT=fixed
  else
    _T65_STRUCT=gap
  fi
  _T65_FLAG="$_T65_ROOT/tests/fixtures/eh3-known-gap-1089.flag"

  if [ -n "${PG_T65_EXPECT:-}" ]; then
    _T65_MODE="$PG_T65_EXPECT"
    printf '  [INFO] 期待値を pin: PG_T65_EXPECT=%s（既定判定を上書き）\n' "$_T65_MODE"
  elif [ -f "$_T65_FLAG" ]; then
    _T65_MODE=gap
  else
    _T65_MODE=fixed
  fi

  # stale 宣言の検出: flag があるのに実装は既に fixed → 宣言を削除すべき
  if [ -z "${PG_T65_EXPECT:-}" ] && [ -f "$_T65_FLAG" ] && [ "$_T65_STRUCT" = fixed ]; then
    t65_fail "TC-00b: stale KNOWN-GAP 宣言 — 実装は既に fixed (L$_T65_LN_OVERRIDE < L$_T65_LN_TASKBRANCH) なのに tests/fixtures/eh3-known-gap-1089.flag が残っている。flag を削除すること（scripts/apply-eh3-ho-always.sh --apply が自動で削除する）"
    _T65_MODE=fixed
  fi

  case "$_T65_MODE" in
    fixed)
      printf '  [INFO] 期待 = fixed（既定。KNOWN-GAP flag なし）/ 構造: %s (L%s vs L%s)\n' \
        "$_T65_STRUCT" "${_T65_LN_OVERRIDE:-?}" "${_T65_LN_TASKBRANCH:-?}"
      _T65_EXP_RC=2
      ;;
    gap)
      printf '  [KNOWN-GAP #1089] tests/fixtures/eh3-known-gap-1089.flag により gap を受理（構造: %s / L%s vs L%s）\n' \
        "$_T65_STRUCT" "${_T65_LN_OVERRIDE:-?}" "${_T65_LN_TASKBRANCH:-?}"
      printf '  [KNOWN-GAP #1089] PLANGATE_HOOK_TASK 設定時、HO パスは block されない（patch 未適用）\n'
      _T65_EXP_RC=0
      ;;
    *)
      t65_fail "TC-00b: PG_T65_EXPECT の値が不正: $_T65_MODE (fixed|gap のみ)"
      _T65_ABORT=1
      ;;
  esac
fi

if [ "$_T65_ABORT" = "0" ]; then
  # === TC-01 (AC-1/AC-2): TASK 文脈ありで HO 全カテゴリが同一挙動 ===
  _t65_bad=0
  _t65_checked=0
  for _t65_p in $_T65_PATTERNS; do
    _t65_checked=$((_t65_checked + 1))
    _t65_rc=0
    _t65_out=$(_t65_hook "$_T65_TASK" "$_t65_p") || _t65_rc=$?
    if [ "$_t65_rc" != "$_T65_EXP_RC" ]; then
      _t65_bad=$((_t65_bad + 1))
      printf '    mismatch: %s → rc=%s (expected rc=%s)\n' "$_t65_p" "$_t65_rc" "$_T65_EXP_RC" >&2
    elif [ "$_T65_MODE" = fixed ] && ! printf '%s' "$_t65_out" | grep -q 'HARDENING_OVERRIDE'; then
      _t65_bad=$((_t65_bad + 1))
      printf '    mismatch: %s → rc=2 だが HARDENING_OVERRIDE 出力なし\n' "$_t65_p" >&2
    fi
  done
  if [ "$_t65_bad" = "0" ] && [ "$_t65_checked" = "$_T65_PATTERN_COUNT" ]; then
    t65_pass "TC-01: TASK 文脈あり × HO ${_T65_PATTERN_COUNT} パターン すべて期待どおり (mode=$_T65_MODE / rc=$_T65_EXP_RC)"
  else
    t65_fail "TC-01: TASK 文脈あり × HO パターン不一致 ${_t65_bad}/${_T65_PATTERN_COUNT} (mode=$_T65_MODE)"
  fi

  # === TC-01b (AC-7): 独立正本（mode-classification.md）由来のパスでも同じ判定 ===
  # hook の case 文だけを根拠にすると「カテゴリ削除／改名」が自己参照で不可視に
  # なるため、正本 .claude/rules/mode-classification.md の Hardening Override 節
  # からも代表パスを導出して同じ表明を行う（件数は固定しない）。
  _T65_RULES="$_T65_ROOT/.claude/rules/mode-classification.md"
  if [ -r "$_T65_RULES" ]; then
    _T65_DOC_PATTERNS=$(awk '/対象パス \(Hardening Override/{g=1} g&&/\(注:/{exit} g' "$_T65_RULES" \
      | grep -o '`[^`]*`' | tr -d '`' | grep '[./]' | sed 's/\*/x/g' | sort -u)
    _T65_DOC_COUNT=$(printf '%s\n' "$_T65_DOC_PATTERNS" | grep -c '[^[:space:]]' || true)
    if [ "${_T65_DOC_COUNT:-0}" -lt 1 ]; then
      t65_fail "TC-01b: 正本 mode-classification.md から HO パスを導出できない（節構造が変わった可能性）"
    else
      _t65_bad=0
      for _t65_p in $_T65_DOC_PATTERNS; do
        _t65_rc=0
        _t65_out=$(_t65_hook "$_T65_TASK" "$_t65_p") || _t65_rc=$?
        if [ "$_t65_rc" != "$_T65_EXP_RC" ]; then
          _t65_bad=$((_t65_bad + 1))
          printf '    doc mismatch: %s → rc=%s (expected rc=%s)\n' "$_t65_p" "$_t65_rc" "$_T65_EXP_RC" >&2
        fi
      done
      if [ "$_t65_bad" = "0" ]; then
        t65_pass "TC-01b (AC-7): 正本由来 ${_T65_DOC_COUNT} パス すべて期待どおり (mode=$_T65_MODE / rc=$_T65_EXP_RC)"
      else
        t65_fail "TC-01b (AC-7): 正本と実装の乖離 ${_t65_bad}/${_T65_DOC_COUNT} (mode=$_T65_MODE)"
      fi
    fi
  else
    t65_fail "TC-01b: 正本 mode-classification.md が読めない: $_T65_RULES"
  fi

  # === TC-02 (AC-1): stdin JSON 経由でも同じ判定 ===
  _t65_rc=0
  _t65_out=$(printf '{"tool_input":{"file_path":"CLAUDE.md"}}' \
    | PLANGATE_HOOK_TASK="$_T65_TASK" sh "$_T65_HOOK" 2>&1) || _t65_rc=$?
  if [ "$_t65_rc" = "$_T65_EXP_RC" ]; then
    t65_pass "TC-02: stdin JSON (CLAUDE.md) × TASK 文脈 → rc=$_T65_EXP_RC (mode=$_T65_MODE)"
  else
    t65_fail "TC-02: stdin JSON 期待 rc=$_T65_EXP_RC, got rc=$_t65_rc"
  fi

  # === TC-03 (AC-3): TASK 未設定時の block は不変（両 mode で rc=2）===
  _t65_bad=0
  for _t65_p in $_T65_PATTERNS; do
    _t65_rc=0
    _t65_out=$(_t65_hook "" "$_t65_p") || _t65_rc=$?
    if [ "$_t65_rc" != "2" ] || ! printf '%s' "$_t65_out" | grep -q 'HARDENING_OVERRIDE'; then
      _t65_bad=$((_t65_bad + 1))
      printf '    no-task mismatch: %s → rc=%s\n' "$_t65_p" "$_t65_rc" >&2
    fi
  done
  if [ "$_t65_bad" = "0" ]; then
    t65_pass "TC-03 (AC-3): TASK 未設定 × HO ${_T65_PATTERN_COUNT} パターン すべて rc=2 + HARDENING_OVERRIDE"
  else
    t65_fail "TC-03 (AC-3): TASK 未設定時の block が退行 (${_t65_bad} 件)"
  fi

  # === TC-04 (AC-4): 非 HO パスの plan_hash 検証全経路が不変（両 mode 共通）===
  _t65_plan="$_T65_TMP/docs/working/$_T65_TASK/plan.md"
  _t65_c3="$_T65_TMP/docs/working/$_T65_TASK/approvals/c3.json"
  _t65_nonho="docs/working/$_T65_TASK/notes.txt"
  _t65_p4_bad=0

  _t65_expect() { # $1=label $2=expected_rc $3=expected_substring
    _t65_e_rc=0
    _t65_e_out=$(_t65_hook "$_T65_TASK" "$_t65_nonho") || _t65_e_rc=$?
    if [ "$_t65_e_rc" = "$2" ] && printf '%s' "$_t65_e_out" | grep -q "$3"; then
      printf '    ok: %s (rc=%s)\n' "$1" "$_t65_e_rc"
    else
      _t65_p4_bad=$((_t65_p4_bad + 1))
      printf '    NG: %s 期待 rc=%s / %s, got rc=%s\n' "$1" "$2" "$3" "$_t65_e_rc" >&2
    fi
  }

  rm -f "$_t65_plan" "$_t65_c3"
  _t65_expect "plan.md 不在 → SKIP" 0 'plan.md not found'

  printf 'PLAN BODY #1089\n' > "$_t65_plan"
  _t65_expect "c3.json 不在 → SKIP" 0 'c3.json not found'

  printf '{"c3_status":"APPROVED"}\n' > "$_t65_c3"
  _t65_expect "plan_hash 未記録 → SKIP" 0 'plan_hash not found in c3.json'

  if command -v sha256sum >/dev/null 2>&1; then
    _t65_h=$(sha256sum "$_t65_plan" | awk '{print $1}')
  else
    _t65_h=$(shasum -a 256 "$_t65_plan" | awk '{print $1}')
  fi
  printf '{"c3_status":"APPROVED","plan_hash":"sha256:%s"}\n' "$_t65_h" > "$_t65_c3"
  _t65_expect "plan_hash 一致 → PASS" 0 'plan_hash matches'

  printf '{"c3_status":"APPROVED","plan_hash":"sha256:deadbeef"}\n' > "$_t65_c3"
  _t65_expect "mismatch (default) → WARNING" 0 'plan_hash mismatch'

  _t65_rc=0
  _t65_out=$(_t65_hook "$_T65_TASK" "$_t65_nonho" 1) || _t65_rc=$?
  if [ "$_t65_rc" = "1" ] && printf '%s' "$_t65_out" | grep -q 'BLOCK'; then
    printf '    ok: mismatch (STRICT) → rc=1 BLOCK\n'
  else
    _t65_p4_bad=$((_t65_p4_bad + 1))
    printf '    NG: mismatch STRICT 期待 rc=1 / BLOCK, got rc=%s\n' "$_t65_rc" >&2
  fi

  if [ "$_t65_p4_bad" = "0" ]; then
    t65_pass "TC-04 (AC-4): 非 HO パスの plan_hash 検証 6 経路すべて不変"
  else
    t65_fail "TC-04 (AC-4): plan_hash 検証経路が退行 (${_t65_p4_bad} 件)"
  fi

  # === TC-05: 優先順 BYPASS > Override は不変 ===
  _t65_rc=0
  _t65_out=$(_t65_hook "$_T65_TASK" "bin/plangate" 0 1) || _t65_rc=$?
  if [ "$_t65_rc" = "0" ] && printf '%s' "$_t65_out" | grep -q 'BYPASS'; then
    t65_pass "TC-05: PLANGATE_BYPASS_HOOK=1 は HO より優先（既存挙動不変）"
  else
    t65_fail "TC-05: BYPASS 優先順が退行 (rc=$_t65_rc)"
  fi

  # === TC-06 (偽陽性の否定表明): HO 近傍の非 HO パスは block されない ===
  # patch は HO block を「no-task のみ」→「全 TASK セッション」へ広げるため、
  # 偽陽性方向（本来触れてよいパスまで塞ぐ）の表明を明示的に持つ。
  # `.claude/skills/` と `scripts/_*.py` は HO 対象**外**（R-003/R-006）。
  # 両 mode で共通に成立する（block されないことの表明）。
  _t65_bad=0
  for _t65_p in \
    ".claude/rules/x.txt" \
    ".claude/skills/x/SKILL.md" \
    "scripts/hooks/x.py" \
    "scripts/_helper.py" \
    "scripts/x.sh" \
    "bin/other" \
    "schemas/x.json" \
    ".github/workflows/x.json" \
    "docs/AGENTS.md" \
    "docs/working/TASK-T65/CLAUDE.md.bak"; do
    # TASK 文脈: block されない（rc≠2 かつ HARDENING_OVERRIDE を出さない）
    _t65_rc=0
    _t65_out=$(_t65_hook "$_T65_TASK" "$_t65_p") || _t65_rc=$?
    if [ "$_t65_rc" = "2" ] || printf '%s' "$_t65_out" | grep -q 'HARDENING_OVERRIDE'; then
      _t65_bad=$((_t65_bad + 1))
      printf '    false positive (task): %s → rc=%s\n' "$_t65_p" "$_t65_rc" >&2
    fi
    # no-task 文脈: rc は経路依存（SKIP_REASON 拒否等で 2 になりうる）が、
    # HO 判定として拾われてはならない
    _t65_rc=0
    _t65_out=$(_t65_hook "" "$_t65_p") || _t65_rc=$?
    if printf '%s' "$_t65_out" | grep -q 'HARDENING_OVERRIDE'; then
      _t65_bad=$((_t65_bad + 1))
      printf '    false positive (no-task): %s → HARDENING_OVERRIDE\n' "$_t65_p" >&2
    fi
  done
  if [ "$_t65_bad" = "0" ]; then
    t65_pass "TC-06: HO 近傍の非 HO パス 10 件が両文脈で HO block されない（偽陽性なし）"
  else
    t65_fail "TC-06: 非 HO パスが HO 扱いされている (${_t65_bad} 件)"
  fi

  # === TC-07 (INFO-2 / KNOWN-GAP 固定): 正規化の穴を明示的に固定する ===
  # `..` 解決 / 大小文字 / 末尾空白の正規化は **patch 適用後も未実装**。
  # 未適用 main の no-task 経路でも同じ rc=0 であり本 PR が作った穴ではないが、
  # 「常時 block」の文言が文字どおりには成立しないことを検査で固定しておく。
  # 将来これらを塞いだ時点で本 TC が RED になり、更新が強制される（意図的）。
  _t65_bad=0
  for _t65_p in "docs/../CLAUDE.md" "CLAUDE.MD" "CLAUDE.md " "bin/../bin/plangate"; do
    _t65_rc=0
    _t65_out=$(_t65_hook "$_T65_TASK" "$_t65_p") || _t65_rc=$?
    if printf '%s' "$_t65_out" | grep -q 'HARDENING_OVERRIDE'; then
      _t65_bad=$((_t65_bad + 1))
      printf '    normalization now covered (更新が必要): %s\n' "$_t65_p" >&2
    fi
  done
  if [ "$_t65_bad" = "0" ]; then
    t65_pass "TC-07 (KNOWN-GAP): .. / 大小文字 / 末尾空白 の正規化は未実装 — 4 ケースを固定（別 PBI 候補）"
  else
    t65_fail "TC-07: 正規化が実装された（${_t65_bad} 件が block）— KNOWN-GAP 記述と ta-65 TC-07 を更新すること"
  fi

  rm -rf "$_T65_TMP" 2>/dev/null || true
fi

pg_extra_contract_finalize
