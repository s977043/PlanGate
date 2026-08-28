# tests/extras/ta-59-apply-settings-merge.sh
# Sourced by tests/run-tests.sh -- uses $pass / $fail counters
# scripts/apply-claude-settings.sh: settings.example.json hooks の冪等 merge
# （#928 AC-1 前提 / #914 の doctor --check-settings ブロッカー解消）
#
# 背景: 旧実装の merge は「EH-3 引数付与」「EH-9 ブロック取り込み」の 2 分岐
# ハードコードだった。settings.json に check-plan-hash.sh ブロック自体が無く
# EH-9 が既にある実環境では両分岐とも no-op となり、何回実行しても
# `doctor --check-settings` が FAIL（不足 5 件）のままだった。
#
# 隔離（tests/extras/README.md §隔離・後始末の規約）:
#   `.claude/settings*.json` は self-mod ガード対象（HO）のため **一切書かない**。
#   mktemp サンドボックスに scripts/ と .claude/ を複製し、対象スクリプトの
#   ROOT 解決（scripts/ → ..）がサンドボックスを指す性質を使って検証する。
#   trap は張らず register_cleanup + 末尾 rm -rf の二重で回収する。

printf '\n=== TA-59: apply-claude-settings.sh idempotent hooks merge (#928) ===\n'

# 単体実行 fallback（#877 F3 / README 規約）: PG_HARNESS_SOURCED と FIXTURES_DIR
# の AND で判別し、片方でも欠ければ standalone（安全側）へ倒す。
if [ "${PG_HARNESS_SOURCED:-0}" != "1" ] || [ -z "${FIXTURES_DIR:-}" ]; then
  _T59_STANDALONE=1
  # 呼び出し元 env の漏れで hook 挙動が変わるのを防ぐ（run-tests.sh L20 と対称）。
  # 1 行に収めるのは可読性のための慣行。行継続（末尾 `\`）で折っても ta-26 TC-33 の
  # 静的検査は awk で継続行を結合してから走査するため検出できる（PR #986 で是正）
  unset PLANGATE_SKIP_REASON PLANGATE_HOOK_TASK PLANGATE_HOOK_FILE PLANGATE_BYPASS_HOOK PLANGATE_HOOK_STRICT PG_HARNESS_SOURCED PLANGATE_ALLOW_MASS_DELETE 2>/dev/null || true
  FIXTURES_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/../fixtures" && pwd)"
  pass=0
  fail=0
  _T59_CLEANUP_PATHS=""
  register_cleanup() {
    for _pg_cp in "$@"; do
      if [ -n "$_pg_cp" ]; then
        _T59_CLEANUP_PATHS="${_T59_CLEANUP_PATHS}${_pg_cp}
"
      fi
    done
  }
else
  _T59_STANDALONE=0
fi

_T59_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
_T59_APPLY="$_T59_ROOT/scripts/apply-claude-settings.sh"
_T59_WIRING="$_T59_ROOT/scripts/check-settings-wiring.sh"
_T59_EXAMPLE="$_T59_ROOT/.claude/settings.example.json"

t59_pass() { pass=$((pass + 1)); printf '  [PASS] %s\n' "$1"; }
t59_fail() { fail=$((fail + 1)); printf '  [FAIL] %s\n' "$1" >&2; }

# サンドボックス生成: <tmp>/scripts/{apply,wiring} + <tmp>/.claude/settings*.json
# $1 = settings.json の中身（空文字なら settings.json を作らない）
_t59_mksbx() {
  _t59_sbx=$(mktemp -d)
  register_cleanup "$_t59_sbx"
  mkdir -p "$_t59_sbx/scripts" "$_t59_sbx/.claude"
  cp "$_T59_APPLY" "$_t59_sbx/scripts/apply-claude-settings.sh"
  cp "$_T59_WIRING" "$_t59_sbx/scripts/check-settings-wiring.sh"
  cp "$_T59_EXAMPLE" "$_t59_sbx/.claude/settings.example.json"
  if [ -n "$1" ]; then
    printf '%s\n' "$1" > "$_t59_sbx/.claude/settings.json"
  fi
}

