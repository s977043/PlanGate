# tests/extras/ta-10-doctor-fix.sh
# Sourced by tests/run-tests.sh
# TASK-0069: scripts/doctor_fix.py — safe settings.json hook merge (check/apply/dry-run)
#
# scripts/doctor_fix.py を一時 dir 隔離で直接叩く単体テスト群。
# 実 .claude/ は汚さない（mktemp -d を --project-dir で渡す）。

printf '\n=== TA-10: doctor --fix (TASK-0069) ===\n'

_ta10_repo="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
_ta10_py="$_ta10_repo/scripts/doctor_fix.py"
_ta10_example="$_ta10_repo/.claude/settings.example.json"

# 一時作業ディレクトリを作り、その中に .claude/ を構築するヘルパ
# usage: _ta10_mkproj   →  echo した path に project dir
_ta10_mkproj() {
  d="$(mktemp -d 2>/dev/null || mktemp -d -t ta10)"
  mkdir -p "$d/.claude"
  cp "$_ta10_example" "$d/.claude/settings.example.json"
  printf '%s' "$d"
}

# ---------------------------------------------------------------------------
# TC-2: dry-run は一切書き換えない（settings.json/EH-8 chmod/.gitignore/docs/working 不変）
# ---------------------------------------------------------------------------
proj="$(_ta10_mkproj)"
python3 "$_ta10_py" --project-dir "$proj" --dry-run >/dev/null 2>&1 && rc=0 || rc=$?
if [ ! -e "$proj/.claude/settings.json" ] && [ ! -e "$proj/.claude/settings.json.bak" ]; then
  printf '[PASS] doctor-fix TC-2: dry-run does not create settings.json / .bak\n'
  pass=$((pass + 1))
else
  printf '[FAIL] doctor-fix TC-2: dry-run wrote files (rc=%d)\n' "$rc"
  fail=$((fail + 1))
fi
rm -rf "$proj"

# ---------------------------------------------------------------------------
# TC-3a: --apply 新規作成・.bak なし
# ---------------------------------------------------------------------------
proj="$(_ta10_mkproj)"
python3 "$_ta10_py" --project-dir "$proj" --apply >/dev/null 2>&1 && rc=0 || rc=$?
if [ "$rc" -eq 0 ] && [ -f "$proj/.claude/settings.json" ] && [ ! -e "$proj/.claude/settings.json.bak" ] \
   && python3 "$_ta10_py" --project-dir "$proj" --check >/dev/null 2>&1; then
  printf '[PASS] doctor-fix TC-3a: --apply creates settings.json, no .bak, --check passes\n'
  pass=$((pass + 1))
else
  printf '[FAIL] doctor-fix TC-3a: new-create behavior wrong (rc=%d)\n' "$rc"
  fail=$((fail + 1))
fi
rm -rf "$proj"

# ---------------------------------------------------------------------------
# TC-3b: 既存 settings.json + 既存 .bak → .bak.<epoch> ローテート退避
# ---------------------------------------------------------------------------
proj="$(_ta10_mkproj)"
printf '{"permissions":{"allow":["Bash(ls)"]}}' > "$proj/.claude/settings.json"
printf 'OLD-BACKUP-CONTENT' > "$proj/.claude/settings.json.bak"
python3 "$_ta10_py" --project-dir "$proj" --apply >/dev/null 2>&1 && rc=0 || rc=$?
rotated="$(ls "$proj"/.claude/settings.json.bak.* 2>/dev/null | head -1)"
if [ "$rc" -eq 0 ] && [ -f "$proj/.claude/settings.json.bak" ] && [ -n "$rotated" ] \
   && [ "$(cat "$rotated")" = "OLD-BACKUP-CONTENT" ] \
   && python3 "$_ta10_py" --project-dir "$proj" --check >/dev/null 2>&1; then
  printf '[PASS] doctor-fix TC-3b: existing .bak rotated to .bak.<epoch>, new .bak created\n'
  pass=$((pass + 1))
