#!/bin/sh
# PG_EXTRA_CAPABILITY: standalone-capable
# TA-90 — Context Lifecycle integration contract (#1410 / R1 follow-up #1429).
#
# Residual threat model (design: pin the normative core, keep heuristics as one
# auxiliary layer, name what is not detected):
# - Pinned to an exact expected value: doc §3 MUST block (TC-02), doc §7 PreCompact
#   section and every doc line naming PreCompact (TC-09), the working-context trigger
#   block (TC-10), the local-exec-handoff transcript rule (TC-11). Any edit inside a
#   pinned range fails until the expectation is updated after C-4 review.
# - Auxiliary heuristics run on sentences (not lines). Anchor words are matched after
#   removing non-alphanumerics and lower-casing (PreCompact / River Review variants).
#   Exemptions are exact-sentence allowlists only.
# - Not detected: synonym / subject / verb rewording outside the pinned ranges (e.g. a
#   rule for "all modes" that never says light, "required" instead of 必須, "送付"
#   instead of 添付, "会話ログ全文" instead of transcript); claims in files this test
#   does not read; claims that never name PreCompact or River Review; schemas whose
#   names miss every TC-07 pattern (checkpoint / context*state / lifecycle / snapshot /
#   session); non-ASCII homoglyphs and full-width letters in anchor words (the
#   normalization drops them, e.g. Cyrillic "а" in PreCompаct or ＰｒｅＣｏｍｐａｃｔ);
#   sentences cut by an in-sentence ". " (cf. / approx. / v2.), which splits the anchor
#   and the claim into separate sentences.
# - Guarantor of semantic correctness is C-4 Human review; this file is one layer of
#   defense in depth, not a completeness claim.

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
_T90_UPDATE_HINT="if the text was changed on purpose, review it at C-4 and update the expected value in ta-90"

# Exact-sentence allowlists (sentences as produced by _t90_sentences).
_T90_ALLOW_RR_MEMORY='**River Review does not own execution-session memory'
_T90_ALLOW_CPJSON_DOC='No new `checkpoint.json`, Context Manifest, or RunState is introduced by this policy.'
_T90_ALLOW_LIGHT_DOC='For `ultra-light` / `light` tasks these triggers are optional (see §8: simple tasks do not gain mandatory ceremony)'
_T90_ALLOW_LIGHT_SKILL='ultra-light / light では上記の「必須」も任意とする。`docs/ai/context-lifecycle.md` §8 （simple tasks do not gain mandatory ceremony）を満たすため、既存の working-context ファイル以上の checkpoint を簡易タスクへ課さない。'
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
  ' "$1" 2>/dev/null
}

# stdin lines whose normalized form (ASCII alphanumerics only, lower-cased) contains $1.
_t90_anchor() {
  LC_ALL=C awk -v a="$1" '{ s = $0; gsub(/[^A-Za-z0-9]/, "", s); s = tolower(s); if (index(s, a)) print }'
}

# Body of doc §3 (Fresh-context triggers), up to the next "## " heading.
_t90_doc_s3() {
  awk '/^## 3\./ { f = 1; next } /^## / { f = 0 } f' "$_T90_DOC" 2>/dev/null
}

