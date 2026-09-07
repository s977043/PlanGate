# tests/extras/ta-82-sync-allowlist-pin.sh
# PG_EXTRA_CAPABILITY: standalone-capable
# Sourced by tests/run-tests.sh — uses $pass / $fail counters
#
# #1263 R3: `scripts/sync-plugin-plangate.sh` の **ガバナンス面 allowlist を静的に固定**する。
#
# 背景（#1263 / 2026-09-06 の実測コメント）:
#   ガバナンス正本 30 件（`.claude/{rules,commands,agents}`）は Hardening Override
#   （HO）で守られているが、**導入先へ配布されるのは非 HO の `plugin/plangate/` 側**
#   である。既存の drift-check（`.github/workflows/sync-plugin-plangate.yml` が
#   `sh scripts/sync-plugin-plangate.sh` を走らせて `git diff` を見る形）は
#   「片側編集」「正本のみ編集」「agents の model 行改変」を FAIL 化できるが、
#   **同期スクリプトの allowlist を縮める改変は素通りする**:
#
#     for _dir in agents rules commands; do   →   for _dir in agents rules; do
#
#   この改変後も `plugin/plangate/commands/` の既存ファイルはそのまま残るため
#   `git diff` は空になり、drift-check は緑のままになる。以降 `.claude/commands/*.md`
#   （C-3 承認手順を含む）を編集しても配布側へ反映されず、しかも誰も気付かない。
#   本ファイルはその 1 点（#1263 受入基準 2 = AC-2）を塞ぐ。
#
# AC-2「同期スクリプト自体の改変が検出対象に含まれるか、含めない理由が明記される」に
# 対する本ファイルの立場（**射程の明示**）:
#   - **含める**: 同期対象ディレクトリの allowlist（`for _dir in ...`）と、その
#     ループ本体の `sync_dir` 呼び出し行。ガバナンス 3 面が同期経路から外れる改変は
#     TC-01 / TC-02 が落とす。
#   - **含めない**: スクリプト全体の byte 固定。同スクリプトは skills / ai-loop /
#     ho-paths 等の同期も担い恒常的に成長するため、byte 固定は無関係な PR を落とす
#     時限爆弾になる（`tests/extras/README.md` P-6「絶対件数の契約値にしない」と同趣旨）。
#     allowlist 以外の改変は `ta-26-plugin-sync.sh` の挙動 TC 群と CI drift-check が
#     受け持つ。
#   - **本ファイルでは塞げないもの**（#1263 の残り 2 点 = Human-owned）:
#     (1) workflow の `paths:` 絞り込みにより job 自体が起動しない経路
#         （`tests/fixtures/sync-paths-known-gap-1249.flag` / patch は Human 適用待ち）
#     (2) drift-check が required status check に未登録（ruleset 操作 = Human-owned）
#     いずれも `.github/workflows/**` / ruleset = HO・Human-owned のため本 TC は触れない。
#
# 検出力の実証（README「PASS 判定の書き方」P-7）: TC-03 / TC-04 / TC-07 / TC-08 は
# サンドボックス複製へ変異を注入し、**変異が実際に入ったこと**（`grep -c` / `cmp`）を
# 先に確認してから、検査器が確かに FAIL することを実測する。TC-09 は逆方向の
# 対照（正当な model 正規化差分を誤検出しない）を置く。
#
# 判定の書き方: 検査器は rc と **T82_ 接頭辞の一意 reason トークン**の対を返す
# （P-1 / P-3）。分岐ごとに固有トークンを持たせ、選言だけの述語は使わない（P-2）。
# 母数は floor で見る（P-6）— `.claude/{rules,commands,agents}` は今後も増えるため
# 絶対件数を契約値にしない。
#
# 隔離（README「隔離・後始末の規約」3 / 9）: 実 repo の tracked パスは読むだけで、
# 書き込みは `mktemp -d` 配下のみ。trap は張らない（規約 1・2）。

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
pg_extra_contract_init ta-82-sync-allowlist-pin standalone-capable

if pg_extra_contract_is_standalone; then
  # standalone: 外部 env 汚染を無害化（tests/extras/README.md「隔離・後始末の規約」8 /
  # ta-26 TC-33 が静的検査する集合と一致させる）
  unset PLANGATE_SKIP_REASON PLANGATE_HOOK_TASK PLANGATE_HOOK_FILE \
    PLANGATE_BYPASS_HOOK PLANGATE_HOOK_STRICT PG_HARNESS_SOURCED \
    PLANGATE_ALLOW_MASS_DELETE 2>/dev/null || true
fi

