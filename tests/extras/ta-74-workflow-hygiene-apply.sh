# tests/extras/ta-74-workflow-hygiene-apply.sh
# PG_EXTRA_CAPABILITY: standalone-capable
# Sourced by tests/run-tests.sh — uses $pass / $fail counters
#
# scripts/apply-workflow-hygiene.sh（.github/workflows/ の衛生是正 apply スクリプト）の
# 振る舞い回帰テスト。同スクリプトは PLANGATE_WF_DIR という sandbox シームを持つため
# 実 HO パスに一切触れずに全経路を検査できる。
#
#   TC-01: 引数 strict 検証（未知引数 / 引数過多 は exit 1）
#   TC-02: 対象ディレクトリ不在なら exit 1
#   TC-03: dry-run は sandbox の 1 ファイルも変更しない（cksum 全一致）
#   TC-04: --apply で (A) timeout-minutes / (B) concurrency / (C) permissions が入り、
#          結果が YAML として parse でき、timeout-minutes 欠落 job が 0 件になる
#   TC-05: 冪等 — 再実行は already applied で rc=0、かつ 1 バイトも変更しない
#   TC-06: アンカー未検出なら exit 1 かつ **全ファイルが不変**（部分適用しない）
#   TC-07: 実 HO パス（<repo>/.github/workflows）への --apply は
#          PLANGATE_APPLY_CONFIRM 無しでは exit 1 かつ 1 バイトも書かない
#
# 空振り防止: TC-04 は「FAIL が無い」ではなく「適用後に期待する構造が実在する」ことを
# 見る。TC-06 は「exit 1 になった」だけでなく「他ファイルの cksum が変わっていない」
# ことまで見る（部分適用は exit 1 でも起きうる）。
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
pg_extra_contract_init ta-74-workflow-hygiene-apply standalone-capable

if pg_extra_contract_is_standalone; then
  unset PLANGATE_SKIP_REASON PLANGATE_HOOK_TASK PLANGATE_HOOK_FILE PLANGATE_BYPASS_HOOK PLANGATE_HOOK_STRICT PG_HARNESS_SOURCED PLANGATE_ALLOW_MASS_DELETE 2>/dev/null || true
fi


printf '\n=== TA-74: apply-workflow-hygiene (workflow 衛生 apply スクリプト) ===\n'

t74_pass() { pass=$((pass + 1)); printf '  [PASS] %s\n' "$1"; }
t74_fail() { fail=$((fail + 1)); printf '  [FAIL] %s\n' "$1" >&2; }

_T74_ROOT="$(CDPATH= cd -- "$_pg_extra_dir/../.." && pwd)"
_T74_AP="$_T74_ROOT/scripts/apply-workflow-hygiene.sh"
_T74_WF="$_T74_ROOT/.github/workflows"

if [ ! -f "$_T74_AP" ]; then
  pg_extra_contract_skip "missing target script: $_T74_AP"
fi
if [ ! -d "$_T74_WF" ]; then
  pg_extra_contract_skip "missing workflows dir: $_T74_WF"
fi
if ! command -v python3 >/dev/null 2>&1; then
  pg_extra_contract_skip "python3 not available (apply スクリプトの本体が python3)"
fi

_T74_SB="$(mktemp -d)"
register_cleanup "$_T74_SB"
_T74_STRUCT="$_T74_SB/t74-struct-check.py"

# 適用結果の構造検査スクリプト（PyYAML 前提。sandbox に置く）
cat >"$_T74_STRUCT" <<'T74PY'
import glob, os, sys, yaml

wfd = os.environ["WFD"]
files = sorted(glob.glob(os.path.join(wfd, "*.yml")))
if not files:
    sys.exit("no workflow files")
no_timeout = []
no_conc = []
for p in files:
    d = yaml.safe_load(open(p, encoding="utf-8"))
    if "concurrency" not in d:
        no_conc.append(os.path.basename(p))
    for jid, job in (d.get("jobs") or {}).items():
        if "timeout-minutes" not in job:
            no_timeout.append("%s/%s" % (os.path.basename(p), jid))
if no_timeout:
    sys.exit("jobs without timeout-minutes: %s" % no_timeout)
if no_conc:
    sys.exit("workflows without concurrency: %s" % no_conc)

perm = yaml.safe_load(open(os.path.join(wfd, "check-pr-issue-link.yml"), encoding="utf-8"))
top = perm.get("permissions") or {}
if "pull-requests" in top:
    sys.exit("top-level still holds pull-requests: %s" % top)