# Pinned block of stdin: from the first heading line starting with $1 up to (not
# including) the next heading of the same or a higher level (#### etc. stay inside).
_t90_block() {
  awk -v h="$1" '
    f && /^#+[[:space:]]/ { match($0, /^#+/); if (RLENGTH <= lvl) { f = 0; done = 1 } }
    !f && !done && index($0, h) == 1 { f = 1; match($0, /^#+/); lvl = RLENGTH }
    f
  '
}

# Expected vs actual block for a failing pin: indented detail lines on stderr (no
# extra [FAIL] lines), first 20 differing lines.
_t90_show_diff() {
  { printf '%s\n' "$1"; printf '%s\n' '@@T90-ACTUAL@@'; printf '%s\n' "$2"; } |
    LC_ALL=C awk '
      !a && $0 == "@@T90-ACTUAL@@" { a = 1; next }
      !a { e[++ne] = $0; next }
      { g[++ng] = $0 }
      END {
        n = (ne > ng ? ne : ng); shown = 0
        for (i = 1; i <= n && shown < 20; i++) if (e[i] != g[i]) {
          printf "    line %d expected: %s\n    line %d actual:   %s\n", i, e[i], i, g[i]; shown++
        }
      }
    ' >&2
}

# §3 MUST block: from the MUST heading up to the next heading of level <= 3.
_t90_must_block() {
  _t90_doc_s3 | _t90_block '### MUST'
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

# §7 PreCompact subsection: from its heading up to the next heading of level <= 3.
_t90_precompact_section() {
  { _t90_block '### PreCompact memory guard' < "$_T90_DOC"; } 2>/dev/null
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

# Every doc line whose normalized form names precompact.
_t90_expect_precompact_lines() {
  cat <<'EOF'
| Compact-time freshness | PreCompact memory guard (#742) | reuse |
### PreCompact memory guard (#742)
the Human-owned PreCompact wiring is active from this document.** Its enforcement status
EOF
}

# working-context trigger block: from its heading up to the next heading of level <= 3.
_t90_wc_trigger_block() {
  { _t90_block '### checkpoint → fresh context の trigger' < "$_T90_WA"; } 2>/dev/null
}

_t90_expect_wc_trigger_block() {
  cat <<'EOF'
### checkpoint → fresh context の trigger

以下は checkpoint 後に fresh context へ切り替える:

- **必須（standard 以上）**: worker / agent / model / runtime の変更、独立 reviewer の開始、worker 間 handoff、
  外部待ち・使用量上限による意図的中断
- **推奨**: compaction / context pressure が近い、phase 遷移で必要 working set が変わる、
  repair/review loop で superseded な議論が蓄積した

ultra-light / light では上記の「必須」も任意とする。`docs/ai/context-lifecycle.md` §8
（simple tasks do not gain mandatory ceremony）を満たすため、既存の working-context
ファイル以上の checkpoint を簡易タスクへ課さない。

provider 非依存の token 閾値は推測で作らない。usage が信頼できる形で取得できる場合のみ
補助情報として使う。
EOF
}

# local-exec-handoff transcript rule: the Rules item line, pinned.
_t90_expect_le_rule() {
  cat <<'EOF'
- **生の会話履歴（raw transcript）は packet に含めず、受け手にも渡さない**。受け手は canonical state（`INDEX.md` → `current-state.md` → phase-required L1）から fresh context で再開する（Context Lifecycle: `docs/ai/context-lifecycle.md`。導入先で解決できなくても本ルールは維持する）
EOF
}

if [ -r "$_T90_DOC" ]; then
  _t90_pass "TC-01 integration map exists"
else
  _t90_fail "TC-01 integration map missing"
fi

_t90_rr_bad="$({ _t90_sentences "$_T90_DOC" | _t90_anchor riverreview | _t90_anchor memory |
  grep -v -x -F -e "$_T90_ALLOW_RR_MEMORY"; } || true)"
_t90_must_act="$(_t90_must_block)"
_t90_must_exp="$(_t90_expect_must_block)"
if [ -r "$_T90_DOC" ] &&
   grep -q 'Fresh-context triggers' "$_T90_DOC" &&
   [ "$_t90_must_act" = "$_t90_must_exp" ] &&
   _t90_doc_s3 | grep -q '^### SHOULD' &&
   _t90_sentences "$_T90_DOC" | grep -q -x -F -e "$_T90_ALLOW_RR_MEMORY" &&
   [ -z "$_t90_rr_bad" ]; then
  _t90_pass "TC-02 owner, triggers, and no-second-SSoT boundary documented"
else
  _t90_fail "TC-02 MUST block differs from _t90_expect_must_block, or River Review+memory sentences other than _T90_ALLOW_RR_MEMORY: [$_t90_rr_bad] ($_T90_UPDATE_HINT)"
  if [ "$_t90_must_act" != "$_t90_must_exp" ]; then _t90_show_diff "$_t90_must_exp" "$_t90_must_act"; fi
fi

if grep -q 'worker / agent / model / runtime' "$_T90_WA" 2>/dev/null &&
   grep -q 'L0 → phase-required L1 → L2/L3 on demand' "$_T90_WA" &&
   grep -q 'raw chat transcript' "$_T90_WA"; then
  _t90_pass "TC-03 working-context carries fresh-context transition contract"
else
  _t90_fail "TC-03 working-context lifecycle contract incomplete"
fi

if grep -q 'conversation history の圧縮コピーではない' "$_T90_CA" 2>/dev/null &&
   grep -q 'review package + diff + evidence' "$_T90_CA" &&
   grep -q 'missing / stale' "$_T90_CA"; then
  _t90_pass "TC-04 context-packager is history-independent and fail-safe"
else
  _t90_fail "TC-04 context-packager handoff contract incomplete"
fi

if [ -r "$_T90_WA" ] && cmp -s "$_T90_WA" "$_T90_WC" && cmp -s "$_T90_WA" "$_T90_WP"; then
  _t90_pass "TC-05 working-context distributed surfaces are byte-identical"
else
  _t90_fail "TC-05 working-context distribution drift"
fi

if [ -r "$_T90_CA" ] && cmp -s "$_T90_CA" "$_T90_CC" && cmp -s "$_T90_CA" "$_T90_CP"; then
  _t90_pass "TC-06 context-packager distributed surfaces are byte-identical"
else
  _t90_fail "TC-06 context-packager distribution drift"
fi

# RunState / Context Manifest are not globbed: #1025 may legitimately add them.
# find (not a shell glob) so that zsh does not abort on a no-match pattern; any depth,
# case-insensitive, regular files and symlinks.
_t90_schema_hits="$({ find "$_T90_ROOT/schemas" \( -type f -o -type l \) \( \
    -iname '*checkpoint*' -o -iname '*context*state*' -o -iname '*lifecycle*' \
    -o -iname '*snapshot*' -o -iname '*session*' \) 2>/dev/null |
  awk -v p="$_T90_ROOT/schemas/" 'index($0, p) == 1 { $0 = substr($0, length(p) + 1) } 1' | awk -v allow=" $_T90_SCHEMA_ALLOW " 'index(allow, " " $0 " ") == 0' |
  sort | tr '\n' ' '; } || true)"
if [ -d "$_T90_ROOT/schemas" ] && [ -z "$_t90_schema_hits" ]; then
  _t90_pass "TC-07 no duplicate checkpoint/context state schema introduced"
else
  _t90_fail "TC-07 duplicate checkpoint/context state schema detected (or schemas/ missing): $_t90_schema_hits"
fi

if grep -q 'Do not persist or mechanically replay' "$_T90_DOC" 2>/dev/null &&
   grep -q 'hidden chain-of-thought' "$_T90_DOC" &&
   grep -q 'credentials, secrets, or personal data' "$_T90_DOC"; then
  _t90_pass "TC-08 privacy and raw-history exclusions documented"
else
  _t90_fail "TC-08 privacy/history exclusions incomplete"
fi

_t90_pc_lines="$({ _t90_anchor precompact < "$_T90_DOC"; } 2>/dev/null || true)"
_t90_pc_wc="$({ _t90_sentences "$_T90_WA" | _t90_anchor precompact; } || true)"
if [ -r "$_T90_DOC" ] && [ -r "$_T90_WA" ] &&
   [ "$(_t90_precompact_section)" = "$(_t90_expect_precompact_section)" ] &&
   [ "$_t90_pc_lines" = "$(_t90_expect_precompact_lines)" ] &&
   [ -z "$_t90_pc_wc" ] &&
   grep -q '#938 remains the owner' "$_T90_DOC"; then
  _t90_pass "TC-09 staged enforcement and open wait/resume ownership stay explicit"
else
  _t90_fail "TC-09 PreCompact section / doc PreCompact lines differ from _t90_expect_precompact_section / _t90_expect_precompact_lines, working-context names PreCompact: [$_t90_pc_wc], or #938 ownership missing ($_T90_UPDATE_HINT)"
fi

_t90_lm="$({ { _t90_sentences "$_T90_WA"; _t90_sentences "$_T90_DOC"; } |
  LC_ALL=C grep -i -E '(^|[^A-Za-z0-9_])light([^A-Za-z0-9_]|$)' |
  grep -i -E '必須|mandatory|must' |
  grep -v -x -F -e "$_T90_ALLOW_LIGHT_SKILL" -e "$_T90_ALLOW_LIGHT_DOC"; } || true)"