# ── EH-3（check-plan-hash.sh）レーン検査ヘルパ（#1104）──────────────────
# #1104 で EH-3 は `Edit|Write` と `Bash` の **2 レーン**に配線された。
# 「出現回数」で判定すると example のレーンが増減するたびに無関係な TC が
# 落ちる（成長しうる対象への絶対件数 assert は時限爆弾）。そこで
# **期待レーン集合を settings.example.json から実行時に導出**し、
# 「example の各レーンにつき正規表記の EH-3 がちょうど 1 本・引数欠落 0」という
# 構造で判定する。
# 正規化規則は apply-claude-settings.sh の `_script_paths()` と同一
# （二重引用符と `${}` の brace は剥がす / 単一引用符と変数名は保持する）。
# ここを緩めると apply 側の誤同一視（TC-14 / TC-21 の検出対象）を見逃す。
#
# 出力（1 行 1 項目）:
#   LANE <matcher> <正規表記の本数> <引数欠落の本数>
#   FOREIGN <正規表記でない EH-3 の本数>   ← 別変数名 / 単一引用符の残存
_t59_ph_report() {  # $1 = 適用後 settings.json  $2 = settings.example.json
  python3 - "$1" "$2" <<'PY59H'
import json, re, sys
_BRACED = re.compile(r"\$\{([A-Za-z_][A-Za-z0-9_]*)\}")
_SCRIPT = re.compile(r"\S+\.(?:sh|py)\b")
CANON = "$CLAUDE_PROJECT_DIR/scripts/hooks/check-plan-hash.sh"


def _norm(tok):
    tok = tok.strip('"')
    tok = _BRACED.sub(r"$\1", tok)
    while tok.startswith("./"):
        tok = tok[2:]
    return tok


def _is_canon(cmd):
    return CANON in [_norm(t) for t in _SCRIPT.findall(cmd or "")]


def _tokens(m):
    m = (m or "").strip()
    if m in ("", "*"):
        return "ALL"
    parts = [p.strip() for p in m.split("|")]
    if parts and all(re.fullmatch(r"[A-Za-z0-9_]+", p) for p in parts):
        return frozenset(parts)
    return None


def _covers(existing, wanted):
    if existing == wanted:
        return True
    et, wt = _tokens(existing), _tokens(wanted)
    if et == "ALL":
        return True
    if et is None or wt is None or wt == "ALL":
        return False
    return wt <= et


def _eh3(doc):
    out = []
    for blk in (doc.get("hooks", {}) or {}).get("PreToolUse", []) or []:
        if not isinstance(blk, dict):
            continue
        for h in blk.get("hooks", []) or []:
            cmd = (h or {}).get("command", "") or ""
            if "check-plan-hash.sh" in cmd:
                out.append((blk.get("matcher") or "", cmd))
    return out


sj = _eh3(json.load(open(sys.argv[1])))
want = sorted({m for m, c in _eh3(json.load(open(sys.argv[2]))) if _is_canon(c)})
for m in want:
    hits = [c for gm, c in sj if _is_canon(c) and _covers(gm, m)]
    bad = sum(1 for c in hits if "${PLANGATE_HOOK_TASK:-}" not in c
              or "${PLANGATE_HOOK_FILE:-}" not in c)
    print("LANE %s %d %d" % (m or "*", len(hits), bad))
print("FOREIGN %d" % sum(1 for m, c in sj if not _is_canon(c)))
PY59H
}

# example の全レーンが「正規表記 1 本・引数欠落 0」なら rc=0
_t59_ph_lanes_ok() {  # $1 = サンドボックス root
  _t59_ph_report "$1/.claude/settings.json" "$1/.claude/settings.example.json" \
    | awk '/^LANE /{ if ($3 != 1 || $4 != 0) bad = 1 } END { exit bad ? 1 : 0 }'
}

# 正規表記でない EH-3（別変数名 / 単一引用符）の残存数を出力
_t59_ph_foreign() {  # $1 = サンドボックス root
  _t59_ph_report "$1/.claude/settings.json" "$1/.claude/settings.example.json" \
    | awk '/^FOREIGN /{ print $2 }'
}

# FAIL 時に貼る診断（レーン別内訳を 1 行に）
_t59_ph_diag() {  # $1 = サンドボックス root
  _t59_ph_report "$1/.claude/settings.json" "$1/.claude/settings.example.json" \
    | tr '\n' ' '
}

# 契約 hook がほぼ未配線の settings.json（PreToolUse は EH-9 の 1 本だけ）
_T59_MINIMAL='{
  "hooks": {
    "PreToolUse": [
      { "matcher": "Bash", "hooks": [ { "type": "command",
        "command": "sh ${CLAUDE_PROJECT_DIR}/scripts/hooks/check-delegation-commit-boundary.sh" } ] }
    ]
  }
}'

# ローカル固有 hook + 引数なし EH-3 を含む settings.json
_T59_LOCAL='{
  "hooks": {
    "PreToolUse": [
      { "_comment_": "LOCAL ONLY", "matcher": "Edit|Write", "hooks": [ { "type": "command",
        "command": "sh ${CLAUDE_PROJECT_DIR}/scripts/hooks/local-only-example.sh" } ] },
      { "matcher": "Edit|Write", "hooks": [ { "type": "command",
        "command": "sh ${CLAUDE_PROJECT_DIR}/scripts/hooks/check-plan-hash.sh ${PLANGATE_HOOK_TASK:-}" } ] }
    ],
    "Stop": [
      { "_comment_": "LOCAL ONLY Stop", "hooks": [ { "type": "command",
        "command": "sh ${CLAUDE_PROJECT_DIR}/scripts/hooks/local-only-stop.sh" } ] }
    ]
  }
}'

