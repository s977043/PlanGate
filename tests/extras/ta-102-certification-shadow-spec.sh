#!/bin/sh
# PG_EXTRA_CAPABILITY: standalone-capable
# TA-102 — Certification View non-authoritative executable spec (#1460).

if [ "${PG_HARNESS_SOURCED:-0}" = "1" ] && [ -n "${FIXTURES_DIR:-}" ] && [ -n "${EXTRAS_DIR:-}" ]; then
  _T102_MODE=harness
  _T102_DIR="$EXTRAS_DIR"
else
  _T102_MODE=standalone
  _T102_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
fi

_T102_HELPER="$_T102_DIR/_extra-contract.sh"
if [ ! -r "$_T102_HELPER" ]; then
  printf '  [FAIL] helper unresolved: %s\n' "$_T102_HELPER" >&2
  if [ "$_T102_MODE" = harness ]; then
    fail=$((fail + 1))
    return 0
  fi
  exit 1
fi

. "$_T102_HELPER"
pg_extra_contract_init ta-102-certification-shadow-spec standalone-capable

if pg_extra_contract_is_standalone; then
  unset PLANGATE_SKIP_REASON PLANGATE_HOOK_TASK PLANGATE_HOOK_FILE \
    PLANGATE_BYPASS_HOOK PLANGATE_HOOK_STRICT PG_HARNESS_SOURCED \
    PLANGATE_ALLOW_MASS_DELETE 2>/dev/null || true
fi

if [ "$_T102_MODE" = harness ]; then
  _T102_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
else
  _T102_ROOT="${_T102_DIR%/tests/extras}"
fi

printf 'TA-102: Certification View executable specification\n'

_T102_RC=0
_T102_OUT=$(python3 "$_T102_ROOT/tests/test_certification_shadow_spec.py" 2>&1) || _T102_RC=$?
printf '%s\n' "$_T102_OUT"

if [ "$_T102_RC" -ne 0 ]; then
  printf '  [FAIL] certification shadow spec failed (rc=%s)\n' "$_T102_RC" >&2
  fail=$((fail + 1))
elif printf '%s\n' "$_T102_OUT" | grep -Eq '^Ran [1-9][0-9]* tests? in '; then
  printf '  [PASS] certification shadow executable spec ran non-zero tests\n'
  pass=$((pass + 1))
else
  printf '  [FAIL] certification shadow spec reported no non-zero test count\n' >&2
  fail=$((fail + 1))
fi

# Mode A must remain tests-only. Production paths must not import the test spec.
_t102_prod_refs() {
  git -C "$1" grep -lF 'test_certification_shadow_spec' -- 'scripts' 'bin' 'plugin' 2>/dev/null || true
}

_t102_design_contract_ok() {
  _t102_design_doc="$1/docs/ai/ai-loop-v2/evidence-certification-promotion.md"
  [ -f "$_t102_design_doc" ] &&
    grep -qF 'Certification View (projection only)' "$_t102_design_doc" &&
    grep -qF 'The Certification View MUST NOT emit or own:' "$_t102_design_doc" &&
    grep -qF 'Decision Engine artifact_verdicts(inputs)' "$_t102_design_doc"
}

_t102_owner_seam_refs() {
  python3 - "$1" <<'PY'
import ast
import subprocess
import sys
from pathlib import Path

root = Path(sys.argv[1])
proc = subprocess.run(
    ["git", "-C", str(root), "ls-files", "scripts/ai-loop-v2/*.py"],
    check=False,
    capture_output=True,
    text=True,
)
if proc.returncode != 0:
    raise SystemExit(proc.returncode)

for rel in sorted(line for line in proc.stdout.splitlines() if line):
    path = root / rel
    try:
        tree = ast.parse(path.read_text(encoding="utf-8"), filename=rel)
    except (OSError, SyntaxError) as exc:
        print(f"PARSE_ERROR:{rel}:{type(exc).__name__}")
        continue
    for node in ast.walk(tree):
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)) and node.name == "artifact_verdicts":
            print(f"{rel}:{node.lineno}:def artifact_verdicts")
PY
}

_T102_PROBE=$(mktemp -d)
register_cleanup "$_T102_PROBE"
mkdir -p "$_T102_PROBE/scripts" "$_T102_PROBE/bin" "$_T102_PROBE/plugin/plangate/skills/demo/scripts"
git -C "$_T102_PROBE" init -q
printf 'import test_certification_shadow_spec\n' >"$_T102_PROBE/scripts/leak.py"
printf 'import test_certification_shadow_spec\n' >"$_T102_PROBE/plugin/plangate/skills/demo/scripts/leak.py"
printf 'print("ok")\n' >"$_T102_PROBE/scripts/ok.py"
printf '#!/bin/sh\nexit 0\n' >"$_T102_PROBE/bin/ok"
mkdir -p "$_T102_PROBE/scripts/ai-loop-v2"
printf '# artifact_verdicts mention only; must not trigger\n' >"$_T102_PROBE/scripts/ai-loop-v2/comment_only.py"
printf 'def artifact_verdicts():\n    return {}\n' >"$_T102_PROBE/scripts/ai-loop-v2/owner.py"
mkdir -p "$_T102_PROBE/docs/ai/ai-loop-v2"
cat >"$_T102_PROBE/docs/ai/ai-loop-v2/evidence-certification-promotion.md" <<'EOF'
Certification View (projection only)
The Certification View MUST NOT emit or own:
Decision Engine artifact_verdicts(inputs)
EOF
git -C "$_T102_PROBE" add scripts bin plugin docs
_T102_PROBE_GOT=$(_t102_prod_refs "$_T102_PROBE")
_T102_SEAM_PROBE_GOT=$(_t102_owner_seam_refs "$_T102_PROBE")

