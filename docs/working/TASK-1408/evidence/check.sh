#!/bin/sh
# TASK-1408 reproduction: REPRO-CHECK (manifest declaration vs measured facts) then TC-01..09, 11, E01..E03.
# Run from repo root on a clean tree after the evidence commit. Reads committed content at HEAD only.
# usage: sh check.sh <base-sha> <canon-sha> <expected-evidence-head> <expected-measure.sh-sha256>
#   The last two come from the record filled by the reviewer (PR body / handoff), never from this repo.
#   If HEAD or HEAD's measure.sh digest differs from them, nothing else runs (exit 3).
# Overall exit is non-zero if any REPRO-CHECK item or TC fails.
# This is a REPRODUCTION PROCEDURE, not a trust anchor. In-repo checks only detect forgetting to
# regenerate; they cannot detect tampering (a commit can rewrite this script and manifest together).
# Trust comes from records outside the commit (reviewed_at_sha, script digests in the PR body / handoff)
# and Human C-4. See status.md "独立再実行の手順".
E=docs/working/TASK-1408/evidence
B=$(git rev-parse "${1:?base}^{commit}") || exit 2
C=$(git rev-parse "${2:?canon}^{commit}") || exit 2
H=$(git rev-parse HEAD)
XH=$(git rev-parse "${3:?expected evidence head}^{commit}") || exit 2
XM=${4:?expected measure.sh sha256}
[ "$H" = "$XH" ] || { echo "STOP: HEAD $H != recorded evidence head $XH"; exit 3; }
[ "$(git show "$H:docs/working/TASK-1408/evidence/measure.sh" | shasum -a 256 | cut -d' ' -f1)" = "$XM" ] \
  || { echo "STOP: measure.sh digest at HEAD != recorded value"; exit 3; }
D=docs/ai/ai-loop-v2
P=$D/phase0-migration.md
T=.github/PULL_REQUEST_TEMPLATE.md
O="$D/README.md $D/north-star.md $D/taxonomy.md $D/harness-manifest.md $D/evaluation-trust-boundary.md $D/artifact-responsibilities.md"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
ALL=0
r() { echo "$1 exit=$2"; [ "$2" = 0 ] || ALL=1; }
hp() { git show "$H:$P"; }
bp() { git show "$B:$P"; }
sec() { hp | awk '/^#### 例外の失効/{f=1} /^#### 経緯/{f=0} f'; hp | awk '/^### Phase 1 exit criteria/{f=1} f'; }
mf() { git show "$H:$E/manifest.txt" | sed -n "s/^$1: //p"; }
sh256() { git show "$H:$E/$1" | shasum -a 256 | cut -d' ' -f1; }

# ---- REPRO-CHECK: declaration (manifest at HEAD) vs fixed expectations vs measured facts.
# Detects forgetting to regenerate only; not a tamper check.
EXP_PATHS='.github/PULL_REQUEST_TEMPLATE.md docs/ai/ai-loop-v2/phase0-migration.md'
v() { echo "REPRO-CHECK $1 exit=$2"; [ "$2" = 0 ] || ALL=1; }
git diff --quiet HEAD && [ -z "$(git ls-files --others --exclude-standard -- "$E")" ]; v clean-tree $?
[ "$ALL" = 0 ] || { echo "ABORT: working tree is not clean"; exit 1; }
git cat-file -e "$H:$E/manifest.txt" 2>/dev/null; v manifest-committed $?
[ "$(mf base)" = "$B" ]; v declared-base $?
[ "$(mf canon)" = "$C" ]; v declared-canon $?
[ "$(mf canon_parent)" = "$B" ] && [ "$(git rev-parse "$C^")" = "$B" ] && [ "$(git rev-list --parents -n1 "$C" | wc -w | tr -d ' ')" = 2 ]; v canon-parent-is-base $?
git merge-base --is-ancestor "$C" "$H" && [ "$C" != "$H" ]; v canon-ancestor-of-head $?
[ "$(mf canon_paths)" = "$EXP_PATHS" ] && [ "$(git diff --name-only "$B" "$C" | sort | tr '\n' ' ' | sed 's/ $//')" = "$EXP_PATHS" ]; v canon-paths-exact $?
pre=$(mf head_paths_prefix)
[ "$pre" = "docs/working/TASK-1408/" ] && [ -n "$(git diff --name-only "$C" "$H")" ] && [ -z "$(git diff --name-only "$C" "$H" | grep -v "^$pre")" ]; v head-paths-scoped $?
( for f in measure.sh check.sh make-manifest.sh regen.sh measurements.txt; do
    d=$(mf "sha256 $f"); [ -n "$d" ] && [ "$d" = "$(sh256 "$f")" ] || { echo "  sha256 mismatch: $f"; exit 1; }
  done ); v blob-digests $?