if [ ! -f "$_T59_APPLY" ] || [ ! -f "$_T59_WIRING" ] || [ ! -f "$_T59_EXAMPLE" ]; then
  t59_fail "TA-59 前提ファイル不在（apply / wiring / settings.example.json）"
else

# === TC-01: 不足 hook を取り込み wiring 契約を満たす（V-1）===
_t59_mksbx "$_T59_MINIMAL"
_t59_sbx1="$_t59_sbx"
_t59_rc=0
_t59_out=$(sh "$_t59_sbx1/scripts/apply-claude-settings.sh" 2>&1) || _t59_rc=$?
_t59_wrc=0
sh "$_t59_sbx1/scripts/check-settings-wiring.sh" --target user >/dev/null 2>&1 || _t59_wrc=$?
if [ "$_t59_rc" -eq 0 ] && [ "$_t59_wrc" -eq 0 ]; then
  t59_pass "TC-01 EH-9 のみの settings.json を merge → wiring 契約 PASS (apply rc=0)"
else
  t59_fail "TC-01 merge 後も契約未充足 (apply rc=$_t59_rc / wiring rc=$_t59_wrc): $_t59_out"
fi

# === TC-02: 契約トークンが全件そろう（不足 5 件の解消を個別に確認）===
_t59_missing=""
for _t59_tok in check-plan-exists.sh check-c3-approval.sh check-forbidden-files.sh \
                check-plan-hash.sh '${PLANGATE_HOOK_FILE:-}'; do
  grep -qF "$_t59_tok" "$_t59_sbx1/.claude/settings.json" || _t59_missing="$_t59_missing $_t59_tok"
done
if [ -z "$_t59_missing" ]; then
  t59_pass "TC-02 EH-1 / EH-2 / EH-6 / EH-3 + PLANGATE_HOOK_FILE 引数がすべて配線される"
else
  t59_fail "TC-02 merge 後も不足:$_t59_missing"
fi

# === TC-03: 冪等（2 回目は変更なし・バイト一致）===
cp "$_t59_sbx1/.claude/settings.json" "$_t59_sbx1/after1.json"
_t59_rc=0
_t59_out=$(sh "$_t59_sbx1/scripts/apply-claude-settings.sh" 2>&1) || _t59_rc=$?
if [ "$_t59_rc" -eq 0 ] \
  && cmp -s "$_t59_sbx1/after1.json" "$_t59_sbx1/.claude/settings.json" \
  && printf '%s' "$_t59_out" | grep -q '変更なし'; then
  t59_pass "TC-03 2 回目実行は「変更なし」かつ settings.json がバイト一致（冪等）"
else
  t59_fail "TC-03 冪等でない (rc=$_t59_rc): $_t59_out"
fi

# === TC-04: 「変更なし」出力が「契約準拠」を主張しない（River Review inf-1）===
if printf '%s' "$_t59_out" | grep -q '変更なし' \
  && ! printf '%s' "$_t59_out" | grep -q '既に契約準拠'; then
  t59_pass "TC-04 変更なし文言が契約準拠判定を主張しない（判定は後段 wiring 検証）"
else
  t59_fail "TC-04 変更なし文言が契約準拠を主張している: $_t59_out"
fi

# === TC-05: settings.json 固有ブロックを削除しない（V-3 / mass-delete 思想）===
_t59_mksbx "$_T59_LOCAL"
_t59_sbx2="$_t59_sbx"
_t59_rc=0
_t59_out=$(sh "$_t59_sbx2/scripts/apply-claude-settings.sh" 2>&1) || _t59_rc=$?
if [ "$_t59_rc" -eq 0 ] \
  && grep -qF 'local-only-example.sh' "$_t59_sbx2/.claude/settings.json" \
  && grep -qF 'local-only-stop.sh' "$_t59_sbx2/.claude/settings.json"; then
  t59_pass "TC-05 example に無いローカル固有 hook（PreToolUse / Stop）が保持される"
else
  t59_fail "TC-05 ローカル固有 hook が失われた (rc=$_t59_rc): $_t59_out"
fi

# === TC-06: EH-3 は引数が付与され、ブロックは二重取り込みされない ===
# #1104 以降 EH-3 は Edit|Write / Bash の 2 レーン。出現回数ではなく
# 「example の各レーンに正規表記が 1 本ずつ・引数欠落 0・異表記の残存 0」で見る。
if _t59_ph_lanes_ok "$_t59_sbx2" && [ "$(_t59_ph_foreign "$_t59_sbx2")" -eq 0 ] \
  && grep -qF 'check-plan-hash.sh ${PLANGATE_HOOK_TASK:-} ${PLANGATE_HOOK_FILE:-}' \
       "$_t59_sbx2/.claude/settings.json"; then
  t59_pass "TC-06 引数なし EH-3 に PLANGATE_HOOK_FILE を付与し各レーン 1 本ずつに収める"