else
  printf '[FAIL] doctor-fix TC-3b: backup rotation wrong (rc=%d rotated=%s)\n' "$rc" "$rotated"
  fail=$((fail + 1))
fi
rm -rf "$proj"

# ---------------------------------------------------------------------------
# TC-3c (Codex C-4 major): 既存 .bak.<epoch> を上書きしない。
#   now-1..now+1 の rotated backup を全て事前配置し、--apply 後も
#   いずれも sentinel 内容を保持し、新 rotated が別名で作られることを検証。
# ---------------------------------------------------------------------------
proj="$(_ta10_mkproj)"
printf '{"permissions":{"allow":["Bash(ls)"]}}' > "$proj/.claude/settings.json"
printf 'OLD-BACKUP-CONTENT' > "$proj/.claude/settings.json.bak"
_now="$(date +%s)"
_pre_ok=1
for _delta in -1 0 1; do
  _e=$((_now + _delta))
  printf 'SENTINEL-%s' "$_e" > "$proj/.claude/settings.json.bak.$_e"
done
python3 "$_ta10_py" --project-dir "$proj" --apply >/dev/null 2>&1 && rc=0 || rc=$?
for _delta in -1 0 1; do
  _e=$((_now + _delta))
  _f="$proj/.claude/settings.json.bak.$_e"
  [ -f "$_f" ] && [ "$(cat "$_f")" = "SENTINEL-$_e" ] || _pre_ok=0
done
# OLD-BACKUP-CONTENT は衝突回避サフィックス付き等の別名へ退避されているはず
_rot_old="$(grep -rl 'OLD-BACKUP-CONTENT' "$proj"/.claude/settings.json.bak.* 2>/dev/null | head -1)"
if [ "$rc" -eq 0 ] && [ "$_pre_ok" -eq 1 ] && [ -n "$_rot_old" ] \
   && [ -f "$proj/.claude/settings.json.bak" ] \
   && python3 "$_ta10_py" --project-dir "$proj" --check >/dev/null 2>&1; then
  printf '[PASS] doctor-fix TC-3c: pre-existing .bak.<epoch> never overwritten\n'
  pass=$((pass + 1))
else
  printf '[FAIL] doctor-fix TC-3c: rotated backup collision overwrote existing (rc=%d pre_ok=%d)\n' "$rc" "$_pre_ok"
  fail=$((fail + 1))
fi
rm -rf "$proj"

# ---------------------------------------------------------------------------
# TC-4: 既存キー温存（merge-only）
# ---------------------------------------------------------------------------
proj="$(_ta10_mkproj)"
cat > "$proj/.claude/settings.json" <<'EOF'
{"permissions":{"allow":["Bash(ls)"]},"hooks":{"SessionStart":[{"hooks":[{"type":"command","command":"echo my-own-hook"}]}]}}
EOF
python3 "$_ta10_py" --project-dir "$proj" --apply >/dev/null 2>&1 && rc=0 || rc=$?
if [ "$rc" -eq 0 ] && python3 - "$proj/.claude/settings.json" <<'PYEOF'
import json, sys
d = json.load(open(sys.argv[1]))
assert d["permissions"]["allow"] == ["Bash(ls)"], "permissions lost"
ss = d["hooks"]["SessionStart"]
flat = [h["command"] for blk in ss for h in blk.get("hooks", [])]
assert "echo my-own-hook" in flat, "existing SessionStart hook lost"
assert any("gh-pin-account.sh" in c for c in flat), "example SessionStart hook not merged"
assert flat.count("echo my-own-hook") == 1, "duplicated existing hook"
PYEOF
then
  printf '[PASS] doctor-fix TC-4: existing keys preserved, example merged (no dup)\n'
  pass=$((pass + 1))
else
  printf '[FAIL] doctor-fix TC-4: merge-only violated (rc=%d)\n' "$rc"
  fail=$((fail + 1))
fi
rm -rf "$proj"