git show "$H:$E/measure.sh" > "$TMP/measure.sh" && sh "$TMP/measure.sh" "$B" "$C" > "$TMP/m.txt" 2>&1 \
 && git show "$H:$E/measurements.txt" | cmp -s - "$TMP/m.txt"; v measurements-reproduce $?
mf me1 | grep -qF '"oid":"3331e5c49751b268412d4db8e5862982ac0005d8"' && mf me1 | grep -qF '"state":"MERGED"' && mf me1 | grep -qF '"mergedAt":"2026-09-29T00:01:17Z"'; v declared-me1 $?
[ "$ALL" = 0 ] || echo "REPRO-CHECK FAILED (TCs below still run)"

gh pr view 1402 -R s977043/plangate --json mergeCommit -q .mergeCommit.oid | grep -qx 3331e5c49751b268412d4db8e5862982ac0005d8 \
 && sec | grep -qF 3331e5c49751b268412d4db8e5862982ac0005d8 && ! bp | grep -qF '例外の失効'; r TC-01 $?

sh "$E/measure.sh" "$B" >/dev/null 2>&1; r TC-02 $?

sec | grep -qF '2026-09-29' && sec | grep -qF 'M-2 と M-3' && sec | grep -qF '以後の canon 7 本の規定変更は I4' \
 && [ "$(hp | grep -c '^#### 例外の失効')" = 1 ] && [ "$(bp | grep -c '^#### 例外の失効')" = 0 ]; r TC-03 $?

sec | grep -qF '**遡及しない。** Phase 0 / Phase 0.1 の充足記録（I1）は当時の規定に照らして有効なまま残す' \
 && [ "$(git diff --numstat "$B" "$H" -- $P | awk '{print $2}')" = 0 ]; r TC-04 $?

[ "$(hp | grep -c '^### Phase 1 exit criteria$')" = 1 ] && [ "$(bp | grep -c 'Phase 1 exit criteria')" = 0 ] \
 && [ "$(hp | grep -c '^- \[ \] `9445df17` より後の canon 7 本の規定変更が、すべて I4')" = 1 ]; r TC-05 $?

( for k in '語彙近似の限界' '`ls schemas/` 非再帰' 'fail-closed の主体と時期'; do sec | grep -F "$k" | grep -q '^|' || exit 1; done ); r TC-06 $?

git diff --quiet --exit-code "$B" "$H" -- $O && [ "$(git diff --numstat "$B" "$H" -- $P | awk '{print $2}')" = 0 ]; r TC-07 $?

git diff --quiet --exit-code "$C" "$H" -- $D $T \
 && [ "$(sh256 measure.sh)" = "$(mf 'sha256 measure.sh')" ]; r TC-08 $?

[ "$(git show "$H:$T" | grep -c 'canon 7 files')" = 1 ] && [ "$(git show "$B:$T" | grep -c 'canon 7 files')" = 0 ] \
 && git show "$H:$T" | grep -F 'canon 7 files' | grep -F 'This replaces re-measuring M-1 to M-3' | grep -F 'CI alone is not enough' | grep -qF 'Only a Human can confirm a change is non-normative' \
 && sec | grep -qF '**以後の I4 の最低要件**' && sec | grep -qF '**再測定の終了**' && sec | grep -qF '| canon 変更 PR ごとの再測定 |'; r TC-09 $?

( n=0; for k in '<別 issue>' '<PR 番号>' '<記録時 SHA>' '<base>' '<実測>' '2026-11-XX' '<canon 7 本>' '<!-- Q-1' '（Q-1）' '（Q-5）'; do sec | grep -qF "$k" && { echo "  found $k"; n=1; }; done; [ $n = 0 ] ); r TC-11 $?

sed "s/^V='HarnessManifest.*/V=''/; s/^V=\"\$V\".*//" "$E/measure.sh" > "$TMP/mut-empty.sh"
! sh "$TMP/mut-empty.sh" "$B" >/dev/null 2>&1 && ! sh "$E/measure.sh" deadbeefdeadbeef >/dev/null 2>&1; r TC-E01 $?

sed "s/^V='HarnessManifest.*/V='zzzz_no_match'/; s/^V=\"\$V\".*//" "$E/measure.sh" > "$TMP/mut-nomatch.sh"
! sh "$TMP/mut-nomatch.sh" "$B" >/dev/null 2>&1; r TC-E01b $?

[ "$(git log --first-parent --format=%h 3331e5c4..$B -- $P $O | sort | tr '\n' ' ')" = "0122d6f9 6d626360 a3c9146d a6d1ea5f " ] \
 && ( for c in a6d1ea5f 6d626360 0122d6f9 a3c9146d; do sec | grep -qF "\`$c\`" || exit 1; done ); r TC-E02 $?

[ "$(git rev-parse --short=8 3331e5c4^1)" = 50fe9d5f ] && [ "$(git rev-list --parents -n1 3331e5c4 | wc -w | tr -d ' ')" = 2 ]; r TC-E03 $?

exit $ALL