printf '\n=== TA-82: sync-plugin allowlist static pin (#1263 R3) ===\n'

_T82_ROOT="$(CDPATH= cd -- "$_pg_extra_dir/../.." && pwd)"
_T82_SCRIPT="$_T82_ROOT/scripts/sync-plugin-plangate.sh"
_T82_CLAUDE="$_T82_ROOT/.claude"
_T82_PLUGIN="$_T82_ROOT/plugin/plangate"
# ガバナンス 3 面（#1263 の実測表と同じ集合）。ここは「下限」であり、同期対象が
# 増えること自体は妨げない（TC-01 は包含で判定する）。
_T82_REQUIRED_DIRS='agents rules commands'
# ループ本体の呼び出し行（構造で見る / P-5）
_T82_CALLSITE='  sync_dir "$CLAUDE_DIR/$_dir" "$PLUGIN_DIR/$_dir" "$_dir"'

t82_pass() { pass=$((pass + 1)); printf '  [PASS] %s\n' "$1"; }
t82_fail() { fail=$((fail + 1)); printf '  [FAIL] %s\n' "$1" >&2; }

if [ ! -f "$_T82_SCRIPT" ] || [ ! -d "$_T82_CLAUDE" ] || [ ! -d "$_T82_PLUGIN" ]; then
  pg_extra_contract_skip "prerequisite absent: scripts/sync-plugin-plangate.sh / .claude / plugin/plangate"
  return 0 2>/dev/null || exit 3
fi

_T82_TMP="$(mktemp -d "${TMPDIR:-/tmp}/pg-ta82.XXXXXX")"
register_cleanup "$_T82_TMP"

# ── 検査器 1: 同期対象 allowlist ────────────────────────────────────
# $1 = 検査対象スクリプト。stdout に一意 reason トークン、rc 0 = 充足。
_t82_loop_check() {
  _t82_lc_f="$1"
  _t82_lc_n=$(grep -c '^for _dir in [a-z ]*; do$' "$_t82_lc_f" 2>/dev/null || true)
  [ -n "$_t82_lc_n" ] || _t82_lc_n=0
  if [ "$_t82_lc_n" != "1" ]; then
    printf 'T82_LOOP_COUNT:%s\n' "$_t82_lc_n"
    return 1
  fi
  _t82_lc_toks=$(sed -n 's/^for _dir in \([a-z ]*\); do$/\1/p' "$_t82_lc_f")
  for _t82_lc_req in $_T82_REQUIRED_DIRS; do
    _t82_lc_hit=0
    for _t82_lc_t in $_t82_lc_toks; do
      if [ "$_t82_lc_t" = "$_t82_lc_req" ]; then
        _t82_lc_hit=1
      fi
    done
    if [ "$_t82_lc_hit" = "0" ]; then
      printf 'T82_DIR_MISSING:%s\n' "$_t82_lc_req"
      return 1
    fi
  done
  printf 'T82_LOOP_OK:%s\n' "$_t82_lc_toks"
  return 0
}

# ── 検査器 2: ループ本体の呼び出し行（allowlist を保ったまま無効化する経路）──
_t82_callsite_check() {
  _t82_cs_f="$1"
  _t82_cs_next=$(awk '/^for _dir in [a-z ]*; do$/{ if ((getline nxt) > 0) print nxt; exit }' "$_t82_cs_f")
  if [ -z "$_t82_cs_next" ]; then
    printf 'T82_CALLSITE_ABSENT\n'
    return 1
  fi
  if [ "$_t82_cs_next" != "$_T82_CALLSITE" ]; then
    printf 'T82_CALLSITE_CHANGED:%s\n' "$_t82_cs_next"
    return 1
  fi
  printf 'T82_CALLSITE_OK\n'
  return 0
}