# ---------------------------------------------------------------------------
# TC-5: 冪等（2 回目 no-op、バイト一致）
# ---------------------------------------------------------------------------
proj="$(_ta10_mkproj)"
python3 "$_ta10_py" --project-dir "$proj" --apply >/dev/null 2>&1
cp "$proj/.claude/settings.json" "$proj/first-run.json"
python3 "$_ta10_py" --project-dir "$proj" --apply >/dev/null 2>&1 && rc=0 || rc=$?
if [ "$rc" -eq 0 ] && cmp -s "$proj/first-run.json" "$proj/.claude/settings.json"; then
  printf '[PASS] doctor-fix TC-5: second --apply is byte-identical no-op\n'
  pass=$((pass + 1))
else
  printf '[FAIL] doctor-fix TC-5: not idempotent (rc=%d)\n' "$rc"
  fail=$((fail + 1))
fi
rm -rf "$proj"

# ---------------------------------------------------------------------------
# TC-E1: 不正 JSON → 上書きせず明示エラー・.bak 作らない
# ---------------------------------------------------------------------------
proj="$(_ta10_mkproj)"
printf '{ "permissions": ' > "$proj/.claude/settings.json"
out="$(python3 "$_ta10_py" --project-dir "$proj" --apply 2>&1)" && rc=0 || rc=$?
if [ "$rc" -ne 0 ] \
   && printf '%s' "$out" | grep -qi 'not valid JSON' \
   && [ "$(cat "$proj/.claude/settings.json")" = '{ "permissions": ' ] \
   && [ ! -e "$proj/.claude/settings.json.bak" ]; then
  printf '[PASS] doctor-fix TC-E1: invalid JSON aborts, no overwrite, no .bak\n'
  pass=$((pass + 1))
else
  printf '[FAIL] doctor-fix TC-E1: invalid JSON not handled safely (rc=%d)\n' "$rc"
  fail=$((fail + 1))
fi
rm -rf "$proj"

# ---------------------------------------------------------------------------
# TC-E2: hooks 一部のみ → 不足ブロックのみ追記・二重リスト構造保持
# ---------------------------------------------------------------------------
proj="$(_ta10_mkproj)"
cat > "$proj/.claude/settings.json" <<'EOF'
{"hooks":{"PreToolUse":[{"matcher":"Edit|Write","hooks":[{"type":"command","command":"sh ${CLAUDE_PROJECT_DIR}/scripts/hooks/check-plan-exists.sh"}]}]}}
EOF
python3 "$_ta10_py" --project-dir "$proj" --apply >/dev/null 2>&1 && rc=0 || rc=$?
if [ "$rc" -eq 0 ] && python3 - "$proj/.claude/settings.json" <<'PYEOF'
import json, sys
d = json.load(open(sys.argv[1]))
pre = d["hooks"]["PreToolUse"]
# 二重リスト構造保持: 各要素は {matcher, hooks:[{type,command}]}
for blk in pre:
    assert isinstance(blk.get("hooks"), list), "double-list structure broken"
cmds = [h["command"] for blk in pre for h in blk["hooks"]]
# 既存 check-plan-exists は重複しない
assert sum("check-plan-exists.sh" in c for c in cmds) == 1, "existing block duplicated"
# 不足 3 ブロック (c3-approval, plan-hash, forbidden-files) が追記
for name in ("check-c3-approval.sh", "check-plan-hash.sh", "check-forbidden-files.sh"):
    assert any(name in c for c in cmds), f"missing block not added: {name}"
PYEOF
then
  printf '[PASS] doctor-fix TC-E2: only missing blocks appended, double-list preserved\n'
  pass=$((pass + 1))
else
  printf '[FAIL] doctor-fix TC-E2: partial-merge wrong (rc=%d)\n' "$rc"
  fail=$((fail + 1))
fi
rm -rf "$proj"

