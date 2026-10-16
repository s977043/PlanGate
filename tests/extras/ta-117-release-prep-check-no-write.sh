#!/bin/sh
# PG_EXTRA_CAPABILITY: standalone-capable
# TA-117 — release-prep.sh --check must not write docs/changelog.md (#1496).
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
pg_extra_contract_init ta-117-release-prep-check-no-write standalone-capable

if [ "$_pg_extra_mode" = harness ]; then
  _T117_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
else
  _T117_ROOT="${_pg_extra_dir%/tests/extras}"
fi

printf 'TA-117: release-prep --check leaves the work tree untouched (#1496)\n'

_t117_ok() { printf '  [PASS] %s\n' "$1"; pass=$((pass + 1)); }
_t117_ng() { printf '  [FAIL] %s\n' "$1" >&2; fail=$((fail + 1)); }

# $1 = sandbox dir, $2 = 1 なら CHANGELOG.md を置く
_t117_fixture() {
  mkdir -p "$1/scripts" "$1/docs"
  cp "$_T117_ROOT/scripts/release-prep.sh" "$_T117_ROOT/scripts/sync-release-docs.sh" "$1/scripts/"
  if [ "$2" = 1 ]; then
    printf '# Changelog\n\n## Unreleased\n\n## v1.0.0 - 2026-01-01\n- new entry\n' > "$1/CHANGELOG.md"
  fi
  printf '# Changelog\n\nstale content\n' > "$1/docs/changelog.md"
  git -C "$1" init -q
  git -C "$1" -c user.name=t -c user.email=t@example.invalid add -A
  git -C "$1" -c user.name=t -c user.email=t@example.invalid commit -qm fixture
}

_T117_SB="$(mktemp -d "${TMPDIR:-/tmp}/ta117.XXXXXX")"
register_cleanup "$_T117_SB"
_t117_fixture "$_T117_SB/unsynced" 1
_t117_fixture "$_T117_SB/nosrc" 0

# TC-01: 未同期 fixture で --check しても作業ツリーは不変
_t117_out="$(sh "$_T117_SB/unsynced/scripts/release-prep.sh" --check 2>&1)" && _t117_rc=0 || _t117_rc=$?
_t117_st="$(git -C "$_T117_SB/unsynced" status --porcelain)"
if [ -z "$_t117_st" ]; then
  _t117_ok "TC-01 --check does not modify the work tree"
else
  _t117_ng "TC-01 --check modified the work tree: $_t117_st"
fi

# TC-02: NG を返し、同期コマンドを表示する
if [ "$_t117_rc" -ne 0 ] \
  && printf '%s\n' "$_t117_out" | grep -q '^NG: docs/changelog.md が未同期' \
  && printf '%s\n' "$_t117_out" | grep -q 'sh scripts/sync-release-docs.sh'; then
  _t117_ok "TC-02 unsynced changelog reported as NG with sync command (rc=$_t117_rc)"
else
  _t117_ng "TC-02 expected NG + sync command, rc=$_t117_rc out=$(printf '%s' "$_t117_out" | grep changelog)"
fi

# TC-03 (positive control): fixture は本当に未同期で、同期後は --check が OK になる
sh "$_T117_SB/unsynced/scripts/sync-release-docs.sh" >/dev/null 2>&1 || true
if [ -n "$(git -C "$_T117_SB/unsynced" status --porcelain)" ] \
  && sh "$_T117_SB/unsynced/scripts/release-prep.sh" --check 2>&1 | grep -q '^OK: docs/changelog.md'; then
  _t117_ok "TC-03 positive control: fixture was unsynced and sync turns the check OK"
else
  _t117_ng "TC-03 positive control failed (fixture not unsynced or check never OK)"
fi

# TC-04: 同期判定そのものが失敗（CHANGELOG.md 欠如）したら「判定エラー」の NG、作業ツリー不変
_t117_out="$(sh "$_T117_SB/nosrc/scripts/release-prep.sh" --check 2>&1)" && _t117_rc=0 || _t117_rc=$?
if [ "$_t117_rc" -ne 0 ] \
  && printf '%s\n' "$_t117_out" | grep -q '^NG: docs/changelog.md の同期判定エラー (rc=1)' \
  && ! printf '%s\n' "$_t117_out" | grep -q 'docs/changelog.md が未同期' \
  && [ -z "$(git -C "$_T117_SB/nosrc" status --porcelain)" ]; then
  _t117_ok "TC-04 sync-check error reported as judgement error NG (rc=$_t117_rc)"
else
  _t117_ng "TC-04 expected judgement-error NG, rc=$_t117_rc out=$(printf '%s' "$_t117_out" | grep changelog)"
fi

unset _t117_out _t117_rc _t117_st 2>/dev/null || true

pg_extra_contract_finalize