# ── 検査器 3: 正本 ↔ 配布ミラーの同値照合（byte 一致 / agents は model 正規化）──
# $1 = 正本ルート（.claude 相当）/ $2 = 配布ルート（plugin/plangate 相当）
# 絶対件数は書かない。母数は floor（`-ge`）で見る（P-6）。
_t82_parity_check() {
  _t82_pc_src_root="$1"
  _t82_pc_dst_root="$2"
  _t82_pc_total=0
  _t82_pc_viol=''
  for _t82_pc_d in $_T82_REQUIRED_DIRS; do
    _t82_pc_n=0
    for _t82_pc_f in "$_t82_pc_src_root/$_t82_pc_d"/*.md; do
      [ -f "$_t82_pc_f" ] || continue
      _t82_pc_n=$((_t82_pc_n + 1))
      _t82_pc_total=$((_t82_pc_total + 1))
      _t82_pc_b="$(basename "$_t82_pc_f")"
      _t82_pc_dst="$_t82_pc_dst_root/$_t82_pc_d/$_t82_pc_b"
      if [ ! -f "$_t82_pc_dst" ]; then
        _t82_pc_viol="$_t82_pc_viol $_t82_pc_d/$_t82_pc_b(missing)"
        continue
      fi
      if [ "$_t82_pc_d" = "agents" ]; then
        # 配布時の model frontmatter 正規化（sync-plugin-plangate.sh の
        # _normalize_model と同一規則）を適用したうえで byte 比較する。
        sed '1,/^---$/{s/^model: .*/model: inherit/;}' "$_t82_pc_f" > "$_T82_TMP/norm.md"
        cmp -s "$_T82_TMP/norm.md" "$_t82_pc_dst" \
          || _t82_pc_viol="$_t82_pc_viol $_t82_pc_d/$_t82_pc_b(diff)"
      else
        cmp -s "$_t82_pc_f" "$_t82_pc_dst" \
          || _t82_pc_viol="$_t82_pc_viol $_t82_pc_d/$_t82_pc_b(diff)"
      fi
    done
    if [ "$_t82_pc_n" -lt 1 ]; then
      _t82_pc_viol="$_t82_pc_viol $_t82_pc_d(empty)"
    fi
  done
  if [ "$_t82_pc_total" -lt 3 ]; then
    printf 'T82_PARITY_FLOOR:%s\n' "$_t82_pc_total"
    return 1
  fi
  if [ -n "$_t82_pc_viol" ]; then
    printf 'T82_PARITY_DIFF:%s\n' "$_t82_pc_viol"
    return 1
  fi
  printf 'T82_PARITY_OK:%s\n' "$_t82_pc_total"
  return 0
}

# ── TC-01: 実スクリプトの allowlist がガバナンス 3 面を包含する ───────
_t82_rc=0
_t82_out=$(_t82_loop_check "$_T82_SCRIPT") || _t82_rc=$?
if [ "$_t82_rc" = "0" ] && printf '%s' "$_t82_out" | grep -q '^T82_LOOP_OK:'; then
  t82_pass "TC-01 sync-plugin-plangate.sh の同期ループが agents/rules/commands を包含 ($_t82_out)"
else
  t82_fail "TC-01 同期 allowlist がガバナンス 3 面を包含しない (rc=$_t82_rc / $_t82_out)"
fi

# ── TC-02: ループ本体が両側パスを loop 変数から導出して sync_dir を呼ぶ ──
_t82_rc=0
_t82_out=$(_t82_callsite_check "$_T82_SCRIPT") || _t82_rc=$?
if [ "$_t82_rc" = "0" ] && [ "$_t82_out" = "T82_CALLSITE_OK" ]; then
  t82_pass "TC-02 ループ本体の sync_dir 呼び出し行が正典形と一致"
else
  t82_fail "TC-02 sync_dir 呼び出し行が変化している (rc=$_t82_rc / $_t82_out)"
fi

# ── TC-03: 変異注入 M1（allowlist から commands を落とす）→ TC-01 が FAIL ──
_t82_m1="$_T82_TMP/m1.sh"
sed 's/^for _dir in agents rules commands; do$/for _dir in agents rules; do/' "$_T82_SCRIPT" > "$_t82_m1"
_t82_m1_applied=$(grep -c '^for _dir in agents rules; do$' "$_t82_m1" 2>/dev/null || true)
_t82_rc=0
_t82_out=$(_t82_loop_check "$_t82_m1") || _t82_rc=$?
if [ "$_t82_m1_applied" != "1" ]; then
  t82_fail "TC-03 変異 M1 が空振りした（複製へ適用されていない: hits=$_t82_m1_applied）"
elif [ "$_t82_rc" != "0" ] && [ "$_t82_out" = "T82_DIR_MISSING:commands" ]; then
  t82_pass "TC-03 変異 M1（commands を allowlist から除去）で TC-01 検査器が FAIL (rc=$_t82_rc / $_t82_out)"
else
  t82_fail "TC-03 変異 M1 を入れたのに検査器が通った＝TC-01 は空振り (rc=$_t82_rc / $_t82_out)"
fi