# ---------------------------------------------------------------------------
# TC-E3: 読み取り専用 dir → 明示エラー・部分書込なし
# ---------------------------------------------------------------------------
proj="$(_ta10_mkproj)"
printf '{"permissions":{"allow":["Bash(ls)"]}}' > "$proj/.claude/settings.json"
chmod 0500 "$proj/.claude"
out="$(python3 "$_ta10_py" --project-dir "$proj" --apply 2>&1)" && rc=0 || rc=$?
chmod 0700 "$proj/.claude"
if [ "$rc" -ne 0 ] && [ ! -e "$proj/.claude/settings.json.bak" ] \
   && [ "$(cat "$proj/.claude/settings.json")" = '{"permissions":{"allow":["Bash(ls)"]}}' ]; then
  printf '[PASS] doctor-fix TC-E3: read-only dir → explicit error, no partial write\n'
  pass=$((pass + 1))
else
  printf '[FAIL] doctor-fix TC-E3: read-only dir not handled (rc=%d)\n' "$rc"
  fail=$((fail + 1))
fi
rm -rf "$proj"

# ===========================================================================
# Integration テスト群（T-10）
#
# bin/plangate doctor は plangate_root を「bin/plangate の親」から算出するため、
# --fix 系を実リポジトリで叩くと .claude/settings.json 等を汚染する。
# よって bin/ + scripts/ + .claude/settings.example.json を mktemp -d 配下に
# コピーした「隔離 plangate ルート」を作り、その bin/plangate を実行する。
# TC-7（--json, 読み取りのみ）は実リポジトリの bin/plangate をそのまま使う。
# ---------------------------------------------------------------------------

# 隔離 plangate ルートを構築（未配線: settings.example.json のみ・settings.json なし）
_ta10_mkroot() {
  r="$(mktemp -d 2>/dev/null || mktemp -d -t ta10root)"
  mkdir -p "$r/bin" "$r/scripts" "$r/.claude" "$r/docs/working"
  cp "$_ta10_repo/bin/plangate" "$r/bin/plangate"
  cp -R "$_ta10_repo/scripts/." "$r/scripts/"
  cp "$_ta10_example" "$r/.claude/settings.example.json"
  printf '%s' "$r"
}

# ---------------------------------------------------------------------------
# TC-1: 未配線環境で doctor が Hook Wiring セクション出力 + FAIL + exit 1
# ---------------------------------------------------------------------------
root="$(_ta10_mkroot)"
out="$(sh "$root/bin/plangate" doctor 2>&1)" && rc=0 || rc=$?
wiring_block="$(printf '%s\n' "$out" | awk '/^=== Hook Enforcement Wiring ===$/{f=1;next} /^=== /{f=0} f')"
if [ "$rc" -eq 1 ] \
   && printf '%s\n' "$out" | grep -q '^=== Hook Enforcement Wiring ===$' \
   && printf '%s\n' "$wiring_block" | grep -q '\[FAIL\] PlanGate hooks not wired'; then
  printf '[PASS] doctor-fix TC-1: unwired env emits Hook Wiring section + FAIL + exit 1\n'
  pass=$((pass + 1))
else
  printf '[FAIL] doctor-fix TC-1: unwired doctor behavior wrong (rc=%d)\n' "$rc"
  fail=$((fail + 1))
fi
rm -rf "$root"