else
  t59_fail "TC-06 EH-3 の引数付与 or 重複排除に失敗（$(_t59_ph_diag "$_t59_sbx2")）"
fi

# === TC-07: ローカル固有あり sandbox でも冪等 ===
cp "$_t59_sbx2/.claude/settings.json" "$_t59_sbx2/after1.json"
_t59_rc=0
_t59_out=$(sh "$_t59_sbx2/scripts/apply-claude-settings.sh" 2>&1) || _t59_rc=$?
if [ "$_t59_rc" -eq 0 ] && cmp -s "$_t59_sbx2/after1.json" "$_t59_sbx2/.claude/settings.json"; then
  t59_pass "TC-07 ローカル固有 hook 併存下でも 2 回目はバイト一致"
else
  t59_fail "TC-07 ローカル固有併存時に冪等でない (rc=$_t59_rc): $_t59_out"
fi

# === TC-08: 無効 JSON は fail-closed（rc≠0）+ 原本復元 ===
_t59_mksbx '{ "hooks": '
_t59_sbx3="$_t59_sbx"
_t59_rc=0
_t59_out=$(sh "$_t59_sbx3/scripts/apply-claude-settings.sh" 2>&1) || _t59_rc=$?
if [ "$_t59_rc" -ne 0 ] && grep -qF '{ "hooks": ' "$_t59_sbx3/.claude/settings.json"; then
  t59_pass "TC-08 無効 JSON は非 0 で終了し原本を復元する（fail-closed）"
else
  t59_fail "TC-08 無効 JSON が fail-open した (rc=$_t59_rc): $_t59_out"
fi

# === TC-09: --dry-run は settings.json を書き換えない ===
_t59_mksbx "$_T59_MINIMAL"
_t59_sbx4="$_t59_sbx"
cp "$_t59_sbx4/.claude/settings.json" "$_t59_sbx4/before.json"
_t59_rc=0
_t59_out=$(sh "$_t59_sbx4/scripts/apply-claude-settings.sh" --dry-run 2>&1) || _t59_rc=$?
if [ "$_t59_rc" -eq 0 ] \
  && cmp -s "$_t59_sbx4/before.json" "$_t59_sbx4/.claude/settings.json" \
  && printf '%s' "$_t59_out" | grep -q '適用予定'; then
  t59_pass "TC-09 --dry-run は適用予定を出すだけで settings.json を変更しない"
else
  t59_fail "TC-09 --dry-run が settings.json を変更した (rc=$_t59_rc): $_t59_out"
fi

# === TC-10: matcher をローカル拡張した hook を二重配線しない ===
# settings.json 側 `Edit|Write|MultiEdit` は example の `Edit|Write` を包含する。
# 包含判定が無いと同じ hook が Edit/Write で 2 回発火する重複ブロックが生える。
_t59_mksbx '{
  "hooks": {
    "PreToolUse": [
      { "matcher": "Edit|Write|MultiEdit", "hooks": [ { "type": "command",
        "command": "sh ${CLAUDE_PROJECT_DIR}/scripts/check-approval-token-write.sh" } ] }
    ]
  }
}'
_t59_sbx5="$_t59_sbx"
_t59_rc=0
_t59_out=$(sh "$_t59_sbx5/scripts/apply-claude-settings.sh" 2>&1) || _t59_rc=$?
_t59_n=$(grep -cF 'check-approval-token-write.sh' "$_t59_sbx5/.claude/settings.json" || true)
# 期待: ローカルの Edit|Write|MultiEdit 1 本 + example の Bash 1 本 = 2 本
if [ "$_t59_rc" -eq 0 ] && [ "$_t59_n" -eq 2 ]; then
  t59_pass "TC-10 matcher 包含（Edit|Write|MultiEdit ⊇ Edit|Write）を二重配線しない（出現 2 回）"
else
  t59_fail "TC-10 matcher 包含判定に失敗 (rc=$_t59_rc / 出現 $_t59_n 回・期待 2)"
fi