_T102_PROBE_WANT='plugin/plangate/skills/demo/scripts/leak.py
scripts/leak.py'
if [ "$_T102_PROBE_GOT" = "$_T102_PROBE_WANT" ]; then
  printf '  [PASS] production-reference detector positive controls (source + plugin)\n'
  pass=$((pass + 1))
else
  printf '  [FAIL] production-reference detector missed planted leak(s):\n%s\n' "$_T102_PROBE_GOT" >&2
  fail=$((fail + 1))
fi

if [ "$_T102_SEAM_PROBE_GOT" = "scripts/ai-loop-v2/owner.py:1:def artifact_verdicts" ]; then
  printf '  [PASS] owner-seam AST tripwire positive/negative controls\n'
  pass=$((pass + 1))
else
  printf '  [FAIL] owner-seam AST tripwire mismatch:\n%s\n' "$_T102_SEAM_PROBE_GOT" >&2
  fail=$((fail + 1))
fi

printf 'def broken(:\n' >"$_T102_PROBE/scripts/ai-loop-v2/broken.py"
git -C "$_T102_PROBE" add scripts/ai-loop-v2/broken.py
_T102_PARSE_PROBE_GOT=$(_t102_owner_seam_refs "$_T102_PROBE")
case "$_T102_PARSE_PROBE_GOT" in
  *'PARSE_ERROR:scripts/ai-loop-v2/broken.py:SyntaxError'*)
    printf '  [PASS] owner-seam parser-error positive control\n'
    pass=$((pass + 1))
    ;;
  *)
    printf '  [FAIL] owner-seam parser-error control did not fail closed:\n%s\n' "$_T102_PARSE_PROBE_GOT" >&2
    fail=$((fail + 1))
    ;;
esac
rm -f "$_T102_PROBE/scripts/ai-loop-v2/broken.py"
git -C "$_T102_PROBE" rm --cached -q scripts/ai-loop-v2/broken.py

if _t102_design_contract_ok "$_T102_PROBE"; then
  printf '  [PASS] design-contract detector positive control\n'
  pass=$((pass + 1))
else
  printf '  [FAIL] design-contract detector rejected complete fixture\n' >&2
  fail=$((fail + 1))
fi
sed '/Decision Engine artifact_verdicts(inputs)/d'   "$_T102_PROBE/docs/ai/ai-loop-v2/evidence-certification-promotion.md"   >"$_T102_PROBE/docs/ai/ai-loop-v2/evidence-certification-promotion.md.tmp"
mv "$_T102_PROBE/docs/ai/ai-loop-v2/evidence-certification-promotion.md.tmp"   "$_T102_PROBE/docs/ai/ai-loop-v2/evidence-certification-promotion.md"
if _t102_design_contract_ok "$_T102_PROBE"; then
  printf '  [FAIL] design-contract detector accepted missing owner-parity marker\n' >&2
  fail=$((fail + 1))
else
  printf '  [PASS] design-contract detector negative control\n'
  pass=$((pass + 1))
fi

rm -rf "$_T102_PROBE"
if [ ! -e "$_T102_PROBE" ]; then
  printf '  [PASS] positive-control repository cleaned up\n'
  pass=$((pass + 1))
else
  printf '  [FAIL] positive-control repository cleanup failed: %s\n' "$_T102_PROBE" >&2
  fail=$((fail + 1))
fi

_T102_GOT=$(_t102_prod_refs "$_T102_ROOT")
if [ -n "$_T102_GOT" ]; then
  printf '  [FAIL] production path imports/references certification test spec:\n%s\n' "$_T102_GOT" >&2
  fail=$((fail + 1))
else
  printf '  [PASS] certification spec is not imported by production paths\n'
  pass=$((pass + 1))
fi

if _t102_design_contract_ok "$_T102_ROOT"; then
  printf '  [PASS] stacked Certification design contract is present\n'
  pass=$((pass + 1))
else
  printf '  [FAIL] Certification design contract missing or changed; review #1459/#1460 dependency\n' >&2
  fail=$((fail + 1))
fi

_T102_OWNER_SEAM=$(_t102_owner_seam_refs "$_T102_ROOT")
case "$_T102_OWNER_SEAM" in
  *PARSE_ERROR:*)
    printf '  [FAIL] owner-seam scan could not parse production Python; Mode A preflight is invalid:\n%s\n' "$_T102_OWNER_SEAM" >&2
    fail=$((fail + 1))
    ;;
  '')
    printf '  [PASS] owner artifact_verdicts seam still absent; Mode A preflight remains valid\n'
    pass=$((pass + 1))
    ;;
  *)
    printf '  [FAIL] owner artifact_verdicts seam detected; re-run #1460 preflight before keeping Mode A:\n%s\n' "$_T102_OWNER_SEAM" >&2
    fail=$((fail + 1))
    ;;
esac

pg_extra_contract_finalize