# ---------------------------------------------------------------------------
# TC-6 / AC-6: gh/codex を PATH から除外 + --fix --yes → 自動インストールせず
#   案内のみ。AC-6 の契約は「自動インストールしない」「案内を出す」であり、
#   overall Result / exit code は他の修復ステップの成否に従う（AC-6 明記）。
#   隔離ルートは hooks 以外の v8.6.0 チェックが構造上 FAIL するため Result は
#   FIX FAILED / rc!=0 になりうるが、それは AC-6 の対象外（gh/codex の挙動のみ
#   を検証する）。よって rc / Result 文字列はアサートしない。
# ---------------------------------------------------------------------------
root="$(_ta10_mkroot)"
# gh/codex を確実に不在化する: coreutils を全 symlink し gh/codex のみ除外した
# shim bin を唯一の PATH にする（CI runner は /usr/bin/gh を持つため単純な
# PATH=/usr/bin:/bin では除外できない＝実装者が info で予告したリスクの恒久対策）。
shimbin="$(mktemp -d 2>/dev/null || mktemp -d -t ta10shim)"
for _d in /usr/bin /bin /usr/local/bin; do
  [ -d "$_d" ] || continue
  for _f in "$_d"/*; do
    [ -e "$_f" ] || continue
    _b="$(basename "$_f")"
    case "$_b" in gh|codex) continue ;; esac
    [ -e "$shimbin/$_b" ] || ln -s "$_f" "$shimbin/$_b" 2>/dev/null || true
  done
done
# python3 が hostedtoolcache 等 PATH 外にある場合に備え明示 symlink
if ! [ -e "$shimbin/python3" ]; then
  _py="$(command -v python3 || true)"
  [ -n "$_py" ] && ln -s "$_py" "$shimbin/python3" 2>/dev/null || true
fi
out="$(PATH="$shimbin" sh "$root/bin/plangate" doctor --fix --yes 2>&1)" && rc=0 || rc=$?
rm -rf "$shimbin"
if printf '%s\n' "$out" | grep -q 'gh (GitHub CLI) not installed' \
   && printf '%s\n' "$out" | grep -q 'codex (Codex CLI) not installed' \
   && ! printf '%s\n' "$out" | grep -qi 'installing gh\|brew install\|apt-get install\|npm install -g'; then
  printf '[PASS] doctor-fix TC-6: missing gh/codex -> guidance only, no auto-install (AC-6)\n'
  pass=$((pass + 1))
else
  printf '[FAIL] doctor-fix TC-6: gh/codex absence not handled as guidance-only (rc=%d)\n' "$rc"
  fail=$((fail + 1))
fi
rm -rf "$root"

# ---------------------------------------------------------------------------
# TC-7: doctor --json --scope hooks に hook-wiring 項目（name/ok/level）を含む。
#       default --json（--scope v8.6.0）はバイト一致で無改変。
#       settings.json の内容値・絶対パス値は JSON に含まれない。
#       読み取りのみ -> 実リポジトリの bin/plangate をそのまま使用。
# ---------------------------------------------------------------------------
# doctor --json は v8.6.0 チェックに FAIL があると exit 1 を返す（CI 環境では
# 構造上ありうる）。TC-7 は JSON 内容のみを比較し終了コードは評価しないため、
# set -e による途中 abort を防ぐ目的で `|| true` を付与する。
_ta10_json_default="$(sh "$_ta10_repo/bin/plangate" doctor --json 2>&1 || true)"
_ta10_json_explicit="$(sh "$_ta10_repo/bin/plangate" doctor --json --scope v8.6.0 2>&1 || true)"
_ta10_json_hooks="$(sh "$_ta10_repo/bin/plangate" doctor --json --scope hooks 2>&1 || true)"
if [ "$_ta10_json_default" = "$_ta10_json_explicit" ] \
   && printf '%s' "$_ta10_json_hooks" | python3 -c '
import json, sys
d = json.load(sys.stdin)
assert d.get("scope") == "hooks", "scope != hooks"
checks = d.get("checks") or []
assert checks, "no checks in hooks scope"
hw = [c for c in checks if "hook" in c.get("name", "").lower()]
assert hw, "hook-wiring check item not present"
c = hw[0]
for k in ("name", "ok", "level"):
    assert k in c, f"missing key: {k}"
assert isinstance(c["ok"], bool), "ok not bool"
blob = json.dumps(d, ensure_ascii=False)
for leak in ("${CLAUDE_PROJECT_DIR}", "scripts/hooks/check-plan-exists.sh", "/Users/", "settings.example.json"):
    assert leak not in blob, f"privacy leak in json: {leak}"
' 2>/dev/null; then
  printf '[PASS] doctor-fix TC-7: --json --scope hooks has hook-wiring item; default byte-identical; no leak\n'
  pass=$((pass + 1))
else
  printf '[FAIL] doctor-fix TC-7: json scope behavior or privacy wrong\n'
  fail=$((fail + 1))
fi