# === TC-11: 引数なし EH-3 には TASK→FILE の順で 2 引数を付与する（F1）===
# 位置引数契約は $1=task_id / $2=target_file
# （scripts/hooks/check-plan-hash.sh: task_id=${PLANGATE_HOOK_TASK:-${1:-}} /
#  target_file=${PLANGATE_HOOK_FILE:-${2:-}}）。
# 効果の範囲（実測）: **空引数を保持する runner**（引用符付き展開・手動実行）
# でのみ位置が保たれる。FILE だけ足した形ではファイルパスが $1＝task_id 扱いに
# なり `invalid task_id` → exit 2。一方 `sh -c` 経路では未引用 `${VAR:-}` の
# 空展開が語ごと消えるため、TASK 未設定 + FILE 設定のケースは付与の有無に
# 関わらず同結果（= example の配線自体が持つ性質。quote 化は #975 follow-up）。
# 契約検証は部分文字列 grep なのでこの破壊を検知できない（Shadow Config）。
_t59_mksbx '{
  "hooks": {
    "PreToolUse": [
      { "matcher": "Edit|Write", "hooks": [ { "type": "command",
        "command": "sh ${CLAUDE_PROJECT_DIR}/scripts/hooks/check-plan-hash.sh" } ] }
    ]
  }
}'
_t59_sbx6="$_t59_sbx"
_t59_rc=0
_t59_out=$(sh "$_t59_sbx6/scripts/apply-claude-settings.sh" 2>&1) || _t59_rc=$?
if [ "$_t59_rc" -eq 0 ] && _t59_ph_lanes_ok "$_t59_sbx6" \
  && [ "$(_t59_ph_foreign "$_t59_sbx6")" -eq 0 ] \
  && grep -qF 'check-plan-hash.sh ${PLANGATE_HOOK_TASK:-} ${PLANGATE_HOOK_FILE:-}' \
       "$_t59_sbx6/.claude/settings.json"; then
  t59_pass "TC-11 引数なし EH-3 に TASK→FILE の順で 2 引数を付与（example と同形・全レーン）"
else
  t59_fail "TC-11 EH-3 の引数位置が壊れている (rc=$_t59_rc / $(_t59_ph_diag "$_t59_sbx6")): $_t59_out"
fi

# === TC-12: matcher "*"（全ツール）を包含として扱う（F2(b)）===
# `"*"` は全ツールに発火する。これを「未知の matcher」として扱うと example の
# `Edit|Write` / `Bash` の 2 ブロックを追加してしまい 3 重発火になる。
_t59_mksbx '{
  "hooks": {
    "PreToolUse": [
      { "matcher": "*", "hooks": [ { "type": "command",
        "command": "sh ${CLAUDE_PROJECT_DIR}/scripts/check-approval-token-write.sh" } ] }
    ]
  }
}'
_t59_sbx7="$_t59_sbx"
_t59_rc=0
_t59_out=$(sh "$_t59_sbx7/scripts/apply-claude-settings.sh" 2>&1) || _t59_rc=$?
_t59_n=$(grep -cF 'check-approval-token-write.sh' "$_t59_sbx7/.claude/settings.json" || true)
if [ "$_t59_rc" -eq 0 ] && [ "$_t59_n" -eq 1 ]; then
  t59_pass "TC-12 matcher \"*\" を全ツール包含として扱い二重配線しない（出現 1 回）"
else
  t59_fail "TC-12 matcher \"*\" の包含判定に失敗 (rc=$_t59_rc / 出現 $_t59_n 回・期待 1)"
fi

# === TC-13: 引用符付きパスを同一 hook と見なす（F2(c)）===
# `sh "${X}/a.sh"` と `sh ${X}/a.sh` は同じファイルを起動する。引用符を
# 剥がさないと別 hook 扱いになり EH-3 が二重発火する（one-shot maintenance
# token が 1 回目で消費され 2 回目が block される実害）。
_t59_mksbx '{
  "hooks": {
    "PreToolUse": [
      { "matcher": "Edit|Write", "hooks": [ { "type": "command",
        "command": "sh \"${CLAUDE_PROJECT_DIR}/scripts/hooks/check-plan-hash.sh\" ${PLANGATE_HOOK_TASK:-} ${PLANGATE_HOOK_FILE:-}" } ] }
    ]
  }
}'
_t59_sbx8="$_t59_sbx"
_t59_rc=0
_t59_out=$(sh "$_t59_sbx8/scripts/apply-claude-settings.sh" 2>&1) || _t59_rc=$?
# 引用符付きは同一 hook＝Edit|Write レーンは既存 1 本のまま（追加されない）。
# 別 hook 扱いになると同レーンが 2 本になり lanes_ok が落ちる。
if [ "$_t59_rc" -eq 0 ] && _t59_ph_lanes_ok "$_t59_sbx8" \
  && [ "$(_t59_ph_foreign "$_t59_sbx8")" -eq 0 ]; then
  t59_pass "TC-13 引用符付きパスを同一 hook と見なす（Edit|Write レーンは 1 本のまま）"
else
  t59_fail "TC-13 引用符付きパスが別 hook 扱いになった (rc=$_t59_rc / $(_t59_ph_diag "$_t59_sbx8"))"
fi