jobperm = perm["jobs"]["check"].get("permissions") or {}
if jobperm.get("pull-requests") != "write":
    sys.exit("job scope lacks pull-requests write: %s" % jobperm)
print("ok files=%d timeout_missing=0 concurrency_missing=0" % len(files))
T74PY

# sandbox の workflows ディレクトリを毎回作り直す（前 TC の適用結果を持ち越さない）
_t74_fresh_wf() {
  rm -rf "$1"
  mkdir -p "$1"
  cp "$_T74_WF"/*.yml "$1/" 2>/dev/null || return 1
  return 0
}

# ディレクトリ内の全ファイルの cksum を 1 行にまとめる（部分適用の検出に使う）
_t74_digest() {
  for _t74_f in "$1"/*.yml; do
    [ -f "$_t74_f" ] || continue
    printf '%s %s\n' "$(basename "$_t74_f")" "$(cksum <"$_t74_f")"
  done
}

# --- TC-01 引数 strict 検証 ---
_t74_rc=0
_t74_out="$(sh "$_T74_AP" --definitely-not-a-flag 2>&1)" || _t74_rc=$?
_t74_rc2=0
_t74_out2="$(sh "$_T74_AP" --dry-run extra-arg 2>&1)" || _t74_rc2=$?
if [ "$_t74_rc" -eq 1 ] && printf '%s' "$_t74_out" | grep -q 'unknown argument' \
   && [ "$_t74_rc2" -eq 1 ] && printf '%s' "$_t74_out2" | grep -q 'too many arguments'; then
  t74_pass "TC-01 未知引数 / 引数過多とも exit 1 + 診断メッセージ"
else
  t74_fail "TC-01 引数 strict 検証が破れている (unknown rc=$_t74_rc / too-many rc=$_t74_rc2)"
fi

# --- TC-02 対象ディレクトリ不在 ---
_t74_rc=0
_t74_out="$(PLANGATE_WF_DIR="$_T74_SB/pg-absent-dir-xyz" sh "$_T74_AP" --dry-run 2>&1)" || _t74_rc=$?
if [ "$_t74_rc" -eq 1 ] && printf '%s' "$_t74_out" | grep -q 'workflows dir not found'; then
  t74_pass "TC-02 対象ディレクトリ不在で exit 1 + 診断メッセージ"
else
  t74_fail "TC-02 ディレクトリ不在の扱いが契約どおりでない (rc=$_t74_rc)"
fi

# --- TC-03 dry-run は 1 バイトも書かない ---
_T74_D1="$_T74_SB/wf-dryrun"
if ! _t74_fresh_wf "$_T74_D1"; then
  printf '  [SKIP] TC-03: workflows のコピーに失敗\n'
else
  _t74_before="$(_t74_digest "$_T74_D1")"
  _t74_rc=0
  _t74_out="$(PLANGATE_WF_DIR="$_T74_D1" sh "$_T74_AP" --dry-run 2>&1)" || _t74_rc=$?
  _t74_after="$(_t74_digest "$_T74_D1")"
  if [ "$_t74_rc" -eq 0 ] && [ "$_t74_before" = "$_t74_after" ] \
     && printf '%s' "$_t74_out" | grep -q 'WILL CHANGE' \
     && printf '%s' "$_t74_out" | grep -q 'dry-run'; then
    t74_pass "TC-03 dry-run は差分を出すが 1 バイトも書かない"
  else
    t74_fail "TC-03 dry-run が書き込んだ / 差分プレビューが出ない (rc=$_t74_rc)"
  fi
fi

# --- TC-04 / TC-05 適用と冪等 ---
_T74_D2="$_T74_SB/wf-apply"
if ! _t74_fresh_wf "$_T74_D2"; then
  printf '  [SKIP] TC-04/05: workflows のコピーに失敗\n'
else
  _t74_rc=0
  _t74_out="$(PLANGATE_WF_DIR="$_T74_D2" sh "$_T74_AP" --apply 2>&1)" || _t74_rc=$?
  _t74_applied="$(_t74_digest "$_T74_D2")"

  _t74_struct_rc=0
  _t74_struct=''
  if python3 -c 'import yaml' >/dev/null 2>&1; then
    _t74_struct="$(WFD="$_T74_D2" python3 "$_T74_STRUCT" 2>&1)" || _t74_struct_rc=$?
  else
    _t74_struct_rc=99
  fi

  _t74_rc2=0
  _t74_out2="$(PLANGATE_WF_DIR="$_T74_D2" sh "$_T74_AP" --apply 2>&1)" || _t74_rc2=$?
  _t74_again="$(_t74_digest "$_T74_D2")"

  if [ "$_t74_struct_rc" -eq 99 ]; then
    printf '  [SKIP] TC-04: python3 の PyYAML が無いため構造検査ができない\n'
  elif [ "$_t74_rc" -eq 0 ] && [ "$_t74_struct_rc" -eq 0 ]; then
    t74_pass "TC-04 --apply で (A)(B)(C) が入り YAML として整合する ($_t74_struct)"
  else
    t74_fail "TC-04 適用結果が期待どおりでない (rc=$_t74_rc / struct=$_t74_struct)"
  fi

  if [ "$_t74_rc2" -eq 0 ] && printf '%s' "$_t74_out2" | grep -q 'already applied' \
     && [ "$_t74_applied" = "$_t74_again" ]; then
    t74_pass "TC-05 冪等: 再実行は already applied で rc=0 かつ 1 バイトも変更しない"
  else
    t74_fail "TC-05 冪等でない (rc=$_t74_rc2)"
  fi
fi

# --- TC-06 アンカー未検出 → exit 1 かつ全ファイル不変（部分適用しない）---
_T74_D3="$_T74_SB/wf-noanchor"
if ! _t74_fresh_wf "$_T74_D3"; then
  printf '  [SKIP] TC-06: workflows のコピーに失敗\n'
else
  sed -e 's|^  analyze:$|  analyze-renamed:|' "$_T74_D3/codeql.yml" >"$_T74_SB/codeql.tmp"
  cp "$_T74_SB/codeql.tmp" "$_T74_D3/codeql.yml"
  rm -f "$_T74_SB/codeql.tmp"
  _t74_before="$(_t74_digest "$_T74_D3")"
  _t74_rc=0
  _t74_out="$(PLANGATE_WF_DIR="$_T74_D3" sh "$_T74_AP" --apply 2>&1)" || _t74_rc=$?
  _t74_after="$(_t74_digest "$_T74_D3")"
  if [ "$_t74_rc" -eq 1 ] \
     && printf '%s' "$_t74_out" | grep -q "anchor not found in codeql.yml" \
     && printf '%s' "$_t74_out" | grep -q '部分適用しない' \
     && [ "$_t74_before" = "$_t74_after" ]; then
    t74_pass "TC-06 アンカー未検出で exit 1 かつ全ファイル不変（部分適用しない）"
  else
    t74_fail "TC-06 アンカー検証 / 部分適用防止が破れている (rc=$_t74_rc)"
  fi
fi

# --- TC-07 実 HO パスへの --apply は確認必須 ---
# 実 workflows ディレクトリを対象にすると（ガードが壊れていた場合に）実ファイルを
# 書き換えてしまうため、**偽 repo root** を作って検査する。REPO_ROOT はスクリプト
# 自身の位置から導出されるので、偽 root 配下が既定の WF_DIR になる。
_T74_FR="$_T74_SB/fake-root"
mkdir -p "$_T74_FR/scripts"
cp "$_T74_AP" "$_T74_FR/scripts/apply-workflow-hygiene.sh"
_T74_FRWF="$_T74_FR/.github/workflows"
mkdir -p "$_T74_FR/.github"
if ! _t74_fresh_wf "$_T74_FRWF"; then
  printf '  [SKIP] TC-07: workflows のコピーに失敗\n'
else
  _t74_before="$(_t74_digest "$_T74_FRWF")"
  _t74_rc=0
  _t74_out="$(sh "$_T74_FR/scripts/apply-workflow-hygiene.sh" --apply 2>&1)" || _t74_rc=$?
  _t74_after="$(_t74_digest "$_T74_FRWF")"
  _t74_rc2=0
  _t74_out2="$(PLANGATE_APPLY_CONFIRM=1 sh "$_T74_FR/scripts/apply-workflow-hygiene.sh" --apply 2>&1)" || _t74_rc2=$?
  _t74_confirmed="$(_t74_digest "$_T74_FRWF")"
  if [ "$_t74_rc" -eq 1 ] && [ "$_t74_before" = "$_t74_after" ] \
     && printf '%s' "$_t74_out" | grep -q 'PLANGATE_APPLY_CONFIRM' \
     && [ "$_t74_rc2" -eq 0 ] && [ "$_t74_before" != "$_t74_confirmed" ]; then
    t74_pass "TC-07 実 HO パスへの --apply: 確認なしは exit 1 + 無変更 / 確認ありで適用"
  else
    t74_fail "TC-07 HO 書き込みガードが破れている (no-confirm rc=$_t74_rc / confirm rc=$_t74_rc2)"
  fi
fi

rm -rf "$_T74_SB"

pg_extra_contract_finalize
