#!/bin/sh
# PG_EXTRA_CAPABILITY: standalone-capable
# TA-90 — Context Lifecycle integration contract (#1410 / R1 follow-up #1429).
#
# Residual threat model: these checks are grep/regex based. They detect the known
# regression shapes (dropped trigger lists, keyword-preserving negation, contradictory
# appended rules, renamed duplicate schemas, distribution drift), but they do not
# prove the meaning of the prose. Where a pattern list kept leaking (TC-02 MUST list,
# TC-09 PreCompact section) the text is pinned to an exact expected value instead, so
# an intended doc change fails here until the expectation is updated after C-4 review.
# Not detected: claims that avoid every pinned/listed surface (e.g. a PreCompact claim
# that never names PreCompact), and schemas whose names miss the TC-07 globs. The
# guarantor of semantic correctness is C-4 Human review; this file is one layer of
# defense in depth, not a completeness claim.

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
pg_extra_contract_init ta-90-context-lifecycle standalone-capable

if pg_extra_contract_is_standalone; then
  unset PLANGATE_SKIP_REASON PLANGATE_HOOK_TASK PLANGATE_HOOK_FILE \
    PLANGATE_BYPASS_HOOK PLANGATE_HOOK_STRICT PG_HARNESS_SOURCED \
    PLANGATE_ALLOW_MASS_DELETE 2>/dev/null || true
fi

if [ "$_pg_extra_mode" = harness ]; then
  _T90_ROOT="$(CDPATH= cd -- "$FIXTURES_DIR/../.." && pwd)"
else
  _T90_ROOT="${_pg_extra_dir%/tests/extras}"
fi

_T90_DOC="$_T90_ROOT/docs/ai/context-lifecycle.md"
_T90_WA="$_T90_ROOT/.agents/skills/working-context/SKILL.md"
_T90_WC="$_T90_ROOT/.codex/skills/working-context/SKILL.md"
_T90_WP="$_T90_ROOT/plugin/plangate/skills/working-context/SKILL.md"
_T90_CA="$_T90_ROOT/.agents/skills/context-packager/SKILL.md"
_T90_CC="$_T90_ROOT/.codex/skills/context-packager/SKILL.md"
_T90_CP="$_T90_ROOT/plugin/plangate/skills/context-packager/SKILL.md"
_T90_LA="$_T90_ROOT/.agents/skills/local-exec-handoff/SKILL.md"
_T90_LC="$_T90_ROOT/.codex/skills/local-exec-handoff/SKILL.md"
_T90_LP="$_T90_ROOT/plugin/plangate/skills/local-exec-handoff/SKILL.md"
# Existing schema files that legitimately match the TC-07 globs (space separated
# basenames). Empty today; add a name here only with a reviewed reason.
_T90_SCHEMA_ALLOW=""
_T90_UPDATE_HINT="if the doc was changed on purpose, review it at C-4 and update the expected value in ta-90"

# Allowlists: exact existing lines only (no keyword-based exemptions).
_T90_ALLOW_LIGHT_SKILL='ultra-light / light では上記の「必須」も任意とする。`docs/ai/context-lifecycle.md` §8'
_T90_ALLOW_LIGHT_DOC='For `ultra-light` / `light` tasks these triggers are optional (see §8: simple tasks do not'
_T90_ALLOW_CPJSON_DOC='No new `checkpoint.json`, Context Manifest, or RunState is introduced by this policy.'
_T90_ALLOW_TRANSCRIPT='- **生の会話履歴（raw transcript）は packet に含めず、受け手にも渡さない**。受け手は canonical state（`INDEX.md` → `current-state.md` → phase-required L1）から fresh context で再開する（Context Lifecycle: `docs/ai/context-lifecycle.md`。導入先で解決できなくても本ルールは維持する）'

printf 'TA-90: Context Lifecycle integration contract (#1410)\n'

_t90_pass() {
  printf '  [PASS] %s\n' "$1"
  pass=$((pass + 1))
}

_t90_fail() {
  printf '  [FAIL] %s\n' "$1" >&2
  fail=$((fail + 1))
}