# === TC-14: 別変数名のパスは同一視しない（F2 逆方向）===
# `$SOMEVAR/...` と `${CLAUDE_PROJECT_DIR}/...` は別ファイルを指しうる。
# 変数を除去して同一視すると「配線済み」と誤判定し必要な hook が入らないまま
# 契約検証（部分文字列 grep）は PASS してしまう。
_t59_mksbx '{
  "hooks": {
    "PreToolUse": [
      { "matcher": "Edit|Write", "hooks": [ { "type": "command",
        "command": "sh $SOMEVAR/scripts/hooks/check-plan-hash.sh ${PLANGATE_HOOK_TASK:-} ${PLANGATE_HOOK_FILE:-}" } ] }
    ]
  }
}'
_t59_sbx9="$_t59_sbx"
_t59_rc=0
_t59_out=$(sh "$_t59_sbx9/scripts/apply-claude-settings.sh" 2>&1) || _t59_rc=$?
# 期待: 正規表記が example の全レーンに 1 本ずつ入り、かつ別変数名の 1 本は
# 削除されず残る（FOREIGN=1）。同一視されると Edit|Write レーンが 0 本になる。
if [ "$_t59_rc" -eq 0 ] && _t59_ph_lanes_ok "$_t59_sbx9" \
  && [ "$(_t59_ph_foreign "$_t59_sbx9")" -eq 1 ]; then
  t59_pass "TC-14 別変数名のパスを同一視せず正規の EH-3 を全レーンへ取り込む"
else
  t59_fail "TC-14 別変数名を同一視して EH-3 が入らなかった (rc=$_t59_rc / $(_t59_ph_diag "$_t59_sbx9"))"
fi

# === TC-15: 未知引数は本適用せずエラー終了する（F5）===
_t59_mksbx "$_T59_MINIMAL"
_t59_sbx10="$_t59_sbx"
cp "$_t59_sbx10/.claude/settings.json" "$_t59_sbx10/before.json"
_t59_rc=0
_t59_out=$(sh "$_t59_sbx10/scripts/apply-claude-settings.sh" --dryrun 2>&1) || _t59_rc=$?
if [ "$_t59_rc" -eq 2 ] \
  && cmp -s "$_t59_sbx10/before.json" "$_t59_sbx10/.claude/settings.json" \
  && printf '%s' "$_t59_out" | grep -q 'usage:'; then
  t59_pass "TC-15 未知引数（--dryrun）は usage + exit 2 で本適用しない"
else
  t59_fail "TC-15 未知引数が本適用された (rc=$_t59_rc): $_t59_out"
fi

# === TC-16: 契約検証 FAIL 時は backup を残す（F4）===
# settings.example.json 側から EH-3 を落とすと、merge 後も契約を満たせず
# apply は exit 1 する。この経路で backup まで消えると巻き戻せない。
_t59_mksbx "$_T59_MINIMAL"
_t59_sbx11="$_t59_sbx"
python3 - "$_t59_sbx11/.claude/settings.example.json" <<'PY59'
import json, sys
p = sys.argv[1]
d = json.load(open(p))
pre = d.get("hooks", {}).get("PreToolUse", [])
d["hooks"]["PreToolUse"] = [
    b for b in pre
    if not any("check-plan-hash.sh" in (h.get("command", "") or "")
               for h in (b.get("hooks") or []))
]
json.dump(d, open(p, "w"), ensure_ascii=False, indent=2)
PY59
_t59_rc=0
_t59_out=$(sh "$_t59_sbx11/scripts/apply-claude-settings.sh" 2>&1) || _t59_rc=$?
_t59_bak=$(ls "$_t59_sbx11/.claude/" | grep -c 'settings.json.bak.' || true)
if [ "$_t59_rc" -ne 0 ] && [ "$_t59_bak" -ge 1 ]; then
  t59_pass "TC-16 契約検証 FAIL 時は backup を残す（巻き戻し可能）"
else
  t59_fail "TC-16 FAIL 経路で backup が消えた (rc=$_t59_rc / backup $_t59_bak 件)"
fi

# === TC-17: 契約 hook を matcher "*" で配線した状態から収束する（MJ-1）===
# apply 側の UNIVERSAL 包含判定と check-settings-wiring.sh の matcher 解釈が
# ずれると、apply は「配線済み」と判断し検証は「不足」と言い続けて
# **何度実行しても rc=1 のまま収束しない**（= #928/#914 が解こうとした
# 「doctor が永久に FAIL」の別条件での再生産）。両者の解釈一致を検証する。
# TC-12 は非契約 hook（approval-token）を題材にしているためこの経路を通らない。
_t59_mksbx '{
  "hooks": {
    "PreToolUse": [
      { "matcher": "*", "hooks": [
        { "type": "command", "command": "sh ${CLAUDE_PROJECT_DIR}/scripts/hooks/check-plan-exists.sh" },
        { "type": "command", "command": "sh ${CLAUDE_PROJECT_DIR}/scripts/hooks/check-c3-approval.sh" },
        { "type": "command", "command": "sh ${CLAUDE_PROJECT_DIR}/scripts/hooks/check-forbidden-files.sh" },
        { "type": "command", "command": "sh ${CLAUDE_PROJECT_DIR}/scripts/hooks/check-plan-hash.sh ${PLANGATE_HOOK_TASK:-} ${PLANGATE_HOOK_FILE:-}" },
        { "type": "command", "command": "sh ${CLAUDE_PROJECT_DIR}/scripts/hooks/check-delegation-commit-boundary.sh" }
      ] }
    ]
  }
}'
_t59_sbx12="$_t59_sbx"
_t59_rc=0
_t59_out=$(sh "$_t59_sbx12/scripts/apply-claude-settings.sh" 2>&1) || _t59_rc=$?
cp "$_t59_sbx12/.claude/settings.json" "$_t59_sbx12/after1.json"
_t59_rc2=0
_t59_out2=$(sh "$_t59_sbx12/scripts/apply-claude-settings.sh" 2>&1) || _t59_rc2=$?
_t59_n=$(grep -cF 'check-plan-hash.sh' "$_t59_sbx12/.claude/settings.json" || true)
if [ "$_t59_rc" -eq 0 ] && [ "$_t59_rc2" -eq 0 ] && [ "$_t59_n" -eq 1 ] \
  && cmp -s "$_t59_sbx12/after1.json" "$_t59_sbx12/.claude/settings.json"; then
  t59_pass "TC-17 契約 hook が matcher \"*\" でも rc=0 で収束（apply と wiring の matcher 解釈が一致）"