# ── TC-04: 変異注入 M2（sync_dir 呼び出しを無効化）→ TC-02 が FAIL ────
_t82_m2="$_T82_TMP/m2.sh"
sed 's|^  sync_dir "\$CLAUDE_DIR/\$_dir" "\$PLUGIN_DIR/\$_dir" "\$_dir"$|  : # disabled|' "$_T82_SCRIPT" > "$_t82_m2"
_t82_m2_applied=$(grep -c '^  : # disabled$' "$_t82_m2" 2>/dev/null || true)
_t82_rc=0
_t82_out=$(_t82_callsite_check "$_t82_m2") || _t82_rc=$?
if [ "$_t82_m2_applied" != "1" ]; then
  t82_fail "TC-04 変異 M2 が空振りした（複製へ適用されていない: hits=$_t82_m2_applied）"
elif [ "$_t82_rc" != "0" ] && printf '%s' "$_t82_out" | grep -q '^T82_CALLSITE_CHANGED:'; then
  t82_pass "TC-04 変異 M2（sync_dir 呼び出しの無効化）で TC-02 検査器が FAIL (rc=$_t82_rc / $_t82_out)"
else
  t82_fail "TC-04 変異 M2 を入れたのに検査器が通った＝TC-02 は空振り (rc=$_t82_rc / $_t82_out)"
fi

# ── TC-05: 変異注入 M3（ループごと削除）→ allowlist 検査器が FAIL ────
_t82_m3="$_T82_TMP/m3.sh"
sed 's/^for _dir in agents rules commands; do$/for _other in agents rules commands; do/' "$_T82_SCRIPT" > "$_t82_m3"
_t82_m3_applied=$(grep -c '^for _other in agents rules commands; do$' "$_t82_m3" 2>/dev/null || true)
_t82_rc=0
_t82_out=$(_t82_loop_check "$_t82_m3") || _t82_rc=$?
if [ "$_t82_m3_applied" != "1" ]; then
  t82_fail "TC-05 変異 M3 が空振りした（複製へ適用されていない: hits=$_t82_m3_applied）"
elif [ "$_t82_rc" != "0" ] && [ "$_t82_out" = "T82_LOOP_COUNT:0" ]; then
  t82_pass "TC-05 変異 M3（同期ループの消失）で検査器が FAIL (rc=$_t82_rc / $_t82_out)"
else
  t82_fail "TC-05 変異 M3 を入れたのに検査器が通った (rc=$_t82_rc / $_t82_out)"
fi

# ── TC-06: 実 repo の正本 ↔ 配布ミラーが同値（agents は model 正規化許容）──
_t82_rc=0
_t82_out=$(_t82_parity_check "$_T82_CLAUDE" "$_T82_PLUGIN") || _t82_rc=$?
if [ "$_t82_rc" = "0" ] && printf '%s' "$_t82_out" | grep -q '^T82_PARITY_OK:'; then
  t82_pass "TC-06 .claude/{agents,rules,commands}/*.md と plugin ミラーが同値 ($_t82_out)"
else
  t82_fail "TC-06 正本と配布ミラーが乖離 (rc=$_t82_rc / $_t82_out)"
fi

