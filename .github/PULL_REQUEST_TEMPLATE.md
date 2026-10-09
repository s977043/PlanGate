# Pull Request

## Summary

Describe what changed and why.

## Linked Issue

<!--
Required if this PR addresses a tracked issue.

If this PR fully resolves the issue, use a GitHub closing keyword so the linked
issue is closed automatically on merge. Multiple keywords are allowed.

  closes #123
  fixes #456 fixes #457
  resolves s977043/plangate#789

If this PR is one slice of a larger issue (the issue must stay open), declare a
non-closing link instead. These are accepted by the issue-link check (#159).

  Refs: #1180
  Part of #1180
  Related to #1180

A bare "#123" mention is not a linkage declaration and does not satisfy the check.
-->

closes #

## Validation

- [ ] I ran the relevant checks locally.
- [ ] I updated documentation when behavior changed.
- [ ] I considered security, privacy, and backward compatibility impacts.
- [ ] **If this PR addresses a tracked issue, I linked it above — a closing keyword (`closes #N` / `fixes #N` / `resolves #N`) when this PR fully resolves it, or a non-closing link (`Refs: #N` / `Part of #N`) when it is one slice and the issue stays open.**

## Rollback / Detection

<!--
How to undo this change, and how we notice early that it was wrong.
Replace each TODO. If a line does not apply, write "N/A (reason)" instead of
deleting it, e.g. for a docs-only PR:

  - Kill-switch: revert this PR (single commit)
  - Detection signal: N/A (no runtime behavior change)
  - Observation window: N/A (nothing to observe after merge)

Docs that change agent behavior (rules, CLAUDE.md, AGENTS.md, agent or
command definitions) are not "no runtime behavior change": name a signal.
-->

- Kill-switch: TODO <!-- env knob / revert unit / none (why). e.g. set an env knob such as PG_T61_PARALLEL (illustrative name) back to serial; revert this PR as one commit -->
- Detection signal: TODO <!-- which CI job / metric / threshold tells us it went wrong. e.g. Test job duration exceeds its usual range -->
- Observation window: TODO <!-- how many runs or days we watch after merge, and what we do if it breaks (use the kill-switch, add one line to AGENT_LEARNINGS.md). e.g. 5 CI runs on main after merge -->

## Notes for reviewers

Add any review focus areas, rollout notes, or follow-up work here.