else
  t59_fail "TC-17 matcher \"*\" で非収束 (run1 rc=$_t59_rc / run2 rc=$_t59_rc2 / EH-3 $_t59_n 回): $_t59_out2"
fi

# === TC-18: 同一秒の再実行でも pristine backup を上書きしない（mn-1）===
# 契約 FAIL → 即再実行は最も自然な操作。backup 名が `$(date +%s)` だと
# 同一秒に同名 backup へ「適用後の内容」が cp され巻き戻せなくなる。
_t59_mksbx "$_T59_MINIMAL"
_t59_sbx13="$_t59_sbx"
cp "$_t59_sbx13/.claude/settings.json" "$_t59_sbx13/pristine.json"
python3 - "$_t59_sbx13/.claude/settings.example.json" <<'PY59'
import json, sys
p = sys.argv[1]
d = json.load(open(p))
d["hooks"]["PreToolUse"] = [
    b for b in d.get("hooks", {}).get("PreToolUse", [])
    if not any("check-plan-hash.sh" in (h.get("command", "") or "")
               for h in (b.get("hooks") or []))
]
json.dump(d, open(p, "w"), ensure_ascii=False, indent=2)
PY59
sh "$_t59_sbx13/scripts/apply-claude-settings.sh" >/dev/null 2>&1 || true
sh "$_t59_sbx13/scripts/apply-claude-settings.sh" >/dev/null 2>&1 || true
_t59_pris=0
for _t59_b in "$_t59_sbx13/.claude/"settings.json.bak.*; do
  if [ -f "$_t59_b" ] && cmp -s "$_t59_b" "$_t59_sbx13/pristine.json"; then
    _t59_pris=$((_t59_pris + 1))
  fi
done
if [ "$_t59_pris" -ge 1 ]; then
  t59_pass "TC-18 FAIL→即再実行でも適用前 pristine の backup が残る（巻き戻し可能）"
else
  t59_fail "TC-18 pristine backup が適用後の内容で上書きされた（一致 $_t59_pris 件）"
fi

# === TC-19: 書き込みで mode が拡大しない（mn-2）===
# os.replace は新規 tmp の mode（umask 由来 0644）を持ち込むため、明示的に
# 引き継がないと 0600 が 0644 へ拡大する。settings.json は env 等の秘匿値を
# 持ちうるので可視範囲を広げてはならない。
_t59_mksbx "$_T59_MINIMAL"
_t59_sbx14="$_t59_sbx"
chmod 600 "$_t59_sbx14/.claude/settings.json"
_t59_rc=0
_t59_out=$(sh "$_t59_sbx14/scripts/apply-claude-settings.sh" 2>&1) || _t59_rc=$?
_t59_mode=$(python3 -c 'import os,sys;print(oct(os.stat(sys.argv[1]).st_mode & 0o777))' \
  "$_t59_sbx14/.claude/settings.json" 2>/dev/null || echo "unknown")
if [ "$_t59_mode" = "0o600" ]; then _t59_modeok=1; else _t59_modeok=0; fi
if [ "$_t59_rc" -eq 0 ] && [ "$_t59_modeok" -eq 1 ]; then
  t59_pass "TC-19 適用後も mode 0600 が保持される（秘匿値の可視範囲を広げない）"
else
  t59_fail "TC-19 mode が拡大した (rc=$_t59_rc / mode=${_t59_mode} 期待 0o600)"
fi