_t90_wct_act="$(_t90_wc_trigger_block)"
_t90_wct_exp="$(_t90_expect_wc_trigger_block)"
_t90_cj="$({ _t90_sentences "$_T90_WA"; _t90_sentences "$_T90_DOC"; } |
  { _t90_anchor checkpointjson | grep -v -x -F -e "$_T90_ALLOW_CPJSON_DOC"; } || true)"
if [ -r "$_T90_WA" ] &&
   [ "$_t90_wct_act" = "$_t90_wct_exp" ] &&
   grep -q 'simple tasks do not gain mandatory ceremony' "$_T90_DOC" &&
   [ -z "$_t90_lm" ] && [ -z "$_t90_cj" ]; then
  _t90_pass "TC-10 mandatory checkpoints are mode-scoped consistent with §8"
else
  _t90_fail "TC-10 trigger block differs from _t90_expect_wc_trigger_block, light+mandatory sentences other than _T90_ALLOW_LIGHT_SKILL / _T90_ALLOW_LIGHT_DOC: [$_t90_lm], or checkpoint.json sentences other than _T90_ALLOW_CPJSON_DOC: [$_t90_cj] ($_T90_UPDATE_HINT)"
  if [ "$_t90_wct_act" != "$_t90_wct_exp" ]; then _t90_show_diff "$_t90_wct_exp" "$_t90_wct_act"; fi
fi

_t90_tr="$({ _t90_sentences "$_T90_LA" | _t90_anchor transcript |
  grep -i -E '添付|含め|渡し|attach|include|pass' |
  grep -v -x -F -e "$_T90_ALLOW_TRANSCRIPT"; } || true)"
if [ -r "$_T90_LA" ] && cmp -s "$_T90_LA" "$_T90_LC" && cmp -s "$_T90_LA" "$_T90_LP" &&
   grep -q -x -F -e "$(_t90_expect_le_rule)" "$_T90_LA" &&
   [ -z "$_t90_tr" ]; then
  _t90_pass "TC-11 local-exec-handoff resumes from canonical state (3 surfaces byte-identical)"
else
  _t90_fail "TC-11 local-exec-handoff rule differs from _t90_expect_le_rule, distribution drift, or transcript-permitting sentences other than _T90_ALLOW_TRANSCRIPT: [$_t90_tr] ($_T90_UPDATE_HINT)"
fi

pg_extra_contract_finalize