# ── サンドボックス複製（TC-07〜TC-09 の変異注入用）────────────────
_t82_sbx="$_T82_TMP/sbx"
mkdir -p "$_t82_sbx/src" "$_t82_sbx/dst"
for _t82_d in $_T82_REQUIRED_DIRS; do
  mkdir -p "$_t82_sbx/src/$_t82_d" "$_t82_sbx/dst/$_t82_d"
  cp "$_T82_CLAUDE/$_t82_d"/*.md "$_t82_sbx/src/$_t82_d/" 2>/dev/null || true
  cp "$_T82_PLUGIN/$_t82_d"/*.md "$_t82_sbx/dst/$_t82_d/" 2>/dev/null || true
done
# 複製自体が同値であることを先に確認する（以降の変異が「効いた」と言うための基準）
_t82_rc=0
_t82_base_out=$(_t82_parity_check "$_t82_sbx/src" "$_t82_sbx/dst") || _t82_rc=$?
if [ "$_t82_rc" != "0" ]; then
  t82_fail "TC-07..09 前提: サンドボックス複製が同値でない (rc=$_t82_rc / $_t82_base_out)"
fi

# ── TC-07: 1 バイト変異（rules 側ミラー）→ 同値照合が FAIL ─────────
_t82_victim="$_t82_sbx/dst/rules/mode-classification.md"
if [ -f "$_t82_victim" ]; then
  cp "$_t82_victim" "$_T82_TMP/rules-orig.md"
  printf 'X' >> "$_t82_victim"
  _t82_mut_ok=0
  cmp -s "$_T82_TMP/rules-orig.md" "$_t82_victim" || _t82_mut_ok=1
  _t82_rc=0
  _t82_out=$(_t82_parity_check "$_t82_sbx/src" "$_t82_sbx/dst") || _t82_rc=$?
  if [ "$_t82_mut_ok" != "1" ]; then
    t82_fail "TC-07 変異が空振り（1 バイト追記が反映されていない）"
  elif [ "$_t82_rc" != "0" ] && printf '%s' "$_t82_out" | grep -q 'rules/mode-classification.md(diff)'; then
    t82_pass "TC-07 配布ミラーの 1 バイト変異を同値照合が検出 (rc=$_t82_rc / $_t82_out)"
  else
    t82_fail "TC-07 1 バイト変異を入れたのに同値照合が通った＝TC-06 は空振り (rc=$_t82_rc / $_t82_out)"
  fi
  cp "$_T82_TMP/rules-orig.md" "$_t82_victim"
else
  t82_fail "TC-07 前提: サンドボックスに rules/mode-classification.md が無い"
fi

# ── TC-08: agents 本文の 1 バイト変異 → model 正規化の許容が本文差分を素通りしない ──
_t82_victim="$_t82_sbx/dst/agents/qa-reviewer.md"
if [ -f "$_t82_victim" ]; then
  cp "$_t82_victim" "$_T82_TMP/agents-orig.md"
  printf 'X' >> "$_t82_victim"
  _t82_mut_ok=0
  cmp -s "$_T82_TMP/agents-orig.md" "$_t82_victim" || _t82_mut_ok=1
  _t82_rc=0
  _t82_out=$(_t82_parity_check "$_t82_sbx/src" "$_t82_sbx/dst") || _t82_rc=$?
  if [ "$_t82_mut_ok" != "1" ]; then
    t82_fail "TC-08 変異が空振り（1 バイト追記が反映されていない）"
  elif [ "$_t82_rc" != "0" ] && printf '%s' "$_t82_out" | grep -q 'agents/qa-reviewer.md(diff)'; then
    t82_pass "TC-08 agents 本文の 1 バイト変異を検出（model 正規化の許容が広すぎない） (rc=$_t82_rc / $_t82_out)"
  else
    t82_fail "TC-08 agents 本文の 1 バイト変異を素通りした (rc=$_t82_rc / $_t82_out)"
  fi
  cp "$_T82_TMP/agents-orig.md" "$_t82_victim"
else
  t82_fail "TC-08 前提: サンドボックスに agents/qa-reviewer.md が無い"
fi

# ── TC-09: 対照 — 正当な model frontmatter 差分は誤検出しない（#1263 受入基準 4）──
# 正本側 agents の model: 行を別 tier へ書き換えても、配布側は inherit のままで
# 同値と判定されること（実 repo の「差異のある 6 件」がこの形）。
_t82_srcv="$_t82_sbx/src/agents/qa-reviewer.md"
if [ -f "$_t82_srcv" ]; then
  cp "$_t82_srcv" "$_T82_TMP/agents-src-orig.md"
  sed '1,/^---$/{s/^model: .*/model: opus/;}' "$_T82_TMP/agents-src-orig.md" > "$_t82_srcv"
  _t82_mut_ok=0
  cmp -s "$_T82_TMP/agents-src-orig.md" "$_t82_srcv" || _t82_mut_ok=1
  _t82_rc=0
  _t82_out=$(_t82_parity_check "$_t82_sbx/src" "$_t82_sbx/dst") || _t82_rc=$?
  if [ "$_t82_mut_ok" != "1" ]; then
    printf '  [SKIP] TC-09: 対象 agents に model frontmatter 行が無く対照を作れない\n'
  elif [ "$_t82_rc" = "0" ] && printf '%s' "$_t82_out" | grep -q '^T82_PARITY_OK:'; then
    t82_pass "TC-09 正当な model 正規化差分は誤検出しない (rc=$_t82_rc / $_t82_out)"
  else
    t82_fail "TC-09 model 行の tier 差分を誤検出した (rc=$_t82_rc / $_t82_out)"
  fi
  cp "$_T82_TMP/agents-src-orig.md" "$_t82_srcv"
else
  t82_fail "TC-09 前提: サンドボックスに src/agents/qa-reviewer.md が無い"
fi

# ── 後片付け（trap は使わない / README 規約 1・2）─────────────────
rm -rf "$_T82_TMP"
if [ -e "$_T82_TMP" ]; then
  t82_fail "TC-10 sandbox cleanup failed: $_T82_TMP"
else
  t82_pass "TC-10 sandbox removed (mktemp 配下のみ・実 repo は不変)"
fi

pg_extra_contract_finalize