# === TC-20: symlink の settings.json を実体へ書く（mn-2）===
# dotfiles 管理で symlink の場合、実体解決しないと os.replace がリンクを
# 実ファイルへ置換し、リンク先は旧内容のまま取り残される。
_t59_mksbx "$_T59_MINIMAL"
_t59_sbx15="$_t59_sbx"
mkdir -p "$_t59_sbx15/dotfiles"
mv "$_t59_sbx15/.claude/settings.json" "$_t59_sbx15/dotfiles/settings.json"
ln -s "$_t59_sbx15/dotfiles/settings.json" "$_t59_sbx15/.claude/settings.json"
_t59_rc=0
_t59_out=$(sh "$_t59_sbx15/scripts/apply-claude-settings.sh" 2>&1) || _t59_rc=$?
_t59_n=$(grep -cF 'check-plan-hash.sh' "$_t59_sbx15/dotfiles/settings.json" || true)
if [ "$_t59_rc" -eq 0 ] && [ -L "$_t59_sbx15/.claude/settings.json" ] && [ "$_t59_n" -ge 1 ]; then
  t59_pass "TC-20 symlink を実体解決して書き込む（リンク維持・リンク先へ反映）"
else
  t59_fail "TC-20 symlink が壊れた (rc=$_t59_rc / link=$([ -L "$_t59_sbx15/.claude/settings.json" ] && echo yes || echo no) / リンク先 EH-3 $_t59_n 回)"
fi

# === TC-21: 単一引用符の literal パスを同一視しない（mn-3）===
# `sh '${X}/a.sh'` はシェルが変数を展開せず literal パスを起動しようとして
# 失敗する別物。同一視すると「配線済み」と誤判定し、正規 EH-3 が入らないまま
# 契約検証（部分文字列 grep）だけ PASS する Shadow Config になる。
_t59_mksbx '{
  "hooks": {
    "PreToolUse": [
      { "matcher": "Edit|Write", "hooks": [ { "type": "command",
        "command": "sh '"'"'${CLAUDE_PROJECT_DIR}/scripts/hooks/check-plan-hash.sh'"'"' ${PLANGATE_HOOK_TASK:-} ${PLANGATE_HOOK_FILE:-}" } ] }
    ]
  }
}'
_t59_sbx16="$_t59_sbx"
_t59_rc=0
_t59_out=$(sh "$_t59_sbx16/scripts/apply-claude-settings.sh" 2>&1) || _t59_rc=$?
# 期待: 正規表記が example の全レーンに 1 本ずつ入り、単一引用符の 1 本は
# 別物として残る（FOREIGN=1）。同一視されると Edit|Write レーンが 0 本になる。
if [ "$_t59_rc" -eq 0 ] && _t59_ph_lanes_ok "$_t59_sbx16" \
  && [ "$(_t59_ph_foreign "$_t59_sbx16")" -eq 1 ]; then
  t59_pass "TC-21 単一引用符の literal パスを同一視せず正規 EH-3 を全レーンへ取り込む"
else
  t59_fail "TC-21 単一引用符を同一視し正規 EH-3 が入らなかった (rc=$_t59_rc / $(_t59_ph_diag "$_t59_sbx16"))"
fi

# === TC-22: サンドボックス後片付け（明示 rm -rf の実効確認）===
rm -rf "$_t59_sbx1" "$_t59_sbx2" "$_t59_sbx3" "$_t59_sbx4" "$_t59_sbx5" \
  "$_t59_sbx6" "$_t59_sbx7" "$_t59_sbx8" "$_t59_sbx9" "$_t59_sbx10" "$_t59_sbx11" \
  "$_t59_sbx12" "$_t59_sbx13" "$_t59_sbx14" "$_t59_sbx15" "$_t59_sbx16"
_t59_left=0
for _t59_d in "$_t59_sbx1" "$_t59_sbx2" "$_t59_sbx3" "$_t59_sbx4" "$_t59_sbx5" \
  "$_t59_sbx6" "$_t59_sbx7" "$_t59_sbx8" "$_t59_sbx9" "$_t59_sbx10" "$_t59_sbx11" \
  "$_t59_sbx12" "$_t59_sbx13" "$_t59_sbx14" "$_t59_sbx15" "$_t59_sbx16"; do
  if [ -d "$_t59_d" ]; then
    _t59_left=$((_t59_left + 1))
  fi
done
if [ "$_t59_left" -eq 0 ]; then
  t59_pass "TC-22 サンドボックスを明示削除（実 .claude/ には一切書き込まない）"
else
  t59_fail "TC-22 サンドボックスが $_t59_left 件残存"
fi

fi

# standalone 実行時は自前 cleanup を drain して結果を出力
if [ "$_T59_STANDALONE" -eq 1 ]; then
  printf '%s' "$_T59_CLEANUP_PATHS" | while IFS= read -r _pg_cp; do
    [ -n "$_pg_cp" ] || continue
    rm -rf "$_pg_cp" 2>/dev/null || true
  done
  printf '\nResults: %d passed, %d failed\n' "$pass" "$fail"
  [ "$fail" -eq 0 ] || exit 1
fi
