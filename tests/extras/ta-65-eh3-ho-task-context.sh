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
#
# 【#1101 / TASK-1101 で追加】パス表記の揺れによる HO 迂回の是正
#   - TC-07  : real hook に patch が適用済みかを測る（既定 fixed / 未適用は
#              tests/fixtures/eh3-normalization-pending-1101.flag で明示 opt-in）
#   - TC-00c : apply スクリプトの `--emit`（書き込みなし）で **patch 済み hook の
#              sandbox 複製**を作る。Human 適用を待たずに patch 内容を実測する
#   - TC-08  : 直積（HO 全パターン × 変換 7 種 + 2 種複合）が rc=2（AC-1）
#   - TC-09  : fail-closed 2 条件（先頭 `..` 残り / セグメント上限）（AC-8）
#   - TC-09b : **絶対パスは block しない**ことの表明（偽陽性の回帰検出 / TC-11b）
#   - TC-10  : `_norm_target` 下流 consumer が不変（AC-2）
#   - TC-11  : 監査ログと reason が**生の要求パス**を保持（AC-9）
#   - TC-12  : 正規化関数が正本 tests/fixtures/pg-fold-path.sh と byte 一致

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

# 任意の hook 複製を対象にする版（#1101: patch 済み複製と未適用複製を
# 同一 harness で測るため）。$1 = hook path / 以降は _t65_hook と同じ。
_t65_hook_at() {
  _t65_h=$1
  PLANGATE_HOOK_TASK="$2" PLANGATE_HOOK_FILE="$3" \
  PLANGATE_HOOK_STRICT="${4:-0}" PLANGATE_BYPASS_HOOK="${5:-0}" \
    sh "$_t65_h" </dev/null 2>&1
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

  # ── #1101: patch 済み hook の sandbox 複製 ────────────────────────
  # `scripts/hooks/check-plan-hash.sh` は Hardening Override 対象パスであり
  # 適用は Human-owned。**Human 適用を待たずに** patch 後の挙動を測るため、
  # apply スクリプトの `--emit`（書き込みなし・stdout のみ）で patch 済み
  # 内容を生成し、sandbox 複製先に置く。real hook が既に適用済みなら
  # `--emit` はその内容をそのまま返す（適用前後で同じ harness が使える）。
  _T65_APPLY="$_T65_ROOT/scripts/apply-1101-ho-normalization.sh"
  _T65_HOOK_P="$_T65_TMP/scripts/hooks/check-plan-hash.patched.sh"
  _T65_PATCH_OK=0
  if [ -r "$_T65_APPLY" ]; then
    if sh "$_T65_APPLY" --emit >"$_T65_HOOK_P" 2>"$_T65_TMP/emit.err" </dev/null; then
      if [ -s "$_T65_HOOK_P" ] && grep -q '_ho_key=' "$_T65_HOOK_P"; then
        _T65_PATCH_OK=1
      fi
    fi
  fi
  if [ "$_T65_PATCH_OK" = "1" ]; then
    t65_pass "TC-00c (#1101): patch 済み hook の sandbox 複製を生成（--emit / 実ファイルは未変更）"
  else
    t65_fail "TC-00c (#1101): patch 済み複製の生成に失敗 — $(cat "$_T65_TMP/emit.err" 2>/dev/null | head -3)"
  fi

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
  # #1101 で拡充: 既存 10 件は**正規化しても値が変わらない**ため、正規化強化に
  # よる偽陽性を検出できない（測定装置として不十分）。**変換を施した非 HO
  # ケース 5 件**を追加し、patch 済み複製に対しても同じ表明を行う。
  #   ⚠ `docs/x/../AGENTS.md` → 畳み込みで `docs/AGENTS.md`（**非 HO・正しい**）。
  #     一方 `x/../AGENTS.md` → `AGENTS.md`（**HO へ変化・仕様どおり**）。
  _t65_bad=0
  _t65_n06=0
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
    "docs/working/TASK-T65/CLAUDE.md.bak" \
    "docs/x/../AGENTS.md" \
    "scripts/hooks/../hooks/x.py" \
    "bin/../bin/other" \
    "docs/working/TASK-T65/../TASK-T65/CLAUDE.md.bak" \
    ".claude//skills/x/SKILL.md"; do
    _t65_n06=$((_t65_n06 + 1))
    # 未適用複製 / patch 済み複製の両方で表明する
    for _t65_h in "$_T65_HOOK" "$_T65_HOOK_P"; do
      [ -s "$_t65_h" ] || continue
      # TASK 文脈: block されない（rc≠2 かつ HARDENING_OVERRIDE を出さない）
      _t65_rc=0
      _t65_out=$(_t65_hook_at "$_t65_h" "$_T65_TASK" "$_t65_p") || _t65_rc=$?
      if [ "$_t65_rc" = "2" ] || printf '%s' "$_t65_out" | grep -q 'HARDENING_OVERRIDE'; then
        _t65_bad=$((_t65_bad + 1))
        printf '    false positive (task/%s): %s → rc=%s\n' "$(basename "$_t65_h")" "$_t65_p" "$_t65_rc" >&2
      fi
      # no-task 文脈: rc は経路依存（SKIP_REASON 拒否等で 2 になりうる）が、
      # HO 判定として拾われてはならない
      _t65_rc=0
      _t65_out=$(_t65_hook_at "$_t65_h" "" "$_t65_p") || _t65_rc=$?
      if printf '%s' "$_t65_out" | grep -q 'HARDENING_OVERRIDE'; then
        _t65_bad=$((_t65_bad + 1))
        printf '    false positive (no-task/%s): %s → HARDENING_OVERRIDE\n' "$(basename "$_t65_h")" "$_t65_p" >&2
      fi
    done
  done
  if [ "$_t65_bad" = "0" ]; then
    t65_pass "TC-06: HO 近傍の非 HO パス ${_t65_n06} 件（変換適用 5 件を含む）が両文脈・両 hook で HO block されない（偽陽性なし）"
  else
    t65_fail "TC-06: 非 HO パスが HO 扱いされている (${_t65_bad} 件)"
  fi

  # === TC-07 (#1101): 表記揺れによる HO 迂回 — 既定 fixed / pending は明示 opt-in ===
  # #1089 の KNOWN-GAP flag と**同じ機構**（既定は fixed、gap の受理は tracked
  # な flag ファイルの存在という明示 opt-in でのみ成立、flag が残ったまま実装が
  # fixed なら stale 宣言として FAIL）。
  #   - real hook は Hardening Override 対象パスであり適用は Human-owned。
  #     適用前は `tests/fixtures/eh3-normalization-pending-1101.flag` が
  #     「まだ適用されていない」ことを**明示的に宣言**する。
  #   - `sh scripts/apply-1101-ho-normalization.sh --apply`（Human）が flag を
  #     自動削除する。以後は fixed 期待となり、退行すれば RED になる。
  #   - patch 内容そのものの検査は TC-08〜TC-12（patch 済み複製）が担う。
  #     本 TC が測るのは「**real hook に適用済みか**」だけである。
  _T65_NFLAG="$_T65_ROOT/tests/fixtures/eh3-normalization-pending-1101.flag"
  _T65_NSTRUCT=pending
  if grep -q '_ho_key=' "$_T65_HOOK_SRC" 2>/dev/null; then
    _T65_NSTRUCT=fixed
  fi
  if [ -n "${PG_T65_NORM_EXPECT:-}" ]; then
    _T65_NMODE="$PG_T65_NORM_EXPECT"
    printf '  [INFO] #1101 期待値を pin: PG_T65_NORM_EXPECT=%s\n' "$_T65_NMODE"
  elif [ -f "$_T65_NFLAG" ]; then
    _T65_NMODE=pending
  else
    _T65_NMODE=fixed
  fi
  if [ -z "${PG_T65_NORM_EXPECT:-}" ] && [ -f "$_T65_NFLAG" ] && [ "$_T65_NSTRUCT" = fixed ]; then
    t65_fail "TC-07b: stale PENDING-APPLY 宣言 — real hook は既に #1101 適用済み (_ho_key あり) なのに tests/fixtures/eh3-normalization-pending-1101.flag が残っている。flag を削除すること（scripts/apply-1101-ho-normalization.sh --apply が自動削除する）"
    _T65_NMODE=fixed
  fi

  # 変換 7 種 + 2 種複合の代表（`ta-65` 単体での可読性のため代表パスで表現）。
  # 網羅的な直積は TC-08 が hook の case 文から導出して実施する。
  _t65_bad=0
  _t65_n07=0
  for _t65_p in \
    "docs/../CLAUDE.md" \
    "CLAUDE.MD" \
    "CLAUDE.md " \
    "bin/../bin/plangate" \
    "bin/./plangate" \
    "bin//plangate" \
    ".//CLAUDE.md" \
    "./bin/../bin/plangate" \
    ".//BIN/plangate"; do
    _t65_n07=$((_t65_n07 + 1))
    _t65_rc=0
    _t65_out=$(_t65_hook "$_T65_TASK" "$_t65_p") || _t65_rc=$?
    _t65_ho=no
    printf '%s' "$_t65_out" | grep -q 'HARDENING_OVERRIDE' && _t65_ho=yes
    if [ "$_T65_NMODE" = fixed ]; then
      if [ "$_t65_rc" != "2" ] || [ "$_t65_ho" != "yes" ]; then
        _t65_bad=$((_t65_bad + 1))
        printf '    bypass still open: %s → rc=%s ho=%s\n' "$_t65_p" "$_t65_rc" "$_t65_ho" >&2
      fi
    else
      if [ "$_t65_ho" = "yes" ]; then
        _t65_bad=$((_t65_bad + 1))
        printf '    normalization now covered (flag の削除が必要): %s\n' "$_t65_p" >&2
      fi
    fi
  done
  if [ "$_t65_bad" = "0" ] && [ "$_T65_NMODE" = fixed ]; then
    t65_pass "TC-07 (#1101): 変換 ${_t65_n07} 形すべてが real hook で rc=2 + HARDENING_OVERRIDE"
  elif [ "$_t65_bad" = "0" ]; then
    printf '  [PENDING-APPLY #1101] tests/fixtures/eh3-normalization-pending-1101.flag により未適用を受理（構造: %s）\n' "$_T65_NSTRUCT"
    t65_pass "TC-07 (#1101 PENDING-APPLY): 変換 ${_t65_n07} 形は real hook では未 block（patch は Human 適用待ち / patch 内容は TC-08〜TC-12 が検査）"
  else
    t65_fail "TC-07 (#1101): 期待 ${_T65_NMODE} に対し ${_t65_bad}/${_t65_n07} 件が不一致"
  fi

  # ================= #1101: patch 済み hook に対する検査 =================
  if [ "$_T65_PATCH_OK" = "1" ]; then

    # === TC-08 (AC-1): 直積 — HO 全パターン × 変換 7 種 + 2 種複合 が rc=2 ===
    # 件数は固定しない（TC-00 と同じく hook の case 文から導出）。
    # `.//` 形を必ず含める（畳み込みを `./` 除去より後ろに置くと素通りする）。
    _t65_bad=0
    _t65_prod=0
    _t65_root_p="$_T65_TMP"   # _T65_HOOK_P の REPO_ROOT
    # **repo root 形にも大小文字変換を当てる**（PR 前レビューで検出した AC-1 未達）。
    # 旧版は repo root 形を常に正しい大小文字で生成しており、「repo root 跨ぎ ×
    # 大小文字」の 2 種複合を一度も評価していなかった。macOS の case-insensitive FS
    # では `/USERS/.../CLAUDE.md` が実体に到達するため、**書き込みが成立する**迂回。
    _t65_root_up=$(printf '%s' "$_t65_root_p" | tr 'a-z' 'A-Z')
    for _t65_p in $_T65_PATTERNS; do
      _t65_up=$(printf '%s' "$_t65_p" | tr 'a-z' 'A-Z')
      case "$_t65_p" in
        */*) _t65_dbl="${_t65_p%%/*}//${_t65_p#*/}"; _t65_dot="${_t65_p%%/*}/./${_t65_p#*/}" ;;
        *)   _t65_dbl=".//$_t65_p"; _t65_dot="././$_t65_p" ;;
      esac
      for _t65_v in \
        "$_t65_p" \
        "./$_t65_p" \
        "$_t65_dbl" \
        ".//$_t65_p" \
        "$_t65_dot" \
        "x/../$_t65_p" \
        "$_t65_root_p/./$_t65_p" \
        "$_t65_up" \
        "$_t65_p " \
        "./x/../$_t65_p" \
        ".//$_t65_up" \
        "$_t65_root_up/$_t65_p" \
        "$_t65_root_up/$_t65_up"; do
        _t65_prod=$((_t65_prod + 1))
        _t65_rc=0
        _t65_out=$(_t65_hook_at "$_T65_HOOK_P" "$_T65_TASK" "$_t65_v") || _t65_rc=$?
        if [ "$_t65_rc" != "2" ] || ! printf '%s' "$_t65_out" | grep -q 'HARDENING_OVERRIDE'; then
          _t65_bad=$((_t65_bad + 1))
          printf '    product miss: [%s] → rc=%s\n' "$_t65_v" "$_t65_rc" >&2
        fi
      done
    done
    if [ "$_t65_bad" = "0" ] && [ "$_t65_prod" -ge 1 ]; then
      t65_pass "TC-08 (AC-1): 直積 ${_t65_prod} 件（${_T65_PATTERN_COUNT} パターン × 変換 13 形）すべて rc=2 + HARDENING_OVERRIDE"
    else
      t65_fail "TC-08 (AC-1): 直積で ${_t65_bad}/${_t65_prod} 件が block されない"
    fi

    # === TC-09 (AC-8): fail-closed 2 条件 + 絶対パスは block しない ===
    _t65_bad=0
    for _t65_p in "../plangate/CLAUDE.md" "../../CLAUDE.md" ".." "a/b/../../../CLAUDE.md"; do
      _t65_rc=0
      _t65_out=$(_t65_hook_at "$_T65_HOOK_P" "$_T65_TASK" "$_t65_p") || _t65_rc=$?
      if [ "$_t65_rc" != "2" ] || ! printf '%s' "$_t65_out" | grep -q 'HARDENING_OVERRIDE'; then
        _t65_bad=$((_t65_bad + 1))
        printf '    fail-closed miss (leading ..): %s → rc=%s\n' "$_t65_p" "$_t65_rc" >&2
      fi
    done
    # セグメント上限（256）超過
    _t65_long=''
    _t65_i=0
    while [ "$_t65_i" -lt 257 ]; do _t65_long="${_t65_long}x/"; _t65_i=$((_t65_i + 1)); done
    _t65_rc=0
    _t65_out=$(_t65_hook_at "$_T65_HOOK_P" "$_T65_TASK" "${_t65_long}CLAUDE.md") || _t65_rc=$?
    if [ "$_t65_rc" != "2" ]; then
      _t65_bad=$((_t65_bad + 1))
      printf '    fail-closed miss (segment limit): rc=%s\n' "$_t65_rc" >&2
    fi
    if [ "$_t65_bad" = "0" ]; then
      t65_pass "TC-09 (AC-8): fail-closed 2 条件（先頭 .. 残り 4 件 / セグメント上限 1 件）すべて rc=2"
    else
      t65_fail "TC-09 (AC-8): fail-closed が成立しない (${_t65_bad} 件)"
    fi

    # === TC-09b (AC-8 の偽陽性防止 / TC-11b): 絶対パスは block しない ===
    # **塞がないことの表明**。AC-8 を「絶対パスも block」に広げる実装が入ったら
    # FAIL する（repo 外＝作業ディレクトリへの書き込みが全部止まるため）。
    _t65_bad=0
    _t65_absdir=$(mktemp -d /tmp/plangate-tc11b.XXXXXX)
    register_cleanup "$_t65_absdir"
    mkdir -p "$_t65_absdir/other-repo"
    : > "$_t65_absdir/note.md"
    : > "$_t65_absdir/foo.txt"
    : > "$_t65_absdir/other-repo/CLAUDE.md"
    for _t65_p in \
      "$_t65_absdir/note.md" \
      "$_t65_absdir/foo.txt" \
      "$_t65_absdir/other-repo/CLAUDE.md" \
      "/CLAUDE.md"; do
      _t65_rc=0
      _t65_out=$(_t65_hook_at "$_T65_HOOK_P" "$_T65_TASK" "$_t65_p") || _t65_rc=$?
      if [ "$_t65_rc" = "2" ] || printf '%s' "$_t65_out" | grep -q 'HARDENING_OVERRIDE'; then
        _t65_bad=$((_t65_bad + 1))
        printf '    absolute path wrongly blocked: %s → rc=%s\n' "$_t65_p" "$_t65_rc" >&2
      fi
    done
    rm -rf "$_t65_absdir" 2>/dev/null || true
    if [ "$_t65_bad" = "0" ]; then
      t65_pass "TC-09b (TC-11b): 絶対パス 4 件は block されない（偽陽性の回帰検出）"
    else
      t65_fail "TC-09b (TC-11b): 絶対パスが block された (${_t65_bad} 件) — repo 外への書き込みが止まる"
    fi

    # === TC-10 (AC-2): _norm_target の下流 consumer が不変 ===
    # patch は HO 判定専用の派生変数 `_ho_key` を足すだけで `_norm_target` を
    # 書き換えない。以下 3 経路は `_norm_target` を**大小文字ごと**共有している。
    _T65_TMP2=$(mktemp -d)
    register_cleanup "$_T65_TMP2"
    mkdir -p "$_T65_TMP2/scripts/hooks" "$_T65_TMP2/docs/working/_audit" \
             "$_T65_TMP2/docs/working/_maintenance" "$_T65_TMP2/docs/working/TASK-1101"
    cp "$_T65_HOOK_P" "$_T65_TMP2/scripts/hooks/check-plan-hash.sh"
    _T65_HOOK2="$_T65_TMP2/scripts/hooks/check-plan-hash.sh"
    _t65_bad=0

    # (a) maintenance allowed_paths（fnmatch.fnmatchcase = 大小文字を区別）
    _t65_now=$(date -u '+%s')
    printf '{"approved_by":"human","reason":"ta-65 TC-10","granted_at":%s,"until":%s,"allowed_paths":["docs/working/TASK-1101/*"],"one_shot":false}\n' \
      "$_t65_now" "$((_t65_now + 900))" > "$_T65_TMP2/docs/working/_maintenance/maintenance.json"
    _t65_rc=0
    _t65_out=$(_t65_hook_at "$_T65_HOOK2" "" "docs/working/TASK-1101/status.md") || _t65_rc=$?
    if [ "$_t65_rc" = "0" ] && printf '%s' "$_t65_out" | grep -q 'MAINTENANCE_SKIP'; then
      printf '    ok: maintenance allowed_paths 一致 (rc=0 MAINTENANCE_SKIP)\n'
    else
      _t65_bad=$((_t65_bad + 1))
      printf '    NG: maintenance allowed_paths 期待 rc=0/MAINTENANCE_SKIP, got rc=%s / %s\n' \
        "$_t65_rc" "$(printf '%s' "$_t65_out" | head -1)" >&2
    fi

    # (c) doc-light の拡張子判定 + reason が _norm_target を原文のまま持つ
    rm -f "$_T65_TMP2/docs/working/_maintenance/maintenance.json"
    _t65_rc=0
    _t65_out=$(_t65_hook_at "$_T65_HOOK2" "" "docs/working/TASK-1101/status.md") || _t65_rc=$?
    if [ "$_t65_rc" = "0" ] && printf '%s' "$_t65_out" | grep -q 'DOC_LIGHT_SKIP' \
       && printf '%s' "$_t65_out" | grep -q 'docs/working/TASK-1101/status.md'; then
      printf '    ok: doc-light 拡張子判定 (rc=0 DOC_LIGHT_SKIP / _norm_target 原文)\n'
    else
      _t65_bad=$((_t65_bad + 1))
      printf '    NG: doc-light 期待 rc=0/DOC_LIGHT_SKIP + 原文パス, got rc=%s / %s\n' \
        "$_t65_rc" "$(printf '%s' "$_t65_out" | head -1)" >&2
    fi

    # (b) C-3 conversation 経路（docs/working/TASK-*/approvals/c3.json）
    if python3 -c 'import yaml' >/dev/null 2>&1; then
      mkdir -p "$_T65_TMP2/docs/working/TASK-T45/approvals"
      printf 'c3_approval:\n  mode: conversation\n' > "$_T65_TMP2/.plangate.yml"
      _t65_rc=0
      _t65_out=$(_t65_hook_at "$_T65_HOOK2" "" "docs/working/TASK-T45/approvals/c3.json") || _t65_rc=$?
      if [ "$_t65_rc" = "0" ] && printf '%s' "$_t65_out" | grep -q 'C3_CONVERSATION_SKIP' \
         && printf '%s' "$_t65_out" | grep -q 'TASK-T45'; then
        printf '    ok: C-3 conversation 経路 (rc=0 C3_CONVERSATION_SKIP / TASK- 大文字保持)\n'
      else
        _t65_bad=$((_t65_bad + 1))
        printf '    NG: C-3 conversation 期待 rc=0/C3_CONVERSATION_SKIP, got rc=%s / %s\n' \
          "$_t65_rc" "$(printf '%s' "$_t65_out" | head -1)" >&2
      fi
    else
      printf '    [INFO] python3 yaml 未導入のため C-3 conversation 経路の検査を省略\n'
    fi

    if [ "$_t65_bad" = "0" ]; then
      t65_pass "TC-10 (AC-2): _norm_target 下流 consumer（maintenance / doc-light / c3 conversation）が不変"
    else
      t65_fail "TC-10 (AC-2): _norm_target の意味論が変わっている (${_t65_bad} 件) — _ho_key ではなく _norm_target を書き換えていないか"
    fi

    # === TC-11 (AC-9): 監査ログと reason が**生の要求パス**を保持 ===
    # 攻撃を塞ぐ変更が「誰が何を編集しようとしたか」の証跡を消してはならない。
    # 対象は `reason` と `_audit/hook-events.log`（HO block 経路は
    # skip-decision-log.jsonl には書かない = 実測）。
    _t65_bad=0
    _t65_raw='bin/../bin/plangate'
    rm -f "$_T65_TMP/docs/working/_audit/hook-events.log"
    _t65_rc=0
    _t65_out=$(_t65_hook_at "$_T65_HOOK_P" "$_T65_TASK" "$_t65_raw") || _t65_rc=$?
    if [ "$_t65_rc" != "2" ]; then
      _t65_bad=$((_t65_bad + 1))
      printf '    NG: 前提の block が成立しない rc=%s\n' "$_t65_rc" >&2
    fi
    if ! printf '%s' "$_t65_out" | grep -qF "$_t65_raw"; then
      _t65_bad=$((_t65_bad + 1))
      printf '    NG: reason に生パスがない: %s\n' "$(printf '%s' "$_t65_out" | head -1)" >&2
    fi
    if ! grep -qF "$_t65_raw" "$_T65_TMP/docs/working/_audit/hook-events.log" 2>/dev/null; then
      _t65_bad=$((_t65_bad + 1))
      printf '    NG: hook-events.log に生パスがない\n' >&2
    fi
    if [ "$_t65_bad" = "0" ]; then
      t65_pass "TC-11 (AC-9): reason と hook-events.log が生パス [${_t65_raw}] を保持"
    else
      t65_fail "TC-11 (AC-9): 監査証跡から原文が失われている (${_t65_bad} 件)"
    fi

    # === TC-12: 正本ソースと patch 済み hook の正規化関数が byte 一致 ===
    # tests/fixtures/pg-fold-path.sh が正本。patch はそこから inline する。
    # 片方だけ直された（= drift）状態を機械検出する。
    _t65_a="$_T65_TMP/fold-lib.txt"
    _t65_b="$_T65_TMP/fold-hook.txt"
    sed -n '/^# >>> PG-FOLD-PATH BEGIN/,/^# <<< PG-FOLD-PATH END/p' \
      "$_T65_ROOT/tests/fixtures/pg-fold-path.sh" > "$_t65_a" 2>/dev/null || true
    sed -n '/^# >>> PG-FOLD-PATH BEGIN/,/^# <<< PG-FOLD-PATH END/p' "$_T65_HOOK_P" > "$_t65_b" 2>/dev/null || true
    if [ -s "$_t65_a" ] && cmp -s "$_t65_a" "$_t65_b"; then
      t65_pass "TC-12: 正規化関数が正本 tests/fixtures/pg-fold-path.sh と byte 一致（drift なし）"
    else
      t65_fail "TC-12: 正規化関数が正本と一致しない — tests/fixtures/pg-fold-path.sh と hook のどちらかだけが変更された"
    fi
  fi

  rm -rf "$_T65_TMP" 2>/dev/null || true
fi

pg_extra_contract_finalize