# One sentence per output line. Headings, table rows, and list items start a new
# sentence; paragraph lines are joined before splitting on sentence punctuation.
_t90_sentences() {
  awk '
    function flush(   n, i) {
      if (buf == "") return
      n = split(buf, parts, /[.!?][*`]*[[:space:]]+/)
      for (i = 1; i <= n; i++) if (parts[i] ~ /[^[:space:]]/) print parts[i]
      buf = ""
    }
    /^[[:space:]]*$/ { flush(); next }
    /^#/ || /^\|/ { flush(); buf = $0; flush(); next }
    /^[[:space:]]*([-*]|[0-9]+\.)[[:space:]]/ { flush() }
    { sub(/^[[:space:]]+/, ""); buf = (buf == "" ? $0 : buf " " $0) }
    END { flush() }
  ' "$1"
}

# Body of doc §3 (Fresh-context triggers), up to the next "## " heading.
_t90_doc_s3() {
  awk '/^## 3\./ { f = 1; next } /^## / { f = 0 } f' "$_T90_DOC"
}

# §3 MUST block: from the MUST heading up to (not including) the next heading.
_t90_must_block() {
  _t90_doc_s3 | awk '/^### MUST/ { f = 1; print; next } /^#/ { f = 0 } f'
}

_t90_expect_must_block() {
  cat <<'EOF'
### MUST checkpoint and restart from canonical state (standard mode and above)

For `ultra-light` / `light` tasks these triggers are optional (see §8: simple tasks do not
gain mandatory ceremony). The same rule is stated in the `working-context` skill.

1. worker / agent / model / runtime changes;
2. an independent reviewer starts;
3. a task is handed from implementer to reviewer or between workers;
4. execution is intentionally interrupted because of an external wait or usage limit.
EOF
}

# §7 PreCompact subsection: from its heading up to (not including) the next heading.
_t90_precompact_section() {
  awk '/^### PreCompact memory guard/ { f = 1; print; next } /^#/ { f = 0 } f' "$_T90_DOC"
}

_t90_expect_precompact_section() {
  cat <<'EOF'
### PreCompact memory guard (#742)

The guard specification, staging script, apply script, and tests exist. **Do not infer that
the Human-owned PreCompact wiring is active from this document.** Its enforcement status
depends on the target environment's settings / Human-applied wiring.

When the guard is actually wired, it is a safety net for stale task memory before compact.
This policy defines what to do with a valid checkpoint afterward: resume from canonical
artifacts rather than replaying conversation history.
EOF
}

# Every doc line that names PreCompact (case-insensitive), anywhere in the doc.
_t90_expect_precompact_lines() {
  cat <<'EOF'
| Compact-time freshness | PreCompact memory guard (#742) | reuse |
### PreCompact memory guard (#742)
the Human-owned PreCompact wiring is active from this document.** Its enforcement status
EOF
}

# Lines naming light (word match) together with a mandatory marker, minus exact allowlist.
_t90_light_mandatory_lines() {
  { grep -i -E '(^|[^[:alnum:]_])light([^[:alnum:]_]|$)' "$1" |
    grep -i -E '必須|mandatory|must' |
    grep -v -x -F -e "$_T90_ALLOW_LIGHT_SKILL" -e "$_T90_ALLOW_LIGHT_DOC"; } || true
}

if [ -r "$_T90_DOC" ]; then
  _t90_pass "TC-01 integration map exists"
else
  _t90_fail "TC-01 integration map missing"
fi

_t90_must_act="$(_t90_must_block)"
_t90_rr_bad="$({ _t90_sentences "$_T90_DOC" | grep -i 'River Review' | grep -i 'memory' |
  grep -v 'does not own'; } || true)"
if grep -q 'Fresh-context triggers' "$_T90_DOC" &&
   [ "$_t90_must_act" = "$(_t90_expect_must_block)" ] &&
   _t90_doc_s3 | grep -q '^### SHOULD' &&
   grep -q 'No new .*checkpoint.json' "$_T90_DOC" &&
   grep -q 'River Review does not own execution-session memory' "$_T90_DOC" &&
   [ -z "$_t90_rr_bad" ]; then
  _t90_pass "TC-02 owner, triggers, and no-second-SSoT boundary documented"
else
  _t90_fail "TC-02 lifecycle boundary text incomplete (MUST block pinned: $_T90_UPDATE_HINT; River Review+memory sentences without 'does not own': [$_t90_rr_bad])"
fi

if grep -q 'worker / agent / model / runtime' "$_T90_WA" &&
   grep -q 'L0 → phase-required L1 → L2/L3 on demand' "$_T90_WA" &&
   grep -q 'raw chat transcript' "$_T90_WA"; then
  _t90_pass "TC-03 working-context carries fresh-context transition contract"
else
  _t90_fail "TC-03 working-context lifecycle contract incomplete"
fi

if grep -q 'conversation history の圧縮コピーではない' "$_T90_CA" &&
   grep -q 'review package + diff + evidence' "$_T90_CA" &&
   grep -q 'missing / stale' "$_T90_CA"; then
  _t90_pass "TC-04 context-packager is history-independent and fail-safe"
else
  _t90_fail "TC-04 context-packager handoff contract incomplete"
fi

if cmp -s "$_T90_WA" "$_T90_WC" && cmp -s "$_T90_WA" "$_T90_WP"; then
  _t90_pass "TC-05 working-context distributed surfaces are byte-identical"
else
  _t90_fail "TC-05 working-context distribution drift"
fi

if cmp -s "$_T90_CA" "$_T90_CC" && cmp -s "$_T90_CA" "$_T90_CP"; then
  _t90_pass "TC-06 context-packager distributed surfaces are byte-identical"
else
  _t90_fail "TC-06 context-packager distribution drift"
fi

_t90_schema_hits=""
for _t90_f in "$_T90_ROOT"/schemas/*checkpoint* "$_T90_ROOT"/schemas/*context*state* \
              "$_T90_ROOT"/schemas/*lifecycle*; do
  [ -e "$_t90_f" ] || continue
  case " $_T90_SCHEMA_ALLOW " in
    *" ${_t90_f##*/} "*) continue ;;
  esac
  _t90_schema_hits="$_t90_schema_hits ${_t90_f##*/}"
done
if [ -z "$_t90_schema_hits" ]; then
  _t90_pass "TC-07 no duplicate checkpoint/context state schema introduced"
else
  _t90_fail "TC-07 duplicate checkpoint/context state schema detected:$_t90_schema_hits"
fi

if grep -q 'Do not persist or mechanically replay' "$_T90_DOC" &&
   grep -q 'hidden chain-of-thought' "$_T90_DOC" &&
   grep -q 'credentials, secrets, or personal data' "$_T90_DOC"; then
  _t90_pass "TC-08 privacy and raw-history exclusions documented"
else
  _t90_fail "TC-08 privacy/history exclusions incomplete"
fi

_t90_pc_lines="$(grep -i 'precompact' "$_T90_DOC" || true)"
if [ "$(_t90_precompact_section)" = "$(_t90_expect_precompact_section)" ] &&
   [ "$_t90_pc_lines" = "$(_t90_expect_precompact_lines)" ] &&
   grep -q '#938 remains the owner' "$_T90_DOC"; then
  _t90_pass "TC-09 staged enforcement and open wait/resume ownership stay explicit"
else
  _t90_fail "TC-09 PreCompact section / PreCompact mentions differ from the pinned text or #938 ownership missing ($_T90_UPDATE_HINT)"
fi

_t90_lm=""
for _t90_f in "$_T90_WA" "$_T90_WC" "$_T90_WP" "$_T90_DOC"; do
  _t90_hit="$(_t90_light_mandatory_lines "$_t90_f")"
  if [ -n "$_t90_hit" ]; then _t90_lm="$_t90_lm [${_t90_f#"$_T90_ROOT"/}: $_t90_hit]"; fi
done
_t90_cj=""
for _t90_f in "$_T90_WA" "$_T90_WC" "$_T90_WP" "$_T90_DOC"; do
  _t90_hit="$({ grep 'checkpoint\.json' "$_t90_f" | grep -v -x -F -e "$_T90_ALLOW_CPJSON_DOC"; } || true)"
  if [ -n "$_t90_hit" ]; then _t90_cj="$_t90_cj [${_t90_f#"$_T90_ROOT"/}: $_t90_hit]"; fi
done
if grep -q '必須（standard 以上）' "$_T90_WA" &&
   grep -q -x -F -e "$_T90_ALLOW_LIGHT_SKILL" "$_T90_WA" &&
   grep -q 'simple tasks do not gain mandatory ceremony' "$_T90_DOC" &&
   _t90_doc_s3 | grep -q -x -F -e "$_T90_ALLOW_LIGHT_DOC" &&
   [ -z "$_t90_lm" ] && [ -z "$_t90_cj" ]; then
  _t90_pass "TC-10 mandatory checkpoints are mode-scoped consistent with §8"
else
  _t90_fail "TC-10 mandatory checkpoints not mode-scoped (light+mandatory lines:${_t90_lm:- none}; checkpoint.json lines:${_t90_cj:- none})"
fi

_t90_tr=""
for _t90_f in "$_T90_LA" "$_T90_LC" "$_T90_LP"; do
  _t90_hit="$({ grep -i 'transcript' "$_t90_f" |
    grep -i -E '添付|含め|渡し|attach|include|pass' |
    grep -v -x -F -e "$_T90_ALLOW_TRANSCRIPT"; } || true)"
  if [ -n "$_t90_hit" ]; then _t90_tr="$_t90_tr [${_t90_f#"$_T90_ROOT"/}: $_t90_hit]"; fi
done
if cmp -s "$_T90_LA" "$_T90_LC" && cmp -s "$_T90_LA" "$_T90_LP" &&
   grep -q -x -F -e "$_T90_ALLOW_TRANSCRIPT" "$_T90_LA" &&
   [ -z "$_t90_tr" ]; then
  _t90_pass "TC-11 local-exec-handoff resumes from canonical state (3 surfaces byte-identical)"
else
  _t90_fail "TC-11 local-exec-handoff transcript rule missing, permitted elsewhere, or distribution drift (transcript-permitting lines:${_t90_tr:- none})"
fi

pg_extra_contract_finalize
