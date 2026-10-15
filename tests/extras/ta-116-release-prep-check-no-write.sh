#!/bin/sh
# PG_EXTRA_CAPABILITY: standalone-capable
# TA-116 — release-prep.sh --check must not write docs/changelog.md (#1496).
#
# 隔離: 実 repo は読むだけ。release-prep.sh / sync-release-docs.sh を mktemp -d の
# 合成 git repo へ複製し、その中で --check を実行する。

if [ "${PG_HARNESS_SOURCED:-0}" = "1" ] && [ -n "${FIXTURES_DIR:-}" ] && [ -n "${EXTRAS_DIR:-}" ]; then
  _pg_extra_mode=harness
  _pg_extra_dir="$EXTRAS_DIR"
else
  _pg_extra_mode=standalone
  _pg_extra_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
  unset PLANGATE_SKIP_REASON PLANGATE_HOOK_TASK PLANGATE_HOOK_FILE \
    PLANGATE_BYPASS_HOOK PLANGATE_HOOK_STRICT PG_HARNESS_SOURCED \
    PLANGATE_ALLOW_MASS_DELETE 2>/dev/null || true
fi

_pg_extra_helper="$_pg_extra_dir/_extra-contract.sh"
if [ ! -r "$_pg_extra_helper" ]; then
  printf '  [FAIL] helper unresolved: %s\n' "$_pg_extra_helper" >&2
  if [ "$_pg_extra_mode" = harness ]; then fail=$((fail + 1)); return 0; fi
  exit 1
fi
. "$_pg_extra_helper"
pg_extra_contract_init ta-116-release-prep-check-no-write standalone-capable

if [ "$_pg_extra_mode" = harness ]; then
  _T116_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
else
  _T116_ROOT="${_pg_extra_dir%/tests/extras}"
fi

printf 'TA-116: release-prep --check leaves the work tree untouched (#1496)\n'

_t116_ok() { printf '  [PASS] %s\n' "$1"; pass=$((pass + 1)); }
_t116_ng() { printf '  [FAIL] %s\n' "$1" >&2; fail=$((fail + 1)); }

_T116_SB="$(mktemp -d "${TMPDIR:-/tmp}/ta116.XXXXXX")"
register_cleanup "$_T116_SB"
mkdir -p "$_T116_SB/scripts" "$_T116_SB/docs"
cp "$_T116_ROOT/scripts/release-prep.sh" "$_T116_ROOT/scripts/sync-release-docs.sh" "$_T116_SB/scripts/"
printf '# Changelog\n\n## Unreleased\n\n## v1.0.0 - 2026-01-01\n- new entry\n' > "$_T116_SB/CHANGELOG.md"
printf '# Changelog\n\nstale content\n' > "$_T116_SB/docs/changelog.md"
git -C "$_T116_SB" init -q
git -C "$_T116_SB" -c user.name=t -c user.email=t@example.invalid add -A
git -C "$_T116_SB" -c user.name=t -c user.email=t@example.invalid commit -qm fixture

# TC-01: 未同期 fixture で --check しても作業ツリーは不変
_t116_out="$(sh "$_T116_SB/scripts/release-prep.sh" --check 2>&1)" && _t116_rc=0 || _t116_rc=$?
_t116_st="$(git -C "$_T116_SB" status --porcelain)"
if [ -z "$_t116_st" ]; then
  _t116_ok "TC-01 --check does not modify the work tree"
else
  _t116_ng "TC-01 --check modified the work tree: $_t116_st"
fi

# TC-02: NG を返し、同期コマンドを表示する
if [ "$_t116_rc" -ne 0 ] \
  && printf '%s\n' "$_t116_out" | grep -q '^NG: docs/changelog.md' \
  && printf '%s\n' "$_t116_out" | grep -q 'sh scripts/sync-release-docs.sh'; then
  _t116_ok "TC-02 unsynced changelog reported as NG with sync command (rc=$_t116_rc)"
else
  _t116_ng "TC-02 expected NG + sync command, rc=$_t116_rc out=$(printf '%s' "$_t116_out" | grep changelog)"
fi

# TC-03 (positive control): fixture は本当に未同期で、同期後は --check が OK になる
sh "$_T116_SB/scripts/sync-release-docs.sh" >/dev/null 2>&1 || true
if [ -n "$(git -C "$_T116_SB" status --porcelain)" ] \
  && sh "$_T116_SB/scripts/release-prep.sh" --check 2>&1 | grep -q '^OK: docs/changelog.md'; then
  _t116_ok "TC-03 positive control: fixture was unsynced and sync turns the check OK"
else
  _t116_ng "TC-03 positive control failed (fixture not unsynced or check never OK)"
fi

if [ "$_pg_extra_mode" = standalone ]; then
  rm -rf "$_T116_SB"
  printf 'TA-116 result: pass=%s fail=%s\n' "$pass" "$fail"
  [ "$fail" -eq 0 ]
fi
